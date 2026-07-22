-- ULTRAKILL Puppet — tutorial-dummy melee enemy.
-- Always-puppeted on spawn (canon). Uses old-Filth model + Filth animations.
-- HP=5, swing 10dmg vs player / 1dmg vs other enemies, slow walker.

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local Vector = Vector
local USoundScript = SERVER and ( UltrakillBase and UltrakillBase.SoundScript ) or function() end
local IsValid = IsValid
local MMax = math.max
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
if not UKPuppet then return end

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )

ENT.Base = "ultrakillbase_nextbot"

-- Misc --
ENT.PrintName = "Puppet"
ENT.Author    = "Flying Dog & Tony Stigell (orig); ULTRAKILL port"
ENT.Category  = "ULTRAKILL - Enemies"
ENT.Spawnable = true
ENT.Models    = { "models/ultrakill_puppet/puppet.mdl" }
ENT.Skins     = { 0 }
ENT.ModelScale = 1
ENT.CollisionBounds   = Vector( 8, 8, 65 ) * 1.15
ENT.SurroundingBounds = Vector( 25, 25, 85 ) * 1.15
ENT.RagdollOnDeath    = false

-- Stats (canon) --
ENT.SpawnHealth = 5

-- Sounds --
ENT.UltrakillBase_HurtSoundDelay = 0.1
ENT.UltrakillBase_HurtSound = "Ultrakill_Filth_Hurt"

-- AI --
ENT.MeleeAttackRange = 75
ENT.ReachEnemyRange  = 45
ENT.AvoidEnemyRange  = 35

-- Detection --
ENT.EyeBone = "Head"

-- Locomotion --
ENT.Acceleration  = 2500
ENT.Deceleration  = 1500
ENT.JumpHeight    = 150
ENT.StepHeight    = 20
ENT.MaxYawRate    = 200    -- slower than Filth's 400 (Puppet is sluggish)
ENT.DeathDropHeight = 10

-- Animations — names match canonical Puppet.controller (Idle / ZombieWalk / Swing).
-- Puppet has no Run sequence in QC; Walk == ZombieWalk slow shamble for both walk/run states.
ENT.WalkAnimation = "Walk"
ENT.WalkAnimRate  = 1
ENT.RunAnimation  = "Walk"
ENT.RunAnimRate   = 1
ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate  = 1
ENT.JumpAnimation = "Falling"
ENT.JumpAnimRate  = 1

-- Movements (canon: slow walker only) --
ENT.UseWalkframes = false
ENT.WalkSpeed = 80
ENT.RunSpeed  = 80

-- Damage table — Swing (NOT parryable per canon) --
ENT.UltrakillBase_DamageInfo = {
  [ "Swing" ] = { 10, 65, DMG_SLASH, 30, Vector( 200, 0, 0 ) }
}

ENT.UltrakillBase_OnEventTable = {
  [ "Damage" ] = function( self, Event, Seq )
    if Event[ 2 ] == "Start" and not self:IsParryInterrupted() then
      local DamageData = self.UltrakillBase_DamageInfo[ Seq ]
      if not istable( DamageData ) then return end
      self:ContinuousAttack( {
        Damage = DamageData[ 1 ],
        Range  = DamageData[ 2 ],
        Type   = DamageData[ 3 ],
        Angle  = DamageData[ 4 ],
        Force  = DamageData[ 5 ],
        Push   = true
      } )
      self:SetContinuousAttack( true )
    else
      self.UltrakillBase_ContinuousAttacksTable = {}
      self:SetContinuousAttack( false )
    end
  end,

  [ "Step" ] = function( self, Event, Seq )
    UltrakillBase.SoundScript( "Ultrakill_HuskStep", self:GetPos() )
  end,

  -- Per-canon: Swing is NOT parryable. We never set Parry flag.
  [ "Flag" ] = function( self, Event, Seq )
    if Event[ 2 ] == "Turning" then
      self:SetTurning( tobool( Event[ 3 ] ) )
    end
  end,
}

ENT.UltrakillBase_EventTable = {
  [ "Swing" ] = {
    { 0,  "Flag Turning 1" },
    { 15, "Flag Turning 0" },
    { 23, "Damage Start"   },
    { 35, "Damage Stop"    },
  },

  [ "Walk" ] = {
    { 19, "Step" },
    { 39, "Step" }
  },
}

ENT.UltrakillBase_AttackTable = { "Swing" }

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 11.5, 34.5 ),
    distance = 115,
    eyepos = false

  },

  {

    offset = Vector( 5.75, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self )

    -- PuppetSwing tolerates a NULL enemy (IsValid-gated interrupt callback).
    self:PuppetSwing( self:PossessionGetLockedOn() )

  end } },

}

if SERVER then

function ENT:OnSpawn()
  BaseClass.OnSpawn( self )
  -- Self-puppet on spawn with full FX.
  UKPuppet.Apply( self, self, { fxLevel = "spawn" } )
end

function ENT:PuppetSwing( Enemy )
  if not self:IsOnGround() then return end
  self:PlaySequenceAndMove( "Swing", nil, function( self, Cycle )
    if IsValid( Enemy ) and self:IsInRange( Enemy, 50 ) and Cycle > 0.6 then
      return true
    end
    if Cycle > 0.95 then return true end
  end )
end

function ENT:OnMeleeAttack( Enemy )
  return self:PuppetSwing( Enemy )
end

function ENT:OnFallDamage( Speed )
  if self:IsClimbing() then return 0 end
  return MMax( 0, Speed - 300 ) * 10
end

function ENT:OnTakeDamage( CDamageInfo, HitGroup )
  BaseClass.OnTakeDamage( self, CDamageInfo, HitGroup )
end

function ENT:OnDeath( Dmg, HitGroup )
  -- Puppet bursts into blood (no ragdoll per canon).
  UltrakillBase.SoundScript( "Ultrakill_Filth_Death", self:GetPos() )
  self:CreateBlood( Dmg, HitGroup )
  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
end

end    -- if SERVER

AddCSLuaFile()
DrGBase.AddNextbot( ENT )
