-- lua/entities/ultrakill_test_geryon.lua
-- Geryon, Watcher of the Skies (Supreme Demon, Layer 8: Fraud, 8-4 boss).
-- Canon-faithful port of the decompiled Geryon class:
-- orbits its target, picks among 4 attacks (never repeating the last two),
-- overheats after maxHeat actions and stuns with the weak point open, second
-- phase below half HP speeds everything up 1.25x and skips attack recoveries.
-- Sandbox adaptation: the canon fight orbits the arena centre in free fall;
-- here Geryon orbits its target and Y-matches it (canon MoveUpdate behaviour).

AddCSLuaFile()

if not DrGBase or not UltrakillBase then return end
if not UKGeryon then include( "autorun/ultrakill_test_geryon_shared.lua" ) end

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local SND = UKGeryon.SOUND
local UNIT = UKGeryon.UNIT

if CLIENT then
  util.PrecacheModel( UKGeryon.MODEL )
end

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Geryon"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKGeryon.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKGeryon.HP
ENT.CollisionBounds = Vector( 160, 160, 340 )
ENT.SurroundingBounds = Vector( 2048, 2048, 2048 )

ENT.Flying = true
ENT.FlyingHeight = 300

ENT.AISight = false
ENT.MeleeAttackRange = 0
ENT.ReachEnemyRange = UKGeryon.ORBIT_MIN
ENT.AvoidEnemyRange = 0
ENT.Acceleration = 1800
ENT.Deceleration = 1800
ENT.JumpHeight = 0
ENT.StepHeight = 0
ENT.MaxYawRate = 160          -- canon yaw chase is 8x angle/s, soft-capped here
ENT.DeathDropHeight = math.huge
ENT.UseWalkframes = false
ENT.WalkSpeed = UKGeryon.MOVE_SPEED
ENT.RunSpeed = UKGeryon.MOVE_SPEED
ENT.IdleAnimation = "Idle"; ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Idle"; ENT.WalkAnimRate = 1
ENT.RunAnimation = "Idle"; ENT.RunAnimRate = 1
ENT.JumpAnimation = "Idle"; ENT.JumpAnimRate = 1

ENT.RagdollOnDeath = false
ENT.IsUltrakillNextbot = true

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

-- always flying: base ApproachFlying controls, own orbit is gated while possessed
ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    offset = Vector( 0, 60, 170 ),
    distance = 550,
    eyepos = false

  },

  {

    offset = Vector( 30, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if Possessor:KeyDown( IN_BACK ) then

      self:UKG_PossessionAttack( 0 ) -- BowUp: bombardment on the lock-on (around self if none)

    else

      self:UKG_PossessionAttack( 1 ) -- BowForward: beam fan where the crosshair points

    end

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    self:UKG_PossessionAttack( 3 ) -- PalmProjectiles: magenta crosses at the lock-on

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    self:UKG_PossessionAttack( 2 ) -- WaveClap: radial shockwaves

  end } },

}

