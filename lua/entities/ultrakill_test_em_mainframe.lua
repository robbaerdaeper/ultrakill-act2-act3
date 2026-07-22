AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Defense System — Mainframe (канон «Mainframe (Hurtable)», 7-4).
-- Синий трекинг-луч (Mindflayer Beam, 15 dmg, медленно догоняет цель).
-- Щит до смерти всех остальных компонентов. Контроллер канон-фаз сета:
--   1) сразу: mainframe (щит) + 2 ракетницы
--   2) смерть 1-й ракетницы -> миномёты
--   3) смерть 2-й ракетницы ИЛИ миномёта -> сикер-башни
--   4) все 6 мертвы -> щит падает
-- convar ultrakill_em_fullset 0 -> одиночный mainframe без щита.

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_em_turret_base"
ENT.PrintName = "Earthmover Defense System"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKEarthmover.MODEL_MAINFRAME }
ENT.CollisionBounds = Vector( 150, 150, 540 )
ENT.SurroundingBounds = Vector( 200, 200, 580 )

ENT.UKEM_Kind = "mainframe"
ENT.UKEM_HasDeploy = false

local NW_BEAM_ON = "UKEM_MF_BeamOn"
local NW_BEAM_END = "UKEM_MF_BeamEnd"
local NW_SHIELD = "UKEM_MF_Shield"

