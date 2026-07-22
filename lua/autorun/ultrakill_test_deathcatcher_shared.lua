-- ULTRAKILL Deathcatcher — shared namespace.
-- Static UB nextbot that catches enemy deaths in a 1500u radius and respawns
-- them as Puppeted (delegates to UKPuppet.Apply). HP=1 + melee-only reflect
-- filter mirrors Idol exactly — defence is the filter, not the HP pool.

UKDeathcatcher = UKDeathcatcher or {}

UKDeathcatcher.Active = UKDeathcatcher.Active or {}    -- [Deathcatcher] = true

UKDeathcatcher.Hooks = {
  SelfDefense = "UKDeathcatcher_SelfDefense",
  CatchDeath  = "UKDeathcatcher_CatchDeath",
  MapClean    = "UKDeathcatcher_MapClean",
}

UKDeathcatcher.NW2 = {
  State   = "UKDC_State",      -- 0=closed, 1=opening, 2=open
  ChargeT = "UKDC_ChargeT",    -- 0..1 — respawn countdown progress
}

UKDeathcatcher.STATE_CLOSED  = 0
UKDeathcatcher.STATE_OPENING = 1
UKDeathcatcher.STATE_OPEN    = 2

UKDeathcatcher.CATCH_RADIUS  = 1500

-- Canon Deathcatcher.cs uses two separate timers:
--   respawnDelay        — visible charge-phase duration (sphere shrinks to heart)
--   TimeUntilRespawn()  — gap between consecutive pulse cycles
--
-- Wiki Terminal Entry phrases everything as "Replication pulses occur every
-- X seconds" — that's the FULL pulse-to-pulse period. Split here as:
--   PULSE_INTERVAL_BY_DIFF[d] = total period
--   CHARGE_DURATION          = visible charge length (fixed)
--   gap = PULSE_INTERVAL - CHARGE_DURATION  (computed on the fly)
UKDeathcatcher.CHARGE_DURATION = 3   -- seconds — sphere visible while it shrinks

-- Pulse intervals (gap = PULSE_INTERVAL - CHARGE_DURATION (3s)). Tuned for
-- breathing room between puppet waves.
UKDeathcatcher.PULSE_INTERVAL_BY_DIFF = {
  [ 0 ] = 20,    -- HARMLESS
  [ 1 ] = 18,    -- LENIENT
  [ 2 ] = 15,    -- STANDARD
  [ 3 ] = 13,    -- VIOLENT (default)
  [ 4 ] = 9,     -- BRUTAL
  [ 5 ] = 9,     -- UMD
  [ 6 ] = 9,     -- HIDDEN MANSION
}

-- Back-compat shim: some old code paths read RESPAWN_DELAY directly.
UKDeathcatcher.RESPAWN_DELAY = UKDeathcatcher.CHARGE_DURATION

function UKDeathcatcher.GetPulseInterval()
  local diff = ( UltrakillBase and UltrakillBase.GetDifficulty
                 and UltrakillBase.GetDifficulty() ) or 3
  return UKDeathcatcher.PULSE_INTERVAL_BY_DIFF[ diff ] or 11
end

-- Skip-list: classes that must never be respawned-as-puppet.
-- Puppets are infrastructure; re-puppeting them would create an infinite
-- loop. Idol is also infrastructure (cross-NPC support entity).
UKDeathcatcher.SkipClasses = {
  -- Never respawn a Puppet (already a puppet, can't double-up).
  ultrakill_test_puppet       = true,
  -- Workshop variant (so respawn doesn't grab the wrong copy)
  ultrakill_puppet            = true,
  -- Engine debris
  prop_ragdoll                = true,
  -- SonaristicCatboy V Series (workshop 3708282959): collab design rule —
  -- the Deathcatcher must NEVER restore V2 in any variant (canon: V2's 4-4
  -- death is final). V1 is intentionally left catchable.
  ultrakill_v2                = true,
  ultrakill_v2_2              = true,   -- V2 (Greed)
  ultrakill_v2_ultrapain      = true,
  -- NOTE: Idol is intentionally NOT in this list — Deathcatcher CAN
  -- resurrect Idols (canon: 8-2 has Deathcatcher loops that include Idols).
}

-- Deathcatcher's own classes sit in a separate list: normally skipped
-- (reviving one spawns a fresh ACTIVE catcher — recursion), but the
-- "DC revives DCs" funny-bug convar lifts the skip on purpose.
UKDeathcatcher.DeathcatcherClasses = {
  ultrakill_test_deathcatcher = true,
  ultrakill_deathcatcher      = true,   -- workshop variant
}

function UKDeathcatcher.IsRevivableClass( cls )
  if UKDeathcatcher.DeathcatcherClasses[ cls ] then
    local cv = GetConVar( "ukdc_revive_deathcatchers_enabled" )
    return ( cv and cv:GetBool() ) or false
  end
  if UKDeathcatcher.SkipClasses[ cls ] then return false end
  -- Don't re-puppet anything that's currently in the UKPuppet registry —
  -- canon: puppets are non-replicable. (UKPuppet.IsApplied is server-side here.)
  return true
end

-- Find nearest active Deathcatcher to `pos`, or nil if none in range.
-- Canon assumes max one Deathcatcher per arena, but this is the safe choice
-- if two ever co-exist (ULTRAKILL never spawns two but mappers might).
-- `exclude` skips a specific catcher — a dying Deathcatcher is still in the
-- Active registry when its death snapshot is taken, and without the exclusion
-- it would always pin ITSELF (distance 0) as its own reviver.
function UKDeathcatcher.NearestActive( pos, exclude )
  local best, bestDistSqr = nil, math.huge
  for dc, _ in pairs( UKDeathcatcher.Active ) do
    if not IsValid( dc ) then UKDeathcatcher.Active[ dc ] = nil; continue end
    if dc == exclude then continue end
    local d = dc:GetPos():DistToSqr( pos )
    if d < bestDistSqr then best, bestDistSqr = dc, d end
  end
  if best and bestDistSqr <= UKDeathcatcher.CATCH_RADIUS * UKDeathcatcher.CATCH_RADIUS then
    return best
  end
  return nil
end
