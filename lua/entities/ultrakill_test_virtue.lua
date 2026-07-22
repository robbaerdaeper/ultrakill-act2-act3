-- lua/entities/ultrakill_test_virtue.lua
-- Virtue (Lesser Angel) — canon-faithful port. DrGBase Flying pattern (ref: ultrakill_drone act1).

AddCSLuaFile()

if not UK_VIRTUE       then include("ultrakill/virtue_constants.lua") end
if SERVER and not UK_VirtueGlobal then include("ultrakill/virtue_global.lua") end

local BaseClass = baseclass.Get("ultrakillbase_nextbot")

if CLIENT then
  -- Принудительно загрузить модель чтобы избежать кеш проблем.
  util.PrecacheModel("models/ultrakill_prelude_test/virtue_v2.mdl")
end

ENT.Type        = "nextbot"
ENT.Base        = "ultrakillbase_nextbot"
ENT.PrintName   = "Virtue"
ENT.Author      = "ultragmod"
ENT.Spawnable   = true
ENT.Category    = "ULTRAKILL - Enemies"

ENT.Models      = { "models/ultrakill_prelude_test/virtue_v2.mdl" }
ENT.ModelScale  = 1.0
ENT.SpawnHealth = UK_VIRTUE.HP
ENT.CollisionBounds   = Vector(28, 28, 64)
ENT.SurroundingBounds = Vector(256, 256, 512)

-- DrGBase Flying — ставит loco:SetGravity(0), SetStepHeight(0), velocity 0 в InitializeFlying.
ENT.Flying           = true
ENT.FlyingHeight     = 96

ENT.AISight          = false
ENT.MeleeAttackRange = 10000
ENT.ReachEnemyRange  = math.huge
ENT.AvoidEnemyRange  = 0
ENT.Acceleration = 5500
ENT.Deceleration = 2500
ENT.JumpHeight       = 0
ENT.StepHeight       = 0
ENT.MaxYawRate       = 400
ENT.DeathDropHeight  = math.huge
ENT.UseWalkframes    = false
ENT.WalkSpeed        = 1000
ENT.RunSpeed         = 1000
ENT.IdleAnimation    = "Idle"; ENT.IdleAnimRate = 1
ENT.WalkAnimation    = "Idle"; ENT.WalkAnimRate = 1
ENT.RunAnimation     = "Idle"; ENT.RunAnimRate  = 1
ENT.JumpAnimation    = "Idle"; ENT.JumpAnimRate = 1

ENT.UltrakillBase_FullTrackingBone = ""
ENT.UltrakillBase_FullTracking     = false

-- canon EnemyIdentifier weight = medium; without this the ultrakillbase
-- default "Light" made the whiplash reel the virtue into the player
-- (workshop report 2026-07-10)
ENT.UltrakillBase_WeightClass = "Medium"

ENT.NW_PARRYABLE = "UKVirtue_Parryable"
ENT.NW_ATTACKS   = "UKVirtue_Attacks"

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled   = true
-- Летун: ultrakillbase PossessionControls (CUSTOM) сам ведёт полёт через ApproachFlying по взгляду.
ENT.PossessionMovement  = POSSESSION_MOVE_CUSTOM
ENT.PossessionViews = {

  {

    offset = Vector(0, 12, 40),
    distance = 140,
    eyepos = false

  },

  {

    offset = Vector(7, 0, 0),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- Те же гейты, что у UKVirtue_TickAttack (свой КД + глобальный round-robin),
    -- иначе зажатая кнопка спамит инсигнии в обход shared cooldown.
    if CurTime() < (self.UKVirtue_NextAttack or 0) then return end
    if not UK_VirtueGlobal.CanAttack(self) then return end

    local target = self:PossessionGetLockedOn()

    self:UKVirtue_SpawnInsignia(target)

    -- Без lock-on инсигнии некого трекать (зависла бы у точки спавна) —
    -- якорим её на точку прицела.
    if not IsValid(target) and IsValid(self.UKVirtue_ActiveInsignia) then
      local tr = self:PossessorTrace()
      if tr then self.UKVirtue_ActiveInsignia.UKInsignia_LastTargetPos = tr.HitPos + Vector(0, 0, 4) end
    end

  end } },

}

