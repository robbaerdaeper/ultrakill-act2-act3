AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_mirror_reaper_shared.lua" )

-- Mirror Reaper (Supreme Husk, 8-2 / Cyber Grind). Level-1 port = the Cyber
-- Grind variant: full canon moveset, no mirror phase (canon precedent — the
-- CG prefab has useMirrorPhase=0; the ONLY diff vs boss is dontSpamProjectiles=1).
-- Event timings extracted from the .anim clips.
-- NB: MirrorReaper.cs was not decompiled — the attack-selection weights below
-- are a wiki-faithful approximation, not a verbatim tree (refine per-boss later).

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Mirror Reaper"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKMirrorReaper.MODEL }
ENT.ModelScale = UKMirrorReaper.SCALE
ENT.SpawnHealth = UKMirrorReaper.HP_REGULAR
-- canon BoxCollider 4 x 7 x 4 m (2x3.5x2 at prefab scale 2), house half-size
ENT.CollisionBounds = Vector( 60, 60, 280 ) * UKMirrorReaper.SCALE
ENT.SurroundingBounds = Vector( 400, 400, 480 ) * UKMirrorReaper.SCALE
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Heavy"

ENT.UKMR_IsMirrorReaper = true

local UNIT = UKMirrorReaper.UNIT
local SCALE = UKMirrorReaper.SCALE

ENT.MeleeAttackRange = 7 * UNIT * SCALE
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 5 * UNIT * SCALE
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 25 * UNIT
ENT.Deceleration = 25 * UNIT
ENT.WalkSpeed = UKMirrorReaper.MOVE_SPEED
ENT.RunSpeed = UKMirrorReaper.MOVE_SPEED
ENT.MaxYawRate = 400
ENT.JumpHeight = 80
ENT.StepHeight = 36
ENT.UseWalkframes = false

-- canon legs are PROCEDURAL (IKFootSolver) — there is no Walk clip. The body
-- glides on Idle (lore: dragged by the puppet strings); canon movementSounds
-- play on a cadence below to sell the motion.
ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Idle"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Idle"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Idle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Idle"
-- the base multiplies this blindly whenever the bot is airborne — nil crashes
-- OnUpdateAnimation (ultrakillbase_nextbot.lua:469) and kills the AI on spawn
ENT.FallingAnimRate = 1

--------------------------------------------------------------------------------
-- Canon clip events (seconds at animation speed 1.0, 30 fps bake).
-- Extracted verbatim from the AnimationClip m_Events:
--   SwingVertical: PredictTarget 0.651/1.283, damage 0.862-1.013 / 1.493-1.651
--   SwingTriple:   damage 0.842-0.980 / 1.145-1.293 / 1.454-1.586
--   SwingSpree:    HighDamageStart x7 (each resets the hit window), stop 2.948
--   GroundWave:    SpawnGroundWave 0.998
--   ProjectileBarrage: decorative 0.855, SpawnProjectiles 1.436
--   Teleport:      TeleportNow 1.212, StartMoving 1.727
--------------------------------------------------------------------------------

local ACTION = {
  SwingVertical = {
    seq = "SwingVertical", dur = 2.441, windup = "WindupVertical",
    ev = {
      { 0.651, "predict" }, { 0.862, "dmgOn" }, { 1.013, "dmgOff" },
      { 1.283, "predict" }, { 1.493, "dmgOn" }, { 1.651, "dmgOff" },
    },
  },
  SwingTriple = {
    seq = "SwingTriple", dur = 2.388, windup = "WindupTriple",
    ev = {
      { 0.842, "dmgOn" }, { 0.980, "dmgOff" },
      { 1.145, "dmgOn" }, { 1.293, "dmgOff" },
      { 1.454, "dmgOn" }, { 1.586, "dmgOff" },
    },
  },
  SwingSpree = {
    seq = "SwingSpree", dur = 3.641, windup = "WindupSpree",
    ev = {
      { 1.479, "dmgOn" }, { 1.693, "dmgOn" }, { 1.894, "dmgOn" },
      { 2.080, "dmgOn" }, { 2.302, "dmgOn" }, { 2.491, "dmgOn" },
      { 2.753, "dmgOn" }, { 2.948, "dmgOff" },
    },
  },
  GroundWave = {
    seq = "GroundWave", dur = 1.985, windup = "WindupGroundwave",
    ev = {
      { 0.998, "spawnHand" },
    },
  },
  ProjectileBarrage = {
    seq = "ProjectileBarrage", dur = 2.007, windup = "WindupProjectile",
    ev = {
      { 0.855, "decorative" }, { 1.436, "spawnOrbs" },
    },
  },
  Teleport = {
    seq = "Teleport", dur = 2.039, windup = nil,
    ev = {
      { 1.212, "teleportNow" }, { 1.727, "reappearDone" },
    },
  },
}

