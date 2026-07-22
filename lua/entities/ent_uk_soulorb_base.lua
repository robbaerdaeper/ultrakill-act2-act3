-- Soul Orb base (canon Bonus prefab: floating sphere, random slow rotation,
-- looping hum at pitch 0.5 / vol 0.25, point light, shatters into particles of
-- its colour on player touch + ParryFlash for the picker).

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Soul Orb"
ENT.Author = "ultragmod"
ENT.Category = "ULTRAKILL"
ENT.Spawnable = false

ENT.OrbModel = "models/hunter/misc/sphere025x025.mdl"
ENT.OrbModelFallback = "models/dav0r/hoverball.mdl"
ENT.OrbRadius = 35
ENT.CoreSprite = true -- small bright core in the middle (gold orb turns it off)
ENT.DrawSphere = true -- render the sphere mesh (gold orb is glow + icon only)
ENT.OrbMaterial = "ultrakill_prelude_test/soulorb/bonus_white"
ENT.OrbColor = Color(255, 255, 255)     -- break particles / glow sprite tint
ENT.LightColor = Color(255, 255, 255)   -- canon Point light colour
ENT.HumSound = nil                      -- looping wav (smpl chunk)
ENT.HumPitch = 50                       -- canon AudioSource pitch 0.5
ENT.HumVolume = 0.25                    -- canon AudioSource volume

local SND_DIR = "ultrakill_prelude_test/soulorb/"

if SERVER then

    -- live size tuning: override radius/height per orb without editing files.
    -- -1 = use the values baked into the Lua; spawned orbs update on the fly.
    for _, sfx in ipairs({ "red", "yellow" }) do
        CreateConVar("ultrakill_orb_" .. sfx .. "_radius", "-1", FCVAR_ARCHIVE,
            "Debug: radius of the " .. sfx .. " soul orb (-1 = baked default)")
        CreateConVar("ultrakill_orb_" .. sfx .. "_height", "-1", FCVAR_ARCHIVE,
            "Debug: height of the " .. sfx .. " orb center over the ground (-1 = baked default)")
    end

    function ENT:EffectiveRadius()
        local sfx = self:GetClass():match("^ent_uk_soulorb_(.+)$")
        local cv = sfx and GetConVar("ultrakill_orb_" .. sfx .. "_radius") or nil
        local v = cv and cv:GetFloat() or -1
        if v > 0 then return v end
        return self.OrbRadius
    end

    function ENT:EffectiveHeight()
        local sfx = self:GetClass():match("^ent_uk_soulorb_(.+)$")
        local cv = sfx and GetConVar("ultrakill_orb_" .. sfx .. "_height") or nil
        local v = cv and cv:GetFloat() or -1
        if v >= 0 then return v end
        return self.SpawnHeight or (self.OrbRadius + 1)
    end

    function ENT:ApplyOrbSize()
        local r = self:EffectiveRadius()
        local h = self:EffectiveHeight()

        -- scale the mesh ONLY if it is drawn (gold orb hides it). A scaled
        -- invisible model inflates the OBB and the sandbox spawner then drops
        -- the orb "in the sky".
        if self.DrawSphere and (self.BaseModelRadius or 0) > 0 then
            self:SetModelScale(r / self.BaseModelRadius, 0)
        end

        local b = r + 4
        self:SetCollisionBounds(Vector(-b, -b, -b), Vector(b, b, b))
        -- rebuilding the bounds can reset solid flags — re-assert the ghost-trigger
        self:SetTrigger(true)
        self:SetNotSolid(true)
        if self.GroundPos then
            self:SetPos(self.GroundPos + Vector(0, 0, h))
        end

        self:SetNW2Float("UKOrbR", r)
        self.AppliedR, self.AppliedH = r, h
    end

end

function ENT:Initialize()
    if SERVER then
        local mdl = util.IsValidModel(self.OrbModel) and self.OrbModel or self.OrbModelFallback
        self:SetModel(mdl)

        -- read OBBMaxs right after SetModel — after SetCollisionBounds it
        -- returns the collision box, not the model
        self.BaseModelRadius = self:OBBMaxs().x

        self:SetMaterial(self.OrbMaterial)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetTrigger(true)
        self:SetNotSolid(true) -- ghost box: fires Touch but never blocks movement
        self:SetUseType(SIMPLE_USE)
        self:DrawShadow(false)

        self:ApplyOrbSize()

        if self.HumSound then
            self:EmitSound(SND_DIR .. self.HumSound, 75, self.HumPitch, self.HumVolume)
        end

        -- the sandbox spawner places entities by model OBB, ignoring our
        -- SpawnFunction half the time — settle to the ground ourselves
        timer.Simple(0, function()
            if not IsValid(self) then return end
            local tr = util.TraceLine({
                start = self:GetPos() + Vector(0, 0, 8),
                endpos = self:GetPos() - Vector(0, 0, 2048),
                filter = self,
                mask = MASK_SOLID,
            })
            if tr.Hit then
                self.GroundPos = tr.HitPos
                self:SetPos(tr.HitPos + Vector(0, 0, self:EffectiveHeight()))
            end
        end)
    end

    if CLIENT then
        -- canon Bonus.Start: cRotation = Random(-5..5) per axis, * 5 deg/s
        self.SpinVel = Angle(math.Rand(-25, 25), math.Rand(-25, 25), math.Rand(-25, 25))
        self.SpinAng = Angle(math.Rand(0, 360), math.Rand(0, 360), 0)

        -- glow sprites are much wider than the (possibly hidden) model —
        -- widen render bounds or the glow pops out at screen edges
        local rb = self.OrbRadius * 3
        self:SetRenderBounds(Vector(-rb, -rb, -rb), Vector(rb, rb, rb))
    end
