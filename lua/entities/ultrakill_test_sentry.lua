AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_sentry_shared.lua" )

-- Sentry (Turret). Canon overhaul 2026-07-03 — full rewrite of the 2026-05 MVP
-- on the Ferryman action/event pattern. Every timing/number comes from
-- Turret.cs, the gameplay prefab dump, or the .anim clip events.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Sentry"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKSentry.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKSentry.HP
-- compiled hull: x -41..50, y +-24, z 0..161. Bullet traces only refine into
-- hitboxes INSIDE the collision box — z must cover the antenna tip (~161).
ENT.CollisionBounds = Vector( 26, 26, 168 )
ENT.SurroundingBounds = Vector( 60, 60, 180 )
-- sentry.mdl ships a jointed $collisionjoints .phy (2026-07-07) — death
-- leaves a real ragdoll
ENT.RagdollOnDeath = true
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }

local UNIT = UKSentry.UNIT

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
-- small: the base stops pathing inside ReachEnemyRange with a visible enemy,
-- and the Sentry should keep walking between attacks (kick triggers from
-- CustomThink at KICK_RANGE on its own)
ENT.ReachEnemyRange = 50
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 9 * UNIT * 10 -- canon accel 360 is effectively instant
ENT.Deceleration = 9 * UNIT * 10
ENT.UltrakillBase_WeightClass = "Medium" -- round 4 2026-07-10: whiplash must not reel the turret in
ENT.WalkSpeed = UKSentry.MOVE_SPEED
ENT.RunSpeed = UKSentry.MOVE_SPEED
ENT.MaxYawRate = UKSentry.ANGULAR_SPEED
ENT.JumpHeight = 100
ENT.StepHeight = 20
ENT.DeathDropHeight = 30
ENT.UseWalkframes = false

-- Animator state speeds from Turret.controller: Idle 1.5, Running 1.75.
ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1.5
ENT.WalkAnimation = "Running"
ENT.WalkAnimRate = 1.75
ENT.RunAnimation = "Running"
ENT.RunAnimRate = 1.75
ENT.JumpAnimation = "Falling"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Falling"
ENT.FallingAnimRate = 1

ENT.EyeBone = "Head"

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    -- compiled hull is 168 tall (~2.3x a humanoid) — presets scaled up from
    -- the workshop humanoid numbers (offset 0/11.5/34.5, distance 115)
    offset = Vector( 0, 24, 75 ),
    distance = 250,
    eyepos = false

  },

  {

    offset = Vector( 12, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  -- charged shot cycle (windup -> aim -> flash -> beam). While possessed
  -- the whole cycle tracks the possessor's crosshair (UKS_PossAimPos) —
  -- lock-on is optional, never a requirement (players don't use it).
  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self )

    if self.UKS_Dead or self:UKS_InAction() or not self:IsOnGround()
        or self.UKS_Cooldown > 0 then return end
    self:UKS_StartWindup( self:PossessionGetLockedOn() )

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self )

    if self.UKS_Dead or self:UKS_InAction() or not self:IsOnGround()
        or self.UKS_KickCooldown > 0 then return end
    self:UKS_Kick( self:PossessionGetLockedOn() )

  end } },

  -- manual CancelAim: the AI's out-of-sight auto-cancel is gated while
  -- possessed — the possessor owns the cancel decision
  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self )

    if self.UKS_Dead then return end
    if self.UKS_Mode ~= "windup" and self.UKS_Mode ~= "aim" then return end
    self:EmitSound( UKSentry.SOUND.Cancel, 75, 100, 0.75 )
    self:UKS_CancelAim( false )

  end } },

}

-- NW2 keys (UKSentry_Glow is also read by the matproxy in
-- autorun/client/ultrakill_test_sentry_matproxy.lua — keep the name).
local NW_GLOW = "UKSentry_Glow"
local NW_LASER_ON = "UKSentry_LaserOn"
local NW_LASER_COL = "UKSentry_LaserCol"
local NW_LASER_END = "UKSentry_LaserEnd"
local NW_FLASH_T = "UKSentry_FlashT"
local NW_BEEP = "UKSentry_Beep"
local NW_SHOT = "UKSentry_Shot"
local NW_SHOT_END = "UKSentry_ShotEnd"

--------------------------------------------------------------------------------
-- Actions: clip events (seconds at clip speed 1.0; .anim event dump 2026-07-03).
-- rate = Turret.controller state speed; runtime rate = rate x difficulty speed.
--------------------------------------------------------------------------------

local ACTION = {
  AimStart = {
    seq = "AimStart", dur = 1.333, rate = 1.0,
    ev = {
      { 0.331, "lodge", 0 }, { 0.599, "extend" }, { 0.667, "lodge", 1 },
      { 0.985, "thunk" }, { 1.106, "startAiming" },
    },
  },
  -- the aim loop itself is open-ended (no dur-based expiry)
  Aiming = { seq = "Aiming", dur = math.huge, rate = 1.0, ev = {} },
  Shoot = {
    seq = "Shoot", dur = 2.0, rate = 1.0,
    ev = {
      { 0.727, "unlodge", 1 }, { 0.980, "footstep" },
      { 1.111, "unlodge", 0 }, { 1.323, "footstep" },
      { 1.749, "stopAction" },
    },
  },
  CancelAim = {
    seq = "CancelAim", dur = 1.333, rate = 1.5,
    ev = {
      { 0.434, "unlodge", 1 }, { 0.636, "footstep" },
      { 0.781, "unlodge", 0 }, { 0.980, "footstep" },
      { 1.114, "stopAction" },
    },
  },
  InterruptAim = {
    seq = "InterruptAim", dur = 3.0, rate = 1.0,
    ev = {
      { 1.644, "unlodge", 1 }, { 1.972, "footstep" },
      { 2.114, "unlodge", 0 }, { 2.333, "footstep" },
      { 2.664, "stopAction" },
    },
  },
  Kick = {
    seq = "Kick", dur = 1.0, rate = 0.85,
    ev = {
      { 0.503, "dmgOn" }, { 0.582, "dmgOff" }, { 0.941, "stopAction" },
    },
  },
}

