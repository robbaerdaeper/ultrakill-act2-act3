-- lua/autorun/server/ultrakill_test_infight.lua
-- "Enemies attack each other" mode: every ULTRAKILL nextbot turns hostile to
-- every other ULTRAKILL nextbot of a DIFFERENT species — Filth never fights
-- Filth, and multi-part bosses (Earthmover turrets/brain, Leviathan tail,
-- Minos arm, Mirror Reaper hands, Gutterman shield helper...) never brawl
-- with their own limbs. Toggling off restores the canon faction alliance.
--
-- The supports referee the brawl instead of joining it:
--   * Idols / Deathcatchers are never targeted (canon outsider→support D_NU
--     stays in force) and keep doing their job — the Idol blesses the
--     strongest fighter (rank pick), the DC revives the fallen as puppets.
--   * Blessed champions KEEP fighting: their support relations live in the
--     blessed→support slots, which we never touch.
--   * Puppets rejoin the brawl against EVERYTHING living, own species
--     included (a revived husk is Death's construct, not kin); puppet↔puppet
--     stays allied (siblings). The outsider→puppet slot is owned by
--     ultrakill_test_idol_blessing.lua — its canon branch consults
--     UKInfight.ShouldFight so both systems write the same value.

if not SERVER then return end

UKInfight = UKInfight or {}

local cv_infight = CreateConVar( "ultrakill_enemies_infight", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "ULTRAKILL enemies attack each other (same enemy type stays allied)." )

-- Support entities never join the brawl — the blessing/puppet relationship
-- system owns their relations (ultrakill_test_idol_blessing.lua).
local SUPPORT_CLASSES = {
  ultrakill_test_idol         = true,
  ultrakill_test_deathcatcher = true,
  ultrakill_idol              = true,
  ultrakill_deathcatcher      = true,
}

-- Hostility override far above the faction-ally definers (DrGBase default
-- priority is 1) yet below the blessing/puppet tier (999).
local INFIGHT_PRIO = 900
UKInfight.PRIO = INFIGHT_PRIO


local function IsPuppet( ent )
  return UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ ent ] or false
end


-- Species key = first class-name segment after the addon prefix, so canon
-- variants and body parts collapse onto one key ("leviathan_tail" →
-- "leviathan", "minos_arm" → "minos", "gutterman_boss" → "gutterman").
local function SpeciesKey( ent )
  local cls = ent:GetClass()
    :gsub( "^ultrakill_test_", "" )
    :gsub( "^ultrakillbase_", "" )
    :gsub( "^ultrakill_", "" )
  local seg = cls:match( "^[^_]+" ) or cls
  -- Earthmover parts are "em_*" but the body is "earthmover"
  if seg == "em" then return "earthmover" end
  return seg
end


-- Brawl participants: UK-faction nextbots including blessed champions,
-- puppets AND the standalone bosses. Kevin's bosses sit in their own factions
-- (FACTION_ULTRAKILL_MINOS / _GABRIEL / _SISYPHUS), not in _ENEMIES — accept
-- any FACTION_ULTRAKILL* membership. Without this, Minos Prime was not a
-- participant, so ShouldFight()=false and the blessing system's canon branch
-- FORCED him neutral (D_NU@999) toward every puppet — «живые не трогают
-- папетов» (playtest report 2026-07-07). Only the support infrastructure sits out.
local function IsInfightNPC( ent )
  if not IsValid( ent ) or not ent.IsDrGNextbot then return false end
  if SUPPORT_CLASSES[ ent:GetClass() ] then return false end
  if not isfunction( ent.IsInFaction ) then return false end
  if ent:IsInFaction( "FACTION_ULTRAKILL_ENEMIES" ) then return true end
  -- _DrGBaseFactions keys are upper-cased by JoinFaction
  for faction in pairs( ent._DrGBaseFactions or {} ) do
    if isstring( faction ) and faction:sub( 1, 17 ) == "FACTION_ULTRAKILL" then
      return true
    end
  end
  return false
