-- ULTRAKILL Puppet Apply tool.
-- LMB on entity → apply Puppeted (idempotent refresh if already applied).
-- RMB on entity → cleanse Puppeted.
-- R  on player  → toggle self-puppet (reads UKPuppet.IsApplied at-press, no caching).

-- Same category name ultrakillbase uses so all tools merge into one list;
-- a shim in ultrakill_test_options_menu.lua retabs Kevin's tools to DrGBase.
TOOL.Tab        = "DrGBase"
TOOL.Category   = "Tools - ULTRAKILL"
TOOL.Name       = "#tool.ultrakill_puppet_apply.name"
TOOL.ConfigName = ""
TOOL.ClientConVar = {}

TOOL.Information = {
  { name = "left" },
  { name = "right" },
  { name = "reload" },
}

if CLIENT then
  language.Add( "tool.ultrakill_puppet_apply.name", "Puppet Apply" )
  language.Add( "tool.ultrakill_puppet_apply.desc",
    "Turn any entity into a Deathcatcher puppet" )
  language.Add( "tool.ultrakill_puppet_apply.left", "Puppet the target" )
  language.Add( "tool.ultrakill_puppet_apply.right",
    "Cleanse a puppeted target" )
  language.Add( "tool.ultrakill_puppet_apply.reload",
    "Toggle self-puppet on yourself" )
end

if SERVER then

function TOOL:LeftClick( trace )
  local ply = self:GetOwner()
  local ent = trace.Entity
  if not IsValid( ent ) then
    ply:ChatPrint( "[UKPuppet] No target." )
    return false
  end
  if not UKPuppet.IsValidTarget( ent ) then
    ply:ChatPrint( "[UKPuppet] Cannot puppet that target." )
    return false
  end
  -- Per ULTRAKILL wiki canon: enemies turned into puppets form from a pool of blood,
  -- same as fresh Puppet spawns. Use the full spawn FX (not the lighter overlay).
  if UKPuppet.Apply( ent, ply, { fxLevel = "spawn" } ) then
    ply:ChatPrint( "[UKPuppet] Puppeted " .. ent:GetClass() .. " #" .. ent:EntIndex() )
    return true
  end
  return false
end

function TOOL:RightClick( trace )
  local ply = self:GetOwner()
  local ent = trace.Entity
  if not IsValid( ent ) then
    ply:ChatPrint( "[UKPuppet] No target." )
    return false
  end
  if not UKPuppet.IsApplied( ent ) then
    ply:ChatPrint( "[UKPuppet] Not puppeted." )
    return false
  end
  UKPuppet.Cleanse( ent )
  ply:ChatPrint( "[UKPuppet] Cleansed " .. ent:GetClass() .. " #" .. ent:EntIndex() )
  return true
end

function TOOL:Reload( trace )
  local ply = self:GetOwner()
  -- Read at-press (no cached state). Toggle self-puppet.
  if UKPuppet.IsApplied( ply ) then
    UKPuppet.Cleanse( ply )
    ply:ChatPrint( "[UKPuppet] Self-puppet OFF" )
  else
    UKPuppet.Apply( ply, ply, { fxLevel = "spawn" } )
    ply:ChatPrint( "[UKPuppet] Self-puppet ON (2× damage taken, 0.75× speed)" )
  end
  return true
end

end    -- if SERVER

function TOOL.BuildCPanel( panel )
  panel:Help(
    "Apply ULTRAKILL Puppeted status to any entity.\n\n" ..
    "LEFT CLICK on NPC/player/prop  — apply Puppeted (red translucent + 2× damage taken + 0.75× slow).\n" ..
    "RIGHT CLICK on puppeted target  — cleanse.\n" ..
    "RELOAD (R)                      — toggle self-puppet on yourself.\n\n" ..
    "Cross-NPC: works on UltrakillBase / DrGBase / ZBase / Source NPCs / Players / props.\n" ..
    "VJBase: visual + damage only (slow not supported).\n" ..
    "Persists until target death."
  )
end
