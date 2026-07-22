-- lua/entities/ultrakill_test_providence_pincer.lua
-- Magenta Cross Pincer (canon 'ProvidencePincer', Layer 8).
-- Canon behaviour (wiki + prefab dump): a rotating Eye-of-Providence sigil
-- appears in front of the Providence's EYE while its wings spin; four beams
-- then shoot FROM THE EYE, starting perpendicular to the eye->target axis and
-- slowly folding onto it (pincerSpeed 45 deg/s) while the whole assembly
-- rotates around the axis (rotationSpeed 90 deg/s). Once fired, the source
-- stays where the eye was and the target position is locked (on BRUTAL the
-- target is tracked for the first second). Beams deal 20 and DO hit enemies.
--
-- The entity itself is an invisible anchor at the EYE position; the target
-- point is networked via NW2Vector.

AddCSLuaFile()

if not UKProvidence then include( "autorun/ultrakill_test_providence_shared.lua" ) end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Providence Magenta Cross Pincer"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

local SND = UKProvidence.SOUND
local MAGENTA = UKProvidence.MAGENTA

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

-- Perpendicular basis for the eye->target axis.
local function AxisBasis( axis )
  local right = axis:Cross( Vector( 0, 0, 1 ) )
  if right:LengthSqr() < 0.01 then right = axis:Cross( Vector( 0, 1, 0 ) ) end
  right:Normalize()
  local up = right:Cross( axis )
  up:Normalize()
  return right, up
end

-- 4 beam directions at time t since the beams fired: fold from 90 deg
-- (perpendicular cross) onto the axis at PINCER_CLOSE_SPEED while spinning
-- around it at PINCER_AXIS_ROT.
local function BeamDirs( axis, t, phase0, dir )
  local right, up = AxisBasis( axis )
  local theta = math.rad( math.max( 90 - UKProvidence.PINCER_CLOSE_SPEED * t, 0 ) )
  local spin = math.rad( phase0 + UKProvidence.PINCER_AXIS_ROT * t * ( dir or 1 ) )
  local sinT, cosT = math.sin( theta ), math.cos( theta )
  local dirs = {}
  for k = 0, 3 do
    local a = spin + k * math.pi * 0.5
    local perp = right * math.cos( a ) + up * math.sin( a )
    dirs[ k + 1 ] = axis * cosT + perp * sinT
  end
  return dirs
end

