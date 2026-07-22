-- lua/entities/ultrakill_test_providence.lua
-- Providence (Lesser Angel, Layer 8: Hurtbreak Wonderland) — canon-faithful port.
-- Canon internals: Drone class, enemyType 38, health 16, flying billboard quad.
-- Behavior (wiki + prefab dump): keeps ~50 m from the target, dashes twice
-- before attacking, attacks in turns with other Providences, primary = Magenta
-- Cross Projectile (65.6%), secondary = Magenta Cross Pincer (34.4%), laughs
-- after dodging, shatters like glass on death (drops a heal — Pink Hookpoint).

AddCSLuaFile()

if not DrGBase or not UltrakillBase then return end
if not UKProvidence then include( "autorun/ultrakill_test_providence_shared.lua" ) end

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local SND = UKProvidence.SOUND

if CLIENT then
  util.PrecacheModel( UKProvidence.MODEL )
end

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Providence"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKProvidence.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKProvidence.HP
-- polish 2026-07-10: model rescaled x0.8 ($scale 302.33 -> 241.86)
ENT.CollisionBounds = Vector( 35, 35, 77 )
ENT.SurroundingBounds = Vector( 384, 384, 512 )

-- DrGBase Flying (Virtue pattern): gravity 0, hover pathing handled by the base.
ENT.Flying = true
ENT.FlyingHeight = 128

ENT.AISight = false
ENT.MeleeAttackRange = 10000
ENT.ReachEnemyRange = UKProvidence.PREFERRED_DIST
ENT.AvoidEnemyRange = 0
ENT.Acceleration = 2200
ENT.Deceleration = 2200
ENT.JumpHeight = 0
ENT.StepHeight = 0
ENT.MaxYawRate = 500
ENT.DeathDropHeight = math.huge
ENT.UseWalkframes = false
-- canon: much faster than Virtues — ProcessTargeting acceleration 250 (5x a
-- regular Drone's 50), velocity clamp 50 m/s
ENT.WalkSpeed = 1000
ENT.RunSpeed = 1000
-- r7: the baked 30 fps Idle reads too sluggish in Source — play it 2x
ENT.IdleAnimation = "Idle"; ENT.IdleAnimRate = 2
ENT.WalkAnimation = "Idle"; ENT.WalkAnimRate = 2
ENT.RunAnimation = "Idle"; ENT.RunAnimRate = 2
ENT.JumpAnimation = "Idle"; ENT.JumpAnimRate = 2

-- MDK/Drone-style facing (r8): entity yaw = server FaceTowards, card
-- pitch = the base FullTracking bone (Providence_Root pivots at the card
-- center, so the hitbox never drifts from the visual). Base Calculate is
-- stubbed below — the client runs its own smooth exp-lerp (MDK pattern).
ENT.UltrakillBase_FullTrackingBone = "Providence_Root"
ENT.UltrakillBase_FullTracking = true

-- NOT "Light": the ukarms Whiplash pulls the PLAYER towards non-light targets
-- (canon: you slingshot to a chanting Providence, it never gets reeled in)
ENT.UltrakillBase_WeightClass = "Medium"

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

-- flyer: CUSTOM movement, but NOT the base implementation — the base
-- ApproachFlying/UpdateFlying pipeline crawls at ~30 su/s on this loco
-- setup (stand-measured velocity sawtooth vs ground friction); see the
-- PossessionControls override below (direct loco velocity steering)
ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    offset = Vector( 0, 12, 50 ),
    distance = 170,
    eyepos = false

  },

  {

    offset = Vector( 10, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

-- same per-entity gates the AI uses in the idle state (a held key must not
-- spam); the global take-turns queue deliberately yields to the possessor.
-- No lock-on required: without one the attack aims at the crosshair point
-- (players rarely use lock-on — the fire sites fall back to PossessorTrace)
local function PossessionAttack( self, kind )

  if self.UKProv_State ~= "idle" or CurTime() < self.UKProv_NextAttack then return end

  local LockedOn = self:PossessionGetLockedOn()
  self:UKProv_BeginAttack( IsValid( LockedOn ) and LockedOn or nil, kind )

end

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    PossessionAttack( self, "orb" )

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    PossessionAttack( self, "pincer" )

  end } },

  [ IN_RELOAD ] = { { coroutine = false, onkeydown = function( self, Possessor )

    -- canon dodge burst; the AI paces its own dodges by a 1-3 s cooldown roll
    if self:GetCooldown( "PossessionDodge" ) > 0 then return end

    self:UKProv_ForceDodge( false )

    self:SetCooldown( "PossessionDodge", UKProvidence.DODGE_CD_MIN )

  end } },

}

