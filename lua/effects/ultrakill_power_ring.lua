-- Power circle burst — canon RageEffectWhite sprite (the blue circle from
-- GabrielJuggleEffect / GabrielDashEffect that Power reuses in ULTRAKILL).
-- EffectData:
--   Origin    = center
--   Scale     = full size in units (sprite side)
--   Magnitude = lifetime in seconds (default 1)
--   Flags     = palette: 0 blue (juggle/spawn), 1 grey (dash), 2 white (flash),
--               3 gold (weapon/death)

local CurTime = CurTime

local RingMat = Material( "models/ultrakill_prelude_test/power/rageeffect" )

local PALETTE = {
  [ 0 ] = Color( 0, 100, 212, 200 ),   -- canon juggle (0, 0.39, 0.83, 0.5)
  [ 1 ] = Color( 128, 128, 128, 60 ),  -- canon dash (0.5, 0.5, 0.5, 0.1)
  [ 2 ] = Color( 255, 255, 255, 220 ),
  [ 3 ] = Color( 255, 190, 40, 220 ),
}

function EFFECT:Init( fx )
  self.Pos = fx:GetOrigin()
  self.Size = math.max( fx:GetScale(), 16 )
  self.DieTime = fx:GetMagnitude() > 0 and fx:GetMagnitude() or 1
  self.Color = PALETTE[ fx:GetFlags() ] or PALETTE[ 0 ]
  self.InitTime = CurTime()

  self:SetPos( self.Pos )
  local r = Vector( self.Size, self.Size, self.Size )
  self:SetRenderBounds( -r, r )
end

function EFFECT:Think()
  return CurTime() - self.InitTime < self.DieTime
end

function EFFECT:Render()
  local t = math.Clamp( ( CurTime() - self.InitTime ) / self.DieTime, 0, 1 )
  -- canon particle: full-size pop, slight growth, fade out
  local size = self.Size * ( 0.9 + 0.25 * t )
  local a = ( 1 - t ) * ( self.Color.a / 255 )

  render.SetMaterial( RingMat )
  render.DrawQuadEasy( self.Pos, EyePos() - self.Pos, size, size,
    Color( self.Color.r, self.Color.g, self.Color.b, a * 255 ),
    0 )
end