if SERVER then
  function ENT:CustomInitialize()
    self:SetTurning(true)

    self.UKVirtue_NextAttack       = CurTime() + UK_VIRTUE.ATTACK_CD_INITIAL
    self.UKVirtue_AttackCount      = 0
    self.UKVirtue_Enraged          = false
    self.UKVirtue_Parryable        = false
    self.UKVirtue_ActiveInsignia   = nil
    self.UKVirtue_NextEnrageCheck  = 0

    self:SetNW2Int (self.NW_ATTACKS,   0)
    self:SetEnraged(false)                        -- база UltrakillBase: IsEnraged/healthbar
    self:SetNW2Bool(self.NW_PARRYABLE, false)

    UK_VirtueGlobal.Register(self)
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn(self)
    UltrakillBase.TraceSetPos(self, self:GetPos() + Vector(0, 0, 80))
    self:SetCooldown( "Attack", 1 )
    self.CanDodge = true
  end

  function ENT:OnRemove() UK_VirtueGlobal.Unregister(self) end

  function ENT:UKVirtue_GetEnemy()
    local enemy = self:GetEnemy()
    if IsValid(enemy) then return enemy end
    -- Fallback-скан (AISight=false → DrGBase не всегда сам ставит врага),
    -- но УВАЖАЕМ отношения: если игрок помечен нейтральным/дружественным
    -- (инструмент DrGBase "Disable/Relationship" или UltrakillBase_Friendly),
    -- виртуха его игнорирует и не атакует.
    local closest, cdist = nil, math.huge
    for _, ply in ipairs(player.GetAll()) do
      if not ply:Alive() then continue end
      if ply.UltrakillBase_Friendly then continue end
      if self.IsEnemy and not self:IsEnemy(ply) then continue end
      local d = self:GetPos():DistToSqr(ply:GetPos())
      if d < cdist then closest = ply; cdist = d end
    end
    return closest
  end

  function ENT:UKVirtue_GetDifficulty()
    -- Канон-сложность = строковый convar drg_ultrakill_difficulty (HARMLESS..BRUTAL).
    -- UltrakillBase.GetDifficulty маппит в число (дефолт VIOLENT=3). Старое чтение
    -- несуществующего "ultrakill_difficulty" всегда давало 2 → enrage/linger ломались.
    if UltrakillBase and UltrakillBase.GetDifficulty then
      return UltrakillBase.GetDifficulty()
    end
    return 3
  end

  -- CustomThink вызывается каждый tick от DrGBase AI loop.
  -- DrGBase сам разруливает hover/chase через HandleEnemyFlyingPathing.
  -- ВАЖНО: DrGBase зовёт CustomThink ДАЖЕ при ai_disable (в отличие от BehaveStart-корутины),
  -- поэтому атаку/додж/энрейдж надо явно гейтить по IsAIDisabled, иначе виртуха
  -- продолжает стрелять при выключенном AI.
  function ENT:CustomThink()
   if not self:HasEnemy() or not self.CanDodge or self:IsAIDisabled() then return end
  local Enemy = self:GetEnemy()

  if self:IsInRange( Enemy, self.ReachEnemyRange ) and not self:IsInRange( Enemy, 200 ) and self:GetCooldown( "Dodge" ) <= 0 then

    self:CallInCoroutine( self.DroneDodge, Enemy, "Side" )

    -- the difference between drones and virtues is that they dont attempt to dash back like drones do. they only dash back when hit in close range!
  --elseif self:IsInRange( Enemy, 200 ) and self:GetCooldown( "Back" ) <= 0 then

    --self:CallOverCoroutine( self.DroneDodge, false, Enemy, "Back", true )

  end
  end

  function ENT:OnMeleeAttack( Enemy )
  if self:GetCooldown( "Attack" ) > 0 then return end
  self:UKVirtue_SpawnInsignia(Enemy)
  self:SetCooldown( "Attack", 8 )
  self:UKVirtue_CheckEnrageTriggers()
  end

function ENT:DroneDodge( Enemy, Direction, Skip ) -- Virtues ingame actually use drones as a base for their AI, so we can just reuse the code from ACT 1 enemies and tweak it a bit.

  if self:GetCooldown( "Dodge" ) > 0 and not Skip or self:GetCooldown( "Back" ) > 0 then return end

  if Direction == "Back" then

    Direction = -self:GetAimVector()

    self:SetCooldown( "Back", 0.33333 / self:CalculateAnimRate() )

  elseif Direction == "Side" then

    Direction = self:GetAimAngles():Right() * math.random( -1,1 ) + self:GetAimAngles():Up() * math.random( -1,1 ) 

    self:SetCooldown( "Dodge", ( math.random( 4, 8 ) / self:CalculateAnimRate() ) + 1 )

  end

  local Old_Speed = self:GetDesiredSpeed()

  local Now = CurTime() + 0.2

  self:SetDesiredSpeed( 1000 )

  while true do

    local Enemy = self:GetEnemy()

    if CurTime() > Now or not IsValid( Enemy ) then break end

    self:LookTowards( Enemy )
    self:ApproachFlying( self:GetPos() + Direction )

    self:YieldCoroutine( false )

  end

  self:SetDesiredSpeed( Old_Speed )

