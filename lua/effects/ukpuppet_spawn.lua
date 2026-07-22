-- Spawn FX: vertical blood column + outward burst.
-- Pool removed (kept invisible across attempts; not worth more debug time).
-- Distortion removed earlier (too weak to read on a small target rect).

local mPulse = Material( "effects/ukpuppet_pulse" )
local mPuff  = "effects/blood_puff"

EFFECT.Lifetime = 1.4

function EFFECT:Init( data )
  self.Origin    = data:GetOrigin()
  self.StartTime = CurTime()
  self.Magnitude = data:GetMagnitude() > 0 and data:GetMagnitude() or 60
  self.Emitter   = ParticleEmitter( self.Origin )

  -- Vertical blood column
  for i = 1, 120 do
    local p = self.Emitter:Add( mPuff, self.Origin + VectorRand() * 10 )
    if p then
      p:SetVelocity( Vector( math.Rand( -25, 25 ), math.Rand( -25, 25 ), math.Rand( 120, 280 ) ) )
      p:SetDieTime( math.Rand( 0.5, 1.1 ) )
      p:SetStartAlpha( 240 )
      p:SetEndAlpha( 0 )
      p:SetStartSize( math.Rand( 10, 22 ) )
      p:SetEndSize( math.Rand( 4, 10 ) )
      p:SetGravity( Vector( 0, 0, -60 ) )
      p:SetCollide( false )
      p:SetColor( math.Rand( 180, 230 ), 0, 0 )
      p:SetAirResistance( 30 )
    end
  end

  -- Outward burst at the base
  for i = 1, 30 do
    local p = self.Emitter:Add( mPuff, self.Origin )
    if p then
      local ang = math.rad( math.Rand( 0, 360 ) )
      local vel = math.Rand( 80, 180 )
      p:SetVelocity( Vector( math.cos( ang ) * vel, math.sin( ang ) * vel, math.Rand( 30, 80 ) ) )
      p:SetDieTime( math.Rand( 0.4, 0.7 ) )
      p:SetStartAlpha( 220 )
      p:SetEndAlpha( 0 )
      p:SetStartSize( math.Rand( 6, 12 ) )
      p:SetEndSize( math.Rand( 3, 6 ) )
      p:SetGravity( Vector( 0, 0, -300 ) )
      p:SetCollide( false )
      p:SetColor( math.Rand( 180, 230 ), 0, 0 )
    end
  end

  self.Emitter:Finish()
end

function EFFECT:Think()
  return ( CurTime() - self.StartTime ) < self.Lifetime
end

function EFFECT:Render()
  local t = ( CurTime() - self.StartTime ) / self.Lifetime
  if t > 1 then return end

  render.SetMaterial( mPulse )
  local size = 80 + 120 * t
  render.DrawSprite( self.Origin + Vector( 0, 0, 30 ), size, size, Color( 255, 0, 0, ( 1 - t ) * 240 ) )

  if t < 0.7 then
    local peakAlpha = ( 1 - t / 0.7 ) * 200
    render.DrawSprite( self.Origin + Vector( 0, 0, 60 + t * 80 ), 50, 50, Color( 255, 60, 60, peakAlpha ) )
  end
end
