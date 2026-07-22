local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
ENT.Base = "ultrakillbase_nextbot"

-- Misc --

ENT.PrintName = "Deathcatcher"
ENT.Author    = "ULTRAKILL port"
ENT.Category  = "ULTRAKILL - Enemies"
ENT.Spawnable = true
ENT.AdminOnly = false

-- Spawn-time model is the closed statue; the animation pipeline is:
--   t=0           closed.mdl (state CLOSED)
--   t=OPEN_DELAY  → animated.mdl bodygroup 0, cycle 0→28 over OPEN_DURATION
--   t=OPEN_DELAY+OPEN_DURATION → open.mdl (state OPEN)
-- Each SetModel is wrapped in a MOVETYPE_NONE pin so the nextbot's locomotor
-- cannot ground-snap to a nearby surface during the hull re-evaluation.
ENT.Models = { "models/ultrakill_deathcatcher/closed.mdl" }
ENT.Skins  = { 0 }

ENT.ModelScale       = 1.3
ENT.CollisionBounds  = Vector( 16, 16, 50 )
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)
ENT.SurroundingBounds = Vector( 80, 80, 100 )
ENT.RagdollOnDeath   = false

-- Stats — same as Idol: HP=1 means ANY melee one-shots. The defence is the
-- reflect filter (server/ultrakill_test_deathcatcher_logic.lua), not the HP pool.
ENT.SpawnHealth = 1

-- AI / locomotion: stationary --

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange  = 99999
ENT.Acceleration     = 0
ENT.Deceleration     = 9999
ENT.WalkSpeed        = 0
ENT.RunSpeed         = 0
ENT.JumpHeight       = 0
ENT.MaxYawRate       = 60     -- soft drift (degrees per second) — same yaw model as Idol
ENT.UseWalkframes    = false

-- Animations --

ENT.WalkAnimation = "Idle"
ENT.RunAnimation  = "Idle"
ENT.IdleAnimation = "Idle"
ENT.JumpAnimation = "Idle"

ENT.EyeBone = "root"

-- Face-tracking: exponential convergence rate (1/sec). Higher = snappier
-- tracking, lower = sluggish drift. 7 gives a "bulky alive" feel — quick
-- enough to follow a moving player but with a soft stop on landing.
ENT.DeathcatcherFaceRate = 7

-- Per-phase yaw offsets. Each model was baked through a different pipeline
-- (Blender for closed/open, Python for animated frames) so their modeling-
-- space "front" doesn't align. We track the player in every state and add
-- the appropriate offset so the front of the active mesh actually faces
-- the target.
ENT.DeathcatcherFaceYawOffset_Closed   = -90
ENT.DeathcatcherFaceYawOffset_Opening  = -90
ENT.DeathcatcherFaceYawOffset_Open     = -90

-- Yaw direction multiplier per phase. closed.mdl was baked through Blender's
-- glb importer which applies a different handedness conversion than my Python
-- bake — its yaw rotates in the opposite sense (model turns AWAY from player
-- with positive offsets). Set -1 to invert the rotation direction.
ENT.DeathcatcherFaceYawSign_Closed   = 1
ENT.DeathcatcherFaceYawSign_Opening  = 1
ENT.DeathcatcherFaceYawSign_Open     = 1

-- Heart anchor in render-angle local space (fwd, right, up). Calibrated
-- in-game with the heart-offset debug tool. Use via:
--   local ang = self:GetRenderAngles()
--   local pos = self:GetPos() + ang:Forward()*ENT.HeartOffset.x
--                             + ang:Right()  *ENT.HeartOffset.y
--                             + ang:Up()     *ENT.HeartOffset.z
ENT.HeartOffset = Vector( 16, -17, 105 )

ENT.UKIdol_IsIdolStatue = true    -- marker for the shared physgun anchor hooks (idol.lua)


-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    -- statue reads ~120u tall (HeartOffset z=105) — humanoid preset
    -- (0/11.5/34.5, distance 115) scaled up; PossessorView multiplies both
    -- offset and distance by ModelScale (1.3) on top of these numbers
    offset = Vector( 0, 14, 60 ),
    distance = 170,
    eyepos = false

  },

  {

    offset = Vector( 12, 0, 62 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  -- The Deathcatcher has no attacks — its only active ability is the
  -- resurrection pulse. IN_ATTACK requests one; SlowUpdate consumes the flag
  -- on its next 0.2s tick through the same charge → FireRespawn cycle the AI
  -- uses (needs dead puppets queued). Both cooldown gates mirror the AI loop,
  -- so a held key yields at most one pulse per pulse interval.
  [ IN_ATTACK ] = { { coroutine = false, onkeydown = function( self )

    if ( self.UKDC_Countdown or 0 ) > 0 then return end
    if ( self.UKDC_NextPulseTime or 0 ) > CurTime() then return end
    self.UKDC_PossessionPulse = true

  end } },

}


if SERVER then


local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )

local OPEN_DELAY    = 1.0    -- how long the closed statue is shown before opening starts
local OPEN_DURATION = 1.6    -- opening animation playback length


-- uk_whiplash's grab trace skips any entity whose GetRidingEntity() is valid
-- (Providence r7 trick). The Deathcatcher is an anchored statue — the hook
-- passes through unless the Funny Bugs toggle explicitly allows the pull.
function ENT:GetRidingEntity()
  if UKIdol and UKIdol.IsWhiplashPullEnabled and UKIdol.IsWhiplashPullEnabled() then return end
  return self
end


