if not SERVER then return end

-- =============================================================================
-- Compatibility shims for third-party ULTRAKILL ecosystem addons.
-- Lives in OUR addon so the workshop copies stay unmodified (no extracted
-- folder overrides in garrysmod/addons/).
-- =============================================================================

-- UltrakillBase × ukdash: RefreshStamina does net.Start("ULTRAKILL_UpdateStaminaCount")
-- but the base addon never pools the string (no receiver exists in current ukdash —
-- client reads AbilityStamina via NW2Int hook). Without pooling every stamina
-- refresh spams "Calling net.Start with unpooled message name" warnings.
-- Pooling it here is idempotent and safe even if the base addon adds it later.
-- (Was previously a local patch inside an extracted addons/ultrakillbase copy —
-- relocated 2026-06-10 when that copy was removed in favour of the workshop sub.)
util.AddNetworkString( "ULTRAKILL_UpdateStaminaCount" )

-- Player → ULTRAKILL-NPC damage at 3x: drg_ultrakill_plydmgmult ships at 1
-- (the base's convar help text suggests 4 for HL2-style weapons; 3 here).
-- Only the untouched factory default is bumped — any user-tuned value (≠ 1) is
-- left alone. NOTE: setting the slider back to exactly 1 will bounce to 3 on
-- next map load; use 0.999/1.001 if raw base scaling is ever wanted.
-- (Idol/Deathcatcher are unaffected by design — they override
-- GetDamageMultiplierConVar to take raw weapon damage.)
hook.Add( "InitPostEntity", "UKTest_PlyDmgMult3x", function()
  local cv = GetConVar( "drg_ultrakill_plydmgmult" )
  if not cv then return end
  if cv:GetFloat() == 1 then
    cv:SetFloat( 3 )
    print( "[ULTRAKILL test] drg_ultrakill_plydmgmult 1 -> 3 (player damage vs UK NPCs)" )
  end
end )
