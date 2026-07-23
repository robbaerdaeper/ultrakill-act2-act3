AddCSLuaFile()
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gutterman Corpse"
ENT.Spawnable = false

-- Lying-pose physics box (death.smd final frame bone extents at $scale 6000,
-- padded; the visual standing-pose .phy hull must not be used here).
local CORPSE_MINS = Vector( -100, -70, 0 )
local CORPSE_MAXS = Vector( 120, 70, 80 )

if SERVER then
  function ENT:Initialize()
    self:SetModel( UKGutterman.MODEL )
    self:SetBodygroupByNameSafe( "body", self.UKGutterman_Casketless and 1 or 0 )
    -- inherit the shield state at death so the swap frame matches the NPC
    self:SetBodygroupByNameSafe( "shield", self.UKGutterman_HadShield and 0 or 1 )
    self:SetBodygroupByNameSafe( "casket_door", self.UKGutterman_Casketless and 1 or 0 )
    self:UKGutterman_SetDeathPose()

    self:PhysicsInitBox( CORPSE_MINS, CORPSE_MAXS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetCollisionBounds( CORPSE_MINS, CORPSE_MAXS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )

    self.UKGutterman_Corpse = true
    self.UKGutterman_Exploded = false
    self.UKGutterman_LastBlood = 0
    self.UKGutterman_DoorBone = self:LookupBone( "CasketDoor" )
    -- canon playerUnstucker: active for ~1 s after FallOver
    self.UKGutterman_UnstuckUntil = CurTime() + 1.0

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:Wake()
      phys:SetMass( 2000 )
      phys:SetDamping( 0.4, 6 )
      phys:SetMaterial( "metal" )
    end
  end

  function ENT:SetBodygroupByNameSafe( name, value )
    local id = self:FindBodygroupByName( name )
    if id and id >= 0 then self:SetBodygroup( id, value ) end
  end

  function ENT:UKGutterman_SetDeathPose()
    local seq = self:LookupSequence( "Death" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetCycle( 1 )
      self:SetPlaybackRate( 0 )
    end
  end

  -- Casket door ---------------------------------------------------------------

  function ENT:UKGutterman_GetDoorPos()
    if self.UKGutterman_DoorBone then
      local m = self:GetBoneMatrix( self.UKGutterman_DoorBone )
      if m then return m:GetTranslation() end
    end
    return self:WorldSpaceCenter() + self:GetUp() * 50
  end

  function ENT:UKGutterman_BreakDoor()
    if self.UKGutterman_DoorBroken or self.UKGutterman_Casketless then return end
    self.UKGutterman_DoorBroken = true
    self:SetBodygroupByNameSafe( "casket_door", 1 )
    self:EmitSound( "physics/metal/metal_box_break1.wav", 80, 95 )

    local fx = EffectData()
    fx:SetOrigin( self:UKGutterman_GetDoorPos() )
    fx:SetMagnitude( 2 )
    fx:SetScale( 1.5 )
    fx:SetRadius( 6 )
    util.Effect( "Sparks", fx, true, true )
  end

  function ENT:UKGutterman_TryBreakDoor( dmg )
    if self.UKGutterman_DoorBroken or self.UKGutterman_Casketless then return end

    local pos = dmg:GetDamagePosition()
    if pos:IsZero() then return end

    local doorPos = self:UKGutterman_GetDoorPos()
    local radius = dmg:IsExplosionDamage() and 170 or 75
    if pos:DistToSqr( doorPos ) <= radius * radius then
      self:UKGutterman_BreakDoor()
    end
  end

  -- Damage / explosion ----------------------------------------------------------

  function ENT:UKGutterman_IsGroundSlamDamage( dmg )
    if dmg.UKGutterman_GroundSlam then return true end

    local inf = dmg:GetInflictor()
    local attacker = dmg:GetAttacker()
    local infClass = IsValid( inf ) and string.lower( inf:GetClass() or "" ) or ""
    local attackerClass = IsValid( attacker ) and string.lower( attacker:GetClass() or "" ) or ""

    return infClass:find( "slam", 1, true )
      or attackerClass:find( "slam", 1, true )
  end

  function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )
    self:UKGutterman_TryBreakDoor( dmg )

    if CurTime() >= self.UKGutterman_LastBlood + 0.15 and UltrakillBase and UltrakillBase.CreateBlood then
      self.UKGutterman_LastBlood = CurTime()
      local pos = dmg:GetDamagePosition()
      if pos:IsZero() then pos = self:WorldSpaceCenter() end
      UltrakillBase.CreateBlood( pos, math.random( 6, 10 ) )
    end

    if self:UKGutterman_IsGroundSlamDamage( dmg ) then
      local a = dmg:GetAttacker()
      self:UKGutterman_ExplodeCorpse( a, IsValid( a ) and a:IsPlayer() and a or nil )
    end
  end

  -- Canon: a ground slam onto the fallen corpse detonates it and launches the
  -- player upward — but only AFTER the slam lands. Firing mid-air fought the
  -- ukdash slam (it keeps forcing downward velocity until it ends) and we
  -- must never clear its networked state ourselves: that desyncs the dash
  -- addon's own state machine ("багается граунд слэм").
  function ENT:UKGutterman_CheckGroundSlam()
    self.UKGutterman_SlamArmed = self.UKGutterman_SlamArmed or {}
    local top = self:GetPos().z + CORPSE_MAXS.z

    for _, ply in ipairs( player.GetAll() ) do
      if not ply:Alive() then continue end

      local lp = self:WorldToLocal( ply:GetPos() )
      local overBox = lp.x >= CORPSE_MINS.x - 30 and lp.x <= CORPSE_MAXS.x + 30
        and lp.y >= CORPSE_MINS.y - 30 and lp.y <= CORPSE_MAXS.y + 30
      local slamming = ply:GetNW2Bool( "ULTRAKILL_GroundSlamActive", false )

      -- arm while the slam is dropping onto the box
      if slamming and overBox and ply:GetVelocity().z < -200
          and ply:GetPos().z > top - 30 and ply:GetPos().z < top + 500 then
        self.UKGutterman_SlamArmed[ ply ] = CurTime() + 1.5
        continue
      end

      local armedUntil = self.UKGutterman_SlamArmed[ ply ]
      if not armedUntil then continue end
      if armedUntil <= CurTime() then
        self.UKGutterman_SlamArmed[ ply ] = nil
        continue
      end

      -- detonate once the slam has finished ON the corpse: ukdash cleared its
      -- flag on landing, or the player has stopped falling on the box
      if overBox and ply:GetPos().z < top + 80
          and ( not slamming or ply:IsOnGround() or ply:GetVelocity().z > -50 ) then
        self.UKGutterman_SlamArmed[ ply ] = nil
        self:UKGutterman_ExplodeCorpse( ply, ply )
        return
      end
    end
  end

  -- Anti-flip: the corpse should rest flat; physgun can still move it around.
  function ENT:UKGutterman_Stabilize()
    if self.UKGutterman_Held then return end

    -- Never fight the surface while someone is standing on it: the repeated
    -- SetAngles snaps kept shifting the ground under the player's feet, which
    -- read as "the corpse slides you off".
    for _, ply in ipairs( player.GetAll() ) do
      if ply:GetGroundEntity() == self then return end
    end

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) or not phys:IsMotionEnabled() then return end
    if phys:GetVelocity():Length() > 60 then return end
    if phys:GetAngleVelocity():Length() > 50 then return end

    local ang = self:GetAngles()
    local p = math.NormalizeAngle( ang.p )
    local r = math.NormalizeAngle( ang.r )
    if math.abs( p ) < 2 and math.abs( r ) < 2 then return end

    local newAng = Angle( p * 0.6, ang.y, r * 0.6 )
    phys:SetAngles( newAng )
    phys:SetAngleVelocity( phys:GetAngleVelocity() * 0.4 )
  end

  -- Canon playerUnstucker: players caught inside the freshly fallen corpse
  -- get pushed out instead of being trapped in the collision box.
  function ENT:UKGutterman_UnstuckPlayers()
    if not self.UKGutterman_UnstuckUntil or CurTime() > self.UKGutterman_UnstuckUntil then return end

    for _, ply in ipairs( player.GetAll() ) do
      if not ply:Alive() then continue end
      local lp = self:WorldToLocal( ply:GetPos() )
      if lp.x < CORPSE_MINS.x or lp.x > CORPSE_MAXS.x then continue end
      if lp.y < CORPSE_MINS.y or lp.y > CORPSE_MAXS.y then continue end
      -- top-8: a player STANDING ON the corpse has his feet exactly at the
      -- box top — that is riding, not being stuck inside, don't eject him
      if lp.z < CORPSE_MINS.z - 8 or lp.z > CORPSE_MAXS.z - 8 then continue end
      if ply:GetGroundEntity() == self then continue end

      local out = ply:GetPos() - self:WorldSpaceCenter()
      out.z = 0
      if out:IsZero() then out = self:GetForward() end
      out:Normalize()
      ply:SetPos( self:LocalToWorld( Vector( 0, 0, CORPSE_MAXS.z + 4 ) ) + out * 24 )
      ply:SetVelocity( out * 120 - ply:GetVelocity() * 0.5 )
    end
  end

  function ENT:Think()
    self:UKGutterman_UnstuckPlayers()
    self:UKGutterman_CheckGroundSlam()
    self:UKGutterman_Stabilize()
    self:NextThink( CurTime() )
    return true
  end

  function ENT:PhysicsCollide( data, phys )
    local oldVel = data.OurOldVelocity or vector_origin
    if data.Speed < 450 then return end
    if oldVel.z > -350 then return end

    -- falling corpse crushes whatever it lands on
    for _, ent in ipairs( ents.FindInSphere( data.HitPos, 110 ) ) do
      if IsValid( ent ) and ent ~= self and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        local dmg = DamageInfo()
        dmg:SetDamage( 1000000 )
        dmg:SetDamageType( DMG_CRUSH )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        ent:TakeDamageInfo( dmg )
      end
    end
  end

  -- Canon "Explosion Gutterman" (prefab Sphere_8 Explosion component):
  -- maxSize 20 m (-> 800 su), damage 35, enemyDamageMultiplier x2 (-> 70),
  -- visual = UK sphere + 3 shockwaves = the base "hard" explosion effect.
  local EXPLODE_RADIUS = 20 * UKGutterman.UNIT
  local EXPLODE_DAMAGE = 35

  function ENT:UKGutterman_ExplodeCorpse( attacker, launchPly )
    if self.UKGutterman_Exploded then return end
    self.UKGutterman_Exploded = true

    local pos = self:WorldSpaceCenter()

    -- Canon look = the standard ULTRAKILL Explosion prefab, the exact effect
    -- the base pack uses everywhere (mines, rockets): "Ultrakill_Explosion"
    -- with radius = worldRadius / 150 * 100 (UltrakillBase CreateExplosion
    -- convention). The "hard" red variant read as foreign here.
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetAngles( angle_zero )
    fx:SetRadius( EXPLODE_RADIUS / 150 * 100 )
    util.Effect( "Ultrakill_Explosion", fx, true, true )

    -- same sound script the base pack big explosions use
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_2", pos )
    else
      sound.Play( "ambient/explosions/explode_4.wav", pos, 120, 70 )
    end
    util.ScreenShake( pos, 14, 70, 1.0, EXPLODE_RADIUS * 1.5 )

    for _, ent in ipairs( ents.FindInSphere( pos, EXPLODE_RADIUS ) ) do
      if not IsValid( ent ) or ent == self then continue end

      if ent:IsPlayer() then
        -- canon: playerDamageOverride -1 (no player damage). Only the slammer
        -- gets the canon Launch(up * 750); bystanders just get shoved.
        if ent == launchPly then
          local downward = math.min( ent:GetVelocity().z, 0 )
          ent:SetVelocity( Vector( 0, 0, 750 - downward ) )
          ent:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 40 ), 0.1, 0.25 )
        else
          local push = ( ent:WorldSpaceCenter() - pos )
          push.z = math.max( push.z, 60 )
          ent:SetVelocity( push:GetNormalized() * 300 )
        end
      elseif ent.UKGutterman_Corpse and ent.UKGutterman_ExplodeCorpse then
        ent:UKGutterman_ExplodeCorpse( attacker )
      elseif ent:IsNPC() or ent:IsNextBot() then
        -- canon 35 x2 vs enemies; pack scale = canon x1000. Attacker stays the
        -- corpse so UltrakillBase does not re-apply the player x10 multiplier.
        local dmg = DamageInfo()
        dmg:SetDamage( EXPLODE_DAMAGE * 2 * 1000 )
        dmg:SetDamageType( DMG_BLAST )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        dmg:SetDamageForce( ( ent:WorldSpaceCenter() - pos ):GetNormalized() * 1000 )
        ent:TakeDamageInfo( dmg )
      elseif not ent:IsWeapon() then
        -- physics shove so the blast reads physical, canon UK explosions kick
        -- props around
        local phys = ent:GetPhysicsObject()
        if IsValid( phys ) and phys:IsMotionEnabled() then
          local dir = ( ent:WorldSpaceCenter() - pos )
          dir.z = math.max( dir.z, 40 )
          phys:ApplyForceCenter( dir:GetNormalized() * math.min( phys:GetMass(), 400 ) * 600 )
        end
      end
    end

    self:Remove()
  end

  hook.Add( "PhysgunPickup", "UKGutterman_CorpseHeld", function( ply, ent )
    if ent.UKGutterman_Corpse then ent.UKGutterman_Held = true end
  end )

  hook.Add( "PhysgunDrop", "UKGutterman_CorpseDrop", function( ply, ent )
    if ent.UKGutterman_Corpse then ent.UKGutterman_Held = false end
  end )
end

if CLIENT then
  function ENT:Draw()
    self:DrawModel()
  end
end
