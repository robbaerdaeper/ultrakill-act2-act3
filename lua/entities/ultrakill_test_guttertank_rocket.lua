AddCSLuaFile()

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_guttertank_shared.lua" )

-- Guttertank rocket (canon RocketEnemy Grenade, real prefab bake: red/orange
-- skull materials). Canon proximity logic: the moment it starts moving AWAY
-- from its target (closest approach passed = it missed), it freezes in place,
-- winds up 0.5 s and self-explodes. Shootable: damage detonates it and the
-- attacker owns the explosion.
--
-- UKWeapons (dredux) integration:
--  * Freezeframe (ULTRAWep_Base.GetActiveFreezeFrame) holds it mid-air;
--  * the player can mount and ride it (uk_proj_rocket controls: WASD steers,
--    JUMP/DUCK dismounts);
--  * a magnet (uk_magnet) stuck to the Guttertank redirects rockets the
--    player had time-frozen back at their shooter;
--  * canon: the Guttertank is instantly killed by his own rocket.

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Guttertank Rocket"
ENT.Category = "UltrakillBase"
ENT.Models = { UKGuttertank.ROCKET_MODEL }
ENT.Spawnable = false
ENT.Gravity = false
ENT.UltrakillBase_Parryable = false
ENT.UltrakillBase_CustomCollisionEnabled = false
-- explosion is deferred out of the physics callback; the base must not
-- auto-Remove() on contact or the deferred payload dies with the entity
ENT.OnContactDelete = -1

local RIDE_RADIUS = 48    -- mount detection around the rocket's center
local RIDE_UP = 6         -- rider feet sit on top of the 8-su-thick body
local STEER_RATE = 150    -- deg/s, uk_proj_rocket rider steering
local HOME_RATE = 540     -- deg/s, unridden magnet redirect
local HOME_RATE_RIDDEN = 240 -- deg/s, magnet aim-assist while ridden