if SERVER then

  function ENT:Initialize()
    -- invisible anchor at the eye (insignia pattern): Draw hook still runs
    self:SetModel( "models/ultrakill/mesh/effects/sphere/sphere_16.mdl" )
    self:PhysicsInitBox( Vector( -1, -1, -1 ), Vector( 1, 1, 1 ) )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup( COLLISION_GROUP_WORLD )
    self:DrawShadow( false )
    self:SetRenderMode( RENDERMODE_TRANSALPHA )
    self:SetColor( Color( 255, 255, 255, 0 ) )

    self.UKPincer_Start = CurTime()
    self.UKPincer_Phase0 = math.Rand( 0, 90 )
    self.UKPincer_HitCD = {}
    self.UKPincer_BeamsOn = false
    self.UKPincer_Diff = UKProvidence.GetDifficulty( self.UKPincer_Owner )

    self:SetNW2Float( "UKPincer_Start", self.UKPincer_Start )
    self:SetNW2Float( "UKPincer_Phase0", self.UKPincer_Phase0 )
    if not self:GetNW2Vector( "UKPincer_TargetPos", vector_origin ):IsZero() then
      -- already set by the NPC before Spawn
    elseif IsValid( self.UKPincer_Target ) then
      self:SetNW2Vector( "UKPincer_TargetPos", self.UKPincer_Target:WorldSpaceCenter() )
    end

    self:EmitSound( SND.Charge, 78, 100, 0.75 )
    self:NextThink( CurTime() )
  end

  function ENT:Think()
    local age = CurTime() - self.UKPincer_Start
    local windup = UKProvidence.PINCER_WINDUP + UKProvidence.PINCER_DELAY

    -- during the chant the sigil stays in front of the owner's eye; the
    -- source position locks the moment the beams fire (canon)
    if age < windup then
      local owner = self.UKPincer_Owner
      if not IsValid( owner ) then self:Remove() return end
      if owner.UKProv_EyePos then self:SetPos( owner:UKProv_EyePos() ) end
    end

    -- BRUTAL quirk: the pincer tracks its target for the first second
    if self.UKPincer_Diff >= 4 and age < UKProvidence.PINCER_FOLLOW_T
       and IsValid( self.UKPincer_Target ) then
      self:SetNW2Vector( "UKPincer_TargetPos", self.UKPincer_Target:WorldSpaceCenter() )
    end

    if age >= windup + UKProvidence.PINCER_BEAM_TIME then
      self:StopSound( SND.BeamLoop )
      self:Remove()
      return
    end

    if age >= windup then
      if not self.UKPincer_BeamsOn then
        self.UKPincer_BeamsOn = true
        self:SetNW2Bool( "UKPincer_Beams", true )
        self:EmitSound( SND.BeamLoop, 80, 100, 0.7 )
        self:EmitSound( SND.BeamImpact, 78, 100, 0.6 )
        util.ScreenShake( self:GetPos(), 4, 10, 0.5, 1500 )
      end
      local source = self:GetPos()
      local targetPos = self:GetNW2Vector( "UKPincer_TargetPos", source )
      local axis = targetPos - source
      if axis:LengthSqr() < 1 then axis = Vector( 0, 0, -1 ) end
      axis:Normalize()
      local spinDir = self:GetNW2Int( "UKPincer_Dir", 1 )
      for _, dir in ipairs( BeamDirs( axis, age - windup, self.UKPincer_Phase0, spinDir ) ) do
        UKProvidence.DamageBeamSegment(
          self.UKPincer_Owner, self, source, dir,
          UKProvidence.PINCER_BEAM_RANGE, UKProvidence.PINCER_BEAM_RADIUS,
          UKProvidence.PINCER_BEAM_DAMAGE, true, -- canon pincer beams DO hit enemies
          self.UKPincer_HitCD )
      end
    end

    self:NextThink( CurTime() )
    return true
  end

  function ENT:OnRemove()
    self:StopSound( SND.BeamLoop )
  end

