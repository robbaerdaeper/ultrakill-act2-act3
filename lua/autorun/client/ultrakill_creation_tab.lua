-- ULTRAKILL spawn-menu tab.
--
-- Single top-level Q-menu tab "ULTRAKILL" with collapsible categories. Class
-- order inside each category is preserved EXACTLY as listed below — no
-- alphabetical sort. Bosses live near the bottom in their own category; the
-- "???" junk drawer (hard-to-classify variants) closes the tab.
--
-- The legacy `ultrakill_categorize_npcs.lua` still recategorizes the standard
-- NPCs tab — both views coexist.

if SERVER then return end


-- =============================================================================
-- Tab definitions. Class lists are in DISPLAY ORDER. Exact match only — variants
-- (`_normal`, `_agony`, `_tundra`) must be listed individually.
-- =============================================================================

local MAIN_TAB = {
  { name = "Husks",       expanded = true, classes = {
    "ultrakill_filth",
    "ultrakill_stray",
    "ultrakill_schism",
    "ultrakill_soldier",
    "ultrakill_test_stalker",
    "ultrakill_test_insurrectionist",  -- Supreme Husk (4-2 boss / Act II+)
    "ultrakill_test_ferryman",  -- Supreme Husk (5-2 / P-2)
    "ultrakill_test_mirror_reaper",  -- Supreme Husk (8-2 / Cyber Grind)
  } },
  { name = "Machines",    expanded = true, classes = {
    "ultrakill_swordsmachine_normal",
    "ultrakill_drone",
    "ultrakill_streetcleaner",
    "ultrakill_mindflayer",
    "ultrakill_test_sentry",
    "ultrakill_test_gutterman",
    "ultrakill_test_guttertank",
    -- Earthmover Defense System components (7-4), одиночный спавн
    "ultrakill_test_em_rocket",
    "ultrakill_test_em_mortar",
    "ultrakill_test_em_tower",
    -- V Series (Supreme Machines) — SonaristicCatboy collab, workshop 3708282959
    "ultrakill_v1",
    "ultrakill_v2",
    "ultrakill_v2_2",           -- V2 (Greed) — 4-4 rematch, whiplash arm
  } },
  { name = "Demons",      expanded = true, classes = {
    "ultrakill_maliciousface_normal",
    "ultrakill_cerberus_normal",
    "ultrakill_hideousmass_normal",
    "ultrakill_test_idol",     "ultrakill_idol",
    "ultrakill_test_deathcatcher", "ultrakill_deathcatcher",
    "ultrakill_test_mannequin",    -- Lesser Demon (Act III)
    "ultrakill_test_minotaur",     -- Supreme Demon (7-2 tram-arena boss)
  } },
  { name = "Angels",      expanded = true, classes = {
    "ultrakill_test_virtue",
    "ultrakill_test_providence",  -- Lesser Angel (Layer 8)
    "ultrakill_test_power",       -- Greater Angel (8-3 / Cyber Grind)
    "ultrakill_gabriel",
    "ultrakill_test_gabriel2",    -- Gabriel, Apostate of Hate (6-2, our port)
  } },
  { name = "Prime Souls", expanded = true, classes = {
    "ultrakill_minosprime",
    "ultrakill_sisyphusprime",
  } },
  { name = "Other",       expanded = true, classes = {
    "ultrakill_wicked",
    "ultrakill_test_rodent",          -- Cancerous Rodent
    "ultrakill_test_rodent_big",      -- Very Cancerous Rodent
    "ultrakill_test_mdk",             -- Mysterious Druid Knight (& Owl), 4-3 secret
    "ultrakill_test_johninator",      -- Big Johninator (secret joke boss statue)
    "ultrakill_test_puppet",          -- Puppet
    -- Flesh boss summons — SonaristicCatboy NPCs, workshop 3671170098. His addon
    -- ships no icons for these; ours come from the BillyMod spawner-arm DLL.
    "ultrakill_minimaurice",          -- Flesh Prison spawn on Brutal difficulty
    "ultrakill_eyespawn",             -- Flesh Prison healing eye
    "ultrakill_eyespawn_spotlight",   -- Flesh Panopticon spotlight eye
    "ultrakill_swordsmachine_tundra", -- variant — unclear bucket, parked here
    "ultrakill_swordsmachine_agony",  -- variant — unclear bucket, parked here
    "ultrakill_test_insurrectionist_angry", -- 6-1 secret duo (red)
    "ultrakill_test_insurrectionist_rude",  -- 6-1 secret duo (blue)
  } },
  { name = "Bosses",      expanded = true, classes = {
    "ultrakill_maliciousface",
    "ultrakill_cerberus",
    "ultrakill_swordsmachine",  -- 1-1 boss encounter (variants live in Machines/Other)
    "ultrakill_hideousmass",
    "ultrakill_test_gutterman_boss",
    "ultrakill_test_power_boss1",
    -- 2-4 "Court of the Corpse King" — first encounter (Arm) + the Corpse (1:1)
    "ultrakill_test_minos_arm",
    "ultrakill_test_minos_corpse",
    -- 5-4 "LEVIATHAN" — Leviathan (Supreme Demon, lake-arena boss)
    "ultrakill_test_leviathan",
    -- 7-4 "...Like Antennas to Heaven" — Earthmover: walker + Defense System + Brain
    "ultrakill_test_earthmover",
    "ultrakill_test_em_mainframe",
    "ultrakill_test_em_brain",
    -- 8-4 "Like a Thief in the Night" — Geryon, Watcher of the Skies (Supreme Demon)
    "ultrakill_test_geryon",
    -- Prime Sanctum bosses — SonaristicCatboy collab, workshop 3671170098
    "ultrakill_fleshprison",
    "ultrakill_fleshpanopticon",
    "ultrakill_fleshpanopticon_breakout",
  } },
  -- Soul orb power-ups (entities, not NPCs — see type = "entity")
  { name = "Power-Ups",   expanded = true, type = "entity", classes = {
    "ent_uk_soulorb_red",     -- 200 HP (canon BonusSuperCharge)
    "ent_uk_soulorb_yellow",  -- dual wield, stackable (canon BonusDualWield)
  } },
  -- Whiplash anchors (canon GrapplePoint, Violence layer). Sandbox spawns the
  -- same three types as the game's own sandbox: green / blue / pink.
  { name = "Hookpoints",  expanded = true, type = "entity", classes = {
    "ultrakill_test_hookpoint",        -- green: pull + up-push, momentum reset
    "ultrakill_test_hookpoint_blue",   -- blue: slingshot, keeps momentum
    "ultrakill_test_hookpoint_pink",   -- pink: slingshot + heal + explosion
  } },
  -- Deployable enemy gear, spawnable standalone (owner = the spawner: the
  -- mine arms against everyone but the player who placed it)
  { name = "Devices",     expanded = true, type = "entity", classes = {
    "ultrakill_test_guttertank_mine",  -- canon sandbox Landmine icon
  } },
  -- Junk drawer: modded-difficulty versions and alternate deployment forms
  -- that don't belong to any canon enemy class bucket.
  { name = "???",         expanded = true, classes = {
    "ultrakill_v2_ultrapain",              -- ULTRAPAIN (mod difficulty)
    "ultrakill_fleshpanopticon_ultrapain", -- ULTRAPAIN (mod difficulty)
    "ultrakill_test_gutterman_casketless",
    "ultrakill_test_gutterman_pod",        -- pod drop
  } },
}


