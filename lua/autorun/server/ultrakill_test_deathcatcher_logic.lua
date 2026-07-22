-- ULTRAKILL Deathcatcher — server-side cross-cutting hooks.
-- 1. Self-defence damage filter (mirror of Idol's: melee passes, everything else
--    reflects with damage=0). Reuses UKIdol.IsMeleeAttack + UKIdol.SpawnReflect
--    directly so the two ports stay in lock-step on melee detection rules.
-- 2. Cross-NPC death-catching: lethal hits on NPCs/nextbots within range of any
--    active Deathcatcher get queued for puppeted respawn.

if not SERVER then return end
if not UKDeathcatcher then return end


-- Funny bug: when 1, a slain Deathcatcher counts as a catchable death — any
-- OTHER active Deathcatcher in range revives it as a puppet-catcher (which is
-- itself active and can revive further victims). Default 0 (canon behaviour:
-- Deathcatchers are infrastructure and never revive each other).
-- Replicated so the Q-menu checkbox on the client can read the current value.
CreateConVar(
  "ukdc_revive_deathcatchers_enabled", "0",
  bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED ),
  "Allow Deathcatchers to revive other Deathcatchers as puppets."
)


-- =============================================================================
-- Damage filter — same melee-only rule as Idol.
-- =============================================================================

hook.Add( "EntityTakeDamage", UKDeathcatcher.Hooks.SelfDefense, function( target, dmg )
  if not IsValid( target ) then return end
  if target:GetClass() ~= "ultrakill_test_deathcatcher" then return end

  if UKIdol and UKIdol.IsMeleeAttack and UKIdol.IsMeleeAttack( dmg:GetAttacker(), dmg ) then
    return    -- pass damage through
  end

  -- NOTE: Stalker sand explosion intentionally takes the default path below —
  -- damage zeroed + reflect cosmetic. The explosion does NOT kill the
  -- Deathcatcher; the sand COAT is applied separately via UKSand.Apply in the
  -- Stalker's explosion loop (canon Sandify has no support-unit exclusion).

  -- Fire damage: extinguish + absorb silently. Burn ticks (~0.5s cadence)
  -- would otherwise each emit a SpawnReflect cosmetic — visual spam. See
  -- the matching block in UKIdol_SelfDefense for the rationale.
  if dmg:IsDamageType( DMG_BURN ) then
    if target.Extinguish then target:Extinguish() end
    dmg:SetDamage( 0 )
    return true
  end

  dmg:SetDamage( 0 )
  if UKIdol and UKIdol.SpawnReflect then
    UKIdol.SpawnReflect( target, dmg )
  end
  return true
end )


-- Deathcatchers are non-flammable: stub Ignite() so any code path (env_fire,
-- hellbullet, player fire weapon) that tries to set them alight is a no-op.
-- Belt-and-suspenders with the SelfDefense Extinguish above.
hook.Add( "OnEntityCreated", "UKDeathcatcher_NoIgnite", function( ent )
  timer.Simple( 0, function()
    if not IsValid( ent ) then return end
    if ent:GetClass() ~= "ultrakill_test_deathcatcher" then return end
    ent.Ignite = function() end
    if ent:IsOnFire() then ent:Extinguish() end
  end )
end )


-- =============================================================================
-- Death-catching, two-phase:
--   1. EntityTakeDamage: refresh a per-entity SNAPSHOT with the latest pos/ang/
--      weapon and pin the nearest Deathcatcher. Cheap, idempotent, no commit.
--   2. EntityRemoved: if a snapshot exists for the removed entity AND it was
--      taken recently (≤2s), commit it to the Deathcatcher's queue.
--
-- Why this shape (vs the earlier deferred-tick design):
--   - Source NPCs spend 1+ ticks in their death animation with HP≤0 but IsValid
--     still true — the previous "is it alive next tick" check could see them
--     "alive enough" and clear the pending flag, missing the death entirely.
--   - The puppet OnKilled stub removes UB/DrGBase nextbots IMMEDIATELY on lethal
--     hit, so EntityRemoved fires reliably for them in the same frame.
--   - Hooking EntityRemoved means the death capture is tied to actual removal,
--     not to "did we see HP=0 in a particular frame". Symmetric for both paths.
--
-- Snapshot is overwritten on every damage so it always reflects the latest
-- pre-death state (entity may move while bleeding out).
-- =============================================================================

local PendingSnapshot = {}    -- [Entity] = { cls, pos, ang, weapon, nearest, snappedAt, lethal }
local SNAPSHOT_TTL = 30.0     -- generous window: animated-death bosses
                              -- (Mindflayer, Hideous Mass, Gabriel, V-CR) play
                              -- multi-second animations between killing blow
                              -- and actual entity removal. A 30s snapshot
                              -- lifetime covers any reasonable anim length.