else -- CLIENT

  -- canon renderers (visual dump: ProvidencePincer): ProvidenceWindup sigil,
  -- muzzleflashturret flash + Shockwave on the delay tick, striped
  -- MindflayerBeam3 beams with RageEffectWhite rings
  local MAT_SIGIL = Material( "effects/ukprovidence_sigil" )
  local MAT_FLASH = Material( "effects/ukprovidence_flash" )
  local MAT_SHOCK = Material( "effects/ukprovidence_shockwave" )
  local MAT_BEAM = Material( "effects/ukprovidence_beam" )
  local MAT_RING = Material( "effects/ukprovidence_ring" )
  local COL_RING = Color( 255, 140, 200, 255 )
  local COL_SIGIL = Color( MAGENTA.r, MAGENTA.g, MAGENTA.b, 200 )
  local BEAM_WIDTH = 30 -- canon 1.0 unit * prefab scale 2 (=50); r8/r9: 40 -> 30
  local RB = Vector( 12000, 12000, 12000 )

  function ENT:Initialize()
    self:SetRenderBounds( -RB, RB )
    self:DrawShadow( false )
  end

  function ENT:Draw() end

  function ENT:DrawPincerEffect()
    local start = self:GetNW2Float( "UKPincer_Start", CurTime() )
    local phase0 = self:GetNW2Float( "UKPincer_Phase0", 0 )
    local age = CurTime() - start
    local windup = UKProvidence.PINCER_WINDUP + UKProvidence.PINCER_DELAY
    local source = self:GetPos()
    local targetPos = self:GetNW2Vector( "UKPincer_TargetPos", source )
    local axis = targetPos - source
    if axis:LengthSqr() < 1 then axis = Vector( 0, 0, -1 ) end
    axis:Normalize()

    -- rotating sigil in front of the eye, facing the target; grows on windup
    local grow = math.Clamp( age / UKProvidence.PINCER_WINDUP, 0, 1 )
    local size = 170 * grow
    local spinDir = self:GetNW2Int( "UKPincer_Dir", 1 )
    local rot = ( age * UKProvidence.PINCER_SIGIL_ROT * spinDir ) % 360
    render.SetMaterial( MAT_SIGIL )
    render.DrawQuadEasy( source + axis * 10, axis, size, size * 1.29, COL_SIGIL, rot )
    render.DrawQuadEasy( source + axis * 10, -axis, size, size * 1.29, COL_SIGIL, -rot )

    -- delay flash: canon muzzleflashturret star (scale 10 * prefab 2) + shockwave
    if age >= UKProvidence.PINCER_WINDUP and age < windup then
      local ft = ( age - UKProvidence.PINCER_WINDUP ) / UKProvidence.PINCER_DELAY
      local f = 1 - ft
      render.SetMaterial( MAT_FLASH )
      render.DrawQuadEasy( source + axis * 14, axis, 500 * f, 500 * f,
        Color( 255, 255, 255, 255 * f ), ( age * 120 ) % 360 )
      render.SetMaterial( MAT_SHOCK )
      local ss = 100 + 500 * ft
      render.DrawSprite( source, ss, ss, Color( 255, 140, 200, 180 * f ) )
    end

    -- beams from the eye folding onto the target while spinning
    if age >= windup and age < windup + UKProvidence.PINCER_BEAM_TIME then
      local t = age - windup
      local fade = 1 - math.max( 0, ( t - UKProvidence.PINCER_BEAM_TIME + 0.4 ) / 0.4 )
      local beamCol = Color( 255, 255, 255, 255 * fade )
      local ringCol = Color( COL_RING.r, COL_RING.g, COL_RING.b, 255 * fade )
      local dirs = BeamDirs( axis, t, phase0, spinDir )
      local beams = {}
      for _, dir in ipairs( dirs ) do
        local tr = util.TraceLine( {
          start = source, endpos = source + dir * UKProvidence.PINCER_BEAM_RANGE,
          mask = MASK_SOLID_BRUSHONLY,
        } )
        beams[ #beams + 1 ] = { dir = dir, endpos = tr.HitPos,
          len = tr.HitPos:Distance( source ), hit = tr.Hit }
      end
      -- canon LineRenderer textureMode=Stretch: the striped MindflayerBeam3
      -- texture is stretched ONCE over the whole beam, never tiled
      render.SetMaterial( MAT_BEAM )
      for _, b in ipairs( beams ) do
        render.DrawBeam( source, b.endpos, BEAM_WIDTH, 0, 1, beamCol )
      end
      -- canon RageEffectWhite rings: magenta rings travelling along each
      -- beam + one at the source of each beam + one at the wall hit
      render.SetMaterial( MAT_RING )
      for _, b in ipairs( beams ) do
        UKProvidence.DrawBeamRings( source, b.dir, b.len, 110, 700, 170, fade )
        render.DrawSprite( source + b.dir * 40, 100, 100, ringCol )
        if b.hit then
          render.DrawSprite( b.endpos - b.dir * 6, 125, 125, ringCol )
        end
      end
    end

    -- magenta light at the eye
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = source
      dl.r, dl.g, dl.b = MAGENTA.r, MAGENTA.g, MAGENTA.b
      dl.brightness = 2.5
      dl.size = 300
      dl.decay = 1000
      dl.dietime = CurTime() + 0.1
    end
  end

  hook.Add( "PostDrawTranslucentRenderables", "UKProvidencePincer_Draw", function( _, bSkybox )
    if bSkybox then return end
    for _, e in ipairs( ents.FindByClass( "ultrakill_test_providence_pincer" ) ) do
      if IsValid( e ) and e.DrawPincerEffect then e:DrawPincerEffect() end
    end
  end )

end
