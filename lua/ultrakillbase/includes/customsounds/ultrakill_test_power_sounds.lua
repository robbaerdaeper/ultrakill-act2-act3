-- lua/ultrakillbase/includes/customsounds/ultrakill_test_power_sounds.lua
-- Power (Greater Angel) voice kit через штатную систему UltrakillBase:
-- AddSoundScript + AddVoiceSoundScript = босс-сабтитры + приоритеты.
-- Тексты — канон 1:1 из PowerVoiceController.cs (DisplaySubtitle).
-- Индекс скрипта = индекс WAV (power_build_sounds.py экспортирует массивы
-- контроллера по порядку, поэтому intro1 = caption case 0 и т.д.).

local SND = "ultrakill_prelude_test/power/"

-- Приоритеты: анонсы/таунты 1 < чипшот/ярость/интро 2 (перебивают).
local PRIO_ANNOUNCE, PRIO_ALERT = 1, 2

local function reg( id, file, prio, caption )
  UltrakillBase.AddSoundScript( "Ultrakill_Power_" .. id, SND .. file, 0, 1, 1, nil, false, 0, true )
  UltrakillBase.AddVoiceSoundScript( "Ultrakill_Power_" .. id, prio, caption )
end

reg( "Intro1", "intro1.wav", PRIO_ALERT, "Be afraid, machine." )
reg( "Intro2", "intro2.wav", PRIO_ALERT, "Here shall be your grave." )
reg( "Intro3", "intro3.wav", PRIO_ALERT, "It is over, machine!" )
reg( "Intro4", "intro4.wav", PRIO_ALERT, "Surrender or perish!" )
reg( "Intro5", "intro5.wav", PRIO_ALERT, "Lay down and die!" )

reg( "Enrage1", "enrage1.wav", PRIO_ALERT, "Bastard!" )
reg( "Enrage2", "enrage2.wav", PRIO_ALERT, "You piece of SHIT!" )
reg( "Enrage3", "enrage3.wav", PRIO_ALERT, "Just DIE already!" )
reg( "Enrage4", "enrage4.wav", PRIO_ALERT, "Why won't you die!?" )
reg( "Enrage5", "enrage5.wav", PRIO_ALERT, "God DAMN it!" )

reg( "Taunt1", "taunt1.wav", PRIO_ANNOUNCE, "This lowly thing could never have bested him!" )
reg( "Taunt2", "taunt2.wav", PRIO_ANNOUNCE, "An inconvenience at best." )
reg( "Taunt3", "taunt3.wav", PRIO_ANNOUNCE, "This is a waste of my time!" )
reg( "Taunt4", "taunt4.wav", PRIO_ANNOUNCE, "Just another worthless object." )

reg( "CheapShot1", "cheapshot1.wav", PRIO_ALERT, "PAY ATTENTION!" )
reg( "CheapShot2", "cheapshot2.wav", PRIO_ALERT, "Wait your TURN!" )
reg( "CheapShot3", "cheapshot3.wav", PRIO_ALERT, "WRONG TARGET!" )

reg( "Rapier1", "rapier1.wav", PRIO_ANNOUNCE, "Rapier!" )
reg( "Rapier2", "rapier2.wav", PRIO_ANNOUNCE, "Rapier!" )
reg( "Greatsword1", "greatsword1.wav", PRIO_ANNOUNCE, "Greatsword!" )
reg( "Greatsword2", "greatsword2.wav", PRIO_ANNOUNCE, "Greatsword!" )
reg( "Spear1", "spear1.wav", PRIO_ANNOUNCE, "Spear!" )
reg( "Spear2", "spear2.wav", PRIO_ANNOUNCE, "Spear!" )
reg( "OverHere1", "overhere1.wav", PRIO_ANNOUNCE, "Over here!" )
reg( "OverHere2", "overhere2.wav", PRIO_ANNOUNCE, "Over here!" )
reg( "Glaive1", "glaive1.wav", PRIO_ANNOUNCE, "Glaive!" )
reg( "Glaive2", "glaive2.wav", PRIO_ANNOUNCE, "Glaive!" )
reg( "GlaiveThrow1", "glaivethrow1.wav", PRIO_ANNOUNCE, "Take THIS!" )
reg( "GlaiveThrow2", "glaivethrow2.wav", PRIO_ANNOUNCE, "Take THIS!" )


local mPowerMandelIntro_Subtitles = {

	{ "HALT!", 0 },
	{ "Where is Gabriel and what have you done to him?", 1 },

}

UltrakillBase.AddSoundScript( "Ultrakill_Power_SpecialIntro1", SND .. "specialintro1.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_Power_SpecialIntro1", 3, mPowerMandelIntro_Subtitles )