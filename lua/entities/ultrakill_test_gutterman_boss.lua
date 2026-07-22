AddCSLuaFile()
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

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
