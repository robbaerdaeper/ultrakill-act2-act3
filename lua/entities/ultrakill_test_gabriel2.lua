-- lua/entities/ultrakill_test_gabriel2.lua
-- Gabriel, Apostate of Hate (Gabriel 2nd, 6-2) — canon-faithful port of
-- GabrielBase + GabrielSecond + GabrielVoice (voice lines reuse the ported
-- Judge of Hell WAVs).
--
-- Canon behaviors ported 1:1 where the engine allows:
--   * ChooseAttack: 4 moves (SwordsCombine/FastComboDash/BasicCombo/ThrowCombo)
--     with random scores + adaptive moveChanceBonuses, previous-move ban,
--     range gates (<5 m bans melee-range moves, >20 m bans closers)
--   * burst attack chains (burstLength), attackCooldown + ready taunts
--   * teleports: pre-attack (no LOS), out-of-sight (3 s), EnrageTeleport
--     mid-combo variants (close/horizontal/dif-gated), decoy ghost trail
--   * combined swords: Gattai -> throw (homing projectile, parry-deflectable),
--     swords hidden while in flight, light-sword copies in phase 2
--   * juggle phase change at 50% HP: launched up, damage bounces, x0.5 taken,
--     ceiling bounce, landing/quota/timeout end -> Enrage anim -> phase 2
--   * spiral swords (Violent+): orbit shield, Brutal+ formation-stab
--
-- Clip event timings from the baked .anim data (gabriel2_events.json),
-- times below are CLIP time; runtime compares elapsed * rate * diffSpeed.

AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKGabriel2 then include( "autorun/ultrakill_test_gabriel2_shared.lua" ) end

if CLIENT then
  util.PrecacheModel( UKGabriel2.MODEL )
  util.PrecacheModel( UKGabriel2.MODEL_COMBINED )
end

local UNIT = UKGabriel2.UNIT
local D = UKGabriel2.DMG

ENT.Type        = "nextbot"
ENT.Base        = "ultrakillbase_nextbot"
ENT.PrintName   = "Gabriel, Apostate of Hate"
ENT.Author      = "ultragmod"
ENT.Spawnable   = true
ENT.AdminOnly   = false
ENT.Category    = "ULTRAKILL - Bosses"

ENT.Models      = { UKGabriel2.MODEL }
ENT.ModelScale  = 1.0
ENT.SpawnHealth = UKGabriel2.HP
ENT.CollisionBounds   = Vector( 13, 13, 99 ) -- 2026-07-10: model rescaled x0.45 (Kevin-scale)
ENT.SurroundingBounds = Vector( 200, 200, 240 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Medium"

ENT.UKG2_IsGabriel = true -- own projectiles never hurt Gabriel

-- DrGBase Flying (canon: Rigidbody no gravity, hovers around the player)
ENT.Flying        = true
ENT.FlyingHeight  = 43 -- 2026-07-10: model rescaled x0.45
ENT.AISight       = false
ENT.MeleeAttackRange = 10000
ENT.ReachEnemyRange  = 5 * UNIT   -- canon: stops closing under 5 m
ENT.AvoidEnemyRange  = 0
ENT.Acceleration  = 3000
ENT.Deceleration  = 3000
ENT.JumpHeight    = 0
ENT.StepHeight    = 0
ENT.MaxYawRate    = 600
ENT.DeathDropHeight = math.huge
ENT.UseWalkframes = false
-- canon idle drift: forward 7.5 m/s + side strafe 5 m/s
ENT.WalkSpeed = 7.5 * UNIT
ENT.RunSpeed  = 7.5 * UNIT
ENT.BehaviourStrafe = true
ENT.BehaviourStrafeUpdate = 4

ENT.IdleAnimation = "Idle"; ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Idle"; ENT.WalkAnimRate = 1
ENT.RunAnimation  = "Idle"; ENT.RunAnimRate  = 1
ENT.JumpAnimation = "Idle"; ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Idle"; ENT.FallingAnimRate = 1

ENT.UltrakillBase_FullTrackingBone = ""
ENT.UltrakillBase_FullTracking     = false

ENT.NW_COMBINED = "UKG2_CombinedHeld"
ENT.NW_PHASE    = "UKG2_Phase"

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    offset = Vector( 0, 13.5, 50.5 ),
    distance = 150,
    eyepos = false

  },

  {

    offset = Vector( 6.75, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKG2_Dead or self:UKG2_InAction() then return end
    if self.UKG2_StartCooldown > 0 or self.UKG2_AttackCooldown > 0 then return end

    self:UKG2_CheckSwordsForCombo()

    if Possessor:KeyDown( IN_FORWARD ) then

      self:UKG2_StartAction( "FastComboDash" )

    elseif Possessor:KeyDown( IN_BACK ) then

      self:UKG2_StartAction( "ThrowCombo" )

    else

      self:UKG2_StartAction( "BasicCombo" )

    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKG2_Dead or self:UKG2_InAction() then return end
    if self.UKG2_StartCooldown > 0 or self.UKG2_AttackCooldown > 0 then return end
    -- one combined-swords throw in flight at a time (canon combinedSwordsCooldown)
    if self.UKG2_CombinedCD > 0 or IsValid( self.UKG2_Thrown ) then return end

    self:UKG2_CheckSwordsForCombo()
    self:UKG2_StartAction( "SwordsCombine" )

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKG2_Dead or self:UKG2_InAction() then return end
    if self:UKG2_SpiralsAlive() or self.UKG2_SpiralWindupAt then return end
    if self.UKG2_SpiralCD > 0 then return end

    self.UKG2_SpiralCD = UKGabriel2.SPIRAL_COOLDOWN
    self:UKG2_SpawnSpiralWindup()

  end } },

}

--------------------------------------------------------------------------------
-- Canon clip events. Times are CLIP seconds; each action has the animator
-- state speed (`rate`). ev kinds:
--   flash(arg 1=unparryable red)  look (snap onto target, freeze rotation)
--   follow (resume smooth tracking)  parry (open base parry window)
--   dmgOn(dmg)/kickOn(dmg)/dmgOff  etp(type: EnrageTeleport variants)
--   dash (StartDash -> 100 m/s fly-in -> FastCombo)  gattai  throw
--   chainThrow (SwordsCombine -> SwordsCombinedThrow)  unenrage  stop
--------------------------------------------------------------------------------

