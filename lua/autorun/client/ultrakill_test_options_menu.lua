-- lua/autorun/client/ultrakill_test_options_menu.lua
-- Our settings panels live under the DrGBase tool tab, in the same
-- "ULTRAKILL" category ultrakillbase uses, so enemy/NPC settings sit in one
-- place. Weapon/HUD workshop addons keep their own Utilities panels.

if not CLIENT then return end


-- Mirror the server convars so the checkboxes can read their current value.
-- Both sides use the same flags so replication works in either direction.
if not ConVarExists( "ukidol_aggro_bug_enabled" ) then
  CreateClientConVar( "ukidol_aggro_bug_enabled", "0", true, false,
    "Enable the friendly-fire bug: blessed/puppeted enemies aggro on their Idol/Deathcatcher." )
end
if not ConVarExists( "ukpuppet_hostile_to_all_enabled" ) then
  CreateClientConVar( "ukpuppet_hostile_to_all_enabled", "0", true, false,
    "Make every Deathcatcher-spawned puppet hostile to all players and NPCs." )
end
if not ConVarExists( "ukdc_revive_deathcatchers_enabled" ) then
  CreateClientConVar( "ukdc_revive_deathcatchers_enabled", "0", true, false,
    "Allow Deathcatchers to revive other Deathcatchers as puppets." )
end
if not ConVarExists( "uksupport_whiplash_pull_enabled" ) then
  CreateClientConVar( "uksupport_whiplash_pull_enabled", "0", true, false,
    "Allow the whiplash to grab and pull the Idol/Deathcatcher statues." )
end
if not ConVarExists( "ultrakill_enemies_infight" ) then
  CreateClientConVar( "ultrakill_enemies_infight", "0", true, false,
    "ULTRAKILL enemies attack each other (same enemy type stays allied)." )
end
if not ConVarExists( "ultrakill_enemies_wander" ) then
  CreateClientConVar( "ultrakill_enemies_wander", "0", true, false,
    "ULTRAKILL enemies lose omniscience: they roam around and hunt by sight and sound." )
end
if not ConVarExists( "ultrakill_enemies_wander_sightrange" ) then
  CreateClientConVar( "ultrakill_enemies_wander_sightrange", "6000", true, false,
    "Sight range (units) while wander mode is on. 0 = keep the class value." )
end


-- Undo the Utilities→DrGBase detour from an earlier revision if its original
-- is still stashed in the global (survives autorefresh without a map change).
if UKTest_OrigAddToolMenuOption then
  spawnmenu.AddToolMenuOption = UKTest_OrigAddToolMenuOption
  UKTest_OrigAddToolMenuOption = nil
end


-- Move every "Tools - ULTRAKILL" toolgun tool (ours + ultrakillbase's
-- Radiance/Sandify) into the DrGBase tab so they sit in one category there.
-- Sandbox reads tool.Tab from the stored TOOL tables inside its own
-- PopulateToolMenu hook, and the spawnmenu runs AddToolMenuTabs strictly
-- before that, so retabbing here is race-free. Runtime tweak only — the
-- ultrakillbase workshop files stay untouched.
hook.Add( "AddToolMenuTabs", "UKTest_RetabUltrakillTools", function()
  local swep = weapons.GetStored( "gmod_tool" )
  if not ( swep and swep.Tool ) then return end
  for _, tool in pairs( swep.Tool ) do
    if tool.Category == "Tools - ULTRAKILL" then
      tool.Tab = "DrGBase"
    end
  end
end )


