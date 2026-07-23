-- lua/autorun/ultrakill_categorize_npcs.lua
-- Unifies ALL ULTRAKILL nextbots in the stock spawnmenu under kevin's original
-- three categories (exact strings from the original DrGBase ULTRAKILL addons):
--   "ULTRAKILL - Enemies" / "ULTRAKILL - Bosses" / "ULTRAKILL - Secrets"
--
-- Also cleans the stock Entities tab: nextbot enemies register there as a side
-- effect of ENT.Spawnable = true (scripted_ents.Register → SpawnableEntities),
-- duplicating the NPCs tab (DrGBase already lists every nextbot in "NPC").
-- Nextbots are stripped from SpawnableEntities; real entities (soul orbs,
-- hookpoints, the Guttertank mine) stay, unified under one "ULTRAKILL" category.
--
-- The custom ULTRAKILL creation tab (ultrakill_creation_tab.lua) is unaffected:
-- it reads the same lists but only ever looks up classes we keep.
--
-- Runs post-load via InitPostEntity (and a fallback timer) so all workshop
-- addons have already registered their NPC list entries.

local CAT_ENEMIES = "ULTRAKILL - Enemies"
local CAT_BOSSES  = "ULTRAKILL - Bosses"
local CAT_SECRETS = "ULTRAKILL - Secrets"