if SERVER then

  -- ---- global attack queue (canon: Providences take turns) -----------------
  UKProvidence.Global = UKProvidence.Global or { cooldown = 0, windingUpRef = nil }
  local G = UKProvidence.Global

  hook.Add( "Tick", "UKProvidence_GlobalTick", function()
    if G.cooldown > 0 then G.cooldown = math.max( 0, G.cooldown - FrameTime() ) end
    if G.windingUpRef ~= nil and not IsValid( G.windingUpRef ) then G.windingUpRef = nil end

    -- canon Drone.Update: a hooked Providence instantly rips the Whiplash off
    -- (StopThrow), LAUGHS and force-dodges — EXCEPT during the Magenta Cross
    -- Pincer chant (wiki: while the sigil is up it cannot dodge the hook; the
    -- hook holds and pulls the PLAYER in, and it rips off the moment the chant
    -- ends and the sigil disappears). ai_disabled = inert, no rip-off either.
    for _, wl in ipairs( ents.FindByClass( "uk_whiplash" ) ) do
      if not IsValid( wl ) then continue end
      local att = wl.AttachedEnt
      if IsValid( att ) and att.UKProv_EvadeWhiplash then
        local chanting = att.UKProv_State == "windup" and att.UKProv_AttackKind == "pincer"
        -- possessed: no auto rip-off dodge (it would fight the player's
        -- controls); the GetRidingEntity trick still detaches the hook
        if not chanting and not att:IsAIDisabled() and not att:IsPossessed() then
          att:UKProv_EvadeWhiplash( wl )
        end
      end
    end

    -- movement bursts: DrGBase flying locomotion rewrites the velocity every
    -- tick, so a one-shot SetVelocity dash dies instantly — instead we force
    -- the burst velocity for its whole (short) duration. The possession
    -- steering velocity needs the same treatment (the base UpdateFlying
    -- zeroes a "resting" flyer every Think, eating slower-rate writes).
    for _, prov in ipairs( ents.FindByClass( UKProvidence.CLASS.Regular ) ) do
      if not IsValid( prov ) or not prov.loco then continue end
      if prov.UKProv_BurstEnd and CurTime() < prov.UKProv_BurstEnd then
        prov.loco:SetVelocity( prov.UKProv_BurstVel )
      elseif prov:IsPossessed() and prov.UKProv_PossessVel then
        prov.loco:SetVelocity( prov.UKProv_PossessVel )
      end
    end
  end )

  -- ---- lifecycle ------------------------------------------------------------
  function ENT:CustomInitialize()
    self:SetTurning( true )

    self.UKProv_State = "idle"
    self.UKProv_StateEnd = 0
    self.UKProv_DashesLeft = 0
    self.UKProv_AttackKind = "orb"
    self.UKProv_NextAttack = CurTime() + UKProvidence.ATTACK_CD_INITIAL
    self.UKProv_DodgeCD = math.Rand( UKProvidence.DODGE_CD_MIN, UKProvidence.DODGE_CD_MAX )

    self:SetParryable( false )
    self:SetNW2Int( "UKProv_WingSpinDir", 0 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    UltrakillBase.TraceSetPos( self, self:GetPos() + Vector( 0, 0, 100 ) )
    self:EmitSound( SND.Spawn, 75, 100, 0.6 )

    -- canon AmbientEffects TrailRenderer: pink streak, width 2.5 u, 0.25 s,
    -- color (1, 0.63, 0.82, 0.49) fading to transparent white
    util.SpriteTrail( self, 0, Color( 255, 160, 210, 125 ), false,
      60, 0, 0.25, 1 / 60 * 0.5, "trails/laser.vmt" )
  end

  function ENT:UKProv_GetDifficulty()
    return UKProvidence.GetDifficulty( self )
  end

  function ENT:UKProv_Timescale()
    return UKProvidence.TIMESCALE[ self:UKProv_GetDifficulty() ] or 1
  end

  local CV_IGNOREPLY = GetConVar( "ai_ignoreplayers" )

  function ENT:UKProv_GetEnemy()
    local enemy = self:GetEnemy() -- possessed: the base substitutes the lock-on
    if IsValid( enemy ) then return enemy end
    -- possessed with no lock-on: never fall back to the scan below (it would
    -- pick the possessor himself as the target)
    if self:IsPossessed() then return nil end
    -- the fallback player scan MUST respect ai_ignoreplayers (the sandbox
    -- "Ignore Players" option), otherwise the bot attacks despite the setting
    if CV_IGNOREPLY and CV_IGNOREPLY:GetBool() then return nil end
    local closest, cdist = nil, math.huge
    for _, ply in ipairs( player.GetAll() ) do
      if ply:Alive() and not ply.UltrakillBase_Friendly then
        local d = self:GetPos():DistToSqr( ply:GetPos() )
        if d < cdist then closest = ply; cdist = d end
      end
    end
    return closest
  end

  -- canon: cannot follow players outside its line of sight
  function ENT:UKProv_HasLOS( target )
    local tr = util.TraceLine( {
      start = self:WorldSpaceCenter(),
      endpos = target.EyePos and target:EyePos() or target:WorldSpaceCenter(),
      mask = MASK_BLOCKLOS,
      filter = { self, target },
    } )
    return not tr.Hit
  end

  -- ---- think / state machine -------------------------------------------------
  function ENT:CustomThink()
    if self:Health() <= 0 then return end

    local possessed = self:IsPossessed()

    -- ai_disabled / per-bot disable; DrGBase itself keeps running possession
    -- under ai_disabled, so the possessed state machine must too
    if self:IsAIDisabled() and not possessed then return end

    -- MDK/Drone-style facing: yaw follows the target on the server, the aim
    -- pitch is networked for the client card-tracking bone (possessed: the
    -- base PossessionFaceForward owns both yaw and aim — no auto-tracking)
    if not possessed then
      local faceTarget = self:UKProv_GetEnemy()
      if IsValid( faceTarget ) then
        self:FaceTowards( faceTarget:GetPos() )
        self:AimTowards( faceTarget )
      end
    end

    local state = self.UKProv_State

    if state == "idle" then
      -- possessed: attacks and dodges start only from the possession binds;
      -- the dash/windup/recover branches below still run — the binds rely on
      -- the state machine to execute the attack they started
      if possessed then return end
      self:UKProv_TickDodge()
      if CurTime() < self.UKProv_NextAttack then return end
      if G.cooldown > 0 or ( G.windingUpRef ~= nil and G.windingUpRef ~= self ) then return end
      local target = self:UKProv_GetEnemy()
      if not IsValid( target ) or not self:UKProv_HasLOS( target ) then return end
      self:UKProv_BeginAttack( target )

    elseif state == "dash" then
      if CurTime() < self.UKProv_StateEnd then return end
      if self.UKProv_DashesLeft > 0 then
        self:UKProv_Dash()
      else
        self:UKProv_BeginWindup()
      end

    elseif state == "windup" then
      -- possessed: steer the pincer sigil with the crosshair until it fires
      if possessed and self.UKProv_AttackKind == "pincer"
         and IsValid( self.UKProv_PincerEnt ) and not self.UKProv_PincerEnt.UKPincer_BeamsOn then
        self.UKProv_PincerEnt:SetNW2Vector( "UKPincer_TargetPos", self:UKProv_PossessionAimPos() )
      end
      if CurTime() < self.UKProv_StateEnd then return end
      self:UKProv_Fire()

    elseif state == "recover" then
      if CurTime() < self.UKProv_StateEnd then return end
      self:UKProv_EndAttack()
    end
  end

  function ENT:UKProv_BeginAttack( target, kind )
    -- possessed: the player decides the pacing — bypass the take-turns
    -- queue and never block the AI Providences with it
    if not self:IsPossessed() then
      G.windingUpRef = self
      G.cooldown = UKProvidence.GLOBAL_CD
    end
    self.UKProv_Target = target
    -- possession binds pass an explicit kind; the AI rolls the canon 34.4%
    self.UKProv_AttackKind = kind or ( math.random() < UKProvidence.SECONDARY_CHANCE and "pincer" or "orb" )
    self.UKProv_DashesLeft = UKProvidence.DASHES[ self:UKProv_GetDifficulty() ] or 2
    self.UKProv_State = "dash"
    self.UKProv_StateEnd = 0
  end

  -- canon: dashes twice before attacking (perpendicular hops)
  function ENT:UKProv_Dash()
    self.UKProv_DashesLeft = self.UKProv_DashesLeft - 1
    self.UKProv_State = "dash"
    self.UKProv_StateEnd = CurTime() + ( UKProvidence.DASH_TIME + UKProvidence.DASH_GAP ) / self:UKProv_Timescale()

    local up = Vector( 0, 0, 1 )
    local right = self:GetRight()
    local dir = up * math.Rand( -0.6, 1 ) + right * ( math.random() < 0.5 and -1 or 1 ) * math.Rand( 0.6, 1 )
    dir:Normalize()
    local tr = util.TraceLine( {
      start = self:GetPos(),
      endpos = self:GetPos() + dir * UKProvidence.DASH_WALL_PROBE,
      filter = self, mask = MASK_SOLID_BRUSHONLY,
    } )
    if tr.Hit then dir = -dir end
    self:UKProv_Burst( dir, UKProvidence.DASH_DIST / UKProvidence.DASH_TIME, UKProvidence.DASH_TIME )
    self:EmitSound( SND.Dodge, 68, math.random( 90, 115 ), 0.7 )
  end

  function ENT:UKProv_BeginWindup()
    local kind = self.UKProv_AttackKind
    self.UKProv_State = "windup"

    -- canon: both windups are parryable (base framework: flash + hitstop)
    self:SetParryable( true )

    if kind == "pincer" then
      -- canon: the sigil is visible for the WHOLE chant — the Pincer entity
      -- spawns now at the eye and fires its beams on its own fixed schedule
      -- (windup 1.0 + delay 0.5, canon timings, not difficulty-scaled)
      self.UKProv_StateEnd = CurTime() + UKProvidence.PINCER_WINDUP + UKProvidence.PINCER_DELAY
      -- canon ShootSecondary: wings spin at a random sign (opposite pairs) and
      -- the sigil rotates the same way
      self.UKProv_SpinDir = math.random( 2 ) == 1 and 1 or -1
      self:SetNW2Int( "UKProv_WingSpinDir", self.UKProv_SpinDir )
      local target = IsValid( self.UKProv_Target ) and self.UKProv_Target or self:UKProv_GetEnemy()
      if IsValid( target ) then
        self:UKProv_SpawnPincer( target )
      elseif self:IsPossessed() then
        -- possessed with no lock-on: chant at the crosshair point
        self:UKProv_SpawnPincer( nil, self:UKProv_PossessionAimPos() )
      end
      local seq = self:LookupSequence( "BeamPrep" )
      if seq and seq >= 0 then self:ResetSequence( seq ) end
      self:EmitSound( SND.WindupBig, 78, 100, 1, CHAN_VOICE )
    else
      self.UKProv_StateEnd = CurTime() + UKProvidence.WINDUP_PRIMARY / self:UKProv_Timescale()
      local seq = self:LookupSequence( "Shoot" )
      if seq and seq >= 0 then self:ResetSequence( seq ) end
      self:EmitSound( SND.Windup[ math.random( #SND.Windup ) ], 78, 100, 1, CHAN_VOICE )
    end
  end

  function ENT:UKProv_Fire()
    self:SetParryable( false )
    local target = IsValid( self.UKProv_Target ) and self.UKProv_Target or self:UKProv_GetEnemy()

    if self.UKProv_AttackKind == "pincer" then
      -- the Pincer entity fires by itself right now; play the shoot anim and
      -- reset the wing spin (canon PincerFired)
      local seq = self:LookupSequence( "BeamShoot" )
      if seq and seq >= 0 then self:ResetSequence( seq ) end
      self:SetNW2Int( "UKProv_WingSpinDir", 0 )
    elseif IsValid( target ) then
      self:UKProv_FireOrb( target )
    elseif self:IsPossessed() then
      -- possessed with no lock-on: the orb flies at the crosshair point
      self:UKProv_FireOrb( nil, self:UKProv_PossessionAimPos() )
    end

    -- canon Shoot/PincerFired: recoil impulse backwards
    self:UKProv_Burst( -self:GetForward(), 400, 0.15 )

    if G.windingUpRef == self then G.windingUpRef = nil end
    self.UKProv_State = "recover"
    self.UKProv_StateEnd = CurTime() + UKProvidence.RECOVER / self:UKProv_Timescale()
  end

  function ENT:UKProv_EndAttack()
    self.UKProv_State = "idle"
    self:SetNW2Int( "UKProv_WingSpinDir", 0 )
    local idle = self:LookupSequence( "Idle" )
    if idle and idle >= 0 then self:ResetSequence( idle ) end
    self.UKProv_NextAttack = CurTime()
      + math.Rand( UKProvidence.ATTACK_CD_MIN, UKProvidence.ATTACK_CD_MAX ) / self:UKProv_Timescale()
  end

  function ENT:UKProv_EyePos()
    local id = self:LookupAttachment( "eye" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter()
  end

  -- canon base aiming recipe (AimProjectile): possessed target = lock-on
  -- center, otherwise the point under the player's crosshair — vertical
  -- included (PossessorTrace)
  function ENT:UKProv_PossessionAimPos()
    local LockedOn = self:PossessionGetLockedOn()
    if IsValid( LockedOn ) then return LockedOn:WorldSpaceCenter() end
    local tr = self:PossessorTrace()
    if tr and tr.HitPos then return tr.HitPos end
    return self:UKProv_EyePos() + self:GetAimVector() * 1000
  end

  -- The base CUSTOM PossessionControls drives ApproachFlying/UpdateFlying;
  -- on this loco setup that pipeline crawls at ~30 su/s and its "resting"
  -- branch zeroes any slower-rate SetVelocity every Think (stand-measured).
  -- Instead this only COMPUTES the steering velocity — the global Tick above
  -- enforces it every tick, the same mechanism the dash/dodge bursts use.
  -- Controls match Kevin's flyers: WASD relative to the crosshair (forward
  -- follows the full 3D aim), plus jump/duck for pure vertical.
  function ENT:PossessionControls( bForward, bBackward, bRight, bLeft )
    local dir = Vector( 0, 0, 0 )
    if bForward then
      dir = dir + self:PossessorNormal()
    elseif bBackward then
      dir = dir - self:PossessorNormal()
    end
    if bRight then
      dir = dir + self:PossessorRight()
    elseif bLeft then
      dir = dir - self:PossessorRight()
    end
    local possessor = self:GetPossessor()
    if IsValid( possessor ) then
      if possessor:KeyDown( IN_JUMP ) then
        dir.z = dir.z + 1
      elseif possessor:KeyDown( IN_DUCK ) then
        dir.z = dir.z - 1
      end
    end

    if dir:IsZero() then
      self.UKProv_PossessVel = vector_origin
    else
      dir:Normalize()
      -- ground contact eats loco velocity: hop off first (base FlyGround)
      if self:IsOnGround() then
        local jh = self.loco:GetJumpHeight()
        self.loco:SetJumpHeight( 1 )
        self.loco:Jump()
        self.loco:SetJumpHeight( jh )
      end
      self.UKProv_PossessVel = dir * self:GetDesiredSpeed()
    end

    self:PossessionFaceForward()
  end

  -- canon 'Projectile Providence': fired from the eye at the target
  -- (or at an explicit point — possession crosshair aim)
  function ENT:UKProv_FireOrb( target, aimpos )
    local from = self:UKProv_EyePos()
    local goal = aimpos or ( target.EyePos and target:EyePos() or target:WorldSpaceCenter() )
    local aim = goal - from
    aim:Normalize()

    local proj = ents.Create( UKProvidence.CLASS.Orb )
    if not IsValid( proj ) then return end
    proj:SetPos( from + aim * 24 )
    proj:SetAngles( aim:Angle() )
    proj:SetOwner( self )
    proj:Spawn()
    local speed = UKProvidence.ORB_SPEED
      * ( UKProvidence.PROJ_SPEED_MULT[ self:UKProv_GetDifficulty() ] or 1 )
    proj:SetVelocity( aim * speed )

    self:EmitSound( SND.Charge, 75, 100, 0.8 )
  end

  -- canon 'ProvidencePincer': the sigil sits in front of the eye during the
  -- chant, then the beams fire FROM THE EYE; source and target lock on fire
  -- (possession: target may be nil — the crosshair point comes as aimpos)
  function ENT:UKProv_SpawnPincer( target, aimpos )
    local pincer = ents.Create( UKProvidence.CLASS.Pincer )
    if not IsValid( pincer ) then return end
    pincer:SetPos( self:UKProv_EyePos() )
    pincer.UKPincer_Owner = self
    pincer.UKPincer_Target = target
    pincer:SetNW2Vector( "UKPincer_TargetPos", aimpos or target:WorldSpaceCenter() )
    pincer:SetNW2Int( "UKPincer_Dir", self.UKProv_SpinDir or 1 )
    pincer:Spawn()
    self.UKProv_PincerEnt = pincer
  end

  -- short velocity burst enforced by the global Tick (see above)
  function ENT:UKProv_Burst( dir, speed, dur )
    self.UKProv_BurstVel = dir * speed
    self.UKProv_BurstEnd = CurTime() + dur
  end

  -- ---- canon Drone.Dodge: dir = up*rand(-5,5) + right*rand(-5,5), 7 m wall
  -- probe flips it, then a hard impulse (Providence: 750 vs Virtue 150)
  function ENT:UKProv_CanonDodge()
    local dir = self:GetUp() * math.Rand( -5, 5 ) + self:GetRight() * math.Rand( -5, 5 )
    if dir:IsZero() then dir = Vector( 0, 0, 1 ) end
    dir:Normalize()
    local tr = util.TraceLine( {
      start = self:GetPos(),
      endpos = self:GetPos() + dir * UKProvidence.DODGE_WALL_PROBE,
      filter = self, mask = MASK_SOLID_BRUSHONLY,
    } )
    if tr.Hit then dir = -dir end
    self:UKProv_Burst( dir, UKProvidence.DODGE_SPEED, 0.22 )
    self:EmitSound( SND.Dodge, 65, math.random( 75, 125 ), 0.6 )
  end

  -- canon Drone.RandomDodge: single dash; a second one 0.1 s later when
  -- forced or on BRUTAL+
  function ENT:UKProv_ForceDodge( force )
    local diff = self:UKProv_GetDifficulty()
    self:UKProv_CanonDodge()
    if diff >= 2 and ( diff >= 4 or force ) then
      local slf = self
      timer.Simple( 0.1, function()
        if IsValid( slf ) and slf.UKProv_CanonDodge then slf:UKProv_CanonDodge() end
      end )
    end
  end

  -- uk_whiplash's CaptureEnt trace filter SKIPS (flies straight through) any
  -- entity whose GetRidingEntity() is valid, and its Think insta-StopReels
  -- when an attached target gains one. Outside the Magenta Cross Pincer chant
  -- we "ride ourselves", so the hook can NEVER latch on — not even for one
  -- tick (r7: no attach at all while it can dodge). During the chant the
  -- method returns nothing and the hook holds canonically.
  function ENT:GetRidingEntity()
    if self.UKProv_State == "windup" and self.UKProv_AttackKind == "pincer" then return end
    return self
  end

  -- canon Drone.Update hook block: StopThrow + guaranteed DodgeLaugh + forced
  -- (double) dodge. Reachable only when a hook held through the chant and the
  -- chant just ended (the sigil disappears -> instant rip-off).
  function ENT:UKProv_EvadeWhiplash( wl )
    if IsValid( wl ) then
      -- clear AttachedEnt BEFORE StopReel so the base reel-end never touches
      -- the player's momentum (hookpoint slingshot pattern)
      wl.AttachedEnt = nil
      if wl.StopReel then wl:StopReel() end
    end
    self:EmitSound( SND.Laugh, 74, math.random( 95, 105 ), 1, CHAN_VOICE )
    self:UKProv_ForceDodge( true )
  end

  -- canon Drone.Update dodge loop: the 1-3 s cooldown ticks at the
  -- difficulty cooldown speed (halved for Providence below BRUTAL), then an
  -- unforced RandomDodge. Providence skips random dodges on HARMLESS/LENIENT.
  function ENT:UKProv_TickDodge()
    local target = self:UKProv_GetEnemy()
    if not IsValid( target ) then return end

    local diff = self:UKProv_GetDifficulty()
    local rate = UKProvidence.DODGE_TICK_RATE[ diff ] or 0.5
    self.UKProv_DodgeCD = self.UKProv_DodgeCD - FrameTime() * rate
    if self.UKProv_DodgeCD > 0 then return end
    self.UKProv_DodgeCD = math.Rand( UKProvidence.DODGE_CD_MIN, UKProvidence.DODGE_CD_MAX )

    if diff < 2 then return end
    self:UKProv_ForceDodge( false )
  end

  -- ---- damage / parry ---------------------------------------------------------
  -- canon Feedbacker parry modifier: 60% (reduced) — no instakill
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    dmg:SetDamage( math.floor( dmg:GetDamage() * UKProvidence.PARRY_DMG_MULT ) )

    -- parry cancels the windup (and the pincer sigil with it)
    if self.UKProv_State == "windup" then
      self:SetParryable( false )
      self:SetNW2Int( "UKProv_WingSpinDir", 0 )
      if IsValid( self.UKProv_PincerEnt ) then self.UKProv_PincerEnt:Remove() end
      if G.windingUpRef == self then G.windingUpRef = nil end
      self.UKProv_State = "recover"
      self.UKProv_StateEnd = CurTime() + UKProvidence.RECOVER
    end
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  -- ---- death: glass shatter (canon ProvidenceShatter) + heal drop -------------
  function ENT:OnKilled( dmginfo )
    local pos = self:WorldSpaceCenter()
    self:EmitSound( SND.Death, 78, math.random( 95, 105 ), 1, CHAN_VOICE )
    sound.Play( SND.Shatter, pos, 78, math.random( 95, 105 ), 0.6 )

    for i = 1, 6 do
      local ed = EffectData()
      ed:SetOrigin( pos + VectorRand() * 30 )
      ed:SetNormal( VectorRand():GetNormalized() )
      util.Effect( "GlassImpact", ed )
    end
    local ed = EffectData()
    ed:SetOrigin( pos )
    util.Effect( "cball_explode", ed )
    util.ScreenShake( pos, 4, 10, 0.5, 600 )

    -- canon Drone.Death: Providence explodes instantly on death (workshop
    -- report 2026-07-10 flagged the missing blast). Harmless shockwave —
    -- Kevin's transparent soft explosion + knockback, no damage dealt.
    local boom = EffectData()
    boom:SetOrigin( pos )
    boom:SetRadius( 170 )
    util.Effect( "Ultrakill_Soft_Explosion", boom, true, true )
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    end
    for _, ent in ipairs( ents.FindInSphere( pos, 250 ) ) do
      if ent == self then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      local dir = ent:GetPos() - pos
      if dir:IsZero() then continue end
      dir.z = math.max( dir.z, 50 )
      ent:SetVelocity( dir:GetNormalized() * 400 )
    end

    -- canon: drops a Pink Hookpoint (slingshot + full heal + explosion)
    local heal = ents.Create( "ultrakill_test_hookpoint_pink" )
    if IsValid( heal ) then
      heal:SetPos( pos )
      heal:Spawn()
    end

    self:Remove()
  end

end

-- The base's CalculateFullTracking is jerky: it rotates the bone on BOTH the
-- server (quantized networked angles) and the client with think-interval
-- steps. Stub it and run a pure client-side per-frame exp-lerp instead
-- (MDK/Idol/DC pattern).
function ENT:CalculateFullTracking() end

if CLIENT then

  -- canon soft white glow behind the body ('Plane' node, GlowStrong sprite)
  local MAT_GLOW = Material( "effects/ukprovidence_glowstrong" )
  local MAGENTA = UKProvidence.MAGENTA

  local WING_BONES = { "PrimaryWings_Center", "SecondaryWings_Center" }

  -- MDK-style card pitch: the networked aim pitch goes into the ROLL slot of
  -- the Providence_Root manipulation (the bone's local X = entity +Y, same
  -- axis family as MDK's Mandalore — the base DoFullTracking convention).
  -- Yaw comes from the server entity angles (FaceTowards), so the card faces
  -- the target at any angle while the hitbox stays put.
  local TRACK_RATE = 6 -- 1/s exp catch-up speed

  function ENT:UKProv_TickTracking()
    local bone = self:LookupBone( "Providence_Root" )
    if not bone then return end
    local aim = self:GetAimAngles()
    local goal = Angle( 0, 0, aim and aim.p or 0 )
    local cur = self.UKProv_TrackAng
    if not cur then
      cur = Angle( goal ) -- first frame: snap, no swing-in from zero
    else
      cur = LerpAngle( 1 - math.exp( -TRACK_RATE * FrameTime() ), cur, goal )
    end
    self.UKProv_TrackAng = cur
    self:ManipulateBoneAngles( bone, cur, false )
  end

  -- canon BlinkAnimTex (Eye node): blinkDelay 0.1, random 3-5 s between
  -- blinks; frames = T_EyeTest_Anim texture-array slices 1..3, then back to
  -- the default open frame (slice 0 = the regular body material)
  local BLINK_FRAMES = {
    "models/ultrakill_prelude_test/providence/providence_body_f1",
    "models/ultrakill_prelude_test/providence/providence_body_f2",
    "models/ultrakill_prelude_test/providence/providence_body_f3",
  }

  function ENT:UKProv_TickBlink()
    if self.UKProv_BodyMatIdx == nil then
      self.UKProv_BodyMatIdx = false
      for i, m in ipairs( self:GetMaterials() ) do
        if m:find( "providence_body", 1, true ) then
          self.UKProv_BodyMatIdx = i - 1
          break
        end
      end
    end
    local idx = self.UKProv_BodyMatIdx
    if idx == false then return end

    local now = CurTime()
    if not self.UKProv_BlinkStart then
      self.UKProv_NextBlink = self.UKProv_NextBlink or now + math.Rand( 3, 5 )
      if now < self.UKProv_NextBlink then return end
      self.UKProv_BlinkStart = now
    end
    local f = math.floor( ( now - self.UKProv_BlinkStart ) / 0.1 ) + 1
    if f > #BLINK_FRAMES then
      self:SetSubMaterial( idx, "" )
      self.UKProv_BlinkStart = nil
      self.UKProv_NextBlink = now + math.Rand( 3, 5 )
    else
      self:SetSubMaterial( idx, BLINK_FRAMES[ f ] )
    end
  end

  function ENT:Draw()
    self:UKProv_TickTracking()

    -- canon Drone.Update wing block: during the chant the rotator wings spin
    -- at 360 deg/s around their local axis, PAIRS IN OPPOSITE DIRECTIONS,
    -- random overall sign; outside the chant they sit at their default pose
    -- (the Animator handles idle motion — no artificial flutter)
    local spin = self:GetNW2Int( "UKProv_WingSpinDir", 0 )
    for i, bname in ipairs( WING_BONES ) do
      local bid = self:LookupBone( bname )
      if bid then
        local ang = Angle( 0, 0, 0 )
        if spin ~= 0 then
          ang = Angle( 0, 0, ( CurTime() * 360 * spin * ( i == 2 and -1 or 1 ) ) % 360 )
        end
        self:ManipulateBoneAngles( bid, ang )
      end
    end

    self:DrawModel()

    -- (the canon GlowStrong plane is baked INTO the model as the
    -- providence_glow mesh — a client sprite always ended up ON TOP of the
    -- eye card because translucent meshes write no depth)

    -- canon BlinkAnimTex: every 3-5 s cycle the T_EyeTest_Anim frames at
    -- 0.1 s/frame (open -> half -> closed -> half -> open)
    self:UKProv_TickBlink()

    local pos = self:WorldSpaceCenter()

    -- magenta buildup while the windup is parryable
    if self:GetNW2Bool( "UltrakillBase_Parryable", false ) then
      local f = 0.6 + 0.4 * math.sin( CurTime() * 20 )
      render.SetMaterial( MAT_GLOW )
      render.DrawSprite( pos, 88 * f, 88 * f,
        Color( MAGENTA.r, MAGENTA.g, MAGENTA.b, 140 * f ) )
    end
  end

end

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_providence", {
  Name = ENT.PrintName,
  Class = "ultrakill_test_providence",
  Category = ENT.Category,
  AdminOnly = false,
} )
