local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local Vector = Vector
local Angle = Angle
local CurTime = CurTime
local ParticleEffect = ParticleEffect
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
ENT.Base = "ultrakillbase_nextbot"

-- Misc --

ENT.PrintName = "Very Cancerous Rodent"
ENT.Category = "ULTRAKILL - Secrets"
ENT.Models = { "models/ultrakill_prelude_test/rodent.mdl" }
ENT.Skins = { 1 }
ENT.ModelScale = 2.0
ENT.CollisionBounds = Vector( 38, 38, 60 )
ENT.SurroundingBounds = Vector( 120, 120, 120 )
ENT.RagdollOnDeath = false
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)

-- Stats --

ENT.SpawnHealth = 50000

-- Sounds --

ENT.UltrakillBase_HurtSoundDelay = 0.1
ENT.UltrakillBase_HurtSound = "Ultrakill_Husk_Hurt"

-- AI --

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 2000
ENT.ReachEnemyRange = 99999

-- Locomotion --

ENT.Acceleration = 100
ENT.Deceleration = 9999    -- effectively stationary but locomotor stays alive for AI/turning
ENT.WalkSpeed = 1
ENT.RunSpeed = 1
ENT.JumpHeight = 0
ENT.MaxYawRate = 360
ENT.UseWalkframes = false

-- Animations --

ENT.WalkAnimation = "Idle"
ENT.RunAnimation = "Idle"
ENT.IdleAnimation = "Idle"
ENT.JumpAnimation = "Idle"

-- Detection --

ENT.EyeBone = "root"

-- Tables --

ENT.UltrakillBase_AttackTable = {

  "FireSeekers"

}


-- Possession --

ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 30, 30 ),
    distance = 80,
    eyepos = false

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { onkeydown = function( self )

    self:RodentFireSeekers()

  end } }

}


if SERVER then


function ENT:RodentFireSeekers( Enemy )

  if self:GetCooldown( "FireSeekers" ) > 0 then return end

  UltrakillBase.SoundScript( "Ultrakill_Projectile_Shoot", self:GetPos(), self )

  -- All 3 spawn at SAME point. Fast stagger 0.05s between each.
  -- Fan-spread yaw angles so projectiles fly out distinguishably.
  -- Slow initial speed; UltrakillBase homing ramps them up toward player.
  local yaw_spread = { -12, 0, 12 }
  local STAGGER = 0.05
  local INITIAL_SPEED = 600

  for i = 1, 3 do

    local delay = ( i - 1 ) * STAGGER
    local yaw_offset = yaw_spread[ i ]

    timer.Simple( delay, function()

      if not IsValid( self ) then return end

      local fwd = self:GetForward()
      local up = self:GetUp()
      local spawn_pos = self:GetPos() + fwd * 60 + up * 20

      local target = self:GetEnemy()
      local target_pos = IsValid( target ) and target:WorldSpaceCenter() or ( spawn_pos + fwd * 1000 )

      local Proj = self:CreateProjectile( "ultrakill_test_rodent_projectile", true )
      if not IsValid( Proj ) then return end

      local to_target = ( target_pos - spawn_pos ):GetNormalized()
      local ang = to_target:Angle()
      ang.yaw = ang.yaw + yaw_offset

      Proj:SetPos( spawn_pos )
      Proj:SetAngles( ang )
      Proj:SetVelocity( ang:Forward() * INITIAL_SPEED )

    end )

  end

  self:SetCooldown( "FireSeekers", 3.5 )

end


function ENT:OnRangeAttack( Enemy )

  self:RodentFireSeekers( Enemy )

end


function ENT:OnSpawn()

  BaseClass.OnSpawn( self )

  self:SetTurning( true )    -- enable auto-rotation toward enemy

  UltrakillBase.AddBoss( self, "VERY CANCEROUS RODENT" )

end


-- Explicit override prevents an inheritance edge case where damage scaling fires twice
-- (test removed → instakill; wrapper present → expected ~5 parries to kill).
function ENT:OnTakeDamage( CDamageInfo, HitGroup )

  BaseClass.OnTakeDamage( self, CDamageInfo, HitGroup )

  if CDamageInfo:GetDamage() > 0 then

    local Pos = CDamageInfo:GetDamagePosition()
    local Center = self:WorldSpaceCenter()
    local Radius = self:GetModelRadius()

    if Pos:DistToSqr( Center ) > Radius * Radius * 0.81 then Pos = Center end

    UltrakillBase.CreateBlood( Pos + VectorRand() * 25, 48 )
    UltrakillBase.CreateBlood( Pos + VectorRand() * 40, 40 )

  end

end


function ENT:CustomThink()

  -- ai_disabled / per-bot disable: SERVER-гейт, на клиенте конвар не читается
  if SERVER and self:IsAIDisabled() then return end

  -- Stationary turret: actively face the enemy regardless of locomotion state.
  local Enemy = self:GetEnemy()
  if IsValid( Enemy ) then

    self:FaceEnemyInstant()

  end

end


function ENT:OnDeath( Dmg, HitGroup )

  -- Hideous-Mass-style death: shake + bleed for 2 seconds, then BOOM.
  UltrakillBase.SoundScript( "Ultrakill_Husk_Death", self:GetPos() )

  -- Heal nearby players +25 HP (per spec).
  for _, ply in pairs( player.GetAll() ) do

    if ply:GetPos():DistToSqr( self:GetPos() ) < 1000 * 1000 then

      ply:SetHealth( math.min( ply:GetMaxHealth(), ply:Health() + 25 ) )

    end

  end

  -- Lock pose; we don't have an animated death sequence so freeze on Idle.
  self:Shake( 8, 16 )

  local DeathEnd = CurTime() + 4
  local Cycle = self:GetCycle()
  local Seq = self:GetSequence()

  local RandomVec = Vector()

  while DeathEnd > CurTime() do

    self:SetPlaybackRate( 0 )
    self:SetCycle( Cycle )
    self:SetSequence( Seq )

    if self:GetCooldown( "BloodSplatter" ) <= 0 then

      RandomVec:Random( -60, 60 )

      UltrakillBase.CreateBlood( self:WorldSpaceCenter() + RandomVec, 24 )
      UltrakillBase.SoundScript( "Ultrakill_Death", self:GetPos() )

      self:SetCooldown( "BloodSplatter", 0.3333 )

    end

    self:YieldCoroutine()

  end

  -- Final burst: gore explosion.
  for X = 1, 6 do

    RandomVec:Random( -60, 60 )

    UltrakillBase.CreateBlood( self:WorldSpaceCenter() + RandomVec, 32 )

  end

  UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )

  UltrakillBase.RemoveBoss( self )

  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

end


end


AddCSLuaFile()
DrGBase.AddNextbot( ENT )
