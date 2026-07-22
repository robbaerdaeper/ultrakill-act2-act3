-- ULTRAKILL Enrage — cross-NPC Enraged status mechanic (tool-facing API).
-- Public surface: UKEnrage.Apply / Remove / IsApplied / ApplyAll / ClearAll.
--
-- Two visual paths:
--   * UltrakillBase NPCs with attachments → native SetEnraged + CreateEnrage
--     (Kevin's client effect + healthbar tint + EnragedRate; per-enemy canon
--     enrage behaviors keyed off IsEnraged fire on their own).
--   * Everything else (DrGBase / VJBase / ZBase / Source NPCs / generic
--     nextbots, plus attachment-less UKBase models) → generic client aura
--     below that replicates Kevin's effect 1:1 (RageEffect sprite + dark
--     lightning + BloodDrop bursts) keyed off an NW2 bool.
--
-- Damage: CANON Enraged never multiplies damage (wiki Status Effects — it's
-- per-enemy behavior changes; flat multipliers belong to Radiance). Default
-- dmgMult is therefore 1; the slider is an opt-in cheat knob. When >1,
-- outgoing damage of an enraged attacker is scaled in EntityTakeDamage
-- (relative scale — safe on top of any base's own multipliers;
-- registry-keyed, so self-enraged NPCs like Virtue/Power/MDK are NOT
-- double-dipped unless the user tool-enrages them explicitly).
--
-- Aggression:
--   * UKBase — the base multiplies ALL anim rates by UltrakillBase_EnragedRate
--     while IsEnraged (attacks included). Kevin's enemies define their own
--     canon rate (1.15–1.5); NPCs without one (all our ports) get the tool's
--     animRate injected for the duration.
--   * VJBase — AnimationPlaybackRate × animRate (anim-driven movement AND
--     attacks speed up together).
--   * Movement speed × speedMult for every framework that exposes it
--     (WalkSpeed/RunSpeed fields, m_flSpeed for Source NPCs) — sentinel
--     pattern from UKPuppet: only rewrite what we were the last to write.

if UKEnrage then return end    -- guard against double-init

UKEnrage = {}

