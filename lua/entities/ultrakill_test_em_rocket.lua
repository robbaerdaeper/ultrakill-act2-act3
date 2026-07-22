AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Defense System — Rocket Launcher (канон CentaurRocketLauncher).
-- DroneFlesh-цикл: cooldown Random(2,3) -> LookAt упреждённой позиции
-- (0.5 c prediction) -> красный warning beam 0.5 c -> RocketEnemy (150 м/с,
-- НЕ трекает). Следующий cooldown Random(1,3). Наведение — кость Hinge_1.

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_em_turret_base"
ENT.PrintName = "Earthmover Rocket Launcher"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKEarthmover.MODEL_ROCKET }
ENT.CollisionBounds = Vector( 120, 120, 270 )
ENT.SurroundingBounds = Vector( 160, 160, 300 )

ENT.UKEM_Kind = "rocket"
ENT.UKEM_HasDeploy = false

local NW_WARN = "UKEM_RL_Warn"       -- bool: warning beam активен
local NW_WARN_END = "UKEM_RL_WarnEnd" -- vector: конец луча

if SERVER then

  function ENT:UKEM_ComponentInit()
    self.UKEM_NextFire = CurTime() + math.Rand(
      UKEarthmover.RL_COOLDOWN_FIRST[ 1 ], UKEarthmover.RL_COOLDOWN_FIRST[ 2 ] )
    self.UKEM_LockedPos = nil
    self.UKEM_FireAt = 0
    self:SetNW2Bool( NW_WARN, false )
    self.UKEM_HingeBone = self:LookupBone( "Hinge_1" )
  end

  function ENT:UKEM_AimHinge( targetPos )
    local bone = self.UKEM_HingeBone
    if not bone then return end
    local muzzle = self:UKEM_AttachPos( "muzzle" )
    local dir = ( targetPos - muzzle ):GetNormalized()
    local lang = self:WorldToLocalAngles( dir:Angle() )
    -- Hinge_1: доворот по yaw корпусом ракетницы, pitch стволом
    self:ManipulateBoneAngles( bone,
      Angle( 0, math.Clamp( lang.p, -45, 60 ), lang.y ), false )
  end

  function ENT:UKEM_CombatThink( enemy, now )
    -- фаза 2: warning beam горит, ждём выстрела
    if self.UKEM_LockedPos then
      if now >= self.UKEM_FireAt then
        self:UKEM_Fire()
      end
      return
    end

    if now < self.UKEM_NextFire then
      -- пассивный доворот к цели (канон tracking до lock-on)
      local targetPos = self:UKEM_TargetPos( enemy )
      if targetPos then self:UKEM_AimHinge( targetPos ) end
      return
    end

    -- lock-on: канон PredictTargetPosition(0.5)
    local targetPos, tgt = self:UKEM_TargetPos( enemy )
    if not targetPos then return end
    local predicted = targetPos + tgt:GetVelocity() * UKEarthmover.RL_PREDICTION
    self.UKEM_LockedPos = predicted
    self.UKEM_FireAt = now + UKEarthmover.RL_WARNING
    self:UKEM_AimHinge( predicted )
    self:SetNW2Bool( NW_WARN, true )
    self:SetNW2Vector( NW_WARN_END, predicted )
    self:EmitSound( "buttons/blip1.wav", 75, 60, 0.8 )
  end

  function ENT:UKEM_Fire()
    local locked = self.UKEM_LockedPos
    self.UKEM_LockedPos = nil
    self:SetNW2Bool( NW_WARN, false )
    self.UKEM_NextFire = CurTime() + math.Rand(
      UKEarthmover.RL_COOLDOWN[ 1 ], UKEarthmover.RL_COOLDOWN[ 2 ] )
    if not locked then return end

    self:EmitSound( UKEarthmover.SOUND.RocketFire, 90, 100, 1.0 )
    local pos = self:UKEM_AttachPos( "muzzle" )
    local proj = self:CreateProjectile( "ultrakill_test_em_rocket_proj", true )
    if not IsValid( proj ) then return end
    local dir = ( locked - pos ):GetNormalized()
    proj:SetPos( pos + dir * 20 )
    proj:SetAngles( dir:Angle() )
    proj:SetVelocity( dir * UKEarthmover.ROCKET_SPEED )
  end

else

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local COL_WARN = Color( 255, 60, 40, 160 )

  function ENT:CustomDraw()
    if not self:GetNW2Bool( NW_WARN, false ) then return end
    local id = self:LookupAttachment( "muzzle" )
    if not id or id <= 0 then return end
    local att = self:GetAttachment( id )
    if not att then return end
    local endPos = self:GetNW2Vector( NW_WARN_END, att.Pos )
    render.SetMaterial( MAT_BEAM )
    render.DrawBeam( att.Pos, endPos, 6, 0, 1, COL_WARN )
  end

end
