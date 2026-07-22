AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Earthmover Brain (канон Brain, 7-4 вторая фаза). HP 100, boss bar
-- «1000-THR "EARTHMOVER"». Висит на месте (канон: закреплён в камере).
-- Форсфилд: контакт 10 dmg + отброс. Giant Hell Seeker каждые 3 c при
-- HP <= 50% (convar ultrakill_em_brain_alwaysfire 1 = сразу, канон hard+).
-- Затяжка боя -> 2 Idol (полный хил если доживут; реюз ultrakill_test_idol).
-- Отражённые снаряды бьют мозг x1.4 (флаг UKEM_IsBrain -> seeker proj).

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Earthmover Brain"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKEarthmover.MODEL_BRAIN }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKEarthmover.BRAIN_HP
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon: Defence System (ultrakill.wiki.gg/wiki/Enemies)

-- закреплён: парит без движения (меш ~19 м шириной, origin в центре мяса)
ENT.Flying = true
ENT.FlyingHeight = 400
ENT.WalkSpeed = 0
ENT.RunSpeed = 0
ENT.Acceleration = 0
ENT.MaxYawRate = 0
ENT.UseWalkframes = false

ENT.CollisionBounds = Vector( 380, 380, 500 )
ENT.SurroundingBounds = Vector( 900, 900, 900 )

ENT.IdleAnimation = "idle"
ENT.WalkAnimation = "idle"
ENT.RunAnimation = "idle"
ENT.JumpAnimation = "idle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "idle"
-- base multiplies this blindly whenever airborne — nil crashes OnUpdateAnimation
ENT.FallingAnimRate = 1

ENT.UKEM_IsBrain = true

local NW_FIELD = "UKEM_Brain_Field"
local NW_IDOLS = "UKEM_Brain_IdolT"    -- 0..1 прогресс прибытия Idol

