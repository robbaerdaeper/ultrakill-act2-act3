-- lua/autorun/server/ultrakill_test_wander.lua
-- "Wander & seek" mode. ultrakillbase_nextbot hardwires ENT.Omniscient = true
-- and blanks ENT:OnIdle(), so every UK enemy always knows where everyone is
-- and never has an idle moment. With this mode on, eligible enemies drop to
-- DrGBase's honest senses — sight (LOS + the base's 90° FOV) and hearing
-- (gunshots become a PatrolSound they run to investigate) — and a restored
-- OnIdle strolls them to random navmesh spots with the stock 3-7s pause at
-- each (DrGBase Patrol flow). Losing sight of a victim sends them to its
-- last known position first, so they genuinely hunt around.
--
-- Needs a navmesh for the strolling, like all nextbot pathing. Omniscience
-- is a per-instance NW2Bool (SetOmniscient), so Kevin's base stays untouched.

if not SERVER then return end

local cv_wander = CreateConVar( "ultrakill_enemies_wander", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "ULTRAKILL enemies lose omniscience: they roam around and hunt by sight and sound." )

local cv_sight = CreateConVar( "ultrakill_enemies_wander_sightrange", "6000",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "Sight range (units) while wander mode is on. 0 = keep the class value (base default 15000)." )

-- Not everything should roam:
--   * supports are statues with their own systems (blessing/revive ranking)
--   * stationary bosses / boss parts would ground-path their anchored bodies
--   * anything with the base's Flying flag (ours AND Kevin's hover enemies)
--     drives its own movement — navmesh patrol would drag it along the floor
local SKIP_CLASSES = {
  ultrakill_test_idol         = true,
  ultrakill_test_deathcatcher = true,
  ultrakill_idol              = true,
  ultrakill_deathcatcher      = true,
  ultrakill_test_earthmover   = true,
  ultrakill_test_minos_corpse = true,
  ultrakill_test_minos_arm    = true,
}
local SKIP_PREFIXES = {
  "ultrakill_test_em_",       -- Earthmover defense-system parts
  "ultrakill_test_leviathan", -- head/tail/ring are anchored in the "water"
}

