AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end

-- Big Johninator (secret boss, 7-1 Garden of Forking Paths). Canon port:
-- the boss is a V2 component reskin (V2.cs, EnemyType.BigJohnator) with all
-- anim triggers suppressed — a statue of Davy Oshry gliding around in a fixed
-- pose. Movement patterns Straight/Circle/Chase/Coward, obstacle jumps and
-- damage dodges from V2.cs; dontEnrage=1 (never enrages), alwaysAimAtGround=1.
-- Attacks (single EnemyRevolver weapon): Rocket Barrage (bullet=RocketEnemy,
-- 3 rockets on VIOLENT+ at 0.75/0.95/1.15 s), Malicious Beam (altBullet,
-- ~5 s cycle, aimed at the ground), Landmine drop every ~4 s (MineLayer).
-- 23 ROTT Big John taunts play back-to-back (Radio component).
-- Movement/AI structure taken from SonaristicCatboy's ultrakill_v2.lua (with
-- permission) + canon V2.cs; in-house driven-loco recipe from the Mannequin.

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Big Johninator"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category = "ULTRAKILL - Secrets"

ENT.Models = { UKJohninator.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKJohninator.HP
-- canon capsule r=1 m h=4 m at 40 su/m
ENT.CollisionBounds = Vector( 26, 26, 160 )
ENT.SurroundingBounds = Vector( 140, 140, 180 )
ENT.RagdollOnDeath = true
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Medium"
ENT.BloodColor = BLOOD_COLOR_RED -- machine blood is fuel

local UNIT = UKJohninator.UNIT

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 10 * UNIT
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 3000
ENT.Deceleration = 2000
ENT.WalkSpeed = 600
ENT.RunSpeed = 600
ENT.MaxYawRate = 800
ENT.JumpHeight = 130
ENT.StepHeight = 24
ENT.UseWalkframes = false

-- single-pose model: every state shows the same gliding statue
ENT.IdleAnimation = "idle"
ENT.WalkAnimation = "idle"
ENT.RunAnimation = "idle"
ENT.JumpAnimation = "idle"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "idle"
-- base multiplies this blindly whenever airborne — nil crashes OnUpdateAnimation
ENT.FallingAnimRate = 1

-- Possession --
ENT.PossessionEnabled = true
ENT.PossessionPrompt = true
ENT.PossessionCrosshair = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {
  { offset = Vector( 0, 30, 140 ), distance = 220 },
}
ENT.PossessionBinds = {
  [IN_ATTACK] = { {
    coroutine = true,
    onkeydown = function( self )
      if self.UKJ_ShootCD <= 0 then self:UKJ_StartBarrage() end
    end,
  } },
  [IN_ATTACK2] = { {
    coroutine = true,
    onkeydown = function( self )
      if self.UKJ_AltCD <= 0 then self:UKJ_StartBeam() end
    end,
  } },
  [IN_RELOAD] = { {
    coroutine = true,
    onkeydown = function( self )
      self:UKJ_DropMine()
    end,
  } },
  [IN_JUMP] = { {
    coroutine = true,
    onkeydown = function( self )
      self:UKJ_Jump()
    end,
  } },
}

local PATTERNS = { "Straight", "Circle", "Chase" } -- Coward is forced, not rolled

if SERVER then

  ------------------------------------------------------------------------------
  -- Init / lifecycle
  ------------------------------------------------------------------------------

  function ENT:CustomInitialize()
    local d = UKJohninator.GetDifficulty( self )
    local prof = UKJohninator.SPEED_PROFILE[ d ] or UKJohninator.SPEED_PROFILE[ 3 ]
    local health = math.floor( ( self.SpawnHealth or UKJohninator.HP ) * prof.hp )
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKJ_Dead = false
    self.UKJ_Speed = UKJohninator.Speed( d )
    self.WalkSpeed = self.UKJ_Speed
    self.RunSpeed = self.UKJ_Speed

    -- canon V2.Start(): shootCooldown = 1, altShootCooldown = 5
    self.UKJ_ShootCD = 1.0
    self.UKJ_AltCD = UKJohninator.ALT_COOLDOWN
    self.UKJ_JumpCD = 0
    self.UKJ_DodgeCD = 3.0     -- canon dodgeCooldown initializer
    self.UKJ_MineCD = UKJohninator.MINE_INTERVAL
    self.UKJ_Charging = false
    self.UKJ_Dodging = 0
    self.UKJ_DodgeDir = nil

    -- canon patterns: Straight at spawn, random direction
    self.UKJ_Pattern = "Straight"
    self.UKJ_PatternCD = math.Rand( 2, 5 )
    self.UKJ_CircleDir = math.random( 0, 1 ) == 0 and 1 or -1
    self.UKJ_StrafeDir = math.random( 0, 1 ) == 0 and 1 or -1
    self.UKJ_DistancePatience = 0  -- >= 4 forces Chase (dontEnrage: no rage)
    self.UKJ_ClosePatience = 5.0

    self.UKJ_Mines = {}
    self.UKJ_NextTaunt = CurTime() + math.Rand( 0.5, 2 )
    self.UKJ_SlowTick = 0
    self.UKJ_HasVision = false
    self.UKJ_NextVisionCheck = 0
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKJ_StopCharge()
  end

  ------------------------------------------------------------------------------
  -- Helpers
  ------------------------------------------------------------------------------

  function ENT:UKJ_GetDifficulty()
    return UKJohninator.GetDifficulty( self )
  end

  function ENT:UKJ_MuzzlePos()
    local att = self:GetAttachment( self:LookupAttachment( "muzzle" ) )
    if att then return att.Pos end
    return self:WorldSpaceCenter() + self:GetForward() * 40 + self:GetUp() * 20
  end

  function ENT:UKJ_UpdateVision( enemy )
    if CurTime() < self.UKJ_NextVisionCheck then return self.UKJ_HasVision end
    self.UKJ_NextVisionCheck = CurTime() + 0.15
    local tr = util.TraceLine( {
      start = self:WorldSpaceCenter(),
      endpos = enemy:WorldSpaceCenter(),
      mask = MASK_BLOCKLOS,
      filter = self,
    } )
    self.UKJ_HasVision = not tr.Hit or tr.Entity == enemy
    return self.UKJ_HasVision
  end

  ------------------------------------------------------------------------------
  -- Radio (canon Voices: 23 ROTT taunts back-to-back, random order)
  ------------------------------------------------------------------------------

  function ENT:UKJ_UpdateRadio()
    if CurTime() < self.UKJ_NextTaunt then return end
    local snd = UKJohninator.TAUNTS[ math.random( #UKJohninator.TAUNTS ) ]
    self:EmitSound( snd, 85, 100, 1, CHAN_VOICE )
    self.UKJ_NextTaunt = CurTime() + SoundDuration( snd ) + math.Rand( 0.3, 1.5 )
  end

  ------------------------------------------------------------------------------
  -- Movement (canon V2Pattern: Straight/Circle/Chase/Coward)
  ------------------------------------------------------------------------------

  function ENT:UKJ_CheckPattern()
    -- canon CheckPattern: no reroll while patience demands Chase
    if self.UKJ_Pattern == "Coward" or self.UKJ_DistancePatience >= 4 then return end
    if self.UKJ_PatternCD > 0 then return end
    self.UKJ_PatternCD = math.Rand( 2, 5 )
    self.UKJ_Pattern = PATTERNS[ math.random( #PATTERNS ) ]
    if self.UKJ_Pattern == "Circle" then
      self.UKJ_CircleDir = math.random( 0, 1 ) == 0 and 1 or -1
    elseif self.UKJ_Pattern == "Straight" then
      self.UKJ_StrafeDir = math.random( 0, 1 ) == 0 and 1 or -1
    end
  end

  function ENT:UKJ_Jump()
    if not self:IsOnGround() or self.UKJ_JumpCD > 0 then return end
    self.UKJ_JumpCD = 3.0
    self:EmitSound( UKJohninator.SOUND.Jump, 80, 100, 0.9 )
    local v = self.loco:GetVelocity()
    v.z = 550
    self.loco:SetVelocity( v )
  end

  function ENT:UKJ_Dodge( away )
    -- canon DodgeNow: burst sideways/away, hookIgnore while dodging
    if self.UKJ_Dodging > CurTime() then return end
    self.UKJ_Dodging = CurTime() + 0.33
    self.UKJ_DodgeDir = away:GetNormalized()
    self:EmitSound( UKJohninator.SOUND.JumpDash, 80, 110, 0.8 )
  end

  function ENT:UKJ_MoveTargetFor( enemy )
    local myPos = self:GetPos()
    local ePos = enemy:GetPos()
    local toMe = myPos - ePos
    toMe.z = 0
    local dist = math.max( toMe:Length(), 1 )
    toMe:Normalize()

    if self.UKJ_Pattern == "Coward" then
      return myPos + toMe * 8 * UNIT
    elseif self.UKJ_Pattern == "Circle" then
      -- orbit: rotate the enemy->self direction, keep current radius
      local ang = toMe:Angle()
      ang:RotateAroundAxis( vector_up, 24 * self.UKJ_CircleDir )
      return ePos + ang:Forward() * math.Clamp( dist, 6 * UNIT, 14 * UNIT )
    elseif self.UKJ_Pattern == "Straight" then
      -- strafe sideways relative to the enemy with a slight approach
      local right = toMe:Cross( vector_up )
      return myPos + right * 6 * UNIT * self.UKJ_StrafeDir - toMe * 1.5 * UNIT
    end
    return nil -- Chase: native loco chase
  end

  ------------------------------------------------------------------------------
  -- Attacks
  ------------------------------------------------------------------------------

  function ENT:UKJ_StartBarrage()
    -- canon ShootCheck primary: Flash + Invoke ShootWeapon 0.75/0.95/1.15
    -- (difficulty >= 2 all three, >= 1 last two, else last one)
    local d = self:UKJ_GetDifficulty()
    self.UKJ_ShootCD = ( d > 2 ) and math.Rand( 1, 2 ) or 2
    local delays = UKJohninator.BARRAGE_DELAYS
    local from = ( d >= 2 ) and 1 or ( d >= 1 and 2 or 3 )
    for i = from, #delays do
      self:Timer( delays[ i ], function()
        if self.UKJ_Dead then return end
        self:UKJ_FireRocket()
      end )
    end
  end

  function ENT:UKJ_FireRocket()
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then return end
    self:EmitSound( UKJohninator.SOUND.RocketFire, 90, math.random( 96, 104 ), 1 )
    local proj = self:CreateProjectile( UKJohninator.CLASS.Rocket, true )
    if not IsValid( proj ) then return end
    proj:SetPos( self:UKJ_MuzzlePos() )
    -- canon predictAmount 0.15 on the primary; base AimProjectile predicts
    self:AimProjectile( proj, UKJohninator.ROCKET_SPEED )
  end

  function ENT:UKJ_StartBeam()
    -- canon PrepareAltFire: ~1 s charge (Throat Drone High), then AltFire
    if self.UKJ_Charging then return end
    self.UKJ_Charging = true
    self.UKJ_AltCD = UKJohninator.ALT_COOLDOWN
    self.UKJ_ShootCD = math.max( self.UKJ_ShootCD, 1.5 )
    self.UKJ_ChargeSound = CreateSound( self, UKJohninator.SOUND.BeamCharge )
    self.UKJ_ChargeSound:PlayEx( 0.8, 60 )
    self.UKJ_ChargeSound:ChangePitch( 160, 1.0 )
    self:Timer( 1.0, function()
      if self.UKJ_Dead then return end
      self:UKJ_FireBeam()
    end )
  end

  function ENT:UKJ_StopCharge()
    if self.UKJ_ChargeSound then
      self.UKJ_ChargeSound:Stop()
      self.UKJ_ChargeSound = nil
    end
    self.UKJ_Charging = false
  end

  function ENT:UKJ_FireBeam()
    self:UKJ_StopCharge()
    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then return end
    self:EmitSound( UKJohninator.SOUND.BeamFire, 95, 100, 1 )
    local proj = self:CreateProjectile( UKJohninator.CLASS.Beam, true )
    if not IsValid( proj ) then return end
    local from = self:UKJ_MuzzlePos()
    proj:SetPos( from )
    -- canon alwaysAimAtGround: the beam goes for the feet (explosive AoE)
    local target = enemy:GetPos() + Vector( 0, 0, 4 )
    local dir = ( target - from ):GetNormalized()
    proj:SetAngles( dir:Angle() )
    proj:SetVelocity( dir * UKJohninator.BEAM_SPEED )
  end

  function ENT:UKJ_DropMine()
    if self.UKJ_MineCD > 0 and not self:IsPossessed() then return end
    self.UKJ_MineCD = UKJohninator.MINE_INTERVAL

    -- canon MineLayer parents mines to the gore zone at the boss's position
    for i = #self.UKJ_Mines, 1, -1 do
      if not IsValid( self.UKJ_Mines[ i ] ) then table.remove( self.UKJ_Mines, i ) end
    end
    if #self.UKJ_Mines >= UKJohninator.MINE_LIMIT then
      local oldest = table.remove( self.UKJ_Mines, 1 )
      if IsValid( oldest ) then oldest:Remove() end
    end

    local mine = self:CreateProjectile( UKJohninator.CLASS.Mine, false )
    if not IsValid( mine ) then return end
    mine:SetPos( self:GetPos() + self:GetForward() * -20 + Vector( 0, 0, 12 ) )
    table.insert( self.UKJ_Mines, mine )
  end

  function ENT:UKJ_ShootCheck( enemy )
    -- canon: charging blocks a new shot decision
    if self.UKJ_Charging then return end
    if self.UKJ_AltCD <= 0 then
      self:UKJ_StartBeam()
    else
      self:UKJ_StartBarrage()
    end
  end

  ------------------------------------------------------------------------------
  -- Think
  ------------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKJ_Dead then return end
    if self:IsAIDisabled() then return end -- ai_disabled / per-bot disable

    local now = CurTime()
    local dt = now - ( self.UKJ_LastThink or now )
    self.UKJ_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    -- cooldowns (canon UpdateCooldowns; low difficulties tick slower)
    local d = self:UKJ_GetDifficulty()
    local cdRate = ( d == 0 and 0.75 ) or ( d == 1 and 0.85 ) or 1
    if self.UKJ_ShootCD > 0 then self.UKJ_ShootCD = math.max( self.UKJ_ShootCD - dt * cdRate, 0 ) end
    if self.UKJ_AltCD > 0 then self.UKJ_AltCD = math.max( self.UKJ_AltCD - dt * cdRate, 0 ) end
    if self.UKJ_JumpCD > 0 then self.UKJ_JumpCD = math.max( self.UKJ_JumpCD - dt, 0 ) end
    if self.UKJ_PatternCD > 0 then self.UKJ_PatternCD = math.max( self.UKJ_PatternCD - dt, 0 ) end
    if self.UKJ_MineCD > 0 then self.UKJ_MineCD = math.max( self.UKJ_MineCD - dt, 0 ) end
    if self.UKJ_DodgeCD < 6 then
      -- canon: dodge charge regen speed by difficulty
      local regen = ( d >= 4 and 1 ) or ( d == 3 and 0.5 ) or 0.1
      self.UKJ_DodgeCD = math.min( self.UKJ_DodgeCD + dt * regen, 6 )
    end

    self:UKJ_UpdateRadio()

    -- dodge burst movement overrides everything else
    if self.UKJ_Dodging > now and self.UKJ_DodgeDir then
      local left = self.UKJ_Dodging - now
      local v = self.UKJ_DodgeDir * self.UKJ_Speed * 5 * ( left / 0.33 )
      self.loco:SetVelocity( Vector( v.x, v.y, self.loco:GetVelocity().z ) )
      return
    end

    if self:IsPossessed() then return end

    local enemy = self:GetEnemy()
    if not IsValid( enemy ) then
      self.CantMove = false
      self:UKJ_StopCharge()
      self.UKJ_DistancePatience = 0
      return
    end

    local hasVision = self:UKJ_UpdateVision( enemy )
    local dist = self:GetPos():Distance( enemy:GetPos() )

    -- canon DistancePatience: far or hidden -> impatience -> forced Chase
    -- (dontEnrage=1: the enrage stage never fires, only the chase)
    local far = dist > 15 * UNIT or not hasVision
    if far then
      self.UKJ_DistancePatience = math.min( self.UKJ_DistancePatience + dt * 2, 12 )
      if self.UKJ_Pattern ~= "Chase"
          and ( self.UKJ_DistancePatience >= 4 or dist > 30 * UNIT ) then
        self.UKJ_Pattern = "Chase"
      end
    else
      self.UKJ_DistancePatience = math.max( self.UKJ_DistancePatience - dt * 2, 0 )
    end

    -- canon closeRangePatience: crowded too long -> dodge away + Coward
    if dist < 10 * UNIT or self.UKJ_Pattern == "Circle" then
      self.UKJ_ClosePatience = math.max( self.UKJ_ClosePatience - dt, 0 )
      if self.UKJ_ClosePatience <= 0 then
        self.UKJ_ClosePatience = 1
        self:UKJ_Dodge( self:GetPos() - enemy:GetPos() )
        if self.UKJ_Pattern ~= "Circle" then
          self.UKJ_Pattern = "Coward"
        end
      end
    else
      self.UKJ_ClosePatience = math.min( self.UKJ_ClosePatience + dt, 5 )
      if self.UKJ_Pattern == "Coward" and self.UKJ_ClosePatience > 2 then
        self.UKJ_Pattern = "Straight"
        self.UKJ_PatternCD = 0
      end
    end

    self:UKJ_CheckPattern()

    -- canon: jump over obstacles ahead
    if self:IsOnGround() and hasVision then
      local tr = util.TraceLine( {
        start = self:GetPos() + Vector( 0, 0, 40 ),
        endpos = self:GetPos() + Vector( 0, 0, 40 ) + self:GetForward() * 4 * UNIT,
        mask = MASK_SOLID_BRUSHONLY,
        filter = self,
      } )
      if tr.Hit then self:UKJ_Jump() end
    end

    -- shooting (canon: only with LOS)
    if self.UKJ_ShootCD <= 0 and hasVision then
      self:UKJ_ShootCheck( enemy )
    end

    -- landmine cycle (canon MineLayer: continuously while active)
    if self.UKJ_MineCD <= 0 and self:IsOnGround() then
      self:UKJ_DropMine()
    end

    -- movement: pattern strafing via the driven-loco recipe; Chase = native
    -- canon Move(): +50% speed while impatient
    local speed = self.UKJ_Speed * ( self.UKJ_DistancePatience > 4 and 1.5 or 1 )
    self.WalkSpeed = speed
    self.RunSpeed = speed

    local target = hasVision and self:UKJ_MoveTargetFor( enemy ) or nil
    if target and self:IsOnGround() then
      self.CantMove = true
      self:SetMaxYawRate( self.MaxYawRate )
      self:FaceTowards( enemy:GetPos() )
      self.loco:SetDesiredSpeed( speed )
      self.loco:Approach( target, 1 )
    else
      self.CantMove = false
    end
  end

  ------------------------------------------------------------------------------
  -- Damage (canon: revolver/bullets x0.6, head x2, limbs x1.5, dodge chance)
  ------------------------------------------------------------------------------

  function ENT:OnTakeDamage( dmg, hitgroup )
    if dmg:IsDamageType( DMG_DIRECT ) or dmg:IsDamageType( DMG_BULLET ) then
      dmg:ScaleDamage( 0.6 )
    end
    if hitgroup == HITGROUP_HEAD then
      dmg:ScaleDamage( 2.0 )
    elseif hitgroup == HITGROUP_LEFTARM or hitgroup == HITGROUP_RIGHTARM
        or hitgroup == HITGROUP_LEFTLEG or hitgroup == HITGROUP_RIGHTLEG then
      dmg:ScaleDamage( 1.5 )
    end

    self:DamageMultiplier( dmg, hitgroup )
    self:CreateBlood( dmg, hitgroup )

    -- canon Dodge: spend the recharge on a sideways burst (6 - difficulty)
    local enemy = self:GetEnemy()
    if IsValid( enemy ) and not self.UKJ_Dead then
      local d = self:UKJ_GetDifficulty()
      if self.UKJ_DodgeCD >= ( 6 - d )
          and self:GetPos():Distance( enemy:GetPos() ) > 15 * UNIT then
        self.UKJ_DodgeCD = self.UKJ_DodgeCD - ( 6 - d )
        local away = ( self:GetPos() - dmg:GetDamagePosition() )
        away.z = 0
        if away:LengthSqr() < 1 then
          away = self:GetRight() * ( math.random( 0, 1 ) == 0 and 1 or -1 )
        end
        self:UKJ_Dodge( away )
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Death (canon Machine simpleDeath: scream + explosion, statue tumbles)
  ------------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKJ_Dead = true
    self:UKJ_StopCharge()
    self:StopSound( UKJohninator.SOUND.BeamCharge )
    self:EmitSound( UKJohninator.SOUND.Death, 95, 100, 1, CHAN_VOICE )
    UltrakillBase.SoundScript( "Ultrakill_Death_Explode", self:GetPos() )
    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "Explosion", fx, true, true )
  end

end -- SERVER

DrGBase.AddNextbot( ENT )

list.Set( "NPC", "ultrakill_test_johninator", {
  Name = "Big Johninator",
  Class = "ultrakill_test_johninator",
  Category = "ULTRAKILL - Secrets",
  Material = "entities/ultrakill_test_johninator.png",
} )
