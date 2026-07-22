AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_power_shared.lua" )

-- Power (Greater Angel, 8-3 / Cyber Grind). Full canon port of Power.cs:
-- 5 attacks with exact clip-event timings, EnemyCooldowns turn queue (groups
-- alternate turns), parry -> juggle launch -> enrage on landing, out-of-turn
-- counter throw ("PAY ATTENTION!"), teleports, spear dive sub-machine.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Power"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKPower.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKPower.HP
-- canon capsule r=1 m h=6 m, model origin at capsule bottom
ENT.CollisionBounds = Vector( 20, 20, 118 ) -- 2026-07-10: model rescaled x0.5 (Kevin-scale)
ENT.SurroundingBounds = Vector( 200, 200, 250 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Medium"

ENT.UKPower_IsPower = true -- canon: Powers never damage each other

local UNIT = UKPower.UNIT

-- DrGBase Flying (canon: rigidbody hover, no gravity)
ENT.Flying = true
ENT.FlyingHeight = 70 -- canon fly pivot 3.38 m above capsule bottom (2026-07-10: x0.5 rescale)

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 8 * UNIT
ENT.AvoidEnemyRange = 5 * UNIT
ENT.Acceleration = 1500
ENT.Deceleration = 1500
ENT.JumpHeight = 0
ENT.StepHeight = 0
ENT.MaxYawRate = 480
ENT.DeathDropHeight = math.huge
ENT.UseWalkframes = false
ENT.WalkSpeed = 5 * UNIT -- canon strafe speed 5 m/s
ENT.RunSpeed = 5 * UNIT

ENT.IdleAnimation = "Idle"; ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Idle"; ENT.WalkAnimRate = 1
ENT.RunAnimation = "Idle"; ENT.RunAnimRate = 1
ENT.JumpAnimation = "Idle"; ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Idle"; ENT.FallingAnimRate = 1

ENT.NW_ENRAGED = "UKPower_Enraged"
ENT.NW_JUGGLED = "UKPower_Juggled"

--------------------------------------------------------------------------------
-- Canon clip events (seconds at animation speed 1.0, extracted from the
-- AssetRipper .anim m_Events). Runtime timings divide by the anim speed.
-- Kinds: weapon <bg>, lookAt, lookAtFlash (canon LookAtTarget(1) = parry
-- flash), follow, parry, dmgOn/dmgOff (goForward also toggles with damage in
-- canon StartDamage/StopDamage), stabOn/stabOff, speed <fwd m/s>, backdash,
-- moveOff, vertical (next orb pair vertical), throwSpinner, throwSpear,
-- spearAttack (enter the dive sub-machine), capeReset, stopAction.
--------------------------------------------------------------------------------

local WEP = { blank = 0, sword = 1, zwei = 2, glaive = 3, spinner = 4, spear = 5 }

local ACTION = {
  Rapier = {
    seq = "Rapier", dur = 5.000, fwd = 100,
    ev = {
      { 0.318, "weapon", WEP.sword },
      { 1.546, "lookAt" }, { 1.674, "dmgOn" }, { 1.874, "dmgOff" },
      { 2.225, "lookAt" }, { 2.377, "dmgOn" }, { 2.573, "dmgOff" },
      { 2.892, "backdash" }, { 3.056, "moveOff" }, { 3.092, "follow" },
      { 3.255, "lookAtFlash" }, { 3.337, "speed", 125 },
      { 3.372, "stabOn" }, { 3.725, "stabOff" },
      { 4.204, "follow" }, { 4.321, "weapon", WEP.blank },
      { 4.918, "stopAction" },
    },
  },
  Zweihander = {
    seq = "Zweihander", dur = 4.667, fwd = 100, zwei = true,
    ev = {
      { 0.492, "weapon", WEP.zwei },
      { 1.241, "lookAt" }, { 1.335, "dmgOn" }, { 1.534, "dmgOff" },
      { 1.862, "follow" },
      { 2.260, "lookAt" }, { 2.330, "dmgOn" }, { 2.541, "dmgOff" },
      { 2.892, "follow" }, { 2.974, "vertical" }, { 3.080, "parry" },
      { 3.279, "lookAt" }, { 3.326, "dmgOn" }, { 3.529, "dmgOff" },
      { 3.857, "weapon", WEP.blank }, { 4.178, "follow" },
      { 4.607, "stopAction" },
    },
  },
  Glaive = {
    seq = "Glaive", dur = 4.667, fwd = 125,
    ev = {
      { 0.404, "weapon", WEP.glaive },
      { 0.849, "weapon", WEP.spinner }, { 1.193, "weapon", WEP.glaive },
      { 1.541, "lookAt" }, { 1.705, "stabOn" }, { 1.989, "stabOff" },
      { 2.273, "lookAt" }, { 2.294, "parry" },
      { 2.536, "dmgOn" }, { 2.689, "dmgOff" },
      { 3.049, "weapon", WEP.spinner }, { 3.115, "follow" },
      { 3.548, "throwSpinner" },
      { 4.219, "follow" }, { 4.503, "stopAction" },
    },
  },
  Throw = {
    seq = "Throw", dur = 3.333,
    ev = {
      { 0.757, "weapon", WEP.spinner },
      { 2.436, "throwSpinner" },
      { 3.240, "stopAction" },
    },
  },
  SpearSpawn = {
    seq = "SpearSpawn", dur = 30, -- open-ended: the dive sub-machine ends it
    ev = {
      { 0.738, "weapon", WEP.spear },
      { 1.468, "spearAttack" },
    },
  },
  SpearThrow = {
    seq = "SpearThrow", dur = 2.333,
    ev = {
      { 0.913, "lookAt" },
      { 1.098, "throwSpear" },
      { 1.787, "follow" },
      { 2.240, "stopAction" },
    },
  },
  Backdash = {
    seq = "Backdash", dur = 0.833, moveAtStart = -85,
    ev = {
      { 0.566, "moveOff" },
      { 0.798, "stopAction" },
    },
  },
  Enrage = {
    seq = "Enrage", dur = 1.333,
    ev = {
      { 0.568, "capeReset" },
      { 1.293, "stopAction" },
    },
  },
  Intro = {
    seq = "Intro", dur = 4.333,
    ev = {
      -- Gabriel-intro pattern: the black silhouette is revealed with a burst
      -- (~60% through, matching Gabriel's frame-164 Reveal cadence)
      { 2.600, "reveal" },
    },
  },
}

-- canon UpdateSpeed: anim.speed by difficulty (0 HARMLESS .. 4+ BRUTAL)
local ANIMSPEED_BY_DIFF = { [0] = 0.7, [1] = 0.8 } -- else 0.95

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

-- flyer: the ultrakillbase CUSTOM PossessionControls steers ApproachFlying
-- along the possessor aim (GetFlying() branch)
ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {
    offset = Vector( 0, 14, 55 ),
    distance = 155,
    eyepos = false,
  },

  {
    -- no EyeBone on this model: EyePos falls back to the hull center (~59 su),
    -- so the offset lifts the camera up to head height (~105 su)
    offset = Vector( 8, 0, 46 ),
    distance = 0,
    eyepos = true,
  },

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKP_Dead or self.UKP_Juggled or self:UKP_InAction() then return end

    -- same voice+action couplets UKP_PickAttack rolls; Turns.Attacking keeps
    -- the group queue honest (StopAction -> UKP_AttackEnd rotates it after)
    UKPower.Turns.Attacking( self )

    if Possessor:KeyDown( IN_FORWARD ) then
      self:UKP_Voice( "Greatsword" )
      self:UKP_StartAction( "Zweihander" )
    elseif Possessor:KeyDown( IN_BACK ) then
      self:UKP_Voice( "Glaive" )
      self:UKP_StartAction( "Glaive" )
    else
      self:UKP_Voice( "Rapier" )
      self:UKP_StartAction( "Rapier" )
    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKP_Dead or self.UKP_Juggled or self:UKP_InAction() then return end

    UKPower.Turns.Attacking( self )
    self:UKP_Voice( "GlaiveThrow" )
    self:UKP_StartAction( "Throw" )

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKP_Dead or self.UKP_Juggled or self:UKP_InAction() then return end

    UKPower.Turns.Attacking( self )
    self:UKP_Voice( "Spear" )
    self:UKP_StartAction( "SpearSpawn" )
    -- dive speed the AI sets after starting the spear machine (PickAttack move 2)
    local diff = self:UKP_GetDifficulty()
    self.UKP_ForwardSpeed = diff >= 2 and 150 or ( diff == 1 and 75 or 60 )

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- UKP_Teleport is relative to the lock-on target and no-ops without one
    if self.UKP_Dead or self.UKP_Juggled or self:UKP_InAction() then return end
    if self:GetCooldown( "Power_Possession_Teleport" ) > 0 then return end

    self:SetCooldown( "Power_Possession_Teleport", 1 )
    self:UKP_Teleport()

  end } },

}

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    self:SetTurning( true )

    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    self:SetMaxHealth( UKPower.HP )
    self:SetHealth( UKPower.HP )

    self.UKP_Dead = false
    self.UKP_Enraged = false
    self.UKP_Juggled = false
    self.UKP_ActionName = nil
    self.UKP_ActionStart = 0
    self.UKP_ActionUntil = nil
    self.UKP_ActionEvIndex = 1
    self.UKP_Damaging = false
    self.UKP_Stabbing = false
    self.UKP_GoForward = false
    self.UKP_ForwardSpeed = 0
    self.UKP_VerticalSwing = false
    self.UKP_ActionHits = nil
    self.UKP_OverrideLook = nil

    -- canon PickAttack state
    self.UKP_MoveBonuses = { 0, 0, 0, 0, 0 }
    self.UKP_AttackCooldown = 2 -- canon initial attackCooldown
    self.UKP_BurstLength = 2
    self.UKP_HasAttacked = false
    self.UKP_PreAttackHealth = UKPower.HP
    self.UKP_TeleportAfterAction = false

    -- self-defense (out-of-turn counter)
    self.UKP_SinceLastAttacked = CurTime()
    self.UKP_CheckingSelfDefend = false
    self.UKP_HealthSinceLastAttacked = UKPower.HP

    -- juggle
    self.UKP_JuggleHp = UKPower.HP
    self.UKP_JuggleT0 = 0
    self.UKP_JuggleVel = 0

    -- spear sub-machine
    self.UKP_SpearAttacksLeft = 0
    self.UKP_Spearing = false

    self.UKP_OutOfSight = 0
    self.UKP_StrafeLeft = math.random( 2 ) == 1
    self.UKP_VoicePitch = math.random( 95, 105 )
    self.UKP_VoiceEnd = 0
    self.UKP_VoiceHigh = false
    self.UKP_LastVoice = {}
    self.UKP_HurtVoiceAt = 0
    self.UKP_FlinchAt = 0
    self.UKP_FlinchUntil = 0

    self:SetSkin( 0 )
    self:UKP_SetWeapon( WEP.blank )
    self:UKP_SetCape( true )
    self:SetNW2Bool( self.NW_ENRAGED, false )
    self:SetNW2Bool( self.NW_JUGGLED, false )
    self:SetParryable( false )

    self:SetNW2Bool( "UKPower_Dying", false )

    UKPower.Turns.Add( self )

    -- canon intro: black silhouette inside a golden light pillar + a blue
    -- circle burst (canon RageEffect); the Intro 'reveal' event strips the
    -- silhouette (Gabriel-intro pattern, gold instead of white)
    self:SetMaterial( "models/ultrakill/shared/Black" )
    local ifx = EffectData()
    ifx:SetEntity( self )
    ifx:SetMagnitude( ( 2.6 / self:UKP_AnimSpeed() ) * 100 )
    util.Effect( "ultrakill_power_intro", ifx, true, true )
    self:UKP_Ring( self:WorldSpaceCenter(), 500, 1.4, 0 )

    self:UKP_Voice( "Intro", true )
    self:UKP_StartAction( "Intro" )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    UltrakillBase.TraceSetPos( self, self:GetPos() + Vector( 0, 0, 20 ) )
  end

  function ENT:OnRemove()
    UKPower.Turns.Remove( self )
  end

  ------------------------------------------------------------------------------
  -- Difficulty / helpers
  ------------------------------------------------------------------------------

  function ENT:UKP_GetDifficulty()
    return self.UltrakillBase_Difficulty or 2
  end

  function ENT:UKP_AnimSpeed()
    return ANIMSPEED_BY_DIFF[ self:UKP_GetDifficulty() ] or 0.95
  end

  function ENT:UKP_SetWeapon( idx )
    self.UKP_CurWeapon = idx
    local bg = self:FindBodygroupByName( "weapon" )
    if bg and bg >= 0 then self:SetBodygroup( bg, idx ) end
  end

  function ENT:UKP_SetCape( on )
    local bg = self:FindBodygroupByName( "cape" )
    if bg and bg >= 0 then self:SetBodygroup( bg, on and 0 or 1 ) end
  end

  function ENT:UKP_GetAttachmentPos( name, fallback )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return fallback
  end

  function ENT:UKP_HeadPos()
    return self:UKP_GetAttachmentPos( "head", self:GetPos() + Vector( 0, 0, 105 ) ) -- x0.5 rescale
  end

  function ENT:UKP_WeaponPos()
    return self:UKP_GetAttachmentPos( "weapon", self:UKP_HeadPos() )
  end

  function ENT:UKP_EnemyHeadPos( enemy )
    enemy = enemy or self:GetEnemy()
    if not IsValid( enemy ) then return self:GetPos() + self:GetForward() * 100 end
    if enemy.EyePos then return enemy:EyePos() end
    return enemy:WorldSpaceCenter()
  end

  ------------------------------------------------------------------------------
  -- Canon RageEffect circle burst (see effects/ultrakill_power_ring.lua)
  -- palette: 0 blue (juggle/spawn), 1 grey (dash), 2 white, 3 gold
  ------------------------------------------------------------------------------

  function ENT:UKP_Ring( pos, size, dur, palette )
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetScale( size )
    fx:SetMagnitude( dur )
    fx:SetFlags( palette or 0 )
    util.Effect( "ultrakill_power_ring", fx, true, true )
  end

  ------------------------------------------------------------------------------
  -- Voice (canon CanPlaySound / PlaySound priority system).
  -- key = UKPower.SOUND key; captioned lines route through UKBase sound
  -- scripts (boss subtitles), the rest are plain EmitSound.
  ------------------------------------------------------------------------------

  function ENT:UKP_Voice( key, highPriority, force )
    if not force and not highPriority
        and self.UKP_VoiceHigh and CurTime() < self.UKP_VoiceEnd then
      return
    end
    local list = UKPower.SOUND[ key ]
    if not list then return end
    local path, idx = list, nil
    if istable( list ) then
      -- canon GetSound: avoid repeating the previous index
      local last = self.UKP_LastVoice[ key ]
      idx = math.random( #list )
      if idx == last and #list > 1 then
        idx = ( idx % #list ) + 1
      end
      self.UKP_LastVoice[ key ] = idx
      path = list[ idx ]
    end
    if UKPower.VOICE_SCRIPT[ key ] and idx then
      UltrakillBase.SoundScript( "Ultrakill_Power_" .. key .. idx, self:GetPos(), self )
    else
      self:EmitSound( path, 95, self.UKP_VoicePitch, 1, CHAN_VOICE )
    end
    self.UKP_VoiceEnd = CurTime() + ( SoundDuration( path ) or 2 )
    self.UKP_VoiceHigh = highPriority or false
  end

  ------------------------------------------------------------------------------
  -- Action system (Ferryman pattern)
  ------------------------------------------------------------------------------

  function ENT:UKP_InAction()
    if self.UKP_ActionUntil and self.UKP_ActionUntil > CurTime() then return true end
    if self.UKP_ActionName then
      self:UKP_StopAction()
      -- StopAction can chain into Backdash (queue rotation) — recheck
      if self.UKP_ActionUntil and self.UKP_ActionUntil > CurTime() then return true end
    end
    return false
  end

  function ENT:UKP_ActionTime()
    return ( CurTime() - ( self.UKP_ActionStart or 0 ) ) * self:UKP_AnimSpeed()
  end

  function ENT:UKP_PlaySeq( name, rate )
    local seq = self:LookupSequence( name )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( rate or self:UKP_AnimSpeed() )
    end
  end

  function ENT:UKP_StartAction( name )
    if self.UKP_Dead then return end
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKP_AnimSpeed()

    local enemy = self:GetEnemy()
    if IsValid( enemy ) and name ~= "Intro" and name ~= "Enrage" then
      self:FaceInstant( self:UKP_EnemyHeadPos( enemy ) )
    end

    self:UKP_PlaySeq( cfg.seq, spd )

    self.UKP_ActionName = name
    self.UKP_ActionStart = CurTime()
    self.UKP_ActionUntil = CurTime() + cfg.dur / spd
    self.UKP_ActionEvIndex = 1
    self.UKP_ForwardSpeed = cfg.fwd or 0
    self.UKP_GoForward = false
    self.UKP_Damaging = false
    self.UKP_Stabbing = false
    self.UKP_VerticalSwing = false
    self.UKP_ZweiOrbs = cfg.zwei and self:UKP_GetDifficulty() >= 3 or false
    self.UKP_ActionHits = {}
    self.UKP_OverrideLook = nil

    if cfg.moveAtStart then
      self.UKP_GoForward = true
      self.UKP_ForwardSpeed = cfg.moveAtStart
      self:UKP_Ring( self:WorldSpaceCenter(), 380, 0.5, 1 ) -- canon dashEffect
    end

    self.CantMove = true
  end

  -- canon StopAction
  function ENT:UKP_StopAction()
    local wasAttack = self.UKP_ActionName ~= nil
      and self.UKP_ActionName ~= "Backdash" and self.UKP_ActionName ~= "Enrage"
      and self.UKP_ActionName ~= "Intro"
    self.UKP_ActionName = nil
    self.UKP_ActionUntil = nil
    self.UKP_GoForward = false
    self.UKP_Damaging = false
    self.UKP_Stabbing = false
    self.UKP_Spearing = false
    self.UKP_SpearAttacksLeft = 0
    self.UKP_VerticalSwing = false
    self.UKP_OverrideLook = nil
    self:SetParryable( false )
    self:UKP_SetWeapon( WEP.blank )
    self.CantMove = false
    self.UKP_StrafeLeft = math.random( 2 ) == 1

    if wasAttack and UKPower.Turns.attacking == self then
      self:UKP_AttackEnd()
    end
    if self.UKP_TeleportAfterAction then
      self.UKP_TeleportAfterAction = false
      self:UKP_Teleport( false, true )
    end
  end

  -- canon AttackEnd: rotate the queue, backdash in groups, taunt when solo
  function ENT:UKP_AttackEnd()
    UKPower.Turns.AttackEnd()
    self.UKP_SinceLastAttacked = CurTime()
    self.UKP_CheckingSelfDefend = false
    if not self.UKP_Enraged then
      if UKPower.Turns.Count() > 1 then
        self:UKP_StartAction( "Backdash" )
      elseif self.UKP_AttackCooldown > 0 then
        self:UKP_Voice( "Taunt", true )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Event dispatch
  ------------------------------------------------------------------------------

  function ENT:UKP_ProcessEvents()
    local name = self.UKP_ActionName
    local cfg = name and ACTION[ name ]
    if not cfg then return end
    local t = self:UKP_ActionTime()
    while self.UKP_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKP_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKP_ActionEvIndex = self.UKP_ActionEvIndex + 1
      self:UKP_FireEvent( ev[ 2 ], ev[ 3 ] )
      -- an event may have swapped the action (stopAction -> Backdash);
      -- never keep feeding it the OLD event table
      if self.UKP_ActionName ~= name then return end
    end
  end

  function ENT:UKP_FireEvent( kind, arg )
    if kind == "weapon" then
      local prev = self.UKP_CurWeapon or WEP.blank
      self:UKP_SetWeapon( arg )
      if arg ~= WEP.blank and prev == WEP.blank then
        -- canon GabrielWeaponSpawn: white flash circle + gold light
        self:EmitSound( UKPower.SOUND.WeaponSpawn, 85, 100, 0.9 )
        local fx = EffectData()
        fx:SetOrigin( self:UKP_WeaponPos() )
        util.Effect( "MuzzleFlash", fx, true, true )
        self:UKP_Ring( self:UKP_WeaponPos(), 90, 0.45, 2 )
      elseif arg == WEP.blank and prev ~= WEP.blank then
        self:EmitSound( UKPower.SOUND.WeaponBreak, 80, 100, 0.8 )
        self:UKP_Ring( self:UKP_WeaponPos(), 70, 0.4, 3 )
      end

    elseif kind == "lookAt" then
      self:UKP_LookAtTarget( false )
    elseif kind == "lookAtFlash" then
      self:UKP_LookAtTarget( true )
    elseif kind == "follow" then
      self.UKP_OverrideLook = nil

    elseif kind == "parry" then
      self:UKP_Flash( true )

    elseif kind == "dmgOn" then
      self:UKP_StartDamage( false )
    elseif kind == "dmgOff" then
      self:UKP_StopDamage()
    elseif kind == "stabOn" then
      self:UKP_StartDamage( true )
    elseif kind == "stabOff" then
      self:UKP_StopDamage()

    elseif kind == "speed" then
      self.UKP_ForwardSpeed = arg or 100

    elseif kind == "backdash" then
      -- canon Backdash(): goForward at -85 m/s, face the target + dash circle
      self.UKP_GoForward = true
      self.UKP_ForwardSpeed = -85
      self:FaceInstant( self:UKP_EnemyHeadPos() )
      self:UKP_Ring( self:WorldSpaceCenter(), 380, 0.5, 1 )
    elseif kind == "moveOff" then
      self.UKP_GoForward = false

    elseif kind == "reveal" then
      -- intro: strip the black silhouette (Gabriel 'Reveal' pattern)
      self:SetMaterial( "" )
      self:EmitSound( UKPower.SOUND.WeaponBreak, 92, 100, 1 )
      self:UKP_Ring( self:WorldSpaceCenter(), 460, 1.0, 3 )
      util.ScreenShake( self:GetPos(), 6, 60, 1.2, 1800 )

    elseif kind == "vertical" then
      self.UKP_VerticalSwing = true

    elseif kind == "throwSpinner" then
      self:UKP_SetWeapon( WEP.blank )
      self:UKP_ThrowSpinner()
    elseif kind == "throwSpear" then
      self:UKP_SetWeapon( WEP.blank )
      self:UKP_ThrowSpear()
    elseif kind == "spearAttack" then
      self.UKP_SpearAttacksLeft = self.UKP_Enraged and 2 or 1
      self:UKP_SpearAttack()

    elseif kind == "capeReset" then
      self:UKP_CapeReset()

    elseif kind == "stopAction" then
      self.UKP_ActionUntil = 0
      self:UKP_StopAction()
    end
  end

  ------------------------------------------------------------------------------
  -- Look / flash / parry
  ------------------------------------------------------------------------------

  -- canon LookAtTarget: snap onto the (predicted on STANDARD+) player position
  function ENT:UKP_LookAtTarget( flash )
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then return end
    local target = self:UKP_EnemyHeadPos( enemy )
    if self:UKP_GetDifficulty() >= 2 and enemy.GetVelocity then
      target = target + enemy:GetVelocity() * 0.2 -- canon PredictPlayerPosition(0.2)
    end
    self.UKP_OverrideLook = target
    self:FaceInstant( target )
    if flash then self:UKP_Flash( true ) end
  end

  function ENT:UKP_Flash( parryable )
    if self.CreateAlert then
      self:CreateAlert( self:UKP_HeadPos() + self:GetForward() * 20,
        parryable and 1 or 2, 3 )
    end
    self:SetParryable( parryable )
  end

  -- canon GotParried -> JuggleStart (launch up, gravity on, stun until landing)
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    self:UKP_JuggleStart()
  end

  ------------------------------------------------------------------------------
  -- Melee damage (canon SwingCheck2: player-only, one hit per window)
  ------------------------------------------------------------------------------

  function ENT:UKP_StartDamage( stab )
    self.UKP_Damaging = true
    self.UKP_Stabbing = stab
    self.UKP_GoForward = true -- canon StartDamage: goForward = true
    self.UKP_ActionHits = {}
    if stab then
      self:EmitSound( UKPower.SOUND.StabLoop, 85, 100, 0.9 )
    else
      local zwei = self.UKP_ActionName == "Zweihander"
      self:EmitSound( zwei and UKPower.SOUND.SwingZwei or UKPower.SOUND.Swing,
        88, math.random( 95, 105 ), 1 )
    end
    -- canon: Violent+ zwei swings each release a Hell orb pair
    if self.UKP_ZweiOrbs and not stab then
      self:UKP_SpawnZweiOrbs( self.UKP_VerticalSwing )
      self.UKP_VerticalSwing = false
    end
  end

  function ENT:UKP_StopDamage()
    self.UKP_Damaging = false
    self.UKP_Stabbing = false
    self.UKP_GoForward = false
    self:SetParryable( false ) -- canon StopDamage: parry window dies with the swing
  end

  function ENT:UKP_ApplyMeleeDamage()
    if not self.UKP_Damaging then return end
    local hits = self.UKP_ActionHits or {}
    self.UKP_ActionHits = hits

    -- canon SwingCheck 3x5x5 m box 2.5 m ahead (zwei 3x5x6 at 3 m)
    local zwei = self.UKP_ActionName == "Zweihander"
    local center = self:WorldSpaceCenter() + self:GetForward() * ( 2.5 * UNIT )
    local radius = ( zwei and 3.5 or 3 ) * UNIT
    local damage = zwei and UKPower.ZWEI_DAMAGE or UKPower.SWING_DAMAGE

    for _, ent in ipairs( ents.FindInSphere( center, radius ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      -- canon SwingCheck2.enemyDamage = 0: melee only ever hurts players
      if not ent:IsPlayer() then continue end
      if not ent:Alive() then continue end
      -- the possessor rides at the bot's own origin, inside the swing box
      if ent == self:GetPossessor() then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKPower.ScaleAttackDamage( ent, damage ) )
      dmg:SetDamageType( DMG_SLASH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 1000 )
      ent:TakeDamageInfo( dmg )
      self.UKP_Damaging = false
      break
    end
  end

  ------------------------------------------------------------------------------
  -- Projectiles
  ------------------------------------------------------------------------------

  function ENT:UKP_ThrowSpinner()
    local proj = self:CreateProjectile( UKPower.CLASS.Spinner, true )
    if not IsValid( proj ) then return end
    proj:SetPos( self:UKP_WeaponPos() )
    local speed = UKPower.SPINNER_SPEED * UNIT
    if self:UKP_GetDifficulty() >= 4 then speed = speed * 1.75 end -- canon
    self:AimProjectile( proj, speed )
  end

  function ENT:UKP_ThrowSpear()
    local proj = self:CreateProjectile( UKPower.CLASS.Spear, true )
    if not IsValid( proj ) then return end
    proj:SetPos( self:GetPos() + Vector( 0, 0, 70 ) + self:GetForward() * ( 3 * UNIT ) ) -- x0.5 rescale
    local speed = UKPower.SPEAR_SPEED * UNIT
    if self:UKP_GetDifficulty() <= 1 then speed = speed * 0.5 end -- canon
    self:AimProjectile( proj, speed )
  end

  -- canon zweiProjectiles: an orb pair 3 m apart joined by an unparryable beam
  function ENT:UKP_SpawnZweiOrbs( vertical )
    local fwd = self:GetForward()
    local side = vertical and Vector( 0, 0, 1 ) or self:GetRight()
    local origin = self:WorldSpaceCenter() + fwd * ( 2 * UNIT )
    local a = ents.Create( UKPower.CLASS.Orb )
    local b = ents.Create( UKPower.CLASS.Orb )
    if not ( IsValid( a ) and IsValid( b ) ) then return end
    for i, orb in ipairs( { a, b } ) do
      -- canon pair separation = 3 m TOTAL (±1.5 m): the joining beam overlaps
      -- the center, so the alternating h/v pairs read as a solid plus sign
      orb:SetPos( origin + side * ( 1.5 * UNIT ) * ( i == 1 and 1 or -1 ) )
      orb:SetAngles( fwd:Angle() )
      orb:SetOwner( self )
      orb:Spawn()
    end
    a.UKOrb_Partner = b
    b.UKOrb_Partner = a
    a.UKOrb_BeamMaster = true
  end

  ------------------------------------------------------------------------------
  -- Teleport (canon Teleport(): upper hemisphere around the player head)
  ------------------------------------------------------------------------------

  function ENT:UKP_Teleport( closeRange, longrange, horizontal )
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) or self.UKP_Juggled then return false end
    local head = self:UKP_EnemyHeadPos( enemy ) + Vector( 0, 0, UNIT )

    for _ = 1, 10 do
      local dir = VectorRand()
      dir:Normalize()
      if dir.z < 0 then dir.z = -dir.z end
      local dist = math.random( 8, 15 )
      if closeRange then dist = math.random( 5, 8 )
      elseif longrange then dist = math.random( 15, 20 ) end
      dist = dist * UNIT

      local tr = util.TraceLine( {
        start = head, endpos = head + dir * dist,
        mask = MASK_SOLID_BRUSHONLY,
      } )
      local pos = tr.Hit and ( tr.HitPos - dir * ( 3 * UNIT ) ) or ( head + dir * dist )
      if horizontal then pos.z = head.z end
      -- feet position (fly pivot ~3.38 m above the origin)
      pos = pos - Vector( 0, 0, 67 ) -- x0.5 rescale

      local hull = util.TraceHull( {
        start = pos + Vector( 0, 0, 5 ), endpos = pos + Vector( 0, 0, 5 ),
        mins = Vector( -40, -40, 0 ), maxs = Vector( 40, 40, 235 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      if not hull.Hit then
        self:UKP_TeleportTo( pos )
        return true
      end
    end
    return false
  end

  function ENT:UKP_TeleportTo( pos )
    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "cball_explode", fx, true, true )
    self:SetPos( pos )
    if self.loco then self.loco:SetVelocity( vector_origin ) end
    sound.Play( UKPower.SOUND.Teleport, pos, 85, 100, 1 )
    self.UKP_OutOfSight = 0
    self.UKP_StrafeLeft = not self.UKP_StrafeLeft
  end

  ------------------------------------------------------------------------------
  -- Spear dive sub-machine (canon SpearAttack / SpearGo / ToSpearThrow)
  ------------------------------------------------------------------------------

  function ENT:UKP_SpearAttack()
    if self.UKP_Dead or self.UKP_Juggled or self.UKP_ActionName ~= "SpearSpawn" then return end
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then self.UKP_SpearAttacksLeft = 0 end

    if self.UKP_SpearAttacksLeft <= 0 then
      self:UKP_ToSpearThrow()
      return
    end
    self.UKP_SpearAttacksLeft = self.UKP_SpearAttacksLeft - 1

    local diff = self:UKP_GetDifficulty()
    local spd = self:UKP_AnimSpeed()
    -- canon inter-attack delay
    local num = diff >= 3 and 0.75 or ( diff == 2 and 1.5 or 2.0 )
    -- canon pre-dive delay
    local num4 = diff >= 3 and 0.5 or ( diff == 2 and 0.75 or 1.0 )

    local head = self:UKP_EnemyHeadPos( enemy )
    local up = util.TraceLine( { start = head, endpos = head + Vector( 0, 0, 17 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY } )
    local horizontal = up.Hit or ( ( diff >= 4 or self.UKP_Enraged ) and math.random() > 0.5 )

    if horizontal then
      -- canon SpearGoHorizontal: long horizontal teleport, flash, dash
      self:UKP_PlaySeq( "SpearDrop" )
      self:UKP_Teleport( false, true, true )
      self:FaceInstant( head )
      timer.Simple( 0.25 / spd, function()
        if IsValid( self ) then self:UKP_Flash( false ) end
      end )
      timer.Simple( 0.5 / spd, function()
        if IsValid( self ) then self:UKP_SpearGo() end
      end )
    else
      -- canon vertical: teleport 15 m above the head, drop pose, dive down
      self:UKP_PlaySeq( "SpearDrop" )
      local pos = head + Vector( 0, 0, 15 * UNIT ) - Vector( 0, 0, 67 ) -- x0.5 rescale
      self:UKP_TeleportTo( pos )
      self.UKP_SpearHover = true
      self:FaceInstant( head )
      timer.Simple( num4 / 2 / spd, function()
        if IsValid( self ) then self:UKP_Flash( false ) end
      end )
      timer.Simple( num4 / spd, function()
        if IsValid( self ) then self:UKP_SpearGo() end
      end )
    end

    timer.Simple( num / spd, function()
      if IsValid( self ) then self:UKP_SpearAttack() end
    end )
  end

  function ENT:UKP_SpearGo()
    if self.UKP_Dead or self.UKP_Juggled or self.UKP_ActionName ~= "SpearSpawn" then return end
    self.UKP_SpearHover = false
    self.UKP_Spearing = true
    local enemy = self:GetEnemy()
    if IsValid( enemy ) then
      -- dive straight at the player (vertical drop dives down through them)
      self:FaceInstant( self:UKP_EnemyHeadPos( enemy ) )
      self.UKP_SpearDir = ( self:UKP_EnemyHeadPos( enemy ) - self:UKP_HeadPos() ):GetNormalized()
    else
      self.UKP_SpearDir = self:GetForward()
    end
    local diff = self:UKP_GetDifficulty()
    self.UKP_ForwardSpeed = diff >= 2 and 150 or ( diff == 1 and 75 or 60 )
    self:UKP_Ring( self:WorldSpaceCenter(), 380, 0.5, 1 ) -- canon dashEffect
    self:UKP_StartDamage( true )
  end

  function ENT:UKP_ToSpearThrow()
    if self.UKP_Dead or self.UKP_Juggled then return end
    self.UKP_Spearing = false
    self:UKP_StopDamage()
    self:UKP_Teleport()
    self:UKP_Voice( "OverHere" )
    self:UKP_StartAction( "SpearThrow" )
    self:UKP_SetWeapon( WEP.spear )
  end

  ------------------------------------------------------------------------------
  -- Juggle (canon GotParried / JuggleStart / JuggleStop)
  ------------------------------------------------------------------------------

  function ENT:UKP_JuggleStart()
    if self.UKP_Dead or self.UKP_Juggled then return end
    self:UKP_StopAction()
    self.UKP_ActionName = nil
    self.UKP_ActionUntil = nil
    self.UKP_Juggled = true
    self:SetNW2Bool( self.NW_JUGGLED, true )
    self.UKP_JuggleT0 = CurTime()
    self.UKP_JuggleHp = self:Health()
    self.UKP_JuggleVel = UKPower.JUGGLE_LAUNCH * UNIT
    self.CantMove = true
    self:UKP_SetCape( false ) -- canon CapeDisable
    self:UKP_PlaySeq( "Juggle" )
    self:EmitSound( UKPower.SOUND.Juggle, 90, 100, 1 )
    -- canon GabrielJuggleEffect: the big blue circle burst
    self:UKP_Ring( self:WorldSpaceCenter(), 640, 1.5, 0 )
    self:UKP_Voice( "HurtBig", true )
    UKPower.Turns.Deprioritize( self )
  end

  function ENT:UKP_JuggleTick( dt )
    local t = CurTime() - self.UKP_JuggleT0
    local vz = self.UKP_JuggleVel

    -- hard safety: a flying bot must never stay stuck in the juggle pose
    if t > 8 then return self:UKP_JuggleStop() end

    -- gravity (canon rb.SetGravityMode(true))
    vz = vz - UKPower.GRAVITY * UNIT * dt

    -- canon: while recently damaged and still early, falling is suppressed
    if vz < 0 and t < 5 and self:Health() < self.UKP_JuggleHp then
      vz = 0
    end
    -- cap at canon 35 m/s
    vz = math.min( vz, 35 * UNIT )
    self.UKP_JuggleHp = self:Health()

    -- SetPos integration: the DrGBase flying locomotion fights loco
    -- velocities (hover-height control), so drive the launch/fall by hand
    if self.loco then self.loco:SetVelocity( vector_origin ) end
    local pos = self:GetPos()
    local step = vz * dt
    if step > 0 then
      local up = util.TraceHull( {
        start = pos, endpos = pos + Vector( 0, 0, step ),
        mins = Vector( -30, -30, 0 ), maxs = Vector( 30, 30, 235 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      if up.Hit then
        vz = 0
        step = math.max( ( up.HitPos - pos ).z - 2, 0 )
      end
      self:SetPos( pos + Vector( 0, 0, step ) )
    elseif step < 0 then
      self:SetPos( pos + Vector( 0, 0, step ) )
    end
    self.UKP_JuggleVel = vz

    -- canon fall scream at < -100 m/s
    if vz < -100 * UNIT and not self.UKP_Screaming then
      self.UKP_Screaming = true
      self:UKP_Voice( "Scream", true )
    end

    -- canon: landing check (3.6 m sphere below) only while falling
    if vz < 0 then
      local tr = util.TraceHull( {
        start = self:GetPos() + Vector( 0, 0, 20 ),
        endpos = self:GetPos() - Vector( 0, 0, 3.6 * UNIT ),
        mins = Vector( -30, -30, 0 ), maxs = Vector( 30, 30, 10 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      if tr.Hit then self:UKP_JuggleStop() end
    end
  end

  function ENT:UKP_JuggleStop()
    self.UKP_Juggled = false
    self.UKP_Screaming = false
    self:SetNW2Bool( self.NW_JUGGLED, false )
    if self.loco then self.loco:SetVelocity( vector_origin ) end
    self:UKP_Voice( "Enrage", true )
    self:UKP_StartAction( "Enrage" )
  end

  -- canon CapeReset (Enrage anim event): cape back + EnrageNow on STANDARD+
  function ENT:UKP_CapeReset()
    self:UKP_SetCape( true )
    if self:UKP_GetDifficulty() >= 2 then
      self:UKP_EnrageNow()
    end
  end

  function ENT:UKP_EnrageNow()
    if self.UKP_Enraged then return end
    self.UKP_Enraged = true
    self:SetNW2Bool( self.NW_ENRAGED, true )
    self:SetSkin( 1 )
    -- UKBase enraged state + the canon enrage particle above the head
    -- (attachment 4 = head)
    self:SetEnraged( true )
    if self.CreateEnrage then self:CreateEnrage( 4, 1.15 ) end
    self.UKP_AttackCooldown = 0
    UKPower.Turns.Refresh()
  end

  ------------------------------------------------------------------------------
  -- PickAttack (canon 1:1: weighted 5-move roll)
  ------------------------------------------------------------------------------

  function ENT:UKP_PickAttack( enemy )
    UKPower.Turns.Attacking( self )
    self.UKP_HasAttacked = true

    local dist = self:GetPos():Distance( self:UKP_EnemyHeadPos( enemy ) )
    local close = dist < 5 * UNIT
    local far = dist > 10 * UNIT

    local bonuses = self.UKP_MoveBonuses
    local weights = { 0, 0, 0, 0, 0 }
    for i = 1, 5 do
      -- canon: skip the previous move; moves 1-2 (throw/spear) banned in close
      if UKPower.Turns.previousMove ~= i and not ( i <= 2 and close ) then
        weights[ i ] = math.Rand( 0, 1 )
          + bonuses[ i ] * ( ( i <= 2 ) and 1 or ( far and 0.5 or 1 ) )
      end
    end
    -- canon: no raw throw in groups
    if UKPower.Turns.Count() > 1 then weights[ 1 ] = 0 end

    local move, best = -1, 0
    for i = 1, 5 do
      if weights[ i ] > best then best = weights[ i ]; move = i end
    end
    if move == -1 then move = 3 end

    if move == 1 then
      self:UKP_Voice( "GlaiveThrow" )
      self:UKP_StartAction( "Throw" )
    elseif move == 2 then
      self:UKP_Voice( "Spear" )
      self:UKP_StartAction( "SpearSpawn" )
      local diff = self:UKP_GetDifficulty()
      self.UKP_ForwardSpeed = diff >= 2 and 150 or ( diff == 1 and 75 or 60 )
    elseif move == 3 then
      if far then self:UKP_Teleport( true, false ) end
      self:UKP_Voice( "Rapier" )
      self:UKP_StartAction( "Rapier" )
    elseif move == 4 then
      if far then self:UKP_Teleport( true, false ) end
      self:UKP_Voice( "Greatsword" )
      self:UKP_StartAction( "Zweihander" )
    elseif move == 5 then
      if far then self:UKP_Teleport( true, false ) end
      self:UKP_Voice( "Glaive" )
      self:UKP_StartAction( "Glaive" )
    end

    UKPower.Turns.previousMove = move
    for i = 1, 5 do
      bonuses[ i ] = ( i == move ) and 0 or ( bonuses[ i ] + 0.25 )
    end

    -- canon burst / cooldown bookkeeping (raw throw doesn't consume a burst)
    if move == 1 then return end
    if self.UKP_BurstLength > 1 then
      self.UKP_BurstLength = self.UKP_BurstLength - 1
      return
    end
    local diff = self:UKP_GetDifficulty()
    self.UKP_BurstLength = diff >= 3 and 3 or 2
    self.UKP_AttackCooldown = self.UKP_Enraged and 0
      or ( diff <= 3 and 3 or ( 6 - diff ) )
  end

  ------------------------------------------------------------------------------
  -- Damage intake: self-defense counter + juggle physics + hurt grunts
  ------------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKP_Dead then return end
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier

    -- canon juggle: damage taken x0.75 and pushes the Power up
    if self.UKP_Juggled then
      dmg:SetDamage( dmg:GetDamage() * UKPower.JUGGLE_DMG_TAKEN_MULT )
      local t = CurTime() - self.UKP_JuggleT0
      local boost = ( dmg:GetDamage() / 1000 ) * math.Clamp( 3 - ( t - 3 ), 0, 5 )
      self.UKP_JuggleVel = math.min( self.UKP_JuggleVel + boost * UNIT, 35 * UNIT )
      -- shots during the juggle answer with the Hurt grunts (bypass the
      -- voice-priority gate: HurtBig from the launch would mute them)
      if CurTime() >= self.UKP_HurtVoiceAt then
        self.UKP_HurtVoiceAt = CurTime() + 0.55
        self:UKP_Voice( "Hurt", false, true )
      end
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  function ENT:OnHurt( dmg, hitgroup )
    -- canon: damaged before our first attack -> jump the queue
    if not self.UKP_HasAttacked and self:Health() < self.UKP_PreAttackHealth then
      self.UKP_PreAttackHealth = self:Health()
      UKPower.Turns.Prioritize( self )
    end

    -- hit reaction on solid hits while idle (short Juggle-pose flinch +
    -- Hurt grunt); never during actions/juggle/death
    if self.UKP_Dead or self.UKP_Juggled then return end
    if self.UKP_ActionName ~= nil then return end
    if dmg and dmg:GetDamage() >= 400 and CurTime() >= self.UKP_FlinchAt then
      self.UKP_FlinchAt = CurTime() + 1.4
      self.UKP_FlinchUntil = CurTime() + 0.4
      self:UKP_PlaySeq( "Juggle", 1.4 )
      if CurTime() >= self.UKP_HurtVoiceAt then
        self.UKP_HurtVoiceAt = CurTime() + 0.55
        self:UKP_Voice( "Hurt" )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKP_Dead then return end
    if self:IsAIDisabled() then -- ai_disabled / per-bot disable
      -- goForward-выпады гонят его по-тиковым loco:SetVelocity — замороженный
      -- мид-рывок иначе дрейфует с последней скоростью (урок Гейбриела)
      if self.loco then self.loco:SetVelocity( vector_origin ) end
      return
    end

    local now = CurTime()
    local dt = math.min( now - ( self.UKP_LastThink or now - FrameTime() ), 0.25 )
    self.UKP_LastThink = now
    if dt <= 0 then dt = FrameTime() end

    local enemy = self:GetEnemy()

    if self.UKP_Juggled then
      self:UKP_JuggleTick( dt )
      -- canon: face the target flat while juggled
      if IsValid( enemy ) then
        local h = self:UKP_EnemyHeadPos( enemy )
        self:FaceInstant( Vector( h.x, h.y, self:GetPos().z ) )
      end
      return
    end

    -- cooldown ticks down only outside actions (canon Update order)
    if not self:UKP_InAction() and self.UKP_AttackCooldown > 0 then
      self.UKP_AttackCooldown = math.max( self.UKP_AttackCooldown - dt, 0 )
    end

    if self.UKP_ActionName then
      self:UKP_ProcessEvents()
    end

    if self:UKP_InAction() then
      -- canon overrideRotation: hard-lock onto the frozen look target
      if self.UKP_OverrideLook then
        self:FaceInstant( self.UKP_OverrideLook )
      elseif IsValid( enemy ) and not self.UKP_Spearing then
        self:FaceTowards( self:UKP_EnemyHeadPos( enemy ) )
      end

      -- canon SpearAttackState.Vertical hover: pinned above the player head
      if self.UKP_SpearHover and IsValid( enemy ) then
        local h = self:UKP_EnemyHeadPos( enemy )
        self:SetPos( h + Vector( 0, 0, 15 * UNIT ) - Vector( 0, 0, 135 ) )
        if self.loco then self.loco:SetVelocity( vector_origin ) end
      end

      -- canon goForward: rb.velocity = forwardSpeed * transform.forward
      -- (m/s x1.25 on Brutal; short damage windows make these fast lunges)
      if self.UKP_GoForward and self.loco then
        local diff = self:UKP_GetDifficulty()
        local mult = diff >= 4 and 1.25 or 1
        local dir = self.UKP_Spearing and ( self.UKP_SpearDir or self:GetForward() )
          or self:GetForward()
        self.loco:SetVelocity( dir *
          ( self.UKP_ForwardSpeed * UNIT * mult * self:UKP_AnimSpeed() ) )

        -- canon spearing raycast: stop the stab at a wall
        if self.UKP_Spearing then
          local tr = util.TraceLine( {
            start = self:UKP_HeadPos(),
            endpos = self:UKP_HeadPos() + dir * ( 2 * UNIT ),
            mask = MASK_SOLID_BRUSHONLY,
          } )
          if tr.Hit then
            self.UKP_Spearing = false
            self:UKP_StopDamage()
          end
        end
      elseif self.loco and self.CantMove then
        self.loco:SetVelocity( vector_origin )
      end

      self:UKP_ApplyMeleeDamage()
      return
    end

    -- possessed: binds start the attacks; everything below is autonomous
    -- decision-making (turn cadence, teleports, self-defense, strafe)
    if self:IsPossessed() then return end

    if not IsValid( enemy ) then return end

    -- canon EnemyCooldowns gate + attack cadence
    local blocked = UKPower.Turns.Blocked( self )
    local visible = self:Visible( enemy )

    if self.UKP_AttackCooldown <= 0 and ( self.UKP_Enraged or not blocked ) then
      if visible then
        self:UKP_PickAttack( enemy )
        return
      end
    end

    -- canon outOfSightTime: teleport after 3 s without vision
    if not visible then
      self.UKP_OutOfSight = math.min( self.UKP_OutOfSight + dt, 3 )
      if self.UKP_OutOfSight >= 3 then
        self:UKP_Teleport()
      end
    else
      self.UKP_OutOfSight = math.max( self.UKP_OutOfSight - dt * 2, 0 )
    end

    -- canon self-defense: hit while waiting for our turn -> counter throw
    if UKPower.Turns.attacking ~= self and UKPower.Turns.Count() > 1
        and now - self.UKP_SinceLastAttacked > 1 then
      if not self.UKP_CheckingSelfDefend then
        self.UKP_CheckingSelfDefend = true
        self.UKP_HealthSinceLastAttacked = self:Health()
      elseif self:Health() <= self.UKP_HealthSinceLastAttacked - 1000 then
        self.UKP_HealthSinceLastAttacked = self:Health()
        if UKPower.Turns.attacking == nil then
          UKPower.Turns.Prioritize( self )
        else
          self.UKP_CheckingSelfDefend = false
          self.UKP_SinceLastAttacked = now
          self:UKP_Voice( "CheapShot", true )
          self:UKP_StartAction( "Throw" )
          self.UKP_TeleportAfterAction = true
          return
        end
      end
    end

    -- canon idle strafe: sidestep around the target, flip at walls
    if self.loco and visible then
      local right = self:GetRight() * ( self.UKP_StrafeLeft and -1 or 1 )
      local probe = util.TraceLine( {
        start = self:WorldSpaceCenter(),
        endpos = self:WorldSpaceCenter() + right * ( 3 * UNIT ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      if probe.Hit then
        self.UKP_StrafeLeft = not self.UKP_StrafeLeft
      else
        -- canon Update: constant 5 m/s sidestep around the target. Steer the
        -- lateral velocity directly (ApproachFlying's accumulator was a
        -- no-show in game) but keep the base's vertical hover correction.
        local vel = right * ( 5 * UNIT )
        vel.z = self.loco:GetVelocity().z
        self.loco:SetVelocity( vel )
      end
      self:FaceTowards( self:UKP_EnemyHeadPos( enemy ) )
    end
  end

  function ENT:OnUpdateAnimation()
    if self.UKP_Juggled then return "Juggle", self:UKP_AnimSpeed() end
    if self.UKP_FlinchUntil and CurTime() < self.UKP_FlinchUntil then
      return "Juggle", 1.4 -- brief hit flinch
    end
    if self.UKP_ActionName and self:UKP_InAction() then
      local cfg = ACTION[ self.UKP_ActionName ]
      -- SpearSpawn's dive phases re-play SpearDrop manually; don't fight them
      if self.UKP_ActionName == "SpearSpawn" and ( self.UKP_Spearing or self.UKP_SpearHover ) then
        return "SpearDrop", self:UKP_AnimSpeed()
      end
      return cfg.seq, self:UKP_AnimSpeed()
    end
    return "Idle", self:UKP_AnimSpeed()
  end

  function ENT:OnMeleeAttack( enemy )
    return -- attacks driven by UKP_PickAttack in CustomThink
  end

  -- actions pin exact velocities (goForward lunges, CantMove zeroing) and the
  -- juggle integrates SetPos by hand — the possessor must not drive the loco
  -- over them; returning true skips DrGBase possession movement for the tick
  function ENT:OnPossession()
    return self.UKP_Juggled or self:UKP_InAction()
  end

  ------------------------------------------------------------------------------
  -- Death (canon Death(): the body vibrates while limbs detach one by one,
  -- light gets sucked back in, then the shell shatters)
  ------------------------------------------------------------------------------

  -- canon deathLimbs order (extremities first); entries scale a whole chain
  -- at once so no child bone is left floating
  local DEATH_LIMBS = {
    { "Foot_L" }, { "Foot_R" },
    { "Calf_L" }, { "Calf_R" },
    { "Thigh_L" }, { "Thigh_R" },
    { "Hand_R", "Fingers_01_R", "Fingers_02_R", "Thumb_01_R", "Thumb_02_R" },
    { "Forearm_R" },
    { "UpperArm_R" },
    { "Head" },
  }

  function ENT:UKP_DetachLimb( bones )
    local anchor
    for _, bname in ipairs( bones ) do
      local id = self:LookupBone( bname )
      if id then
        anchor = anchor or self:GetBonePosition( id )
        self:ManipulateBoneScale( id, Vector( 0.01, 0.01, 0.01 ) )
      end
    end
    anchor = anchor or self:WorldSpaceCenter()
    self:UKP_Ring( anchor, 110, 0.45, 3 )
    self:EmitSound( UKPower.SOUND.WeaponBreak, 78, math.random( 118, 140 ), 0.55 )
  end

  function ENT:OnDeath( dmg, hitgroup )
    self.UKP_Dead = true
    UKPower.Turns.Remove( self )
    self:UKP_StopAction()
    self:SetParryable( false )
    self:SetEnraged( false )
    self:SetMaterial( "" ) -- in case death lands mid-intro (black silhouette)
    self:UKP_SetWeapon( WEP.blank )
    self:UKP_SetCape( false )
    self:UKP_Voice( "Death", true )

    self:UKP_PlaySeq( "Death", 1 )
    self.CantMove = true
    if self.loco then self.loco:SetVelocity( vector_origin ) end

    -- canon DyingUpdate: vibrate while the limbs pop off one after another;
    -- the client draws light particles being sucked INTO the body meanwhile
    self:SetNW2Bool( "UKPower_Dying", true )
    local base = self:GetPos()
    local shakeUntil = CurTime() + 3.0
    local nextLimb = CurTime() + 0.35
    local limbIdx = 1
    while IsValid( self ) and CurTime() < shakeUntil do
      self:SetPos( base + Vector( math.Rand( -8, 8 ), math.Rand( -8, 8 ), math.Rand( -4, 4 ) ) )
      if CurTime() >= nextLimb and limbIdx <= #DEATH_LIMBS then
        self:UKP_DetachLimb( DEATH_LIMBS[ limbIdx ] )
        limbIdx = limbIdx + 1
        nextLimb = CurTime() + 0.26
      end
      self:YieldCoroutine()
    end
    if not IsValid( self ) then return dmg end
    self:SetPos( base )
    self:SetNW2Bool( "UKPower_Dying", false )

    -- canon DeathEffects: the light shatters
    local center = self:WorldSpaceCenter()
    sound.Play( UKPower.SOUND.DeathShatter, center, 95, 100, 1 )
    self:UKP_Ring( center, 640, 1.2, 3 )
    local fx = EffectData()
    fx:SetOrigin( center )
    fx:SetRadius( 4 * UNIT )
    util.Effect( "Ultrakill_Explosion", fx, true, true )

    self:SetRenderMode( RENDERMODE_TRANSCOLOR )
    local fadeUntil = CurTime() + 1.0
    while IsValid( self ) and CurTime() < fadeUntil do
      local a = math.Clamp( ( fadeUntil - CurTime() ), 0, 1 )
      self:SetColor( Color( 255, 255, 255, a * 255 ) )
      self:YieldCoroutine()
    end

    return dmg
  end
end

if CLIENT then

  -- death: light particles get sucked INTO the collapsing body
  function ENT:UKP_DrawDeathSuction()
    if ( self.UKP_NextSuck or 0 ) > CurTime() then return end
    self.UKP_NextSuck = CurTime() + 0.045
    local center = self:WorldSpaceCenter()
    local em = ParticleEmitter( center )
    if not em then return end
    for _ = 1, 5 do
      local dir = VectorRand()
      dir:Normalize()
      local dist = math.Rand( 110, 200 )
      local p = em:Add( "sprites/light_glow02_add", center + dir * dist )
      if p then
        local life = 0.4
        p:SetDieTime( life )
        p:SetStartAlpha( 255 )
        p:SetEndAlpha( 60 )
        p:SetStartSize( math.Rand( 6, 14 ) )
        p:SetEndSize( 2 )
        p:SetColor( 255, 200, 70 )
        p:SetVelocity( dir * ( -dist / life ) )
        p:SetAirResistance( 0 )
        p:SetCollide( false )
      end
    end
    em:Finish()
  end

  -- CustomDraw (NOT Draw): the DrGBase Draw already runs DrawModel +
  -- _BaseDraw (UKBase enraged particle via DrawEnraged) before this hook —
  -- overriding Draw would kill the canon enrage effect.
  function ENT:CustomDraw()
    if self:GetNW2Bool( "UKPower_Dying", false ) then
      self:UKP_DrawDeathSuction()
    end

    -- enraged: gold-red emissive pulse over the whole model (canon Enraged
    -- mats already come through skin 1)
    if self:GetNW2Bool( self.NW_ENRAGED, false ) then
      local pulse = 0.75 + 0.25 * math.sin( CurTime() * 6 )
      render.SetColorModulation( 1, 0.55 * pulse, 0.25 * pulse )
      render.SetBlend( 0.35 )
      self:DrawModel()
      render.SetBlend( 1 )
      render.SetColorModulation( 1, 1, 1 )

      local dl = DynamicLight( self:EntIndex() )
      if dl then
        dl.pos = self:WorldSpaceCenter()
        dl.r, dl.g, dl.b = 255, 120, 30
        dl.brightness = 1.2
        dl.size = 220
        dl.decay = 0
        dl.dietime = CurTime() + 0.1
      end
    end
  end

end

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_power", {
  Name = ENT.PrintName,
  Class = "ultrakill_test_power",
  Category = ENT.Category,
  AdminOnly = false,
} )
