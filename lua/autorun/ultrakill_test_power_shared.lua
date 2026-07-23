if SERVER then AddCSLuaFile() end

-- Power (Greater Angel, Layer 8 / 8-3 Disintegration Loop).
-- Canon sources: Power.cs, PowerVoiceController.cs, EnemyCooldowns.cs,
-- gameprefabs 'Power' prefab dump (tools/steamcmd/power_probe2.py).

UKPower = UKPower or {}

UKPower.MODEL = "models/ultrakill_prelude_test/power.mdl"
UKPower.MODEL_SPEAR = "models/ultrakill_prelude_test/power_proj_spear.mdl"
UKPower.MODEL_SPINNER = "models/ultrakill_prelude_test/power_proj_spinner.mdl"
UKPower.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Power: 40 HP.
UKPower.HP = 40000
UKPower.UNIT = 20 -- su per canon meter

-- Canon damage (SwingCheck2 / Projectile dumps). Melee enemyDamage = 0:
-- Powers only hurt the machine, never other enemies.
UKPower.SWING_DAMAGE = 200        -- root SwingCheck (sword/glaive/stab)
UKPower.ZWEI_DAMAGE = 300         -- ZweiCheck boxes
UKPower.SPEAR_THROWN_DAMAGE = 350 -- PowerThrownSpear (strong, speed 150)
UKPower.SPINNER_THROWN_DAMAGE = 350 -- PowerSpinnerThrown (homing 66 deg/s, speed 50)
UKPower.ORB_DAMAGE = 250          -- zwei Hell orb pair (speed 100)
UKPower.BEAM_DAMAGE = 350         -- unparryable beam between the orbs
UKPower.SPINNER_ENEMY_MULT = 2.5 -- canon enemyDamageMultiplier

UKPower.SPEAR_SPEED = 150        -- m/s
UKPower.SPINNER_SPEED = 50       -- m/s
UKPower.SPINNER_TURNRATE = 66    -- deg/s (canon turnSpeed)
UKPower.ORB_SPEED = 100          -- m/s

-- canon Power.Update self-defense / cooldowns
UKPower.JUGGLE_LAUNCH = 140       -- m/s up on parry
UKPower.JUGGLE_DMG_TAKEN_MULT = 0.75
UKPower.GRAVITY = 40           -- m/s^2 (Unity default; rb.useGravity in juggle)

local SND = "ultrakill_prelude_test/power/"
UKPower.SOUND = {
  Intro = { SND .. "intro1.wav", SND .. "intro2.wav", SND .. "intro3.wav",
            SND .. "intro4.wav", SND .. "intro5.wav" },
  Enrage = { SND .. "enrage1.wav", SND .. "enrage2.wav", SND .. "enrage3.wav",
             SND .. "enrage4.wav", SND .. "enrage5.wav" },
  Taunt = { SND .. "taunt1.wav", SND .. "taunt2.wav", SND .. "taunt3.wav",
            SND .. "taunt4.wav" },
  CheapShot = { SND .. "cheapshot1.wav", SND .. "cheapshot2.wav", SND .. "cheapshot3.wav" },
  Hurt = { SND .. "hurt1.wav", SND .. "hurt2.wav", SND .. "hurt3.wav" },
  HurtBig = { SND .. "hurtbig1.wav", SND .. "hurtbig2.wav" },
  Death = { SND .. "death1.wav", SND .. "death2.wav" },
  Rapier = { SND .. "rapier1.wav", SND .. "rapier2.wav" },
  Greatsword = { SND .. "greatsword1.wav", SND .. "greatsword2.wav" },
  Spear = { SND .. "spear1.wav", SND .. "spear2.wav" },
  OverHere = { SND .. "overhere1.wav", SND .. "overhere2.wav" },
  Glaive = { SND .. "glaive1.wav", SND .. "glaive2.wav" },
  GlaiveThrow = { SND .. "glaivethrow1.wav", SND .. "glaivethrow2.wav" },
  Scream = SND .. "scream.wav",
  Swing = SND .. "swing.wav",
  SwingZwei = SND .. "swing_zwei.wav",
  SwingLoop = SND .. "swing_loop.wav",
  StabLoop = SND .. "stab_loop.wav",
  Orb = SND .. "orb.wav",
  OrbCharge = SND .. "orb_charge.wav",
  Beam = SND .. "beam.wav",
  Teleport = SND .. "teleport.wav",
  WeaponSpawn = SND .. "weapon_spawn.wav",
  WeaponBreak = SND .. "weapon_break.wav",
  Juggle = SND .. "juggle.wav",
  ProjExplosion = SND .. "proj_explosion.wav",
  DeathShatter = SND .. "death_shatter.wav",
}

