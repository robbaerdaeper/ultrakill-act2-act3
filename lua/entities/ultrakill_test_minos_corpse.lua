AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end

-- The Corpse of King Minos — 2-4 "Court of the Corpse King" boss (Supreme
-- Husk), 1:1 scale (~100 m of torso above ground, the rest buried below like
-- in canon). Full port of MinosBoss.cs: zone-based hand slams (45 dmg,
-- partially parryable, "+ DOWN TO SIZE" + 35 self-damage on parry), black hole
-- projectile (99 hard damage), phase 2 at 50% HP (eyes shut -> eyeless skin,
-- two projectile-shooting parasites become the weak point), special death.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "The Corpse of King Minos"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKMinos.MODEL_CORPSE }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKMinos.HP_CORPSE
-- solid torso column; head/arms are hit via hitboxes inside surrounding bounds
ENT.CollisionBounds = Vector( 1100, 1100, 4000 )
ENT.SurroundingBounds = Vector( 8000, 8000, 4500 )
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
-- Canon clip events (minos_events.json, seconds @ speed 1.0).
-- side = which canon arm attacks (SwingStart/GotParried bookkeeping).
--------------------------------------------------------------------------------

local ACTION = {
  SlamRight = { seq = "SlamRight", dur = 4.206, side = "right", ev = {
    { 2.451, "swingStart" }, { 2.813, "swingEnd" }, { 4.128, "resetColliders" },
  } },
  SlamLeft = { seq = "SlamLeft", dur = 4.181, side = "left", ev = {
    { 2.092, "swingStart" }, { 2.752, "swingEnd" }, { 4.091, "resetColliders" },
  } },
  SlamMiddle = { seq = "SlamMiddle", dur = 3.996, side = "left", ev = {
    { 2.138, "swingStart" }, { 2.595, "swingEnd" }, { 3.765, "resetColliders" },
  } },
  SlamMiddleLow = { seq = "SlamMiddleLow", dur = 4.072, side = "right", ev = {
    { 2.149, "swingStart" }, { 2.733, "swingEnd" }, { 3.880, "resetColliders" },
  } },
  ParryRight = { seq = "ParryRight", dur = 2.752, ev = {
    { 1.371, "resetColliders" },
  } },
  ParryLeft = { seq = "ParryLeft", dur = 2.731, ev = {
    { 1.463, "resetColliders" },
  } },
  SpawnBlackHole = { seq = "SpawnBlackHole", dur = 3.597, ev = {
    { 1.347, "spawnBH" }, { 1.993, "launchBH" },
  } },
  PhaseParasite = { seq = "PhaseParasite", dur = 4.898, ev = {
    { 0.567, "shutEye0" }, { 1.627, "shutEye1" }, { 2.788, "resetColliders" },
    { 3.655, "spawnParasites" },
  } },
}

-- zone thresholds (su): the canon arena splits into right/middle/left trigger
-- volumes in front of the boss; hands rest ~±(3-4.3)k su to the sides.
local ZONE_SIDE = 800       -- |lateral| beyond this => that side's zone
local ZONE_MIDDLE = 3200    -- |lateral| below this => middle zone reachable