-- ULTRAKILL difficulty -> animation speed (house profile, same as Ferryman)
local ANIMSPEED_BY_DIFF = { [ 0 ] = 0.5, [ 1 ] = 0.75, [ 2 ] = 1.0, [ 3 ] = 1.0, [ 4 ] = 1.25, [ 5 ] = 1.5 }

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 20, 60 ),
    distance = 200,
    eyepos = false

  },

  {

    offset = Vector( 10, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMR_Dead or self:UKMR_InAction() then return end

    if Possessor:KeyDown( IN_FORWARD ) then

      self:UKMR_StartAction( "SwingTriple" )

    elseif Possessor:KeyDown( IN_BACK ) then

      self:UKMR_StartAction( "SwingSpree" )

    else

      self:UKMR_StartAction( "SwingVertical" )

    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMR_Dead or self:UKMR_InAction() then return end
    if CurTime() < self.UKMR_OrbCooldown then return end

    self.UKMR_OrbCooldown = CurTime() + 7
    self:UKMR_StartAction( "ProjectileBarrage" )

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMR_Dead or self:UKMR_InAction() then return end
    if CurTime() < self.UKMR_HandCooldown then return end
    if self:UKMR_ActiveHandCount() >= self:UKMR_MaxHands() then return end

    self.UKMR_HandCooldown = CurTime() + ( self:UKMR_GetDifficulty() >= 4 and 6 or 9 )
    self:UKMR_StartAction( "GroundWave" )

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMR_Dead or self:UKMR_InAction() then return end
    if CurTime() < self.UKMR_VanishCooldown then return end
    -- UKMR_PickTeleportSpot anchors on the enemy: no lock-on = no destination
    if not IsValid( self:PossessionGetLockedOn() ) then return end

    self.UKMR_VanishCooldown = CurTime() + 10
    self:UKMR_StartAction( "Teleport" )

  end } },

}