UKEnrage.NW2 = {
  Active    = "UKEnrage_Active",      -- status flag (queries)
  Aura      = "UKEnrage_Aura",        -- generic client aura should draw
  Radius    = "UKEnrage_Radius",      -- aura scale (Kevin's fRadius semantics: sprite = 100 * r)
  AppliedAt = "UKEnrage_AppliedAt",   -- CurTime at apply (client activation burst)
}

UKEnrage.Sounds = {
  Start = "ultrakill/sound/enrage.wav",
  Loop  = "ultrakill/sound/rageloop.wav",
  End   = "ultrakill/sound/enrageend.wav",
}

-- Server-authoritative registry. [Entity] = { dmgMult, sound, selfEnraged,
--   framework, speedMult, origSpeed, origRunSpeed, lastAppliedSpeed,
--   lastAppliedRun, ukRateInjected, origVJRate }
UKEnrage.Targets = {}

-- Same chain as UKPuppet.DetectFramework (UKBase nextbots are DrGBase-derived,
-- so the UKBase check must run first).
function UKEnrage.DetectFramework( ent )
  if ent.IsUltrakillNextbot then return "ultrakillbase" end
  if ent.IsDrGNextbot or ent.IsDrGNextbotV2 then return "drgbase" end
  if ent.IsZBaseNPC then return "zbase" end
  if ent.IsVJBaseSNPC or ent.VJ_NPC_Class then return "vjbase" end
  if ent:IsNPC() then return "source_npc" end
  if ent:IsNextBot() then return "nextbot_generic" end
  return "other"
end

-- Kevin's fRadius=1 sprite (100 units) fits a man-size enemy whose
-- OBBMaxs length is ~75 (16,16,72-ish bounds). Scale by that, clamp for
-- headcrabs / map-size giants.
function UKEnrage.CalcRadius( ent )
  return math.Clamp( ent:OBBMaxs():Length() / 75, 0.5, 8 )
end

-- NPC-likes only: players get no combat benefit from a status meant for
-- enemies, props have no "damage dealt" to scale.
function UKEnrage.IsValidTarget( ent )
  if not IsValid( ent ) then return false end
  if ent:IsPlayer() then return false end
  if not ( ent:IsNPC() or ent:IsNextBot() ) then return false end
  if ( ent.Health and ent:Health() or 0 ) <= 0 then return false end
  return true
end

function UKEnrage.IsApplied( ent )
  if not IsValid( ent ) then return false end
  if SERVER then
    return UKEnrage.Targets[ ent ] ~= nil
  else
    return ent:GetNW2Bool( UKEnrage.NW2.Active, false )
  end
end

-- =============================================================================
-- SERVER: apply / remove / damage hook / cleanup
-- =============================================================================

if SERVER then

-- Speed snapshot for the boost tick (same sources as UKPuppet.StashSpeed).
local function StashSpeed( ent, framework )
  if framework == "ultrakillbase" or framework == "drgbase" or framework == "nextbot_generic" then
    return ent.WalkSpeed or ( ent.GetWalkSpeed and ent:GetWalkSpeed() ) or 100,
           ent.RunSpeed  or ( ent.GetRunSpeed  and ent:GetRunSpeed()  ) or 200
  elseif framework == "source_npc" or framework == "zbase" then
    -- ZBase NPCs are engine `ai` NPCs — no WalkSpeed/RunSpeed Lua fields
    -- (writing those was a silent no-op); m_flSpeed is the working route.
    -- pcall: piengineers Lua patcher rewrites GetSaveValue and crashes on NPCs
    -- whose internal save-value resolver returns nil. Best-effort.
    local ok, speed = pcall( ent.GetSaveValue, ent, "m_flSpeed" )
    return ( ok and speed ) or 100, nil
  end
  return nil, nil    -- vjbase (anim-driven movement), other
end

function UKEnrage.Apply( ent, opts )
  opts = opts or {}
  if not UKEnrage.IsValidTarget( ent ) then return false end

  -- Idempotent refresh: retune multipliers, no FX replay. The speed tick
  -- recomputes from origSpeed so a new speedMult takes effect on its own.
  local existing = UKEnrage.Targets[ ent ]
  if existing then
    existing.dmgMult   = opts.dmgMult or existing.dmgMult
    existing.speedMult = opts.speedMult or existing.speedMult
    if opts.animRate then
      if existing.ukRateInjected then
        ent.UltrakillBase_EnragedRate = opts.animRate
      elseif existing.origVJRate then
        ent.AnimationPlaybackRate = existing.origVJRate * opts.animRate
      end
    end
    return true
  end

  local dmgMult   = opts.dmgMult or 1
  local speedMult = opts.speedMult or 1.25
  local animRate  = opts.animRate or 1.25
  local aura      = opts.aura ~= false
  local sound     = opts.sound ~= false
  local radius    = UKEnrage.CalcRadius( ent )
  local framework = UKEnrage.DetectFramework( ent )
  local isUK      = framework == "ultrakillbase" and ent.SetEnraged ~= nil

  -- Self-enraged UKBase NPC (Virtue past its HP threshold etc): don't stack a
  -- second CreateEnrage aura on top of whatever the NPC already drew.
  local selfEnraged = isUK and ent:IsEnraged() or false

  -- Attack/anim speedup.
  local ukRateInjected = false
  local origVJRate = nil
  if isUK then
    -- Kevin's enemies carry a canon per-enemy rate — respect it (HideousMass
    -- deliberately declares 1). Only NPCs with no rate at all get ours.
    if ent.UltrakillBase_EnragedRate == nil and animRate ~= 1 then
      ent.UltrakillBase_EnragedRate = animRate
      ukRateInjected = true
    end
  elseif framework == "vjbase" and animRate ~= 1 then
    origVJRate = ent.AnimationPlaybackRate or 1
    ent.AnimationPlaybackRate = origVJRate * animRate
  end

  local origSpeed, origRun = nil, nil
  if speedMult ~= 1 then
    origSpeed, origRun = StashSpeed( ent, framework )
  end

  local nativeVisual = false
  if isUK then
    ent:SetEnraged( true )
    if aura and not selfEnraged then
      -- CreateEnrage anchors to attachment 1; attachment-less models
      -- (most of our generated QCs) fall through to the generic aura.
      local atts = ent:GetAttachments()
      if atts and #atts > 0 then
        ent:CreateEnrage( 1, radius )
        nativeVisual = true
      end
    elseif selfEnraged then
      nativeVisual = true
    end
  end

  if aura and not nativeVisual then
    ent:SetNW2Float( UKEnrage.NW2.Radius, radius )
    ent:SetNW2Float( UKEnrage.NW2.AppliedAt, CurTime() )
    ent:SetNW2Bool( UKEnrage.NW2.Aura, true )
  end
  ent:SetNW2Bool( UKEnrage.NW2.Active, true )

  if sound then
    ent:EmitSound( UKEnrage.Sounds.Start, 80, 100, 1, CHAN_STATIC )
    -- Canon loop (RageEffect prefab plays rageloop.wav at 0.6 while active).
    ent:EmitSound( UKEnrage.Sounds.Loop, 75, 100, 0.6, CHAN_STATIC )
  end

  UKEnrage.Targets[ ent ] = {
    dmgMult          = dmgMult,
    sound            = sound,
    selfEnraged      = selfEnraged,
    framework        = framework,
    speedMult        = speedMult,
    origSpeed        = origSpeed,
    origRunSpeed     = origRun,
    lastAppliedSpeed = nil,
    lastAppliedRun   = nil,
    ukRateInjected   = ukRateInjected,
    origVJRate       = origVJRate,
  }
  return true
