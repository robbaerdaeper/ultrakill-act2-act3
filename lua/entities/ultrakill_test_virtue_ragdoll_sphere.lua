local UltrakillBase = UltrakillBase
local SafeRemoveEntity = SafeRemoveEntity
local Angle = Angle
local AddCSLuaFile = AddCSLuaFile

if not UK_VIRTUE then include("ultrakill/virtue_constants.lua") end
if not DrGBase or not UltrakillBase then return end -- return if DrGBase or UltrakillBase isn't installed
ENT.Base = "ultrakillbase_projectile"

-- Misc --

ENT.PrintName = "Virtue Corpse"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/ultrakill/mesh/effects/projectiles/Mortar.mdl" }
ENT.ModelScale = 1
ENT.Spawnable = false

-- Collision --
ENT.UltrakillBase_CustomCollisionEnabled = true

-- Locomotion --
ENT.Gravity = true

ENT.UltrakillBase_HomingType = 3
ENT.UltrakillBase_HomingTurningMultiplier = 0
ENT.UltrakillBase_HomingTurningSpeed = 0

ENT.Effect = nil



if SERVER then


function ENT:CustomInitialize()

  UltrakillBase.SoundScript( "Ultrakill_VirtueDeath", self:GetPos(), self )
  self:SetRenderMode( RENDERMODE_TRANSCOLOR )
  self:SetColor(Color(255,255,255,0))

    self.effect = ents.Create("prop_effect") -- why is the virtue corpse a effecttt aaaaaaaaaaaaaahhh
    self.effect :SetModel("models/ultrakill_prelude_test/virtue_corpse.mdl")
    self.effect :SetPos(self:GetPos())
      if self.UKRS_Enraged then
      for i, m in ipairs(self.effect :GetMaterials()) do
        if string.find(string.lower(m), "sphere", 1, true) then
          self.effect :SetSubMaterial(i - 1, "models/ultrakill_test/virtue/virtue_sphere_enraged")
        end
      end
    end
    self.effect :Spawn()

    SafeRemoveEntityDelayed( self, 10 )
    
end

function ENT:CustomThink() 
 if IsValid(self.effect) then
  self.effect:SetPos(self:GetPos())
  self.effect:SetAngles(self:GetAngles())
 end
end


function ENT:OnTakeDamage( Dmg )

  self:CheckParry( Dmg )

  if not self:GetParried() and not self.HasExploded then

    self:OnContact()

  end

end


function ENT:OnContact( Ent )

  if self.HasExploded then return end

  self:UKRS_SoftExplode()

end

  function ENT:UKRS_SoftExplode()
    self.HasExploded = true
    local pos = self:GetPos()

    -- Канонный ULTRAKILL-взрыв (тот же, что мины/ракеты базы) + канон-звук.
    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetRadius(UK_VIRTUE.RAGDOLL_EXPLODE_RANGE / 150 * 100)
    util.Effect( "ultrakill_test_softexplosion", fx )

    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_VirtueShatter", self:GetPos() )
    end

    for _, ent in ipairs(ents.FindInSphere(pos, UK_VIRTUE.RAGDOLL_EXPLODE_RANGE)) do
      if not IsValid(ent) or ent == self then continue end
      if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
      local dir = ent:GetPos() - pos
      if dir:IsZero() then continue end
      dir.z = math.max(dir.z, 50)
      ent:SetVelocity(dir:GetNormalized() * UK_VIRTUE.RAGDOLL_KNOCKBACK)
    end
    self.effect:Remove()
    self:Remove()
  end

end


AddCSLuaFile()
