-- Guttertank rocket proximity windup — canon Grenade.proximityWindup: the
-- moment the rocket freezes mid-air a warning sphere pops around it and
-- rapidly shrinks into the body over the 0.5 s fuse, then the blast follows.
-- Rendering recipe mirrors ultrakill_test_softexplosion (sphere mesh +
-- MaterialOverride), just played backwards and tinted warning-orange.

local Vector = Vector
local Angle = Angle
local CurTime = CurTime
local ClientsideModel = ClientsideModel
local Material = Material
local Lerp = Lerp
local OutCirc = math.ease.OutCirc
local RMaterialOverride = CLIENT and render.MaterialOverride
local RSetBlend = CLIENT and render.SetBlend
local RSetColorModulation = CLIENT and render.SetColorModulation
local CLuaEffect = UltrakillBase and UltrakillBase.CLuaEffect or nil

local DIE_TIME = 0.5        -- matches the UKGT_Freeze fuse
local SPHERE_BASE = 8       -- Sphere_8.mdl radius at scale 1 (su)

-- round 3 (2026-07-10): the r2 CreateMaterial(UnlitGeneric) rendered NOTHING;
-- the working look is Kevin's fresnel envmap bubble (the visible white
-- sphere from r1) — so use a file-based clone of that VMT with the
-- $EnvMapTint pre-baked orange ($Color2 [0 0 0] kills any runtime tint)
local SphereMaterial = Material( "ultrakill_test/gt_windup_sphere" )
local AngleOffset = Angle( 90, 0, 0 )


function EFFECT:Init( CEffectData )

  local Pos = CEffectData:GetOrigin()
  self.StartRadius = CEffectData:GetRadius() > 0 and CEffectData:GetRadius() or 110
  self.InitTime = CurTime()

  self:SetPos( Pos )
  local bounds = Vector( 1, 1, 1 ) * ( self.StartRadius + 32 )
  self:SetRenderBounds( -bounds, bounds )

  self.Sphere = ClientsideModel( "models/ultrakill/mesh/effects/sphere/Sphere_8.mdl", RENDERGROUP_BOTH )
  AngleOffset:Random( -45, 45 )
  self.Sphere:SetPos( Pos )
  self.Sphere:SetAngles( AngleOffset )
  self.Sphere:SetNoDraw( true )

  -- warning light on the frozen rocket
  local dl = DynamicLight( self:EntIndex() )
  if dl then
    dl.pos = Pos
    dl.r, dl.g, dl.b = 255, 140, 40
    dl.brightness = 2
    dl.size = self.StartRadius * 2
    dl.decay = self.StartRadius * 4
    dl.dietime = CurTime() + DIE_TIME
  end

  if CLuaEffect and CLuaEffect.AddToGarbageCollector then
    CLuaEffect.AddToGarbageCollector( self, self.Sphere )
  end

end


function EFFECT:Think()
  return CurTime() - self.InitTime <= DIE_TIME
end


function EFFECT:Render()
  if not IsValid( self.Sphere ) then return end

  local delta = ( CurTime() - self.InitTime ) / DIE_TIME
  if delta > 1 then delta = 1 end

  -- collapse: full warning bubble -> swallowed by the rocket body
  local radius = Lerp( OutCirc( delta ), self.StartRadius, 2 )

  RMaterialOverride( SphereMaterial )
  RSetBlend( 1 )

  self.Sphere:SetModelScale( radius / SPHERE_BASE )
  self.Sphere:DrawModel()
  self.Sphere:DrawModel()

  RMaterialOverride()
end
