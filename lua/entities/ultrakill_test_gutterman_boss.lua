AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local BaseClass = baseclass.Get( "ultrakill_test_gutterman_base" )

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_gutterman_base"
ENT.PrintName = "Gutterman (Boss)"
ENT.Category = "ULTRAKILL - Bosses"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.UKGutterman_Variant = "boss"
ENT.SpawnHealth = UKGutterman.HP_BOSS
ENT.UKGutterman_Boss = true
ENT.UKGutterman_Casketless = false

DrGBase.AddNextbot( ENT )

function ENT:OnSpawn()

  BaseClass.OnSpawn( self )
  
  self:Timer( 0, UltrakillBase.PlayMusic, "Do Robots Dream of Eternal Sleep?" )
end

function ENT:OnRemove()

  UltrakillBase.StopCurrentMusic( self )

end

function  ENT:OnDeath()

  BaseClass.OnDeath( self )
  UltrakillBase.StopCurrentMusic( self )

end
