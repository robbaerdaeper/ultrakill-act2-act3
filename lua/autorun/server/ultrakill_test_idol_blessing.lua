-- lua/autorun/server/ultrakill_test_idol_blessing.lua
if not SERVER then return end

util.AddNetworkString( "UKIdol_HitFlash" )


-- Classes that should be treated as allies by any blessed/puppeted NPC.
-- Idols & Deathcatchers are "support infrastructure" — canon ULTRAKILL never
-- lets their own beneficiaries attack them, so we mirror that here.
local SUPPORT_CLASSES = {
  ultrakill_test_idol         = true,
  ultrakill_test_deathcatcher = true,
  ultrakill_idol              = true,
  ultrakill_deathcatcher      = true,
}

-- Toggle: when 1, blessed/puppeted enemies WILL aggro on the Idol/Deathcatcher
-- that bonded with them (the original funny bug). Default 0 (canon behavior).
-- Replicated so the Q-menu checkbox on the client can read the current value.
local cv_aggroBug = CreateConVar(
  "ukidol_aggro_bug_enabled", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "Enable the friendly-fire bug: blessed/puppeted enemies aggro on their Idol/Deathcatcher."
)

-- Toggle: when 1, every puppet spawned by a Deathcatcher is set hostile to all
-- players and NPCs (including other puppets and the spawning DC itself) — a
-- free-for-all rampage mode.
local cv_puppetFFA = CreateConVar(
  "ukpuppet_hostile_to_all_enabled", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "Make every Deathcatcher-spawned puppet hostile to all players and NPCs."
)


function UKIdol.IsPuppetFFAEnabled()
  return cv_puppetFFA:GetBool()
end

-- Toggle: when 1, the ULTRAKILL Arms whiplash may grab and reel in the Idol /
-- Deathcatcher statues (both count as Light for the base, so the hook yanks
-- the whole statue straight into the player's face). Default 0 (canon): the
-- statues are anchored fixtures and the hook passes through them.
local cv_whiplashPull = CreateConVar(
  "uksupport_whiplash_pull_enabled", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "Allow the whiplash to grab and pull the Idol/Deathcatcher statues."
)

function UKIdol.IsWhiplashPullEnabled()
  return cv_whiplashPull:GetBool()
end

function UKIdol.IsAggroBugEnabled()
  return cv_aggroBug:GetBool()
end


-- Any ULTRAKILL NPC — our ports (ultrakill_test_*), Kevin's enemies/bosses
-- (ultrakill_*, or their own FACTION_ULTRAKILL_* factions), UB nextbots.
-- Includes the Idol/DC support classes too — callers that need supports
-- handled differently check SUPPORT_CLASSES first.
function UKIdol.IsUltrakillNPC( ent )
  if not IsValid( ent ) then return false end
  if not ( ent:IsNPC() or ent:IsNextBot() ) then return false end
  if ent.IsUltrakillNextbot then return true end
  local cls = ent:GetClass()
  if cls:sub( 1, 10 ) == "ultrakill_" or cls:sub( 1, 14 ) == "ultrakillbase_" then
    return true
  end
  -- Kevin's standalone bosses sit in their own FACTION_ULTRAKILL_* factions
  -- (same acceptance rule as UKInfight.IsInfightNPC).
  for faction in pairs( ent._DrGBaseFactions or {} ) do
    if isstring( faction ) and faction:sub( 1, 17 ) == "FACTION_ULTRAKILL" then
      return true
    end
  end
  return false
end


-- Apply a per-entity relationship override. Handles both DrGBase nextbots
-- (custom :SetEntityRelationship API) AND engine HL2 NPCs (:AddEntityRelationship).
-- Priority controls target-selection order — higher = picked first.
local function applyRel( npc, ent, disp, priority )
  priority = priority or 999
  if npc.SetEntityRelationship then
    npc:SetEntityRelationship( ent, disp, priority )
  end
  if npc.AddEntityRelationship then
    npc:AddEntityRelationship( ent, disp, priority )
  end
end


-- Priority tier for outsider NPCs (not blessed/puppeted): every Deathcatcher
-- puppet is a top priority target. The DC/Idol support entity itself is:
--   - D_NU (neutral)             when FFA flag is OFF — canon behaviour, UK
--                                NPCs never aggro on the DC by themselves.
--   - D_HT priority LOW (10)     when FFA flag is ON  — DC becomes a target
--                                so the outsider NPCs can eventually kill it
--                                AFTER they've cleared the higher-priority
--                                puppets first.
local PRIO_PUPPET_TARGET  = 100
local PRIO_SUPPORT_TARGET = 10


-- Set npc → support entity relationship to LIKED (won't aggro / won't attack).
function UKIdol.SetupFriendlyToSupports( npc )
  if cv_aggroBug:GetBool() then return end           -- bug enabled → skip
  if not IsValid( npc ) then return end
  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) then continue end
    if SUPPORT_CLASSES[ ent:GetClass() ] then
      applyRel( npc, ent, D_LI )
      -- HL2 NPCs (combine_s etc) keep an EnemyMemory list independent of the
      -- relationship table — flushing it forces a fresh target search.
      if npc.ClearEnemyMemory  then pcall( npc.ClearEnemyMemory,  npc, ent ) end
      if npc.GetEnemy and npc:GetEnemy() == ent then
        if npc.SetEnemy then npc:SetEnemy( NULL ) end
      end
      -- Re-assert on a tick delay too — some frameworks (and engine NPCs after
      -- AddOutput/Spawn) reset relationships in PostSpawn; doing it again on
      -- the next tick survives that reset.
      timer.Simple( 0.1, function()
        if not IsValid( npc ) or not IsValid( ent ) then return end
        applyRel( npc, ent, D_LI )
        if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, ent ) end
        if npc.GetEnemy and npc:GetEnemy() == ent then
          if npc.SetEnemy then npc:SetEnemy( NULL ) end
        end
      end )
    end
  end
