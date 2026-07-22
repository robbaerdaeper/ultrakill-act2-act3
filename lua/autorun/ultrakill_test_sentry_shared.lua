if SERVER then AddCSLuaFile() end

UKSentry = UKSentry or {}

UKSentry.MODEL = "models/ultrakill_prelude_test/sentry.mdl"
UKSentry.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Sentry (EnemyIdentifier
-- dump 2026-07-03): health = 12. (The old brief's "30" was wrong.)
UKSentry.HP = 12000

-- Project convention: 40 su per canon meter.
UKSentry.UNIT = 40

-- Canon Turret.GetSpeed: speed 20, angularSpeed 1200 deg/s, accel 360.
-- Raw 20 m/s (800 su/s) plays absurdly fast in GMod (in-game test 2026-07-03);
-- since the Turret only walks when it has NO line of sight, 6 m/s reads canon.
UKSentry.MOVE_SPEED = 7 * UKSentry.UNIT -- round 2 2026-07-10: «скорость чуть выше» (was 6)
UKSentry.ANGULAR_SPEED = 1200

-- Canon RevolverBeam prefab ("Turret Beam"): damage 5.0 (enemy-HP units),
-- bulletForce 10000, hitAmount/maxHitsPerTarget 3, ignoreEnemyType Turret.
-- Player numbers are FLAT canon wiki values (50/40) — decision
-- 2026-07-07: no raw x10 / plytakedmgmult games, the player just takes canon.
UKSentry.BEAM_DAMAGE_PLAYER = 50
UKSentry.BEAM_DAMAGE_NPC = 5 * 1000
UKSentry.BEAM_PIERCE = 3
UKSentry.BEAM_RANGE = 250 * UKSentry.UNIT

-- Spec 2026-07-07: at the end of the aim the bot freezes with a bright
-- yellow muzzle flash for ~0.5 s (parry window), then fires.
UKSentry.FLASH_HOLD = 0.5

-- Spec 2026-07-07: freshly spawned Sentries walk for a couple of
-- seconds before the first burrow+aim (ignores the stand-when-seen gate).
UKSentry.SPAWN_WANDER = 2.5

-- Canon SwingCheck2 (kick): damage 40 (player), enemyDamage 2, knockback 25 m/s,
-- strong (unparryable). Box (5,6,5) m centered 2 m ahead => sphere approx.
UKSentry.KICK_DAMAGE_PLAYER = 40
UKSentry.KICK_DAMAGE_NPC = 2 * 1000
UKSentry.KICK_KNOCKBACK = 25 * UKSentry.UNIT
UKSentry.KICK_RANGE = 5 * UKSentry.UNIT      -- trigger distance (canon < 5 m)
UKSentry.KICK_HIT_RADIUS = 3 * UKSentry.UNIT -- swing sphere radius
UKSentry.KICK_HIT_FORWARD = 2 * UKSentry.UNIT

-- Canon aim times per difficulty (Turret.cs Start), animator speed per diff.
UKSentry.AIM_TIME_BY_DIFF = { [0] = 7.5, [1] = 5.0, [2] = 5.0, [3] = 4.0, [4] = 3.0, [5] = 3.0 }
UKSentry.ANIM_SPEED_BY_DIFF = { [0] = 0.5, [1] = 0.75, [2] = 1.0, [3] = 1.0, [4] = 1.0, [5] = 1.0 }

-- Canon cooldowns: field init 2.0 (0.5 with quickStart), Shoot() rolls
-- Random(2.5, 3.5), CancelAim clamps >= 1.0, Interrupt sets 3.0.
UKSentry.COOLDOWN_INITIAL = 2.0
UKSentry.COOLDOWN_MIN = 2.5
UKSentry.COOLDOWN_MAX = 3.5
UKSentry.COOLDOWN_INTERRUPT = 3.0

-- Multi-shot: diff 4 => chains of 2, diff 5 => endless. Two real-time Invokes.
UKSentry.PRE_REAIM_DELAY = 0.25
UKSentry.REAIM_DELAY = 0.25

UKSentry.OUT_OF_SIGHT_CANCEL = 1.0
UKSentry.VISION_RANGE = 60 * UKSentry.UNIT

-- Canon laser colors: defaultColor pink, white pulse, orange warning.
UKSentry.LASER_PINK = Color( 255, 112, 188 )
UKSentry.LASER_WHITE = Color( 255, 255, 255 )
UKSentry.LASER_ORANGE = Color( 255, 191, 127 )

-- Audio kit (canon clips + canon FX-prefab pitches baked into the WAVs):
-- warning = TurretReady @1.5x, kick_warning = TurretCancel @1.5x,
-- extend = Drill @3x, thunk = LockOpen @3x, shoot = M1 Garand @0.5x,
-- beep = Beep_high, kick = whoosh @2x, rubble = boulder impact,
-- spawn = PortalHeavy @0.5x.
UKSentry.SOUND = {
  Ready       = "ultrakill_test/sentry_ready.wav",
  Cancel      = "ultrakill_test/sentry_cancel.wav",
  Death       = "ultrakill_test/sentry_death.wav",
  Hurt        = "ultrakill_test/sentry_hurt.wav",
  Interrupt   = "ultrakill_test/sentry_interrupt.wav",
  Step        = "ultrakill_test/sentry_step.wav",
  Warning     = "ultrakill_test/sentry_warning.wav",
  KickWarning = "ultrakill_test/sentry_kick_warning.wav",
  Extend      = "ultrakill_test/sentry_extend.wav",
  Thunk       = "ultrakill_test/sentry_thunk.wav",
  Shoot       = "ultrakill_test/sentry_shoot.wav",
  Beep        = "ultrakill_test/sentry_beep.wav",
  Kick        = "ultrakill_test/sentry_kick.wav",
  Rubble      = "ultrakill_test/sentry_rubble.wav",
  Spawn       = "ultrakill_test/sentry_spawn.wav",
  -- picked 2026-07-07 (Boulder_impact_on_stones_14): one play per foot
  -- lodging into the ground — the AimStart clip has two lodge events
  Lodge       = "ultrakill_test/sentry_lodge.wav",
}

-- Difficulty: reuse the base ecosystem convar (drg_ultrakill_difficulty,
-- HARMLESS..HIDDEN MANSION => 0..6). Canon Turret only knows 0..5.
function UKSentry.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty or nil
  if d == nil and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( d or 3, 0, 5 )
end

-- Attacker-side damage scaling. Players take FLAT canon damage (50 beam /
-- 40 kick) — drg_ultrakill_plytakedmgmult defaults to 0.1 and used to shrink
-- the beam to 5; decision 2026-07-07: Sentry ignores that convar.
function UKSentry.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end
