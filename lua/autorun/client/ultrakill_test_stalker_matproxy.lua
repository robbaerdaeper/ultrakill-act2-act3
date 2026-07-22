-- Stalker canister glow MaterialProxy.
-- Bound to the "UKStalkerGlow" proxy in stalker_can.vmt (the opaque canister
-- material, NOT the glass shell). Reads per-entity NW2 (light state, blink
-- phase, HP frac) and writes them into the material's $selfillumtint each
-- frame. The actual emission shape is controlled by the $selfillummask
-- texture (stalker_can_emission.vtf, converted from canon T_SandCanEmission.png),
-- so only the canon-defined hot regions of the canister glow — the
-- "отдельные элементы светятся" effect.
--
-- Canon mapping (Stalker.cs:309, 316, 334):
--   lit.color = currentColor * ((hp + 0.2) / (maxHp + 0.2))
--   on blink → toggle between lit.color and Color.black hard, every 0.1s
--   canRenderer.material.SetColor("_EmissiveColor", lit.color)
--
-- $selfillumtint multiplies the masked emission output, so a tint of [0 0 0]
-- gives no emission while the underlying $basetexture stays visible (canon:
-- glass shell remains, only the lamp goes dark on blink-off).

if not CLIENT then return end

-- State → emission color vector. Components are 0..N (matproxy $color2 isn't
-- clamped to 1.0), so we let yellow/red push past unit for over-brightness
-- on $additive blend without burning to white.
-- Canon Stalker.cs flow: Phase B (green_blink) keeps `currentColor` as lightColors[0]
-- (green). Only Phase C (yellow_solid) switches to lightColors[1] (yellow). So the
-- emissive color for green_blink must stay GREEN — only `blinking` toggles.
local STATE_COLOR = {
  green_steady = Vector( 0.235, 1.000, 0.235 ),
  green_blink  = Vector( 0.235, 1.000, 0.235 ),
  yellow_solid = Vector( 1.000, 0.784, 0.000 ),
  red_blink    = Vector( 1.000, 0.117, 0.117 ),
}

local BLACK = Vector( 0, 0, 0 )

matproxy.Add( {
  name = "UKStalkerGlow",
  init = function( self, mat, values ) end,
  bind = function( self, mat, ent )
    if not IsValid( ent ) then
      mat:SetVector( "$selfillumtint", BLACK )
      return
    end
    if ent:GetClass() ~= "ultrakill_test_stalker" then
      -- Default canister look for non-Stalker entities sharing the material
      -- (e.g. spawn-icon previews) — stay green at full HP.
      mat:SetVector( "$selfillumtint", STATE_COLOR.green_steady )
      return
    end

    -- Hard blink toggle: on the "off" half, emission is black (canon Stalker.cs:315).
    if ent:GetNW2Bool( "UKStalker_BlinkOn", false ) then
      mat:SetVector( "$selfillumtint", BLACK )
      return
    end

    local state  = ent:GetNW2String( "UKStalker_LightState", "green_steady" )
    local hpFrac = ent:GetNW2Float( "UKStalker_HPFrac", 1.0 )
    local col    = STATE_COLOR[ state ] or STATE_COLOR.green_steady
    mat:SetVector( "$selfillumtint", col * hpFrac )
  end,
} )
