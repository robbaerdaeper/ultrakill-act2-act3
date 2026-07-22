-- lua/ultrakill/virtue_constants.lua
-- Canon constants for Virtue port. Refs: Drone.cs, VirtueInsignia.cs, EnemyCooldowns.cs, .mat files.

UK_VIRTUE = {
  SCALE_M_TO_SU         = 25.0,
  -- Конвенция пака: HP врага = канон × 1000 (канон Virtue Health = 10 → 10000).
  -- В ряд с Mannequin 6000 / Sentry 12000. Старое 100 умирало с одного выстрела мод-оружия.
  HP                    = 10000,

  HOVER_DRAG            = 0.975,
  HOVER_FORCE_ACCEL     = 250,
  HOVER_MAX_VEL         = 1250,
  PREFERRED_DIST        = 375,

  BOB_AMP               = 6,
  BOB_RATE              = 1.0,
  YAW_LERP_RATE         = 5,

  DODGE_FORCE           = 150,
  DODGE_CD_MIN          = 1.0,
  DODGE_CD_MAX          = 3.0,
  DODGE_AXIS_RANGE      = 5,
  DODGE_WALL_PROBE      = 175,
  DODGE_DIFF_CHANCE     = { [0]=0.0, [1]=0.25, [2]=1.0, [3]=1.0, [4]=1.0, [5]=1.0 },

  ATTACK_CD_INITIAL     = 1.5,
  ATTACK_CD_MIN         = 1.0,
  ATTACK_CD_MAX         = 3.0,
  GLOBAL_VIRTUE_CD      = 1.0,
  MAX_VIRTUES_ENRAGE    = 3,

  ENRAGE_USED_ATTACKS   = { [0]=99, [1]=99, [2]=5, [3]=3, [4]=3, [5]=3 },

  INSIGNIA_WINDUP       = 2.0,
  INSIGNIA_ACTIVATE     = 1.0,
  INSIGNIA_LINGER       = 2.0,   -- канон: луч висит ~2с (было 1с — слишком мало)
  INSIGNIA_LINGER_BRUTAL= 4.0,   -- Brutal: «lingers for much longer»
  INSIGNIA_TRACK_BASE   = 50,
  INSIGNIA_TRACK_DIST   = 100,
  INSIGNIA_YAW_TRACK    = 180,
  INSIGNIA_YAW_ACTIVE   = 720,
  INSIGNIA_RADIUS       = 110,
  INSIGNIA_GLYPH_RADIUS = 130,   -- радиус плоского глифа на земле (SU)
  INSIGNIA_DAMAGE       = 50,    -- урон игроку (просьба: бить на 50, не выносить все 100)
  -- Урон по NPC пака (HP = канон×1000). Значение = ФИНАЛЬНОЕ приземлённое:
  -- тик пре-делит его на множитель базы (жертва-нектбот сама умножает урон
  -- по типу атакера: Virtue = UK-нектбот → ×20; из-за этого первые 10000
  -- приземлялись как 200000 — «слишком много»). r2: 10000 → 5000.
  -- r3 по запросу юзера: 5000 → 20000.
  INSIGNIA_DAMAGE_NPC   = 20 * 1000,
  INSIGNIA_LAUNCH_STR   = 200,
  INSIGNIA_LAUNCH_MULT  = 5,
  INSIGNIA_PREDICTIVE_T = 1.0,
  INSIGNIA_FLAMMABLE_T  = 10,
  CAMERA_SHAKE_AMP      = 5,

  MULTI_CHARGES         = 3,
  MULTI_INTERVAL        = 0.25,

  BEAM_HEIGHT_SU        = 4096,
  BEAM_THICKNESS_MAX_SU = 80,

  -- Аура рисуется текстурой charge (сине-циановой) с color_white — свой цвет НЕ задаём.
  AURA_RING_PERIOD      = 1.5,
  AURA_RING_COUNT       = 3,
  AURA_RING_MAX_RADIUS  = 80,

  PARRY_DMG_MULT_FRAME  = 3.0,
  PARRY_DMG_MULT_OPEN   = 4.0,
  PARRY_KNOCKBACK_FORCE = 25000,
  PARRY_HITTER_TAGS     = { ["punch"]=true, ["shotgunzone"]=true, ["hammerzone"]=true },
  PARRY_HOOK_GRACE_DIFF = { [0]=1.0, [1]=0.5, [2]=0, [3]=0, [4]=0, [5]=0 },
  PARRY_CANCEL_INSIGNIA = true,

  -- Крылья не смоделены в mesh (в Unity это trail-шейдер), рисуем клиентскими quad'ами.
  -- Канон: узкое перо под углом вверх-наружу (V), сужается к кончику, полупрозрачное.
  WING_CENTER_Z         = 42,   -- высота центра сферы над GetPos (SU)
  WING_LEN              = 95,   -- длина крыла корень→кончик (SU) при extend=1
  WING_WIDTH            = 46,   -- ширина крыла у корня (SU)
  WING_TAPER            = 0.20, -- доля ширины у кончика (сужение к перу)
  WING_ANGLE            = 52,   -- угол взмаха вверх от горизонтали (град)
  WING_INSET            = 20,   -- отступ основания крыла от центра
  WING_UP_OFFSET        = 8,    -- корень крыла чуть выше центра сферы
  WING_ALPHA            = 200,  -- полупрозрачность
  WING_REST_SCALE       = 0.9,
  WING_EXTEND_SCALE     = 1.2,

  ENRAGE_ATTACK_CD_MULT = 0.5,  -- ярость → атаки в 2× чаще

  HEAD_MULT             = 2.0,
  LIMB_MULT             = 1.5,
  TORSO_MULT            = 1.0,

  RAGDOLL_SPHERE_HP     = 1,
  RAGDOLL_FALL_GRAVITY  = 1.0,
  RAGDOLL_EXPLODE_RANGE = 250,
  RAGDOLL_KNOCKBACK     = 400,
  RAGDOLL_FADE_TIME     = 6.0,
}