if SERVER then

  -- optional turret mode (spec stretch): snapshot at spawn
  local cvStationary = CreateConVar( "ultrakill_sentry_stationary", "0",
    FCVAR_ARCHIVE, "Newly spawned Sentries hold position (canon stationary mode)" )

  ------------------------------------------------------------------------------
  -- Init
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKSentry.HP
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKS_Dead = false
    self.UKS_Difficulty = UKSentry.GetDifficulty( self )
    self.UKS_MaxAimTime = UKSentry.AIM_TIME_BY_DIFF[ self.UKS_Difficulty ] or 4.0
    self.UKS_Stationary = cvStationary:GetBool()

    -- canon Turret field inits
    self.UKS_Cooldown = UKSentry.COOLDOWN_INITIAL
    self.UKS_KickCooldown = 1.0

    self.UKS_Mode = "idle"          -- idle|windup|aim|shoot|cancel|interrupt|kick
    self.UKS_ActionStart = 0
    self.UKS_ActionRate = 1
    self.UKS_ActionEvIndex = 1
    self.UKS_Aiming = false
    self.UKS_AimTime = 0
    self.UKS_FlashTime = 0
    self.UKS_OutOfSight = 0
    self.UKS_WhiteLine = false
    self.UKS_NextBeep = 0
    self.UKS_LastBeep = 0
    self.UKS_ShotsInRow = 0
    self.UKS_PreReAimAt = nil
    self.UKS_ReAimAt = nil
    self.UKS_LeftLodged = false
    self.UKS_RightLodged = false
    self.UKS_KickDamaging = false
    self.UKS_KickHits = nil
    self.UKS_DelayedPos = nil
    self.UKS_HasVision = false
    self.UKS_NextVisionCheck = 0
    -- walk for a couple of seconds after spawn before the first burrow
    self.UKS_WanderUntil = CurTime() + UKSentry.SPAWN_WANDER
    -- per-player ground-slam NW flag snapshots (slam deals no damage — the
    -- canon "shockwave interrupts the aim" needs the true->false transition)
    self.UKS_SlamState = {}

    self:SetNW2Int( NW_GLOW, 0 )
    self:SetNW2Bool( NW_LASER_ON, false )
    self:SetNW2Int( NW_LASER_COL, 0 )
    self:SetNW2Vector( NW_LASER_END, vector_origin )
    self:SetNW2Float( NW_FLASH_T, 0 )
    self:SetNW2Int( NW_BEEP, 0 )
    self:SetNW2Int( NW_SHOT, 0 )
    self:SetInterruptable( false )
    self:SetParryable( false )

    self:EmitSound( UKSentry.SOUND.Spawn, 85, 100, 0.6 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  ------------------------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------------------------

  function ENT:UKS_AnimSpeed()
    return UKSentry.ANIM_SPEED_BY_DIFF[ self.UKS_Difficulty ] or 1.0
  end

  function ENT:UKS_AttPos( name, fallback )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos, att.Ang end
    end
    return fallback, self:GetAngles()
  end

  function ENT:UKS_BarrelPos()
    return self:UKS_AttPos( "barrel_tip", self:WorldSpaceCenter() + self:GetUp() * 40 )
  end

  function ENT:UKS_AntennaPos()
    return self:UKS_AttPos( "antenna", self:GetPos() + Vector( 0, 0, 150 ) )
  end

  -- possession aim point (canon ultrakillbase_aiming AimProjectile recipe):
  -- lock-on target center if any, else the point under the possessor's
  -- crosshair — including the vertical
  function ENT:UKS_PossAimPos()
    local locked = self:PossessionGetLockedOn()
    if IsValid( locked ) then return locked:WorldSpaceCenter() end
    local tr = self:PossessorTrace()
    if tr and tr.HitPos then return tr.HitPos end
    return self:UKS_BarrelPos() + self:GetForward() * UKSentry.BEAM_RANGE
  end

  -- canon VisionSourcePosition: (x, head.y, z) — body axis at head height
  function ENT:UKS_VisionPos()
    local headPos = self:UKS_AttPos( "head", self:WorldSpaceCenter() + Vector( 0, 0, 40 ) )
    local pos = self:GetPos()
    return Vector( pos.x, pos.y, headPos.z )
  end

  function ENT:UKS_HasLOS( enemy )
    local tr = util.TraceLine{
      start = self:UKS_VisionPos(),
      endpos = enemy:WorldSpaceCenter(),
      filter = { self, enemy },
      mask = MASK_VISIBLE_AND_NPCS,
    }
    return not tr.Hit
  end

  function ENT:UKS_FaceInstant( pos )
    local diff = pos - self:GetPos(); diff.z = 0
    if diff:LengthSqr() < 1 then return end
    self:SetAngles( Angle( 0, diff:Angle().yaw, 0 ) )
  end

  -- canon Turret.GetWanderPosition: a random horizontal ray, endpoint (or
  -- wall hit minus a step) dropped to the ground. Round 2 (2026-07-10):
  -- shorter legs — the 8-25 m spread wandered way too far from the post
  function ENT:UKS_PickWanderPos()
    local myPos = self:GetPos()
    local eye = myPos + Vector( 0, 0, 32 )
    for _ = 1, 6 do
      local yaw = math.Rand( 0, 360 )
      local dir = Vector( math.cos( math.rad( yaw ) ), math.sin( math.rad( yaw ) ), 0 )
      local tr = util.TraceLine{
        start = eye,
        endpos = eye + dir * math.Rand( 4, 10 ) * UNIT,
        mask = MASK_SOLID_BRUSHONLY,
        filter = self,
      }
      local goal = tr.HitPos - dir * 20
      local down = util.TraceLine{
        start = goal,
        endpos = goal - Vector( 0, 0, 500 ),
        mask = MASK_SOLID_BRUSHONLY,
      }
      if down.Hit and down.HitPos:DistToSqr( myPos ) > ( 2 * UNIT ) ^ 2 then
        return down.HitPos
      end
    end
    return nil
  end

  -- canon Turret.NavigationUpdate: with clear LOS the turret never beelines
  -- at the player — it walks to random wander spots instead; only a HIDDEN
  -- target gets pathed to directly (workshop report 2026-07-10: "chases you
  -- directly instead of wandering around for a position"). The
  -- round-5 rule stays intact: it keeps walking between attacks either way.
  -- Round 2: a wander leg lasts ~2 s on Brutal+, ~3 s below.
  function ENT:OnChaseEnemy( enemy )
    if not self.UKS_HasVision then return end    -- hidden target: base direct path (canon)
    local now = CurTime()
    local goal = self.UKS_WanderGoal
    if not goal or now >= ( self.UKS_WanderRepickAt or 0 )
        or self:GetPos():DistToSqr( goal ) < 70 * 70 then
      goal = self:UKS_PickWanderPos()
      self.UKS_WanderGoal = goal
      self.UKS_WanderRepickAt = now
        + ( ( self.UKS_Difficulty or 3 ) >= 4 and 2.0 or 3.0 )
    end
    if not goal then return end                  -- nowhere to strafe: fall back to chase
    self:FollowPath( goal, 50 )
    return true
  end

  function ENT:UKS_Footstep()
    -- canon FootStep(0) => pitch 1.5 +- 0.1
    self:EmitSound( UKSentry.SOUND.Step, 75, math.random( 140, 160 ), 0.8 )
  end

  -- ukdash ground-slam shockwave reach (ultrakill_shockwave_radius, def. 200)
  local function UKS_SLAM_RADIUS_SQR()
    local cv = GetConVar( "ultrakill_shockwave_radius" )
    local r = cv and cv:GetFloat() or 200
    return r * r
  end

  ------------------------------------------------------------------------------
  -- Action machinery (Ferryman pattern)
  ------------------------------------------------------------------------------

  function ENT:UKS_InAction()
    return self.UKS_Mode ~= "idle"
  end

  function ENT:UKS_SetMode( mode )
    local cfg = ACTION[ mode == "windup" and "AimStart"
      or mode == "aim" and "Aiming"
      or mode == "shoot" and "Shoot"
      or mode == "cancel" and "CancelAim"
      or mode == "interrupt" and "InterruptAim"
      or mode == "kick" and "Kick" or "" ]
    self.UKS_Mode = mode
    self.UKS_ActionStart = CurTime()
    self.UKS_ActionEvIndex = 1
    if cfg then
      self.UKS_ActionCfg = cfg
      self.UKS_ActionRate = cfg.rate * self:UKS_AnimSpeed()
      -- lock loco yaw: aim tracking owns the rotation during actions
      self:SetMaxYawRate( 0 )
    else
      self.UKS_ActionCfg = nil
      self.UKS_ActionRate = 1
      self:SetMaxYawRate( self.MaxYawRate )
    end
  end

  function ENT:UKS_ActionClipTime()
    return ( CurTime() - self.UKS_ActionStart ) * self.UKS_ActionRate
  end

  function ENT:UKS_ProcessEvents()
    local cfg = self.UKS_ActionCfg
    if not cfg then return end
    local t = self:UKS_ActionClipTime()
    while self.UKS_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKS_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKS_ActionEvIndex = self.UKS_ActionEvIndex + 1
      self:UKS_FireEvent( ev[ 2 ], ev[ 3 ] )
      -- an event may end/switch the action (stopAction resets UKS_ActionEvIndex
      -- to 1) — continuing the loop with the stale cfg/t replays the clip's
      -- events forever and hard-freezes the game. Bail out on any mode change.
      if self.UKS_ActionCfg ~= cfg then return end
    end
    -- windup clip finished -> hold the Aiming loop
    if self.UKS_Mode == "windup" and t >= cfg.dur then
      self:UKS_SetMode( "aim" )
    end
  end

  function ENT:UKS_FireEvent( kind, arg )
    if kind == "lodge" then
      if arg == 0 then self.UKS_LeftLodged = true else self.UKS_RightLodged = true end
      -- boulder impact per lodging foot (two plays per burrow — spec)
      self:EmitSound( UKSentry.SOUND.Lodge, 80, math.random( 95, 105 ), 0.9 )
    elseif kind == "unlodge" then
      self:UKS_UnlodgeFoot( arg )
    elseif kind == "extend" then
      self:EmitSound( UKSentry.SOUND.Extend, 80, 100, 0.5 )
    elseif kind == "thunk" then
      self:EmitSound( UKSentry.SOUND.Thunk, 80, 100, 0.5 )
    elseif kind == "footstep" then
      self:UKS_Footstep()
    elseif kind == "startAiming" then
      self:UKS_StartAiming()
    elseif kind == "dmgOn" then
      self.UKS_KickDamaging = true
      self.UKS_KickHits = {}
      self:EmitSound( UKSentry.SOUND.Kick, 90, 100, 1.0 )
    elseif kind == "dmgOff" then
      self.UKS_KickDamaging = false
    elseif kind == "stopAction" then
      self:UKS_StopAction()
    end
  end

  function ENT:UKS_StopAction()
    self:UKS_SetMode( "idle" )
    self:UKS_SetGlow( 0 )
  end

  function ENT:UKS_Lodged()
    return self.UKS_LeftLodged and self.UKS_RightLodged
  end

  function ENT:UKS_UnlodgeFoot( which )
    local was = ( which == 0 and self.UKS_LeftLodged ) or ( which == 1 and self.UKS_RightLodged )
    if which == 0 then self.UKS_LeftLodged = false else self.UKS_RightLodged = false end
    if was then
      self:EmitSound( UKSentry.SOUND.Rubble, 70, 100, 0.4 )
    end
  end

  -- canon Unlodge(): both feet + kickCooldown 0.25
  function ENT:UKS_Unlodge()
    self:UKS_UnlodgeFoot( 0 )
    self:UKS_UnlodgeFoot( 1 )
    self.UKS_KickCooldown = 0.25
  end

  function ENT:UKS_SetGlow( idx )
    self:SetNW2Int( NW_GLOW, idx )
  end

  ------------------------------------------------------------------------------
  -- Windup / aiming (canon StartWindup + StartAiming + Aiming)
  ------------------------------------------------------------------------------

  function ENT:UKS_StartWindup( enemy )
    self:UKS_SetMode( "windup" )
    -- the possession bind may start with no lock-on: face the crosshair
    if IsValid( enemy ) then
      self:UKS_FaceInstant( enemy:GetPos() )
    elseif self:IsPossessed() then
      self:UKS_FaceInstant( self:UKS_PossAimPos() )
    end
    self.UKS_KickCooldown = 0
    self.UKS_Aiming = false
    self.UKS_AimTime = 0
    self.UKS_FlashTime = 0
    self.UKS_OutOfSight = 0
    self:UKS_SetGlow( 1 )
    -- canon: aimWarningSound (TurretReady @1.5x) once at windup start
    self:EmitSound( UKSentry.SOUND.Warning, 85, 100, 0.5 )
  end

  -- canon StartAiming animator event (AimStart @1.106s)
  function ENT:UKS_StartAiming()
    self.UKS_Aiming = true
    self.UKS_WhiteLine = false
    self.UKS_FlashTime = 0
    self.UKS_ShotsInRow = 0
    self.UKS_NextBeep = self.UKS_AimTime + ( self.UKS_MaxAimTime - self.UKS_AimTime ) / 6
    self.UKS_LastBeep = 0
    self:SetInterruptable( true ) -- canon eid.weakPoint = antenna
    self:SetNW2Bool( NW_LASER_ON, true )
    self:SetNW2Int( NW_LASER_COL, 0 )
    self:UKS_Beep()
  end

  function ENT:UKS_Beep()
    local pos = self:UKS_AntennaPos()
    sound.Play( UKSentry.SOUND.Beep, pos, 70, 100, 0.45 )
    self:SetNW2Int( NW_BEEP, self:GetNW2Int( NW_BEEP, 0 ) + 1 )
  end

  function ENT:UKS_TickAiming( enemy, dt )
    local maxAim = self.UKS_MaxAimTime
    local now = CurTime()
    -- possessed: the crosshair point replaces the enemy every tick (enemy
    -- may be NULL for the whole cycle)
    local possAim = self:IsPossessed() and self:UKS_PossAimPos() or nil

    -- canon AimAt: torso tracks every frame; we rotate the body yaw.
    -- During the pre-shot flash the whole bot FREEZES (spec: "стоп").
    if self.UKS_FlashTime <= 0 then
      local dir = ( possAim or enemy:GetPos() ) - self:GetPos(); dir.z = 0
      if dir:LengthSqr() > 1 then
        local want = dir:Angle().yaw
        local cur = self:GetAngles().yaw
        self:SetAngles( Angle( 0, math.ApproachAngle( cur, want, UKSentry.ANGULAR_SPEED * dt ), 0 ) )
      end
    end

    -- possessed: no out-of-sight auto-cancel (IN_RELOAD cancels instead) and
    -- the final flash must not wait for a sightline; the beam trace itself
    -- still clips on walls
    local hasVision = self:IsPossessed() or self:UKS_HasLOS( enemy )
    if hasVision then
      self.UKS_OutOfSight = 0
    elseif self.UKS_FlashTime <= 0 then
      self.UKS_OutOfSight = self.UKS_OutOfSight + dt
    end

    if self.UKS_OutOfSight >= UKSentry.OUT_OF_SIGHT_CANCEL then
      self:EmitSound( UKSentry.SOUND.Cancel, 75, 100, 0.75 )
      self:UKS_CancelAim( false )
      return
    end

    self.UKS_AimTime = math.min( self.UKS_AimTime + dt, maxAim )

    -- laser endpoint: barrel -> target (env-clipped)
    local barrel = self:UKS_BarrelPos()
    local aimDir = ( ( possAim or enemy:WorldSpaceCenter() ) - barrel ):GetNormalized()
    local laserTr = util.TraceLine{
      start = barrel,
      endpos = barrel + aimDir * UKSentry.BEAM_RANGE,
      filter = self,
      mask = MASK_SHOT,
    }
    self:SetNW2Vector( NW_LASER_END, laserTr.HitPos )

    if self.UKS_AimTime >= maxAim and ( hasVision or self.UKS_FlashTime > 0 ) then
      -- WARNING FLASH (spec 2026-07-07): bright yellow flash pops, the
      -- bot freezes for FLASH_HOLD (~0.5 s; canon parry window), then fires
      if self.UKS_FlashTime <= 0 then
        self:UKS_SetGlow( 2 )
        self:SetNW2Int( NW_LASER_COL, 2 )
        self:SetParryable( true )            -- canon mach.ParryableCheck
        self.UKS_DelayedPos = possAim or enemy:WorldSpaceCenter() -- canon delayedLastPlayerPosition
        -- canon parry-window alert: the big yellow star + the base alert
        -- chirp (the "missing" wiki sound = ComputerSFX_alerts-004)
        if self.CreateAlert then
          self:CreateAlert( ( self:UKS_BarrelPos() ), 1, 2.5 )
        end
      end
      self.UKS_FlashTime = math.min( self.UKS_FlashTime + dt / UKSentry.FLASH_HOLD, 1.0 )
      self:SetNW2Float( NW_FLASH_T, self.UKS_FlashTime )
      if self.UKS_FlashTime >= 1.0 then
        self:UKS_Shoot( enemy )
      end
    elseif self.UKS_AimTime >= self.UKS_NextBeep and ( now - self.UKS_LastBeep ) >= 0.075 then
      -- BEEP phase: pink<->white pulse, accelerating chirp
      self.UKS_WhiteLine = not self.UKS_WhiteLine
      self:SetNW2Int( NW_LASER_COL, self.UKS_WhiteLine and 1 or 0 )
      self.UKS_NextBeep = self.UKS_AimTime + ( maxAim - self.UKS_AimTime ) / 6
      self.UKS_LastBeep = now
      self:UKS_Beep()
    end
  end

  ------------------------------------------------------------------------------
  -- Shooting (canon Shoot + RevolverBeam)
  ------------------------------------------------------------------------------

  function ENT:UKS_Shoot( enemy )
    self:UKS_FireBeam( enemy )
    self:EmitSound( UKSentry.SOUND.Shoot, 95, 100, 0.75 )

    -- canon Shoot(): CancelAim() core (no anim), then roll cooldown IN SHOOT
    self.UKS_Aiming = false
    self.UKS_AimTime = 0
    self.UKS_OutOfSight = 0
    self.UKS_FlashTime = 0
    self:SetNW2Bool( NW_LASER_ON, false )
    self:SetNW2Float( NW_FLASH_T, 0 )
    self:SetParryable( false )
    self:SetInterruptable( false )
    self:UKS_SetGlow( 0 )
    self:UKS_ClearReAim()

    self:UKS_SetMode( "shoot" )
    self.UKS_Cooldown = math.Rand( UKSentry.COOLDOWN_MIN, UKSentry.COOLDOWN_MAX )
    self.UKS_ShotsInRow = self.UKS_ShotsInRow + 1

    local diff = self.UKS_Difficulty
    if ( diff == 4 and self.UKS_ShotsInRow < 2 ) or diff == 5 then
      self.UKS_PreReAimAt = CurTime() + UKSentry.PRE_REAIM_DELAY
    end
  end

  function ENT:UKS_FireBeam( enemy )
    -- canon origin: body axis at barrel height; visual start = barrel tip
    local barrel = self:UKS_BarrelPos()
    local myPos = self:GetPos()
    local origin = Vector( myPos.x, myPos.y, barrel.z )

    local dir
    if self:IsPossessed() then
      -- possessed: the beam lands on the live crosshair point (enemy may
      -- be NULL for the whole cycle) — no low-difficulty lag either
      dir = ( self:UKS_PossAimPos() - origin ):GetNormalized()
    elseif self.UKS_Difficulty <= 1 and self.UKS_DelayedPos then
      -- canon: low difficulties fire at the (lagged) stored position
      dir = ( self.UKS_DelayedPos - origin ):GetNormalized()
    else
      dir = ( enemy:WorldSpaceCenter() - origin ):GetNormalized()
    end

    -- pierce up to 3 victims; pass through other Sentries (canon ignoreEnemyType)
    local filter = { self }
    local hitPos = origin + dir * UKSentry.BEAM_RANGE
    local victims = 0
    for _ = 1, 16 do
      local tr = util.TraceLine{
        start = origin, endpos = origin + dir * UKSentry.BEAM_RANGE,
        filter = filter, mask = MASK_SHOT,
      }
      hitPos = tr.HitPos
      if not tr.Hit or tr.HitWorld then break end
      local ent = tr.Entity
      if not IsValid( ent ) then break end
      if ent:GetClass() == self:GetClass() then
        table.insert( filter, ent ) -- beam ignores other Sentries
        continue
      end
      if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
        -- round-3 sweep (2026-07-10): *_NPC constants are target LANDED
        -- values — fed raw they double-dipped the victim's x20 (beam landed
        -- 100k and one-shotted the pack) → pre-divide via UKNpcDmg.PreMult
        local amount = ent:IsPlayer() and UKSentry.BEAM_DAMAGE_PLAYER
          or UKNpcDmg.PreMult( ent, self, UKSentry.BEAM_DAMAGE_NPC )
        local dmg = DamageInfo()
        dmg:SetDamage( ent:IsPlayer() and UKSentry.ScaleAttackDamage( ent, amount ) or amount )
        dmg:SetDamageType( DMG_BULLET )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( tr.HitPos )
        dmg:SetReportedPosition( tr.HitPos )
        dmg:SetDamageForce( dir * 200 )
        ent:TakeDamageInfo( dmg )
        victims = victims + 1
        if victims >= UKSentry.BEAM_PIERCE then break end
        table.insert( filter, ent )
      else
        break
      end
    end

    -- COIN CHARGEBACK: a live ultrakill_coin近 the beam path intercepts the
    -- shot; bullet damage with the coin owner as attacker makes the coin mod
    -- run its own Ricoshot into the nearest valid target (us included).
    local coin = self:UKS_FindBeamCoin( origin, hitPos )
    if IsValid( coin ) then
      hitPos = coin:GetPos()
      local owner = coin:GetOwner()
      if not ( IsValid( owner ) and owner:IsPlayer() ) then
        -- fallback: nearest player threw it
        local best, bd = nil, math.huge
        for _, ply in ipairs( player.GetAll() ) do
          local d = ply:GetPos():DistToSqr( coin:GetPos() )
          if d < bd then best, bd = ply, d end
        end
        owner = best
      end
      local dmg = DamageInfo()
      dmg:SetDamage( UKSentry.BEAM_DAMAGE_NPC )
      dmg:SetDamageType( DMG_BULLET )
      dmg:SetAttacker( IsValid( owner ) and owner or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( coin:GetPos() )
      dmg:SetReportedPosition( coin:GetPos() )
      dmg:SetDamageForce( dir )
      coin:TakeDamageInfo( dmg )
    end

    -- impact FX + client tracer
    local impact = EffectData()
    impact:SetOrigin( hitPos )
    impact:SetNormal( -dir )
    util.Effect( "MetalSpark", impact )
    self:SetNW2Vector( NW_SHOT_END, hitPos )
    self:SetNW2Int( NW_SHOT, self:GetNW2Int( NW_SHOT, 0 ) + 1 )
  end

  function ENT:UKS_FindBeamCoin( from, to )
    local half = 10
    local best, bestDist = nil, math.huge
    for _, ent in ipairs( ents.FindAlongRay( from, to,
        Vector( -half, -half, -half ), Vector( half, half, half ) ) ) do
      if IsValid( ent ) and ent:GetClass() == "ultrakill_coin"
          and not ( ent.GetDead and ent:GetDead() ) then
        local d = from:DistToSqr( ent:GetPos() )
        if d < bestDist then best, bestDist = ent, d end
      end
    end
    return best
  end

  ------------------------------------------------------------------------------
  -- Multi-shot (canon PreReAim/ReAim Invokes — real-time 0.25 + 0.25)
  ------------------------------------------------------------------------------

  function ENT:UKS_ClearReAim()
    self.UKS_PreReAimAt = nil
    self.UKS_ReAimAt = nil
  end

  function ENT:UKS_TickReAim()
    local now = CurTime()
    if self.UKS_PreReAimAt and now >= self.UKS_PreReAimAt then
      self.UKS_PreReAimAt = nil
      -- canon PreReAim: anim.Play("Aiming") interrupts the Shoot clip (feet
      -- stay lodged for the whole chain)
      self:UKS_SetMode( "aim" )
      self:UKS_SetGlow( 1 )
      self.UKS_ReAimAt = now + UKSentry.REAIM_DELAY
    end
    if self.UKS_ReAimAt and now >= self.UKS_ReAimAt then
      self.UKS_ReAimAt = nil
      local enemy = self:GetEnemy()
      if ( IsValid( enemy ) or self:IsPossessed() ) and self.UKS_Mode == "aim" then
        -- canon ReAim: straight back to the flash phase
        self.UKS_Aiming = true
        self.UKS_AimTime = self.UKS_MaxAimTime
        self.UKS_FlashTime = 0
        self:SetInterruptable( true )
        self:SetNW2Bool( NW_LASER_ON, true )
        self:SetNW2Int( NW_LASER_COL, 0 )
      elseif self.UKS_Mode == "aim" then
        self:UKS_CancelAim( true )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Cancel / Interrupt (canon CancelAim + Interrupt)
  ------------------------------------------------------------------------------

  function ENT:UKS_CancelAim( instant )
    self.UKS_Aiming = false
    self.UKS_AimTime = 0
    self.UKS_OutOfSight = 0
    self.UKS_FlashTime = 0
    self:SetNW2Bool( NW_LASER_ON, false )
    self:SetNW2Float( NW_FLASH_T, 0 )
    self:SetParryable( false )
    self:SetInterruptable( false )
    self:UKS_SetGlow( 0 )
    self:UKS_ClearReAim()

    if instant then
      self:UKS_Unlodge()
      self:UKS_SetMode( "idle" )
    else
      self:UKS_SetMode( "cancel" )
    end
    -- canon clamp (no reroll here — the roll lives in Shoot)
    if self.UKS_Cooldown < 1.0 then self.UKS_Cooldown = 1.0 end
  end

  function ENT:UKS_Interrupt()
    if self.UKS_Dead then return end
    self:UKS_CancelAim( false )      -- clears laser/parry/reaim, clamps cooldown
    self:UKS_SetMode( "interrupt" )  -- override the CancelAim anim with InterruptAim
    self.UKS_Cooldown = UKSentry.COOLDOWN_INTERRUPT
    self:EmitSound( UKSentry.SOUND.Interrupt, 85, 100, 0.9 )
  end

  -- canon GotParried() -> Interrupt(); base OnParry handles sound/hitstop/bonus
  function ENT:OnParry( ply, dmginfo )
    BaseClass.OnParry( self, ply, dmginfo )
    self:UKS_Interrupt()
  end

  ------------------------------------------------------------------------------
  -- Kick (canon Kick + SwingCheck2 window from Kick.anim)
  ------------------------------------------------------------------------------

  function ENT:UKS_Kick( enemy )
    self:UKS_SetMode( "kick" )
    -- the possession bind may kick without a lock-on; facing then stays
    -- wherever the possessor last pointed the bot
    if IsValid( enemy ) then self:UKS_FaceInstant( enemy:GetPos() ) end
    self.UKS_KickCooldown = 1.0
    self:UKS_SetGlow( 3 )
    self:EmitSound( UKSentry.SOUND.KickWarning, 85, 100, 0.75 )
    -- canon UnparryableFlash (red = unparryable in the base alert scheme)
    if self.CreateAlert then
      self:CreateAlert( self:WorldSpaceCenter() + self:GetForward() * 40, 2, 3 )
    end
  end

  function ENT:UKS_ApplyKickDamage()
    if not self.UKS_KickDamaging then return end
    local hits = self.UKS_KickHits or {}
    self.UKS_KickHits = hits
    local center = self:GetPos() + self:GetForward() * UKSentry.KICK_HIT_FORWARD
      + Vector( 0, 0, 40 )
    for _, ent in ipairs( ents.FindInSphere( center, UKSentry.KICK_HIT_RADIUS ) ) do
      if not IsValid( ent ) or ent == self or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      hits[ ent ] = true
      -- round-3 sweep: KICK_DAMAGE_NPC is the target LANDED value — pre-divide
      local amount = ent:IsPlayer() and UKSentry.KICK_DAMAGE_PLAYER
        or UKNpcDmg.PreMult( ent, self, UKSentry.KICK_DAMAGE_NPC )
      local dmg = DamageInfo()
      dmg:SetDamage( ent:IsPlayer() and UKSentry.ScaleAttackDamage( ent, amount ) or amount )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      ent:TakeDamageInfo( dmg )
      -- canon knockBackForce 25 m/s
      local push = ( ent:WorldSpaceCenter() - self:GetPos() ):GetNormalized()
      push.z = 0.3
      if ent:IsPlayer() then
        ent:SetVelocity( push * UKSentry.KICK_KNOCKBACK )
      elseif ent.loco then
        ent.loco:SetVelocity( ent.loco:GetVelocity() + push * UKSentry.KICK_KNOCKBACK )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Damage in (weakpoint / interrupt / parry / lodged heavy sources)
  ------------------------------------------------------------------------------

  -- "precise Revolver shot" gate. The dredux revolvers are classed
  -- weapon_dredux_uk_piercer/marksman/sharpshooter — NO "revolver" substring
  -- (round-6 find: this gate silently killed every antenna interrupt), so a
  -- player hitscan bullet that is not buckshot counts as a revolver-grade
  -- shot; coins keep their explicit match.
  local function IsRevolverOrCoinSource( dmginfo )
    local inflictor = dmginfo:GetInflictor()
    if IsValid( inflictor ) and inflictor:GetClass():lower():find( "coin", 1, true ) then
      return true
    end
    local attacker = dmginfo:GetAttacker()
    if not IsValid( attacker ) or not attacker:IsPlayer() then return false end
    return dmginfo:IsBulletDamage() and not dmginfo:IsDamageType( DMG_BUCKSHOT )
  end

  -- ukcoin deals its damage with attacker == inflictor == player (never the
  -- coin entity!), so a feedbacker-punched homing coin is indistinguishable
  -- from a plain bullet by DamageInfo alone. The coin ALWAYS aims at our
  -- antenna attachment on interruptable NPCs — recognizing the ultrakill_coin
  -- callstack is enough to count it as an antenna hit.
  local function DamageStackHasCoin()
    if not debug or not debug.getinfo then return false end
    for level = 2, 12 do
      local info = debug.getinfo( level, "S" )
      if not info then return false end
      if string.find( string.lower( info.short_src or "" ), "ultrakill_coin", 1, true ) then
        return true
      end
    end
    return false
  end

  -- Temy ULTRAKILL Arms Knuckleblaster punch builds DamageInfo with
  -- attacker == inflictor == player and DMG_GENERIC/DMG_CLUB — the only
  -- reliable separator is the vmanipfeedbacker Lua callstack (gutterman recipe)
  local function DamageStackHasKnuckleblasterArm()
    if not debug or not debug.getinfo or not debug.getlocal then return false end
    for level = 2, 10 do
      local info = debug.getinfo( level, "S" )
      local src = info and string.lower( info.short_src or "" ) or ""
      if string.find( src, "vmanipfeedbacker", 1, true ) then
        for idx = 1, 32 do
          local name, value = debug.getlocal( level, idx )
          if not name then break end
          if name == "arm" and string.upper( tostring( value ) ) == "KNUCKLEBLASTER" then
            return true
          end
        end
      end
    end
    return false
  end

  -- canon interrupt list (wiki): Knuckleblaster punch, Electric/Malicious
  -- Railcannon (NOT Screwdriver), SRS cannonball, Impact Hammer blast, any
  -- enemy shockwave (ultrakillbase_shockwave deals real damage).
  -- In-game classes (2026-07-07): dredux hammer = weapon_dredux_uk_impact_*
  -- (no "hammer" in the class!), the Knuckleblaster arm is NOT the active
  -- weapon — both need the gutterman-style DamageInfo shape checks.
  local HEAVY_HITTERS = { "hammer", "cannonball", "knuckle", "shockwave" }
  local function IsHeavySource( dmginfo )
    local function match( ent )
      if not IsValid( ent ) then return false end
      local cls = ent:GetClass():lower()
      for _, key in ipairs( HEAVY_HITTERS ) do
        if cls:find( key, 1, true ) then return true end
      end
      if cls:find( "railcannon", 1, true ) and not cls:find( "screw", 1, true ) then
        return true
      end
      return false
    end
    if match( dmginfo:GetInflictor() ) then return true end

    local attacker = dmginfo:GetAttacker()
    if not IsValid( attacker ) or not attacker:IsPlayer() then return false end

    -- Knuckleblaster shockwave marker (Temy arms)
    if dmginfo:IsDamageType( DMG_ALWAYSGIB ) then return true end

    local wep = attacker:GetActiveWeapon()
    local cls = IsValid( wep ) and wep:GetClass():lower() or ""
    if IsValid( wep ) and match( wep ) then return true end

    -- dredux Impact Hammer: active weapon "impact_*", DMG_CLUB, inflictor
    -- is the SWEP or the player itself
    local inflictor = dmginfo:GetInflictor()
    if cls:find( "impact", 1, true ) and dmginfo:IsDamageType( DMG_CLUB )
        and ( not IsValid( inflictor ) or inflictor == attacker or inflictor == wep ) then
      return true
    end

    -- Knuckleblaster basic punch: attacker == inflictor == player,
    -- DMG_GENERIC/DMG_CLUB, vmanipfeedbacker on the callstack
    if ( not IsValid( inflictor ) or inflictor == attacker )
        and ( dmginfo:GetDamageType() == DMG_GENERIC or dmginfo:IsDamageType( DMG_CLUB ) )
        and DamageStackHasKnuckleblasterArm() then
      return true
    end

    return false
  end

  local HITGROUP_ANTENNA = 9 -- compiled $hbox group of the Antena_* bones

  -- did this damage land on the antenna? hitgroup from the compiled $hbox
  -- set is authoritative; fallback = distance to the FULL antenna axis
  -- (segment head->tip, lower 35% excluded so the head stays the head)
  function ENT:UKS_HitAntenna( dmg, hitgroup )
    if hitgroup == HITGROUP_ANTENNA then return true end
    local pos = dmg:GetDamagePosition()
    if not pos or pos:IsZero() then return false end
    local base = ( self:UKS_AttPos( "head", self:WorldSpaceCenter() + Vector( 0, 0, 40 ) ) )
    local tip = ( self:UKS_AttPos( "antenna_tip", self:GetPos() + Vector( 0, 0, 160 ) ) )
    local seg = tip - base
    local lenSqr = seg:LengthSqr()
    if lenSqr < 1 then return false end
    local t = math.Clamp( ( pos - base ):Dot( seg ) / lenSqr, 0.35, 1 )
    local r = 30 * self:GetModelScale()
    return pos:DistToSqr( base + seg * t ) <= r * r
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKS_Dead then return end

    -- weakpoint x2: head normally, antenna while aiming (canon eid.weakPoint);
    -- hitgroup from the compiled $hbox set, attachment distance as fallback
    if dmg:IsDamageType( DMG_BULLET ) then
      local wpHit
      if self.UKS_Aiming then
        wpHit = ( hitgroup == HITGROUP_ANTENNA )
          or dmg:GetDamagePosition():DistToSqr( self:UKS_AntennaPos() )
            <= ( 30 * self:GetModelScale() ) ^ 2
      else
        wpHit = ( hitgroup == HITGROUP_HEAD )
          or dmg:GetDamagePosition():DistToSqr(
            self:UKS_AttPos( "head", self:WorldSpaceCenter() + Vector( 0, 0, 40 ) ) )
            <= ( 30 * self:GetModelScale() ) ^ 2
      end
      if wpHit then dmg:ScaleDamage( 2 ) end
    end

    -- parry (melee / point-blank shotgun in the orange window) runs inside
    -- BaseClass.OnTakeDamage AFTER DamageMultiplier — an earlier CheckParry
    -- would put the flat +5000 bonus under the x10 multiplier. A parry that
    -- also matches the heavy branch below just re-enters the idempotent
    -- UKS_Interrupt from OnParry.

    -- canon interrupt (wiki list): a heavy source during the windup/aim
    -- breaks the attack outright with the InterruptAim stagger; outside the
    -- aim it still knocks the lodged feet loose
    if IsHeavySource( dmg ) then
      if self.UKS_Aiming or self.UKS_Mode == "windup" then
        self:UKS_Interrupt()
      elseif self:UKS_Lodged() then
        self:UKS_CancelAim( true )
      end
    end

    -- canon OnDamage: precise revolver/coin hit on the antenna while aiming
    -- -> Interrupt. Own gate (base CheckInterrupt's single 30-su point was
    -- too strict in-game); FX below = the base CheckInterrupt recipe.
    -- NO explosion here (round 7): the base CheckInterrupt recipe spawned a
    -- real 500-damage blast on the Sentry — with weapon damage on top it
    -- read as "detonates and dies". Canon interrupt = ricochet ding + white
    -- flash + hitstop + the InterruptAim stagger, nothing more.
    if self.UKS_Aiming and self:GetInterruptable() and IsRevolverOrCoinSource( dmg )
        and dmg:IsBulletDamage() and not dmg:IsDamageType( DMG_BUCKSHOT )
        and ( self:UKS_HitAntenna( dmg, hitgroup ) or DamageStackHasCoin() ) then
      local ply = dmg:GetAttacker()
      if UltrakillBase.SoundScript then
        UltrakillBase.SoundScript( "Ultrakill_Ricochet", self:GetPos() )
      end
      if UltrakillBase.HitStop then UltrakillBase.HitStop( 0.25 ) end
      if IsValid( ply ) and ply:IsPlayer() then
        ply:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 40 ), 0.1, 0.25 )
      end
      self:SetInterruptable( false )
      self:UKS_Interrupt()
    end

    local now = CurTime()
    if ( self.UKS_NextHurtSound or 0 ) <= now and dmg:GetDamage() > 0 then
      self.UKS_NextHurtSound = now + 0.35
      self:EmitSound( UKSentry.SOUND.Hurt, 75, math.random( 95, 105 ), 0.8 )
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Animation / speed hooks
  ------------------------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    local spd = self:UKS_AnimSpeed()
    local cfg = self.UKS_ActionCfg
    if self.UKS_Mode ~= "idle" and cfg then
      return cfg.seq, cfg.rate * spd
    end
    if not self:IsOnGround() then return "Falling", spd end
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco and self.loco:GetVelocity():Length() > 1 * UNIT
    if moving then return "Running", 1.75 * spd end
    return "Idle", 1.5 * spd
  end

  function ENT:OnUpdateSpeed()
    if self:UKS_InAction() or self.UKS_Stationary then return 0 end
    -- decision 2026-07-07 (round 5): the Sentry ALWAYS walks between
    -- attacks — the canon stand-when-seen gate is dropped. UKS_WanderUntil
    -- still blocks the first windup so it strolls a bit before burrowing.
    return UKSentry.MOVE_SPEED * self:UKS_AnimSpeed()
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are driven by CustomThink
    return
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKS_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = now - ( self.UKS_LastThink or now )
    self.UKS_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    self:UKS_TickReAim()
    self:UKS_ProcessEvents()

    local enemy = self:GetEnemy()
    local mode = self.UKS_Mode

    if mode == "aim" or mode == "windup" then
      -- possessed: the cycle runs on the crosshair — a NULL enemy must
      -- not break it (players don't use lock-on)
      if not IsValid( enemy ) and not self:IsPossessed() then
        self:UKS_CancelAim( true )
        return
      end
      if self.UKS_Aiming then
        -- runs during late windup too: StartAiming fires at 1.106 while the
        -- AimStart clip lasts 1.333 — the laser must live from the event on
        self:UKS_TickAiming( enemy, dt )
      else
        -- pre-StartAiming (or PreReAim gap): keep tracking the target yaw
        local aimAt = self:IsPossessed() and self:UKS_PossAimPos() or enemy:GetPos()
        local dir = aimAt - self:GetPos(); dir.z = 0
        if dir:LengthSqr() > 1 then
          local want = dir:Angle().yaw
          self:SetAngles( Angle( 0,
            math.ApproachAngle( self:GetAngles().yaw, want, UKSentry.ANGULAR_SPEED * dt ), 0 ) )
        end
      end
    elseif mode == "kick" then
      self:UKS_ApplyKickDamage()
    end

    -- canon: a player ground-slam shockwave interrupts the aim. The ukdash
    -- slam deals no damage — watch the NW2 flag drop (impact frame) nearby.
    do
      local slams = self.UKS_SlamState
      if not slams then slams = {}; self.UKS_SlamState = slams end
      for _, ply in ipairs( player.GetAll() ) do
        local active = ply:GetNW2Bool( "ULTRAKILL_GroundSlamActive", false )
        local id = ply:EntIndex()
        if slams[ id ] and not active
            and ( self.UKS_Aiming or self.UKS_Mode == "windup" )
            and ply:GetPos():DistToSqr( self:GetPos() ) <= UKS_SLAM_RADIUS_SQR() then
          self:UKS_Interrupt()
        end
        slams[ id ] = active
      end
    end

    -- vision cache (throttled): drives both the windup decision and
    -- OnUpdateSpeed's stand-still-when-seen gate
    if ( self.UKS_NextVisionCheck or 0 ) <= now then
      self.UKS_NextVisionCheck = now + 0.15
      self.UKS_HasVision = IsValid( enemy ) and self:UKS_HasLOS( enemy ) or false
    end

    -- canon Update: cooldowns only tick outside actions while grounded
    if not self:UKS_InAction() and self:IsOnGround() then
      self.UKS_Cooldown = math.max( 0, self.UKS_Cooldown - dt )
      self.UKS_KickCooldown = math.max( 0, self.UKS_KickCooldown - dt )

      -- possessed: attacks start from the possession binds only (cooldowns
      -- above keep ticking — the binds respect them)
      if IsValid( enemy ) and not self:IsPossessed() then
        local dist = self:GetPos():Distance( enemy:GetPos() )
        if dist < UKSentry.KICK_RANGE and self.UKS_KickCooldown <= 0
            and self.UKS_Difficulty >= 2 then
          self:UKS_Kick( enemy )
        -- canon: no distance gate on the windup — clear LOS is the condition
        -- (blocked while the spawn wander is still running)
        elseif self.UKS_Cooldown <= 0 and self.UKS_HasVision
            and now >= ( self.UKS_WanderUntil or 0 )
            and not self:UKS_IsWindUpObstructed( enemy ) then
          self:UKS_StartWindup( enemy )
        end
      end
    end

    self:UKS_UpdateFootsteps()
  end

  -- Running.anim FootStep events at 0.385/1.038 of the 1.267 s clip
  local RUN_STEPS = { 0.30, 0.82 }

  function ENT:UKS_UpdateFootsteps()
    if self:UKS_InAction() then return end
    if not ( self:IsMoving() or self:IsRunning() ) then return end
    local seqName = self:GetSequenceName( self:GetSequence() ) or ""
    if seqName ~= "Running" then return end
    local cycle = self:GetCycle()
    local last = self.UKS_LastRunCycle or 0
    for _, mark in ipairs( RUN_STEPS ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) )
      if crossed then
        self:UKS_Footstep()
        break
      end
    end
    self.UKS_LastRunCycle = cycle
  end

  -- canon IsWindUpObstructed: 1.5 m sphere cast toward the target
  function ENT:UKS_IsWindUpObstructed( enemy )
    local radius = 1.5 * UNIT
    local from = self:UKS_VisionPos()
    local to = enemy:WorldSpaceCenter()
    local dist = math.max( from:Distance( to ) - radius * 1.5 - 30, 0 )
    local tr = util.TraceHull{
      start = from,
      endpos = from + ( to - from ):GetNormalized() * dist,
      mins = Vector( -radius, -radius, -radius ),
      maxs = Vector( radius, radius, radius ),
      filter = { self, enemy },
      mask = MASK_SOLID_BRUSHONLY,
    }
    return tr.Hit
  end

  ------------------------------------------------------------------------------
  -- Death
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKS_Dead = true
    self:UKS_ClearReAim()
    self.UKS_Aiming = false
    self:SetNW2Bool( NW_LASER_ON, false )
    self:SetNW2Float( NW_FLASH_T, 0 )
    self:SetParryable( false )
    self:SetInterruptable( false )
    self:UKS_SetGlow( 4 )
    self:UKS_Unlodge()
    -- world-positioned: the entity is removed right after (ragdoll swap) and
    -- entity-bound EmitSound would get cut off
    local pos = self:WorldSpaceCenter()
    sound.Play( UKSentry.SOUND.Death, pos, 90, 100, 1.0 )
    sound.Play( UKSentry.SOUND.Rubble, pos, 80, 100, 0.5 )
    if BaseClass and BaseClass.OnDeath then BaseClass.OnDeath( self, dmg, hitgroup ) end
    -- returning the dmg keeps the killing blow's force on the ragdoll
    -- (base zeroes it if OnDeath yielded and returned nil — ferryman recipe)
    return dmg
  end

  -- called by the base as .OnRagdoll( ragdoll, dmg, nextbot ) — tag the
  -- corpse so the client matproxy switches the emission to the dead tint
  function ENT.OnRagdoll( ragdoll, dmg, nextbot )
    if IsValid( ragdoll ) then
      ragdoll:SetNW2Bool( "UKSentry_DeadGlow", true )
    end
    -- falsy return keeps the base fade-and-remove behaviour
  end

