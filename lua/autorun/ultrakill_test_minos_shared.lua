if SERVER then AddCSLuaFile() end

-- The Corpse of King Minos (2-4 boss) + its Arm (2-4 first encounter).
-- Sources: MinosBoss.cs / MinosArm.cs / Parasite.cs / PhysicalShockwave.cs /
-- BlackHoleProjectile.cs decompile, level 2-4 scene dump (minos_probe.py),
-- clip events from the AssetRipper .anim exports (minos_events.json).

UKMinos = UKMinos or {}

UKMinos.CATEGORY = "ULTRAKILL Test"

UKMinos.MODEL_CORPSE = "models/ultrakill_prelude_test/minos_corpse.mdl"
UKMinos.MODEL_ARM = "models/ultrakill_prelude_test/minos_arm.mdl"
UKMinos.MODEL_PARASITE = "models/ultrakill_prelude_test/minos_parasite.mdl"

-- Workshop pack convention: canon HP x1000.
UKMinos.HP_CORPSE = 160 * 1000
UKMinos.HP_ARM = 65 * 1000

-- TRUE 1:1 scale: 1 canon metre = 40 su (the corpse torso is ~100 m above
-- ground, hands ~35 m to each side — as in the game).
UKMinos.UNIT = 40

-- Both bosses are arena-anchored in canon and never rotate. In sandbox they
-- slowly yaw toward their target so they stay engageable; the rate is a convar
-- (slow by default, adjustable).
CreateConVar( "ukminos_turnrate", "10",
  FCVAR_ARCHIVE + FCVAR_REPLICATED,
  "Minos corpse/arm turn rate toward the target, deg/s (canon: 0 - static)", 0, 360 )

-- Canon PhysicalShockwave: damage 35, maxSize 350 m (radius), speed 90 m/s
-- (60 on LENIENT, 30 on HARMLESS). Height ratios x3 ground / x7 wall are canon;
-- the base is playability-capped so the wave stays jumpable like in the game.
UKMinos.WAVE_DAMAGE = 35
UKMinos.WAVE_MAXSIZE = 350          -- metres
UKMinos.WAVE_HEIGHT_DOWN = 2.5      -- metres (jumpable front)
UKMinos.WAVE_HEIGHT_WALL = 6.0
UKMinos.WAVE_THICKNESS = 2.0        -- metres, radial hit band

-- Corpse swing: SwingCheck2 damage 45 (parryable, "+ DOWN TO SIZE" on parry,
-- 35 self-damage on parry). Arm radius approximates the canon arm capsules
-- (r 2.5-3 units * 5 m).
UKMinos.SWING_DAMAGE = 45
UKMinos.SWING_RADIUS_M = 14         -- metres around the arm segment
UKMinos.PARRY_SELF_DAMAGE = 35 * 1000

-- Parasites (phase 2): canon Projectile Spread = 8+1 projectiles, 3 deg cone,
-- 25 dmg, speed >= 65 m/s; Projectile Homing = 30 dmg (prefab), x5 scale.
UKMinos.PARASITE_SPREAD_DAMAGE = 25
UKMinos.PARASITE_SPREAD_COUNT = 8   -- + centre projectile = 9 total
UKMinos.PARASITE_SPREAD_ANGLE = 3
UKMinos.PARASITE_PROJ_SPEED = 65    -- m/s minimum (canon: max(65, dist))

-- Black hole: speed 8 m/s (x1.5 BRUTAL, x2 UKMD), contact = 99 hard damage
-- (hp>10 -> hp=1, else kill).
UKMinos.BLACKHOLE_SPEED = 8

UKMinos.SOUND = {
  Hurt          = "ultrakill_prelude_test/minos/hurt.wav",            -- MinosHurt (windup/flinch)
  BigHurt       = "ultrakill_prelude_test/minos/bighurt.wav",         -- MinosBigHurtShorter
  BigHurtQuiet  = "ultrakill_prelude_test/minos/bighurt_quiet.wav",   -- MinosBigHurtQuieter (arm death)
  Impact        = "ultrakill_prelude_test/minos/impact.wav",          -- canon triple layer
  ShakeLoop     = "ultrakill_prelude_test/minos/shake_loop.wav",      -- Door 2 Open @0.25
  Shockwave     = "ultrakill_prelude_test/minos/shockwave.wav",       -- Impacts_001Short @0.75
  PunchExplosion = "ultrakill_prelude_test/minos/punch_explosion.wav",
  ParasiteWindup = "ultrakill_prelude_test/minos/parasite_windup.wav", -- MassBigPain @0.65
  BlackHoleLoop = "ultrakill_prelude_test/minos/blackhole_loop.wav",  -- loop @1.5
  ProjLoop      = "ultrakill_prelude_test/mannequin/proj_loop.wav",   -- AnimeSlash (shared kit)
  ProjCharge    = "ultrakill_prelude_test/mannequin/proj_charge.wav",
}

