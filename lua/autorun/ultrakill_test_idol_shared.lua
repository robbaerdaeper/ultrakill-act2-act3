-- lua/autorun/ultrakill_test_idol_shared.lua

UKIdol = UKIdol or {}

UKIdol.Blessed         = UKIdol.Blessed         or {}    -- [target] = idol
UKIdol.Bonds           = UKIdol.Bonds           or {}    -- [idol]   = target
UKIdol.Ranks           = UKIdol.Ranks           or {}
UKIdol.MeleeWeaponClasses = UKIdol.MeleeWeaponClasses or {}
UKIdol.BaseDetectors   = UKIdol.BaseDetectors   or {}
UKIdol.WeakspotHitboxes = UKIdol.WeakspotHitboxes or {}    -- [class] = { hbox_idx, ... }
UKIdol.DMG_CUSTOM_MELEE = 0x10000


function UKIdol.IsBlessed( ent )
  local idol = UKIdol.Blessed[ ent ]
  return IsValid( idol ) and idol or nil
end


function UKIdol.RegisterRank( class, rank )
  UKIdol.Ranks[ class ] = rank
end


function UKIdol.RegisterMeleeWeapon( class )
  UKIdol.MeleeWeaponClasses[ class ] = true
end


function UKIdol.AddBaseDetector( check_fn, rank_fn )
  table.insert( UKIdol.BaseDetectors, { check = check_fn, rank = rank_fn } )
end


function UKIdol.GetLimbPositions( ent )
  if not IsValid( ent ) then return {} end
  local hbset = ent:GetHitboxSet()
  if not hbset then return {} end
  local count = ent:GetHitBoxCount( hbset )
  if not count or count == 0 then return {} end

  local limbs = {}
  for i = 0, count - 1 do
    local boneIdx = ent:GetHitBoxBone( i, hbset )
    local mins, maxs = ent:GetHitBoxBounds( i, hbset )
    if not mins or not maxs then continue end
    local matrix = ent:GetBoneMatrix( boneIdx )
    if not matrix then continue end

    -- Hitbox bounds are in BONE-LOCAL space. LocalToWorld (with Angle() as the
    -- local angle) handles Source's coordinate convention (Right = -Y) so we
    -- don't have to track per-axis sign flips manually.
    local localCenter = ( mins + maxs ) * 0.5
    local center = LocalToWorld( localCenter, angle_zero,
                                 matrix:GetTranslation(), matrix:GetAngles() )

    local size = math.max( maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z )
    table.insert( limbs, { pos = center, size = size, hbox = i, bone = boneIdx } )
  end
  return limbs
end


-- Cross-NPC heuristic: "Is this hitbox a limb / extremity vs. the torso?"
-- Largest hitbox by volume = torso. Everything else = extremity (head, arm, leg, hand, foot).
-- Single-hitbox NPCs (some basic nextbots) → always torso.
function UKIdol.IsExtremity( ent, hboxIdx )
  if not IsValid( ent ) then return false end
  local hbset = ent:GetHitboxSet()
  if not hbset then return false end
  local count = ent:GetHitBoxCount( hbset )
  if not count or count <= 1 then return false end

  local biggestVol, biggestIdx = 0, -1
  for i = 0, count - 1 do
    local mins, maxs = ent:GetHitBoxBounds( i, hbset )
    if mins and maxs then
      local v = ( maxs.x - mins.x ) * ( maxs.y - mins.y ) * ( maxs.z - mins.z )
      if v > biggestVol then biggestVol, biggestIdx = v, i end
    end
  end

  return hboxIdx ~= biggestIdx
end


