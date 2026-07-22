if SERVER then AddCSLuaFile() end

UKGutterman = UKGutterman or {}

UKGutterman.MODEL = "models/ultrakill_prelude_test/gutterman.mdl"
UKGutterman.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000 (Gabriel 100->100000, Cerberus 80->80000).
-- Canon Gutterman: 25 HP, 7-2 bossish: 30 HP.
UKGutterman.HP_REGULAR = 25000
UKGutterman.HP_BOSS = 30000
UKGutterman.BOSS_TITLE = "GUTTERMAN"

-- Canon scale: compiled model ~174 su tall vs ~4.4 m in ULTRAKILL => ~40 su/m.
UKGutterman.UNIT = 40
-- Canon standard profile: movement speed 10 m/s, windup 1/s, tracking base 1 m/s.
UKGutterman.MOVE_SPEED = 7 * UKGutterman.UNIT -- round 4 2026-07-10: «уменьшить скорость гаттермана» (was 10 = canon)
UKGutterman.WINDUP_SPEED = 1
UKGutterman.TRACK_DEFAULT = 1 * UKGutterman.UNIT
-- Canon ShieldBash trigger: head distance < 12 m.
UKGutterman.BASH_RANGE = 12 * UKGutterman.UNIT
-- Swing contact zone (canon damage comes from a SwingCheck2 collider on the
-- shield/hand, not from range checks — keep the zone tight to the model).
UKGutterman.BASH_HIT_FORWARD = 1.5 * UKGutterman.UNIT
UKGutterman.BASH_HIT_RADIUS = 2.5 * UKGutterman.UNIT

-- Canon "Gutterman Beam" RevolverBeam fields (gameprefabs bundle dump):
-- damage 1.0 (player hit = damage x10 = 10 HP), enemyDamageOverride 0.2,
-- deflected (chargeback) enemy damage = 0.2 x 2.5 = 0.5 enemy units.
UKGutterman.BEAM_DAMAGE_PLAYER = 10  -- net player HP per hit (canon 10)
-- Canon player hit: NewMovement.GetHurt(..., invincible: true) — every hit
-- grants i-frames, so sustained fire reads as ~10 damage per second.
UKGutterman.PLAYER_HIT_COOLDOWN = 1.0
-- NPC targets tick on the same kind of gate, but theirs spins up with the
-- cannon: 1.0s interval at trigger pull, ~halved after every
-- NPC_GATE_HALVE_TIME seconds of sustained fire, floored at the MIN. Each
-- tick hits much harder than a single canon beam (per live feedback: canon
-- 0.2/0.5 units per beam read as "no damage at all" at pack HP scale).
UKGutterman.NPC_HIT_COOLDOWN_START = 1.0
UKGutterman.NPC_HIT_COOLDOWN_MIN = 0.15
UKGutterman.NPC_GATE_HALVE_TIME = 1.5
-- Per gate tick (not per beam): enemy units vs UK pack bots (x1000 HP scale),
-- player units vs everything else (HL2 NPCs etc.).
UKGutterman.BEAM_NPC_TICK_UNITS = 2
UKGutterman.BEAM_NPC_TICK_PLAYER_UNITS = 40
-- Raw damage fed to a coin on chargeback. Coin doubles it (dmg + dmg*Power)
-- and the victim-side player-attacker multiplier is x10: 25 -> ~500 vs
-- 25000 HP = canon "abysmal" 0.5 enemy units.
UKGutterman.BEAM_COIN_DAMAGE = 25

-- SwingCheck damages: player HP units / enemy HP units.
UKGutterman.MELEE = {
  ShieldBash = { player = 40, units = 4 },
  Smack = { player = 30, units = 3 },
}

-- Unified outgoing damage scaling (mirrors pack conventions):
--  * player target: raw = playerUnits x10, then drg_ultrakill_plytakedmgmult
--    (default 0.1) brings it back to playerUnits;
--  * UltrakillBase nextbot target: their OnTakeDamage multiplies nextbot
--    attackers by x20, so raw = enemyUnits x50 nets enemyUnits x1000 (pack HP
--    scale);
--  * other NPCs: playerUnits x drg_ultrakill_dmgmult (pack default 25), but
--    the multiplier is FLOORED AT 1: archived configs can carry tiny values
--    (0.1 seen live), which turned every hit vs HL2 NPCs into ~1 HP.
function UKGutterman.ScaleDamage( ent, playerUnits, enemyUnits )
  if not IsValid( ent ) then return playerUnits end
  if ent:IsPlayer() then
    -- round-4 2026-07-10: FLAT canon to the player (was x10 x plytakedmgmult,
    -- net-identical at the 0.1 default but convar-fragile)
    return playerUnits
  end
  if ent.IsUltrakillNextbot then
    return ( enemyUnits or playerUnits / 10 ) * 50
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return playerUnits * math.max( cv and cv:GetFloat() or 1, 1 )
end