UKMinos.CLASS = {
  Corpse = "ultrakill_test_minos_corpse",
  Arm = "ultrakill_test_minos_arm",
  Parasite = "ultrakill_test_minos_parasite",
  BlackHole = "ultrakill_test_minos_blackhole",
  Projectile = "ultrakill_test_minos_projectile",
  Homing = "ultrakill_mindflayer_projectile",     -- act1 required dep (mannequin pattern)
}

-- Base difficulty convar (drg_ultrakill_difficulty) — sentry/mannequin pattern.
function UKMinos.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

function UKMinos.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    -- round-4 2026-07-10: FLAT canon to the player — plytakedmgmult defaults
    -- to 0.1 and quietly cut every hit to 10% (Sentry r3 policy, pack-wide)
    return damage
  end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

--------------------------------------------------------------------------------
-- Physical shockwaves (canon PhysicalShockwave, server-side damage ring +
-- clientside expanding visual). One global list, one Tick hook — waves outlive
-- their owner like in canon.
--------------------------------------------------------------------------------

if SERVER then

  util.AddNetworkString( "UKMinos_Wave" )

  UKMinos.ActiveWaves = UKMinos.ActiveWaves or {}

  -- normal: plane normal (ground wave = up, wall wave = wall normal)
  function UKMinos.SpawnWave( owner, origin, normal, opts )
    opts = opts or {}
    local UNIT = UKMinos.UNIT
    local diff = UKMinos.GetDifficulty( owner )
    local speed = 90
    if diff == 1 then speed = 60 elseif diff == 0 then speed = 30 end

    local wave = {
      owner = owner,
      origin = origin,
      normal = normal,
      radius = 0,
      speed = ( opts.speed or speed ) * UNIT,
      maxR = ( opts.maxsize or UKMinos.WAVE_MAXSIZE ) * UNIT,
      height = ( opts.height or UKMinos.WAVE_HEIGHT_DOWN ) * UNIT,
      thick = UKMinos.WAVE_THICKNESS * UNIT,
      damage = opts.damage or UKMinos.WAVE_DAMAGE,
      hitPlayers = {},
      hitEnts = {},
    }
    table.insert( UKMinos.ActiveWaves, wave )

    sound.Play( UKMinos.SOUND.Shockwave, origin, 140, math.random( 68, 82 ), 1 )

    net.Start( "UKMinos_Wave" )
    net.WriteVector( origin )
    net.WriteNormal( normal )
    net.WriteFloat( wave.speed )
    net.WriteFloat( wave.maxR )
    net.WriteFloat( wave.height )
    net.Broadcast()

    return wave
  end

  local function WaveHits( wave, ent )
    local center = ent:WorldSpaceCenter()
    local rel = center - wave.origin
    local n = wave.normal
    local alongN = rel:Dot( n )
    -- must be within the wave sheet's extent off the plane
    if alongN < -wave.height * 0.2 or alongN > wave.height then return false end
    local inPlane = rel - n * alongN
    local d = inPlane:Length()
    -- radial hit band (front of the expanding ring), padded by entity radius
    local pad = ent:BoundingRadius() * 0.5 + wave.thick
    return math.abs( d - wave.radius ) <= pad
  end

  hook.Add( "Tick", "UKMinos_Waves", function()
    local waves = UKMinos.ActiveWaves
    if #waves == 0 then return end
    local dt = engine.TickInterval()

    for i = #waves, 1, -1 do
      local wave = waves[ i ]
      wave.radius = wave.radius + wave.speed * dt

      -- players
      for _, ply in ipairs( player.GetAll() ) do
        if ply:Alive() and not wave.hitPlayers[ ply ] and WaveHits( wave, ply ) then
          wave.hitPlayers[ ply ] = true
          local dmg = DamageInfo()
          dmg:SetDamage( UKMinos.ScaleAttackDamage( ply, wave.damage ) )
          dmg:SetDamageType( DMG_SONIC )
          dmg:SetAttacker( IsValid( wave.owner ) and wave.owner or game.GetWorld() )
          dmg:SetInflictor( IsValid( wave.owner ) and wave.owner or game.GetWorld() )
          dmg:SetDamagePosition( ply:WorldSpaceCenter() )
          ply:TakeDamageInfo( dmg )
          -- canon: LaunchFromPoint below the player (30, 30)
          ply:SetVelocity( Vector( 0, 0, 400 ) )
        end
      end

      -- NPCs/nextbots: canon multiplier = damage/10 (3.5 -> x1000)
      for _, ent in ipairs( ents.FindInSphere( wave.origin, wave.radius + 200 ) ) do
        if ent ~= wave.owner and IsValid( ent ) and not wave.hitEnts[ ent ]
            and ( ent:IsNPC() or ent:IsNextBot() )
            and not ( ent.UKMinos_IsMinos ) and WaveHits( wave, ent ) then
          wave.hitEnts[ ent ] = true
          local dmg = DamageInfo()
          -- round-3 sweep: canon x100 LANDED, pre-divided (was raw x100 -> landed x2000 of canon)
          dmg:SetDamage( ent.IsUltrakillNextbot
            and UKNpcDmg.PreMult( ent, wave.owner, wave.damage * 100 )
            or wave.damage )
          dmg:SetDamageType( DMG_SONIC )
          dmg:SetAttacker( IsValid( wave.owner ) and wave.owner or game.GetWorld() )
          dmg:SetInflictor( IsValid( wave.owner ) and wave.owner or game.GetWorld() )
          dmg:SetDamagePosition( ent:WorldSpaceCenter() )
          dmg:SetDamageForce( Vector( 0, 0, 20000 ) )
          ent:TakeDamageInfo( dmg )
        end
      end

      if wave.radius >= wave.maxR then
        table.remove( waves, i )
      end
    end
  end )

