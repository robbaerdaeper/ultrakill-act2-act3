if SERVER then AddCSLuaFile() end

UKFerryman = UKFerryman or {}

UKFerryman.MODEL = "models/ultrakill_prelude_test/ferryman.mdl"
UKFerryman.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Ferryman (P-2 / Cyber Grind): 30 HP.
-- 5-2 boss: 90 HP (two 45 HP phases) — boss variant is a future entity.
UKFerryman.HP_REGULAR = 30000

-- Canon scale: 40 su per canon meter (compiled model ~200 su vs 5 m capsule).
UKFerryman.UNIT = 24 -- 2026-07-10 r3: ещё +10% (итог x0.605 от исходных 40)
-- Canon NavMeshAgent speed: 32 m/s (fastest ground unit in the game).
UKFerryman.MOVE_SPEED = 32 * UKFerryman.UNIT
-- Canon SwingCheck2 damage: StartDamage anim events pass int 0 => default 25.
UKFerryman.SWING_DAMAGE = 25
-- Canon slam explosion ("Explosion Ferryman"): damage 35, maxSize 6.
-- Explosion.cs FixedUpdate: growth stops when lossyScale*collider.radius >
-- maxSize => maxSize IS the final world RADIUS in meters.
UKFerryman.SLAM_DAMAGE = 35
UKFerryman.SLAM_RADIUS = 6 * UKFerryman.UNIT
-- Canon lightning ("Explosion Lightning"): damage 35, maxSize 20 (radius, m), electric.
UKFerryman.LIGHTNING_DAMAGE = 35
UKFerryman.LIGHTNING_RADIUS = 20 * UKFerryman.UNIT
-- Canon coin chargeback ("Ride the Lightning"): the reflected prefab is an
-- ultraRicocheter railcannon RevolverBeam that kills nearly any non-boss
-- enemy it chains into. ukcoin's RAILCANNON state scales x1.25 and the beam
-- carries attacker=player, so UK nextbots multiply it x10 again in
-- DamageMultiplier: 4000 -> beam 5000 -> effective 50000 — above every
-- regular enemy's HP (canon HP x1000). The Ferryman himself caps it to half
-- his max HP in OnTakeDamage (massive canon damage, not an instakill).
UKFerryman.CHARGEBACK_DAMAGE = 4000

UKFerryman.SOUND = {
  Swing1 = "ultrakill_prelude_test/ferryman/swing1.wav",
  Swing2 = "ultrakill_prelude_test/ferryman/swing2.wav",
  Chimes = "ultrakill_prelude_test/ferryman/chimes.wav",
  Footstep = "ultrakill_prelude_test/ferryman/footstep.wav",
  Thunder = "ultrakill_prelude_test/ferryman/thunder.wav",
  WindupRumble = "ultrakill_prelude_test/ferryman/windup_rumble.wav",
  -- shipped by the required ultrakillbase addon
  Spawn = "ultrakill/sound/portalferryman.wav",
}

UKFerryman.CLASS = {
  Regular = "ultrakill_test_ferryman",
  Windup = "ultrakill_test_ferryman_windup",
}

-- Canon EnemyCooldowns.ferrymanCooldown: shared across ALL Ferrymen, +6 s per
-- lightning cast, ticks down 1/s (a timestamp models exactly that).
UKFerryman.GlobalLightningUntil = UKFerryman.GlobalLightningUntil or 0

function UKFerryman.GlobalLightningReady()
  return CurTime() >= UKFerryman.GlobalLightningUntil
end

function UKFerryman.AddGlobalLightningCooldown( seconds )
  local base = math.max( UKFerryman.GlobalLightningUntil, CurTime() )
  UKFerryman.GlobalLightningUntil = base + seconds
end

-- Attacker-side damage scaling shared with the other test enemies.
-- `attacker` (optional) — round-3 sweep 2026-07-10: pack-NPC victims get the
-- convention target (canon x100 LANDED), pre-divided by their own incoming
-- multiplier; without it the ferryman fed raw wiki numbers and landed
-- wiki x20 = five times short.
function UKFerryman.ScaleAttackDamage( ent, damage, attacker )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    -- flat canon to the player (Sentry r3 policy, extended here 2026-07-10
    -- round 2: drg_ultrakill_plytakedmgmult defaults to 0.1 and quietly cut
    -- ferryman hits to 10% of the wiki numbers)
    return damage
  end
  if ent.IsUltrakillNextbot then
    return UKNpcDmg.PreMult( ent, attacker, damage * 100 )
  end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

-- Canon flat-damage sphere (ULTRAKILL Explosion: no distance falloff inside
-- maxSize). safeForPlayer mirrors Explosion.canHit = EnemiesOnly.
function UKFerryman.Explode( attacker, pos, radius, damage, opts )
  opts = opts or {}
  if SERVER then
    for _, ent in ipairs( ents.FindInSphere( pos, radius ) ) do
      if not IsValid( ent ) or ent == attacker then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      -- canon toIgnore: EnemyType.Ferryman — lightning/slam never hurt Ferrymen
      if ent.UKFerryman_IsFerryman then continue end
      if opts.safeForPlayer and ent:IsPlayer() then continue end

      local dmg = DamageInfo()
      dmg:SetDamage( UKFerryman.ScaleAttackDamage( ent, damage, attacker ) )
      dmg:SetDamageType( bit.bor( DMG_BLAST, opts.electric and DMG_SHOCK or 0 ) )
      dmg:SetAttacker( IsValid( attacker ) and attacker or game.GetWorld() )
      dmg:SetInflictor( IsValid( attacker ) and attacker or game.GetWorld() )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      local dir = ent:WorldSpaceCenter() - pos
      dir:Normalize()
      dmg:SetDamageForce( dir * 6000 )
      ent:TakeDamageInfo( dmg )
    end

    -- canon ULTRAKILL explosion visual at the blast point. The effect reads
    -- GetRadius()*0.01 as the sphere model scale (Kevin's CreateExplosion
    -- passes Radius*100 with Radius 1..3); feeding it the raw damage radius
    -- in su (800+) produced a broken oversized sphere = "no explosion".
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetAngles( angle_zero )
    fx:SetRadius( 300 )
    util.Effect( "Ultrakill_Explosion", fx, true, true )
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    end
  end
end
