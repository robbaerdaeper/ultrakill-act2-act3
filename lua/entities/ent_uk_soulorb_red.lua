-- Red Soul Orb (canon BonusSuperCharge): NewMovement.SuperCharge() =
-- "GetHealth(100, silent); hp = 200" — full heal incl. hard damage, then 200 HP
-- flat (overheal past max health). Hum = 'Throat Drone' loop, red point light.

AddCSLuaFile()

ENT.Base = "ent_uk_soulorb_base"
ENT.Type = "anim"
ENT.PrintName = "Soul Orb (Red — 200 HP)"
ENT.Category = "ULTRAKILL"
ENT.Spawnable = true

ENT.OrbRadius = 30 -- the solid sphere reads much bigger than the gold glow
ENT.SpawnHeight = 40 -- tuned: sphere floats clear of the ground
ENT.OrbMaterial = "ultrakill_prelude_test/soulorb/bonus_red"
ENT.OrbColor = Color(255, 55, 55)
ENT.LightColor = Color(255, 0, 3) -- canon (1, 0, 0.01)
ENT.HumSound = "hum_red.wav"

function ENT:OnPickup(ply)
    if CLIENT then return end
    -- canon sets hp = 200 flat; never rob modded players who are above that
    ply:SetHealth(math.max(ply:Health(), 200))

    -- canon first-pickup popup
    if not ply.UKSoulOrbs_SawRedHint then
        ply.UKSoulOrbs_SawRedHint = true
        ply:PrintMessage(HUD_PRINTCENTER, "RED SOUL ORBS give 200 HEALTH. Overheal cannot be regained.")
    end
end
