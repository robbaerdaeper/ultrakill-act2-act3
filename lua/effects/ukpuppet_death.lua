-- Death FX: chunky blood explosion when a puppeted entity dies.

local mPuff = "effects/blood_puff"

EFFECT.Lifetime = 1.5

function EFFECT:Init( data )
  self.Origin    = data:GetOrigin()
  self.StartTime = CurTime()
  self.Magnitude = data:GetMagnitude() > 0 and data:GetMagnitude() or 80

  local emitter = ParticleEmitter( self.Origin )

  -- Spherical burst — 180 particles in all directions
  for i = 1, 180 do
    local p = emitter:Add( mPuff, self.Origin )
    if not p then break end
    local dir = VectorRand()
    if dir:LengthSqr() < 0.01 then dir = Vector( 0, 0, 1 ) end
    dir:Normalize()
    local spd = math.Rand( 200, 500 )
    p:SetVelocity( dir * spd + Vector( 0, 0, math.Rand( 50, 150 ) ) )
    p:SetDieTime( math.Rand( 0.6, 1.4 ) )
    p:SetStartAlpha( 240 )
    p:SetEndAlpha( 0 )
    p:SetStartSize( math.Rand( 12, 26 ) )
    p:SetEndSize( math.Rand( 4, 10 ) )
    p:SetGravity( Vector( 0, 0, -500 ) )
    p:SetCollide( true )
    p:SetBounce( 0.1 )
    p:SetColor( math.Rand( 180, 230 ), 0, 0 )
    p:SetAirResistance( 25 )
  end

  -- Heavy chunks — slower, fall faster
  for i = 1, 40 do
    local p = emitter:Add( mPuff, self.Origin + VectorRand() * 6 )
    if not p then break end
    p:SetVelocity( VectorRand() * math.Rand( 60, 140 ) + Vector( 0, 0, math.Rand( 80, 200 ) ) )
    p:SetDieTime( math.Rand( 1.0, 1.8 ) )
    p:SetStartAlpha( 255 )
    p:SetEndAlpha( 200 )
    p:SetStartSize( math.Rand( 18, 34 ) )
    p:SetEndSize( math.Rand( 14, 22 ) )
    p:SetGravity( Vector( 0, 0, -700 ) )
    p:SetCollide( true )
    p:SetBounce( 0.15 )
    p:SetColor( math.Rand( 150, 200 ), 0, 0 )
  end

  emitter:Finish()
end

function EFFECT:Think()
  return ( CurTime() - self.StartTime ) < self.Lifetime
end

function EFFECT:Render()
end
