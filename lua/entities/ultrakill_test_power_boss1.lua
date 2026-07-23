AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local BaseClass = baseclass.Get( "ultrakill_test_power" )

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_power_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_power"
ENT.PrintName = "Power".. ' "Mandel"'
ENT.Category = "ULTRAKILL - Bosses"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.IsBoss = true
ENT.BossName = "POWER".. ' "MANDEL"'

DrGBase.AddNextbot( ENT )

function ENT:OnSpawn()

  BaseClass.OnSpawn( self )
  
  self:Timer( 0, UltrakillBase.PlayMusic, "The Shattering Circle, or: A Charade of Shadeless Ones and Zeroes Rearranged ad Nihilum" )
end

function ENT:OnRemove()

  UltrakillBase.StopCurrentMusic( self )

end

function  ENT:OnDeath()

  UltrakillBase.StopCurrentMusic( self )
  BaseClass.OnDeath( self )

end
