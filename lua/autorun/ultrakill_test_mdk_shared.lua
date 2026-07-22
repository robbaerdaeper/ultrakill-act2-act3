-- lua/autorun/ultrakill_test_mdk_shared.lua
-- Canon constants for the Mysterious Druid Knight (& Owl) port.
-- Refs: Mandalore.cs, MandaloreVoice.cs, Drone.cs, ProjectileSpread.cs,
-- gameprefab dump (mdk_probe_out.txt).

if SERVER then AddCSLuaFile() end

UKMDK = UKMDK or {}

UKMDK.MODEL = "models/ultrakill_prelude_test/mdk.mdl"
UKMDK.CATEGORY = "ULTRAKILL Test"
UKMDK.SCALE = 0.50   -- ModelScale босса и краш-сущности (по фидбеку юзера)

-- Canon scale: 40 su per canon meter.
UKMDK.UNIT = 40

-- Workshop pack convention: canon HP x 1000. Canon MDK: 80 (4 фазы по 20).
UKMDK.HP = 80000

-- Canon phase thresholds (Mandalore.cs Update): 3/4, 1/2, 1/4 of max HP.
UKMDK.PHASE2_FRAC = 0.75
UKMDK.PHASE3_FRAC = 0.5
UKMDK.PHASE4_FRAC = 0.25
-- Phase 4: eid.Sandify() запускается через 2.5 c после реплики.
UKMDK.SANDIFY_DELAY = 2.5

-- Canon Drone movement (ProcessTargeting, ветка EnemyType.Mandalore):
-- rb.velocity *= 0.95 каждый физтик; тяга 50 м/с² (Brutal+: 250) вдоль
-- forward когда дальше preferredDistanceToTarget=15 м; рывок-Impulse назад
-- когда < 5 м; между — дрейф с затуханием; клэмп скорости 50 м/с.
-- Эмуляция на флай-интеграторе базы (ApproachFlying/UpdateFlying):
-- терминальная скорость = DesiredSpeed, тяга = Acceleration,
-- затухание = Deceleration (линейная аппроксимация *0.95).
-- ПО ФИДБЕКУ ЮЗЕРА движение НЕ канонное (канонная погоня 20-50 м/с в GMod
-- чересчур): босс в основном ВИСИТ, перемещается рывками (вики: «moving
-- around by dashing spontaneously»), к цели лишь медленно дрейфует когда
-- дальше 15 м. Сложность влияет только на частоту рывков (DODGE_CD_SPEED).
UKMDK.PREFERRED_DIST = 15 * UKMDK.UNIT   -- 600 su
UKMDK.BACKOFF_DIST = 5 * UKMDK.UNIT      -- 200 su
UKMDK.BACKOFF_CD = 0.4
UKMDK.ACCEL = 1200                       -- su/s², мягкий разгон дрейфа
UKMDK.MOVE_SPEED = 450                   -- медленный дрейф к цели
UKMDK.DECEL = 2000                       -- su/s², затухание

-- Canon Dodge(): импульс Δv = 50 м/с в случайном up/right-направлении; от
-- стены (raycast 7 м) инвертируется. Кулдаун 1-3 c ТИКАЕТ со скоростью canon
-- GetCooldownSpeed (difficulty/2, оверрайды 0.5/0.75) — на брутале дэш каждые
-- ~0.4-1.5 c (вики: near-constant dashing). Исполнение: burst DODGE_TIME сек
-- через ApproachFlying на DODGE_SPEED с форс-ускорением (канонный Δv
-- мгновенный; одиночный loco-импульс интегратор базы перетирает в тот же тик).
UKMDK.DODGE_CD_MIN = 1.0
UKMDK.DODGE_CD_MAX = 3.0
UKMDK.DODGE_SPEED = 800                  -- резкий короткий сайд-хоп
UKMDK.DODGE_TIME = 0.15
UKMDK.DODGE_ACCEL = 12000                -- почти мгновенный разгон
UKMDK.DODGE_WALL_PROBE = 7 * UKMDK.UNIT  -- 280 su
-- canon RandomDodge: diff 0 — никогда, diff 1 — 75%, иначе всегда.
UKMDK.DODGE_DIFF_CHANCE = { [0]=0.0, [1]=0.75, [2]=1.0, [3]=1.0, [4]=1.0, [5]=1.0 }
UKMDK.DODGE_CD_SPEED = { [0]=0.5, [1]=0.75, [2]=1.0, [3]=1.5, [4]=2.0, [5]=2.5 }
-- «tending to evade player attacks with these same dashes»: шанс дэша при уроне.
UKMDK.EVADE_HURT_CHANCE = 0.45
UKMDK.EVADE_HURT_MIN_INTERVAL = 0.4

