-- ULTRAKILL Puppet — UltrakillBase nextbot ENT method extension.
-- Adds Set/Get/IsPuppet/Puppet/Unpuppet methods to ultrakillbase_nextbot.
-- Methods are THIN ADAPTERS — they read/write the same UKPuppet.Targets registry,
-- so there is no double-state drift. Adapter writes go through _ApplyInternal /
-- _CleanseInternal primitives (NOT public Apply/Cleanse) to avoid recursion.

if not UKPuppet then return end    -- shared file must load first

local function InstallPuppetMethods( ENT )
  if not ENT then return end
  if ENT.UKPuppet_Installed then return end
  ENT.UKPuppet_Installed = true

  function ENT:SetPuppet( bool )
    if not SERVER then return end
    if bool then
      UKPuppet._ApplyInternal( self, self, {} )
    else
      UKPuppet._CleanseInternal( self )
    end
  end

  function ENT:GetPuppet() return UKPuppet.IsApplied( self ) end
  function ENT:IsPuppet()  return UKPuppet.IsApplied( self ) end

  function ENT:Puppet()    self:SetPuppet( true )  end
  function ENT:Unpuppet()  self:SetPuppet( false ) end
end

-- Install on InitPostEntity (after upstream UB has registered ENT).
hook.Add( "InitPostEntity", "UKPuppet_InstallUBExt", function()
  local base = baseclass.Get( "ultrakillbase_nextbot" )
  if base then InstallPuppetMethods( base ) end
end )

-- Also install if UB is already loaded (e.g., on lua_openscript reload).
timer.Simple( 1, function()
  local base = baseclass.Get( "ultrakillbase_nextbot" )
  if base then InstallPuppetMethods( base ) end
end )