end


function UKInfight.IsEnabled()
  return cv_infight:GetBool()
end

-- Shared verdict for this file AND the blessing system's outsider→puppet
-- branch. Rules, in order:
--   * puppet vs puppet          → never (all DC's team)
--   * living vs puppet          → ALWAYS fight, same species included — a
--                                  revived husk is Death's construct, not kin
--                                  (playtest report 2026-07-07: «живые не трогают
--                                  папетов» — species loyalty used to shield
--                                  same-species puppets from the whole brawl)
--   * living vs living          → fight only across species (Filth never
--                                  attacks a living Filth)
function UKInfight.ShouldFight( a, b )
  if not cv_infight:GetBool() then return false end
  if not ( IsInfightNPC( a ) and IsInfightNPC( b ) ) then return false end
  local aPup = IsPuppet( a ) and true or false
  local bPup = IsPuppet( b ) and true or false
  if aPup and bPup then return false end
  if aPup ~= bPup then return true end
  if SpeciesKey( a ) == SpeciesKey( b ) then return false end
  return true
end


-- Restore "no override". For enemy↔enemy that is DrGBase's DEFAULT_REL
-- (D_NU prio 1) so the faction alliance resolves again; pairs touching a
-- puppet get the blessing system's canon value instead (D_NU prio 999 —
-- forced neutrality toward puppets).
local function ClearPair( a, b )
  local prio = ( IsPuppet( a ) or IsPuppet( b ) ) and 999 or 1
  a:SetEntityRelationship( b, D_NU, prio )
  b:SetEntityRelationship( a, D_NU, prio )
end

-- Drive a pair to its correct state. Crucially this also CLEARS pairs that
-- should no longer fight (same living species, or both just became puppets),
-- so stale D_HT from a previous state doesn't linger.
local function ReconcilePair( a, b )
  if UKInfight.ShouldFight( a, b ) then
    a:SetEntityRelationship( b, D_HT, INFIGHT_PRIO )
    b:SetEntityRelationship( a, D_HT, INFIGHT_PRIO )
  else
    ClearPair( a, b )
  end
end


local function AllInfightNPCs()
  local list = {}
  for _, ent in ipairs( ents.GetAll() ) do
    if IsInfightNPC( ent ) then list[ #list + 1 ] = ent end
  end
  return list
end

local function ApplyAll( on )
  local npcs = AllInfightNPCs()
  for i = 1, #npcs do
    for j = i + 1, #npcs do
      if on then
        ReconcilePair( npcs[ i ], npcs[ j ] )
      else
        ClearPair( npcs[ i ], npcs[ j ] )
      end
    end
  end
end


cvars.AddChangeCallback( "ultrakill_enemies_infight", function( _, _, newVal )
  ApplyAll( tobool( newVal ) )
end, "UKInfight_Live" )


-- Newly spawned enemies join the brawl ~0.5s later: DrGBase rebuilds its
-- relationship definers during Initialize, so anything applied earlier gets
-- wiped (the PostSpawn-reset trap).
hook.Add( "OnEntityCreated", "UKInfight_Spawn", function( ent )
  if not cv_infight:GetBool() then return end
  timer.Simple( 0.5, function()
    if not cv_infight:GetBool() then return end
    if not IsInfightNPC( ent ) then return end
    for _, other in ipairs( AllInfightNPCs() ) do
      if other ~= ent then ReconcilePair( ent, other ) end
    end
  end )
end )


-- Slow reconciler: DC revivals, puppet cleanses, un-blessings and missed
-- spawns drift the overrides — sweep them back every 10s while the mode is
-- on. This is also what folds freshly revived puppets back into the brawl.
timer.Create( "UKInfight_Reconcile", 10, 0, function()
  if not cv_infight:GetBool() then return end
  ApplyAll( true )
end )