function ENT:OnSpawn()

  BaseClass.OnSpawn( self )

  -- SetTurning(true) keeps client-side angle interpolation enabled; the open
  -- Deathcatcher's face-tracking writes via SetRenderAngles client-side
  -- (mirroring the Idol pattern), and the network smooths yaw drift.
  self:SetTurning( true )
  self:SetGravity( 1 )

  -- Anchor: Deathcatcher is immovable.
  local phys = self:GetPhysicsObject()
  if IsValid( phys ) then
    phys:EnableMotion( false )
    phys:SetMass( 50000 )
  end

  -- State init: closed, no charge yet
  self:SetNW2Int( UKDeathcatcher.NW2.State, UKDeathcatcher.STATE_CLOSED )
  self:SetNW2Float( UKDeathcatcher.NW2.ChargeT, 0 )

  self.UKDC_DeadList  = {}    -- list of { class, pos, ang, puppet }
  self.UKDC_Countdown = 0     -- seconds until next respawn fire

  -- Spawn-time anchor — used to pin Z across SetModel swaps (closed → animated
  -- → open). Without this pin the engine can shift the entity vertically when
  -- collision hulls differ between models, causing the catcher's root to lift
  -- out of the floor mid-opening.
  self.UKDC_AnchorPos = self:GetPos()

  -- Three-phase opening sequence:
  --   t=0           closed.mdl shown (state CLOSED)
  --   t=OPEN_DELAY  swap to animated.mdl, fire FX + sound, cycle bodygroup 0→28
  --   t=OPEN_DELAY+OPEN_DURATION  swap to open.mdl (state OPEN, registry active)
  local FRAME_COUNT = 29
  local FRAME_INTERVAL = OPEN_DURATION / ( FRAME_COUNT - 1 )

  -- Internal helper: swap model without the engine ground-correcting the
  -- entity. SetModel resets collision bounds to the model's bbox (which for
  -- the catcher extends ~43 units below origin since the mesh hangs down
  -- from $origin). On thin floors with a cavity beneath, the engine then
  -- treats the entity as "embedded" and lifts it upward to make the new
  -- hull rest on the floor surface. Re-applying the nextbot's authored
  -- bounds (mins.z = 0) after the swap keeps the hull above the floor so
  -- no correction happens. MOVETYPE_NONE around the call freezes any
  -- locomotor adjustment that might fire on the same tick.
  local cb = self.CollisionBounds
  local CB_MINS = Vector( -cb.x, -cb.y, 0 )
  local CB_MAXS = Vector(  cb.x,  cb.y, cb.z )

  local function pinnedSetModel( ent, path )
    local prevMove = ent:GetMoveType()
    ent:SetMoveType( MOVETYPE_NONE )
    ent:SetModel( path )
    ent:SetCollisionBounds( CB_MINS, CB_MAXS )
    ent:SetPos( ent.UKDC_AnchorPos )
    ent:SetMoveType( prevMove )
    ent:SetCollisionBounds( CB_MINS, CB_MAXS )
    ent:SetPos( ent.UKDC_AnchorPos )
  end

  -- Phase 1 → Phase 2: swap closed→animated, kick off opening FX and bodygroup cycle.
  timer.Simple( OPEN_DELAY, function()
    if not IsValid( self ) then return end
    pinnedSetModel( self, "models/ultrakill_deathcatcher/animated.mdl" )
    self:SetBodygroup( 0, 0 )
    self:SetNW2Int( UKDeathcatcher.NW2.State, UKDeathcatcher.STATE_OPENING )

    local fx = EffectData()
    fx:SetOrigin( self:WorldSpaceCenter() )
    fx:SetEntity( self )
    fx:SetMagnitude( self:OBBMaxs():Length() )
    util.Effect( "ukdeathcatcher_open", fx, true, true )
  end )

  -- Bodygroup cycle 1→28 (frame 0 was set in phase 1). Each tick fires after
  -- OPEN_DELAY + (fi * FRAME_INTERVAL) so the cycle stays in sync with phase 1.
  for fi = 1, FRAME_COUNT - 1 do
    timer.Simple( OPEN_DELAY + fi * FRAME_INTERVAL, function()
      if not IsValid( self ) then return end
      if self:GetModel() ~= "models/ultrakill_deathcatcher/animated.mdl" then return end
      self:SetBodygroup( 0, fi )
    end )
  end

  -- Phase 2 → Phase 3: swap animated→open canonical static mesh, register active.
  -- Canon Deathcatcher.cs Opened() fires its "complete" cue at this moment
  -- (end of opening animation), so the heart is exposed and the catcher is
  -- ready to absorb deaths.
  timer.Simple( OPEN_DELAY + OPEN_DURATION, function()
    if not IsValid( self ) then return end
    pinnedSetModel( self, "models/ultrakill_deathcatcher/open.mdl" )
    self:SetNW2Int( UKDeathcatcher.NW2.State, UKDeathcatcher.STATE_OPEN )
    UKDeathcatcher.Active[ self ] = true
    sound.Play( "ultrakill_deathcatcher/complete.ogg", self:WorldSpaceCenter(), 100, 100, 1 )
  end )

  -- Slow tick — process queue, advance countdown, refresh puppet positions
  self.SlowTimerID = "UKDeathcatcher_Slow_" .. self:EntIndex()
  timer.Create( self.SlowTimerID, 0.2, 0, function()
    if not IsValid( self ) then return end
    self:SlowUpdate()
  end )

end


function ENT:OnRemove()

  if self.SlowTimerID then timer.Remove( self.SlowTimerID ) end
  UKDeathcatcher.Active[ self ] = nil
  self.UKDC_HeartbeatActive = false   -- stops the queued timer tick chain

  -- Silent puppet cleanup for non-death removals (admin cleanup / map clean / manual
  -- npc_remove). The death path in OnDeath already explosively kills its puppets;
  -- this is the safety net for everything else. Cleanse first so OnKilled stub
  -- is restored before remove (no FX, no gibs).
  if self.UKDC_DeadList then
    for _, rec in ipairs( self.UKDC_DeadList ) do
      if IsValid( rec.puppet ) then
        if UKPuppet and UKPuppet.Cleanse then UKPuppet.Cleanse( rec.puppet ) end
        SafeRemoveEntity( rec.puppet )
      end
    end
  end

end


-- Anchor enforcement, idol pattern (round 2, 2026-07-10): base blast
-- knockback writes loco velocity directly and dragged the statue around.
-- UKDC_AnchorPos doubles as the SetModel-swap pin, so it stays authoritative
-- here; while airborne (spawned in the air) the anchor follows until landing.
function ENT:CustomThink()

  if CLIENT then return end

  if self._UKIdolHeld then
    local h = self._UKIdolHolder
    if not IsValid( h ) or not IsValid( h:GetActiveWeapon() )
      or h:GetActiveWeapon():GetClass() ~= "weapon_physgun" then
      self._UKIdolHeld = false
    end
    self.UKDC_AnchorPos = self:GetPos()
    return
  end

  local pos = self:GetPos()
  local anchor = self.UKDC_AnchorPos
  if not anchor then
    self.UKDC_AnchorPos = pos
    return
  end

  if self.loco and not self.loco:IsOnGround() and self.loco:GetVelocity().z < -10 then
    -- falling after an air spawn: follow until we land
    self.UKDC_AnchorPos = pos
    return
  end

  local distSqr = pos:DistToSqr( anchor )
  if distSqr == 0 then return end
  -- teleports (tools) come without loco velocity; blast shoves don't
  local vel = self.loco and self.loco:GetVelocity() or vector_origin
  if distSqr > 300 * 300 and vel:LengthSqr() < 25 then
    self.UKDC_AnchorPos = pos
    return
  end

  self:SetPos( anchor )
  if self.loco then self.loco:SetVelocity( vector_origin ) end

