AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Defense System rocket (canon RocketEnemy / Grenade, rocketSpeed 150).
-- Не трекает после запуска; выстрел по нему детонирует (Johninator-паттерн).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Earthmover Rocket"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/weapons/w_missile_launch.mdl" }
ENT.Spawnable = false
ENT.Gravity = false
ENT.UltrakillBase_Parryable = false
ENT.UltrakillBase_CustomCollisionEnabled = false

if SERVER then

  function ENT:CustomInitialize()
    self:SetColor( Color( 255, 80, 60, 255 ) )
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )

    util.SpriteTrail( self, 0, Color( 255, 90, 60 ), false, 12, 18, 0.3,
      2 / 16 * 0.5, "trails/smoke" )

    self.UKEM_LoopSound = CreateSound( self, UKEarthmover.SOUND.RocketLoop )
    self.UKEM_LoopSound:PlayEx( 0.7, 100 )

    SafeRemoveEntityDelayed( self, 10 )
  end

  function ENT:UKEM_Explode()
    if self.UKEM_Exploded then return end
    self.UKEM_Exploded = true
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
    self:Explosion( self:GetPos(), UKEarthmover.ROCKET_DAMAGE * 10, nil, 150,
      0.2, self:GetOwner() )
    self:CreateExplosion( self:GetPos(), self:GetAngles() )
    self:Remove()
  end

  function ENT:OnContact( mEntity )
    self:UKEM_Explode()
  end

  function ENT:OnTakeDamage( dmg )
    -- канон: ракеты можно сбить/вернуть (Freezeframe/магниты) — детонация,
    -- взрыв принадлежит атакующему
    self:SetOwner( dmg:GetAttacker() )
    self:UKEM_Explode()
  end

  function ENT:OnRemove()
    if self.UKEM_LoopSound then self.UKEM_LoopSound:Stop() end
  end

else

  function ENT:CustomThink()
    self:AngleFollowVelocity()
  end

end

AddCSLuaFile()
