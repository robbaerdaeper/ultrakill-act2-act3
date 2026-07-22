AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- Общая база стационарных компонентов Earthmover Defense System.
-- Канон: все компоненты неподвижны (TempSpider — пустой EnemyScript),
-- HP 15, стрельба data-driven (MortarLauncher / DroneFlesh).

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Earthmover Component"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.Category = UKEarthmover.CATEGORY

ENT.Models = { UKEarthmover.MODEL_TOWER }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKEarthmover.COMPONENT_HP
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon: Defence System (ultrakill.wiki.gg/wiki/Enemies)

-- стационарные: не ходят и не поворачиваются корпусом
ENT.WalkSpeed = 0
ENT.RunSpeed = 0
ENT.Acceleration = 0
ENT.Deceleration = 0
ENT.MaxYawRate = 0
ENT.JumpHeight = 0
ENT.StepHeight = 0
ENT.UseWalkframes = false

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 0
ENT.AvoidEnemyRange = 0

ENT.IdleAnimation = "idle"
ENT.IdleAnimRate = 1.0
ENT.WalkAnimation = "idle"
ENT.RunAnimation = "idle"
ENT.JumpAnimation = "idle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "idle"
-- base multiplies this blindly whenever airborne — nil crashes OnUpdateAnimation
ENT.FallingAnimRate = 1

-- переопределяются наследниками
ENT.UKEM_Kind = "component"     -- "rocket" | "mortar" | "tower"
ENT.UKEM_HasDeploy = true
ENT.UKEM_DeployLen = 1.37       -- Deploy клип 41 кадр @30

if SERVER then

  function ENT:CustomInitialize()
    self:SetMaxHealth( self.SpawnHealth )
    self:SetHealth( self.SpawnHealth )

    -- origin модели у ВЕРХА (префаб-конвенция): поднимаем над землёй
    local mins = self:OBBMins()
    if mins.z < -10 then
      self:SetPos( self:GetPos() + Vector( 0, 0, -mins.z ) )
    end

    self.UKEM_Dead = false
    self.UKEM_NextFire = CurTime() + ( self.UKEM_FirstDelay or 2.0 )

    if self.UKEM_HasDeploy then
      self:UKEM_PlaySeq( "deploy" )
      self.UKEM_DeployUntil = CurTime() + self.UKEM_DeployLen
      self:EmitSound( UKEarthmover.SOUND.Deploy, 80, 100, 0.8 )
      self.UKEM_NextFire = math.max( self.UKEM_NextFire,
        self.UKEM_DeployUntil + 0.2 )
    else
      self.UKEM_DeployUntil = 0
    end

    self:UKEM_ComponentInit()
  end

  function ENT:UKEM_ComponentInit() end

  function ENT:UKEM_PlaySeq( name )
    local seq = self:LookupSequence( name )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1.0 )
      -- держим секвенцию против анимационного драйвера базы
      self.UKEM_ActionSeq = name
      self.UKEM_ActionUntil = CurTime() + self:SequenceDuration( seq )
    end
  end

  function ENT:OnUpdateAnimation()
    if self.UKEM_ActionSeq and CurTime() < ( self.UKEM_ActionUntil or 0 ) then
      return self.UKEM_ActionSeq, 1.0
    end
    self.UKEM_ActionSeq = nil
    return "idle", 1.0
  end

  function ENT:OnUpdateSpeed()
    return 0 -- стационарные
  end

  -- стоим на месте: пустое поведение
  function ENT:OnIdle() end
  function ENT:OnChaseEnemy( enemy ) end

  function ENT:UKEM_TargetPos( enemy )
    if not IsValid( enemy ) then return nil end
    if enemy:IsPlayer() then
      return enemy:GetPos() + Vector( 0, 0, 36 ), enemy
    end
    return enemy:WorldSpaceCenter(), enemy
  end

  function ENT:CustomThink()
    if self.UKEM_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable
    local now = CurTime()
    if now < ( self.UKEM_DeployUntil or 0 ) then return end

    local enemy = self:GetEnemy()
    if not IsValid( enemy ) or enemy:Health() <= 0 then return end

    self:UKEM_CombatThink( enemy, now )
  end

  function ENT:UKEM_CombatThink( enemy, now ) end

  function ENT:UKEM_AttachPos( name )
    local id = self:LookupAttachment( name )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos, att.Ang end
    end
    return self:WorldSpaceCenter(), self:GetAngles()
  end

  function ENT:UKEM_BaseOnDeath( dmg, hitGroup )
    if self.UKEM_Dead then return end
    self.UKEM_Dead = true

    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:WorldSpaceCenter() )
    local ed = EffectData()
    ed:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "Explosion", ed )

    -- сообщаем контроллеру сета (mainframe)
    local master = self.UKEM_GroupMaster
    if IsValid( master ) and master.UKEM_ComponentDied then
      master:UKEM_ComponentDied( self.UKEM_Kind, self )
    end
  end

  function ENT:OnDeath( dmg, hitGroup )
    self:UKEM_BaseOnDeath( dmg, hitGroup )
  end

  -- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
  -- OnInjured re-calls it with a real hitgroup; without this gate the base
  -- DamageMultiplier runs twice (x10 player damage twice = x100). Inherited
  -- by all Defense System components (tower/mortar/rocket/mainframe).
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    baseclass.Get( "ultrakillbase_nextbot" ).OnTakeDamage( self, dmg, hitgroup )
  end

end
