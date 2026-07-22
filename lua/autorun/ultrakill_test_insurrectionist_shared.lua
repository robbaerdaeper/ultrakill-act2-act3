if SERVER then AddCSLuaFile() end

UKSisy = UKSisy or {}

-- Sisyphean Insurrectionist (Supreme Husk). Sources: Sisyphus.cs /
-- SisyAttackAnimationDetails / Cannonball.cs / Explosion.cs decompile,
-- gameprefabs 'Sisyphus' dump (sisy_probe*.py), clip events from the
-- AssetRipper .anim exports.

UKSisy.CATEGORY = "ULTRAKILL Test"

UKSisy.MODEL = "models/ultrakill_prelude_test/insurrectionist.mdl"
UKSisy.MODEL_BOULDER = "models/ultrakill_prelude_test/insurrectionist_boulder.mdl"
UKSisy.MODEL_GIB_LEG_L = "models/ultrakill_prelude_test/insurrectionist_gib_leg_l.mdl"
UKSisy.MODEL_GIB_LEG_R = "models/ultrakill_prelude_test/insurrectionist_gib_leg_r.mdl"

-- Workshop pack convention: canon HP x1000. Common form 75 HP (boss 4-2: 110).
UKSisy.HP = 75 * 1000

-- TRUE 1:1: 1 canon metre = 40 su (rig scale 2.5, $scale 100 => ~12 m tall).
UKSisy.UNIT = 20 -- 2026-07-10: model rescaled x0.5 (Kevin-scale), was 40

-- Canon NavMeshAgent: speed 10 m/s, accel 666, angular 999 deg/s, stop 1.5 m.
-- Tuned 2026-07-07: canon pace felt too frantic in sandbox — walk slower,
-- swing slower, wait longer between attacks, jump rarer.
UKSisy.MOVE_SPEED = 7 * UKSisy.UNIT   -- canon 10 m/s
UKSisy.WALK_ANIM_RATE = 0.7           -- walk clip was baked for 10 m/s
UKSisy.COOLDOWN_MULT = 2.0            -- canon 2 s between attacks -> 4 s
UKSisy.SWING_TUNE = 0.75              -- boulder swings: anim + flight speed
UKSisy.STOMP_TUNE = 0.85              -- stomp wind-up
UKSisy.JUMP_AFTER_MIN = 4             -- canon jumps every 2-3 attacks
UKSisy.JUMP_AFTER_MAX = 6
UKSisy.STOP_DISTANCE = 1.5 * UKSisy.UNIT

-- Cooldown system: spawn 3 s (Brutal 1 s); per-attack 3 - difficulty/2 (int);
-- depletes x3 while the target is closer than 10 m.
UKSisy.SPAWN_COOLDOWN = 3
UKSisy.CLOSE_RANGE = 10   -- metres
UKSisy.STOMP_RANGE = 8    -- metres
UKSisy.JUMP_RANGE = 100   -- metres
-- AirStab clearance: our hover apex is ~25 m (vz 100 m/s, g 200 m/s^2 at
-- +0.45 s); the canon 73 m sky check failed under any ceiling, so the
-- attack never fired on real maps.
UKSisy.AIRSTAB_RISE = 75  -- metres; round 3 2026-07-10: «ещё выше» (was 50, was 25)

-- SwingCheck2 on the stretchy hand: 30 dmg, knockback 500, strong.
UKSisy.SWING_DAMAGE = 30

-- Boulder = Cannonball: parry -> launched; hitting the Insurrectionist deals
-- 22 canon dmg + Knockdown. Launch speed 150 m/s.
UKSisy.CANNONBALL_DAMAGE = 22
UKSisy.CANNONBALL_SPEED = 150 * UKSisy.UNIT

