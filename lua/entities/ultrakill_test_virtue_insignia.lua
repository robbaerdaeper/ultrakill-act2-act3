-- lua/entities/ultrakill_test_virtue_insignia.lua
-- Virtue Insignia projectile — canon 3-phase lifecycle.
-- WIND_UP (2s) → ACTIVATING (1s) → LINGER+EXPLODE (1s) → Remove.

AddCSLuaFile()

if not UK_VIRTUE then include("ultrakill/virtue_constants.lua") end

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Virtue Insignia"
ENT.Author      = "ultragmod"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:UpdateTransmitState()
  return TRANSMIT_ALWAYS
end

if SERVER then
  function ENT:Initialize()
    -- Canon ULTRAKILL sphere anchor. TRANSALPHA + alpha 0 делает модель невидимой
    -- но ENT:Draw() hook всё ещё вызывается (RENDERMODE_NONE его блокирует).
    self:SetModel("models/ultrakill/mesh/effects/sphere/sphere_16.mdl")
    self:PhysicsInitBox(Vector(-1,-1,-1), Vector(1,1,1))
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:DrawShadow(false)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(255, 255, 255, 0))

    self.UKInsignia_StartTime  = CurTime()
    self.UKInsignia_Phase      = "WIND_UP"
    self.UKInsignia_Activated  = false
    self.UKInsignia_Exploded   = false
    self.UKInsignia_HitTargets = {}
    self.UKInsignia_LastTargetPos = IsValid(self.UKInsignia_Target)
                                    and (self.UKInsignia_Target:GetPos() + Vector(0,0,4))
                                    or self:GetPos()

    self.UKInsignia_LingerDur = self.UKInsignia_Linger or UK_VIRTUE.INSIGNIA_LINGER

    self:SetNW2Float("UKInsignia_Start",      self.UKInsignia_StartTime)
    self:SetNW2Float("UKInsignia_LingerDur",  self.UKInsignia_LingerDur)
    self:SetNW2Bool ("UKInsignia_Enraged",    self.UKInsignia_Enraged or false)
    self:SetNW2Bool ("UKInsignia_Predictive", self.UKInsignia_Predictive or false)

    self:NextThink(CurTime())
  end

  function ENT:Think()
    if not self:IsValid() then return end

    -- Owner-died guard: if Virtue gone и ещё не в LINGER → remove silently
    if not IsValid(self.UKInsignia_Owner) and self.UKInsignia_Phase ~= "LINGER" then
      self:Remove(); return
    end

    local age = CurTime() - self.UKInsignia_StartTime

    if age < UK_VIRTUE.INSIGNIA_WINDUP then
      self.UKInsignia_Phase = "WIND_UP"
      self:UKInsignia_Track()
    elseif age < UK_VIRTUE.INSIGNIA_WINDUP + UK_VIRTUE.INSIGNIA_ACTIVATE then
      if not self.UKInsignia_Activated then
        self.UKInsignia_Activated = true
        self.UKInsignia_Phase = "ACTIVATING"
        self:SetNW2Bool("UKInsignia_Activating", true)
        if IsValid(self.UKInsignia_Owner) and self.UKInsignia_Owner.UKVirtue_OnInsigniaActivating then
          self.UKInsignia_Owner:UKVirtue_OnInsigniaActivating(self)
        end
        if self.UKInsignia_Predictive then self:UKInsignia_ApplyPredictiveOffset() end
        if (self.UKInsignia_Charges or 1) > 1 then self:UKInsignia_SpawnNextCharge() end
      end
    elseif age < UK_VIRTUE.INSIGNIA_WINDUP + UK_VIRTUE.INSIGNIA_ACTIVATE + self.UKInsignia_LingerDur then
      if not self.UKInsignia_Exploded then
        self.UKInsignia_Exploded = true
        self.UKInsignia_Phase = "LINGER"
        self:SetNW2Bool("UKInsignia_Exploded", true)
        self:UKInsignia_OnExplodeStart()
      end
      self:UKInsignia_DamageTick()
      -- Ручной loop гула луча: перезапускаем на CHAN_BODY чуть раньше конца файла.
      if CurTime() >= (self.UKInsignia_NextBeamSnd or math.huge) then
        self:EmitSound("ultrakill_test/virtue_beam_ambiance.ogg", 85, 100, 0.9, CHAN_BODY)
        self.UKInsignia_NextBeamSnd = CurTime() + 0.98
      end
    else
      self:Remove(); return
    end

    self:NextThink(CurTime())
    return true
  end

  function ENT:UKInsignia_Track()
    if IsValid(self.UKInsignia_Target) then
      self.UKInsignia_LastTargetPos = self.UKInsignia_Target:GetPos() + Vector(0,0,4)
    end
    local tpos = self.UKInsignia_LastTargetPos
    local pos  = self:GetPos()
    local dist = pos:Distance(tpos)
    local dt   = engine.TickInterval()
    -- canon Drone.cs formula: MoveTowards(pos, target, dt*50 + dt*dist*100) — Unity metres
    -- in Source: distance в SU уже, скорость даём в SU/s через ×SCALE_M_TO_SU
    local step = (UK_VIRTUE.INSIGNIA_TRACK_BASE + dist / UK_VIRTUE.SCALE_M_TO_SU * UK_VIRTUE.INSIGNIA_TRACK_DIST) * dt * UK_VIRTUE.SCALE_M_TO_SU
    if step >= dist then
      self:SetPos(tpos)
    else
      local dir = (tpos - pos):GetNormalized()
      self:SetPos(pos + dir * step)
    end
    local ang = self:GetAngles()
    ang.y = ang.y + UK_VIRTUE.INSIGNIA_YAW_TRACK * dt
    self:SetAngles(ang)
  end

  function ENT:UKInsignia_ApplyPredictiveOffset()
    if not IsValid(self.UKInsignia_Target) then return end
    local vel = self.UKInsignia_Target:GetVelocity()
    local offset = Vector(vel.x, vel.y, 0) * UK_VIRTUE.INSIGNIA_PREDICTIVE_T
    self:SetPos(self.UKInsignia_LastTargetPos + offset)
    self.UKInsignia_LastTargetPos = self:GetPos()
  end

  function ENT:UKInsignia_SpawnNextCharge()
    -- canon VirtueInsignia.cs:160-164 — recursive Instantiate immediately в Activating().
    -- Natural stagger between beam взрывами = WINDUP time (2s), не 0.25s.
    if (self.UKInsignia_Charges or 1) <= 1 then return end
    if not IsValid(self.UKInsignia_Owner) then return end
    if not IsValid(self.UKInsignia_Target) then return end
    local ins = ents.Create("ultrakill_test_virtue_insignia")
    if not IsValid(ins) then return end
    ins:SetPos(self.UKInsignia_Owner:LocalToWorld(Vector(24, 0, 16)))
    ins.UKInsignia_Target     = self.UKInsignia_Target
    ins.UKInsignia_Owner      = self.UKInsignia_Owner
    ins.UKInsignia_Enraged    = self.UKInsignia_Enraged
    ins.UKInsignia_Predictive = self.UKInsignia_Predictive
    ins.UKInsignia_Charges    = (self.UKInsignia_Charges or 1) - 1
    ins:Spawn()
  end

  function ENT:UKInsignia_OnExplodeStart()
    util.ScreenShake(self.UKInsignia_LastTargetPos,
                     UK_VIRTUE.CAMERA_SHAKE_AMP, 10, 0.6,
                     UK_VIRTUE.INSIGNIA_RADIUS * 4)
    self:EmitSound("ultrakill_test/virtue_attack.wav", 80, 100, 1, CHAN_STATIC)
    -- Гул стоящего луча: файл 1.03с, а луч висит 2-4с. .ogg через CreateSound в Source
    -- надёжно НЕ зациклился (loop-метки нет) → крутим сами повтором по тику (см. Think).
    self:EmitSound("ultrakill_test/virtue_beam_ambiance.ogg", 85, 100, 0.9, CHAN_BODY)
    self.UKInsignia_NextBeamSnd = CurTime() + 0.98   -- перезапуск чуть раньше конца (бесшовно)
    if IsValid(self.UKInsignia_Owner) and self.UKInsignia_Owner.UKVirtue_OnInsigniaLinger then
      self.UKInsignia_Owner:UKVirtue_OnInsigniaLinger(self)
    end
  end

  function ENT:OnRemove()
    self:StopSound("ultrakill_test/virtue_beam_ambiance.ogg")
  end

  function ENT:UKInsignia_DamageTick()
    local origin = self.UKInsignia_LastTargetPos
    for _, ent in ipairs(ents.FindInSphere(origin, UK_VIRTUE.INSIGNIA_RADIUS)) do
      if not IsValid(ent) then continue end
      if self.UKInsignia_HitTargets[ent] then continue end
      if ent == self or ent == self.UKInsignia_Owner then continue end
      local isPlayer = ent:IsPlayer()
      local isLiving = ent:IsNPC() or ent:IsNextBot() or isPlayer
      if not isLiving then continue end

      self.UKInsignia_HitTargets[ent] = true

      -- Игрок: флэт 50 (не трогать). NPC пака (HP = канон×1000): своя шкала,
      -- причём жертва-нектбот UK-базы сама множит урон по типу атакера
      -- (Virtue = UK-нектбот → ×20) — кормим пре-множительное число, чтобы
      -- приземлилось ровно INSIGNIA_DAMAGE_NPC (рецепт power_spear).
      -- Чужие NPC (HL2/другие DrGBase, HP в игроковой шкале): 50 × dmgmult.
      local attacker = IsValid(self.UKInsignia_Owner) and self.UKInsignia_Owner or self
      local amount = UK_VIRTUE.INSIGNIA_DAMAGE * UK_VIRTUE.TORSO_MULT
      if not isPlayer then
        if ent.IsUltrakillNextbot then
          local mult = isfunction(ent.GetDamageMultiplierConVar)
            and ent:GetDamageMultiplierConVar(attacker) or 1
          amount = UK_VIRTUE.INSIGNIA_DAMAGE_NPC / math.max(mult, 0.01)
        else
          local cv = GetConVar("drg_ultrakill_dmgmult")
          amount = amount * math.max(cv and cv:GetFloat() or 1, 0)
        end
      end

      local dmg = DamageInfo()
      dmg:SetDamage(amount)
      dmg:SetDamageType(DMG_BLAST)
      dmg:SetAttacker(attacker)
      dmg:SetInflictor(self)
      dmg:SetDamageForce(vector_origin)
      dmg:SetDamagePosition(origin)
      ent:TakeDamageInfo(dmg)

      if isPlayer and ent:Alive() then
        local kbDir = (ent:GetPos() - origin); kbDir.z = 0
        if kbDir:IsZero() then kbDir = Vector(0,0,1) else kbDir:Normalize() end
        local v = kbDir * UK_VIRTUE.INSIGNIA_LAUNCH_STR
              + Vector(0, 0, UK_VIRTUE.INSIGNIA_LAUNCH_STR * UK_VIRTUE.INSIGNIA_LAUNCH_MULT * 0.6)
        ent:SetVelocity(v)
      end

      if ent.UltrakillBase_Burn then ent:UltrakillBase_Burn(UK_VIRTUE.INSIGNIA_FLAMMABLE_T) end
    end
  end
