if SERVER then AddCSLuaFile() end

UKMannequin = UKMannequin or {}

UKMannequin.MODEL = "models/ultrakill_prelude_test/mannequin.mdl"
UKMannequin.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Mannequin: 6 HP (Lesser Demon).
UKMannequin.HP = 6000

-- 19 su per canon meter => model ~115 su (100 su + 15%).
-- Size history: 40 -> 20 -> 13 -> 10 -> 12.5 -> 16.5 -> 19; early shrink
-- rounds were judged against a CACHED .mdl (GMod only reloads models on game
-- restart). Scales canon-meter DISTANCES (melee ~95 su, cling probes, ceiling
-- scan); movement speeds are decoupled below.
UKMannequin.UNIT = 19

-- Canon SetSpeed (Mannequin.cs): walk/skitter m/s + anim speed per difficulty
-- (0 HARMLESS, 1 LENIENT, 2 STANDARD, 3 VIOLENT, 4/5 BRUTAL/UKMD).
-- Movement speeds are decoupled from UNIT (tuned 2026-07-03): two-legged walk
-- keeps the tested feel (m/s x 20 su), the all-fours skitter is FAST
-- (m/s x 26.5 su -> 1700 su/s on VIOLENT).
local WALK_SU = 20
local SKITTER_SU = 26.5
UKMannequin.SPEED_PROFILE = {
  [0] = { anim = 0.75, walk = 10 * WALK_SU, skitter = 32 * SKITTER_SU },
  [1] = { anim = 0.85, walk = 12 * WALK_SU, skitter = 48 * SKITTER_SU },
  [2] = { anim = 1.00, walk = 16 * WALK_SU, skitter = 64 * SKITTER_SU },
  [3] = { anim = 1.00, walk = 16 * WALK_SU, skitter = 64 * SKITTER_SU },
  [4] = { anim = 1.25, walk = 20 * WALK_SU, skitter = 64 * SKITTER_SU },
  [5] = { anim = 1.25, walk = 20 * WALK_SU, skitter = 64 * SKITTER_SU },
}

-- Canon SwingCheck2: damage 30 (player units, matches wiki), enemyDamage 2.
UKMannequin.MELEE_DAMAGE_PLAYER = 30
UKMannequin.MELEE_DAMAGE_NPC = 2 * 1000 -- target LANDED value (canon enemyDamage 2 x HP-scale); fed via UKNpcDmg.PreMult
-- Canon melee trigger: Vector3.Distance < 5 m; SwingCheck box (3,6,4) m at 1.75 m fwd.
UKMannequin.MELEE_RANGE = 5 * UKMannequin.UNIT
UKMannequin.MELEE_HIT_RADIUS = 3 * UKMannequin.UNIT
-- Canon MeleeAttack(): meleeCooldown = 2 s (the 0.5 field initializer is overwritten).
UKMannequin.MELEE_COOLDOWN = 2.0
-- Canon FixedUpdate moveForward dash: rb.velocity = forward * 55 * anim.speed.
UKMannequin.MELEE_DASH_SPEED = 55 * UKMannequin.UNIT

-- Canon "Projectile Homing" -> the ready-made blue hell seeker from the act1
-- dep (ultrakill_mindflayer_projectile): same Sphere_16 + Ultrakill_HomingOrb
-- visuals, Gradual homing, base-handled damage/parry. Canon Mannequin tweak
-- applied at spawn: turningSpeedMultiplier 0.75 below VIOLENT, 1.0 otherwise.

UKMannequin.SOUND = {
  Breathing  = "ultrakill_prelude_test/mannequin/breathing.wav",   -- loop, head
  Skitter    = "ultrakill_prelude_test/mannequin/skitter.wav",     -- loop
  Swing      = "ultrakill_prelude_test/mannequin/swing.wav",       -- canon pitch 2 baked
  Cling      = "ultrakill_prelude_test/mannequin/cling.wav",       -- canon pitch 3 baked
  Spawn      = "ultrakill_prelude_test/mannequin/spawn.wav",       -- PortalHeavy
  ProjLoop   = "ultrakill_prelude_test/mannequin/proj_loop.wav",   -- canon pitch 1.8-2 baked 1.9
  ProjCharge = "ultrakill_prelude_test/mannequin/proj_charge.wav", -- loop
  ProjTwirl  = "ultrakill_prelude_test/mannequin/proj_twirl.wav",  -- canon pitch 3 baked
}

UKMannequin.CLASS = {
  Regular = "ultrakill_test_mannequin",
  Projectile = "ultrakill_mindflayer_projectile", -- act1 required dep
}

-- Gib piece models (compiled from the enemy mesh split by dominant bone) and
-- the bone each piece snaps to at death.
UKMannequin.GIBS = {
  { model = "models/ultrakill_prelude_test/mannequin_gib_head.mdl",   bone = "Head" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_torso.mdl",  bone = "Spine_03" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_pelvis.mdl", bone = "Spine_01" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_arm_l.mdl",  bone = "UpperArm_L" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_arm_r.mdl",  bone = "UpperArm_R" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_leg_l.mdl",  bone = "Thigh_L" },
  { model = "models/ultrakill_prelude_test/mannequin_gib_leg_r.mdl",  bone = "Thigh_R" },
}

-- Base difficulty convar (drg_ultrakill_difficulty, VIOLENT default) — sentry pattern.
function UKMannequin.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

-- Attacker-side damage scaling shared with the other test enemies (ferryman/sentry).
function UKMannequin.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    -- flat canon to the player (Sentry r3 policy, extended here 2026-07-10
    -- round 2: drg_ultrakill_plytakedmgmult defaults to 0.1 and quietly cut
    -- mannequin hits to 10% of the wiki numbers)
    return damage
  end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end