if SERVER then

  function ENT:CustomInitialize()
    self:SetColor( Color( 255, 255, 255, 255 ) )
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )

    -- Shootable is handled by the EntityFireBullets hook in the shared file:
    -- the engine refused to deliver bullet damage into this projectile no
    -- matter its solidity (rounds 5-7), so the rocket stays trace-transparent
    -- (base default) and player shots are intersected with it by hand.
    -- Physics contacts (walls, victims, riders) are live via vphysics anyway.

    self.UKGT_Shooter = self:GetOwner() -- the tank; Owner may change (rider)
    self.UKGT_Frozen = false            -- canon missed-shot windup
    self.UKGT_FreezeAt = nil
    self.UKGT_TimeFrozen = false        -- UKWeapons Freezeframe hold
    self.UKGT_WasTimeFrozen = false
    self.UKGT_Redirected = false
    self.UKGT_RedirectCredit = nil
    self.UKGT_GraceUntil = CurTime() + 0.15
    self.UKGT_OwnerGraceUntil = CurTime() + 0.25
    self.UKGT_NextRideTime = CurTime() + 0.1
    self.UKGT_LastDist = nil
    self.UKGT_LastThink = CurTime()

    util.SpriteTrail( self, 0, Color( 255, 90, 60 ), false, 10, 15, 0.3,
      2 / 16 * 0.5, "trails/smoke" )

    self.UKGT_LoopSound = CreateSound( self, UKGuttertank.SOUND.RocketLoop )
    self.UKGT_LoopSound:PlayEx( 0.7, 100 )

    SafeRemoveEntityDelayed( self, 30 )
  end

  function ENT:UKGT_GetRider()
    local rider = self:GetNW2Entity( "UKGT_RidingEnt" )
    return IsValid( rider ) and rider or nil
  end

  function ENT:UKGT_Speed2()
    return self.UKGT_Speed or UKGuttertank.ROCKET_SPEED
  end

  -- Explode / instakill ------------------------------------------------------

  function ENT:UKGT_Explode( instakillTarget )
    if self.UKGT_Exploded then return end
    self.UKGT_Exploded = true
    -- OnContact runs inside a physics callback: damage, effects and Remove()
    -- there are crash bait — detonate next tick
    timer.Simple( 0, function()
      if not IsValid( self ) then return end

      if IsValid( instakillTarget ) and instakillTarget:Health() > 0 then
        -- canon: the Guttertank is instantly killed by his own rockets
        local credit = self:UKGT_GetRider() or self.UKGT_LastRider
          or self.UKGT_RedirectCredit
        local dmg = DamageInfo()
        dmg:SetDamage( math.max( instakillTarget:GetMaxHealth(),
          instakillTarget:Health() ) * 10 )
        dmg:SetDamageType( DMG_BLAST )
        dmg:SetAttacker( IsValid( credit ) and credit or self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( instakillTarget:WorldSpaceCenter() )
        instakillTarget:TakeDamageInfo( dmg )
      end

      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
      -- blast-gated HL2 heavies (helicopter/gunship/strider) get their
      -- engine-shaped damage; the filter keeps the base blast off them
      local ignore = UKGuttertank.BlastCompat( self, self:GetOwner(),
        self:GetPos(), 150, UKGuttertank.ROCKET_DAMAGE )
      -- round-3 sweep (2026-07-10): a player-owned blast (shot-down /
      -- redirected rocket) nets a fixed x40 on UK victims — feed the mine's
      -- landed target / 40 so both owner paths land the same 7000
      -- (raw 350 through the player path landed 14000, twice the mine)
      local blastDamage = UKGuttertank.ROCKET_DAMAGE
      local owner = self:GetOwner()
      if IsValid( owner ) and owner:IsPlayer() then
        blastDamage = UKGuttertank.MINE_DAMAGE_NPC / 40
      end
      self:Explosion( self:GetPos(), blastDamage, nil, 150,
        0.2, self:GetOwner(), nil, ignore )
      self:CreateExplosion( self:GetPos(), self:GetAngles() )
      self:Remove()
    end )
  end

  -- Flight helpers: the base projectile is VPhysics-backed (its own parry
  -- code drives the phys object) — movetype/SetVelocity hacks do nothing.

  function ENT:UKGT_HoldStill()
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:SetVelocity( vector_origin )
      phys:EnableMotion( false )
    else
      self:SetMoveType( MOVETYPE_NONE )
    end
  end

  function ENT:UKGT_ResumeFlight()
    local vel = self:GetForward() * self:UKGT_Speed2()
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( true )
      phys:Wake()
      phys:SetVelocity( vel )
    else
      self:SetMoveType( MOVETYPE_FLY )
      self:SetVelocity( vel )
    end
  end

  function ENT:UKGT_SetFlightVelocity( vel )
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then phys:SetVelocity( vel ) else self:SetVelocity( vel ) end
  end

  -- Canon missed-shot windup -------------------------------------------------

  function ENT:UKGT_Freeze()
    if self.UKGT_Frozen or self.UKGT_Exploded then return end
    -- canon: rb.isKinematic = true + RocketSelfExplodeWindup, 0.5 s fuse
    self.UKGT_Frozen = true
    self.UKGT_FreezeAt = CurTime() + 0.5
    self:UKGT_HoldStill()
    self:SetColor( Color( 255, 200, 120, 255 ) )
    -- canon proximityWindup telegraph: warning sphere collapses into the
    -- rocket over the fuse (workshop report 2026-07-10: "rocket freezing"
    -- read as missing — the old color-change was invisible in the moment)
    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    fx:SetRadius( 110 )
    util.Effect( "ultrakill_test_gt_windup", fx, true, true )
    self:EmitSound( UKGuttertank.SOUND.MineBeep, 80, 130, 0.8 )
    if self.UKGT_LoopSound then self.UKGT_LoopSound:ChangePitch( 160, 0.1 ) end
  end

  -- UKWeapons Freezeframe ------------------------------------------------------

  function ENT:UKGT_SetTimeFrozen( state )
    if self.UKGT_TimeFrozen == state then return end
    self.UKGT_TimeFrozen = state
    self:SetNW2Bool( "UKGT_TimeFrozen", state )
    if state then
      self.UKGT_WasTimeFrozen = true
      self:UKGT_HoldStill()
      if self.UKGT_LoopSound then self.UKGT_LoopSound:ChangePitch( 40, 0.1 ) end
    else
      if not self.UKGT_Frozen then self:UKGT_ResumeFlight() end
      if self.UKGT_LoopSound then self.UKGT_LoopSound:ChangePitch( 100, 0.1 ) end
      -- no magnet: it flies on where it was going, and the tank's canon
      -- proximity stop re-arms fresh (re-baseline the closest-approach clock)
      self.UKGT_LastDist = nil
      self.UKGT_GraceUntil = CurTime() + 0.15
      -- released rockets fly at the magnet stuck to their shooter (only ones
      -- the player actually stopped — the rest keep obeying the Guttertank)
      self:UKGT_TryRedirect()
    end
  end

  function ENT:UKGT_FindShooterMagnet()
    local shooter = self.UKGT_Shooter
    if not IsValid( shooter ) or shooter:Health() <= 0 then return nil end
    if not istable( shooter.AttachedMagnets ) then return nil end
    for _, magnet in ipairs( shooter.AttachedMagnets ) do
      if IsValid( magnet ) then return magnet end
    end
    return nil
  end

  function ENT:UKGT_TryRedirect()
    if not self.UKGT_WasTimeFrozen or self.UKGT_Redirected then return end
    local magnet = self:UKGT_FindShooterMagnet()
    if not magnet then return end
    self.UKGT_Redirected = true
    -- the magnet thrower owns the turnaround: the explosion must hurt the tank
    local thrower = magnet.GetTrueOwner and magnet:GetTrueOwner() or nil
    if IsValid( thrower ) then
      self.UKGT_RedirectCredit = thrower
      if not self:UKGT_GetRider() then self:SetOwner( thrower ) end
    end
  end

  -- Riding (uk_proj_rocket pattern) ---------------------------------------------

  function ENT:UKGT_Mount( ply )
    -- once ridden, always lethal to its shooter — even after jumping off
    self.UKGT_WasRidden = true
    self.UKGT_LastRider = ply
    self:SetNW2Entity( "UKGT_RidingEnt", ply )
    ply:SetNW2Entity( "UK_RiddenRocket", self ) -- uk rockets honor this too
    self.UKGT_RiderMoveType = ply:GetMoveType()
    ply:SetMoveType( MOVETYPE_NONE )
    self:SetOwner( ply )
    self:EmitSound( "ultrakill/weapons/rocket_launcher/rocket_ride.ogg", 80, 50 )
    self:UKGT_PinRider( ply )
  end

  function ENT:UKGT_Unmount( ply, jumped )
    self:SetNW2Entity( "UKGT_RidingEnt", nil )
    if IsValid( ply ) then
      if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
        ply:SetMoveType( self.UKGT_RiderMoveType or MOVETYPE_WALK )
      end
      ply:SetNW2Entity( "UK_RiddenRocket", nil )
      ply:SetLocalVelocity( vector_origin )
      if jumped then ply:SetVelocity( Vector( 0, 0, 450 ) ) end
    end
    self.UKGT_NextRideTime = CurTime() + 0.25
    -- ownership falls back to whoever should own the blast
    if IsValid( self.UKGT_RedirectCredit ) then
      self:SetOwner( self.UKGT_RedirectCredit )
    elseif IsValid( self.UKGT_Shooter ) then
      self:SetOwner( self.UKGT_Shooter )
    end
  end

  function ENT:UKGT_PinRider( ply )
    local centerOffset = ply:WorldSpaceCenter() - ply:GetPos()
    ply:SetPos( self:WorldSpaceCenter() + self:GetUp() * RIDE_UP - centerOffset )
    ply:SetVelocity( self:GetVelocity() - ply:GetVelocity() )
  end

  function ENT:UKGT_CheckMount()
    if self.UKGT_Frozen then return end -- mid-windup, about to pop
    if self.UKGT_NextRideTime > CurTime() then return end
    for _, ply in ipairs( ents.FindInSphere( self:WorldSpaceCenter(), RIDE_RADIUS ) ) do
      if ply:IsPlayer() and ply:Alive() then
        local ridden = ply:GetNW2Entity( "UK_RiddenRocket" )
        if IsValid( ridden ) and ridden ~= self then continue end
        local dir = ( ply:WorldSpaceCenter() - self:WorldSpaceCenter() ):GetNormalized()
        -- uk_proj_rocket: falling onto the top of the rocket mounts it
        if dir:Dot( vector_up ) > 0.85 and ply:GetVelocity().z <= 0 then
          self:UKGT_Mount( ply )
          return
        end
      end
    end
  end

  function ENT:UKGT_RotateTowards( targetPos, rate, dt )
    local want = ( targetPos - self:WorldSpaceCenter() ):Angle()
    local cur = self:GetAngles()
    cur.p = math.ApproachAngle( cur.p, want.p, rate * dt )
    cur.y = math.ApproachAngle( cur.y, want.y, rate * dt )
    cur.r = 0
    self:SetAngles( cur )
  end

  -- Think ------------------------------------------------------------------------

  function ENT:CustomThink()
    if self.UKGT_Exploded then return end

    local now = CurTime()
    local dt = math.max( now - ( self.UKGT_LastThink or now ), 0 )
    self.UKGT_LastThink = now

    -- UKWeapons Freezeframe: hold everything (incl. the windup fuse)
    local timeStop = ULTRAWep_Base and ULTRAWep_Base.GetActiveFreezeFrame
      and ULTRAWep_Base.GetActiveFreezeFrame() or false
    self:UKGT_SetTimeFrozen( timeStop )
    if self.UKGT_TimeFrozen then
      if self.UKGT_FreezeAt then self.UKGT_FreezeAt = self.UKGT_FreezeAt + dt end
      self:UKGT_CheckMount()
      local rider = self:UKGT_GetRider()
      if rider then self:UKGT_HandleRider( rider, dt, true ) end
      return
    end

    -- canon missed-shot windup fuse
    if self.UKGT_Frozen then
      if self.UKGT_FreezeAt and now >= self.UKGT_FreezeAt then
        self:UKGT_Explode()
      end
      return
    end

    local rider = self:UKGT_GetRider()
    if not rider then self:UKGT_CheckMount() end
    rider = self:UKGT_GetRider()

    -- magnet redirect (armed on unfreeze; keeps homing while the magnet lives)
    if self.UKGT_Redirected then
      local magnet = self:UKGT_FindShooterMagnet()
      if magnet then
        self:UKGT_RotateTowards( magnet:GetPos(),
          rider and HOME_RATE_RIDDEN or HOME_RATE, dt )
      end
    end

    if rider then
      self:UKGT_HandleRider( rider, dt, false )
      self:UKGT_SetFlightVelocity( self:GetForward() * self:UKGT_Speed2() )
      return
    end

    if self.UKGT_Redirected then
      self:UKGT_SetFlightVelocity( self:GetForward() * self:UKGT_Speed2() )
      return
    end

    -- canon proximity self-explode: receding from the target = missed.
    -- Not for rockets the player has ridden: those are on a new mission
    -- (receding from the PLAYER is the whole point of steering it away).
    if self.UKGT_WasRidden then return end
    local target = self.UKGT_ProximityTarget
    if IsValid( target ) and now >= self.UKGT_GraceUntil then
      local dist = target:WorldSpaceCenter():Distance( self:GetPos() )
      local last = self.UKGT_LastDist
      self.UKGT_LastDist = dist
      if last and dist > last and dist < 20 * UKGuttertank.UNIT then
        self:UKGT_Freeze()
      end
    end
  end

  function ENT:UKGT_HandleRider( rider, dt, frozen )
    if not rider:Alive() then
      self:UKGT_Unmount( rider, false )
      return
    end

    -- uk_proj_rocket steering: pitch on W/S, yaw on A/D at 150 deg/s
    local ang = self:GetAngles()
    local turn = STEER_RATE * dt
    if rider:KeyDown( IN_FORWARD ) then ang:RotateAroundAxis( self:GetRight(), -turn ) end
    if rider:KeyDown( IN_BACK ) then ang:RotateAroundAxis( self:GetRight(), turn ) end
    if rider:KeyDown( IN_MOVELEFT ) then ang:RotateAroundAxis( self:GetUp(), turn ) end
    if rider:KeyDown( IN_MOVERIGHT ) then ang:RotateAroundAxis( self:GetUp(), -turn ) end
    self:SetAngles( ang )

    self:UKGT_PinRider( rider )

    if rider:KeyPressed( IN_JUMP ) or rider:KeyPressed( IN_DUCK ) then
      self:UKGT_Unmount( rider, rider:KeyPressed( IN_JUMP ) )
    end
  end

  -- Contact / damage ---------------------------------------------------------------

  function ENT:OnContact( mEntity )
    if self.UKGT_Exploded then return false end

    local rider = self:UKGT_GetRider()
    if IsValid( rider ) and mEntity == rider then return false end

    local shooter = self.UKGT_Shooter
    if IsValid( shooter ) and mEntity == shooter then
      -- muzzle overlap grace right after firing
      if CurTime() < self.UKGT_OwnerGraceUntil
          and not rider and not self.UKGT_Redirected then
        return false
      end
      if self.UKGT_WasRidden then
        -- only rockets the player has ridden instakill him — and they stay
        -- lethal after the player jumps off mid-flight
        self:UKGT_Explode( shooter )
      else
        -- magnet-served (or blundered-into) rocket: just a normal hit
        self:UKGT_Explode()
      end
      return false
    end

    if mEntity == self:GetOwner() then return false end

    -- a player physically bumping it from above (vphysics contact): feet
    -- above the center while not moving up = a mount attempt (canon riding),
    -- not a hit — don't blow up in his face. A rocket to the legs still
    -- explodes (his feet sit at/below the rocket's center then).
    if mEntity:IsPlayer() and mEntity:Alive()
        and mEntity:GetPos().z >= self:WorldSpaceCenter().z
        and mEntity:GetVelocity().z <= 0 then
      -- physics callback: mounting flips movetypes — defer (uk_magnet pattern)
      timer.Simple( 0, function()
        if not IsValid( self ) or self.UKGT_Exploded then return end
        self:UKGT_CheckMount()
        -- the bump bent the phys velocity; put an unmounted rocket back on course
        if not self:UKGT_GetRider() and not self.UKGT_Frozen
            and not self.UKGT_TimeFrozen then
          self:UKGT_SetFlightVelocity( self:GetForward() * self:UKGT_Speed2() )
        end
      end )
      return false
    end

    self:UKGT_Explode()
    return false
  end

  function ENT:OnTakeDamage( dmg )
    -- canon: rockets are interactable — shooting one detonates it and the
    -- attacker owns the explosion; for a player that's a parry-grade play,
    -- so it lands with the parry hitstop + ding
    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and attacker:IsPlayer() and not self.UKGT_Exploded then
      -- the parry FEEL is the white flash over the frozen frame, not the
      -- timescale alone — same screen package as OnParryPlayer, minus the
      -- heal/stamina (shooting a rocket down is not a parry)
      UltrakillBase.HitStop( 0.25 )
      UltrakillBase.SoundScript( "Ultrakill_Parry", self:GetPos() )
      attacker:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 40 ), 0.1, 0.25 )
      util.ScreenShake( attacker:GetPos(), 50, 1, 0.3, 10, true )
    end
    self:SetOwner( attacker )
    self:UKGT_Explode()
  end

  function ENT:OnRemove()
    if self.UKGT_LoopSound then self.UKGT_LoopSound:Stop() end
    local rider = self:UKGT_GetRider()
    if IsValid( rider ) then self:UKGT_Unmount( rider, false ) end
  end

else

  local haloMat = Material( "hud/reticles/weapons/ultrakill/rocket_launcher/RageEffectWhite" )

  function ENT:CustomThink()
    if self:GetVelocity():LengthSqr() > 100 then
      self:AngleFollowVelocity()
    end
  end

  function ENT:CustomDraw()
    self:DrawModel()
    -- Freezeframe halo (uk_proj_rocket look)
    if not self:GetNW2Bool( "UKGT_TimeFrozen", false ) then return end
    if haloMat:IsError() then return end
    render.SetMaterial( haloMat )
    render.DrawQuadEasy( self:WorldSpaceCenter(), -EyeVector(), 56, 56,
      Color( 77, 212, 253 ), CurTime() * -45 % 360 )
  end

end

AddCSLuaFile()
