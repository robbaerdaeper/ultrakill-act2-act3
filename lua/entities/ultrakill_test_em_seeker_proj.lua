AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Hell Seeker (canon 'Projectile Homing': damage 30, homingType 1,
-- медленный неотступный хоминг). Зелёный черепа-орб. Парируемый.
-- Тот же класс использует Brain как «giant hell seeker» (scale x3, 10 c жизни).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Earthmover Hell Seeker"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 1.0
ENT.Spawnable = false
ENT.Gravity = false

-- канон homingType 1: InstantHoming (вектор всегда на цель)
ENT.UltrakillBase_HomingType = 1
ENT.UltrakillBase_HomingSpeed = UKEarthmover.SEEKER_SPEED
ENT.UltrakillBase_HomingTurningSpeed = 90
ENT.UltrakillBase_HomingTurningMultiplier = 1

ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 12, 12, 12 )

-- параметры «гиганта» (Brain выставляет UKEM_Giant = true перед Spawn)
ENT.UKEM_Giant = false

if SERVER then

  function ENT:CustomInitialize()
    self:SetMaterial( "models/ultrakill/vfx/skulls/skull2_4" )

    if self.UKEM_Giant then
      -- канон: Projectile Homing scale 5, RemoveOnTime 10, парируемый
      self:SetColor( Color( 120, 190, 255, 255 ) )
      self:SetModelScale( 3.0 )
      self.UltrakillBase_HomingSpeed = UKEarthmover.BRAIN_ORB_SPEED
      self.UltrakillBase_CustomCollisionBounds = Vector( 34, 34, 34 )
      self:EmitSound( UKEarthmover.SOUND.BrainOrb, 80, 90, 0.7 )
      SafeRemoveEntityDelayed( self, 10 )
    else
      self:SetColor( Color( 120, 255, 140, 255 ) )
      self:EmitSound( UKEarthmover.SOUND.SeekerLoop, 75, 110, 0.5 )
      SafeRemoveEntityDelayed( self, 12 )
    end
  end

  function ENT:OnTakeDamage( CDamageInfo )
    self:CheckReflect( CDamageInfo )
    self:CheckParry( CDamageInfo )
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then return self:ParryCollide( 25000 ) end

    self:StopSound( UKEarthmover.SOUND.SeekerLoop )
    local ed = EffectData()
    ed:SetOrigin( self:GetPos() )
    util.Effect( "cball_explode", ed )
    self:EmitSound( "ambient/levels/labs/electric_explosion2.wav", 80, 120, 0.7 )

    if IsValid( mEntity ) and ( mEntity:IsPlayer() or mEntity:IsNPC() or mEntity:IsNextBot() ) then
      -- канон: отражённый в мозг снаряд бьёт x1.4
      local dmgAmount = self.UKEM_Giant and UKEarthmover.BRAIN_ORB_DAMAGE
        or UKEarthmover.SEEKER_DAMAGE
      if self:GetParried() or self.UltrakillBase_Reflected then
        if mEntity.UKEM_IsBrain then dmgAmount = dmgAmount * UKEarthmover.REFLECT_MULT end
      end
      UKEarthmover.DealDamage( mEntity, self, self:GetOwner(), dmgAmount,
        DMG_ENERGYBEAM )
    end
    self:Remove()
  end

  function ENT:OnRemove()
    self:StopSound( UKEarthmover.SOUND.SeekerLoop )
    self:StopSound( UKEarthmover.SOUND.BrainOrb )
  end

else

  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL_GREEN = Color( 130, 255, 150, 255 )
  local COL_BLUE = Color( 130, 190, 255, 255 )
  local COL_CORE = Color( 240, 255, 245, 255 )

  function ENT:CustomInitialize()
    local rb = Vector( 300, 300, 300 )
    self:SetRenderBounds( -rb, rb )
  end

  function ENT:CustomDraw()
    local pos = self:GetPos()
    local giant = self:GetModelScale() > 2
    local base = giant and 160 or 60
    render.SetMaterial( MAT_GLOW )
    local pulse = ( giant and 14 or 5 ) * math.sin( CurTime() * 9 )
    render.DrawSprite( pos, base + pulse, base + pulse, giant and COL_BLUE or COL_GREEN )
    render.DrawSprite( pos, base * 0.45, base * 0.45, COL_CORE )
  end

end

AddCSLuaFile()
