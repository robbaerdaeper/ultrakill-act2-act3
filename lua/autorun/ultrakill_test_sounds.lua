	hook.Add("PopulateToolMenu", "NewUltrakillMusic", function()
spawnmenu.AddToolMenuOption("DrGBase", "ULTRAKILL", "drgbase_ultrakill_music_sc", "ACT 2+3 Music Settings", "", "", function(Panel)
				Panel:CheckBox( "Enable Gutterman Music", "drg_ultrakill_guttermanmusic" )
				Panel:ControlHelp( "Enable/Disable Gutterman's Music." )
		end)
    end)

if CLIENT then
CreateConVar( "drg_ultrakill_guttermanmusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Gutterman Music" )
local mGutterMusicConVar = CreateConVar( "drg_ultrakill_guttermanmusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Gutterman Music" )
UltrakillBase.AddMusic( "Do Robots Dream of Eternal Sleep?", "ultrakill/music/7-2 Intro Battle.wav", mGutterMusicConVar )
end

DrGBase.IncludeFolder( "ultrakillbase/Modules" )
DrGBase.IncludeFolder( "ultrakillbase/Includes/CustomCode/UltrakillBase" )
DrGBase.IncludeFolder( "ultrakillbase/Includes/CustomSounds" )