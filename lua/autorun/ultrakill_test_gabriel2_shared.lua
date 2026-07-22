if SERVER then AddCSLuaFile() end

UKGabriel2 = UKGabriel2 or {}

UKGabriel2.MODEL          = "models/ultrakill_prelude_test/gabriel2.mdl"
UKGabriel2.MODEL_COMBINED = "models/ultrakill_prelude_test/gabriel2_combined.mdl"
UKGabriel2.MODEL_ZWEI     = "models/ultrakill_prelude_test/gabriel2_zwei.mdl"
UKGabriel2.CATEGORY       = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Gabriel 2nd: 100 (50 per phase).
UKGabriel2.HP = 100000
UKGabriel2.PHASE2_FRAC = 0.5

-- Canon scale: 40 su per canon meter.
UKGabriel2.UNIT = 18 -- 2026-07-10: model rescaled x0.45 (Kevin-scale), was 40

-- Canon damages (per-hit, ULTRAKILL 100-hp scale; from the .anim events).
UKGabriel2.DMG = {
  LIGHT_HIT    = 20, -- FastCombo hits 1-4
  LIGHT_FINISH = 35, -- FastCombo lunge
  MED_HIT      = 30, -- BasicCombo swings 1-2
  MED_THRUST   = 35, -- BasicCombo thrust
  MED_FINISH   = 35, -- BasicCombo dashing slice
  HEAVY_1      = 35, -- ThrowCombo first cleave
  HEAVY_2      = 45, -- ThrowCombo second cleave (+kick)
  THROWN       = 35, -- combined swords projectile
  ZWEI         = 35, -- each spiral sword
}

-- Canon combined swords projectile (GabrielCombinedSwords prefab).
UKGabriel2.THROWN_SPEED     = 50 * UKGabriel2.UNIT   -- m/s -> su/s
UKGabriel2.THROWN_TURNRATE  = 75                     -- deg/s homing
UKGabriel2.THROWN_SPEED_HARD = 1.75                  -- x speed on Brutal+ (diff >= 4)

-- Canon spiral swords (GabrielSummonedSwords, 8x GabrielThrownZwei).
UKGabriel2.SPIRAL_COUNT       = 8
UKGabriel2.SPIRAL_ORBIT_R     = 2.5 * UKGabriel2.UNIT * 2 -- 5 m ring radius
UKGabriel2.SPIRAL_ORBIT_DEG   = 720                       -- deg/s orbit spin
UKGabriel2.SPIRAL_LIFE        = 5                         -- s before resolve
UKGabriel2.SPIRAL_STAB_SPEED  = 150 * UKGabriel2.UNIT     -- m/s at SpiralStab
UKGabriel2.SPIRAL_COOLDOWN    = 15

UKGabriel2.SOUND = {
  Swing       = "ultrakill_prelude_test/gabriel2/swing.wav",
  SwingLoop   = "ultrakill_prelude_test/gabriel2/swing_loop.wav",
  KickSwing   = "ultrakill_prelude_test/ferryman/swing2.wav", -- canon FerrymanSwing2
  Dash        = "ultrakill_prelude_test/ferryman/swing1.wav", -- canon FerrymanSwing1
  Teleport    = "ultrakill_prelude_test/gabriel2/teleport.wav",
  TeleportHigh = "ultrakill_prelude_test/gabriel2/teleport_high.wav",
  Juggle      = "ultrakill_prelude_test/gabriel2/juggle.wav",
  SummonWindup = "ultrakill_prelude_test/gabriel2/summon_windup.wav",
  SummonSpawn = "ultrakill_prelude_test/gabriel2/summon_spawn.wav",
  WeaponBreak = "ultrakill_prelude_test/gabriel2/weapon_break.wav",
}

-- Judge of Hell voice lines (reuse kevin's ported WAVs).
local V = "ultrakill_prelude_test/gabriel2/"
UKGabriel2.VOICE = {
  Intro       = { V .. "gab_intro1d.wav", V .. "gab_intro2b.wav", V .. "gab_behold.wav" },
  Hurt        = { V .. "gab_hurt1.wav", V .. "gab_hurt2.wav",
                  V .. "gab_hurt3.wav", V .. "gab_hurt4.wav" },
  BigHurt     = { V .. "gab_bighurt1.wav" },
  PhaseChange = { V .. "gab_enough.wav" },
  Death       = { V .. "gab_woes.wav" },
  -- phase 1 (enraged judge) / phase 2 pools, canon no-repeat rotation
  Taunt1 = { V .. "gab_taunt1.wav", V .. "gab_taunt2.wav", V .. "gab_taunt3.wav",
             V .. "gab_taunt4.wav", V .. "gab_taunt5.wav", V .. "gab_taunt6.wav" },
  Taunt2 = { V .. "gab_taunt7.wav", V .. "gab_taunt8.wav", V .. "gab_taunt9.wav",
             V .. "gab_taunt10.wav", V .. "gab_taunt11.wav", V .. "gab_taunt12.wav",
             V .. "gab_insignificant2b.wav" },
}

-- Attacker-side damage scaling shared with the other test enemies.
-- round-3 sweep 2026-07-10: player takes FLAT canon (plytakedmgmult defaults
-- to 0.1 and cut hits to 10% — Sentry r3 policy); pack-NPC victims get the
-- convention target (canon x100 LANDED) pre-divided by their own multiplier
-- (raw wiki landed only wiki x20). `attacker` optional.
function UKGabriel2.ScaleAttackDamage( ent, damage, attacker )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then
    return UKNpcDmg.PreMult( ent, attacker, damage * 100 )
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end