local ACTION = {
  BasicCombo = {
    seq = "BasicCombo", rate = 1.0, stop = 4.3333, fwdMin = 125, fwdMax = 175,
    ev = {
      { 0.361, "flash", 1 },
      { 0.744, "look" },
      { 0.843, "dmgOn", D.MED_HIT }, { 0.952, "dmgOff" },
      { 1.346, "look" },
      { 1.434, "dmgOn", D.MED_HIT }, { 1.521, "dmgOff" },
      { 1.915, "look" },
      { 2.013, "dmgOn", D.MED_THRUST }, { 2.303, "dmgOff" },
      { 2.506, "follow" },
      { 2.622, "etp", 1 },
      { 2.639, "parry" },
      { 2.812, "look" },
      { 2.900, "dmgOn", D.MED_FINISH }, { 3.064, "dmgOff" },
      { 3.370, "follow" },
      { 3.972, "stop" },
    },
  },
  FastComboDash = {
    seq = "FastComboDash", rate = 2.0, stop = 1.5,
    ev = {
      { 1.245, "flash", 1 },
      { 1.394, "dash" },
    },
  },
  FastCombo = {
    seq = "FastCombo", rate = 0.8, stop = 3.0, fwdMin = 75, fwdMax = 125,
    ev = {
      { 0.172, "look" },
      { 0.266, "dmgOn", D.LIGHT_HIT }, { 0.372, "dmgOff" },
      { 0.482, "look" },
      { 0.617, "dmgOn", D.LIGHT_HIT }, { 0.702, "dmgOff" },
      { 0.739, "look" },
      { 0.854, "dmgOn", D.LIGHT_HIT }, { 0.955, "dmgOff" },
      { 1.212, "look" },
      { 1.265, "kickOn", D.LIGHT_HIT }, { 1.360, "dmgOff" },
      { 1.445, "follow" },
      { 1.621, "etp", 4 },
      { 1.679, "parry" },
      { 1.808, "look" },
      { 1.942, "dmgOn", D.LIGHT_FINISH }, { 2.219, "dmgOff" },
      { 2.318, "follow" },
      { 2.844, "stop" },
    },
  },
  SwordsCombine = {
    seq = "SwordsCombine", rate = 3.0, stop = 1.5,
    ev = {
      { 1.161, "gattai" },
      { 1.451, "chainThrow" },
    },
  },
  SwordsCombinedThrow = {
    seq = "SwordsCombinedThrow", rate = 2.0, stop = 2.1667,
    ev = {
      { 0.728, "etp", 4 },
      { 0.903, "flash", 0 },
      { 1.258, "throw" },
      { 2.079, "stop" },
    },
  },
  ThrowCombo = {
    seq = "ThrowCombo", rate = 1.25, stop = 3.8333, fwdMin = 125, fwdMax = 175,
    ev = {
      { 0.513, "parry" },
      { 0.658, "look" },
      { 0.862, "dmgOn", D.HEAVY_1 }, { 0.987, "dmgOff" },
      { 1.261, "etp", 12 },
      { 1.684, "parry" },
      { 1.801, "look" },
      { 1.926, "kickOn", D.HEAVY_2 },
      { 1.955, "dmgOn", D.HEAVY_2 }, { 2.101, "dmgOff" },
      { 2.410, "follow" },
      { 2.575, "gattai" },
      { 2.642, "etp", 4 },
      { 2.730, "flash", 0 },
      { 2.923, "throw" },
      { 3.707, "stop" },
    },
  },
  Juggle = { seq = "Juggle", rate = 0.85, stop = 0.6667, ev = {} },
  Enrage = {
    seq = "Enrage", rate = 0.5, stop = 1.15,
    ev = {
      { 0.584, "unenrage" },
      { 0.877, "stop" },
    },
  },
}

