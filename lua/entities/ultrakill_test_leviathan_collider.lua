AddCSLuaFile()

if not UKLeviathan then include( "autorun/ultrakill_test_leviathan_shared.lua" ) end

-- Invisible static collision box for the Leviathan (gutterman-shield idiom).
-- GMod nextbots never physically block players, so the colossal serpent body
-- needs frozen VPhysics boxes the player can actually stand against. Damage
-- that lands on a box is forwarded to the boss (plain hitgroup, no weak point).

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Leviathan Collider"
ENT.Spawnable = false

-- attacks/beam/orb checks of the boss skip anything with this flag
ENT.UKLev_IsLeviathan = true
ENT.UKLev_IsCollider = true

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate2x3.mdl" )
    self:SetNoDraw( true )
    local mins = self.UKLev_Mins or Vector( -50, -50, 0 )
    local maxs = self.UKLev_Maxs or Vector( 50, 50, 100 )
    self:PhysicsInitBox( mins, maxs )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionBounds( mins, maxs )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetCustomCollisionCheck( true )   -- else the ShouldCollide hook is never asked
    self:CollisionRulesChanged()
    self:SetTrigger( false )
    self:DrawShadow( false )

    -- Arms REVAMPED feedbacker refuses to damage Health() < 1 entities, so the
    -- box stays pinned at 100 (gutterman shield lesson); forwarding keeps it up.
    self:SetMaxHealth( 100 )
    self:SetHealth( 100 )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
    else
      -- PhysicsInitBox can fail on very large boxes: fall back to OBB solid
      self:SetSolid( SOLID_BBOX )
    end
  end

  -- The boxes rotate with the boss (beam sweep) — anything that ends up inside
  -- gets nudged out sideways so nobody is trapped (gutterman-shield pattern).
  function ENT:Think()
    if not self:IsSolid() then
      self:NextThink( CurTime() + 0.2 )
      return true
    end
    local mins, maxs = self:WorldSpaceAABB()
    local bmin, bmax = self:GetCollisionBounds()
    for _, ent in ipairs( ents.FindInBox( mins, maxs ) ) do
      if not IsValid( ent ) or not ent:IsPlayer() or not ent:Alive() then continue end
      -- world AABB of the rotated box over-covers: confirm truly inside the OBB
      local lp = self:WorldToLocal( ent:WorldSpaceCenter() )
      if lp.x < bmin.x or lp.x > bmax.x or lp.y < bmin.y or lp.y > bmax.y
          or lp.z < bmin.z or lp.z > bmax.z then continue end
      local dir = ent:WorldSpaceCenter() - self:LocalToWorld( ( bmin + bmax ) * 0.5 )
      dir.z = 0
      if dir:IsZero() then dir = self:GetForward() end
      ent:SetPos( ent:GetPos() + dir:GetNormalized() * 8 )
    end
    self:NextThink( CurTime() )
    return true
  end

  -- forward everything to the boss as plain body damage
  function ENT:OnTakeDamage( dmg )
    local target = self.UKLev_ForwardTo
    if IsValid( target ) and not target.UKLev_Dead then
      local fwd = DamageInfo()
      fwd:SetDamage( dmg:GetDamage() )
      fwd:SetDamageType( dmg:GetDamageType() )
      fwd:SetAttacker( IsValid( dmg:GetAttacker() ) and dmg:GetAttacker() or self )
      fwd:SetInflictor( IsValid( dmg:GetInflictor() ) and dmg:GetInflictor() or self )
      fwd:SetDamagePosition( dmg:GetDamagePosition() )
      target:TakeDamageInfo( fwd )
    end
    self:SetHealth( 100 )
    dmg:SetDamage( 0 )
    return 0
  end

  -- ULTRAKILL projectiles must fly through the body boxes (the boss's own
  -- barrage spawns at the mouth right above them); players/props still collide
  hook.Add( "ShouldCollide", "UKLev_ColliderVsProjectiles", function( a, b )
    if a.UKLev_IsCollider and b.IsUltrakillProjectile then return false end
    if b.UKLev_IsCollider and a.IsUltrakillProjectile then return false end
  end )

  hook.Add( "PhysgunPickup", "UKLev_ColliderNoPhysgun", function( _, ent )
    if ent.UKLev_IsCollider then return false end
  end )

end