end


-- Bypass UltrakillBase ×40/×20 scaling — Deathcatcher takes raw weapon damage
-- (the reflect filter zeroes out non-melee anyway).
function ENT:GetDamageMultiplierConVar( attacker )
  return 1
end


function ENT:SlowUpdate()

  if not UKDeathcatcher.Active[ self ] then return end

  -- Refresh puppet position trackers + detect dead-puppets that need respawn.
  -- Canonical behaviour: while puppet is alive we record its current pos so
  -- the respawn appears wherever the puppet last fell, not the original site.
  local hasDeadPuppets = false
  for _, rec in ipairs( self.UKDC_DeadList ) do
    if IsValid( rec.puppet ) and ( rec.puppet.Health and rec.puppet:Health() or 0 ) > 0 then
      rec.pos = rec.puppet:GetPos()
      rec.ang = rec.puppet:GetAngles()
    else
      rec.puppet = nil
      hasDeadPuppets = true
    end
  end

  if not hasDeadPuppets then
    self.UKDC_Countdown = 0
    self:SetNW2Float( UKDeathcatcher.NW2.ChargeT, 0 )
    self:UKDC_StopHeartbeat()
    self.UKDC_PossessionPulse = nil    -- drop stale pulse requests (nothing to revive)
    return
  end

  -- Canon: only the `ai_disabled` cheat freezes the resurrection loop.
  -- Player visibility / LOS is NOT a gate — Deathcatcher keeps respawning
  -- even if everyone left the arena.
  local cvAi = GetConVar( "ai_disabled" )
  if cvAi and cvAi:GetInt() ~= 0 then return end

  if self.UKDC_Countdown <= 0 then
    -- Charge phase not active. Honour the cooldown set by the previous
    -- FireRespawn (canon TimeUntilRespawn behaviour): the next pulse can
    -- only begin once the full pulse-interval has elapsed since the last
    -- pulse start. Bail until then so the catcher actually rests.
    if ( self.UKDC_NextPulseTime or 0 ) > CurTime() then return end

    -- While possessed, starting a pulse is the possessor's deliberate call
    -- (IN_ATTACK bind sets the request flag). A charge that is already
    -- running keeps counting down through FireRespawn below regardless.
    if self:IsPossessed() and not self.UKDC_PossessionPulse then return end
    self.UKDC_PossessionPulse = nil

    -- Start the visible charge phase. Always lasts CHARGE_DURATION; the
    -- pulse-to-pulse interval (which depends on difficulty) is scheduled
    -- below at FireRespawn.
    self.UKDC_CurrentDelay   = UKDeathcatcher.CHARGE_DURATION
    self.UKDC_PulseStartTime = CurTime()
    self.UKDC_Countdown      = self.UKDC_CurrentDelay
    self:UKDC_StartHeartbeat()
  end

  self.UKDC_Countdown = math.max( 0, self.UKDC_Countdown - 0.2 )

  local delay = self.UKDC_CurrentDelay or UKDeathcatcher.CHARGE_DURATION
  local progress = 1 - ( self.UKDC_Countdown / delay )
  self:SetNW2Float( UKDeathcatcher.NW2.ChargeT, progress )

  if self.UKDC_Countdown <= 0 then
    self:FireRespawn()
    self:UKDC_StopHeartbeat()
    -- Schedule the next allowed pulse start relative to THIS pulse's start —
    -- canon "Replication pulses occur every X seconds" means full period from
    -- one pulse-start to the next. Charge (already played) + remaining gap.
    self.UKDC_NextPulseTime = ( self.UKDC_PulseStartTime or CurTime() )
                            + UKDeathcatcher.GetPulseInterval()
  end

end


-- Canonical Deathcatcher.cs Update logic for the heartbeat audio:
--   ratio  = countdownToRespawn / respawnDelay   (1.0 → 0.0 across charge)
--   pitch  = (1 - ratio) * 2 + 1                  (1× → 3×)
--   volume = 1 - ratio * 0.66                     (0.34 → 1.0)
-- We can't loop heartbeat.ogg directly via sound.Play (no built-in loop point),
-- so we chain timer.Simple calls — each tick spawns a one-shot at the current
-- pitch/volume, and schedules the next tick at an interval that shortens with
-- pitch (heart beats faster as the charge progresses).
local HEARTBEAT_BASE_INTERVAL = 0.85   -- seconds between thumps at pitch 1×
local HEARTBEAT_MAX_PITCH     = 255    -- engine clamp on sound pitch

function ENT:UKDC_StartHeartbeat()
  self.UKDC_HeartbeatActive = true
  self:UKDC_PlayHeartbeatTick()
end

function ENT:UKDC_PlayHeartbeatTick()
  if not self.UKDC_HeartbeatActive then return end
  if not IsValid( self ) then return end

  local cd = self.UKDC_Countdown or 0
  if cd <= 0 then self.UKDC_HeartbeatActive = false; return end

  local delay = self.UKDC_CurrentDelay or UKDeathcatcher.RESPAWN_DELAY
  local ratio = cd / delay
  local progress = 1 - ratio                              -- 0..1 over charge
  local pitch = math.min( 100 + progress * 155, HEARTBEAT_MAX_PITCH )
  local vol   = 0.34 + progress * 0.66

  sound.Play( "ultrakill_deathcatcher/heartbeat.ogg",
              self:WorldSpaceCenter(), 95, pitch, vol )

  -- Next interval shortens as pitch goes up (faster heartbeat).
  local interval = HEARTBEAT_BASE_INTERVAL / ( pitch / 100 )
  timer.Simple( interval, function()
    if IsValid( self ) then self:UKDC_PlayHeartbeatTick() end
  end )
end

function ENT:UKDC_StopHeartbeat()
  self.UKDC_HeartbeatActive = false
end


-- Save a death record. Called from logic.lua's deferred lethal-hit detector
-- with a pre-death snapshot (class/pos/ang/weapon captured before the puppet
-- OnKilled stub potentially removes the entity).
function ENT:CatchDeath( cls, pos, ang, weapon )

  if not UKDeathcatcher.Active[ self ] then return end
  if not UKDeathcatcher.IsRevivableClass( cls ) then return end

  table.insert( self.UKDC_DeadList, {
    class  = cls,
    pos    = pos,
    ang    = ang,
    weapon = weapon,    -- weapon classname or nil (nextbots have none)
    puppet = nil,
  } )

end


