AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Hell Mortar (canon 'Projectile Explosive HH': damage 60,
-- explosive + bigExplosion, homingType 3 = только горизонтальный доворот,
-- turnSpeed 25). Жёлтый большой взрыв. Парируемый (Projectile канон).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Earthmover Hell Mortar"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 1.4
ENT.Spawnable = false
ENT.Gravity = true

-- канон homingType 3: HorizontalOnlyHoming
ENT.UltrakillBase_HomingType = 3
ENT.UltrakillBase_HomingSpeed = UKEarthmover.MORTAR_FORCE
ENT.UltrakillBase_HomingTurningSpeed = UKEarthmover.MORTAR_TURN
ENT.UltrakillBase_HomingTurningMultiplier = 1

ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 14, 14, 14 )

if SERVER then

  function ENT:CustomInitialize()
    self:SetMaterial( "models/ultrakill/vfx/skulls/skull2_4" )
    self:SetColor( Color( 255, 210, 80, 255 ) )

    util.SpriteTrail( self, 0, Color( 255, 200, 60 ), false, 16, 24, 0.35,
      2 / 16 * 0.5, "trails/laser" )

    self:EmitSound( UKEarthmover.SOUND.SeekerLoop, 75, 90, 0.5 )
    SafeRemoveEntityDelayed( self, 15 )
  end

  function ENT:OnTakeDamage( CDamageInfo )
    self:CheckReflect( CDamageInfo )
    self:CheckParry( CDamageInfo )
  end

  function ENT:UKEM_Explode()
    if self.UKEM_Exploded then return end
    self.UKEM_Exploded = true
    self:StopSound( UKEarthmover.SOUND.SeekerLoop )
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
    -- канон bigExplosion: массивный жёлтый взрыв
    self:Explosion( self:GetPos(), UKEarthmover.MORTAR_DAMAGE * 10, nil, 260,
      0.25, self:GetOwner() )
    self:CreateExplosion( self:GetPos(), self:GetAngles() )
    self:Remove()
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then return self:ParryCollide( 25000 ) end
    self:UKEM_Explode()
  end

  function ENT:OnRemove()
    self:StopSound( UKEarthmover.SOUND.SeekerLoop )
  end

else

  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL = Color( 255, 210, 90, 255 )
  local COL_CORE = Color( 255, 250, 220, 255 )

  function ENT:CustomInitialize()
    local rb = Vector( 200, 200, 200 )
    self:SetRenderBounds( -rb, rb )
  end

  function ENT:CustomDraw()
    local pos = self:GetPos()
    render.SetMaterial( MAT_GLOW )
    local pulse = 5 * math.sin( CurTime() * 10 )
    render.DrawSprite( pos, 70 + pulse, 70 + pulse, COL )
    render.DrawSprite( pos, 34, 34, COL_CORE )
  end

end

AddCSLuaFile()
