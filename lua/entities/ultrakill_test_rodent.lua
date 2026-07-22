local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local Vector = Vector
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
ENT.Base = "ultrakillbase_nextbot"

-- Misc --

ENT.PrintName = "Cancerous Rodent"
ENT.Category = "ULTRAKILL - Secrets"
ENT.Models = { "models/ultrakill_prelude_test/rodent.mdl" }
ENT.Skins = { 0 }
ENT.ModelScale = 0.08
ENT.CollisionBounds = Vector( 2, 2, 2 )
ENT.SurroundingBounds = Vector( 10, 10, 10 )
ENT.RagdollOnDeath = false
ENT.UltrakillBase_WeightClass = "Heavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)

-- Stats --

ENT.SpawnHealth = 10

-- Sounds --

ENT.UltrakillBase_HurtSoundDelay = 0.1
ENT.UltrakillBase_HurtSound = "Ultrakill_Husk_Hurt"

-- AI --

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 0   -- walk straight under player

-- Locomotion --

ENT.Acceleration = 500
ENT.Deceleration = 500
ENT.WalkSpeed = 25
ENT.RunSpeed = 25
ENT.JumpHeight = 0
ENT.StepHeight = 4
ENT.MaxYawRate = 200
ENT.UseWalkframes = false

-- Animations --

ENT.WalkAnimation = "Idle"
ENT.RunAnimation = "Idle"
ENT.IdleAnimation = "Idle"
ENT.JumpAnimation = "Idle"

-- Detection --

ENT.EyeBone = "root"

-- Possession --

ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 13, 8 ),
    distance = 30,
    eyepos = false

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { onkeydown = function( self )

    UltrakillBase.SoundScript( "Ultrakill_Husk_Hurt", self:GetPos(), self )

  end } }

}


if SERVER then


function ENT:OnSpawn()

  BaseClass.OnSpawn( self )

  -- Wall penetration: ignore world brushes via collision group.
  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
  self:SetGravity( 0 )

end


function ENT:OnTakeDamage( CDamageInfo, HitGroup )

  if CDamageInfo:IsDamageType( DMG_BLAST + DMG_BLAST_SURFACE ) then

    CDamageInfo:SetDamage( 0 )

    return

  end

  BaseClass.OnTakeDamage( self, CDamageInfo, HitGroup )

  if CDamageInfo:GetDamage() > 0 then

    local Pos = CDamageInfo:GetDamagePosition()
    local Center = self:WorldSpaceCenter()
    local Radius = self:GetModelRadius()

    if Pos:DistToSqr( Center ) > Radius * Radius * 0.81 then Pos = Center end

    UltrakillBase.CreateBlood( Pos + VectorRand() * 6, 24 )
    UltrakillBase.CreateBlood( Pos + VectorRand() * 10, 18 )

  end

end


function ENT:OnDeath( Dmg, HitGroup )

  -- Standard rodent doesn't ragdoll, doesn't gib — just removes itself.
  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

end


end


AddCSLuaFile()
DrGBase.AddNextbot( ENT )