-- Built-in class ranks
local DEFAULT_RANKS = {
  -- ULTRAKILL bosses / elites
  [ "ultrakill_v2" ]              = 6,
  [ "ultrakill_gabriel" ]         = 6,
  [ "ultrakill_minosprime" ]      = 6,
  [ "ultrakill_sisyphusprime" ]   = 6,
  [ "ultrakill_cerberus" ]        = 5,
  [ "ultrakill_hideous_mass" ]    = 5,
  -- canon 5-2: the Idols in the arena bless the Ferryman himself
  [ "ultrakill_test_ferryman" ]   = 5,
  [ "ultrakill_ferryman" ]        = 5,
  -- The Corpse of King Minos (rank 6 on the wiki) + its Arm
  [ "ultrakill_test_minos_corpse" ] = 6,
  [ "ultrakill_test_minos_arm" ]    = 6,
  [ "ultrakill_maliciousface" ]   = 4,
  [ "ultrakill_test_rodent_big" ] = 4,
  [ "ultrakill_swordsmachine" ]   = 4,
  -- SonaristicCatboy collab NPCs (workshop 3708282959 / 3671170098) — explicit
  -- ranks so Idol prioritizes them properly (their base sets IsUltrakillNextbot,
  -- which opts them out of the DrGBase detector below).
  [ "ultrakill_v1" ]                        = 6,
  [ "ultrakill_v2_2" ]                      = 6,   -- V2 (Greed); plain ultrakill_v2 already ranked above
  [ "ultrakill_v2_ultrapain" ]              = 6,
  [ "ultrakill_fleshprison" ]               = 6,
  [ "ultrakill_fleshpanopticon" ]           = 6,
  [ "ultrakill_fleshpanopticon_breakout" ]  = 6,
  [ "ultrakill_fleshpanopticon_ultrapain" ] = 6,
  [ "ultrakill_minimaurice" ]               = 3,   -- mini Malicious Face — one tier below the real one
  [ "ultrakill_eyespawn" ]                  = 2,
  [ "ultrakill_eyespawn_spotlight" ]        = 2,
  -- Deathcatcher is itself a "support" demon — Idol shouldn't bless it
  -- (canon: Idol-protected Deathcatcher would lock the arena since you
  -- couldn't kill the catcher to stop the puppet loop).
  [ "ultrakill_test_deathcatcher" ] = 0,
  [ "ultrakill_deathcatcher" ]      = 0,
  [ "ultrakill_soldier" ]         = 3,
  [ "ultrakill_schism" ]          = 3,
  [ "ultrakill_stray" ]           = 2,
  [ "ultrakill_test_rodent" ]     = 1,
  [ "ultrakill_filth" ]           = 1,
  [ "ultrakill_test_idol" ]       = 0,
  -- HL2 baseline
  [ "npc_strider" ]               = 5,
  [ "npc_helicopter" ]            = 5,
  [ "npc_combinegunship" ]        = 5,
  [ "npc_antlionguard" ]          = 4,
  [ "npc_combine_super_soldier" ] = 3,
  [ "npc_combine_elite" ]         = 3,
  [ "npc_combine_s" ]             = 2,
  [ "npc_metropolice" ]           = 2,
  [ "npc_zombine" ]               = 2,
  [ "npc_fastzombie" ]            = 2,
  [ "npc_zombie" ]                = 1,
  [ "npc_headcrab" ]              = 1,
  -- Friendly NPC blacklist
  [ "npc_citizen" ]               = 0,
  [ "npc_alyx" ]                  = 0,
  [ "npc_barney" ]                = 0,
  [ "npc_kleiner" ]               = 0,
  [ "npc_eli" ]                   = 0,
  [ "npc_monk" ]                  = 0,
  [ "npc_mossman" ]               = 0,
  [ "npc_breen" ]                 = 0,
  [ "npc_gman" ]                  = 0,
}

for cls, r in pairs( DEFAULT_RANKS ) do
  if UKIdol.Ranks[ cls ] == nil then UKIdol.Ranks[ cls ] = r end
end


-- Built-in framework detectors
UKIdol.AddBaseDetector(
  function( e ) return e.IsVJBaseSNPC == true end,
  function( e )
    if e.IsVJBoss or e.VJ_IsHugeMonster then return 5 end
    local hp = e.MaxHealth or e:GetMaxHealth()
    if hp > 5000 then return 5
    elseif hp > 2000 then return 4
    elseif hp > 500 then return 3
    elseif hp > 200 then return 2 end
    return 1
  end
)

UKIdol.AddBaseDetector(
  function( e ) return e.IsZBaseNPC == true end,
  function( e )
    if e.IsBoss then return 5 end
    local hp = e.MaxHealth or e:GetMaxHealth()
    if hp > 3000 then return 5
    elseif hp > 1000 then return 3 end
    return 2
  end
)

UKIdol.AddBaseDetector(
  function( e ) return e.IsDrGNextbot == true and not e.IsUltrakillNextbot end,
  function( e )
    local hp = e.SpawnHealth or e:GetMaxHealth()
    if hp > 5000 then return 5
    elseif hp > 1000 then return 3 end
    return 2
  end
)

UKIdol.AddBaseDetector(
  function( e )
    return e:IsNextBot() and not e.IsDrGNextbot and not e.IsZBaseNPC
  end,
  function( e )
    local hp = e:GetMaxHealth()
    if hp > 1000 then return 3 end
    return 1
  end
)


function UKIdol.GetRank( ent )
  if not IsValid( ent ) then return 0 end

  local r = UKIdol.Ranks[ ent:GetClass() ]
  if r ~= nil then return r end

  for _, det in ipairs( UKIdol.BaseDetectors ) do
    if det.check( ent ) then return det.rank( ent ) end
  end

  local hp = ent:GetMaxHealth()
  if hp > 5000 then return 5
  elseif hp > 1500 then return 4
  elseif hp > 500 then return 3
  elseif hp > 100 then return 2 end
  return 1
end


function UKIdol.IsValidTarget( ent )
  if not IsValid( ent ) or ent:IsPlayer() then return false end
  if not ( ent:IsNPC() or ent:IsNextBot() ) then return false end
  if ent:Health() <= 0 then return false end
  if ent:GetClass() == "ultrakill_test_idol" then return false end
  if UKIdol.IsBlessed( ent ) then return false end
  if UKIdol.GetRank( ent ) <= 0 then return false end
  return true
end
