if SERVER then AddCSLuaFile() end

UKGuttertank = UKGuttertank or {}

UKGuttertank.MODEL = "models/ultrakill_prelude_test/guttertank.mdl"
-- canon RocketEnemy prefab bake (red/orange skull materials, 20 su/m to
-- match the tank's visual scale — fits the cannon bore)
UKGuttertank.ROCKET_MODEL = "models/ultrakill_prelude_test/guttertank_rocket.mdl"
-- canon Landmine prefab bake (ProBuilder plate + light beacon, 20 su/m)
UKGuttertank.MINE_MODEL = "models/ultrakill_prelude_test/guttertank_mine.mdl"
UKGuttertank.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Guttertank: 23 HP.
UKGuttertank.HP = 23000

-- Logic convention: 40 su per canon meter (gutterman/johninator standard).
-- The model itself is compiled at $scale 60 (~180 su) to stand next to the
-- shipped Gutterman (174 su) — canon envelope is the same 8 m capsule.
UKGuttertank.UNIT = 40

-- Canon Guttertank.GetSpeed: 20 m/s, angular 1200, acceleration 80; SetSpeed
-- anim/nav multipliers per difficulty (0 HARMLESS .. 5 UKMD).
local UNIT = UKGuttertank.UNIT
UKGuttertank.BASE_SPEED = 14 * UNIT -- round 3 2026-07-10: «уменьшить скорость ходьбы» (was 20)
UKGuttertank.SPEED_MULT = { [0] = 0.6, [1] = 0.8, [2] = 0.9, [3] = 1.0, [4] = 1.0, [5] = 1.0 }
function UKGuttertank.Speed( d )
  return UKGuttertank.BASE_SPEED * ( UKGuttertank.SPEED_MULT[ d ] or 1.0 )
end

-- UKBase Explosion damage convention: wiki player damage x10. Canon: rocket
-- explosion 35, landmine explosion 35 (super = enemyDamageMultiplier 2),
-- punch SwingCheck 35.
UKGuttertank.ROCKET_DAMAGE = 35 * 10
UKGuttertank.MINE_DAMAGE = 35 * 10
UKGuttertank.PUNCH_DAMAGE = 35 * 10

-- NPC-scale LANDED mine blast targets. A player-owned blast (parried serve
-- or shot-down mine) nets a FIXED x40 on UK-nextbot victims through the base
-- Explosion -> DealDamage path (Providence PARRY_EXPLOSION_NET_MULT lesson:
-- UltrakillScaleDamage pre-scales by 40/(plydmgmult*10), the victim's
-- DamageMultiplier multiplies plydmgmult*10 back) — 525 fed landed as 21000.
-- Targets are parity with the NPC-owned path (fed x20 by the victim), so the
-- mine hurts NPCs the same no matter who set it off; parried = x1.5 (super).
UKGuttertank.MINE_DAMAGE_NPC = UKGuttertank.MINE_DAMAGE * 20         -- 7000
UKGuttertank.MINE_PARRY_DAMAGE_NPC = UKGuttertank.MINE_DAMAGE * 1.5 * 20 -- 10500
UKGuttertank.PARRY_EXPLOSION_NET_MULT = 40

-- Canon Grenade.rocketSpeed = 150 m/s (=6000 su/s); clamped for Source physics
-- (johninator convention).
UKGuttertank.ROCKET_SPEED = 4200

-- Feedback tune: he attacked a touch too often — every canon cooldown is
-- stretched by this much (rates stay canon-shaped, just slower)
UKGuttertank.COOLDOWN_MULT = 1.25

-- Canon decision ranges (Guttertank.Update): punch < 10 m (now or predicted
-- 0.5 s), rocket only when predicted 1 s distance > 15 m, mine spacing 15 m.
-- Tuned 2026-07-10: the canon trigger armed the punch from ~20 m against
-- an approaching target (10 m + 0.5 s lead) while the swing itself only
-- reaches lunge 6 m + hit sphere ~4 m — he kept punching air. Trigger cut to
-- 6 m with a 0.2 s lead; the punch damage/lunge stay canon.
UKGuttertank.PUNCH_RANGE = 5 * UNIT
UKGuttertank.PUNCH_PREDICT = 0.2       -- canon 0.5 s
UKGuttertank.ROCKET_MIN_RANGE = 15 * UNIT
UKGuttertank.MINE_SPACING = 15 * UNIT
UKGuttertank.MINE_LIMIT = 5

-- Real action timings: Unity clip-event seconds / controller state speed
-- (Punch x1.2, Shoot x1.25, Landmine x1.5, PunchStagger x1, Death x1).
UKGuttertank.ACTION = {
  Punch = {
    duration = 1.128,  -- StopAction 1.3534 / 1.2
    active = 0.442,    -- PunchActive 0.5307 / 1.2
    stop = 0.542,      -- PunchStop 0.6499 / 1.2
  },
  Shoot = {
    duration = 1.518,  -- StopAction 1.8973 / 1.25
    predict = 0.364,   -- PredictTarget 0.4550 / 1.25
    fire = 0.771,      -- FireRocket 0.9641 / 1.25
  },
  Landmine = {
    duration = 0.816,  -- StopAction 1.2235 / 1.5
    place = 0.500,     -- PlaceMine 0.7494 / 1.5
  },
  PunchStagger = {
    duration = 1.873,      -- StopAction
    fallImpact = 0.069,    -- FallImpact
    stopParryable = 1.319, -- StopParryable
    clipLength = 1.9667,   -- canon GotParried replays from normalized 0.7
  },
  Death = { duration = 0.467 },
}

UKGuttertank.SOUND = {
  Hurt = {
    "ultrakill_prelude_test/guttertank/hurt1.wav",
    "ultrakill_prelude_test/guttertank/hurt2.wav",
    "ultrakill_prelude_test/guttertank/hurt3.wav",
    "ultrakill_prelude_test/guttertank/hurt4.wav",
  },
  Death       = "ultrakill_prelude_test/guttertank/death.wav",
  PunchPrep   = "ultrakill_prelude_test/guttertank/punch_prep.wav",
  PunchHit    = "ultrakill_prelude_test/guttertank/punch_hit.wav",
  RocketPrep  = "ultrakill_prelude_test/guttertank/rocket_prep.wav",
  RocketFire  = "ultrakill_prelude_test/guttertank/rocket_fire.wav",
  RocketLoop  = "ultrakill_prelude_test/guttertank/rocket_loop.wav",
  MinePrep    = "ultrakill_prelude_test/guttertank/mine_prep.wav",
  MineBeep    = "ultrakill_prelude_test/guttertank/mine_beep.wav",   -- canon pitch 1.5 baked
  MineScan    = "ultrakill_prelude_test/guttertank/mine_scan.wav",   -- loop
  FallImpact  = "ultrakill_prelude_test/guttertank/fall_impact.wav", -- GuttermanRelease x0.5
  RadioStatic = "ultrakill_prelude_test/guttertank/radio_static.wav", -- loop, canon vol 0.2
  SteamLoop   = "ultrakill_prelude_test/guttertank/steam_loop.wav",   -- loop, canon vol 0.25
  Step        = "ultrakill_prelude_test/guttertank/step.wav",
}

UKGuttertank.CLASS = {
  Rocket = "ultrakill_test_guttertank_rocket",
  Mine   = "ultrakill_test_guttertank_mine",
  Corpse = "ultrakill_test_guttertank_corpse",
}

-- Canon sibling rivalry: the Guttertank's punch instantly kills a Gutterman.
UKGuttertank.GUTTERMAN_CLASSES = {
  ultrakill_test_gutterman            = true,
  ultrakill_test_gutterman_boss       = true,
  ultrakill_test_gutterman_casketless = true,
}

if SERVER then

  -- HL2 heavies gate explosion damage in the engine, so the base's plain
  -- DMG_BLAST TakeDamageInfo bounces off them: the helicopter demands
  -- DMG_AIRBOAT (or a CLASS_MISSILE inflictor), the strider wants
  -- MaxDamage > 50, the gunship eats health in blast increments. Value =
  -- damage multiplier (the helicopter's 5600 hp would otherwise take ~16
  -- rockets).
  local BLAST_GATED = {
    npc_helicopter     = 4,
    npc_combinegunship = 1,
    npc_strider        = 1,
    npc_combinedropship = 1,
  }

  -- Deal engine-shaped blast damage to gated NPCs in the radius; returns an
  -- IgnoreFilter for the base Explosion so they aren't hit twice.
  function UKGuttertank.BlastCompat( inflictor, attacker, pos, radius, damage )
    local ignore = {}
    if not IsValid( inflictor ) then return ignore end
    attacker = IsValid( attacker ) and attacker or inflictor
    for _, ent in ipairs( ents.FindInSphere( pos, radius ) ) do
      local mult = BLAST_GATED[ ent:GetClass() ]
      if mult and ent:Health() > 0 then
        local dmg = DamageInfo()
        dmg:SetDamage( damage * mult )
        if dmg.SetMaxDamage then dmg:SetMaxDamage( damage * mult ) end
        dmg:SetDamageType( bit.bor( DMG_BLAST, DMG_AIRBOAT ) )
        dmg:SetAttacker( attacker )
        dmg:SetInflictor( inflictor )
        dmg:SetDamagePosition( pos )
        if dmg.SetReportedPosition then dmg:SetReportedPosition( pos ) end
        ent:TakeDamageInfo( dmg )
        ignore[ ent:EntIndex() ] = true
      end
    end
    return ignore
  end

  -- Shootable projectiles, the reliable way. The engine never delivered
  -- bullet damage into these DrG-based projectiles no matter what (solid +
  -- valid mdl hitbox + clean Lua chain — rounds 5-7), so the trace ->
  -- DispatchTraceAttack channel is abandoned entirely: every player shot
  -- (UKWeapons and HL2 guns both go through FireBullets) is intersected
  -- with the projectiles by hand and the hit is dispatched straight into
  -- OnTakeDamage. Value = hit radius around the entity's center.
  local SHOOTABLE = {
    [ UKGuttertank.CLASS.Rocket ] = 60,
    [ UKGuttertank.CLASS.Mine ]   = 40,
  }

  -- The rocket covers 4200 su/s while the client renders it a whole interp
  -- window (~0.03-0.1 s = 130-420 su) BEHIND its real server position, so a
  -- point test can only hit by fluke: the player aims at where the rocket
  -- was. Test the shot ray against the rocket's recent travel SEGMENT
  -- instead (rewind by interp + a tick of lead) — classic closest-points-
  -- of-two-segments (Ericson).
  local LAG_REWIND = 0.15
  local TICK_LEAD = 0.02

  local function SegSegDistSqr( p1, q1, p2, q2 )
    local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
    local a, e = d1:Dot( d1 ), d2:Dot( d2 )
    local f = d2:Dot( r )
    local s, t
    if a <= 1e-6 and e <= 1e-6 then
      return r:Dot( r ), p1
    elseif a <= 1e-6 then
      s, t = 0, math.Clamp( f / e, 0, 1 )
    else
      local c = d1:Dot( r )
      if e <= 1e-6 then
        t, s = 0, math.Clamp( -c / a, 0, 1 )
      else
        local b = d1:Dot( d2 )
        local denom = a * e - b * b
        s = denom > 1e-6 and math.Clamp( ( b * f - c * e ) / denom, 0, 1 ) or 0
        t = ( b * s + f ) / e
        if t < 0 then
          t, s = 0, math.Clamp( -c / a, 0, 1 )
        elseif t > 1 then
          t, s = 1, math.Clamp( ( b - c ) / a, 0, 1 )
        end
      end
    end
    local c1 = p1 + d1 * s
    local c2 = p2 + d2 * t
    return ( c1 - c2 ):Dot( c1 - c2 ), c1
  end

  -- diagnostics for in-game rounds: near misses print their distance so a
  -- silent console after a shot means the hook never ran (confirmed working
  -- round 9 — keep off)
  local DEBUG = false

  -- Impact Hammer compat shim. The dredux hammer swing (SWEP:ImpactPunch)
  -- hits NPCs via a filtered TraceHull and sweeps PROJECTILES via a
  -- hardcoded class list (uk_proj_core/rocket/chainsaw) — our mine and
  -- rocket are invisible to it. Wrap ImpactPunch (base + the pump override;
  -- core/sawedon inherit the base one) and run the same 155-su/16³ sweep
  -- over our projectiles: melee DMG_CLUB straight into OnTakeDamage —
  -- an armed mine parries, a standby mine gets knocked away, a rocket pops.
  local function UKGT_HammerSweep( swep )
    local owner = swep:GetOwner()
    if not IsValid( owner ) or not owner:IsPlayer() then return end
    local startPos = owner:GetShootPos()
    local aim = owner:GetAimVector()
    local bounds = Vector( 16, 16, 16 )
    for _, ent in ipairs( ents.FindAlongRay( startPos, startPos + aim * 155,
        -bounds, bounds ) ) do
      if SHOOTABLE[ ent:GetClass() ] and not ent.UKGT_Exploded then
        local dmg = DamageInfo()
        dmg:SetDamage( 1 )
        dmg:SetAttacker( owner )
        dmg:SetInflictor( swep )
        dmg:SetDamageType( DMG_CLUB )
        dmg:SetDamageForce( aim * 10000 )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        ent:OnTakeDamage( dmg )
        ent:EmitSound( "ultrakill/weapons/shotgun/hammerimpact.ogg", 90,
          math.random( 95, 105 ), 1 )
      end
    end
  end

  local function UKGT_WrapImpactPunch( stored )
    if not istable( stored ) or not isfunction( stored.ImpactPunch ) then return end
    if stored.UKGT_HammerShim then return end
    stored.UKGT_HammerShim = true
    local orig = stored.ImpactPunch
    stored.ImpactPunch = function( swep, ... )
      UKGT_HammerSweep( swep )
      return orig( swep, ... )
    end
  end

  hook.Add( "InitPostEntity", "UKGT_ImpactHammerShim", function()
    UKGT_WrapImpactPunch( weapons.GetStored( "weapon_dredux_base2_uk" ) )
    UKGT_WrapImpactPunch( weapons.GetStored( "weapon_dredux_uk_impact_pump" ) )
  end )

  hook.Add( "EntityFireBullets", "UKGT_ShootableProjectiles", function( shooter, data )
    if not IsValid( shooter ) or not shooter:IsPlayer() then return end
    local src = data.Src
    local dir = data.Dir:GetNormalized()
    local dist = ( data.Distance and data.Distance > 0 ) and data.Distance or 56756
    local rayEnd = src + dir * dist

    for class, hitR in pairs( SHOOTABLE ) do
      for _, ent in ipairs( ents.FindByClass( class ) ) do
        if IsValid( ent ) and not ent.UKGT_Exploded then
          local center = ent:WorldSpaceCenter()
          local vel = ent:GetVelocity()
          local dSqr, rayPt = SegSegDistSqr( src, rayEnd,
            center - vel * LAG_REWIND, center + vel * TICK_LEAD )
          if dSqr <= hitR * hitR then
            -- a wall (or an NPC body) between the muzzle and the
            -- projectile still blocks the shot — but sibling projectiles
            -- don't shield each other (round-9 log: a second rocket
            -- BLOCKED the shot at the first one)
            local tr = util.TraceLine( {
              start = src,
              endpos = rayPt,
              mask = MASK_SHOT_HULL,
              filter = function( hit )
                if hit == shooter then return false end
                if SHOOTABLE[ hit:GetClass() ] then return false end
                return true
              end,
            } )
            if not tr.Hit then
              if DEBUG then
                print( string.format( "[UKGT] %s shot down (miss dist %.0f su)",
                  class, math.sqrt( dSqr ) ) )
              end
              local dmg = DamageInfo()
              dmg:SetDamage( math.max( data.Damage or 1, 1 ) )
              dmg:SetDamageType( DMG_BULLET )
              dmg:SetAttacker( shooter )
              dmg:SetInflictor( shooter )
              dmg:SetDamagePosition( rayPt )
              ent:OnTakeDamage( dmg )
            elseif DEBUG then
              print( string.format( "[UKGT] %s shot BLOCKED by %s",
                class, tostring( tr.Entity ) ) )
            end
          elseif DEBUG and dSqr <= 300 * 300 then
            print( string.format( "[UKGT] %s near miss: %.0f su (need <= %d)",
              class, math.sqrt( dSqr ), hitR ) )
          end
        end
      end
    end
  end )

end

-- Death gibs: the tank falls apart into pieces of himself (split of the
-- canon mesh by dominant bone, mannequin pipeline). Anchor bone = prop origin.
UKGuttertank.GIBS = {
  { model = "models/ultrakill_prelude_test/guttertank_gib_torso.mdl",  bone = "Spine" },
  { model = "models/ultrakill_prelude_test/guttertank_gib_pelvis.mdl", bone = "Hips" },
  { model = "models/ultrakill_prelude_test/guttertank_gib_arm_l.mdl",  bone = "Uppearm_L" },
  { model = "models/ultrakill_prelude_test/guttertank_gib_cannon.mdl", bone = "Cannon" },
  { model = "models/ultrakill_prelude_test/guttertank_gib_leg_l.mdl",  bone = "Leg_L" },
  { model = "models/ultrakill_prelude_test/guttertank_gib_leg_r.mdl",  bone = "Leg_R" },
}