end

if CLIENT then

  -- clientside expanding ring visuals (rendered by a PostDrawTranslucent hook;
  -- effect entities can't easily outlive huge radii)
  UKMinos.ClientWaves = UKMinos.ClientWaves or {}

  net.Receive( "UKMinos_Wave", function()
    table.insert( UKMinos.ClientWaves, {
      origin = net.ReadVector(),
      normal = net.ReadNormal(),
      speed = net.ReadFloat(),
      maxR = net.ReadFloat(),
      height = net.ReadFloat(),
      born = CurTime(),
    } )
  end )

  local matWave = CreateMaterial( "UKMinos_Wave_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "vgui/white",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )

  local SEGS = 96

  hook.Add( "PostDrawTranslucentRenderables", "UKMinos_Waves", function( depth, sky )
    if sky then return end
    local waves = UKMinos.ClientWaves
    if #waves == 0 then return end
    local now = CurTime()

    for i = #waves, 1, -1 do
      local w = waves[ i ]
      local r = ( now - w.born ) * w.speed
      if r >= w.maxR then
        table.remove( waves, i )
        continue
      end

      -- ring basis on the wave plane
      local n = w.normal
      local t1 = n:Cross( math.abs( n.z ) < 0.9 and Vector( 0, 0, 1 ) or Vector( 1, 0, 0 ) )
      t1:Normalize()
      local t2 = n:Cross( t1 )

      local fade = 1 - r / w.maxR
      local a = math.floor( 200 * fade )

      render.SetMaterial( matWave )
      mesh.Begin( MATERIAL_TRIANGLE_STRIP, SEGS * 2 + 2 )
      for s = 0, SEGS do
        local ang = ( s / SEGS ) * math.pi * 2
        local dir = t1 * math.cos( ang ) + t2 * math.sin( ang )
        local base = w.origin + dir * r
        mesh.Position( base )
        mesh.Color( 255, 240, 200, a )
        mesh.TexCoord( 0, 0, 0 )
        mesh.AdvanceVertex()
        mesh.Position( base + n * w.height )
        mesh.Color( 255, 240, 200, 0 )
        mesh.TexCoord( 0, 0, 1 )
        mesh.AdvanceVertex()
      end
      mesh.End()
    end
  end )

end
