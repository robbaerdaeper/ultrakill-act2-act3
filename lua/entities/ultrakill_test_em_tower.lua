AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Defense System — Seeker Tower (канон CentaurTower).
-- MortarLauncher: каждые 6 с (первый 2 c) -> Hell Seeker (30 dmg, хоминг).
-- Кончик светится зелёным за 1 с до выстрела (канон Sphere(1) чардж).

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_em_turret_base"
ENT.PrintName = "Earthmover Seeker Tower"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKEarthmover.MODEL_TOWER }
ENT.CollisionBounds = Vector( 40, 40, 350 )
ENT.SurroundingBounds = Vector( 80, 80, 380 )

ENT.UKEM_Kind = "tower"
ENT.UKEM_HasDeploy = true
ENT.UKEM_FirstDelay = UKEarthmover.TOWER_FIRST

local NW_CHARGE = "UKEM_ChargeT"

if SERVER then

  function ENT:UKEM_ComponentInit()
    self:SetNW2Float( NW_CHARGE, 0 )
  end

  function ENT:UKEM_CombatThink( enemy, now )
    -- зелёный чардж на кончике за TOWER_CHARGE до выстрела
    local t = self.UKEM_NextFire - now
    if t <= UKEarthmover.TOWER_CHARGE and t > 0 then
      self:SetNW2Float( NW_CHARGE, 1 - t / UKEarthmover.TOWER_CHARGE )
    end

    if now < self.UKEM_NextFire then return end
    self.UKEM_NextFire = now + UKEarthmover.TOWER_DELAY
    self:SetNW2Float( NW_CHARGE, 0 )

    self:UKEM_PlaySeq( "shoot" )
    self:EmitSound( UKEarthmover.SOUND.SeekerFire, 80, 105, 0.9 )

    local pos = self:UKEM_AttachPos( "tip" )
    local proj = self:CreateProjectile( "ultrakill_test_em_seeker_proj", true )
    if not IsValid( proj ) then return end
    proj:SetPos( pos )

    local targetPos = self:UKEM_TargetPos( enemy )
    local dir = ( targetPos - pos ):GetNormalized()
    proj:SetAngles( dir:Angle() )
    proj:SetVelocity( dir * UKEarthmover.SEEKER_SPEED )
  end

else

  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL_GREEN = Color( 120, 255, 130, 255 )

  function ENT:CustomDraw()
    local c = self:GetNW2Float( NW_CHARGE, 0 )
    if c <= 0 then return end
    local id = self:LookupAttachment( "tip" )
    if not id or id <= 0 then return end
    local att = self:GetAttachment( id )
    if not att then return end
    render.SetMaterial( MAT_GLOW )
    local s = 20 + 70 * c
    render.DrawSprite( att.Pos, s, s, COL_GREEN )
  end

end