end

  function ENT:UKVirtue_SpawnInsignia(target)
    UK_VirtueGlobal.OnAttackStart(self)
    local ins = ents.Create("ultrakill_test_virtue_insignia")
    if not IsValid(ins) then return end
    ins:SetPos(self:LocalToWorld(Vector(24, 0, 16)))
    ins.UKInsignia_Target     = target
    ins.UKInsignia_Owner      = self
    ins.UKInsignia_Enraged    = self.UKVirtue_Enraged
    ins.UKInsignia_Predictive = self.UKVirtue_Enraged
    ins.UKInsignia_Charges    = 1
    -- Brutal (сложность ≥4): луч висит намного дольше.
    ins.UKInsignia_Linger     = (self:UKVirtue_GetDifficulty() >= 4)
                                and UK_VIRTUE.INSIGNIA_LINGER_BRUTAL or UK_VIRTUE.INSIGNIA_LINGER
    ins:Spawn()

    self.UKVirtue_ActiveInsignia = ins
    self.UKVirtue_Parryable      = true
    self:SetNW2Bool(self.NW_PARRYABLE, true)
    self.UKVirtue_AttackCount = self.UKVirtue_AttackCount + 1
    self:SetNW2Int(self.NW_ATTACKS, self.UKVirtue_AttackCount)
    local cd = math.Rand(UK_VIRTUE.ATTACK_CD_MIN, UK_VIRTUE.ATTACK_CD_MAX)
    if self.UKVirtue_Enraged then cd = cd * UK_VIRTUE.ENRAGE_ATTACK_CD_MULT end
    self.UKVirtue_NextAttack = CurTime() + UK_VIRTUE.INSIGNIA_WINDUP + cd
    UltrakillBase.SoundScript( "Ultrakill_VirtueCharge", self:GetPos(), self )
  end

  -- Attack идёт ТОЛЬКО через TickAttack (CustomThink). OnMeleeAttack убран чтоб не было
  -- двух атак одновременно от DrGBase HandleAttacking + наш timer.

  function ENT:UKVirtue_OnInsigniaActivating(ins)
    UK_VirtueGlobal.OnWindupComplete(self)
  end

  function ENT:UKVirtue_OnInsigniaLinger(ins)
    self.UKVirtue_Parryable = false
    self:SetNW2Bool(self.NW_PARRYABLE, false)
    self.UKVirtue_ActiveInsignia = nil
  end

  function ENT:UKVirtue_CheckEnrageTriggers()
    if self:IsEnraged() then return end
    if UK_VirtueGlobal.Count() >= UK_VIRTUE.MAX_VIRTUES_ENRAGE then return end

    local diff      = self:UKVirtue_GetDifficulty()
    local threshold = UK_VIRTUE.ENRAGE_USED_ATTACKS[diff] or 99
    if threshold >= 99 then return end                 -- Harmless/Lenient: enrage запрещён
    local blessed   = self.UltrakillBase_Blessed == true
    local condAtks  = (self.UKVirtue_AttackCount >= threshold)  -- канон: «after three attacks»
    if not (condAtks or blessed) then return end

    self:UKVirtue_Enrage()
  end

  -- Свап сабматериала по подстроке имени (server → реплицируется клиентам).
  function ENT:UKVirtue_SetSubMat(needle, mat)
    for i, m in ipairs(self:GetMaterials()) do
      if string.find(string.lower(m), needle, 1, true) then
        self:SetSubMaterial(i - 1, mat)
      end
    end
  end

  function ENT:UKVirtue_Enrage()
    if self:IsEnraged() then return end
    self.UKVirtue_Enraged = true

    -- Звук ярости ПЕРВЫМ (база SetEnraged звука НЕ даёт). Берём КАНОН из базы, как MDK:
    -- Ultrakill_Enrage = ultrakill/sound/enrage.wav (рёв) + Ultrakill_Enrage_Loop = rageloop.wav
    -- (луп, parent=self → снимается со смертью). НЕ реплики Power'а.
    UltrakillBase.SoundScript("Ultrakill_Enrage", self:GetPos(), self)
    UltrakillBase.SoundScript("Ultrakill_Enrage_Loop", self:GetPos(), self)

    self:SetEnraged(true)                              -- база: IsEnraged/healthbar-цвет
    -- Оболочка-шар → канон красная полупрозрачная (ядро — отдельный материал, не трогается).
    self:UKVirtue_SetSubMat("sphere", "models/ultrakill_test/virtue/virtue_sphere_enraged")
    -- НАТИВНЫЙ базовый enrage-эффект (белый RageEffect + красные молнии), как у mdk/power.
    -- Атачмент "enrage" в центре сферы делает GetAttachment валидным (иначе DrawEnraged краш).
    local att = self:LookupAttachment("enrage")
    self:CreateEnrage(att > 0 and att or 1, 1.2)
    util.ScreenShake(self:GetPos(), 8, 10, 0.6, 700)
    -- ярость раскрывает крылья (красные) и укорачивает КД до следующей атаки
    self.UKVirtue_NextAttack = math.min(self.UKVirtue_NextAttack, CurTime() + 0.4)
  end

  function ENT:OnHurt(dmg, hitgroup)
    if math.random() < 0.3 then
      self:EmitSound("ultrakill_test/virtue_hurt.wav", 70, math.random(90, 110), 1, CHAN_VOICE)
    end
    if not self.UKVirtue_Parryable then return end
    local attacker = nil
    if dmg.GetAttacker then attacker = dmg:GetAttacker() end
    local hitter = nil
    if IsValid(attacker) then
      hitter = attacker.UltrakillBase_LastHitterTag
            or (dmg:IsDamageType(DMG_CLUB) and "punch" or nil)
    end
    if not hitter or not UK_VIRTUE.PARRY_HITTER_TAGS[hitter] then return end

    local hasFrames = IsValid(attacker)
                  and attacker.UltrakillBase_ParryFramesLeft
                  and attacker.UltrakillBase_ParryFramesLeft > 0
    local frameMult = hasFrames and UK_VIRTUE.PARRY_DMG_MULT_FRAME or UK_VIRTUE.PARRY_DMG_MULT_OPEN
    dmg:SetDamage(dmg:GetDamage() * frameMult)

    if IsValid(attacker) and attacker:IsPlayer() then
      local fwd = attacker:GetAimVector()
      self:CallOverCoroutine( self.DroneDodge, false, Enemy, "Back", true )
    end

    self.UKVirtue_Parryable = false
    self:SetNW2Bool(self.NW_PARRYABLE, false)
    if UK_VIRTUE.PARRY_CANCEL_INSIGNIA and IsValid(self.UKVirtue_ActiveInsignia) then
      UK_VirtueGlobal.OnWindupComplete(self)
      self.UKVirtue_ActiveInsignia:Remove()
      self.UKVirtue_ActiveInsignia = nil
    end
  end

  function ENT:OnKilled(dmginfo)
    self:EmitSound("ultrakill_test/virtue_death.wav", 75, 100, 1, CHAN_VOICE)
    -- Канон-труп = ТОЛЬКО голубой шар с ядром-ромбом (цепи/корона скрыты). Никаких обломков.
    local rs = ents.Create("ultrakill_test_virtue_ragdoll_sphere")
    if IsValid(rs) then
      rs:SetPos(self:GetPos() + Vector(0, 0, 32))
      rs:SetAngles(self:GetAngles())
      rs.UKRS_Mode    = "ball"
      rs.UKRS_Enraged = self:IsEnraged()     -- сфера красная, если умер в ярости
      rs:Spawn()
      local phys = rs:GetPhysicsObject()
      if IsValid(phys) then
        phys:SetVelocity(Vector(math.Rand(-40, 40), math.Rand(-40, 40), 90))
      end
    end

    UK_VirtueGlobal.Unregister(self)
    self:Remove()
  end
