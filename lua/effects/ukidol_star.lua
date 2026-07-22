-- lua/effects/ukidol_star.lua

local matStar = Material( "effects/ukidol_halo" )

function EFFECT:Init( data )
  self.Pos       = data:GetOrigin()
  self.Vel       = data:GetNormal() * math.Rand( 8, 24 ) + Vector( 0, 0, math.Rand( 4, 18 ) )
  self.StartTime = CurTime()
  self.Life      = 1.5
  self.Size      = math.Rand( 4, 9 )
end


function EFFECT:Think()
  local t = ( CurTime() - self.StartTime ) / self.Life
  if t >= 1 then return false end
  self.Pos = self.Pos + self.Vel * FrameTime()
  self.Vel = self.Vel * 0.96 + Vector( 0, 0, 4 ) * FrameTime()    -- slow rise
  return true
end


function EFFECT:Render()
  local t = ( CurTime() - self.StartTime ) / self.Life
  local fade = 1 - t * t    -- ease-out
  render.SetMaterial( matStar )
  render.DrawSprite( self.Pos, self.Size, self.Size, Color( 220, 240, 255, fade * 200 ) )
end
