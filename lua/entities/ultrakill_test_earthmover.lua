AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKEarthmover then include( "autorun/ultrakill_test_earthmover_shared.lua" ) end

-- 1000-THR «Earthmover» (Centaur) — гигантский walker из 7-4.
-- Модель скомпилирована в 1:8 канона (~106 м высоты, канон ~835 м);
-- convar ultrakill_earthmover_scale масштабирует дополнительно (0.25..2).
-- Меш Centaur_Midpoly_Riggeda + канон Walk (CentaurTease). Давит всё под
-- собой. Против другого Earthmover — канон-дуэль молниями (обе неуязвимы
-- к лучу: в 7-4 их выстрелы блокируются барьерами).

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "1000-THR Earthmover"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.Category = "ULTRAKILL - Bosses"

ENT.Models = { UKEarthmover.MODEL_GIANT }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKEarthmover.GIANT_HP
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }

ENT.CollisionBounds = Vector( 550, 550, 3900 )
ENT.SurroundingBounds = Vector( 1500, 1500, 4200 )
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)

ENT.WalkSpeed = UKEarthmover.GIANT_SPEED
ENT.RunSpeed = UKEarthmover.GIANT_SPEED
ENT.Acceleration = 400
ENT.Deceleration = 400
ENT.MaxYawRate = 12          -- громада поворачивает медленно
ENT.JumpHeight = 0
ENT.StepHeight = 500         -- перешагивает дома
ENT.DeathDropHeight = 100000
ENT.UseWalkframes = false

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 800
ENT.AvoidEnemyRange = 0

ENT.IdleAnimation = "idle"
ENT.IdleAnimRate = 1.0
ENT.WalkAnimation = "walk"
ENT.WalkAnimRate = 1.0
ENT.RunAnimation = "walk"
ENT.RunAnimRate = 1.0
ENT.JumpAnimation = "idle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "idle"
-- base multiplies this blindly whenever airborne — nil crashes OnUpdateAnimation
ENT.FallingAnimRate = 1

ENT.UKEM_IsEarthmover = true

local NW_ZAP = "UKEM_Giant_Zap"
local NW_ZAP_END = "UKEM_Giant_ZapEnd"


-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    -- туша ~3900 юнитов; offset/distance база умножает на ModelScale,
    -- так что convar ultrakill_earthmover_scale учитывается сам
    offset = Vector( 0, 600, 1800 ),
    distance = 6000,
    eyepos = false

  },

  {

    -- EyePos = центр коллизии (полубокс 550) — вынос вперёд за меш
    offset = Vector( 700, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}


ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    -- канон-молния (чисто визуальная, урона не наносит); общий с ИИ-дуэлью
    -- кулдаун UKEM_NextZap, 1.5 c > 1.2-с вспышки — зажатая кнопка не спамит
    if CurTime() < ( self.UKEM_NextZap or 0 ) then return end

    local target = self:PossessionGetLockedOn()
    if not IsValid( target ) then return end

    self.UKEM_NextZap = CurTime() + 1.5
    self:UKEM_ZapAt( target )

  end } }

}