-- Find a non-clipping spawn position near `desired`. Snaps to ground via
-- downward trace, then probes the desired spot + a ring of offsets with a
-- hull trace until one is clear of other entities. Falls back to the original
-- position if everything around is occupied (better cramped than no respawn).
local DEFAULT_HULL_MINS = Vector( -16, -16, 0 )
local DEFAULT_HULL_MAXS = Vector(  16,  16, 72 )

local function FindClearSpawnPos( desired, ignoreEnt )
  -- Snap to ground (max 96u up, 200u down — covers stairs / platforms)
  local tr = util.TraceLine( {
    start  = desired + Vector( 0, 0, 96 ),
    endpos = desired - Vector( 0, 0, 200 ),
    mask   = MASK_SOLID_BRUSHONLY,
    filter = ignoreEnt,
  } )
  local ground = tr.Hit and tr.HitPos or desired

  -- Candidate offsets: center first, then 8-spoke ring at r=40, 80
  local candidates = { Vector( 0, 0, 0 ) }
  for _, r in ipairs( { 40, 80 } ) do
    for i = 0, 7 do
      local a = ( i / 8 ) * math.pi * 2
      table.insert( candidates, Vector( math.cos( a ) * r, math.sin( a ) * r, 0 ) )
    end
  end

  for _, off in ipairs( candidates ) do
    local p = ground + off + Vector( 0, 0, 4 )    -- nudge up 4u to avoid floor seam
    local hull = util.TraceHull( {
      start  = p,
      endpos = p,
      mins   = DEFAULT_HULL_MINS,
      maxs   = DEFAULT_HULL_MAXS,
      mask   = MASK_NPCSOLID,
      filter = ignoreEnt,
    } )
    if not hull.Hit then return p end
  end

  return ground + Vector( 0, 0, 4 )
end


-- UKPuppet.Apply rejects targets with HP<=0 (IsValidTarget), and some NPC bases
-- deliver health AFTER Spawn() returns (timer-deferred init). Retry the status
-- application for ~2s so such NPCs don't come back as plain un-puppeted copies.
local function ApplyPuppetRetry( catcher, ent, attempt )
  if not IsValid( catcher ) or not IsValid( ent ) then return end
  if not ( UKPuppet and UKPuppet.Apply ) then return end
  if UKPuppet.Apply( ent, catcher, { fxLevel = "spawn" } ) then return end
  attempt = ( attempt or 0 ) + 1
  if attempt >= 10 then return end
  timer.Simple( 0.2, function() ApplyPuppetRetry( catcher, ent, attempt ) end )
end


function ENT:FireRespawn()

  -- Resurrection cue — same sample as the opening "complete" hit. Played once
  -- per pulse from the catcher's center, regardless of how many puppets are
  -- about to respawn, so multi-resurrects don't stack the sample on itself.
  sound.Play( "ultrakill_deathcatcher/complete.ogg", self:WorldSpaceCenter(), 100, 100, 1 )

  for i, rec in ipairs( self.UKDC_DeadList ) do
    if not IsValid( rec.puppet ) then
      timer.Simple( ( i - 1 ) * 0.1, function()
        if not IsValid( self ) then return end

        local new = ents.Create( rec.class )
        if not IsValid( new ) then return end

        local clearPos = FindClearSpawnPos( rec.pos, self )
        new:SetPos( clearPos )
        new:SetAngles( rec.ang )

        -- Source NPCs need weapon assigned BEFORE Spawn() (engine sets up
        -- ai_relationship / equipment slots during Spawn). For nextbots
        -- weapon is nil so this is a no-op.
        local weapon = rec.weapon
        if weapon and new.SetKeyValue then
          new:SetKeyValue( "additionalequipment", weapon )
        end

        new:Spawn()
        if new.Activate then new:Activate() end

        -- Fallback equip post-Spawn for NPCs that didn't pick up via keyvalue
        if weapon and new:IsNPC() and new.GetActiveWeapon then
          local cur = new:GetActiveWeapon()
          if not IsValid( cur ) and new.Give then new:Give( weapon ) end
        end

        -- Make the freshly-spawned puppet treat us as ally — otherwise source
        -- NPCs (no faction concept) attack the Deathcatcher on sight, and even
        -- UB/DrGBase nextbots can mistarget across framework boundaries. We
        -- call both APIs so whichever one the puppet's framework respects wins.
        if new.AddEntityRelationship then
          new:AddEntityRelationship( self, D_LI, 99 )
        end
        if new.SetRelationship then
          pcall( new.SetRelationship, new, self, "ally" )
        end

        ApplyPuppetRetry( self, new )

        rec.puppet = new
      end )
    end
  end

end


function ENT:OnDeath( dmg, hitGroup )

  UKDeathcatcher.Active[ self ] = nil

  local atk = dmg and dmg:GetAttacker() or nil
  if IsValid( atk ) and atk:IsPlayer() then
    -- +90 HP heal for the killer
    atk:SetHealth( math.min( atk:GetMaxHealth(), atk:Health() + 90 ) )

    -- +HEARTBREAK style (UltrakillBase exposes UKStyle when its style HUD is loaded;
    -- guard each call so we don't crash when the addon is missing it).
    if _G.UKStyle and _G.UKStyle.AddPoints then
      _G.UKStyle.AddPoints( atk, 80, "+HEARTBREAK" )
    end

  end

  -- Shockwave knockback — every alive player within blast radius gets launched
  -- away from the Deathcatcher's center (like Idol's death). Falloff so distant
  -- players get a nudge, close ones get yeeted.
  local epicenter = self:WorldSpaceCenter()
  local BLAST_RADIUS = 600
  for _, ply in ipairs( player.GetAll() ) do
    if not ply:Alive() then continue end
    local diff = ply:WorldSpaceCenter() - epicenter
    local dist = diff:Length()
    if dist > BLAST_RADIUS then continue end
    local dir = dist > 1 and ( diff / dist ) or Vector( 0, 0, 1 )
    local falloff = 1 - ( dist / BLAST_RADIUS )
    local launch = dir * 1500 * falloff + Vector( 0, 0, 500 * falloff )
    ply:SetVelocity( launch )
  end

  -- killPuppetsOnDeath: instant-kill every tracked puppet so they explode in blood.
  -- We TakeDamage with the puppet's OnKilled stub still installed — that fires
  -- UKPuppet._FireDeathFX + SafeRemoveEntity inside the stub, giving each puppet
  -- the canonical "pop in red" rather than silent removal.
  if self.UKDC_DeadList then
    for _, rec in ipairs( self.UKDC_DeadList ) do
      if IsValid( rec.puppet ) then
        local hp = rec.puppet.Health and rec.puppet:Health() or 0
        if hp > 0 then
          rec.puppet:TakeDamage( hp + 9999, atk or self, self )
        else
          if UKPuppet and UKPuppet._FireDeathFX then UKPuppet._FireDeathFX( rec.puppet ) end
          SafeRemoveEntity( rec.puppet )
        end
      end
    end
  end

  -- Death FX — ULTRAKILL blood spray (CreateBlood trails+splatter) plus the
  -- Deathcatcher-specific transparent shockwave (soft_explosion sans virtue gibs).
  local epc = self:WorldSpaceCenter()
  if UltrakillBase and UltrakillBase.CreateBlood then
    UltrakillBase.CreateBlood( epc, 48 )
    for i = 1, 4 do
      UltrakillBase.CreateBlood( epc + VectorRand() * math.Rand( 12, 40 ), 48 )
    end
  end

  local fx = EffectData()
  fx:SetOrigin( epc )
  fx:SetAngles( self:GetAngles() )
  fx:SetRadius( 200 )
  util.Effect( "ultrakill_test_softexplosion", fx )

  if UltrakillBase and UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
  end

  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

