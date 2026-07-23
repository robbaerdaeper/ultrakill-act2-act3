AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase
local BaseClass = baseclass.Get( "ultrakill_test_minotaur" )

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_minotaur_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_minotaur"
ENT.PrintName = "Minotaur"
ENT.Category = "ULTRAKILL - Bosses"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.IsBoss = true

DrGBase.AddNextbot( ENT )

function ENT:OnSpawn()

  BaseClass.OnSpawn( self )
  
  self:Timer( 0, UltrakillBase.PlayMusic, "Bull of Hell" )
end

function ENT:OnRemove()

  UltrakillBase.StopCurrentMusic( self )

end
