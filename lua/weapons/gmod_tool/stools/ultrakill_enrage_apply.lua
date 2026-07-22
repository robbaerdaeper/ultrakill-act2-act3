-- ULTRAKILL Enrage tool.
-- LMB on NPC → enrage (idempotent refresh retunes the damage multiplier).
-- RMB on NPC → un-enrage (also force-clears natively self-enraged UKBase NPCs).
-- R          → enrage every NPC on the map.
-- Works on UltrakillBase / DrGBase / VJBase / ZBase / Source NPCs / generic nextbots.

-- Same category name ultrakillbase uses so all tools merge into one list;
-- a shim in ultrakill_test_options_menu.lua retabs Kevin's tools to DrGBase.
TOOL.Tab        = "DrGBase"
TOOL.Category   = "Tools - ULTRAKILL"
TOOL.Name       = "#tool.ultrakill_enrage_apply.name"
TOOL.ConfigName = ""
-- NB: the damage convar was renamed dmgmult -> dmgscale when its default
-- changed 2 -> 1 (canon): tool convars are archived client-side, so the old
-- name would keep resurrecting the saved "2" over the new default.
TOOL.ClientConVar = {
  dmgscale  = "1",
  speedmult = "1.25",
  animrate  = "1.25",
  aura      = "1",
  sound     = "1",
}

TOOL.Information = {
  { name = "left" },
  { name = "right" },
  { name = "reload" },
}

if CLIENT then
  language.Add( "tool.ultrakill_enrage_apply.name", "Enrage" )
  language.Add( "tool.ultrakill_enrage_apply.desc",
    "Apply the ULTRAKILL Enraged status to any NPC" )
  language.Add( "tool.ultrakill_enrage_apply.left", "Enrage the target" )
  language.Add( "tool.ultrakill_enrage_apply.right", "Un-enrage the target" )
  language.Add( "tool.ultrakill_enrage_apply.reload", "Enrage ALL NPCs on the map" )
end

if SERVER then

local function OptsFromTool( tool )
  return {
    dmgMult   = math.max( tool:GetClientNumber( "dmgscale", 1 ), 0.1 ),
    speedMult = math.max( tool:GetClientNumber( "speedmult", 1.25 ), 0.1 ),
    animRate  = math.max( tool:GetClientNumber( "animrate", 1.25 ), 0.1 ),
    aura      = tool:GetClientNumber( "aura", 1 ) ~= 0,
    sound     = tool:GetClientNumber( "sound", 1 ) ~= 0,
  }
end

function TOOL:LeftClick( trace )
  local ply = self:GetOwner()
  local ent = trace.Entity
  if not IsValid( ent ) then
    ply:ChatPrint( "[UKEnrage] No target." )
    return false
  end
  if not UKEnrage.IsValidTarget( ent ) then
    ply:ChatPrint( "[UKEnrage] Cannot enrage that target (NPCs only)." )
    return false
  end
  local refreshed = UKEnrage.IsApplied( ent )
  if UKEnrage.Apply( ent, OptsFromTool( self ) ) then
    ply:ChatPrint( "[UKEnrage] " .. ( refreshed and "Retuned " or "Enraged " )
      .. ent:GetClass() .. " #" .. ent:EntIndex() )
    return true
  end
  return false
end

function TOOL:RightClick( trace )
  local ply = self:GetOwner()
  local ent = trace.Entity
  if not IsValid( ent ) then
    ply:ChatPrint( "[UKEnrage] No target." )
    return false
  end
  if UKEnrage.Remove( ent, { sound = self:GetClientNumber( "sound", 1 ) ~= 0 } ) then
    ply:ChatPrint( "[UKEnrage] Un-enraged " .. ent:GetClass() .. " #" .. ent:EntIndex() )
    return true
  end
  ply:ChatPrint( "[UKEnrage] Target is not enraged." )
  return false
end

function TOOL:Reload( trace )
  local ply = self:GetOwner()
  local n = UKEnrage.ApplyAll( OptsFromTool( self ) )
  ply:ChatPrint( "[UKEnrage] Enraged " .. n .. " NPC(s)." )
  return n > 0
end

end    -- if SERVER

function TOOL.BuildCPanel( panel )
  panel:Help(
    "Apply the ULTRAKILL Enraged status to any NPC.\n\n" ..
    "LEFT CLICK  — enrage the target (re-click to retune the multiplier).\n" ..
    "RIGHT CLICK — un-enrage (also clears self-enraged ULTRAKILL enemies).\n" ..
    "RELOAD (R)  — enrage every NPC on the map.\n\n" ..
    "ULTRAKILL enemies get their canon enraged behavior + Kevin's aura; " ..
    "other NPCs (DrGBase / VJBase / ZBase / HL2 / nextbots) get a matching " ..
    "aura and the damage / speed boosts.\n" ..
    "Enrage ends on death (canon EnrageEnd burst + sound)."
  )
  panel:NumSlider( "Damage multiplier", "ultrakill_enrage_apply_dmgscale", 1, 10, 1 )
  panel:ControlHelp( "NOT canon — Enraged never boosts damage in ULTRAKILL "
    .. "(that's Radiance). Kept at 1 by default; raise for extra chaos." )
  panel:NumSlider( "Attack / anim speed", "ultrakill_enrage_apply_animrate", 1, 3, 2 )
  panel:ControlHelp( "Animation rate: ULTRAKILL enemies without a canon enrage rate + VJBase. "
    .. "Canon rates (Cerberus 1.35 etc) are never overridden." )
  panel:NumSlider( "Movement speed", "ultrakill_enrage_apply_speedmult", 1, 3, 2 )
  panel:ControlHelp( "Walk/run speed of the enraged NPC (all bases except VJBase)." )
  panel:CheckBox( "Rage aura visual", "ultrakill_enrage_apply_aura" )
  panel:CheckBox( "Enrage sounds (start / loop / end)", "ultrakill_enrage_apply_sound" )
  panel:Button( "Enrage ALL NPCs", "uk_enrage_all" )
  panel:Button( "Clear ALL", "uk_enrage_clearall" )
end
