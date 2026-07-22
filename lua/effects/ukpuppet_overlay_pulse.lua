-- Light overlay pulse for cross-NPC apply (Tool Gun). NO body fade-out.
-- A red sprite expands quickly around the target and fades.

local mPulse = Material( "effects/ukpuppet_pulse" )

EFFECT.Lifetime = 0.4

function EFFECT:Init( data )
  self.Origin    = data:GetOrigin()
  self.Scale     = data:GetMagnitude() > 0 and data:GetMagnitude() or 60
  self.StartTime = CurTime()
  self.Emitter   = ParticleEmitter( self.Origin )

  -- 4 small blood specks
  for i = 1, 4 do
    local p = self.Emitter:Add( "effects/blood_puff", self.Origin + VectorRand() * self.Scale * 0.5 )
    if p then
      p:SetVelocity( VectorRand() * 30 )
      p:SetDieTime( 0.5 )
      p:SetStartAlpha( 200 )
      p:SetEndAlpha( 0 )
      p:SetStartSize( 6 )
      p:SetEndSize( 2 )
      p:SetGravity( Vector( 0, 0, -80 ) )
      p:SetCollide( false )
      p:SetColor( 200, 0, 0 )
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
  local size = self.Scale * ( 0.6 + 0.6 * t )
  render.DrawSprite( self.Origin, size, size, Color( 255, 30, 30, ( 1 - t ) * 220 ) )
end
