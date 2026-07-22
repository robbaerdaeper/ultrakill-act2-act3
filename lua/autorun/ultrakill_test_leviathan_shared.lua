if SERVER then AddCSLuaFile() end

-- Leviathan (5-4 "LEVIATHAN" boss, Supreme Demon).
-- Sources: LeviathanController.cs / LeviathanHead.cs / LeviathanTail.cs
-- decompile, level 5-4 scene dump (leviathan_probe.py), clip events from the
-- AssetRipper .anim exports (leviathan_events.json).
-- Brief: docs/leviathan_port_brief.md

UKLeviathan = UKLeviathan or {}

UKLeviathan.CATEGORY = "ULTRAKILL Test"

UKLeviathan.MODEL = "models/ultrakill_prelude_test/leviathan.mdl"

-- Workshop pack convention: canon HP x1000 (BossHealthBar: 2 layers of 120).
UKLeviathan.HP = 240 * 1000
UKLeviathan.HP_LAYERS = { 120 * 1000, 120 * 1000 }

-- canon LeviathanController: tailAddHealth 180 / phaseChangeHealth 120 (of 240)
UKLeviathan.TAILADD_FRAC = 180 / 240
UKLeviathan.PHASE2_FRAC = 120 / 240   -- informational: the 50% flip rides the
                                      -- base phase system (OnPhaseChange)

-- TRUE canon metre = 40 su; the mdl is compiled 1:1 ($scale 40). The boss is
-- colossal (head bone ~84 m over the waterline), so the sandbox default is
-- half size — flip the convar to 1 for the true canon experience.
UKLeviathan.UNIT = 40

CreateConVar( "ukleviathan_scale", "0.5",
  FCVAR_ARCHIVE + FCVAR_REPLICATED,
  "Leviathan model/arena scale (1 = canon 1:1, huge)", 0.1, 1 )

CreateConVar( "ukleviathan_orbspeed", "0.5",
  FCVAR_ARCHIVE + FCVAR_REPLICATED,
  "Leviathan barrage projectile speed multiplier", 0.1, 2 )

CreateConVar( "ukleviathan_debug", "0", FCVAR_ARCHIVE,
  "Draw Leviathan strike zones (bite sweep, tail whip polyline)" )

-- Visible body arc from the compiled skeleton (entity-local metres): x = behind
-- the face along +forward, z = above the origin/waterline. AABB slices for the
-- static colliders; the head/heart region (z > 62) stays box-free so shots
-- reach the weak-point hitboxes directly.
UKLeviathan.BODY_ARC = {
  { x0 = -4,  x1 = 24,  z0 = 0,  z1 = 18 },  -- neck rise at the waterline
  { x0 = 12,  x1 = 44,  z0 = 18, z1 = 44 },  -- neck mid
  { x0 = 18,  x1 = 48,  z0 = 44, z1 = 62 },  -- neck upper
  { x0 = 134, x1 = 174, z0 = 0,  z1 = 36 },  -- back hump rise
  { x0 = 167, x1 = 226, z0 = 28, z1 = 59 },  -- hump top (walk under it)
  { x0 = 214, x1 = 275, z0 = 0,  z1 = 38 },  -- hump fall
}
UKLeviathan.BODY_ARC_HALFY = 13              -- body tube half-width, m

-- canon head spawn positions around the anchor (unity local x,z; y=0=water)
UKLeviathan.HEAD_SPOTS = {
  { 0, 55 }, { 0, -55 }, { 25, 40 }, { 25, -40 }, { -25, 40 }, { -25, -40 },
}
UKLeviathan.HEAD_CENTER = { 0, 75 }   -- phase-2 centerSpawnPosition
-- canon tail spawn positions (phase 1) and second-phase ring positions
UKLeviathan.TAIL_SPOTS = { { 55, 0 }, { -55, 0 }, { 0, 55 }, { 0, -55 } }
UKLeviathan.TAIL_SPOTS2 = { { 100, 75 }, { -100, 75 }, { 0, 175 }, { 0, -25 } }
UKLeviathan.TAIL_SPOT2_Y = 5          -- second positions ride 5 m higher