end


-- After un-bless / un-puppet, restore the canon default: NPCs view support
-- entities (DC/Idol) as NEUTRAL — not hostile. UK NPCs are never naturally
-- aggro toward DC even when they're not bonded.
function UKIdol.RestoreHostileToSupports( npc )
  if not IsValid( npc ) then return end
  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) then continue end
    if SUPPORT_CLASSES[ ent:GetClass() ] then
      applyRel( npc, ent, D_NU )
      if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, ent ) end
      if npc.GetEnemy and npc:GetEnemy() == ent then
        if npc.SetEnemy then npc:SetEnemy( NULL ) end
      end
    end
  end
end


-- VJ Base arbitration. VJ SNPCs pick enemies in MaintainRelationships, which
-- FORCE-writes D_HT@0 to any visible non-allied entity on every VJ think —
-- the engine relationship slots we set (D_LI/D_NU@999) get overwritten, and
-- the 0.2s enemy policing loses the rewrite war (playtest report: VJ Liberty
-- Prime revived as puppet kept attacking its Deathcatcher). VJ's own escape
-- hatch: if the PERCEIVED entity defines
--   ent:HandlePerceivedRelationship( viewer, dist, isFriendly )
-- its return value overrides VJ's whole decision for that pair (false = let
-- VJ decide naturally). We stamp this arbiter on supports, puppets and UK
-- NPCs; the function itself re-reads the convars so a stamped entity behaves
-- correctly when the checkboxes flip later.
local function UKVJArbiter( perceived, viewer, dist, isFriendly )
  if not ( IsValid( perceived ) and IsValid( viewer ) ) then return false end
  local ffaOn = cv_puppetFFA:GetBool()
  local viewerIsPuppet    = UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ viewer ] and true or false
  local perceivedIsPuppet = UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ perceived ] and true or false

  -- Supports (Idol/DC): nobody targets them — except FFA mode, and except a
  -- puppet viewer while the aggro-bug checkbox is on.
  if SUPPORT_CLASSES[ perceived:GetClass() ] then
    if ffaOn then return false end
    if viewerIsPuppet and cv_aggroBug:GetBool() then return false end
    return D_LI
  end

  -- VJ puppet looking at the world (FFA off): siblings are kin, UK NPCs are
  -- off-limits, everything else (players, outsider NPCs) is VJ's own business.
  if viewerIsPuppet and not ffaOn then
    if perceivedIsPuppet then return D_LI end
    if UKIdol.IsUltrakillNPC( perceived ) then return D_NU end
    return false
  end

  -- Living VJ outsider looking at a puppet (FFA off): canon — no induced
  -- aggression toward the Deathcatcher's constructs.
  if perceivedIsPuppet and not ffaOn then return D_NU end

  return false
end

-- Stamp the arbiter onto an entity. Never clobber a foreign handler — VJ NPC
-- authors use this field for their own logic.
function UKIdol.StampVJArbiter( ent )
  if not IsValid( ent ) then return end
  if ent.HandlePerceivedRelationship ~= nil
     and ent.HandlePerceivedRelationship ~= UKVJArbiter then return end
  ent.HandlePerceivedRelationship = UKVJArbiter
end


