-- Gutterman minigun beam — canon RevolverBeam/LineRenderer replica.
--
-- Canon numbers (Gutterman Beam prefab + RevolverBeam.Update):
--   widthMultiplier 0.5 m (20 su), flat width curve;
--   colour gradient white (muzzle) -> yellow (1, 0.807, 0) at the end;
--   fadeOut: widthMultiplier -= dt * 1.5  =>  full width -> 0 in 0.333 s,
--   alpha stays FULL the whole time; the line is world-static;
--   muzzle light (1, 0.936, 0.665) intensity 20 -> fades at 100/s.
--
-- The start point is taken from the CLIENT bone matrix at spawn time, so the
-- line begins exactly at the drawn barrel (server bones lag the visual gun);
-- after that the line stays fixed in the world like the canon LineRenderer.

local BEAM_MAT = Material( "models/ultrakill_prelude_test/gutterman/beam" )
local GLOW_MAT = Material( "sprites/light_glow02_add" )

local WIDTH = 14        -- canon 0.5 m = 20 su, drawn slimmer per live feedback
local FADE_RATE = 42    -- keeps the canon 0.333 s fade time at the new width

local COL_END = Color( 255, 206, 0 ) -- canon gradient key1 (1, 0.807, 0)

function EFFECT:Init( data )
  self.StartPos = data:GetStart()
  self.EndPos = data:GetOrigin()

  -- re-anchor the start to the client-side muzzle at fire time
  local ent = data:GetEntity()
  if IsValid( ent ) and ent.UKGutterman_GetMuzzle then
    local ok, muzzle = pcall( ent.UKGutterman_GetMuzzle, ent )
    if ok and isvector( muzzle ) then
      self.StartPos = muzzle
    end
  end

  self.SpawnTime = CurTime()
  self.LifeTime = WIDTH / FADE_RATE -- 0.333 s, canon

  -- SetPos MUST come before SetRenderBoundsWS: world-space bounds are stored
  -- relative to the entity position at call time, and effects spawn at the
  -- world origin — setting bounds first shifted them by StartPos, so the beam
  -- got culled the moment the Gutterman left the screen ("trails vanish when
  -- you look away"). Pad by the beam width so edge-on views survive too.
  self:SetPos( self.StartPos )
  local pad = Vector( WIDTH + 16, WIDTH + 16, WIDTH + 16 )
  local mins = Vector(
    math.min( self.StartPos.x, self.EndPos.x ),
    math.min( self.StartPos.y, self.EndPos.y ),
    math.min( self.StartPos.z, self.EndPos.z )
  ) - pad
  local maxs = Vector(
    math.max( self.StartPos.x, self.EndPos.x ),
    math.max( self.StartPos.y, self.EndPos.y ),
    math.max( self.StartPos.z, self.EndPos.z )
  ) + pad
  self:SetRenderBoundsWS( mins, maxs )

  -- canon muzzle light: warm white-yellow, fades out fast (100/s from 20)
  local dl = DynamicLight( self:EntIndex() )
  if dl then
    dl.pos = self.StartPos
    dl.r = 255
    dl.g = 238
    dl.b = 170
    dl.brightness = 3
    dl.size = 400
    dl.decay = 2000
    dl.dietime = CurTime() + 0.2
  end
end

function EFFECT:Think()
  return CurTime() - self.SpawnTime < self.LifeTime
end

function EFFECT:Render()
  local width = WIDTH - ( CurTime() - self.SpawnTime ) * FADE_RATE
  if width <= 0 then return end

  -- canon: width shrinks, colour/alpha stay full
  render.SetMaterial( BEAM_MAT )
  render.StartBeam( 2 )
  render.AddBeam( self.StartPos, width, 0, color_white )
  render.AddBeam( self.EndPos, width, 1, COL_END )
  render.EndBeam()

  -- muzzle glow shrinking with the beam (the steady star is in CustomDraw)
  local gfrac = width / WIDTH
  render.SetMaterial( GLOW_MAT )
  render.DrawSprite( self.StartPos, 34 * gfrac, 34 * gfrac, Color( 255, 230, 150, 255 * gfrac ) )
end