-- Canon attack loop (Mandalore.cs): cooldown старт 2 c; выбор атаки маятником
-- fullerChance (roll > fc -> Full Auto, fc=max(0.5,fc)+0.2; иначе Fuller Auto,
-- fc=min(0.5,fc)-0.2). Анонс-войс, атака через 1 c после него.
UKMDK.ATTACK_CD_INITIAL = 2.0
UKMDK.ATTACK_WINDUP = 1.0
-- Full Auto CD по фазам 1/2/3+ (Mandalore.cs).
UKMDK.FULL_CD = { [1]=4.0, [2]=3.25, [3]=2.5, [4]=2.5 }
-- Fuller Auto CD по остатку HP: >2/3 -> 4, >1/3 -> 3, иначе 2.
UKMDK.FULLER_CD_HIGH = 4.0
UKMDK.FULLER_CD_MID = 3.0
UKMDK.FULLER_CD_LOW = 2.0

-- Full Auto: 4 залпа с шагом 0.2 c; залп = 7 hell-орбов (центр + 6 по кольцу
-- с наклоном spreadAmount 10°). Орб = готовый ultrakill_stray_projectile
-- (dmg 250 в юнитах пака = канон 25, парри/рефлект встроены); наш только
-- канонный оверрайд скорости: Projectile.speed 250 м/с.
UKMDK.FULL_VOLLEYS = 4
UKMDK.FULL_VOLLEY_INTERVAL = 0.2
UKMDK.FULL_SPREAD_DEG = 10
UKMDK.FULL_RING = 6
UKMDK.ORB_SPEED = 250 * UKMDK.UNIT       -- 10000 su/s — канон, почти хитскан

-- Fuller Auto: 40 hell-seekers с шагом 0.02 c, спавн с рандомной ориентацией.
-- Сикер = готовый ultrakill_mindflayer_projectile (dmg 300 = канон 30,
-- GradualHoming c разгоном по сложности встроен в ultrakillbase).
UKMDK.FULLER_COUNT = 40
UKMDK.FULLER_INTERVAL = 0.02
UKMDK.SEEKER_START_SPEED = 2.5 * UKMDK.UNIT  -- канон Projectile.speed 2.5 м/с
-- Possession free-aim (no entity under the crosshair): seekers fly straight,
-- so match the gradual-homing cruise speed (~25 м/с after a second of accel);
-- small random cone keeps the 40-shot stream from being a single laser line.
UKMDK.SEEKER_FREE_SPEED = 25 * UKMDK.UNIT
UKMDK.SEEKER_FREE_SPREAD = 0.08

-- Canon death (Drone.cs Death/ProcessCrashing, EnemyType.Mandalore):
-- suicide dive — LookAt(цель), accel 50 м/с² вперёд, roll-спин модели,
-- 0.5 c нельзя прервать, потом любой урон или касание -> взрыв; авто через 5 c.
-- Взрыв "как у Mindflayer": 50 dmg, большой циан.
UKMDK.CRASH_ACCEL = 50 * UKMDK.UNIT      -- su/s^2
UKMDK.CRASH_MAX_SPEED = 50 * UKMDK.UNIT * 1.6
UKMDK.CRASH_GRACE = 0.5
UKMDK.CRASH_FUSE = 5.0
UKMDK.EXPLOSION_DAMAGE = 50
UKMDK.EXPLOSION_RADIUS = 8 * UKMDK.UNIT
UKMDK.PARRY_REDIRECT_SPEED = 40 * UKMDK.UNIT