end -- SERVER

if CLIENT then

  local BEAM_MAT = Material( "models/ultrakill_prelude_test/sentry_beam" )
  local GLOW_MAT = Material( "sprites/light_glow02_add" )

  -- canon ULTRAKILL flash: the yellow pixel star (base ships the texture);
  -- billboard particle with a random roll shrinking to zero — same recipe
  -- as the base ultrakill_alert effect
  local STAR_MAT = "particles/ultrakill/muzzleflash"
  local function SpawnStar( pos, size, dietime, r, g, b )
    -- nudge toward the camera so the star is not buried in the model
    -- (same trick as the base ultrakill_alert effect)
    pos = pos + ( EyePos() - pos ):GetNormalized()
      * math.Clamp( size * 0.15, 6, 24 )
    local emitter = ParticleEmitter( pos )
    if not emitter then return end
    local p = emitter:Add( STAR_MAT, pos )
    if p then
      p:SetDieTime( dietime )
      p:SetStartSize( size )
      p:SetEndSize( 0 )
      p:SetStartAlpha( 255 )
      p:SetEndAlpha( 0 )
      p:SetRoll( math.Rand( 0, 360 ) )
      p:SetColor( r, g, b )
    end
    emitter:Finish()
  end

  local LASER_COL = {
    [0] = UKSentry.LASER_PINK,
    [1] = UKSentry.LASER_WHITE,
    [2] = UKSentry.LASER_ORANGE,
  }

  local GLOW_VEC = {
    [0] = Vector( 0.980, 0.522, 0.733 ),
    [1] = Vector( 0.980, 0.522, 0.733 ),
    [2] = Vector( 1.0, 0.40, 0.0 ),
    [3] = Vector( 0.35, 0.55, 1.0 ),
    [4] = Vector( 0.05, 0.05, 0.05 ),
  }

  local function AttPos( ent, name, fallback )
    local id = ent:LookupAttachment( name )
    if id and id > 0 then
      local att = ent:GetAttachment( id )
      if att then return att.Pos end
    end
    return fallback
  end

  hook.Add( "PostDrawTranslucentRenderables", "UKSentry_DrawFX", function( bDepth, bSkybox )
    if bDepth or bSkybox then return end
    local now = RealTime()
    for _, ent in ipairs( ents.FindByClass( "ultrakill_test_sentry" ) ) do
      if not IsValid( ent ) or ent:IsDormant() then continue end
      local barrel = AttPos( ent, "barrel_tip", ent:WorldSpaceCenter() + ent:GetUp() * 40 )

      -- aim laser: THIN but high-contrast (spec 2026-07-07) — the
      -- colored line drawn twice (additive stacking) + a white-hot core
      if ent:GetNW2Bool( "UKSentry_LaserOn", false ) then
        local endpos = ent:GetNW2Vector( "UKSentry_LaserEnd", barrel )
        local col = LASER_COL[ ent:GetNW2Int( "UKSentry_LaserCol", 0 ) ] or UKSentry.LASER_PINK
        render.SetMaterial( BEAM_MAT )
        render.DrawBeam( barrel, endpos, 1.2, 0, 1, col )
        render.DrawBeam( barrel, endpos, 1.2, 0, 1, col )
        render.DrawBeam( barrel, endpos, 0.4, 0, 1, Color( 255, 255, 255, 255 ) )
      end

      -- antenna beep sparkle: bright pink canon star popping on EVERY beep
      -- at the very top of the antenna (spec: bigger, brighter, blinks)
      local beep = ent:GetNW2Int( "UKSentry_Beep", 0 )
      if beep ~= ent.UKS_LastBeepSeen then
        ent.UKS_LastBeepSeen = beep
        local ant = AttPos( ent, "antenna_tip",
          AttPos( ent, "antenna", ent:WorldSpaceCenter() + Vector( 0, 0, 60 ) ) )
        SpawnStar( ant, 32, 0.14, 255, 140, 200 )
      end

      -- shot: canon GunFlashDistant — a HUGE yellow star dwarfing the bot
      -- (ULTRAKILL reference screenshot 2026-07-07) + FAT beam. Two layers:
      -- giant translucent wings + a brighter core.
      local shot = ent:GetNW2Int( "UKSentry_Shot", 0 )
      if shot ~= ent.UKS_LastShotSeen then
        ent.UKS_LastShotSeen = shot
        ent.UKS_ShotFadeUntil = now + 0.22
        ent.UKS_ShotEndPos = ent:GetNW2Vector( "UKSentry_ShotEnd", barrel )
        SpawnStar( barrel, 480, 0.35, 255, 255, 255 )
        SpawnStar( barrel, 190, 0.3, 255, 255, 255 )
      end
      local fadeUntil = ent.UKS_ShotFadeUntil or 0
      if fadeUntil > now and ent.UKS_ShotEndPos then
        local a = ( fadeUntil - now ) / 0.22
        render.SetMaterial( BEAM_MAT )
        render.DrawBeam( barrel, ent.UKS_ShotEndPos, 11 * a,
          0, 1, Color( 255, 255, 255, 255 * a ) )
        render.DrawBeam( barrel, ent.UKS_ShotEndPos, 26 * a,
          0, 1, Color( 255, 112, 188, 170 * a ) )
      end

      -- Round 3 (2026-07-10): the eye glow is now BAKED into sentry_diffuse
      -- (canon composite: albedo + GlowMask x #FA85BB x 1.25 — Source
      -- $selfillum only unshadows the albedo and the canon albedo eye is
      -- dark, which is why the lens looked empty). The sprite hack is gone;
      -- state colors (orange windup / blue kick) stay on the dynamic light.
    end
  end )

  -- emissive glow dynamic light (canon light intensity pulse 1.25<->1.5).
  -- NOTE: DynamicLight struct fields are lowercase — the original capitalized
  -- Pos/Brightness/Size/Decay/DieTime were silently ignored, which is exactly
  -- why "the pink eye glow is straight up not there" (workshop report
  -- 2026-07-10).
  hook.Add( "Think", "UKSentry_DynLight", function()
    for _, ent in ipairs( ents.FindByClass( "ultrakill_test_sentry" ) ) do
      if not IsValid( ent ) or ent:IsDormant() then continue end
      local idx = ent:GetNW2Int( "UKSentry_Glow", 0 )
      if idx == 4 then continue end
      local v = GLOW_VEC[ idx ] or GLOW_VEC[ 0 ]
      local pos = AttPos( ent, "head", ent:WorldSpaceCenter() + Vector( 0, 0, 40 ) )
      local pulse = 1.375 + 0.125 * math.sin( CurTime() * 1.5 )
      local dl = DynamicLight( ent:EntIndex() )
      if dl then
        dl.pos = pos
        dl.r = math.floor( v.x * 255 )
        dl.g = math.floor( v.y * 255 )
        dl.b = math.floor( v.z * 255 )
        dl.brightness = pulse * ( ( idx == 2 ) and 1.4 or 1.0 )
        dl.size = ( idx == 2 ) and 280 or 200
        dl.decay = 1000
        dl.dietime = CurTime() + 0.1
      end
    end
  end )

end -- CLIENT

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_sentry", {
  Name = "Sentry",
  Class = "ultrakill_test_sentry",
  Category = "ULTRAKILL - Enemies",
  Material = "entities/ultrakill_test_sentry.png",
} )
