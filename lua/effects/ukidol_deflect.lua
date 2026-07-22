-- lua/effects/ukidol_deflect.lua

local matHit = Material( "effects/ukidol_hit" )


function EFFECT:Init( data )
  self.Pos       = data:GetOrigin()
  self.StartTime = CurTime()
  self.Life      = 0.25
  self.Ent       = data:GetEntity()
  self.Scale     = data:GetScale()
  if self.Scale == 0 then self.Scale = 1 end
end


function EFFECT:Think()
  return CurTime() - self.StartTime < self.Life
end


function EFFECT:Render()
  local t = ( CurTime() - self.StartTime ) / self.Life
  local size = Lerp( t, 12, 64 ) * self.Scale
  local alpha = 255 * ( 1 - t )

  render.SetMaterial( matHit )
  render.DrawSprite( self.Pos, size, size, Color( 220, 240, 255, alpha ) )
end