if SERVER then

  -- ---- lifecycle ------------------------------------------------------------

  function ENT:CustomInitialize()
    self:SetTurning( true )

    self.UKG_State = "idle"
    self.UKG_Heat = 0
    self.UKG_PrevAttacks = {}
    self.UKG_Cooldown = UKGeryon.START_COOLDOWN
    self.UKG_BlockerCD = 0
    self.UKG_ShieldTouchCD = {}
    self.UKG_Phase2 = false
    self.UKG_Stunned = false
    self.UKG_StunTime = 0
    self.UKG_MaxStunTime = 1
    self.UKG_OrbitDir = math.random() < 0.5 and 1 or -1
    self.UKG_OrbitDist = math.Rand( UKGeryon.ORBIT_MIN, UKGeryon.ORBIT_MAX )
    self.UKG_CrossRotation = 0
    self.UKG_CrossRotDir = 1
    self.UKG_LastThink = CurTime()

    self:SetParryable( false )
    self:SetNW2Float( "UKG_Heat", 0 )
    self:SetNW2Float( "UKG_StunFrac", 0 )
    self:SetNW2Bool( "UKG_Stunned", false )
    self:SetNW2Bool( "UKG_Enraged", false )
    self:SetNW2String( "UKG_Charge", "" )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    UltrakillBase.TraceSetPos( self, self:GetPos() + Vector( 0, 0, 200 ) )
    self:EmitSound( SND.Spawn, 90, 100, 1, CHAN_VOICE )
    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, UKGeryon.BOSS_TITLE, UKGeryon.BOSS_SPLITS, true )
    end
  end

  function ENT:UKG_Difficulty()
    return UKGeryon.GetDifficulty( self )
  end

  -- canon anim.speed (0.7..1.2, x1.25 in phase 2)
  function ENT:UKG_AnimSpeed()
    local s = UKGeryon.ANIM_SPEED[ self:UKG_Difficulty() ] or 1
    if self.UKG_Phase2 then s = s * UKGeryon.PHASE2_ANIM_MULT end
    return s
  end

  function ENT:UKG_MaxHeat()
    return ( UKGeryon.MAX_HEAT[ self:UKG_Difficulty() ] or 5 )
      + ( self.UKG_Phase2 and UKGeryon.PHASE2_EXTRA_HEAT or 0 )
  end

  local CV_IGNOREPLY = GetConVar( "ai_ignoreplayers" )

  function ENT:UKG_GetEnemy()
    local enemy = self:GetEnemy()
    if IsValid( enemy ) then return enemy end
    -- possessed: GetEnemy() already resolves to the possessor's lock-on; the
    -- player scan below would pick the possessor's own parked body as a target
    if self:IsPossessed() then return nil end
    -- fallback-скан игроков ОБЯЗАН уважать ai_ignoreplayers (DrGBase-опция
    -- "ignore players"), иначе бот атакует вопреки настройке
    if CV_IGNOREPLY and CV_IGNOREPLY:GetBool() then return nil end
    local closest, cdist = nil, math.huge
    for _, ply in ipairs( player.GetAll() ) do
      if ply:Alive() and not ply.UltrakillBase_Friendly then
        local d = self:GetPos():DistToSqr( ply:GetPos() )
        if d < cdist then closest = ply; cdist = d end
      end
    end
    return closest
  end

  -- ---- clip player (canon Animator events) -----------------------------------

  function ENT:UKG_StartClip( name )
    local def = UKGeryon.CLIP[ name ]
    if not def then return end
    local seq = self:LookupSequence( def.seq )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( self:UKG_AnimSpeed() )
    end
    self.UKG_Clip = { name = name, def = def, start = CurTime(),
                      speed = self:UKG_AnimSpeed(), evIdx = 1 }
  end

  function ENT:UKG_StopClip()
    self.UKG_Clip = nil
    self:SetPlaybackRate( 1 )
    local idle = self:LookupSequence( "Idle" )
    if idle and idle >= 0 then self:ResetSequence( idle ) end
  end

  -- dispatches due clip events; ends the clip after its (scaled) length
  function ENT:UKG_TickClip()
    local clip = self.UKG_Clip
    if not clip then return end
    local t = ( CurTime() - clip.start ) * clip.speed
    local evs = clip.def.events
    while clip.evIdx <= #evs do
      local ev = evs[ clip.evIdx ]
      if t < ev[ 1 ] then break end
      clip.evIdx = clip.evIdx + 1
      local fn = self[ "UKG_Ev_" .. ev[ 2 ] ]
      if fn then fn( self, ev[ 3 ] ) end
      if self.UKG_Clip ~= clip then return end -- event switched the clip
    end
    if t >= clip.def.len then
      local name = clip.name
      self:UKG_StopClip()
      self:UKG_ClipFinished( name )
    end
  end

  function ENT:UKG_ClipFinished( name )
    if name == "StunStart" then
      -- loop the stunned pose until the stun timer runs out
      local seq = self:LookupSequence( "StunState" )
      if seq and seq >= 0 then
        self:ResetSequence( seq )
        self:SetPlaybackRate( self:UKG_AnimSpeed() )
      end
    elseif name == "StunStop" then
      self:UKG_EndAction()
    elseif self.UKG_State == "action" then
      -- safety: EndAction event should already have fired
      self:UKG_EndAction()
    end
  end

  -- ---- think ------------------------------------------------------------------

  function ENT:CustomThink()
    if self:Health() <= 0 or self.UKG_State == "dead" then return end
    -- ai_disabled / per-bot disable; possession must keep the clip event loop
    -- alive (DrGBase allows possessing bots while their AI is disabled)
    if self:IsAIDisabled() and not self:IsPossessed() then return end
    local now = CurTime()
    local dt = math.Clamp( now - ( self.UKG_LastThink or now ), 0, 0.2 )
    self.UKG_LastThink = now

    -- phase 2 (canon: below half HP, speed up + enrage effect on the heart)
    if not self.UKG_Phase2 and self:Health() <= self:GetMaxHealth() / 2 then
      self.UKG_Phase2 = true
      self:SetNW2Bool( "UKG_Enraged", true )
      self:EmitSound( SND.Laugh, 95, 100, 1, CHAN_VOICE )
    end

    self:UKG_TickClip()
    self:UKG_TickStun( dt )
    self:UKG_TickBlocker( dt )
    self:UKG_UpdateBossBar()

    -- possessed: the base CUSTOM flight moves/faces the boss and the binds
    -- start attacks; only the BowUp cooldown keeps draining
    if self:IsPossessed() then
      if self.UKG_State == "idle" and self.UKG_Cooldown > 0 then
        self.UKG_Cooldown = math.max( 0, self.UKG_Cooldown - dt )
      end
      return
    end

    self:UKG_Move( dt )

    if self.UKG_State == "idle" then
      if self.UKG_Cooldown > 0 then
        self.UKG_Cooldown = math.max( 0, self.UKG_Cooldown - dt )
      elseif IsValid( self:UKG_GetEnemy() ) then
        self:UKG_PickAttack()
      end
    end
  end

  -- Fully custom movement: suppress the base flying chase/idle handlers
  -- (they would fight the orbit and call LookTowards — Gutterman lesson).
  function ENT:OnChaseEnemy( enemy ) return true end
  function ENT:OnIdleEnemy( enemy ) return true end
  function ENT:OnAvoidEnemy( enemy ) return true end

  -- canon MoveUpdate: orbit + Y-match while idle, freeze while acting
  function ENT:UKG_Move( dt )
    local target = self:UKG_GetEnemy()
    if not IsValid( target ) then return end

    if IsValid( target ) then self:FaceTowards( target:GetPos() ) end

    if self.UKG_State ~= "idle" then
      -- canon: rb.velocity = zero during actions/stun
      self:ApproachFlying( self:GetPos(), 1 )
      return
    end

    local tpos = target:GetPos()
    local mypos = self:GetPos()
    local flat = Vector( tpos.x - mypos.x, tpos.y - mypos.y, 0 )
    local dist = flat:Length()
    if dist < 1 then return end
    local toC = flat / dist

    -- tangential orbit direction (canon: Quaternion.Euler(0, 90*dir, 0) * toCentre)
    local tang = Vector( -toC.y * self.UKG_OrbitDir, toC.x * self.UKG_OrbitDir, 0 )
    local goal = mypos + tang * 300

    -- keep the orbit ring [0.75r, 1.25r] (canon correction pull)
    if dist > self.UKG_OrbitDist * 1.25 then
      goal = goal + toC * ( dist - self.UKG_OrbitDist )
    elseif dist < self.UKG_OrbitDist * 0.75 then
      goal = goal - toC * ( self.UKG_OrbitDist - dist )
    end

    -- canon Y-match: chase the target's height (origin at body centre)
    goal.z = tpos.z + 200

    self:ApproachFlying( goal, 2 )
  end

  -- ---- attack picking (canon PickAttack) ----------------------------------------

  local ATTACKS = { "BowUp", "BowForward", "WaveClap", "PalmProjectiles" }

  function ENT:UKG_PickAttack()
    if self.UKG_Heat >= self:UKG_MaxHeat() then
      self.UKG_Heat = 0
      self:UKG_EnterStun()
      return
    end
    self.UKG_Heat = self.UKG_Heat + UKGeryon.HEAT_PER_ATTACK

    local num = math.random( 0, 3 )
    local function used( n )
      for _, v in ipairs( self.UKG_PrevAttacks ) do if v == n then return true end end
      return false
    end
    while used( num ) do
      num = num + 1
      if num >= 4 then num = 0 end
    end
    self:UKG_StartAttack( num )
  end

  function ENT:UKG_StartAttack( num )
    if #self.UKG_PrevAttacks > 1 then table.remove( self.UKG_PrevAttacks, 1 ) end
    table.insert( self.UKG_PrevAttacks, num )

    local kind = ATTACKS[ num + 1 ]
    self.UKG_State = "action"
    self:UKG_StartClip( kind )

    if kind == "BowUp" then
      self:EmitSound( SND.BowUp, 90, math.random( 90, 110 ), 1, CHAN_VOICE )
    elseif kind == "BowForward" then
      self:EmitSound( SND.BowForward, 90, math.random( 90, 110 ), 1, CHAN_VOICE )
    elseif kind == "WaveClap" then
      self:EmitSound( SND.WaveClap, 90, math.random( 90, 110 ), 1, CHAN_VOICE )
    elseif kind == "PalmProjectiles" then
      self.UKG_CrossRotation = 0
      self.UKG_CrossRotDir = math.random() < 0.5 and 1 or -1
      self:EmitSound( SND.Palm, 90, math.random( 90, 110 ), 1, CHAN_VOICE )
    end
  end

  -- possession bind entry: same idle/cooldown gate as the AI and the same
  -- overheat rule — spamming attacks past max heat opens the weak point
  function ENT:UKG_PossessionAttack( num )
    if self.UKG_State ~= "idle" or self.UKG_Cooldown > 0 then return end
    if self.UKG_Heat >= self:UKG_MaxHeat() then
      self.UKG_Heat = 0
      self:UKG_EnterStun()
      return
    end
    self.UKG_Heat = self.UKG_Heat + UKGeryon.HEAT_PER_ATTACK
    self:UKG_StartAttack( num )
  end

  function ENT:UKG_EndAction()
    self.UKG_State = "idle"
    self:SetNW2String( "UKG_Charge", "" )
    local last = self.UKG_PrevAttacks[ #self.UKG_PrevAttacks ]
    self.UKG_Cooldown = ( last == 0 ) and UKGeryon.BOWUP_COOLDOWN or 0
    self.UKG_OrbitDir = math.random() < 0.5 and 1 or -1
    self.UKG_OrbitDist = math.Rand( UKGeryon.ORBIT_MIN, UKGeryon.ORBIT_MAX )
  end

  -- ---- attachment helpers --------------------------------------------------------

  function ENT:UKG_AttachPos( name )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter()
  end

  -- ---- clip event handlers (canon Animator event functions) -----------------------

  function ENT:UKG_Ev_BowCharge()
    self:SetNW2String( "UKG_Charge", "bow" )
    self:EmitSound( SND.ArrowShort, 80, 100, 0.8 )
  end

  function ENT:UKG_Ev_BowUpShoot()
    self:SetNW2String( "UKG_Charge", "" )
    self:EmitSound( SND.ArrowLong, 95, 100, 1 )
    util.ScreenShake( self:GetPos(), 8, 40, 1, 2000 )

    local target = self:UKG_GetEnemy()
    local center = IsValid( target ) and target:GetPos() or self:GetPos()
    -- canon: Invoke("BowUpSpawnBeams", 1) + 0.25 s realtime gaps
    for i = 0, UKGeryon.BOWUP_BEAMS - 1 do
      timer.Simple( UKGeryon.BOWUP_SPAWN_DELAY + i * UKGeryon.BOWUP_BEAM_GAP, function()
        if not IsValid( self ) or self:Health() <= 0 then return end
        local t = self:UKG_GetEnemy()
        local pos
        if i == 0 and IsValid( t ) then
          pos = t:GetPos() -- canon: first beam right on the target
        else
          local ang = math.Rand( 0, 360 )
          local r = math.Rand( 0, UKGeryon.BOWUP_SPREAD )
          pos = center + Vector( math.cos( ang ) * r, math.sin( ang ) * r, 0 )
        end
        self:UKG_SpawnPillar( pos, "up" )
      end )
    end
  end

  function ENT:UKG_Ev_BowForwardShoot( shotNumber )
    self:EmitSound( SND.Beam, 92, math.random( 95, 105 ), 1 )
    util.ScreenShake( self:GetPos(), 3, 30, 0.5, 1500 )

    local num = shotNumber
    if self:UKG_Difficulty() >= 4 then num = num + UKGeryon.BOWFWD_BRUTAL_EXTRA end

    local fwd = self:GetForward()
    fwd.z = 0
    fwd:Normalize()
    local from = self:UKG_AttachPos( "bow" )
    for i = 0, num - 1 do
      local deg = 0
      if num > 1 then
        deg = Lerp( i / ( num - 1 ), UKGeryon.BOWFWD_FAN_DEG, -UKGeryon.BOWFWD_FAN_DEG )
      end
      local dir = Angle( 0, fwd:Angle().y + deg, 0 ):Forward()
      local pos = Vector( from.x, from.y, self:GetPos().z )
      self:UKG_SpawnPillar( pos + dir * 100, "forward", dir )
    end
    if shotNumber == 3 then self:SetNW2String( "UKG_Charge", "" ) end
  end

  function ENT:UKG_SpawnPillar( pos, mode, dir )
    local pillar = ents.Create( UKGeryon.CLASS.Pillar )
    if not IsValid( pillar ) then return end
    pillar:SetPos( pos )
    if dir then pillar:SetAngles( dir:Angle() ) end
    pillar:SetOwner( self )
    pillar:SetNW2String( "UKG_Mode", mode )
    pillar:Spawn()
  end

  function ENT:UKG_Ev_WaveClapCharge()
    self:SetNW2String( "UKG_Charge", "clap" )
  end

  function ENT:UKG_Ev_WaveClapChargeFreeze()
    -- canon: the charge orb stops following the hands (visual only)
  end

  function ENT:UKG_Ev_WaveClapShoot()
    self:SetNW2String( "UKG_Charge", "" )
    self:EmitSound( SND.Clap, 100, 100, 1 )
    util.ScreenShake( self:GetPos(), 10, 40, 1, 3000 )

    local base = self:WorldSpaceCenter()
    -- canon: three shockwaves at speeds 50/(j+1), shuffled Y offsets 0/+20/-20 m
    local offsets = { 0, UKGeryon.CLAP_Y_OFFSET, -UKGeryon.CLAP_Y_OFFSET }
    for i = #offsets, 2, -1 do
      local j = math.random( i )
      offsets[ i ], offsets[ j ] = offsets[ j ], offsets[ i ]
    end
    for j = 0, UKGeryon.CLAP_WAVES - 1 do
      local wave = ents.Create( UKGeryon.CLASS.Wave )
      if IsValid( wave ) then
        wave:SetPos( base + Vector( 0, 0, offsets[ j + 1 ] ) )
        wave:SetOwner( self )
        wave:SetNW2String( "UKG_Mode", "ring" )
        wave:SetNW2Float( "UKG_Speed", UKGeryon.CLAP_SPEED / ( j + 1 ) )
        wave:Spawn()
      end
    end
  end

  function ENT:UKG_Ev_PalmProjectileCharge()
    self:SetNW2String( "UKG_Charge", "palm" )
  end

  function ENT:UKG_Ev_PalmProjectileShoot( hand )
    self:UKG_FireCross( hand, self.UKG_CrossRotation, 1, 0 )
    self.UKG_CrossRotation = self.UKG_CrossRotation
      + UKGeryon.CROSS_STEP_DEG * self.UKG_CrossRotDir
  end

  function ENT:UKG_Ev_PalmProjectileShootBoth()
    self:SetNW2String( "UKG_Charge", "" )
    local spin2 = self:UKG_Difficulty() >= 4
      and -UKGeryon.CROSS_BOTH_SPIN or UKGeryon.CROSS_BOTH_SPIN
    self:UKG_FireCross( 0, 0, UKGeryon.CROSS_BOTH_SPEED_MULT, UKGeryon.CROSS_BOTH_SPIN )
    self:UKG_FireCross( 1, 45, UKGeryon.CROSS_BOTH_SPEED_MULT, spin2 )
  end

  function ENT:UKG_FireCross( hand, rollDeg, speedMult, spin )
    local from = self:UKG_AttachPos( hand == 0 and "lefthand" or "righthand" )
    local target = self:UKG_GetEnemy()
    local aim = self:GetForward()
    if IsValid( target ) then
      aim = ( target:WorldSpaceCenter() - from ):GetNormalized()
    end

    local proj = ents.Create( UKGeryon.CLASS.Cross )
    if not IsValid( proj ) then return end
    local ang = aim:Angle()
    ang:RotateAroundAxis( aim, rollDeg )
    proj:SetPos( from + aim * 40 )
    proj:SetAngles( ang )
    proj:SetOwner( self )
    proj:SetNW2Float( "UKG_Spin", spin * -self.UKG_CrossRotDir )
    proj:Spawn()

    local speed = UKGeryon.CROSS_SPEED * speedMult
    if self:UKG_Difficulty() >= 3 then speed = speed * UKGeryon.CROSS_VIOLENT_SPEED end
    proj:SetVelocity( aim * speed )
  end

  function ENT:UKG_Ev_DustHands()
    local pos = ( self:UKG_AttachPos( "lefthand" ) + self:UKG_AttachPos( "righthand" ) ) / 2
    local ed = EffectData()
    ed:SetOrigin( pos )
    ed:SetScale( 4 )
    util.Effect( "ThumperDust", ed )
  end

  function ENT:UKG_Ev_SkipRecovery()
    -- canon: in phase 2 the attack recovery is cancelled (attacks overlap)
    if self.UKG_Phase2 and self.UKG_State == "action" then
      self:UKG_StopClip()
      self:UKG_EndAction()
    end
  end

  function ENT:UKG_Ev_EndAction()
    if self.UKG_State == "action" then
      self:UKG_StopClip()
      self:UKG_EndAction()
    end
  end

  -- ---- stun (canon overheat) -----------------------------------------------------

  function ENT:UKG_EnterStun()
    self.UKG_State = "stun"
    self.UKG_Stunned = false -- becomes true at HeadOpen
    local st = UKGeryon.STUN_TIME[ self:UKG_Difficulty() ] or 7
    self.UKG_StunTime = st
    self.UKG_MaxStunTime = st
    self:SetNW2Bool( "UKG_Stunned", true )
    self:UKG_StartClip( "StunStart" )
    self:EmitSound( SND.BigHurt, 95, 100, 1, CHAN_VOICE )

    -- canon: 3x HeadHort blood bursts on entering the stun
    for i = 0, 2 do
      timer.Simple( i * 0.5, function()
        if not IsValid( self ) or self:Health() <= 0 then return end
        local ed = EffectData()
        ed:SetOrigin( self:UKG_AttachPos( "weakpoint" ) + VectorRand() * 25 )
        util.Effect( "BloodImpact", ed )
      end )
    end
  end

  function ENT:UKG_Ev_HeadOpen()
    self.UKG_Stunned = true
  end

  function ENT:UKG_TickStun( dt )
    if self.UKG_State ~= "stun" or not self.UKG_Stunned then return end

    -- canon: DoT 2 hp/s (scaled by pack convention) while the head is open
    local dot = DamageInfo()
    dot:SetDamage( UKGeryon.STUN_DOT * 1000 * dt )
    dot:SetDamageType( DMG_BURN )
    dot:SetAttacker( self )
    dot:SetInflictor( self )
    self:TakeDamageInfo( dot )

    local drain = self.UKG_Phase2 and UKGeryon.PHASE2_STUN_DRAIN or 1
    self.UKG_StunTime = math.max( 0, self.UKG_StunTime - dt * drain )
    if self.UKG_StunTime <= 0 then
      self:UKG_Unstun()
    end
  end

  function ENT:UKG_Unstun()
    self.UKG_Stunned = false
    self:EmitSound( SND.Recovery, 90, 100, 1, CHAN_VOICE )
    self:UKG_StartClip( "StunStop" )
  end

  function ENT:UKG_Ev_UnstunClose()
    self:SetNW2Bool( "UKG_Stunned", false )
    self:SetNW2Float( "UKG_StunFrac", 0 )
    -- canon Recover Blast: harmless but huge knockback
    local wave = ents.Create( UKGeryon.CLASS.Wave )
    if IsValid( wave ) then
      wave:SetPos( self:GetPos() + self:GetForward() * UKGeryon.SHIELD_FWD )
      wave:SetOwner( self )
      wave:SetNW2String( "UKG_Mode", "pushback" )
      wave:Spawn()
    end
    self.UKG_BlockerCD = UKGeryon.BLOCKER_CD
  end

  function ENT:UKG_Ev_StopAction()
    -- handled by UKG_ClipFinished("StunStop") -> UKG_EndAction
  end

  -- ---- Green Explosion / PlayerBlocker (canon multi-consciousness defence) --------

  function ENT:UKG_ShieldPos()
    return self:GetPos() + self:GetForward() * UKGeryon.SHIELD_FWD
      + Vector( 0, 0, -1.25 * UNIT )
  end

  function ENT:UKG_TickBlocker( dt )
    if self.UKG_BlockerCD > 0 then
      self.UKG_BlockerCD = math.max( 0, self.UKG_BlockerCD - dt )
    end
    if self.UKG_State == "stun" then return end
    if self.UKG_Heat >= self:UKG_MaxHeat() then return end -- canon: not in max heat

    local spos = self:UKG_ShieldPos()

    -- shield contact (canon HurtZone: 10 dmg + bounce 350, 1 s cooldown)
    for _, ply in ipairs( player.GetAll() ) do
      if not ply:Alive() or ply.UltrakillBase_Friendly then continue end
      local d = spos:Distance( ply:WorldSpaceCenter() )
      if d < 17.5 * UNIT * 0.55 then
        local cd = self.UKG_ShieldTouchCD[ ply ]
        if not cd or cd <= CurTime() then
          self.UKG_ShieldTouchCD[ ply ] = CurTime() + UKGeryon.SHIELD_TOUCH_CD
          local dmg = DamageInfo()
          dmg:SetDamage( UKGeryon.ScaleAttackDamage( ply, UKGeryon.SHIELD_TOUCH_DAMAGE ) )
          dmg:SetDamageType( DMG_SHOCK )
          dmg:SetAttacker( self )
          dmg:SetInflictor( self )
          ply:TakeDamageInfo( dmg )
          local push = ( ply:WorldSpaceCenter() - spos ):GetNormalized()
          ply:SetVelocity( push * UKGeryon.SHIELD_BOUNCE * 2 )
        end
      end
    end

    if self.UKG_BlockerCD > 0 then return end
    -- the proximity blast is an AI decision (and adds heat) — player-started
    -- attacks only while possessed; the shield contact damage above stays
    if self:IsPossessed() then return end
    local target = self:UKG_GetEnemy()
    if not IsValid( target ) then return end
    if spos:Distance( target:WorldSpaceCenter() ) >= UKGeryon.BLOCKER_RANGE then return end

    -- canon: proximity explosion counts as an action towards the overheat
    self.UKG_BlockerCD = UKGeryon.BLOCKER_CD
    self.UKG_Heat = self.UKG_Heat + UKGeryon.HEAT_PER_ATTACK
    local blast = ents.Create( UKGeryon.CLASS.Wave )
    if IsValid( blast ) then
      blast:SetPos( spos )
      blast:SetOwner( self )
      blast:SetNW2String( "UKG_Mode", "green" )
      blast:Spawn()
    end
  end

  -- ---- boss bar (canon UpdateBossBar: heat meter / stun timer) ---------------------

  function ENT:UKG_UpdateBossBar()
    if self.UKG_State == "stun" and self.UKG_Stunned then
      self:SetNW2Float( "UKG_StunFrac", self.UKG_StunTime / self.UKG_MaxStunTime )
    else
      self:SetNW2Float( "UKG_Heat",
        math.Clamp( self.UKG_Heat / self:UKG_MaxHeat(), 0, 1 ) )
    end
  end

  -- ---- damage ---------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKG_State == "stun" and self.UKG_Stunned then
      -- canon HeadOpen: totalDamageTakenMultiplier 0.66, weak point exposed
      dmg:ScaleDamage( UKGeryon.STUN_DMG_TAKEN )
      if hitgroup == HITGROUP_HEAD then
        dmg:ScaleDamage( UKGeryon.WEAKPOINT_MULT )
      end
    elseif hitgroup == HITGROUP_HEAD then
      -- wiki: head 200% (the weak point drives locational damage)
      dmg:ScaleDamage( UKGeryon.WEAKPOINT_MULT )
    end
    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  -- ---- death (canon Death: play the clip, no ragdoll) -------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKG_State = "dead"
    self:SetNW2String( "UKG_Charge", "" )
    self:SetNW2Bool( "UKG_Stunned", false )
    self:EmitSound( SND.Death, 100, 100, 1, CHAN_VOICE )
    if UltrakillBase.RemoveBoss then UltrakillBase.RemoveBoss( self ) end

    self:UKG_StopClip()
    local seq = self:LookupSequence( "Death" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end

    local deadline = CurTime() + UKGeryon.CLIP.Death.len
    while IsValid( self ) and CurTime() < deadline do
      self:YieldCoroutine()
    end
    if not IsValid( self ) then return dmg end

    local seq2 = self:LookupSequence( "DeathEnd" )
    if seq2 and seq2 >= 0 then self:ResetSequence( seq2 ) end
    local fade = CurTime() + 2.5
    while IsValid( self ) and CurTime() < fade do
      self:YieldCoroutine()
    end
    if IsValid( self ) then
      local ed = EffectData()
      ed:SetOrigin( self:WorldSpaceCenter() )
      util.Effect( "Explosion", ed )
      self:Remove()
    end
    return dmg
  end

end

if CLIENT then

  local MAGENTA = UKGeryon.MAGENTA
  local GREEN = UKGeryon.GREEN
  local ORANGE = UKGeryon.ORANGE
  local BLUE = UKGeryon.BLUE
  local MAT_GLOW = Material( "sprites/light_glow02_add" )

  -- canon boss bar secondary: heat meter (green/yellow/orange/red) or the
  -- stun timer flashing red/black while stunned
  function ENT:GetSecondaryBarValues()
    if self:GetNW2Bool( "UKG_Stunned", false ) then
      local flash = math.floor( CurTime() * 5 ) % 2 == 0
      return self:GetNW2Float( "UKG_StunFrac", 0 ),
        flash and Color( 255, 0, 0 ) or Color( 0, 0, 0 )
    end
    local heat = self:GetNW2Float( "UKG_Heat", 0 )
    local col
    if heat <= 0.33 then col = Color( 0, 255, 0 )
    elseif heat <= 0.66 then col = Color( 255, 255, 0 )
    elseif heat < 1 then col = Color( 255, 90, 0 )
    else col = Color( 255, 0, 0 ) end
    return heat, col
  end

  local function chargeGlow( pos, col, size )
    render.SetMaterial( MAT_GLOW )
    local f = 0.7 + 0.3 * math.sin( CurTime() * 18 )
    render.DrawSprite( pos, size * f, size * f, Color( col.r, col.g, col.b, 200 ) )
    render.DrawSprite( pos, size * 0.4, size * 0.4, Color( 255, 255, 255, 230 ) )
  end

  function ENT:UKG_ClientAttach( name )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter()
  end

  function ENT:Draw()
    self:DrawModel()

    local charge = self:GetNW2String( "UKG_Charge", "" )
    if charge == "bow" then
      chargeGlow( self:UKG_ClientAttach( "bow" ), ORANGE, 120 )
    elseif charge == "clap" then
      local pos = ( self:UKG_ClientAttach( "lefthand" )
        + self:UKG_ClientAttach( "righthand" ) ) / 2
      chargeGlow( pos, MAGENTA, 160 )
    elseif charge == "palm" then
      chargeGlow( self:UKG_ClientAttach( "lefthand" ), MAGENTA, 100 )
      chargeGlow( self:UKG_ClientAttach( "righthand" ), MAGENTA, 100 )
    end

    -- stunned: the chest weak point glows invitingly
    if self:GetNW2Bool( "UKG_Stunned", false ) then
      local pos = self:UKG_ClientAttach( "weakpoint" )
      local f = 0.6 + 0.4 * math.sin( CurTime() * 8 )
      render.SetMaterial( MAT_GLOW )
      render.DrawSprite( pos, 180 * f, 180 * f, Color( 255, 60, 60, 190 ) )
      render.DrawSprite( pos, 70, 70, Color( 255, 220, 200, 230 ) )
    elseif self:GetNW2Bool( "UKG_Enraged", false ) then
      local pos = self:UKG_ClientAttach( "weakpoint" )
      render.SetMaterial( MAT_GLOW )
      render.DrawSprite( pos, 90, 90, Color( 255, 40, 40, 120 ) )
    end
  end

end

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_geryon", {
  Name = ENT.PrintName,
  Class = "ultrakill_test_geryon",
  Category = ENT.Category,
  AdminOnly = false,
} )
