AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKLeviathan then include( "autorun/ultrakill_test_leviathan_shared.lua" ) end
if SERVER and not UKLeviathanStrikes then
  include( "autorun/ultrakill_test_leviathan_strikes.lua" )
end

-- Leviathan — 5-4 "LEVIATHAN" boss (Supreme Demon). Full LeviathanController +
-- LeviathanHead port: the head teleports between canon spots around the spawn
-- anchor ("virtual water" = spawn plane), Bite (35, parryable, "+ DOWN TO
-- SIZE", 20 self-damage on parry), 80-orb spiral Hell Orb barrage (every 10th
-- aimed, every 20th explosive on Violent+), forced Beam sweeps, tail
-- sub-phases (separate entity), heart weak point (x3), phase 2 at 50% HP
-- (boat gone -> rotating Ouroboros ring, head center-anchored, predictive
-- aim), special segment-chain gib death + player FullHeal.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Leviathan"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKLeviathan.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKLeviathan.HP
ENT.CollisionBounds = Vector( 350, 350, 3000 )   -- rescaled in Initialize
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy"
ENT.BloodColor = BLOOD_COLOR_RED

-- Sisyphus Prime scheme: base auto-flips to phase 2 at 50% HP (OnPhaseChange),
-- boss bar renders as two stacked 120-HP layers (AddBoss splits = 2)
ENT.UltrakillBase_PhaseMax = 2

ENT.UKLev_IsLeviathan = true

-- stationary (minos/idol pattern): all movement is scripted teleports
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

local UNIT = UKLeviathan.UNIT
local SND = UKLeviathan.SOUND

--------------------------------------------------------------------------------
-- Canon clip events (leviathan_events.json, seconds @ speed 1.0)
--------------------------------------------------------------------------------

local ACTION = {
  AscendLong = { seq = "AscendLong", dur = 4.00, ev = {
    { 2.12, "roar" }, { 3.74, "stopAction" },
  } },
  Ascend = { seq = "Ascend", dur = 2.00, ev = {
    { 1.66, "stopAction" },
  } },
  Descend = { seq = "Descend", dur = 3.00, ev = {
    { 1.80, "bigSplash" }, { 2.93, "descendEnd" },
  } },
  -- biteDamageStop extended 1.67 -> 1.80: the canon window closed while the
  -- FORWARD half of the visible ground sweep (frames 46-54, where players
  -- actually stand) was still passing through them
  Bite = { seq = "Bite", dur = 5.33, ev = {
    { 0.89, "biteLock" }, { 1.38, "biteDamageStart" }, { 1.80, "biteDamageStop" },
    { 4.57, "biteReset" }, { 5.17, "stopAction" },
  } },
  BiteParried = { seq = "BiteParried", dur = 3.33, ev = {
    { 3.13, "stopAction" },
  } },
  BurstStart = { seq = "BurstStart", dur = 1.17, ev = {
    { 1.13, "burstBegin" },
  } },
  BurstLoop = { seq = "BurstLoop", dur = 3600, ev = {} },  -- ends when the burst runs dry
  BurstStop = { seq = "BurstStop", dur = 2.17, ev = {
    { 1.62, "stopAction" },
  } },
  BeamStart = { seq = "BeamStart", dur = 1.00, ev = {
    { 0.43, "beamCharge" }, { 0.96, "beamFire" },
  } },
  BeamLoop = { seq = "BeamLoop", dur = 3600, ev = {} },    -- ends when beamTime runs out
  BeamEnd = { seq = "BeamEnd", dur = 2.00, ev = {
    { 1.83, "stopAction" },
  } },
}

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    -- sized for the colossal serpent (~90 canon m tall); DrGBase multiplies
    -- offset/distance by the model scale, so ukleviathan_scale shrinks them too
    offset = Vector( 0, 250, 750 ),
    distance = 9500,
    eyepos = false

  },

  {

    -- the origin sits at the waterline, so "first person" rides the head bone
    offset = Vector( 550, 0, 120 ),
    distance = 0,
    bone = "Bone001"

  }

}


ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKLev_Dead or self.UKLev_State ~= "active" or self:UKLev_InAction() or self.UKLev_Cooldown > 0 then return end

    self:UKLev_Bite()

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKLev_Dead or self.UKLev_State ~= "active" or self:UKLev_InAction() or self.UKLev_Cooldown > 0 then return end

    self:UKLev_ProjectileBurst()

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKLev_Dead or self.UKLev_State ~= "active" or self:UKLev_InAction() or self.UKLev_Cooldown > 0 then return end

    self:UKLev_BeamAttack()

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- dive: submerge, run the tail sub-phase, re-ascend at another canon spot
    if self.UKLev_Dead or self.UKLev_State ~= "active" or self:UKLev_InAction() or self.UKLev_Cooldown > 0 then return end

    self:UKLev_Descend()

  end } }

}