-- arm bones for the swing damage capsule
local ARM_BONES = {
  right = { "upperarm.r", "lowerarmtwist.r", "hand.r", "HandCenter" },
  left = { "upperarm.l", "lowerarmtwist.l", "hand.l", "HandCenter_(1)" },
}

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 500, 1600 ),
    distance = 5500,
    eyepos = false

  },

  {

    -- forward past the 1100 su torso half-width, or the camera sits inside
    offset = Vector( 1300, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMC_Dead or self.UKMC_InPhaseChange or self:UKMC_InAction() then return end
    if self.UKMC_Cooldown > 0 then return end

    -- same pacing bookkeeping as the AI attack tree (held key must respect it)
    local d = self:UKMC_GetDifficulty()
    if self.UKMC_Phase == 1 and d < 4 then
      self.UKMC_Cooldown = 2
    elseif self.UKMC_Phase == 2 or d >= 4 then
      if ( d == 4 and self.UKMC_PunchesSinceBreak < 2 ) or d == 5 then
        self.UKMC_PunchesSinceBreak = self.UKMC_PunchesSinceBreak + 1
        self.UKMC_Cooldown = 0
      else
        self.UKMC_PunchesSinceBreak = 0
        self.UKMC_Cooldown = 3
      end
    else
      self.UKMC_Cooldown = 0
    end

    local LockedOn = self:PossessionGetLockedOn()

    if Possessor:KeyDown( IN_FORWARD ) then
      self:EmitSound( UKMinos.SOUND.Hurt, 150, math.random( 95, 105 ), 0.75 )
      self.UKMC_AttackingSide = "right"
      self:UKMC_StartAction( "SlamRight" )
    elseif Possessor:KeyDown( IN_BACK ) then
      self:EmitSound( UKMinos.SOUND.Hurt, 150, math.random( 95, 105 ), 0.75 )
      self.UKMC_AttackingSide = "left"
      self:UKMC_StartAction( "SlamLeft" )
    elseif IsValid( LockedOn ) then
      -- canon zone pick (PickSlam dereferences the target, so lock required)
      self:UKMC_PickSlam( LockedOn )
    else
      self:EmitSound( UKMinos.SOUND.Hurt, 150, math.random( 95, 105 ), 0.75 )
      if math.Rand( 0, 1 ) > 0.5 then
        self.UKMC_AttackingSide = "left"
        self:UKMC_StartAction( "SlamMiddle" )
      else
        self.UKMC_AttackingSide = "right"
        self:UKMC_StartAction( "SlamMiddleLow" )
      end
    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKMC_Dead or self.UKMC_InPhaseChange or self:UKMC_InAction() then return end
    -- AI gates: one hole at a time + cooldown + no holes in phase 2 below Brutal
    if self.UKMC_BlackHole or self.UKMC_BHCooldown > 0 then return end
    if self.UKMC_Phase >= 2 and self:UKMC_GetDifficulty() <= 2 then return end

    self.UKMC_BHCooldown = 5
    self:UKMC_StartAction( "SpawnBlackHole" )

  end } }

}

