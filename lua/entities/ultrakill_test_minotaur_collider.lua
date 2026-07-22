AddCSLuaFile()

if not UKMinotaur then include( "autorun/ultrakill_test_minotaur_shared.lua" ) end

-- Invisible body collision box for the Minotaur (gutterman-shield idiom,
-- leviathan collider pattern). GMod nextbots never physically block players,
-- so the long quadruped body gets frozen VPhysics boxes that follow the boss
-- every tick. Damage on a box is forwarded as plain body damage; the
-- fractured-head zone is deliberately box-free so weak-point shots land.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minotaur Collider"
ENT.Spawnable = false

-- the boss's own melee/explosions/acid skip anything with this flag
ENT.UKMinotaur_IsMinotaur = true
ENT.UKM_IsCollider = true

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate2x3.mdl" )
    self:SetNoDraw( true )
    local mins = self.UKM_Mins or Vector( -40, -30, 0 )
    local maxs = self.UKM_Maxs or Vector( 40, 30, 100 )
    self:PhysicsInitBox( mins, maxs )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionBounds( mins, maxs )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetCustomCollisionCheck( true )   -- else the ShouldCollide hook is never asked
    self:CollisionRulesChanged()
    self:SetTrigger( false )
    self:DrawShadow( false )

    -- Arms REVAMPED feedbacker refuses to damage Health() < 1 entities
    -- (gutterman shield lesson); forwarding keeps it pinned at 100
    self:SetMaxHealth( 100 )
    self:SetHealth( 100 )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
    else
      self:SetSolid( SOLID_BBOX )
    end
  end

  -- Follow the boss ourselves every tick (smoother than the boss's behaviour
  -- cadence — it charges at 50 m/s) and nudge out anyone trapped inside.
  function ENT:Think()
    local boss = self.UKM_ForwardTo
    if not IsValid( boss ) then
      self:Remove()
      return
    end
    self:SetPos( boss:GetPos() )
    self:SetAngles( Angle( 0, boss:GetAngles().yaw, 0 ) )

    if self:IsSolid() then
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
    end

    self:NextThink( CurTime() )
    return true
  end

  -- forward everything to the boss as plain body damage
  function ENT:OnTakeDamage( dmg )
    local target = self.UKM_ForwardTo
    if IsValid( target ) and not target.UKM_Dead then
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

  -- ULTRAKILL projectiles (incl. the Minotaur's own meat glob) fly through the
  -- body boxes, and the boss's own locomotion never trips over them;
  -- players/props still collide
  hook.Add( "ShouldCollide", "UKM_ColliderRules", function( a, b )
    if a.UKM_IsCollider then
      if b.IsUltrakillProjectile or b.UKMinotaur_IsMinotaur or b == a.UKM_ForwardTo then return false end
    end
    if b.UKM_IsCollider then
      if a.IsUltrakillProjectile or a.UKMinotaur_IsMinotaur or a == b.UKM_ForwardTo then return false end
    end
  end )

  hook.Add( "PhysgunPickup", "UKM_ColliderNoPhysgun", function( _, ent )
    if ent.UKM_IsCollider then return false end
  end )

end
