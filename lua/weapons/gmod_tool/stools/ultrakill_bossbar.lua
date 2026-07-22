-- lua/weapons/gmod_tool/stools/ultrakill_bossbar.lua
-- ULTRAKILL boss HP bar for ANY NPC (DrGBase, VJBase, HL2, nextbots, players).
-- Two naming modes: auto (spawnmenu display name) or custom text.
-- Splits slider = layered phases like multi-phase bosses (each deeper layer
-- darker red, base behaviour). Applied via UltrakillBase.UKToolAddBoss
-- (client receiver in ultrakill_bossbar_stack.lua) so entities with their own
-- secondary bar (Geryon heat meter) keep it on re-apply.

-- Same category name ultrakillbase uses so all tools merge into one list;
-- a shim in ultrakill_test_options_menu.lua retabs Kevin's tools to DrGBase.
TOOL.Tab        = "DrGBase"
TOOL.Category   = "Tools - ULTRAKILL"
TOOL.Name       = "#tool.ultrakill_bossbar.name"
TOOL.ConfigName = ""

TOOL.ClientConVar = {
  custom = "0",
  name   = "",
  splits = "1",
}

TOOL.Information = {
  { name = "left" },
  { name = "right" },
  { name = "reload" },
}

if CLIENT then
  language.Add( "tool.ultrakill_bossbar.name", "Boss Bar" )
  language.Add( "tool.ultrakill_bossbar.desc",
    "Give any NPC an ULTRAKILL boss HP bar" )
  language.Add( "tool.ultrakill_bossbar.left", "Apply boss bar to target" )
  language.Add( "tool.ultrakill_bossbar.right", "Remove target's boss bar" )
  language.Add( "tool.ultrakill_bossbar.reload", "Remove all bars applied by this tool" )
end


if SERVER then

local function IsEligible( ent )
  return IsValid( ent ) and ( ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer() )
end


local function PrettyClass( class )
  local n = class
    :gsub( "^npc_", "" )
    :gsub( "^monster_", "" )
    :gsub( "^drgbase_", "" )
    :gsub( "^ultrakill_test_", "" )
    :gsub( "^ultrakill_", "" )
  return ( n:gsub( "_", " " ) )
end


-- Display name like the spawnmenu shows it: direct list.Get("NPC") key first
-- (DrGBase/VJBase register by class), then any entry with matching .Class
-- (HL2 variants), then the entity's own PrintName, then prettified class.
local function AutoName( ent )

  if ent:IsPlayer() then return ent:Nick() end

  local class = ent:GetClass()
  local npcs = list.Get( "NPC" )

  local def = npcs[ class ]
  if istable( def ) and isstring( def.Name ) and def.Name ~= "" then return def.Name end

  for _, t in pairs( npcs ) do
    if istable( t ) and t.Class == class and isstring( t.Name ) and t.Name ~= "" then
      return t.Name
    end
  end

  if isstring( ent.PrintName ) and ent.PrintName ~= "" then return ent.PrintName end

  return PrettyClass( class )

end


function TOOL:LeftClick( trace )

  local ply = self:GetOwner()
  local ent = trace.Entity

  if not IsEligible( ent ) then return false end

  if not UltrakillBase or not UltrakillBase.CallOnClient then
    ply:ChatPrint( "[BossBar] ULTRAKILL Base is required." )
    return false
  end

  -- имя не апперкейсим и токены "#npc_*" не трогаем: перевод и ToUpper
  -- делает клиентский приёмник UKToolAddBoss (language.GetPhrase есть
  -- только на клиенте, и у каждого игрока свой язык)
  local title
  if self:GetClientNumber( "custom", 0 ) == 1 then
    title = string.Trim( self:GetClientInfo( "name" ) )
  end
  if not title or title == "" then title = AutoName( ent ) end

  local splits = math.Clamp( math.floor( self:GetClientNumber( "splits", 1 ) ), 1, 10 )

  -- у части NPC MaxHealth 0 или меньше текущего HP — бар делит на MaxHP
  if ent:GetMaxHealth() < math.max( ent:Health(), 1 ) then
    ent:SetMaxHealth( math.max( ent:Health(), 1 ) )
  end

  UltrakillBase.CallOnClient( "UKToolAddBoss", ent, title, splits )
  ent.UKBossBar_ToolApplied = true

  ply:ChatPrint( ( '[BossBar] "%s" — %d phase(s).' ):format( ( title:gsub( "^#", "" ) ), splits ) )
  return true

end


function TOOL:RightClick( trace )

  local ent = trace.Entity
  if not IsValid( ent ) or not UltrakillBase then return false end

  UltrakillBase.RemoveBoss( ent )
  ent.UKBossBar_ToolApplied = nil

  self:GetOwner():ChatPrint( "[BossBar] Bar removed from " .. ent:GetClass() .. "." )
  return true

end


function TOOL:Reload( trace )

  if not UltrakillBase then return false end

  local n = 0
  for _, ent in ipairs( ents.GetAll() ) do
    if ent.UKBossBar_ToolApplied then
      UltrakillBase.RemoveBoss( ent )
      ent.UKBossBar_ToolApplied = nil
      n = n + 1
    end
  end

  self:GetOwner():ChatPrint( ( "[BossBar] Removed %d tool bar(s)." ):format( n ) )
  return true

end

end


function TOOL.BuildCPanel( panel )

  panel:Help(
    "Give any NPC an ULTRAKILL-style boss HP bar.\n\n" ..
    "LEFT CLICK — apply the bar (works on DrGBase / VJBase / HL2 NPCs, " ..
    "nextbots and players).\n" ..
    "RIGHT CLICK — remove the target's bar (including built-in boss bars).\n" ..
    "RELOAD — remove every bar applied with this tool."
  )

  panel:CheckBox( "Use custom name (text below)", "ultrakill_bossbar_custom" )
  panel:TextEntry( "Custom name", "ultrakill_bossbar_name" )
  panel:ControlHelp( "Unchecked = name is taken from the spawn menu automatically." )

  panel:NumSlider( "Phases (HP layers)", "ultrakill_bossbar_splits", 1, 10, 0 )
  panel:ControlHelp(
    "Splits the bar into stacked phase layers — each deeper layer is a " ..
    "darker red, like multi-phase bosses in ULTRAKILL."
  )

  panel:Help(
    "With more than 2 bars on screen, all bars shrink to fit the top of the " ..
    "screen — same behaviour as ULTRAKILL."
  )

end
