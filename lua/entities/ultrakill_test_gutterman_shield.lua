AddCSLuaFile()
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gutterman Shield Helper"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- Shield mesh bounds live in the shared file (the base uses them for the
-- frontal-blast gate); keep hot local aliases for the per-tick math here.
local SHIELD_MINS = UKGutterman.SHIELD_MINS
local SHIELD_MAXS = UKGutterman.SHIELD_MAXS

-- The collision box must never wander away from the model: server-side bone
-- matrices on nextbots can go stale/garbage, which used to leave a phantom
-- shield hitbox far from the Gutterman. 260 su covers the widest ShieldBash
-- swing (seq bbox reaches ~215 su); beyond that the matrix is garbage.
local MAX_BONE_DRIFT_SQR = 260 * 260

if SERVER then
  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate2x3.mdl" )
    self:SetNoDraw( true )
    self:PhysicsInitBox( SHIELD_MINS, SHIELD_MAXS )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionBounds( SHIELD_MINS, SHIELD_MAXS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )
    self:SetTrigger( false )
    self:DrawShadow( false )
    self.UKGutterman_IsShieldHelper = true

    -- The Knuckleblaster punch (Arms REVAMPED vmanipfeedbacker) refuses to
    -- deal damage to entities with Health() < 1, so a 0-HP helper would eat
    -- the punch without ever reaching OnTakeDamage -> UKGutterman_TryShieldBreak.
    -- Anim SENTs only lose health if we do it ourselves, so this stays pinned.
    self:SetMaxHealth( 100 )
    self:SetHealth( 100 )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
    end
  end

  function ENT:SetGuttermanOwner( owner )
    self.UKGutterman_Owner = owner
    -- owner system: no collision between the Gutterman and its own shield,
    -- and the owner's own traces skip it explicitly in the base file
    self:SetOwner( owner )
  end

  function ENT:Think()
    local owner = self.UKGutterman_Owner
    -- Self-destruct on EVERY path that ends the shield: owner gone, owner
    -- dead, or the shield broken by any means. Guarantees no phantom hitbox
    -- can outlive a shield break even if the owner's reference was lost.
    if not IsValid( owner ) or owner.UKGutterman_Dead or not owner.UKGutterman_HasShield then
      self:Remove()
      return
    end

    self:UKGutterman_UpdatePose( owner )
    self:UKGutterman_RejectWhiplash()
    self:UKGutterman_DeflectIncoming()
    self:UKGutterman_PushOutOverlaps()
    self:NextThink( CurTime() )
    return true
  end

  -- The frozen VPhysics box does NOT follow SetPos/SetAngles on its own: the
  -- entity teleports but the physics shape (what bullet/hitscan traces
  -- actually hit) stays behind, so every shot went straight through the
  -- shield. Teleport the phys object explicitly every time the pose moves.
  function ENT:UKGutterman_ApplyPose( pos, ang )
    self:SetPos( pos )
    self:SetAngles( ang )
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:SetPos( pos )
      phys:SetAngles( ang )
      phys:EnableMotion( false )
    end
  end

  function ENT:UKGutterman_UpdatePose( owner )
    local bone = owner:LookupBone( "Shield 1" )
    if bone then
      local m = owner:GetBoneMatrix( bone )
      if m then
        local pos = m:GetTranslation()
        if pos:DistToSqr( owner:WorldSpaceCenter() ) < MAX_BONE_DRIFT_SQR then
          self.UKGutterman_HadGoodPose = true
          self:UKGutterman_ApplyPose( pos, m:GetAngles() )
          return
        end
      end
    end

    -- Bad/garbage matrix: KEEP the last good pose instead of snapping to a
    -- fallback point — teleporting the box around made the collision flicker.
    if self.UKGutterman_HadGoodPose then return end

    -- never had a good pose yet: hang in front of the owner
    self:UKGutterman_ApplyPose(
      owner:WorldSpaceCenter() + owner:GetForward() * 55,
      owner:GetAngles()
    )
  end

  -- Canon: the shield cannot be grappled with the Whiplash. The uk_whiplash
  -- hook attaches to anything with Health() > 0, so force any hook that
  -- latched onto the helper to reel back like it hit a wall.
  function ENT:UKGutterman_RejectWhiplash()
    for _, wl in ipairs( ents.FindByClass( "uk_whiplash" ) ) do
      if wl.AttachedEnt == self then
        wl.AttachedEnt = nil
        if wl.SetReturning then wl:SetReturning( true ) end
        wl:EmitSound( "vmanip/feedbacker/whiplashHitWall.ogg", 90, 180 )
      end
    end
  end

  -- Eject only entities whose center is ACTUALLY inside the shield OBB.
  -- The old approximate world-AABB test was much fatter than the real box:
  -- it kept shoving players standing on the Gutterman's head sideways every
  -- tick, which both slid them around and ate their jump impulses.
  function ENT:UKGutterman_PushOutOverlaps()
    local center = self:LocalToWorld( ( SHIELD_MINS + SHIELD_MAXS ) * 0.5 )
    local radius = SHIELD_MINS:Distance( SHIELD_MAXS ) * 0.5

    for _, ent in ipairs( ents.FindInSphere( center, radius ) ) do
      if not IsValid( ent ) or ent == self or ent == self.UKGutterman_Owner then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

      local lp = self:WorldToLocal( ent:WorldSpaceCenter() )
      if lp.x < SHIELD_MINS.x or lp.x > SHIELD_MAXS.x then continue end
      if lp.y < SHIELD_MINS.y or lp.y > SHIELD_MAXS.y then continue end
      if lp.z < SHIELD_MINS.z or lp.z > SHIELD_MAXS.z then continue end

      local dir = ent:WorldSpaceCenter() - center
      dir.z = 0
      if dir:IsZero() then dir = self:GetForward() end
      ent:SetPos( ent:GetPos() + dir:GetNormalized() * 8 )
    end
  end

  -- Metallic hit feedback: without sparks/sound the soaked shots looked
  -- like they vanished into thin air next to the model.
  function ENT:UKGutterman_ShieldHitFeedback( pos )
    if CurTime() < ( self.UKGutterman_NextHitFx or 0 ) then return end
    self.UKGutterman_NextHitFx = CurTime() + 0.06
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetMagnitude( 1.2 )
    fx:SetScale( 1 )
    fx:SetRadius( 5 )
    util.Effect( "MetalSpark", fx, true, true )
    self:EmitSound( "physics/metal/metal_solid_impact_bullet"
      .. math.random( 2, 4 ) .. ".wav", 75, math.random( 95, 110 ) )
  end

  -- Showy hitscan ricochet: a reflected tracer whipping off the shield plane
  -- per blocked bullet (shotgun pellets each get their own — a point-blank
  -- blast fans out), plus sparks and a throttled ricochet ping.
  function ENT:UKGutterman_ShieldRicochetFx( hitPos, dir )
    local normal = self:GetUp() -- bone-local up = away from the shield face
    if normal:Dot( dir ) > 0 then normal = -normal end
    local refl = ( dir - normal * ( 2 * dir:Dot( normal ) )
      + VectorRand() * 0.2 ):GetNormalized()

    local fx = EffectData()
    fx:SetStart( hitPos )
    fx:SetOrigin( hitPos + refl * math.Rand( 300, 600 ) )
    fx:SetScale( 6000 )
    util.Effect( "Tracer", fx, true, true )

    self:UKGutterman_ShieldHitFeedback( hitPos )
    if CurTime() >= ( self.UKGutterman_NextRicoSnd or 0 ) then
      self.UKGutterman_NextRicoSnd = CurTime() + 0.08
      self:EmitSound( "FX_RicochetSound.Ricochet" )
    end
  end

  function ENT:OnTakeDamage( dmg )
    local owner = self.UKGutterman_Owner
    if IsValid( owner ) and owner.UKGutterman_TryShieldBreak then
      -- Knuckleblaster hits break the shield instantly (canon); anything else
      -- is soaked by the shield.
      owner:UKGutterman_TryShieldBreak( dmg )
    end

    local pos = dmg:GetDamagePosition()
    if pos:IsZero() then pos = self:WorldSpaceCenter() end

    if dmg:IsDamageType( DMG_CLUB ) or dmg:IsDamageType( DMG_SLASH ) then
      -- melee: heavy metal clang, no tracer (a ricochet streak after a
      -- crowbar swing reads wrong)
      self:UKGutterman_ShieldHitFeedback( pos )
      self:EmitSound( "physics/metal/metal_solid_impact_hard"
        .. math.random( 1, 3 ) .. ".wav", 85, math.random( 85, 100 ) )
    else
      -- non-FireBullets hitscan (railcannons trace + TakeDamageInfo directly)
      -- and anything else that damages the helper bounces visibly
      local dir = dmg:GetDamageForce()
      dir = dir:IsZero() and -self:GetUp() or dir:GetNormalized()
      self:UKGutterman_ShieldRicochetFx( pos, dir )
    end

    dmg:SetDamage( 0 )
    self:SetHealth( 100 ) -- keep the helper punchable (see Initialize)
    return 0
  end

  -- FireBullets interception: solidity alone is NOT enough for bullets in
  -- this stack (proven on the Guttertank shootable projectile — the reliable
  -- recipe is the EntityFireBullets ray test). Clamp any shot whose ray
  -- crosses a live shield OBB so it dies on the shield plane instead of
  -- passing through into the body.
  hook.Add( "EntityFireBullets", "UKGutterman_ShieldBlockBullets", function( shooter, data )
    local helpers = ents.FindByClass( "ultrakill_test_gutterman_shield" )
    if #helpers == 0 then return end

    local src = data.Src
    local dir = data.Dir:GetNormalized()
    local maxDist = ( data.Distance and data.Distance > 0 ) and data.Distance or 56756

    local best, bestDist
    for _, h in ipairs( helpers ) do
      if not IsValid( h ) then continue end
      if shooter == h or shooter == h.UKGutterman_Owner then continue end
      local hitPos = util.IntersectRayWithOBB(
        src, dir * maxDist, h:GetPos(), h:GetAngles(), SHIELD_MINS, SHIELD_MAXS )
      if hitPos then
        local d = src:Distance( hitPos )
        if not bestDist or d < bestDist then best, bestDist = h, d end
      end
    end
    if not best then return end

    -- Anything nearer along the ray (body, wall, prop) still gets hit first;
    -- the clamp only stops the bullet from continuing PAST the shield plane.
    data.Distance = bestDist + 1

    local helper = best
    local shotDir = dir
    local oldCb = data.Callback
    data.Callback = function( attacker, tr, dmginfo )
      if oldCb then oldCb( attacker, tr, dmginfo ) end
      if not IsValid( helper ) then return end
      -- feedback + break test only when the bullet actually reached the plane
      -- (rather than dying on a closer wall/entity)
      local reached = tr.HitPos and tr.HitPos:DistToSqr( src ) >= ( bestDist - 8 ) * ( bestDist - 8 )
      if not reached then return end
      if IsValid( tr.Entity ) and tr.Entity ~= helper then return end

      helper:UKGutterman_ShieldRicochetFx( tr.HitPos, shotDir )
      local owner = helper.UKGutterman_Owner
      if IsValid( owner ) and owner.UKGutterman_TryShieldBreak then
        owner:UKGutterman_TryShieldBreak( dmginfo )
      end
    end

    return true
  end )

  function ENT:UKGutterman_IsOrbLike( ent )
    if not IsValid( ent ) then return false end
    local cls = string.lower( ent:GetClass() or "" )
    if UKGutterman.EXCLUDED_ORB_CLASS[ cls ] then return true end
    return string.find( cls, "orb", 1, true ) ~= nil
  end

  -- Canon wiki: "some projectiles (such as sawblades and rockets) bounce off
  -- of it" — treat those like the orb deflection. Coverage per live request:
  -- UKWeapons (uk_nail, uk_proj_* = chainsaw/sawblades/core/rocket/
  -- screwdriver, proj_dredux_*), HL2 (crossbow bolts, RPG missiles, SMG and
  -- frag grenades, AR2 combine ball) and custom addons via the same word
  -- patterns ("proj" alone catches most *_projectile classes).
  local BOUNCY_WORDS = {
    "proj", "nail", "sawblade", "chainsaw", "rocket", "missile",
    "grenade", "bolt", "cannonball", "shell", "dart", "arrow", "bomb",
  }

  function ENT:UKGutterman_IsBouncyProjectile( ent )
    if not IsValid( ent ) then return false end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return false end
    local cls = string.lower( ent:GetClass() or "" )
    -- mines must reach the shield and blow it up, never get batted away
    if string.find( cls, "mine", 1, true ) then return false end
    -- coins must stay live for the canon chargeback
    if cls == "ultrakill_coin" then return false end
    if cls == "prop_combine_ball" then return true end
    for _, word in ipairs( BOUNCY_WORDS ) do
      if string.find( cls, word, 1, true ) then return true end
    end
    return false
  end

  -- Rockets and other contact-fused projectiles explode in their own Touch
  -- before ours ever runs, so waiting for Touch means a detonation instead of
  -- a canon bounce. Scan the space in front of the shield and bat incoming
  -- projectiles away BEFORE they make contact.
  local DEFLECT_SCAN_RADIUS = 130

  function ENT:UKGutterman_DeflectIncoming()
    local center = self:LocalToWorld( ( SHIELD_MINS + SHIELD_MAXS ) * 0.5 )
    local owner = self.UKGutterman_Owner

    for _, ent in ipairs( ents.FindInSphere( center, DEFLECT_SCAN_RADIUS ) ) do
      if not IsValid( ent ) or ent == self or ent == owner then continue end
      if not self:UKGutterman_IsBouncyProjectile( ent ) then continue end
      -- our own detonated/deflected leftovers get one grace tick
      if ent.UKGutterman_LastShieldDeflect and ent.UKGutterman_LastShieldDeflect + 0.15 > CurTime() then continue end

      local vel = ent:GetVelocity()
      -- only bat away projectiles actually flying INTO the shield
      if vel:LengthSqr() < 100 * 100 then continue end
      if vel:Dot( center - ent:GetPos() ) <= 0 then continue end

      self:UKGutterman_DeflectProjectile( ent )
    end
  end

  function ENT:UKGutterman_DeflectProjectile( ent )
    if ent.UKGutterman_LastShieldDeflect and ent.UKGutterman_LastShieldDeflect + 0.05 > CurTime() then return end
    ent.UKGutterman_LastShieldDeflect = CurTime()

    local vel = ent:GetVelocity()
    local speed = math.max( vel:Length(), 600 )
    local outward = self:GetUp() -- bone-local up points away from the shield face
    local owner = self.UKGutterman_Owner
    if IsValid( owner ) and outward:Dot( ent:GetPos() - owner:WorldSpaceCenter() ) < 0 then
      outward = -outward
    end
    local randomDir = (
      outward
      + self:GetRight() * math.Rand( -0.7, 0.7 )
      + self:GetForward() * math.Rand( -0.5, 0.5 )
      + Vector( 0, 0, math.Rand( 0, 0.5 ) )
    ):GetNormalized()

    ent:SetVelocity( randomDir * speed )
    local phys = ent:GetPhysicsObject()
    if IsValid( phys ) then
      phys:SetVelocity( randomDir * speed )
    end
    -- rockets steer along their angles — turn the whole projectile, not just
    -- its velocity, or it curves right back into the shield
    ent:SetAngles( randomDir:Angle() )

    local fx = EffectData()
    fx:SetOrigin( ent:GetPos() )
    fx:SetMagnitude( 1.5 )
    fx:SetScale( 1 )
    fx:SetRadius( 6 )
    util.Effect( "MetalSpark", fx, true, true )

    self:EmitSound( "physics/metal/metal_solid_impact_hard"
      .. math.random( 1, 3 ) .. ".wav", 80, math.random( 90, 110 ) )
  end

  function ENT:Touch( ent )
    if self:UKGutterman_IsOrbLike( ent ) or self:UKGutterman_IsBouncyProjectile( ent ) then
      self:UKGutterman_DeflectProjectile( ent )
    end
  end

  -- The physgun must never latch onto the helper (frozen MOVETYPE_NONE box).
  hook.Add( "PhysgunPickup", "UKGutterman_ShieldNoPhysgun", function( _, ent )
    if ent.UKGutterman_IsShieldHelper then return false end
  end )
end

if CLIENT then
  local DEBUG_COL = Color( 40, 140, 255 )

  function ENT:Draw()
    if not UKGutterman.IsDebugHelpersEnabled() then return end
    render.DrawWireframeBox( self:GetPos(), self:GetAngles(), SHIELD_MINS, SHIELD_MAXS, DEBUG_COL, true )
  end
end