-- Puppet ↔ ULTRAKILL-NPC peace (playtest report 2026-07-10: a revived Liberty
-- Prime puppet attacked its own Deathcatcher). While the FFA checkbox is OFF a
-- puppet must not be hostile toward ANY ULTRAKILL NPC — not only the Idol/DC
-- supports. Per-entity D_NU@999 covers frameworks that respect relationships
-- (engine NPCs, DrGBase, ZBase); VJ SNPCs need the UKVJArbiter stamp above;
-- bases with fully custom target scans are handled by PoliceUKPuppetEnemy
-- below (0.2s enemy-slot reset from the puppet effects tick). Pairs the
-- infight system wants fighting (living vs puppet while
-- ultrakill_enemies_infight=1) are left alone — that slot is owned by
-- UKInfight (D_HT@900) and forcing D_NU@999 here would out-prioritize it.
function UKIdol.SetupPuppetPeaceWithUK( puppet )
  if not IsValid( puppet ) then return end
  if cv_puppetFFA:GetBool() then return end
  -- VJ viewers consult the PERCEIVED entity's handler — stamp the puppet (so
  -- VJ outsiders leave it alone) and, below, every UK NPC / sibling it must
  -- not target (so a VJ puppet leaves THEM alone).
  UKIdol.StampVJArbiter( puppet )
  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) or ent == puppet then continue end
    if SUPPORT_CLASSES[ ent:GetClass() ] then continue end    -- D_LI slot owned by SetupFriendlyToSupports (+aggro-bug logic)

    -- Sibling puppets: allied BOTH ways. FFA mode and the infight verdict
    -- already treat puppet↔puppet as kin, but plain canon mode relied on
    -- class defaults — a UB-based puppet (default-hostile to everything)
    -- happily gunned down a fellow puppet of another species.
    if UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ ent ] then
      UKIdol.StampVJArbiter( ent )
      applyRel( puppet, ent, D_LI, 999 )
      applyRel( ent, puppet, D_LI, 999 )
      if puppet.ClearEnemyMemory then pcall( puppet.ClearEnemyMemory, puppet, ent ) end
      if ent.ClearEnemyMemory then pcall( ent.ClearEnemyMemory, ent, puppet ) end
      if ent.GetEnemy and ent:GetEnemy() == puppet then
        if ent.SetEnemy then pcall( ent.SetEnemy, ent, NULL ) end
      end
      continue
    end

    if not UKIdol.IsUltrakillNPC( ent ) then continue end
    UKIdol.StampVJArbiter( ent )
    if UKInfight and UKInfight.ShouldFight and UKInfight.ShouldFight( puppet, ent ) then continue end
    applyRel( puppet, ent, D_NU, 999 )
    if puppet.ClearEnemyMemory then pcall( puppet.ClearEnemyMemory, puppet, ent ) end
    if puppet.GetEnemy and puppet:GetEnemy() == ent then
      if puppet.SetEnemy then pcall( puppet.SetEnemy, puppet, NULL ) end
    end
  end
end


-- Enemy-slot policing for puppets whose framework ignores relationship tables
-- (custom nextbots with their own target scans — the Liberty Prime case).
-- Called every 0.2s from the puppet effects tick while the puppet lives.
-- Rules: FFA on → no policing (hostility is the point). Support target →
-- reset unless the aggro-bug checkbox allows it. UK NPC target → reset unless
-- the infight system says this pair should fight.
function UKIdol.PoliceUKPuppetEnemy( puppet )
  if cv_puppetFFA:GetBool() then return end

  -- Relationship slot toward the OWN Deathcatcher: outside code (or a class
  -- default) can overwrite our D_LI with D_HT while the puppet is busy with
  -- another target — the moment that target is gone it would turn on its DC.
  -- Repair the slot every tick, not only when the DC is the current enemy.
  if not cv_aggroBug:GetBool() and UKPuppet and UKPuppet.GetState then
    local state = UKPuppet.GetState( puppet )
    local src = state and state.source
    if IsValid( src ) then
      local okD, disp = pcall( function()
        if puppet.GetRelationship then return puppet:GetRelationship( src ) end
        if puppet.Disposition then return puppet:Disposition( src ) end
      end )
      if okD and disp == D_HT then
        applyRel( puppet, src, D_LI, 999 )
        if puppet.ClearEnemyMemory then pcall( puppet.ClearEnemyMemory, puppet, src ) end
      end
    end
  end

  if not isfunction( puppet.GetEnemy ) then return end
  local ok, enemy = pcall( puppet.GetEnemy, puppet )
  if not ok or not IsValid( enemy ) then return end

  local isSupport = SUPPORT_CLASSES[ enemy:GetClass() ]
  local isSibling = not isSupport and UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ enemy ] and true or false
  if isSupport and cv_aggroBug:GetBool() then return end
  if not isSupport and not isSibling then
    if not UKIdol.IsUltrakillNPC( enemy ) then return end
    if UKInfight and UKInfight.ShouldFight and UKInfight.ShouldFight( puppet, enemy ) then return end
  end

  applyRel( puppet, enemy, ( isSupport or isSibling ) and D_LI or D_NU, 999 )
  if puppet.ClearEnemyMemory then pcall( puppet.ClearEnemyMemory, puppet, enemy ) end
  if puppet.SetEnemy then pcall( puppet.SetEnemy, puppet, NULL ) end
end


-- Rampage mode: puppet hates every player / NPC / nextbot EXCEPT the support
-- infrastructure that spawned them (Deathcatchers, Idols) AND other puppets
-- (their "siblings"). Those stay allies; everyone else is fair game.
function UKIdol.SetupHostileToAll( npc )
  if not IsValid( npc ) then return end

  local allyList = {}    -- collect for re-assert timer

  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) or ent == npc then continue end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

    local isSupport = SUPPORT_CLASSES[ ent:GetClass() ]
    local isPuppet  = UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ ent ]

    if isSupport or isPuppet then
      applyRel( npc, ent, D_LI )
      if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, ent ) end
      if npc.GetEnemy and npc:GetEnemy() == ent then
        if npc.SetEnemy then npc:SetEnemy( NULL ) end
      end
      table.insert( allyList, ent )
    else
      applyRel( npc, ent, D_HT )
    end
  end

  -- Re-assert ally relationships on the next tick. HL2 NPCs (combine_s) reset
  -- per-entity relationships in PostSpawn — without this, the D_LI we just set
  -- to the Deathcatcher gets wiped and combine resumes shooting at it.
  timer.Simple( 0.1, function()
    if not IsValid( npc ) then return end
    for _, ent in ipairs( allyList ) do
      if not IsValid( ent ) then continue end
      applyRel( npc, ent, D_LI )
      if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, ent ) end
      if npc.GetEnemy and npc:GetEnemy() == ent then
        if npc.SetEnemy then npc:SetEnemy( NULL ) end
      end
    end
  end )
