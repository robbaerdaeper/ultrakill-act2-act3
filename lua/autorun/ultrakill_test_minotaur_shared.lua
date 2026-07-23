if SERVER then AddCSLuaFile() end

UKMinotaur = UKMinotaur or {}

UKMinotaur.MODEL = "models/ultrakill_prelude_test/minotaur.mdl"
UKMinotaur.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Arena/sandbox Minotaur: 80 HP.
UKMinotaur.HP = 80000

-- Sandbox scale: 0.5x canon. 20 su per canon meter ($scale 40 on rigging
-- units = 2 m each). Canon 1:1 was UNIT 40 / $scale 80 — a 440 su giant.
UKMinotaur.UNIT = 40
-- Canon NavMeshAgent: speed 50 m/s, acceleration 100, stoppingDistance 15 m,
-- agent radius 3 m, height 11 m. AngularSpeed 12000 = effectively instant.
-- Raw canon 50 m/s reads as absurdly fast in GMod (user feedback 2026-07-07)
-- -> chase 30 m/s, ram keeps more of the canon punch at 40 m/s.
UKMinotaur.STOP_DISTANCE = 15 * UKMinotaur.UNIT
-- Ram charge: same agent, headfirst. Canon RamSwingCheck: 50 dmg, kb 100.
UKMinotaur.RAM_SPEED = 20 * UKMinotaur.UNIT
UKMinotaur.RAM_DAMAGE = 500
UKMinotaur.RAM_KNOCKBACK = 100
-- Canon SwingCheck2 on Staff / HandSwing / SwingCheckHelper: 25.
UKMinotaur.SWING_DAMAGE = 250
-- Canon HammerSmash: impact 25, then Explosion 35, then Explosion Super 35.
-- ULTRAKILL 'Explosion' maxSize is the final world radius in meters.
UKMinotaur.SMASH_IMPACT_DAMAGE = 250
UKMinotaur.EXPLOSION_DAMAGE = 350
UKMinotaur.EXPLOSION_RADIUS = 3
UKMinotaur.SUPER_EXPLOSION_DAMAGE = 350
UKMinotaur.SUPER_EXPLOSION_RADIUS = 4
-- Canon ram wall bonk: the Minotaur hurts ITSELF (wiki: 6 dmg) and stuns.
UKMinotaur.BONK_SELF_DAMAGE = 6000
-- Canon ram parry: ~30 canon damage dealt to the Minotaur (x1000).
-- UKBase OnParry already lands +5000 DMG_DIRECT; the NPC tops it up.
UKMinotaur.PARRY_TOTAL_DAMAGE = 30000
-- Acid (Goop): canon tick damage 3/7/15 by difficulty; puddle ~10 s,
-- cloud ~10 s, Brutal doubles duration (GoopLong prefabs: 20 s vs 12.5 s).
UKMinotaur.ACID_TICK_INTERVAL = 0.5
UKMinotaur.ACID_LIFETIME = 10
-- upsized vs canon 3 / 4.5 m (user feedback 2026-07-07 x3: puddle 12 m flat)
UKMinotaur.PUDDLE_RADIUS = 6 * UKMinotaur.UNIT
UKMinotaur.CLOUD_RADIUS = 4.5 * UKMinotaur.UNIT

UKMinotaur.SOUND = {
  Roar = "ultrakill_prelude_test/minotaur/roar.wav",
  RoarShort = "ultrakill_prelude_test/minotaur/roar_short.wav",
  Grunt1 = "ultrakill_prelude_test/minotaur/grunt1.wav",
  Grunt2 = "ultrakill_prelude_test/minotaur/grunt2.wav",
  GruntLong = "ultrakill_prelude_test/minotaur/grunt_long.wav",
  Squeal = "ultrakill_prelude_test/minotaur/squeal.wav",
  Exhale = "ultrakill_prelude_test/minotaur/exhale.wav",
  Swing1 = "ultrakill_prelude_test/minotaur/swing1.wav",
  Swing2 = "ultrakill_prelude_test/minotaur/swing2.wav",
  HammerImpact = "ultrakill_prelude_test/minotaur/hammer_impact.wav",
  Explosion = "ultrakill_prelude_test/minotaur/explosion.wav",
  ExplosionSuper = "ultrakill_prelude_test/minotaur/explosion_super.wav",
  MeatSquish = "ultrakill_prelude_test/minotaur/meat_squish.wav",
  Step = "ultrakill_prelude_test/minotaur/step.wav",
}

UKMinotaur.CLASS = {
  Regular = "ultrakill_test_minotaur",
  Acid = "ultrakill_test_minotaur_acid",
  Meat = "ultrakill_test_minotaur_meat",
  Collider = "ultrakill_test_minotaur_collider",
}

-- Canon Goop green (GoopCloud 'Water 9' material: _Color 0.19 1.0 0.0).
UKMinotaur.ACID_COLOR = Color( 49, 255, 0 )

-- Canon acid tick damage by UltrakillBase difficulty (0..4+).
function UKMinotaur.AcidTickDamage( diff )
  if diff <= 0 then return 3 end
  if diff == 1 then return 7 end
  return 15
end

local function UltrakillScaleDamage( Ent )

  if Ent:IsPlayer() then

    return math.max( GetConVar( "drg_ultrakill_plytakedmgmult" ):GetFloat(), 0 )

  elseif Ent.IsUltrakillNextbot then

    return 1

  else

    return math.max( GetConVar( "drg_ultrakill_dmgmult" ):GetFloat(), 0 )

  end

end

-- Attacker-side damage scaling. Players take FLAT canon wiki damage —
-- drg_ultrakill_plytakedmgmult defaults to 0.1 and shrank every hit to 10%
-- (Sentry r3 lesson; user decision 2026-07-07: ignore that convar).
function UKMinotaur.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  return damage * UltrakillScaleDamage( ent )
end

-- Canon flat-damage sphere (ULTRAKILL Explosion: no falloff inside maxSize).
-- opts.super = the red "Explosion Super" of the HammerSmash pull-out.
function UKMinotaur.Explode( attacker, pos, radius, damage, opts )
  opts = opts or {}
  if SERVER then
    for _, ent in ipairs( ents.FindInSphere( pos, radius ) ) do
      if not IsValid( ent ) or ent == attacker then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      -- canon: the Minotaur's own explosions never hurt Minotaurs
      if ent.UKMinotaur_IsMinotaur then continue end

      local dmg = DamageInfo()
      dmg:SetDamage( UKMinotaur.ScaleAttackDamage( ent, damage ) )
      dmg:SetDamageType( DMG_BLAST )
      dmg:SetAttacker( IsValid( attacker ) and attacker or game.GetWorld() )
      dmg:SetInflictor( IsValid( attacker ) and attacker or game.GetWorld() )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      local dir = ent:WorldSpaceCenter() - pos
      dir:Normalize()
      dmg:SetDamageForce( dir * 6000 )
      ent:TakeDamageInfo( dmg )
    end

        if opts.super then
      -- canon: the pull-out is a RED super explosion
      local rfx = EffectData()
      rfx:SetOrigin( pos )
      rfx:SetRadius( radius )
      util.Effect( "ultrakill_minotaur_super", rfx, true, true )
      local fx = EffectData()
      fx:SetOrigin( pos )
      fx:SetRadius( radius )
      util.Effect( "Ultrakill_Hard_Explosion", fx, true, true )
    else
      local fx = EffectData()
      fx:SetOrigin( pos )
      fx:SetRadius( radius )
      util.Effect( "Ultrakill_Explosion", fx, true, true )
    end
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    end
  end
end
