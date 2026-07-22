AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end

-- Mannequin (Lesser Demon, Act III). Full canon port of Mannequin.cs:
-- behaviors (Melee/RunAway/Wander/Jump), 2-swing melee dash combo with
-- parry->instakill, chargeable Gradual-homing projectile (interruptible),
-- wall/ceiling cling with surface relocation + knock-off stun, Landing stun,
-- post-mortem breathing.
-- Clip-event timings from the Mannequin animator controller dump.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Mannequin"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKMannequin.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKMannequin.HP
-- canon capsule r=0.75 m h=6 m at 19 su/m (~115 su tall — player x1.6)
ENT.CollisionBounds = Vector( 16, 16, 112 )
ENT.SurroundingBounds = Vector( 150, 150, 170 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
-- canon EnemyIdentifier weight = medium: whiplash yanks V1 to the mannequin,
-- not the mannequin to V1 (workshop report 2026-07-10)
ENT.UltrakillBase_WeightClass = "Medium"
ENT.BloodColor = BLOOD_COLOR_RED

ENT.UKMannequin_IsMannequin = true -- canon projectile safeEnemyType = Mannequin

local UNIT = UKMannequin.UNIT

ENT.MeleeAttackRange = UKMannequin.MELEE_RANGE
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 3 * UNIT
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 1000 * UNIT -- canon nav acceleration 1000 m/s^2 (instant)
ENT.Deceleration = 1000 * UNIT
ENT.WalkSpeed = 320   -- profile walk (VIOLENT), su/s
ENT.RunSpeed = 1700   -- profile skitter (VIOLENT), su/s
-- canon angular speed 36000 deg/s = instant snap; slow sweep at skitter speed
-- read as "drifting" in-game (tuned 2026-07-03)
ENT.MaxYawRate = 2400
ENT.JumpHeight = 120
ENT.StepHeight = 24
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Walk"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Skitter"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Falling"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Falling"
ENT.FallingAnimRate = 1

--------------------------------------------------------------------------------
-- Canon clip events (seconds at animation speed 1.0, 30 fps bake).
-- At runtime every timing is divided by the difficulty animation speed.
-- MeleeAttack: StopTracking(1)@0.278 SwingStart(0)@0.488 SwingEnd(0)@0.610
--   StopTracking(0)@0.746 SwingStart(1)@0.853 SwingEnd(1)@1.043 StopAction@1.497
-- ProjectileAttack: Charge@0.114 Shoot@0.639 StopAiming@1.199 StopAction@1.338
-- WallClingProjectile: Charge@0.132 Shoot@0.634 StopAiming@1.341 StopAction@1.541
-- Jump: JumpNow@0.324 ; Landing: StopAction@0.720
--------------------------------------------------------------------------------

local ACTION = {
  MeleeAttack = {
    seq = "MeleeAttack", dur = 1.497, track = true,
    ev = {
      { 0.278, "parryOn" },
      { 0.488, "swingOn" }, { 0.610, "swingOff" },
      { 0.746, "reface" },
      { 0.853, "swingOn" }, { 1.043, "swingOff" }, { 1.043, "parryOff" },
    },
  },
  ProjectileAttack = {
    seq = "ProjectileAttack", dur = 1.338, track = true,
    ev = {
      { 0.114, "charge" }, { 0.639, "shoot" }, { 1.199, "stopAim" },
    },
  },
  WallClingProjectile = {
    seq = "WallClingProjectile", dur = 1.541, track = true, cling = true,
    ev = {
      { 0.132, "charge" }, { 0.634, "shoot" }, { 1.341, "stopAim" },
    },
  },
  Jump = {
    seq = "Jump", dur = 0.430, track = false,
    ev = {
      { 0.324, "jumpNow" },
    },
  },
  Landing = {
    seq = "Landing", dur = 0.720, track = false,
    ev = {},
  },
}

local BEHAVIOR_RANDOM = { "RunAway", "Wander", "Jump" }

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 14, 56 ),
    distance = 180,
    eyepos = false

  },

  {

    -- no EyeBone on this model: EyePos() is the bounds center, lift to the head
    offset = Vector( 7, 0, 48 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self )

    if self:UKM_InAction() or self.UKM_MeleeCD > 0 or not self:IsOnGround() then return end

    self.UKM_MeleeCD = UKMannequin.MELEE_COOLDOWN
    self:UKM_StartAction( "MeleeAttack" )

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self )

    if self:UKM_InAction() or self.UKM_ProjCD > 0 or not self:IsOnGround() then return end

    self:UKM_StartProjectileAttack()

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self )

    if self:UKM_InAction() or self.UKM_JumpCD > 0 or not self:IsOnGround() then return end

    self.UKM_JumpCD = 2
    self:UKM_StartAction( "Jump" )

  end } },

  [ IN_SPEED ] = { { coroutine = false, onkeydown = function( self )

    self.UKM_SkitterMode = true

  end, onkeyup = function( self )

    self.UKM_SkitterMode = false

  end } },

}

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKMannequin.HP
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKM_Dead = false
    self.UKM_ActionName = nil
    self.UKM_ActionStart = 0
    self.UKM_ActionUntil = nil
    self.UKM_ActionEvIndex = 1
    self.UKM_Tracking = false
    self.UKM_Damaging = false
    self.UKM_Dashing = false
    self.UKM_Charging = false
    self.UKM_ActionHits = nil
    self.UKM_FallSpeed = 0
    self:SetParryable( false )

    -- canon cooldown fields (initializers)
    self.UKM_MeleeCD = 0.5
    self.UKM_ProjCD = 1.0
    self.UKM_JumpCD = 2.0
    self.UKM_MeleeBehaviorCancel = 3.5

    self.UKM_Behavior = "Random"
    self.UKM_SkitterMode = false
    self.UKM_MoveTarget = nil    -- manual (Wander/RunAway) movement target
    self.UKM_InControl = false
    self.UKM_CanCling = true
    self.UKM_Clinging = false
    self.UKM_ClingNormal = nil
    self.UKM_ClingPos = nil
    self.UKM_ClingMoveTarget = nil
    self.UKM_AttacksWhileClinging = 0
    self.UKM_FirstClingCheck = true
    self.UKM_Jumping = false

    self.UKM_AirSince = nil
    self.UKM_HasVision = false
    self.UKM_NextVisionCheck = 0
    self.UKM_SlowTick = 0

    self:UKM_ChangeBehavior( false )

    -- canon: breathing loops from the Head bone (vol 0.035, RandomPitch)
    self.UKM_BreathSound = CreateSound( self, UKMannequin.SOUND.Breathing )
    self.UKM_BreathSound:PlayEx( 0.3, math.random( 92, 108 ) )
    self.UKM_SkitterSound = CreateSound( self, UKMannequin.SOUND.Skitter )
    self.UKM_SkitterPlaying = false

    self:EmitSound( UKMannequin.SOUND.Spawn, 80, 100, 0.6 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    if self.UKM_ClingHook then
      hook.Remove( "Tick", self.UKM_ClingHook )
      self.UKM_ClingHook = nil
    end
    if self.UKM_BreathSound then self.UKM_BreathSound:Stop() end
    if self.UKM_SkitterSound then self.UKM_SkitterSound:Stop() end
  end

  ------------------------------------------------------------------------------
  -- Difficulty (canon SetSpeed profiles)
  ------------------------------------------------------------------------------

  function ENT:UKM_GetDifficulty()
    return UKMannequin.GetDifficulty( self )
  end

  function ENT:UKM_Profile()
    return UKMannequin.SPEED_PROFILE[ self:UKM_GetDifficulty() ]
      or UKMannequin.SPEED_PROFILE[ 3 ]
  end

  function ENT:UKM_AnimSpeed()
    return self:UKM_Profile().anim
  end

  ------------------------------------------------------------------------------
  -- Behavior (canon ChangeBehavior: 35% Melee else RunAway/Wander/Jump)
  ------------------------------------------------------------------------------

  function ENT:UKM_ChangeBehavior( noMelee )
    self.UKM_MoveTarget = nil
    if not noMelee and math.Rand( 0, 1 ) < 0.35 then
      self.UKM_MeleeBehaviorCancel = 3.5
      self.UKM_Behavior = "Melee"
    else
      self.UKM_Behavior = BEHAVIOR_RANDOM[ math.random( #BEHAVIOR_RANDOM ) ]
    end
  end

  ------------------------------------------------------------------------------
  -- Vision (canon shootQuery: LOS blocked by environment; props block — MASK_SHOT)
  ------------------------------------------------------------------------------

  function ENT:UKM_UpdateVision( enemy )
    if CurTime() < self.UKM_NextVisionCheck then return self.UKM_HasVision end
    self.UKM_NextVisionCheck = CurTime() + 0.15

    local eyes = enemy.EyePos and enemy:EyePos() or enemy:WorldSpaceCenter()
    local tr = util.TraceLine( {
      start = self:WorldSpaceCenter(),
      endpos = eyes,
      mask = MASK_SHOT,
      filter = { self, enemy },
    } )
    self.UKM_HasVision = not tr.Hit
    return self.UKM_HasVision
  end

  ------------------------------------------------------------------------------
  -- Action system (ferryman/sentry pattern: cfg-guarded event loop)
  ------------------------------------------------------------------------------

  function ENT:UKM_InAction()
    if self.UKM_ActionUntil and self.UKM_ActionUntil > CurTime() then return true end
    if self.UKM_ActionName then self:UKM_EndAction() end
    return false
  end

  function ENT:UKM_ActionTime()
    return ( CurTime() - ( self.UKM_ActionStart or 0 ) ) * self:UKM_AnimSpeed()
  end

  function ENT:UKM_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKM_AnimSpeed()

    local enemy = self:GetEnemy()
    if IsValid( enemy ) and cfg.track and not self.UKM_Clinging then
      self:FaceInstant( enemy:GetPos() )
    end

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKM_ActionName = name
    self.UKM_ActionStart = CurTime()
    self.UKM_ActionUntil = CurTime() + cfg.dur / spd
    self.UKM_ActionEvIndex = 1
    self.UKM_ActionCfg = cfg
    self.UKM_Tracking = cfg.track or false
    self.UKM_ActionHits = {}
    self.UKM_Damaging = false
    self.UKM_Dashing = false

    if not self.UKM_Clinging then
      self.loco:SetVelocity( vector_origin )
      self.CantMove = true
      self:SetMaxYawRate( 0 )
    end
  end

  function ENT:UKM_EndAction( keepBehavior )
    local wasAction = self.UKM_ActionName ~= nil
    self.UKM_ActionName = nil
    self.UKM_ActionUntil = nil
    self.UKM_ActionCfg = nil
    self.UKM_Tracking = false
    self.UKM_Damaging = false
    self.UKM_Dashing = false
    self.UKM_Charging = false
    self:SetParryable( false )
    self:UKM_StopChargeFX()

    if not self.UKM_Clinging then
      self.CantMove = false
      self:SetMaxYawRate( self.MaxYawRate )
      -- canon StopAction else-branch: clear jump/cling-walk leftovers
      self.UKM_ClingMoveTarget = nil
      self.UKM_Jumping = false
    end

    -- canon StopAction: cling attack counting + relocation + behavior reroll
    if wasAction and not keepBehavior then
      if self.UKM_Clinging then
        if self.UKM_AttacksWhileClinging >= ( math.Rand( 0, 1 ) > 0.5 and 2 or 4 ) then
          self.UKM_AttacksWhileClinging = 0
          self.UKM_InControl = true
          self:UKM_Uncling()
        elseif not self.UKM_Jumping then
          self:UKM_RelocateWhileClinging( math.Rand( 0, 1 ) > 0.5 )
        end
      end
      self:UKM_ChangeBehavior( false )
    end
  end

  -- canon CancelActions (damage interrupt / falling)
  function ENT:UKM_CancelAction()
    self:UKM_StopChargeFX()
    self:UKM_EndAction( true )
    local idle = self:LookupSequence( self.UKM_Clinging and "WallCling" or "Idle" )
    if idle and idle >= 0 then self:ResetSequence( idle ) end
  end

  function ENT:UKM_ProcessEvents()
    local cfg = self.UKM_ActionCfg
    if not cfg then return end
    local t = self:UKM_ActionTime()

    while self.UKM_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKM_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKM_ActionEvIndex = self.UKM_ActionEvIndex + 1
      self:UKM_FireEvent( ev[ 2 ] )
      -- sentry lesson: an event can switch the action; stale cfg must bail out
      if self.UKM_ActionCfg ~= cfg then return end
    end
  end

  function ENT:UKM_FireEvent( kind )
    local enemy = self:GetEnemy()

    if kind == "parryOn" then
      -- canon StopTracking(1): lock facing + open the parry window + flash.
      -- Window handled by the BASE parry framework (flash + hitstop built-in).
      self.UKM_Tracking = false
      if IsValid( enemy ) and not self.UKM_Clinging then self:FaceInstant( enemy:GetPos() ) end
      self:SetParryable( true )
      if self.CreateAlert then
        self:CreateAlert( self:UKM_HeadPos() + self:GetForward() * 20, 1, 3 )
      end

    elseif kind == "parryOff" then
      self:SetParryable( false )

    elseif kind == "reface" then
      -- canon StopTracking(0): instant aim correction between swings
      if IsValid( enemy ) and not self.UKM_Clinging then self:FaceInstant( enemy:GetPos() ) end

    elseif kind == "swingOn" then
      self.UKM_Damaging = true
      self.UKM_Dashing = true
      self.UKM_ActionHits = {}
      self:EmitSound( UKMannequin.SOUND.Swing, 80, math.random( 95, 105 ), 1 )

    elseif kind == "swingOff" then
      self.UKM_Damaging = false
      self.UKM_Dashing = false
      local v = self.loco:GetVelocity()
      self.loco:SetVelocity( Vector( 0, 0, v.z ) )

    elseif kind == "charge" then
      self.UKM_Charging = true
      self:UKM_StartChargeFX()

    elseif kind == "shoot" then
      self.UKM_Charging = false
      self:UKM_StopChargeFX()
      self:UKM_ShootProjectile()

    elseif kind == "stopAim" then
      self.UKM_Tracking = false

    elseif kind == "jumpNow" then
      -- canon JumpNow: straight up 100 m/s toward the ceiling
      self.UKM_InControl = true
      self.UKM_Jumping = true
      self:LeaveGround()
      self.loco:SetVelocity( Vector( 0, 0, 100 * UNIT ) )
    end
  end

  ------------------------------------------------------------------------------
  -- Positions
  ------------------------------------------------------------------------------

  function ENT:UKM_GetAttachmentPos( name, fallback )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return fallback
  end

  function ENT:UKM_HeadPos()
    return self:UKM_GetAttachmentPos( "head", self:GetPos() + self:GetUp() * 104 )
  end

  function ENT:UKM_ShootPos()
    return self:UKM_GetAttachmentPos( "shootpoint", self:WorldSpaceCenter() )
  end

  ------------------------------------------------------------------------------
  -- Melee (canon SwingCheck2 windows + moveForward dash)
  ------------------------------------------------------------------------------

  function ENT:UKM_ApplyMeleeDamage()
    if not self.UKM_Damaging then return end
    local hits = self.UKM_ActionHits or {}
    self.UKM_ActionHits = hits

    -- canon SwingCheck box (3,6,4) m centered 1.75 m ahead — sphere approx
    local center = self:WorldSpaceCenter() + self:GetForward() * ( 1.75 * UNIT )
    for _, ent in ipairs( ents.FindInSphere( center, UKMannequin.MELEE_HIT_RADIUS ) ) do
      -- the possessor rides at the bot origin, inside the swing sphere
      if ent == self or ent == self:GetPossessor() or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKMannequin_IsMannequin then continue end

      hits[ ent ] = true
      -- round 3 (2026-07-10): MELEE_DAMAGE_NPC is the target LANDED value —
      -- pre-divide by the victim's incoming multiplier (x20 raw landed 40k
      -- and one-shotted everything)
      local amount = ent.IsUltrakillNextbot
        and UKNpcDmg.PreMult( ent, self, UKMannequin.MELEE_DAMAGE_NPC )
        or UKMannequin.ScaleAttackDamage( ent, UKMannequin.MELEE_DAMAGE_PLAYER )
      local dmg = DamageInfo()
      dmg:SetDamage( amount )
      dmg:SetDamageType( DMG_SLASH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 1200 )
      ent:TakeDamageInfo( dmg )

      -- canon TargetBeenHit: a landed hit closes the damage window
      self.UKM_Damaging = false
      break
    end
  end

  -- canon FixedUpdate moveForward: forward 55 m/s while swinging, stops at the
  -- player (raycast gate) and at ledges
  function ENT:UKM_ApplyDash()
    if not self.UKM_Dashing then return end
    local spd = UKMannequin.MELEE_DASH_SPEED * self:UKM_AnimSpeed()
    local dir = self:GetForward()

    local enemy = self:GetEnemy()
    if IsValid( enemy )
        and self:GetPos():Distance( enemy:GetPos() ) < 1.4 * UNIT then
      self.loco:SetVelocity( vector_origin )
      return
    end

    if self:UKM_IsLedgeSafe( dir ) then
      self.loco:SetDesiredSpeed( spd )
      self.loco:Approach( self:GetPos() + dir * 100, 1 )
      self.loco:SetVelocity( Vector( dir.x * spd, dir.y * spd, self.loco:GetVelocity().z ) )
    else
      self.loco:SetVelocity( vector_origin )
    end
  end

  function ENT:UKM_IsLedgeSafe( dir )
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
  -- Projectile (canon ChargeProjectile / ShootProjectile)
  ------------------------------------------------------------------------------

  function ENT:UKM_StartChargeFX()
    local id = self:LookupAttachment( "shootpoint" )
    if id and id > 0 then
      -- signature: ParticleEffectAttach( name, attachType, entity, attachmentID )
      ParticleEffectAttach( "Ultrakill_HomingOrb", PATTACH_POINT_FOLLOW, self, id )
    end
    self:EmitSound( UKMannequin.SOUND.ProjCharge, 75, 100, 0.5 )
    self:EmitSound( UKMannequin.SOUND.ProjTwirl, 70, 100, 0.6 )
  end

  function ENT:UKM_StopChargeFX()
    self:StopParticles()
    self:StopSound( UKMannequin.SOUND.ProjCharge )
    self:StopSound( UKMannequin.SOUND.ProjTwirl )
  end

  function ENT:UKM_ShootProjectile()
    local enemy = self:GetEnemy()
    local pos = self:UKM_ShootPos()

    -- ready-made blue hell seeker from the act1 dep (tuned 2026-07-03)
    local proj = ents.Create( UKMannequin.CLASS.Projectile )
    if not IsValid( proj ) then return end

    local aim = self:GetForward()
    if IsValid( enemy ) then
      local eyes = enemy.EyePos and enemy:EyePos() or enemy:WorldSpaceCenter()
      aim = ( eyes - pos ):GetNormalized()
    elseif self:IsPossessed() then
      -- no lock-on: shoot at the possessor crosshair
      aim = ( self:PossessorTrace().HitPos - pos ):GetNormalized()
    end

    proj:SetPos( pos )
    proj:SetAngles( aim:Angle() )
    proj:SetOwner( self )
    proj:Spawn()
    -- canon Mannequin: turningSpeedMultiplier 0.75 below VIOLENT, 1.0 otherwise
    -- (override the mindflayer default 1.5 after Spawn — read every think)
    proj.UltrakillBase_HomingTurningMultiplier =
      self:UKM_GetDifficulty() <= 2 and 0.75 or 1.0
    if IsValid( enemy ) and proj.SetEnemy then proj:SetEnemy( enemy ) end
  end

  -- canon ProjectileAttack(): cooldown Random(6-diff, 8-diff)
  function ENT:UKM_StartProjectileAttack()
    local diff = self:UKM_GetDifficulty()
    self.UKM_ProjCD = math.Rand( 6 - diff, 8 - diff )
    if self.UKM_Clinging then
      self.UKM_AttacksWhileClinging = self.UKM_AttacksWhileClinging + 1
      self:UKM_StartAction( "WallClingProjectile" )
    else
      self:UKM_StartAction( "ProjectileAttack" )
    end
  end

  ------------------------------------------------------------------------------
  -- Cling (canon ClingToSurface / RelocateWhileClinging / Uncling)
  ------------------------------------------------------------------------------

  -- AABB covering the model when its up-axis is the surface normal (the hull
  -- cannot rotate — without this a ceiling cling leaves the hull inside the
  -- ceiling and the hanging body is untraceable/unshootable).
  local CLING_HEIGHT = 112
  local CLING_MARGIN = 24

  function ENT:UKM_ApplyClingBounds( n )
    local ext = n * CLING_HEIGHT
    local mins = Vector(
      math.min( 0, ext.x ) - CLING_MARGIN,
      math.min( 0, ext.y ) - CLING_MARGIN,
      math.min( 0, ext.z ) - CLING_MARGIN )
    local maxs = Vector(
      math.max( 0, ext.x ) + CLING_MARGIN,
      math.max( 0, ext.y ) + CLING_MARGIN,
      math.max( 0, ext.z ) + CLING_MARGIN )
    self:SetCollisionBounds( mins, maxs )
    self:SetSurroundingBounds( mins * 1.4, maxs * 1.4 )
  end

  function ENT:UKM_RestoreBounds()
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    local sb = self.SurroundingBounds
    self:SetSurroundingBounds( Vector( -sb.x, -sb.y, 0 ), Vector( sb.x, sb.y, sb.z ) )
  end

  function ENT:UKM_ClingToSurface( hitPos, hitNormal )
    self:UKM_CancelAction()
    self.UKM_CanCling = false
    self.UKM_Clinging = true
    self.UKM_Jumping = false -- the leap is over once attached (bugfix:
    -- a stuck flag suppressed every post-attack relocation on the surface)
    self.UKM_SkitterMode = false
    self.UKM_ClingNormal = hitNormal
    self.UKM_ClingPos = hitPos
    self.UKM_ClingMoveTarget = nil

    self.CantMove = true
    self:SetMaxYawRate( 0 )
    self.UKM_LocoGravity = self.loco:GetGravity()
    self.loco:SetGravity( 0 )
    self.loco:SetVelocity( vector_origin )
    self:SetPos( hitPos )
    self:UKM_ApplyClingBounds( hitNormal )
    self:UKM_ClingOrient()
    if self.UKM_ClingAngles then self:SetAngles( self.UKM_ClingAngles ) end

    -- DrGBase re-uprights the bot every frame; win by re-applying pos/angles
    -- in a Tick hook that runs AFTER all entity thinks.
    local hookName = "UKMannequin_Cling_" .. self:EntIndex()
    self.UKM_ClingHook = hookName
    local ent = self
    hook.Add( "Tick", hookName, function()
      if not IsValid( ent ) or not ent.UKM_Clinging then
        hook.Remove( "Tick", hookName )
        return
      end
      if ent.UKM_ClingPos then ent:SetPos( ent.UKM_ClingPos ) end
      if ent.UKM_ClingAngles then ent:SetAngles( ent.UKM_ClingAngles ) end
      ent.loco:SetVelocity( vector_origin )
    end )

    if not self.UKM_FirstClingCheck then
      sound.Play( UKMannequin.SOUND.Cling, hitPos, 75, math.random( 95, 105 ), 0.4 )
    end

    -- canon: projectileCooldown = Random(0, 0.5) on cling
    self.UKM_ProjCD = math.Rand( 0, 0.5 )
  end

  function ENT:UKM_ClingOrient()
    local n = self.UKM_ClingNormal
    if not n then return end
    local enemy = self:GetEnemy()
    local fwd
    if IsValid( enemy ) then
      local to = enemy:GetPos() - self:GetPos()
      fwd = ( to - n * to:Dot( n ) )
    end
    if not fwd or fwd:LengthSqr() < 1 then
      fwd = n:Cross( math.abs( n.z ) < 0.9 and Vector( 0, 0, 1 ) or Vector( 1, 0, 0 ) )
    end
    fwd:Normalize()
    -- model up-axis = surface normal, facing the target along the surface
    self.UKM_ClingAngles = fwd:AngleEx( n )
  end

  -- DrGBase re-flattens EVERY angle change to yaw-only via its OnAngleChange
  -- callback (misc.lua: SetAngles(Angle(0, y, 0))) unless this hook returns
  -- true. Without it the cling pitch/roll get wiped right after we set them,
  -- leaving the model upright — buried inside the wall/ceiling brush.
  function ENT:OnAngleChange()
    if self.UKM_Clinging then return true end
  end

  -- canon EvaluateMaxClingWalkDistance: 1.5 m surface-following steps, max 20 m
  function ENT:UKM_MaxClingWalk( origin, dir )
    local n = self.UKM_ClingNormal
    local step = 1.5 * UNIT
    local dist = 0
    local pos = origin
    while dist < 20 * UNIT do
      local probe = pos + n * ( 1.25 * UNIT )
      local tr = util.TraceLine( {
        start = probe, endpos = probe - n * ( 2.5 * UNIT ),
        mask = MASK_SOLID_BRUSHONLY, filter = self,
      } )
      if not tr.Hit or tr.HitNormal:Dot( n ) < 0.996 then
        return math.max( dist - step * 1.5, 0 )
      end
      local blocked = util.TraceLine( {
        start = probe - dir * 4, endpos = probe + dir * ( step * 1.25 ),
        mask = MASK_SOLID_BRUSHONLY, filter = self,
      } )
      if blocked.Hit then
        return math.max( dist - step * 1.5, 0 )
      end
      dist = dist + step
      pos = pos + dir * step
    end
    return math.max( dist - step * 1.5, 0 )
  end

  function ENT:UKM_RelocateWhileClinging( horizontal )
    local n = self.UKM_ClingNormal
    if not n then return end
    local t1
    if math.abs( n:Dot( Vector( 0, 0, 1 ) ) ) < 0.99 then
      t1 = n:Cross( Vector( 0, 0, 1 ) )
    else
      t1 = n:Cross( Vector( 1, 0, 0 ) )
    end
    t1:Normalize()
    local t2 = n:Cross( t1 )
    t2:Normalize()
    local dir = horizontal and t1 or t2

    local pos = self:GetPos()
    local maxPos = self:UKM_MaxClingWalk( pos, dir )
    local maxNeg = self:UKM_MaxClingWalk( pos, -dir )
    local d = math.Rand( -maxNeg, maxPos )
    if math.abs( d ) <= 2 * UNIT then return end

    -- canon bump correction: snap the target back onto the surface
    local target = pos + dir * d
    local snap = util.TraceLine( {
      start = target + n * ( 1.25 * UNIT ), endpos = target - n * ( 1.25 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    if snap.Hit then target = snap.HitPos end

    self.UKM_ClingMoveTarget = target
    self.UKM_SkitterMode = true
  end

  function ENT:UKM_Uncling()
    self.UKM_Clinging = false
    if self.UKM_ClingHook then
      hook.Remove( "Tick", self.UKM_ClingHook )
      self.UKM_ClingHook = nil
    end
    self:UKM_RestoreBounds()
    self.UKM_ClingAngles = nil
    self:UKM_CancelAction()

    local n = self.UKM_ClingNormal or Vector( 0, 0, 1 )
    local offset = Vector( n.x * 2 * UNIT, n.y * 2 * UNIT, n.z * 6 * UNIT )
    if math.abs( offset.z ) < 6 * UNIT then
      local up = util.TraceLine( {
        start = self:WorldSpaceCenter(),
        endpos = self:WorldSpaceCenter() + Vector( 0, 0, 4 * UNIT ),
        mask = MASK_SOLID_BRUSHONLY, filter = self,
      } )
      if up.Hit then offset.z = -6 * UNIT end -- canon: full 6 m downward pop
    end

    self:SetPos( self:GetPos() + offset )

    local enemy = self:GetEnemy()
    local yaw = self:GetAngles().yaw
    if IsValid( enemy ) then
      yaw = ( enemy:GetPos() - self:GetPos() ):Angle().yaw
    end
    self:SetAngles( Angle( 0, yaw, 0 ) )

    self.UKM_ClingNormal = nil
    self.UKM_ClingPos = nil
    self.UKM_ClingMoveTarget = nil
    self.UKM_JumpCD = 2
    self.UKM_SkitterMode = false
    self.UKM_AttacksWhileClinging = 0
    self.CantMove = false
    self:SetMaxYawRate( self.MaxYawRate )
    if self.UKM_LocoGravity then self.loco:SetGravity( self.UKM_LocoGravity ) end

    if self.UKM_InControl then
      self.loco:SetVelocity( Vector( 0, 0, -50 * UNIT ) )
    end
  end

  function ENT:UKM_ClingThink( enemy )
    -- surface walk (canon 30 m/s MoveTowards)
    if self.UKM_ClingMoveTarget and not self:UKM_InAction() then
      local dt = FrameTime()
      local pos = self:GetPos()
      local to = self.UKM_ClingMoveTarget - pos
      local step = 30 * UNIT * dt
      if to:Length() <= step then
        self:SetPos( self.UKM_ClingMoveTarget )
        self.UKM_ClingPos = self.UKM_ClingMoveTarget
        self.UKM_ClingMoveTarget = nil
        self.UKM_SkitterMode = false
        -- canon: reached the floor while cling-walking -> hop off
        local down = util.TraceLine( {
          start = self:GetPos(), endpos = self:GetPos() - Vector( 0, 0, 3 * UNIT ),
          mask = MASK_SOLID_BRUSHONLY, filter = self,
        } )
        if down.Hit then
          self.UKM_InControl = true
          self:UKM_Uncling()
          return
        end
      else
        local newPos = pos + to:GetNormalized() * step
        self:SetPos( newPos )
        self.UKM_ClingPos = newPos
      end
    elseif self.UKM_ClingPos then
      self:SetPos( self.UKM_ClingPos ) -- kinematic pin (canon rb.isKinematic)
    end
    self.loco:SetVelocity( vector_origin )

    -- canon trackTarget while clinging: rotate around the surface normal
    if IsValid( enemy ) then self:UKM_ClingOrient() end

    -- canon SlowUpdate cling branch
    if IsValid( enemy ) and self:UKM_UpdateVision( enemy ) then
      if self.UKM_ProjCD <= 0 and not self.UKM_ClingMoveTarget
          and not self:UKM_InAction() then
        self:UKM_StartProjectileAttack()
      end
    elseif not self:UKM_InAction() then
      -- lost sight -> drop deliberately, chase again
      self.UKM_InControl = true
      self:UKM_Uncling()
    end
  end

  -- canon CheckClings (airborne)
  function ENT:UKM_CheckClings()
    local first = self.UKM_FirstClingCheck
    self.UKM_FirstClingCheck = false
    local center = self:WorldSpaceCenter()

    -- small anti-tunnel lookahead only (~one think of travel, capped 3 m):
    -- a big velocity-scaled probe visibly teleported the bot to the ceiling
    local vel0 = self.loco:GetVelocity()
    local upLen = ( first and 9.5 or 7 ) * UNIT
      + math.min( math.max( 0, vel0.z ) * 0.1, 3 * UNIT )
    local up = util.TraceLine( {
      start = self:GetPos(), endpos = self:GetPos() + Vector( 0, 0, upLen ),
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    if up.Hit and up.HitNormal.z <= 0 then
      self:UKM_ClingToSurface( up.HitPos, up.HitNormal )
      return
    end

    local vel = self.loco:GetVelocity()
    local hvel = Vector( vel.x, vel.y, 0 )
    if first or hvel:Length() > 3 * UNIT then
      local dir = hvel:LengthSqr() > 1 and hvel:GetNormalized() or self:GetForward()
      local side = util.TraceLine( {
        start = center, endpos = center + dir * ( ( first and 3.5 or 2 ) * UNIT ),
        mask = MASK_SOLID_BRUSHONLY, filter = self,
      } )
      if side.Hit and math.abs( side.HitNormal.z ) < 0.7 then
        self:UKM_ClingToSurface( side.HitPos, side.HitNormal )
      end
    end
  end

  -- canon Update wall-cling while running (RunAway/Wander only, never mid-action)
  function ENT:UKM_CheckRunningCling()
    if self:UKM_InAction() then return end
    if self.UKM_Behavior ~= "RunAway" and self.UKM_Behavior ~= "Wander" then return end
    local vel = self.loco:GetVelocity()
    local hvel = Vector( vel.x, vel.y, 0 )
    if hvel:Length() < 2 * UNIT then return end

    local origin = self:WorldSpaceCenter() + Vector( 0, 0, 0.5 * UNIT )
    local dir = hvel:GetNormalized()
    local fwd = util.TraceLine( {
      start = origin, endpos = origin + dir * ( 6 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    if not fwd.Hit or math.abs( fwd.HitNormal.z ) > 0.7 then return end

    -- canon: tight-space check — both side probes must be clear
    local left = dir:Angle():Right() * -1
    for _, side in ipairs( { left, -left } ) do
      local tr = util.TraceLine( {
        start = origin, endpos = origin + side * ( 2 * UNIT ),
        mask = MASK_SOLID_BRUSHONLY, filter = self,
      } )
      if tr.Hit then return end
    end

    self.UKM_ClingMoveTarget = nil
    self:UKM_ClingToSurface( fwd.HitPos, fwd.HitNormal )
    self:UKM_RelocateWhileClinging( false ) -- canon: Vertical after a running cling
  end

  ------------------------------------------------------------------------------
  -- Jump behavior (canon: leap up to a ceiling with LOS to the target)
  ------------------------------------------------------------------------------

  function ENT:UKM_TryJump( enemy )
    if self.UKM_JumpCD > 0 or not self.UKM_CanCling then return false end

    local up = util.TraceLine( {
      start = self:GetPos() + Vector( 0, 0, UNIT ),
      endpos = self:GetPos() + Vector( 0, 0, 41 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    if not up.Hit then return false end

    -- canon: the spot 3 m below the ceiling must see the target
    local probe = up.HitPos - Vector( 0, 0, 3 * UNIT )
    local tpos = enemy:WorldSpaceCenter()
    local los = util.TraceLine( {
      start = probe, endpos = tpos,
      mask = MASK_SHOT, filter = { self, enemy },
    } )
    if los.Hit then return false end

    self.UKM_JumpCD = 2
    self:UKM_StartAction( "Jump" )
    return true
  end

  ------------------------------------------------------------------------------
  -- Parry (base framework: flash + Ultrakill_Parry + HitStop; wiki: parrying
  -- either melee swing instantly kills the Mannequin)
  ------------------------------------------------------------------------------

  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    self:UKM_CancelAction()
    -- wiki instakill: let the boosted damage kill outright
    dmg:SetDamage( self:Health() + self:GetMaxHealth() )
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKM_Dead then return end

    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier

    -- canon: the projectile charge-up can be interrupted (Breakable ball);
    -- canon CancelActions rerolls the behavior afterwards
    if self.UKM_Charging then
      self:UKM_CancelAction()
      self:UKM_ChangeBehavior( false )
    end

    -- wiki: hitting a clinging Mannequin knocks it to the ground (stun on land)
    if self.UKM_Clinging then
      self.UKM_InControl = false
      self:UKM_Uncling()
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Animation / speed
  ------------------------------------------------------------------------------

  -- Locomotion clips are authored for canon speeds (Walk = 16 m/s, Skitter =
  -- 64 m/s at rate 1.0). Playing them at a fixed rate while the loco moves at
  -- profile speeds makes the feet ice-skate — scale playback by actual ground
  -- speed instead. This also reproduces canon anim.speed per difficulty.
  local WALK_ANIM_REF = 16 * UNIT
  local SKITTER_ANIM_REF = 64 * UNIT

  function ENT:OnUpdateAnimation()
    local spd = self:UKM_AnimSpeed()

    if self.UKM_ActionName and self:UKM_InAction() then
      return self.UKM_ActionCfg.seq, spd
    end

    if self.UKM_Clinging then
      -- surface skitter: pace the crawl clip too
      if self.UKM_ClingMoveTarget then
        return "Skitter", math.Clamp( ( 30 * UNIT ) / SKITTER_ANIM_REF, 0.6, 2.8 )
      end
      return "WallCling", spd
    end

    if not self:IsOnGround() then
      return self.UKM_InControl and "FallingControlled" or "Falling", spd
    end

    local speed = self.loco:GetVelocity():Length()
    if speed > 3 * UNIT then
      if self.UKM_SkitterMode then
        return "Skitter", math.Clamp( speed / SKITTER_ANIM_REF, 0.6, 2.8 )
      end
      return "Walk", math.Clamp( speed / WALK_ANIM_REF, 0.5, 2.0 )
    end
    return self.UKM_SkitterMode and "SkitterIdle" or "Idle", spd
  end

  function ENT:OnUpdateSpeed()
    if self:UKM_InAction() or self.UKM_Clinging then return 0 end
    local prof = self:UKM_Profile()
    return self.UKM_SkitterMode and prof.skitter or prof.walk
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are driven by the canon SlowUpdate tree in CustomThink
    return
  end

  ------------------------------------------------------------------------------
  -- Movement decision (canon SlowUpdate ground branch)
  ------------------------------------------------------------------------------

  function ENT:UKM_GroundDecision( enemy, hasVision )
    local dist = self:GetPos():Distance( enemy:GetPos() )

    -- melee first (canon: dist < 5 m, cooldown ready)
    if self.UKM_MeleeCD <= 0 and dist < UKMannequin.MELEE_RANGE then
      self.UKM_MeleeCD = UKMannequin.MELEE_COOLDOWN
      self:UKM_StartAction( "MeleeAttack" )
      return
    end

    -- canon: Melee behavior or no LOS -> chase (forced skitter)
    if self.UKM_Behavior == "Melee" or not hasVision then
      self.UKM_MoveTarget = nil
      self.CantMove = false
      self.UKM_SkitterMode = true
      return
    end

    -- canon: LOS + projectile ready -> shoot
    if self.UKM_ProjCD <= 0 then
      self:UKM_StartProjectileAttack()
      return
    end

    -- canon: very far -> close in (stop 40 m short is irrelevant at GMod scales)
    if dist > 50 * UNIT then
      self.UKM_MoveTarget = nil
      self.CantMove = false
      self.UKM_SkitterMode = true
      return
    end

    -- canon RunAway: back off when closer than 15 m
    if self.UKM_Behavior == "RunAway" and dist < 15 * UNIT then
      local away = ( self:GetPos() - enemy:GetPos() )
      away.z = 0
      away:Normalize()
      self:UKM_SetMoveTarget( away, ( 20 * UNIT ) - dist )
      return
    end

    -- canon Jump: leap to the ceiling
    if self.UKM_Behavior == "Jump" and self:UKM_TryJump( enemy ) then
      return
    end

    -- canon Wander: random surface targets
    if not self.UKM_MoveTarget
        or self:GetPos():Distance( self.UKM_MoveTarget ) < 5 * UNIT then
      local dir = VectorRand()
      dir.z = 0
      if dir:LengthSqr() < 0.01 then dir = self:GetForward() end
      dir:Normalize()
      self:UKM_SetMoveTarget( dir, math.Rand( 5, 25 ) * UNIT )
    end
  end

  -- canon SetMovementTarget: raycast-validated point in a direction
  function ENT:UKM_SetMoveTarget( dir, dist )
    local origin = self:WorldSpaceCenter()
    local tr = util.TraceLine( {
      start = origin, endpos = origin + dir * dist,
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    local target = tr.Hit and tr.HitPos - dir * UNIT or origin + dir * dist
    -- project onto the ground
    local down = util.TraceLine( {
      start = target, endpos = target - Vector( 0, 0, 500 ),
      mask = MASK_SOLID_BRUSHONLY, filter = self,
    } )
    if down.Hit then target = down.HitPos end

    self.UKM_MoveTarget = target
    -- canon MoveToTarget: skitter if far or high difficulty
    local d = self:GetPos():Distance( target )
    self.UKM_SkitterMode = ( self:UKM_GetDifficulty() >= 3 or math.Rand( 0, 1 ) > 0.5 )
      and d > 15 * UNIT
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKM_Dead then return end
    if self:IsAIDisabled() and not self:IsPossessed() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = now - ( self.UKM_LastThink or now )
    self.UKM_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    -- canon Update cooldown ticking
    if self.UKM_MeleeCD > 0 then self.UKM_MeleeCD = math.max( self.UKM_MeleeCD - dt, 0 ) end
    if self.UKM_ProjCD > 0 then self.UKM_ProjCD = math.max( self.UKM_ProjCD - dt, 0 ) end
    if self.UKM_JumpCD > 0 then self.UKM_JumpCD = math.max( self.UKM_JumpCD - dt, 0 ) end

    -- canon: Melee behavior self-cancels after 3.5 s
    if self.UKM_Behavior == "Melee" and not self:UKM_InAction() then
      self.UKM_MeleeBehaviorCancel = math.max( self.UKM_MeleeBehaviorCancel - dt, 0 )
      if self.UKM_MeleeBehaviorCancel <= 0 then
        self:UKM_ChangeBehavior( true )
      end
    end

    local enemy = self:GetEnemy()
    local grounded = self:IsOnGround()

    -- landing / fall bookkeeping (canon OnLand)
    if self.UKM_Clinging then
      self.UKM_AirSince = nil
    elseif not grounded then
      self.UKM_AirSince = self.UKM_AirSince or now
      self.UKM_FallSpeed = math.max( self.UKM_FallSpeed or 0,
        -self.loco:GetVelocity().z )
      -- canon OnFall: falling cancels a running ground action
      if self:UKM_InAction() and not self.UKM_Jumping and not self.UKM_InControl then
        self:UKM_CancelAction()
      end
      if self.UKM_CanCling and not self:IsPossessed() then
        self:UKM_CheckClings()
      end
    else
      if self.UKM_AirSince then
        local fallTime = now - self.UKM_AirSince
        self.UKM_AirSince = nil
        self.UKM_Jumping = false
        self.UKM_MoveTarget = nil

        -- fall damage (canon prefab is noFallDamage, override 2026-07-03)
        local impact = self.UKM_FallSpeed or 0
        self.UKM_FallSpeed = 0
        if impact > 700 then
          local dmg = DamageInfo()
          dmg:SetDamage( ( impact - 700 ) * 6 )
          dmg:SetDamageType( DMG_FALL )
          dmg:SetAttacker( game.GetWorld() )
          dmg:SetInflictor( game.GetWorld() )
          dmg:SetDamagePosition( self:GetPos() )
          self:TakeDamageInfo( dmg )
          if not IsValid( self ) or self:Health() <= 0 then return end
        end

        if fallTime > 0.2 then
          -- body-fall splat (2026-07-03: "после падения нет звука шлепка")
          self:EmitSound( "physics/flesh/flesh_impact_hard"
            .. math.random( 1, 6 ) .. ".wav", 78, math.random( 90, 110 ), 1 )
          -- canon Landing: stun unless in control (Brutal+ is always in control)
          if self:UKM_GetDifficulty() >= 4 then self.UKM_InControl = true end
          if not self.UKM_InControl then
            self.UKM_InControl = true
            self:UKM_StartAction( "Landing" )
          end
        else
          self.UKM_InControl = true
        end
      end
      -- canon: firstClingCheck is one-shot per lifetime, NOT reset on landing
      self.UKM_CanCling = true
    end

    -- skitter loop sound (canon: plays while skittering fast)
    local movingFast = self.loco:GetVelocity():Length() > 3 * UNIT
    local wantSkitterSound = ( self.UKM_SkitterMode and movingFast )
      or ( self.UKM_Clinging and self.UKM_ClingMoveTarget ~= nil )
    if wantSkitterSound and not self.UKM_SkitterPlaying then
      self.UKM_SkitterSound:PlayEx( 0.65, math.random( 90, 110 ) )
      self.UKM_SkitterPlaying = true
    elseif not wantSkitterSound and self.UKM_SkitterPlaying then
      self.UKM_SkitterSound:Stop()
      self.UKM_SkitterPlaying = false
    end

    if self:IsPossessed() then
      -- the cling Tick pin and Wander/RunAway move targets fight the
      -- possessor's movement; running actions still execute below
      if self.UKM_Clinging then
        self.UKM_InControl = true
        self:UKM_Uncling()
      end
      if self.UKM_MoveTarget then
        self.UKM_MoveTarget = nil
        if not self:UKM_InAction() then self.CantMove = false end
      end
    elseif not IsValid( enemy ) then
      if self:UKM_InAction() then self:UKM_CancelAction() end
      if self.UKM_Clinging then
        self.UKM_InControl = true
        self:UKM_Uncling()
      end
      self.UKM_MoveTarget = nil
      self.UKM_SkitterMode = false
      return
    end

    -- clinging is its own control mode
    if self.UKM_Clinging then
      if self:UKM_InAction() then self:UKM_ProcessEvents() end
      self:UKM_ClingThink( enemy )
      return
    end

    if self.UKM_ActionName then
      self:UKM_ProcessEvents()
    end

    if self:UKM_InAction() then
      -- canon trackTarget: fast proportional turn toward the target
      if self.UKM_Tracking then
        self:SetMaxYawRate( 900 * self:UKM_AnimSpeed() )
        local aimPos
        if IsValid( enemy ) then
          aimPos = enemy:GetPos()
        elseif self:IsPossessed() then
          -- no lock-on: the possessor view steers the swing/aim
          aimPos = self:GetPos() + self:PossessorNormal() * 100
        end
        if aimPos then
          local dir = aimPos - self:GetPos()
          dir.z = 0
          if dir:LengthSqr() > 1 then
            self:FaceTowards( self:GetPos() + dir )
          end
        end
      else
        self:SetMaxYawRate( 0 )
      end

      self:UKM_ApplyDash()
      self:UKM_ApplyMeleeDamage()
      return
    end

    -- possessed: no autonomous decisions; attack starts come from the binds
    if self:IsPossessed() then
      self:UKM_UpdateFootsteps()
      return
    end

    local hasVision = self:UKM_UpdateVision( enemy )

    -- canon SlowUpdate cadence
    self.UKM_SlowTick = self.UKM_SlowTick + dt
    if self.UKM_SlowTick >= 0.25 and grounded then
      self.UKM_SlowTick = 0
      self:UKM_GroundDecision( enemy, hasVision )
    end

    -- manual movement leg (Wander/RunAway targets) — driven-loco recipe
    if self.UKM_MoveTarget and grounded then
      self.CantMove = true
      local to = self.UKM_MoveTarget - self:GetPos()
      to.z = 0
      if to:Length() < 1 * UNIT then
        self.UKM_MoveTarget = nil
        self.CantMove = false
      else
        local prof = self:UKM_Profile()
        local speed = self.UKM_SkitterMode and prof.skitter or prof.walk
        self:SetMaxYawRate( self.MaxYawRate )
        self:FaceTowards( self.UKM_MoveTarget )
        self.loco:SetDesiredSpeed( speed )
        self.loco:Approach( self.UKM_MoveTarget, 1 )
      end
    elseif not self.UKM_MoveTarget and not self:UKM_InAction() then
      self.CantMove = false
    end

    -- canon Update: running into a wall in RunAway/Wander -> cling
    if grounded and self.UKM_CanCling then
      self:UKM_CheckRunningCling()
    end

    self:UKM_UpdateFootsteps()
  end

  ------------------------------------------------------------------------------
  -- Footsteps (two-legged walk only; the skitter has its own loop sound)
  ------------------------------------------------------------------------------

  local WALK_STEPS = { 0.25, 0.75 }

  function ENT:UKM_UpdateFootsteps()
    if self:UKM_InAction() or self.UKM_Clinging then return end
    local seqName = self:GetSequenceName( self:GetSequence() ) or ""
    if seqName ~= "Walk" then return end

    local cycle = self:GetCycle()
    local last = self.UKM_LastWalkCycle or 0
    for _, mark in ipairs( WALK_STEPS ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) )
      if crossed then
        self:EmitSound( "physics/body/body_medium_impact_soft"
          .. math.random( 1, 7 ) .. ".wav", 70, math.random( 96, 108 ), 0.45 )
        break
      end
    end
    self.UKM_LastWalkCycle = cycle
  end

  ------------------------------------------------------------------------------
  -- Death (canon OnGoLimp: instant gib + blood, breathing continues from the head)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKM_Dead = true
    self:UKM_StopChargeFX()
    if self.UKM_ClingHook then
      hook.Remove( "Tick", self.UKM_ClingHook )
      self.UKM_ClingHook = nil
    end
    if self.UKM_BreathSound then self.UKM_BreathSound:Stop() end
    if self.UKM_SkitterSound then self.UKM_SkitterSound:Stop() end

    local headPos = self:UKM_HeadPos()
    local center = self:WorldSpaceCenter()
    local baseVel = self.loco:GetVelocity() * 0.5
    local force = dmg and dmg:GetDamageForce() or vector_origin
    if force:LengthSqr() > 1 then
      force = force:GetNormalized() * math.min( force:Length() * 0.02, 300 )
    end

    -- canon OnGoLimp: the Mannequin shatters into its own pieces, every gib
    -- fragment sprays blood (wiki trivia)
    for _, gib in ipairs( UKMannequin.GIBS ) do
      local boneId = self:LookupBone( gib.bone )
      local pos, ang = center, self:GetAngles()
      if boneId then
        local bp, ba = self:GetBonePosition( boneId )
        if bp then pos, ang = bp, ba end
      end

      local prop = ents.Create( "prop_physics" )
      if not IsValid( prop ) then continue end
      prop:SetModel( gib.model )
      prop:SetPos( pos )
      prop:SetAngles( ang )
      prop:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
      prop:Spawn()

      local phys = prop:GetPhysicsObject()
      if IsValid( phys ) then
        phys:SetVelocity( baseVel + force
          + ( pos - center ):GetNormalized() * math.Rand( 100, 260 )
          + VectorRand() * 80 + Vector( 0, 0, math.Rand( 80, 200 ) ) )
        phys:AddAngleVelocity( VectorRand() * 360 )
      end

      -- blood spray from each fragment for a couple of seconds + floor decals
      local sprays = 6
      local tname = "UKMannequinGib" .. prop:EntIndex()
      timer.Create( tname, 0.35, sprays, function()
        if not IsValid( prop ) then timer.Remove( tname ) return end
        local gpos = prop:WorldSpaceCenter()
        local fx = EffectData()
        fx:SetOrigin( gpos )
        fx:SetMagnitude( 2 )
        fx:SetScale( 2 )
        fx:SetFlags( 3 )
        util.Effect( "bloodspray", fx, true, true )
        util.Decal( "Blood", gpos, gpos - Vector( 0, 0, 64 ), prop )
      end )

      SafeRemoveEntityDelayed( prop, 12 )
    end

    -- central burst + splatter decals around the death spot
    for i = 1, 8 do
      local fx = EffectData()
      fx:SetOrigin( center + VectorRand() * math.Rand( 0, 24 ) )
      fx:SetMagnitude( 2.5 )
      fx:SetScale( 2.5 )
      fx:SetFlags( 3 )
      util.Effect( "bloodspray", fx, true, true )
    end
    local imp = EffectData()
    imp:SetOrigin( center )
    util.Effect( "BloodImpact", imp, true, true )
    for i = 1, 6 do
      local dir = VectorRand()
      dir.z = -math.abs( dir.z ) - 0.5
      util.Decal( "Blood", center, center + dir:GetNormalized() * 140, self )
    end

    -- canon trivia: the head keeps breathing after death
    local breather = ents.Create( "base_anim" )
    if IsValid( breather ) then
      breather:SetPos( headPos )
      breather:SetNoDraw( true )
      breather:SetNotSolid( true )
      breather:Spawn()
      breather:EmitSound( UKMannequin.SOUND.Breathing, 65, math.random( 92, 108 ), 0.3 )
      SafeRemoveEntityDelayed( breather, 25 )
    end

    self:Remove()
    return dmg
  end

end

DrGBase.AddNextbot( ENT )