if SERVER then

  local cvFullset = CreateConVar( "ultrakill_em_fullset", "1", FCVAR_ARCHIVE,
    "Mainframe spawns the full canon Defense System set (2 rockets, 2 mortars, 2 towers)" )

  function ENT:UKEM_ComponentInit()
    self.UKEM_Fullset = cvFullset:GetBool()
    self.UKEM_Shielded = self.UKEM_Fullset
    self.UKEM_BeamDir = self:GetForward()
    self.UKEM_BeamHitCD = {}
    self.UKEM_Deaths = { rocket = 0, mortar = 0, tower = 0 }
    self.UKEM_Satellites = {}
    self.UKEM_MortarsSpawned = false
    self.UKEM_TowersSpawned = false

    self:SetNW2Bool( NW_BEAM_ON, false )
    self:UKEM_SetShield( self.UKEM_Shielded )

    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, "1000-THR DEFENSE SYSTEM" )
    end

    if self.UKEM_Fullset then
      -- фаза 1: две ракетницы по бокам
      timer.Simple( 0.1, function()
        if not IsValid( self ) then return end
        self:UKEM_SpawnSatellite( "ultrakill_test_em_rocket", 90 )
        self:UKEM_SpawnSatellite( "ultrakill_test_em_rocket", 270 )
      end )
    end
  end

  function ENT:UKEM_SetShield( on )
    self.UKEM_Shielded = on
    self:SetNW2Bool( NW_SHIELD, on )
    local bg = self:FindBodygroupByName( "shield" )
    if bg and bg >= 0 then
      self:SetBodygroup( bg, on and 0 or 1 )
    end
  end

  function ENT:UKEM_SpawnSatellite( class, yawOffset )
    local ang = self:GetAngles().yaw + yawOffset
    local dir = Angle( 0, ang, 0 ):Forward()
    local pos = self:GetPos() + dir * UKEarthmover.SET_RADIUS

    -- ищем землю под точкой
    local tr = util.TraceLine( {
      start = pos + Vector( 0, 0, 200 ),
      endpos = pos - Vector( 0, 0, 2000 ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if tr.Hit then pos = tr.HitPos end

    local ent = ents.Create( class )
    if not IsValid( ent ) then return end
    ent:SetPos( pos )
    ent:SetAngles( Angle( 0, ang, 0 ) )
    ent.UKEM_GroupMaster = self
    ent:Spawn()
    ent:EmitSound( UKEarthmover.SOUND.Spawn, 85, 100, 0.6 )
    table.insert( self.UKEM_Satellites, ent )
    self:DeleteOnRemove( ent )
    return ent
  end

  function ENT:UKEM_ComponentDied( kind, ent )
    self.UKEM_Deaths[ kind ] = ( self.UKEM_Deaths[ kind ] or 0 ) + 1
    local d = self.UKEM_Deaths

    -- канон-фазы
    if d.rocket >= 1 and not self.UKEM_MortarsSpawned then
      self.UKEM_MortarsSpawned = true
      self:UKEM_SpawnSatellite( "ultrakill_test_em_mortar", 30 )
      self:UKEM_SpawnSatellite( "ultrakill_test_em_mortar", 210 )
    end
    if ( d.rocket >= 2 or d.mortar >= 1 ) and not self.UKEM_TowersSpawned then
      self.UKEM_TowersSpawned = true
      self:UKEM_SpawnSatellite( "ultrakill_test_em_tower", 150 )
      self:UKEM_SpawnSatellite( "ultrakill_test_em_tower", 330 )
    end

    -- щит: падает когда все 6 мертвы
    if self.UKEM_Shielded and d.rocket >= 2 and d.mortar >= 2 and d.tower >= 2 then
      self:UKEM_SetShield( false )
      self:EmitSound( UKEarthmover.SOUND.ShieldDown, 90, 100, 1.0 )
    end
  end

  function ENT:OnTakeDamage( dmg, hitGroup )
    if self.UKEM_Shielded then
      dmg:SetDamage( 0 )
      self:EmitSound( "hl1/fvox/blip.wav", 60, 130, 0.4 )
      return true
    end
  end

  function ENT:UKEM_EyePos()
    return self:GetPos() + Vector( 0, 0,
      UKEarthmover.MAINFRAME_EYE_Z * self:GetModelScale() )
  end

  function ENT:UKEM_CombatThink( enemy, now )
    local eyePos = self:UKEM_EyePos()
    local targetPos = self:UKEM_TargetPos( enemy )
    if not targetPos then
      self:SetNW2Bool( NW_BEAM_ON, false )
      if self.UKEM_BeamSound then self.UKEM_BeamSound:Stop() end
      return
    end

    -- канон AlwaysLookAtCamera speed 1.0: луч медленно доворачивается
    local wantDir = ( targetPos - eyePos ):GetNormalized()
    local cur = self.UKEM_BeamDir or wantDir
    local maxRad = math.rad( UKEarthmover.BEAM_TRACK_SPEED ) * FrameTime()
    local dot = math.Clamp( cur:Dot( wantDir ), -1, 1 )
    local angBetween = math.acos( dot )
    local dir
    if angBetween <= maxRad then
      dir = wantDir
    else
      local f = maxRad / angBetween
      dir = ( cur * ( 1 - f ) + wantDir * f ):GetNormalized()
    end
    self.UKEM_BeamDir = dir

    local tr = util.TraceLine( {
      start = eyePos,
      endpos = eyePos + dir * UKEarthmover.BEAM_RANGE,
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self then return false end
        if ent.UKEM_GroupMaster == self then return false end
        return true
      end,
    } )

    if not self:GetNW2Bool( NW_BEAM_ON, false ) then
      self.UKEM_BeamSound = self.UKEM_BeamSound
        or CreateSound( self, UKEarthmover.SOUND.BeamLoop )
      self.UKEM_BeamSound:PlayEx( 0.5, 100 )
    end
    self:SetNW2Bool( NW_BEAM_ON, true )
    self:SetNW2Vector( NW_BEAM_END, tr.HitPos )

    -- контакт-урон (канон ContinuousBeam 15)
    local hit = tr.Entity
    if IsValid( hit ) and ( hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot() ) then
      local key = hit:EntIndex()
      if ( self.UKEM_BeamHitCD[ key ] or 0 ) <= now then
        self.UKEM_BeamHitCD[ key ] = now + UKEarthmover.BEAM_TICK
        UKEarthmover.DealDamage( hit, self, self, UKEarthmover.BEAM_DAMAGE,
          DMG_ENERGYBEAM )
      end
    end
  end

  function ENT:OnDeath( dmg, hitGroup )
    self:SetNW2Bool( NW_BEAM_ON, false )
    if self.UKEM_BeamSound then self.UKEM_BeamSound:Stop() end
    self:UKEM_BaseOnDeath( dmg, hitGroup )
  end

  function ENT:OnRemove()
    if self.UKEM_BeamSound then self.UKEM_BeamSound:Stop() end
  end

else

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL_BEAM = Color( 90, 160, 255, 230 )
  local COL_BEAM_SOFT = Color( 90, 160, 255, 80 )
  local COL_EYE = Color( 210, 235, 255, 255 )

  function ENT:CustomDraw()
    local eyePos = self:GetPos() + Vector( 0, 0,
      UKEarthmover.MAINFRAME_EYE_Z * self:GetModelScale() )

    -- глаз светится всегда пока жив
    if self:Health() > 0 then
      render.SetMaterial( MAT_GLOW )
      render.DrawSprite( eyePos, 90, 90, COL_EYE )
    end

    if not self:GetNW2Bool( NW_BEAM_ON, false ) then return end
    local endPos = self:GetNW2Vector( NW_BEAM_END, eyePos )
    render.SetMaterial( MAT_BEAM )
    render.DrawBeam( eyePos, endPos, 14, 0, 1, COL_BEAM )
    render.DrawBeam( eyePos, endPos, 40, 0, 1, COL_BEAM_SOFT )
    render.SetMaterial( MAT_GLOW )
    render.DrawSprite( endPos, 50, 50, COL_BEAM )
  end

end
