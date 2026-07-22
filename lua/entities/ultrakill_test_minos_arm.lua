AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end

-- The Corpse of King Minos' Arm — 2-4 "Court of the Corpse King" first
-- encounter (Supreme Husk boss-part). Full canon port of MinosArm.cs:
-- 3 slams (never the same twice), slam series -> cooldown 5-speedState,
-- PhysicalShockwave (35 dmg, 90 m/s, 350 m), HP-phase speedups with Flinch
-- (0.75/0.4 HP: anim x1.25/x1.5, maxSlams+1), Retreat death. 1:1 scale.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "The Corpse of King Minos' Arm"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKMinos.MODEL_ARM }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKMinos.HP_ARM
-- solid core around the base; the animated arm itself is hit via hitboxes
-- inside the (huge) surrounding bounds
ENT.CollisionBounds = Vector( 350, 350, 1500 )
ENT.SurroundingBounds = Vector( 7000, 7000, 4200 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy"
ENT.BloodColor = BLOOD_COLOR_RED

ENT.UKMinos_IsMinos = true

-- stationary (idol pattern)
ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 99999
ENT.Acceleration = 0
ENT.Deceleration = 9999
ENT.WalkSpeed = 0
ENT.RunSpeed = 0
ENT.JumpHeight = 0
ENT.MaxYawRate = 0
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.WalkAnimation = "Idle"
ENT.RunAnimation = "Idle"
ENT.JumpAnimation = "Idle"

local UNIT = UKMinos.UNIT

--------------------------------------------------------------------------------
-- Canon clip events (seconds @ speed 1.0): minos_events.json
--  Intro:     StartShaking@2.970 StopShaking@4.561 BigImpact@5.586 IntroEnd@6.762
--  SlamDown:  Slam(0)@1.250 StopAction@2.487
--  SlamLeft:  Slam(1)@1.436 StopAction@2.527   (1 = +transform.right)
--  SlamRight: Slam(2)@1.237 StopAction@2.540   (2 = -transform.right)
--  Flinch:    StopAction@0.566
--  Retreat:   EndEncounter@1.396
--------------------------------------------------------------------------------

local ACTION = {
  Intro = { seq = "Intro", dur = 7.0, ev = {
    { 2.970, "startShake" }, { 4.561, "stopShake" },
    { 5.586, "bigImpact" }, { 6.762, "introEnd" },
  } },
  SlamDown = { seq = "SlamDown", dur = 2.487, ev = {
    { 1.250, "slam0" },
  } },
  SlamLeft = { seq = "SlamLeft", dur = 2.527, ev = {
    { 1.436, "slam1" },
  } },
  SlamRight = { seq = "SlamRight", dur = 2.540, ev = {
    { 1.237, "slam2" },
  } },
  Flinch = { seq = "Flinch", dur = 0.566, ev = {} },
}

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 400, 1800 ),
    distance = 4500,
    eyepos = false

  },

  {

    offset = Vector( 450, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMA_Dead or not self.UKMA_IntroOver then return end
    if self.UKMA_AttackCooldown > 0 or self:UKMA_InAction() then return end

    -- canon naming quirk: SlamLeft sweeps toward +GetRight() (see event table)
    local num = 0
    if Possessor:KeyDown( IN_FORWARD ) then
      num = 1
    elseif Possessor:KeyDown( IN_BACK ) then
      num = 2
    end

    -- same series bookkeeping as the AI attack loop (slams -> forced break)
    self.UKMA_MaxSlams = math.max( self.UKMA_MaxSlams, self:UKMA_MaxSlamsForDiff() )
    self.UKMA_PreviousSlam = num
    if num == 0 then
      self:UKMA_StartAction( "SlamDown" )
    elseif num == 1 then
      self:UKMA_StartAction( "SlamLeft" )
    else
      self:UKMA_StartAction( "SlamRight" )
    end
    self:EmitSound( UKMinos.SOUND.Hurt, 130, math.random( 96, 104 ), 0.6 )
    self.UKMA_CurrentSlams = self.UKMA_CurrentSlams + 1
    if self.UKMA_CurrentSlams >= self.UKMA_MaxSlams then
      self.UKMA_CurrentSlams = 0
      self.UKMA_AttackCooldown = 5 - self.UKMA_SpeedState
    end

  end } }

}

