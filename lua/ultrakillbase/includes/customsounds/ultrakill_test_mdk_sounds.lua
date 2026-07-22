-- lua/ultrakillbase/includes/customsounds/ultrakill_test_mdk_sounds.lua
-- MDK voice kit через штатную систему UltrakillBase (как у прайм-душ):
-- AddSoundScript + AddVoiceSoundScript = сабтитры + приоритетное перебивание.
-- Тексты/тайминги — канон из Mandalore.cs (SubtitleController.DisplaySubtitle).
--
-- Цвета сабтитров — канонные из декомпила: рыцарь <color=#FFC49E>,
-- сова <color=#9EE6FF>. Прокидываются префиксом "<#RRGGBB>" в строке —
-- его понимает наш рендерер (autorun/client/ultrakill_mdk_hud.lua);
-- "Full auto"/"Fuller auto" — обычный белый, как в игре.
--
-- Пары mandy/shammy: скрипт играет основной файл, второй голос энтити
-- доигрывает обычным EmitSound одновременно.

local SND = "ultrakill_prelude_test/mdk/"

local MANDY = "<#FFC49E>"
local SHAMMY = "<#9EE6FF>"

-- Приоритеты: таунты/анонсы 1 < фазы 2 < смерть 3 (канон: aud.Stop() + новая).
local PRIO_TAUNT, PRIO_PHASE, PRIO_DEATH = 1, 2, 3

-- Интро энкаунтера (сцена 4-3, GO IntroLine): всегда первая реплика спавна.
UltrakillBase.AddSoundScript( "Ultrakill_MDK_Intro", SND .. "waitingpuzzle2_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Intro", PRIO_TAUNT, {
  { MANDY .. "Finally, our waiting puzzle is over", 0 },
  { SHAMMY .. "What?", 2.6 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Taunt1", SND .. "taunt1_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Taunt1", PRIO_TAUNT, {
  { MANDY .. "You cannot imagine what you'll face here", 0 },
  { SHAMMY .. "I'm gonna shoot em with a gun", 2.5 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Taunt2", SND .. "taunt2_shammy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Taunt2", PRIO_TAUNT, SHAMMY .. "Why are we in the past" )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Taunt3", SND .. "taunt3_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Taunt3", PRIO_TAUNT, {
  { MANDY .. "I'm going to fucking poison you", 0 },
  { SHAMMY .. "What", 2 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Taunt4", SND .. "taunt4_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Taunt4", PRIO_TAUNT, {
  { MANDY .. "Hold still", 0.6 },
} )

-- Анонсы атак — обычный белый текст (канон, без цветовых тегов).
UltrakillBase.AddSoundScript( "Ultrakill_MDK_FullAuto", SND .. "fullauto.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_FullAuto", PRIO_TAUNT, "Full auto" )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_FullerAuto", SND .. "fullerauto.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_FullerAuto", PRIO_TAUNT, "Fuller auto" )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Phase2", SND .. "speed1_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Phase2", PRIO_PHASE, {
  { MANDY .. "Through the magic of the Druids, I increase my speed!", 0 },
  { SHAMMY .. "Just fucking hit em", 2.5 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Phase3", SND .. "speed2_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Phase3", PRIO_PHASE, {
  { MANDY .. "Feel my maximum speed!", 0 },
  { SHAMMY .. "Slow down", 3.25 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Phase4", SND .. "speed3_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Phase4", PRIO_PHASE, {
  { SHAMMY .. "Use the salt!", 0 },
  { MANDY .. "I'm reaching!", 1.5 },
} )

UltrakillBase.AddSoundScript( "Ultrakill_MDK_Death", SND .. "death_mandy.wav", 0, 1, 1, nil, false, 0, true )
UltrakillBase.AddVoiceSoundScript( "Ultrakill_MDK_Death", PRIO_DEATH, {
  { MANDY .. "AGHHH!", 0 },
  { SHAMMY .. "Oh great, now we lost the fight, fantastic", 0.6 },
} )