hook.Add( "PopulateToolMenu", "UKTest_OptionsMenu", function()

  spawnmenu.AddToolMenuOption(
    "DrGBase", "ULTRAKILL", "UKTest_Bugs", "Funny Bugs", "", "",
    function( panel )
      panel:ClearControls()
      panel:Help(
        "Toggle gameplay bugs / chaos modes kept around for the lulz." )

      panel:CheckBox(
        "Blessed/Puppeted enemies aggro on Idol/Deathcatcher",
        "ukidol_aggro_bug_enabled" )
      panel:ControlHelp(
        "When on, an enemy bonded by an Idol or revived by a Deathcatcher will\n"
        .. "still try to attack the support entity that bonded with it." )

      panel:CheckBox(
        "Puppets are hostile to ALL (rampage mode)",
        "ukpuppet_hostile_to_all_enabled" )
      panel:ControlHelp(
        "When on, every Deathcatcher-spawned puppet attacks every player, NPC,\n"
        .. "and other puppet (including its own Deathcatcher)." )

      panel:CheckBox(
        "Deathcatchers revive other Deathcatchers",
        "ukdc_revive_deathcatchers_enabled" )
      panel:ControlHelp(
        "When on, a slain Deathcatcher near another active one gets revived\n"
        .. "as a puppet-catcher — which keeps catching and reviving on its own.\n"
        .. "A lone Deathcatcher still can't resurrect itself." )

      panel:CheckBox(
        "Whiplash can yank Idols/Deathcatchers around",
        "uksupport_whiplash_pull_enabled" )
      panel:ControlHelp(
        "When on, the ULTRAKILL Arms whiplash grabs the support statues and\n"
        .. "reels the whole thing straight into your face. When off (default)\n"
        .. "the hook passes through them." )

      panel:CheckBox(
        "Enemies attack each other (infighting)",
        "ultrakill_enemies_infight" )
      panel:ControlHelp(
        "Every ULTRAKILL enemy turns hostile to every other one.\n"
        .. "Same kind never fights itself (Filth won't attack Filth), and\n"
        .. "multi-part bosses never fight their own limbs.\n"
        .. "Idols & Deathcatchers referee the brawl: nobody targets them,\n"
        .. "the Idol blesses the strongest fighter, the DC revives the\n"
        .. "fallen as puppets — which every living enemy then hunts." )
    end
  )

  spawnmenu.AddToolMenuOption(
    "DrGBase", "ULTRAKILL", "UKTest_AI", "Enemy AI", "", "",
    function( panel )
      panel:ClearControls()
      panel:Help( "Enemy awareness / roaming behavior." )

      panel:CheckBox(
        "Enemies wander & search (no omniscience)",
        "ultrakill_enemies_wander" )
      panel:ControlHelp(
        "Canon enemies always know where you are. This strips that: they\n"
        .. "only notice what they can SEE (line of sight) or HEAR (gunshots\n"
        .. "make them run over to investigate), stroll to random spots while\n"
        .. "idle, and check your last known position after losing you.\n"
        .. "Needs a navmesh on the map. Hover enemies, supports and\n"
        .. "stationary bosses keep their all-seeing eyes." )

      panel:NumSlider(
        "Sight range", "ultrakill_enemies_wander_sightrange", 0, 15000, 0 )
      panel:ControlHelp(
        "How far they can spot you while the mode is on.\n"
        .. "0 = keep the class value (base default 15000 — nearly map-wide;\n"
        .. "lower it for proper hide-and-seek)." )
    end
  )

  spawnmenu.AddToolMenuOption(
    "DrGBase", "ULTRAKILL", "UKTest_SpawnMenu", "Spawn Menu", "", "",
    function( panel )
      panel:ClearControls()
      panel:Help( "Spawn-menu layout options." )

      -- Convar lives in ultrakill_creation_tab.lua; its change callback
      -- re-adds / removes the tab and runs spawnmenu_reload.
      panel:CheckBox( "Show the ULTRAKILL tab", "ultrakill_spawnmenu_tab" )
      panel:ControlHelp(
        "Top-level Q-menu tab with every enemy grouped by class.\n"
        .. "Toggling rebuilds the spawnmenu (it will close — reopen with Q)." )
    end
  )

  spawnmenu.AddToolMenuOption(
    "DrGBase", "ULTRAKILL", "UKTest_SoulOrbs", "Soul Orbs", "", "",
    function( panel )
      panel:ClearControls()
      panel:Help( "Gold soul orb / dual wield power-up settings." )

      panel:NumSlider(
        "Dual wield duration (s)", "ultrakill_dualwield_duration", 5, 300, 0 )
      panel:ControlHelp( "Juice per gold orb pickup. Canon: 30." )

      panel:NumSlider(
        "Echo shot delay (s)", "ultrakill_dualwield_delay", 0, 1, 2 )
      panel:ControlHelp( "Delay between each copy's echo shot.\n"
        .. "0 = canon minimum (0.05s per copy)." )

      panel:NumSlider(
        "Max visual weapon copies", "ultrakill_dualwield_maxcopies_visual", 1, 16, 0 )

      panel:CheckBox(
        "Infinite power-ups (dual wield never expires)",
        "ultrakill_powerups_infinite" )
      panel:ControlHelp(
        "Juice stays pinned at full; death/respawn still clears the stacks." )

      panel:CheckBox(
        "Sharpshooter helicopter (4+ stacks, hold RMB)",
        "ultrakill_sharpshooter_helicopter" )
      panel:ControlHelp(
        "1-3 stacks slow your fall while twirling; 4+ stacks lift off,\n"
        .. "more stacks = stronger flight." )

      panel:Help( "DEBUG orb sizing: spawned orbs update live. -1 = use the\n"
        .. "value baked into the code." )

      panel:NumSlider( "Red orb radius", "ultrakill_orb_red_radius", -1, 100, 0 )
      panel:NumSlider( "Red orb height", "ultrakill_orb_red_height", -1, 100, 0 )
      panel:NumSlider( "Yellow orb radius", "ultrakill_orb_yellow_radius", -1, 100, 0 )
      panel:NumSlider( "Yellow orb height", "ultrakill_orb_yellow_height", -1, 100, 0 )
      panel:ControlHelp(
        "Radius = sphere/glow size and the pickup range.\n"
        .. "Height = orb center over the ground (below radius sinks the sphere)." )
    end
  )

end )
