AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_gutterman_base"
ENT.PrintName = "Gutterman"
ENT.Category = "ULTRAKILL - Enemies"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.UKGutterman_Variant = "regular"
ENT.SpawnHealth = UKGutterman.HP_REGULAR
ENT.UKGutterman_Boss = false
ENT.UKGutterman_Casketless = false

DrGBase.AddNextbot( ENT )