end

if CLIENT then
  -- Все эффекты рисуем БЕЗ собственного цвета: цвет берётся из самих текстур
  -- (charge — сине-циановый, wings — синие/красные), color_white только модулирует альфу.
  local MAT_AURA    = Material("models/ultrakill_test/virtue/virtue_aura")          -- charge glow (cyan)
  local MAT_WING    = Material("models/ultrakill_test/virtue/virtue_wing")          -- divine_orthos_wings (blue)
  local MAT_WING_EN = Material("models/ultrakill_test/virtue/virtue_wing_enraged")  -- divine_enraged_wings (red)
  local vUp   = Vector(0, 0, 1)

  -- Canon Virtue: Divine Orthos радиально-симметричен → всегда «смотрит» на игрока.
  function ENT:GetRenderAngles()
    local ply = LocalPlayer()
    if not IsValid(ply) then return self:GetAngles() end
    local diff = ply:EyePos() - self:GetPos()
    if diff:IsZero() then return self:GetAngles() end
    return diff:Angle()
  end

  -- Плавное раскрытие крыльев: raise при windup-парри и в энрейдже, иначе отдых.
  function ENT:UKVirtue_WingExtend()
    local parryable = self:GetNW2Bool(self.NW_PARRYABLE, false)
    local enraged   = self:IsEnraged()
    local target    = (parryable or enraged) and UK_VIRTUE.WING_EXTEND_SCALE or UK_VIRTUE.WING_REST_SCALE
    local cur = self.UKVirtue_WingCur or UK_VIRTUE.WING_REST_SCALE
    cur = Lerp(FrameTime() * 6, cur, target)
    self.UKVirtue_WingCur = cur
    return cur
  end

  function ENT:UKVirtue_DrawWings(enraged)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local center = self:GetPos() + Vector(0, 0, UK_VIRTUE.WING_CENTER_Z)
    -- Горизонтальный «право» относительно взгляда игрока; плоскость (right, vUp) фронтом к игроку.
    local toPly = ply:EyePos() - center; toPly.z = 0
    if toPly:IsZero() then toPly = self:GetForward() end
    toPly:Normalize()
    local right = toPly:Cross(vUp); right:Normalize()

    local ext  = self:UKVirtue_WingExtend()
    local flap = math.sin(CurTime() * 3) * 4                       -- лёгкий взмах ±4°
    local L    = UK_VIRTUE.WING_LEN   * ext
    local W    = UK_VIRTUE.WING_WIDTH * ext
    local ang  = math.rad(UK_VIRTUE.WING_ANGLE + flap)
    local col  = Color(255, 255, 255, UK_VIRTUE.WING_ALPHA)
    render.SetMaterial(enraged and MAT_WING_EN or MAT_WING)

    for _, side in ipairs({ 1, -1 }) do
      -- крыло тянется вверх-наружу (dOut) от корня; сужается к кончику по dPerp.
      local dOut  = right * (side *  math.cos(ang)) + vUp * math.sin(ang)
      local dPerp = right * (side * -math.sin(ang)) + vUp * math.cos(ang)
      local root  = center + right * (side * UK_VIRTUE.WING_INSET) + vUp * UK_VIRTUE.WING_UP_OFFSET
      local hR    = W * 0.5
      local hT    = W * 0.5 * UK_VIRTUE.WING_TAPER
      local rB = root + dPerp * hR                    -- root-back
      local rF = root - dPerp * hR                    -- root-front
      local tB = root + dOut * L + dPerp * hT          -- tip-back
      local tF = root + dOut * L - dPerp * hT          -- tip-front
      -- зеркалим UV для второй стороны (обратный обход вершин)
      if side > 0 then render.DrawQuad(rF, tF, tB, rB, col)
      else             render.DrawQuad(rB, tB, tF, rF, col) end
    end
  end

  -- Циан-ореол заряда ТОЛЬКО вне ярости. В ярости эффект рисует НАТИВНАЯ база
  -- (CreateEnrage/DrawEnraged через _BaseDraw) — своих костылей не рисуем.
  function ENT:UKVirtue_DrawAura()
    local pos   = self:GetPos() + Vector(0, 0, UK_VIRTUE.WING_CENTER_Z)
    local pulse = 0.9 + 0.1 * math.sin(CurTime() * 2)
    local r     = UK_VIRTUE.AURA_RING_MAX_RADIUS * pulse
    render.SetMaterial(MAT_AURA)
    render.DrawSprite(pos, r * 2, r * 2, Color(255, 255, 255, 70))
  end

  -- CustomDraw вызывается базой ПОСЛЕ DrawModel() и _BaseDraw() (enrage/sand/shake),
  -- поэтому свою модель тут повторно НЕ рисуем и базовый enrage-слой не теряем.
  function ENT:CustomDraw()
    local enraged = self:IsEnraged()
    self:UKVirtue_DrawWings(enraged)   -- крылья: вне ярости синие, в ярости красные (канон-запрос)
    if not enraged then self:UKVirtue_DrawAura() end
  end
end

DrGBase.AddNextbot(ENT)

list.Set("NPC", "ultrakill_test_virtue", {
  Name      = ENT.PrintName,
  Class     = "ultrakill_test_virtue",
  Category  = ENT.Category,
  AdminOnly = false,
})

-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (x10 player damage twice = x100).
if SERVER then
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end
end
