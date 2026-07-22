if not SERVER then return end

-- Cross-Stalker target reservation table.
-- Canon `StalkerController.targets` (StalkerController.cs:6) — one Stalker per target.
UKStalker = UKStalker or {}
UKStalker.targets = UKStalker.targets or {}  -- weak-keyed map: target_ent -> stalker_ent

setmetatable( UKStalker.targets, { __mode = "k" } )

function UKStalker.IsTaken( target )
  if not IsValid( target ) then return false end
  local owner = UKStalker.targets[ target ]
  return IsValid( owner )
end

function UKStalker.Owner( target )
  return UKStalker.targets[ target ]
end

-- Reserve `target` for `stalker`. FIRST releases all prior reservations owned by this stalker
-- (matches canon ChangeTarget() ordering — remove old, then add new).
function UKStalker.Reserve( stalker, target )
  if not IsValid( stalker ) or not IsValid( target ) then return end
  -- Drop everything owned by this stalker
  for t, o in pairs( UKStalker.targets ) do
    if o == stalker then UKStalker.targets[ t ] = nil end
  end
  -- Register the new one
  UKStalker.targets[ target ] = stalker
end

function UKStalker.Release( stalker, target )
  if IsValid( target ) and UKStalker.targets[ target ] == stalker then
    UKStalker.targets[ target ] = nil
  end
end

-- EntityRemoved → cleanup. Drop entries for the removed ent regardless of role.
hook.Add( "EntityRemoved", "UKStalker_Cleanup", function( ent )
  if not IsValid( ent ) then return end
  if UKStalker.targets[ ent ] then UKStalker.targets[ ent ] = nil end
  -- Also drop entries owned by the removed stalker
  for t, o in pairs( UKStalker.targets ) do
    if o == ent then UKStalker.targets[ t ] = nil end
  end
end )

-- 5s sanity sweep — kill stale entries that survived hook misses (defensive).
timer.Create( "UKStalker_Sweep", 5, 0, function()
  for t, o in pairs( UKStalker.targets ) do
    if not IsValid( t ) or not IsValid( o ) then UKStalker.targets[ t ] = nil end
  end
end )
