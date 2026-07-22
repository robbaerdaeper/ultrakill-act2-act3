-- Deathcatcher open animation FX: vertical bloodsplat column + outward red ring,
-- mimics the canon "shell cracks open" reveal on first appearance in 8-2.

local mPuff = "effects/blood_puff"
local mGlow = "effects/yellowflare"

EFFECT.Lifetime = 1.4

function EFFECT:Init( data )
  self.Origin    = data:GetOrigin()
  self.StartTime = CurTime()
  self.Magnitude = data:GetMagnitude() > 0 and data:GetMagnitude() or 100

  local emitter = ParticleEmitter( self.Origin )

  -- Outward ring of red puffs at chest level
  for i = 1, 60 do
    local p = emitter:Add( mPuff, self.Origin )
    if not p then break end
    local ang = ( i / 60 ) * math.pi * 2
    local dir = Vector( math.cos( ang ), math.sin( ang ), 0 )
    local spd = math.Rand( 180, 320 )
    p:SetVelocity( dir * spd + Vector( 0, 0, math.Rand( -40, 80 ) ) )
    p:SetDieTime( math.Rand( 0.7, 1.2 ) )
    p:SetStartAlpha( 230 )
    p:SetEndAlpha( 0 )
    p:SetStartSize( math.Rand( 14, 24 ) )
    p:SetEndSize( math.Rand( 4, 10 ) )
    p:SetGravity( Vector( 0, 0, -200 ) )
    p:SetCollide( true )
    p:SetBounce( 0.1 )
    p:SetColor( math.Rand( 170, 220 ), 0, 0 )
    p:SetAirResistance( 30 )
  end

  -- Vertical column upward — "heart pulse" shoot
  for i = 1, 30 do
    local p = emitter:Add( mPuff, self.Origin + VectorRand() * 6 )
    if not p then break end
    p:SetVelocity( Vector( 0, 0, math.Rand( 200, 380 ) ) + VectorRand() * 30 )
    p:SetDieTime( math.Rand( 0.8, 1.3 ) )
    p:SetStartAlpha( 240 )
    p:SetEndAlpha( 0 )
    p:SetStartSize( math.Rand( 18, 30 ) )
    p:SetEndSize( math.Rand( 8, 16 ) )
    p:SetGravity( Vector( 0, 0, -500 ) )
    p:SetColor( math.Rand( 200, 240 ), 0, 0 )
  end

  -- Bright glow flash at center
  local flash = emitter:Add( mGlow, self.Origin )
  if flash then
    flash:SetVelocity( vector_origin )
    flash:SetDieTime( 0.4 )
    flash:SetStartAlpha( 220 )
    flash:SetEndAlpha( 0 )
    flash:SetStartSize( 100 )
    flash:SetEndSize( 200 )
    flash:SetColor( 255, 80, 80 )
  end

  emitter:Finish()
end

function EFFECT:Think()
  return ( CurTime() - self.StartTime ) < self.Lifetime
end

function EFFECT:Render()
end