if SERVER then

  local cvAlwaysFire = CreateConVar( "ultrakill_em_brain_alwaysfire", "0",
    FCVAR_ARCHIVE, "Brain fires homing orbs from full HP (canon Violent+)" )
  local cvIdols = CreateConVar( "ultrakill_em_brain_idols", "1",
    FCVAR_ARCHIVE, "Brain summons 2 protective Idols when the fight drags on" )

  function ENT:CustomInitialize()
    self:SetMaxHealth( self.SpawnHealth )
    self:SetHealth( self.SpawnHealth )

    self.UKEM_Dead = false
    self.UKEM_NextOrb = 0
    self.UKEM_FieldHitCD = {}
    self.UKEM_CombatSince = nil
    self.UKEM_IdolsSummoned = false
    self.UKEM_IdolArriveAt = nil
    self.UKEM_Idols = {}
    -- радиус форсфилда от коллизии
    self.UKEM_FieldRadius = self.CollisionBounds.x
      * UKEarthmover.FORCEFIELD_RADIUS_MULT * self:GetModelScale()

    self:SetNW2Bool( NW_FIELD, true )
    self:SetNW2Float( NW_IDOLS, 0 )

    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, "1000-THR \"EARTHMOVER\"" )
    end
  end

  -- висит: пустое поведение
  function ENT:OnIdle() end
  function ENT:OnChaseEnemy( enemy ) end

  function ENT:UKEM_OrbActive()
    if cvAlwaysFire:GetBool() then return true end
    return self:Health() <= self:GetMaxHealth() * UKEarthmover.BRAIN_ORB_AT_HP
  end

  function ENT:UKEM_FireOrb( enemy )
    self:EmitSound( UKEarthmover.SOUND.BrainOrb, 85, 80, 1.0 )
    local pos = self:WorldSpaceCenter()
      + ( enemy:WorldSpaceCenter() - self:WorldSpaceCenter() ):GetNormalized()
      * ( self.UKEM_FieldRadius + 40 )
    local proj = self:CreateProjectile( "ultrakill_test_em_seeker_proj", true )
    if not IsValid( proj ) then return end
    proj.UKEM_Giant = true
    proj:SetPos( pos )
    local dir = ( enemy:WorldSpaceCenter() - pos ):GetNormalized()
    proj:SetAngles( dir:Angle() )
    proj:SetVelocity( dir * UKEarthmover.BRAIN_ORB_SPEED )
  end

  function ENT:UKEM_TickForcefield( now )
    for _, ent in ipairs( ents.FindInSphere( self:WorldSpaceCenter(),
        self.UKEM_FieldRadius ) ) do
      if ent == self then continue end
      if not ( ent:IsPlayer() or ( ent:IsNPC() or ent:IsNextBot() )
        and not ent.UKEM_IsBrain ) then continue end
      if ent:GetClass() == "ultrakill_test_idol" then continue end
      local key = ent:EntIndex()
      if ( self.UKEM_FieldHitCD[ key ] or 0 ) > now then continue end
      self.UKEM_FieldHitCD[ key ] = now + 0.5

      UKEarthmover.DealDamage( ent, self, self, UKEarthmover.FORCEFIELD_DAMAGE,
        DMG_SHOCK )
      -- канон: отброс от поля
      local push = ( ent:WorldSpaceCenter() - self:WorldSpaceCenter() ):GetNormalized()
      push.z = math.max( push.z, 0.35 )
      ent:SetVelocity( push * UKEarthmover.FORCEFIELD_KNOCKBACK )
      self:EmitSound( UKEarthmover.SOUND.Forcefield, 75, 110, 0.6 )
    end
  end

  function ENT:UKEM_SummonIdols()
    self.UKEM_IdolsSummoned = true
    self.UKEM_IdolArriveAt = CurTime() + UKEarthmover.BRAIN_IDOL_ARRIVE
    for i = 1, 2 do
      local ang = self:GetAngles().yaw + ( i == 1 and 90 or 270 )
      local dir = Angle( 0, ang, 0 ):Forward()
      local pos = self:GetPos() + dir * ( self.UKEM_FieldRadius + 150 )
      local tr = util.TraceLine( {
        start = pos, endpos = pos - Vector( 0, 0, 3000 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      if tr.Hit then pos = tr.HitPos + Vector( 0, 0, 10 ) end
      local idol = ents.Create( "ultrakill_test_idol" )
      if IsValid( idol ) then
        idol:SetPos( pos )
        idol:Spawn()
        table.insert( self.UKEM_Idols, idol )
      end
    end
  end

  function ENT:UKEM_IdolsAlive()
    local n = 0
    for _, idol in ipairs( self.UKEM_Idols ) do
      if IsValid( idol ) and idol:Health() > 0 then n = n + 1 end
    end
    return n
  end

  function ENT:CustomThink()
    if self.UKEM_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable
    local now = CurTime()

    self:UKEM_TickForcefield( now )

    local enemy = self:GetEnemy()
    local inCombat = IsValid( enemy ) and enemy:Health() > 0

    -- Giant Hell Seeker
    if inCombat and self:UKEM_OrbActive() and now >= self.UKEM_NextOrb then
      self.UKEM_NextOrb = now + UKEarthmover.BRAIN_ORB_DELAY
      self:UKEM_FireOrb( enemy )
    end

    -- Idol summon при затяжке боя
    if cvIdols:GetBool() then
      if inCombat then
        self.UKEM_CombatSince = self.UKEM_CombatSince or now
        if not self.UKEM_IdolsSummoned
          and now - self.UKEM_CombatSince >= UKEarthmover.BRAIN_IDOL_DELAY
          and self:Health() < self:GetMaxHealth() then
          self:UKEM_SummonIdols()
        end
      end

      if self.UKEM_IdolArriveAt then
        local left = self.UKEM_IdolArriveAt - now
        self:SetNW2Float( NW_IDOLS,
          math.Clamp( 1 - left / UKEarthmover.BRAIN_IDOL_ARRIVE, 0, 1 ) )
        if left <= 0 then
          self.UKEM_IdolArriveAt = nil
          self:SetNW2Float( NW_IDOLS, 0 )
          -- канон: Idol доехали -> полный хил
          if self:UKEM_IdolsAlive() > 0 then
            self:SetHealth( self:GetMaxHealth() )
            self:EmitSound( "items/medshot4.wav", 80, 70, 1.0 )
          end
        end
      end
    end
  end

  function ENT:OnDeath( dmg, hitGroup )
    if self.UKEM_Dead then return end
    self.UKEM_Dead = true
    self:SetNW2Bool( NW_FIELD, false )

    self:EmitSound( UKEarthmover.SOUND.BrainDeath, 100, 100, 1.0 )
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:WorldSpaceCenter() )
    local ed = EffectData()
    ed:SetOrigin( self:WorldSpaceCenter() )
    ed:SetScale( 3 )
    util.Effect( "Explosion", ed )

    -- призванные Idol умирают вместе с мозгом
    for _, idol in ipairs( self.UKEM_Idols or {} ) do
      if IsValid( idol ) then idol:Remove() end
    end
  end

else -- CLIENT

  local MAT_GLOW = Material( "sprites/light_glow02_add" )
  local COL_FIELD = Color( 90, 220, 255, 40 )
  local COL_FIELD_EDGE = Color( 120, 230, 255, 120 )

  function ENT:CustomInitialize()
    local rb = Vector( 900, 900, 900 )
    self:SetRenderBounds( -rb, rb )
  end

  function ENT:CustomDraw()
    if self:Health() <= 0 then return end
    if not self:GetNW2Bool( NW_FIELD, false ) then return end

    local center = self:WorldSpaceCenter()
    local r = self:OBBMaxs().x * UKEarthmover.FORCEFIELD_RADIUS_MULT
      * self:GetModelScale() * 2.2

    -- электрическое поле: пульсирующий глоу + мерцающие дуги
    render.SetMaterial( MAT_GLOW )
    local pulse = 1 + 0.06 * math.sin( CurTime() * 6 )
    render.DrawSprite( center, r * 2.2 * pulse, r * 2.2 * pulse, COL_FIELD )
    render.DrawSprite( center, r * 1.4, r * 1.4, COL_FIELD_EDGE )

    -- индикатор прибытия Idol (голубая полоска канона — рисуем кольцом)
    local idolT = self:GetNW2Float( NW_IDOLS, 0 )
    if idolT > 0 then
      local flick = math.sin( CurTime() * 20 ) > 0 and 255 or 180
      render.DrawSprite( center + Vector( 0, 0, r * 1.2 ), 60 + 40 * idolT,
        60 + 40 * idolT, Color( 64, 191, 255, flick ) )
    end
  end

end

-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (x10 player damage twice = x100).
if SERVER then
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    baseclass.Get( "ultrakillbase_nextbot" ).OnTakeDamage( self, dmg, hitgroup )
  end
end