-- Visual shield mesh bounds in "Shield 1" bone-local space: exact inverse-bind
-- projection of gutterman_shield.smd verts at QC $scale 6000 (no inflation —
-- an inflated box ate shots aimed next to the visual shield edge). Shared so
-- the base can test "does the shield stand between the damage and the body".
UKGutterman.SHIELD_MINS = Vector( -71, 4, -49 )
UKGutterman.SHIELD_MAXS = Vector( 93, 25, 37 )

UKGutterman.DEBUG_HELPERS_CVAR = "ultrakill_test_gutterman_debug_helpers"
UKGutterman.DebugHelpers = UKGutterman.DebugHelpers or GetConVar( UKGutterman.DEBUG_HELPERS_CVAR )
if not UKGutterman.DebugHelpers then
  UKGutterman.DebugHelpers = CreateConVar(
    UKGutterman.DEBUG_HELPERS_CVAR,
    "0",
    FCVAR_ARCHIVE,
    "Show Gutterman shield helper hitbox."
  )
end

UKGutterman.SOUND = {
  Bonk = "ultrakill_prelude_test/gutterman/bonk.wav",
  Death = "ultrakill_prelude_test/gutterman/death.wav",
  GunWindup = "ultrakill_prelude_test/gutterman/gun_windup.wav",
  Release = "ultrakill_prelude_test/gutterman/release.wav",
  ShieldBreak = "ultrakill_prelude_test/gutterman/shield_break.wav",
  Step = "ultrakill_prelude_test/gutterman/step.wav",
  -- Canon beam fire clip (MachineGun3B), played per beam (AudioSource pitch
  -- 0.5 + RandomPitch 0.7 +- 0.1).
  Fire = "ultrakill_prelude_test/gutterman/fire.wav",
  -- Canon BombFalling whistle for the drop pod.
  PodFalling = "ultrakill_prelude_test/gutterman/pod_falling.wav",
}

UKGutterman.CLASS = {
  Regular = "ultrakill_test_gutterman",
  Boss = "ultrakill_test_gutterman_boss",
  Casketless = "ultrakill_test_gutterman_casketless",
  Base = "ultrakill_test_gutterman_base",
  Shield = "ultrakill_test_gutterman_shield",
  Corpse = "ultrakill_test_gutterman_corpse",
}

UKGutterman.EXCLUDED_ORB_CLASS = {
  ultrakill_test_rodent_projectile = true,
  ultrakill_stray_projectile = true,
  ultrakill_schism_projectile = true,
  ultrakill_soldier_projectile = true,
  ultrakill_drone_projectile = true,
  ultrakill_drone_corpse_projectile = true,
  ultrakill_mindflayer_projectile = true,
  ultrakill_maliciousface_projectile = true,
  ultrakill_cerberus_projectile = true,
  ultrakill_hideousmass_mortar_projectile = true,
  ultrakill_minos_snakeprojectile = true,
}

function UKGutterman.IsDebugHelpersEnabled()
  return UKGutterman.DebugHelpers and UKGutterman.DebugHelpers:GetBool() or false
end

-- Live (not yet ricoshot) player coin closest to `from` along the ray
-- from->to. Used for canon chargeback + the coin line-of-fire spool-down.
function UKGutterman.FindBeamCoin( from, to )
  local half = Vector( 12, 12, 12 )
  local best, bestDist = nil, math.huge
  for _, ent in ipairs( ents.FindAlongRay( from, to, -half, half ) ) do
    if IsValid( ent ) and ent:GetClass() == "ultrakill_coin"
        and not ( ent.GetDead and ent:GetDead() ) then
      local d = from:DistToSqr( ent:GetPos() )
      if d < bestDist then best, bestDist = ent, d end
    end
  end
  return best
end
