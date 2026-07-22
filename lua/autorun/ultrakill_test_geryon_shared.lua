-- lua/autorun/ultrakill_test_geryon_shared.lua
-- Geryon (Supreme Demon, Layer 8: Fraud) — shared config.
-- Canon source: decompiled Geryon class + level8-4 scene dump
-- All timings are the raw animation-event times
-- of the 30 fps clips; the boss divides them by its anim speed.

if SERVER then AddCSLuaFile() end

UKGeryon = UKGeryon or {}

UKGeryon.MODEL = "models/ultrakill_prelude_test/geryon.mdl"
UKGeryon.CATEGORY = "ULTRAKILL Test"
UKGeryon.BOSS_TITLE = "GERYON, WATCHER OF THE SKIES"

-- Workshop pack convention: canon HP x 1000. Canon Geryon: 180 (2 layers x 90).
UKGeryon.HP = 180000
UKGeryon.BOSS_SPLITS = 2

-- 25 su per canon metre (Layer 8 family: Providence/Virtue). Enemy-root units
-- are metres; Geryon_Rig 1.75 / Armature 100 are baked into the .mdl.
UKGeryon.UNIT = 25

UKGeryon.MAGENTA = Color( 255, 0, 115 )
UKGeryon.GREEN = Color( 90, 255, 60 )
UKGeryon.ORANGE = Color( 255, 150, 40 )
UKGeryon.BLUE = Color( 80, 160, 255 )

-- ---- difficulty (canon UpdateDifficulty) ------------------------------------
-- 0 HARMLESS, 1 LENIENT, 2 STANDARD, 3 VIOLENT, 4/5 BRUTAL/UKMD.
UKGeryon.ANIM_SPEED = { [0] = 0.7, [1] = 0.8, [2] = 0.9, [3] = 1.0, [4] = 1.2, [5] = 1.2 }
UKGeryon.MAX_HEAT = { [0] = 3, [1] = 4, [2] = 5, [3] = 6, [4] = 9, [5] = 9 }
UKGeryon.STUN_TIME = { [0] = 9, [1] = 9, [2] = 7, [3] = 6, [4] = 5, [5] = 5 }
UKGeryon.PHASE2_ANIM_MULT = 1.25    -- canon: anim.speed *= 1.25 in phase 2
UKGeryon.PHASE2_EXTRA_HEAT = 1      -- canon: maximumHeat + 1 in phase 2
UKGeryon.PHASE2_STUN_DRAIN = 1.5    -- canon: stun timer drains 1.5x faster
UKGeryon.HEAT_PER_ATTACK = 1.01

-- ---- movement (canon MoveUpdate) --------------------------------------------
-- canon: orbits rotateAround at random(10,60) m; sandbox has no arena centre,
-- so Geryon orbits its TARGET instead. moveSpeed 20 m/s, yaw chase 8x angle/s.
UKGeryon.ORBIT_MIN = 10 * UKGeryon.UNIT
UKGeryon.ORBIT_MAX = 60 * UKGeryon.UNIT
UKGeryon.MOVE_SPEED = 20 * UKGeryon.UNIT
UKGeryon.START_COOLDOWN = 3.0       -- canon: cooldown = 3 on spawn
UKGeryon.BOWUP_COOLDOWN = 2.0       -- canon: only BowUp sets a cooldown

-- ---- PlayerBlocker / Green Explosion (canon PlayerBlocker) ------------------
UKGeryon.SHIELD_FWD = 4 * UKGeryon.UNIT       -- shield sits 4 m ahead, y-1.25
UKGeryon.BLOCKER_RANGE = 22 * UKGeryon.UNIT   -- trigger distance
UKGeryon.BLOCKER_CD = 3.0
UKGeryon.SHIELD_TOUCH_DAMAGE = 10             -- HurtZone setDamage 10 (contact)
UKGeryon.SHIELD_TOUCH_CD = 1.0
UKGeryon.SHIELD_BOUNCE = 350
UKGeryon.GREEN_DAMAGE = 30                    -- Explosion damage 30 (asset)
UKGeryon.GREEN_MAX_R = 30 * UKGeryon.UNIT     -- maxSize 30 m
UKGeryon.GREEN_GROW_TIME = 1.4                -- slow expanding cloud
UKGeryon.GREEN_PUSH = 900                     -- 'high knockback'