end


-- When the convar flips, apply/undo the friendliness across all currently
-- blessed and puppeted NPCs immediately.
cvars.AddChangeCallback( "ukidol_aggro_bug_enabled", function( _, _, newVal )
  local bugOn = tobool( newVal )
  for blessed in pairs( UKIdol.Blessed or {} ) do
    if not IsValid( blessed ) then continue end
    if bugOn then
      UKIdol.RestoreHostileToSupports( blessed )    -- bug ON → make hostile
    else
      UKIdol.SetupFriendlyToSupports( blessed )     -- bug OFF → make friendly
    end
  end
  for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
    if not IsValid( puppet ) then continue end
    if bugOn then
      UKIdol.RestoreHostileToSupports( puppet )
    else
      UKIdol.SetupFriendlyToSupports( puppet )
    end
  end
end, "UKIdol_AggroBugLive" )


-- For an OUTSIDER NPC (not currently blessed and not currently puppeted):
--   FFA OFF (canon):
--     * Puppets and DC/Idol both D_NU — no induced aggression at all.
--   FFA ON (rampage):
--     * Puppets → D_HT priority HIGH (priority kill target)
--     * DC/Idol → D_HT priority LOW  (killable after puppets are cleared)
function UKIdol.SetupOutsiderPriorityTargets( npc )
  if not IsValid( npc ) then return end
  if UKIdol.Blessed and UKIdol.Blessed[ npc ] then return end
  if UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ npc ] then return end
  if not ( npc:IsNPC() or npc:IsNextBot() ) then return end

  local ffaOn = cv_puppetFFA:GetBool()

  -- Puppets
  for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
    if IsValid( puppet ) and puppet ~= npc then
      if ffaOn then
        applyRel( npc, puppet, D_HT, PRIO_PUPPET_TARGET )
      elseif UKInfight and UKInfight.ShouldFight( npc, puppet ) then
        -- Infight mode: living enemies hunt the Deathcatcher's revived
        -- puppets. Same disp/prio the infight system writes into this slot,
        -- so the two systems never overwrite each other back and forth.
        applyRel( npc, puppet, D_HT, UKInfight.PRIO )
      else
        applyRel( npc, puppet, D_NU, 999 )
        if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, puppet ) end
        if npc.GetEnemy and npc:GetEnemy() == puppet then
          if npc.SetEnemy then npc:SetEnemy( NULL ) end
        end
      end
    end
  end

  -- DC / Idol support entities
  for _, ent in ipairs( ents.GetAll() ) do
    if IsValid( ent ) and ent ~= npc and SUPPORT_CLASSES[ ent:GetClass() ] then
      if ffaOn then
        applyRel( npc, ent, D_HT, PRIO_SUPPORT_TARGET )
      else
        applyRel( npc, ent, D_NU, 999 )
        if npc.ClearEnemyMemory then pcall( npc.ClearEnemyMemory, npc, ent ) end
        if npc.GetEnemy and npc:GetEnemy() == ent then
          if npc.SetEnemy then npc:SetEnemy( NULL ) end
        end
      end
    end
  end
end


-- When a new support / puppet spawns, EVERY existing outsider NPC has to
-- reconsider its priority targets.
local function ReprioritizeAllOutsiders()
  for _, ent in ipairs( ents.GetAll() ) do
    if IsValid( ent ) and ( ent:IsNPC() or ent:IsNextBot() ) then
      UKIdol.SetupOutsiderPriorityTargets( ent )
    end
  end
end


-- When a new Idol / Deathcatcher spawns: (a) propagate friendliness to all
-- currently blessed/puppeted enemies, (b) re-prioritize all outsider NPCs so
-- they fold the new support entity into their target hierarchy.
hook.Add( "OnEntityCreated", "UKIdol_PropagateSupportFriendliness", function( ent )
  timer.Simple( 0.1, function()
    if not IsValid( ent ) then return end
    if not SUPPORT_CLASSES[ ent:GetClass() ] then return end
    UKIdol.StampVJArbiter( ent )    -- VJ NPCs consult the perceived entity's handler

    for blessed in pairs( UKIdol.Blessed or {} ) do
      if IsValid( blessed ) then applyRel( blessed, ent, D_LI ) end
    end
    if not cv_puppetFFA:GetBool() then
      for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
        if IsValid( puppet ) then applyRel( puppet, ent, D_LI ) end
      end
    end
    ReprioritizeAllOutsiders()
  end )
end )


