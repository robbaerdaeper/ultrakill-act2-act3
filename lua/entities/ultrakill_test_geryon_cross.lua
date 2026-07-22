-- lua/entities/ultrakill_test_geryon_cross.lua
-- Geryon Magenta Cross (canon 'Projectile Providence Geryon').
-- Identical to the Providence cross orb but slower (40 m/s) and with the
-- optional slow spin of the final pair. Parryable/reflectable — canon strategy
-- is punching it right back into Geryon.

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGeryon then include( "autorun/ultrakill_test_geryon_shared.lua" ) end

ENT.Base = "ultrakillbase_projectile"

ENT.PrintName = "Geryon Magenta Cross"
ENT.Category = UKGeryon.CATEGORY
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 0.8
ENT.Spawnable = false

ENT.UltrakillBase_HomingType = -1  -- straight flight (canon turnSpeed 0)
ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 10, 10, 10 )

local SND = UKGeryon.SOUND
local MAGENTA = UKGeryon.MAGENTA

-- cross beam directions: up/right in the projectile's roll frame (the shots
-- are rolled +15 deg per shot, the final pair spins via UKG_Spin)
local function CrossDirs( self, dir )
  local ang = dir:Angle()
  ang:RotateAroundAxis( dir, self.UKG_Roll or 0 )
  local up, right = ang:Up(), ang:Right()
  return { up, -up, right, -right }
end

if SERVER then

  function ENT:CustomInitialize()
    self:SetMaterial( "models/ultrakill/vfx/Skulls/Skull2_4" )
    self:SetColor( MAGENTA )

    self.UKG_HitCD = {}
    self.UKG_NextBeamTick = 0
    self.UKG_Roll = self:GetAngles().roll or 0

    self:EmitSound( SND.ArrowShort, 75, math.random( 95, 110 ), 0.6 )

    SafeRemoveEntityDelayed( self, UKGeryon.CROSS_LIFETIME )
  end

  function ENT:OnTakeDamage( CDamageInfo )
    self:CheckReflect( CDamageInfo )
    self:CheckParry( CDamageInfo )
  end

  function ENT:CustomThink()
    if self:GetParried() then return end
    -- canon Spin component: the final pair slowly rotates its cross
    local spin = self:GetNW2Float( "UKG_Spin", 0 )
    if spin ~= 0 then
      self.UKG_Roll = ( self.UKG_Roll or 0 ) + spin * FrameTime()
    end

    if CurTime() < self.UKG_NextBeamTick then return end
    self.UKG_NextBeamTick = CurTime() + 0.1

    local vel = self:GetVelocity()
    if vel:LengthSqr() < 1 then return end
    local dir = vel:GetNormalized()
    local owner = self:GetOwner()
    for _, d in ipairs( CrossDirs( self, dir ) ) do
      UKGeryon.DamageBeamSegment( owner, self, self:GetPos(), d,
        UKGeryon.CROSS_BEAM_RANGE, UKGeryon.CROSS_BEAM_RADIUS,
        UKGeryon.CROSS_BEAM_DAMAGE, false, self.UKG_HitCD )
    end
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then return self:ParryCollide( 25000 ) end

    self:EmitSound( SND.Beam, 80, 130, 0.7 )
    local ed = EffectData()
    ed:SetOrigin( self:GetPos() )
    util.Effect( "cball_explode", ed )

    if IsValid( mEntity ) and ( mEntity:IsPlayer() or mEntity:IsNPC() or mEntity:IsNextBot() )
       and mEntity:GetClass() ~= UKGeryon.CLASS.Regular then
      local dmg = DamageInfo()
      dmg:SetDamage( UKGeryon.ScaleAttackDamage( mEntity, UKGeryon.CROSS_DAMAGE, self:GetOwner() ) )
      dmg:SetDamageType( DMG_ENERGYBEAM )
      local owner = self:GetOwner()
      dmg:SetAttacker( IsValid( owner ) and owner or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( self:GetPos() )
      mEntity:TakeDamageInfo( dmg )
    end
    self:Remove()
  end

end

if CLIENT then

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL_BEAM = Color( MAGENTA.r, MAGENTA.g, MAGENTA.b, 220 )
  local COL_BEAM_SOFT = Color( MAGENTA.r, MAGENTA.g, MAGENTA.b, 70 )
  local RB = Vector( 4200, 4200, 4200 )

  function ENT:CustomInitialize()
    self:SetRenderBounds( -RB, RB )
  end

  function ENT:CustomDraw()
    local pos = self:GetPos()

    render.SetMaterial( MAT_GLOW )
    render.DrawSprite( pos, 70, 70, COL_BEAM )
    render.DrawSprite( pos, 32, 32, Color( 255, 200, 240, 255 ) )

    if self:GetParried() then return end -- canon: beams die on parry

    local vel = self:GetVelocity()
    if vel:LengthSqr() < 1 then return end
    local dir = vel:GetNormalized()

    -- the four cross beams (rolled by the shot offset + optional slow spin)
    local spin = self:GetNW2Float( "UKG_Spin", 0 )
    self.UKG_RollCl = ( self.UKG_RollCl or self:GetAngles().roll or 0 )
      + spin * FrameTime()
    local ang = dir:Angle()
    ang:RotateAroundAxis( dir, self.UKG_RollCl )
    render.SetMaterial( MAT_BEAM )
    for _, d in ipairs( { ang:Up(), ang:Up() * -1, ang:Right(), ang:Right() * -1 } ) do
      local tr = util.TraceLine( { start = pos, endpos = pos + d * UKGeryon.CROSS_BEAM_RANGE,
                                   mask = MASK_SOLID_BRUSHONLY } )
      render.DrawBeam( pos, tr.HitPos, 12, 0, 1, COL_BEAM )
      render.DrawBeam( pos, tr.HitPos, 34, 0, 1, COL_BEAM_SOFT )
    end
  end

end

AddCSLuaFile()
