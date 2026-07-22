AddCSLuaFile()

if not UKLeviathan then include( "autorun/ultrakill_test_leviathan_shared.lua" ) end

-- Leviathan phase-3 midsection — the invulnerable Ouroboros ring that replaces
-- the boat (canon LeviathanBodyParent: Spin 10 deg/s gradual accel + rise 14 m
-- via MovingPlatform; child LeviathanBody plays the LeviathanOuroboros loop).
-- Pure visual: non-solid, spins clockwise around the arena center forever.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Leviathan Body"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

local UNIT = UKLeviathan.UNIT

if SERVER then

  function ENT:Initialize()
    self:SetModel( UKLeviathan.MODEL )
    local head = self.UKLev_Head
    local scale = IsValid( head ) and head.UKLev_Scale or UKLeviathan.GetScale()
    self:SetModelScale( scale )
    self.UKLev_U = self.UKLev_U or ( UNIT * scale )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:DrawShadow( false )
    -- NOTE: SetRenderBounds is CLIENT-only — calling it here killed Initialize
    -- mid-way (RiseZ nil -> Think spam); the client block below handles bounds

    -- canon: parent spins around the arena-center pivot (local 0,75)
    local a = self.UKLev_AnchorAng or angle_zero
    local anchor = self.UKLev_Anchor or self:GetPos()
    self.UKLevBody_Pivot = anchor + a:Forward() * ( 75 * self.UKLev_U )
    self.UKLevBody_Offset = self:GetPos() - Vector(
      self.UKLevBody_Pivot.x, self.UKLevBody_Pivot.y, self:GetPos().z )
    self.UKLevBody_BaseZ = self:GetPos().z
    self.UKLevBody_RiseZ = 14 * self.UKLev_U     -- canon MovingPlatform +14 m
    self.UKLevBody_Born = CurTime()
    self.UKLevBody_Yaw = 0
    self.UKLevBody_Omega = 0
    self.UKLevBody_Spinning = true
    self.UKLevBody_BaseYaw = ( self.UKLev_AnchorAng or angle_zero ).yaw + 180

    local seq = self:LookupSequence( "Ouroboros" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetPlaybackRate( 1 )
    end
    self:NextThink( CurTime() )
  end

  function ENT:Think()
    local now = CurTime()
    local dt = math.min( now - ( self.UKLevBody_LastThink or now ), 0.25 )
    self.UKLevBody_LastThink = now

    -- rise out of the water (canon speed 10 m/s, ease-out)
    local age = now - ( self.UKLevBody_Born or now )
    local riseT = math.Clamp( age / 1.4, 0, 1 )
    local rise = ( 1 - ( 1 - riseT ) ^ 2 ) * self.UKLevBody_RiseZ

    -- gradual spin-up to 10 deg/s (canon Spin gradualSpeed 2)
    if self.UKLevBody_Spinning then
      self.UKLevBody_Omega = math.min( ( self.UKLevBody_Omega or 0 ) + 2 * dt, 10 )
    else
      self.UKLevBody_Omega = math.max( ( self.UKLevBody_Omega or 0 ) - 2 * dt, 0 )
    end
    self.UKLevBody_Yaw = ( self.UKLevBody_Yaw or 0 ) + self.UKLevBody_Omega * dt

    local off = self.UKLevBody_Offset or vector_origin
    local rotated = Vector( off.x, off.y, 0 )
    rotated:Rotate( Angle( 0, self.UKLevBody_Yaw, 0 ) )
    local pivot = self.UKLevBody_Pivot or self:GetPos()
    self:SetPos( Vector( pivot.x + rotated.x, pivot.y + rotated.y,
      self.UKLevBody_BaseZ + rise ) )
    self:SetAngles( Angle( 0, self.UKLevBody_BaseYaw + self.UKLevBody_Yaw, 0 ) )

    self:NextThink( now )
    return true
  end

end

if CLIENT then

  function ENT:Initialize()
    -- huge ring model: without explicit render bounds it culls out constantly
    local sr = 220 * UKLeviathan.UNIT * math.max( self:GetModelScale(), 0.1 )
    self:SetRenderBounds( Vector( -sr, -sr, -sr ), Vector( sr, sr, sr ) )
  end

  function ENT:Draw()
    self:DrawModel()
  end

end
