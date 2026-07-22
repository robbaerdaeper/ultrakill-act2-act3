-- ULTRAKILL Puppet — server-side effect layer.
-- Damage scaling (×2 received), per-framework speed dispatcher, universal death cleanup,
-- GC hooks, periodic safety sweep.

if not UKPuppet then return end

local SLOW = 0.75
local TICK = 0.2
local SWEEP = 5

-- Recent death sites — used to kill ragdolls spawned by frameworks
-- (DrGBase calls BecomeRagdoll inside its own OnKilled callback, which runs
-- *after* our EntityTakeDamage hook removes the entity, so the engine-level
-- Remove can't suppress those ragdolls).
local RecentDeaths = {}
local DEATH_RAG_RADIUS_SQR = 220 * 220
local DEATH_RAG_TTL        = 0.6

-- Death FX: blood explosion at the target's center. Marks the entity so we
-- never fire it twice (Tick + EntityRemoved + OnKilled-stub can all fire for
-- the same death). Exposed as UKPuppet._FireDeathFX so the OnKilled stub
-- installed in shared.lua _ApplyInternal can reach it.
function UKPuppet._FireDeathFX( target )
  if not IsValid( target ) then return end
  if target.UKPuppet_DeathFXFired then return end
  target.UKPuppet_DeathFXFired = true

  local pos = target:WorldSpaceCenter()
  local fx  = EffectData()
  fx:SetOrigin( pos )
  fx:SetMagnitude( target:OBBMaxs():Length() * 1.5 )
  util.Effect( "ukpuppet_death", fx, true, true )
  sound.Play( "physics/flesh/flesh_bloody_break.wav", pos, 90, 100 )

  -- Big UK blood burst on death — puppets are made of blood, so dying pops the
  -- whole reservoir. Scaled by body size; client-side CreateBlood caps at 256.
  if UltrakillBase and UltrakillBase.CreateBlood then
    UltrakillBase.CreateBlood( pos, math.Clamp( target:OBBMaxs():Length() * 2.5, 100, 220 ) )
  end

  -- Per-class extras. Routed through _FireDeathFX (called from EVERY death
  -- path: OnKilled stub, lethal-hit detector, EntityRemoved fallback) so the
  -- effect fires regardless of which path the framework actually takes.
  local cls = target:GetClass()
  if cls == "ultrakill_test_idol" or cls == "ultrakill_idol" then
    -- Canon Idol explosion + shockwave (Idol's own OnDeath bypassed by stub).
    local boom = EffectData()
    boom:SetOrigin( pos )
    boom:SetMagnitude( 1 )
    boom:SetScale( 1 )
    util.Effect( "Explosion", boom )
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    end

    -- Capture players + epicenter for the deferred velocity push.
    local epicenter = pos
    local players = player.GetAll()
    timer.Simple( 0, function()
      for _, ply in ipairs( players ) do
        if not IsValid( ply ) or not ply:Alive() then continue end
        local diff = ply:WorldSpaceCenter() - epicenter
        local dist = diff:Length()
        if dist > 350 then continue end
        local dir = dist > 1 and ( diff / dist ) or Vector( 0, 0, 1 )
        local falloff = 1 - ( dist / 350 )
        ply:SetVelocity( dir * 900 * falloff + Vector( 0, 0, 350 * falloff ) )
      end
    end )
  end

  -- Record the death site so any ragdoll spawned in the next ~0.6s nearby
  -- (by the framework's own death sequence) gets killed.
  RecentDeaths[ #RecentDeaths + 1 ] = { pos = pos, time = CurTime() }
end

-- Kill ragdolls spawned by puppet death sequences. Defer one tick because
-- OnEntityCreated fires before the engine sets the ragdoll's position.
-- Matches by classname keyword (covers prop_ragdoll, framework custom ragdolls,
-- and class-server ragdoll variants). Logs every spawn near a death site so
-- we can extend the keyword list when something slips through.
local RAG_KEYWORDS = { "ragdoll", "corpse", "gib" }

local function looksLikeRagdoll( cls )
  cls = string.lower( cls )
  for _, kw in ipairs( RAG_KEYWORDS ) do
    if string.find( cls, kw, 1, true ) then return true end
  end
  return false
end

hook.Add( "OnEntityCreated", "UKPuppet_KillRagdolls", function( ent )
  timer.Simple( 0, function()
    if not IsValid( ent ) then return end

    local now = CurTime()
    -- Sweep stale entries
    for i = #RecentDeaths, 1, -1 do
      if now - RecentDeaths[ i ].time > DEATH_RAG_TTL then
        table.remove( RecentDeaths, i )
      end
    end
    if #RecentDeaths == 0 then return end

    local p = ent:GetPos()
    local cls = ent:GetClass()
    local matched = false
    for _, d in ipairs( RecentDeaths ) do
      if d.pos:DistToSqr( p ) < DEATH_RAG_RADIUS_SQR then
        matched = true
        break
      end
    end
    if not matched then return end

    if looksLikeRagdoll( cls ) then ent:Remove() end
  end )
end )

-- =============================================================================
-- Damage hook: combines two effects in deterministic order:
--   1. Puppet-as-attacker swing nerf: Puppet swing does 10 dmg vs player, 1 dmg vs other enemies.
--      QC declares 10 (the player-facing value); we override to 1 when victim is non-player.
--   2. Puppeted-victim ×2 received: applied AFTER the nerf so a Puppet hitting another puppeted
--      enemy resolves to 1 × 2 = 2 (canon: puppeted takes double).
-- No coordination with Idol-blessing (commutative scalar mul: 0×2 = 2×0 = 0).
-- =============================================================================

hook.Add( "EntityTakeDamage", UKPuppet.Hooks.Damage, function( ent, dmg )
  local atk = dmg:GetAttacker()
  if IsValid( atk ) and atk:GetClass() == "ultrakill_test_puppet"
        and IsValid( ent ) and not ent:IsPlayer() then
    dmg:SetDamage( 1 )
  end
  if UKPuppet.IsApplied( ent ) then
    dmg:ScaleDamage( 2.0 )

    -- Lethal hit: fire blood explosion early and set DMG_REMOVENORAGDOLL for
    -- source NPCs (their engine death would otherwise spawn the standard
    -- ragdoll). UB/DrGBase nextbots are handled via the OnKilled override
    -- installed in shared.lua _ApplyInternal — that one fully bypasses the
    -- framework death anim + custom gib spawn (Cerberus / Schism / Malicious
    -- Face / Mindflayer / Hideous Mass).
    -- IMPORTANT: do NOT cleanse here. The OnKilled stub depends on still being
    -- installed when the framework calls it — cleansing now would restore the
    -- original OnKilled and let the gib coroutine fire. Cleanse runs from
    -- EntityRemoved instead, after Remove takes effect.
    if not ent:IsPlayer() then
      local hp = ent.Health and ent:Health() or 0
      if hp > 0 and dmg:GetDamage() >= hp then
        -- Mark engine NPC ragdoll suppression IMMEDIATELY so source NPCs'
        -- engine death pipeline picks it up. (Required mid-hook because the
        -- engine reads dmg flags right after this returns.)
        dmg:SetDamageType( bit.bor( dmg:GetDamageType(), DMG_REMOVENORAGDOLL ) )

        -- Defer the FX so we don't fire it for damage that gets blocked
        -- AFTER us (Idol's mêlée filter, blessing, etc). On next tick,
        -- if the entity is actually dead/removed, fire the FX. Otherwise
        -- a damage-blocked Idol stays alive without a fake explosion.
        timer.Simple( 0, function()
          if not IsValid( ent ) then
            -- Entity was removed (e.g. via OnKilled stub) — nothing to FX
            -- because _FireDeathFX needs a valid entity for pos. The stub
            -- itself already called _FireDeathFX before SafeRemoveEntity.
            return
          end
          if ent.Health and ent:Health() <= 0 then
            UKPuppet._FireDeathFX( ent )
          end
        end )
      end
    end
  end
end )

-- =============================================================================
-- ULTRAKILL blood + "blood is fuel" healing for non-UltrakillBase puppets.
-- UB nextbots already spawn UK blood (ENT:CreateBlood) and heal the attacker
-- via the base's own PostEntityTakeDamage hook; every other puppeted living
-- thing (Source NPCs like citizens, players, generic nextbots) gets the same
-- treatment here. Their stock Source blood is suppressed at Apply time
-- (SetBloodColor DONT_BLEED in shared.lua), so this is their only blood.
-- =============================================================================

local BLOOD_CAP = 96

hook.Add( "PostEntityTakeDamage", UKPuppet.Hooks.BloodFuel, function( ent, dmg, took )
  if not took or not IsValid( ent ) then return end
  if not UKPuppet.IsApplied( ent ) then return end
  if ent.IsUltrakillNextbot then return end    -- base handles blood + healing itself
  if not UltrakillBase then return end
  -- Only living things bleed — skip puppeted props.
  if not ( ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() ) then return end

  local damage = dmg:GetDamage()
  if damage <= 0 then return end

  -- UK blood burst at the hit position; off-model / unset positions fall back
  -- to WorldSpaceCenter (same 0.81-radius² rule the base's ENT:CreateBlood uses).
  if UltrakillBase.CreateBlood then
    local pos = dmg:GetDamagePosition()
    local center = ent:WorldSpaceCenter()
    local radius = ent:GetModelRadius() or ent:BoundingRadius()
    if not pos or pos:IsZero() or pos:DistToSqr( center ) > radius * radius * 0.81 then
      pos = center
    end
    -- 2× the base's per-hit formula — puppets bleed heavier than regular enemies.
    local amount = math.max( 4, 1.5 * ( damage - 5 ) )
    UltrakillBase.CreateBlood( pos, math.min( amount, BLOOD_CAP ) )
  end

  -- Blood is fuel: heal the attacking player, mirroring the base healing hook
  -- (ultrakillbase_healing.lua). We only fill the gap the base leaves open:
  -- with drg_ultrakill_healing_ultrakillonly=1 (default) the base ignores
  -- non-UK victims; with 0 the base already heals from everything, so we stay
  -- silent to avoid double healing.
  local cvHealing = GetConVar( "drg_ultrakill_healing" )
  local cvUKOnly  = GetConVar( "drg_ultrakill_healing_ultrakillonly" )
  if not cvHealing or not cvHealing:GetBool() then return end
  if not cvUKOnly or not cvUKOnly:GetBool() then return end

  local ply = dmg:GetAttacker()
  if not IsValid( ply ) or not ply:IsPlayer() or ply == ent then return end

  local cvRange = GetConVar( "drg_ultrakill_healing_range" )
  local range = ( cvRange and cvRange:GetFloat() or 200 ) + ent:BoundingRadius() * 0.75
  if ply:WorldSpaceCenter():DistToSqr( ent:WorldSpaceCenter() ) > range * range then return end

  local hp, maxHP = ply:Health(), ply:GetMaxHealth()
  if hp >= maxHP then return end

  local cvMaxHeal = GetConVar( "drg_ultrakill_healing_maxheal" )
  local heal = math.min( damage, cvMaxHeal and cvMaxHeal:GetInt() or 25 )
  local hardDamage = UltrakillBase.GetHardDamage and UltrakillBase.GetHardDamage( ply ) or 0
  ply:SetHealth( math.Clamp( hp + heal, 0, maxHP - hardDamage ) )

  if UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_HP", ply:GetPos(), ply )
  end
end )

-- =============================================================================
-- Per-tick speed dispatcher (Think every 0.2s). Also handles universal death cleanup.
-- =============================================================================

-- DrGBase / UltrakillBase nextbots compute movement speed via OnUpdateSpeed() returning
-- self.WalkSpeed or self.RunSpeed FIELDS. There are no SetWalkSpeed/SetRunSpeed methods
-- on these nextbots — writing the field directly is the only way to slow them.
-- The sentinel pattern: only overwrite if current value still matches what WE wrote last
-- (or no slow has fired yet). If something external changed the speed in-between, leave
-- it alone — assume the user/another system meant it.
local function ApplySlow( target, state )
  local fw = state.framework
  if fw == "ultrakillbase" or fw == "drgbase" or fw == "nextbot_generic" then
    if not state.origSpeed then return end
    -- Walk
    local curWalk = target.WalkSpeed
    if state.lastAppliedSpeed == nil or curWalk == state.lastAppliedSpeed then
      local newWalk = state.origSpeed * SLOW
      target.WalkSpeed = newWalk
      state.lastAppliedSpeed = newWalk
    end
    -- Run
    if state.origRunSpeed then
      local curRun = target.RunSpeed
      if state.lastAppliedRun == nil or curRun == state.lastAppliedRun then
        local newRun = state.origRunSpeed * SLOW
        target.RunSpeed = newRun
        state.lastAppliedRun = newRun
      end
    end
    state.speedSlowed = true
  elseif fw == "source_npc" or fw == "zbase" or fw == "vjbase" then
    -- Engine `ai` NPCs (incl. ZBase / VJ Base) — m_flSpeed save value; the
    -- nextbot WalkSpeed/RunSpeed fields don't exist on them.
    if state.origSpeed then
      local ok, curSpeed = pcall( target.GetSaveValue, target, "m_flSpeed" )
      curSpeed = ( ok and curSpeed ) or state.origSpeed
      if state.lastAppliedSpeed == nil or curSpeed == state.lastAppliedSpeed then
        local newSpeed = state.origSpeed * SLOW
        pcall( target.SetSaveValue, target, "m_flSpeed", newSpeed )
        state.lastAppliedSpeed = newSpeed
        state.speedSlowed = true
      end
    end
  elseif fw == "player" then
    if state.origSpeed then
      local curWalk = target:GetWalkSpeed()
      if state.lastAppliedSpeed == nil or curWalk == state.lastAppliedSpeed then
        local newWalk = state.origSpeed * SLOW
        target:SetWalkSpeed( newWalk )
        state.lastAppliedSpeed = newWalk
      end
    end
    if state.origRunSpeed then
      local curRun = target:GetRunSpeed()
      if state.lastAppliedRun == nil or curRun == state.lastAppliedRun then
        local newRun = state.origRunSpeed * SLOW
        target:SetRunSpeed( newRun )
        state.lastAppliedRun = newRun
      end
    end
    state.speedSlowed = true
  end
  -- vjbase, prop, other: no-op (best-effort, speedSlowed remains false)
end

local nextTick = 0

hook.Add( "Think", UKPuppet.Hooks.Tick, function()
  if CurTime() < nextTick then return end
  nextTick = CurTime() + TICK

  for target, state in pairs( UKPuppet.Targets ) do
    if not IsValid( target ) then
      UKPuppet.Targets[ target ] = nil
    else
      -- Universal death detection. Living entities + breakable props (origSpeed irrelevant
      -- for props; we use a once-positive-now-zero HP transition to detect destruction).
      -- Plain destroyed props get caught by the EntityRemoved hook anyway; this is the
      -- belt-and-braces for breakables that switch to 0 HP without being removed.
      local isLiving = target:IsNPC() or target:IsNextBot() or target:IsPlayer()
      local hp = target.Health and target:Health() or 0
      -- "Seen alive" latch: some NPC bases deliver health AFTER Spawn() returns
      -- (timer-deferred init), so a freshly respawned puppet can sit at HP 0
      -- for a few ticks. Without the latch this loop instantly declared it
      -- dead and cleansed the status — the NPC then lived on as a plain
      -- un-puppeted copy. The 2s appliedAt grace keeps genuinely broken
      -- entities from lingering in the registry forever.
      if isLiving and hp > 0 and not state.sawAlive then state.sawAlive = true end
      if isLiving and hp <= 0 and ( state.sawAlive or CurTime() - state.appliedAt > 2 ) then
        if not target:IsPlayer() then UKPuppet._FireDeathFX( target ) end
        UKPuppet._CleanseInternal( target )
      elseif state.framework == "prop" and state.propHadHP and hp <= 0 then
        UKPuppet._FireDeathFX( target )
        UKPuppet._CleanseInternal( target )
      else
        if state.framework == "prop" and not state.propHadHP and hp > 0 then
          state.propHadHP = true
        end
        ApplySlow( target, state )
        -- Puppet must not hunt ULTRAKILL NPCs / its own support while the FFA
        -- checkbox is off — relationship overrides don't reach frameworks with
        -- fully custom target scans, so reset their enemy slot each tick.
        if UKIdol and UKIdol.PoliceUKPuppetEnemy then
          UKIdol.PoliceUKPuppetEnemy( target )
        end
      end
    end
  end
end )

-- =============================================================================
-- GC hooks
-- =============================================================================

hook.Add( "EntityRemoved", UKPuppet.Hooks.EntRemoved, function( ent )
  -- Instant-kill (e.g. crowbar OHK) can remove the entity before the next Tick
  -- detects the HP drop. Fire the death FX here too — UKPuppet._FireDeathFX is idempotent
  -- via UKPuppet_DeathFXFired so we never double-burst.
  if UKPuppet.Targets[ ent ] and IsValid( ent ) and not ent:IsPlayer() then
    UKPuppet._FireDeathFX( ent )
  end
  -- Drop key if ent was a target
  UKPuppet.Targets[ ent ] = nil
  -- Also nil source ref in any other state where this ent was the source
  for _, state in pairs( UKPuppet.Targets ) do
    if state.source == ent then state.source = nil end
  end
end )

hook.Add( "PlayerDisconnected", UKPuppet.Hooks.PlyDC, function( ply )
  UKPuppet._CleanseInternal( ply )
end )

hook.Add( "PlayerDeath", UKPuppet.Hooks.PlyDeath, function( ply )
  UKPuppet._CleanseInternal( ply )
end )

hook.Add( "PlayerSpawn", UKPuppet.Hooks.PlySpawn, function( ply )
  UKPuppet._CleanseInternal( ply )
end )

hook.Add( "PostCleanupMap", UKPuppet.Hooks.MapClean, function()
  -- Cleanse surviving valid entities first (restores their speed/material), then wipe.
  for ent, _ in pairs( UKPuppet.Targets ) do
    if IsValid( ent ) then
      UKPuppet._CleanseInternal( ent )
    end
  end
  UKPuppet.Targets = {}
end )

-- =============================================================================
-- Periodic safety sweep (every 5s) — drops stale entries that escaped the hooks.
-- =============================================================================

timer.Create( "UKPuppet_Sweep", SWEEP, 0, function()
  for target, _ in pairs( UKPuppet.Targets ) do
    if not IsValid( target ) then UKPuppet.Targets[ target ] = nil end
  end
end )
