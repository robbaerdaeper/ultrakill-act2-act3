if not CLIENT then return end

-- Unified render coordinator: draws sand → puppet pulse → bless as additive passes.
-- Lives ON TOP OF each entity's own Draw (or ENT.RenderOverride). Each pass is per-entity.
-- This replaces the old per-system PostDrawTranslucentRenderables hooks (removed in Tasks 12-13).

hook.Add( "PostDrawTranslucentRenderables", "UKStatusLayering", function( bDepth, bSky, b3DSky )
  if bSky or b3DSky then return end

  for _, ent in ipairs( ents.GetAll() ) do
    if not IsValid( ent ) then continue end
    if ent:IsDormant() then continue end

    local sand   = UKSand   and UKSand.IsSand   and UKSand.IsSand( ent )
    local puppet = UKPuppet and UKPuppet.IsApplied and UKPuppet.IsApplied( ent )
    local bless  = UKIdol   and UKIdol.Blessed  and UKIdol.Blessed[ ent ] ~= nil
    if not ( sand or puppet or bless ) then continue end

    -- Pass 1: Sand overlay — SKIP for Stalker (his body is already canister-styled;
    -- scrolling gold on his own diffuse looks wrong).
    if sand and ent:GetClass() ~= "ultrakill_test_stalker" then
      local ok = pcall( UKSand.RenderSandLayer, ent )
      if not ok then render.MaterialOverride( nil ) end  -- belt+suspenders cleanup
    end

    -- Pass 2: Puppet additive pulse (NOT base material — that's ENT.RenderOverride, untouched here).
    if puppet and UKPuppet.RenderPuppetLayer then
      pcall( UKPuppet.RenderPuppetLayer, ent )
    end

    -- Pass 3: Bless overlay (per-limb sprites + cyan glow).
    if bless and UKIdol.RenderBlessLayer then
      pcall( UKIdol.RenderBlessLayer, ent )
    end
  end
end )
