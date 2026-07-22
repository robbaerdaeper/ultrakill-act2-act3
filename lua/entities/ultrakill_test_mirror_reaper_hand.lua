AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_mirror_reaper_shared.lua" )

-- Phantom Hand (canon MirrorReaperGroundWave): a ghostly hand that rushes the
-- target along the ground for 15 s. HurtZone 20 dmg / 1 s cooldown, Breakable
-- durability 3 (weak: any hitscan chip breaks it), parry launches it along the
-- player's aim (5 DP to enemies it hits), destroying it fully heals the killer.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Phantom Hand"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.Category = UKMirrorReaper.CATEGORY

ENT.Models = { UKMirrorReaper.HAND_MODEL }
-- half-size in step with the reaper (canon hand ~6.7 m is about reaper-tall)
ENT.ModelScale = UKMirrorReaper.SCALE
ENT.SpawnHealth = UKMirrorReaper.HAND_HP
ENT.CollisionBounds = Vector( 30, 30, 200 ) * UKMirrorReaper.SCALE
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Light"

ENT.UKMR_IsHand = true

local UNIT = UKMirrorReaper.UNIT
local SCALE = UKMirrorReaper.SCALE

ENT.MeleeAttackRange = 3 * UNIT
ENT.ReachEnemyRange = 2 * UNIT
ENT.Acceleration = 50 * UNIT -- canon agent acceleration 50
ENT.Deceleration = 50 * UNIT
ENT.WalkSpeed = UKMirrorReaper.HAND_SPEED
ENT.RunSpeed = UKMirrorReaper.HAND_SPEED
ENT.MaxYawRate = 500
ENT.JumpHeight = 60
ENT.StepHeight = 30
ENT.UseWalkframes = false

ENT.IdleAnimation = "HandIdle"
ENT.WalkAnimation = "HandIdle"
ENT.RunAnimation = "HandIdle"
ENT.JumpAnimation = "HandIdle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "HandIdle"
-- the base multiplies this blindly whenever the bot is airborne — nil crashes
-- OnUpdateAnimation (ultrakillbase_nextbot.lua:469): spawn AI freeze + parry error
ENT.FallingAnimRate = 1