end


end    -- if SERVER


if CLIENT then


-- NOTE: do NOT define ENT:Initialize / ENT:OnRemove on client — both would
-- override the DrGBase base initializer (which sets _DrGBaseBaseThinkDelay,
-- _DrGBaseSequenceEvents and other fields the engine reads each tick).


-- Per-frame face tracking on the LOCAL client. Mirrors UKIdol_UpdateClientYaw —
-- bypasses network angle interpolation by using SetRenderAngles, which only
-- affects rendering. Server's actual ENT.Angles stays at default and never
-- desyncs through network jitter. Only runs when STATE_OPEN; closed statue
-- and opening transition keep their spawn rotation.
local STATE_OFFSET_KEY = {
  [ UKDeathcatcher.STATE_CLOSED  ] = "DeathcatcherFaceYawOffset_Closed",
  [ UKDeathcatcher.STATE_OPENING ] = "DeathcatcherFaceYawOffset_Opening",
  [ UKDeathcatcher.STATE_OPEN    ] = "DeathcatcherFaceYawOffset_Open",
}

local STATE_SIGN_KEY = {
  [ UKDeathcatcher.STATE_CLOSED  ] = "DeathcatcherFaceYawSign_Closed",
  [ UKDeathcatcher.STATE_OPENING ] = "DeathcatcherFaceYawSign_Opening",
  [ UKDeathcatcher.STATE_OPEN    ] = "DeathcatcherFaceYawSign_Open",
}


