-- ULTRAKILL Puppet — client-side render layer.
-- Material override + bone jitter + spawn rise (root-bone translation).

if not UKPuppet then return end
if SERVER then return end

local AMP_BASE  = 2.0
local SPEED     = 6.0
local VEL_REF   = 300
local AMP_MAX_X = 3.0

local SPAWN_RISE_DUR = 0.8

UKPuppet.PuppetIMaterial = UKPuppet.PuppetIMaterial or Material( UKPuppet.PuppetMaterial )

local DBG = false
local function dbg( fmt, ... )
  if not DBG then return end
  print( string.format( "[UKPuppet/render] " .. fmt, ... ) )
end

local function GetSink( ent )
  local spawnedAt = ent:GetNW2Float( UKPuppet.NW2.SpawnedAt, 0 )
  if spawnedAt <= 0 then return 0 end
  local riseT = math.Clamp( ( CurTime() - spawnedAt ) / SPAWN_RISE_DUR, 0, 1 )
  if riseT >= 1 then return 0 end
  local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
  local bodyH = ( maxs.z - mins.z ) or 72
  return ( 1 - riseT ) * bodyH
end

-- =============================================================================
-- RenderOverride. During rise, body is lowered via root-bone translation —
-- that puts geometry inside the floor where engine ambient samples come back
-- as pure black (this is what made DrGBase NPCs go black). Force a baseline
-- ambient via ResetModelLighting + fullbright via SuppressEngineLighting so
-- the rising body is visible. Restore once rise completes.
-- =============================================================================

local function PuppetRenderOverride( self, flags )
  if not IsValid( self ) then return end
  if not self:GetNW2Bool( UKPuppet.NW2.Active, false ) then
    if self.UKPuppet_LastRenderState ~= "inactive" then
      dbg( "ent=%d cls=%s → INACTIVE (NW2 cleared, restoring orig RenderOverride=%s)",
           self:EntIndex(), self:GetClass(), tostring( self.UKPuppet_OrigRenderOverride ~= nil ) )
      self.UKPuppet_LastRenderState = "inactive"
    end
    self.RenderOverride = self.UKPuppet_OrigRenderOverride
    self.UKPuppet_OrigRenderOverride = nil
    -- Clear the attach flag too — NW2 can momentarily read false on dormancy /
    -- PVS re-entry; without this the Think loop saw a stale "attached" flag
    -- and never re-installed the override (puppet stayed visually normal).
    self.UKPuppet_OverrideAttached = nil
    self:DrawModel( flags )
    return
  end

  -- Single unified draw path while puppeted: suppress engine lighting and force
  -- bright red colormod. We can't trust the per-entity ambient cube (UB/DrGBase
  -- nextbots don't run RenderOverride and their draw hooks don't set up the
  -- ambient probe correctly for our $rimlight material → one side goes black).
  -- This costs us "puppet reacts to room light" but guarantees uniform read.
  local sink = GetSink( self )
  local state = sink > 0 and "rise" or "normal"
  if self.UKPuppet_LastRenderState ~= state then
    dbg( "ent=%d cls=%s → %s (sink=%.1f, hasOrigOverride=%s)",
         self:EntIndex(), self:GetClass(), state, sink,
         tostring( self.UKPuppet_OrigRenderOverride ~= nil ) )
    self.UKPuppet_LastRenderState = state
  end

  render.SuppressEngineLighting( true )
  render.SetColorModulation( 1.4, 0.45, 0.45 )
  render.MaterialOverride( UKPuppet.PuppetIMaterial )
  self:DrawModel( flags )
  render.MaterialOverride()
  render.SetColorModulation( 1, 1, 1 )
  render.SuppressEngineLighting( false )
end

local function AttachOverride( ent )
  -- Compare against the actual field instead of a one-shot flag: an NPC base or
  -- another addon may overwrite ent.RenderOverride after us (and our own
  -- inactive path in PuppetRenderOverride legitimately removes it on a
  -- momentary NW2 dropout) — in both cases we must re-install next Think.
  if ent.RenderOverride == PuppetRenderOverride then return end
  ent.UKPuppet_OrigRenderOverride = ent.RenderOverride
  ent.RenderOverride = PuppetRenderOverride
  ent.UKPuppet_OverrideAttached = true
  dbg( "ATTACH ent=%d cls=%s (origRenderOverride captured: %s)",
       ent:EntIndex(), ent:GetClass(), tostring( ent.UKPuppet_OrigRenderOverride ~= nil ) )
end