end

function ENT:OnPickup(ply)
    -- override in child
end

function ENT:Collect(ply, skipRangeCheck)
    if self.Collected then return end
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return end

    -- the box trigger over-reaches the sphere at its corners (a cube of
    -- half-width r+4 pokes ~1.7r diagonally) — gate the pickup by the true
    -- distance from the player's hull to the orb center
    if not skipRangeCheck then
        local r = (self.AppliedR or self.OrbRadius) + 2
        local nearest = ply:NearestPoint(self:GetPos())
        if nearest:DistToSqr(self:GetPos()) > r * r then return end
    end

    self.Collected = true

    self:OnPickup(ply)

    local pos = self:WorldSpaceCenter()
    sound.Play(SND_DIR .. "break.wav", pos, 90, math.random(98, 102), 1)

    local fx = EffectData()
    fx:SetOrigin(pos)
    fx:SetStart(Vector(self.OrbColor.r, self.OrbColor.g, self.OrbColor.b))
    util.Effect("uk_soulorb_break", fx, true, true)

    if UKSoulOrbs then UKSoulOrbs.PickupFlash(ply) end

    if self.HumSound then
        self:StopSound(SND_DIR .. self.HumSound)
    end
    self:Remove()
end

if SERVER then

    function ENT:Touch(ent)
        self:Collect(ent)
    end

    function ENT:StartTouch(ent)
        self:Collect(ent)
    end

    function ENT:Use(activator)
        self:Collect(activator, true) -- +use already traced to us, no range gate
    end

    function ENT:Think()
        -- live debug: reapply size/height when the tuning convars change
        if self:EffectiveRadius() ~= self.AppliedR
            or self:EffectiveHeight() ~= self.AppliedH then
            self:ApplyOrbSize()
        end
        self:NextThink(CurTime() + 0.25)
        return true
    end

    function ENT:OnRemove()
        if self.HumSound then
            self:StopSound(SND_DIR .. self.HumSound)
        end
    end

    function ENT:SpawnFunction(ply, tr, class)
        if not tr.Hit then return end
        local ent = ents.Create(class)
        -- rest on the ground, no hovering (SpawnHeight can sink the sphere)
        local h = ent.SpawnHeight or ((ent.OrbRadius or 15) + 1)
        ent:SetPos(tr.HitPos + tr.HitNormal * h)
        ent:Spawn()
        ent:Activate()
        return ent
    end

end

if CLIENT then

    local glowMat = Material("sprites/light_glow02_add")

    function ENT:Think()
        -- canon Bonus.Update: transform.Rotate(cRotation * dt * 5)
        if self.SpinAng then
            self.SpinAng = self.SpinAng + self.SpinVel * FrameTime()
            self:SetRenderAngles(self.SpinAng)
        end
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        -- no bobbing: the orb stands still (only the canon slow spin)
        local pos = self:GetPos()

        local r = self:GetNW2Float("UKOrbR", 0)
        if r <= 0 then r = self.OrbRadius end
        if r ~= self.LastRenderR then
            self.LastRenderR = r
            local rb = r * 3
            self:SetRenderBounds(Vector(-rb, -rb, -rb), Vector(rb, rb, rb))
        end

        if self.DrawSphere then
            self:DrawModel()
        end

        local c = self.OrbColor
        render.SetMaterial(glowMat)
        render.DrawSprite(pos, r * 5.5, r * 5.5, Color(c.r, c.g, c.b, 120))
        if self.CoreSprite then
            render.DrawSprite(pos, r * 2.3, r * 2.3, Color(255, 255, 255, 180))
        end

        self:DrawInner(pos, r)

        -- canon Point light: intensity 10, range 5 m
        local dl = DynamicLight(self:EntIndex())
        if dl then
            local lc = self.LightColor
            dl.pos = pos
            dl.r, dl.g, dl.b = lc.r, lc.g, lc.b
            dl.brightness = 2
            dl.decay = 1000
            dl.size = 190
            dl.dietime = CurTime() + 0.1
        end
    end

    function ENT:DrawInner(pos, r)
        -- override in child (gold orb draws the dual wield sprite)
    end

end
