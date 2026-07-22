-- lua/entities/ultrakill_test_geryon_wave.lua
-- Geryon expanding waves, three canon modes:
--   "ring"     — Magenta Shockwave wall (PhysicalShockwaveMagenta: dmg 25,
--                force 10000, maxSize 100 m, wall height 60 m; speed via NW).
--   "green"    — Green Explosion cloud (Explosion dmg 30, maxSize 30 m, slow
--                expansion, high knockback; canon proximity defence).
--   "pushback" — Recover Blast (dmg 0, huge knockback; canon post-stun shove).

AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGeryon then include( "autorun/ultrakill_test_geryon_shared.lua" ) end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Geryon Wave"
ENT.Category = UKGeryon.CATEGORY
ENT.Spawnable = false

local UNIT = UKGeryon.UNIT
local SND = UKGeryon.SOUND

local MODES = {
  ring = {
    damage = UKGeryon.CLAP_DAMAGE, maxR = UKGeryon.CLAP_MAX_R,
    push = UKGeryon.CLAP_PUSH, halfHeight = UKGeryon.CLAP_HEIGHT / 2,
    thickness = 60,
  },
  green = {
    damage = UKGeryon.GREEN_DAMAGE, maxR = UKGeryon.GREEN_MAX_R,
    push = UKGeryon.GREEN_PUSH, sphere = true,
  },
  pushback = {
    damage = 0, maxR = UKGeryon.GREEN_MAX_R,
    push = UKGeryon.RECOVER_PUSH, sphere = true,
  },
}

function ENT:UKG_Mode()
  return self:GetNW2String( "UKG_Mode", "ring" )
end

function ENT:UKG_Def()
  return MODES[ self:UKG_Mode() ] or MODES.ring
end

function ENT:UKG_Speed()
  local mode = self:UKG_Mode()
  if mode == "ring" then
    return self:GetNW2Float( "UKG_Speed", UKGeryon.CLAP_SPEED )
  end
  -- green/pushback expand over a fixed grow time
  return self:UKG_Def().maxR / UKGeryon.GREEN_GROW_TIME
end

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate.mdl" )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:SetNoDraw( true )
    self:DrawShadow( false )

    self.UKG_Born = CurTime()
    self.UKG_Radius = 0
    self.UKG_Hit = {}
    self:SetNW2Float( "UKG_Born", self.UKG_Born )

    local mode = self:UKG_Mode()
    if mode == "green" then
      self:EmitSound( SND.Beam, 90, 140, 0.9 )
    elseif mode == "pushback" then
      self:EmitSound( SND.ArrowShort, 90, 80, 1 )
    end
  end

  function ENT:Think()
    local def = self:UKG_Def()
    local dt = FrameTime()
    self.UKG_Radius = self.UKG_Radius + self:UKG_Speed() * dt
    self:SetNW2Float( "UKG_Radius", self.UKG_Radius )

    if self.UKG_Radius >= def.maxR then
      self:Remove()
      return
    end

    local origin = self:GetPos()
    local owner = self:GetOwner()
    local r = self.UKG_Radius

    for _, ent in ipairs( ents.FindInSphere( origin, r + 100 ) ) do
      if not IsValid( ent ) or ent == self or ent == owner then continue end
      if self.UKG_Hit[ ent ] then continue end
      local isPlayer = ent:IsPlayer()
      if isPlayer and not ent:Alive() then continue end
      if not isPlayer then
        if not ( ent:IsNPC() or ent:IsNextBot() ) then continue end
        if ent:GetClass() == UKGeryon.CLASS.Regular then continue end
      end

      local p = ent:WorldSpaceCenter()
      local flat = Vector( p.x - origin.x, p.y - origin.y, 0 )
      local d = flat:Length()

      local inside
      if def.sphere then
        inside = p:Distance( origin ) <= r
      else
        -- expanding wall ring: radial band + height band
        inside = math.abs( d - r ) <= def.thickness + ent:BoundingRadius() * 0.5
          and math.abs( p.z - origin.z ) <= def.halfHeight
      end
      if not inside then continue end

      self.UKG_Hit[ ent ] = true

      if def.damage > 0 then
        local dmg = DamageInfo()
        dmg:SetDamage( UKGeryon.ScaleAttackDamage( ent, def.damage, self:GetOwner() ) )
        dmg:SetDamageType( DMG_SONIC )
        dmg:SetAttacker( IsValid( owner ) and owner or self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( p )
        ent:TakeDamageInfo( dmg )
      end

      -- canon knockback: shockwaves hurl the player outwards
      local dir = def.sphere and ( p - origin ):GetNormalized()
        or ( d > 1 and flat / d or ent:GetForward() )
      local push = dir * def.push + Vector( 0, 0, def.push * 0.25 )
      if isPlayer then
        ent:SetVelocity( push )
      elseif ent.IsDrGNextbot then
        local loco = ent.loco
        if loco then loco:SetVelocity( loco:GetVelocity() + push ) end
      end
    end

    self:NextThink( CurTime() )
    return true
  end

end

if CLIENT then

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local SEGS = 40

  function ENT:Initialize()
    local r = self:UKG_Def().maxR
    self:SetRenderBounds( Vector( -r, -r, -r ), Vector( r, r, r ) )
  end

  function ENT:Draw() end

  function ENT:DrawTranslucent()
    local mode = self:UKG_Mode()
    local def = self:UKG_Def()
    local r = self:GetNW2Float( "UKG_Radius", 0 )
    if r < 1 then return end
    local origin = self:GetPos()
    local frac = math.Clamp( r / def.maxR, 0, 1 )
    local alpha = 255 * ( 1 - frac * 0.7 )

    if mode == "ring" then
      local col = UKGeryon.MAGENTA
      render.SetMaterial( MAT_BEAM )
      -- magenta wall: stacked beam rings
      for _, zf in ipairs( { -0.9, -0.45, 0, 0.45, 0.9 } ) do
        local z = def.halfHeight * zf
        local prev
        for i = 0, SEGS do
          local a = i / SEGS * math.pi * 2
          local pt = origin + Vector( math.cos( a ) * r, math.sin( a ) * r, z )
          if prev then
            render.DrawBeam( prev, pt, 120, 0, 1,
              Color( col.r, col.g, col.b, alpha * ( 1 - math.abs( zf ) * 0.5 ) ) )
          end
          prev = pt
        end
      end
    else
      local col = mode == "green" and UKGeryon.GREEN or Color( 255, 255, 255 )
      render.SetMaterial( MAT_GLOW )
      render.DrawSprite( origin, r * 2.2, r * 2.2,
        Color( col.r, col.g, col.b, alpha * 0.55 ) )
      render.DrawSprite( origin, r * 1.2, r * 1.2,
        Color( 255, 255, 255, alpha * 0.4 ) )
      -- lightning crackle for the green defence blast
      if mode == "green" then
        render.SetMaterial( MAT_BEAM )
        for i = 1, 6 do
          local a = math.Rand( 0, math.pi * 2 )
          local dir = Vector( math.cos( a ), math.sin( a ), math.Rand( -0.5, 0.5 ) ):GetNormalized()
          render.DrawBeam( origin, origin + dir * r, 24, 0, 1,
            Color( col.r, col.g, col.b, alpha ) )
        end
      end
    end
  end

end
