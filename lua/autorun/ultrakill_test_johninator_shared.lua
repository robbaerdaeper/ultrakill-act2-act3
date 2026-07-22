if SERVER then AddCSLuaFile() end

UKJohninator = UKJohninator or {}

UKJohninator.MODEL = "models/ultrakill_prelude_test/johninator.mdl"
UKJohninator.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Big Johninator: 40 HP.
UKJohninator.HP = 40000

-- Model compiled at $scale 60 (BigJohn node x1.5) => 40 su per canon meter.
UKJohninator.UNIT = 40

-- Canon V2.cs SetSpeed multipliers on movementSpeed 15 m/s
-- (0 HARMLESS, 1 LENIENT, 2 STANDARD, 3 VIOLENT, 4/5 BRUTAL/UKMD).
local BASE_SPEED = 15 * UKJohninator.UNIT
UKJohninator.SPEED_PROFILE = {
  [0] = { mult = 0.65, hp = 1.0 },
  [1] = { mult = 0.75, hp = 1.0 },
  [2] = { mult = 0.85, hp = 1.0 },
  [3] = { mult = 1.00, hp = 1.0 },
  [4] = { mult = 1.50, hp = 1.5 }, -- wiki: BRUTAL +50% HP
  [5] = { mult = 1.50, hp = 1.5 },
}
function UKJohninator.Speed( d )
  return BASE_SPEED * ( UKJohninator.SPEED_PROFILE[ d ] or UKJohninator.SPEED_PROFILE[ 3 ] ).mult
end

-- UKBase Explosion damage convention: wiki player damage x10 (the base
-- applies drg_ultrakill_plytakedmgmult, default 0.1, vs players — the
-- V Series V2 rocket passes 350 for the same canon 35).
UKJohninator.ROCKET_DAMAGE = 35 * 10
UKJohninator.BEAM_DAMAGE = 50 * 10
UKJohninator.MINE_DAMAGE = 35 * 10

-- Canon Grenade.rocketSpeed = 150 m/s (=6000 su/s); clamped for Source physics.
UKJohninator.ROCKET_SPEED = 4200
UKJohninator.BEAM_SPEED = 5200

-- Canon V2.ShootCheck rocket barrage delays (difficulty >= 2 fires all three,
-- >= 1 the last two, else the last one) and the ~5 s alt (Malicious Beam) cycle.
UKJohninator.BARRAGE_DELAYS = { 0.75, 0.95, 1.15 }
UKJohninator.ALT_COOLDOWN = 5.0
-- Canon MineLayer cycle: spawn -> 1 s -> 3 s delay -> spawn (one mine per ~4 s).
UKJohninator.MINE_INTERVAL = 4.0
UKJohninator.MINE_LIMIT = 12

UKJohninator.SOUND = {
  Death      = "ultrakill_prelude_test/johninator/death.wav",
  MineBeep   = "ultrakill_prelude_test/johninator/mine_beep.wav",   -- canon pitch 1.5 baked
  MineScan   = "ultrakill_prelude_test/johninator/mine_scan.wav",   -- mine idle loop
  BeamCharge = "ultrakill_prelude_test/johninator/beam_charge.wav", -- Throat Drone High
  BeamFire   = "ultrakill_prelude_test/johninator/beam_fire.wav",   -- Shoot2b3
  RocketFire = "ultrakill_prelude_test/johninator/rocket_fire.wav", -- RocketFire5
  RocketLoop = "ultrakill_prelude_test/johninator/rocket_loop.wav",
  Jump       = "ultrakill_prelude_test/johninator/jump.wav",
  JumpDash   = "ultrakill_prelude_test/johninator/jump_dash.wav",
}

-- Canon Radio 'Voices': 23 ROTT Big John taunts, random order, back-to-back.
UKJohninator.TAUNTS = {}
for i = 1, 23 do
  UKJohninator.TAUNTS[ i ] = string.format(
    "ultrakill_prelude_test/johninator/taunt%02d.wav", i )
end

UKJohninator.CLASS = {
  Regular = "ultrakill_test_johninator",
  Rocket = "ultrakill_test_johninator_rocket",
  Beam = "ultrakill_test_johninator_beam",
  Mine = "ultrakill_test_johninator_mine",
}

-- Base difficulty convar (drg_ultrakill_difficulty, VIOLENT default) — sentry pattern.
function UKJohninator.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

-- Attacker-side damage scaling shared with the other test enemies (ferryman/sentry).
function UKJohninator.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    local cv = GetConVar( "drg_ultrakill_plytakedmgmult" )
    return damage * math.max( cv and cv:GetFloat() or 1, 0 )
  end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end
