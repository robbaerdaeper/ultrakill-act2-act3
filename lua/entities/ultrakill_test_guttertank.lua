AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_guttertank_shared.lua" )

-- Guttertank (Greater Machine, Layer 7) — canon 1:1 port of Guttertank.cs:
-- rocket launcher with velocity prediction (missed rockets freeze then pop),
-- landmines under its feet (faster cadence without line of sight), an
-- unparryable punch with a 75 m/s lunge, and the canon slip: a missed punch
-- staggers it and opens a parry window on the ground impact.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Guttertank"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Enemies"

ENT.Models = { UKGuttertank.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKGuttertank.HP
-- Model ~180 su tall, stocky: canon capsule r=2 m but a 80-su hull won't
-- path corridors; 44 follows the gutterman lesson (36 for a 174-su model).
ENT.CollisionBounds = Vector( 44, 44, 185 )
ENT.SurroundingBounds = Vector( 170, 170, 240 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Heavy"

local UNIT = UKGuttertank.UNIT
local ACTION = UKGuttertank.ACTION
local SOUND = UKGuttertank.SOUND

ENT.MeleeAttackRange = UKGuttertank.PUNCH_RANGE
ENT.RangeAttackRange = 4000
-- stop just inside punch range (6 m trigger) so the 6-15 m dead zone
-- (rockets forbidden, punch out of reach) can't stall him
ENT.ReachEnemyRange = 5 * UNIT
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 80 * UNIT -- canon acceleration 80
ENT.Deceleration = 1200
ENT.WalkSpeed = UKGuttertank.BASE_SPEED
ENT.RunSpeed = UKGuttertank.BASE_SPEED
ENT.MaxYawRate = 1200 -- canon angular speed
ENT.JumpHeight = 80
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Walk"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Walk"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Walk"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Walk"
ENT.FallingAnimRate = 1

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 26, 78 ),
    distance = 260,
    eyepos = false

  },

  {

    -- no EyeBone: EyePos is the bounds center, deep inside the chest armor;
    -- the forward offset has to clear the hull (halfwidth 44)
    offset = Vector( 40, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

-- Binds reuse the AI gates (InAction + per-attack cooldown clocks, which keep
-- ticking in CustomThink while possessed) so a held key can't restart actions.
ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self )

    if self.UKGT_Dead or self:UKGT_InAction() or self.UKGT_PunchCooldown > 0 then return end

    self:UKGT_StartPunch( self:PossessionGetLockedOn() )

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self )

    if self.UKGT_Dead or self:UKGT_InAction() or self.UKGT_ShootCooldown > 0 then return end

    self:UKGT_StartRocket( self:PossessionGetLockedOn() )

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self )

    if self.UKGT_Dead or self:UKGT_InAction() or self.UKGT_MineCooldown > 0 then return end
    if not self:UKGT_CheckMines() then return end

    self:UKGT_StartMine()

  end } },

}