end

-- Removes the tool-applied status. Also acts as a universal "un-enrage":
-- pointing it at a UKBase NPC that enraged ITSELF (never tool-touched)
-- force-clears the native state too.
function UKEnrage.Remove( ent, opts )
  opts = opts or {}
  local state = UKEnrage.Targets[ ent ]

  if not state then
    -- Not ours — but still offer native un-enrage for UKBase NPCs.
    if IsValid( ent ) and ent.IsUltrakillNextbot and ent.SetEnraged and ent:IsEnraged() then
      ent:SetEnraged( false )
      if opts.sound ~= false then
        ent:EmitSound( UKEnrage.Sounds.End, 80, 100, 1, CHAN_STATIC )
      end
      return true
    end
    return false
  end

  UKEnrage.Targets[ ent ] = nil
  if not IsValid( ent ) then return true end

  if ent.SetEnraged then ent:SetEnraged( false ) end

  -- Undo aggression boosts.
  if state.ukRateInjected then
    ent.UltrakillBase_EnragedRate = nil    -- fall back to metatable (none for our ports)
  end
  if state.origVJRate then
    ent.AnimationPlaybackRate = state.origVJRate
  end
  -- Restore speed only if WE were the last writer (sentinel pattern).
  if state.framework == "ultrakillbase" or state.framework == "drgbase"
      or state.framework == "nextbot_generic" then
    if state.origSpeed and ( not state.lastAppliedSpeed or ent.WalkSpeed == state.lastAppliedSpeed ) then
      ent.WalkSpeed = state.origSpeed
    end
    if state.origRunSpeed and ( not state.lastAppliedRun or ent.RunSpeed == state.lastAppliedRun ) then
      ent.RunSpeed = state.origRunSpeed
    end
  elseif ( state.framework == "source_npc" or state.framework == "zbase" ) and state.origSpeed then
    local ok, curSpeed = pcall( ent.GetSaveValue, ent, "m_flSpeed" )
    curSpeed = ( ok and curSpeed ) or state.origSpeed
    if not state.lastAppliedSpeed or curSpeed == state.lastAppliedSpeed then
      pcall( ent.SetSaveValue, ent, "m_flSpeed", state.origSpeed )
    end
  end
  ent:SetNW2Bool( UKEnrage.NW2.Active, false )
  ent:SetNW2Bool( UKEnrage.NW2.Aura, false )     -- client plays deactivate burst on this edge
  ent:StopSound( UKEnrage.Sounds.Loop )
  if state.sound and opts.sound ~= false then
    -- Canon: EnrageEffect.OnDestroy plays EnrageEnd.wav (also fires on death).
    ent:EmitSound( UKEnrage.Sounds.End, 80, 100, 1, CHAN_STATIC )
  end
  return true