-- attacks (canon SwingCheck2 / projectile data)
UKLeviathan.BITE_DAMAGE = 35          -- parryable, "+ DOWN TO SIZE"
UKLeviathan.BITE_RANGE = 50           -- m (2D): closer than this forces Bite
-- r4: damage follows the SAMPLED animation path (ultrakill_test_leviathan_
-- strikes.lua) — the head sweeps the ground from ~54 m behind to ~97 m in
-- front. Radius = head flesh half-thickness around the animated head bone.
UKLeviathan.BITE_RADIUS = 12
UKLeviathan.PARRY_SELF_DAMAGE = 20 * 1000  -- canon GotParried GetHurt(20)
UKLeviathan.TAIL_DAMAGE = 35          -- NOT parryable
-- r4: damage follows the SAMPLED TailWhip chain polyline (strikes.lua); only
-- what the visible whip actually passes through gets hit. Reach = seek radius
-- around the tail (the whip tip rises ~103 arena-m on the 0.75 tail).
UKLeviathan.TAIL_REACH = 115          -- arena m: candidate search radius
UKLeviathan.TAIL_RADIUS_M = 10        -- model m: whip tube half-thickness
UKLeviathan.BEAM_DAMAGE = 35          -- NOT parryable
UKLeviathan.BEAM_RANGE = 250          -- m
UKLeviathan.ORB_DAMAGE = 25           -- Hell Orb
UKLeviathan.ORB_EXPLOSIVE_DAMAGE = 20 -- Energy Orb (explosion, 13 falloff)
UKLeviathan.ORB_SPEED = 65            -- m/s @ Standard (wiki: 32.5/48.75/87.75)
UKLeviathan.KNOCKBACK = 500

UKLeviathan.SOUND = {
  Roar            = "ultrakill_prelude_test/leviathan/roar.wav",
  RoarLoop        = "ultrakill_prelude_test/leviathan/roar_loop.wav",
  HeartLoop       = "ultrakill_prelude_test/leviathan/heart_loop.wav",
  WindupProjectile = "ultrakill_prelude_test/leviathan/windup_projectile.wav",
  WindupBeam      = "ultrakill_prelude_test/leviathan/windup_beam.wav",
  WindupBite      = "ultrakill_prelude_test/leviathan/windup_bite.wav",
  WindupDescend   = "ultrakill_prelude_test/leviathan/windup_descend.wav",
  Hurt            = "ultrakill_prelude_test/leviathan/hurt.wav",
  Swing           = "ultrakill_prelude_test/leviathan/swing.wav",
  SwingTail       = "ultrakill_prelude_test/leviathan/swing_tail.wav",
  TailSpawn       = "ultrakill_prelude_test/leviathan/tail_spawn.wav",
  TailSpawn2      = "ultrakill_prelude_test/leviathan/tail_spawn2.wav",
  TailHigh        = "ultrakill_prelude_test/leviathan/tail_high.wav",
  TailLow         = "ultrakill_prelude_test/leviathan/tail_low.wav",
  Splash          = "ultrakill_prelude_test/leviathan/splash.wav",
  SplashBig       = "ultrakill_prelude_test/leviathan/splash_big.wav",
  BeamCharge      = "ultrakill_prelude_test/leviathan/beam_charge.wav",
  BeamLoop        = "ultrakill_prelude_test/leviathan/beam_loop.wav",
  BeamExplosion   = "ultrakill_prelude_test/leviathan/beam_explosion.wav",
}

UKLeviathan.CLASS = {
  Head = "ultrakill_test_leviathan",
  Tail = "ultrakill_test_leviathan_tail",
  Body = "ultrakill_test_leviathan_body",
  -- barrage rides the familiar workshop projectiles (required deps): red Hell
  -- Orb from the prelude Stray, yellow explosive mortar from act1 Hideous Mass
  OrbRed    = "ultrakill_stray_projectile",
  OrbYellow = "ultrakill_hideousmass_mortar_projectile",
  Orb  = "ultrakill_test_leviathan_proj",  -- fallback if the deps are missing
  Collider = "ultrakill_test_leviathan_collider",
}

function UKLeviathan.GetScale()
  local cv = GetConVar( "ukleviathan_scale" )
  return math.Clamp( cv and cv:GetFloat() or 0.5, 0.1, 1 )
end

function UKLeviathan.OrbSpeedMult()
  local cv = GetConVar( "ukleviathan_orbspeed" )
  return math.Clamp( cv and cv:GetFloat() or 0.5, 0.1, 2 )
end

-- Base difficulty convar (drg_ultrakill_difficulty) — sentry/mannequin pattern.
function UKLeviathan.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

function UKLeviathan.ScaleAttackDamage( ent, damage )
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

-- canon head/tail anim speed tables
function UKLeviathan.HeadAnimSpeed( d )
  if d == 0 then return 0.65 end
  if d == 1 then return 0.8 end
  if d == 2 then return 0.9 end
  if d == 3 then return 1.0 end
  return 1.25
end

function UKLeviathan.TailAnimSpeed( d )
  if d == 5 then return 2.0 end
  if d == 4 then return 1.5 end
  if d == 2 then return 0.85 end
  if d == 1 then return 0.65 end
  if d == 0 then return 0.45 end
  return 1.0
end

-- wiki projectile speed table: 32.5 / 48.75 / 65 / 87.75 m/s
function UKLeviathan.OrbSpeed( d )
  local s = UKLeviathan.ORB_SPEED
  if d == 0 then return s * 0.5 end
  if d == 1 then return s * 0.75 end
  if d >= 4 then return s * 1.35 end
  return s
end