if SERVER then

  local function ScaleUltrakillAttackDamage( ent, damage )
    if not IsValid( ent ) then return damage end
    if ent:IsPlayer() then
      -- round-4 2026-07-10: FLAT canon to the player. The guttertank
      -- constants are wiki x10 (base-Explosion convention), so /10 lands the
      -- wiki number regardless of the plytakedmgmult convar (default 0.1
      -- used to do the same division implicitly).
      return damage / 10
    end
    if ent.IsUltrakillNextbot then return damage end
    local cv = GetConVar( "drg_ultrakill_dmgmult" )
    return damage * math.max( cv and cv:GetFloat() or 1, 0 )
  end

  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKGuttertank.HP

    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKGT_Dead = false
    self.UKGT_ActionSequence = nil
    self.UKGT_ActionName = nil
    self.UKGT_ActionUntil = nil
    self.UKGT_ActionStart = 0
    self.UKGT_ActionHits = nil
    self.UKGT_LOSTimer = 0
    -- canon GetValues: shootCooldown Random(0.75,1.25), mineCooldown Random(2,3)
    self.UKGT_ShootCooldown = math.Rand( 0.75, 1.25 ) * UKGuttertank.COOLDOWN_MULT
    self.UKGT_MineCooldown = math.Rand( 2, 3 )
    self.UKGT_PunchCooldown = 0
    self.UKGT_PunchHit = false
    self.UKGT_PunchStopDone = false
    self.UKGT_RocketTarget = nil
    self.UKGT_RocketFired = false
    self.UKGT_RocketPredicted = false
    self.UKGT_MinePlaced = false
    self.UKGT_Mines = {}
    self.UKGT_ParryWindowUntil = nil
    self.UKGT_NextHurtSound = 0
    self.UKGT_LastWalkCycle = 0
    self.UKGT_GibsSpawned = false
    self:SetParryable( false )

    -- canon idle loops: garbled radio static (vol 0.2) + steam hiss (vol 0.25)
    self.UKGT_RadioSound = CreateSound( self, SOUND.RadioStatic )
    self.UKGT_RadioSound:PlayEx( 0.2, 100 )
    self.UKGT_SteamSound = CreateSound( self, SOUND.SteamLoop )
    self.UKGT_SteamSound:PlayEx( 0.25, 100 )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:CreatePortal( self:WorldSpaceCenter(), self:GetAngles(), 3, Vector( 210, 180, 260 ) )
    self:ParticleEffectTimed( 2, "Ultrakill_Portal_Cerberus", { pos = self:WorldSpaceCenter(), ang = self:GetAngles() } )
    UltrakillBase.SoundScript( "Ultrakill_Portal_Superheavy", self:GetPos() )
    self:SetTurning( true )
  end

  function ENT:UKGT_StopLoops()
    if self.UKGT_RadioSound then self.UKGT_RadioSound:Stop() self.UKGT_RadioSound = nil end
    if self.UKGT_SteamSound then self.UKGT_SteamSound:Stop() self.UKGT_SteamSound = nil end
  end

  function ENT:OnRemove()
    self:UKGT_StopLoops()
  end

  -- Difficulty --------------------------------------------------------------

  function ENT:UKGT_GetDifficulty()
    return self.UltrakillBase_Difficulty or 3
  end

  function ENT:UKGT_SpeedMult()
    return UKGuttertank.SPEED_MULT[ self:UKGT_GetDifficulty() ] or 1.0
  end

  -- Actions -------------------------------------------------------------------

  function ENT:UKGT_PlayAction( name, sequence, duration, cycle )
    local seq = self:LookupSequence( sequence )
    if seq and seq >= 0 then
      self.UKGT_ActionSequence = sequence
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( cycle or 0 )
      self:SetPlaybackRate( self:UKGT_SpeedMult() )
    end
    self.UKGT_ActionName = name
    self.UKGT_ActionStart = CurTime()
    self.UKGT_ActionUntil = CurTime() + duration / self:UKGT_SpeedMult()
    self.UKGT_ActionHits = {}
  end

  function ENT:UKGT_InAction()
    if self.UKGT_ActionUntil and self.UKGT_ActionUntil > CurTime() then return true end
    self.UKGT_ActionUntil = nil
    self.UKGT_ActionSequence = nil
    self.UKGT_ActionName = nil
    return false
  end

  function ENT:UKGT_ActionTime()
    -- action-local seconds on the canon clock (difficulty slows the clip)
    return ( CurTime() - ( self.UKGT_ActionStart or 0 ) ) * self:UKGT_SpeedMult()
  end

  function ENT:UKGT_SetYawRate( rate )
    if self.UKGT_YawRate ~= rate then
      self.UKGT_YawRate = rate
      self:SetMaxYawRate( rate )
    end
  end

  -- Animation -----------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    if self.UKGT_ActionSequence and self:UKGT_InAction() then
      return self.UKGT_ActionSequence, self:UKGT_SpeedMult()
    end
    local rate = self:UKGT_SpeedMult()
    -- canon Walking animator bool: nav velocity > 2.5 m/s (100 su/s)
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco:GetVelocity():Length() > 100
    if moving then return "Walk", rate end
    return "Idle", rate
  end

  function ENT:OnUpdateSpeed()
    return UKGuttertank.Speed( self:UKGT_GetDifficulty() )
  end

  -- Vision / prediction ---------------------------------------------------------

  -- canon VisionSourcePosition: own x/z at chest (Spine) height
  function ENT:UKGT_GetEyePos()
    local b = self:LookupBone( "Spine" )
    if b then
      local m = self:GetBoneMatrix( b )
      if m then return m:GetTranslation() end
    end
    return self:WorldSpaceCenter() + self:GetUp() * 40
  end

  function ENT:UKGT_GetTargetHead( enemy )
    if enemy.EyePos then
      local ok, pos = pcall( enemy.EyePos, enemy )
      if ok and isvector( pos ) then return pos end
    end
    return enemy:WorldSpaceCenter()
  end

  function ENT:UKGT_GetTargetVelocity( enemy )
    if not IsValid( enemy ) then return vector_origin end
    local v = enemy:GetVelocity()
    return isvector( v ) and v or vector_origin
  end

  function ENT:UKGT_PredictTargetPos( enemy, t )
    return enemy:GetPos() + self:UKGT_GetTargetVelocity( enemy ) * t
  end

  function ENT:UKGT_HasLineOfSight( enemy )
    if not IsValid( enemy ) then return false end
    local tr = util.TraceLine( {
      start = self:UKGT_GetEyePos(),
      endpos = self:UKGT_GetTargetHead( enemy ),
      mask = MASK_SHOT,
      filter = function( ent ) return ent ~= self end,
    } )
    return not tr.Hit or tr.Entity == enemy
  end

  -- Punch (canon Punch/PunchActive/PunchStop) -----------------------------------

  function ENT:UKGT_StartPunch( enemy )
    -- canon punch cooldown by difficulty (VIOLENT has none)
    local diff = self:UKGT_GetDifficulty()
    if diff <= 2 then
      self.UKGT_PunchCooldown = ( 4.5 - diff ) * UKGuttertank.COOLDOWN_MULT
    elseif diff == 4 then
      self.UKGT_PunchCooldown = 1.5 * UKGuttertank.COOLDOWN_MULT
    end

    self.UKGT_PunchHit = false
    self.UKGT_PunchStopDone = false
    -- cap the lunge so he never slides far past a dodging target: he may
    -- close up to where the enemy stood at swing start, 6 m tops
    self.UKGT_LungeFrom = self:GetPos()
    local dist = IsValid( enemy )
      and self:GetPos():Distance( enemy:GetPos() ) or ( 4 * UNIT )
    self.UKGT_LungeMax = math.Clamp( dist - 1.5 * UNIT, 1.5 * UNIT, 6 * UNIT )
    self:UKGT_PlayAction( "Punch", "Punch", ACTION.Punch.duration )
    UltrakillBase.SoundScript( "Ultrakill_GuttertankPunchPrep", self:GetPos() )
    -- canon unparryableFlash x5 in front of the swing check
    if self.CreateAlert then
      self:CreateAlert( self:WorldSpaceCenter() + self:GetForward() * ( 1.5 * UNIT ), 2, 2 )
    end
  end

  function ENT:UKGT_ProcessPunch( enemy )
    local t = self:UKGT_ActionTime()
    local cfg = ACTION.Punch

    if t < cfg.active then
      -- canon trackInAction: 360 deg/s onto the target before the swing.
      -- He PLANTS during the windup — leftover walk speed here was the
      -- "slides way too far on Brutal" bug (0.44 s of drift before the lunge)
      self.loco:SetVelocity( vector_origin )
      self:UKGT_SetYawRate( 360 )
      if IsValid( enemy ) then self:FaceTowards( enemy:GetPos() ) end
    elseif t <= cfg.stop then
      -- canon PunchActive: moveForward lunge at 75 m/s (anim-speed scaled),
      -- 90 deg/s correction, stops early if the spherecast finds the victim
      self:UKGT_SetYawRate( 90 )

      local fwd = self:GetForward()
      local lungeSpeed = 75 * UNIT * self:UKGT_SpeedMult()

      -- canon: SphereCast r=1.5 ahead — do not run the victim over, stop on him
      local ahead = util.TraceHull( {
        start = self:WorldSpaceCenter(),
        endpos = self:WorldSpaceCenter() + fwd * ( 2 * UNIT ),
        mins = Vector( -60, -60, -60 ),
        maxs = Vector( 60, 60, 60 ),
        mask = MASK_SHOT_HULL,
        filter = function( ent ) return ent ~= self end,
      } )
      local blocked = ahead.Hit and IsValid( ahead.Entity )
        and ( ahead.Entity:IsPlayer() or ahead.Entity:IsNPC() or ahead.Entity:IsNextBot() )

      -- canon IsLedgeSafe: don't lunge off a cliff
      local ground = util.TraceLine( {
        start = self:GetPos() + fwd * UNIT + Vector( 0, 0, UNIT ),
        endpos = self:GetPos() + fwd * UNIT - Vector( 0, 0, 22 * UNIT ),
        mask = MASK_SOLID_BRUSHONLY,
      } )

      -- lunge travel cap (Brutal feedback: he stepped way too far forward)
      local traveled = self.UKGT_LungeFrom
        and self:GetPos():Distance( self.UKGT_LungeFrom ) or 0

      if blocked or not ground.Hit or traveled >= ( self.UKGT_LungeMax or 240 ) then
        self.loco:SetVelocity( vector_origin )
      else
        self.loco:SetVelocity( fwd * lungeSpeed )
      end

      self:UKGT_DoPunchDamage()
    elseif not self.UKGT_PunchStopDone then
      -- canon PunchStop: stop the lunge; a missed punch slips the tank on
      -- difficulty < 4. On BRUTAL+ he keeps his footing — unless the floor
      -- under the swing is covered in Firestarter oil (ukweapons).
      self.UKGT_PunchStopDone = true
      self.loco:SetVelocity( vector_origin )
      self:UKGT_SetYawRate( 1200 )
      if not self.UKGT_PunchHit
          and ( self:UKGT_GetDifficulty() < 4 or self:UKGT_OnOil() ) then
        self:UKGT_StartStagger()
      end
    end
  end

  -- Firestarter integration: gasoline on him or an uk_oil_stain puddle under
  -- his feet / the end of the lunge robs the punch recovery of its footing.
  function ENT:UKGT_OnOil()
    if self:GetNW2Float( "UK_Gasoline_Meter", 0 ) > 0 then return true end
    local feet = self:GetPos() + self:GetForward() * 40
    for _, stain in ipairs( ents.FindInSphere( feet, 160 ) ) do
      if stain:GetClass() == "uk_oil_stain"
          and math.abs( stain:GetPos().z - self:GetPos().z ) < 80 then
        return true
      end
    end
    return false
  end

  function ENT:UKGT_DoPunchDamage()
    -- canon SwingCheck2: ~2x3x2.5 m box 1.25 m in front of the chest
    local origin = self:WorldSpaceCenter() + self:GetForward() * ( 1.5 * UNIT )
    local hits = self.UKGT_ActionHits or {}
    self.UKGT_ActionHits = hits

    for _, ent in ipairs( ents.FindInSphere( origin, 2.5 * UNIT ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

      hits[ ent ] = true
      self.UKGT_PunchHit = true

      local amount = ScaleUltrakillAttackDamage( ent, UKGuttertank.PUNCH_DAMAGE )
      -- canon: the punch instantly kills his brother machine (the 10x
      -- overkill margin also shrugs off the shield's /1.5 softening)
      if UKGuttertank.GUTTERMAN_CLASSES[ ent:GetClass() ] then
        amount = math.max( ent:GetMaxHealth(), ent:Health() ) * 10
      end

      local dmg = DamageInfo()
      dmg:SetDamage( amount )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetForward() * 2500 + Vector( 0, 0, 400 ) )
      ent:TakeDamageInfo( dmg )

      -- canon knockBackForce 50: heavy launch along the punch direction
      if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNextBot() ) then
        ent:SetVelocity( self:GetForward() * 2500 + Vector( 0, 0, 300 ) )
      end

      UltrakillBase.SoundScript( "Ultrakill_GuttertankPunchHit", self:GetPos() )
    end
  end

  -- Slip / stagger (canon PunchStagger + FallImpact parry window) ---------------

  function ENT:UKGT_StartStagger()
    self:UKGT_PlayAction( "PunchStagger", "PunchStagger", ACTION.PunchStagger.duration )
    self.UKGT_StaggerImpactDone = false
  end

  function ENT:UKGT_ProcessStagger()
    local t = self:UKGT_ActionTime()
    local cfg = ACTION.PunchStagger

    self.loco:SetVelocity( vector_origin )

    if not self.UKGT_StaggerImpactDone and t >= cfg.fallImpact then
      -- canon FallImpact: clang, 0.1 self-damage, parryable until StopParryable
      self.UKGT_StaggerImpactDone = true
      UltrakillBase.SoundScript( "Ultrakill_GuttertankFallImpact", self:GetPos() )
      util.ScreenShake( self:GetPos(), 6, 50, 0.4, 500 )

      self:SetHealth( math.max( self:Health() - 100, 1 ) ) -- canon 0.1 x1000

      self:SetParryable( true )
      self.UKGT_ParryWindowUntil = self.UKGT_ActionStart
        + ( cfg.stopParryable / self:UKGT_SpeedMult() )
      if self.CreateAlert then
        self:CreateAlert( self:WorldSpaceCenter() + self:GetForward() * ( 2 * UNIT ), 1, 3 )
      end
    end
  end

  -- Canon GotParried: replay PunchStagger from normalized 0.7 (skip to getting
  -- up), drop the parry flag. Base OnParry already did flash/hitstop/damage.
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    self.UKGT_ParryWindowUntil = nil
    local cfg = ACTION.PunchStagger
    self:UKGT_PlayAction( "PunchStagger", "PunchStagger",
      cfg.clipLength * 0.3, 0.7 )
    self.UKGT_StaggerImpactDone = true
  end

  -- Rocket (canon PrepRocket/PredictTarget/FireRocket) ---------------------------

  function ENT:UKGT_GetMuzzle()
    local att = self:LookupAttachment( "muzzle" )
    if att and att > 0 then
      local a = self:GetAttachment( att )
      if a then return a.Pos, a.Ang:Forward() end
    end
    return self:WorldSpaceCenter() + self:GetForward() * ( 1.5 * UNIT ) + self:GetUp() * ( 1.5 * UNIT ),
      self:GetForward()
  end

  function ENT:UKGT_StartRocket( enemy )
    self.UKGT_RocketPredicted = false
    self.UKGT_RocketFired = false
    self.UKGT_RocketAim = nil
    self:UKGT_PlayAction( "Shoot", "Shoot", ACTION.Shoot.duration )
    UltrakillBase.SoundScript( "Ultrakill_GuttertankFire", self:GetPos() )
  end

  function ENT:UKGT_ProcessRocket( enemy )
    self:FaceTowards( enemy:GetPos() )
    local t = self:UKGT_ActionTime()
    local cfg = ACTION.Shoot
    -- canon trackInAction: rotate onto the target at 360 deg/s the whole action
    self:UKGT_SetYawRate( 360 )
    if IsValid( enemy ) then self:FaceTowards( enemy:GetPos() ) end
    self.loco:SetVelocity( vector_origin )

    if not self.UKGT_RocketPredicted and t >= cfg.predict then
      self.UKGT_RocketPredicted = true
      self:UKGT_PredictTarget( enemy )
    end

    if not self.UKGT_RocketFired and t >= cfg.fire then
      self.UKGT_RocketFired = true
      self:UKGT_FireRocket( enemy )
      -- canon: shootCooldown = Random(1.25,1.75) - (BRUTAL+ 0.5)
      self.UKGT_ShootCooldown = ( math.Rand( 1.25, 1.75 )
        - ( self:UKGT_GetDifficulty() >= 4 and 0.5 or 0 ) )
        * UKGuttertank.COOLDOWN_MULT
    end
  end

  function ENT:UKGT_PredictTarget( enemy )
    local muzzle = self:UKGT_GetMuzzle()

    -- canon: big unparryable flash at the muzzle
    if self.CreateAlert then
      self:CreateAlert( muzzle + self:GetForward() * 40, 2, 4 )
    end

    if not IsValid( enemy ) then return end

    local headPos = self:UKGT_GetTargetHead( enemy )
    local targetPos = enemy:GetPos()

    -- canon lead: target + velocity * ((Rand(0.75,1) + dist/rocketSpeed) * num)
    local diff = self:UKGT_GetDifficulty()
    local num = 1
    if diff <= 1 then num = ( diff == 0 ) and 0.5 or 0.75 end

    local dist = muzzle:Distance( headPos )
    local lead = ( math.Rand( 0.75, 1 ) + dist / UKGuttertank.ROCKET_SPEED ) * num
    local aim = targetPos + self:UKGT_GetTargetVelocity( enemy ) * lead

    -- canon: if the target is within 15 m of the ground, aim at head height
    -- so the lead shot doesn't just plow the floor in front of him
    local down = util.TraceLine( {
      start = targetPos,
      endpos = targetPos - Vector( 0, 0, 15 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if down.Hit then
      aim.z = headPos.z
    end

    -- canon: obstruction between muzzle and the lead point -> shoot the head
    local block = util.TraceLine( {
      start = muzzle,
      endpos = aim,
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if block.Hit then aim = headPos end

    self.UKGT_RocketAim = aim
  end

  function ENT:UKGT_FireRocket( enemy )
    local muzzle = self:UKGT_GetMuzzle()
    local aim = self.UKGT_RocketAim
      or ( IsValid( enemy ) and self:UKGT_GetTargetHead( enemy ) )
      or ( muzzle + self:GetForward() * 1000 )

    -- possessed free-aim (base AimProjectile recipe): lock-on center or the
    -- point under the possessor's crosshair — vertical included, no lead
    if self:IsPossessed() then
      local lockon = self:PossessionGetLockedOn()
      if IsValid( lockon ) then
        aim = lockon:WorldSpaceCenter()
      else
        local tr = self:PossessorTrace()
        if tr then aim = tr.HitPos end
      end
    end

    local dir = aim - muzzle
    if dir:LengthSqr() < 1 then dir = self:GetForward() else dir:Normalize() end

    local rocket = ents.Create( UKGuttertank.CLASS.Rocket )
    if IsValid( rocket ) then
      rocket:SetPos( muzzle + dir * 30 )
      rocket:SetAngles( dir:Angle() )
      rocket:SetOwner( self )
      rocket.UKGT_ProximityTarget = IsValid( enemy ) and enemy or nil
      -- canon: low difficulties slow the rocket down (x0.6 / x0.8)
      local diff = self:UKGT_GetDifficulty()
      local speed = UKGuttertank.ROCKET_SPEED
      if diff <= 1 then speed = speed * ( ( diff == 0 ) and 0.6 or 0.8 ) end
      rocket.UKGT_Speed = speed
      rocket:Spawn()
      rocket:SetVelocity( dir * speed )
    end

    UltrakillBase.SoundScript( "Ultrakill_GuttertankRocketFirePrep", self:GetPos() )
    local fx = EffectData()
    fx:SetOrigin( muzzle )
    fx:SetNormal( dir )
    fx:SetScale( 1 )
    util.Effect( "MuzzleEffect", fx, true, true )
  end

  -- Landmine (canon PrepMine/PlaceMine/CheckMines) -------------------------------

  function ENT:UKGT_CheckMines()
    -- prune dead references, cap own live mines at 5
    local mines = self.UKGT_Mines or {}
    for i = #mines, 1, -1 do
      if not IsValid( mines[ i ] ) then table.remove( mines, i ) end
    end
    self.UKGT_Mines = mines
    if #mines >= UKGuttertank.MINE_LIMIT then return false end

    -- canon: no other landmine (anyone's) within 15 m
    for _, mine in ipairs( ents.FindByClass( UKGuttertank.CLASS.Mine ) ) do
      if IsValid( mine ) and mine:GetPos():DistToSqr( self:GetPos() )
          < UKGuttertank.MINE_SPACING * UKGuttertank.MINE_SPACING then
        return false
      end
    end
    return true
  end

  function ENT:UKGT_StartMine()
    self.UKGT_MinePlaced = false
    self:UKGT_PlayAction( "Landmine", "Landmine", ACTION.Landmine.duration )
    UltrakillBase.SoundScript( "Ultrakill_GuttertankMinePrep", self:GetPos() )
    -- canon: mineCooldown = Random(2,3)
    self.UKGT_MineCooldown = math.Rand( 2, 3 )
  end

  function ENT:UKGT_ProcessMine()
    local t = self:UKGT_ActionTime()
    self.loco:SetVelocity( vector_origin )
    if not self.UKGT_MinePlaced and t >= ACTION.Landmine.place then
      self.UKGT_MinePlaced = true
      local mine = ents.Create( UKGuttertank.CLASS.Mine )
      if IsValid( mine ) then
        mine:SetPos( self:GetPos() + Vector( 0, 0, 8 ) )
        mine:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )
        mine:SetOwner( self )
        mine:Spawn()
        table.insert( self.UKGT_Mines, mine )
      end
    end
  end

  -- Action dispatch ---------------------------------------------------------------

  function ENT:UKGT_ProcessAction( enemy )
    local name = self.UKGT_ActionName
    if name == "Punch" then
      self:UKGT_ProcessPunch( enemy )
    elseif name == "PunchStagger" then
      self:UKGT_ProcessStagger()
    elseif name == "Shoot" then
      self:UKGT_ProcessRocket( enemy )
    elseif name == "Landmine" then
      self:UKGT_ProcessMine()
    end
  end

  -- Base scheduler must not double-drive attacks; everything runs off the think.
  function ENT:OnMeleeAttack( enemy ) return end
  function ENT:OnRangeAttack( enemy ) return end

  -- Footsteps -----------------------------------------------------------------------

  local WALK_STEPS = { 0.21, 0.74 } -- Walk_6 footstep events / 1.0333 s clip

  function ENT:UKGT_UpdateFootsteps()
    if not ( self:IsMoving() or self:IsRunning() ) then return end
    local seqName = self:GetSequenceName( self:GetSequence() ) or ""
    if not string.find( seqName, "Walk", 1, true ) then return end

    local cycle = self:GetCycle()
    local last = self.UKGT_LastWalkCycle or 0
    for _, mark in ipairs( WALK_STEPS ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) ) -- wrap
      if crossed then
        self:EmitSound( SOUND.Step, 90, math.random( 95, 105 ) )
        util.ScreenShake( self:GetPos(), 2, 40, 0.25, 500 )
        break
      end
    end
    self.UKGT_LastWalkCycle = cycle
  end

  -- Think ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKGT_Dead then return end
    if self:IsAIDisabled() then -- ai_disabled / per-bot disable
      -- выпад панча гонит его по-тиковым SetVelocity; замороженный
      -- мид-выпад иначе скользит с последней скоростью
      if self:UKGT_InAction() and self.loco then
        self.loco:SetVelocity( vector_origin )
      end
      return
    end

    local now = CurTime()
    local dt = now - ( self.UKGT_LastThink or now )
    self.UKGT_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )
    local speedMult = self:UKGT_SpeedMult()

    -- close the stagger parry window on canon StopParryable
    if self.UKGT_ParryWindowUntil and now >= self.UKGT_ParryWindowUntil then
      self.UKGT_ParryWindowUntil = nil
      self:SetParryable( false )
    end

    -- canon cooldown clocks (mine clock at half rate while he has LOS)
    self.UKGT_PunchCooldown = math.max( self.UKGT_PunchCooldown - dt * speedMult, 0 )
    if self.UKGT_ShootCooldown > 0 then
      self.UKGT_ShootCooldown = math.max( self.UKGT_ShootCooldown - dt * speedMult, 0 )
    end
    if self.UKGT_MineCooldown > 0 then
      self.UKGT_MineCooldown = math.max( self.UKGT_MineCooldown
        - dt * ( ( self.UKGT_LOSTimer >= 0.5 ) and 0.5 or 1 ) * speedMult, 0 )
    end

    local enemy = self:GetEnemy()
    local hasLoS = IsValid( enemy ) and self:UKGT_HasLineOfSight( enemy ) or false
    self.UKGT_LOSTimer = math.Approach( self.UKGT_LOSTimer, hasLoS and 1 or 0, dt * speedMult )

    if self:UKGT_InAction() then
      self:UKGT_ProcessAction( enemy )
      self:UKGT_UpdateFootsteps()
      return
    end
    self:UKGT_SetYawRate( 1200 )

    -- possessed: no autonomous punch/predict/rocket/mine triggers, attacks
    -- start from the binds only (locked-on target flows in through the
    -- base GetEnemy override); the cooldown clocks above keep running
    if self:IsPossessed() then
      self:UKGT_UpdateFootsteps()
      return
    end

    -- canon Update decision block
    if IsValid( enemy ) and self.UKGT_LOSTimer >= 0.5 then
      local pos = self:GetPos()
      local diff = self:UKGT_GetDifficulty()
      local close = pos:Distance( enemy:GetPos() ) < UKGuttertank.PUNCH_RANGE
        or pos:Distance( self:UKGT_PredictTargetPos( enemy, UKGuttertank.PUNCH_PREDICT ) )
          < UKGuttertank.PUNCH_RANGE

      -- canon: low difficulties keep re-arming the punch delay while far away
      if diff <= 1 and not close then
        self.UKGT_PunchCooldown = ( ( diff == 1 ) and 1 or 2 )
          * UKGuttertank.COOLDOWN_MULT
      end

      if self.UKGT_PunchCooldown <= 0 and close then
        self:UKGT_StartPunch( enemy )
      elseif self.UKGT_ShootCooldown <= 0
          and pos:Distance( self:UKGT_PredictTargetPos( enemy, 1 ) ) > UKGuttertank.ROCKET_MIN_RANGE then
        self:UKGT_StartRocket( enemy )
      end
    end

    -- canon mine block (runs regardless of LOS; cadence handled by the clock)
    if IsValid( enemy ) and self.UKGT_MineCooldown <= 0 and not self:UKGT_InAction() then
      if self:UKGT_CheckMines() then
        self:UKGT_StartMine()
      else
        self.UKGT_MineCooldown = 0.5
      end
    end

    self:UKGT_UpdateFootsteps()
  end

  -- Damage -----------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKGT_Dead then return end

    -- parry (stagger recovery window) runs inside BaseClass.OnTakeDamage AFTER
    -- DamageMultiplier; an earlier CheckParry would put the flat +5000 bonus
    -- under the x10 player-damage multiplier

    if CurTime() >= ( self.UKGT_NextHurtSound or 0 ) and dmg:GetDamage() > 0 then
      self.UKGT_NextHurtSound = CurTime() + 0.35
      self:EmitSound( SOUND.Hurt[ math.random( #SOUND.Hurt ) ], 80 )
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  -- Death ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKGT_Dead = true
    self.UKGT_ParryWindowUntil = nil
    self:SetParryable( false )
    self:UKGT_StopLoops()
    UltrakillBase.SoundScript( "Ultrakill_GuttertankDeath", self:GetPos() )
    self:UKGT_PlayAction( "Death", "Death", ACTION.Death.duration )

    local doneAt = CurTime() + ACTION.Death.duration
    while IsValid( self ) and CurTime() < doneAt do
      self.loco:SetVelocity( vector_origin )
      self:YieldCoroutine()
    end

    if IsValid( self ) and not self.UKGT_GibsSpawned then
      self.UKGT_GibsSpawned = true
      self:UKGT_SpawnGibs( dmg )
    end

    return dmg
  end

  -- The tank falls apart into pieces of himself (mannequin gib pattern):
  -- each gib prop spawns at its anchor bone's death-pose position, inherits
  -- the killing blow's push and sprays blood (machines run on blood).
  function ENT:UKGT_SpawnGibs( dmg )
    local center = self:WorldSpaceCenter()
    local baseVel = self.loco:GetVelocity() * 0.5
    local force = dmg and dmg:GetDamageForce() or vector_origin
    if force:LengthSqr() > 1 then
      force = force:GetNormalized() * math.min( force:Length() * 0.02, 350 )
    end

    self:EmitSound( SOUND.FallImpact, 90, 90 )

    local pieces = {}
    for _, gib in ipairs( UKGuttertank.GIBS ) do
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
      pieces[ gib.bone ] = prop

      local phys = prop:GetPhysicsObject()
      if IsValid( phys ) then
        phys:SetVelocity( baseVel + force
          + ( pos - center ):GetNormalized() * math.Rand( 120, 280 )
          + VectorRand() * 80 + Vector( 0, 0, math.Rand( 100, 240 ) ) )
        phys:AddAngleVelocity( VectorRand() * 300 )
      end

      -- machines bleed: short spray from each piece + floor decals
      local tname = "UKGuttertankGib" .. prop:EntIndex()
      timer.Create( tname, 0.4, 4, function()
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

      SafeRemoveEntityDelayed( prop, 25 )
    end

    -- the rocket launcher stays wired to the main body (canon cabling):
    -- physical rope between the torso piece and the cannon piece
    local torso, cannon = pieces[ "Spine" ], pieces[ "Cannon" ]
    if IsValid( torso ) and IsValid( cannon ) then
      constraint.Rope( torso, cannon, 0, 0, vector_origin, vector_origin,
        torso:GetPos():Distance( cannon:GetPos() ), 45, 0, 2,
        "cable/cable2", false )
    end

    -- central burst
    for i = 1, 6 do
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
  end

end

DrGBase.AddNextbot( ENT )