if SERVER then

  function ENT:CustomInitialize()
    self:SetModel( UKMirrorReaper.HAND_MODEL )
    self.UKMR_HitCooldowns = {}
    self.UKMR_DieAt = CurTime() + UKMirrorReaper.HAND_LIFETIME
    self.UKMR_Launched = false
    -- canon ParryHelper is always live on the hurt zone
    self:SetParryable( true )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:EmitSound( UKMirrorReaper.SOUND.GroundwaveLoop, 85, 100, 0.66 )
  end

  -- canon HurtZone: 20 dmg, 1 s per-target cooldown, dashing player is safe
  function ENT:UKMR_TryHurt( ent )
    if not IsValid( ent ) or ent == self then return end
    if ent.UKMR_IsHand or ent.UKMR_IsMirrorReaper then return end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then return end
    local now = CurTime()
    if ( self.UKMR_HitCooldowns[ ent ] or 0 ) > now then return end
    -- canon ignoreDashingPlayer
    if ent:IsPlayer() and ent:GetVelocity():Length2D() > 600 then return end

    self.UKMR_HitCooldowns[ ent ] = now + 1.0
    -- round-3 sweep: pass the canon number, the shared scaler lands x100 on
    -- pack NPCs (the raw HAND_ENEMY_DAMAGE=5000 double-dipped the x20)
    local damage = UKMirrorReaper.HAND_DAMAGE
    local dmg = DamageInfo()
    dmg:SetDamage( UKMirrorReaper.ScaleAttackDamage( ent, damage,
      IsValid( self.UKMR_Owner ) and self.UKMR_Owner or self ) )
    dmg:SetDamageType( DMG_SLASH )
    dmg:SetAttacker( IsValid( self.UKMR_Owner ) and self.UKMR_Owner or self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    dmg:SetDamageForce( ( ent:WorldSpaceCenter() - self:WorldSpaceCenter() ):GetNormalized() * 800 )
    ent:TakeDamageInfo( dmg )

    local grab = self:LookupSequence( "HandGrab" )
    if grab and grab >= 0 then
      self:ResetSequence( grab )
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end
  end

  function ENT:CustomThink()
    if self.UKMR_Dead then return end
    local now = CurTime()

    -- canon lifetime 15 s, then fade out
    if now >= self.UKMR_DieAt then
      self.UKMR_Dead = true
      self:Remove()
      return
    end

    -- canon: the hand is soaked in blood — smear a trail on the floor
    if now >= ( self.UKMR_NextBlood or 0 ) then
      self.UKMR_NextBlood = now + math.Rand( 0.15, 0.35 )
      local base = self:GetPos() + Vector( math.Rand( -12, 12 ), math.Rand( -12, 12 ), 10 )
      util.Decal( "Blood", base, base - Vector( 0, 0, 60 ), self )
    end

    if self:IsAIDisabled() then return end -- ai_disabled: no contact damage

    if self.UKMR_Launched then
      -- parried: a flying battering ram — hurts enemies it passes through
      for _, ent in ipairs( ents.FindInSphere( self:WorldSpaceCenter(), 2 * UNIT * SCALE ) ) do
        if ent ~= self and IsValid( ent ) and ( ent:IsNPC() or ent:IsNextBot() )
            and not ent.UKMR_IsHand then
          self:UKMR_TryHurt( ent )
        end
      end
      if self:IsOnGround() and self:GetVelocity():Length() < 100 then
        self:UKMR_Break( nil )
      end
      return
    end

    -- contact damage while chasing
    for _, ent in ipairs( ents.FindInSphere( self:WorldSpaceCenter(), 1.8 * UNIT * SCALE ) ) do
      self:UKMR_TryHurt( ent )
    end
  end

  -- canon Breakable (weak): hitscan/projectile chips break it fast, but the
  -- bestiary is explicit: "explosions do not damage them"
  function ENT:OnTakeDamage( dmg, hitgroup )
    -- engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
    -- OnInjured re-calls it; no DrGBase gate here (no AddNextbot on the hand),
    -- so gate manually or the base DamageMultiplier runs twice (x100)
    if not isnumber( hitgroup ) then return end
    if self.UKMR_Dead then return end
    if bit.band( dmg:GetDamageType(), DMG_BLAST ) ~= 0 then return end
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end

  -- canon: "can be parried to launch them away in direction of aim, 5 DP"
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    -- canon parry = launch, not a kill: strip the base +5000 bonus, the
    -- 3000 HP hand would die mid-launch otherwise
    dmg:SetDamage( math.max( dmg:GetDamage() - 5000, 0 ) )
    self.UKMR_Launched = true
    self.CantMove = true
    self:SetParryable( false )
    local aim = IsValid( ply ) and ply:GetAimVector() or self:GetForward()
    self:LeaveGround()
    self.loco:SetVelocity( aim * ( 60 * UNIT ) )
  end

  function ENT:UKMR_Break( attacker )
    if self.UKMR_Broken then return end
    self.UKMR_Broken = true
    self:EmitSound( UKMirrorReaper.SOUND.HandBreak, 88, 100, 0.4 )
    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "cball_explode", fx, true, true )
    -- canon: destroying a Phantom Hand grants a full blood heal
    if IsValid( attacker ) and attacker:IsPlayer() and attacker:Alive() then
      attacker:SetHealth( attacker:GetMaxHealth() )
    end
    self:Remove()
  end

  function ENT:OnDeath( dmg, hitgroup )
    self.UKMR_Dead = true
    self:UKMR_Break( IsValid( dmg ) and dmg:GetAttacker() or nil )
    return dmg
  end

end

if CLIENT then

  -- canon "ghostly, bloody hand": constant dark-red drips falling off the mesh
  function ENT:CustomThink()
    if not self.UKMR_Emitter then
      self.UKMR_Emitter = ParticleEmitter( self:GetPos() )
    end
    if not self.UKMR_Emitter then return end
    if CurTime() < ( self.UKMR_NextDrip or 0 ) then return end
    self.UKMR_NextDrip = CurTime() + 0.08

    local mins, maxs = self:GetCollisionBounds()
    for _ = 1, 2 do
      local pos = self:GetPos() + Vector(
        math.Rand( mins.x, maxs.x ),
        math.Rand( mins.y, maxs.y ),
        math.Rand( maxs.z * 0.2, maxs.z * 0.95 ) )
      local p = self.UKMR_Emitter:Add( "effects/blood_core", pos )
      if p then
        p:SetVelocity( Vector( math.Rand( -8, 8 ), math.Rand( -8, 8 ), math.Rand( -20, 0 ) ) )
        p:SetGravity( Vector( 0, 0, -500 ) )
        p:SetDieTime( math.Rand( 0.4, 0.8 ) )
        p:SetStartAlpha( 230 )
        p:SetEndAlpha( 120 )
        p:SetStartSize( math.Rand( 2, 5 ) )
        p:SetEndSize( 1 )
        p:SetColor( 140, 10, 10 )
        p:SetLighting( false )
        p:SetCollide( true )
        p:SetBounce( 0 )
      end
    end
  end

  function ENT:OnRemove()
    if self.UKMR_Emitter then
      self.UKMR_Emitter:Finish()
      self.UKMR_Emitter = nil
    end
  end

end
