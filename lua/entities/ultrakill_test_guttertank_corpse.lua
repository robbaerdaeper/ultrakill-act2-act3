AddCSLuaFile()
include( "autorun/ultrakill_test_guttertank_shared.lua" )

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Guttertank Corpse"
-- death now shatters the tank into gibs; the inert corpse stays around as a
-- fun spawnable prop (Q menu -> Entities)
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL"

-- Lying-pose physics box (Death final frame: the tank tips over; keep the
-- box near-symmetric until the fall direction is verified in-game).
local CORPSE_MINS = Vector( -100, -70, 0 )
local CORPSE_MAXS = Vector( 140, 70, 75 )

if SERVER then

  function ENT:Initialize()
    self:SetModel( UKGuttertank.MODEL )

    local seq = self:LookupSequence( "Death" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetCycle( 1 )
      self:SetPlaybackRate( 0 )
    end

    self:PhysicsInitBox( CORPSE_MINS, CORPSE_MAXS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionBounds( CORPSE_MINS, CORPSE_MAXS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )

    self.UKGT_Corpse = true
    self.UKGT_LastBlood = 0

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:Wake()
      phys:SetMass( 2500 )
      phys:SetDamping( 0.4, 6 )
      phys:SetMaterial( "metal" )
    end
  end

  function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

    -- corpse blood is visual only: this entity is not IsUltrakillNextbot,
    -- so the base healing path never triggers off it
    if CurTime() >= self.UKGT_LastBlood + 0.15 and UltrakillBase and UltrakillBase.CreateBlood then
      self.UKGT_LastBlood = CurTime()
      local pos = dmg:GetDamagePosition()
      if pos:IsZero() then pos = self:WorldSpaceCenter() end
      UltrakillBase.CreateBlood( pos, math.random( 6, 10 ) )
    end
  end

end