if SERVER then

  function ENT:CustomInitialize()
    self:SetModel( UKMirrorReaper.MODEL )

    self.UKMR_ActionName = nil
    self.UKMR_ActionStart = 0
    self.UKMR_ActionUntil = nil
    self.UKMR_ActionEvIndex = 1
    self.UKMR_Damaging = false
    self.UKMR_ActionHits = nil
    self.UKMR_Tracking = false

    self.UKMR_Hands = {}
    self.UKMR_HandsThisCycle = 0
    self.UKMR_HandCooldown = 2
    self.UKMR_OrbCooldown = 4
    self.UKMR_VanishCooldown = 8
    self.UKMR_RecentDamage = 0
    self.UKMR_RecentDamageAt = 0
    self.UKMR_UnreachSince = nil
    self.UKMR_SlowTick = 0
    self.UKMR_NextMoveSound = 0
    self.UKMR_NextBreath = 0

    self:SetParryable( false )

    -- live mesh (bodygroup body: 0 = live, 1 = canon corpse mesh)
    local bg = self:FindBodygroupByName( "body" )
    if bg and bg >= 0 then self:SetBodygroup( bg, 0 ) end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKMR_RemoveHands()
  end

  function ENT:UKMR_GetDifficulty()
    return self.UltrakillBase_Difficulty or 3
  end

  function ENT:UKMR_AnimSpeed()
    return ANIMSPEED_BY_DIFF[ self:UKMR_GetDifficulty() ] or 1.0
  end

  ------------------------------------------------------------------------------
  -- Action system (Ferryman pattern)
  ------------------------------------------------------------------------------

  function ENT:UKMR_InAction()
    if self.UKMR_ActionUntil and self.UKMR_ActionUntil > CurTime() then return true end
    if self.UKMR_ActionName then self:UKMR_EndAction() end
    return false
  end

  function ENT:UKMR_ActionTime()
    return ( CurTime() - ( self.UKMR_ActionStart or 0 ) ) * self:UKMR_AnimSpeed()
  end

  function ENT:UKMR_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKMR_AnimSpeed()

    local enemy = self:GetEnemy()
    if IsValid( enemy ) then
      local tpos = enemy:GetPos()
      self:FaceInstant( Vector( tpos.x, tpos.y, self:GetPos().z ) )
    end

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKMR_ActionName = name
    self.UKMR_ActionStart = CurTime()
    self.UKMR_ActionUntil = CurTime() + cfg.dur / spd
    self.UKMR_ActionEvIndex = 1
    self.UKMR_ActionHits = {}
    self.UKMR_Damaging = false
    self.UKMR_Tracking = true

    if cfg.windup then
      self:EmitSound( UKMirrorReaper.SOUND[ cfg.windup ], 95, 100, 1 )
    end

    self.loco:SetVelocity( vector_origin )
    self.CantMove = true
    self:SetMaxYawRate( 0 )
  end

  function ENT:UKMR_EndAction()
    self.UKMR_ActionName = nil
    self.UKMR_ActionUntil = nil
    self.UKMR_Damaging = false
    self.UKMR_Tracking = false
    self.CantMove = false
    self:SetParryable( false )
    self:SetMaxYawRate( self.MaxYawRate )
  end

  ------------------------------------------------------------------------------
  -- Events
  ------------------------------------------------------------------------------

  function ENT:UKMR_ProcessEvents()
    local cfg = self.UKMR_ActionName and ACTION[ self.UKMR_ActionName ]
    if not cfg then return end
    local t = self:UKMR_ActionTime()
    while self.UKMR_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKMR_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKMR_ActionEvIndex = self.UKMR_ActionEvIndex + 1
      self:UKMR_FireEvent( ev[ 2 ], ev[ 3 ] )
    end
  end

  function ENT:UKMR_FireEvent( kind, arg )
    if kind == "predict" then
      -- canon PredictTarget: snap onto the target right before the vertical hit
      local enemy = self:GetEnemy()
      if IsValid( enemy ) then
        local tpos = enemy:GetPos()
        self:FaceInstant( Vector( tpos.x, tpos.y, self:GetPos().z ) )
      end
    elseif kind == "dmgOn" then
      self:UKMR_StartDamage()
    elseif kind == "dmgOff" then
      self:UKMR_StopDamage()
    elseif kind == "spawnHand" then
      self:UKMR_SpawnHand()
    elseif kind == "decorative" then
      -- canon SpawnDecorativeProjectiles: telegraph orbs around the body
      local fx = EffectData()
      fx:SetOrigin( self:UKMR_ChestPos() )
      fx:SetScale( 1 )
      util.Effect( "cball_bounce", fx, true, true )
    elseif kind == "spawnOrbs" then
      self:UKMR_SpawnOrbs()
    elseif kind == "teleportNow" then
      self:UKMR_TeleportNow()
    elseif kind == "reappearDone" then
      self:EmitSound( UKMirrorReaper.SOUND.TeleportReverse, 90, 100, 1 )
    end
  end

  ------------------------------------------------------------------------------
  -- Melee (canon SwingCheck2: 30 dmg, sliding player is ignored, one landed
  -- hit closes the window; per-window hit list reset)
  ------------------------------------------------------------------------------

  function ENT:UKMR_StartDamage()
    self.UKMR_Damaging = true
    self.UKMR_ActionHits = {}
    -- canon: SwingCheck AudioSources play FerrymanSwing1 at pitch 2.0
    self:EmitSound( UKMirrorReaper.SOUND.SwingWhoosh, 90, math.random( 190, 210 ), 1 )
  end

  function ENT:UKMR_StopDamage()
    self.UKMR_Damaging = false
    self:SetParryable( false )
  end

  function ENT:UKMR_ApplyMeleeDamage()
    if not self.UKMR_Damaging then return end
    local hits = self.UKMR_ActionHits or {}
    self.UKMR_ActionHits = hits

    -- canon check boxes (prefab local, x2 world scale): low 4x2x5.5 @ z2.5,
    -- high 4x1x5.5 @ z2.5, vertical 0.7x6x4.5 @ z2.25 — front boxes ~5 m deep.
    -- Approximated as a frontal sphere (scaled with the half-size model).
    local center = self:WorldSpaceCenter() + self:GetForward() * ( 2.5 * UNIT * SCALE )
    local radius = 3.5 * UNIT * SCALE

    for _, ent in ipairs( ents.FindInSphere( center, radius ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKMR_IsMirrorReaper or ent.UKMR_IsHand then continue end
      -- canon ignoreSlidingPlayer: a sliding player passes under every swing
      if ent:IsPlayer() and ent:Crouching() and ent:GetVelocity():Length2D() > 250 then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKMirrorReaper.ScaleAttackDamage( ent, UKMirrorReaper.SWING_DAMAGE, self ) )
      dmg:SetDamageType( DMG_SLASH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 1400 + Vector( 0, 0, 220 ) )
      ent:TakeDamageInfo( dmg )
      self:EmitSound( UKMirrorReaper.SOUND.SwingImpact, 90, 100, 0.8 )

      -- canon TargetBeenHit: a landed hit closes the window
      self.UKMR_Damaging = false
      break
    end
  end

  ------------------------------------------------------------------------------
  -- Phantom Hand (canon GroundWave)
  ------------------------------------------------------------------------------

  function ENT:UKMR_ActiveHandCount()
    local n = 0
    for i = #self.UKMR_Hands, 1, -1 do
      local h = self.UKMR_Hands[ i ]
      if IsValid( h ) then n = n + 1 else table.remove( self.UKMR_Hands, i ) end
    end
    return n
  end

  function ENT:UKMR_MaxHands()
    -- canon: 2 active (Brutal: 3); Harmless/Lenient: 1
    local diff = self:UKMR_GetDifficulty()
    if diff <= 1 then return 1 end
    if diff >= 5 then return 3 end
    return 2
  end

  function ENT:UKMR_SpawnHand()
    if self:UKMR_ActiveHandCount() >= self:UKMR_MaxHands() then return end
    local pos = self:GetPos() + self:GetForward() * ( 2 * UNIT * SCALE )
    local tr = util.TraceLine( {
      start = pos + Vector( 0, 0, 40 ),
      endpos = pos - Vector( 0, 0, 200 ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    local hand = ents.Create( UKMirrorReaper.CLASS.Hand )
    if not IsValid( hand ) then return end
    hand:SetPos( tr.Hit and tr.HitPos or pos )
    hand:SetAngles( Angle( 0, self:GetAngles().yaw, 0 ) )
    hand.UKMR_Owner = self
    hand:Spawn()
    table.insert( self.UKMR_Hands, hand )
    self:EmitSound( UKMirrorReaper.SOUND.GroundwaveLoop, 90, 100, 0.66 )
  end

  function ENT:UKMR_RemoveHands()
    for _, h in ipairs( self.UKMR_Hands or {} ) do
      if IsValid( h ) then h:Remove() end
    end
    self.UKMR_Hands = {}
  end

  ------------------------------------------------------------------------------
  -- Acid Missiles (canon ProjectileBarrage: 3 orbs, homing 2 s)
  ------------------------------------------------------------------------------

  function ENT:UKMR_SpawnOrbs()
    local enemy = self:GetEnemy()
    local chest = self:UKMR_ChestPos()
    for i = -1, 1 do
      local orb = ents.Create( UKMirrorReaper.CLASS.Orb )
      if not IsValid( orb ) then continue end
      local dir
      if IsValid( enemy ) then
        dir = ( enemy:WorldSpaceCenter() - chest ):GetNormalized()
      else
        dir = self:GetForward()
      end
      local ang = dir:Angle()
      ang:RotateAroundAxis( ang:Up(), i * 12 )
      orb:SetPos( chest + self:GetForward() * ( 30 * SCALE ) + self:GetRight() * ( i * 25 * SCALE ) )
      orb:SetAngles( ang )
      orb.UKMR_Owner = self
      orb.UltrakillBase_Target = enemy
      orb:Spawn()
      orb:SetVelocity( ang:Forward() * ( 20 * UNIT ) )
    end
  end

  ------------------------------------------------------------------------------
  -- Vanish (canon Teleport: random spot out of the player's sight) and the
  -- portal-to-player fallback (canon: "uses portal to the player's location
  -- if there is no direct path")
  ------------------------------------------------------------------------------

  function ENT:UKMR_TeleportNow()
    self:EmitSound( UKMirrorReaper.SOUND.Teleport, 95, 100, 1 )
    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    fx:SetScale( 2 )
    util.Effect( "cball_explode", fx, true, true )

    local enemy = self:GetEnemy()
    local dest = self:UKMR_PickTeleportSpot( enemy, self.UKMR_TeleportToPlayer )
    self.UKMR_TeleportToPlayer = false
    if dest then
      self:SetPos( dest )
      self.loco:SetVelocity( vector_origin )
    end

    local fx2 = EffectData()
    fx2:SetOrigin( self:WorldSpaceCenter() )
    fx2:SetScale( 2 )
    util.Effect( "cball_explode", fx2, true, true )
  end

  -- toPlayer=true: land next to the target (path recovery). Otherwise: a
  -- random navmesh spot 10-20 m away, preferring no line of sight to the player.
  function ENT:UKMR_PickTeleportSpot( enemy, toPlayer )
    if not IsValid( enemy ) then return nil end
    local epos = enemy:GetPos()
    local eyes = enemy.EyePos and enemy:EyePos() or epos

    local best, bestLOS
    for i = 1, 14 do
      local ang = math.Rand( 0, 360 )
      local dist = toPlayer and math.Rand( 4, 7 ) or math.Rand( 10, 20 )
      local candidate = epos + Angle( 0, ang, 0 ):Forward() * ( dist * UNIT )
      local nav = navmesh.GetNearestNavArea( candidate, false, 3000, true )
      if not IsValid( nav ) then continue end
      local spot = nav:GetClosestPointOnArea( candidate ) + Vector( 0, 0, 5 )
      local tr = util.TraceLine( { start = eyes, endpos = spot + Vector( 0, 0, 100 ), mask = MASK_VISIBLE } )
      local visible = not tr.Hit
      if toPlayer then
        return spot -- path recovery: LOS is fine, proximity matters
      end
      if not visible then return spot end
      if not best then best, bestLOS = spot, visible end
    end
    return best
  end

  ------------------------------------------------------------------------------
  -- Damage in / weaknesses (canon weaknessMultipliers)
  ------------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKMR_Dead then return end

    -- canon: fire 0.33 (ground slam / nails / sawblades 0.5 are weapon-pack
    -- specific mechanics — handled when the pack compat lands)
    if bit.band( dmg:GetDamageType(), DMG_BURN ) ~= 0 then
      dmg:ScaleDamage( 0.33 )
    end

    -- vanish pressure: heavy burst damage pushes it to teleport away
    local now = CurTime()
    if now - self.UKMR_RecentDamageAt > 2 then self.UKMR_RecentDamage = 0 end
    self.UKMR_RecentDamage = self.UKMR_RecentDamage + dmg:GetDamage()
    self.UKMR_RecentDamageAt = now

    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Attack selection (wiki-faithful approximation; see header note)
  ------------------------------------------------------------------------------

  function ENT:UKMR_AttackCheck( enemy )
    local dist = self:GetPos():Distance( enemy:GetPos() )
    local now = CurTime()

    -- burst-damage vanish (out of melee pressure)
    if self.UKMR_RecentDamage > UKMirrorReaper.HP_REGULAR * 0.12
        and now >= self.UKMR_VanishCooldown then
      self.UKMR_RecentDamage = 0
      self.UKMR_VanishCooldown = now + 10
      self:UKMR_StartAction( "Teleport" )
      return
    end

    if dist <= self.MeleeAttackRange then
      -- canon: keeps short range for melee combos; frenzy punishes lingering
      local roll = math.random()
      if roll < 0.15 and self:UKMR_GetDifficulty() >= 2 then
        self:UKMR_StartAction( "SwingSpree" )
      elseif roll < 0.55 then
        self:UKMR_StartAction( "SwingVertical" )
      else
        self:UKMR_StartAction( "SwingTriple" )
      end
      return
    end

    if dist <= 25 * UNIT then
      -- mid range: hands and orbs on their own cooldowns
      if now >= self.UKMR_HandCooldown
          and self:UKMR_ActiveHandCount() < self:UKMR_MaxHands() then
        self.UKMR_HandCooldown = now + ( self:UKMR_GetDifficulty() >= 4 and 6 or 9 )
        self:UKMR_StartAction( "GroundWave" )
        return
      end
      if now >= self.UKMR_OrbCooldown then
        -- CG variant: dontSpamProjectiles => longer cooldown
        self.UKMR_OrbCooldown = now + 7
        self:UKMR_StartAction( "ProjectileBarrage" )
        return
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:UKMR_ChestPos()
    local id = self:LookupAttachment( "chest" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter() + Vector( 0, 0, 60 * SCALE )
  end

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKMR_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local enemy = self:GetEnemy()

    -- canon Breathing loop (vol 0.35, on Spine_05)
    if now >= self.UKMR_NextBreath then
      self.UKMR_NextBreath = now + math.max( SoundDuration( UKMirrorReaper.SOUND.Breathing ) or 2, 1.5 )
      self:EmitSound( UKMirrorReaper.SOUND.Breathing, 80, 100, 0.35 )
    end

    -- possessed: an empty lock-on is the normal state — the event/damage loop
    -- below must keep running or bind-started swings get cancelled mid-animation
    if not IsValid( enemy ) and not self:IsPossessed() then
      if self:UKMR_InAction() then self:UKMR_EndAction() end
      return
    end

    -- canon movementSounds: random of 4 while gliding
    if not self:UKMR_InAction() and self.loco:GetVelocity():Length2D() > 40
        and now >= self.UKMR_NextMoveSound then
      self.UKMR_NextMoveSound = now + math.Rand( 0.55, 0.8 )
      self:EmitSound( UKMirrorReaper.SOUND.Movement[ math.random( 4 ) ], 85,
        math.random( 95, 105 ), 0.8 )
    end

    -- canon portal-to-player: no path to the target for 3 s => teleport to it
    if not self:IsPossessed() then
      self.UKMR_SlowTick = self.UKMR_SlowTick + FrameTime()
      if self.UKMR_SlowTick >= 0.5 then
        self.UKMR_SlowTick = 0
        local path = self:GetPath()
        local stuck = not IsValid( enemy:GetPhysicsObject() ) and false
        local unreachable = ( path and not path:IsValid() ) or false
        if unreachable then
          self.UKMR_UnreachSince = self.UKMR_UnreachSince or CurTime()
          if CurTime() - self.UKMR_UnreachSince > 3 and not self:UKMR_InAction() then
            self.UKMR_UnreachSince = nil
            self.UKMR_TeleportToPlayer = true
            self:UKMR_StartAction( "Teleport" )
          end
        else
          self.UKMR_UnreachSince = nil
        end
      end
    end

    if self.UKMR_ActionName then
      self:UKMR_ProcessEvents()
    end

    if self:UKMR_InAction() then
      self:UKMR_ApplyMeleeDamage()
    elseif self:IsOnGround() and not self:IsPossessed() then
      self:UKMR_AttackCheck( enemy )
    end
  end

  function ENT:OnMeleeAttack( enemy )
    -- driven by UKMR_AttackCheck in CustomThink
    return
  end

  function ENT:OnUpdateSpeed()
    return UKMirrorReaper.MOVE_SPEED * self:UKMR_AnimSpeed()
  end

  ------------------------------------------------------------------------------
  -- Death (canon: sharedMesh swapped to the corpse mesh, rig frozen)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKMR_Dead = true
    self:UKMR_EndAction()
    self:UKMR_RemoveHands()
    self:StopSound( UKMirrorReaper.SOUND.Breathing )

    self:EmitSound( UKMirrorReaper.SOUND.Death, 90, 100, 0.35 )
    if math.random( 3 ) == 1 then
      self:EmitSound( UKMirrorReaper.SOUND.Scream, 92, 100, 0.8 )
    end

    -- canon corpse: swap to the dead mesh, freeze on the current frame
    local bg = self:FindBodygroupByName( "body" )
    if bg and bg >= 0 then self:SetBodygroup( bg, 1 ) end
    local idle = self:LookupSequence( "Idle" )
    if idle and idle >= 0 then
      self:ResetSequence( idle )
      self:SetCycle( 0 )
      self:SetPlaybackRate( 0 )
    end

    local lieUntil = CurTime() + 4
    while IsValid( self ) and CurTime() < lieUntil do
      self:YieldCoroutine()
    end

    if IsValid( self ) then
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

end

DrGBase.AddNextbot( ENT )