local function IsWanderNPC( ent )
  if not IsValid( ent ) or not ent.IsDrGNextbot then return false end
  local cls = ent:GetClass()
  if SKIP_CLASSES[ cls ] then return false end
  for _, prefix in ipairs( SKIP_PREFIXES ) do
    if cls:sub( 1, #prefix ) == prefix then return false end
  end
  if isfunction( ent.GetFlying ) and ent:GetFlying() then return false end
  if not isfunction( ent.IsInFaction ) then return false end
  -- any FACTION_ULTRAKILL* membership counts (Kevin's bosses sit in their
  -- own factions — same acceptance rule as the infight system)
  if ent:IsInFaction( "FACTION_ULTRAKILL_ENEMIES" ) then return true end
  for faction in pairs( ent._DrGBaseFactions or {} ) do
    if isstring( faction ) and faction:sub( 1, 17 ) == "FACTION_ULTRAKILL" then
      return true
    end
  end
  return false
end


-- ultrakillbase runs BehaviourType = AI_BEHAV_CUSTOM: Kevin's AIBehaviour()
-- replaces DrGBase's standard loop and has NO patrol branch, so AddPatrolPos
-- queues points nobody ever consumes (found the hard way — the bots stood
-- still with full patrol queues). His loop does call OnIdle() every behaviour
-- tick though, and OnIdle runs inside the behave coroutine — so we walk the
-- path ourselves (own FollowPath loop, GoTo has no early-out hooks). The
-- stroll aborts the moment an enemy appears (sight or sound — hearing a
-- player SpotEntity()s them directly). Wait() self-aborts on HasEnemy.
--
-- The navmesh is cut for player-sized hulls, so a big enemy happily picks a
-- point behind a doorway it can't squeeze through and grinds on the frame.
-- Track progress toward the goal: "stuck" from FollowPath or ~4s without
-- getting closer → drop the point and redraw, next one from a shorter radius
-- (random direction, so a blocked route isn't retried over and over).
local function WanderOnIdle( self )
  local pos
  if self._UKWander_ShortNext then
    self._UKWander_ShortNext = nil
    pos = self:RandomPos( 300, 1200 )
  else
    pos = self:RandomPos( 1500, 4000 )
  end
  if not isvector( pos ) then return end
  local deadline = CurTime() + 20
  local best = self:GetPos():Distance( pos )
  local progressAt = CurTime()
  while true do
    local res = self:FollowPath( pos, 50 )
    if res == "reached" or res == "unreachable" then break end
    if res == "stuck" then
      self._UKWander_ShortNext = true
      break
    end
    local dist = self:GetPos():Distance( pos )
    if dist < best - 16 then
      best = dist
      progressAt = CurTime()
    elseif CurTime() - progressAt > 4 then
      -- pushing against something it can't pass — pick another route
      self._UKWander_ShortNext = true
      break
    end
    if self:HasEnemy() or self:IsAIDisabled() or CurTime() > deadline then break end
    self:YieldCoroutine( true )
  end
  self:Wait( math.Rand( 1, 3 ) )
end

-- Kevin's AIBehaviour only leaves the HasEnemy branch when the enemy entity
-- turns INVALID — with omniscience that's how it should be, but for us a
-- hidden player is still a perfectly valid entity, so the NPC would x-ray
-- chase forever and never idle. DrGBase awareness already expires the spot
-- (SpotDuration) and fires OnLost — drop the enemy there so the loop falls
-- through to OnIdle and the hunt-around begins.
local function WanderOnLost( self, lost )
  if self:GetEnemy() == lost then self:SetEnemy( NULL ) end
end

local function SightRangeFor( ent )
  local range = cv_sight:GetInt()
  if range > 0 then return range end
  return ent._UKWander_Prev and ent._UKWander_Prev.sight or ent:GetSightRange()
end


local function Apply( ent )
  if ent._UKWander_Prev then return end
  ent._UKWander_Prev = {
    omni   = ent:GetNW2Bool( "DrGBaseOmniscient" ),
    sight  = ent:GetSightRange(),
    spot   = ent:GetSpotDuration(),
    onidle = ent.OnIdle,
    onlost = ent.OnLost,
  }
  ent:SetOmniscient( false )
  ent:SetSightRange( SightRangeFor( ent ) )
  -- stock 30s of perfect memory after LOS break means half a minute of
  -- standing around before any strolling — cut it so they give up and hunt
  ent:SetSpotDuration( 8 )
  ent.OnIdle = WanderOnIdle
  ent.OnLost = WanderOnLost
end

local function Restore( ent )
  local prev = ent._UKWander_Prev
  if not prev then return end
  ent._UKWander_Prev = nil
  ent:SetOmniscient( prev.omni )
  ent:SetSightRange( prev.sight )
  ent:SetSpotDuration( prev.spot )
  ent.OnIdle = prev.onidle
  ent.OnLost = prev.onlost
end


local function ApplyAll( on )
  for _, ent in ipairs( ents.GetAll() ) do
    if on and IsWanderNPC( ent ) then
      Apply( ent )
    elseif not on and ent._UKWander_Prev then
      Restore( ent )
    end
  end
end

cvars.AddChangeCallback( "ultrakill_enemies_wander", function( _, _, newVal )
  ApplyAll( tobool( newVal ) )
end, "UKWander_Live" )

cvars.AddChangeCallback( "ultrakill_enemies_wander_sightrange", function()
  if not cv_wander:GetBool() then return end
  for _, ent in ipairs( ents.GetAll() ) do
    if ent._UKWander_Prev then ent:SetSightRange( SightRangeFor( ent ) ) end
  end
end, "UKWander_Sight" )


-- Newly spawned enemies join ~0.5s later: DrGBase's Initialize re-stamps the
-- omniscience NW2Bool from the class (_InitAwareness), so anything applied
-- earlier gets wiped (the same PostSpawn-reset trap as the infight shim).
hook.Add( "OnEntityCreated", "UKWander_Spawn", function( ent )
  if not cv_wander:GetBool() then return end
  timer.Simple( 0.5, function()
    if not cv_wander:GetBool() then return end
    if IsWanderNPC( ent ) then Apply( ent ) end
  end )
end )


-- Unstick sweep. When the enemy entity is REMOVED (killed NPC, disconnect),
-- the DrGBaseEnemy NW2 proxy never fires, so _DrGBaseHadEnemy sticks true and
-- Kevin's loop spins in its UpdateEnemy branch forever — OnIdle would never
-- run again. Vanilla recovers because omniscient FetchEnemy always finds the
-- next target; our spotted-only FetchEnemy returns nil, so clear the flag by
-- hand and let the NPC go back to strolling.
timer.Create( "UKWander_Unstick", 1, 0, function()
  if not cv_wander:GetBool() then return end
  for _, ent in ipairs( ents.GetAll() ) do
    if ent._UKWander_Prev and ent:HadEnemy() and not IsValid( ent:GetEnemy() ) then
      ent:SetEnemy( NULL )
      ent._DrGBaseHadEnemy = false
    end
  end
end )