local function DetachOverride( ent )
  if not ent.UKPuppet_OverrideAttached then return end
  dbg( "DETACH ent=%d cls=%s (restoring orig=%s)",
       ent:EntIndex(), ent:GetClass(), tostring( ent.UKPuppet_OrigRenderOverride ~= nil ) )
  ent.RenderOverride = ent.UKPuppet_OrigRenderOverride
  ent.UKPuppet_OrigRenderOverride = nil
  ent.UKPuppet_OverrideAttached = nil
  ent.UKPuppet_LastRenderState = nil
end

-- =============================================================================
-- Bone jitter + rise. Rise translates root bone down by `sink`; child bones
-- inherit, so the entire skeleton shifts. Collision/AI stay at GetPos. Map BSP
-- naturally clips the buried portion → "growing out of the puddle" silhouette.
-- =============================================================================

local function ApplyBoneJitter( ent )
  if not IsValid( ent ) then return end
  if not ent:GetNW2Bool( UKPuppet.NW2.Active, false ) then return end

  local boneCount = ent:GetBoneCount() or 0
  if boneCount <= 0 then return end
  if ent:IsRagdoll() then return end
  local cls = ent:GetClass()
  if cls == "prop_ragdoll" or cls == "gmod_hands" or cls == "predicted_viewmodel" then return end

  ent:SetupBones()

  local vel = ent:GetVelocity():Length()
  local velScale = math.Clamp( vel / VEL_REF, 1.0, AMP_MAX_X )
  local amp = AMP_BASE * velScale
  local t = RealTime() * SPEED

  local sink = GetSink( ent )

  for b = 0, boneCount - 1 do
    local seed = b * 0.7
    local off = Vector(
      math.sin( t + seed ) * amp,
      math.cos( t + seed * 1.3 ) * amp,
      math.sin( t + seed * 0.7 ) * amp * 0.5
    )
    if b == 0 and sink > 0 then
      off.z = off.z - sink
    end
    ent:ManipulateBonePosition( b, off )
  end
end

local function ClearBoneJitter( ent )
  if not IsValid( ent ) then return end
  local boneCount = ent:GetBoneCount() or 0
  if boneCount <= 0 then return end
  for b = 0, boneCount - 1 do
    ent:ManipulateBonePosition( b, vector_origin )
  end
end

-- =============================================================================
-- Per-entity puppet additive bloom/pulse.
-- Called by the status_layering coordinator (Task 14) once per frame per entity
-- that has the puppet status. Draws a second model pass in additive mode with a
-- time-pulsed red glow on top of the base material override that RenderOverride
-- already applied. ENT.RenderOverride is untouched — it handles the base body
-- material swap and stays in place.
-- =============================================================================

local PULSE_SPEED = 3.0
local PULSE_MIN   = 0.05
local PULSE_MAX   = 0.18

local mPuppetAdd = Material( UKPuppet.PuppetMaterial )

function UKPuppet.RenderPuppetLayer( ent )
  if not IsValid( ent ) then return end
  if not UKPuppet.IsApplied( ent ) then return end
  if ent:IsDormant() then return end

  -- Pulsing additive pass: sin-wave alpha between PULSE_MIN and PULSE_MAX gives a
  -- soft bloom shimmer on top of the red body without obscuring sand / bless layers.
  local alpha = PULSE_MIN + ( PULSE_MAX - PULSE_MIN ) * ( 0.5 + 0.5 * math.sin( RealTime() * PULSE_SPEED ) )

  render.SetBlend( alpha )
  render.MaterialOverride( mPuppetAdd )
  render.ModelMaterialOverride( mPuppetAdd )
  local oldAM = render.GetAlphaMode and render.GetAlphaMode()
  -- Draw additive on top of base pass.
  render.SetColorModulation( 1.4, 0.45, 0.45 )
  ent:DrawModel()
  render.SetColorModulation( 1, 1, 1 )
  render.ModelMaterialOverride( nil )
  render.MaterialOverride()
  render.SetBlend( 1 )
end

-- =============================================================================

local LastApplied = {}

hook.Add( "Think", UKPuppet.Hooks.Render, function()
  for _, ent in ipairs( ents.GetAll() ) do
    if IsValid( ent ) and ent:GetNW2Bool( UKPuppet.NW2.Active, false ) then
      AttachOverride( ent )
      ApplyBoneJitter( ent )
      LastApplied[ ent ] = true
    end
  end

  for ent, _ in pairs( LastApplied ) do
    if not IsValid( ent ) or not ent:GetNW2Bool( UKPuppet.NW2.Active, false ) then
      if IsValid( ent ) then
        DetachOverride( ent )
        ClearBoneJitter( ent )
      end
      LastApplied[ ent ] = nil
    end
  end
end )