-- ---- BowUp / Orange Bombardment ---------------------------------------------
UKGeryon.BOWUP_BEAMS = 5                      -- canon beamsAmount = 5
UKGeryon.BOWUP_SPAWN_DELAY = 1.0              -- Invoke("BowUpSpawnBeams", 1)
UKGeryon.BOWUP_BEAM_GAP = 0.25                -- WaitForSecondsRealtime(0.25)
UKGeryon.BOWUP_SPREAD = 60 * UKGeryon.UNIT    -- random ring = maximumAroundDistance

-- ---- BowForward / Blue Beams --------------------------------------------------
UKGeryon.BOWFWD_FAN_DEG = 30                  -- fan +-30 deg
UKGeryon.BOWFWD_BRUTAL_EXTRA = 2              -- difficulty>=4: shots+2 (3/4/5)
UKGeryon.BOWFWD_SPEED = 12 * UKGeryon.UNIT    -- forward beam drift (ConstantForce)

-- ---- beams (GeryonUp/ForwardArrowBeam) ----------------------------------------
UKGeryon.PILLAR_DAMAGE = 30                   -- HurtZone setDamage 30
UKGeryon.PILLAR_TICK = 1.0                    -- hurtCooldown 1 s
UKGeryon.PILLAR_TELEGRAPH = 1.0               -- warning sigil before it fires
UKGeryon.PILLAR_LIFE = 3.0                    -- active beam lifetime (shrinks out)
UKGeryon.PILLAR_R_UP = 2.0 * UKGeryon.UNIT    -- orange pillar hurt radius
UKGeryon.PILLAR_R_FWD = 1.5 * UKGeryon.UNIT   -- blue pillar hurt radius
UKGeryon.PILLAR_HEIGHT = 800 * UKGeryon.UNIT  -- canon capsule y-scale 800 (sky)
UKGeryon.PILLAR_FWD_LIFE = 5.0

-- ---- WaveClap / Magenta Shockwaves --------------------------------------------
UKGeryon.CLAP_WAVES = 3
UKGeryon.CLAP_SPEED = 50 * UKGeryon.UNIT      -- speed 50/(j+1): 50, 25, 16.7 m/s
UKGeryon.CLAP_MAX_R = 100 * UKGeryon.UNIT     -- PhysicalShockwave maxSize 100
UKGeryon.CLAP_DAMAGE = 25
UKGeryon.CLAP_HEIGHT = 60 * UKGeryon.UNIT     -- wall height (scale y 60)
UKGeryon.CLAP_Y_OFFSET = 20 * UKGeryon.UNIT   -- waves at 0 / +20 / -20 m
UKGeryon.CLAP_PUSH = 1200                     -- force 10000: hurls into walls

-- ---- PalmProjectiles / Magenta Cross ------------------------------------------
UKGeryon.CROSS_SPEED = 40 * UKGeryon.UNIT     -- Projectile Providence Geryon speed 40
UKGeryon.CROSS_DAMAGE = 25
UKGeryon.CROSS_LIFETIME = 6
UKGeryon.CROSS_BEAM_DAMAGE = 20               -- cross beams (Providence values)
UKGeryon.CROSS_BEAM_RANGE = 4096
UKGeryon.CROSS_BEAM_RADIUS = 13
UKGeryon.CROSS_STEP_DEG = 15                  -- each single shot +15 deg
UKGeryon.CROSS_BOTH_SPEED_MULT = 0.5          -- final pair at half speed
UKGeryon.CROSS_BOTH_SPIN = 45                 -- deg/s spin of the final pair
UKGeryon.CROSS_VIOLENT_SPEED = 1.5            -- difficulty>=3 projectile speed x1.5
UKGeryon.PARRY_DMG_MULT = 1.0                 -- canon: parry the cross back = big damage

