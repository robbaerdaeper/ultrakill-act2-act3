-- Shared NPC-vs-NPC damage helper — round-3 sweep (2026-07-10).
--
-- ULTRAKILL-base victims multiply INCOMING damage themselves
-- (GetDamageMultiplierConVar: x20 when the attacker is a UK nextbot or its
-- projectile), so raw numbers fed to TakeDamageInfo land inflated. The
-- convention (npc_vs_npc_damage_scale): decide the TARGET LANDED value
-- (canon player damage x100), then pre-divide by the victim's multiplier —
-- the Providence PreMultDamage recipe, generalized so every port can share
-- one implementation.

UKNpcDmg = UKNpcDmg or {}

function UKNpcDmg.PreMult( victim, attacker, target )
  if not ( IsValid( victim ) and victim.IsUltrakillNextbot ) then return target end
  local mult = isfunction( victim.GetDamageMultiplierConVar )
    and victim:GetDamageMultiplierConVar( attacker ) or 1
  return target / math.max( mult, 0.01 )
end

-- The base Explosion / ParryCollide -> DealDamage path nets a FIXED x40 on
-- UK-nextbot victims regardless of convars (stand-measured on Providence and
-- the Guttertank mine). Feed target / EXPLOSION_NET_MULT there instead.
UKNpcDmg.EXPLOSION_NET_MULT = 40