if SERVER then

  local cvScale = CreateConVar( "ultrakill_earthmover_scale", "1",
    FCVAR_ARCHIVE, "Model scale multiplier for newly spawned Earthmovers (base = 1:8 canon)", 0.25, 2 )
  local cvInvuln = CreateConVar( "ultrakill_earthmover_invulnerable", "0",
    FCVAR_ARCHIVE, "Earthmovers ignore all damage (canon: shield generator)" )

  function ENT:CustomInitialize()
    local s = cvScale:GetFloat()
    self.UKEM_Scale = s
    if s ~= 1 then
      self:SetModelScale( s )
      local cb = self.CollisionBounds * s
      self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )
      local sb = self.SurroundingBounds * s
      self:SetSurroundingBounds( -sb, sb )
    end

    self:SetMaxHealth( self.SpawnHealth )
    self:SetHealth( self.SpawnHealth )

    self.UKEM_Dead = false
    self.UKEM_NextStep = 0
    self.UKEM_NextStomp = 0
    self.UKEM_NextZap = CurTime() + 5
    self:SetNW2Bool( NW_ZAP, false )

    if UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, "1000-THR \"EARTHMOVER\"" )
    end
  end

  function ENT:OnTakeDamage( dmg, hitGroup )
    if cvInvuln:GetBool() then
      dmg:SetDamage( 0 )
      return true
    end
    -- канон-дуэль: молнии другого Earthmover не наносят урона
    local infl = dmg:GetInflictor()
    if IsValid( infl ) and infl.UKEM_IsEarthmover then
      dmg:SetDamage( 0 )
      return true
    end
  end

  -- давим всё под тушей и ногами
  function ENT:UKEM_Trample( now )
    if now < self.UKEM_NextStomp then return end
    self.UKEM_NextStomp = now + 0.4

    local vel = self.loco and self.loco:GetVelocity() or vector_origin
    if vel:LengthSqr() < 100 then return end

    local s = self.UKEM_Scale or 1
    local center = self:GetPos() + Vector( 0, 0, 100 * s )
    local half = Vector( 500 * s, 500 * s, 220 * s )
    for _, ent in ipairs( ents.FindInBox( center - half, center + half ) ) do
      if ent == self or ent.UKEM_IsEarthmover then continue end
      if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
        UKEarthmover.DealDamage( ent, self, self, UKEarthmover.STOMP_DAMAGE,
          DMG_CRUSH )
      elseif IsValid( ent:GetPhysicsObject() ) then
        ent:GetPhysicsObject():ApplyForceCenter(
          ( ent:WorldSpaceCenter() - center ):GetNormalized()
          * ent:GetPhysicsObject():GetMass() * 600 + Vector( 0, 0, 20000 ) )
      end
    end
  end

  -- канон-пасхалка: два Earthmover бесконечно стреляют друг в друга молниями
  function ENT:UKEM_FindRival()
    for _, ent in ipairs( ents.FindByClass( self:GetClass() ) ) do
      if ent ~= self and IsValid( ent ) and ent:Health() > 0 then return ent end
    end
  end

  function ENT:UKEM_HeadPos()
    local id = self:LookupAttachment( "head" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter()
      + Vector( 0, 0, self:OBBMaxs().z * 0.45 )
  end

  function ENT:UKEM_ZapAt( target )
    if not IsValid( target ) then return end
    self:SetNW2Bool( NW_ZAP, true )
    self:SetNW2Vector( NW_ZAP_END, target.UKEM_HeadPos and target:UKEM_HeadPos()
      or target:WorldSpaceCenter() )
    self:EmitSound( UKEarthmover.SOUND.GiantFire, 140, 100, 1.0 )
    timer.Simple( 1.2, function()
      if IsValid( self ) then self:SetNW2Bool( NW_ZAP, false ) end
    end )
  end

  function ENT:CustomThink()
    if self.UKEM_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable
    local now = CurTime()

    self:UKEM_Trample( now )

    -- канон CentaurSpotted: гигант замечает цель (один раз за цель)
    local enemy = self:GetEnemy()
    if IsValid( enemy ) and enemy ~= self.UKEM_LastSpotted then
      self.UKEM_LastSpotted = enemy
      self:EmitSound( UKEarthmover.SOUND.GiantSpotted, 140, 100, 1.0 )
    end

    -- шаги: 2 удара на цикл Walk 1.3 c
    local vel = self.loco and self.loco:GetVelocity() or vector_origin
    if vel:LengthSqr() > 100 and now >= self.UKEM_NextStep then
      self.UKEM_NextStep = now + UKEarthmover.GIANT_WALK_LEN / 2
      self:EmitSound( UKEarthmover.SOUND.GiantStep, 140, 90, 1.0 )
      util.ScreenShake( self:GetPos(), 4, 40, 0.6, 3000 * ( self.UKEM_Scale or 1 ) )
    end

    -- дуэль молниями с другим Earthmover (при поссессии молния только по бинду)
    if now >= self.UKEM_NextZap and not self:IsPossessed() then
      self.UKEM_NextZap = now + math.Rand( 6, 10 )
      self:UKEM_ZapAt( self:UKEM_FindRival() )
    end
  end

  function ENT:OnDeath( dmg, hitGroup )
    if self.UKEM_Dead then return end
    self.UKEM_Dead = true
    -- канон CentaurDeath: горит и оседает; у нас — серия взрывов по туше
    local base = self:GetPos()
    local s = self.UKEM_Scale or 1
    for i = 0, 6 do
      timer.Simple( i * 0.35, function()
        if not IsValid( self ) then return end
        local ed = EffectData()
        ed:SetOrigin( base + Vector( math.Rand( -400, 400 ) * s,
          math.Rand( -400, 400 ) * s, math.Rand( 200, 3500 ) * s ) )
        ed:SetScale( 2 )
        util.Effect( "Explosion", ed )
      end )
    end
    util.ScreenShake( base, 10, 60, 2.5, 6000 * s )
  end

else -- CLIENT

  local MAT_BEAM = Material( "sprites/laserbeam" )
  local COL_ZAP = Color( 200, 230, 255, 255 )
  local COL_ZAP_SOFT = Color( 120, 170, 255, 90 )

  function ENT:CustomInitialize()
    local rb = Vector( 5000, 5000, 5000 )
    self:SetRenderBounds( -rb, rb )
  end

  function ENT:CustomDraw()
    if not self:GetNW2Bool( NW_ZAP, false ) then return end
    local id = self:LookupAttachment( "head" )
    local from
    if id and id > 0 then
      local att = self:GetAttachment( id )
      from = att and att.Pos
    end
    from = from or ( self:WorldSpaceCenter() + Vector( 0, 0, self:OBBMaxs().z * 0.45 ) )
    local endPos = self:GetNW2Vector( NW_ZAP_END, from )

    -- ломаная молния
    render.SetMaterial( MAT_BEAM )
    local segs = 8
    local prev = from
    local dir = ( endPos - from )
    for i = 1, segs do
      local t = i / segs
      local p = from + dir * t
      if i < segs then
        p = p + VectorRand() * dir:Length() * 0.015
      end
      render.DrawBeam( prev, p, 28, 0, 1, COL_ZAP )
      render.DrawBeam( prev, p, 80, 0, 1, COL_ZAP_SOFT )
      prev = p
    end
  end

end