-- ---- stun / weak point ---------------------------------------------------------
UKGeryon.STUN_DOT = 2                         -- canon DoT 2 hp/s while stunned
UKGeryon.STUN_DMG_TAKEN = 0.66                -- totalDamageTakenMultiplier in stun
UKGeryon.WEAKPOINT_MULT = 2.0                 -- wiki: head 200% (open in stun)
UKGeryon.RECOVER_PUSH = 1200                  -- UnstunClose player push-backer

-- ---- animation clips (30 fps bake, geryon_events.json) --------------------------
-- t* are raw clip times; divide by the current anim speed at runtime.
UKGeryon.CLIP = {
  BowUp = { seq = "BowUp", len = 3.2,
    events = { { 0.373, "BowCharge" }, { 1.221, "BowUpShoot" },
               { 2.415, "SkipRecovery" }, { 3.122, "EndAction" } } },
  BowForward = { seq = "BowForward", len = 6.4,
    events = { { 0.767, "BowCharge" }, { 1.413, "BowForwardShoot", 1 },
               { 2.808, "BowForwardShoot", 2 }, { 4.203, "BowForwardShoot", 3 },
               { 4.831, "SkipRecovery" }, { 5.022, "DustHands" },
               { 5.598, "DustHands" }, { 6.278, "EndAction" } } },
  WaveClap = { seq = "WaveClap", len = 3.2,
    events = { { 0.593, "WaveClapCharge" }, { 1.212, "WaveClapChargeFreeze" },
               { 1.918, "WaveClapShoot" }, { 2.677, "SkipRecovery" },
               { 3.095, "EndAction" } } },
  PalmProjectiles = { seq = "PalmProjectiles", len = 4.8,
    events = { { 0.628, "PalmProjectileCharge" },
               { 1.923, "PalmProjectileShoot", 1 }, { 2.106, "PalmProjectileShoot", 0 },
               { 2.315, "PalmProjectileShoot", 1 }, { 2.511, "PalmProjectileShoot", 0 },
               { 2.72, "PalmProjectileShoot", 1 }, { 2.917, "PalmProjectileShoot", 0 },
               { 3.584, "PalmProjectileShootBoth" }, { 4.211, "SkipRecovery" },
               { 4.656, "EndAction" } } },
  StunStart = { seq = "StunStart", len = 2.4,
    events = { { 1.543, "HeadOpen" } } },
  StunStop = { seq = "StunStop", len = 1.2,
    events = { { 0.203, "UnstunClose" }, { 1.118, "StopAction" } } },
  Death = { seq = "Death", len = 3.6, events = {} },
}

UKGeryon.SOUND = {
  Spawn      = "ultrakill_prelude_test/geryon/spawn.wav",
  BowUp      = "ultrakill_prelude_test/geryon/windup1.wav",   -- canon bowUpSound
  BowForward = "ultrakill_prelude_test/geryon/windup2.wav",   -- canon bowForwardSound
  WaveClap   = "ultrakill_prelude_test/geryon/windup8.wav",   -- canon waveClapSound
  Palm       = "ultrakill_prelude_test/geryon/windup7.wav",   -- canon palmProjectilesSound
  Recovery   = "ultrakill_prelude_test/geryon/windup4.wav",   -- canon recoverySound
  BigHurt    = "ultrakill_prelude_test/geryon/bighurt.wav",   -- canon bigHurtSound (stun)
  Death      = "ultrakill_prelude_test/geryon/death.wav",
  Clap       = "ultrakill_prelude_test/geryon/clap.wav",
  ArrowLong  = "ultrakill_prelude_test/geryon/arrow_long.wav",
  ArrowShort = "ultrakill_prelude_test/geryon/arrow_short.wav",
  Beam       = "ultrakill_prelude_test/geryon/beam.wav",
  BeamLoud   = "ultrakill_prelude_test/geryon/beam_loud.wav",
  Laugh      = "ultrakill_prelude_test/geryon/laugh.wav",
}

