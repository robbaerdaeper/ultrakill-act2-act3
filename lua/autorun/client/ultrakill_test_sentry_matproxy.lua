-- Sentry (Turret) emission MaterialProxy.
-- Bound to "UKSentryGlow" proxy in sentry.vmt. Reads NW2 glow index per entity
-- (set by server in CustomInitialize / state transitions) and writes the
-- corresponding emission tint to $selfillumtint.
--
-- Canon Turret.cs:1024-1034 ChangeLightsColor:
--   smr.material.SetColor("_EmissiveColor", target)
-- The colors are: default (pink-ish ambient), attacking (orange), kick (blue), dead (near-black).
-- Source $selfillummask reads the GlowMask alpha so only the canon-emissive
-- regions (canister/eye/antenna) light up.

if not CLIENT then return end

-- Exact prefab values (Turret MB dump 2026-07-03): defaultLightsColor
-- (0.980, 0.522, 0.733), attackingLightsColor (1.0, 0.4, 0.0).
local GLOW_VEC = {
  [0] = Vector( 0.980, 0.522, 0.733 ),  -- default pink ambient
  [1] = Vector( 0.980, 0.522, 0.733 ),  -- aiming (same pink — only laser changes color)
  [2] = Vector( 1.0, 0.40, 0.0 ),       -- attacking (orange warning)
  [3] = Vector( 0.35, 0.55, 1.0 ),      -- kick (blue)
  [4] = Vector( 0.05, 0.05, 0.05 ),     -- dead (near-black)
}

matproxy.Add( {
  name = "UKSentryGlow",
  init = function( self, mat, values ) end,
  bind = function( self, mat, ent )
    if not IsValid( ent ) then
      mat:SetVector( "$selfillumtint", GLOW_VEC[ 0 ] )
      return
    end
    if ent:GetClass() ~= "ultrakill_test_sentry" then
      -- death ragdoll (tagged by ENT.OnRagdoll) keeps the dead near-black tint
      if ent:GetNW2Bool( "UKSentry_DeadGlow", false ) then
        mat:SetVector( "$selfillumtint", GLOW_VEC[ 4 ] )
        return
      end
      mat:SetVector( "$selfillumtint", GLOW_VEC[ 0 ] )
      return
    end
    local idx = ent:GetNW2Int( "UKSentry_Glow", 0 )
    mat:SetVector( "$selfillumtint", GLOW_VEC[ idx ] or GLOW_VEC[ 0 ] )
  end,
} )
