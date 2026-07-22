-- lua/entities/ultrakill_test_mdk.lua
-- Mysterious Druid Knight (& Owl) — canon-faithful port of the 4-3 secret boss.
-- Drone-type flying enemy (Drone.cs, EnemyType.Mandalore) + Mandalore.cs attack
-- loop: Full Auto / Fuller Auto pendulum, 4 фазы c войсами, suicide dive on
-- death (отдельная сущность ultrakill_test_mdk_crash).

AddCSLuaFile()

if not UKMDK then include( "autorun/ultrakill_test_mdk_shared.lua" ) end

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )

if CLIENT then
  util.PrecacheModel( UKMDK.MODEL )
end

ENT.Type        = "nextbot"
ENT.Base        = "ultrakillbase_nextbot"
ENT.PrintName   = "Mysterious Druid Knight (& Owl)"
ENT.Author      = "ultragmod"
ENT.Spawnable   = true
ENT.Category    = "ULTRAKILL - Secrets"

ENT.Models      = { UKMDK.MODEL }
ENT.ModelScale  = UKMDK.SCALE
ENT.SpawnHealth = UKMDK.HP
-- canon root BoxCollider: 1 x 2.5 x 5 m (вытянут по forward — модель летит
-- "супермэном"); nextbot-бокс симметричный: ширина/высота x UKMDK.SCALE.
ENT.CollisionBounds   = Vector( 40, 40, 101 ) * UKMDK.SCALE
ENT.SurroundingBounds = Vector( 512, 512, 512 )
ENT.UltrakillBase_WeightClass = "Medium" -- canon (ultrakill.wiki.gg/wiki/Enemies)

ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }

-- DrGBase Flying (паттерн Virtue).
ENT.Flying           = true
ENT.FlyingHeight     = 100

ENT.AISight          = false
ENT.MeleeAttackRange = 10000
ENT.ReachEnemyRange  = UKMDK.PREFERRED_DIST
ENT.AvoidEnemyRange  = 0   -- канонный back-off делаем сами (UKMDK_Move)
ENT.Acceleration     = UKMDK.ACCEL
ENT.Deceleration     = UKMDK.DECEL
ENT.JumpHeight       = 0
ENT.StepHeight       = 0
ENT.MaxYawRate       = 400
ENT.DeathDropHeight  = math.huge
ENT.UseWalkframes    = false
ENT.WalkSpeed        = UKMDK.MOVE_SPEED
ENT.RunSpeed         = UKMDK.MOVE_SPEED
ENT.IdleAnimation    = "Idle"; ENT.IdleAnimRate = 1
ENT.WalkAnimation    = "Idle"; ENT.WalkAnimRate = 1
ENT.RunAnimation     = "Idle"; ENT.RunAnimRate  = 1
ENT.JumpAnimation    = "Idle"; ENT.JumpAnimRate = 1

ENT.UKMDK_IsMDK = true

-- Наведение корпусом на цель (canon Drone.cs: LookRotation по viewTarget,
-- в т.ч. питч когда игрок под ним) — штатная FullTracking-система базы,
-- как у ultrakill_drone: манипуляция root-кости по питчу аима.
ENT.UltrakillBase_FullTrackingBone = "Mandalore"
ENT.UltrakillBase_FullTracking     = true

-- canon Death Restart Quotes = таунты (реплики при рестарте файта, как у
-- прайм-душ: играются когда ранее убитый игрок возвращается).
ENT.UltrakillBase_RestartVoiceLine = {
  "Ultrakill_MDK_Taunt1", "Ultrakill_MDK_Taunt2",
  "Ultrakill_MDK_Taunt3", "Ultrakill_MDK_Taunt4",
}

