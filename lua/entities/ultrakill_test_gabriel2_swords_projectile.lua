-- lua/entities/ultrakill_test_gabriel2_swords_projectile.lua
-- Gabriel 2nd thrown combined swords (canon GabrielCombinedSwords projectile):
-- speed 50 m/s, homing turnSpeed 75 deg/s (canon homingType 4 == the base's
-- DefaultHoming), damage 35, parry-deflectable (feedbacker needs "proj" in the
-- class name). On any death the real swords teleport back to Gabriel's hands
-- (canon GabrielCombinedSwordsThrown.OnDestroy).

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGabriel2 then include( "autorun/ultrakill_test_gabriel2_shared.lua" ) end

ENT.Base = "ultrakillbase_projectile"

ENT.PrintName = "Gabriel Combined Swords"
ENT.Category = UKGabriel2.CATEGORY
ENT.Models = { UKGabriel2.MODEL_COMBINED }
ENT.ModelScale = 1
ENT.Spawnable = false

-- canon Projectile: homingType 4 -> constant turn at turnSpeed deg/s
ENT.UltrakillBase_HomingType = 4
ENT.UltrakillBase_HomingSpeed = UKGabriel2.THROWN_SPEED
ENT.UltrakillBase_HomingTurningSpeed = UKGabriel2.THROWN_TURNRATE
ENT.UltrakillBase_HomingPredictiveMultiplier = 0

ENT.UltrakillBase_Parryable = true
ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 14, 14, 14 ) -- x0.45 rescale

local UNIT = UKGabriel2.UNIT

if SERVER then

  function ENT:CustomInitialize()
    -- canon: GabrielSwing2Loop while the swords fly (smpl-looped WAV)
    self.UKG2S_Loop = CreateSound( self, UKGabriel2.SOUND.SwingLoop )
    if self.UKG2S_Loop then self.UKG2S_Loop:Play() end
    -- failsafe so a lost projectile never wedges Gabriel's attack gate
    SafeRemoveEntityDelayed( self, 20 )
  end

  function ENT:OnTakeDamage( CDamageInfo )
    self:CheckReflect( CDamageInfo )
    self:CheckParry( CDamageInfo )
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then
      -- canon: the parried throw slams back into Gabriel and explodes
      -- (Projectile.damage 35 x enemyDamageMultiplier 0.25, pack x1000)
      return self:ParryCollide( UKGabriel2.DMG.THROWN * 0.25 * 1000 )
    end

    local pos = self:GetPos()
    local owner = self.UKG2S_Owner

    if IsValid( mEntity ) and ( mEntity:IsPlayer() or mEntity:IsNPC() or mEntity:IsNextBot() ) then
      if mEntity.UKG2_IsGabriel then return false end -- pass through Gabriels
      local dmg = DamageInfo()
      dmg:SetDamage( UKGabriel2.ScaleAttackDamage( mEntity, UKGabriel2.DMG.THROWN, self:GetOwner() ) )
      dmg:SetDamageType( DMG_SLASH )
      dmg:SetAttacker( IsValid( owner ) and owner or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( mEntity:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetVelocity():GetNormalized() * 3000 )
      mEntity:TakeDamageInfo( dmg )
    else
      -- canon: breaks on the environment with a real Explosion
      local fx = EffectData()
      fx:SetOrigin( pos )
      fx:SetRadius( 3 * UNIT )
      util.Effect( "Explosion", fx, true, true )
      for _, ent in ipairs( ents.FindInSphere( pos, 3 * UNIT ) ) do
        if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() )
            and not ent.UKG2_IsGabriel then
          local dmg = DamageInfo()
          dmg:SetDamage( UKGabriel2.ScaleAttackDamage( ent, UKGabriel2.DMG.THROWN, self:GetOwner() ) )
          dmg:SetDamageType( DMG_BLAST )
          dmg:SetAttacker( IsValid( owner ) and owner or self )
          dmg:SetInflictor( self )
          dmg:SetDamagePosition( ent:WorldSpaceCenter() )
          dmg:SetDamageForce( ( ent:WorldSpaceCenter() - pos ):GetNormalized() * 4000 )
          ent:TakeDamageInfo( dmg )
        end
      end
    end
  end

  function ENT:OnRemove()
    if self.UKG2S_Loop then self.UKG2S_Loop:Stop() end
    local owner = self.UKG2S_Owner
    if IsValid( owner ) and owner.UKG2_SwordsReturned then
      owner:UKG2_SwordsReturned()
    end
  end

else -- CLIENT

  function ENT:CustomThink()
    self:AngleFollowVelocity()
  end

  function ENT:CustomDraw()
    -- canon Rotator: spin around the flight axis at 2700 deg/s
    local vel = self:GetVelocity()
    local dir = vel:LengthSqr() > 1 and vel:GetNormalized() or self:GetForward()
    local ang = dir:Angle()
    ang:RotateAroundAxis( dir, ( CurTime() * 2700 ) % 360 )
    self:SetRenderAngles( ang )
    self:DrawModel()
  end

end

AddCSLuaFile()
