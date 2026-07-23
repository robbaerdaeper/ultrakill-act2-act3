	hook.Add("PopulateToolMenu", "NewUltrakillMusic", function()
		spawnmenu.AddToolMenuOption("DrGBase", "ULTRAKILL", "drgbase_ultrakill_music_act23", "ACT 2+3 Music Settings", "", "", function(Panel)
				Panel:CheckBox( "Enable Gutterman Music", "drg_ultrakill_guttermanmusic" )
				Panel:ControlHelp( "Enable/Disable Gutterman's Music." )

				Panel:CheckBox( "Enable Power Music", "drg_ultrakill_powermusic" )
				Panel:ControlHelp( "Enable/Disable Power's Music." )
		end)
    end)

if CLIENT then
CreateConVar( "drg_ultrakill_guttermanmusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Gutterman Music" )
local mGutterMusicConVar = CreateConVar( "drg_ultrakill_guttermanmusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Gutterman Music" )
UltrakillBase.AddMusic( "Do Robots Dream of Eternal Sleep?", "ultrakill/music/7-2 Intro Battle.wav", mGutterMusicConVar )

CreateConVar( "drg_ultrakill_powermusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Power Music" )
local mPowerMusicConVar = CreateConVar( "drg_ultrakill_powermusic", 1, { FCVAR_ARCHIVE, FCVAR_LUA_CLIENT }, "Enables Power Music" )
UltrakillBase.AddMusic( "The Shattering Circle, or: A Charade of Shadeless Ones and Zeroes Rearranged ad Nihilum", "ultrakill/music/8-3.wav", mGutterMusicConVar )
end

DrGBase.IncludeFolder( "ultrakillbase/Modules" )
DrGBase.IncludeFolder( "ultrakillbase/Includes/CustomCode/UltrakillBase" )
DrGBase.IncludeFolder( "ultrakillbase/Includes/CustomSounds" )