ENT.NW_PHASE = "UKMDK_Phase"   -- 1..4

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    offset = Vector( 0, 12, 36 ),
    distance = 120,
    eyepos = false

  },

  {

    offset = Vector( 6, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- UKMDK_NextAttack is the AI's pacing BETWEEN attacks (seconds): gating
    -- on it turned a held button into sparse single bursts. This only starts
    -- the announced burst; held fire lives in UKMDK_TickPossessionFire.
    if CurTime() < self.UKMDK_TalkingUntil then return end
    if CurTime() < ( self.UKMDK_PossFireEnd or 0 ) then return end

    self:UKMDK_PossessionFullAuto()

  end } },

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if CurTime() < self.UKMDK_NextAttack or CurTime() < self.UKMDK_TalkingUntil then return end

    -- no lock-on required: each seeker resolves its target at spawn time
    -- (lock-on -> entity under the crosshair -> straight free-aim shot)
    self:UKMDK_FullerAuto( self:PossessionGetLockedOn() )

  end } },

  [ IN_RELOAD ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self:GetCooldown( "MDK_Possession_Taunt" ) > 0 or CurTime() < self.UKMDK_TalkingUntil then return end

    self:UKMDK_Speak( UKMDK.VOICE.taunts[ math.random( #UKMDK.VOICE.taunts ) ] )

    self:SetCooldown( "MDK_Possession_Taunt", 3 )

  end } },

  [ IN_JUMP ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self:GetCooldown( "MDK_Possession_Dash" ) > 0 then return end

    self:UKMDK_Dash( Possessor:KeyDown( IN_BACK ) and -self:PossessorForward() or self:PossessorForward() )

    self:SetCooldown( "MDK_Possession_Dash", 0.5 )

  end } },

}

