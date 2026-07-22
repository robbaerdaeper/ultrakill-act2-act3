AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_gutterman_base"
ENT.PrintName = "Gutterman (Casketless)"
ENT.Category = "ULTRAKILL - Secrets"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.UKGutterman_Variant = "casketless"
ENT.SpawnHealth = UKGutterman.HP_REGULAR
ENT.UKGutterman_Boss = false
ENT.UKGutterman_Casketless = true

DrGBase.AddNextbot( ENT )