if SERVER then

  ------------------------------------------------------------------------------
  -- Init
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local scale = UKLeviathan.GetScale()
    self.UKLev_Scale = scale
    self:SetModelScale( scale )
    self.UKLev_U = UNIT * scale                 -- su per canon metre

    local r, h = 12 * self.UKLev_U, 90 * self.UKLev_U
    self:SetCollisionBounds( Vector( -r, -r, 0 ), Vector( r, r, h ) )
    local sr = 220 * self.UKLev_U
    self:SetSurroundingBounds( Vector( -sr, -sr, -sr ), Vector( sr, sr, h + 20 * self.UKLev_U ) )

    self:SetMaxHealth( UKLeviathan.HP )
    self:SetHealth( UKLeviathan.HP )

    -- "virtual water": the spawn plane. The spawnmenu points the entity AT the
    -- player; flip the anchor 180 so the canon spots extend away from them and
    -- the serpent's -forward face ends up looking back at the spawn point.
    self.UKLev_Anchor = self:GetPos()
    self.UKLev_AnchorAng = Angle( 0, self:GetAngles().yaw + 180, 0 )
    self.UKLev_WaterZ = self:GetPos().z

    -- controller state (LeviathanController)
    self.UKLev_Dead = false
    self.UKLev_TailAddPhase = false
    self.UKLev_ReadyForSecond = false
    self.UKLev_SecondPhase = false
    self.UKLev_StopTail = false
    self.UKLev_InSubPhase = false
    self.UKLev_TailAttacking = false
    self.UKLev_TailTimer = 0
    self.UKLev_SubAttacksLeft = 0

    -- head state (LeviathanHead)
    self.UKLev_State = "intro"
    self.UKLev_Cooldown = 0
    self.UKLev_RecentAttacks = 0
    self.UKLev_PreviousAttack = -1
    self.UKLev_ForceBeam = false
    self.UKLev_PrevSpot = 0
    self.UKLev_BiteDamaging = false
    self.UKLev_BiteHit = false
    self.UKLev_LockYaw = nil

    -- burst state
    self.UKLev_BurstLeft = 0
    self.UKLev_BurstMax = 80
    self.UKLev_BurstNextShot = 0

    -- beam state
    self.UKLev_BeamTime = 0

    self.UKLev_ActionName = nil
    self.UKLev_ActionUntil = nil
    self.UKLev_ActionEvIndex = 1

    self:SetParryable( false )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
      phys:SetMass( 50000 )
    end

    if not UKLeviathanStrikes then
      ErrorNoHalt( "[UKLeviathan] strikes table missing — bite/tail damage disabled!\n" )
    end

    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, "LEVIATHAN", 2 )
    end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )

    -- intro rise at the first canon spot
    timer.Simple( 0, function()
      if not IsValid( self ) then return end
      self.UKLev_Anchor = self:GetPos()
      self.UKLev_AnchorAng = Angle( 0, self:GetAngles().yaw + 180, 0 )
      self.UKLev_WaterZ = self:GetPos().z
      self:UKLev_CreateColliders()
      self:UKLev_PlaceAtSpot( 1 )
      self:UKLev_StartAction( "AscendLong" )
      self:EmitSound( SND.SplashBig, 120, 100, 1 )
      self.UKLev_IdleLoop = CreateSound( self, SND.RoarLoop )
      self.UKLev_IdleLoop:PlayEx( 0.4, 100 )

      -- spawn the tail companion
      local tail = ents.Create( UKLeviathan.CLASS.Tail )
      if IsValid( tail ) then
        tail.UKLev_Head = self
        tail:SetPos( self.UKLev_Anchor )
        tail:Spawn()
        tail:SetNoDraw( true )
        self.UKLev_Tail = tail
      end
    end )
  end

  function ENT:OnRemove()
    if self.UKLev_IdleLoop then self.UKLev_IdleLoop:Stop() end
    if self.UKLev_BeamSound then self.UKLev_BeamSound:Stop() end
    if IsValid( self.UKLev_Tail ) then self.UKLev_Tail:Remove() end
    if IsValid( self.UKLev_Body ) then self.UKLev_Body:Remove() end
  end

  ------------------------------------------------------------------------------
  -- Positions / orientation.
  -- Canon rotation convention everywhere: LookRotation(pos - target), i.e. the
  -- entity's +forward points AWAY from the target and the serpent's face looks
  -- back at it. Helpers keep that in one place.
  ------------------------------------------------------------------------------

  function ENT:UKLev_FaceDir()
    return -self:GetForward()
  end

  function ENT:UKLev_FaceAngles( targetPos )
    local d = self:GetPos() - targetPos
    d.z = 0
    if d:LengthSqr() < 1 then d = Vector( 1, 0, 0 ) end
    return d:Angle()
  end

  -- canon local (x, z) around the anchor -> world (anchor frame)
  function ENT:UKLev_SpotPos( x, z, y )
    local a = self.UKLev_AnchorAng or angle_zero
    local u = self.UKLev_U
    return self.UKLev_Anchor
      + a:Forward() * ( z * u )
      + a:Right() * ( x * u )
      + Vector( 0, 0, ( y or 0 ) * u )
  end

  function ENT:UKLev_PlaceAtSpot( idx )
    local spot = UKLeviathan.HEAD_SPOTS[ idx ]
    local pos = self:UKLev_SpotPos( spot[ 1 ], spot[ 2 ] )
    self.UKLev_PrevSpot = idx
    self:SetPos( pos )
    self:SetAngles( self:UKLev_FaceAngles( self.UKLev_Anchor ) )
    self:UKLev_UpdateColliders()
  end

  -- canon ChangePosition: random spot, not the previous one, keep 10 m off the tail
  function ENT:UKLev_ChangePosition()
    local n = #UKLeviathan.HEAD_SPOTS
    local idx = math.random( n )
    if idx == self.UKLev_PrevSpot then idx = idx % n + 1 end
    local tail = self.UKLev_Tail
    if IsValid( tail ) and not tail:GetNoDraw() then
      local spot = UKLeviathan.HEAD_SPOTS[ idx ]
      local pos = self:UKLev_SpotPos( spot[ 1 ], spot[ 2 ] )
      if pos:Distance( tail:GetPos() ) < 10 * self.UKLev_U then idx = idx % n + 1 end
    end
    self:UKLev_PlaceAtSpot( idx )
  end

  function ENT:UKLev_CenterPosition()
    local c = UKLeviathan.HEAD_CENTER
    self:SetPos( self:UKLev_SpotPos( c[ 1 ], c[ 2 ] ) )
    local enemy = self:GetEnemy()
    if IsValid( enemy ) then
      self:SetAngles( self:UKLev_FaceAngles( enemy:GetPos() ) )
    end
    self:UKLev_UpdateColliders()
  end

  function ENT:UKLev_AttPos( name )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos, att.Ang end
    end
    return nil
  end

  function ENT:UKLev_HeadPos()
    local p = self:UKLev_AttPos( "head" )
    return p or ( self:GetPos() + Vector( 0, 0, 84 * self.UKLev_U ) )
  end

  ------------------------------------------------------------------------------
  -- Colliders: GMod nextbots never physically block players, so the VISIBLE
  -- body arc gets frozen VPhysics boxes (gutterman-shield idiom). Layout comes
  -- from the compiled skeleton (UKLeviathan.BODY_ARC): the neck rises 4-48 m
  -- BEHIND the origin and a second body hump arcs 134-275 m behind it — the r2
  -- origin-centered column stood in empty water, hence "still no collision".
  -- Boxes rotate with the entity yaw and go non-solid while it is underwater.
  ------------------------------------------------------------------------------

  -- split arc AABBs so no PhysicsInitBox dimension exceeds ~1000 su
  local function SplitSpans( a0, a1, u, maxsu )
    local parts = math.max( 1, math.ceil( ( a1 - a0 ) * u / maxsu ) )
    local out = {}
    for i = 0, parts - 1 do
      out[ #out + 1 ] = {
        a0 + ( a1 - a0 ) * i / parts,
        a0 + ( a1 - a0 ) * ( i + 1 ) / parts,
      }
    end
    return out
  end

  function ENT:UKLev_CreateColliders()
    local u = self.UKLev_U
    local hy = UKLeviathan.BODY_ARC_HALFY
    self.UKLev_Colliders = {}
    for _, b in ipairs( UKLeviathan.BODY_ARC ) do
      for _, xs in ipairs( SplitSpans( b.x0, b.x1, u, 1000 ) ) do
        for _, zs in ipairs( SplitSpans( b.z0, b.z1, u, 1000 ) ) do
          local col = ents.Create( UKLeviathan.CLASS.Collider )
          if not IsValid( col ) then continue end
          col.UKLev_Mins = Vector( xs[ 1 ] * u, -hy * u, zs[ 1 ] * u )
          col.UKLev_Maxs = Vector( xs[ 2 ] * u, hy * u, zs[ 2 ] * u )
          col.UKLev_ForwardTo = self
          col:SetPos( self:GetPos() )
          col:SetAngles( Angle( 0, self:GetAngles().yaw, 0 ) )
          col:Spawn()
          self:DeleteOnRemove( col )
          table.insert( self.UKLev_Colliders, col )
        end
      end
    end
  end

  function ENT:UKLev_UpdateColliders()
    if not self.UKLev_Colliders then return end
    local pos = self:GetPos()
    local ang = Angle( 0, self:GetAngles().yaw, 0 )
    for _, col in ipairs( self.UKLev_Colliders ) do
      if IsValid( col ) then
        col:SetPos( pos )
        col:SetAngles( ang )
      end
    end
  end

  function ENT:UKLev_SetCollidersSolid( solid )
    if not self.UKLev_Colliders then return end
    for _, col in ipairs( self.UKLev_Colliders ) do
      if IsValid( col ) then col:SetNotSolid( not solid ) end
    end
  end

  function ENT:UKLev_MuzzlePos()
    local p = self:UKLev_AttPos( "muzzle" )
    return p or ( self:UKLev_HeadPos() + self:UKLev_FaceDir() * 10 * self.UKLev_U )
  end

  ------------------------------------------------------------------------------
  -- Difficulty
  ------------------------------------------------------------------------------

  function ENT:UKLev_GetDifficulty()
    return UKLeviathan.GetDifficulty( self )
  end

  function ENT:UKLev_AnimSpeed()
    return UKLeviathan.HeadAnimSpeed( self:UKLev_GetDifficulty() )
  end

  ------------------------------------------------------------------------------
  -- Action runner (minos pattern)
  ------------------------------------------------------------------------------

  function ENT:UKLev_InAction()
    if self.UKLev_ActionUntil and self.UKLev_ActionUntil > CurTime() then return true end
    if self.UKLev_ActionName then self:UKLev_EndAction() end
    return false
  end

  function ENT:UKLev_StartAction( name )
    local cfg = ACTION[ name ]
    if not cfg then return end
    local spd = self:UKLev_AnimSpeed()

    local seq = self:LookupSequence( cfg.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end

    self.UKLev_ActionName = name
    self.UKLev_ActionCfg = cfg
    self.UKLev_ActionStart = CurTime()
    self.UKLev_ActionUntil = CurTime() + cfg.dur / spd
    self.UKLev_ActionEvIndex = 1
  end

  function ENT:UKLev_EndAction()
    self.UKLev_ActionName = nil
    self.UKLev_ActionCfg = nil
    self.UKLev_ActionUntil = nil
    self.UKLev_BiteDamaging = false
    self.UKLev_LockYaw = nil
    self:SetParryable( false )
  end

  function ENT:UKLev_ProcessEvents()
    local cfg = self.UKLev_ActionCfg
    if not cfg then return end
    local t = ( CurTime() - ( self.UKLev_ActionStart or 0 ) ) * self:UKLev_AnimSpeed()
    while self.UKLev_ActionEvIndex <= #cfg.ev do
      local ev = cfg.ev[ self.UKLev_ActionEvIndex ]
      if t < ev[ 1 ] then break end
      self.UKLev_ActionEvIndex = self.UKLev_ActionEvIndex + 1
      self:UKLev_FireEvent( ev[ 2 ] )
      if self.UKLev_ActionCfg ~= cfg then return end
    end
  end

  ------------------------------------------------------------------------------
  -- Events
  ------------------------------------------------------------------------------

  function ENT:UKLev_FireEvent( kind )
    local u = self.UKLev_U

    if kind == "roar" then
      self:EmitSound( SND.Roar, 140, 100, 1 )
      util.ScreenShake( self:GetPos(), 2, 20, 1.0, 200 * u )

    elseif kind == "stopAction" then
      self:UKLev_EndAction()
      self.UKLev_State = "active"

    elseif kind == "bigSplash" then
      self:UKLev_Splash( self:GetPos() )

    elseif kind == "descendEnd" then
      self:UKLev_EndAction()
      self:SetNoDraw( true )
      self.UKLev_State = "hidden"
      self:UKLev_SetCollidersSolid( false )
      if self.UKLev_IdleLoop then self.UKLev_IdleLoop:ChangeVolume( 0, 0.3 ) end
      self:UKLev_MainPhaseOver()

    elseif kind == "biteLock" then
      -- canon BiteStopTracking: freeze aim at the predicted player position
      local enemy = self:GetEnemy()
      if IsValid( enemy ) then
        local d = self:UKLev_GetDifficulty()
        local lead = ( d >= 2 ) and 0.85 or ( d == 0 and 0 or 0.4 )
        local predicted = enemy:GetPos() + enemy:GetVelocity() * lead
        self.UKLev_LockYaw = self:UKLev_FaceAngles( predicted ).yaw
        -- canon V2Flash warning at the weak point
        self:SetNW2Float( "UKLev_FlashUntil", CurTime() + 0.35 )
      end

    elseif kind == "biteDamageStart" then
      self.UKLev_BiteDamaging = true
      self.UKLev_BiteHit = false
      self.UKLev_BiteLastT = nil
      self:SetParryable( true )
      self:EmitSound( SND.Swing, 130, 100, 1 )

    elseif kind == "biteDamageStop" then
      self.UKLev_BiteDamaging = false
      self:SetParryable( false )

    elseif kind == "biteReset" then
      self.UKLev_LockYaw = nil

    elseif kind == "burstBegin" then
      local d = self:UKLev_GetDifficulty()
      self.UKLev_BurstMax = ( d >= 2 ) and 80 or ( d == 1 and 60 or 40 )
      self.UKLev_BurstLeft = self.UKLev_BurstMax
      self.UKLev_BurstNextShot = 0
      self:UKLev_StartAction( "BurstLoop" )

    elseif kind == "beamCharge" then
      self:EmitSound( SND.BeamCharge, 120, 100, 0.5 )
      self:SetNW2Bool( "UKLev_BeamCharge", true )

    elseif kind == "beamFire" then
      self:SetNW2Bool( "UKLev_BeamCharge", false )
      self:SetNW2Bool( "UKLev_Beam", true )
      self.UKLev_BeamTime = 10
      self.UKLev_BeamHits = {}
      self.UKLev_BeamSound = CreateSound( self, SND.BeamLoop )
      self.UKLev_BeamSound:PlayEx( 0.6, 100 )
      -- canon BeamTurn: the sweep starts 90 deg ahead of the player
      local enemy = self:GetEnemy()
      if IsValid( enemy ) then
        local a = self:UKLev_FaceAngles( enemy:GetPos() )
        a:RotateAroundAxis( vector_up, -90 )
        self:SetAngles( Angle( 0, a.yaw, 0 ) )
      end
      self:UKLev_StartAction( "BeamLoop" )
    end
  end

  ------------------------------------------------------------------------------
  -- Splash (virtual water)
  ------------------------------------------------------------------------------

  function ENT:UKLev_Splash( pos )
    local at = Vector( pos.x, pos.y, self.UKLev_WaterZ )
    local fx = EffectData()
    fx:SetOrigin( at )
    fx:SetScale( 40 * self.UKLev_Scale )
    util.Effect( "watersplash", fx, true, true )
    sound.Play( SND.SplashBig, at, 130, math.random( 95, 105 ), 1 )
  end

  ------------------------------------------------------------------------------
  -- Bite damage (canon SwingCheck2 sphere on the head bone)
  ------------------------------------------------------------------------------

  -- 2D distance to the segment + a vertical band: the head is a ~23 m tall
  -- mass of flesh, a sweep passing right over the player must connect ("бьёт
  -- над игроком" feedback) — while side-dodges stay fully honest.
  local function StrikeHitsPoint( ec, a, b, radius, ztol )
    local abx, aby = b.x - a.x, b.y - a.y
    local len = abx * abx + aby * aby
    local t = 0
    if len > 0 then
      t = math.Clamp( ( ( ec.x - a.x ) * abx + ( ec.y - a.y ) * aby ) / len, 0, 1 )
    end
    local dx = ec.x - ( a.x + abx * t )
    local dy = ec.y - ( a.y + aby * t )
    if dx * dx + dy * dy > radius * radius then return false end
    local cz = a.z + ( b.z - a.z ) * t
    return math.abs( ec.z - cz ) <= ztol
  end

  -- r4: the strike zone is the head<->jaw segment of the animation frame,
  -- sampled offline from leviathan_bite.smd — damage lands exactly where the
  -- mouth visibly sweeps. r5: sub-stepped over the anim-time interval between
  -- thinks so the 400 m/s sweep can't skip over anyone.
  function ENT:UKLev_BiteSegmentAt( t )
    local D = UKLeviathanStrikes
    if not D then return end
    local fr = t * D.BITE_FPS - D.BITE_FRAME0 + 1
    local n = #D.BITE
    if fr < 1 or fr > n then return end
    local i0 = math.floor( fr )
    local i1 = math.min( i0 + 1, n )
    local frac = fr - i0
    local r0, r1 = D.BITE[ i0 ], D.BITE[ i1 ]
    local u = self.UKLev_U
    local side = D.SIDE
    local pos = self:GetPos()
    local fwd, right = self:GetForward(), self:GetRight()
    local function P( k )
      local f = r0[ k ] + ( r1[ k ] - r0[ k ] ) * frac
      local s = r0[ k + 1 ] + ( r1[ k + 1 ] - r0[ k + 1 ] ) * frac
      local h = r0[ k + 2 ] + ( r1[ k + 2 ] - r0[ k + 2 ] ) * frac
      return pos + fwd * ( f * u ) + right * ( s * side * u ) + Vector( 0, 0, h * u )
    end
    return P( 1 ), P( 4 )   -- head bone, jaw bone
  end

  function ENT:UKLev_BiteHitTarget( ent, center )
    local amount
    if ent:IsPlayer() then
      amount = UKLeviathan.ScaleAttackDamage( ent, UKLeviathan.BITE_DAMAGE )
    else
      -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
      amount = ent.IsUltrakillNextbot
        and UKNpcDmg.PreMult( ent, self, UKLeviathan.BITE_DAMAGE * 100 )
        or UKLeviathan.BITE_DAMAGE
    end
    local dmg = DamageInfo()
    dmg:SetDamage( amount )
    dmg:SetDamageType( DMG_SLASH )
    dmg:SetAttacker( self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    dmg:SetDamageForce( self:UKLev_FaceDir() * 1000 )
    ent:TakeDamageInfo( dmg )
    if ent:IsPlayer() then
      local dir = ( ent:WorldSpaceCenter() - center ):GetNormalized()
      ent:SetVelocity( dir * 800 + Vector( 0, 0, 300 ) )
    end

    -- canon TargetBeenHit: one landed hit closes the swing
    self.UKLev_BiteHit = true
    self.UKLev_BiteDamaging = false
    self:SetParryable( false )
  end

  function ENT:UKLev_ApplyBiteDamage()
    if not self.UKLev_BiteDamaging or self.UKLev_BiteHit then return end
    if not UKLeviathanStrikes then return end
    local u = self.UKLev_U
    local radius = UKLeviathan.BITE_RADIUS * u
    local nowT = ( CurTime() - ( self.UKLev_ActionStart or 0 ) ) * self:UKLev_AnimSpeed()
    local fromT = self.UKLev_BiteLastT or math.max( nowT - 0.05, 0 )
    self.UKLev_BiteLastT = nowT

    -- candidates once per think: the sweep reaches ~98 m from the base
    local targets = {}
    for _, ent in ipairs( ents.FindInSphere( self:GetPos(), 110 * u ) ) do
      if ent ~= self and IsValid( ent ) and not ent.UKLev_IsLeviathan
          and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        targets[ #targets + 1 ] = ent
      end
    end

    local debug = GetConVar( "ukleviathan_debug" ):GetBool()
    local t = fromT
    while true do
      local jaw, mouth = self:UKLev_BiteSegmentAt( t )
      if jaw then
        if debug then
          debugoverlay.Line( jaw, mouth, 0.5, Color( 255, 60, 60 ), true )
          debugoverlay.Sphere( mouth, radius, 0.5, Color( 255, 60, 60 ), false )
        end
        for _, ent in ipairs( targets ) do
          if IsValid( ent )
              and StrikeHitsPoint( ent:WorldSpaceCenter(), jaw, mouth, radius, 18 * u ) then
            self:UKLev_BiteHitTarget( ent, ( jaw + mouth ) * 0.5 )
            return
          end
        end
      end
      if t >= nowT then break end
      t = math.min( t + 0.015, nowT )
    end
  end

  ------------------------------------------------------------------------------
  -- Projectile burst (canon FixedUpdate spiral)
  ------------------------------------------------------------------------------

  local function RotateAboutAxis( v, axis, deg )
    local rad = math.rad( deg )
    local c, s = math.cos( rad ), math.sin( rad )
    return v * c + axis:Cross( v ) * s + axis * ( axis:Dot( v ) * ( 1 - c ) )
  end

  -- Barrage projectiles = the familiar workshop ones: red Hell Orb from the
  -- prelude Stray, yellow explosive mortar from the act1 Hideous Mass. Spawned
  -- manually (not CreateProjectile) so the gravity/homing overrides land
  -- BEFORE Spawn — the stock mortar arcs and homes, which would eat the spiral.
  function ENT:UKLev_SpawnOrb( explosive )
    local class = explosive and UKLeviathan.CLASS.OrbYellow or UKLeviathan.CLASS.OrbRed
    if not scripted_ents.GetStored( class ) then class = UKLeviathan.CLASS.Orb end

    local orb = ents.Create( class )
    if not IsValid( orb ) then return end
    orb:SetOwner( self )
    orb.Gravity = false
    orb.UltrakillBase_HomingType = -1
    if explosive then orb.UKLev_Explosive = true end   -- for the fallback class
    self:DeleteOnRemove( orb )
    orb:Spawn()

    if explosive and class == UKLeviathan.CLASS.OrbYellow then
      -- canon Energy Orb hits for 20 (x10 UKBase convention), not the mortar's 60
      orb.OnContact = function( proj )
        if proj:GetParried() then return proj:ParryCollide( 600 ) end
        UltrakillBase.SoundScript( "Ultrakill_Explosion_1", proj:GetPos() )
        proj:Explosion( proj:GetPos(), UKLeviathan.ORB_EXPLOSIVE_DAMAGE * 10, nil,
          150, 0.2, proj:GetOwner() )
        proj:CreateExplosion( proj:GetPos(), proj:GetAngles(), 1.25 )
      end
    end
    return orb
  end

  function ENT:UKLev_BurstThink()
    if self.UKLev_BurstLeft <= 0 then return end
    local now = CurTime()
    if now < self.UKLev_BurstNextShot then return end
    local d = self:UKLev_GetDifficulty()
    local interval = ( d >= 2 ) and 0.025 or ( d == 1 and 0.0375 or 0.05 )
    self.UKLev_BurstNextShot = now + interval

    local enemy = self:GetEnemy()
    local muzzle = self:UKLev_MuzzlePos()
    local n = self.UKLev_BurstLeft
    self.UKLev_BurstLeft = n - 1

    -- aim basis: canon shootPoint tracks the player (predicted in phase 2)
    local aimPos
    if IsValid( enemy ) then
      aimPos = enemy:IsPlayer() and ( enemy:GetPos() + enemy:GetViewOffset() ) or enemy:WorldSpaceCenter()
      if self.UKLev_SecondPhase then
        aimPos = aimPos + enemy:GetVelocity() * 1.5
      end
    elseif self:IsPossessed() then
      -- free aim without a lock-on: the spiral follows the possessor's view
      aimPos = muzzle + self:GetPossessor():GetAimVector() * 100
    else
      aimPos = muzzle + self:UKLev_FaceDir() * 100
    end
    local F = ( aimPos - muzzle ):GetNormalized()

    local dir
    if n % 10 == 0 then
      dir = F  -- canon: every 10th orb aims at the target
    else
      -- canon spiral: roll (n%10)*36 deg around forward, then spread around
      -- the rolled up axis with a triangular envelope over the burst
      local spread = 15 * ( ( d < 2 ) and 1 or 2 ) * 1.5
      local max = self.UKLev_BurstMax
      if n > max / 2 then
        spread = spread * ( 1 - n / max )
      else
        spread = spread * ( n / max )
      end
      local up = F:Angle():Up()
      up = RotateAboutAxis( up, F, ( n % 10 ) * 36 )
      dir = RotateAboutAxis( F, up, spread )
    end

    local orb = self:UKLev_SpawnOrb( d >= 2 and n % 20 == 0 )
    if not IsValid( orb ) then return end
    orb:SetPos( muzzle + dir * 2 * self.UKLev_U )
    orb:SetAngles( dir:Angle() )
    -- scale-aware speed x tunable convar (ukleviathan_orbspeed, default 0.5 —
    -- r3 "make them even slower" feedback)
    local vel = dir * UKLeviathan.OrbSpeed( d ) * self.UKLev_U * UKLeviathan.OrbSpeedMult()
    local phys = orb:GetPhysicsObject()
    if IsValid( phys ) then phys:SetVelocity( vel ) else orb:SetVelocity( vel ) end

    if self.UKLev_BurstLeft <= 0 then
      self:UKLev_StartAction( "BurstStop" )
    end
  end

  ------------------------------------------------------------------------------
  -- Beam (canon LateUpdate sweep: 3 accelerating rotations, 35 dmg, unparryable)
  ------------------------------------------------------------------------------

  function ENT:UKLev_BeamThink( dt )
    if self.UKLev_BeamTime <= 0 then return end
    self.UKLev_BeamTime = math.max( self.UKLev_BeamTime - dt, 0 )
    local w = math.Clamp( ( 10 - self.UKLev_BeamTime ) ^ 2 * 5, 0, 180 )
    local ang = self:GetAngles()
    ang.yaw = ang.yaw + w * dt * self:UKLev_AnimSpeed()
    self:SetAngles( Angle( 0, ang.yaw, 0 ) )

    -- damage trace along the face direction
    local u = self.UKLev_U
    local from = self:UKLev_MuzzlePos()
    local dir = self:UKLev_FaceDir()
    local tr = util.TraceHull( {
      start = from, endpos = from + dir * UKLeviathan.BEAM_RANGE * u,
      mins = Vector( -12, -12, -12 ), maxs = Vector( 12, 12, 12 ),
      mask = MASK_SHOT,
      filter = function( e )
        return IsValid( e ) and not e.UKLev_IsLeviathan
          and not e.IsUltrakillProjectile
      end,
    } )
    local ent = tr.Entity
    if tr.Hit and IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
      self.UKLev_BeamHits = self.UKLev_BeamHits or {}
      local nextOk = self.UKLev_BeamHits[ ent ] or 0
      if CurTime() >= nextOk then
        self.UKLev_BeamHits[ ent ] = CurTime() + 1.0
        local amount
        if ent:IsPlayer() then
          amount = UKLeviathan.ScaleAttackDamage( ent, UKLeviathan.BEAM_DAMAGE )
        else
          -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
          amount = ent.IsUltrakillNextbot
            and UKNpcDmg.PreMult( ent, self, UKLeviathan.BEAM_DAMAGE * 100 )
            or UKLeviathan.BEAM_DAMAGE
        end
        local dmg = DamageInfo()
        dmg:SetDamage( amount )
        dmg:SetDamageType( DMG_ENERGYBEAM )
        dmg:SetAttacker( self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( tr.HitPos )
        ent:TakeDamageInfo( dmg )
        sound.Play( SND.BeamExplosion, tr.HitPos, 100, 100, 0.5 )
      end
    end

    if self.UKLev_BeamTime <= 0 then
      self:SetNW2Bool( "UKLev_Beam", false )
      if self.UKLev_BeamSound then self.UKLev_BeamSound:Stop() self.UKLev_BeamSound = nil end
      self.UKLev_StopTail = false
      self:UKLev_StartAction( "BeamEnd" )
    end
  end

  ------------------------------------------------------------------------------
  -- Attacks (canon Update attack tree)
  ------------------------------------------------------------------------------

  function ENT:UKLev_Bite()
    self:EmitSound( SND.WindupBite, 120, 100, 0.75 )
    self:UKLev_StartAction( "Bite" )
    local d = self:UKLev_GetDifficulty()
    if d <= 2 then self.UKLev_Cooldown = 0.2 + ( 2 - d ) end
  end

  function ENT:UKLev_ProjectileBurst()
    self:EmitSound( SND.WindupProjectile, 120, 100, 0.75 )
    self:UKLev_StartAction( "BurstStart" )
    local d = self:UKLev_GetDifficulty()
    if d <= 2 then self.UKLev_Cooldown = 0.5 + ( 2 - d ) end
  end

  function ENT:UKLev_BeamAttack()
    self.UKLev_StopTail = true
    self:EmitSound( SND.WindupBeam, 120, 100, 0.75 )
    self:UKLev_StartAction( "BeamStart" )
  end

  function ENT:UKLev_Descend()
    self.UKLev_State = "descending"
    self.UKLev_RecentAttacks = 0
    self.UKLev_PreviousAttack = -1
    self:EmitSound( SND.WindupDescend, 120, 100, 0.75 )
    self:UKLev_StartAction( "Descend" )
  end

  function ENT:UKLev_Ascend( long )
    self:SetNoDraw( false )
    self:UKLev_SetCollidersSolid( true )
    self.UKLev_State = "ascending"
    if self.UKLev_IdleLoop then self.UKLev_IdleLoop:ChangeVolume( 0.4, 0.3 ) end
    self:UKLev_Splash( self:GetPos() )
    self:UKLev_StartAction( long and "AscendLong" or "Ascend" )
    local d = self:UKLev_GetDifficulty()
    if self.UKLev_SecondPhase then
      self.UKLev_Cooldown = 3
    elseif d <= 2 then
      self.UKLev_Cooldown = 1 + ( 2 - d )
    else
      self.UKLev_Cooldown = 0
    end
  end

  ------------------------------------------------------------------------------
  -- Controller (LeviathanController): sub-phases, phase 2
  ------------------------------------------------------------------------------

  function ENT:UKLev_MainPhaseOver()
    if self.UKLev_Dead then return end
    if not self.UKLev_TailAddPhase then
      self:UKLev_BeginSubPhase()
    else
      self:UKLev_BeginMainPhase()
    end
  end

  function ENT:UKLev_BeginMainPhase()
    if self.UKLev_Dead then return end
    if not self.UKLev_TailAddPhase then
      self.UKLev_InSubPhase = false
    end
    if self.UKLev_ReadyForSecond or self.UKLev_SecondPhase then
      if self.UKLev_ReadyForSecond then
        self.UKLev_ReadyForSecond = false
        self.UKLev_SecondPhase = true
        self:UKLev_EnterSecondPhase()
      end
      self:UKLev_CenterPosition()
    else
      self:UKLev_ChangePosition()
    end
    self:UKLev_Ascend( false )
  end

  function ENT:UKLev_BeginSubPhase()
    if self.UKLev_InSubPhase or self.UKLev_Dead then return end
    self.UKLev_InSubPhase = true
    self.UKLev_SubAttacksLeft = 2
    self:UKLev_SubAttack()
  end

  function ENT:UKLev_SubAttack()
    if self.UKLev_Dead then return end
    local tail = self.UKLev_Tail
    -- a possessed tail is player-controlled: skip it so the head never waits
    -- underwater for a whip that will not come
    if not IsValid( tail ) or tail:IsPossessed() then
      self:UKLev_BeginMainPhase()
      return
    end
    self.UKLev_TailAttacking = true
    tail:UKLevTail_ChangePosition()
  end

  -- called by the tail entity when its whip completes
  function ENT:UKLev_SubAttackOver()
    if self.UKLev_Dead then return end
    self.UKLev_TailAttacking = false
    if not self.UKLev_TailAddPhase then
      self.UKLev_SubAttacksLeft = self.UKLev_SubAttacksLeft - 1
      if self.UKLev_SubAttacksLeft <= 0 then
        self:UKLev_BeginMainPhase()
      else
        self:UKLev_SubAttack()
      end
    else
      local d = self:UKLev_GetDifficulty()
      if d <= 2 then
        self.UKLev_TailTimer = 10 - d * 2.5
      else
        self.UKLev_TailTimer = 0
      end
    end
  end

  function ENT:UKLev_EnterSecondPhase()
    -- canon onEnterSecondPhase: boat destroyed, Ouroboros ring rises and spins
    util.ScreenShake( self:GetPos(), 3, 20, 1.5, 300 * self.UKLev_U )
    sound.Play( SND.Roar, self.UKLev_Anchor, 140, 90, 1 )
    if not IsValid( self.UKLev_Body ) then
      local body = ents.Create( UKLeviathan.CLASS.Body )
      if IsValid( body ) then
        body.UKLev_Head = self
        body.UKLev_Anchor = self.UKLev_Anchor
        body.UKLev_AnchorAng = self.UKLev_AnchorAng
        body.UKLev_U = self.UKLev_U
        body:SetPos( self:UKLev_SpotPos( 0, 25, -14 ) )
        body:Spawn()
        self.UKLev_Body = body
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Phase 2 (Sisyphus Prime scheme: base flips the phase when the first
  -- 120-HP bar layer empties; this arms the canon readyForSecondPhase chain:
  -- damage x0.5 -> forced beam -> descend -> ascend center + Ouroboros ring)
  ------------------------------------------------------------------------------

  function ENT:OnPhaseChange( phase )
    if phase ~= 2 or self.UKLev_Dead then return end
    if self.UKLev_SecondPhase or self.UKLev_ReadyForSecond then return end
    self.UKLev_ReadyForSecond = true
    self.UKLev_StopTail = true
    if UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_SisyphusPrime_Phase", self:GetPos(), self )
    end
    self:EmitSound( SND.Roar, 140, 85, 1 )
    util.ScreenShake( self:GetPos(), 3, 20, 1.5, 300 * self.UKLev_U )
  end

  ------------------------------------------------------------------------------
  -- Parry (canon GotParried: BiteParried anim, 20 self-damage, "+ DOWN TO SIZE")
  ------------------------------------------------------------------------------

  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    if self.UKLev_Dead then return end

    self.UKLev_BiteDamaging = false
    self:SetParryable( false )
    self.UKLev_LockYaw = nil
    self:EmitSound( SND.Hurt, 140, 100, 0.75 )

    -- canon: the parry deals a flat 20 to the boss
    dmg:SetDamage( UKLeviathan.PARRY_SELF_DAMAGE )

    self:UKLev_StartAction( "BiteParried" )
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKLev_Dead then return end
    -- underwater = untouchable (canon: the GO is inactive); damage forwarded
    -- from the tail entity passes through (canon subphase weak point)
    if self.UKLev_State == "hidden" and not self.UKLev_TailForward then
      dmg:SetDamage( 0 )
      return
    end
    -- parry runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an
    -- earlier CheckParry would put the flat +5000 bonus under the x10 multiplier

    -- canon Statue extraDamageZones: Heart x3 (hitgroup 2 = WeakpointBone hbox)
    if hitgroup == 2 then
      dmg:ScaleDamage( 3 )
    end
    -- canon readyForSecondPhase: totalDamageTakenMultiplier 0.5
    if self.UKLev_ReadyForSecond then
      dmg:ScaleDamage( 0.5 )
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  ------------------------------------------------------------------------------
  -- Think (canon LeviathanController.Update + LeviathanHead.Update)
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT or self.UKLev_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = math.min( now - ( self.UKLev_LastThink or now ), 0.25 )
    self.UKLev_LastThink = now

    -- boxes follow the entity yaw (beam sweep, enemy tracking)
    self:UKLev_UpdateColliders()

    if self.UKLev_ActionName then self:UKLev_ProcessEvents() end
    self:UKLev_ApplyBiteDamage()
    if self.UKLev_ActionName == "BurstLoop" then self:UKLev_BurstThink() end
    if self.UKLev_ActionName == "BeamLoop" then self:UKLev_BeamThink( dt ) end

    local health = self:Health()
    local maxHealth = self:GetMaxHealth()

    -- controller: tailAdd phase at 75% HP (the 50% phase change now rides the
    -- base phase system -> OnPhaseChange, Sisyphus Prime scheme)
    if not self.UKLev_TailAddPhase and health <= maxHealth * UKLeviathan.TAILADD_FRAC then
      self.UKLev_TailAddPhase = true
      if not self.UKLev_InSubPhase then
        self:UKLev_BeginSubPhase()
      else
        -- head returns while the tail keeps going
        if self.UKLev_State == "hidden" then self:UKLev_BeginMainPhase() end
      end
    end

    -- controller: autonomous tail in tailAdd phase (a possessed tail whips on
    -- its own binds instead)
    if self.UKLev_TailAddPhase and not self.UKLev_TailAttacking then
      self.UKLev_TailTimer = math.max( ( self.UKLev_TailTimer or 0 ) - dt, 0 )
      if self.UKLev_TailTimer <= 0 and not self.UKLev_StopTail
          and not ( IsValid( self.UKLev_Tail ) and self.UKLev_Tail:IsPossessed() ) then
        self:UKLev_SubAttack()
      end
    end

    local enemy = self:GetEnemy()

    -- body rotation toward the target (canon LateUpdate rotateBody/secondPhase)
    if self.UKLev_State == "active" and not self:UKLev_InAction() then
      local targetYaw
      if self.UKLev_LockYaw then
        targetYaw = self.UKLev_LockYaw
      elseif IsValid( enemy ) then
        targetYaw = self:UKLev_FaceAngles( enemy:GetPos() ).yaw
      elseif self:IsPossessed() then
        -- free aim: -forward is the face, so the entity yaw trails aim + 180
        targetYaw = self:GetPossessor():EyeAngles().yaw + 180
      end
      if targetYaw then
        local myAng = self:GetAngles()
        local delta = math.AngleDifference( targetYaw, myAng.yaw )
        local rate = math.max( math.min( 270, math.abs( delta ) * 13.5 ), 10 )
        local step = math.Clamp( delta, -rate * dt, rate * dt )
        self:SetAngles( Angle( 0, myAng.yaw + step, 0 ) )
      end
    elseif self.UKLev_ActionName == "Bite" then
      -- canon: the head visibly tracks the player until biteLock freezes the
      -- aim, then homes hard on the locked yaw — "he aims right at you"
      local targetYaw = self.UKLev_LockYaw
      if not targetYaw and IsValid( enemy ) then
        targetYaw = self:UKLev_FaceAngles( enemy:GetPos() ).yaw
      end
      if not targetYaw and self:IsPossessed() then
        targetYaw = self:GetPossessor():EyeAngles().yaw + 180
      end
      if targetYaw then
        local myAng = self:GetAngles()
        local delta = math.AngleDifference( targetYaw, myAng.yaw )
        local step = math.Clamp( delta, -540 * dt, 540 * dt )
        self:SetAngles( Angle( 0, myAng.yaw + step, 0 ) )
      end
    end

    -- head attack loop
    if self:IsPossessed() then
      -- the possessor drives attacks through PossessionBinds; only the phase
      -- machinery and the cooldown stay autonomous
      if self.UKLev_State ~= "active" or self:UKLev_InAction() then return end
      if self.UKLev_ReadyForSecond then
        self.UKLev_ForceBeam = true
        self:UKLev_Descend()
        return
      end
      if self.UKLev_Cooldown > 0 then
        self.UKLev_Cooldown = math.max( self.UKLev_Cooldown - dt * self:UKLev_AnimSpeed(), 0 )
      end
      return
    end

    if self.UKLev_State ~= "active" or self:UKLev_InAction() or not IsValid( enemy ) then
      return
    end

    -- canon: readyForSecondPhase forces beam-next + immediate descend
    if self.UKLev_ReadyForSecond then
      self.UKLev_ForceBeam = true
      self:UKLev_Descend()
      return
    end

    if self.UKLev_Cooldown > 0 then
      self.UKLev_Cooldown = math.max( self.UKLev_Cooldown - dt * self:UKLev_AnimSpeed(), 0 )
      return
    end

    if self.UKLev_RecentAttacks >= 3 then
      if self.UKLev_SecondPhase then
        self.UKLev_RecentAttacks = 0
        self.UKLev_ForceBeam = true
      else
        self:UKLev_Descend()
        return
      end
    end

    local u = self.UKLev_U
    -- canon "too close -> bite", measured 2D from the base: the sampled lunge
    -- sweeps the ground out to ~97 m in front, so a <50 m target is always
    -- inside the real strike path
    local ep = enemy:GetPos()
    local ddx, ddy = ep.x - self:GetPos().x, ep.y - self:GetPos().y
    if ddx * ddx + ddy * ddy < ( UKLeviathan.BITE_RANGE * u ) ^ 2 then
      self:UKLev_Bite()
      self.UKLev_PreviousAttack = 1
      self.UKLev_RecentAttacks = self.UKLev_RecentAttacks + 1
      return
    end

    local num = math.random( 0, 1 )
    if num == self.UKLev_PreviousAttack then num = num + 1 end
    if num > 1 then num = 0 end
    if self.UKLev_ForceBeam then
      num = 2
      self.UKLev_ForceBeam = false
    end

    if num == 0 then
      self:UKLev_ProjectileBurst()
    elseif num == 1 then
      self:UKLev_Bite()
    else
      self:UKLev_BeamAttack()
    end
    self.UKLev_PreviousAttack = num
    self.UKLev_RecentAttacks = self.UKLev_RecentAttacks + 1
  end

  function ENT:OnUpdateAnimation()
    local spd = self:UKLev_AnimSpeed()
    if self.UKLev_ActionName and self:UKLev_InAction() then
      return self.UKLev_ActionCfg.seq, spd
    end
    return "Idle", spd
  end

  function ENT:OnUpdateSpeed()
    return 0
  end

  function ENT:OnMeleeAttack( enemy )
    return
  end

  -- stationary boss: every move is a scripted teleport, so the possessor only
  -- steers the aim (CustomThink rotation) and triggers attacks through binds
  function ENT:PossessionControls()
  end

  ------------------------------------------------------------------------------
  -- Death (canon SpecialDeath: Death anims, segment-chain gibs, final gore
  -- mountain, player FullHeal)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKLev_Dead = true
    self:UKLev_EndAction()
    self:UKLev_SetCollidersSolid( false )
    self:SetNoDraw( false )
    self:SetNW2Bool( "UKLev_Beam", false )
    if self.UKLev_BeamSound then self.UKLev_BeamSound:Stop() self.UKLev_BeamSound = nil end
    if self.UKLev_IdleLoop then self.UKLev_IdleLoop:Stop() self.UKLev_IdleLoop = nil end

    local tail = self.UKLev_Tail
    if IsValid( tail ) then tail:UKLevTail_Death() end
    if IsValid( self.UKLev_Body ) then self.UKLev_Body.UKLevBody_Spinning = false end

    self:EmitSound( SND.Roar, 150, 80, 1 )
    util.ScreenShake( self:GetPos(), 2, 20, 2.0, 400 * self.UKLev_U )

    local seq = self:LookupSequence( "Death" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end

    -- canon death loop sound with pitch fading to zero
    local deathLoop = CreateSound( self, SND.RoarLoop )
    deathLoop:PlayEx( 0.5, 100 )
    self.UKLev_DeathLoop = deathLoop

    -- HeadExplode @2.35: chain gibs from the tail end toward the head
    local explodeAt = CurTime() + 2.35
    while IsValid( self ) and CurTime() < explodeAt do
      local frac = 1 - ( explodeAt - CurTime() ) / 2.35
      deathLoop:ChangePitch( math.max( 100 * ( 1 - frac ), 30 ), 0.1 )
      self:YieldCoroutine()
    end
    if not IsValid( self ) then return dmg end

    -- collect chain bones, far end first (canon ExplodeTail/ExplodeHead)
    local chain = {}
    for i = 0, self:GetBoneCount() - 1 do
      local name = self:GetBoneName( i )
      if name and name:match( "^Bone0%d%d$" ) and name ~= "Bone001" then
        table.insert( chain, i )
      end
    end
    table.sort( chain, function( a, b )
      return self:GetBoneName( a ) > self:GetBoneName( b )
    end )

    local waterZ = self.UKLev_WaterZ
    for step = 1, #chain, 2 do
      local boneId = chain[ step ]
      local pos = self:GetBonePosition( boneId )
      if pos and pos.z > waterZ - 5 * self.UKLev_U then
        local fx = EffectData()
        fx:SetOrigin( pos )
        fx:SetMagnitude( 6 )
        fx:SetScale( 6 )
        fx:SetFlags( 3 )
        util.Effect( "bloodspray", fx, true, true )
        sound.Play( SND.Hurt, pos, 110, math.random( 80, 120 ), 0.5 )
        self:ManipulateBoneScale( boneId, vector_origin )
        local waitUntil = CurTime() + 0.125
        while IsValid( self ) and CurTime() < waitUntil do self:YieldCoroutine() end
        if not IsValid( self ) then return dmg end
      else
        self:ManipulateBoneScale( boneId, vector_origin )
      end
    end

    -- FinalExplosion: gore mountain at the head + shake; canon heals the player
    local head = self:UKLev_HeadPos()
    for i = 1, 12 do
      local fx = EffectData()
      fx:SetOrigin( head + VectorRand() * 10 * self.UKLev_U )
      fx:SetMagnitude( 8 )
      fx:SetScale( 8 )
      fx:SetFlags( 3 )
      util.Effect( "bloodspray", fx, true, true )
    end
    util.ScreenShake( self:GetPos(), 5, 30, 1.5, 500 * self.UKLev_U )
    sound.Play( SND.Roar, head, 150, 60, 1 )
    if deathLoop then deathLoop:Stop() end
    for _, ply in ipairs( player.GetAll() ) do
      if ply:Alive() then ply:SetHealth( ply:GetMaxHealth() ) end
    end

    -- fade out
    self:SetRenderMode( RENDERMODE_TRANSCOLOR )
    local fadeUntil = CurTime() + 2
    while IsValid( self ) and CurTime() < fadeUntil do
      local a = math.Clamp( ( fadeUntil - CurTime() ) / 2, 0, 1 )
      self:SetColor( Color( 255, 255, 255, a * 255 ) )
      self:YieldCoroutine()
    end
    if IsValid( self.UKLev_Tail ) then self.UKLev_Tail:Remove() end
    if IsValid( self.UKLev_Body ) then self.UKLev_Body:Remove() end

    return dmg
  end

end

if CLIENT then

  local matGlow = CreateMaterial( "UKLev_Glow_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "sprites/light_glow02_add_noz",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )
  local matBeam = Material( "sprites/laserbeam" )

  function ENT:CustomDraw()
    -- warning flash before the bite lock (canon V2Flash at the weak point)
    local flashUntil = self:GetNW2Float( "UKLev_FlashUntil", 0 )
    if flashUntil > CurTime() then
      local id = self:LookupAttachment( "heart" )
      local att = id and id > 0 and self:GetAttachment( id )
      if att then
        local a = math.abs( math.sin( CurTime() * 40 ) )
        render.SetMaterial( matGlow )
        render.DrawQuadEasy( att.Pos, EyePos() - att.Pos, 220, 220,
          Color( 255, 60, 60, 255 * a ), 0 )
      end
    end

    -- beam charge glow + the sweep beam itself
    local id = self:LookupAttachment( "muzzle" )
    local att = id and id > 0 and self:GetAttachment( id )
    if att then
      if self:GetNW2Bool( "UKLev_BeamCharge", false ) then
        local a = math.abs( math.sin( CurTime() * 20 ) )
        render.SetMaterial( matGlow )
        render.DrawQuadEasy( att.Pos, EyePos() - att.Pos, 300, 300,
          Color( 120, 200, 255, 150 + 100 * a ), 0 )
      end
      if self:GetNW2Bool( "UKLev_Beam", false ) then
        local dir = -self:GetForward()
        local from = att.Pos
        local to = from + dir * 12000
        local tr = util.TraceLine( { start = from, endpos = to, mask = MASK_SHOT_HULL } )
        render.SetMaterial( matBeam )
        render.DrawBeam( from, tr.HitPos, 60, 0, 4, Color( 140, 210, 255, 255 ) )
        render.DrawBeam( from, tr.HitPos, 24, 0, 2, Color( 240, 250, 255, 255 ) )
        local dl = DynamicLight( self:EntIndex() )
        if dl then
          dl.pos = from + dir * 100
          dl.r, dl.g, dl.b = 140, 210, 255
          dl.brightness = 2
          dl.size = 600
          dl.dietime = CurTime() + 0.1
        end
      end
    end
  end

end

DrGBase.AddNextbot( ENT )