if SERVER then

  util.AddNetworkString( "ukg2_teleport_trail" )

  ------------------------------------------------------------------------------
  -- Init
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    self:SetMaxHealth( UKGabriel2.HP )
    self:SetHealth( UKGabriel2.HP )

    self.UKG2_Dead = false
    self.UKG2_Phase = 1
    self:SetSkin( 0 )              -- canon: spawns enraged (red)
    self:SetNW2Int( self.NW_PHASE, 1 )
    self:SetNW2Bool( self.NW_COMBINED, false )

    -- action system
    self.UKG2_ActionName = nil
    self.UKG2_ActionStart = 0
    self.UKG2_ActionUntil = nil
    self.UKG2_ActionEvIndex = 1
    self.UKG2_Tracking = false
    self.UKG2_Damaging = false
    self.UKG2_KickWindow = false
    self.UKG2_ActionHits = nil
    self.UKG2_Forward = false
    self.UKG2_FwdMin, self.UKG2_FwdMax = 125, 175
    self.UKG2_FreezeUntil = 0

    -- canon GabrielBase state
    self.UKG2_StartCooldown = 2
    self.UKG2_AttackCooldown = 0
    self.UKG2_PreTeleCD = 0
    self.UKG2_OutOfSight = 0
    self.UKG2_BurstLength = ( self:UKG2_Difficulty() >= 3 ) and 3 or 2
    self.UKG2_ReadyTaunt = false
    self.UKG2_PrevMove = -1
    self.UKG2_MoveBonus = { 0, 0, 0, 0 }

    -- combined swords
    self.UKG2_CombinedCD = 0
    self.UKG2_Thrown = nil
    self.UKG2_SwordsAway = false

    -- dash
    self.UKG2_Dashing = false
    self.UKG2_DashTarget = nil
    self.UKG2_DashAttempts = 0
    self.UKG2_ForcedDash = 0

    -- juggle / phase
    self.UKG2_Juggled = false
    self.UKG2_JuggleHp = 0
    self.UKG2_JuggleEndHp = 0
    self.UKG2_JuggleLen = 0
    self.UKG2_JuggleFalling = false
    self.UKG2_CeilingCD = 0

    -- spiral swords
    self.UKG2_Spirals = nil
    self.UKG2_SpiralPhase = nil     -- "orbit" | "formation" | nil
    self.UKG2_SpiralAt = 0
    self.UKG2_SpiralCD = UKGabriel2.SPIRAL_COOLDOWN
    self.UKG2_SpiralWindupAt = nil

    -- voice
    self.UKG2_UsedTaunts = {}
    self.UKG2_VoiceBusyUntil = 0
    self:UKG2_PlayVoice( UKGabriel2.VOICE.Intro, 0.85, 1 )

    self:SetParryable( false )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
    UltrakillBase.TraceSetPos( self, self:GetPos() + Vector( 0, 0, 27 ) ) -- x0.45 rescale
  end

  function ENT:OnRemove()
    self:UKG2_ClearProjectiles()
  end

  function ENT:UKG2_ClearProjectiles()
    if IsValid( self.UKG2_Thrown ) then self.UKG2_Thrown:Remove() end
    if self.UKG2_Spirals then
      for _, s in ipairs( self.UKG2_Spirals ) do
        if IsValid( s ) then s:Remove() end
      end
      self.UKG2_Spirals = nil
      self.UKG2_SpiralPhase = nil
    end
  end

  ------------------------------------------------------------------------------
  -- Difficulty / speed (canon UpdateSpeed)
  ------------------------------------------------------------------------------

  function ENT:UKG2_Difficulty()
    return self.UltrakillBase_Difficulty or 3
  end

  function ENT:UKG2_AnimSpeed()
    local diff = self:UKG2_Difficulty()
    if diff <= 0 then return 0.75 end
    if diff == 1 then return 0.85 end
    return 1.0
  end

  -- possession-aware target: stock DrGBase forces the enemy slot to NULL while
  -- possessed (UpdateEnemy/FetchEnemy both return NULL under possession), so
  -- the whole attack pipeline resolves its target here — the possessor's
  -- lock-on under possession (Kevin's binds pass PossessionGetLockedOn() the
  -- same way), plain GetEnemy() otherwise
  function ENT:UKG2_Target()
    if self:IsPossessed() then return self:PossessionGetLockedOn() end
    return self:GetEnemy()
  end

  ------------------------------------------------------------------------------
  -- Voice (canon GabrielVoice: priority + no-repeat taunt rotation)
  ------------------------------------------------------------------------------

  function ENT:UKG2_PlayVoice( pool, vol, priority )
    if not pool or #pool == 0 then return end
    priority = priority or 0
    local now = CurTime()
    if priority < ( self.UKG2_VoicePriority or 0 ) and now < self.UKG2_VoiceBusyUntil then
      return
    end
    local snd = pool[ math.random( #pool ) ]
    self:EmitSound( snd, 95, 100, vol or 1, CHAN_VOICE )
    self.UKG2_VoicePriority = priority
    self.UKG2_VoiceBusyUntil = now + ( SoundDuration( snd ) or 2 )
  end

  function ENT:UKG2_Taunt()
    local pool = ( self.UKG2_Phase >= 2 ) and UKGabriel2.VOICE.Taunt2
                                          or UKGabriel2.VOICE.Taunt1
    local used = self.UKG2_UsedTaunts
    local idx = math.random( #pool )
    if used[ idx ] then
      for i = 1, #pool do
        if not used[ i ] then idx = i break end
      end
    end
    local count = 0
    for _ in pairs( used ) do count = count + 1 end
    if count >= #pool - 1 then self.UKG2_UsedTaunts = {} used = self.UKG2_UsedTaunts end
    used[ idx ] = true
    self:EmitSound( pool[ idx ], 95, 100, 0.85, CHAN_VOICE )
    self.UKG2_VoicePriority = 1
    self.UKG2_VoiceBusyUntil = CurTime() + ( SoundDuration( pool[ idx ] ) or 2 )
  end

  ------------------------------------------------------------------------------
  -- Action system (ferryman pattern + per-action animator rate)
  ------------------------------------------------------------------------------

  function ENT:UKG2_InAction()
    if self.UKG2_Dashing or self.UKG2_Juggled then return true end
    if self.UKG2_ActionUntil and self.UKG2_ActionUntil > CurTime() then return true end
    if self.UKG2_ActionName then self:UKG2_EndAction() end
    return false
  end

  function ENT:UKG2_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKG2_AnimSpeed()

    local enemy = self:UKG2_Target()
    if IsValid( enemy ) and name ~= "Juggle" and name ~= "Enrage" then
      self:FaceInstant( enemy:GetPos() )
    end

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( cfg.rate * spd )
    end

    self.UKG2_ActionName = name
    self.UKG2_ActionStart = CurTime()
    self.UKG2_ActionUntil = CurTime() + cfg.stop / ( cfg.rate * spd )
    self.UKG2_ActionEvIndex = 1
    self.UKG2_Tracking = false
    self.UKG2_Damaging = false
    self.UKG2_KickWindow = false
    self.UKG2_Forward = false
    self.UKG2_ActionHits = {}
    self.UKG2_FwdMin = cfg.fwdMin or 125
    self.UKG2_FwdMax = cfg.fwdMax or 175

    self.CantMove = true
    self:SetMaxYawRate( 0 )
    self.loco:SetVelocity( vector_origin )
  end

  function ENT:UKG2_EndAction()
    self.UKG2_ActionName = nil
    self.UKG2_ActionUntil = nil
    self.UKG2_Tracking = false
    self.UKG2_Damaging = false
    self.UKG2_KickWindow = false
    self.UKG2_Forward = false
    if not ( self.UKG2_Dashing or self.UKG2_Juggled ) then
      self.CantMove = false
    end
    self:SetParryable( false )
    self:SetMaxYawRate( self.MaxYawRate )
    self:SetPlaybackRate( 1 )
  end

  function ENT:UKG2_ProcessEvents()
    local name = self.UKG2_ActionName
    local cfg = name and ACTION[ name ]
    if not cfg then return end
    local t = ( CurTime() - self.UKG2_ActionStart ) * cfg.rate * self:UKG2_AnimSpeed()

    while self.UKG2_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKG2_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKG2_ActionEvIndex = self.UKG2_ActionEvIndex + 1
      self:UKG2_FireEvent( ev[ 2 ], ev[ 3 ] )
      if self.UKG2_ActionName ~= name then return end -- action switched mid-loop
    end
  end

  function ENT:UKG2_FireEvent( kind, arg )
    local enemy = self:UKG2_Target()

    if kind == "flash" then
      if self.CreateAlert then
        self:CreateAlert( self:UKG2_HeadPos() + self:GetForward() * 20,
          ( arg == 1 ) and 2 or 1, 3 )
      end

    elseif kind == "parry" then
      -- canon Parryable -> mach.ParryableCheck; window dies with the swing
      self:SetParryable( true )
      if self.CreateAlert then
        self:CreateAlert( self:UKG2_HeadPos() + self:GetForward() * 20, 1, 3 )
      end

    elseif kind == "look" then
      if IsValid( enemy ) then self:FaceInstant( enemy:EyePos() ) end
      self.UKG2_Tracking = false

    elseif kind == "follow" then
      self.UKG2_Tracking = true

    elseif kind == "dmgOn" or kind == "kickOn" then
      self:UKG2_StartDamage( arg or 20, kind == "kickOn" )

    elseif kind == "dmgOff" then
      self:UKG2_StopDamage()

    elseif kind == "etp" then
      self:UKG2_EnrageTeleport( arg or 0 )

    elseif kind == "dash" then
      self:UKG2_StartDash()

    elseif kind == "gattai" then
      self:UKG2_Gattai()

    elseif kind == "chainThrow" then
      -- canon CombinedSwordAttack: anim.Play("SwordsCombinedThrow")
      self:UKG2_EndAction()
      self:UKG2_StartAction( "SwordsCombinedThrow" )

    elseif kind == "throw" then
      self:UKG2_ThrowSwords()

    elseif kind == "unenrage" then
      self:UKG2_UnEnrage()

    elseif kind == "stop" then
      self:UKG2_EndAction()
      self.UKG2_ActionUntil = nil
    end
  end

  function ENT:UKG2_HeadPos()
    local id = self:LookupAttachment( "head" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter() + Vector( 0, 0, 27 ) -- x0.45 rescale
  end

  function ENT:UKG2_RightHandPos()
    local id = self:LookupAttachment( "righthand" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter() + self:GetForward() * 40
  end

  ------------------------------------------------------------------------------
  -- Melee damage (canon SwingCheck2: sword capsules + general 4x6x5 m box)
  ------------------------------------------------------------------------------

  function ENT:UKG2_StartDamage( damage, isKick )
    self.UKG2_Damaging = true
    self.UKG2_KickWindow = isKick or false
    self.UKG2_Damage = damage
    self.UKG2_ActionHits = {}
    -- canon: swing audio per window (RandomPitch 0.2)
    self:EmitSound( isKick and UKGabriel2.SOUND.KickSwing or UKGabriel2.SOUND.Swing,
      85, math.random( 85, 115 ), 1 )
    -- canon DamageStart -> goForward = true + DecideMovementSpeed
    self.UKG2_Forward = true
    self:UKG2_DecideMoveSpeed()
  end

  function ENT:UKG2_StopDamage()
    self.UKG2_Damaging = false
    self.UKG2_KickWindow = false
    self.UKG2_Forward = false
    self:SetParryable( false ) -- canon Unparryable in DamageStopped
  end

  function ENT:UKG2_DecideMoveSpeed()
    local enemy = self:UKG2_Target()
    local spd = self:UKG2_AnimSpeed()
    local far = IsValid( enemy )
      and self:GetPos():Distance( enemy:GetPos() + enemy:GetVelocity() * 0.25 ) > 20 * UNIT
    local base = far and self.UKG2_FwdMax or self.UKG2_FwdMin
    if self:UKG2_Difficulty() <= 1 then base = self.UKG2_FwdMin end
    self.UKG2_FwdSpeed = base * UNIT * spd
  end

  function ENT:UKG2_ApplyMeleeDamage()
    if not self.UKG2_Damaging then return end
    local hits = self.UKG2_ActionHits or {}
    self.UKG2_ActionHits = hits

    -- canon reach: general SwingCheck 4x6x5 m box at +2.5 m; sword capsules
    -- ~2.5 m. Approximated as a sphere ahead of the chest.
    local center = self:WorldSpaceCenter() + self:GetForward() * ( 2.5 * UNIT )
    local radius = ( self.UKG2_KickWindow and 3 or 2.6 ) * UNIT

    for _, ent in ipairs( ents.FindInSphere( center, radius ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKG2_IsGabriel then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKGabriel2.ScaleAttackDamage( ent, self.UKG2_Damage or 20, self ) )
      dmg:SetDamageType( self.UKG2_KickWindow and DMG_CLUB or DMG_SLASH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 1500 + Vector( 0, 0, 150 ) )
      ent:TakeDamageInfo( dmg )

      -- canon TargetBeenHit: a landed hit closes the whole swing
      self.UKG2_Damaging = false
      break
    end
  end

  ------------------------------------------------------------------------------
  -- Teleports (canon Teleport + EnrageTeleport + decoy ghost trail)
  ------------------------------------------------------------------------------

  function ENT:UKG2_SendTrail( from, to )
    net.Start( "ukg2_teleport_trail" )
    net.WriteEntity( self )
    net.WriteVector( from )
    net.WriteVector( to )
    net.WriteUInt( math.max( self:GetSequence(), 0 ), 12 )
    net.WriteFloat( self:GetCycle() )
    net.WriteUInt( self:GetSkin(), 4 )
    net.Broadcast()
  end

  function ENT:UKG2_Teleport( closeRange, longrange, horizontal )
    local enemy = self:UKG2_Target()
    if not IsValid( enemy ) then return end
    local eyes = enemy:IsPlayer() and enemy:EyePos() or enemy:WorldSpaceCenter()
    local mins, maxs = self:GetCollisionBounds()

    for attempt = 1, 10 do
      local dir = VectorRand()
      if dir:IsZero() then dir = Vector( 0, 0, 1 ) end
      dir:Normalize()
      if dir.z < 0 then dir.z = -dir.z end

      local dist = math.Rand( 8, 15 )
      if closeRange then dist = math.Rand( 5, 8 )
      elseif longrange then dist = math.Rand( 15, 20 ) end
      dist = dist * UNIT

      local base = eyes + Vector( 0, 0, 18 ) -- x0.45 rescale
      local tr = util.TraceLine( { start = base, endpos = base + dir * dist,
                                   mask = MASK_SOLID_BRUSHONLY } )
      local pos = tr.Hit and ( tr.HitPos - dir * ( 3 * UNIT ) ) or ( base + dir * dist )

      if horizontal then
        -- canon horizontal variants park him at head height (+3.5 m over floor)
        local down = util.TraceLine( { start = pos, endpos = pos - Vector( 0, 0, 8 * UNIT ),
                                       mask = MASK_SOLID_BRUSHONLY } )
        pos.z = down.Hit and ( down.HitPos.z + 3.5 * UNIT ) or eyes.z
      end

      -- feet-origin hull clearance check
      local hullPos = pos - Vector( 0, 0, maxs.z * 0.5 )
      local hull = util.TraceHull( { start = hullPos, endpos = hullPos,
                                     mins = mins, maxs = maxs,
                                     mask = MASK_SOLID_BRUSHONLY } )
      if not hull.Hit then
        local from = self:GetPos()
        self:SetPos( hullPos )
        sound.Play( UKGabriel2.SOUND.Teleport, hullPos, 80, 100, 0.9 )
        self:UKG2_SendTrail( from, hullPos )
        self.UKG2_OutOfSight = 0
        if IsValid( enemy ) then self:FaceInstant( enemy:EyePos() ) end
        return true
      end
    end
    return false
  end

  -- canon EnrageTeleport: phase 2 only, blocked while the combined swords fly
  function ENT:UKG2_EnrageTeleport( teleportType )
    local enemy = self:UKG2_Target()
    if self.UKG2_Phase >= 2 and not IsValid( self.UKG2_Thrown ) then
      if teleportType >= 10 then
        if self:UKG2_Difficulty() <= 2 then
          if IsValid( enemy ) then self:FaceInstant( enemy:EyePos() ) end
          return
        end
        teleportType = teleportType - 10
      end
      if teleportType <= 0 then teleportType = 2 end

      if teleportType == 1 then
        self:UKG2_Teleport( true, false, false )
      elseif teleportType == 2 then
        self:UKG2_Teleport( false, false, false )
      elseif teleportType == 3 then
        self:UKG2_Teleport( true, false, true )
      elseif teleportType == 4 then
        self:UKG2_Teleport( false, false, true )
      else
        self:UKG2_Teleport( false, false, false )
      end

      -- canon: anim.speed = 0 for 0.25 s after the blink
      local now = CurTime()
      self.UKG2_FreezeUntil = now + 0.25 / self:UKG2_AnimSpeed()
      self:SetPlaybackRate( 0 )
      -- shift action timing so clip time effectively pauses too
      self.UKG2_ActionStart = self.UKG2_ActionStart + 0.25 / self:UKG2_AnimSpeed()
      if self.UKG2_ActionUntil then
        self.UKG2_ActionUntil = self.UKG2_ActionUntil + 0.25 / self:UKG2_AnimSpeed()
      end
    end
    if IsValid( enemy ) then self:FaceInstant( enemy:EyePos() ) end
  end

  ------------------------------------------------------------------------------
  -- Dash (canon StartDash / AttackMovement dashing branch / DashAttack)
  ------------------------------------------------------------------------------

  function ENT:UKG2_StartDash()
    local enemy = self:UKG2_Target()
    if not IsValid( enemy ) then return end
    self.UKG2_Dashing = true
    self.UKG2_DashTarget = enemy:GetPos() + Vector( 0, 0, 40 )
    self.UKG2_DashAttempts = 0
    self.UKG2_ForcedDash = 0
    self.CantMove = true
    self:FaceInstant( self.UKG2_DashTarget )
    self:EmitSound( UKGabriel2.SOUND.Dash, 80, 100, 0.5 )
  end

  function ENT:UKG2_DashThink( dt )
    local spd = self:UKG2_AnimSpeed()
    local pos = self:WorldSpaceCenter()
    local target = self.UKG2_DashTarget or pos

    if self.UKG2_ForcedDash > 0 then
      self.UKG2_ForcedDash = math.max( self.UKG2_ForcedDash - dt * spd, 0 )
    end

    local dist = pos:Distance( target )
    if dist > 5 * UNIT and self.UKG2_DashAttempts < 5 then
      local tr = util.TraceHull( {
        start = pos, endpos = target,
        mins = Vector( -20, -20, -20 ), maxs = Vector( 20, 20, 20 ),
        filter = self, mask = MASK_SOLID_BRUSHONLY,
      } )
      if tr.Hit then
        self.UKG2_DashAttempts = self.UKG2_DashAttempts + 1
        local enemy = self:UKG2_Target()
        self:UKG2_Teleport( false, true, false )
        self.UKG2_DashTarget = IsValid( enemy )
          and ( enemy:EyePos() ) or target
        self.UKG2_ForcedDash = 0.35
        return
      end
      local dir = ( target - pos ):GetNormalized()
      self:SetAngles( Angle( 0, dir:Angle().y, 0 ) )
      local vel = dir * ( 100 * UNIT * spd )
      self.loco:SetDesiredSpeed( vel:Length() )
      self.loco:Approach( self:GetPos() + dir * 100, 1 )
      self.loco:SetVelocity( vel )
    elseif self.UKG2_ForcedDash <= 0 then
      self.UKG2_Dashing = false
      self.UKG2_DashAttempts = 0
      self.loco:SetVelocity( vector_origin )
      -- canon DashAttack -> FastCombo
      self:UKG2_StartAction( "FastCombo" )
    end
  end

  ------------------------------------------------------------------------------
  -- Combined swords (canon Gattai / ThrowSwords / UnGattai / light swords)
  ------------------------------------------------------------------------------

  function ENT:UKG2_SetSwordsVisible( visible )
    local bg = self:FindBodygroupByName( "swords" )
    if bg and bg >= 0 then self:SetBodygroup( bg, visible and 0 or 1 ) end
  end

  function ENT:UKG2_Gattai()
    self:UKG2_SetSwordsVisible( false )
    self:SetNW2Bool( self.NW_COMBINED, true )
    self:EmitSound( UKGabriel2.SOUND.SummonSpawn, 80, 120, 0.7 )
  end

  function ENT:UKG2_ThrowSwords()
    self:SetNW2Bool( self.NW_COMBINED, false )
    local enemy = self:UKG2_Target()
    local diff = self:UKG2_Difficulty()

    self:EmitSound( UKGabriel2.SOUND.KickSwing, 85, math.random( 90, 110 ), 1 )

    local proj = ents.Create( "ultrakill_test_gabriel2_swords_projectile" )
    if not IsValid( proj ) then return end
    local from = self:UKG2_RightHandPos()
    local speed = UKGabriel2.THROWN_SPEED
      * ( diff >= 4 and UKGabriel2.THROWN_SPEED_HARD or 1 )
    proj:SetPos( from )
    local dir
    if IsValid( enemy ) then
      dir = ( enemy:EyePos() - from ):GetNormalized()
    elseif self:IsPossessed() then
      -- no lock-on: aim at the possessor's crosshair (DrGBase AimProjectile pattern)
      local tr = self:PossessorTrace()
      dir = tr and ( tr.HitPos - from ):GetNormalized() or self:GetForward()
    else
      dir = self:GetForward()
    end
    proj:SetAngles( dir:Angle() )
    proj:SetOwner( self )
    proj.UKG2S_Owner = self
    proj.UltrakillBase_Target = enemy
    proj.UltrakillBase_HomingSpeed = speed
    proj:Spawn()
    proj:SetVelocity( dir * speed )

    self.UKG2_Thrown = proj
    self.UKG2_SwordsAway = true
    -- canon: combinedSwordsCooldown = (difficulty > 2) ? 1 : 2
    self.UKG2_CombinedCD = ( diff > 2 ) and 1 or 2
  end

  -- projectile died (hit/parry/recall) -> real swords come back to the hands
  -- (called from the projectile's OnRemove — every death path lands here)
  function ENT:UKG2_SwordsReturned()
    self.UKG2_Thrown = nil
    if not self.UKG2_SwordsAway then return end
    self.UKG2_SwordsAway = false
    self:SetNW2Bool( self.NW_COMBINED, false )
    self:UKG2_SetSwordsVisible( true )
    if not self.UKG2_Dead then
      self:EmitSound( UKGabriel2.SOUND.TeleportHigh, 75, 100, 0.9 )
    end
  end

  -- canon CheckIfSwordsCombined at combo start
  function ENT:UKG2_CheckSwordsForCombo()
    if not self.UKG2_SwordsAway then return end
    if self.UKG2_Phase >= 2 then
      -- canon CreateLightSwords: fights with light-construct copies
      self:UKG2_SetSwordsVisible( true )
    elseif IsValid( self.UKG2_Thrown ) then
      -- canon UnGattai(destroySwords = true); OnRemove hands the swords back
      self.UKG2_Thrown:Remove()
    end
  end

  ------------------------------------------------------------------------------
  -- Spiral swords (canon SummonedSwords, Violent+; Brutal+ formation stab)
  ------------------------------------------------------------------------------

  function ENT:UKG2_SpawnSpiralWindup()
    self.UKG2_SpiralWindupAt = CurTime() + 1 / self:UKG2_AnimSpeed()
    self:EmitSound( UKGabriel2.SOUND.SummonWindup, 85, 100, 1 )
  end

  function ENT:UKG2_SpawnSpirals()
    self.UKG2_SpiralWindupAt = nil
    self:UKG2_ClearSpirals( true )
    local swords = {}
    for i = 1, UKGabriel2.SPIRAL_COUNT do
      local s = ents.Create( "ultrakill_test_gabriel2_zwei_projectile" )
      if IsValid( s ) then
        s.UKG2Z_Owner = self
        s.UKG2Z_Mode = "orbit"
        s.UKG2Z_Index = i
        s:SetPos( self:WorldSpaceCenter() )
        s:SetOwner( self )
        s:Spawn()
        swords[ #swords + 1 ] = s
      end
    end
    self.UKG2_Spirals = swords
    self.UKG2_SpiralPhase = "orbit"
    self.UKG2_SpiralAt = CurTime()
  end

  function ENT:UKG2_ClearSpirals( silent )
    if not self.UKG2_Spirals then return end
    for _, s in ipairs( self.UKG2_Spirals ) do
      if IsValid( s ) then
        if silent then s:Remove() else s:UKG2Z_Break() end
      end
    end
    self.UKG2_Spirals = nil
    self.UKG2_SpiralPhase = nil
  end

  function ENT:UKG2_SpiralsAlive()
    if not self.UKG2_Spirals then return false end
    for _, s in ipairs( self.UKG2_Spirals ) do
      if IsValid( s ) then return true end
    end
    self.UKG2_Spirals = nil
    self.UKG2_SpiralPhase = nil
    return false
  end

  function ENT:UKG2_SpiralThink()
    if not self:UKG2_SpiralsAlive() then return end
    local now = CurTime()
    local t = now - self.UKG2_SpiralAt
    local spd = self:UKG2_AnimSpeed()
    local phase = self.UKG2_SpiralPhase
    local enemy = self:UKG2_Target()

    if phase == "orbit" then
      local center = self:WorldSpaceCenter()
      for _, s in ipairs( self.UKG2_Spirals ) do
        if IsValid( s ) then
          local ang = math.rad( ( s.UKG2Z_Index - 1 ) * ( 360 / UKGabriel2.SPIRAL_COUNT )
            + t * UKGabriel2.SPIRAL_ORBIT_DEG * spd )
          local off = Vector( math.cos( ang ), math.sin( ang ), 0 ) * ( 2.5 * UNIT )
          s:SetPos( center + off )
          s:SetAngles( Angle( 0, math.deg( ang ) + 90, 0 ) )
        end
      end
      -- canon Begin after 5 s
      if t >= UKGabriel2.SPIRAL_LIFE / spd then
        if self:UKG2_Difficulty() > 3 and IsValid( enemy ) then
          self.UKG2_SpiralPhase = "formation"
          self.UKG2_SpiralAt = now
          local eyes = enemy:EyePos()
          self.UKG2_SpiralCenter = eyes
          for _, s in ipairs( self.UKG2_Spirals ) do
            if IsValid( s ) then
              s.UKG2Z_Mode = "formation"
              local ang = math.rad( ( s.UKG2Z_Index - 1 ) * ( 360 / UKGabriel2.SPIRAL_COUNT ) )
              local off = Vector( math.cos( ang ), math.sin( ang ), 0 ) * UKGabriel2.SPIRAL_ORBIT_R
              s:SetPos( eyes + off )
              -- canon: rotated to face the center
              s:SetAngles( ( -off ):Angle() )
            end
          end
          sound.Play( UKGabriel2.SOUND.Teleport, eyes, 75, 130, 0.8 )
        else
          -- canon: below Brutal the shield just shatters after its lifetime
          self:UKG2_ClearSpirals( false )
        end
      end

    elseif phase == "formation" then
      -- canon: ring follows the player, spins 0.75 s, flashes, stabs at 1 s
      if IsValid( enemy ) then
        local eyes = enemy:EyePos()
        self.UKG2_SpiralCenter = eyes
        local spin = ( t < 0.75 / spd )
          and t * UKGabriel2.SPIRAL_ORBIT_DEG * spd or nil
        for _, s in ipairs( self.UKG2_Spirals ) do
          if IsValid( s ) and s.UKG2Z_Mode == "formation" then
            local base = ( s.UKG2Z_Index - 1 ) * ( 360 / UKGabriel2.SPIRAL_COUNT )
            local ang = math.rad( base + ( spin or 0 ) )
            local off = Vector( math.cos( ang ), math.sin( ang ), 0 ) * UKGabriel2.SPIRAL_ORBIT_R
            s:SetPos( eyes + off )
            s:SetAngles( ( -off ):Angle() )
          end
        end
      end
      if not self.UKG2_SpiralFlashed and t >= 0.75 / spd then
        self.UKG2_SpiralFlashed = true
        -- canon StopSpinning: parry flash on every sword (now deflectable)
        for _, s in ipairs( self.UKG2_Spirals ) do
          if IsValid( s ) and self.CreateAlert then
            self:CreateAlert( s:WorldSpaceCenter(), 1, 3 )
          end
        end
      end
      if t >= 1 / spd then
        local center = self.UKG2_SpiralCenter or ( IsValid( enemy ) and enemy:EyePos() )
        for _, s in ipairs( self.UKG2_Spirals ) do
          if IsValid( s ) and s.UKG2Z_Mode == "formation" and isvector( center ) then
            s:UKG2Z_Stab( ( center - s:GetPos() ):GetNormalized() )
          end
        end
        self.UKG2_Spirals = nil
        self.UKG2_SpiralPhase = nil
        self.UKG2_SpiralFlashed = nil
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Juggle / phase change (canon JuggleStart / JuggleUpdate / JuggleStop)
  ------------------------------------------------------------------------------

  function ENT:UKG2_JuggleStart()
    self:UKG2_EndAction()
    self.UKG2_Dashing = false
    self.UKG2_Juggled = true
    -- canon: secondPhase flips at juggle START (taunt pool, teleports, gates);
    -- the visual un-enrage (skin swap) happens later inside the Enrage clip
    self.UKG2_Phase = 2
    self:SetNW2Int( self.NW_PHASE, 2 )
    self.UKG2_NeedPhaseAnim = true
    self.UKG2_JuggleHp = self:Health()
    -- canon gabe2 quota: 7.5 canon hp (x1000)
    self.UKG2_JuggleEndHp = self:Health() - 7500
    self.UKG2_JuggleLen = 5
    self.UKG2_JuggleFalling = false
    self.CantMove = true

    self:UKG2_PlayVoice( UKGabriel2.VOICE.BigHurt, 1, 2 )
    self:EmitSound( UKGabriel2.SOUND.Juggle, 90, 100, 1 )

    local enemy = self:UKG2_Target()
    if IsValid( enemy ) then
      local flat = enemy:GetPos()
      flat.z = self:GetPos().z
      self:FaceInstant( flat )
    end

    local seq = self:LookupSequence( "Juggle" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetCycle( 0 )
      self:SetPlaybackRate( ACTION.Juggle.rate * self:UKG2_AnimSpeed() )
    end

    -- canon: gravity back on + 35 m/s up
    self:LeaveGround()
    self.loco:SetGravity( 600 )
    self.loco:SetVelocity( Vector( 0, 0, 35 * UNIT ) )
  end

  function ENT:UKG2_JuggleThink( dt )
    local spd = self:UKG2_AnimSpeed()
    self.UKG2_JuggleLen = math.max( self.UKG2_JuggleLen - dt * spd, 0 )
    local vel = self.loco:GetVelocity()

    -- canon cap: up velocity <= 35 m/s, XZ zeroed
    local vz = math.min( vel.z, 35 * UNIT )
    self.loco:SetVelocity( Vector( 0, 0, vz ) )

    -- damage bounces (canon JuggleUpdate)
    local hp = self:Health()
    if hp < self.UKG2_JuggleHp then
      local deltaCanon = ( self.UKG2_JuggleHp - hp ) / 1000
      self.UKG2_JuggleHp = hp
      local up = math.max( vz, 0 ) + deltaCanon * 10 * UNIT
      self.loco:SetVelocity( Vector( 0, 0, math.min( up, 35 * UNIT ) ) )
      local seq = self:LookupSequence( "Juggle" )
      if seq and seq >= 0 then
        self:ResetSequence( seq )
        self:SetCycle( 0 )
        self:SetPlaybackRate( ACTION.Juggle.rate * spd )
      end
      self:UKG2_PlayVoice( UKGabriel2.VOICE.Hurt, 0.75, 0 )
      if hp < self.UKG2_JuggleEndHp or self.UKG2_JuggleLen <= 0 then
        self:UKG2_JuggleStop()
        return
      end
    end

    -- ceiling bounce (canon CeilingCheck)
    if self.UKG2_CeilingCD > 0 then
      self.UKG2_CeilingCD = math.max( self.UKG2_CeilingCD - dt, 0 )
    elseif vz > 1 * UNIT then
      local head = self:UKG2_HeadPos()
      local tr = util.TraceLine( { start = head,
        endpos = head + Vector( 0, 0, 3 * UNIT + vz * dt ),
        filter = self, mask = MASK_SOLID_BRUSHONLY } )
      if tr.Hit then
        self.UKG2_CeilingCD = 0.5
        self.loco:SetVelocity( Vector( 0, 0, -vz ) )
        self:UKG2_PlayVoice( UKGabriel2.VOICE.Hurt, 0.75, 0 )
        local fx = EffectData()
        fx:SetOrigin( tr.HitPos )
        util.Effect( "cball_bounce", fx, true, true )
      end
    end

    -- landing while falling (canon SphereCast down 3.6 m)
    local falling = self.loco:GetVelocity().z < 0
    if self.UKG2_JuggleFalling and falling then
      local tr = util.TraceHull( {
        start = self:GetPos() + Vector( 0, 0, 10 ),
        endpos = self:GetPos() - Vector( 0, 0, 3.6 * UNIT ),
        mins = Vector( -25, -25, 0 ), maxs = Vector( 25, 25, 10 ),
        filter = self, mask = MASK_SOLID_BRUSHONLY,
      } )
      if tr.Hit then
        self:UKG2_JuggleStop()
        return
      end
    end
    if self.UKG2_JuggleLen <= 0 and falling and self:IsOnGround() then
      self:UKG2_JuggleStop()
      return
    end
    self.UKG2_JuggleFalling = falling
  end

  function ENT:UKG2_JuggleStop()
    self.UKG2_Juggled = false
    self.loco:SetGravity( 0 ) -- DrGBase flying default
    self.loco:SetVelocity( vector_origin )
    self.CantMove = false
    local diff = self:UKG2_Difficulty()
    self.UKG2_BurstLength = ( diff == 0 ) and 1 or diff

    self:UKG2_PlayVoice( UKGabriel2.VOICE.PhaseChange, 1, 3 )

    if self.UKG2_NeedPhaseAnim then
      -- canon EnrageAnimation -> UnEnrage inside the Enrage clip
      self:UKG2_StartAction( "Enrage" )
      if diff >= 3 then self:UKG2_SpawnSpiralWindup() end
    else
      self.UKG2_AttackCooldown = 1
      self:UKG2_Teleport()
    end
  end

  -- canon UnEnrage: red -> normal look, phase 2 combat rules kick in
  function ENT:UKG2_UnEnrage()
    self.UKG2_NeedPhaseAnim = nil
    self:SetSkin( 1 )
    local diff = self:UKG2_Difficulty()
    self.UKG2_BurstLength = ( diff == 0 ) and 1 or diff
    self.UKG2_AttackCooldown = 0
    if diff >= 3 then
      self:UKG2_SpawnSpirals()
    end
  end

  ------------------------------------------------------------------------------
  -- ChooseAttack (canon GabrielSecond.ChooseAttack, verbatim logic)
  ------------------------------------------------------------------------------

  function ENT:UKG2_ChooseAttack( enemy )
    local dist = self:GetPos():Distance( enemy:GetPos() )
    local close = dist < 5 * UNIT
    local far = dist > 20 * UNIT
    local diff = self:UKG2_Difficulty()

    local scores = { 0, 0, 0, 0 }
    for i = 0, 3 do
      if self.UKG2_PrevMove ~= i then
        local ok
        if i == 0 or i == 1 then ok = not close else ok = not far end
        if ok then
          scores[ i + 1 ] = math.Rand( 0, 1 ) + self.UKG2_MoveBonus[ i + 1 ]
        end
      end
    end

    local best, num = 0, -1
    for i = 1, 4 do
      if scores[ i ] > best then
        best = scores[ i ]
        num = i - 1
      end
    end

    if num == 0 then
      -- canon CombineSwords (ends in the throw)
      self:UKG2_CheckSwordsForCombo()
      self:UKG2_StartAction( "SwordsCombine" )
    elseif num == 1 then
      self:UKG2_CheckSwordsForCombo()
      self:UKG2_StartAction( "FastComboDash" )
    elseif num == 2 then
      self:UKG2_CheckSwordsForCombo()
      self:UKG2_StartAction( "BasicCombo" )
    elseif num == 3 then
      self:UKG2_CheckSwordsForCombo()
      self:UKG2_StartAction( "ThrowCombo" )
    end

    self.UKG2_PrevMove = num
    for i = 1, 4 do
      self.UKG2_MoveBonus[ i ] = ( ( i - 1 ) == num ) and 0
        or ( self.UKG2_MoveBonus[ i ] + 0.25 )
    end

    if num ~= 0 then
      if self.UKG2_BurstLength > 1 then
        self.UKG2_BurstLength = self.UKG2_BurstLength - 1
      else
        self.UKG2_BurstLength = ( diff >= 3 ) and 3 or 2
        self.UKG2_AttackCooldown = ( diff <= 3 ) and 3 or ( 5 - diff )
        self.UKG2_ReadyTaunt = true
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Base hooks
  ------------------------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    if self.UKG2_ActionName and self.UKG2_ActionUntil
        and self.UKG2_ActionUntil > CurTime() then
      local cfg = ACTION[ self.UKG2_ActionName ]
      local rate = ( CurTime() < self.UKG2_FreezeUntil ) and 0
        or ( cfg.rate * self:UKG2_AnimSpeed() )
      return cfg.seq, rate
    end
    if self.UKG2_Juggled then
      return "Juggle", ACTION.Juggle.rate * self:UKG2_AnimSpeed()
    end
    if self.UKG2_Dashing then
      -- canon: FastComboDash has no exit transition — the pose holds mid-dash
      return "FastComboDash", 0
    end
    return "Idle", 1
  end

  function ENT:OnUpdateSpeed()
    return self.WalkSpeed
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are scheduled canon-style in CustomThink
    return
  end

  function ENT:OnPossession()
    -- dash/juggle/combo lunges drive per-tick loco:SetVelocity; returning true
    -- skips the possession movement pass (ApproachFlying / zero-velocity idle)
    -- so it can't fight them, and skips the coroutine binds (attack anti-spam)
    return self:UKG2_InAction()
  end

  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    -- a parry interrupts the current swing (canon: stagger + window closes)
    self:UKG2_StopDamage()
    self:UKG2_EndAction()
    -- interrupted between Gattai and the throw: hand the real swords back
    if self:GetNW2Bool( self.NW_COMBINED, false ) and not IsValid( self.UKG2_Thrown ) then
      self:SetNW2Bool( self.NW_COMBINED, false )
      self:UKG2_SetSwordsVisible( true )
    end
    self.UKG2_AttackCooldown = math.max( self.UKG2_AttackCooldown, 1 )
    self.UKG2_ReadyTaunt = true
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKG2_Dead then return end
    -- canon: x0.5 damage taken while juggled
    if self.UKG2_Juggled then
      dmg:SetDamage( dmg:GetDamage() * 0.5 )
    end
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Think (canon Update + UpdateCooldowns + FixedUpdate)
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKG2_Dead then return end
    if self:IsAIDisabled() then -- ai_disabled / per-bot disable
      -- дэш/джаггл/комбо-выпады (UKG2_Forward) гонят его через по-тиковый
      -- loco:SetVelocity — замороженный мид-мув иначе дрейфует с последней
      -- скоростью за край карты (в т.ч. за drgbase_ai_radius)
      if self.loco then self.loco:SetVelocity( vector_origin ) end
      return
    end

    local now = CurTime()
    local dt = now - ( self.UKG2_LastThink or now )
    self.UKG2_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    local spd = self:UKG2_AnimSpeed()
    local enemy = self:UKG2_Target() -- possessed: possessor's lock-on (base NULLs GetEnemy)
    local possessed = self:IsPossessed()

    -- restore anim speed after a teleport freeze
    if self.UKG2_FreezeUntil > 0 and now >= self.UKG2_FreezeUntil then
      self.UKG2_FreezeUntil = 0
      local cfg = self.UKG2_ActionName and ACTION[ self.UKG2_ActionName ]
      if cfg then self:SetPlaybackRate( cfg.rate * spd ) end
    end

    -- phase change trigger (canon Update)
    if self.UKG2_Phase == 1 and not self.UKG2_Juggled
        and self:Health() <= self:GetMaxHealth() * UKGabriel2.PHASE2_FRAC then
      self:UKG2_JuggleStart()
    end

    -- the spiral shield is its own object in canon: keeps orbiting mid-juggle
    self:UKG2_SpiralThink()

    if self.UKG2_Juggled then
      self:UKG2_JuggleThink( dt )
      return
    end

    -- spiral windup fires even out of actions
    if self.UKG2_SpiralWindupAt and now >= self.UKG2_SpiralWindupAt then
      self:UKG2_SpawnSpirals()
    end

    -- canon UpdateCooldowns
    if self.UKG2_StartCooldown > 0 then
      self.UKG2_StartCooldown = math.max( self.UKG2_StartCooldown - dt * spd, 0 )
    end
    if self.UKG2_PreTeleCD > 0 then
      self.UKG2_PreTeleCD = math.max( self.UKG2_PreTeleCD - dt * spd, 0 )
    end
    if self.UKG2_CombinedCD > 0 then
      self.UKG2_CombinedCD = math.max( self.UKG2_CombinedCD - dt, 0 )
      if self.UKG2_Phase >= 2 or not IsValid( self.UKG2_Thrown ) then
        self.UKG2_CombinedCD = 0
      end
    end
    -- possessed: the cooldown still charges (for the IN_RELOAD bind) but the
    -- auto-summon decision stays off
    if ( ( self.UKG2_Phase >= 2 and self:UKG2_Difficulty() >= 3 ) or possessed )
        and not self:UKG2_SpiralsAlive() and not self.UKG2_SpiralWindupAt then
      self.UKG2_SpiralCD = math.max( self.UKG2_SpiralCD - dt * spd, 0 )
      if not possessed and self.UKG2_SpiralCD <= 0 and not self:UKG2_InAction() and self.UKG2_ReadyTaunt then
        self.UKG2_SpiralCD = UKGabriel2.SPIRAL_COOLDOWN
        self:UKG2_SpawnSpiralWindup()
      end
    end
    if not self:UKG2_InAction() and self.UKG2_AttackCooldown > 0 then
      self.UKG2_AttackCooldown = math.max( self.UKG2_AttackCooldown - dt * spd, 0 )
      if self.UKG2_ReadyTaunt then
        self:UKG2_Taunt()
        self.UKG2_ReadyTaunt = false
      end
    end

    if not IsValid( enemy ) and not possessed then
      if self:UKG2_InAction() and not self.UKG2_Juggled then
        self.UKG2_Dashing = false
        self:UKG2_EndAction()
      end
      return
    end

    -- possessed with no lock-on: enemy is NULL but bind-started actions still
    -- need the event/movement pipeline below (its enemy uses are all guarded)
    local eyes, hasLOS
    if IsValid( enemy ) then
      eyes = enemy:IsPlayer() and enemy:EyePos() or enemy:WorldSpaceCenter()
      local myCenter = self:WorldSpaceCenter()
      local losTr = util.TraceLine( { start = myCenter, endpos = eyes,
                                      filter = self, mask = MASK_SOLID_BRUSHONLY } )
      hasLOS = not losTr.Hit
    end

    -- canon out-of-sight teleport charge (the possessor repositions himself)
    if not possessed and self.UKG2_StartCooldown <= 0 then
      local lost = self:GetPos():Distance( eyes ) > 20 * UNIT
        or self:GetPos().z > eyes.z + 15 * UNIT
        or not hasLOS
      if lost then
        self.UKG2_OutOfSight = math.min( self.UKG2_OutOfSight + dt * spd, 3 )
      else
        self.UKG2_OutOfSight = math.max( self.UKG2_OutOfSight - dt * 2 * spd, 0 )
      end
      if self.UKG2_OutOfSight >= 3 and not self:UKG2_InAction() then
        self:UKG2_Teleport()
      end
    end

    if self.UKG2_Dashing then
      self:UKG2_DashThink( dt )
      return
    end

    if self.UKG2_ActionName then
      self:UKG2_ProcessEvents()
    end

    if self:UKG2_InAction() then
      -- canon UpdateRotation while tracking
      if self.UKG2_Tracking then
        self:SetMaxYawRate( 600 * spd )
        if eyes then
          local dir = eyes - self:GetPos()
          dir.z = 0
          if dir:LengthSqr() > 1 then
            self:FaceTowards( self:GetPos() + dir )
          end
        end
      else
        self:SetMaxYawRate( 0 )
      end

      -- canon AttackMovement: goForward during damage windows
      if self.UKG2_Forward then
        local dir = self:GetForward()
        local speed = ( self.UKG2_FwdSpeed or ( 125 * UNIT ) )
          * ( ( self:UKG2_Difficulty() >= 4 ) and 1.25 or 1 )
        self.loco:SetDesiredSpeed( speed )
        self.loco:Approach( self:GetPos() + dir * 100, 1 )
        self.loco:SetVelocity( dir * speed )
      end

      self:UKG2_ApplyMeleeDamage()
      return
    end

    -- possessed: attacks start from PossessionBinds, never autonomously
    if possessed then return end

    -- canon attack gate
    if self.UKG2_StartCooldown > 0 or self.UKG2_AttackCooldown > 0 then return end

    if not hasLOS then
      if self.UKG2_PreTeleCD <= 0 then
        self.UKG2_PreTeleCD = 0.5
        self:UKG2_Teleport()
      end
      return
    end

    -- canon: no attacks while the thrown swords are between him and the player
    if self.UKG2_CombinedCD > 0 then return end
    if IsValid( self.UKG2_Thrown ) then
      local dProj = self:GetPos():Distance( self.UKG2_Thrown:GetPos() )
      local dEnemy = self:GetPos():Distance( enemy:GetPos() )
      if dProj < dEnemy then return end
    end

    self:UKG2_ChooseAttack( enemy )
  end

  ------------------------------------------------------------------------------
  -- Death (boss outro is out of scope: voice line + decoy-style vanish)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    if self.UKG2_Dead then return end
    self.UKG2_Dead = true
    self:UKG2_EndAction()
    self.UKG2_Dashing = false
    self:UKG2_ClearProjectiles()
    self:SetNW2Bool( self.NW_COMBINED, false )

    self:UKG2_PlayVoice( UKGabriel2.VOICE.Death, 1, 4 )
    sound.Play( UKGabriel2.SOUND.Teleport, self:WorldSpaceCenter(), 85, 80, 1 )
    self:UKG2_SendTrail( self:GetPos(), self:GetPos() + Vector( 0, 0, 54 ) ) -- x0.45 rescale

    local delay = SoundDuration( UKGabriel2.VOICE.Death[ 1 ] ) or 2.5
    SafeRemoveEntityDelayed( self, math.min( delay, 4 ) )
  end

end

--------------------------------------------------------------------------------
-- Client: combined-swords hand visual + teleport decoy ghosts
--------------------------------------------------------------------------------

if CLIENT then

  local ghosts = {}

  net.Receive( "ukg2_teleport_trail", function()
    local ent = net.ReadEntity()
    local from = net.ReadVector()
    local to = net.ReadVector()
    local seq = net.ReadUInt( 12 )
    local cyc = net.ReadFloat()
    local skin = net.ReadUInt( 4 )

    local count = math.Clamp( math.floor( from:Distance( to ) / ( 2.5 * 40 ) ), 2, 8 )
    for i = 0, count - 1 do
      local f = i / count
      local mdl = ClientsideModel( UKGabriel2.MODEL, RENDERGROUP_TRANSLUCENT )
      if IsValid( mdl ) then
        mdl:SetPos( LerpVector( f, from, to ) )
        mdl:SetSkin( skin )
        mdl:SetSequence( seq )
        mdl:SetCycle( cyc )
        mdl:SetPlaybackRate( 0 )
        mdl:SetRenderMode( RENDERMODE_TRANSCOLOR )
        ghosts[ #ghosts + 1 ] = { mdl = mdl, die = CurTime() + 0.35 + f * 0.25 }
      end
    end
  end )

  hook.Add( "Think", "UKG2_TeleportGhosts", function()
    if #ghosts == 0 then return end
    local now = CurTime()
    for i = #ghosts, 1, -1 do
      local g = ghosts[ i ]
      if not IsValid( g.mdl ) then
        table.remove( ghosts, i )
      elseif now >= g.die then
        g.mdl:Remove()
        table.remove( ghosts, i )
      else
        local a = math.Clamp( ( g.die - now ) / 0.5, 0, 1 ) * 160
        g.mdl:SetColor( Color( 255, 220, 120, a ) )
      end
    end
  end )

  function ENT:Draw()
    self:DrawModel()

    -- combined swords spinning in the right hand between Gattai and the throw
    if self:GetNW2Bool( self.NW_COMBINED, false ) then
      if not IsValid( self.UKG2_CombinedMdl ) then
        self.UKG2_CombinedMdl = ClientsideModel( UKGabriel2.MODEL_COMBINED, RENDERGROUP_OPAQUE )
        if IsValid( self.UKG2_CombinedMdl ) then
          self.UKG2_CombinedMdl:SetNoDraw( true )
        end
      end
      local mdl = self.UKG2_CombinedMdl
      if IsValid( mdl ) then
        local id = self:LookupAttachment( "righthand" )
        local att = id and id > 0 and self:GetAttachment( id ) or nil
        local pos = att and att.Pos or ( self:WorldSpaceCenter() + self:GetForward() * 40 )
        local ang = self:GetAngles()
        ang:RotateAroundAxis( self:GetForward(), ( CurTime() * 1000 ) % 360 )
        mdl:SetPos( pos )
        mdl:SetAngles( ang )
        mdl:DrawModel()
      end
    elseif IsValid( self.UKG2_CombinedMdl ) then
      self.UKG2_CombinedMdl:Remove()
      self.UKG2_CombinedMdl = nil
    end
  end

  function ENT:OnRemove()
    if IsValid( self.UKG2_CombinedMdl ) then
      self.UKG2_CombinedMdl:Remove()
      self.UKG2_CombinedMdl = nil
    end
  end

end

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_gabriel2", {
  Name      = ENT.PrintName,
  Class     = "ultrakill_test_gabriel2",
  Category  = ENT.Category,
  AdminOnly = false,
} )
