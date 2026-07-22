AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_ferryman_shared.lua" )

-- Ferryman (Supreme Husk, 5-2 boss / P-2 regular). Full canon port of
-- Ferryman.cs: 8 melee attacks with exact clip-event timings, dodge roll,
-- tracking lightning cast with follow windup, parry -> self-lightning.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Ferryman"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKFerryman.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKFerryman.HP_REGULAR
-- canon capsule r=1.25 m h=5 m; NavAgent radius 1 m -> 40 su half-extents
ENT.CollisionBounds = Vector( 24, 24, 121 ) -- 2026-07-10 r3: ещё +10%
ENT.SurroundingBounds = Vector( 206, 206, 278 )
ENT.RagdollOnDeath = true -- model compiled with jointed $collisionjoints phys
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Heavy"

ENT.UKFerryman_IsFerryman = true -- canon Explosion.toIgnore = EnemyType.Ferryman

local UNIT = UKFerryman.UNIT

ENT.MeleeAttackRange = 8 * UNIT
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 4 * UNIT
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 25 * UNIT -- canon acceleration 1000 is effectively instant
ENT.Deceleration = 25 * UNIT
ENT.WalkSpeed = UKFerryman.MOVE_SPEED
ENT.RunSpeed = UKFerryman.MOVE_SPEED
-- canon nav angular speed is effectively instant, but a one-tick 180 flip
-- reads as jerky in GMod; 600 deg/s = full turn in ~0.3 s, swept smoothly
ENT.MaxYawRate = 600
ENT.JumpHeight = 120
ENT.StepHeight = 36
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Run"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Run"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Falling"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Falling"
ENT.FallingAnimRate = 1

--------------------------------------------------------------------------------
-- Canon clip events (seconds at animation speed 1.0, 30 fps bake).
-- At runtime every timing is divided by the difficulty animation speed.
-- ev kinds: parry/unparry flash, trackOn/trackOff, dmgOn/dmgOff, moveOn(speed
-- in canon units, velocity = speed*10 m/s)/moveOff, upOn/upOff (uppercut),
-- slam (ground explosion at the oar), windup/windupOver (lightning).
--------------------------------------------------------------------------------

local ACTION = {
  Downslam = {
    seq = "Downslam", dur = 1.740, track = true, checks = "oar",
    ev = {
      { 1.040, "parry" }, { 1.077, "trackOff" },
      { 1.320, "dmgOn" }, { 1.401, "slam" }, { 1.428, "dmgOff" },
    },
  },
  BackstepAttack = {
    seq = "BackstepAttack", dur = 2.282, track = false, checks = "oar",
    knockback = true, moveAtStart = -3.5,
    ev = {
      { 0.511, "moveOff" }, { 0.770, "trackOn" },
      { 1.115, "parry" }, { 1.127, "trackOff" },
      { 1.272, "moveOn", 14 }, { 1.313, "dmgOn" },
      { 1.492, "dmgOff" }, { 1.518, "moveOff" },
    },
  },
  Stinger = {
    seq = "Stinger", dur = 1.221, track = true, checks = "oar",
    ev = {
      { 0.131, "trackOff" }, { 0.223, "parry" },
      { 0.410, "dmgOn" }, { 0.413, "moveOn", 12 },
      { 0.652, "moveOff" }, { 0.653, "dmgOff" },
    },
  },
  Vault = {
    seq = "Vault", dur = 1.039, track = true, checks = "kick",
    moveAtStart = 0.5,
    ev = {
      { 0.478, "moveOn", 8 }, { 0.563, "dmgOn" },
      { 0.615, "trackOff" }, { 0.881, "dmgOff" },
    },
  },
  VaultSwing = {
    seq = "VaultSwing", dur = 1.287, track = true, checks = "oar",
    moveAtStart = 0.5,
    ev = {
      { 0.439, "moveOn", 8 }, { 0.560, "trackOff" }, { 0.621, "unparry" },
      { 0.706, "dmgOn" }, { 0.819, "dmgOff" },
      { 0.943, "moveOn", 1 }, { 1.037, "moveOff" }, { 1.164, "trackOn" },
    },
  },
  KickCombo = {
    -- canon UpdateUses(main=true, oar=false, kick=true): main check stays live
    seq = "KickCombo", dur = 2.350, track = true, checks = "mainkick",
    ev = {
      { 0.218, "trackOff" }, { 0.243, "unparry" },
      { 0.473, "moveOn", 6 }, { 0.486, "dmgOn" },
      { 0.600, "dmgOff" }, { 0.650, "moveOff" },
      { 0.835, "moveOn", 0.5 }, { 0.853, "trackOn" },
      { 1.152, "parry" }, { 1.153, "trackOff" },
      { 1.262, "moveOn", 8.5 }, { 1.339, "dmgOn" },
      { 1.463, "dmgOff" }, { 1.515, "moveOff" },
    },
  },
  OarCombo = {
    seq = "OarCombo", dur = 2.376, track = true, checks = "oar",
    ev = {
      { 0.416, "trackOff" }, { 0.417, "unparry" },
      { 0.590, "dmgOn" }, { 0.626, "moveOn", 15 },
      { 0.727, "moveOff" }, { 0.763, "dmgOff" },
      { 1.074, "trackOn" }, { 1.436, "trackOff" }, { 1.439, "parry" },
      { 1.559, "moveOn", 20 }, { 1.599, "dmgOn" },
      { 1.705, "moveOff" }, { 1.734, "dmgOff" },
    },
  },
  Uppercut = {
    seq = "Uppercut", dur = 0.870, track = true, checks = "oar",
    ev = {
      { 0.280, "unparry" }, { 0.466, "trackOff" },
      { 0.500, "upOn" }, { 0.656, "upOff" },
    },
  },
  Roll = {
    seq = "Roll", dur = 0.486, track = false, checks = nil,
    moveAtStart = 5,
    ev = {},
  },
  LightningBolt = {
    seq = "LightningBolt", dur = 2.974, track = true, checks = nil,
    ev = {
      { 0.516, "windup" }, { 2.524, "windupOver" },
    },
  },
  QuickLightningBolt = {
    seq = "QuickLightningBolt", dur = 1.105, track = true, checks = nil,
    ev = {
      { 0.446, "windupQuick" },
    },
  },
  Knockdown = {
    seq = "Knockdown", dur = 3.348, track = false, checks = nil,
    ev = {},
  },
}