if SERVER then

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKMinos.HP_CORPSE
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
    local sb = self.SurroundingBounds
    self:SetSurroundingBounds( Vector( -sb.x, -sb.y, -500 ), Vector( sb.x, sb.y, sb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKMC_Dead = false
    self.UKMC_Phase = 1
    self.UKMC_InPhaseChange = false
    self.UKMC_Cooldown = 3          -- canon initializer
    self.UKMC_BHCooldown = 10       -- canon initializer
    self.UKMC_LowMiddleChance = 0.5
    self.UKMC_PunchesSinceBreak = 0
    self.UKMC_AttackingSide = nil
    self.UKMC_Damaging = false
    self.UKMC_SwingHit = false
    self.UKMC_BlackHole = nil
    self.UKMC_Parasites = {}

    self.UKMC_ActionName = nil
    self.UKMC_ActionUntil = nil
    self.UKMC_ActionEvIndex = 1

    self:SetParryable( false )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
      phys:SetMass( 50000 )
    end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    if IsValid( self.UKMC_BlackHole ) then self.UKMC_BlackHole:Remove() end
    for _, p in ipairs( self.UKMC_Parasites or {} ) do
      if IsValid( p ) then p:Remove() end
    end
  end

  ------------------------------------------------------------------------------
  -- Difficulty (canon SetSpeed)
  ------------------------------------------------------------------------------

  function ENT:UKMC_GetDifficulty()
    return UKMinos.GetDifficulty( self )
  end

  function ENT:UKMC_AnimSpeed()
    local d = self:UKMC_GetDifficulty()
    if d == 0 then return 0.65 end
    if d == 1 then return 0.85 end
    if d == 4 then return 1.25 end
    if d == 5 then return 1.5 end
    return 1.0
  end

  ------------------------------------------------------------------------------
  -- Actions
  ------------------------------------------------------------------------------

  function ENT:UKMC_InAction()
    if self.UKMC_ActionUntil and self.UKMC_ActionUntil > CurTime() then return true end
    if self.UKMC_ActionName then self:UKMC_EndAction() end
    return false
  end

  function ENT:UKMC_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKMC_AnimSpeed()

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKMC_ActionName = name
    self.UKMC_ActionCfg = cfg
    self.UKMC_ActionStart = CurTime()
    self.UKMC_ActionUntil = CurTime() + cfg.dur / spd
    self.UKMC_ActionEvIndex = 1
  end

  function ENT:UKMC_EndAction()
    self.UKMC_ActionName = nil
    self.UKMC_ActionCfg = nil
    self.UKMC_ActionUntil = nil
    self.UKMC_Damaging = false
    self.UKMC_AttackingSide = nil
    self:SetParryable( false )
  end

  function ENT:UKMC_ProcessEvents()
    local cfg = self.UKMC_ActionCfg
    if not cfg then return end
    local t = ( CurTime() - ( self.UKMC_ActionStart or 0 ) ) * self:UKMC_AnimSpeed()
    while self.UKMC_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKMC_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKMC_ActionEvIndex = self.UKMC_ActionEvIndex + 1
      self:UKMC_FireEvent( ev[ 2 ] )
      if self.UKMC_ActionCfg ~= cfg then return end
    end
  end

  function ENT:UKMC_FireEvent( kind )
    if kind == "swingStart" then
      -- canon SwingStart: damage on + ParryableCheck(partial)
      self.UKMC_Damaging = true
      self.UKMC_SwingHit = false
      self:SetParryable( true )

    elseif kind == "swingEnd" then
      -- canon SwingEnd: damage off, punch explosion under the hand, big shake
      self.UKMC_Damaging = false
      self:SetParryable( false )
      util.ScreenShake( self:GetPos(), 2, 20, 0.8, 12000 )
      local handPos = self:UKMC_HandPos( self.UKMC_AttackingSide )
      if handPos then
        local tr = util.TraceLine( {
          start = handPos, endpos = handPos - Vector( 0, 0, 100 * UNIT ),
          mask = MASK_SOLID_BRUSHONLY, filter = self,
        } )
        local pos = tr.Hit and tr.HitPos or handPos
        self:UKMC_PunchExplosion( pos )
      end

    elseif kind == "resetColliders" then
      self.UKMC_Damaging = false
      self:SetParryable( false )

    elseif kind == "spawnBH" then
      if not self.UKMC_InPhaseChange then
        self:UKMC_SpawnBlackHole()
      end

    elseif kind == "launchBH" then
      if IsValid( self.UKMC_BlackHole ) then
        self.UKMC_BlackHole:Activate()
      end

    elseif kind == "shutEye0" then
      self:UKMC_EyeGore()

    elseif kind == "shutEye1" then
      self:UKMC_EyeGore()
      -- canon ShutEye(1): swap to the eyeless texture + kill the eye lights
      local bg = self:FindBodygroupByName( "eyes" )
      if bg and bg >= 0 then self:SetBodygroup( bg, 1 ) end
      self:SetSkin( 1 )

    elseif kind == "spawnParasites" then
      self:UKMC_SpawnParasites()
      self.UKMC_InPhaseChange = false
    end
  end

  ------------------------------------------------------------------------------
  -- Positions
  ------------------------------------------------------------------------------

  function ENT:UKMC_AttPos( name )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos, att.Ang end
    end
    return nil
  end

  function ENT:UKMC_HeadPos()
    local p = self:UKMC_AttPos( "head" )
    return p or ( self:GetPos() + Vector( 0, 0, 3800 ) )
  end

  function ENT:UKMC_HandPos( side )
    return self:UKMC_AttPos( side == "right" and "righthand" or "lefthand" )
  end

  ------------------------------------------------------------------------------
  -- Swing damage (canon SwingCheck2 capsules along the attacking arm)
  ------------------------------------------------------------------------------

  function ENT:UKMC_ApplySwingDamage()
    if not self.UKMC_Damaging or self.UKMC_SwingHit then return end
    local side = self.UKMC_AttackingSide
    if not side then return end

    -- sample points along the arm bone chain
    local points = {}
    for _, boneName in ipairs( ARM_BONES[ side ] or {} ) do
      local id = self:LookupBone( boneName )
      if id then
        local p = self:GetBonePosition( id )
        if p then table.insert( points, p ) end
      end
    end
    if #points < 2 then return end

    -- subdivide segments so the capsule has no gaps
    local samples = {}
    for i = 1, #points - 1 do
      local a, b = points[ i ], points[ i + 1 ]
      local segs = math.max( math.ceil( a:Distance( b ) / ( 8 * UNIT ) ), 1 )
      for s = 0, segs do
        table.insert( samples, LerpVector( s / segs, a, b ) )
      end
    end

    local radius = UKMinos.SWING_RADIUS_M * UNIT
    for _, pos in ipairs( samples ) do
      for _, ent in ipairs( ents.FindInSphere( pos, radius ) ) do
        if ent == self or not IsValid( ent ) then continue end
        if ent.UKMinos_IsMinos then continue end
        if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

        local amount
        if ent:IsPlayer() then
          amount = UKMinos.ScaleAttackDamage( ent, UKMinos.SWING_DAMAGE )
        else
          -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
          amount = ent.IsUltrakillNextbot
            and UKNpcDmg.PreMult( ent, self, UKMinos.SWING_DAMAGE * 100 )
            or UKMinos.SWING_DAMAGE
        end
        local dmg = DamageInfo()
        dmg:SetDamage( amount )
        dmg:SetDamageType( DMG_CLUB )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        dmg:SetDamageForce( Vector( 0, 0, -1000 ) )
        ent:TakeDamageInfo( dmg )

        -- canon TargetBeenHit: one landed hit closes the swing
        self.UKMC_SwingHit = true
        self.UKMC_Damaging = false
        self:SetParryable( false )
        return
      end
    end
  end

  -- canon punchExplosion ("Explosion Wave Enemy"): harmless push wave + visuals
  function ENT:UKMC_PunchExplosion( pos )
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetAngles( self:GetAngles() )
    fx:SetRadius( 600 )
    util.Effect( "ultrakill_test_softexplosion", fx, true, true )
    sound.Play( UKMinos.SOUND.PunchExplosion, pos, 140, math.random( 90, 110 ), 1 )

    -- canon Explosion: harmless=1 damage=0 — pure knockback (maxSize 80 m)
    local R = 80 * UNIT
    for _, ply in ipairs( player.GetAll() ) do
      if not ply:Alive() then continue end
      local diff = ply:WorldSpaceCenter() - pos
      local dist = diff:Length()
      if dist > R then continue end
      local dir = dist > 1 and ( diff / dist ) or Vector( 0, 0, 1 )
      local falloff = 1 - dist / R
      ply:SetVelocity( dir * 600 * falloff + Vector( 0, 0, 300 * falloff ) )
    end
  end

  ------------------------------------------------------------------------------
  -- Black hole (canon BlackHole()/SpawnBlackHole/LaunchBlackHole)
  ------------------------------------------------------------------------------

  function ENT:UKMC_SpawnBlackHole()
    local pos = self:UKMC_AttPos( "blackhole" ) or ( self:UKMC_HeadPos() + self:GetForward() * 2000 )
    local bh = ents.Create( UKMinos.CLASS.BlackHole )
    if not IsValid( bh ) then return end
    bh:SetPos( pos )
    bh:SetOwner( self )
    bh.UKMinos_Owner = self
    bh:Spawn()

    local d = self:UKMC_GetDifficulty()
    local speed = UKMinos.BLACKHOLE_SPEED
    if d == 4 then speed = speed * 1.5 elseif d == 5 then speed = speed * 2 end
    bh.UKBH_Speed = speed * UNIT
    bh:FadeIn()

    self.UKMC_BlackHole = bh
  end

  ------------------------------------------------------------------------------
  -- Phase 2 (canon PhaseChange + SpawnParasites)
  ------------------------------------------------------------------------------

  function ENT:UKMC_PhaseChange()
    self.UKMC_Phase = 2
    self.UKMC_InPhaseChange = true
    local d = self:UKMC_GetDifficulty()
    self.UKMC_Cooldown = ( d >= 4 ) and 1 or 4
    self:EmitSound( UKMinos.SOUND.BigHurt, 150, 100, 0.75 )

    -- interrupt whatever is happening
    self.UKMC_Damaging = false
    self:SetParryable( false )
    self:UKMC_StartAction( "PhaseParasite" )

    -- canon: the active black hole is destroyed (kept on Violent+ unless fading)
    local bh = self.UKMC_BlackHole
    if IsValid( bh ) and ( d <= 2 or bh.UKBH_FadingIn ) then
      bh:Explode()
      self.UKMC_BlackHole = nil
    end
  end

  function ENT:UKMC_EyeGore()
    local head = self:UKMC_HeadPos()
    for i = 1, 3 do
      local fx = EffectData()
      fx:SetOrigin( head + VectorRand() * 300 )
      fx:SetMagnitude( 4 )
      fx:SetScale( 4 )
      fx:SetFlags( 3 )
      util.Effect( "bloodspray", fx, true, true )
    end
    self:EmitSound( UKMinos.SOUND.Hurt, 140, math.random( 90, 100 ), 0.75 )
  end

  -- parasite mount offsets in head-attachment local space (fwd/left/up, su):
  -- remapped from the canon eye-socket positions in Unity Head space
  -- (Cube (3) x=4.32 y=8.99 z=7.71; Cube (2) x=-2.15 y=8.42 z=8.14; x $scale 200)
  local PARASITE_MOUNTS = {
    Vector( 1542, -864, 1798 ),
    Vector( 1628, 430, 1684 ),
  }

  function ENT:UKMC_SpawnParasites()
    util.ScreenShake( self:GetPos(), 2, 20, 1.0, 12000 )
    local headPos, headAng = self:UKMC_AttPos( "head" )
    if not headPos then headPos, headAng = self:UKMC_HeadPos(), self:GetAngles() end

    self.UKMC_Parasites = {}
    for i, mount in ipairs( PARASITE_MOUNTS ) do
      local p = ents.Create( UKMinos.CLASS.Parasite )
      if not IsValid( p ) then continue end
      p.UKPar_Corpse = self
      p.UKPar_MountLocal = mount
      p:SetPos( LocalToWorld( mount, angle_zero, headPos, headAng or angle_zero ) )
      p:Spawn()
      table.insert( self.UKMC_Parasites, p )

      -- eye gore burst
      for g = 1, 3 do
        local fx = EffectData()
        fx:SetOrigin( p:GetPos() + VectorRand() * 100 )
        fx:SetMagnitude( 4 )
        fx:SetScale( 4 )
        fx:SetFlags( 3 )
        util.Effect( "bloodspray", fx, true, true )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Parry (canon GotParried: 35 self-damage spread over the arm, ParryL/R anim,
  -- "+ DOWN TO SIZE")
  ------------------------------------------------------------------------------

  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    if self.UKMC_Dead then return end

    local side = self.UKMC_AttackingSide
    self:EmitSound( UKMinos.SOUND.BigHurt, 150, 100, 0.75 )
    self.UKMC_PunchesSinceBreak = 0
    self.UKMC_Damaging = false
    self:SetParryable( false )

    -- canon: parry deals a flat 35 to the boss (not the parry-boosted hit)
    dmg:SetDamage( UKMinos.PARRY_SELF_DAMAGE )

    self:UKMC_StartAction( side == "right" and "ParryRight" or "ParryLeft" )
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKMC_Dead then return end
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Zones + attack selection (canon Update)
  ------------------------------------------------------------------------------

  function ENT:UKMC_PickSlam( enemy )
    local rel = enemy:GetPos() - self:GetPos()
    local lateral = rel:Dot( self:GetRight() )
    local onRight = lateral > ZONE_SIDE
    local onLeft = lateral < -ZONE_SIDE
    local onMiddle = math.abs( lateral ) < ZONE_MIDDLE

    local function middle()
      -- canon SlamMiddle: alternating high/low with adaptive chance
      if math.Rand( 0, 1 ) > self.UKMC_LowMiddleChance then
        if self.UKMC_LowMiddleChance < 0.5 then self.UKMC_LowMiddleChance = 0.5 end
        self.UKMC_LowMiddleChance = self.UKMC_LowMiddleChance + 0.25
        self.UKMC_AttackingSide = "left"
        self:UKMC_StartAction( "SlamMiddle" )
      else
        if self.UKMC_LowMiddleChance > 0.5 then self.UKMC_LowMiddleChance = 0.5 end
        self.UKMC_LowMiddleChance = self.UKMC_LowMiddleChance - 0.25
        self.UKMC_AttackingSide = "right"
        self:UKMC_StartAction( "SlamMiddleLow" )
      end
    end

    self:EmitSound( UKMinos.SOUND.Hurt, 150, math.random( 95, 105 ), 0.75 )

    if onRight then
      if onMiddle and math.Rand( 0, 1 ) > 0.5 then middle()
      else
        self.UKMC_AttackingSide = "right"
        self:UKMC_StartAction( "SlamRight" )
      end
    elseif onLeft then
      if onMiddle and math.Rand( 0, 1 ) > 0.5 then middle()
      else
        self.UKMC_AttackingSide = "left"
        self:UKMC_StartAction( "SlamLeft" )
      end
    else
      middle()
    end
  end

  ------------------------------------------------------------------------------
  -- Think (canon Update)
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT or self.UKMC_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = math.min( now - ( self.UKMC_LastThink or now ), 0.25 )
    self.UKMC_LastThink = now

    if self.UKMC_ActionName then self:UKMC_ProcessEvents() end
    self:UKMC_ApplySwingDamage()

    local d = self:UKMC_GetDifficulty()

    if not IsValid( self.UKMC_BlackHole ) then self.UKMC_BlackHole = nil end

    -- canon: BH cooldown ticks only without an active hole and in phase 1
    -- (or past phase 1 on Brutal+)
    if not self.UKMC_BlackHole and self.UKMC_BHCooldown > 0
        and ( self.UKMC_Phase < 2 or d > 2 ) then
      self.UKMC_BHCooldown = math.max( self.UKMC_BHCooldown - dt, 0 )
    end

    -- phase change at 50% HP
    if self:Health() < self:GetMaxHealth() / 2 and self.UKMC_Phase < 2
        and not self.UKMC_InPhaseChange then
      self:UKMC_PhaseChange()
      return
    end

    local enemy = self:GetEnemy()

    -- slow rotation toward the target (convar; canon is fully static)
    if IsValid( enemy ) and not self:UKMC_InAction() then
      local rate = GetConVar( "ukminos_turnrate" ):GetFloat()
      if rate > 0 then
        local toYaw = ( enemy:GetPos() - self:GetPos() ):Angle().yaw
        local myAng = self:GetAngles()
        local delta = math.AngleDifference( toYaw, myAng.yaw )
        local step = math.Clamp( delta, -rate * dt, rate * dt )
        self:SetAngles( Angle( 0, myAng.yaw + step, 0 ) )
      end
    end

    -- possessed: the binds drive the attacks; keep their pacing timer ticking
    -- (a frozen cooldown would lock the binds forever)
    if self:IsPossessed() then
      if self.UKMC_Cooldown > 0 then
        self.UKMC_Cooldown = math.max( self.UKMC_Cooldown - dt * self:UKMC_AnimSpeed(), 0 )
      end
      return
    end

    if not IsValid( enemy ) or self:UKMC_InAction() or self.UKMC_InPhaseChange then
      return
    end

    -- canon attack tree
    if not self.UKMC_BlackHole and self.UKMC_BHCooldown == 0 and d >= 2
        and ( self.UKMC_Phase < 2 or d > 2 ) then
      self.UKMC_BHCooldown = 5
      self:UKMC_StartAction( "SpawnBlackHole" )
      return
    end

    if self.UKMC_Cooldown > 0 then
      self.UKMC_Cooldown = math.max( self.UKMC_Cooldown - dt * self:UKMC_AnimSpeed(), 0 )
      return
    end

    -- cooldown after this slam (canon phase/difficulty table)
    if self.UKMC_Phase == 1 and d < 4 then
      self.UKMC_Cooldown = 2
    elseif self.UKMC_Phase == 2 or d >= 4 then
      if ( d == 4 and self.UKMC_PunchesSinceBreak < 2 ) or d == 5 then
        self.UKMC_PunchesSinceBreak = self.UKMC_PunchesSinceBreak + 1
        self.UKMC_Cooldown = 0
      else
        self.UKMC_PunchesSinceBreak = 0
        self.UKMC_Cooldown = 3
      end
    else
      self.UKMC_Cooldown = 0
    end

    self:UKMC_PickSlam( enemy )
  end

  function ENT:OnUpdateAnimation()
    local spd = self:UKMC_AnimSpeed()
    if self.UKMC_ActionName and self:UKMC_InAction() then
      return self.UKMC_ActionCfg.seq, spd
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
  -- Death (canon SpecialDeath -> Death anim: Impact@2.637, DeathOver@3.672)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKMC_Dead = true
    self:UKMC_EndAction()

    if IsValid( self.UKMC_BlackHole ) then
      self.UKMC_BlackHole:Explode()
      self.UKMC_BlackHole = nil
    end
    for _, p in ipairs( self.UKMC_Parasites or {} ) do
      if IsValid( p ) then p:Remove() end
    end
    self.UKMC_Parasites = {}

    self:EmitSound( UKMinos.SOUND.BigHurt, 150, 75, 0.75 )
    util.ScreenShake( self:GetPos(), 1, 20, 1.5, 12000 )

    local seq = self:LookupSequence( "Death" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end

    -- Impact @2.637: the head crashes down
    local impactAt = CurTime() + 2.637
    while IsValid( self ) and CurTime() < impactAt do
      self:YieldCoroutine()
    end
    if IsValid( self ) then
      local head = self:UKMC_HeadPos()
      local fx = EffectData()
      fx:SetOrigin( head )
      fx:SetAngles( self:GetAngles() )
      fx:SetRadius( 900 )
      util.Effect( "ultrakill_test_softexplosion", fx, true, true )
      sound.Play( UKMinos.SOUND.PunchExplosion, head, 150, 80, 1 )
      util.ScreenShake( self:GetPos(), 3, 20, 1.2, 16000 )
    end

    -- DeathOver @3.672, then fade the colossus out
    local overAt = CurTime() + ( 3.672 - 2.637 )
    while IsValid( self ) and CurTime() < overAt do
      self:YieldCoroutine()
    end
    if IsValid( self ) then
      self:SetRenderMode( RENDERMODE_TRANSCOLOR )
      local fadeUntil = CurTime() + 3
      while IsValid( self ) and CurTime() < fadeUntil do
        local a = math.Clamp( ( fadeUntil - CurTime() ) / 3, 0, 1 )
        self:SetColor( Color( 255, 255, 255, a * 255 ) )
        self:YieldCoroutine()
      end
    end

    return dmg
  end

end

DrGBase.AddNextbot( ENT )