function ENT:UKDeathcatcher_UpdateClientYaw()
  local now = RealTime()
  local dt  = now - ( self.UKDC_LastFaceFrame or now )
  self.UKDC_LastFaceFrame = now
  if dt <= 0 then return end

  local targetYaw

  -- Possessed: the possessor owns facing — follow their aim yaw. Without this
  -- branch the tracker would chase the possessor's own hidden player entity.
  local possessor = self:GetPossessor()
  if IsValid( possessor ) then
    targetYaw = possessor:EyeAngles().yaw
  else
    -- Track the closest alive player (matches Idol's "closest player" pick)
    local myCenter = self:WorldSpaceCenter()
    local best, bestDistSqr = nil, math.huge
    for _, ply in ipairs( player.GetAll() ) do
      if not ply:Alive() then continue end
      local d = ply:EyePos():DistToSqr( myCenter )
      if d < bestDistSqr then best, bestDistSqr = ply, d end
    end
    if not IsValid( best ) then return end
    targetYaw = ( best:EyePos() - myCenter ):Angle().yaw
  end

  -- First frame: snap straight to target yaw so the model spawns already
  -- facing the player. Without this, default visualYaw=0 + offset=-90
  -- renders the model showing its side until tracking catches up.
  if self.UKDC_VisualYaw == nil then
    self.UKDC_VisualYaw = targetYaw
  end

  local curYaw = self.UKDC_VisualYaw
  local delta  = math.AngleDifference( targetYaw, curYaw )

  -- Exponential lerp (ease-out): step proportional to remaining delta, so the
  -- catcher rotates fast when far from target and decelerates smoothly as it
  -- closes in. `DeathcatcherFaceRate` controls convergence speed (~7-8 ≈
  -- bulkier-feeling tracking; lower is sluggish, higher is snappier).
  local rate = self.DeathcatcherFaceRate or 7
  local f = 1 - math.exp( -rate * dt )

  self.UKDC_VisualYaw = math.NormalizeAngle( curYaw + delta * f )

  -- Per-state offset and sign since each phase's mesh has its own forward
  -- axis (offset) and handedness (sign — closed.mdl rotates opposite way).
  local state = self:GetNW2Int( UKDeathcatcher.NW2.State, 0 )
  local offset = self[ STATE_OFFSET_KEY[ state ] or "DeathcatcherFaceYawOffset_Open" ] or 0
  local sign   = self[ STATE_SIGN_KEY[ state ]   or "DeathcatcherFaceYawSign_Open"   ] or 1

  self:SetRenderAngles( Angle( 0, sign * self.UKDC_VisualYaw + offset, 0 ) )
end


-- Heart-FX materials (loaded once)
local matStreak  = Material( "trails/laser" )
local matSparkle = Material( "sprites/light_glow02_add" )
local matSpike   = Material( "trails/laser" )
-- Known-good additive glow material (same used by soft_explosion flash).
local matGlow = Material( "effects/yellowflare" )
-- Charge sphere uses two passes to match the canon look (no alpha gaps):
--   Pass 1: solid mid-red base (SetColorMaterial), always visible.
--   Pass 2: dark-red smoke detail translucently layered on top — where the
--           texture is bright/opaque, a dark spot is painted onto the base.
--           Translucent instead of additive so the spots read DARKER than
--           the base instead of brighter.
local matChargeSphereDetail = CreateMaterial( "UKDC_ChargeSphereDetail_v3", "UnlitGeneric", {
  [ "$basetexture" ] = "particles/ULTRAKILL/smoke",
  [ "$additive"    ] = "1",
  [ "$vertexcolor" ] = "1",
  [ "$vertexalpha" ] = "1",
  [ "$nocull"      ] = "1",
} )


-- Per-element constants. Tuned to read as "small swirling vortex of red into
-- the heart with sun-ray spikes outside" — adjust here for taste.
local HFX_INNER_RADIUS    = 15
local HFX_STREAK_COUNT    = 54
local HFX_SPARKLE_COUNT   = 42
local HFX_SPIKE_COUNT     = 108
local HFX_SPIKE_LENGTH    = 36
local HFX_INNER_ANGSPEED  = -1.6   -- rad/s, negative = CCW
local HFX_OUTER_ANGSPEED  =  0.9   -- rad/s, positive = CW
local HFX_SPIKE_LIFE      = 1.1    -- seconds for grow→hold→fade
local HFX_SPIKE_GROW_END  = 0.4    -- phase at which spike reaches full length
local HFX_SPIKE_HOLD_END  = 0.65   -- phase at which fade starts


function ENT:Draw()
  self:UKDeathcatcher_UpdateClientYaw()
  self:DrawModel()

  -- Heart world position via render-angle local offset (face-tracking aware).
  -- Computed up-front because both the long-range beacon and the open-state
  -- heart FX anchor to it. GetRenderAngles() returns nil until the first
  -- SetRenderAngles call — UpdateClientYaw bails early on the first frame
  -- (dt<=0) and when no alive player is present, so fall back to entity angles.
  local rang = self:GetRenderAngles() or self:GetAngles()
  local rfwd, rright, rup = rang:Forward(), rang:Right(), rang:Up()
  local ho = self.HeartOffset
  local heartPos = self:GetPos() + rfwd * ho.x + rright * ho.y + rup * ho.z

  -- Canon ULTRAKILL behaviour: Deathcatchers emit a vertical dark-red beacon
  -- of light visible from a distance, helping players spot active resurrection
  -- anchors across an arena. Fades in over a distance band so it doesn't
  -- distract when the catcher is close. Anchored at the catcher's bounding
  -- box centre (not the heart) so the column sits centred on the body.
  local lp = LocalPlayer()
  if IsValid( lp ) then
    local beaconAnchor = self:WorldSpaceCenter()
    local distSqr = lp:EyePos():DistToSqr( beaconAnchor )
    local FAR_START = 400 * 400
    local FAR_FULL  = 1200 * 1200
    if distSqr > FAR_START then
      local k = math.Clamp( ( distSqr - FAR_START ) / ( FAR_FULL - FAR_START ), 0, 1 )
      local a = k * 220
      render.SetMaterial( matStreak )
      render.StartBeam( 4 )
        render.AddBeam( beaconAnchor,                      700, 0,    Color( 180, 0, 0, a       ) )
        render.AddBeam( beaconAnchor + Vector( 0, 0, 220 ), 600, 0.3,  Color( 160, 0, 0, a * 0.8 ) )
        render.AddBeam( beaconAnchor + Vector( 0, 0, 560 ), 440, 0.65, Color( 140, 0, 0, a * 0.5 ) )
        render.AddBeam( beaconAnchor + Vector( 0, 0, 950 ), 240, 1,    Color( 120, 0, 0, 0       ) )
      render.EndBeam()
    end
  end

  local state = self:GetNW2Int( UKDeathcatcher.NW2.State, 0 )
  if state ~= UKDeathcatcher.STATE_OPEN then return end

  -- Disc plane: camera-facing billboard. Right/Up vectors lie in the plane
  -- perpendicular to the camera-look direction, so the swirl reads as flat
  -- regardless of viewing angle.
  local toCam = EyePos() - heartPos
  if toCam:LengthSqr() < 1 then return end
  toCam:Normalize()
  local discAng = toCam:Angle()
  local discRight = discAng:Right()
  local discUp    = discAng:Up()

  local t = CurTime()
  local TWO_PI = math.pi * 2

  -- 1. Layered hot core. Outer soft red falloff → pink mid → white-hot tight
  -- core. Reads as a saturated "burning" point inside the chest cavity. Slight
  -- pulse on the core sells the heart-beat without needing a bodygroup cycle.
  -- Soft glow disc — single triangle-fan billboard contained within the
  -- streak radius. Centre vertex is bright/opaque, rim vertices are fully
  -- transparent, so the glow fades smoothly to nothing exactly where the
  -- streaks emerge. No pulse — steady warm pink-white core.
  local GLOW_SEGMENTS = 36
  render.SetColorMaterial()
  mesh.Begin( MATERIAL_TRIANGLES, GLOW_SEGMENTS )
  for i = 0, GLOW_SEGMENTS - 1 do
    local a1 = ( i       / GLOW_SEGMENTS ) * TWO_PI
    local a2 = ( ( i + 1 ) / GLOW_SEGMENTS ) * TWO_PI

    mesh.Position( heartPos )
    mesh.Color( 255, 40, 40, 255 )                                -- centre: bright red aura (canon)
    mesh.AdvanceVertex()

    mesh.Position( heartPos + discRight * math.cos( a1 ) * HFX_INNER_RADIUS
                            + discUp    * math.sin( a1 ) * HFX_INNER_RADIUS )
    mesh.Color( 255, 40, 40, 0 )                                  -- rim: fully fade
    mesh.AdvanceVertex()

    mesh.Position( heartPos + discRight * math.cos( a2 ) * HFX_INNER_RADIUS
                            + discUp    * math.sin( a2 ) * HFX_INNER_RADIUS )
    mesh.Color( 255, 40, 40, 0 )
    mesh.AdvanceVertex()
  end
  mesh.End()

  -- 1b. Resurrection-charge sphere — canon Deathcatcher.cs Update logic:
  --   scale   = R_MAX * (1 - charge)    (big → 0 as charge fills)
  --   opacity = charge                   (invisible → opaque, fades IN)
  -- Translucent UV sphere with the ULTRAKILL smoke texture mapped on the
  -- surface gives a dark red organic orb (swirling noise pattern internally),
  -- closer to the canon shader look than a flat additive shell.
  -- Client-side smoothing: server only ticks ChargeT every 0.2 s (SlowUpdate),
  -- so the raw value jumps in 5 fps steps. Exponential lerp lets the visual
  -- ramp glide between updates instead of stuttering.
  local serverCharge = self:GetNW2Float( UKDeathcatcher.NW2.ChargeT, 0 )
  local now = RealTime()
  local dtCharge = now - ( self.UKDC_LastChargeFrame or now )
  self.UKDC_LastChargeFrame = now

  -- Detect the resurrection moment: charge was high, server snapped it back to
  -- zero (cycle complete, puppet spawned). Latch a brief flash on the next
  -- frames so the sphere "pops" instead of just vanishing.
  local prevServer = self.UKDC_PrevServerCharge or 0
  if prevServer > 0.5 and serverCharge <= 0.05 then
    self.UKDC_FlashTime = CurTime()
  end
  self.UKDC_PrevServerCharge = serverCharge

  -- Snap when transitioning to/from zero so we don't bleed a leftover value
  -- across cycles.
  if serverCharge <= 0 or ( self.UKDC_DisplayCharge or 0 ) <= 0 and serverCharge > 0 then
    self.UKDC_DisplayCharge = serverCharge
  else
    local rate = 6    -- lower = smoother (more easing between server ticks)
    local f = 1 - math.exp( -rate * dtCharge )
    self.UKDC_DisplayCharge = ( self.UKDC_DisplayCharge or 0 )
                            + ( serverCharge - ( self.UKDC_DisplayCharge or 0 ) ) * f
  end
  local charge = self.UKDC_DisplayCharge
  if charge > 0 and charge < 1 then
    local R_MAX  = HFX_INNER_RADIUS * 24
    local sphereR = R_MAX * ( 1 - charge )
    local alpha = math.floor( math.min( charge * 350, 255 ) )

    if sphereR > 0.5 and alpha > 1 then
      local LAT = 24
      local LON = 42
      -- Smoke texture detail flows upward across the sphere; UV tile = 1 so
      -- the pattern reads as one large flowing organic mass (matching canon
      -- screenshot) rather than many tiny tiled blobs.
      local UV_TILE = 4
      local scrollV = ( t * 0.15 ) % 1.0

      -- Precompute vertex grid once and reuse across both passes — saves
      -- re-running all the trig per draw.
      local verts = {}
      for j = 0, LAT do
        local v = j / LAT
        local phi = v * math.pi
        local sinV, cosV = math.sin( phi ), math.cos( phi )
        verts[ j ] = {}
        for i = 0, LON do
          local u = i / LON
          local theta = u * TWO_PI
          verts[ j ][ i ] = {
            pos = heartPos + Vector( sinV * math.cos( theta ), sinV * math.sin( theta ), cosV ) * sphereR,
            u   = u * UV_TILE,
            v   = ( v + scrollV ) * UV_TILE,
          }
        end
      end

      -- Pass 1: solid dark-red base shell (no texture). Alpha scales with
      -- charge so the whole sphere fades in smoothly.
      local baseA = math.floor( math.min( charge * 130, 130 ) )
      render.SetColorMaterial()
      mesh.Begin( MATERIAL_TRIANGLES, LAT * LON * 2 )
      for j = 0, LAT - 1 do
        for i = 0, LON - 1 do
          local p00 = verts[ j     ][ i     ].pos
          local p01 = verts[ j + 1 ][ i     ].pos
          local p10 = verts[ j     ][ i + 1 ].pos
          local p11 = verts[ j + 1 ][ i + 1 ].pos

          mesh.Position( p00 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()
          mesh.Position( p10 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()
          mesh.Position( p01 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()

          mesh.Position( p01 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()
          mesh.Position( p10 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()
          mesh.Position( p11 ); mesh.Color( 170, 90, 90, baseA ); mesh.AdvanceVertex()
        end
      end
      mesh.End()

      -- Pass 2: additive smoke detail overlay. Brightens the base where the
      -- texture is bright, never punches holes (additive can't subtract).
      local detailA = math.floor( math.min( charge * 130, 130 ) )
      render.SetMaterial( matChargeSphereDetail )
      mesh.Begin( MATERIAL_TRIANGLES, LAT * LON * 2 )
      for j = 0, LAT - 1 do
        for i = 0, LON - 1 do
          local a = verts[ j     ][ i     ]
          local b = verts[ j + 1 ][ i     ]
          local c = verts[ j     ][ i + 1 ]
          local d = verts[ j + 1 ][ i + 1 ]

          mesh.Position( a.pos ); mesh.TexCoord( 0, a.u, a.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()
          mesh.Position( c.pos ); mesh.TexCoord( 0, c.u, c.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()
          mesh.Position( b.pos ); mesh.TexCoord( 0, b.u, b.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()

          mesh.Position( b.pos ); mesh.TexCoord( 0, b.u, b.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()
          mesh.Position( c.pos ); mesh.TexCoord( 0, c.u, c.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()
          mesh.Position( d.pos ); mesh.TexCoord( 0, d.u, d.v ); mesh.Color( 180, 60, 50, detailA ); mesh.AdvanceVertex()
        end
      end
      mesh.End()
    end
  end

  -- 1c. Spawn flash — short bright additive sphere that pops when the
  -- resurrection fires (server-side ChargeT snaps high→0). Quick grow + fade
  -- over ~0.3 s sells the "burst of life" beat.
  if self.UKDC_FlashTime then
    local FLASH_DUR = 0.3
    local age = CurTime() - self.UKDC_FlashTime
    if age >= FLASH_DUR then
      self.UKDC_FlashTime = nil
    else
      local k = age / FLASH_DUR
      local flashR = HFX_INNER_RADIUS * ( 6 + 24 * k )    -- 90 → 450
      local flashA = math.floor( ( 1 - k ) * 220 )

      if flashA > 1 then
        local FLAT = 10
        local FLON = 18
        -- Same smoke-noise material as the main charge sphere, but with a
        -- warmer bright tint for the burst moment.
        local flashScrollU = ( t * 0.05 ) % 1.0
        local flashScrollV = ( t * 0.03 ) % 1.0
        render.SetMaterial( matChargeSphereDetail )
        mesh.Begin( MATERIAL_TRIANGLES, FLAT * FLON * 2 )
        for j = 0, FLAT - 1 do
          local v0 = j       / FLAT
          local v1 = ( j + 1 ) / FLAT
          local phi0 = v0 * math.pi
          local phi1 = v1 * math.pi
          local sinV0, cosV0 = math.sin( phi0 ), math.cos( phi0 )
          local sinV1, cosV1 = math.sin( phi1 ), math.cos( phi1 )
          for i = 0, FLON - 1 do
            local u0 = i       / FLON
            local u1 = ( i + 1 ) / FLON
            local theta0 = u0 * TWO_PI
            local theta1 = u1 * TWO_PI
            local cU0, sU0 = math.cos( theta0 ), math.sin( theta0 )
            local cU1, sU1 = math.cos( theta1 ), math.sin( theta1 )

            local p00 = heartPos + Vector( sinV0 * cU0, sinV0 * sU0, cosV0 ) * flashR
            local p01 = heartPos + Vector( sinV1 * cU0, sinV1 * sU0, cosV1 ) * flashR
            local p10 = heartPos + Vector( sinV0 * cU1, sinV0 * sU1, cosV0 ) * flashR
            local p11 = heartPos + Vector( sinV1 * cU1, sinV1 * sU1, cosV1 ) * flashR

            local t_u0, t_u1 = u0 + flashScrollU, u1 + flashScrollU
            local t_v0, t_v1 = v0 + flashScrollV, v1 + flashScrollV

            mesh.Position( p00 ); mesh.TexCoord( 0, t_u0, t_v0 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()
            mesh.Position( p10 ); mesh.TexCoord( 0, t_u1, t_v0 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()
            mesh.Position( p01 ); mesh.TexCoord( 0, t_u0, t_v1 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()

            mesh.Position( p01 ); mesh.TexCoord( 0, t_u0, t_v1 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()
            mesh.Position( p10 ); mesh.TexCoord( 0, t_u1, t_v0 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()
            mesh.Position( p11 ); mesh.TexCoord( 0, t_u1, t_v1 ); mesh.Color( 255, 100, 80, flashA ); mesh.AdvanceVertex()
          end
        end
        mesh.End()
      end
    end
  end

  -- 2. CCW inward streaks — short tangent-offset beams from ring towards heart.
  render.SetMaterial( matStreak )
  for i = 1, HFX_STREAK_COUNT do
    local a = ( i / HFX_STREAK_COUNT ) * TWO_PI + t * HFX_INNER_ANGSPEED
    local outerP = heartPos + discRight * math.cos( a ) * HFX_INNER_RADIUS
                            + discUp    * math.sin( a ) * HFX_INNER_RADIUS
    -- Spiral inward: rotate angle a bit + collapse radius
    local b = a + 0.5
    local innerP = heartPos + discRight * math.cos( b ) * HFX_INNER_RADIUS * 0.15
                            + discUp    * math.sin( b ) * HFX_INNER_RADIUS * 0.15
    render.DrawBeam( outerP, innerP, 1.5, 0, 1, Color( 255, 25, 25, 200 ) )
  end

  -- 3. CCW inward 4-pointed star sparkles — each sparkle is two crossed beams
  -- (horizontal + vertical in disc plane). Each sparkle has its own angular
  -- speed multiplier so they drift relative to one another instead of all
  -- rotating in lockstep.
  render.SetMaterial( matSparkle )
  local SPARK_LEN = 3
  local SPARK_THIN = 1.6
  for i = 1, HFX_SPARKLE_COUNT do
    local seed = i * 0.7913
    -- Phase rates also varied so sparkles don't pulse synchronously
    local phase = ( ( t * ( 0.9 + ( ( i * 17 ) % 11 ) * 0.04 ) + seed ) % 1.0 )
    local angSpeed = HFX_INNER_ANGSPEED * ( 0.6 + ( ( i * 13 ) % 9 ) * 0.12 )
    local a = seed * 9.0 + t * angSpeed
    local rDist = HFX_INNER_RADIUS * ( 1 - phase )
    local sparkPos = heartPos + discRight * math.cos( a ) * rDist
                              + discUp    * math.sin( a ) * rDist
    -- Snap fade only at birth/death edges so most of the journey the sparkle
    -- is full alpha + fully saturated red. Quick in/out keeps the spawn pop.
    local alpha
    if phase < 0.08 then alpha = ( phase / 0.08 ) * 255
    elseif phase > 0.92 then alpha = ( ( 1 - phase ) / 0.08 ) * 255
    else alpha = 255 end
    local col = Color( 255, 0, 0, alpha )
    render.DrawBeam( sparkPos - discRight * SPARK_LEN, sparkPos + discRight * SPARK_LEN, SPARK_THIN, 0, 1, col )
    render.DrawBeam( sparkPos - discUp    * SPARK_LEN, sparkPos + discUp    * SPARK_LEN, SPARK_THIN, 0, 1, col )
  end

  -- 4. CW outward spikes — sun-ray beams from rim, staggered lifecycle.
  -- Each spike picks a colour tier (white inner short / pink mid / salmon
  -- long-outer) based on its index so the whole ring reads as a layered
  -- multi-shell starburst rather than monochrome red lines.
  local SPIKE_TIERS = {
    { len = 13, col = Color( 255, 110, 110, 255 ), width = 5.5 },    -- bright red short
    { len = 19, col = Color( 255,  60,  60, 240 ), width = 6.5 },    -- red medium
    { len = 26, col = Color( 220,  30,  30, 220 ), width = 7.5 },    -- deep red long
  }
  render.SetMaterial( matSpike )
  for i = 1, HFX_SPIKE_COUNT do
    local a = ( i / HFX_SPIKE_COUNT ) * TWO_PI + t * HFX_OUTER_ANGSPEED
    local phaseOff = ( i / HFX_SPIKE_COUNT ) * HFX_SPIKE_LIFE
    local phase    = ( ( t + phaseOff ) % HFX_SPIKE_LIFE ) / HFX_SPIKE_LIFE  -- 0..1

    local lengthMul, fadeAlpha
    if phase < HFX_SPIKE_GROW_END then
      local k = phase / HFX_SPIKE_GROW_END
      lengthMul, fadeAlpha = k, k
    elseif phase < HFX_SPIKE_HOLD_END then
      lengthMul, fadeAlpha = 1, 1
    else
      local k = ( phase - HFX_SPIKE_HOLD_END ) / ( 1 - HFX_SPIKE_HOLD_END )
      lengthMul, fadeAlpha = 1, ( 1 - k )
    end

    local tier = SPIKE_TIERS[ ( ( i - 1 ) % #SPIKE_TIERS ) + 1 ]
    local col  = Color( tier.col.r, tier.col.g, tier.col.b, tier.col.a * fadeAlpha )

    local cosA, sinA = math.cos( a ), math.sin( a )
    local fromP = heartPos + discRight * cosA * HFX_INNER_RADIUS
                           + discUp    * sinA * HFX_INNER_RADIUS
    local toP   = heartPos + discRight * cosA * ( HFX_INNER_RADIUS + tier.len * lengthMul )
                           + discUp    * sinA * ( HFX_INNER_RADIUS + tier.len * lengthMul )
    render.DrawBeam( fromP, toP, tier.width, 0, 1, col )
  end
end


end    -- if CLIENT


-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (doubled impact sounds/blood on every hit).
if SERVER then
  -- (shotgun pellets are blocked engine-side by the shared EntityTakeDamage
  -- hook "UKIdol_PelletBounce" in ultrakill_test_idol.lua — the marker field
  -- UKIdol_IsIdolStatue routes this statue through it too)
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    baseclass.Get( "ultrakillbase_nextbot" ).OnTakeDamage( self, dmg, hitgroup )
  end
end

AddCSLuaFile()
DrGBase.AddNextbot( ENT )