-- canon SetSpeed: anim.speed per difficulty (0 HARMLESS .. 3+ VIOLENT/BRUTAL)
local ANIMSPEED_BY_DIFF = { [0] = 0.6, [1] = 0.8, [2] = 0.9 }

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_1DIR

ENT.PossessionViews = {

  {
    offset = Vector( 0, 15, 55 ),
    distance = 165,
    eyepos = false,
  },

  {
    -- no EyeBone on this model: EyePos falls back to the hull center, so the
    -- offset lifts the camera up to head height (~103 su)
    offset = Vector( 10, 0, 42 ),
    distance = 0,
    eyepos = true,
  },

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKF_Dead or self:UKF_InAction() then return end

    if self:IsOnGround() then

      if Possessor:KeyDown( IN_FORWARD ) then
        self:UKF_StartAction( "Stinger" )
      elseif Possessor:KeyDown( IN_BACK ) then
        self:UKF_StartAction( "BackstepAttack" )
      else
        self:UKF_StartAction( "OarCombo" )
      end

    else
      self:UKF_StartAction( "Downslam" )
    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKF_Dead or self:UKF_InAction() or not self:IsOnGround() then return end

    if Possessor:KeyDown( IN_FORWARD ) then
      if self.UKF_VaultCooldown > 0 then return end
      self.UKF_VaultCooldown = 2 -- same cooldown the AI vault branch sets
      self:UKF_StartAction( self:UKF_GetDifficulty() >= 3 and "VaultSwing" or "Vault" )
    elseif Possessor:KeyDown( IN_BACK ) then
      self:UKF_StartAction( "Uppercut" )
    else
      self:UKF_StartAction( "KickCombo" )
    end

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- UKF_CanLightning while possessed = cooldown gates only (own + global
    -- Ferryman cooldown); the canon below-STANDARD refusal stays AI-only
    if self.UKF_Dead or self:UKF_InAction() or not self:UKF_CanLightning() then return end

    self:UKF_CastLightning( true )

  end }, { coroutine = false, onkeypressed = function( self, Possessor )

    -- the lightning cooldowns are invisible to the possessor — without a deny
    -- cue a refused cast reads as a dead bind (onkeypressed = once per press,
    -- so holding the key cannot spam this)
    if self.UKF_Dead or self:UKF_InAction() or self:UKF_CanLightning() then return end

    self:EmitSound( "player/suit_denydevice.wav", 60, 100, 0.4 )

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKF_Dead or self:UKF_InAction() or not self:IsOnGround() then return end
    if self.UKF_RollCooldown > 0 then return end

    self:UKF_Roll( false )

  end } },

}

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKFerryman.HP_REGULAR
    -- never SetModel here (DrGBase already applied ENT.Models); re-assert hull
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKF_Dead = false
    self.UKF_ActionName = nil
    self.UKF_ActionStart = 0
    self.UKF_ActionUntil = nil
    self.UKF_ActionEvIndex = 1
    self.UKF_Tracking = false
    self.UKF_Moving = false
    self.UKF_MovingSpeed = 0
    self.UKF_Uppercutting = false
    self.UKF_Knockback = false
    self.UKF_ActionHits = nil
    self.UKF_Checks = nil

    -- canon adaptive chances (alternate 0.25 <-> 0.75)
    self.UKF_OverheadChance = 0.5
    self.UKF_StingerChance = 0.5
    self.UKF_KickComboChance = 0.5

    self.UKF_RollCooldown = 0
    self.UKF_VaultCooldown = 0
    self.UKF_LightningCooldown = 1.5 -- canon initial value
    self.UKF_OutOfReachCharge = 0
    self.UKF_LightningCancellable = false
    self.UKF_SlowTick = 0
    self.UKF_UnreachSince = nil
    self:SetParryable( false )

    -- player status
    self.UKF_PlayerApproaching = false
    self.UKF_PlayerRetreating = false
    self.UKF_PlayerAbove = false

    self:SetSkin( 0 )
    local oarBg = self:FindBodygroupByName( "oar" )
    if oarBg and oarBg >= 0 then self:SetBodygroup( oarBg, 0 ) end

    self:EmitSound( UKFerryman.SOUND.Spawn, 95, 100, 1 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKF_RemoveWindup()
  end

  ------------------------------------------------------------------------------
  -- Difficulty (canon SetSpeed profiles)
  ------------------------------------------------------------------------------

  function ENT:UKF_GetDifficulty()
    return self.UltrakillBase_Difficulty or 3
  end

  function ENT:UKF_AnimSpeed()
    return ANIMSPEED_BY_DIFF[ self:UKF_GetDifficulty() ] or 1.0
  end

  ------------------------------------------------------------------------------
  -- Player status / prediction (canon PlayerStatus, PredictPlayerPos)
  ------------------------------------------------------------------------------

  function ENT:UKF_UpdatePlayerStatus( enemy )
    local mypos = self:GetPos()
    local tpos = enemy:GetPos()
    local vel = enemy.GetVelocity and enemy:GetVelocity() or vector_origin

    self.UKF_TargetPos = tpos
    self.UKF_TargetVel = vel
    self.UKF_PlayerPos = Vector( tpos.x, tpos.y, mypos.z ) -- ToPlanePos
    self.UKF_PlayerAbove = tpos.z > mypos.z + 3 * UNIT

    local hv = Vector( vel.x, vel.y, 0 )
    if hv:Length() < 1 * UNIT then
      self.UKF_PlayerApproaching = false
      self.UKF_PlayerRetreating = false
    else
      hv:Normalize()
      local toPlayer = self.UKF_PlayerPos - mypos
      toPlayer:Normalize()
      local ang = math.deg( math.acos( math.Clamp( hv:Dot( toPlayer ), -1, 1 ) ) )
      self.UKF_PlayerRetreating = ang < 80
      self.UKF_PlayerApproaching = ang > 135
    end
  end

  -- canon PredictPlayerPos: horizontal, capped at maxPrediction meters;
  -- no prediction below STANDARD difficulty
  function ENT:UKF_PredictPlayerPos( maxPredictionMeters )
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then return self:GetPos() + self:GetForward() end
    if self:UKF_GetDifficulty() <= 1 then return self.UKF_PlayerPos or enemy:GetPos() end

    maxPredictionMeters = maxPredictionMeters or 5
    local vel = self.UKF_TargetVel or vector_origin
    local hv = Vector( vel.x, vel.y, 0 )
    local speedMeters = hv:Length() / UNIT
    if speedMeters > 0.01 then
      hv:Normalize()
      hv:Mul( math.min( speedMeters, maxPredictionMeters ) * UNIT )
    end
    return ( self.UKF_PlayerPos or enemy:GetPos() ) + hv
  end

  -- vertical variant (windup placement): full 3D position + velocity lead
  function ENT:UKF_PredictPlayerPosVertical()
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then
      -- possessed with no lock-on: drop the bolt at the crosshair
      if self:IsPossessed() then
        local tr = self:PossessorTrace()
        if tr then return tr.HitPos end
      end
      return self:GetPos() + self:GetForward()
    end
    if self:UKF_GetDifficulty() <= 1 then return enemy:GetPos() end
    local vel = self.UKF_TargetVel or vector_origin
    local lead = vel:GetNormalized() * math.min( vel:Length() / UNIT, 5 ) * UNIT
    return enemy:GetPos() + lead
  end

  ------------------------------------------------------------------------------
  -- Action system
  ------------------------------------------------------------------------------

  function ENT:UKF_InAction()
    if self.UKF_ActionUntil and self.UKF_ActionUntil > CurTime() then return true end
    if self.UKF_ActionName then self:UKF_EndAction() end
    return false
  end

  function ENT:UKF_ActionTime()
    return ( CurTime() - ( self.UKF_ActionStart or 0 ) ) * self:UKF_AnimSpeed()
  end

  function ENT:UKF_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKF_AnimSpeed()

    -- canon PrepAttack: instant look at the player + stop nav
    local enemy = self:GetEnemy()
    if name ~= "Roll" and name ~= "Knockdown" then
      if IsValid( enemy ) then
        self:FaceInstant( self.UKF_PlayerPos or enemy:GetPos() )
      elseif self:IsPossessed() then
        -- no lock-on: every swing is built on GetForward, so the body must
        -- snap onto the possessor's aim (base PossessionFaceForwardInstant
        -- recipe) or bind attacks whiff into whatever he last faced
        self:FaceInstant( self:GetPos() + self:PossessorNormal() * 100 )
      end
    end

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKF_ActionName = name
    self.UKF_ActionStart = CurTime()
    self.UKF_ActionUntil = CurTime() + cfg.dur / spd
    self.UKF_ActionEvIndex = 1
    self.UKF_Tracking = cfg.track or false
    self.UKF_Checks = cfg.checks
    self.UKF_Knockback = cfg.knockback or false
    self.UKF_ActionHits = {}
    self.UKF_Damaging = false
    self.UKF_Uppercutting = false

    if cfg.moveAtStart then
      self:UKF_StartMoving( cfg.moveAtStart )
    else
      self.UKF_Moving = false
      -- canon PrepAttack: the nav agent halts — kill residual chase momentum
      -- or the whole action visibly slides across the floor
      self.loco:SetVelocity( vector_origin )
    end

    -- canon: nma.enabled = false during actions. CantMove gates the base AI's
    -- HandleEnemyPathing (no chasing mid-action); yaw 0 locks the loco so it
    -- can't fight the canon tracking rotation.
    self.CantMove = true
    self:SetMaxYawRate( 0 )
  end

  function ENT:UKF_EndAction()
    self.UKF_ActionName = nil
    self.UKF_ActionUntil = nil
    self.UKF_Tracking = false
    self.UKF_Moving = false
    self.UKF_Uppercutting = false
    self.UKF_Damaging = false
    self.UKF_Knockback = false
    self.CantMove = false
    -- never let the base parry window outlive the action (also covers death)
    self:SetParryable( false )
    self:SetMaxYawRate( self.MaxYawRate )
  end

  -- canon StartMoving: movingSpeed = speed * 10 (m/s)
  function ENT:UKF_StartMoving( speed )
    self.UKF_MovingSpeed = speed * 10 * UNIT
    self.UKF_Moving = true
    self:UKF_Footstep( 0.75 )
  end

  function ENT:UKF_StopMoving()
    self.UKF_Moving = false
    self:UKF_Footstep( 0.75 )
  end

  -- canon IsLedgeSafe: don't dash off a cliff (checked along the DASH
  -- direction — BackstepAttack moves backwards)
  function ENT:UKF_IsLedgeSafe( dir )
    dir = dir or self:GetForward()
    local ahead = self:GetPos() + dir * ( 2 * UNIT ) + Vector( 0, 0, 10 )
    local tr = util.TraceLine( {
      start = ahead,
      endpos = ahead - Vector( 0, 0, 8 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    return tr.Hit
  end

  ------------------------------------------------------------------------------
  -- Event dispatch
  ------------------------------------------------------------------------------

  function ENT:UKF_ProcessEvents()
    local name = self.UKF_ActionName
    local cfg = name and ACTION[ name ]
    if not cfg then return end
    local t = self:UKF_ActionTime()

    while self.UKF_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKF_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKF_ActionEvIndex = self.UKF_ActionEvIndex + 1
      self:UKF_FireEvent( ev[ 2 ], ev[ 3 ] )
    end
  end

  function ENT:UKF_FireEvent( kind, arg )
    if kind == "parry" then
      self:UKF_Flash( true )
    elseif kind == "unparry" then
      self:UKF_Flash( false )
    elseif kind == "trackOn" then
      self.UKF_Tracking = true
    elseif kind == "trackOff" then
      self.UKF_Tracking = false
    elseif kind == "dmgOn" then
      self:UKF_StartDamage()
    elseif kind == "dmgOff" then
      self:UKF_StopDamage()
    elseif kind == "moveOn" then
      self:UKF_StartMoving( arg or 1 )
    elseif kind == "moveOff" then
      self:UKF_StopMoving()
    elseif kind == "upOn" then
      self.UKF_Uppercutting = true
      self:UKF_StartDamage()
      -- canon: the Ferryman launches himself up WITH the target. On the
      -- ground the loco zeroes any +Z velocity, so detach first.
      self:LeaveGround()
    elseif kind == "upOff" then
      self.UKF_Uppercutting = false
      self:UKF_StopDamage()
      -- canon StopUppercut: pop up 10 m/s, gravity back on
      self.loco:SetVelocity( Vector( 0, 0, 10 * UNIT ) )
    elseif kind == "slam" then
      self:UKF_SlamHit()
    elseif kind == "windup" then
      self:UKF_SpawnWindup( false )
    elseif kind == "windupQuick" then
      self:UKF_SpawnWindup( true )
    elseif kind == "windupOver" then
      if IsValid( self.UKF_Windup ) then self.UKF_Windup:WindupOver() end
    end
  end

  ------------------------------------------------------------------------------
  -- Flash / parry (canon Flash + GotParried)
  ------------------------------------------------------------------------------

  function ENT:UKF_GetAttachmentPos( name, fallback )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return fallback
  end

  function ENT:UKF_HeadPos()
    return self:UKF_GetAttachmentPos( "head",
      self:GetPos() + Vector( 0, 0, 103 ) ) -- x0.605 rescale
  end

  function ENT:UKF_ChestPos()
    return self:UKF_GetAttachmentPos( "chest",
      self:WorldSpaceCenter() + Vector( 0, 0, 19 ) ) -- x0.605 rescale
  end

  function ENT:UKF_Flash( parryable )
    if self.CreateAlert then
      self:CreateAlert( self:UKF_HeadPos() + self:GetForward() * 20,
        parryable and 1 or 2, 3 )
    end
    -- canon mach.ParryableCheck: hand the window to the base parry framework
    -- (CheckParry in OnTakeDamage does the golden flash sound + hitstop)
    self:SetParryable( parryable )
  end

  -- canon GotParried: lightning strikes the Ferryman himself (safe for the
  -- player, hurts other enemies), windup destroyed, attack interrupted.
  -- Sound/hitstop/bonus damage live in the base OnParry — not duplicated here.
  function ENT:UKF_GotParried()
    self:UKF_RemoveWindup()
    self:SetSkin( 0 )
    self:UKF_EndAction()

    local chest = self:UKF_ChestPos()
    UKFerryman.Explode( self, chest, UKFerryman.LIGHTNING_RADIUS,
      UKFerryman.LIGHTNING_DAMAGE, { electric = true, safeForPlayer = true } )

    local fx = EffectData()
    fx:SetOrigin( Vector( chest.x, chest.y, self:GetPos().z ) )
    util.Effect( "ultrakill_test_ferryman_bolt", fx, true, true )
    sound.Play( UKFerryman.SOUND.Thunder, chest, 130, 110, 1 )

    -- brief stagger so the parry visibly interrupts him
    local idle = self:LookupSequence( "Idle" )
    if idle and idle >= 0 then self:ResetSequence( idle ) end
  end

  -- base parry framework: BaseClass.OnParry adds +5000 DMG_DIRECT, plays the
  -- canon golden flash sound, hitstops and closes the window; the Ferryman
  -- then chains his canon GotParried reaction (self-lightning).
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    self:UKF_GotParried()
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKF_Dead then return end

    -- "Ride the Lightning" chargeback: the coin's railcannon beam hits the
    -- Ferryman for massive canon damage but must not one-shot him — cap the
    -- self-hit to half max HP. The cap is applied pre-multiplier, so divide
    -- by the same DamageMultiplier the base is about to apply.
    if ( self.UKF_ChargebackUntil or 0 ) > CurTime()
        and dmg:IsDamageType( DMG_SHOCK ) then
      local mult = math.max( self:GetDamageMultiplierConVar( dmg:GetAttacker() ), 0.01 )
      dmg:SetDamage( math.min( dmg:GetDamage(), self:GetMaxHealth() * 0.5 / mult ) )
      self.UKF_ChargebackUntil = nil
    end

    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; calling
    -- CheckParry earlier would put the flat +5000 parry bonus under the x10
    -- player-damage multiplier (instakill)
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Melee damage (canon SwingCheck2 windows)
  ------------------------------------------------------------------------------

  function ENT:UKF_StartDamage()
    self.UKF_Damaging = true
    -- canon SwingCheck2.DamageStop clears hit lists per damage WINDOW, not per
    -- action — combos legitimately hit once per window
    self.UKF_ActionHits = {}
    -- canon swing audio: oar pitch 0.65-0.9 vol 1.0, kick pitch 2.1-2.55 vol 0.75
    local isKick = self.UKF_Checks == "kick" or self.UKF_Checks == "mainkick"
    local snd = math.random( 2 ) == 1 and UKFerryman.SOUND.Swing1 or UKFerryman.SOUND.Swing2
    self:EmitSound( snd, 90,
      isKick and math.random( 210, 255 ) or math.random( 65, 90 ),
      isKick and 0.75 or 1.0 )
  end

  function ENT:UKF_StopDamage()
    self.UKF_Damaging = false
    -- canon StopDamage: mach.parryable = false — the parry window dies with the swing
    self:SetParryable( false )
  end

  function ENT:UKF_ApplyMeleeDamage()
    if not self.UKF_Damaging then return end
    local hits = self.UKF_ActionHits or {}
    self.UKF_ActionHits = hits

    -- canon reach: main frontal box 3x5x5 m @ 2.5 m fwd + long oar capsule;
    -- the pure kick check (Vault: main=false, kick=true) is shorter, while
    -- KickCombo runs main+kick — full main reach. Approximated as spheres.
    local fwd = self:GetForward()
    if self:IsPossessed() and not IsValid( self:GetEnemy() ) then
      -- no lock-on: the swing volume follows the possessor's aim (vertical
      -- included) — body yaw alone can't reach targets above/below
      local aim = self:PossessorNormal()
      if aim then fwd = aim end
    end
    local shortReach = self.UKF_Checks == "kick"
    local center = self:WorldSpaceCenter()
      + fwd * ( ( shortReach and 1.5 or 2.5 ) * UNIT )
    local radius = ( shortReach and 2.5 or 4 ) * UNIT

    for _, ent in ipairs( ents.FindInSphere( center, radius ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKFerryman_IsFerryman then continue end -- canon type self-ignore

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKFerryman.ScaleAttackDamage( ent, UKFerryman.SWING_DAMAGE, self ) )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( fwd * 1200 + Vector( 0, 0, 200 ) )
      ent:TakeDamageInfo( dmg )

      -- canon TargetBeenHit: ANY landed hit closes every check for this swing
      self.UKF_Damaging = false
      -- canon BackstepAttack knockBack: Launch(dir*2500 + up*250)
      if self.UKF_Knockback and ent:IsPlayer() then
        local dir = ( ent:GetPos() - self:GetPos() )
        dir.z = 0
        dir:Normalize()
        ent:SetVelocity( dir * 900 + Vector( 0, 0, 350 ) )
      end
      break
    end
  end

  -- canon SlamHit: "Explosion Ferryman" (35 dmg, 6 m sphere) at the oar tip on the ground
  function ENT:UKF_SlamHit()
    local oar = self:UKF_GetAttachmentPos( "oar",
      self:GetPos() + self:GetForward() * ( 3 * UNIT ) )
    local ground = Vector( oar.x, oar.y, self:GetPos().z )
    UKFerryman.Explode( self, ground, UKFerryman.SLAM_RADIUS, UKFerryman.SLAM_DAMAGE, {} )
    self:UKF_Footstep( 0.75 )
  end

  function ENT:UKF_Footstep( volume )
    self:EmitSound( UKFerryman.SOUND.Footstep, 85,
      math.random( 115, 135 ), volume or 0.5 )
  end

  ------------------------------------------------------------------------------
  -- Lightning (canon LightningBolt / windup / cancel)
  ------------------------------------------------------------------------------

  function ENT:UKF_CanLightning()
    -- canon: SlowUpdate refuses the bolt below STANDARD — an AI decision only;
    -- a possessed player's cast button must never go silently dead on low
    -- difficulties (the cooldowns below still apply)
    if self:UKF_GetDifficulty() <= 1 and not self:IsPossessed() then return false end
    return self.UKF_LightningCooldown <= 0 and UKFerryman.GlobalLightningReady()
  end

  function ENT:UKF_CastLightning( quick )
    UKFerryman.AddGlobalLightningCooldown( 6 )
    local diff = self:UKF_GetDifficulty()
    self.UKF_LightningCooldown = 8 - diff * 2
    if quick and diff >= 4 and self.UKF_LightningCooldown < 3 then
      self.UKF_LightningCooldown = 3
    end

    if quick and diff >= 4 then
      self:UKF_StartAction( "QuickLightningBolt" )
    else
      self:UKF_StartAction( "LightningBolt" )
      self.UKF_LightningCancellable = true
    end
  end

  function ENT:UKF_SpawnWindup( quick )
    self:UKF_RemoveWindup()

    local windup = ents.Create( UKFerryman.CLASS.Windup )
    if not IsValid( windup ) then return end

    windup:UKFW_Setup( self, self:GetEnemy(), quick, self:UKF_GetDifficulty(), 1 )
    windup:SetPos( self:UKF_PredictPlayerPosVertical() )
    windup:Spawn()
    self.UKF_Windup = windup

    -- canon: charged oar material + halo chimes for the whole windup
    self:SetSkin( 1 )
    self:EmitSound( UKFerryman.SOUND.Chimes, 85, 100, 0.5 )
    self.UKF_Tracking = false
  end

  function ENT:UKF_RemoveWindup()
    if IsValid( self.UKF_Windup ) then
      self.UKF_Windup:Cancel()
    end
    self.UKF_Windup = nil
    self:StopSound( UKFerryman.SOUND.Chimes )
  end

  -- windup entity callback: strike happened -> restore the oar material
  function ENT:UKFerryman_OnLightningStrike()
    self:SetSkin( 0 )
    self.UKF_LightningCancellable = false
    self.UKF_Windup = nil
    self:StopSound( UKFerryman.SOUND.Chimes )
  end

  function ENT:UKF_CancelLightning()
    self:UKF_RemoveWindup()
    self:SetSkin( 0 )
    self.UKF_LightningCancellable = false
    if self.UKF_ActionName == "LightningBolt" then
      self:UKF_EndAction()
      local idle = self:LookupSequence( "Idle" )
      if idle and idle >= 0 then self:ResetSequence( idle ) end
    end
  end

  -- Reachability heuristic replacing canon NavMesh.CalculatePath status.
  -- Canon projects airborne targets onto the ground and paths there, so a
  -- merely jumping player is NOT unreachable; the flag fires only for targets
  -- hanging 20+ m above, long-airborne targets (slam storage / noclip) or a
  -- chase that visibly cannot close the distance.
  function ENT:UKF_TargetUnreachable( enemy )
    local mypos = self:GetPos()
    local tpos = enemy:GetPos()

    if tpos.z > mypos.z + 20 * UNIT then return true end

    if enemy:IsOnGround() then
      self.UKF_AirSince = nil
    else
      self.UKF_AirSince = self.UKF_AirSince or CurTime()
    end
    local airborneLong = self.UKF_AirSince and ( CurTime() - self.UKF_AirSince > 2 )

    local dist2d = Vector( tpos.x - mypos.x, tpos.y - mypos.y, 0 ):Length()
    local stuck = dist2d > 8 * UNIT and self.loco:GetVelocity():Length() < 2 * UNIT

    if airborneLong or stuck then
      self.UKF_UnreachSince = self.UKF_UnreachSince or CurTime()
      return CurTime() - self.UKF_UnreachSince > 0.75
    end

    self.UKF_UnreachSince = nil
    return false
  end

  ------------------------------------------------------------------------------
  -- AttackCheck (canon decision tree, verbatim structure)
  ------------------------------------------------------------------------------

  function ENT:UKF_AttackCheck( enemy )
    local diff = self:UKF_GetDifficulty()

    -- 1. Brutal+: 50% quick lightning as an opener
    if diff >= 4 and self.UKF_LightningCooldown <= 0
        and UKFerryman.GlobalLightningReady() then
      if math.Rand( 0, 1 ) > 0.5 then
        self:UKF_CastLightning( true )
      else
        self.UKF_LightningCooldown = 0.4
      end
      return
    end

    local mypos = self:GetPos()
    local playerPos = self.UKF_PlayerPos
    local targetPos = self.UKF_TargetPos
    local targetVel = self.UKF_TargetVel
    local num = playerPos:Distance( mypos )

    -- 2. close + airborne target -> Roll away or Uppercut
    if num < 8 * UNIT and ( targetPos.z > mypos.z + 5 * UNIT
        or ( targetVel.z > 5 * UNIT and not enemy:IsOnGround() ) ) then
      if self.UKF_PlayerRetreating and self.UKF_RollCooldown <= 0 then
        self:UKF_Roll( false )
      elseif num < 5 * UNIT and targetPos.z < mypos.z + 20 * UNIT then
        self:UKF_StartAction( "Uppercut" )
      end

    -- 3. far, or retreating slide
    elseif num > 8 * UNIT
        or ( self.UKF_PlayerRetreating and enemy:IsPlayer() and enemy:Crouching() ) then
      if self.UKF_VaultCooldown <= 0 and num < 35 * UNIT and num > 30 * UNIT
          and not self.UKF_PlayerApproaching
          and targetPos.z <= mypos.z + 20 * UNIT then
        self.UKF_VaultCooldown = 2
        self:UKF_StartAction( diff >= 3 and "VaultSwing" or "Vault" )
      elseif num < 14 * UNIT and self.UKF_PlayerRetreating and not self.UKF_PlayerAbove then
        if math.Rand( 0, 1 ) < self.UKF_StingerChance or self.UKF_RollCooldown > 0 then
          self.UKF_StingerChance = math.min( 0.25, self.UKF_StingerChance - 0.25 )
          self:UKF_StartAction( "Stinger" )
        else
          self.UKF_StingerChance = math.max( 0.75, self.UKF_StingerChance + 0.25 )
          self:UKF_Roll( false )
        end
      end

    -- 4. player charging in
    elseif self.UKF_PlayerApproaching then
      if math.Rand( 0, 1 ) < 0.25 then
        if math.Rand( 0, 1 ) < 0.75 and self.UKF_RollCooldown <= 0 then
          self:UKF_Roll( true )
        elseif math.Rand( 0, 1 ) < 0.5 then
          self:UKF_StartAction( "KickCombo" )
        else
          self:UKF_StartAction( "OarCombo" )
        end
      elseif math.Rand( 0, 1 ) < self.UKF_OverheadChance then
        self.UKF_OverheadChance = math.min( 0.25, self.UKF_OverheadChance - 0.25 )
        self:UKF_StartAction( "Downslam" )
      else
        self.UKF_OverheadChance = math.max( 0.75, self.UKF_OverheadChance + 0.25 )
        self:UKF_StartAction( "BackstepAttack" )
      end

    -- 5. standing next to the target
    elseif math.Rand( 0, 1 ) < self.UKF_KickComboChance then
      self.UKF_KickComboChance = math.min( 0.25, self.UKF_KickComboChance - 0.25 )
      self:UKF_StartAction( "KickCombo" )
    else
      self.UKF_KickComboChance = math.max( 0.75, self.UKF_KickComboChance + 0.25 )
      self:UKF_StartAction( "OarCombo" )
    end
  end

  function ENT:UKF_Roll( toPlayerSide )
    self:UKF_StartAction( "Roll" )

    local enemy = self:GetEnemy()
    if self:IsPossessed() and not IsValid( enemy ) then
      -- no lock-on: the roll dash runs on GetForward — point it at the aim
      self:FaceInstant( self:GetPos() + self:PossessorNormal() * 100 )
    elseif not toPlayerSide then
      self:FaceInstant( self:UKF_PredictPlayerPos( 20 ) )
    elseif IsValid( enemy ) then
      local side = ( math.Rand( 0, 1 ) > 0.5 and 1 or -1 ) * 5 * UNIT
      local right = enemy:GetRight()
      self:FaceInstant( ( self.UKF_PlayerPos or enemy:GetPos() ) + right * side )
    end

    local diff = self:UKF_GetDifficulty()
    if diff <= 2 then
      self.UKF_RollCooldown = 5.5 - diff * 2
    end
  end

  ------------------------------------------------------------------------------
  -- Animation / speed
  ------------------------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    if self.UKF_ActionName and self:UKF_InAction() then
      local cfg = ACTION[ self.UKF_ActionName ]
      return cfg.seq, self:UKF_AnimSpeed()
    end

    local spd = self:UKF_AnimSpeed()
    if not self:IsOnGround() then return "Falling", spd end
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco:GetVelocity():Length() > 2 * UNIT
    if moving then return "Run", spd end
    return "Idle", spd
  end

  function ENT:OnUpdateSpeed()
    return UKFerryman.MOVE_SPEED * self:UKF_AnimSpeed()
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are driven by UKF_AttackCheck in CustomThink
    return
  end

  -- canon: nma.enabled = false during actions — the possessor must not drive
  -- the loco mid-action either (move events pin exact velocities); returning
  -- true skips DrGBase possession movement for the tick
  function ENT:OnPossession()
    return self:UKF_InAction()
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKF_Dead then return end
    if self:IsAIDisabled() then -- ai_disabled / per-bot disable
      -- дэш-мув/апперкот гонят его по-тиковым SetVelocity; замороженный
      -- мид-экшен иначе дрейфует с последней скоростью
      if ( self.UKF_Moving or self.UKF_Uppercutting ) and self.loco then
        self.loco:SetVelocity( vector_origin )
      end
      return
    end

    local now = CurTime()
    local dt = now - ( self.UKF_LastThink or now )
    self.UKF_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    local spd = self:UKF_AnimSpeed()
    -- possessed: the base GetEnemy override returns PossessionGetLockedOn()
    local enemy = self:GetEnemy()
    local possessed = self:IsPossessed()

    -- canon UpdateCooldowns: lightning ticks at x0.4 for the regular enemy
    if self.UKF_LightningCooldown > 0 then
      self.UKF_LightningCooldown = math.max( self.UKF_LightningCooldown - dt * 0.4, 0 )
    end
    if self.UKF_RollCooldown > 0 then
      self.UKF_RollCooldown = math.max( self.UKF_RollCooldown - dt, 0 )
    end
    if self.UKF_VaultCooldown > 0 then
      self.UKF_VaultCooldown = math.max( self.UKF_VaultCooldown - dt, 0 )
    end

    if not IsValid( enemy ) then
      -- possessed: bind-started actions must survive a NULL lock-on, so the
      -- no-enemy cancel stays an autonomous-AI decision only
      if not possessed then
        if self:UKF_InAction() or self.UKF_LightningCancellable then
          self:UKF_CancelLightning()
          self:UKF_EndAction()
        end
        return
      end
    else
      self:UKF_UpdatePlayerStatus( enemy )
    end

    -- canon SlowUpdate (out-of-reach lightning), 0.25 s cadence; casting when
    -- unreachable / dropping the bolt are autonomous decisions — a possessed
    -- cast is the player's call
    if not possessed then
      self.UKF_SlowTick = self.UKF_SlowTick + dt
      if self.UKF_SlowTick >= 0.25 then
        self.UKF_SlowTick = 0
        local unreachable = self:UKF_TargetUnreachable( enemy )

        if unreachable and self:UKF_GetDifficulty() >= 2 then
          -- canon: +0.1 per SlowUpdate tick (GetUpdateRate = 0.2..0.5 s) =>
          -- 3.0 charge fills in ~6-15 s; 0.1 per 0.25 s lands mid-range (7.5 s)
          self.UKF_OutOfReachCharge = self.UKF_OutOfReachCharge + 0.1
          if not self:UKF_InAction() and self.UKF_OutOfReachCharge > 3
              and self:UKF_CanLightning() then
            self.UKF_OutOfReachCharge = 0
            self:UKF_CastLightning( true )
          end
        else
          self.UKF_OutOfReachCharge = 0
          -- canon: an in-flight cancellable bolt is dropped once the target
          -- becomes reachable again (Brutal+ never cancels: death/parry only)
          if self.UKF_LightningCancellable and self:UKF_GetDifficulty() < 4 then
            self:UKF_CancelLightning()
          end
        end
      end
    end

    -- fire due events BEFORE the action-expiry check: a long frame hitch past
    -- ActionUntil must not swallow pending events (e.g. LightningBolt's
    -- windupOver at 2.524 with StopAction at 2.974)
    if self.UKF_ActionName then
      self:UKF_ProcessEvents()
    end

    if self:UKF_InAction() then
      -- canon tracking: rotate onto the predicted player pos at 600 deg/s.
      -- Done through the loco (yaw rate + FaceTowards) — direct SetAngles
      -- steps at think cadence read as jerky snapping in-game.
      if self.UKF_Tracking then
        self:SetMaxYawRate( 600 * spd )
        local target = self:UKF_PredictPlayerPos( 5 )
        if possessed and not IsValid( enemy ) then
          -- no lock-on: canon tracking steers onto the possessor's crosshair
          target = self:GetPos() + self:PossessorNormal() * 100
        end
        local dir = target - self:GetPos()
        dir.z = 0
        if dir:LengthSqr() > 1 then
          self:FaceTowards( self:GetPos() + dir )
        end
      else
        self:SetMaxYawRate( 0 )
      end

      -- canon moving: rb.velocity = dir * movingSpeed (ledge-gated). An IDLE
      -- ground loco (CantMove stops the nav from Approaching) ignores a bare
      -- SetVelocity — it must be DRIVEN: Approach marks it as moving this
      -- tick, desired speed lets it move that fast, SetVelocity pins the
      -- exact canon dash vector on top.
      if self.UKF_Moving then
        local dir = self:GetForward() * ( self.UKF_MovingSpeed >= 0 and 1 or -1 )
        local speed = math.abs( self.UKF_MovingSpeed ) * spd
        if self:UKF_IsLedgeSafe( dir ) then
          self.loco:SetDesiredSpeed( speed )
          self.loco:Approach( self:GetPos() + dir * 100, 1 )
          self.loco:SetVelocity( Vector( dir.x * speed, dir.y * speed,
            self.loco:GetVelocity().z ) )
        else
          self.loco:SetVelocity( vector_origin )
        end
      end

      -- canon uppercutting: up 100 m/s + forward min(100, dist*40) m/s
      if self.UKF_Uppercutting then
        -- no lock-on: the launch reads the aim point (planar, like canon
        -- ToPlanePos) — UKF_PlayerPos may be stale from a pre-possession fight
        local planar = self.UKF_PlayerPos
        if possessed and not IsValid( enemy ) then
          local tr = self:PossessorTrace()
          planar = tr and Vector( tr.HitPos.x, tr.HitPos.y, self:GetPos().z ) or nil
        end
        local dist = planar and self:GetPos():Distance( planar ) or 0
        local fwdSpeed = 0
        if self:UKF_IsLedgeSafe() and dist > 5 * UNIT then
          fwdSpeed = math.min( 100 * UNIT, dist * 40 )
        end
        self.loco:SetVelocity( Vector( 0, 0, 100 * UNIT * spd )
          + self:GetForward() * ( fwdSpeed * spd ) )
      end

      self:UKF_ApplyMeleeDamage()

    elseif self:IsOnGround() and not possessed then
      self:UKF_AttackCheck( enemy )
    end

    self:UKF_UpdateFootsteps()
  end

  ------------------------------------------------------------------------------
  -- Footsteps (Run_1 events 0.022 / 0.293 over a 0.63 s clip)
  ------------------------------------------------------------------------------

  local RUN_STEPS = { 0.035, 0.465 }

  function ENT:UKF_UpdateFootsteps()
    if self:UKF_InAction() then return end
    if not ( self:IsMoving() or self:IsRunning() ) then return end
    local seqName = self:GetSequenceName( self:GetSequence() ) or ""
    if seqName ~= "Run" then return end

    local cycle = self:GetCycle()
    local last = self.UKF_LastRunCycle or 0
    for _, mark in ipairs( RUN_STEPS ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) )
      if crossed then
        self:UKF_Footstep( 0.5 )
        break
      end
    end
    self.UKF_LastRunCycle = cycle
  end

  ------------------------------------------------------------------------------
  -- Death (canon: go limp, the oar vanishes — Enemy.onDeath Oar.SetActive(false))
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKF_Dead = true
    self:UKF_RemoveWindup()
    self:SetSkin( 0 )
    self:UKF_EndAction()

    -- the base ragdoll copies bodygroups, so the corpse spawns without the oar
    local oarBg = self:FindBodygroupByName( "oar" )
    if oarBg and oarBg >= 0 then self:SetBodygroup( oarBg, 1 ) end

    -- canon: he just goes limp. Returning the dmg hands it to the base
    -- BecomeRagdoll (RagdollOnDeath) — jointed ragdoll + killing-blow force.
    return dmg
  end
end

DrGBase.AddNextbot( ENT )
