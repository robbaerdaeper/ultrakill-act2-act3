AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_insurrectionist_shared.lua" )

-- Sisyphean Insurrectionist (Supreme Husk). Full canon port of Sisyphus.cs:
--   * cooldown system (2 s STANDARD, x3 depletion inside 10 m, 3 s on spawn)
--   * Stomp inside 8 m; Jump after 2-3 attacks / beyond 100 m (landing
--     PhysicalShockwave ring 25 dmg + crushes enemies it lands on)
--   * 4 boulder attacks with canon trajectories and clip-event timings:
--     OverheadSlam / HorizontalSwing / GroundStab / AirStab (self-pull + drop)
--   * boulder = separate parryable Cannonball entity; a parried boulder that
--     hits its owner deals 22 dmg and knocks it down (0.85 s / 4 s in air)
--   * canon locational damage: limbs x1.5, no head; the Malicious-Face mace
--     soaks bullets for free (hitgroup 9 = 0 damage); fire weakness x2
--   * death: scream, body bursts into gore, both legs detach as physics gibs

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Sisyphean Insurrectionist"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKSisy.MODEL }
ENT.ModelScale = 0.95 -- tuned 2026-07-07: slightly smaller than canon
ENT.SpawnHealth = UKSisy.HP
-- canon CapsuleCollider r 2.5 m h 12 m, scaled with ModelScale
ENT.CollisionBounds = Vector( 38, 38, 228 ) -- 2026-07-10: model rescaled x0.5 (Kevin-scale)
ENT.SurroundingBounds = Vector( 300, 300, 320 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy"

ENT.UKSisy_IsSisy = true -- own explosions never hurt Insurrectionists

local UNIT = UKSisy.UNIT
local CLIP = UKSisy.CLIP
local DETAILS = UKSisy.DETAILS

ENT.MeleeAttackRange = UKSisy.STOMP_RANGE * UNIT
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = UKSisy.STOP_DISTANCE
ENT.AvoidEnemyRange = 0

-- canon NavMeshAgent: speed 10 m/s, accel 666 m/s^2 (~instant), angular 999
ENT.Acceleration = 666 * UNIT
ENT.Deceleration = 666 * UNIT
ENT.WalkSpeed = UKSisy.MOVE_SPEED
ENT.RunSpeed = UKSisy.MOVE_SPEED
ENT.MaxYawRate = 400
ENT.JumpHeight = 120
ENT.StepHeight = 40
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Walking"
ENT.WalkAnimRate = UKSisy.WALK_ANIM_RATE
ENT.RunAnimation = "Walking"
ENT.RunAnimRate = UKSisy.WALK_ANIM_RATE
ENT.JumpAnimation = "Jump"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Jump"
ENT.FallingAnimRate = 1

-- attack ids follow the canon enum
local ATK_OVERHEAD, ATK_HORIZONTAL, ATK_STAB, ATK_AIRSTAB = 0, 1, 2, 3
local ATK_NAME = {
  [ATK_OVERHEAD] = "overheadslam",
  [ATK_HORIZONTAL] = "horizontalswing",
  [ATK_STAB] = "stab",
  [ATK_AIRSTAB] = "airstab",
}
local ATK_VOICE = {
  [ATK_OVERHEAD] = "AttackOverhead",
  [ATK_HORIZONTAL] = "AttackHorizontal",
  [ATK_STAB] = "AttackStab",
  [ATK_AIRSTAB] = "AttackAirStab",
}
-- canon RotateTowardsTarget trackingY per attack (yaw only; X is body pitch)
local ATK_TRACKY = {
  [ATK_OVERHEAD] = 0.15,
  [ATK_HORIZONTAL] = 1.0,
  [ATK_STAB] = 0.5,
  [ATK_AIRSTAB] = 0.9,
}

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_1DIR

ENT.PossessionViews = {

  {
    offset = Vector( 0, 40, 115 ),
    distance = 380,
    eyepos = false,
  },

  {
    -- no EyeBone on this model: EyePos falls back to the hull center, so the
    -- offset lifts the camera to head height (~210 su on the 228 su hull)
    offset = Vector( 20, 0, 95 ),
    distance = 0,
    eyepos = true,
  },

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKS_Dead or self.UKS_Cooldown > 0 then return end

    -- airborne (mid possessed jump or a plain fall): canon Air Stab, its
    -- player-homing replaced by the point under the crosshair
    if self.UKS_Airborne == "jump"
        or ( not self.UKS_Airborne and not self:UKS_InAction()
          and not self:IsOnGround() ) then
      self.UKS_Cooldown = UKSisy.AttackCooldown( self:UKS_GetDifficulty() )
      self.UKS_PreviousAttack = ATK_AIRSTAB
      self.UKS_PreviouslyJumped = false
      self.UKS_AttacksPerformed = self.UKS_AttacksPerformed + 1
      self:UKS_StartPossessAirStab()
      return
    end

    if self:UKS_InAction() or self.UKS_Airborne or not self:IsOnGround() then return end

    local atk
    if Possessor:KeyDown( IN_FORWARD ) then
      atk = ATK_OVERHEAD
    elseif Possessor:KeyDown( IN_BACK ) then
      atk = ATK_STAB
    else
      atk = ATK_HORIZONTAL
    end

    -- same selection bookkeeping as UKS_AttackCheck (shared attack cooldown);
    -- the start functions aim at the crosshair point, no lock-on required
    self.UKS_Cooldown = UKSisy.AttackCooldown( self:UKS_GetDifficulty() )
    self.UKS_PreviousAttack = atk
    self.UKS_PreviouslyJumped = false
    self.UKS_AttacksPerformed = self.UKS_AttacksPerformed + 1
    self:UKS_StartBoulderAttack( atk )

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKS_Dead or self:UKS_InAction() or self.UKS_Airborne
        or self.UKS_Cooldown > 0 or not self:IsOnGround() then return end

    -- UKS_StartStomp sets the shared attack cooldown itself
    self:UKS_StartStomp()

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKS_Dead or self:UKS_InAction() or self.UKS_Airborne
        or self.UKS_Cooldown > 0 or not self:IsOnGround() then return end

    self.UKS_Cooldown = UKSisy.AttackCooldown( self:UKS_GetDifficulty() )
    self.UKS_PreviousAttack = ATK_AIRSTAB
    self.UKS_AttacksPerformed = self.UKS_AttacksPerformed + 1
    self:UKS_StartAirStab()

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKS_Dead or self:UKS_InAction() or self.UKS_Airborne
        or not self:IsOnGround() then return end

    local LockedOn = self:PossessionGetLockedOn()
    local target
    if IsValid( LockedOn ) then
      target = LockedOn:GetPos()
    else
      local tr = self:PossessorTrace()
      target = tr and tr.HitPos or self:GetPos() + self:GetForward() * ( 20 * UNIT )
    end
    self.UKS_AttacksPerformed = 0
    self:UKS_StartJump( target )

  end } },

}

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKSisy.HP
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    self:SetMaxHealth( health )
    self:SetHealth( health )

    local diff = UKSisy.GetDifficulty( self )

    self.UKS_Dead = false
    -- canon: 3 s cooldown on spawn (1 s on BRUTAL)
    self.UKS_Cooldown = diff >= 4 and 1 or UKSisy.SPAWN_COOLDOWN
    self.UKS_LastCdThink = CurTime()
    self.UKS_AttacksPerformed = 0
    self.UKS_PreviousAttack = -1
    self.UKS_PreviouslyJumped = false

    self.UKS_Action = nil
    self.UKS_ActionEnd = 0
    self.UKS_ExtendAt = nil
    self.UKS_RetractAt = nil
    self.UKS_StompAt = nil
    self.UKS_AirStabAt = nil
    self.UKS_FlyAt = nil
    self.UKS_TrackY = 0
    self.UKS_SeqName = "Idle"
    self.UKS_SeqRate = 1

    self.UKS_Airborne = nil
    self.UKS_AirborneSince = 0
    self.UKS_JumpTarget = nil
    self.UKS_SuperKnockdownPending = false
    self.UKS_PullT0 = nil

    self.UKS_Boulder = nil
    self.UKS_BoulderBG = self:FindBodygroupByName( "boulder" )

    self.UKS_NextHurtSound = 0
    self.UKS_DefaultGravity = ( self.loco.GetGravity and self.loco:GetGravity() ) or 1000

    self:SetParryable( false )
    self:EmitSound( UKSisy.SOUND.Spawn, 105, 100, 1 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    if IsValid( self.UKS_Boulder ) then self.UKS_Boulder:Remove() end
  end

  function ENT:UKS_GetDifficulty()
    return UKSisy.GetDifficulty( self )
  end

  ------------------------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------------------------

  function ENT:UKS_BoulderAttachPos()
    local id = self:LookupAttachment( "boulder" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter() + self:GetForward() * ( 3 * UNIT )
  end

  function ENT:UKS_TargetPos( enemy )
    enemy = enemy or self:GetEnemy()
    if not IsValid( enemy ) then return self:GetPos() end
    return enemy:GetPos()
  end

  function ENT:UKS_DistToTarget( enemy )
    return self:GetPos():Distance( self:UKS_TargetPos( enemy ) )
  end

  -- possession aim point (base AimProjectile recipe): lock-on centre or the
  -- point under the possessor's crosshair — vertical included, and a lock-on
  -- is never required
  function ENT:UKS_PossessAimPos()
    local LockedOn = self:PossessionGetLockedOn()
    if IsValid( LockedOn ) then return LockedOn:WorldSpaceCenter() end
    local tr = self:PossessorTrace()
    if tr and tr.HitPos then return tr.HitPos end
    return self:GetPos() + self:GetForward() * ( 20 * UNIT )
  end

  function ENT:UKS_PlaySeq( name, rate )
    local seq = self:LookupSequence( name )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( rate or 1 )
    end
    self.UKS_SeqName = name
    self.UKS_SeqRate = rate or 1
  end

  function ENT:UKS_SetBoulderHidden( hidden )
    if self.UKS_BoulderBG and self.UKS_BoulderBG >= 0 then
      self:SetBodygroup( self.UKS_BoulderBG, hidden and 1 or 0 )
    end
  end

  ------------------------------------------------------------------------------
  -- Action bookkeeping
  ------------------------------------------------------------------------------

  function ENT:UKS_InAction()
    return self.UKS_Action ~= nil
  end

  function ENT:UKS_BeginAction( name, dur )
    self.UKS_Action = name
    self.UKS_ActionEnd = CurTime() + dur
    self.UKS_ExtendAt = nil
    self.UKS_RetractAt = nil
    self.UKS_StompAt = nil
    self.UKS_TrackY = 0
    self.CantMove = true
    self.loco:SetVelocity( vector_origin )
  end

  function ENT:UKS_EndAction()
    self.UKS_Action = nil
    self.UKS_ExtendAt = nil
    self.UKS_RetractAt = nil
    self.UKS_StompAt = nil
    self.UKS_AirStabAt = nil
    self.UKS_FlyAt = nil
    self.UKS_TrackY = 0
    self.CantMove = false
    self:SetMaxYawRate( self.MaxYawRate )
    self:SetPlaybackRate( 1 )
    self.UKS_SeqRate = 1
  end

  ------------------------------------------------------------------------------
  -- Canon TestAttack clearance checks (LMD.Environment ~ world brushes)
  ------------------------------------------------------------------------------

  local function ClearLine( from, to )
    return not util.TraceLine( {
      start = from, endpos = to, mask = MASK_SOLID_BRUSHONLY,
    } ).Hit
  end

  function ENT:UKS_TestAttack( atk, enemy )
    local pos = self:GetPos()
    local tpos = self:UKS_TargetPos( enemy )
    local dist = pos:Distance( tpos )
    local up = Vector( 0, 0, 1 )

    if atk == ATK_OVERHEAD then
      return ClearLine( pos, pos + up * dist )
        and ClearLine( pos + up * dist, pos + up * dist
          + ( tpos - pos ):GetNormalized() * dist )
        and ClearLine( tpos, tpos + up * dist )
    elseif atk == ATK_HORIZONTAL then
      local right = self:GetRight()
      local high = pos + up * ( 3 * UNIT )
      local num2 = tpos.z - pos.z
      local L = pos + up * ( 5 * UNIT ) - right * dist
      local R = pos + up * ( 5 * UNIT ) + up * ( num2 * 2 ) + right * dist
      return ClearLine( high, high - right * dist )
        and ClearLine( L, tpos )
        and ClearLine( high, high + right * dist )
        and ClearLine( R, tpos )
    elseif atk == ATK_STAB then
      local from = pos + up * ( 3 * UNIT )
      local to = tpos + up * ( 3 * UNIT )
      local r = 1.75 * UNIT
      local tr = util.TraceHull( {
        start = from, endpos = to,
        mins = Vector( -r, -r, -r ), maxs = Vector( r, r, r ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      return not tr.Hit
    elseif atk == ATK_AIRSTAB then
      -- canon checks 73 m of open sky, unreachable on GMod maps (the trace
      -- hits skybox/ceilings) — check our actual hover height instead
      local high = pos + up * ( UKSisy.AIRSTAB_RISE * UNIT )
      return ClearLine( pos + up * ( 3 * UNIT ), high )
        and ClearLine( high, tpos )
    end
    return false
  end

  ------------------------------------------------------------------------------
  -- Attack selection (canon FixedUpdate decision block)
  ------------------------------------------------------------------------------

  function ENT:UKS_AttackCheck( enemy )
    local diff = self:UKS_GetDifficulty()
    local distM = self:UKS_DistToTarget( enemy ) / UNIT

    -- canon: Stomp when the target is closer than 8 m (never on HARMLESS)
    if distM < UKSisy.STOMP_RANGE and diff ~= 0 then
      self:UKS_StartStomp()
      return
    end

    -- canon: jump after 2-3 attacks or beyond 100 m (needs floor below
    -- target); tuned 2026-07-07 spaces the jumps out to every 4-6 attacks
    local threshold = math.random( UKSisy.JUMP_AFTER_MIN, UKSisy.JUMP_AFTER_MAX )
    if ( self.UKS_AttacksPerformed >= threshold or distM > UKSisy.JUMP_RANGE )
        and util.TraceLine( {
          start = self:UKS_TargetPos( enemy ),
          endpos = self:UKS_TargetPos( enemy ) - Vector( 0, 0, 50 * UNIT ),
          mask = MASK_SOLID_BRUSHONLY,
        } ).Hit then
      self.UKS_AttacksPerformed = 0
      self:UKS_StartJump( self:UKS_TargetPos( enemy ) )
      return
    end

    -- canon: random boulder attack, no repeats, no AirStab right after a jump
    local pick = math.random( 0, 3 )
    local guard = 0
    while ( pick == self.UKS_PreviousAttack
        or ( pick == ATK_AIRSTAB and self.UKS_PreviouslyJumped ) )
        and guard < 10 do
      guard = guard + 1
      pick = math.random( 0, 3 )
    end

    local ok = self:UKS_TestAttack( pick, enemy )
    if not ok then
      -- canon: shuffled fallback over the other attacks
      local order = { 0, 1, 2, 3 }
      local n = self.UKS_PreviouslyJumped and 3 or 4
      for i = 1, n do
        local j = math.random( i, n )
        order[ i ], order[ j ] = order[ j ], order[ i ]
      end
      for i = 1, 4 do
        local cand = order[ i ]
        if cand ~= pick and not ( cand == ATK_AIRSTAB and self.UKS_PreviouslyJumped )
            and self:UKS_TestAttack( cand, enemy ) then
          ok = true
          pick = cand
          break
        end
      end
    end

    if not ok then
      -- canon: nothing fits -> jump at the target
      self:UKS_StartJump( self:UKS_TargetPos( enemy ) )
      return
    end

    self.UKS_Cooldown = UKSisy.AttackCooldown( diff )
    self.UKS_PreviousAttack = pick
    self.UKS_PreviouslyJumped = false
    self.UKS_AttacksPerformed = self.UKS_AttacksPerformed + 1

    if pick == ATK_AIRSTAB then
      self:UKS_StartAirStab()
    else
      self:UKS_StartBoulderAttack( pick )
    end
  end

  ------------------------------------------------------------------------------
  -- Boulder attacks (OverheadSlam / HorizontalSwing / GroundStab)
  ------------------------------------------------------------------------------

  function ENT:UKS_StartBoulderAttack( atk )
    local name = ATK_NAME[ atk ]
    local clip = CLIP[ name ]
    local enemy = self:GetEnemy()

    if self:IsPossessed() then
      -- possession: the body yaw lags the camera, so snap to the crosshair
      -- or the swing arcs start out wherever the corpse last pointed
      self:FaceInstant( self:UKS_PossessAimPos() )
    elseif atk == ATK_OVERHEAD and IsValid( enemy ) then
      self:FaceInstant( enemy:GetPos() )
    end

    self:UKS_BeginAction( name, clip.stop )
    self:UKS_PlaySeq( name == "overheadslam" and "OverheadSlam"
      or name == "horizontalswing" and "HorizontalSwing" or "Stab", 1 )
    self.UKS_ExtendAt = CurTime() + clip.extend
    self.UKS_ActionEnd = CurTime() + clip.stop
    self.UKS_TrackY = ATK_TRACKY[ atk ]

    -- canon voices: HorizontalSwing screeches at pitch 1.4-1.6
    local pitch = atk == ATK_HORIZONTAL and math.random( 140, 160 )
      or math.random( 90, 110 )
    self:EmitSound( UKSisy.SOUND[ ATK_VOICE[ atk ] ], 100, pitch, 1, CHAN_VOICE )
    -- canon attackFlash telegraph on the boulder
    self:EmitSound( UKSisy.SOUND.AttackFlash, 85, 100, 0.8 )
  end

  -- canon ExtendArm: distance-driven boulder speed / anim speed
  function ENT:UKS_ComputeExtend( name, distSu )
    local det = DETAILS[ name ]
    local diff = self:UKS_GetDifficulty()
    local d = math.max( distSu / UNIT - 10, 0 )
    local sas = math.Clamp( d / det.divide, det.minB, det.maxB )
    local animSpeed = math.Clamp( ( 1 - d / det.divide ) * det.spdMult,
      det.capMin, det.capMax )
    local num3 = UKSisy.SwingDiffMult( diff )
    animSpeed = animSpeed * num3
    sas = sas / num3
    if name == "airstab" then sas = sas / 2 end -- canon airStabOvershoot
    local T = det.evFloat * sas * det.durMult
    return sas, animSpeed, T
  end

  function ENT:UKS_SpawnBoulder()
    if IsValid( self.UKS_Boulder ) then self.UKS_Boulder:Remove() end
    local b = ents.Create( UKSisy.CLASS.Boulder )
    if not IsValid( b ) then return nil end
    b:SetPos( self:UKS_BoulderAttachPos() )
    b:SetOwner( self )
    b:Spawn()
    self.UKS_Boulder = b
    self:UKS_SetBoulderHidden( true )
    return b
  end

  function ENT:UKS_DoExtend()
    local name = self.UKS_Action
    local clip = CLIP[ name ]
    local enemy = self:GetEnemy()
    local aimPos
    if self:IsPossessed() then
      -- re-snap at release: the camera may have turned during the wind-up
      aimPos = self:UKS_PossessAimPos()
      self:FaceInstant( aimPos )
    end
    local epos = aimPos or ( IsValid( enemy ) and enemy:WorldSpaceCenter()
      or self:GetPos() + self:GetForward() * ( 20 * UNIT ) )
    local pos = self:GetPos()

    -- canon GetActualTargetPos per attack
    local aim = epos
    local distSu
    if name == "stab" then
      if aimPos then
        -- the stab flight flies THROUGH its target point: thrust straight at
        -- the crosshair, vertical included
        distSu = pos:Distance( aimPos )
      else
        local b = self:UKS_TargetPos( enemy ) + Vector( 0, 0, 3 * UNIT )
        distSu = pos:Distance( b )
        aim = pos + self:GetForward() * distSu
        aim.z = b.z
      end
    elseif name == "airstab" then
      distSu = pos:Distance( epos )
    else
      distSu = pos:Distance( aimPos or self:UKS_TargetPos( enemy ) )
    end

    local sas, animSpeed, T = self:UKS_ComputeExtend( name, distSu )
    self:SetPlaybackRate( animSpeed )
    self.UKS_SeqRate = animSpeed

    local b = self:UKS_SpawnBoulder()
    if IsValid( b ) then
      local mode = name
      local target = aim
      if name == "airstab" then
        local start = b:GetPos()
        local dir = ( epos - start ):GetNormalized()
        target = start + dir * ( distSu * 2 ) -- canon airStabOvershoot = 2
      end
      b:UKSB_Fly( {
        mode = mode,
        T = T,
        sas = sas,
        target = target,
        targetEnt = enemy,
        dist = distSu,
      } )
    end

    if clip.retract then
      -- the boulder flight (T, incl. the overheadslam durMult 4) outlasts the
      -- clip window on far targets — the fixed-time retract then yanked the
      -- mace back mid-air, the action expired and the boss "instantly
      -- switched to another attack" (round 2, 2026-07-10). Hold the
      -- action until the flight actually lands; the impact path schedules its
      -- own rest+retract.
      local clipRetract = ( clip.retract - clip.extend ) / animSpeed
      local clipStop    = ( clip.stop    - clip.extend ) / animSpeed
      local flight      = T + 0.1
      self.UKS_RetractAt = CurTime() + math.max( clipRetract, flight )
      self.UKS_ActionEnd = CurTime() + math.max( clipStop, flight + 0.4 )
    elseif name == "airstab" then
      self.UKS_FlyAt = CurTime() + ( clip.fly - clip.extend ) / animSpeed
      self.UKS_ActionEnd = CurTime() + ( clip.stop - clip.extend ) / animSpeed + 3
    end
    self.UKS_ExtendAt = nil

    -- canon post-extend tracking: the stab locks its heading
    if name == "stab" then self.UKS_TrackY = 0 end
  end

  function ENT:UKS_DoRetract()
    self.UKS_RetractAt = nil
    if IsValid( self.UKS_Boulder ) then
      self.UKS_Boulder:UKSB_Retract( 1 )
    end
    -- canon RetractArm: inAction = false, the enemy resumes walking while the
    -- arm pulls back; the attack cooldown was set at selection time
    self:UKS_EndAction()
  end

  -- boulder slammed into the environment (explosion already applied)
  function ENT:UKS_BoulderImpact( pos )
    local name = self.UKS_Action
    -- canon AirStab: the boulder rests where it slammed until FlyToArm pulls
    -- the Insurrectionist to it — never auto-retract
    if name == "airstab" then return end
    local rest = ( name == "overheadslam" ) and 1.0 or 0.5
    local ret = ( name == "overheadslam" ) and 2.0 or 0.5
    local b = self.UKS_Boulder
    timer.Simple( rest, function()
      if IsValid( b ) then b:UKSB_Retract( ret ) end
    end )
  end

  function ENT:UKS_BoulderReturned()
    self.UKS_Boulder = nil
    self:UKS_SetBoulderHidden( false )
  end

  -- hovering with zero gravity (AirStab) must never outlive its attack
  function ENT:UKS_DropFromHover()
    if self.UKS_Airborne == "airstab_hover" or self.UKS_Airborne == "airstab_jump" then
      self.UKS_AirStabAt = nil
      self.UKS_FlyAt = nil
      self.loco:SetGravity( 200 * UNIT )
      self.UKS_Airborne = "airstab_fall"
      self.UKS_AirborneSince = CurTime()
    end
  end

  function ENT:UKS_BoulderBroken()
    self.UKS_Boulder = nil
    if self.UKS_Action and self.UKS_Action ~= "knockdown" then
      self:UKS_EndAction()
    end
    self:UKS_DropFromHover()
    -- canon: the mace reappears in hand shortly after (ResetBoulderPose)
    timer.Simple( 1.0, function()
      if IsValid( self ) then self:UKS_SetBoulderHidden( false ) end
    end )
  end

  -- canon GotParried: the boulder stops following the swing; the attack stalls
  function ENT:UKS_OnBoulderParried()
    if self.UKS_Action and self.UKS_Action ~= "knockdown" then
      self:UKS_EndAction()
    end
    self:UKS_DropFromHover()
  end

  ------------------------------------------------------------------------------
  -- Stomp
  ------------------------------------------------------------------------------

  function ENT:UKS_StartStomp()
    local diff = self:UKS_GetDifficulty()
    local rate = UKSisy.StompSpeed( diff )
    local clip = CLIP.stomp

    self.UKS_Cooldown = UKSisy.AttackCooldown( diff )
    self:UKS_BeginAction( "stomp", clip.stopaction / rate )
    self:UKS_PlaySeq( "Stomp", rate )
    self.UKS_StompAt = CurTime() + clip.explode / rate
    self:EmitSound( UKSisy.SOUND.Stomp, 100, math.random( 140, 160 ), 1, CHAN_VOICE )
  end

  function ENT:UKS_DoStomp()
    self.UKS_StompAt = nil
    local diff = self:UKS_GetDifficulty()
    local pos = self:GetPos() + Vector( 0, 0, 1 * UNIT )
    local enemy = self:GetEnemy()
    if IsValid( enemy ) and not ClearLine( pos, enemy:WorldSpaceCenter() ) then
      pos = self:GetPos() + Vector( 0, 0, 5 * UNIT )
    end
    -- canon StompExplosion: full-size wave, x1.5 on VIOLENT+ (no x0.66 shrink)
    UKSisy.Explode( self, pos, diff >= 3 and 1.5 or 1.0 )
  end

  ------------------------------------------------------------------------------
  -- Jump (canon: up to max(50, 100+dist) m/s, extra gravity, air-steered)
  ------------------------------------------------------------------------------

  function ENT:UKS_StartJump( target, noEnd )
    if self.UKS_Airborne then return end
    self.UKS_PreviouslyJumped = true

    -- ground-snap the jump target like canon NavMesh.SamplePosition
    local down = util.TraceLine( {
      start = target + Vector( 0, 0, 32 ),
      endpos = target - Vector( 0, 0, 50 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    self.UKS_JumpTarget = down.Hit and down.HitPos or target

    local distM = self:GetPos():Distance( target ) / UNIT
    local vz = math.min( math.max( 50, 100 + distM ), 200 ) * UNIT

    self:UKS_BeginAction( noEnd and "airstab_jump" or "jump", 30 )
    self:UKS_PlaySeq( "Jump", 1 )
    self.UKS_Airborne = noEnd and "airstab_jump" or "jump"
    self.UKS_AirborneSince = CurTime()
    self.UKS_CrushHits = {}

    sound.Play( UKSisy.SOUND.JumpRubble, self:GetPos(), 100, 100, 1 )
    local fx = EffectData()
    fx:SetOrigin( self:GetPos() )
    util.Effect( "ThumperDust", fx, true, true )

    self:LeaveGround()
    self.loco:SetGravity( 200 * UNIT )
    self.loco:SetVelocity( Vector( 0, 0, vz ) )
  end

  -- canon FallKillEnemy: enemies underneath a falling Insurrectionist die
  function ENT:UKS_CrushCheck()
    local vel = self.loco:GetVelocity()
    if vel.z > -50 then return end
    self.UKS_CrushHits = self.UKS_CrushHits or {}
    for _, ent in ipairs( ents.FindInSphere( self:GetPos() + Vector( 0, 0, 30 ), 2.5 * UNIT ) ) do -- x0.5 rescale
      if ent ~= self and IsValid( ent ) and not self.UKS_CrushHits[ ent ]
          and ( ent:IsNPC() or ent:IsNextBot() ) and not ent.UKSisy_IsSisy then
        self.UKS_CrushHits[ ent ] = true
        local dmg = DamageInfo()
        dmg:SetDamage( 1e6 )
        dmg:SetDamageType( DMG_CRUSH )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        ent:TakeDamageInfo( dmg )
      end
    end
  end

  -- possession landing: the per-tick crush scan above steps ~400 su per
  -- think at fall speed and UKS_Land fires before it on the landing tick, so
  -- a victim right under the landing point was skipped — sweep the whole
  -- hull footprint on touchdown instead (canon FallKillEnemy, no enemy
  -- involved); crush survivors would trap us inside their hull (nextbots
  -- don't collide with NPCs), so shove ourselves out sideways afterwards
  function ENT:UKS_PossessCrushLanding()
    local cb = self.CollisionBounds
    local pos = self:GetPos()
    self.UKS_CrushHits = self.UKS_CrushHits or {}
    for _, ent in ipairs( ents.FindInBox(
        pos + Vector( -cb.x - 16, -cb.y - 16, -40 ),
        pos + Vector( cb.x + 16, cb.y + 16, cb.z ) ) ) do
      if ent ~= self and IsValid( ent ) and not self.UKS_CrushHits[ ent ]
          and ( ent:IsNPC() or ent:IsNextBot() ) and not ent.UKSisy_IsSisy then
        self.UKS_CrushHits[ ent ] = true
        local dmg = DamageInfo()
        dmg:SetDamage( 1e6 )
        dmg:SetDamageType( DMG_CRUSH )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        ent:TakeDamageInfo( dmg )
      end
    end
    -- minimal horizontal separation per survivor (Minotaur-collider nudge)
    local smin, smax = self:WorldSpaceAABB()
    for _, ent in ipairs( ents.FindInBox( smin, smax ) ) do
      if ent ~= self and IsValid( ent ) and ent:Health() > 0
          and ( ent:IsNPC() or ent:IsNextBot() ) and not ent.UKSisy_IsSisy then
        local emin, emax = ent:WorldSpaceAABB()
        if smax.x > emin.x and smin.x < emax.x and smax.y > emin.y
            and smin.y < emax.y and smax.z > emin.z and smin.z < emax.z then
          local pushX = ( pos.x >= ent:WorldSpaceCenter().x )
            and ( emax.x - smin.x ) or -( smax.x - emin.x )
          local pushY = ( pos.y >= ent:WorldSpaceCenter().y )
            and ( emax.y - smin.y ) or -( smax.y - emin.y )
          self:SetPos( pos + ( math.abs( pushX ) <= math.abs( pushY )
            and Vector( pushX, 0, 0 ) or Vector( 0, pushY, 0 ) ) )
          pos = self:GetPos()
          smin, smax = self:WorldSpaceAABB()
        end
      end
    end
  end

  function ENT:UKS_AirThink()
    local mode = self.UKS_Airborne
    local now = CurTime()

    -- min air time so IsOnGround from the launch frame doesn't end the jump
    if now - self.UKS_AirborneSince > 0.25 and self:IsOnGround() then
      self:UKS_Land()
      return
    end

    if mode == "jump" then
      -- canon RotateTowardsTarget while jumping (trackingY = 1)
      local enemy = self:GetEnemy()
      if IsValid( enemy ) then
        self:SetMaxYawRate( 300 )
        local dir = enemy:GetPos() - self:GetPos()
        dir.z = 0
        if dir:LengthSqr() > 1 then
          self:FaceTowards( self:GetPos() + dir )
        end
      end
      -- canon horizontal MoveTowards: closes at (remaining distance x2)/s
      local target = self.UKS_JumpTarget
      if target then
        local pos = self:GetPos()
        local flat = Vector( target.x - pos.x, target.y - pos.y, 0 )
        local remaining = flat:Length()
        local v = self.loco:GetVelocity()
        if remaining > 8 then
          flat:Normalize()
          local hspeed = remaining * 2
          self.loco:SetVelocity( Vector( flat.x * hspeed, flat.y * hspeed, v.z ) )
        else
          self.loco:SetVelocity( Vector( 0, 0, v.z ) )
        end
      end
      self:UKS_CrushCheck()

    elseif mode == "airstab_jump" then
      -- rise in place; at +1.0 s freeze mid-air and swing (canon AirStab())
      if self.UKS_AirStabAt and now >= self.UKS_AirStabAt then
        self.UKS_AirStabAt = nil
        self.UKS_Airborne = "airstab_hover"
        self.loco:SetGravity( 0 )
        self.loco:SetVelocity( vector_origin )
        local clip = CLIP.airstab
        self:UKS_PlaySeq( "AirStab", 1 )
        self.UKS_Action = "airstab"
        self.UKS_ExtendAt = now + clip.extend
        self.UKS_ActionEnd = now + clip.stop + 3
        self.UKS_TrackY = ATK_TRACKY[ ATK_AIRSTAB ]
        self:EmitSound( UKSisy.SOUND[ ATK_VOICE[ ATK_AIRSTAB ] ], 100,
          math.random( 90, 110 ), 1, CHAN_VOICE )
        self:EmitSound( UKSisy.SOUND.AttackFlash, 90, 100, 1 )
      end

    elseif mode == "airstab_fall" then
      self:UKS_CrushCheck()
    end
  end

  function ENT:UKS_Land()
    local diff = self:UKS_GetDifficulty()
    self.UKS_Airborne = nil
    self.UKS_JumpTarget = nil
    self.loco:SetGravity( self.UKS_DefaultGravity or 1000 )
    self.loco:SetVelocity( vector_origin )

    if self:IsPossessed() then self:UKS_PossessCrushLanding() end

    if self.UKS_SuperKnockdownPending then
      -- canon superKnockdownWindow: 4 s knockdown on landing + style bonus
      self.UKS_SuperKnockdownPending = false
      self:UKS_Knockdown( self:GetPos() + self:GetForward() * 100, true )
      return
    end

    local clip = CLIP.landing
    self:UKS_BeginAction( "landing", clip.stopaction )
    self:UKS_PlaySeq( "Landing", 1 )
    sound.Play( UKSisy.SOUND.Fall, self:GetPos(), 110, 100, 1 )
    util.ScreenShake( self:GetPos(), 8, 40, 0.6, 1500 )

    -- canon landing PhysicalShockwave (all difficulties but HARMLESS),
    -- rendered as the UltrakillBase expanding ring — the Hideous Mass wave
    if diff >= 1 then
      self:Shockwave( true, self:GetPos(), angle_zero,
        UKSisy.WAVE_DAMAGE * 10,                            -- base units
        UKSisy.WAVE_MAXSIZE / UKSisy.WAVE_SPEED,            -- 100 m at 35 m/s
        math.ceil( UKSisy.WAVE_MAXSIZE * UNIT / 22 ),       -- ring model size
        UKSisy.WAVE_SCALEZ )
    end
  end

  ------------------------------------------------------------------------------
  -- AirStab (jump straight up -> hover -> dive the boulder -> pull self -> drop)
  ------------------------------------------------------------------------------

  function ENT:UKS_StartAirStab()
    self:UKS_StartJump( self:GetPos(), true )
    -- freeze just before the ballistic apex (~0.5 s at vz 100 m/s, g 200):
    -- the canon +1.0 s mark is past the apex, he was back on the ground and
    -- UKS_Land ate the attack before the swing could fire
    self.UKS_AirStabAt = CurTime() + 0.45
  end

  -- possession Air Stab: swing from wherever we already are in the air
  -- (mid possessed jump or a plain fall) instead of the canon self-launch;
  -- the next think enters the canon hover -> swing -> pull-self machinery
  function ENT:UKS_StartPossessAirStab()
    self:UKS_BeginAction( "airstab_jump", 30 )
    self:UKS_PlaySeq( "Jump", 1 )
    self.UKS_Airborne = "airstab_jump"
    self.UKS_AirborneSince = CurTime()
    self.UKS_JumpTarget = nil
    self.UKS_CrushHits = {}
    self.loco:SetGravity( 0 ) -- no sag while waiting for the hover think
    self.UKS_AirStabAt = CurTime()
  end

  function ENT:UKS_DoFlyToArm()
    self.UKS_FlyAt = nil
    local b = self.UKS_Boulder
    if IsValid( b ) and b.UKSB_Mode == "parried" then b = nil end
    if not IsValid( b ) then
      -- nothing to pull to: cancel like canon AirStabCancel
      self:UKS_PlaySeq( "AirStabCancel", 1 )
      self.UKS_Action = "airstabcancel"
      self.UKS_ActionEnd = CurTime() + CLIP.airstabcancel.stop
      self.loco:SetGravity( 200 * UNIT )
      self.UKS_Airborne = "airstab_fall"
      return
    end
    -- canon FlyToArm: pitch-perfect voice + 0.4 s self-pull to the boulder
    self:EmitSound( UKSisy.SOUND[ ATK_VOICE[ ATK_AIRSTAB ] ], 100,
      math.random( 140, 160 ), 1, CHAN_VOICE )
    self.UKS_PullT0 = CurTime()
    self.UKS_PullFrom = self:GetPos()
  end

  function ENT:UKS_PullThink()
    local b = self.UKS_Boulder
    local frac = math.Clamp( ( CurTime() - self.UKS_PullT0 ) / 0.4, 0, 1 )
    local dest = IsValid( b ) and ( b:GetPos() + Vector( 0, 0, 20 ) ) or self:GetPos() -- x0.5 rescale
    self:SetPos( LerpVector( frac, self.UKS_PullFrom, dest ) )
    if frac >= 1 then
      self.UKS_PullT0 = nil
      if IsValid( b ) then b:UKSB_Retract( 0.4 ) end
      -- canon: rb.AddForce(down * 300, VelocityChange) — a violent slam-drop
      self.loco:SetGravity( 200 * UNIT )
      self.loco:SetVelocity( Vector( 0, 0, -4000 ) )
      self.UKS_Airborne = "airstab_fall"
      self.UKS_AirborneSince = CurTime()
      self.UKS_CrushHits = {}
    end
  end

  ------------------------------------------------------------------------------
  -- Knockdown (canon: parried boulder / heavy impact)
  ------------------------------------------------------------------------------

  function ENT:UKS_Knockdown( fromPos, super )
    if self.UKS_Dead then return end

    if self.UKS_Airborne and not super then
      -- canon: cannonballed in the air -> 4 s knockdown right after landing
      self.UKS_SuperKnockdownPending = true
      self:UKS_DropFromHover() -- a zero-gravity hover would never land
      return
    end

    if IsValid( self.UKS_Boulder ) then
      self.UKS_Boulder:UKSB_Retract( 0.3 )
    end

    local diff = self:UKS_GetDifficulty()
    local rate = diff >= 4 and 2 or 1 -- canon DownedSpeed (BRUTAL recovers x2)
    local clip = CLIP.knockdown

    if fromPos then
      self:FaceInstant( fromPos )
    end

    self:UKS_EndAction()
    self:UKS_BeginAction( "knockdown", clip.stopaction / rate
      + ( super and UKSisy.SUPER_KNOCKDOWN_TIME or 0 ) )
    self:UKS_PlaySeq( "Knockdown", rate )
    self:EmitSound( UKSisy.SOUND.HurtBig, 100, math.random( 80, 120 ), 1, CHAN_VOICE )

    local this = self
    timer.Simple( clip.fallsound / rate, function()
      if IsValid( this ) and this.UKS_Action == "knockdown" then
        sound.Play( UKSisy.SOUND.Fall, this:GetPos(), 105, 100, 1 )
        util.ScreenShake( this:GetPos(), 6, 40, 0.5, 1200 )
      end
    end )

    if super then
      -- canon downed: freeze the clip mid-way for the long stun
      timer.Simple( UKSisy.KNOCKDOWN_TIME / rate, function()
        if IsValid( this ) and this.UKS_Action == "knockdown" then
          this:SetPlaybackRate( 0 )
          this.UKS_SeqRate = 0
        end
      end )
      timer.Simple( UKSisy.KNOCKDOWN_TIME / rate + UKSisy.SUPER_KNOCKDOWN_TIME, function()
        if IsValid( this ) and this.UKS_Action == "knockdown" then
          this:SetPlaybackRate( rate )
          this.UKS_SeqRate = rate
        end
      end )
    end
  end

  ------------------------------------------------------------------------------
  -- Damage
  ------------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKS_Dead then return end
    hitgroup = hitgroup or HITGROUP_GENERIC

    -- hitgroup 9 = the dead Malicious Face mace: canon soaks damage for free
    if hitgroup == 9 then
      dmg:ScaleDamage( 0 )
      BaseClass.OnTakeDamage( self, dmg, hitgroup )
      return
    end

    -- canon locational damage: limbs x1.5 (no head to headshot)
    if hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
        or hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
      dmg:ScaleDamage( 1.5 )
    end

    -- canon weakness: fire x2
    if bit.band( dmg:GetDamageType(), bit.bor( DMG_BURN, DMG_SLOWBURN ) ) ~= 0 then
      dmg:ScaleDamage( 2 )
    end

    if CurTime() >= ( self.UKS_NextHurtSound or 0 ) and dmg:GetDamage() > 0 then
      self.UKS_NextHurtSound = CurTime() + 0.7
      local amount = dmg:GetDamage()
      local snd = amount >= 5000 and UKSisy.SOUND.HurtBig
        or amount >= 1500 and UKSisy.SOUND.HurtMid or UKSisy.SOUND.HurtSmall
      self:EmitSound( snd, 90, math.random( 80, 120 ), 1, CHAN_VOICE )
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end

  ------------------------------------------------------------------------------
  -- Animation / movement plumbing
  ------------------------------------------------------------------------------

  local SEQ_BY_ACTION = {
    overheadslam = "OverheadSlam",
    horizontalswing = "HorizontalSwing",
    stab = "Stab",
    airstab = "AirStab",
    airstabcancel = "AirStabCancel",
    stomp = "Stomp",
    jump = "Jump",
    airstab_jump = "Jump",
    landing = "Landing",
    knockdown = "Knockdown",
  }

  function ENT:OnUpdateAnimation()
    if self.UKS_Action then
      return SEQ_BY_ACTION[ self.UKS_Action ] or self.UKS_SeqName, self.UKS_SeqRate
    end
    if self.UKS_Airborne then return "Jump", 1 end
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco:GetVelocity():Length() > 30
    if moving then return "Walking", UKSisy.WALK_ANIM_RATE end
    return "Idle", 1
  end

  function ENT:OnUpdateSpeed()
    return UKSisy.MOVE_SPEED
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are driven by UKS_AttackCheck in CustomThink
    return
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKS_Dead then return end
    if self:IsAIDisabled() then -- ai_disabled / per-bot disable
      -- воздушные фазы/подтяг к валуну рулятся по-тиковым SetVelocity;
      -- замороженный мид-полёт иначе дрейфует с последней скоростью
      if ( self.UKS_Airborne or self.UKS_PullT0 ) and self.loco then
        self.loco:SetVelocity( vector_origin )
      end
      return
    end
    local now = CurTime()

    -- self-pull to the boulder overrides everything (canon pullSelfRetract)
    if self.UKS_PullT0 then
      self:UKS_PullThink()
      return
    end

    if self.UKS_Airborne then
      self:UKS_AirThink()
    end

    local enemy = self:GetEnemy()

    -- pending timed events (variable playback rates make these explicit)
    if self.UKS_ExtendAt and now >= self.UKS_ExtendAt and not self.UKS_Airborne then
      self:UKS_DoExtend()
    elseif self.UKS_ExtendAt and now >= self.UKS_ExtendAt
        and self.UKS_Airborne == "airstab_hover" then
      self:UKS_DoExtend()
    end
    if self.UKS_StompAt and now >= self.UKS_StompAt then
      self:UKS_DoStomp()
    end
    if self.UKS_RetractAt and now >= self.UKS_RetractAt then
      self:UKS_DoRetract()
    end
    if self.UKS_FlyAt and now >= self.UKS_FlyAt then
      self:UKS_DoFlyToArm()
    end

    if self.UKS_Action then
      -- action tracking (canon RotateTowardsTarget, yaw component)
      if self.UKS_TrackY > 0 and IsValid( enemy ) and not self.UKS_Airborne then
        self:SetMaxYawRate( 300 * self.UKS_TrackY )
        local dir = enemy:GetPos() - self:GetPos()
        dir.z = 0
        if dir:LengthSqr() > 1 then
          self:FaceTowards( self:GetPos() + dir )
        end
      elseif not self.UKS_Airborne then
        self:SetMaxYawRate( 0 )
      end

      if now >= self.UKS_ActionEnd and not self.UKS_Airborne
          and not self.UKS_PullT0 then
        self:UKS_EndAction()
      end
      return
    end

    -- possessed: the base GetEnemy override returns PossessionGetLockedOn();
    -- the cooldown must keep ticking even with no lock-on or the binds jam
    local possessed = self:IsPossessed()

    if not IsValid( enemy ) and not possessed then return end
    if self.UKS_Airborne then return end

    -- canon cooldown depletion: x3 while the target is inside 10 m
    local dt = now - ( self.UKS_LastCdThink or now )
    self.UKS_LastCdThink = now
    if self.UKS_Cooldown > 0 then
      local rate = ( IsValid( enemy )
        and self:UKS_DistToTarget( enemy ) < UKSisy.CLOSE_RANGE * UNIT )
        and 3 or 1
      self.UKS_Cooldown = math.max( self.UKS_Cooldown - dt * rate, 0 )
      return
    end

    if self:IsOnGround() and not possessed then
      self:UKS_AttackCheck( enemy )
    end
  end

  ------------------------------------------------------------------------------
  -- Death (canon: gore burst, legs detach as physics props, boulder gone)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    if self.UKS_Dead then return end
    self.UKS_Dead = true
    self:UKS_EndAction()
    if IsValid( self.UKS_Boulder ) then self.UKS_Boulder:Remove() end
    self.loco:SetVelocity( vector_origin )

    local pos = self:GetPos()
    sound.Play( UKSisy.SOUND.Death, pos, 110, math.random( 90, 110 ), 1 )

    -- gore burst on the torso segments
    for i = 1, 6 do
      local fx = EffectData()
      fx:SetOrigin( pos + Vector( math.Rand( -60, 60 ), math.Rand( -60, 60 ),
        math.Rand( 100, 400 ) ) )
      fx:SetScale( 2 )
      util.Effect( "BloodImpact", fx, true, true )
    end
    util.Decal( "Blood", pos + Vector( 0, 0, 10 ), pos - Vector( 0, 0, 100 ) )

    -- canon Death(): both legs unparent and fall as physics objects
    local gibs = {
      { model = UKSisy.MODEL_GIB_LEG_L, bone = "thigh.L" },
      { model = UKSisy.MODEL_GIB_LEG_R, bone = "thigh.R" },
    }
    for _, g in ipairs( gibs ) do
      local boneId = self:LookupBone( g.bone )
      local bpos, bang = pos + Vector( 0, 0, 100 ), self:GetAngles() -- x0.5 rescale
      if boneId then
        local m = self:GetBoneMatrix( boneId )
        if m then
          bpos = m:GetTranslation()
          bang = m:GetAngles()
        end
      end
      local prop = ents.Create( "prop_physics" )
      if IsValid( prop ) then
        prop:SetModel( g.model )
        prop:SetPos( bpos )
        prop:SetAngles( bang )
        prop:Spawn()
        -- варианты Angry/Rude перекрашены через SetSubMaterial — гибы тоже
        if self.UKSAR_BodyMaterial then
          for i, m in ipairs( prop:GetMaterials() ) do
            if m:find( "sisy_body", 1, true ) then
              prop:SetSubMaterial( i - 1, self.UKSAR_BodyMaterial )
            end
          end
        end
        local phys = prop:GetPhysicsObject()
        if IsValid( phys ) then
          phys:SetVelocity( VectorRand() * 150 + Vector( 0, 0, 120 ) )
          phys:AddAngleVelocity( VectorRand() * 90 )
        end
        SafeRemoveEntityDelayed( prop, 30 )
      end
    end

    SafeRemoveEntityDelayed( self, 0.05 )
    return dmg
  end

end

if CLIENT then
  function ENT:Draw()
    self:DrawModel()
  end
end

DrGBase.AddNextbot( ENT )