-- 'Explosion Wave Sisyphus': sphere 1 = 30 dmg, R 13.5 m; sphere 2 = pure
-- player knockback, R 18 m. Canon Explosion halves (x1/1.5) damage beyond
-- R/2. Boulder impacts scale x0.66 below VIOLENT; the Stomp does not (it
-- instead grows x1.5 on VIOLENT+).
UKSisy.EXPLOSION_DAMAGE = 30
UKSisy.EXPLOSION_R1 = 13.5   -- metres
UKSisy.EXPLOSION_R2 = 18.0

-- NPC-scale LANDED targets (Sentry convention: enemy-scale = wiki/10, x1000).
-- Deal-sites must pre-divide them by the victim's base multiplier
-- (PreMultDamage below): the UK base rescales any damage TO a UK nextbot by
-- attacker type (player = plydmgmult*10, UK nextbot/projectile = x20). The
-- old raw `*1000` numbers double-dipped into that x20 and landed ~600k per
-- swing — one-shot for the whole pack (workshop report 2026-07-10).
UKSisy.SWING_DAMAGE_NPC = 3000
UKSisy.EXPLOSION_DAMAGE_NPC = 3000
-- parried boulder: reward parity with VCR seeker (10000) / GT mine (10500)
UKSisy.CANNONBALL_PARRY_NPC = 10000
-- parried boulder into its owner: canon 22 x 1000 pack scale, landed
UKSisy.CANNONBALL_OWNER_DAMAGE = 22 * 1000

-- Jump-landing PhysicalShockwave: 25 dmg, radius 100 m, speed 35 m/s.
-- Rendered through the UltrakillBase ENT:Shockwave ring (the Hideous Mass
-- wave): damage in base units (canon x10), model size = su / 22, time =
-- maxsize / speed, ScaleZ 0.2 = HM stomp height (jumpable).
UKSisy.WAVE_DAMAGE = 25
UKSisy.WAVE_MAXSIZE = 100
UKSisy.WAVE_SPEED = 35
UKSisy.WAVE_SCALEZ = 0.2

-- Knockdown recovery: 0.85 s grounded re-check; 4 s when cannonballed in air
-- just before landing (superKnockdownWindow 0.25 s).
UKSisy.KNOCKDOWN_TIME = 0.85
UKSisy.SUPER_KNOCKDOWN_TIME = 4

-- Angry/Rude: сколько секунд лежащий наполняет HP до уровня напарника
-- (клип замирает на земле, как super-knockdown). Кевин делал ~1.8 с —
-- юзер-тюн 2026-07-10: «слишком быстрое заполнение», растянуто.
UKSisy.DOWNED_REGEN_TIME = 5.0

-- SisyAttackAnimationDetails (ExtendArm boulder/anim speed maths):
--   d = max(dist_m - 10, 0); sas = clamp(d/divide, minB, maxB)
--   animSpeed = clamp((1 - d/divide)*spdMult, capMin, capMax) * diffMult
--   flightTime = evFloat * sas * durMult (seconds)
UKSisy.DETAILS = {
  overheadslam = { minB = 0.10, divide = 150, maxB = 0.5,  durMult = 4.0,
                   spdMult = 0.75, capMin = 0.10, capMax = 1.0, evFloat = 1.25 },
  horizontalswing = { minB = 0.10, divide = 100, maxB = 0.25, durMult = 5.0,
                   spdMult = 1.0,  capMin = 0.75, capMax = 1.0, evFloat = 1.0 },
  stab =         { minB = 0.05, divide = 50,  maxB = 0.5,  durMult = 0.75,
                   spdMult = 2.0,  capMin = 0.75, capMax = 2.0, evFloat = 1.0 },
  airstab =      { minB = 0.01, divide = 100, maxB = 1e10, durMult = 2.5,
                   spdMult = 1.0,  capMin = 0.10, capMax = 1.0, evFloat = 1.0 },
}