if SERVER then

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKMinos.HP_ARM
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    local sb = self.SurroundingBounds
    self:SetSurroundingBounds( Vector( -sb.x, -sb.y, -200 ), Vector( sb.x, sb.y, sb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKMA_Dead = false
    self.UKMA_IntroOver = false
    self.UKMA_AttackCooldown = 1.5      -- canon initializer
    self.UKMA_PreviousSlam = -1
    self.UKMA_MaxSlams = 2
    self.UKMA_CurrentSlams = 0
    self.UKMA_SpeedState = 0
    self.UKMA_Shaking = false

    self.UKMA_ActionName = nil
    self.UKMA_ActionUntil = nil
    self.UKMA_ActionEvIndex = 1

    -- anchored: immune to physics shoves
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
      phys:SetMass( 50000 )
    end

    self:UKMA_StartAction( "Intro" )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKMA_SetShaking( false )
  end

  ------------------------------------------------------------------------------
  -- Difficulty (canon SetSpeed)
  ------------------------------------------------------------------------------

  function ENT:UKMA_GetDifficulty()
    return UKMinos.GetDifficulty( self )
  end

  function ENT:UKMA_AnimSpeed()
    local d = self:UKMA_GetDifficulty()
    local base = 1.0
    if d == 1 then base = 0.85 elseif d == 0 then base = 0.65 end
    return base * ( 1 + self.UKMA_SpeedState / 4 )
  end

  function ENT:UKMA_MaxSlamsForDiff()
    local d = self:UKMA_GetDifficulty()
    if d >= 4 then return 99 end
    if d == 3 then return 3 end
    return 2
  end

  ------------------------------------------------------------------------------
  -- Actions (mannequin/ferryman event loop)
  ------------------------------------------------------------------------------

  function ENT:UKMA_InAction()
    if self.UKMA_ActionUntil and self.UKMA_ActionUntil > CurTime() then return true end
    if self.UKMA_ActionName then self:UKMA_EndAction() end
    return false
  end

  function ENT:UKMA_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKMA_AnimSpeed()

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKMA_ActionName = name
    self.UKMA_ActionCfg = cfg
    self.UKMA_ActionStart = CurTime()
    self.UKMA_ActionUntil = CurTime() + cfg.dur / spd
    self.UKMA_ActionEvIndex = 1
  end

  function ENT:UKMA_EndAction()
    self.UKMA_ActionName = nil
    self.UKMA_ActionCfg = nil
    self.UKMA_ActionUntil = nil
  end

  function ENT:UKMA_ProcessEvents()
    local cfg = self.UKMA_ActionCfg
    if not cfg then return end
    local t = ( CurTime() - ( self.UKMA_ActionStart or 0 ) ) * self:UKMA_AnimSpeed()
    while self.UKMA_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKMA_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKMA_ActionEvIndex = self.UKMA_ActionEvIndex + 1
      self:UKMA_FireEvent( ev[ 2 ] )
      if self.UKMA_ActionCfg ~= cfg then return end
    end
  end

  function ENT:UKMA_FireEvent( kind )
    if kind == "startShake" then
      self:UKMA_SetShaking( true )
    elseif kind == "stopShake" then
      self:UKMA_SetShaking( false )
      self:UKMA_BigImpact( 1 )
    elseif kind == "bigImpact" then
      self:UKMA_BigImpact( 2 )
    elseif kind == "introEnd" then
      self.UKMA_IntroOver = true
    elseif kind == "slam0" then
      self:UKMA_Slam( 0 )
    elseif kind == "slam1" then
      self:UKMA_Slam( 1 )
    elseif kind == "slam2" then
      self:UKMA_Slam( 2 )
    end
  end

  ------------------------------------------------------------------------------
  -- Slams (canon MinosArm.Slam)
  ------------------------------------------------------------------------------

  function ENT:UKMA_HandPos()
    local id = self:LookupAttachment( "hand" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter()
  end

  function ENT:UKMA_Slam( slamType )
    local handPos = self:UKMA_HandPos()
    local dir = Vector( 0, 0, -1 )
    if slamType == 1 then
      dir = self:GetRight()
    elseif slamType == 2 then
      dir = -self:GetRight()
    end

    -- canon: raycast 100 m from the hand along the slam direction
    local tr = util.TraceLine( {
      start = handPos,
      endpos = handPos + dir * ( 100 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
      filter = self,
    } )
    local pos = tr.Hit and ( tr.HitPos - dir * ( 0.1 * UNIT ) ) or handPos
    local normal = tr.Hit and tr.HitNormal or Vector( 0, 0, 1 )

    UKMinos.SpawnWave( self, pos, normal, {
      damage = UKMinos.WAVE_DAMAGE,
      height = ( slamType > 0 ) and UKMinos.WAVE_HEIGHT_WALL or UKMinos.WAVE_HEIGHT_DOWN,
    } )

    self:UKMA_BigImpact( 2, pos )
    self:EmitSound( UKMinos.SOUND.Impact, 140, math.random( 96, 104 ), 1 )
  end

  function ENT:UKMA_BigImpact( shakeAmount, pos )
    util.ScreenShake( pos or self:GetPos(), shakeAmount or 2, 20, 0.7, 4000 )
    local fx = EffectData()
    fx:SetOrigin( pos or self:GetPos() )
    fx:SetScale( 8 )
    util.Effect( "ThumperDust", fx, true, true )
  end

  function ENT:UKMA_SetShaking( on )
    if on == self.UKMA_Shaking then return end
    self.UKMA_Shaking = on
    if on then
      if not self.UKMA_ShakeSound then
        self.UKMA_ShakeSound = CreateSound( self, UKMinos.SOUND.ShakeLoop )
      end
      self.UKMA_ShakeSound:PlayEx( 1, 100 )
    elseif self.UKMA_ShakeSound then
      self.UKMA_ShakeSound:Stop()
    end
  end

  ------------------------------------------------------------------------------
  -- Flinch phases (canon Update: 0.75 / 0.4 HP)
  ------------------------------------------------------------------------------

  function ENT:UKMA_Flinch()
    self:UKMA_StartAction( "Flinch" )
    self.UKMA_CurrentSlams = 0
    self.UKMA_MaxSlams = self.UKMA_MaxSlams + 1
    self.UKMA_AttackCooldown = 0
    -- canon Flinch during the intro rushes StartEncounter + IntroEnd
    if not self.UKMA_IntroOver then
      self:UKMA_SetShaking( false )
      self.UKMA_IntroOver = true
    end
    self:EmitSound( UKMinos.SOUND.Hurt, 130, 100, 0.75 )
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT or self.UKMA_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = math.min( now - ( self.UKMA_LastThink or now ), 0.25 )
    self.UKMA_LastThink = now

    if self.UKMA_ActionName then self:UKMA_ProcessEvents() end

    -- continuous shake while shaking (canon CameraShake(0.25) per frame)
    if self.UKMA_Shaking then
      util.ScreenShake( self:GetPos(), 1, 20, 0.3, 4000 )
    end

    -- HP speed phases
    local frac = self:Health() / math.max( self:GetMaxHealth(), 1 )
    if self.UKMA_SpeedState == 1 and frac < 0.4 then
      self.UKMA_SpeedState = 2
      self:UKMA_Flinch()
    elseif self.UKMA_SpeedState == 0 and frac < 0.75 then
      self.UKMA_SpeedState = 1
      self:UKMA_Flinch()
    end

    if not self.UKMA_IntroOver then return end

    local enemy = self:GetEnemy()

    -- slow rotation toward the target (convar; canon is fully static)
    if IsValid( enemy ) and not self:UKMA_InAction() then
      local rate = GetConVar( "ukminos_turnrate" ):GetFloat()
      if rate > 0 then
        local toYaw = ( enemy:GetPos() - self:GetPos() ):Angle().yaw
        local myAng = self:GetAngles()
        local delta = math.AngleDifference( toYaw, myAng.yaw )
        local step = math.Clamp( delta, -rate * dt, rate * dt )
        self:SetAngles( Angle( 0, myAng.yaw + step, 0 ) )
      end
    end

    -- possessed: the bind drives the slams; keep their pacing timer ticking
    -- (a frozen cooldown would lock the bind forever)
    if self:IsPossessed() then
      if self.UKMA_AttackCooldown > 0 then
        self.UKMA_AttackCooldown = math.max( self.UKMA_AttackCooldown - dt, 0 )
      end
      return
    end

    if not IsValid( enemy ) then return end

    -- canon attack loop
    if self.UKMA_AttackCooldown > 0 then
      self.UKMA_AttackCooldown = math.max( self.UKMA_AttackCooldown - dt, 0 )
    elseif not self:UKMA_InAction() then
      self.UKMA_MaxSlams = math.max( self.UKMA_MaxSlams, self:UKMA_MaxSlamsForDiff() )
      local num
      repeat
        num = math.random( 0, 2 )
      until num ~= self.UKMA_PreviousSlam
      self.UKMA_PreviousSlam = num
      if num == 0 then
        self:UKMA_StartAction( "SlamDown" )
      elseif num == 1 then
        self:UKMA_StartAction( "SlamLeft" )
      else
        self:UKMA_StartAction( "SlamRight" )
      end
      self:EmitSound( UKMinos.SOUND.Hurt, 130, math.random( 96, 104 ), 0.6 )
      self.UKMA_CurrentSlams = self.UKMA_CurrentSlams + 1
      if self.UKMA_CurrentSlams >= self.UKMA_MaxSlams then
        self.UKMA_CurrentSlams = 0
        self.UKMA_AttackCooldown = 5 - self.UKMA_SpeedState
      end
    end
  end

  function ENT:OnUpdateAnimation()
    local spd = self:UKMA_AnimSpeed()
    if self.UKMA_ActionName and self:UKMA_InAction() then
      return self.UKMA_ActionCfg.seq, spd
    end
    return "Idle", spd
  end

  function ENT:OnUpdateSpeed()
    return 0
  end

  function ENT:OnMeleeAttack( enemy )
    return
  end

  ------------------------------------------------------------------------------
  -- Death (canon OnGoLimp -> Retreat -> EndEncounter)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKMA_Dead = true
    self:UKMA_EndAction()
    self:EmitSound( UKMinos.SOUND.BigHurtQuiet, 140, 100, 0.9 )

    local spd = 1.0
    local seq = self:LookupSequence( "Retreat" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end
    self:UKMA_SetShaking( true )

    local endAt = CurTime() + 1.396 / spd
    while IsValid( self ) and CurTime() < endAt do
      util.ScreenShake( self:GetPos(), 1, 20, 0.3, 4000 )
      self:YieldCoroutine()
    end

    if IsValid( self ) then
      self:UKMA_SetShaking( false )
      self:UKMA_BigImpact( 1 )
      self:EmitSound( UKMinos.SOUND.Impact, 140, 90, 1 )

      -- hold the retreat pose briefly, then fade (the arm withdraws into the dark)
      self:SetRenderMode( RENDERMODE_TRANSCOLOR )
      local fadeUntil = CurTime() + 2
      while IsValid( self ) and CurTime() < fadeUntil do
        local a = math.Clamp( ( fadeUntil - CurTime() ) / 2, 0, 1 )
        self:SetColor( Color( 255, 255, 255, a * 255 ) )
        self:YieldCoroutine()
      end
    end

    return dmg
  end

  -- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
  -- OnInjured re-calls it with a real hitgroup; without this gate the base
  -- DamageMultiplier runs twice (x10 player damage twice = x100).
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end

end

DrGBase.AddNextbot( ENT )