UKGeryon.CLASS = {
  Regular = "ultrakill_test_geryon",
  Cross = "ultrakill_test_geryon_cross",
  Pillar = "ultrakill_test_geryon_pillar",
  Wave = "ultrakill_test_geryon_wave",
}

-- Difficulty + attacker-side damage scaling — shared pack conventions
-- (identical to the Providence/Sentry helpers).
function UKGeryon.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

-- Round-3 sweep 2026-07-10: player = FLAT canon (plytakedmgmult 0.1 cut hits
-- to 10%); pack-NPC = convention target canon x100 LANDED pre-divided (the old
-- `x1000 for IsUltrakillNextbot OR IsDrGNextbot` landed 400-600k and also
-- one-shotted foreign DrGBase nextbots without pack-scale HP).
function UKGeryon.ScaleAttackDamage( ent, damage, attacker )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then
    return UKNpcDmg.PreMult( ent, attacker, damage * 100 )
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

if SERVER then

  -- Segment damage helper (Providence pattern) with per-inflictor hit cooldowns.
  function UKGeryon.DamageBeamSegment( owner, inflictor, from, dir, length, radius,
                                       damage, hitNPC, hitCD, tick )
    tick = tick or 0.4
    local tr = util.TraceLine( {
      start = from, endpos = from + dir * length,
      mask = MASK_SOLID_BRUSHONLY, filter = inflictor,
    } )
    local endpos = tr.HitPos
    local seg = endpos - from
    local seglen = seg:Length()
    if seglen < 1 then return endpos end
    local segdir = seg / seglen

    for _, ent in ipairs( ents.FindInBox(
      Vector( math.min( from.x, endpos.x ) - radius, math.min( from.y, endpos.y ) - radius, math.min( from.z, endpos.z ) - radius ),
      Vector( math.max( from.x, endpos.x ) + radius, math.max( from.y, endpos.y ) + radius, math.max( from.z, endpos.z ) + radius ) ) ) do
      if not IsValid( ent ) or ent == inflictor or ent == owner then continue end
      local isPlayer = ent:IsPlayer()
      if isPlayer and not ent:Alive() then continue end
      if not isPlayer then
        if not hitNPC then continue end
        if not ( ent:IsNPC() or ent:IsNextBot() ) then continue end
        -- canon safeEnemyType 42: never hurt Geryon itself
        if ent:GetClass() == UKGeryon.CLASS.Regular then continue end
      end
      if hitCD[ ent ] and hitCD[ ent ] > CurTime() then continue end

      local p = ent:WorldSpaceCenter()
      local t = math.Clamp( ( p - from ):Dot( segdir ), 0, seglen )
      local closest = from + segdir * t
      local hitR = radius + ent:BoundingRadius() * 0.5
      if p:DistToSqr( closest ) > hitR * hitR then continue end

      hitCD[ ent ] = CurTime() + tick
      local dmg = DamageInfo()
      dmg:SetDamage( UKGeryon.ScaleAttackDamage( ent, damage, owner ) )
      dmg:SetDamageType( DMG_ENERGYBEAM )
      dmg:SetAttacker( IsValid( owner ) and owner or inflictor )
      dmg:SetInflictor( IsValid( inflictor ) and inflictor or owner )
      dmg:SetDamagePosition( closest )
      dmg:SetDamageForce( vector_origin )
      ent:TakeDamageInfo( dmg )
    end
    return endpos
  end

end
