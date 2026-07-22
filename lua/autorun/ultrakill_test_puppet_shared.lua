-- ULTRAKILL Puppet — cross-NPC Puppeted status mechanic
-- Shared API + registry. Public surface: UKPuppet.Apply / Cleanse / IsApplied / GetSource / GetState.

if UKPuppet then return end    -- guard against double-init

UKPuppet = {}

-- Server-authoritative registry. [Entity] = StateRecord:
--   { source, appliedAt, framework, origSpeed, origRunSpeed,
--     lastAppliedSpeed, lastAppliedRun, speedSlowed }
UKPuppet.Targets = {}

-- Namespaced hook ids — avoid collision with Idol or third-party addons.
UKPuppet.Hooks = {
  Damage     = "UKPuppet_DamageScale",
  Tick       = "UKPuppet_SpeedTick",
  EntRemoved = "UKPuppet_EntCleanup",
  PlyDC      = "UKPuppet_PlyDC",
  PlyDeath   = "UKPuppet_PlyDeath",
  PlySpawn   = "UKPuppet_PlySpawn",
  MapClean   = "UKPuppet_MapCleanup",
  Render     = "UKPuppet_RenderJitter",
  BloodFuel  = "UKPuppet_BloodFuel",
}

UKPuppet.NW2 = {
  Active    = "UKPuppet_Active",
  Source    = "UKPuppet_Source",
  SpawnedAt = "UKPuppet_SpawnedAt",    -- CurTime when spawn FX fired (for body fade-in)
}

UKPuppet.PuppetMaterial = "models/ultrakill_puppet/puppet_blood"

-- Classes that must never be puppeted regardless of HP / framework detection.
-- Ragdolls are corpse remnants (already dead from gameplay perspective); hands and
-- viewmodels are first-person rendering helpers, not gameplay entities.
local REJECT_CLASSES = {
  worldspawn = true, gmod_hands = true,
  predicted_viewmodel = true, viewmodel = true,
  prop_ragdoll = true,
}

-- Framework detection chain. Returns string label.
function UKPuppet.DetectFramework( ent )
  if not IsValid( ent ) then return "invalid" end
  local cls = ent:GetClass()
  if REJECT_CLASSES[ cls ] then return "invalid" end
  if ent:IsPlayer() then return "player" end
  if ent.IsUltrakillNextbot then return "ultrakillbase" end
  if ent.IsDrGNextbot or ent.IsDrGNextbotV2 then return "drgbase" end
  if ent.IsZBaseNPC then return "zbase" end
  if ent.IsVJBaseSNPC or ent.VJ_NPC_Class then return "vjbase" end
  if ent:IsNPC() then return "source_npc" end
  if ent:IsNextBot() then return "nextbot_generic" end
  if cls == "prop_physics" or cls == "prop_dynamic" then
    return "prop"
  end
  return "other"
end

-- Validation: returns bool. Excludes only impossible-to-puppet entities.
-- Already-puppeted is NOT a rejection (Apply handles as idempotent refresh).
function UKPuppet.IsValidTarget( ent )
  if not IsValid( ent ) then return false end
  local cls = ent:GetClass()
  if REJECT_CLASSES[ cls ] then return false end
  if cls:sub( 1, 4 ) == "env_" then return false end
  -- Only living entities check Health<=0 (props with 0 HP are valid: indestructible).
  if ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() then
    if ( ent.Health and ent:Health() or 0 ) <= 0 then return false end
  end
  return true
end

-- Queries (shared client+server)
function UKPuppet.IsApplied( ent )
  if not IsValid( ent ) then return false end
  if SERVER then
    return UKPuppet.Targets[ ent ] ~= nil
  else
    return ent:GetNW2Bool( UKPuppet.NW2.Active, false )
  end
end

function UKPuppet.GetSource( ent )
  if not IsValid( ent ) then return nil end
  if SERVER then
    local s = UKPuppet.Targets[ ent ]
    return s and s.source or nil
  else
    local src = ent:GetNW2Entity( UKPuppet.NW2.Source )
    if IsValid( src ) then return src end
    return nil
  end
end

function UKPuppet.GetState( ent )
  if not SERVER then return nil end
  return UKPuppet.Targets[ ent ]
end

-- =============================================================================
-- Apply / Cleanse (server-only). Public Apply uses _ApplyInternal primitive.
-- _ApplyInternal is non-reentrant (UB ENT adapters call it directly to avoid recursion).
-- =============================================================================

