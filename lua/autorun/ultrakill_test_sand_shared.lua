-- UKSand global API (shared client/server).
-- Manages the Sandified status (canon Sandify): networked NW2 flags + helpers.

UKSand = UKSand or {}

-- Per-class opt-in registry for non-UltrakillBase nextbots (HL2 NPCs, VJ, ZBase, generic).
-- Default: anything that is an UltrakillBase nextbot is sandable (handled by IsSandable).
UKSand.RegisteredClasses = UKSand.RegisteredClasses or {}

UKSand.NW2 = {
  Sand     = "UltrakillBase_Sand",
  Sandable = "UltrakillBase_Sandable",
}

function UKSand.IsSand( ent )
  if not IsValid( ent ) then return false end
  return ent:GetNW2Bool( UKSand.NW2.Sand, false )
end

function UKSand.IsSandable( ent )
  if not IsValid( ent ) then return false end
  -- Explicit per-instance opt-out (Stalker uses this to disable re-sandification of itself)
  if ent:GetNW2Bool( UKSand.NW2.Sandable, true ) == false then return false end
  if ent.IsUltrakillNextbot then return true end
  local cls = ent:GetClass()
  if UKSand.RegisteredClasses[ cls ] then return true end
  return false
end

function UKSand.RegisterClass( cls, sandable )
  UKSand.RegisteredClasses[ cls ] = sandable and true or false
end

-- Stalker AI target filter (canon Stalker.cs:178-200).
-- Returns true if `ent` is a valid pursuit target for `stalker`.
function UKSand.IsValidStalkerTarget( ent, stalker )
  if not IsValid( ent ) then return false end
  if ent == stalker then return false end
  if ent:IsPlayer() then return false end   -- player is the fallback in SlowUpdate
  if not ( ent:IsNPC() or ent:IsNextBot() ) then return false end
  local hp = ent.Health and ent:Health() or 0
  if hp <= 0 then return false end

  -- Canon exclusions:
  if UKSand.IsSand( ent ) then return false end  -- already sand (incl. other Stalkers)
  if UKPuppet and UKPuppet.IsApplied and UKPuppet.IsApplied( ent ) then return false end
  if ent:GetClass() == "ultrakill_test_deathcatcher" then return false end
  -- NOTE: blessed targets ARE valid (canon Stalker.cs:182 does not filter blessed)

  -- Flying enemies excluded (canon `currentEnemies[i].flying`). We approximate via class table.
  local flyingClasses = {
    ultrakill_test_drone           = true,
    ultrakill_drone                = true,
    ultrakill_mindflayer           = true,
    ultrakill_maliciousface        = true,
    ultrakill_maliciousface_normal = true,
    ultrakill_virtue               = true,
    ultrakill_idol                 = true,  -- Idol floats per canon Idol.cs
    ultrakill_test_idol            = true,
  }
  if flyingClasses[ ent:GetClass() ] then return false end

  -- Rank check via UKIdol's cross-mod ranking API.
  if UKIdol and UKIdol.GetRank then
    local rank = UKIdol.GetRank( ent )
    if not rank or rank < 0 then return false end
  end

  return true
end
