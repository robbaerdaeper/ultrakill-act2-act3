-- lua/weapons/gmod_tool/stools/ultrakill_idol_bind.lua

-- Same category name ultrakillbase uses so all tools merge into one list;
-- a shim in ultrakill_test_options_menu.lua retabs Kevin's tools to DrGBase.
TOOL.Tab        = "DrGBase"
TOOL.Category   = "Tools - ULTRAKILL"
TOOL.Name       = "#tool.ultrakill_idol_bind.name"
TOOL.ConfigName = ""
TOOL.ClientConVar = {}

TOOL.Information = {
  { name = "left" },
  { name = "right" },
  { name = "reload" },
}

if CLIENT then
  language.Add( "tool.ultrakill_idol_bind.name", "Idol Bind" )
  language.Add( "tool.ultrakill_idol_bind.desc",
    "Force an Idol to bless any chosen entity" )
  language.Add( "tool.ultrakill_idol_bind.left", "Select an Idol" )
  language.Add( "tool.ultrakill_idol_bind.right",
    "Force-bless the target entity" )
  language.Add( "tool.ultrakill_idol_bind.reload", "Clear the manual bond" )
end


if SERVER then

function TOOL:LeftClick( trace )
  local ply = self:GetOwner()
  if not IsValid( trace.Entity ) then return false end
  if trace.Entity:GetClass() ~= "ultrakill_test_idol" then
    ply:ChatPrint( "[UKIdol] Click an Idol first." )
    return false
  end
  ply.UKIdol_ToolSelected = trace.Entity
  ply:ChatPrint( "[UKIdol] Selected idol #" .. trace.Entity:EntIndex() ..
                 ". Right-click any entity to force-bless. Reload to clear." )
  return true
end


function TOOL:RightClick( trace )
  local ply = self:GetOwner()
  local idol = ply.UKIdol_ToolSelected

  if not IsValid( idol ) or idol:GetClass() ~= "ultrakill_test_idol" then
    ply:ChatPrint( "[UKIdol] Left-click an Idol first." )
    return false
  end

  if not IsValid( trace.Entity ) then
    ply:ChatPrint( "[UKIdol] No valid target." )
    return false
  end

  -- Manual bind bypasses IsValidTarget — works on props, vehicles, friendlies, players
  UKIdol.Bind( idol, trace.Entity, true )
  ply:ChatPrint( "[UKIdol] Idol #" .. idol:EntIndex() ..
                 " now blessing " .. trace.Entity:GetClass() ..
                 " #" .. trace.Entity:EntIndex() )
  return true
end


function TOOL:Reload( trace )
  local ply = self:GetOwner()
  local idol = ply.UKIdol_ToolSelected
  if IsValid( idol ) then
    UKIdol.Unbind( idol )
    idol.UKIdol_ManualBond = false
    ply:ChatPrint( "[UKIdol] Cleared bond on idol #" .. idol:EntIndex() )
  end
  return true
end

end


function TOOL.BuildCPanel( panel )
  panel:Help(
    "Force any Idol to bless any chosen entity.\n\n" ..
    "1. LEFT CLICK on an Idol — selects it.\n" ..
    "2. RIGHT CLICK on any entity (NPC, prop, vehicle, even friendlies/players) — Idol force-binds to it.\n" ..
    "3. RELOAD — clears the manual bond, Idol resumes auto-target picking.\n\n" ..
    "Manual bonds bypass rank/eligibility filters."
  )
end