-- When a new NPC/nextbot spawns: set its priority targets (puppets first, DC
-- second). Skip blessed/puppeted enemies — they have their own relationship
-- setup via Bind/Apply. Re-applied at 0 / 0.2 / 0.5s to survive the various
-- framework init paths (DrGBase _StartRelationships, UltrakillBase CustomInitialize,
-- etc.) that may overwrite per-entity relationships after Spawn().
hook.Add( "OnEntityCreated", "UKIdol_PrioritizeNewOutsider", function( ent )
  local function setup()
    if IsValid( ent ) then UKIdol.SetupOutsiderPriorityTargets( ent ) end
  end
  timer.Simple( 0,    setup )
  timer.Simple( 0.2,  setup )
  timer.Simple( 0.5,  setup )
end )


-- When a new ULTRAKILL NPC spawns while puppets exist (FFA off): every puppet
-- goes neutral toward it. Re-applied at 0.3/0.8s — DrGBase rebuilds its
-- relationship definers during init and would wipe an earlier write; anything
-- that still slips through is caught by the PoliceUKPuppetEnemy tick.
hook.Add( "OnEntityCreated", "UKPuppet_PeaceWithNewUKNPC", function( ent )
  local function setup()
    if not IsValid( ent ) then return end
    if SUPPORT_CLASSES[ ent:GetClass() ] then return end    -- handled by PropagateSupportFriendliness
    if not UKIdol.IsUltrakillNPC( ent ) then return end
    UKIdol.StampVJArbiter( ent )    -- before the FFA gate: the arbiter re-reads convars itself
    if cv_puppetFFA:GetBool() then return end
    for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
      if not IsValid( puppet ) or puppet == ent then continue end
      if UKInfight and UKInfight.ShouldFight and UKInfight.ShouldFight( puppet, ent ) then continue end
      applyRel( puppet, ent, D_NU, 999 )
    end
  end
  timer.Simple( 0.3, setup )
  timer.Simple( 0.8, setup )
end )


-- When a new NPC/player/nextbot spawns, every existing FFA-mode puppet picks
-- the right disposition: hostile to outsiders, but allied to DCs/Idols and
-- to other puppets.
hook.Add( "OnEntityCreated", "UKPuppet_PropagateFFAHostility", function( ent )
  if not cv_puppetFFA:GetBool() then return end
  timer.Simple( 0.1, function()
    if not IsValid( ent ) then return end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then return end

    local isSupport = SUPPORT_CLASSES[ ent:GetClass() ]
    local isPuppet  = UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ ent ]
    local disp      = ( isSupport or isPuppet ) and D_LI or D_HT

    for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
      if IsValid( puppet ) and puppet ~= ent then
        applyRel( puppet, ent, disp )
      end
    end
  end )
end )


-- Reset a puppet's per-entity relationship overrides back to D_NU for every
-- non-support, non-puppet entity. SetupHostileToAll explicitly D_HT-overrode
-- every NPC/player in the world while FFA was on — those overrides have to
-- be CLEARED when FFA turns off, otherwise the puppet keeps the FFA-mode
-- aggression to NPCs that its natural class disposition wouldn't target.
local function ResetPuppetOverridesToCanon( puppet )
  if not IsValid( puppet ) then return end
  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) or ent == puppet then continue end
    if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
    local isSupport = SUPPORT_CLASSES[ ent:GetClass() ]
    local isPuppet  = UKPuppet and UKPuppet.Targets and UKPuppet.Targets[ ent ]
    if isSupport then
      applyRel( puppet, ent, D_LI )    -- supports stay allies
    elseif isPuppet then
      applyRel( puppet, ent, D_LI )    -- sibling puppets stay allies
    elseif UKInfight and UKInfight.ShouldFight and UKInfight.ShouldFight( puppet, ent ) then
      -- Infight mode owns this pair (living vs puppet, D_HT@900) — writing
      -- D_NU@999 here would out-prioritize it and shield the puppet.
    else
      -- Clear the FFA D_HT override → restore canon class-based disposition
      applyRel( puppet, ent, D_NU )
    end
  end
end


-- Re-apply FFA across existing puppets AND every outsider NPC when the toggle
-- flips. Critical: on FFA-off we have to CLEAR the per-entity D_HT overrides
-- SetupHostileToAll added, otherwise puppets stay aggressive to non-natural
-- targets after the flag is gone.
cvars.AddChangeCallback( "ukpuppet_hostile_to_all_enabled", function( _, _, newVal )
  local ffaOn = tobool( newVal )
  for puppet in pairs( UKPuppet and UKPuppet.Targets or {} ) do
    if not IsValid( puppet ) then continue end
    if ffaOn then
      UKIdol.SetupHostileToAll( puppet )
    else
      ResetPuppetOverridesToCanon( puppet )
      UKIdol.SetupFriendlyToSupports( puppet )
      UKIdol.SetupPuppetPeaceWithUK( puppet )
    end
  end
  ReprioritizeAllOutsiders()
end, "UKPuppet_FFALive" )