if SERVER then

  function ENT:CustomInitialize()
    self:SetFullTracking( true )
    self:SetTurning( true )

    self:SetAcceleration( UKMDK.ACCEL )

    self.UKMDK_Phase        = 1
    self.UKMDK_FullerChance = 0
    self.UKMDK_NextAttack   = CurTime() + UKMDK.ATTACK_CD_INITIAL
    self.UKMDK_TalkingUntil = 0
    self.UKMDK_DodgeCD      = math.Rand( 0.5, UKMDK.DODGE_CD_MAX )
    self.UKMDK_LastVoices   = {}
    self.UKMDK_LastEvade    = 0

    self:SetNW2Int( self.NW_PHASE, 1 )
    self:SetSandable( true )   -- canon: Sandify() в фазе 4

    -- босс-бар: свой рендер с канонными цветами слоёв
    -- (autorun/client/ultrakill_mdk_hud.lua), AddBoss базы не используем.

    -- Спавн-реплика ВСЕГДА интро энкаунтера ("Finally, our waiting puzzle is
    -- over" / "What?"); 4 таунта — это Death Restart Quotes (RestartVoiceLine).
    self:Timer( 0.5, function( self )
      self:UKMDK_Speak( UKMDK.VOICE.intro )
    end )
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    UltrakillBase.TraceSetPos( self, self:GetPos() + Vector( 0, 0, 80 ) )
  end

  -- Реплики через VoiceScript-систему пака (сабтитры + приоритетное
  -- перебивание, как у прайм-душ). Второй голос пары (secondary) играет
  -- одновременно обычным EmitSound; при новой реплике его глушим вручную
  -- (canon MandaloreVoice: aud.Stop() + PlayOneShot).
  function ENT:UKMDK_Speak( entry )
    if not entry then return end
    for _, snd in ipairs( self.UKMDK_LastVoices ) do self:StopSound( snd ) end
    self.UKMDK_LastVoices = {}
    UltrakillBase.SoundScript( entry.script, self:GetPos(), self )
    if entry.secondary then
      self:EmitSound( entry.secondary, 90, 100, 1, CHAN_VOICE2 )
      table.insert( self.UKMDK_LastVoices, entry.secondary )
    end
    self.UKMDK_TalkingUntil = math.max( self.UKMDK_TalkingUntil, CurTime() + ( entry.dur or 2 ) )
  end

  local CV_IGNOREPLY = GetConVar( "ai_ignoreplayers" )

  function ENT:UKMDK_GetEnemy()
    local enemy = self:GetEnemy()
    if IsValid( enemy ) then return enemy end
    -- possessed: GetEnemy() is already the lock-on; the free player scan
    -- below would otherwise pick the possessor itself
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

  function ENT:CustomThink()
    if self:Health() <= 0 then return end
    if self:IsAIDisabled() then return end   -- ai_disabled / per-bot disable
    local now = CurTime()
    local dt = math.Clamp( now - ( self.UKMDK_LastThink or now ), 0, 0.2 )
    self.UKMDK_LastThink = now
    self:UKMDK_TickPhases()
    if self:IsPossessed() then
      -- possessor drives attacks/dodges/steering; phases keep running and
      -- UKMDK_Move stays on for the dash-burst executor (IN_JUMP bind)
      self:UKMDK_Move( dt )
      self:UKMDK_TickPossessionFire()
      return
    end
    self:UKMDK_TickAttack()
    self:UKMDK_TickDodge( dt )
    self:UKMDK_Move( dt )
  end

  -- Движение полностью своё (канон Drone.ProcessTargeting): базовые
  -- chase/avoid/idle-хэндлеры глушим, иначе их path-following каждый тик
  -- перерулит наш стиринг (урок: одиночный loco-импульс жил один тик —
  -- отсюда «сантиметровые рывки»).
  function ENT:OnChaseEnemy( enemy ) return true end
  function ENT:OnAvoidEnemy( enemy ) return true end
  function ENT:OnIdleEnemy( enemy ) return true end

  -- Босс в основном висит; перемещение — рывками (UKMDK_TickDodge). К цели
  -- лишь медленно дрейфует когда дальше 15 м, ближе 5 м — рывок назад.
  function ENT:UKMDK_Move( dt )
    local target = self:UKMDK_GetEnemy()

    if self.UKMDK_DodgeUntil and CurTime() < self.UKMDK_DodgeUntil then
      self:SetDesiredSpeed( UKMDK.DODGE_SPEED )
      self:SetAcceleration( UKMDK.DODGE_ACCEL )
      self:ApproachFlying( self:GetPos() + self.UKMDK_DodgeDir * 100, 2 )
      if IsValid( target ) and not self:IsPossessed() then
        self:FaceTowards( target:GetPos() )
        self:AimTowards( target )
      end
      return
    end
    self:SetAcceleration( UKMDK.ACCEL )

    if self:IsPossessed() then
      -- flight is done by the base PossessionControls (ApproachFlying along
      -- the possessor aim); restore cruise speed after dash bursts and keep
      -- the FullTracking bone pitched at the crosshair
      self:SetDesiredSpeed( UKMDK.MOVE_SPEED )
      self:AimTowards( self:PossessorTrace().HitPos )
      return
    end

    if not IsValid( target ) then return end
    self:FaceTowards( target:GetPos() )
    -- Питч слежения: GetAimAngles() обновляется ТОЛЬКО через AimTowards —
    -- без него FullTracking-кость вечно держит углы спавна (паттерн
    -- Providence r8: FaceTowards = yaw корпуса, AimTowards = питч кости).
    self:AimTowards( target )
    self:SetDesiredSpeed( UKMDK.MOVE_SPEED )

    local goal = target:WorldSpaceCenter()
    local dist = self:GetPos():Distance( goal )
    if dist > UKMDK.PREFERRED_DIST then
      self:ApproachFlying( goal, 1 )
    elseif dist < UKMDK.BACKOFF_DIST
      and ( self.UKMDK_NextBackoff or 0 ) <= CurTime() then
      self.UKMDK_NextBackoff = CurTime() + UKMDK.BACKOFF_CD
      self:UKMDK_Dash( ( self:GetPos() - goal ):GetNormalized() )
    end
  end

  -- canon Update(): переходы фаз только когда голоса молчат; проверка сверху
  -- вниз (4 -> 3 -> 2), т.е. при быстром уроне фазы можно перескочить.
  -- Фаза 3 = штатное Enraged-состояние базы (RageEffect + молнии),
  -- фаза 4 = штатное Sand() (песчаный взрыв + Sand-материал + drip-партиклы).
  function ENT:UKMDK_TickPhases()
    if CurTime() < self.UKMDK_TalkingUntil then return end
    local frac = self:Health() / self:GetMaxHealth()
    local phase = self.UKMDK_Phase
    if phase < 4 and frac < UKMDK.PHASE4_FRAC then
      self.UKMDK_Phase = 4
      self:SetNW2Int( self.NW_PHASE, 4 )
      self:UKMDK_Speak( UKMDK.VOICE.phase4 )   -- "Use the salt!" / "I'm reaching!"
      self:Timer( UKMDK.SANDIFY_DELAY, function( self )
        self:Sand()                            -- canon eid.Sandify()
      end )
    elseif phase < 3 and frac < UKMDK.PHASE3_FRAC then
      self.UKMDK_Phase = 3
      self:SetNW2Int( self.NW_PHASE, 3 )
      self:SetEnraged( true )                  -- canon: Enraged status effect
      self:CreateEnrage( 1, 1.5 )
      -- канон: звук встроен в enrageEffect-префаб; в базе — отдельные скрипты
      -- (рецепт Cerberus). Луп глохнет сам через SOUND_EnrageFunction.
      UltrakillBase.SoundScript( "Ultrakill_Enrage", self:GetPos(), self )
      UltrakillBase.SoundScript( "Ultrakill_Enrage_Loop", self:GetPos(), self )
      self:UKMDK_Speak( UKMDK.VOICE.phase3 )   -- "Feel my maximum speed!" / "Slow down"
    elseif phase < 2 and frac < UKMDK.PHASE2_FRAC then
      self.UKMDK_Phase = 2
      self:SetNW2Int( self.NW_PHASE, 2 )
      self:UKMDK_Speak( UKMDK.VOICE.phase2 )   -- "Through the magic of the Druids..."
    end
  end

  -- canon: cooldown тикает всегда, атака только когда голоса молчат.
  function ENT:UKMDK_TickAttack()
    if CurTime() < self.UKMDK_NextAttack then return end
    if CurTime() < self.UKMDK_TalkingUntil then return end
    local target = self:UKMDK_GetEnemy()
    if not IsValid( target ) then return end

    if math.random() > self.UKMDK_FullerChance then
      self:UKMDK_FullAuto( target )
    else
      self:UKMDK_FullerAuto( target )
    end
  end

  function ENT:UKMDK_FullAuto( target )
    self.UKMDK_FullerChance = math.max( 0.5, self.UKMDK_FullerChance ) + 0.2
    self.UKMDK_NextAttack = CurTime() + ( UKMDK.FULL_CD[ self.UKMDK_Phase ] or 2.5 )
    self:UKMDK_Speak( UKMDK.VOICE.fullauto )    -- "Full auto"

    for v = 0, UKMDK.FULL_VOLLEYS - 1 do
      self:Timer( UKMDK.ATTACK_WINDUP + v * UKMDK.FULL_VOLLEY_INTERVAL, function( self )
        if self:Health() <= 0 then return end
        self:UKMDK_SpawnVolley( target )
      end )
    end
  end

  -- Possession Full Auto: same canon burst as UKMDK_FullAuto but without the
  -- AI pacing cooldown / pendulum bookkeeping; while IN_ATTACK stays held,
  -- UKMDK_TickPossessionFire extends the volley chain at the burst's own
  -- canon rate instead of restarting whole attacks.
  function ENT:UKMDK_PossessionFullAuto()
    self:UKMDK_Speak( UKMDK.VOICE.fullauto )
    -- time of the volley that would follow the last scheduled one
    self.UKMDK_PossFireEnd = CurTime() + UKMDK.ATTACK_WINDUP
      + UKMDK.FULL_VOLLEYS * UKMDK.FULL_VOLLEY_INTERVAL

    for v = 0, UKMDK.FULL_VOLLEYS - 1 do
      self:Timer( UKMDK.ATTACK_WINDUP + v * UKMDK.FULL_VOLLEY_INTERVAL, function( self )
        if self:Health() <= 0 or not self:IsPossessed() then return end
        -- per-volley re-aim: SpawnVolley falls back to PossessorTrace().HitPos
        -- when the lock-on is NULL
        self:UKMDK_SpawnVolley( self:PossessionGetLockedOn() )
      end )
    end
  end

  -- Honest full auto while possessed: after the announced burst the chain
  -- keeps firing at FULL_VOLLEY_INTERVAL for as long as IN_ATTACK is held;
  -- a stale press (or one swallowed by a voice line) restarts the burst.
  function ENT:UKMDK_TickPossessionFire()
    local possessor = self:GetPossessor()
    if not IsValid( possessor ) or not possessor:KeyDown( IN_ATTACK ) then return end
    local now = CurTime()
    local fireEnd = self.UKMDK_PossFireEnd or 0
    if now < fireEnd then return end
    if now - fireEnd < 0.5 then
      -- seamless continuation of the running burst
      self.UKMDK_PossFireEnd = now + UKMDK.FULL_VOLLEY_INTERVAL
      self:UKMDK_SpawnVolley( self:PossessionGetLockedOn() )
    elseif now >= self.UKMDK_TalkingUntil then
      self:UKMDK_PossessionFullAuto()
    end
  end

  -- canon ProjectileSpread: центр + 6 орбов, наклон 10° от forward, шаг 60°.
  -- Орб = готовый ultrakill_stray_projectile (канонный hell orb, dmg 250 в
  -- юнитах пака = канон 25); только скорость канонного оверрайда 250 м/с.
  function ENT:UKMDK_SpawnVolley( target )
    if not IsValid( target ) then target = self:UKMDK_GetEnemy() end
    if not IsValid( target ) and not self:IsPossessed() then return end
    local muzzle = self:GetAttachment( self:LookupAttachment( "muzzle" ) )
    local origin = muzzle and muzzle.Pos or self:WorldSpaceCenter()
    -- possessed with no lock-on: free-aim the volley at the crosshair
    local aim = IsValid( target ) and target:WorldSpaceCenter()
      or self:PossessorTrace().HitPos
    local fwd = ( aim - origin ):GetNormalized()
    local ang = fwd:Angle()
    local up, right = ang:Up(), ang:Right()
    local tilt = math.rad( UKMDK.FULL_SPREAD_DEG )

    local dirs = { fwd }
    for i = 0, UKMDK.FULL_RING - 1 do
      local theta = math.rad( i * 360 / UKMDK.FULL_RING )
      local axis = up * math.cos( theta ) + right * math.sin( theta )
      dirs[ #dirs + 1 ] = ( fwd * math.cos( tilt ) + axis * math.sin( tilt ) ):GetNormalized()
    end

    for _, dir in ipairs( dirs ) do
      local orb = ents.Create( "ultrakill_stray_projectile" )
      if not IsValid( orb ) then continue end
      orb:SetPos( origin + dir * 20 )
      orb:SetAngles( dir:Angle() )
      orb:SetOwner( self )
      orb:Spawn()
      orb:SetVelocity( dir * UKMDK.ORB_SPEED )
    end
    self:EmitSound( "weapons/physcannon/energy_sing_flyby1.wav", 75, 140, 0.8, CHAN_STATIC )
  end

  function ENT:UKMDK_FullerAuto( target )
    self.UKMDK_FullerChance = math.min( 0.5, self.UKMDK_FullerChance ) - 0.2
    local frac = self:Health() / self:GetMaxHealth()
    local cd = frac > 2 / 3 and UKMDK.FULLER_CD_HIGH
            or frac > 1 / 3 and UKMDK.FULLER_CD_MID
            or UKMDK.FULLER_CD_LOW
    self.UKMDK_NextAttack = CurTime() + math.max( cd,
      UKMDK.ATTACK_WINDUP + UKMDK.FULLER_COUNT * UKMDK.FULLER_INTERVAL + 0.2 )
    self:UKMDK_Speak( UKMDK.VOICE.fullerauto )  -- "Fuller auto"

    -- Сикер = готовый ultrakill_mindflayer_projectile (канонный красный
    -- homing skull — Fuller Auto стреляет тем же семейством префабов, что
    -- Mindflayer; dmg 300 = канон 30, разгон по сложности встроен в базу).
    for i = 1, UKMDK.FULLER_COUNT do
      self:Timer( UKMDK.ATTACK_WINDUP + i * UKMDK.FULLER_INTERVAL, function( self )
        if self:Health() <= 0 then return end
        local tgt = IsValid( target ) and target or self:UKMDK_GetEnemy()
        if not IsValid( tgt ) and self:IsPossessed() then
          tgt = self:UKMDK_PossessionSeekerTarget()
          if not tgt then return self:UKMDK_SpawnFreeSeeker() end
        end
        if not IsValid( tgt ) then return end
        local seeker = ents.Create( "ultrakill_mindflayer_projectile" )
        if not IsValid( seeker ) then return end
        -- canon: Instantiate(pos, Random.rotation)
        local dir = VectorRand():GetNormalized()
        seeker:SetPos( self:WorldSpaceCenter() + dir * 30 )
        seeker:SetAngles( dir:Angle() )
        seeker:SetOwner( self )
        seeker:Spawn()
        seeker:SetEnemy( tgt )
        seeker:SetVelocity( dir * UKMDK.SEEKER_START_SPEED )
      end )
    end
  end

  -- Possessed seeker target: lock-on first, else the character under the
  -- crosshair (seekers home on an ENTITY — a bare HitPos can't be homed at).
  function ENT:UKMDK_PossessionSeekerTarget()
    local locked = self:PossessionGetLockedOn()
    if IsValid( locked ) then return locked end
    local ent = self:PossessorTrace().Entity
    if IsValid( ent ) and ent ~= self and ent:Health() > 0
      and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then return ent end
    return nil
  end

  -- Possessed free-aim (nothing under the crosshair to home at): straight
  -- seeker at the crosshair point — the base skips homing without an enemy,
  -- so the canon crawl speed would leave it drifting in place.
  function ENT:UKMDK_SpawnFreeSeeker()
    local seeker = ents.Create( "ultrakill_mindflayer_projectile" )
    if not IsValid( seeker ) then return end
    local aim = self:PossessorTrace().HitPos
    local dir = ( aim - self:WorldSpaceCenter() ):GetNormalized()
    dir = ( dir + VectorRand() * UKMDK.SEEKER_FREE_SPREAD ):GetNormalized()
    seeker:SetPos( self:WorldSpaceCenter() + dir * 30 )
    seeker:SetAngles( dir:Angle() )
    seeker:SetOwner( self )
    seeker:Spawn()
    seeker:SetVelocity( dir * UKMDK.SEEKER_FREE_SPEED )
  end

  -- Рывок только в горизонтали (по фидбеку: чуть влево/вправо, не вверх);
  -- от стены (raycast 7 м) инвертируется; исполняет burst в UKMDK_Move.
  function ENT:UKMDK_Dash( dir )
    dir = Vector( dir.x, dir.y, 0 )
    if dir:IsZero() then dir = self:GetRight() end
    dir:Normalize()
    local tr = util.TraceLine{ start = self:GetPos(),
                               endpos = self:GetPos() + dir * UKMDK.DODGE_WALL_PROBE,
                               filter = self, mask = MASK_SOLID_BRUSHONLY }
    if tr.Hit then dir = -dir end
    self.UKMDK_DodgeDir = dir
    self.UKMDK_DodgeUntil = CurTime() + UKMDK.DODGE_TIME
  end

  -- canon Drone.Update: dodge каждые 1-3 c, кулдаун тикает со скоростью
  -- GetCooldownSpeed (difficulty/2) — на брутале дэшит почти постоянно.
  function ENT:UKMDK_TickDodge( dt )
    local target = self:UKMDK_GetEnemy()
    if not IsValid( target ) then return end

    local diff = UKMDK.GetDifficulty()
    self.UKMDK_DodgeCD = self.UKMDK_DodgeCD
      - dt * ( UKMDK.DODGE_CD_SPEED[ diff ] or 1.0 )
    if self.UKMDK_DodgeCD > 0 then return end
    self.UKMDK_DodgeCD = math.Rand( UKMDK.DODGE_CD_MIN, UKMDK.DODGE_CD_MAX )

    local chance = UKMDK.DODGE_DIFF_CHANCE[ diff ] or 1.0
    if math.random() > chance then return end

    self:UKMDK_Dash( self:GetRight() * ( math.random() < 0.5 and -1 or 1 ) )
  end

  -- «tending to evade player attacks with these same dashes»: шанс уклониться
  -- боковым дэшем при получении урона.
  function ENT:OnHurt( dmg, hitgroup )
    if self:Health() <= 0 then return end
    -- random evade dash would fight the possessor's steering
    if self:IsPossessed() then return end
    if CurTime() < self.UKMDK_LastEvade + UKMDK.EVADE_HURT_MIN_INTERVAL then return end
    local chance = UKMDK.DODGE_DIFF_CHANCE[ UKMDK.GetDifficulty() ] or 1.0
    if math.random() > UKMDK.EVADE_HURT_CHANCE * chance then return end
    self.UKMDK_LastEvade = CurTime()
    self:UKMDK_Dash( self:GetRight() * ( math.random() < 0.5 and 1 or -1 ) )
  end

  -- canon Drone.Death: suicide dive вместо смерти. Убит панчем -> улетает по
  -- направлению удара (home run), иначе пикирует в цель.
  function ENT:OnKilled( dmginfo )
    if self.UKMDK_Died then return end
    self.UKMDK_Died = true

    local attacker = dmginfo and dmginfo:GetAttacker() or nil
    local dir
    local hitter = IsValid( attacker ) and attacker.UltrakillBase_LastHitterTag or nil
    local melee = hitter == "punch" or hitter == "hammerzone"
              or ( dmginfo and dmginfo:IsDamageType( DMG_CLUB ) )
    if melee and IsValid( attacker ) and attacker:IsPlayer() then
      dir = attacker:GetAimVector()
    else
      local target = self:UKMDK_GetEnemy()
      if not IsValid( target ) and IsValid( attacker ) then target = attacker end
      dir = IsValid( target )
        and ( target:WorldSpaceCenter() - self:WorldSpaceCenter() ):GetNormalized()
        or self:GetForward()
    end

    local crash = ents.Create( "ultrakill_test_mdk_crash" )
    if IsValid( crash ) then
      crash:SetPos( self:GetPos() )
      crash.UKMDKCrash_Dir = dir
      -- состояние для отрисовки: 2 = песок (Sand-материал), 1 = enraged
      crash.UKMDKCrash_Tint = self:GetSand() and 2 or ( self:GetEnraged() and 1 or 0 )
      crash:Spawn()
      local vel = self.loco and self.loco:GetVelocity() or Vector()
      crash.UKMDKCrash_Speed = math.max( 400, vel:Length() )
    end
    self:Remove()
  end

  -- Луп enrage удаляется вместе с боссом (DeleteOnRemove в SoundScript),
  -- финальный EnrageEnd играем без родителя — как Cerberus базы.
  function ENT:OnRemove()
    if self:GetEnraged() then
      UltrakillBase.SoundScript( "Ultrakill_Enrage_End", self:GetPos() )
    end
  end
end

-- Клиентский Draw НЕ переопределяем: DrGBase Draw -> _BaseDraw базы сам
-- рисует Sand-материал, Enrage-эффект и Radiance.

-- FullTracking делаем сами: базовая версия дёргает — крутит кость и на
-- сервере (сетевые квантованные углы), и на клиенте, линейным AngleApproach
-- с шагом think-интервала. Глушим её и ведём чисто клиентский пер-кадровый
-- exp-lerp (паттерн Idol/DC: снап первого кадра + плавный догон).
function ENT:CalculateFullTracking() end

if CLIENT then
  local TRACK_RATE = 6  -- 1/с, скорость exp-догона

  function ENT:CustomDraw()
    if not self:GetFullTracking() then return end
    local bone = self:LookupBone( "Mandalore" )
    if not bone then return end

    -- как в DoFullTracking базы: питч аима кладётся в .z манипуляции кости
    local aim = self:GetAimAngles()
    local goal = Angle( 0, 0, aim and aim.p or 0 )

    local cur = self.UKMDK_TrackAng
    if not cur then
      cur = Angle( goal )                 -- первый кадр — без размаха с нуля
    else
      cur = LerpAngle( 1 - math.exp( -TRACK_RATE * FrameTime() ), cur, goal )
    end
    self.UKMDK_TrackAng = cur
    self:ManipulateBoneAngles( bone, cur, false )
  end
end

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_mdk", {
  Name      = ENT.PrintName,
  Class     = "ultrakill_test_mdk",
  Category  = ENT.Category,
  AdminOnly = false,
} )

-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (x10 player damage twice = x100 => a parried
-- projectile one-shots the boss).
if SERVER then
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end
end
