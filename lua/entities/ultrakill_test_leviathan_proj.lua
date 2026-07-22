AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKLeviathan then include( "autorun/ultrakill_test_leviathan_shared.lua" ) end

-- Leviathan Hell Orb (canon DefaultReferenceManager.projectile, x2 scale).
-- 25 dmg contact; every 20th in a barrage is the explosive Energy Orb variant
-- (canon projectileExplosive: 20 center / 13 falloff, big knockback).
-- Parryable/deflectable ("proj" in the classname enables feedbacker parry).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Leviathan Hell Orb"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 2.0
ENT.Spawnable = false
ENT.Gravity = false

ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 20, 20, 20 )

ENT.UKLev_Explosive = false

local SND = UKLeviathan.SOUND

if SERVER then

  function ENT:CustomInitialize()
    if self.UKLev_Explosive then
      -- canon Energy Orb: yellow, explosive
      self:SetColor( Color( 255, 220, 80, 255 ) )
      self:SetModelScale( 2.5 )
      util.SpriteTrail( self, 0, Color( 255, 220, 90 ), false, 14, 20, 0.35,
        2 / 16 * 0.5, "trails/laser" )
    else
      -- canon Hell Orb: red
      self:SetColor( Color( 255, 70, 50, 255 ) )
      util.SpriteTrail( self, 0, Color( 255, 80, 50 ), false, 10, 16, 0.3,
        2 / 16 * 0.5, "trails/laser" )
    end
    self:SetMaterial( "lights/white" )
    SafeRemoveEntityDelayed( self, 8 )
  end

  function ENT:UKLev_Hit( ent )
    if not IsValid( ent ) then return end
    if ent.UKLev_IsLeviathan then return end
    local base = UKLeviathan.ORB_DAMAGE
    local amount
    if ent:IsPlayer() then
      amount = UKLeviathan.ScaleAttackDamage( ent, base )
    else
      -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
      amount = ent.IsUltrakillNextbot
        and UKNpcDmg.PreMult( ent, self:GetOwner(), base * 100 )
        or base
    end
    local dmg = DamageInfo()
    dmg:SetDamage( amount )
    dmg:SetDamageType( DMG_ENERGYBEAM )
    local owner = self:GetOwner()
    dmg:SetAttacker( IsValid( owner ) and owner or self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    dmg:SetDamageForce( self:GetForward() * 400 )
    ent:TakeDamageInfo( dmg )
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then return self:ParryCollide( 25000 ) end
    if IsValid( mEntity ) and ( mEntity.UKLev_IsLeviathan and not self:GetParried() ) then
      return
    end

    if self.UKLev_Explosive then
      -- canon Energy Orb: 20 center (x10 UKBase convention), knockback radius
      sound.Play( SND.BeamExplosion, self:GetPos(), 110, 120, 0.8 )
      self:Explosion( self:GetPos(), UKLeviathan.ORB_EXPLOSIVE_DAMAGE * 10, nil,
        120, 0.35, self:GetOwner() )
      self:CreateExplosion( self:GetPos(), self:GetAngles() )
    else
      if IsValid( mEntity ) then self:UKLev_Hit( mEntity ) end
      local fx = EffectData()
      fx:SetOrigin( self:GetPos() )
      util.Effect( "ManhackSparks", fx, true, true )
    end
    self:Remove()
  end

  function ENT:OnTakeDamage( dmg )
    self:CheckReflect( dmg )
    self:CheckParry( dmg )
  end

end

if CLIENT then

  local matGlow = CreateMaterial( "UKLev_OrbGlow_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "sprites/light_glow02_add_noz",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )

  function ENT:CustomDraw()
    local pos = self:GetPos()
    local col = self:GetColor()
    render.SetMaterial( matGlow )
    render.DrawQuadEasy( pos, EyePos() - pos, 70, 70,
      Color( col.r, col.g, col.b, 220 ), 0 )
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = pos
      dl.r, dl.g, dl.b = col.r, col.g, col.b
      dl.brightness = 1
      dl.size = 140
      dl.decay = 0
      dl.dietime = CurTime() + 0.1
    end
  end

end