function UKIdol.Bind( idol, target, manual )
  if not IsValid( idol ) or not IsValid( target ) then return end
  UKIdol.Unbind( idol )

  UKIdol.Blessed[ target ] = idol
  UKIdol.Bonds  [ idol ]   = target
  idol.UKIdol_ManualBond   = manual or false
  idol:SetNW2Entity( "UKIdol_Target", target )

  -- Make blessed enemy stop aggroing on Idols / Deathcatchers
  UKIdol.SetupFriendlyToSupports( target )

  -- Cleanup on either side's removal
  local cleanupKey = "UKIdol_Cleanup_" .. idol:EntIndex()
  target:CallOnRemove( cleanupKey, function()
    UKIdol.Blessed[ target ] = nil
    UKIdol.Bonds  [ idol   ] = nil
    if IsValid( idol ) then idol:SetNW2Entity( "UKIdol_Target", NULL ) end
  end )
  idol.UKIdol_CleanupKey = cleanupKey

  if UltrakillBase and UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_Idol_Bless", idol:GetPos() )
  end
end


function UKIdol.Unbind( idol )
  if not IsValid( idol ) then return end
  local target = UKIdol.Bonds[ idol ]
  UKIdol.Bonds[ idol ] = nil
  if IsValid( target ) then
    UKIdol.Blessed[ target ] = nil
    if idol.UKIdol_CleanupKey then
      target:RemoveCallOnRemove( idol.UKIdol_CleanupKey )
    end
    -- If this enemy is also currently puppeted, keep it friendly to supports;
    -- otherwise restore default hostile relationship.
    if not ( UKPuppet and UKPuppet.IsApplied and UKPuppet.IsApplied( target ) ) then
      UKIdol.RestoreHostileToSupports( target )
    end
  end
  idol:SetNW2Entity( "UKIdol_Target", NULL )
end


-- Default melee weapon class whitelist
for _, cls in ipairs({
  "weapon_crowbar", "weapon_stunstick", "weapon_fists",
  "weapon_ultrakill_feedbacker", "ultrakill_arm_feedbacker",
  "weapon_ultrakill_knuckleblaster", "ultrakill_arm_knuckleblaster",
  "weapon_ultrakill_impact_hammer", "weapon_uk_impact_hammer",
}) do
  UKIdol.MeleeWeaponClasses[ cls ] = true
end


-- STRICT WHITELIST classifier — only true melee passes through Idol/DC
-- self-defence. Previous negative-list fallback (attacker==inflictor==player
-- and "no NON_MELEE flag") leaked any custom SWEP that explicitly self-
-- inflicted with an unfamiliar type (DMG_DIRECT, DMG_CRUSH, DMG_SHOCK, etc.).
-- Diagnosis confirmed: DamageInfo() never auto-fills
-- inflictor from attacker — SetInflictor==attacker is always a script
-- intent, never a true bullet/explosion. So the new rules are positive-only.

-- Temy ULTRAKILL ARMS Knuckleblaster basic punch and Bootleg uknail/sawblade
-- both build DamageInfo with attacker == inflictor == player and use
-- DMG_GENERIC (or DMG_SLASH). They are indistinguishable from the DamageInfo
-- alone. The only reliable separator is the Lua call stack: Temy fires the
-- TakeDamageInfo from inside a net.Receive callback that lives in
-- lua/autorun/cl_vmanipfeedbacker.lua, while Bootleg projectiles deal damage
-- from their own ENT:Think / ENT:Touch in lua/entities/projectile_uk*.lua.
local function UKIdol_InTemyContext()
  for i = 2, 12 do
    local info = debug.getinfo( i, "S" )
    if not info then return false end
    local src = info.short_src or info.source or ""
    if src:find( "vmanipfeedbacker", 1, true )
       or src:find( "feedbackermenu",  1, true ) then
      return true
    end
  end
  return false