-- Lethal-state heuristic. Some frameworks (UltrakillBase, DrGBase) intercept
-- damage and either zero it or clamp HP to 1 before our hook sees it. We
-- combine multiple signals so we still detect "this NPC is dying" reliably.
local function isEntityDying( ent, dmgAmount )
  if not IsValid( ent ) then return true end    -- already gone — count as dying
  if ent.IsDead and ent:IsDead() then return true end
  local hp = ent.Health and ent:Health() or 0
  if hp <= 0 then return true end
  if hp <= dmgAmount then return true end
  -- DrGBase / UltrakillBase flags
  if ent.GetNW2Bool then
    if ent:GetNW2Bool( "DrGBaseDown" ) then return true end
  end
  if ent._DrGBase_OnFatalDamage_Fired then return true end
  return false
end


hook.Add( "EntityTakeDamage", UKDeathcatcher.Hooks.CatchDeath, function( ent, dmg )
  if not IsValid( ent ) then return end
  if not ( ent:IsNPC() or ent:IsNextBot() ) then return end
  if not UKDeathcatcher.IsRevivableClass( ent:GetClass() ) then return end

  -- Skip anything that's currently a puppet — canon: puppets are non-replicable.
  -- (The original puppet record stays in the Deathcatcher's DeadList from its
  -- first death, so its respawn loop is driven by SlowUpdate noticing the
  -- puppet entity went invalid.)
  if UKPuppet and UKPuppet.IsApplied and UKPuppet.IsApplied( ent ) then return end

  -- Exclude the victim itself: a dying Deathcatcher (revive-DC bug on) is
  -- still in the Active registry here and must not catch its own death.
  local nearest = UKDeathcatcher.NearestActive( ent:GetPos(), ent )
  if not IsValid( nearest ) then return end

  local weapon = nil
  if ent:IsNPC() and ent.GetActiveWeapon then
    local wep = ent:GetActiveWeapon()
    if IsValid( wep ) then weapon = wep:GetClass() end
  end

  local dmgAmount = dmg:GetDamage() or 0
  local existing  = PendingSnapshot[ ent ]
  local lethal    = ( existing and existing.lethal ) or isEntityDying( ent, dmgAmount )

  PendingSnapshot[ ent ] = {
    cls       = ent:GetClass(),
    pos       = ent:GetPos(),
    ang       = ent:GetAngles(),
    -- Sticky weapon: the engine DROPS the held weapon inside Event_Killed, but
    -- follow-up damage events on the dying body (remaining shotgun pellets,
    -- blast splash) still enter this hook — with GetActiveWeapon now NULL.
    -- Without stickiness those events wiped the previously captured class and
    -- the puppet respawned unarmed.
    weapon    = weapon or ( existing and existing.weapon ) or nil,
    nearest   = nearest,
    snappedAt = CurTime(),
    lethal    = lethal,
  }
end )


-- Mark the snapshot lethal as soon as the framework starts playing the death
-- animation: DrGBase fires a "DrGBaseDown" NW2 bool and UltrakillBase sets HP
-- to 0 mid-coroutine. This Tick scan promotes any pending snapshot whose owner
-- is now in a dying state, even if it stops taking damage during the anim.
hook.Add( "Tick", UKDeathcatcher.Hooks.CatchDeath .. "_Promote", function()
  for ent, snap in pairs( PendingSnapshot ) do
    if snap.lethal then continue end
    if IsValid( ent ) and isEntityDying( ent, 0 ) then
      snap.lethal = true
    end
  end
end )


hook.Add( "EntityRemoved", UKDeathcatcher.Hooks.CatchDeath .. "_Removed", function( ent )
  local snap = PendingSnapshot[ ent ]
  if not snap then return end
  PendingSnapshot[ ent ] = nil

  if CurTime() - snap.snappedAt > SNAPSHOT_TTL then return end

  if not IsValid( snap.nearest ) then return end
  snap.nearest:CatchDeath( snap.cls, snap.pos, snap.ang, snap.weapon )
end )


-- Periodic cleanup of orphaned snapshots (entities that took damage but never
-- got removed — e.g. invulnerable NPCs that recovered). Without this the table
-- would slowly leak.
timer.Create( "UKDeathcatcher_SnapCleanup", 10, 0, function()
  local now = CurTime()
  for ent, snap in pairs( PendingSnapshot ) do
    if not IsValid( ent ) or now - snap.snappedAt > SNAPSHOT_TTL then
      PendingSnapshot[ ent ] = nil
    end
  end
end )


hook.Add( "PostCleanupMap", UKDeathcatcher.Hooks.MapClean, function()
  UKDeathcatcher.Active = {}
end )
