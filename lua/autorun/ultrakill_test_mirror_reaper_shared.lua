if SERVER then AddCSLuaFile() end

UKMirrorReaper = UKMirrorReaper or {}

UKMirrorReaper.MODEL = "models/ultrakill_prelude_test/mirror_reaper.mdl"
UKMirrorReaper.HAND_MODEL = "models/ultrakill_prelude_test/mirror_reaper_hand.mdl"
UKMirrorReaper.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000.
-- Cyber Grind / phase 1: 70 HP. 8-2 boss: 120 (70 + 50 mirror phase) — boss
-- variant is the level-2 entity (mirror phase).
UKMirrorReaper.HP_REGULAR = 70000
UKMirrorReaper.HP_BOSS_PHASE2 = 50000

-- Canon scale: 40 su per canon meter.
UKMirrorReaper.UNIT = 40
-- House half-size: the full canon reaper (~7 m tall) is unplayably huge on
-- GMod maps. Everything tied to model geometry (bounds, melee reach, spawn
-- offsets) multiplies by this; world speeds / teleport distances stay canon.
UKMirrorReaper.SCALE = 0.5
-- Canon MirrorReaper.speed = 5 m/s (NavMeshAgent capped by MoveSpeed logic).
UKMirrorReaper.MOVE_SPEED = 5 * UKMirrorReaper.UNIT
-- Canon SwingCheck2 damage: 30 (all three checks).
UKMirrorReaper.SWING_DAMAGE = 30
-- Canon GroundWave (Phantom Hand) HurtZone: setDamage 20, hurtCooldown 1.0,
-- enemyDamageOverride 5 (=> 5000 with the x1000 convention when parried into
-- enemies), Breakable durability 3, lifetime 15 s, agent speed 50 m/s.
UKMirrorReaper.HAND_DAMAGE = 20
UKMirrorReaper.HAND_ENEMY_DAMAGE = 5000
UKMirrorReaper.HAND_HP = 3000
UKMirrorReaper.HAND_LIFETIME = 15
UKMirrorReaper.HAND_SPEED = 50 * UKMirrorReaper.UNIT
-- Canon Acid Missile: direct 30, poison cloud 15 per tick, homing lost after 2 s.
UKMirrorReaper.ORB_DAMAGE = 30
UKMirrorReaper.CLOUD_DAMAGE = 15
UKMirrorReaper.CLOUD_RADIUS = 2.5 * UKMirrorReaper.UNIT
UKMirrorReaper.ORB_HOMING_TIME = 2.0

UKMirrorReaper.SOUND = {
  WindupTriple = "ultrakill_prelude_test/mirror_reaper/windup_triple.wav",
  WindupVertical = "ultrakill_prelude_test/mirror_reaper/windup_vertical.wav",
  WindupSpree = "ultrakill_prelude_test/mirror_reaper/windup_spree.wav",
  WindupProjectile = "ultrakill_prelude_test/mirror_reaper/windup_projectile.wav",
  WindupGroundwave = "ultrakill_prelude_test/mirror_reaper/windup_groundwave.wav",
  Teleport = "ultrakill_prelude_test/mirror_reaper/teleport.wav",
  TeleportReverse = "ultrakill_prelude_test/mirror_reaper/teleport_reverse.wav",
  Movement = {
    "ultrakill_prelude_test/mirror_reaper/movement1.wav",
    "ultrakill_prelude_test/mirror_reaper/movement2.wav",
    "ultrakill_prelude_test/mirror_reaper/movement3.wav",
    "ultrakill_prelude_test/mirror_reaper/movement4.wav",
  },
  Death = "ultrakill_prelude_test/mirror_reaper/death.wav",
  Scream = "ultrakill_prelude_test/mirror_reaper/scream.wav",
  -- canon: FerrymanSwing1 played at pitch 2.0 by the SwingCheck AudioSources
  SwingWhoosh = "ultrakill_prelude_test/mirror_reaper/swing_whoosh.wav",
  SwingImpact = "ultrakill_prelude_test/mirror_reaper/swing_impact.wav",
  GroundwaveLoop = "ultrakill_prelude_test/mirror_reaper/groundwave_loop.wav",
  Breathing = "ultrakill_prelude_test/mirror_reaper/breathing.wav",
  HandBreak = "ultrakill_prelude_test/mirror_reaper/hand_break.wav",
}

UKMirrorReaper.CLASS = {
  Regular = "ultrakill_test_mirror_reaper",
  Hand = "ultrakill_test_mirror_reaper_hand",
  Orb = "ultrakill_test_mirror_reaper_orb",
}

-- Attacker-side damage scaling shared with the other test enemies.
-- Round-3 sweep 2026-07-10: player = FLAT canon (plytakedmgmult 0.1 cut hits
-- to 10%); pack-NPC = convention target canon x100 LANDED, pre-divided by the
-- victim's own multiplier. Callers pass CANON player-scale numbers.
function UKMirrorReaper.ScaleAttackDamage( ent, damage, attacker )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then
    return UKNpcDmg.PreMult( ent, attacker, damage * 100 )
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end
