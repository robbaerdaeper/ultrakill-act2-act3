-- Red overlay for the Minotaur's HammerSmash pull-out (canon: "a red super
-- explosion"). Layered on top of the stock Ultrakill_Explosion effect, which
-- has no color parameter: red shockwave ring + red core flash + red light.

local ShockwaveMat = "particles/ultrakill/Shockwave_NoCull"
local GlowMat = "sprites/light_glow02_add"

function EFFECT:Init( data )
  local pos = data:GetOrigin()
  local radius = math.max( data:GetRadius(), 60 )

  local dl = DynamicLight( math.random( 2048, 4095 ) )
  if dl then
    dl.pos = pos + Vector( 0, 0, 12 )
    dl.r, dl.g, dl.b = 255, 30, 10
    dl.brightness = 4
    dl.decay = 900
    dl.size = radius * 2.5
    dl.dietime = CurTime() + 0.5
  end

  -- flat ground ring wants a 3D particle; glows/sparks stay 2D billboards
  local emitter3d = ParticleEmitter( pos, true )
  if emitter3d then
    local ring = emitter3d:Add( ShockwaveMat, pos + Vector( 0, 0, 5 ) )
    if ring then
      ring:SetAngles( Vector( 0, 0, -1 ):Angle() ) -- sprite plane horizontal
      ring:SetDieTime( 0.45 )
      ring:SetStartSize( 0 )
      ring:SetEndSize( radius * 4 )
      ring:SetStartAlpha( 220 )
      ring:SetEndAlpha( 0 )
      ring:SetColor( 255, 45, 20 )
    end
    emitter3d:Finish()
  end

  local emitter = ParticleEmitter( pos )
  if not emitter then return end

  for i = 1, 3 do
    local core = emitter:Add( GlowMat, pos + Vector( 0, 0, 8 ) )
    if core then
      core:SetDieTime( 0.25 + i * 0.08 )
      core:SetStartSize( radius * ( 0.9 + i * 0.35 ) )
      core:SetEndSize( radius * ( 1.6 + i * 0.5 ) )
      core:SetStartAlpha( 200 - i * 40 )
      core:SetEndAlpha( 0 )
      core:SetColor( 255, 40 + i * 15, 15 )
    end
  end

  -- red embers
  for _ = 1, 14 do
    local dir = VectorRand()
    dir.z = math.abs( dir.z ) * 0.8
    dir:Normalize()
    local spark = emitter:Add( GlowMat, pos + dir * radius * 0.2 )
    if spark then
      spark:SetVelocity( dir * math.Rand( 200, 520 ) )
      spark:SetGravity( Vector( 0, 0, -400 ) )
      spark:SetDieTime( math.Rand( 0.35, 0.7 ) )
      spark:SetStartSize( math.Rand( 4, 9 ) )
      spark:SetEndSize( 0 )
      spark:SetStartAlpha( 255 )
      spark:SetEndAlpha( 0 )
      spark:SetColor( 255, math.random( 30, 90 ), 15 )
    end
  end

  emitter:Finish()
end

function EFFECT:Think()
  return false
end

function EFFECT:Render()
end