-- Clip timings (30 fps bake, seconds at rate 1.0; from the canon anim events).
UKSisy.CLIP = {
  overheadslam    = { stop = 2.000, extend = 0.660, retract = 1.264 },
  horizontalswing = { stop = 3.333, extend = 1.195, retract = 2.275 },
  stab            = { stop = 3.667, extend = 1.400, retract = 2.972 },
  airstab         = { stop = 2.667, extend = 0.855, cancel = 1.578, fly = 1.874 },
  airstabcancel   = { stop = 2.000 },
  stomp           = { stop = 1.333, explode = 0.690, stopaction = 1.158 },
  landing         = { stop = 1.100, stopaction = 0.734 },
  knockdown       = { stop = 2.167, fallsound = 0.329, stopaction = 2.014 },
  jump            = { stop = 2.000 },
}

UKSisy.SOUND = {
  AttackOverhead   = "ultrakill_prelude_test/sisy/attack_overhead.wav",   -- SisypheanVoice9b
  AttackHorizontal = "ultrakill_prelude_test/sisy/attack_horizontal.wav", -- SisypheanVoice7b
  AttackStab       = "ultrakill_prelude_test/sisy/attack_stab.wav",       -- SisypheanVoice8b
  AttackAirStab    = "ultrakill_prelude_test/sisy/attack_airstab.wav",    -- SisypheanVoice5b
  Stomp            = "ultrakill_prelude_test/sisy/stomp.wav",             -- SisypheanVoice6b
  Death            = "ultrakill_prelude_test/sisy/death.wav",             -- SisypheanScream
  HurtSmall        = "ultrakill_prelude_test/sisy/hurt_small.wav",        -- SisypheanHurtMid
  HurtMid          = "ultrakill_prelude_test/sisy/hurt_mid.wav",          -- SisypheanHurtBig
  HurtBig          = "ultrakill_prelude_test/sisy/hurt_big.wav",          -- SisypheanHurtBigger
  SwingLoop        = "ultrakill_prelude_test/sisy/swing_loop.wav",        -- WhooshLoud @1.5, loop
  Explosion        = "ultrakill_prelude_test/sisy/explosion.wav",         -- Impacts_PROCESSED_001Short
  JumpRubble       = "ultrakill_prelude_test/sisy/jump_rubble.wav",       -- bigRockBreak
  Fall             = "ultrakill_prelude_test/sisy/fall.wav",              -- stonestep
  BoulderBreak     = "ultrakill_prelude_test/sisy/boulder_break.wav",     -- boulder_impact_on_stones_14
  AttackFlash      = "ultrakill_prelude_test/sisy/attack_flash.wav",      -- ComputerSFX_alerts-004 @1.5
  Spawn            = "ultrakill_prelude_test/sisy/spawn.wav",             -- PortalInsurrectionist2
}

UKSisy.CLASS = {
  Regular = "ultrakill_test_insurrectionist",
  -- 'projectile' in the class name is mandatory: ukarms CheckCriticalProjectile
  -- (feedbacker parry) string.find's the class for "proj"
  Boulder = "ultrakill_test_insurrectionist_projectile",
}

function UKSisy.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

-- Canon global swing-speed multiplier applied inside ExtendArm (num3),
-- scaled by the SWING_TUNE pace knob (slower anim AND longer flight).
function UKSisy.SwingDiffMult( diff )
  local m = UKSisy.SWING_TUNE or 1
  if diff >= 4 then return 1.5 * m end
  if diff == 3 then return 1.25 * m end
  if diff == 1 then return 0.75 * m end
  if diff == 0 then return 0.5 * m end
  return 1.0 * m
end

-- Canon StompSpeed anim float, scaled by the STOMP_TUNE pace knob.
function UKSisy.StompSpeed( diff )
  local m = UKSisy.STOMP_TUNE or 1
  if diff <= 1 then return 0.75 * m end
  if diff == 2 then return 0.875 * m end
  return 1.0 * m
end

