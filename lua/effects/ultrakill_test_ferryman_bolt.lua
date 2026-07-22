-- Canon LightningStrike visual ('Explosion Lightning' prefab): a huge
-- camera-facing 'Lightning_Still' sprite from the sky (TestLightning material,
-- AnimatedTexture flicker), a white point light (canon intensity 25 range
-- 1000) and an impact glow. render.DrawBeam auto-billboards the quad exactly
-- like the canon AlwaysLookAtCamera Y-axis billboard.

local boltMat = Material( "effects/ukferryman_bolt" )
local glowMat = Material( "sprites/light_glow02_add" )

EFFECT.LIFETIME = 0.5
EFFECT.HEIGHT = 2600

function EFFECT:Init( data )
  self.Pos = data:GetOrigin()
  self.StartTime = CurTime()
  self.Seed = math.random( 1, 10000 )

  local top = self.Pos + Vector( 0, 0, self.HEIGHT )
  self:SetRenderBoundsWS( self.Pos - Vector( 400, 400, 0 ), top + Vector( 400, 400, 100 ) )

  -- canon Point Light: white, intensity 25, range 1000
  local dl = DynamicLight( self:EntIndex() )
  if dl then
    dl.pos = self.Pos + Vector( 0, 0, 120 )
    dl.r, dl.g, dl.b = 255, 255, 255
    dl.brightness = 8
    dl.decay = 2400
    dl.size = 1200
    dl.dietime = CurTime() + 0.5
  end
end

function EFFECT:Think()
  return CurTime() - self.StartTime < self.LIFETIME
end

function EFFECT:Render()
  local age = ( CurTime() - self.StartTime ) / self.LIFETIME
  local alpha = 255 * ( 1 - age )
  if alpha <= 0 then return end

  -- canon AnimatedTexture: the bolt flickers while alive
  local flicker = 0.75 + 0.25 * math.sin( ( CurTime() + self.Seed ) * 70 )
  local a = alpha * flicker

  local base = self.Pos
  local top = base + Vector( 0, 0, self.HEIGHT )

  render.SetMaterial( boltMat )
  -- main bolt + wider faint halo copy (canon glow pass)
  render.DrawBeam( top, base, 190, 0, 1, Color( 255, 255, 255, a ) )
  render.DrawBeam( top, base, 420, 0, 1, Color( 190, 225, 255, a * 0.35 ) )

  render.SetMaterial( glowMat )
  render.DrawSprite( base + Vector( 0, 0, 30 ),
    300 * ( 1 - age * 0.5 ), 300 * ( 1 - age * 0.5 ),
    Color( 235, 245, 255, alpha ) )
end
