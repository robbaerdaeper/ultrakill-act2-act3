-- lua/entities/ultrakill_test_geryon_pillar.lua
-- Geryon arrow beam pillars (canon GeryonUpArrowBeam / GeryonForwardArrowBeam).
-- mode "up" (Orange Bombardment): telegraphed vertical orange pillar at a
-- ground spot, multi-tick damage, shrinks out. mode "forward" (Blue Beams):
-- blue pillar that drifts forward from the bow (canon ConstantForce).
-- Both: HurtZone setDamage 30, hurtCooldown 1 s.

AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGeryon then include( "autorun/ultrakill_test_geryon_shared.lua" ) end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Geryon Arrow Beam"
ENT.Category = UKGeryon.CATEGORY
ENT.Spawnable = false

local UNIT = UKGeryon.UNIT
local SND = UKGeryon.SOUND

function ENT:UKG_Mode()
  return self:GetNW2String( "UKG_Mode", "up" )
end

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate.mdl" )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:SetNoDraw( true ) -- rendered by the clientside beam ent below
    self:DrawShadow( false )

    local mode = self:UKG_Mode()
    -- snap to the ground (canon beams spawn at arena height - 5 and span 800 up)
    local tr = util.TraceLine( {
      start = self:GetPos() + Vector( 0, 0, 200 ),
      endpos = self:GetPos() - Vector( 0, 0, 16384 ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if tr.Hit then self:SetPos( tr.HitPos ) end

    self.UKG_Born = CurTime()
    self.UKG_ActiveAt = CurTime() + UKGeryon.PILLAR_TELEGRAPH
    self.UKG_DieAt = self.UKG_ActiveAt
      + ( mode == "up" and UKGeryon.PILLAR_LIFE or UKGeryon.PILLAR_FWD_LIFE )
    self.UKG_HitCD = {}
    self.UKG_Fired = false

    self:SetNW2Float( "UKG_ActiveAt", self.UKG_ActiveAt )
    self:SetNW2Float( "UKG_DieAt", self.UKG_DieAt )

    -- canon Warning audio on the telegraph sigil
    self:EmitSound( SND.ArrowShort, 85, mode == "up" and 100 or 115, 0.9 )
  end

  function ENT:Think()
    local now = CurTime()
    if now >= self.UKG_DieAt then
      self:Remove()
      return
    end

    local mode = self:UKG_Mode()

    if now >= self.UKG_ActiveAt then
      if not self.UKG_Fired then
        self.UKG_Fired = true
        self:EmitSound( mode == "up" and SND.BeamLoud or SND.Beam, 95, 100, 1 )
        util.ScreenShake( self:GetPos(), 5, 30, 0.4, 1500 )
      end

      -- canon forward beams fly ahead (Rigidbody + ConstantForce)
      if mode == "forward" then
        self:SetPos( self:GetPos() + self:GetForward() * UKGeryon.BOWFWD_SPEED * FrameTime() )
      end

      -- vertical hurt column, multi-tick (canon HurtZone cooldown 1 s)
      local owner = self:GetOwner()
      local radius = mode == "up" and UKGeryon.PILLAR_R_UP or UKGeryon.PILLAR_R_FWD
      UKGeryon.DamageBeamSegment( owner, self,
        self:GetPos() - Vector( 0, 0, 100 ), Vector( 0, 0, 1 ),
        UKGeryon.PILLAR_HEIGHT, radius, UKGeryon.PILLAR_DAMAGE, false,
        self.UKG_HitCD, UKGeryon.PILLAR_TICK )
    end

    self:NextThink( now )
    return true
  end

end

if CLIENT then

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local MAT_RING = Material( "effects/select_ring" )

  function ENT:Initialize()
    self:SetRenderBounds( Vector( -400, -400, 0 ), Vector( 400, 400, 20000 ) )
  end

  function ENT:Draw() end

  function ENT:DrawTranslucent()
    local mode = self:UKG_Mode()
    local col = mode == "up" and UKGeryon.ORANGE or UKGeryon.BLUE
    local now = CurTime()
    local activeAt = self:GetNW2Float( "UKG_ActiveAt", now )
    local dieAt = self:GetNW2Float( "UKG_DieAt", now + 1 )
    local pos = self:GetPos()

    if now < activeAt then
      -- telegraph: rotating ground sigil + faint warning column
      local f = 1 - ( activeAt - now ) / UKGeryon.PILLAR_TELEGRAPH
      render.SetMaterial( MAT_RING )
      render.DrawQuadEasy( pos + Vector( 0, 0, 4 ), Vector( 0, 0, 1 ),
        500 * ( 0.5 + 0.5 * f ), 500 * ( 0.5 + 0.5 * f ),
        Color( col.r, col.g, col.b, 160 ), now * 90 % 360 )
      render.SetMaterial( MAT_BEAM )
      render.DrawBeam( pos, pos + Vector( 0, 0, 4000 ), 20 + 30 * f,
        0, 10, Color( col.r, col.g, col.b, 60 + 60 * f ) )
      return
    end

    -- active pillar, shrinking out over its lifetime (canon ScaleTransform)
    local life = math.Clamp( ( dieAt - now )
      / ( mode == "up" and UKGeryon.PILLAR_LIFE or UKGeryon.PILLAR_FWD_LIFE ), 0, 1 )
    local radius = ( mode == "up" and UKGeryon.PILLAR_R_UP or UKGeryon.PILLAR_R_FWD )
    local w = radius * 2 * ( 0.4 + 0.6 * life )

    render.SetMaterial( MAT_BEAM )
    render.DrawBeam( pos - Vector( 0, 0, 100 ), pos + Vector( 0, 0, 9000 ),
      w * 2.2, 0, 20, Color( col.r, col.g, col.b, 90 ) )
    render.DrawBeam( pos - Vector( 0, 0, 100 ), pos + Vector( 0, 0, 9000 ),
      w, 0, 20, Color( 255, 255, 255, 200 ) )

    render.SetMaterial( MAT_GLOW )
    render.DrawSprite( pos + Vector( 0, 0, 40 ), w * 4, w * 4,
      Color( col.r, col.g, col.b, 180 ) )
  end

end