end

if CLIENT then
  -- Канон-рендер (ref: ultrakillbase_virtue_beam.lua). НЕ рисуем своих цветов:
  --   * глиф — настоящий VirtueSigil (белая руна, форма в альфе) через DrawBox;
  --   * столб — lightpillar (белый / для ярости красный canon-материал) на растянутой сфере.
  -- lightpillar-материалы примонтированы workshop-базой ultrakillbase.
  local MAT_GLYPH    = Material("models/ultrakill_test/virtue/virtue_sigil")
  local MAT_BEAM     = Material("models/ultrakill/vfx/lightpillars/lightpillar_white")
  local SPHERE_MDL   = "models/ultrakill/mesh/effects/sphere/sphere_16.mdl"
  local INS_RB       = Vector(10000, 10000, 10000)

  function ENT:Initialize()
    self:DrawShadow(false)
    self:SetRenderBounds(-INS_RB, INS_RB)

    self.mBeamCSENT = ClientsideModel(SPHERE_MDL, RENDERGROUP_TRANSLUCENT)
    if IsValid(self.mBeamCSENT) then self.mBeamCSENT:SetNoDraw(true) end
    self.mGlyphRot = 0
  end

  function ENT:OnRemove()
    SafeRemoveEntity(self.mBeamCSENT)
  end

  function ENT:Draw() end  -- реальный render через PostDrawTranslucentRenderables ниже

  function ENT:DrawInsigniaEffect()
    local start      = self:GetNW2Float("UKInsignia_Start", CurTime())
    local age        = CurTime() - start
    local enraged    = self:GetNW2Bool("UKInsignia_Enraged", false)
    local exploded   = self:GetNW2Bool("UKInsignia_Exploded", false)
    local activating = self:GetNW2Bool("UKInsignia_Activating", false)
    local pos        = self:GetPos()

    if not exploded then
      -- Плоский глиф на земле; в фазе activating крутится быстрее (720°/s).
      -- Канон: печать белая, в ярости — КРАСНАЯ.
      local rate = activating and UK_VIRTUE.INSIGNIA_YAW_ACTIVE or UK_VIRTUE.INSIGNIA_YAW_TRACK
      self.mGlyphRot = (self.mGlyphRot + rate * FrameTime()) % 360
      local r = UK_VIRTUE.INSIGNIA_GLYPH_RADIUS
      render.SetMaterial(MAT_GLYPH)
      render.DrawBox(pos + Vector(0, 0, 2), Angle(0, self.mGlyphRot, 0),
                     Vector(-r, -r, 0), Vector(r, r, 0),
                     enraged and Color(255, 55, 55) or color_white)
    else
      if not IsValid(self.mBeamCSENT) then return end
      local linger    = self:GetNW2Float("UKInsignia_LingerDur", UK_VIRTUE.INSIGNIA_LINGER)
      local lingerAge = math.max(0, age - (UK_VIRTUE.INSIGNIA_WINDUP + UK_VIRTUE.INSIGNIA_ACTIVATE))
      local lingerT   = math.Clamp(lingerAge / linger, 0, 1)
      local thick     = Lerp(lingerT, UK_VIRTUE.BEAM_THICKNESS_MAX_SU, 0) / 16
      local hscale    = UK_VIRTUE.BEAM_HEIGHT_SU / 16
      local m = Matrix()
      m:SetScale(Vector(thick, thick, hscale))
      self.mBeamCSENT:SetPos(pos + Vector(0, 0, UK_VIRTUE.BEAM_HEIGHT_SU / 2))
      self.mBeamCSENT:SetAngles(angle_zero)
      self.mBeamCSENT:EnableMatrix("RenderMultiply", m)
      -- Луч дивинного света ВСЕГДА белый (красный lightpillar_stronger_red = чёрный, $color2 0 0 0).
      render.MaterialOverride(MAT_BEAM)
      self.mBeamCSENT:DrawModel()
      render.MaterialOverride()
    end
  end

  hook.Add("PostDrawTranslucentRenderables", "UKVirtueInsignia_Draw", function(_, bSkybox)
    if bSkybox then return end
    for _, ins in ipairs(ents.FindByClass("ultrakill_test_virtue_insignia")) do
      if IsValid(ins) and ins.DrawInsigniaEffect then ins:DrawInsigniaEffect() end
    end
  end)
end