-- =============================================================================
-- Layout constants. ContentIcon is 128×128 by default; anything smaller and
-- the auto-flow column count gets weird at common Q-menu widths.
-- =============================================================================

local ICON_SIZE  = 128
local ICON_PAD   = 4
local TILE       = ICON_SIZE + ICON_PAD
local HEADER_PAD = 32


-- Per-category icon background tint. Drawn behind the ContentIcon's image so
-- transparent / white-silhouette NPC icons read as "Hotline Miami"-style class
-- swatches (ULTRAKILL's own UI uses similar colour-coding by enemy class).
local CATEGORY_BG = {
  [ "Husks" ]       = Color( 0xE5, 0xA8, 0xA8 ),
  [ "Machines" ]    = Color( 0x7A, 0x9E, 0xD9 ),
  [ "Demons" ]      = Color( 0x84, 0xE7, 0x82 ),
  [ "Angels" ]      = Color( 0xFF, 0xE8, 0x72 ),
  [ "Prime Souls" ] = Color( 0x59, 0x59, 0x59 ),
  [ "Other" ]       = Color( 0xBF, 0xBF, 0xBF ),
  -- Bosses / ???: no tint specified — leave default
}


-- Per-class material override. Most NPC classes use `entities/<class>.png` by
-- convention; this map only handles the rare exceptions where the icon lives
-- under a different name. Currently empty — both swordsmachine variants and
-- Deathcatcher now have proper icons under their canonical paths.
local MATERIAL_OVERRIDE = {}


-- =============================================================================
-- Bucket collection. Iterates each category's class list IN GIVEN ORDER and
-- only includes classes that exist in list.Get("NPC"). Result preserves the
-- explicit order from the tab definitions above.
-- =============================================================================

local function CollectForTab( categories )
  local buckets = {}
  local npcs = list.Get( "NPC" ) or {}
  local sents = list.Get( "SpawnableEntities" ) or {}

  for _, cat in ipairs( categories ) do
    local pool = ( cat.type == "entity" ) and sents or npcs
    local bucket = {}
    for _, class in ipairs( cat.classes ) do
      local entry = pool[ class ]
      if entry and istable( entry ) then
        table.insert( bucket, { class = class, entry = entry } )
      end
    end
    buckets[ cat.name ] = bucket
  end

  return buckets
end


-- =============================================================================
-- Panel builder (shared between both tabs)
-- =============================================================================

local function BuildPanel( categories )
  local panel = vgui.Create( "DPanel" )
  panel:Dock( FILL )
  panel:SetPaintBackground( false )

  local scroll = vgui.Create( "DScrollPanel", panel )
  scroll:Dock( FILL )

  -- Categories dock onto the canvas — its auto-grow vertical sizing is what
  -- gives us the outer scrollbar when content exceeds the viewport.
  local canvas = scroll:GetCanvas()

  local buckets = CollectForTab( categories )

  for _, cat in ipairs( categories ) do
    local entries = buckets[ cat.name ] or {}
    if #entries == 0 then continue end

    local node = vgui.Create( "DCollapsibleCategory", canvas )
    node:Dock( TOP )
    node:DockMargin( 2, 2, 2, 2 )
    node:SetLabel( string.format( "%s (%d)", cat.name, #entries ) )
    node:SetExpanded( cat.expanded ~= false )

    local layout = vgui.Create( "DIconLayout" )
    layout:SetSpaceX( ICON_PAD )
    layout:SetSpaceY( ICON_PAD )

    local catBG = CATEGORY_BG[ cat.name ]

    for _, e in ipairs( entries ) do
      -- spawnmenu.CreateContentIcon dispatches to the "npc" content type
      -- callback registered by GMod itself, which wires DoClick →
      -- gmod_spawnnpc plus the standard right-click menu / spawn-tool hookup.
      local mat = MATERIAL_OVERRIDE[ e.class ] or ( "entities/" .. e.class .. ".png" )
      -- "entity" categories dispatch to the sandbox entity content type
      -- (SpawnableEntities entries use PrintName, not Name)
      local icon = spawnmenu.CreateContentIcon( cat.type or "npc", layout, {
        nicename  = e.entry.Name or e.entry.PrintName or e.class,
        spawnname = e.class,
        material  = mat,
        admin     = e.entry.AdminOnly,
        weapon    = e.entry.Weapons,
      } )

      -- Tinted background for the icon. ContentIcon's Paint draws the icon
      -- image (and label gradient) — overriding it here paints a solid colour
      -- BEFORE the chain runs so transparent icon edges show the tint. Inset
      -- by 3px because ContentIcon's visible image area sits inside a small
      -- internal margin — drawing edge-to-edge bleeds past the visual border.
      if IsValid( icon ) and catBG then
        local oldPaint = icon.Paint
        icon.Paint = function( self, w, h )
          surface.SetDrawColor( catBG.r, catBG.g, catBG.b, 255 )
          surface.DrawRect( 3, 3, w - 6, h - 6 )
          if oldPaint then oldPaint( self, w, h ) end
        end
      end
    end

    node:SetContents( layout )

    -- Pre-size so first SetExpanded() reads non-zero contents:GetTall(),
    -- otherwise a category that begins collapsed unfolds to header-only.
    local rows0 = math.ceil( #entries / 5 )
    layout:SetTall( rows0 * TILE )
    node:SetTall( rows0 * TILE + HEADER_PAD )

    -- Per-layout pass keeps contents height in sync with current width.
    -- Update layout BEFORE calling parent PerformLayout so the collapsible's
    -- own expand/collapse height calculation reads the right contents height.
    function node:PerformLayout()
      if IsValid( layout ) then
        local cols = math.max( 1, math.floor( self:GetWide() / TILE ) )
        local rows = math.ceil( #entries / cols )
        local lh = rows * TILE
        if layout:GetTall() ~= lh then layout:SetTall( lh ) end
      end
      DCollapsibleCategory.PerformLayout( self )
    end
  end

  return panel
end


-- =============================================================================
-- Tab registration. Gated behind an archived convar so the tab can be turned
-- off from the settings panel (DrGBase → ULTRAKILL → Spawn Menu) or console.
-- =============================================================================

local TAB_NAME = "ULTRAKILL"

local cvTab = CreateClientConVar( "ultrakill_spawnmenu_tab", "1", true, false,
  "Show the ULTRAKILL tab in the spawnmenu (Q menu).", 0, 1 )

local function RegisterTab()
  spawnmenu.AddCreationTab(
    TAB_NAME,
    function() return BuildPanel( MAIN_TAB ) end,
    "icon16/ultrakill_v1.png",
    1,
    "ULTRAKILL enemies — Husks / Machines / Demons / Angels / Prime Souls / Other / Bosses"
  )
end

if cvTab:GetBool() then RegisterTab() end

cvars.AddChangeCallback( "ultrakill_spawnmenu_tab", function( _, _, new )
  if tobool( new ) then
    RegisterTab()
  else
    -- GetCreationTabs() hands back the live registry table; there is no
    -- RemoveCreationTab, so delete the entry directly.
    spawnmenu.GetCreationTabs()[ TAB_NAME ] = nil
  end
  -- Deferred one frame: the toggle usually comes from a checkbox inside the
  -- very spawnmenu the reload is about to destroy.
  timer.Simple( 0, function() RunConsoleCommand( "spawnmenu_reload" ) end )
end, "UKTest_CreationTabToggle" )