UKPower.CLASS = {
  Regular = "ultrakill_test_power",
  Spear = "ultrakill_test_power_spear",
  Spinner = "ultrakill_test_power_spinner",
  Orb = "ultrakill_test_power_orb",
}

-- Voice lines with canon captions go through UKBase sound scripts
-- ("Ultrakill_Power_<Key><idx>", see ultrakillbase/includes/customsounds/
-- ultrakill_test_power_sounds.lua) so they get boss subtitles. Keys absent
-- here (Hurt/HurtBig/Death/Scream) have no canon captions -> plain EmitSound.
UKPower.VOICE_SCRIPT = {
  Intro = true, SpecialIntro1 = true, Enrage = true, Taunt = true, CheapShot = true,
  Rapier = true, Greatsword = true, Spear = true, OverHere = true,
  Glaive = true, GlaiveThrow = true,
}

-- Attacker-side damage scaling shared with the other test enemies.
function UKPower.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    local cv = GetConVar( "drg_ultrakill_plytakedmgmult" )
    return damage * math.max( cv and cv:GetFloat() or 1, 0 )
  end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

--------------------------------------------------------------------------------
-- Turn manager: 1:1 port of EnemyCooldowns' Power queue. powers[1] holds the
-- turn; PowerAttackEnd rotates the attacker to the back; enraged Powers bubble
-- to the front and attack simultaneously (their gate bypasses the queue).
--------------------------------------------------------------------------------

if SERVER then

  UKPower.Turns = UKPower.Turns or {
    list = {},
    attacking = nil,
    previousMove = -1,
  }
  local T = UKPower.Turns

  local function prune()
    for i = #T.list, 1, -1 do
      if not IsValid( T.list[ i ] ) or T.list[ i ].UKP_Dead then
        table.remove( T.list, i )
      end
    end
    if T.attacking ~= nil and ( not IsValid( T.attacking ) or T.attacking.UKP_Dead ) then
      T.attacking = nil
    end
  end

  function UKPower.Turns.Add( ent )
    prune()
    if not table.HasValue( T.list, ent ) then
      table.insert( T.list, ent )
    end
  end

  function UKPower.Turns.Remove( ent )
    table.RemoveByValue( T.list, ent )
    if T.attacking == ent then T.attacking = nil end
    prune()
  end

  -- canon RefreshPowers: the (lowest-index scanned last) enraged Power moves
  -- to the front
  function UKPower.Turns.Refresh()
    prune()
    local idx = nil
    for i = #T.list, 1, -1 do
      if T.list[ i ].UKP_Enraged then idx = i end
    end
    if idx then
      local ent = table.remove( T.list, idx )
      table.insert( T.list, 1, ent )
    end
  end

  function UKPower.Turns.Attacking( ent )
    prune()
    T.attacking = ent
  end

  function UKPower.Turns.AttackEnd()
    prune()
    if IsValid( T.attacking ) then
      table.RemoveByValue( T.list, T.attacking )
      table.insert( T.list, T.attacking )
    end
    T.attacking = nil
    UKPower.Turns.Refresh()
  end

  local function moveTo( index, ent )
    prune()
    if #T.list == 0 or not table.HasValue( T.list, ent ) then return end
    table.RemoveByValue( T.list, ent )
    table.insert( T.list, math.Clamp( index, 1, #T.list + 1 ), ent )
  end

  function UKPower.Turns.Prioritize( ent ) moveTo( 1, ent ) end
  function UKPower.Turns.Deprioritize( ent ) moveTo( #T.list + 1, ent ) end

  -- canon Update 'flag': blocked when a queue exists and either someone is
  -- mid-attack or we are not at the front
  function UKPower.Turns.Blocked( ent )
    prune()
    return #T.list > 0 and ( T.attacking ~= nil or T.list[ 1 ] ~= ent )
  end

  function UKPower.Turns.Count()
    prune()
    return #T.list
  end

end