end

function UKEnrage.ApplyAll( opts )
  local n = 0
  for _, ent in ipairs( ents.GetAll() ) do
    if not UKEnrage.Targets[ ent ] and UKEnrage.IsValidTarget( ent ) then
      if UKEnrage.Apply( ent, opts ) then n = n + 1 end
    end
  end
  return n
end

function UKEnrage.ClearAll()
  local n = 0
  for ent in pairs( UKEnrage.Targets ) do
    if UKEnrage.Remove( ent ) then n = n + 1 end
  end
  -- Also sweep natively-enraged UKBase NPCs (self-enraged or uk_enrage_test).
  for _, ent in ipairs( ents.GetAll() ) do
    if IsValid( ent ) and ent.IsUltrakillNextbot and ent.SetEnraged and ent:IsEnraged() then
      if UKEnrage.Remove( ent ) then n = n + 1 end
    end
  end
  return n
end

-- Outgoing damage of an enraged attacker. Relative ScaleDamage composes
-- cleanly with base-side multipliers (see docs on the ukbase damage pipeline);
-- EntityTakeDamage fires once per damage event (UKPuppet precedent).
hook.Add( "EntityTakeDamage", "UKEnrage_DamageScale", function( ent, dmg )
  local atk = dmg:GetAttacker()
  local state = IsValid( atk ) and UKEnrage.Targets[ atk ] or nil
  if not state then
    local inf = dmg:GetInflictor()
    state = IsValid( inf ) and UKEnrage.Targets[ inf ] or nil
    atk = inf
  end
  if state and state.dmgMult ~= 1 and ent ~= atk then
    dmg:ScaleDamage( state.dmgMult )
  end
end )

-- Movement speed boost tick. Frameworks rewrite WalkSpeed/RunSpeed from their
-- own state machines, so a one-shot write decays — reapply on a 0.2s cadence
-- with the UKPuppet sentinel pattern (only overwrite if the current value is
-- still the one WE wrote; anything else means another system took over).
-- Recomputes from origSpeed each pass, so a retuned speedMult self-applies.
local function ApplyBoost( ent, state )
  if not state.origSpeed then return end
  local fw = state.framework
  if fw == "ultrakillbase" or fw == "drgbase" or fw == "nextbot_generic" then
    local curWalk = ent.WalkSpeed
    if state.lastAppliedSpeed == nil or curWalk == state.lastAppliedSpeed then
      local newWalk = state.origSpeed * state.speedMult
      ent.WalkSpeed = newWalk
      state.lastAppliedSpeed = newWalk
    end
    if state.origRunSpeed then
      local curRun = ent.RunSpeed
      if state.lastAppliedRun == nil or curRun == state.lastAppliedRun then
        local newRun = state.origRunSpeed * state.speedMult
        ent.RunSpeed = newRun
        state.lastAppliedRun = newRun
      end
    end
  elseif fw == "source_npc" or fw == "zbase" then
    local ok, curSpeed = pcall( ent.GetSaveValue, ent, "m_flSpeed" )
    curSpeed = ( ok and curSpeed ) or state.origSpeed
    if state.lastAppliedSpeed == nil or curSpeed == state.lastAppliedSpeed then
      local newSpeed = state.origSpeed * state.speedMult
      pcall( ent.SetSaveValue, ent, "m_flSpeed", newSpeed )
      state.lastAppliedSpeed = newSpeed
    end
  end
  -- vjbase: movement is anim-driven; AnimationPlaybackRate (set at apply) covers it.
