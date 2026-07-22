AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end

-- Big Johninator rocket (canon RocketEnemy / Grenade, hitterWeapon rocket0).
-- Not parryable (canon), but shootable: damage detonates it in flight.
-- Projectile shape from SonaristicCatboy's ent_ultrakill_rocket (V Series).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Johninator Rocket"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/weapons/w_missile_launch.mdl" }
ENT.Spawnable = false
ENT.Gravity = false
ENT.UltrakillBase_Parryable = false
ENT.UltrakillBase_CustomCollisionEnabled = false

if SERVER then

  function ENT:CustomInitialize()
    self:SetColor( Color( 255, 191, 0, 255 ) )
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )

    util.SpriteTrail( self, 0, Color( 255, 200, 0 ), false, 10, 15, 0.25,
      2 / 16 * 0.5, "trails/smoke" )

    self.UKJ_LoopSound = CreateSound( self, UKJohninator.SOUND.RocketLoop )
    self.UKJ_LoopSound:PlayEx( 0.7, 100 )

    SafeRemoveEntityDelayed( self, 10 )
  end

  function ENT:UKJ_Explode()
    if self.UKJ_Exploded then return end
    self.UKJ_Exploded = true
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
    self:Explosion( self:GetPos(), UKJohninator.ROCKET_DAMAGE, nil, 150,
      0.2, self:GetOwner() )
    self:CreateExplosion( self:GetPos(), self:GetAngles() )
    self:Remove()
  end

  function ENT:OnContact( mEntity )
    self:UKJ_Explode()
  end

  function ENT:OnTakeDamage( dmg )
    -- canon: rockets are interactable — shooting one detonates it and the
    -- attacker owns the explosion (send it back with anything you have)
    self:SetOwner( dmg:GetAttacker() )
    self:UKJ_Explode()
  end

  function ENT:OnRemove()
    if self.UKJ_LoopSound then self.UKJ_LoopSound:Stop() end
  end

else

  function ENT:CustomThink()
    self:AngleFollowVelocity()
  end

end

AddCSLuaFile()
