-- lua/entities/ultrakill_test_gabriel2_zwei_projectile.lua
-- Gabriel 2nd spiral sword (canon GabrielThrownZwei inside GabrielSummonedSwords).
-- Modes (driven by the Gabriel NPC): "orbit" (shield ring around Gabriel, deals
-- contact damage, undeflectable), "formation" (ring around the player,
-- colliders off — canon SummonedSwords.Begin on Brutal+), "stab" (150 m/s
-- dash after the yellow flash; breaks on walls, deflectable).

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGabriel2 then include( "autorun/ultrakill_test_gabriel2_shared.lua" ) end

ENT.Base = "ultrakillbase_projectile"

ENT.PrintName = "Gabriel Spiral Sword"
ENT.Category = UKGabriel2.CATEGORY
ENT.Models = { UKGabriel2.MODEL_ZWEI }
ENT.ModelScale = 1
ENT.Spawnable = false

ENT.UltrakillBase_HomingType = -1
-- canon: unparryable/undeflectable until the StopSpinning flash
ENT.UltrakillBase_Parryable = false
ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 9, 9, 9 ) -- x0.45 rescale

local UNIT = UKGabriel2.UNIT

if SERVER then

  function ENT:CustomInitialize()
    self.UKG2Z_Mode = self.UKG2Z_Mode or "orbit"
    self.UKG2Z_HitCD = 0
    self:EmitSound( UKGabriel2.SOUND.SummonSpawn, 70, math.random( 90, 110 ), 0.6 )
    -- failsafe: never outlive a stuck controller
    SafeRemoveEntityDelayed( self, 30 )
  end

  function ENT:UKG2Z_Break( silent )
    if self.UKG2Z_Broken or not IsValid( self ) then return end
    self.UKG2Z_Broken = true
    if not silent then
      self:EmitSound( UKGabriel2.SOUND.WeaponBreak, 75, math.random( 90, 110 ), 0.9 )
      local fx = EffectData()
      fx:SetOrigin( self:WorldSpaceCenter() )
      fx:SetMagnitude( 2 )
      fx:SetScale( 1.5 )
      fx:SetRadius( 3 )
      util.Effect( "Sparks", fx, true, true )
    end
    self:Remove()
  end

  -- canon SpiralStab: colliders back on, speed 150 m/s, deflectable
  function ENT:UKG2Z_Stab( dir )
    self.UKG2Z_Mode = "stab"
    self:SetParryable( true )
    self:SetAngles( dir:Angle() )
    self:SetVelocity( dir * UKGabriel2.SPIRAL_STAB_SPEED )
    self:EmitSound( UKGabriel2.SOUND.Swing, 75, math.random( 110, 130 ), 0.8 )
    SafeRemoveEntityDelayed( self, 3 )
  end

  function ENT:UKG2Z_DealDamage( ent )
    local owner = self.UKG2Z_Owner
    local dmg = DamageInfo()
    dmg:SetDamage( UKGabriel2.ScaleAttackDamage( ent, UKGabriel2.DMG.ZWEI, self:GetOwner() ) )
    dmg:SetDamageType( DMG_SLASH )
    dmg:SetAttacker( IsValid( owner ) and owner or self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    dmg:SetDamageForce( self:GetForward() * 2000 )
    ent:TakeDamageInfo( dmg )
  end

  function ENT:CustomThink()
    -- orbit shield: contact damage via proximity (SetPos movement never
    -- triggers the base velocity-sweep collision)
    if self.UKG2Z_Mode == "orbit" and CurTime() > ( self.UKG2Z_HitCD or 0 ) then
      for _, ent in ipairs( ents.FindInSphere( self:WorldSpaceCenter(), 1.5 * UNIT ) ) do
        if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() )
            and not ent.UKG2_IsGabriel and ent ~= self.UKG2Z_Owner then
          self.UKG2Z_HitCD = CurTime() + 0.5
          self:UKG2Z_DealDamage( ent )
          self:UKG2Z_Break()
          return
        end
      end
    end
  end

  function ENT:OnContact( mEntity )
    -- canon: colliders disabled while forming around the player
    if self.UKG2Z_Mode == "formation" then return false end
    if IsValid( mEntity ) and ( mEntity:IsPlayer() or mEntity:IsNPC() or mEntity:IsNextBot() ) then
      if mEntity.UKG2_IsGabriel or mEntity == self.UKG2Z_Owner then return false end
      self:UKG2Z_DealDamage( mEntity )
    end
    -- world contact in stab mode: canon ignoreEnvironment=false after the stab
    self:UKG2Z_Break()
  end

  function ENT:OnTakeDamage( CDamageInfo )
    -- canon: deflectable only after the yellow flash (stab); orbit is immune
    if self.UKG2Z_Mode == "orbit" then return end
    local att = CDamageInfo:GetAttacker()
    if IsValid( att ) and att:IsPlayer() then
      self:UKG2Z_Break()
    end
  end

else -- CLIENT

  function ENT:CustomDraw()
    self:DrawModel()
  end

end

AddCSLuaFile()