end

local nextBoostTick = 0

hook.Add( "Think", "UKEnrage_SpeedTick", function()
  if CurTime() < nextBoostTick then return end
  nextBoostTick = CurTime() + 0.2

  for ent, state in pairs( UKEnrage.Targets ) do
    if IsValid( ent ) then
      ApplyBoost( ent, state )
    else
      UKEnrage.Targets[ ent ] = nil
    end
  end
end )

hook.Add( "EntityRemoved", "UKEnrage_EntCleanup", function( ent )
  UKEnrage.Targets[ ent ] = nil
end )

hook.Add( "PostCleanupMap", "UKEnrage_MapCleanup", function()
  for ent in pairs( UKEnrage.Targets ) do
    if IsValid( ent ) then UKEnrage.Remove( ent, { sound = false } ) end
  end
  UKEnrage.Targets = {}
end )

-- Death sweep: enrage ends when the enraged one dies (canon — the Unity
-- RageEffect is destroyed with its owner, which is what plays EnrageEnd).
-- Frameworks that keep the entity alive through a death anim (DrGBase
-- ragdollless deaths, Source NPC corpses) need this; plain removals are
-- caught by EntityRemoved above.
timer.Create( "UKEnrage_DeathSweep", 1, 0, function()
  for ent, state in pairs( UKEnrage.Targets ) do
    if not IsValid( ent ) then
      UKEnrage.Targets[ ent ] = nil
    elseif ( ent.Health and ent:Health() or 0 ) <= 0 then
      UKEnrage.Remove( ent )
    end
  end
end )

-- Convenience console commands (tool panel buttons). Same gate as uk_enrage_test.
local function CmdAllowed( ply )
  return not IsValid( ply ) or game.SinglePlayer() or ply:IsSuperAdmin()
end

local function OptsFromPlayer( ply )
  if not IsValid( ply ) then return {} end
  return {
    dmgMult   = math.max( ply:GetInfoNum( "ultrakill_enrage_apply_dmgscale", 1 ), 0.1 ),
    speedMult = math.max( ply:GetInfoNum( "ultrakill_enrage_apply_speedmult", 1.25 ), 0.1 ),
    animRate  = math.max( ply:GetInfoNum( "ultrakill_enrage_apply_animrate", 1.25 ), 0.1 ),
    aura      = ply:GetInfoNum( "ultrakill_enrage_apply_aura", 1 ) ~= 0,
    sound     = ply:GetInfoNum( "ultrakill_enrage_apply_sound", 1 ) ~= 0,
  }
end

concommand.Add( "uk_enrage_all", function( ply )
  if not CmdAllowed( ply ) then return end
  local n = UKEnrage.ApplyAll( OptsFromPlayer( ply ) )
  if IsValid( ply ) then ply:ChatPrint( "[UKEnrage] Enraged " .. n .. " NPC(s)." ) end
end )

concommand.Add( "uk_enrage_clearall", function( ply )
  if not CmdAllowed( ply ) then return end
  local n = UKEnrage.ClearAll()
  if IsValid( ply ) then ply:ChatPrint( "[UKEnrage] Cleared " .. n .. " NPC(s)." ) end
end )

end    -- if SERVER

