AddCSLuaFile()

local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_insurrectionist_shared.lua" )

-- Insurrectionist "Angry" — красная половина секретного дуэта 6-1
-- "CRY FOR THE WEEPER". Канон-материал SisyphusRed (T_ArmStretcherRed).
-- Вся вариант-логика (Symbiote-связка, downed-реген, портал, босс-бар) —
-- UKSisy.ApplyVariant в ultrakill_test_insurrectionist_shared.lua.

ENT.Type = "nextbot"
ENT.Base = "ultrakill_test_insurrectionist"
ENT.Author = "ultragmod"
ENT.Spawnable = true
ENT.AdminOnly = false

UKSisy.ApplyVariant( ENT, {
  name = "Angry",
  bossTitle = 'INSURRECTIONIST "ANGRY"',
  material = "models/ultrakill_prelude_test/insurrectionist/sisy_body_red",
  partner = "ultrakill_test_insurrectionist_rude",
} )

DrGBase.AddNextbot( ENT )