-- Canon attack cooldown: 3 - difficulty/2 (integer division), scaled by
-- the COOLDOWN_MULT pace knob.
function UKSisy.AttackCooldown( diff )
  return ( 3 - math.floor( diff / 2 ) ) * ( UKSisy.COOLDOWN_MULT or 1 )
end

-- Players take FLAT canon damage (30 swing / 30-20 blast / 22 cannonball):
-- drg_ultrakill_plytakedmgmult defaults to 0.1 and shrank every hit to 10%
-- of canon; policy 2026-07-07 (same as Sentry) — ignore that convar.
function UKSisy.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then return damage end
  if ent.IsUltrakillNextbot then return damage end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

-- The UK base rescales ANY damage TO a UK nextbot inside the victim's
-- DamageMultiplier by attacker type: player = plydmgmult*10, UK nextbot /
-- UK projectile = x20, everything else = takedmgmult. The *_NPC constants
-- above are the values we want LANDED, so deal-sites feed the pre-divided
-- number (Providence / power_spear recipe).
function UKSisy.PreMultDamage( victim, attacker, amount )
  if not ( IsValid( victim ) and victim.IsUltrakillNextbot ) then return amount end
  local mult = isfunction( victim.GetDamageMultiplierConVar )
    and victim:GetDamageMultiplierConVar( attacker ) or 1
  return amount / math.max( mult, 0.01 )
end

--------------------------------------------------------------------------
-- Canon ArmStretcher: while the boulder entity is out (and not parried
-- off), the arm visually stretches after it — client-only, server
-- animations and hitboxes are untouched. Implemented by writing the chain
-- bones' world matrices directly inside a BuildBonePositions callback:
-- each bone gets its origin on the shoulder->boulder line (rest-length
-- proportions), a basis whose local Y (the bone length axis) runs along
-- the line, and that Y column scaled by the stretch factor so the
-- near-rigid vert weights elongate the tube instead of tearing it.
-- NOT ManipulateBone*: engine clamps manip positions to ~±512/bone, which
-- capped the reach at roughly half of a long throw; SetBoneMatrix inside
-- the callback has no such limit and needs no per-frame feedback loop.
--------------------------------------------------------------------------

UKSisy.ARM_ANCHOR = "upper_arm.L"
UKSisy.ARM_CHAIN = {
  "forearm.L", "hand.L", "hand.L.001", "hand.L.002", "hand.L.003",
  "hand.L.004", "hand.L.005", "hand.L.006",
}
-- mace centre sits ~0.9 model units past the hand.L.006 origin (the
-- "boulder" attachment) — keep the hand that far short of the projectile
UKSisy.ARM_TIP_BACKOFF = 45 -- 2026-07-10: model rescaled x0.5