-- =============================================================================
-- CLIENT: generic aura — 1:1 replica of ultrakillbase_enraged.lua visuals
-- for entities Kevin's DrawEnraged can't reach (non-UKBase frameworks and
-- attachment-less UKBase models). Anchored to WorldSpaceCenter instead of
-- attachment 1; lightning is not transform-locked (brief trail on fast
-- movers reads as part of the effect).
-- =============================================================================

if CLIENT then

local NW2 = UKEnrage.NW2
local mRageMat          = Material( "particles/ultrakill/RageEffect" )
local sLightningTexture = "particles/ultrakill/LightningDark"
local sDotTexture       = "particles/ultrakill/BloodDrop"
local cSprite           = Color( 255, 255, 255, 255 )
local EMIT_RATE         = 1      -- Kevin's fEnragedLightingEmissionRate

-- [ent] = { nextEmit }
local Aura = {}

-- Kevin's (De)ActivateParticles: 64 red BloodDrop dots flying outward.
local function Burst( ent, speedMin, speedMax, dieTime )
  local center = ent:WorldSpaceCenter()
  local emitter = ParticleEmitter( center )
  if not emitter then return end
  for i = 1, 64 do
    local p = emitter:Add( sDotTexture, center )
    if p then
      local f = math.Rand( 0.267, 0.62 )
      p:SetDieTime( dieTime )
      p:SetStartSize( 14 )
      p:SetEndSize( 0 )
      p:SetStartAlpha( 200 )
      p:SetEndAlpha( 200 )
      p:SetColor( 255 * f, 0, 0 )
      p:SetVelocity( VectorRand() * math.Rand( speedMin, speedMax ) )
      p:SetAirResistance( 0 )
      p:SetCollide( false )
    end
  end
  emitter:Finish()
end

local function EmitLightning( pos, radius )
  local emitter = ParticleEmitter( pos )
  if not emitter then return end
  for i = 1, 4 do
    local p = emitter:Add( sLightningTexture, pos )
    if p then
      p:SetDieTime( 1 )
      p:SetColor( 255, 0, 0 )
      p:SetStartAlpha( 200 )
      p:SetEndAlpha( 0 )
      p:SetStartSize( 90 * radius )
      p:SetEndSize( 100 * radius )
      p:SetRoll( math.rad( math.Rand( -360, 360 ) ) )
      p:SetCollide( false )
    end
  end
  emitter:Finish()
end

-- Discover aura-flagged entities (covers PVS entry / late join — NW2 bools
-- network automatically, so a plain periodic scan is the robust path).
timer.Create( "UKEnrage_AuraScan", 0.5, 0, function()
  for _, ent in ipairs( ents.GetAll() ) do
    if not Aura[ ent ] and ent:GetNW2Bool( NW2.Aura, false ) then
      Aura[ ent ] = { nextEmit = 0 }
      -- Activation burst only for a fresh apply, not for auras first seen
      -- long after (walked into PVS, late join).
      if CurTime() - ent:GetNW2Float( NW2.AppliedAt, 0 ) < 1.5 then
        Burst( ent, 228, 428, 0.5 )
      end
    end
  end
end )

hook.Add( "PostDrawTranslucentRenderables", "UKEnrage_AuraDraw", function( bDepth, bSkybox )
  if bDepth or bSkybox then return end

  for ent, state in pairs( Aura ) do
    if not IsValid( ent ) or not ent:GetNW2Bool( NW2.Aura, false ) then
      if IsValid( ent ) then Burst( ent, 128, 228, 0.7 ) end    -- deactivate edge
      Aura[ ent ] = nil
    elseif not ent:IsDormant() then
      local pos = ent:WorldSpaceCenter()
      local radius = ent:GetNW2Float( NW2.Radius, 1 )

      render.SetMaterial( mRageMat )
      render.DrawSprite( pos, 100 * radius, 100 * radius, cSprite )

      if CurTime() >= state.nextEmit then
        EmitLightning( pos, radius )
        state.nextEmit = CurTime() + EMIT_RATE
      end
    end
  end
end )

end    -- if CLIENT