end
function UKIdol.IsMeleeAttack( attacker, dmg )
  local infl    = dmg:GetInflictor()
  local dmgType = dmg:GetDamageType()

  -- 1. Explicit custom-flag marker (addon-set escape hatch — highest priority)
  if dmg:GetDamageCustom() == UKIdol.DMG_CUSTOM_MELEE then return true end

  -- 2. Inflictor self-identifies as melee (weapon ENT with explicit flag)
  if IsValid( infl ) and ( infl.IsMeleeWeapon or infl.IsUKArm ) then
    return true
  end

  local attackerIsPlayer = IsValid( attacker ) and attacker:IsPlayer()
  local wep              = attackerIsPlayer and attacker:GetActiveWeapon() or nil
  local activeIsCanonArm = false

  -- 3. Player wielding a canon UK Arm / class-whitelisted SWEP / flagged SWEP
  if IsValid( wep ) then
    activeIsCanonArm =
      ( UKIdol.MeleeWeaponClasses and UKIdol.MeleeWeaponClasses[ wep:GetClass() ] )
      or wep.IsUKArm or false
    if activeIsCanonArm or wep.IsMelee then return true end
  end

  -- 4. DMG_CLUB always accepted — crowbar / stunstick / weapon_fists / canon melee
  if dmg:IsDamageType( DMG_CLUB ) then return true end

  -- 5. DMG_SLASH is INTENTIONALLY NOT accepted here. Bootleg ULTRAKILL Sweps
  -- sawblade sets attacker == inflictor == player AND DMG_SLASH (see
  -- projectile_uksawblade.lua lines 47-48, 100-101), so accepting on that
  -- pattern leaks. Real melee that wants DMG_SLASH must go through one of:
  --   * canon UK Arm in MeleeWeaponClasses whitelist (step 3),
  --   * inflictor flagged IsUKArm/IsMeleeWeapon (step 2),
  --   * explicit UKIdol.DMG_CUSTOM_MELEE flag (step 1).
  -- Parried Swordsmachine swords / NPC slash also use DMG_SLASH — those must
  -- stay blocked too.

  -- 6. DMG_ALWAYSGIB — Temy ULTRAKILL Arms Knuckleblaster shockwave marker
  if dmgType == DMG_ALWAYSGIB then return true end

  -- 7. DMG_CRUSH only when ULTRAKILL Ground Slam is active (or just landed)
  if dmgType == DMG_CRUSH and attackerIsPlayer then
    if type( _G.IsGroundSlamActive ) == "function"
         and _G.IsGroundSlamActive( attacker ) then
      return true
    end
    local lgs = attacker.LastGroundSlam
    if type( lgs ) == "number" and CurTime() - lgs <= 0.5 then
      return true
    end
  end

  -- 8. DMG_GENERIC (== 0) — Temy Knuckleblaster basic punch path.
  -- Bootleg uknail uses the same DamageInfo signature, so we either need:
  --   (a) no active SWEP (player meleeing bare-handed via concommand bind),
  --   (b) the active SWEP is a trusted canon UK Arm, OR
  --   (c) the damage is being applied INSIDE Temy's net.Receive callback
  --       (detected via Lua call-stack source path match).
  if dmgType == 0 and attackerIsPlayer
       and IsValid( infl ) and infl == attacker then
    if not IsValid( wep ) then return true end
    if activeIsCanonArm then return true end
    if UKIdol_InTemyContext() then return true end
  end

  return false
end


-- DMG_BURN intentionally NOT here: ULTRAKILL canon blessed enemies are immune
-- to all fire (hellbullet projectiles use DMG_BURN too — caught earlier via
-- fromUK, but env_fire / map fire / player fire weapons would otherwise slip
-- through). The remaining flags cover edge env-damage paths that should still
-- be able to clean up stuck blessed NPCs (drown trigger, dissolve, radiation).
local ENV_DMG = bit.bor(
  DMG_FALL, DMG_DROWN, DMG_NERVEGAS,
  DMG_RADIATION, DMG_DISSOLVE, DMG_PHYSGUN
)


function UKIdol.NearestHitbox( ent, pos )
  local limbs = UKIdol.GetLimbPositions( ent )
  if #limbs == 0 then return 0 end

  local bestIdx, bestDistSqr = 0, math.huge
  for _, lim in ipairs( limbs ) do
    local d = lim.pos:DistToSqr( pos )
    if d < bestDistSqr then bestIdx, bestDistSqr = lim.hbox, d end
  end
  return bestIdx
end


function UKIdol.IsWeakspotHitbox( ent, hbox )
  local list = UKIdol.WeakspotHitboxes[ ent:GetClass() ]
  if not list then return false end
  for _, idx in ipairs( list ) do
    if idx == hbox then return true end
  end
  return false
end