if CLIENT then

  local tracked = {} -- npc -> true while its arm is stretched / relaxing

  -- resolve the chain + pose-invariant stretch fractions (bone rest
  -- lengths don't change with animation, so any pose works for measuring);
  -- also clears leftover ManipulateBone* values from older versions
  local function ArmSetup( npc )
    local anchor = npc:LookupBone( UKSisy.ARM_ANCHOR )
    if not anchor then return nil end
    local chain = {}
    for _, name in ipairs( UKSisy.ARM_CHAIN ) do
      local id = npc:LookupBone( name )
      if not id then return nil end
      chain[ #chain + 1 ] = { id = id, frac = 0 }
      npc:ManipulateBonePosition( id, vector_origin )
      npc:ManipulateBoneScale( id, Vector( 1, 1, 1 ) )
      npc:ManipulateBoneAngles( id, angle_zero )
    end
    npc:ManipulateBoneScale( anchor, Vector( 1, 1, 1 ) )
    npc:ManipulateBoneAngles( anchor, angle_zero )
    npc:SetupBones()
    local total = 0
    local am = npc:GetBoneMatrix( anchor )
    local prevPos = am and am:GetTranslation()
    for _, b in ipairs( chain ) do
      local m = npc:GetBoneMatrix( b.id )
      if not m or not prevPos then return nil end
      local pos = m:GetTranslation()
      total = total + pos:Distance( prevPos )
      b.frac = total
      prevPos = pos
    end
    if total <= 0 then return nil end
    for _, b in ipairs( chain ) do b.frac = b.frac / total end
    return { anchor = anchor, chain = chain, restTotal = total }
  end

  local UP_Z, UP_X = Vector( 0, 0, 1 ), Vector( 1, 0, 0 )

  -- BuildBonePositions: overwrite the chain matrices with a straight tube
  -- anchor->cur. While a boulder is linked, cur chases its live position;
  -- with the goal gone, cur chases the ANIMATED hand until it gets there
  -- and the override switches off (smooth zip-back, tiny final blend pop).
  local function ArmBuildBones( ent )
    local arm = ent.UKSisyArm
    if not arm then return end
    local goal = ent.UKSisyArmGoal
    if not goal and not ent.UKSisyArmCur then return end

    local am = ent:GetBoneMatrix( arm.anchor )
    if not am then return end
    local anchor = am:GetTranslation()

    local target = goal
    if not target then
      local tm = ent:GetBoneMatrix( arm.chain[ #arm.chain ].id )
      if not tm then
        ent.UKSisyArmCur = nil
        return
      end
      target = tm:GetTranslation()
    end

    -- advance the smoothing once per frame: the callback also fires for
    -- extra render passes (shadows, reflections) within the same frame
    local now = CurTime()
    local cur = ent.UKSisyArmCur
    if ent.UKSisyArmLastT ~= now then
      ent.UKSisyArmLastT = now
      local f = 1 - math.exp( -FrameTime() * ( goal and 30 or 10 ) )
      cur = cur and LerpVector( f, cur, target ) or target
      ent.UKSisyArmCur = cur
      if not goal and cur:DistToSqr( target ) < 25 then
        ent.UKSisyArmCur = nil
        return
      end
    end
    if not cur then return end

    local dir = cur - anchor
    local dist = dir:Length()
    if dist < 1 then return end
    dir:Mul( 1 / dist )
    -- while linked keep the hand short of the mace centre; while relaxing
    -- the target IS the animated hand, no backoff
    local eff = math.max( dist - ( goal and UKSisy.ARM_TIP_BACKOFF or 0 ), 1 )
    local s = math.max( eff / arm.restTotal, 0.05 )

    -- shared straight-tube basis: local +Y (bone length axis) along the
    -- line, Y column scaled by the stretch factor (VMatrix "right" = -Y)
    local upref = math.abs( dir.z ) < 0.99 and UP_Z or UP_X
    local bx = dir:Cross( upref )
    bx:Normalize()
    local bz = bx:Cross( dir )
    local ny = dir * -s

    local m = Matrix()
    m:SetForward( bx )
    m:SetRight( ny )
    m:SetUp( bz )
    m:SetTranslation( anchor )
    ent:SetBoneMatrix( arm.anchor, m )
    for _, b in ipairs( arm.chain ) do
      local bm = Matrix()
      bm:SetForward( bx )
      bm:SetRight( ny )
      bm:SetUp( bz )
      bm:SetTranslation( anchor + dir * ( eff * b.frac ) )
      ent:SetBoneMatrix( b.id, bm )
    end
  end

  hook.Add( "Think", "UKSisy_ArmStretch", function()
    local touched
    for _, b in ipairs( ents.FindByClass( UKSisy.CLASS.Boulder ) ) do
      if b:GetNW2Bool( "UKSB_ArmLinked", false ) and not b:IsDormant() then
        local npc = b:GetOwner()
        if IsValid( npc ) and npc.UKSisy_IsSisy and not npc:IsDormant() then
          if npc.UKSisyArm == nil then npc.UKSisyArm = ArmSetup( npc ) end
          if npc.UKSisyArm then
            if not npc.UKSisyArmCB then
              npc.UKSisyArmCB = true
              npc:AddCallback( "BuildBonePositions", ArmBuildBones )
            end
            npc.UKSisyArmGoal = b:GetPos()
            tracked[ npc ] = true
            touched = touched or {}
            touched[ npc ] = true
          end
        end
      end
    end
    for npc in pairs( tracked ) do
      if not IsValid( npc ) then
        tracked[ npc ] = nil
      elseif not ( touched and touched[ npc ] ) then
        npc.UKSisyArmGoal = nil -- callback eases the arm home by itself
        if npc.UKSisyArmCur == nil then tracked[ npc ] = nil end
      end
    end
  end )

end

--------------------------------------------------------------------------
-- Angry & Rude — секретный дуэт 6-1 "CRY FOR THE WEEPER". Рецепт Кевина
-- (Tundra/Agony у swordsmachine) на нашем порте: портал + босс-бар +
-- Symbiote-связка. Канон (вики + Кевин): летальный урон при живом
-- напарнике не убивает — хаск падает в Knockdown на 1 HP и за время клипа
-- его HP ползёт к текущему HP напарника; по-настоящему умирают, только
-- когда второй уже мёртв/тоже лежит. Перекрас = канонные материалы
-- SisyphusRed/SisyphusBlue (подменяют только _MainTex) через
-- SetSubMaterial — mdl не трогаем (bless_overlay_vmt_lessons).
--------------------------------------------------------------------------

function UKSisy.ApplyVariant( ENT, cfg )
  ENT.Base = UKSisy.CLASS.Regular
  ENT.PrintName = cfg.name
  ENT.Category = "ULTRAKILL - Secrets"
  ENT.Models = { UKSisy.MODEL }
  ENT.SpawnHealth = UKSisy.HP -- канон: у Angry/Rude обычные 75 HP
  ENT.UKSAR_BodyMaterial = cfg.material
  ENT.UKSAR_PartnerClass = cfg.partner
  ENT.UKSAR_BossTitle = cfg.bossTitle

  if CLIENT then return end

  local BaseClass = baseclass.Get( UKSisy.CLASS.Regular )

  function ENT:CustomInitialize()
    BaseClass.CustomInitialize( self )
    self.UKSAR_Downed = false
    self.UKSAR_Symbiote = NULL
    for i, mat in ipairs( self:GetMaterials() ) do
      if mat:find( "sisy_body", 1, true ) then
        self:SetSubMaterial( i - 1, self.UKSAR_BodyMaterial )
      end
    end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    -- выход секретного варианта у Кевина: портал (3 = Superheavy);
    -- канонный звук портала уже играет спавн-саунд базового порта
    self:CreatePortal( self:WorldSpaceCenter(), self:GetAngles(), 3,
      Vector( 120, 120, 470 ) )
    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, self.UKSAR_BossTitle )
    end
    -- связка с напарником противоположного класса (цикл Кевина)
    for _, v in ipairs( self:GetAllies() ) do
      if IsValid( v ) and v:GetClass() == self.UKSAR_PartnerClass
          and not IsValid( v.UKSAR_Symbiote ) then
        self.UKSAR_Symbiote = v
        v.UKSAR_Symbiote = self
        break
      end
    end
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
    if self.UKS_Dead then return end
    if self.UKSAR_Downed then
      -- лежащий неуязвим (Кевин: ScaleDamage(0) пока IsDowned)
      dmg:ScaleDamage( 0 )
      return
    end
    -- правило Кевина (юзер вернул 2026-07-10 р3): рескью только при
    -- СТОЯЩЕМ живом напарнике; летальный удар, пока напарник лежит, =
    -- настоящая смерть — окно, чтобы добить пару
    local partner = self.UKSAR_Symbiote
    if self:Health() - dmg:GetDamage() <= 0 and IsValid( partner )
        and not partner.UKSAR_Downed and not partner.UKS_Dead then
      dmg:ScaleDamage( 0 )
      self:SetHealth( 1 )
      self:UKSAR_StartDowned( partner )
    end
  end

  -- канонный нокдаун от парированного валуна не должен перезапускать
  -- downed-клип поверх самого себя
  function ENT:UKS_Knockdown( fromPos, super )
    if self.UKSAR_Downed then return end
    BaseClass.UKS_Knockdown( self, fromPos, super )
  end

  function ENT:UKSAR_StartDowned( partner )
    self.UKSAR_Downed = true

    -- обрываем текущую атаку/полёт, как канонный нокдаун
    if IsValid( self.UKS_Boulder ) then self.UKS_Boulder:UKSB_Retract( 0.3 ) end
    self.UKS_Airborne = nil
    self.UKS_JumpTarget = nil
    self.UKS_PullT0 = nil
    if self.loco then
      self.loco:SetGravity( self.UKS_DefaultGravity or 1000 )
      self.loco:SetVelocity( vector_origin )
    end
    self:UKS_EndAction()

    -- клип замирает лёжа (рецепт super-knockdown базового порта): упал за
    -- KNOCKDOWN_TIME, лежит и наполняется DOWNED_REGEN_TIME, потом встаёт
    local clip = UKSisy.CLIP.knockdown
    local hold = UKSisy.DOWNED_REGEN_TIME
    local getup = clip.stopaction - UKSisy.KNOCKDOWN_TIME
    self:UKS_BeginAction( "knockdown", clip.stopaction + hold )
    self:UKS_PlaySeq( "Knockdown", 1 )
    self:EmitSound( UKSisy.SOUND.HurtBig, 100, math.random( 80, 120 ), 1, CHAN_VOICE )

    -- HP ползёт от ~0 к HP напарника, пока он лежит (юзер-тюн: медленно)
    local target = math.max( IsValid( partner ) and partner:Health() or 1, 1 )
    self.UKSAR_RegenTarget = target
    self.UKSAR_RegenRate = target / hold
    self.UKSAR_LastRegenT = CurTime()
    self.UKSAR_GetupTime = getup

    local this = self
    timer.Simple( clip.fallsound, function()
      if IsValid( this ) and this.UKSAR_Downed then
        sound.Play( UKSisy.SOUND.Fall, this:GetPos(), 105, 100, 1 )
        util.ScreenShake( this:GetPos(), 6, 40, 0.5, 1200 )
      end
    end )
    timer.Simple( UKSisy.KNOCKDOWN_TIME, function()
      -- RegenTarget уже nil = напарник умер, идёт ранний подъём — не замирать
      if IsValid( this ) and this.UKSAR_Downed and this.UKS_Action == "knockdown"
          and this.UKSAR_RegenTarget then
        this:SetPlaybackRate( 0 )
        this.UKS_SeqRate = 0
      end
    end )
    timer.Simple( UKSisy.KNOCKDOWN_TIME + hold, function()
      if IsValid( this ) and this.UKSAR_Downed and this.UKS_Action == "knockdown"
          and this.UKS_SeqRate == 0 then
        this:SetPlaybackRate( 1 )
        this.UKS_SeqRate = 1
      end
    end )
  end

  function ENT:UKSAR_DownedThink()
    local now = CurTime()
    local dt = now - ( self.UKSAR_LastRegenT or now )
    self.UKSAR_LastRegenT = now

    local partner = self.UKSAR_Symbiote
    -- напарник умер, пока мы лежали — реген отменяется и хаск сразу встаёт
    -- (ранний выход из callback'а у Кевина)
    if self.UKSAR_RegenTarget
        and ( not IsValid( partner ) or partner.UKSAR_Downed or partner.UKS_Dead ) then
      self.UKSAR_RegenTarget = nil
      if self.UKS_Action == "knockdown" then
        if self.UKS_SeqRate == 0 then
          self:SetPlaybackRate( 1 )
          self.UKS_SeqRate = 1
        end
        self.UKS_ActionEnd = math.min( self.UKS_ActionEnd,
          now + ( self.UKSAR_GetupTime or 1.2 ) )
      end
    end
    if self.UKSAR_RegenTarget and dt > 0 then
      self:SetHealth( math.Approach( self:Health(), self.UKSAR_RegenTarget,
        self.UKSAR_RegenRate * dt ) )
    end
    -- клип доигран (базовый Think снял action) — встаём
    if not self.UKS_Action then
      self.UKSAR_Downed = false
      self.UKSAR_RegenTarget = nil
      if self:Health() < 1 then self:SetHealth( 1 ) end
    end
  end

  function ENT:CustomThink()
    if self.UKSAR_Downed and not self.UKS_Dead then
      self:UKSAR_DownedThink()
    end
    BaseClass.CustomThink( self )
  end
end

-- Canon two-sphere Explosion Wave Sisyphus. sizeMult: x0.66 boulder impacts
-- below VIOLENT, x1.5 Stomp on VIOLENT+. Inner sphere damages (halved x1/1.5
-- beyond R/2, enemies take damage/10), outer sphere only shoves players.
function UKSisy.Explode( attacker, pos, sizeMult )
  if not SERVER then return end
  sizeMult = sizeMult or 1
  local UNIT = UKSisy.UNIT
  local r1 = UKSisy.EXPLOSION_R1 * sizeMult * UNIT
  local r2 = UKSisy.EXPLOSION_R2 * sizeMult * UNIT
  local D = UKSisy.EXPLOSION_DAMAGE

  for _, ent in ipairs( ents.FindInSphere( pos, r2 ) ) do
    if not IsValid( ent ) or ent == attacker then continue end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
    -- canon toIgnore: the explosion never hurts Insurrectionists
    if ent.UKSisy_IsSisy then continue end

    local center = ent:WorldSpaceCenter()
    local dist = center:Distance( pos )
    local dir = center - pos
    if dir:IsZero() then dir = Vector( 0, 0, 1 ) end
    dir:Normalize()

    if dist <= r1 then
      local atk = IsValid( attacker ) and attacker or game.GetWorld()
      local half = dist > r1 * 0.5 -- canon halves (x1/1.5) beyond R/2
      local amount
      if ent:IsPlayer() then
        amount = UKSisy.ScaleAttackDamage( ent, half and D / 1.5 or D )
      elseif ent.IsUltrakillNextbot then
        -- landed NPC target, pre-divided by the victim's base multiplier
        -- (the old raw x1000 double-dipped into the base's x20 => ~60k)
        local DN = UKSisy.EXPLOSION_DAMAGE_NPC
        amount = UKSisy.PreMultDamage( ent, atk, half and DN / 1.5 or DN )
      else
        -- canon: enemies take damage/10 x enemyDamageMultiplier(1) => flat
        amount = half and D / 1.5 or D
      end
      local dmg = DamageInfo()
      dmg:SetDamage( amount )
      dmg:SetDamageType( DMG_BLAST )
      dmg:SetAttacker( atk )
      dmg:SetInflictor( atk )
      dmg:SetDamagePosition( center )
      dmg:SetDamageForce( dir * 8000 )
      ent:TakeDamageInfo( dmg )
    end
    if ent:IsPlayer() then
      -- outer sphere: pushForce only (canon sphere 2: damage 0, PlayerOnly)
      ent:SetVelocity( dir * 500 + Vector( 0, 0, 250 ) )
    end
  end

  local fx = EffectData()
  fx:SetOrigin( pos )
  fx:SetRadius( r1 )
  util.Effect( "Ultrakill_Explosion", fx, true, true )
  sound.Play( UKSisy.SOUND.Explosion, pos, 120, math.random( 75, 125 ), 1 )
  util.ScreenShake( pos, 8, 40, 0.7, r2 * 2 )
end
