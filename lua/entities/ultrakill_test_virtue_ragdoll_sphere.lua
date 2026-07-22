-- lua/entities/ultrakill_test_virtue_ragdoll_sphere.lua
-- Посмертный труп Virtue = ТОЛЬКО голубой шар с розовым ромбом-ядром.
-- Модель virtue_corpse.mdl вообще не содержит цепей/короны (выброшены при компиляции),
-- поэтому белым цепям взяться неоткуда. Падает, катится, при ударе — канон ULTRAKILL-взрыв.

AddCSLuaFile()

if not UK_VIRTUE then include("ultrakill/virtue_constants.lua") end

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Virtue Corpse"
ENT.Author      = "ultragmod"
ENT.Spawnable   = false

local CORPSE_MDL = "models/ultrakill_prelude_test/virtue_corpse.mdl"

if CLIENT then
  util.PrecacheModel(CORPSE_MDL)
end

if SERVER then
  function ENT:Initialize()
    self:SetModel(CORPSE_MDL)
    -- Только сфера красная в ярости; ядро (virtue_core) — дефолтный розовый ромб.
    if self.UKRS_Enraged then
      for i, m in ipairs(self:GetMaterials()) do
        if string.find(string.lower(m), "sphere", 1, true) then
          self:SetSubMaterial(i - 1, "models/ultrakill_test/virtue/virtue_sphere_enraged")
        end
      end
    end

    -- У модели нет .phy → катящаяся сфера-физика.
    self:PhysicsInitSphere(28, "metal")
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self:SetCollisionBounds(Vector(-28, -28, -28), Vector(28, 28, 28))
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
      phys:Wake()
      phys:EnableGravity(true)
      phys:SetMass(20)
    end

    self.UKRS_SpawnTime = CurTime()
    self.UKRS_Exploded  = false
    timer.Simple(UK_VIRTUE.RAGDOLL_FADE_TIME, function()
      if IsValid(self) then self:Remove() end
    end)
  end

  function ENT:PhysicsCollide(data, physobj)
    if self.UKRS_Exploded then return end
    if data.Speed < 100 then return end
    self:UKRS_SoftExplode()
  end

  function ENT:UKRS_SoftExplode()
    self.UKRS_Exploded = true
    local pos = self:GetPos()

    -- Канон: посмертный бабах Virtue — БЕЗУРОННАЯ ударная волна (воркшоп-репорт
    -- 2026-07-10: боевой Ultrakill_Explosion с TakeDamage(50) читался как «взрыв,
    -- который зачем-то ранит»). Визуал = прозрачный софт-взрыв базы Кевина.
    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetRadius(UK_VIRTUE.RAGDOLL_EXPLODE_RANGE / 150 * 100)
    util.Effect("Ultrakill_Soft_Explosion", fx, true, true)
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript("Ultrakill_Explosion_1", pos)
    end

    for _, ent in ipairs(ents.FindInSphere(pos, UK_VIRTUE.RAGDOLL_EXPLODE_RANGE)) do
      if not IsValid(ent) or ent == self then continue end
      if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
      local dir = ent:GetPos() - pos
      if dir:IsZero() then continue end
      dir.z = math.max(dir.z, 50)
      ent:SetVelocity(dir:GetNormalized() * UK_VIRTUE.RAGDOLL_KNOCKBACK)
    end
    self:Remove()
  end
end

if CLIENT then function ENT:Draw() self:DrawModel() end end
