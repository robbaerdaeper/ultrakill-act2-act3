-- Power spawn intro: golden light pillar (Gabriel-intro pattern, but gold
-- transparent instead of white — canon Power is a GOLD angel).
-- EffectData: Entity = the Power, Magnitude = lifetime * 100.

local IsValid = IsValid
local CurTime = CurTime

local MinBounds = Vector( 300, 300, 100 )
local MaxBounds = Vector( 300, 300, 3500 )

local PillarMat = Material( "models/ultrakill_prelude_test/power/lightpillar" )
local ScaleVec = Vector( 1, 1, 10 )
local VMat = Matrix()

function EFFECT:Init( fx )
  self.Ent = fx:GetEntity()
  self.DieTime = math.max( fx:GetMagnitude() * 0.01, 0.5 )
  self.InitTime = CurTime()

  if not IsValid( self.Ent ) then return false end

  local pos = self.Ent:GetPos()
  self:SetRenderBounds( -MinBounds, MaxBounds )
  self:SetPos( pos )

  self.Sphere = ClientsideModel( "models/ultrakill/mesh/effects/sphere/sphere_16.mdl",
    RENDERGROUP_TRANSLUCENT )
  if not IsValid( self.Sphere ) then return false end
  self.Sphere:SetPos( pos )
  self.Sphere:SetModelScale( 19 )
  self.Sphere:SetNoDraw( true )

  self.Initialized = true
end

function EFFECT:Think()
  if CurTime() - self.InitTime > self.DieTime then
    if IsValid( self.Sphere ) then self.Sphere:Remove() end
    return false
  end
  if not IsValid( self.Ent ) then
    if IsValid( self.Sphere ) then self.Sphere:Remove() end
    return false
  end
  return true
end

function EFFECT:Render()
  if not self.Initialized or not IsValid( self.Sphere ) then return end

  -- fade out over the last 30%
  local t = ( CurTime() - self.InitTime ) / self.DieTime
  local a = t > 0.7 and ( 1 - t ) / 0.3 or 1

  render.MaterialOverride( PillarMat )
  render.SetBlend( a )

  VMat:Identity()
  VMat:SetScale( ScaleVec )
  self.Sphere:EnableMatrix( "RenderMultiply", VMat )
  self.Sphere:DrawModel()

  render.SetBlend( 1 )
  render.MaterialOverride()

  local dl = DynamicLight( self:EntIndex() + 20000 )
  if dl then
    dl.pos = self:GetPos() + Vector( 0, 0, 120 )
    dl.r, dl.g, dl.b = 255, 200, 60
    dl.brightness = 2.5 * a
    dl.size = 480
    dl.decay = 0
    dl.dietime = CurTime() + 0.1
  end
end
