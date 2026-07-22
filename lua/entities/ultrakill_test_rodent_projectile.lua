local UltrakillBase = UltrakillBase
local SafeRemoveEntityDelayed = SafeRemoveEntityDelayed
local CurTime = CurTime
local ParticleEffect = ParticleEffect
local Vector = Vector
local Material = Material
local Color = Color
local RSetMaterial = CLIENT and render.SetMaterial
local RDrawSprite = CLIENT and render.DrawSprite
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
ENT.Base = "ultrakillbase_projectile"

-- Misc --

ENT.PrintName = "RodentHellSeeker"
ENT.Category = "UltrakillBase Test"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 0.6
ENT.Spawnable = false

-- Homing --

ENT.UltrakillBase_HomingType = 0
ENT.UltrakillBase_HomingSpeed = 10
ENT.UltrakillBase_HomingTurningMultiplier = 1.5

-- Collision --

ENT.UltrakillBase_CustomCollisionEnabled = true


if SERVER then


function ENT:CustomInitialize()

  self:ParticleEffectSlot( "Projectile_Trail", "Ultrakill_HomingOrb", { parent = self } )

  self:SetMaterial( "models/ultrakill_prelude_test/rodent/rodent_hellseeker" )

  UltrakillBase.SoundScript( "Ultrakill_MindFlayer_Projectile_Loop", self:GetPos(), self )

  SafeRemoveEntityDelayed( self, 5 )

end


function ENT:OnTakeDamage( CDamageInfo )

  self:CheckReflect( CDamageInfo )
  self:CheckParry( CDamageInfo )

end


function ENT:OnContact( mEntity )

  -- ParryCollide -> base Explosion nets a FIXED x40 on UK-nextbot victims
  -- (providence_shared recipe): 250 lands 10 000 — same as Kevin's parried
  -- Stray orb. The old 500 landed 20 000 and one-shot most of the pack.
  if self:GetParried() then return self:ParryCollide( 250 ) end

  UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
  ParticleEffect( "Ultrakill_HomingOrb_Impact", self:GetPos(), self:GetAngles() )
  ParticleEffect( "Ultrakill_ExplosionSmoke", self:GetPos(), self:GetAngles() )
  ParticleEffect( "Ultrakill_ExplosionSmokeLinger", self:GetPos(), self:GetAngles() )

  self:DealDamage( mEntity, 200, nil, DMG_BLAST )

end


else


function ENT:CustomThink()

  self:AngleFollowVelocity()

end


local SpriteMaterial = Material( "particles/ultrakill/Charge" )
local SpriteColor = Color( 13, 255, 0, 255 )


function ENT:CustomDraw()

  RSetMaterial( SpriteMaterial )

  RDrawSprite( self:GetPos(), 34, 34, SpriteColor )

end


end


AddCSLuaFile()
