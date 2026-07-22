-- Gold Soul Orb (canon BonusDualWield Variant): +1 dual wield copy per pickup,
-- no stack limit; 30s juice, timer refreshes only if the new duration beats
-- the remaining one. CameraShake(0.35) + PowerUpDualGet boom (BlackHoleLaunch
-- @ pitch 0.5, baked into the wav). Gold light (1, 0.6, 0), floating
-- 'dualwieldpowerup' sprite inside the orb.

AddCSLuaFile()

ENT.Base = "ent_uk_soulorb_base"
ENT.Type = "anim"
ENT.PrintName = "Soul Orb (Gold — Dual Wield)"
ENT.Category = "ULTRAKILL"
ENT.Spawnable = true

ENT.OrbMaterial = "ultrakill_prelude_test/soulorb/bonus_gold"
ENT.OrbColor = Color(255, 170, 0)
ENT.LightColor = Color(255, 153, 0) -- canon (1, 0.6, 0)
ENT.HumSound = "hum_gold.wav"
ENT.CoreSprite = false -- no bright blob in the middle
ENT.DrawSphere = false -- no sphere mesh: gold glow + revolver badge only
ENT.OrbRadius = 40 -- pure glow reads smaller than a solid sphere — oversize it
ENT.SpawnHeight = 40 -- tuned: glow floats clear of the ground

local SND_DIR = "ultrakill_prelude_test/soulorb/"

function ENT:OnPickup(ply)
    if CLIENT then return end
    if UKSoulOrbs then UKSoulOrbs.AddDualWield(ply) end

    -- canon CameraController.CameraShake(0.35) + PowerUpDualGet sound
    util.ScreenShake(self:GetPos(), 5, 5, 0.35, 600)
    sound.Play(SND_DIR .. "dualwield_get.wav", self:GetPos(), 85, 100, 0.85)
end

if CLIENT then

    local iconMat = Material("ultrakill_prelude_test/soulorb/dualwield_icon")

    function ENT:DrawInner(pos, r)
        -- canon 'dualwieldpowerup' badge, camera-facing at the orb center
        local eye = EyePos()
        local dir = (eye - pos):GetNormalized()
        local sz = (r or self.OrbRadius) * 1.5
        render.SetMaterial(iconMat)
        render.DrawQuadEasy(pos + dir * 2, dir, sz, sz, color_white, 180)
    end

end