-- GetCategory returns the FIRST match in list order, so exact-class / longer
-- overrides MUST stay above their parent prefixes (e.g. _normal variants above
-- the bare boss class, _ultrapain above ultrakill_v2).
local PREFIX_MAP = {

  -- ── Overrides (must precede their parent prefixes below) ─
  { prefix = "ultrakill_v2_ultrapain",              cat = CAT_SECRETS },
  { prefix = "ultrakill_fleshpanopticon_ultrapain", cat = CAT_SECRETS },
  { prefix = "ultrakill_test_gutterman_casketless", cat = CAT_SECRETS },
  { prefix = "ultrakill_test_gutterman_pod",        cat = CAT_SECRETS },
  { prefix = "ultrakill_test_gutterman_boss",       cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_power_boss1",       cat = CAT_BOSSES  },
  { prefix = "ultrakill_swordsmachine_agony",       cat = CAT_SECRETS },
  { prefix = "ultrakill_swordsmachine_tundra",      cat = CAT_SECRETS },
  { prefix = "ultrakill_swordsmachine_normal",      cat = CAT_ENEMIES },
  { prefix = "ultrakill_maliciousface_normal",      cat = CAT_ENEMIES },
  { prefix = "ultrakill_cerberus_normal",           cat = CAT_ENEMIES },
  { prefix = "ultrakill_hideousmass_normal",        cat = CAT_ENEMIES },
  -- Earthmover Defense System: mainframe/brain are boss parts, turrets are mobs
  { prefix = "ultrakill_test_em_mainframe",         cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_em_brain",             cat = CAT_BOSSES  },

  -- ── Enemies ─────────────────────────────────────────────
  { prefix = "ultrakill_filth",                cat = CAT_ENEMIES },
  { prefix = "ultrakill_stray",                cat = CAT_ENEMIES },
  { prefix = "ultrakill_schism",               cat = CAT_ENEMIES },
  { prefix = "ultrakill_soldier",              cat = CAT_ENEMIES },
  { prefix = "ultrakill_stalker",              cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_stalker",         cat = CAT_ENEMIES },
  { prefix = "ultrakill_drone",                cat = CAT_ENEMIES },
  { prefix = "ultrakill_streetcleaner",        cat = CAT_ENEMIES },
  { prefix = "ultrakill_mindflayer",           cat = CAT_ENEMIES },
  { prefix = "ultrakill_sentry",               cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_sentry",          cat = CAT_ENEMIES },
  { prefix = "ultrakill_gutterman",            cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_gutterman",       cat = CAT_ENEMIES },
  { prefix = "ultrakill_guttertank",           cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_guttertank",      cat = CAT_ENEMIES },
  { prefix = "ultrakill_idol",                 cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_idol",            cat = CAT_ENEMIES },
  { prefix = "ultrakill_deathcatcher",         cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_deathcatcher",    cat = CAT_ENEMIES },
  { prefix = "ultrakill_mannequin",            cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_mannequin",       cat = CAT_ENEMIES },
  { prefix = "ultrakill_virtue",               cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_virtue",          cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_providence",      cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_power",           cat = CAT_ENEMIES },
  -- секретный дуэт 6-1 (Angry/Rude) — точные оверрайды НАД родительским префиксом
  { prefix = "ultrakill_test_insurrectionist_angry", cat = CAT_SECRETS },
  { prefix = "ultrakill_test_insurrectionist_rude",  cat = CAT_SECRETS },
  { prefix = "ultrakill_insurrectionist",      cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_insurrectionist", cat = CAT_ENEMIES },
  { prefix = "ultrakill_ferryman",             cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_ferryman",        cat = CAT_ENEMIES },
  { prefix = "ultrakill_puppet",               cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_puppet",          cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_em_rocket",       cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_em_mortar",       cat = CAT_ENEMIES },
  { prefix = "ultrakill_test_em_tower",        cat = CAT_ENEMIES },

  -- ── Bosses ──────────────────────────────────────────────
  { prefix = "ultrakill_maliciousface",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_cerberus",             cat = CAT_BOSSES  },
  { prefix = "ultrakill_hideousmass",          cat = CAT_BOSSES  },
  { prefix = "ultrakill_hideous_mass",         cat = CAT_BOSSES  },
  { prefix = "ultrakill_swordsmachine",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_gabriel",              cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_gabriel2",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_minosprime",           cat = CAT_BOSSES  },
  { prefix = "ultrakill_sisyphusprime",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_minos",           cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_minotaur_boss",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_minotaur",             cat = CAT_BOSSES  },
  { prefix = "ultrakill_leviathan",            cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_leviathan",       cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_earthmover",      cat = CAT_BOSSES  },
  { prefix = "ultrakill_earthmover",           cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_geryon",          cat = CAT_BOSSES  },
  { prefix = "ultrakill_mirror_reaper",        cat = CAT_BOSSES  },
  { prefix = "ultrakill_test_mirror_reaper",   cat = CAT_BOSSES  },
  -- V Series (SonaristicCatboy) — unique duel characters, boss shelf
  { prefix = "ultrakill_v1",                   cat = CAT_BOSSES  },
  { prefix = "ultrakill_v2",                   cat = CAT_BOSSES  },
  -- Flesh bosses (SonaristicCatboy spellings + legacy underscore spellings);
  -- fleshpanopticon prefix also catches _breakout (_ultrapain → Secrets above)
  { prefix = "ultrakill_fleshprison",          cat = CAT_BOSSES  },
  { prefix = "ultrakill_fleshpanopticon",      cat = CAT_BOSSES  },
  { prefix = "ultrakill_flesh_prison",         cat = CAT_BOSSES  },
  { prefix = "ultrakill_flesh_panopticon",     cat = CAT_BOSSES  },

  -- ── Secrets ─────────────────────────────────────────────
  { prefix = "ultrakill_wicked",               cat = CAT_SECRETS },
  -- ultrakill_test_rodent also catches _big via the underscore rule
  { prefix = "ultrakill_test_rodent",          cat = CAT_SECRETS },
  { prefix = "ultrakill_druid",                cat = CAT_SECRETS },
  { prefix = "ultrakill_test_mdk",             cat = CAT_SECRETS },
  { prefix = "ultrakill_johninator",           cat = CAT_SECRETS },
  { prefix = "ultrakill_test_johninator",      cat = CAT_SECRETS },
  { prefix = "ultrakill_minimaurice",          cat = CAT_SECRETS },
  -- eyespawn prefix also catches _spotlight
  { prefix = "ultrakill_eyespawn",             cat = CAT_SECRETS },

}


local function GetCategory( class )
  for _, p in ipairs( PREFIX_MAP ) do
    if class == p.prefix or class:sub( 1, #p.prefix + 1 ) == p.prefix .. "_" then
      return p.cat
    end
  end
  return nil
end


local function IsUltrakillClass( class )
  -- isstring: some addons list.Add() numeric-keyed entries — calling :sub on a
  -- number key would crash the whole pass and leave every category raw.
  -- "ultrakill_" but NOT "ultrakillbase_*" (framework helpers stay untouched)
  return isstring( class ) and class:sub( 1, 10 ) == "ultrakill_"
end


local function ApplyCategories()
  -- 1) NPCs tab (+ DrGBase Nextbots tab): collapse everything into the three
  --    kevin categories. Entries are mutated in place via GetForEdit.
  for _, listName in ipairs( { "NPC", "DrGBaseNextbots" } ) do
    local L = list.GetForEdit( listName )
    if not L then continue end
    for class, entry in pairs( L ) do
      if not IsUltrakillClass( class ) then continue end
      if not istable( entry ) then continue end
      local cat = GetCategory( class )
      if cat then entry.Category = cat end
    end
  end

  -- 2) Entities tab: drop nextbot duplicates (they live in the NPCs tab via
  --    DrGBase's own list.Set("NPC", ...)). Real entities — soul orbs,
  --    hookpoints, the Guttertank mine — stay, under one "ULTRAKILL" category.
  local sents = list.GetForEdit( "SpawnableEntities" )
  if sents then
    for class, entry in pairs( sents ) do
      if not IsUltrakillClass( class ) then continue end
      if scripted_ents.IsBasedOn( class, "drgbase_nextbot" ) then
        sents[ class ] = nil
      elseif istable( entry ) then
        entry.Category = "ULTRAKILL"
      end
    end
  end
end


hook.Add( "InitPostEntity", "UKIdol_CategorizeNPCs", ApplyCategories )
-- Fallback for cases where InitPostEntity already fired (e.g. lua_openscript reload):
timer.Simple( 2, ApplyCategories )
-- Re-apply on every Q-menu open (client): idempotent and cheap, covers any
-- addon that (re)registers list entries after InitPostEntity, and guarantees
-- clean lists before the NPCs/Entities tab content is built on first click.
hook.Add( "OnSpawnMenuOpen", "UKIdol_CategorizeNPCs", ApplyCategories )
-- Manual re-apply for debugging: run ultrakill_recategorize, then spawnmenu_reload.
concommand.Add( "ultrakill_recategorize", function()
  ApplyCategories()
  print( "[ULTRAKILL] spawnmenu categories re-applied — run spawnmenu_reload to rebuild the menu" )
end )