-- Voice kit — через штатную VoiceScript-систему UltrakillBase (как у
-- прайм-душ): сабтитры + приоритетное перебивание. Регистрация скриптов:
-- lua/ultrakillbase/includes/customsounds/ultrakill_test_mdk_sounds.lua.
-- Пары mandy/shammy равной длины: script играет основной файл, secondary
-- (второй голос) доигрывается обычным EmitSound одновременно.
local SND = "ultrakill_prelude_test/mdk/"
UKMDK.SOUND_DIR = SND
UKMDK.BOSS_TITLE = "MYSTERIOUS DRUID KNIGHT (& OWL)"  -- canon overrideFullName
UKMDK.VOICE = {
  -- интро энкаунтера (сцена 4-3): всегда первая реплика при спавне
  intro      = { script = "Ultrakill_MDK_Intro", secondary = SND .. "waitingpuzzle_shammy.wav", dur = 3.4 },
  fullauto   = { script = "Ultrakill_MDK_FullAuto",   dur = 0.75 },
  fullerauto = { script = "Ultrakill_MDK_FullerAuto", dur = 0.78 },
  phase2 = { script = "Ultrakill_MDK_Phase2", secondary = SND .. "speed1_shammy.wav", dur = 3.71 },
  phase3 = { script = "Ultrakill_MDK_Phase3", secondary = SND .. "speed2_shammy.wav", dur = 4.38 },
  phase4 = { script = "Ultrakill_MDK_Phase4", secondary = SND .. "speed3_shammy.wav", dur = 3.01 },
  death  = { script = "Ultrakill_MDK_Death",  secondary = SND .. "death_shammy.wav",  dur = 4.01 },
  -- canon taunts: mandy = {t1, nil, t3, t4}, shammy = {t1, t2, t3, nil}
  taunts = {
    { script = "Ultrakill_MDK_Taunt1", secondary = SND .. "taunt1_shammy.wav", dur = 3.77 },
    { script = "Ultrakill_MDK_Taunt2", dur = 1.32 },  -- только сова
    { script = "Ultrakill_MDK_Taunt3", secondary = SND .. "taunt3_shammy.wav", dur = 2.59 },
    { script = "Ultrakill_MDK_Taunt4", dur = 2.03 },  -- только рыцарь
  },
}

-- Enraged-тинт краш-сущности (боссу состояния рисует _BaseDraw базы;
-- Sanded на краше = Sand-материал, см. ultrakill_test_mdk_crash.lua).
UKMDK.TINT_ENRAGED = { 1.6, 0.55, 0.55 }

function UKMDK.GetDifficulty()
  local cv = GetConVar( "ultrakill_difficulty" )
  return cv and cv:GetInt() or 2
end

-- Attacker-side damage scaling shared with the other test enemies.
-- Round-3 sweep 2026-07-10: player = FLAT canon (plytakedmgmult 0.1 cut hits
-- to 10%); pack-NPC = convention target canon x100 LANDED, pre-divided by the
-- victim's own multiplier (the old x1000 was the flagged one-shot family).
function UKMDK.ScaleAttackDamage( ent, damage, attacker )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then
    return UKNpcDmg.PreMult( ent, attacker, damage * 100 )
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * 10 * math.max( cv and cv:GetFloat() or 1, 0 )
end

-- Canon flat-damage sphere (Explosion.cs: без фоллоффа внутри maxSize).
function UKMDK.Explode( attacker, pos, radius, damage )
  if not SERVER then return end
  for _, ent in ipairs( ents.FindInSphere( pos, radius ) ) do
    if not IsValid( ent ) or ent == attacker then continue end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
    if ent.UKMDK_IsMDK then continue end  -- canon toIgnore: свой тип

    local dmg = DamageInfo()
    dmg:SetDamage( UKMDK.ScaleAttackDamage( ent, damage, attacker ) )
    dmg:SetDamageType( DMG_BLAST )
    dmg:SetAttacker( IsValid( attacker ) and attacker or game.GetWorld() )
    dmg:SetInflictor( IsValid( attacker ) and attacker or game.GetWorld() )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    local dir = ent:WorldSpaceCenter() - pos
    dir:Normalize()
    dmg:SetDamageForce( dir * 8000 )
    ent:TakeDamageInfo( dmg )
  end

  local fx = EffectData()
  fx:SetOrigin( pos )
  fx:SetRadius( radius )
  util.Effect( "Ultrakill_Explosion", fx, true, true )
  if UltrakillBase and UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
  end
end
