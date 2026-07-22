AddCSLuaFile()

local UltrakillBase = UltrakillBase
local Material = Material
local Color = Color
local RSetMaterial = CLIENT and render.SetMaterial
local RDrawSprite = CLIENT and render.DrawSprite

if not DrGBase or not UltrakillBase then return end

-- Big Johninator Malicious Beam (canon altBullet: RevolverBeam beamType 2,
-- hitParticle 'Explosion Big'). Aimed at the ground under the target
-- (alwaysAimAtGround=1). Canon: NOT parryable, but punch-returnable — the
-- base CheckReflect handles the feedbacker (maliciousface projectile pattern).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Johninator Malicious Beam"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 0.5
ENT.Spawnable = false
ENT.Gravity = false
ENT.UltrakillBase_Parryable = false
ENT.UltrakillBase_CustomCollisionEnabled = true

if SERVER then

  function ENT:CustomInitialize()
    self:SetMaterial( "models/ultrakill/vfx/Skulls/Skull2" )
    util.SpriteTrail( self, 0, Color( 255, 60, 30 ), false, 22, 4, 0.18,
      2 / 26 * 0.5, "trails/laser" )
    SafeRemoveEntityDelayed( self, 5 )
  end

  function ENT:UKJ_Explode()
    if self.UKJ_Exploded then return end
    self.UKJ_Exploded = true
    -- canon Explosion Big: the beam hit is a full-size explosion
    UltrakillBase.SoundScript( "Ultrakill_Explosion_2", self:GetPos() )
    self:Explosion( self:GetPos(), UKJohninator.BEAM_DAMAGE, nil, 250,
      0.25, self:GetOwner() )
    self:CreateExplosion( self:GetPos(), self:GetAngles(), 1.4 )
    self:ScreenShake( 1500, 8, 1, 4000 )
    self:Remove()
  end

  function ENT:OnContact( mEntity )
    self:UKJ_Explode()
  end

  function ENT:OnTakeDamage( dmg )
    -- punch return only (canon: unparriable); reflect flips owner + velocity
    self:CheckReflect( dmg )
  end

else

  local SpriteMaterial = Material( "particles/ultrakill/Charge" )
  local SpriteColor = Color( 255, 40, 20, 255 )

  function ENT:CustomThink()
    self:AngleFollowVelocity()
  end

  function ENT:CustomDraw()
    RSetMaterial( SpriteMaterial )
    RDrawSprite( self:GetPos(), 46, 46, SpriteColor )
  end

end

AddCSLuaFile()