hook.Add( "EntityTakeDamage", "UKIdol_Bless", function( target, dmg )
  local idol = UKIdol.Blessed[ target ]
  if not IsValid( idol ) then return end

  local atk  = dmg:GetAttacker()
  local infl = dmg:GetInflictor()

  -- ULTRAKILL "hell" projectiles (Stray/Schism/Malicious Face/Drone/Soldier/
  -- Mindflayer hellbullets) all deal DMG_BURN — without this check they would
  -- slip through the ENV_DMG bypass below and damage blessed enemies. Treat
  -- any UK-sourced damage as combat regardless of damage type flags.
  local fromUK = ( IsValid( infl ) and ( infl.IsUltrakillProjectile or infl.IsUltrakillNextbot ) )
              or ( IsValid( atk  ) and ( atk.IsUltrakillProjectile  or atk.IsUltrakillNextbot  ) )

  if not fromUK and dmg:IsDamageType( ENV_DMG ) then return end
  if not IsValid( atk ) or atk:IsWorld() then return end

  -- Trigger CheckParry manually BEFORE zeroing damage. Without this, DrGBase's
  -- OnInjured short-circuits on dmg <= 0 and skips OnTakeDamage → CheckParry,
  -- so the parry effect (Ultrakill_Parry sound, hit-stop, style hook,
  -- SetParryable false) never fires on a blessed enemy mid-windup. The +5000
  -- damage OnParry adds is wiped by the dmg:SetDamage(0) below — the blessed
  -- enemy stays unkillable but the player still gets full parry feedback.
  if isfunction( target.CheckParry ) then
    pcall( target.CheckParry, target, dmg )
  end

  -- Zero HP loss but preserve physics impulse.
  -- For HL2-style NPCs the engine auto-applies damage force when we don't return true.
  -- For DrGBase nextbots there's no physics body, so we manually push them via SetVelocity.
  local force = dmg:GetDamageForce()
  if force:LengthSqr() > 0 then
    if target:IsNextBot() and target.SetVelocity then
      local cur = target:GetVelocity() or vector_origin
      target:SetVelocity( cur + force * 0.0015 )    -- scale down (force is in units * mass)
    else
      local phys = target:GetPhysicsObject()
      if IsValid( phys ) then phys:ApplyForceCenter( force ) end
    end
  end

  dmg:ScaleDamage( 0 )
  dmg:SetDamage( 0 )

  local hitPos = dmg:GetDamagePosition()
  if hitPos == vector_origin then hitPos = target:WorldSpaceCenter() end

  local hboxIdx = UKIdol.NearestHitbox( target, hitPos )

  -- Hit on any extremity (head/arm/leg/hand/foot) → big flash; torso → small.
  -- Per-class explicit weakspot table can still override (some bosses have non-head weakpoints).
  local isExtremity = UKIdol.IsExtremity( target, hboxIdx )
                   or UKIdol.IsWeakspotHitbox( target, hboxIdx )

  -- Spawn BlessingHit sprite at exact hit position (faithful to vanilla)
  local fx = EffectData()
  fx:SetOrigin( hitPos )
  fx:SetEntity( target )
  fx:SetScale( isExtremity and 3.0 or 1.0 )
  util.Effect( "ukidol_deflect", fx )

  net.Start( "UKIdol_HitFlash", true )
    net.WriteEntity( target )
    net.WriteUInt( hboxIdx, 8 )
    net.WriteBool( isExtremity )
  net.Broadcast()
  -- NOTE: no `return true` — let the damage chain proceed with damage=0 so physics
  -- impulse from explosions/bullets still launches the blessed entity.
end )


function UKIdol.SpawnReflect( idol, dmg )
  local hitPos = dmg:GetDamagePosition()
  if hitPos == vector_origin then hitPos = idol:WorldSpaceCenter() end

  local fx = EffectData()
  fx:SetOrigin( hitPos )
  fx:SetEntity( idol )
  util.Effect( "ukidol_deflect", fx )

  -- Reflect projectile-class inflictors
  local infl = dmg:GetInflictor()
  if IsValid( infl ) and infl ~= dmg:GetAttacker() and infl.IsUltrakillProjectile then
    local incomingVel = infl:GetVelocity()
    local mag = incomingVel:Length()
    if mag > 0 then
      local normal = ( hitPos - idol:WorldSpaceCenter() ):GetNormalized()
      local reflected = incomingVel - 2 * incomingVel:Dot( normal ) * normal
      infl:SetPos(infl:GetPos() + reflected)
      infl:SetVelocity( reflected * 0.85 )
      if infl.SetParried then infl:SetParried( true ) end
    end
  end

  if UltrakillBase and UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_Parry", hitPos )
  else
    sound.Play( "ultrakill/idol_hit.wav", hitPos, 70, 100, 1 )
  end
end


hook.Add( "EntityTakeDamage", "UKIdol_SelfDefense", function( target, dmg )
  if target:GetClass() ~= "ultrakill_test_idol" then return end
  if UKIdol.IsMeleeAttack( dmg:GetAttacker(), dmg ) then return end

  -- Fire damage: extinguish immediately and absorb silently. Without the
  -- Extinguish() the entity stays visually on fire and the engine keeps
  -- spawning DMG_BURN ticks every ~0.5s, which would each trigger a
  -- SpawnReflect cosmetic — visual spam. Treat fire as a non-event.
  if dmg:IsDamageType( DMG_BURN ) then
    if target.Extinguish then target:Extinguish() end
    dmg:SetDamage( 0 )
    return true
  end

  dmg:SetDamage( 0 )
  UKIdol.SpawnReflect( target, dmg )
  return true
end )


-- Idols are non-flammable: stub Ignite() so any code path (env_fire trigger,
-- hellbullet detonation, player fire weapon, console) that tries to set them
-- alight is a no-op. Belt-and-suspenders with the SelfDefense Extinguish above.
hook.Add( "OnEntityCreated", "UKIdol_NoIgnite", function( ent )
  timer.Simple( 0, function()
    if not IsValid( ent ) then return end
    if ent:GetClass() ~= "ultrakill_test_idol" then return end
    ent.Ignite = function() end
    if ent:IsOnFire() then ent:Extinguish() end
  end )
end )


-- Blessed ULTRAKILL NPCs are immune to fall damage — the bless effect
-- protects them from environmental death so the Idol's reflect filter
-- remains the only path to kill them.
hook.Add( "EntityTakeDamage", "UKIdol_BlessFallImmune", function( target, dmg )
  if not IsValid( target ) then return end
  if not UKIdol.Blessed[ target ] then return end
  if not dmg:IsDamageType( DMG_FALL ) then return end

  local cls = target:GetClass()
  if not ( string.StartWith( cls, "ultrakill_" )
           or string.StartWith( cls, "ultrakillbase_" ) ) then return end

  dmg:SetDamage( 0 )
  return true
end )
