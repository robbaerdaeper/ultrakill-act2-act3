if SERVER then AddCSLuaFile() end

UKEarthmover = UKEarthmover or {}

local EM = UKEarthmover

EM.CATEGORY = "ULTRAKILL Test"

-- Project convention: 40 su per canon meter.
EM.UNIT = 40

EM.MODEL_GIANT     = "models/ultrakill_prelude_test/earthmover_giant.mdl"
EM.MODEL_MAINFRAME = "models/ultrakill_prelude_test/em_mainframe.mdl"
EM.MODEL_ROCKET    = "models/ultrakill_prelude_test/em_rocketlauncher.mdl"
EM.MODEL_MORTAR    = "models/ultrakill_prelude_test/em_mortar.mdl"
EM.MODEL_TOWER     = "models/ultrakill_prelude_test/em_seekertower.mdl"
EM.MODEL_BRAIN     = "models/ultrakill_prelude_test/em_brain.mdl"

-- Workshop pack convention: canon HP x 1000.
-- Canon (7-4 scene EnemyIdentifier dumps 2026-07-03): all Defense System
-- components health = 15, Brain health = 100.
EM.COMPONENT_HP = 15 * 1000
EM.BRAIN_HP = 100 * 1000
-- Сам Earthmover — не канон-боевая единица (в 7-4 неуязвим); даём массивный пул.
EM.GIANT_HP = 1000 * 1000

-- Player-scale damage numbers (canon files / wiki):
EM.ROCKET_DAMAGE = 35          -- wiki (RocketEnemy Grenade explosion)
EM.MORTAR_DAMAGE = 60          -- 'Projectile Explosive HH' damage 60
EM.SEEKER_DAMAGE = 30          -- 'Projectile Homing' damage 30
EM.BEAM_DAMAGE = 15            -- Mainframe 'Mindflayer Beam' ContinuousBeam 15
EM.BRAIN_ORB_DAMAGE = 30       -- giant 'Projectile Homing' damage 30 (вики: 40)
EM.FORCEFIELD_DAMAGE = 10      -- wiki: brain forcefield contact
EM.STOMP_DAMAGE = 200          -- giant: под ногой/тушей — не канон, здравый смысл

-- Speeds (canon m/s -> su/s):
EM.ROCKET_SPEED = 150 * EM.UNIT      -- Grenade rocketSpeed 150
EM.MORTAR_FORCE = 55 * EM.UNIT       -- MortarLauncher projectileForce 55
EM.MORTAR_TURN = 25                  -- Projectile turnSpeed 25 (horizontal homing)
EM.SEEKER_SPEED = 30 * EM.UNIT       -- медленный хоминг (канон-кап ~65 u/s)
EM.BRAIN_ORB_SPEED = 15 * EM.UNIT    -- гигант медленный («easy to counter»)

-- Firing cycles (canon MortarLauncher fields):
EM.MORTAR_DELAY = 7.0
EM.MORTAR_FIRST = 2.0
EM.TOWER_DELAY = 6.0
EM.TOWER_FIRST = 2.0
EM.TOWER_CHARGE = 1.0                -- зелёный чардж на кончике перед выстрелом
EM.BRAIN_ORB_DELAY = 3.0             -- HomingProjectileSpawner firingDelay 3

-- Rocket launcher (canon DroneFlesh):
EM.RL_COOLDOWN_FIRST = { 2.0, 3.0 }  -- Random(2,3)
EM.RL_COOLDOWN = { 1.0, 3.0 }        -- Random(1,3)
EM.RL_WARNING = 0.5                  -- warning beam -> shot (standard diff)
EM.RL_PREDICTION = 0.5               -- LookAt PredictTargetPosition(0.5)

-- Mainframe beam tracking (canon AlwaysLookAtCamera speed 1.0, easeIn):
EM.BEAM_TRACK_SPEED = 30             -- deg/s поворота луча к цели
EM.BEAM_RANGE = 300 * EM.UNIT
EM.BEAM_TICK = 0.5                   -- контакт-кулдаун урона на цель
EM.MAINFRAME_EYE_Z = 12.5 * EM.UNIT  -- глаз-сфера над origin (origin у основания)

