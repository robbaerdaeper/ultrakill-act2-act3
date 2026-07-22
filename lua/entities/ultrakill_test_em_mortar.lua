AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Defense System — Mortar Launcher (канон CentaurMortar).
-- MortarLauncher: залп каждые 7 с (первый 2 c), force 55 -> Hell Mortar
-- (60 dmg, bigExplosion, горизонтальный хоминг).

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_em_turret_base"
ENT.PrintName = "Earthmover Mortar"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKEarthmover.MODEL_MORTAR }
ENT.CollisionBounds = Vector( 110, 110, 340 )
ENT.SurroundingBounds = Vector( 150, 150, 380 )

ENT.UKEM_Kind = "mortar"
ENT.UKEM_HasDeploy = true
ENT.UKEM_FirstDelay = UKEarthmover.MORTAR_FIRST

if SERVER then

  function ENT:UKEM_CombatThink( enemy, now )
    if now < self.UKEM_NextFire then return end
    self.UKEM_NextFire = now + UKEarthmover.MORTAR_DELAY

    self:UKEM_PlaySeq( "shoot" )
    self:EmitSound( UKEarthmover.SOUND.MortarFire, 85, 95, 1.0 )

    local pos = self:UKEM_AttachPos( "muzzle" )
    local proj = self:CreateProjectile( "ultrakill_test_em_mortar_proj", true )
    if not IsValid( proj ) then return end
    proj:SetPos( pos )

    -- канон: миномёт стреляет вверх-вбок, дальше горизонтальный хоминг
    local targetPos = self:UKEM_TargetPos( enemy )
    local flat = targetPos - pos
    flat.z = 0
    local dir = ( flat:GetNormalized() * 0.55 + Vector( 0, 0, 1 ) ):GetNormalized()
    proj:SetAngles( dir:Angle() )
    proj:SetVelocity( dir * UKEarthmover.MORTAR_FORCE )
  end

end
