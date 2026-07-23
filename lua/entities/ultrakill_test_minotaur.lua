AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_minotaur_shared.lua" )

-- Minotaur (Supreme Demon, 7-1 boss). Arena / sandbox variant = canon phase 2:
-- the game's own EnemySpawnableInstance prefab ('Minotaur', ctrl Minotaur).
-- Attacks with exact clip-event timings from the baked .anim data:
--   HammerTantrum (4-swing combo), HammerSmash (impact + 2 explosions),
--   MeatLow (acid splash -> puddle), MeatHigh (acid bomb -> cloud),
--   Ram (windup -> charge; parryable; wall bonk stun / parried stun).
-- Canon rules: guaranteed tantrum opener, forced ram after 3 other attacks,
-- fractured-head weak point exposed only while attacking or stunned.
-- The tram-chase variant (MinotaurChase) is a separate future entity.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Minotaur (Sandbox)"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKMinotaur.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKMinotaur.HP
-- canon NavAgent r=3 m, h=11 m at 20 su/m; the long body beyond this square
-- is covered by the frozen VPhysics body colliders (UKM_Colliders)
ENT.CollisionBounds = Vector( 128, 128, 220 )
ENT.SurroundingBounds = Vector( 320, 320, 360 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy"

ENT.UKMinotaur_IsMinotaur = true -- own explosions/acid never hurt Minotaurs
ENT.IsBoss = false

local UNIT = UKMinotaur.UNIT

ENT.MeleeAttackRange = 10 * UNIT
ENT.RangeAttackRange = 0
-- canon NavMeshAgent stoppingDistance 15 m
ENT.ReachEnemyRange = UKMinotaur.STOP_DISTANCE
ENT.AvoidEnemyRange = 0


ENT.Acceleration = 100 * UNIT
ENT.Deceleration = 0
ENT.WalkSpeed = 1000
ENT.RunSpeed = 1000
ENT.MaxYawRate = 400
ENT.JumpHeight = 75
ENT.StepHeight = 45
ENT.UseWalkframes = false

ENT.IdleAnimation = "HurtIdle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Run"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Run"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Run"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Run"
ENT.FallingAnimRate = 1

--------------------------------------------------------------------------------
-- Canon clip events (seconds at animation speed 1.0, 30 fps bake).
-- ev kinds: swingOn/swingOff (staff/hand SwingCheck2 window), impact (hammer
-- ground hit: 25 dmg window close + BreakParticleBig), explosion/superExplosion
-- (HammerExplosion events), handBlood, meatSpawn/meatSplash/meatExplode,
-- ramStart (windup -> charge), thud (BodyImpact), trackOn/trackOff,
-- moveOn(speed m/s)/moveOff.
--------------------------------------------------------------------------------

local ACTION = {
  HammerTantrum = {
    seq = "HammerTantrum", dur = 3.800, track = true, roar = true,
    ev = {
      -- canon: four swings while approaching (horizontal, vert, vert, horizontal)
      -- the moveoff actually stops somwhere around 2.6
      { 0.900, "moveOn", 10 },
      { 1.128, "swingOn" }, { 1.477, "swingOff" },
      { 1.643, "swingOn" }, { 1.975, "swingOff" },
      { 2.174, "swingOn" }, { 2.412, "impact" },
      { 2.689, "swingOn" }, { 3.004, "swingOff" },
      { 2.6, "moveOff" },
    },
  },
  HammerSmash = {
    seq = "HammerSmash", dur = 3.511, track = true,
    ev = {
      { 0.957, "swingOn" }, { 1.102, "impact" },
      { 1.778, "explosion" },
      { 2.493, "superExplosion" },
      { 3.025, "trackOn" },
    },
  },
  MeatLow = {
    seq = "MeatLow", dur = 3.190, track = true,
    ev = {
      { 0.404, "handBlood" },
      { 1.014, "meatSpawn" },
      { 2.403, "meatSplash" },
      { 2.734, "trackOn" },
    },
  },
  MeatHigh = {
    seq = "MeatHigh", dur = 3.451, track = true,
    ev = {
      { 0.441, "handBlood" },
      { 1.097, "meatSpawn" },
      { 2.387, "meatExplode" },
      { 3.010, "trackOn" },
    },
  },
  RamWindup = {
    seq = "RamWindup", dur = 1.167, track = true, roar = true,
    ev = {
      { 0.942, "ramStart" },
    },
  },
  RamSwing = {
    seq = "RamSwing", dur = 0.805, track = false,
    ev = {},
  },
  RamBonk = {
    -- canon wall bonk; extra hold past the clip = the wall-stun window
    seq = "RamBonk", dur = 2.100, track = false, stun = true,
    ev = {
      { 0.876, "trackOn" },
    },
  },
  RamParried = {
    -- canon parry stun exceeds the wall stun
    seq = "RamParried", dur = 3.600, track = false, stun = true,
    ev = {
      { 0.741, "thud" },
      { 1.790, "trackOn" },
    },
  },
}

-- canon difficulty speed profile (wiki): -50% / -25% / 1.0 / +25% / +50%
local ANIMSPEED_BY_DIFF = { [0] = 0.5, [1] = 0.75, [2] = 1.0, [3] = 1.25, [4] = 1.5 }

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKMinotaur.HP
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
    self.UKM_Moving = false
    self.UKM_MovingSpeed = 0
    self.UKM_Swinging = false
    self.UKM_ActionHits = nil
    self.UKM_Stunned = false
    self.AvailableAttacks = {"HammerTantrum", "HammerSmash", "MeatLow","MeatHigh"}

    -- canon arena behavior: tantrum is the guaranteed opener, and every
    -- 3 non-ram attacks force a Stampede Charge
    self.UKM_FirstAttackDone = false
    self.UKM_AttackCount = 0
    self.UKM_AttackCooldown = 0

    self.UKM_Ramming = false
    self.UKM_RamUntil = 0
    self.UKM_RamHitAt = nil

    self.UKM_NextHurtSound = 0
    self.UKM_NextExhale = CurTime() + math.Rand( 4, 8 )

    self:SetParryable( false )
    self:SetSkin( 0 )

    --self:UKM_CreateColliders()

    UltrakillBase.SoundScript( "Ultrakill_MinotaurRoar", self:GetPos() )
    if self.IsBoss and UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, "MINOTAUR" )
      self:UKM_StartAction( "HammerTantrum" )
    end
  end

  ------------------------------------------------------------------------------
  -- Body colliders (gutterman-shield idiom): the nextbot square only covers
  -- the torso column, so the long body gets frozen VPhysics boxes that track
  -- the boss themselves (collider Think). The fractured-head zone stays
  -- box-free so weak-point shots and coin ricochets still reach the hitboxes.
  ------------------------------------------------------------------------------

  function ENT:UKM_CreateColliders()
    self.UKM_Colliders = {}
    -- canon root BoxCollider 4x8x8 m (4 wide, 8 tall, 8 long, 1 m back)
    local boxes = {
      -- chest / front legs, kept below the lowered head line
      { mins = Vector( 0, -1.8 * UNIT, 0.3 * UNIT ),
        maxs = Vector( 3.5 * UNIT, 1.8 * UNIT, 6.2 * UNIT ) },
      -- body / hindquarters
      { mins = Vector( -5 * UNIT, -1.9 * UNIT, 0.3 * UNIT ),
        maxs = Vector( 0, 1.9 * UNIT, 7 * UNIT ) },
    }
    for _, box in ipairs( boxes ) do
      local col = ents.Create( UKMinotaur.CLASS.Collider )
      if not IsValid( col ) then continue end
      col.UKM_Mins = box.mins
      col.UKM_Maxs = box.maxs
      col.UKM_ForwardTo = self
      col:SetPos( self:GetPos() )
      col:SetAngles( Angle( 0, self:GetAngles().yaw, 0 ) )
      col:Spawn()
      col:SetOwner( self )
      self:DeleteOnRemove( col )
      table.insert( self.UKM_Colliders, col )
    end
  end

  function ENT:UKM_SetCollidersSolid( solid )
    if not self.UKM_Colliders then return end
    for _, col in ipairs( self.UKM_Colliders ) do
      if IsValid( col ) then col:SetNotSolid( not solid ) end
    end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKM_RemoveMeatProp()
  end

  function ENT:UKM_GetDifficulty()
    return self.UltrakillBase_Difficulty or 2
  end

  function ENT:UKM_AnimSpeed()
    return ANIMSPEED_BY_DIFF[ self:UKM_GetDifficulty() ] or 1.0
  end

  ------------------------------------------------------------------------------
  -- Helpers
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
    return self:UKM_GetAttachmentPos( "head",
      self:GetPos() + Vector( 0, 0, 10 * UNIT ) )
  end

  function ENT:UKM_HammerPos()
    return self:UKM_GetAttachmentPos( "hammer",
      self:GetPos() + self:GetForward() * ( 5 * UNIT ) )
  end

  function ENT:UKM_MeatPos()
    return self:UKM_GetAttachmentPos( "meat",
      self:WorldSpaceCenter() + self:GetForward() * ( 2 * UNIT ) )
  end

  -- horizontal player-position prediction (STANDARD+ only, like canon AI)
  function ENT:UKM_PredictEnemyPos( maxLeadMeters )
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then return self:GetPos() + self:GetForward() * 100 end
    local tpos = enemy:GetPos()
    if self:UKM_GetDifficulty() <= 1 then return tpos end
    local vel = enemy.GetVelocity and enemy:GetVelocity() or vector_origin
    local hv = Vector( vel.x, vel.y, 0 )
    local speedMeters = hv:Length() / UNIT
    if speedMeters > 0.01 then
      hv:Normalize()
      hv:Mul( math.min( speedMeters, maxLeadMeters or 4 ) * UNIT )
    end
    return tpos + hv
  end

  ------------------------------------------------------------------------------
  -- Action system (ferryman pattern)
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
    if IsValid( enemy ) and not cfg.stun then
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
    self.UKM_Tracking = cfg.track or false
    self.UKM_Moving = false
    self.UKM_MovingUntil = nil
    self.UKM_Swinging = false
    self.UKM_ActionHits = {}
    self.UKM_Stunned = cfg.stun or false

    self.loco:SetVelocity( vector_origin )
    self.CantMove = true
    self:SetMaxYawRate( 0 )
    if name == "HammerSmash" then
      UltrakillBase.SoundScript( "Ultrakill_MinotaurSqueal", self:GetPos() )
    self.AvailableAttacks = {"HammerTantrum", "MeatLow","MeatHigh"}
    elseif  name == "HammerTantrum" then
    self.AvailableAttacks = {"HammerSmash", "MeatLow","MeatHigh"}
    end

    if cfg.roar then
      if name == "HammerTantrum" then
      UltrakillBase.SoundScript( "Ultrakill_MinotaurRoar", self:GetPos() )
      else
      UltrakillBase.SoundScript( "Ultrakill_MinotaurGruntLong", self:GetPos() )
      end
    elseif not cfg.stun then
      UltrakillBase.SoundScript( "Ultrakill_MinotaurShort", self:GetPos() )
    end
  end

  function ENT:UKM_EndAction()
    self.UKM_ActionName = nil
    self.UKM_ActionUntil = nil
    self.UKM_Tracking = false
    self.UKM_Moving = false
    self.UKM_MovingUntil = nil
    self.UKM_Swinging = false
    self.UKM_Stunned = false
    self.CantMove = false
    self:SetParryable( false )
    self:SetMaxYawRate( self.MaxYawRate )
    self:UKM_RemoveMeatProp()
    -- pause before the next decision (canon attack cadence)
    self.UKM_AttackCooldown = CurTime()
      + math.Rand( 0.7, 1.3 ) / self:UKM_AnimSpeed()
  end

  ------------------------------------------------------------------------------
  -- Event dispatch
  ------------------------------------------------------------------------------

  function ENT:UKM_ProcessEvents()
    local cfg = self.UKM_ActionName and ACTION[ self.UKM_ActionName ]
    if not cfg then return end
    local t = self:UKM_ActionTime()

    while self.UKM_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKM_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKM_ActionEvIndex = self.UKM_ActionEvIndex + 1
      self:UKM_FireEvent( ev[ 2 ], ev[ 3 ] )
    end
  end

  function ENT:UKM_FireEvent( kind, arg )
    if kind == "swingOn" then
      self.UKM_Swinging = true
      self.UKM_ActionHits = {} -- canon SwingCheck2: hit list per damage window
      self.UKM_Tracking = false
      local snd = math.random( 2 ) == 1 and UKMinotaur.SOUND.Swing1 or UKMinotaur.SOUND.Swing2
      self:EmitSound( snd, 95, math.random( 55, 75 ), 1 )
    elseif kind == "swingOff" then
      self.UKM_Swinging = false
      self.UKM_Tracking = true
    elseif kind == "impact" then
      self.UKM_Swinging = false
      self.UKM_Tracking = true
      local pos = self:UKM_HammerPos()
      pos = Vector( pos.x, pos.y, self:GetPos().z )
      UltrakillBase.SoundScript( "Ultrakill_RockBreak", self:GetPos() )
      self:CreateBigRubble(  pos, self:GetAngles() )
      self:ScreenShake( 150, 10, 1, 2000 )
    elseif kind == "explosion" then
      local pos = self.UKM_LastImpactPos or self:UKM_HammerPos()
      self:ScreenShake( 2500, 10, 1.5, 6500 )
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
      self:Explosion( self:GetPos(), 350, Vector( 350, 0, 300 ), 500, 0.2 )
      self:CreateExplosion( pos, self:GetAngles(), UKMinotaur.EXPLOSION_RADIUS )
    elseif kind == "superExplosion" then
      local pos = self.UKM_LastImpactPos or self:UKM_HammerPos()
      self:ScreenShake( 2500, 10, 1.5, 6500 )
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
      self:Explosion( self:GetPos(), 350, Vector( 350, 0, 300 ), 800, 0.2 )
      self:CreateHardExplosion( pos, self:GetAngles(), UKMinotaur.SUPER_EXPLOSION_RADIUS )
    elseif kind == "handBlood" then
      self.AvailableAttacks = {"HammerTantrum", "HammerSmash"}
      sound.Play( UKMinotaur.SOUND.MeatSquish, self:UKM_MeatPos(), 85, 100, 0.8 )
    elseif kind == "meatSpawn" then
      self:UKM_SpawnMeatProp()
    elseif kind == "meatSplash" then
      self:UKM_ThrowMeat()
    elseif kind == "meatExplode" then
      self:UKM_ExplodeMeat()
    elseif kind == "ramStart" then
      self:UKM_BeginRamRun()
    elseif kind == "thud" then
      local pos = self:GetPos()
      UltrakillBase.SoundScript( "Ultrakill_PunchHeavy", self:GetPos() )
      UltrakillBase.SoundScript( "Ultrakill_RockBreak", self:GetPos() )
      self:CreateBigRubble(  pos, self:GetAngles() )
      self:ScreenShake( 50, 10, 1, 2000 )
    elseif kind == "trackOn" then
      self.UKM_Tracking = true
    elseif kind == "trackOff" then
      self.UKM_Tracking = false
    elseif kind == "moveOn" then
      self.UKM_Moving = true
      self.UKM_MovingSpeed = ( arg or 1 ) * UNIT
    elseif kind == "moveOff" then
      self.UKM_Moving = false
    end
  end

  ------------------------------------------------------------------------------
  -- Meat (acid) attacks
  ------------------------------------------------------------------------------

  function ENT:UKM_AcidOpts( mode )
    local diff = self:UKM_GetDifficulty()
    return {
      mode = mode,
      attacker = self,
      tickDamage = UKMinotaur.AcidTickDamage( diff ),
      -- canon Brutal: acid lingers twice as long (GoopLong prefabs)
      lifetime = UKMinotaur.ACID_LIFETIME * ( diff >= 4 and 2 or 1 ),
      radius = mode == "cloud" and UKMinotaur.CLOUD_RADIUS
        or UKMinotaur.PUDDLE_RADIUS,
    }
  end

  function ENT:UKM_SpawnMeatProp()
    self:UKM_RemoveMeatProp()
    local prop = ents.Create( "prop_dynamic" )
    if not IsValid( prop ) then return end
    prop:SetModel( "models/hunter/misc/sphere025x025.mdl" )
    prop:SetModelScale( 1.6, 0 )
    prop:SetPos( self:UKM_MeatPos() )
    -- unlit canon-green glob (hunter plastic is lit -> near-black in shade)
    prop:SetMaterial( "models/ultrakill_prelude_test/minotaur/acid_glob" )
    prop:SetColor( Color( 110, 230, 70, 235 ) )
    prop:SetRenderMode( RENDERMODE_TRANSCOLOR )
    prop:Spawn()
    prop:SetParent( self )
    prop:Fire( "SetParentAttachment", "meat" )
    self.UKM_MeatProp = prop
  end

  function ENT:UKM_RemoveMeatProp()
    if IsValid( self.UKM_MeatProp ) then self.UKM_MeatProp:Remove() end
    self.UKM_MeatProp = nil
  end

  -- canon MeatSplash: the goop pool lands on the floor directly under the
  -- hand — decomp spawns it at (meatInHand.x, boss.y, meatInHand.z), i.e. in
  -- front of the minotaur, NEVER aimed at the player (workshop report
  -- 2026-07-10: "throws it at you directly instead of in front of it on the
  -- floor" — the old code lobbed it at the player's predicted position)
  function ENT:UKM_ThrowMeat()
    self:UKM_RemoveMeatProp()
    local hand = self:UKM_MeatPos()
    -- round 2 (2026-07-10): «дальность x2» — the pool lands twice as far in
    -- front (hand offset from the body doubled), still on the boss's floor
    local myPos = self:GetPos()
    local target = Vector(
      myPos.x + ( hand.x - myPos.x ) * 2,
      myPos.y + ( hand.y - myPos.y ) * 2,
      myPos.z )
    local down = util.TraceLine( {
      start = target + Vector( 0, 0, 16 ),
      endpos = target - Vector( 0, 0, 1024 ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if down.Hit then target = down.HitPos end

    local meat = ents.Create( UKMinotaur.CLASS.Meat )
    if not IsValid( meat ) then return end
    meat:SetPos( self:UKM_MeatPos() )
    meat:Spawn()
    meat:UKMM_Setup( self, target, 0.45 / self:UKM_AnimSpeed(),
      self:UKM_AcidOpts( "puddle" ) )
    self:EmitSound( UKMinotaur.SOUND.MeatSquish, 85, 110, 0.7 )
  end

  -- canon MeatHigh: crush the glob in the air -> big stationary cloud.
  -- The crush happens at hand height; the cloud must hug the ground, so the
  -- sphere center is clamped down to ~0.6 R above the floor.
  function ENT:UKM_ExplodeMeat()
    self:UKM_RemoveMeatProp()
    local pos = self:UKM_MeatPos()
    local down = util.TraceLine( {
      start = pos,
      endpos = pos - Vector( 0, 0, 40 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if down.Hit then
      pos = Vector( pos.x, pos.y,
        math.min( pos.z, down.HitPos.z + UKMinotaur.CLOUD_RADIUS * 0.6 ) )
    end
    local acid = ents.Create( UKMinotaur.CLASS.Acid )
    if IsValid( acid ) then
      acid:SetPos( pos )
      acid:Spawn()
      acid:UKMA_Setup( self:UKM_AcidOpts( "cloud" ) )
    end
    sound.Play( UKMinotaur.SOUND.MeatSquish, pos, 90, 80, 1 )
  end

  ------------------------------------------------------------------------------
  -- Hammer / hand melee (canon SwingCheck2 windows)
  ------------------------------------------------------------------------------

  -- point-to-segment distance for the animated staff capsule
  local function DistToSegment( p, a, b )
    local ab = b - a
    local lenSqr = ab:LengthSqr()
    if lenSqr <= 0 then return p:Distance( a ) end
    local t = math.Clamp( ( p - a ):Dot( ab ) / lenSqr, 0, 1 )
    return p:Distance( a + ab * t )
  end

  function ENT:UKM_ApplyMeleeDamage()
    if not self.UKM_Swinging then return end
    local hits = self.UKM_ActionHits or {}
    self.UKM_ActionHits = hits

    -- canon SwingCheck2 colliders live ON the staff: a capsule from the grip
    -- (Staff bone) to past the hammer head, following the actual animation —
    -- what the hammer visually sweeps through is what takes damage — plus the
    -- chest SwingCheckHelper box (4x6x8 m at (0,3,4)) as a sphere.
    local grip = self:UKM_GetAttachmentPos( "staffbase",
      self:WorldSpaceCenter() + self:GetForward() * ( 2 * UNIT ) )
    local tip = self:UKM_HammerPos()
    local dir = tip - grip
    if dir:LengthSqr() > 1 then
      dir:Normalize()
      tip = tip + dir * ( 1.5 * UNIT ) -- the hammer head is ~1.5 m of mass
    end
    local capsuleR = 1.6 * UNIT

    local chest = self:WorldSpaceCenter() + self:GetForward() * ( 3 * UNIT )
    local chestR = 4 * UNIT

    for _, ent in ipairs( ents.FindInSphere( self:WorldSpaceCenter(), 14 * UNIT ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKMinotaur_IsMinotaur then continue end

      local target = ent:WorldSpaceCenter()
      local hit = target:Distance( chest ) <= chestR
        or DistToSegment( target, grip, tip ) <= capsuleR
        or DistToSegment( ent:GetPos(), grip, tip ) <= capsuleR
      if not hit then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKMinotaur.ScaleAttackDamage( ent, UKMinotaur.SWING_DAMAGE ) )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 2000 + Vector( 0, 0, 300 ) )
      ent:TakeDamageInfo( dmg )

      -- canon TargetBeenHit: a landed hit closes the swing window
      self.UKM_Swinging = false
      break
    end
  end

  ------------------------------------------------------------------------------
  -- Ram (canon Stampede Charge): windup -> charge -> bonk/parried/swing-out
  ------------------------------------------------------------------------------

  function ENT:UKM_StartRam()
    self.UKM_AttackCount = 0
    self.AvailableAttacks = {"HammerTantrum", "HammerSmash", "MeatLow","MeatHigh"}
    self:UKM_StartAction( "RamWindup" )
  end

  function ENT:UKM_BeginRamRun()
    local spd = self:UKM_AnimSpeed()
    self.UKM_ActionName = nil
    self.UKM_ActionUntil = nil

    self.UKM_Ramming = true
    self.UKM_RamUntil = CurTime() + 4 / spd
    self.UKM_RamHitAt = nil
    self.UKM_BackSlammed = false
    self.UKM_ActionHits = {}
    self.CantMove = true
    self:SetMaxYawRate( 0 )
    -- canon RamStuff: ParryHelper + always-on 50 dmg RamSwingCheck
    self:SetParryable( true )
    -- canon parryable telegraph: the yellow flash on the lowered head.
    -- The base's CreateAlertFollow feeds EffectData:SetAttachment, which
    -- takes the numeric attachment ID — not the attachment name.
    local headAtt = self:LookupAttachment( "head" )
    if self.CreateAlertFollow and headAtt and headAtt > 0 then
      self:CreateAlertFollow( self, 1, 3.5, headAtt )
    elseif self.CreateAlert then
      self:CreateAlert( self:UKM_HeadPos(), 1, 3.5 )
    end

    local seq = self:LookupSequence( "RamRun" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end
  end

  function ENT:UKM_StopRam( outcome )
    self.UKM_Ramming = false
    self:SetParryable( false )
    self.loco:SetVelocity( vector_origin )

    if outcome == "bonk" then
      -- canon: the wall hurts the Minotaur and stuns it
      UltrakillBase.SoundScript( "Ultrakill_MinotaurRoarShort", self:GetPos() )
      UltrakillBase.SoundScript( "Ultrakill_RockBreak", self:GetPos() )
      self:ScreenShake( 250, 10, 1, 2000 )
      local dmg = DamageInfo()
      dmg:SetDamage( UKMinotaur.BONK_SELF_DAMAGE )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      self:TakeDamageInfo( dmg )
      self:UKM_StartAction( "RamBonk" )
    elseif outcome == "parried" then
      UltrakillBase.SoundScript( "Ultrakill_MinotaurRoarShort", self:GetPos() )
      self:UKM_StartAction( "RamParried" )
      -- canon: the parry knocks the Minotaur back
      self.UKM_Moving = true
      self.UKM_MovingSpeed = -20 * UNIT
      self.UKM_MovingUntil = CurTime() + 0.35
    else
      self:UKM_StartAction( "RamSwing" )
    end
  end

  function ENT:UKM_RamThink()
    local spd = self:UKM_AnimSpeed()

    if CurTime() >= self.UKM_RamUntil then
      self:UKM_StopRam( "swing" )
      return
    end

    -- canon: keeps charging in a circle if the player evades — limited steering
    local enemy = self:GetEnemy()
    if IsValid( enemy ) then
      self:SetMaxYawRate( 140 * spd )
      local dir = enemy:GetPos() - self:GetPos()
      dir.z = 0
      if dir:LengthSqr() > 1 then
        self:FaceTowards( self:GetPos() + dir )
      end
    end

    -- canon: ground slamming onto its back during the charge parries it
    -- (30 damage, knockback, the longest stun)
    if not self.UKM_BackSlammed then
      for _, ply in ipairs( player.GetAll() ) do
        if not IsValid( ply ) or not ply:Alive() then continue end
        if not ply:GetNW2Bool( "ULTRAKILL_GroundSlamActive", false ) then continue end
        if ply:GetVelocity().z > -100 then continue end
        local lp = self:WorldToLocal( ply:GetPos() )
        -- the saddle: behind the head, over the spine, coming down onto it
        if lp.x > -5 * UNIT and lp.x < 2.5 * UNIT
            and math.abs( lp.y ) < 2.5 * UNIT
            and lp.z > 3 * UNIT and lp.z < 10 * UNIT then
          self.UKM_BackSlammed = true
          local d = DamageInfo()
          d:SetDamage( 0 )
          d:SetDamageType( DMG_CLUB )
          d:SetAttacker( ply )
          d:SetInflictor( ply )
          -- OnParry: base flash/hitstop + our top-up to canon 30; the base
          -- only MUTATES the info (+5000 DMG_DIRECT), so land it ourselves
          self:OnParry( ply, d )
          self:TakeDamageInfo( d )
          -- bounce the slammer off the back
          ply:SetVelocity( Vector( 0, 0, 600 - ply:GetVelocity().z ) )
          return
        end
      end
    end

    local fwd = self:GetForward()
    local speed = UKMinotaur.RAM_SPEED * spd

    -- wall check ahead of the lowered head
    local headFront = self:GetPos() + Vector( 0, 0, 2.5 * UNIT )
    local tr = util.TraceHull( {
      start = headFront,
      endpos = headFront + fwd * ( 2.5 * UNIT ),
      mins = Vector( -1.5 * UNIT, -1.5 * UNIT, -1.5 * UNIT ),
      maxs = Vector( 1.5 * UNIT, 1.5 * UNIT, 1.5 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if tr.Hit and tr.HitNormal:Dot( fwd ) < -0.5 then
      self:UKM_StopRam( "bonk" )
      return
    end

    -- ledge check: never charge off a cliff
    local ahead = self:GetPos() + fwd * ( 3 * UNIT ) + Vector( 0, 0, 10 )
    local drop = util.TraceLine( {
      start = ahead,
      endpos = ahead - Vector( 0, 0, 10 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if not drop.Hit then
      self:UKM_StopRam( "swing" )
      return
    end

    -- drive the charge
    self.loco:SetDesiredSpeed( speed )
    self.loco:Approach( self:GetPos() + fwd * 200, 1 )
    self.loco:SetVelocity( Vector( fwd.x * speed, fwd.y * speed,
      self.loco:GetVelocity().z ) )

    -- canon RamSwingCheck: 50 dmg + knockback 100, once per charge
    local hits = self.UKM_ActionHits or {}
    self.UKM_ActionHits = hits
    local center = self:GetPos() + fwd * ( 3 * UNIT ) + Vector( 0, 0, 3 * UNIT )
    for _, ent in ipairs( ents.FindInSphere( center, 2.5 * UNIT ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKMinotaur_IsMinotaur then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKMinotaur.ScaleAttackDamage( ent, UKMinotaur.RAM_DAMAGE ) )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( fwd * 8000 )
      ent:TakeDamageInfo( dmg )
      -- canon Launch: knockBackForce 100
      if ent:IsPlayer() then
        ent:SetVelocity( fwd * 1200 + Vector( 0, 0, 400 ) )
      end
      self.UKM_RamHitAt = self.UKM_RamHitAt or CurTime()
    end

    -- after connecting, carry through briefly, then swing out of the charge
    if self.UKM_RamHitAt and CurTime() - self.UKM_RamHitAt > 0.4 / spd then
      self:UKM_StopRam( "swing" )
    end

    self:UKM_CycleFootsteps( "RamRun", { 0.016, 0.171, 0.676, 0.830 } )
  end

  ------------------------------------------------------------------------------
  -- Parry (UKBase standard: SetParryable/CheckParry/OnParry only)
  ------------------------------------------------------------------------------

  function ENT:OnParry( ply, dmg )
    -- base adds +5000 DMG_DIRECT + golden flash + hitstop
    BaseClass.OnParry( self, ply, dmg )
    -- canon: parry deals a flat 30 total. Overwrite the damageinfo (OnParry
    -- runs AFTER DamageMultiplier, so this lands flat) — a separate
    -- TakeDamageInfo here would recurse through the x10 multiplier and instakill
    dmg:SetDamage( UKMinotaur.PARRY_TOTAL_DAMAGE )
    if self.UKM_Ramming then
      self:UKM_StopRam( "parried" )
    end
  end

  ------------------------------------------------------------------------------
  -- Damage (canon locational multipliers + weak point gating)
  ------------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKM_Dead then return end

    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier

    hitgroup = hitgroup or HITGROUP_GENERIC
    -- canon: head 200%, limbs 150%; the fractured-head weak point is exposed
    -- only while attacking or stunned — otherwise the hand covers it (x1)
    if hitgroup == HITGROUP_HEAD then
      local exposed = self.UKM_Ramming or self.UKM_Stunned or self:UKM_InAction()
      dmg:ScaleDamage( exposed and 2.0 or 1.0 )
    elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
        or hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
      dmg:ScaleDamage( 1.5 )
    end

    if CurTime() >= ( self.UKM_NextHurtSound or 0 ) and dmg:GetDamage() > 0 then
      self.UKM_NextHurtSound = CurTime() + 0.6
      if math.random( 2 ) == 1 then
        UltrakillBase.SoundScript( "Ultrakill_MinotaurGrunt1", self:GetPos() )
      else
        UltrakillBase.SoundScript( "Ultrakill_MinotaurGrunt2", self:GetPos() )
      end
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end

  ------------------------------------------------------------------------------
  -- Attack selection (canon arena rules)
  ------------------------------------------------------------------------------
  function tablecontains(table, element) -- i wonder why this isn't a thing in lua
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

  function ENT:UKM_AttackCheck( enemy )
    if CurTime() < ( self.UKM_AttackCooldown or 0 ) then return end

    local mypos = self:GetPos()
    local tpos = enemy:GetPos()
    local dist = Vector( tpos.x - mypos.x, tpos.y - mypos.y, 0 ):Length()
    if dist > 20 * UNIT then return end

    -- canon: forced Stampede Charge after three other attacks
    if self.UKM_FirstAttackDone and self.UKM_AttackCount >= 3 then
      self:UKM_StartRam()
      return
    end

    -- canon: the Four-Swing Combo is the guaranteed arena opener
    -- (16 m > stoppingDistance 15 m, so it fires right where the nav halts)
    if not self.UKM_FirstAttackDone then
      if dist < 16 * UNIT then
        self.UKM_FirstAttackDone = true
        self.UKM_AttackCount = self.UKM_AttackCount + 1
        self:UKM_StartAction( "HammerTantrum" )
      end
      return
    end

    local pick
    if dist < 7 * UNIT then
      local rng = math.random(1,2)
      if rng == 1 then
        if tablecontains(self.AvailableAttacks, "HammerTantrum") then
          pick = "HammerTantrum"
        else
          if tablecontains(self.AvailableAttacks, "HammerSmash") then
          pick = "HammerSmash"
          else
          rng = math.random(1,2)
          if rng == 1 then
          pick = "MeatLow"
          else
          pick = "MeatHigh"
          end
          end
        end
      else
        if tablecontains(self.AvailableAttacks, "HammerSmash") then
          pick = "HammerSmash"
        else
          if tablecontains(self.AvailableAttacks, "HammerTantrum") then
          pick = "HammerTantrum"
          else
                    rng = math.random(1,2)
          if rng == 1 then
          pick = "MeatLow"
          else
          pick = "MeatHigh"
          end
          end
        end
      end
    else
      if tablecontains(self.AvailableAttacks, "MeatLow") and tablecontains(self.AvailableAttacks, "MeatHigh") then
      rng = math.random(1,2)
      if rng == 1 then
        pick = "MeatLow"
      else
        pick = "MeatHigh"
      end
    else
      pick = "HammerSmash"
    end
    end

    self.UKM_AttackCount = self.UKM_AttackCount + 1
    self:UKM_StartAction( pick )
  end

  ------------------------------------------------------------------------------
  -- Animation / movement
  ------------------------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    local spd = self:UKM_AnimSpeed()
    -- the base keeps driving animations through the whole OnDeath coroutine —
    -- without this gate it stomps the Death clip back to HurtIdle/Run
    if self.UKM_Dead then return "Death", 1 end
    if self.UKM_Ramming then return "RamRun", spd end
    if self.UKM_ActionName and self:UKM_InAction() then
      return ACTION[ self.UKM_ActionName ].seq, spd
    end
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco:GetVelocity():Length() > 2 * UNIT
    if moving then return "Run", spd end
    return "HurtIdle", spd
  end

  function ENT:OnUpdateSpeed()
    return 1000 * self:UKM_AnimSpeed()
  end

  function ENT:OnMeleeAttack( enemy )
    -- attacks are driven by UKM_AttackCheck in CustomThink
    return
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKM_Dead then return end
    local difficulty = UltrakillBase.GetDifficulty()
    local spd = self:UKM_AnimSpeed()
    
    local enemy = self:GetEnemy()

    if self.UKM_Ramming then
      self:UKM_RamThink()
      return
    end

    -- fire due events BEFORE the expiry check so a frame hitch past
    -- ActionUntil can't swallow pending events — and INDEPENDENT of the
    -- enemy being alive: the second (red super) smash explosion must still
    -- go off when the first explosion killed the target
    if self.UKM_ActionName then
      self:UKM_ProcessEvents()
    end

    if not IsValid( enemy ) and not self:UKM_InAction() then
      -- ambient exhale while wandering
      if CurTime() >= ( self.UKM_NextExhale or 0 ) then
        self.UKM_NextExhale = CurTime() + math.Rand( 6, 12 )
        self:EmitSound( UKMinotaur.SOUND.Exhale, 80, 100, 0.6 )
      end
      return
    end

    if self:UKM_InAction() then
      if self.UKM_Tracking and IsValid( enemy ) then
        self:SetMaxYawRate( 220 * spd )
        local dir = self:UKM_PredictEnemyPos( 4 ) - self:GetPos()
        dir.z = 0
        if dir:LengthSqr() > 1 then
          self:FaceTowards( self:GetPos() + dir )
        end
      else
        self:SetMaxYawRate( 0 )
      end

      if self.UKM_Moving and self.UKM_MovingUntil
          and CurTime() >= self.UKM_MovingUntil then
        self.UKM_Moving = false
        self.UKM_MovingUntil = nil
      end
      if self.UKM_Moving then
        local speed = self.UKM_MovingSpeed * spd
        local dir
        if speed < 0 then
          -- knockback burst: drive straight backward
          dir = -self:GetForward()
          speed = -speed
        else
          -- canon Four-Swing Combo approaches the PLAYER, not blindly forward
          dir = self:GetForward()
          if self.UKM_ActionName == "HammerTantrum" and IsValid( enemy ) then
            local to = self:UKM_PredictEnemyPos( 4 ) - self:GetPos()
            to.z = 0
            if to:LengthSqr() > ( 2 * UNIT ) ^ 2 then
              dir = to:GetNormalized()
            end
          end
        end
        self.loco:SetDesiredSpeed( speed )
        self.loco:Approach( self:GetPos() + dir * 200, 1 )
        self.loco:SetVelocity( Vector( dir.x * speed, dir.y * speed,
          self.loco:GetVelocity().z ) )
      end

      self:UKM_ApplyMeleeDamage()

    elseif self:IsOnGround() then
      self:UKM_AttackCheck( enemy )
    end

    self:UKM_CycleFootsteps( "Run", { 0.023, 0.167, 0.600, 0.743, 0.830 } )
  end

  ------------------------------------------------------------------------------
  -- Footsteps (canon Footstep clip events)
  ------------------------------------------------------------------------------

  function ENT:UKM_CycleFootsteps( seqName, marks )
    local cur = self:GetSequenceName( self:GetSequence() ) or ""
    if cur ~= seqName then
      self.UKM_LastStepCycle = nil
      return
    end
    if seqName == "Run" and not self.UKM_Ramming then
      if self:UKM_InAction() then return end
      if not ( self:IsMoving() or self:IsRunning() ) then return end
    end

    local cycle = self:GetCycle()
    local last = self.UKM_LastStepCycle or 0
    for _, mark in ipairs( marks ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) )
      if crossed then
        self:EmitSound( UKMinotaur.SOUND.Step, 90, math.random( 90, 110 ), 0.8 )
        break
      end
    end
    self.UKM_LastStepCycle = cycle
  end

  ------------------------------------------------------------------------------
  -- Death (canon: collapses, then reaches a hand up towards the sky)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKM_Dead = true
    self.UKM_Ramming = false
    self:SetParryable( false )
    self:UKM_EndAction()
    self:UKM_RemoveMeatProp()
    -- the standing-pose body boxes would be an invisible wall over the corpse
    self:UKM_SetCollidersSolid( false )
    self.loco:SetVelocity( vector_origin )

    self:Shake( 6, 8 ) -- shake

    UltrakillBase.SoundScript( "Ultrakill_MinotaurRoarShort", self:GetPos() )

    local seq = self:LookupSequence( "Death" )
    local dur = 2.4
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 0 ) -- the cycle is driven manually below
      dur = math.max( self:SequenceDuration( seq ), 0.1 )
    end

    -- Death clip plays out, then a Hideous-Mass-style finale (user spec
    -- 2026-07-07): escalating blood splatters through the collapse, then a
    -- big blood burst + Death_Explode + slow motion instead of a fade-out.
    -- HM lesson: the base's animation think runs through the whole OnDeath
    -- coroutine and stomps one-shot clips, so the clip is RE-PINNED every
    -- tick with a manually advanced cycle (playback rate 0).
    local deathStart = CurTime()
    local thudAt = CurTime() + 0.97       -- canon Death clip BodyImpact
    local thudDone = false
    local screamAt = CurTime() + 1.3
    local screamDone = false
    -- hold through the clip + the raised-hand beat at the end
    local lieUntil = CurTime() + 5.0
    local nextBlood = CurTime() + 0.3
    while IsValid( self ) and CurTime() < lieUntil do
      if seq and seq >= 0 then
        if self:GetSequence() ~= seq then
          self:ResetSequence( seq )
          self:ResetSequenceInfo()
        end
        self:SetPlaybackRate( 0 )
        self:SetCycle( math.min( ( CurTime() - deathStart ) / dur, 0.999 ) )
      end
      if not thudDone and CurTime() >= thudAt then
        thudDone = true
        UltrakillBase.SoundScript( "Ultrakill_PunchHeavy", self:GetPos() )
        self:ScreenShake( 150, 10, 1, 2000 )
      end
      -- scream
      if not screamDone and CurTime() >= screamAt then
        screamDone = true
        UltrakillBase.SoundScript( "Ultrakill_MinotaurDie", self:GetPos() )
      end
      if CurTime() >= nextBlood and UltrakillBase and UltrakillBase.CreateBlood then
        nextBlood = CurTime() + 0.3
        for _ = 1,3 do
        UltrakillBase.CreateBlood(
          self:WorldSpaceCenter() + VectorRand() * ( 3 * UNIT ), 24 )
        end
        UltrakillBase.SoundScript( "Ultrakill_Death", self:GetPos() )
      end
      self:YieldCoroutine()
    end

    if IsValid( self ) and UltrakillBase and UltrakillBase.CreateBlood then
      for _ = 1, 8 do
        UltrakillBase.CreateBlood(
          self:WorldSpaceCenter() + VectorRand() * ( 3 * UNIT ), 32 )
      end
      UltrakillBase.SoundScript( "Ultrakill_Death_Explode", self:GetPos() )
      if UltrakillBase.SlowMotion then UltrakillBase.SlowMotion( 2 ) end
    end
    if self.IsBoss then
        UltrakillBase.StopCurrentMusic( self )
    end
    -- no return value: the base removes the body right after the burst
  end
end

DrGBase.AddNextbot( ENT )