-- Brain:
EM.BRAIN_ORB_AT_HP = 0.5             -- StartHalfway (normal); AlwaysFire = convar
EM.FORCEFIELD_RADIUS_MULT = 1.25     -- радиус поля от OBB
EM.FORCEFIELD_KNOCKBACK = 25 * EM.UNIT
EM.BRAIN_IDOL_DELAY = 45             -- затяжка боя до призыва Idol, сек
EM.BRAIN_IDOL_ARRIVE = 6             -- сек до полного хила (убей Idol раньше)
EM.REFLECT_MULT = 1.4                -- отражённые снаряды x1.4 по мозгу

-- Giant walker:
EM.GIANT_SPEED = 6 * EM.UNIT         -- канон-громада: медленный шаг (визуально)
EM.GIANT_WALK_LEN = 1.3              -- Walk клип 1.3 c
EM.GIANT_SCALE_DEFAULT = 1.0         -- модель скомпилирована в 1:8 канона

-- Defense System group phases (canon 7-4):
--   1) mainframe (в щите) + 2 ракетницы активны сразу
--   2) смерть 1-й ракетницы -> миномёты
--   3) смерть 2-й ракетницы ИЛИ миномёта -> сикер-башни
--   4) все 6 мертвы -> щит падает
EM.SET_RADIUS = 22 * EM.UNIT         -- расстановка сателлитов вокруг mainframe

-- Канон-клипы (дамп AudioSource 2026-07-03): MortarDeploy, MindflayerBeam,
-- AnimeSlash(Loop), saw, Door 2 Close, ElectricityContinuous3, PortalHeavy,
-- footstep_heavy1, CentaurFire/Alarm/Hurt/Spotted. Ракеты — канон RocketEnemy
-- клипы, уже извлечённые Johninator-портом (тот же префаб).
EM.SOUND = {
  RocketLoop   = "ultrakill_prelude_test/johninator/rocket_loop.wav",
  RocketFire   = "ultrakill_prelude_test/johninator/rocket_fire.wav",
  MortarFire   = "ultrakill_test/em_mortar_fire.wav",
  SeekerFire   = "ultrakill_test/em_seeker_fire.wav",
  SeekerLoop   = "ultrakill_test/em_seeker_loop.wav",
  Deploy       = "ultrakill_test/em_deploy.wav",
  BeamLoop     = "ultrakill_test/em_beam_loop.wav",
  ShieldDown   = "ultrakill_test/em_shield_down.wav",
  Spawn        = "ultrakill_test/em_spawn.wav",
  BrainOrb     = "ultrakill_test/em_brain_orb.wav",
  BrainDeath   = "ultrakill_test/em_giant_hurt.wav",
  Forcefield   = "ultrakill_test/em_forcefield.wav",
  GiantStep    = "ultrakill_test/em_giant_step.wav",
  GiantFire    = "ultrakill_test/em_giant_fire.wav",
  GiantAlarm   = "ultrakill_test/em_giant_alarm.wav",
  GiantHurt    = "ultrakill_test/em_giant_hurt.wav",
  GiantSpotted = "ultrakill_test/em_giant_spotted.wav",
}

-- Attacker-side damage scaling shared with the other test enemies.
function EM.ScaleAttackDamage( ent, damage )
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

-- Урон цели: игрок = player-scale, UK nextbot = x1000 (конвенция паков).
function EM.DealDamage( target, inflictor, attacker, damage, dmgtype, force )
  if not IsValid( target ) then return end
  local amount
  if target:IsPlayer() then
    amount = EM.ScaleAttackDamage( target, damage )
  elseif target.IsUltrakillNextbot then
    -- round-3 sweep 2026-07-10: the old x1000 without pre-division landed
    -- 200k-4M on pack NPCs — convention is canon x100 LANDED, pre-divided
    amount = UKNpcDmg.PreMult( target, attacker, damage * 100 )
  else
    amount = damage * 10
  end
  local dmg = DamageInfo()
  dmg:SetDamage( amount )
  dmg:SetDamageType( dmgtype or DMG_GENERIC )
  dmg:SetAttacker( IsValid( attacker ) and attacker or inflictor )
  dmg:SetInflictor( inflictor )
  dmg:SetDamagePosition( target:WorldSpaceCenter() )
  dmg:SetDamageForce( force or vector_origin )
  target:TakeDamageInfo( dmg )
end

function EM.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty or nil
  if d == nil and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( d or 3, 0, 5 )
end