if SERVER then

local function StashSpeed( ent, framework )
  if framework == "ultrakillbase" or framework == "drgbase" or framework == "nextbot_generic" then
    return ent.WalkSpeed or ( ent.GetWalkSpeed and ent:GetWalkSpeed() ) or 100,
           ent.RunSpeed  or ( ent.GetRunSpeed  and ent:GetRunSpeed()  ) or 200
  elseif framework == "source_npc" or framework == "zbase" or framework == "vjbase" then
    -- ZBase / VJ Base NPCs are engine `ai` NPCs — they have no WalkSpeed/RunSpeed
    -- Lua fields (writing those was a silent no-op), so they take the same
    -- m_flSpeed save-value route as stock Source NPCs.
    -- pcall: piengineers Lua patcher rewrites GetSaveValue and crashes on NPCs
    -- whose internal save-value resolver returns nil. We treat it as best-effort.
    local ok, speed = pcall( ent.GetSaveValue, ent, "m_flSpeed" )
    return ( ok and speed ) or 100, nil
  elseif framework == "player" then
    return ent:GetWalkSpeed(), ent:GetRunSpeed()
  end
  return nil, nil
end

function UKPuppet._ApplyInternal( target, source, opts )
  opts = opts or {}
  if not UKPuppet.IsValidTarget( target ) then return false end

  -- Idempotent refresh: already in Targets → just update source/appliedAt, no FX replay.
  local existing = UKPuppet.Targets[ target ]
  if existing then
    existing.source    = IsValid( source ) and source or existing.source
    existing.appliedAt = CurTime()
    if IsValid( source ) then target:SetNW2Entity( UKPuppet.NW2.Source, source ) end
    return true
  end

  -- Sand+Puppet canon interaction (EnemyIdentifier.cs:2235):
  --   * already-sand non-Stalker target → instakill + cloud (sand symmetry: sand→puppet kills)
  --   * already-sand Stalker → exempt; puppet applies normally (Stalker is permanently sand by design)
  if UKSand and UKSand.IsSand and UKSand.IsSand( target )
     and target:GetClass() ~= "ultrakill_test_stalker" then
    timer.Simple( 0.05, function()
      if not IsValid( target ) then return end
      ParticleEffect( "Ultrakill_SandExplosion", target:WorldSpaceCenter(), target:GetAngles() )
      sound.Play( "ultrakill_test/sand_hit.wav", target:GetPos(), 75, 100, 1 )
      target:TakeDamage( 99999, IsValid( source ) and source or target,
                                  IsValid( source ) and source or target )
    end )
    -- Continue with normal puppet apply — the timer kills the target on next tick, but the puppet
    -- flag still gets set (matches canon: target is puppeted-then-immediately-dies, which fires
    -- our puppet death FX hook before remove).
  end

  local framework = UKPuppet.DetectFramework( target )
  local origSpeed, origRun = StashSpeed( target, framework )

  UKPuppet.Targets[ target ] = {
    source           = IsValid( source ) and source or nil,
    appliedAt        = CurTime(),
    framework        = framework,
    origSpeed        = origSpeed,
    origRunSpeed     = origRun,
    lastAppliedSpeed = nil,
    lastAppliedRun   = nil,
    speedSlowed      = false,
  }

  -- NW2 sync
  target:SetNW2Bool( UKPuppet.NW2.Active, true )
  if IsValid( source ) then target:SetNW2Entity( UKPuppet.NW2.Source, source ) end

  -- Stop puppeted enemies from aggroing on Idols / Deathcatchers (canon:
  -- support entities are never targets of their own beneficiaries).
  -- FFA mode (puppet_hostile_to_all_enabled) overrides: puppet hates everyone.
  if UKIdol and UKIdol.IsPuppetFFAEnabled and UKIdol.IsPuppetFFAEnabled() then
    if UKIdol.SetupHostileToAll then UKIdol.SetupHostileToAll( target ) end
  elseif UKIdol and UKIdol.SetupFriendlyToSupports then
    UKIdol.SetupFriendlyToSupports( target )
    -- FFA off: puppets are also non-hostile toward EVERY ULTRAKILL NPC, not
    -- just the supports (playtest report: puppet Liberty Prime attacked its DC).
    if UKIdol.SetupPuppetPeaceWithUK then UKIdol.SetupPuppetPeaceWithUK( target ) end
  end

  -- Tell every outsider NPC that this new puppet is now a priority target.
  if UKIdol and UKIdol.SetupOutsiderPriorityTargets then
    for _, e in ipairs( ents.GetAll() ) do
      if IsValid( e ) and ( e:IsNPC() or e:IsNextBot() ) and e ~= target then
        UKIdol.SetupOutsiderPriorityTargets( e )
      end
    end
  end

  -- Stash render mode + color so cleanse can restore them. No SetMaterial here —
  -- material replacement now happens client-side via ENT.RenderOverride (render.lua).
  if not target.UKPuppet_OrigRenderModeStashed then
    target.UKPuppet_OrigRenderMode = target:GetRenderMode()
    local cr, cg, cb, ca = target:GetColor():Unpack()
    target.UKPuppet_OrigColor = Color( cr, cg, cb, ca )
    target.UKPuppet_OrigRenderModeStashed = true
  end
  -- Render mode only — the actual material override happens client-side via
  -- ENT.RenderOverride (set up in render.lua). This avoids losing the override to
  -- framework-owned draw paths (UltrakillBase/DrGBase override SetMaterial in their
  -- _BaseDraw passes) and prevents the chromatic flicker race seen on UB nextbots.
  -- Alpha 170 (~0.666) drives translucency through entity color modulation —
  -- $alpha in VMT is unreliable under render.MaterialOverride.
  target:SetRenderMode( RENDERMODE_TRANSCOLOR )
  target:SetColor( Color( 255, 255, 255, 170 ) )

  -- Puppets are made of blood (canon), so they bleed ULTRAKILL blood: suppress
  -- the stock Source blood decals/particles here; the UK blood burst + healing
  -- happen server-side on PostEntityTakeDamage (effects.lua, Hooks.BloodFuel).
  -- UltrakillBase nextbots keep their own pipeline — the base already spawns
  -- UK blood and heals from them, touching their blood color would be a no-op
  -- at best and a double-blood source at worst.
  if framework ~= "ultrakillbase" and not target.UKPuppet_OrigBloodColorStashed then
    target.UKPuppet_OrigBloodColor = target:GetBloodColor()
    target.UKPuppet_OrigBloodColorStashed = true
    target:SetBloodColor( DONT_BLEED )
  end

  -- Hijack ENT:OnKilled (UB/DrGBase nextbots use it as their death entry point).
  -- Their default OnKilled runs OnDeath in a coroutine — that's where Cerberus,
  -- Schism, Malicious Face etc spawn gibs and where Mindflayer / Hideous Mass
  -- play their death animations. We want NONE of that for puppeted enemies:
  -- just blood explosion and instant remove. Source NPCs don't have ENT:OnKilled
  -- (engine handles their death), so this override is a no-op for them and the
  -- EntityTakeDamage lethal-detection path covers them instead.
  if not target.UKPuppet_OrigOnKilledStashed then
    -- Capture via target.OnKilled (NOT rawget — entities are userdata, not
    -- tables; rawget errors out). This resolves through the metatable so we
    -- pick up the framework's meta-default OnKilled when there's no instance
    -- override, which is what we want to restore on cleanse.
    target.UKPuppet_OrigOnKilled = target.OnKilled
    target.UKPuppet_OrigOnKilledStashed = true
    target.OnKilled = function( self, dmg )
      -- Per-class extras (Idol shockwave etc) are inside _FireDeathFX itself
      -- so they fire regardless of which death path runs (OnKilled stub OR
      -- the EntityTakeDamage lethal detector OR EntityRemoved fallback).
      if UKPuppet._FireDeathFX then UKPuppet._FireDeathFX( self ) end
      SafeRemoveEntity( self )
    end
  end

  -- FX dispatch. For the canonical "vertical rise from a blood pool" spawn FX we want
  -- to start at ground level (target's feet), not at WorldSpaceCenter — otherwise the
  -- pool/rise begins inside the torso and looks broken. Overlay pulse stays centred.
  local fxLevel = opts.fxLevel or "overlay"
  if fxLevel ~= "none" then
    local fx = EffectData()
    fx:SetMagnitude( target:OBBMaxs():Length() * 1.5 )
    if fxLevel == "spawn" then
      fx:SetOrigin( target:GetPos() )
      fx:SetEntity( target )    -- so client EFFECT can clip distortion to target bounds
      util.Effect( "ukpuppet_spawn", fx, true, true )
      -- Tell client to rise body from pool over the spawn animation duration.
      target:SetNW2Float( UKPuppet.NW2.SpawnedAt, CurTime() )
    else
      fx:SetOrigin( target:WorldSpaceCenter() )
      util.Effect( "ukpuppet_overlay_pulse", fx, true, true )
    end
    sound.Play( "Ultrakill_Puppet_Spawn", target:GetPos() )
  end

  return true
end

function UKPuppet._CleanseInternal( target )
  if not IsValid( target ) then
    UKPuppet.Targets[ target ] = nil
    return false
  end
  local state = UKPuppet.Targets[ target ]
  if not state then return false end

  -- Restore speed only if WE were the last writer (lastAppliedSpeed sentinel).
  -- Player has SetWalkSpeed/SetRunSpeed methods; nextbots use WalkSpeed/RunSpeed fields.
  if state.framework == "player" then
    if state.origSpeed and ( not state.lastAppliedSpeed or target:GetWalkSpeed() == state.lastAppliedSpeed ) then
      target:SetWalkSpeed( state.origSpeed )
    end
    if state.origRunSpeed and ( not state.lastAppliedRun or target:GetRunSpeed() == state.lastAppliedRun ) then
      target:SetRunSpeed( state.origRunSpeed )
    end
  elseif state.framework == "ultrakillbase" or state.framework == "drgbase" or state.framework == "nextbot_generic" then
    if state.origSpeed and ( not state.lastAppliedSpeed or target.WalkSpeed == state.lastAppliedSpeed ) then
      target.WalkSpeed = state.origSpeed
    end
    if state.origRunSpeed and ( not state.lastAppliedRun or target.RunSpeed == state.lastAppliedRun ) then
      target.RunSpeed = state.origRunSpeed
    end
  elseif state.framework == "source_npc" or state.framework == "zbase" or state.framework == "vjbase" then
    if state.origSpeed then
      local ok, curSpeed = pcall( target.GetSaveValue, target, "m_flSpeed" )
      curSpeed = ( ok and curSpeed ) or state.origSpeed
      if not state.lastAppliedSpeed or curSpeed == state.lastAppliedSpeed then
        pcall( target.SetSaveValue, target, "m_flSpeed", state.origSpeed )
      end
    end
  end

  -- Restore render mode + color (material override is on the client RenderOverride
  -- side and will detach itself on the next client tick when NW2_Active goes false).
  if target.UKPuppet_OrigRenderModeStashed then
    target:SetRenderMode( target.UKPuppet_OrigRenderMode or RENDERMODE_NORMAL )
    if target.UKPuppet_OrigColor then target:SetColor( target.UKPuppet_OrigColor ) end
    target.UKPuppet_OrigRenderMode = nil
    target.UKPuppet_OrigColor      = nil
    target.UKPuppet_OrigRenderModeStashed = nil
  end

  -- Restore stock blood color (BLOOD_COLOR_RED is 0, so nil-check explicitly —
  -- `or` fallback would eat a legitimately stashed 0).
  if target.UKPuppet_OrigBloodColorStashed then
    if target.UKPuppet_OrigBloodColor ~= nil then
      target:SetBloodColor( target.UKPuppet_OrigBloodColor )
    end
    target.UKPuppet_OrigBloodColor = nil
    target.UKPuppet_OrigBloodColorStashed = nil
  end

  -- Restore OnKilled (was nil-rawget if entity used meta default; setting back
  -- to nil makes lookups fall through to the meta again).
  if target.UKPuppet_OrigOnKilledStashed then
    target.OnKilled = target.UKPuppet_OrigOnKilled
    target.UKPuppet_OrigOnKilled = nil
    target.UKPuppet_OrigOnKilledStashed = nil
  end

  -- Clear NW2
  target:SetNW2Bool( UKPuppet.NW2.Active, false )
  target:SetNW2Entity( UKPuppet.NW2.Source, NULL )

  UKPuppet.Targets[ target ] = nil

  -- Restore default hostile relationship to Idols/Deathcatchers, unless this
  -- enemy is still blessed by an Idol (in which case we keep it friendly).
  if UKIdol and UKIdol.RestoreHostileToSupports
       and not ( UKIdol.Blessed and UKIdol.Blessed[ target ] ) then
    UKIdol.RestoreHostileToSupports( target )
  end

  return true
end

-- Public API (calls primitive directly — no recursion through adapters)
function UKPuppet.Apply( target, source, opts )
  return UKPuppet._ApplyInternal( target, source, opts )
end

function UKPuppet.Cleanse( target )
  return UKPuppet._CleanseInternal( target )
end

end    -- if SERVER
