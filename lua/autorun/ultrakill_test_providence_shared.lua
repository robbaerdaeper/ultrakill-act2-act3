if SERVER then AddCSLuaFile() end

UKProvidence = UKProvidence or {}

UKProvidence.MODEL = "models/ultrakill_prelude_test/providence.mdl"
UKProvidence.CATEGORY = "ULTRAKILL Test"

-- Workshop pack convention: canon HP x 1000. Canon Providence: 16 HP (Lesser Angel).
UKProvidence.HP = 16000

-- 25 su per canon meter (Virtue angel scale). Enemy prefab root scale 3 and
-- model-node scale 4.03 are baked into the .mdl ($scale 302.33).
UKProvidence.UNIT = 25

-- canon Drone.preferredDistanceToTarget = 50 m
UKProvidence.PREFERRED_DIST = 50 * UKProvidence.UNIT

-- canon Pincer.targetColor (1, 0, 0.45) — the magenta everything is tinted with
UKProvidence.MAGENTA = Color( 255, 0, 115 )

-- Difficulty scaling (wiki): HARMLESS 50% slower + no pre-attack dashes,
-- LENIENT 25% slower, VIOLENT 25% faster, BRUTAL 50% faster + double dashes
-- (0 HARMLESS, 1 LENIENT, 2 STANDARD, 3 VIOLENT, 4/5 BRUTAL/UKMD).
UKProvidence.TIMESCALE = { [0] = 0.50, [1] = 0.75, [2] = 1.0, [3] = 1.25, [4] = 1.5, [5] = 1.5 }
UKProvidence.DASHES = { [0] = 0, [1] = 1, [2] = 2, [3] = 2, [4] = 4, [5] = 4 }
UKProvidence.PROJ_SPEED_MULT = { [0] = 0.65, [1] = 0.85, [2] = 1.0, [3] = 1.15, [4] = 1.25, [5] = 1.25 }

-- Attack state machine timings (canon Shoot/BeamPrep clips = 1.97 s @ 30 fps,
-- windup sounds ~1 s). Cooldowns divided by TIMESCALE.
UKProvidence.ATTACK_CD_INITIAL = 2.0
UKProvidence.ATTACK_CD_MIN = 2.0
UKProvidence.ATTACK_CD_MAX = 3.5
UKProvidence.GLOBAL_CD = 1.0 -- canon: multiple Providences take turns
UKProvidence.WINDUP_PRIMARY = 1.0
-- (pincer windup = PINCER_WINDUP + PINCER_DELAY, canon fixed timings)
UKProvidence.RECOVER = 0.6
-- canon Drone.secondaryChance = 0.344 (Magenta Cross Pincer)
UKProvidence.SECONDARY_CHANCE = 0.344

-- pre-attack dash (r7: 260/850 read as violent teleport-jerks — toned down)
UKProvidence.DASH_TIME = 0.22
UKProvidence.DASH_GAP = 0.13
UKProvidence.DASH_DIST = 150
UKProvidence.DASH_WALL_PROBE = 300

-- canon Drone dodge loop: cooldown Random(1,3) ticking at GetCooldownSpeed()
-- (halved for Providence below BRUTAL): d2 0.5, d3 0.625, d4+ 1.5. The dodge
-- itself is a hard impulse 750 (5x Virtue) with a 7 m wall probe.
UKProvidence.DODGE_CD_MIN = 1.0
UKProvidence.DODGE_CD_MAX = 3.0
UKProvidence.DODGE_TICK_RATE = { [0] = 0.25, [1] = 0.375, [2] = 0.5, [3] = 0.625, [4] = 1.5, [5] = 1.5 }
UKProvidence.DODGE_SPEED = 550 -- su/s burst (canon impulse 750; 850 too jerky per r7)
UKProvidence.DODGE_WALL_PROBE = 175 -- canon 7 m raycast flips the direction

-- canon Feedbacker parry damage modifier: 60% (reduced) — NOT an instakill
UKProvidence.PARRY_DMG_MULT = 0.6

-- ---- Magenta Cross Projectile (canon 'Projectile Providence') --------------
-- Projectile: speed 65 m/s, orb damage 25, RemoveOnTime 5 s.
-- 4 child ContinuousBeams: damage 20, width 1 m, canHitPlayer only.
UKProvidence.ORB_SPEED = 45 * UKProvidence.UNIT -- canon 65 m/s; slowed twice by playtest feedback (r8: 55, r9: 45)
UKProvidence.ORB_LIFETIME = 5
UKProvidence.ORB_DAMAGE = 25
-- Parry reward: the returned orb detonates on contact for HALF the
-- Providence HP (16000) — two parries kill, never a one-shot. r12
-- note: the old flat ParryCollide(25000) + the player's x10 base
-- DamageMultiplier vaporized the Providence instantly.
UKProvidence.ORB_PARRY_DAMAGE = 8000
UKProvidence.ORB_RADIUS = 14 -- ~0.5 m trigger sphere
UKProvidence.CROSS_BEAM_DAMAGE = 20
UKProvidence.CROSS_BEAM_RANGE = 4096 -- canon maxDistance 0 = until geometry
UKProvidence.CROSS_BEAM_RADIUS = 13 -- 1 m beam width / 2
UKProvidence.CROSS_BEAM_TICK = 0.4 -- per-target damage cooldown
-- canon canHitEnemy=0 while the orb is the Providence's; once PARRIED the
-- orb plays for the player and its beams DO hit enemies (r10
-- note — the proj passes `parried or CROSS_BEAMS_HIT_NPC`)
UKProvidence.CROSS_BEAMS_HIT_NPC = false

-- ---- Magenta Cross Pincer (canon 'ProvidencePincer') ------------------------
-- Canon (wiki + prefab): a rotating sigil appears in front of the EYE, then
-- 4 beams shoot FROM THE EYE, start perpendicular to the eye->target axis and
-- slowly fold onto it (pincerSpeed 45 deg/s: 90->0 in 2 s) while the whole
-- assembly spins around the axis (rotationSpeed 90 deg/s). Source and target
-- are locked once fired. Beams damage 20 and DO hit enemies.
UKProvidence.PINCER_WINDUP = 1.0
UKProvidence.PINCER_DELAY = 0.5
UKProvidence.PINCER_SIGIL_ROT = 90
UKProvidence.PINCER_AXIS_ROT = 90   -- deg/s assembly spin around the axis
UKProvidence.PINCER_CLOSE_SPEED = 45 -- deg/s beams fold from 90 deg to the axis
UKProvidence.PINCER_BEAM_TIME = 90 / 45 + 0.5 -- full close + hold on target
UKProvidence.PINCER_BEAM_RANGE = 10000 -- canon maxDistance 0 = until geometry
UKProvidence.PINCER_BEAM_DAMAGE = 20
UKProvidence.PINCER_BEAM_RADIUS = 16 -- matches the r9 visual width 30 (was canon 26 @ width 50)
UKProvidence.PINCER_BEAM_TICK = 0.4
-- Brutal quirk (wiki): the pincer follows its target for 1 s post-summon
UKProvidence.PINCER_FOLLOW_T = 1.0

UKProvidence.SOUND = {
  Windup = {
    "ultrakill_prelude_test/providence/windup1.wav",
    "ultrakill_prelude_test/providence/windup2.wav",
    "ultrakill_prelude_test/providence/windup3.wav",
  },
  WindupBig  = "ultrakill_prelude_test/providence/windup_big.wav",
  Dodge      = "ultrakill_prelude_test/providence/dodge.wav",
  Laugh      = "ultrakill_prelude_test/providence/laugh.wav",
  Death      = "ultrakill_prelude_test/providence/death.wav",
  Shatter    = "ultrakill_prelude_test/providence/shatter.wav",   -- canon pitch 2.5 baked
  Charge     = "ultrakill_prelude_test/providence/charge.wav",    -- orb/pincer charge
  ProjFly    = "ultrakill_prelude_test/providence/proj_fly.wav",
  BeamLoop   = "ultrakill_prelude_test/providence/beam_loop.wav", -- smpl loop
  BeamImpact = "ultrakill_prelude_test/providence/beam_impact.wav", -- canon pitch 0.5 baked
  Spawn      = "ultrakill_prelude_test/providence/spawn.wav",
}

UKProvidence.CLASS = {
  Regular = "ultrakill_test_providence",
  -- 'proj' in the class name is REQUIRED for the Feedbacker punch to target
  -- the orb at all (ukarms parry scan matches '*proj*' — Gabriel port lesson)
  Orb = "ultrakill_test_providence_proj",
  Pincer = "ultrakill_test_providence_pincer",
}

-- Base difficulty convar (drg_ultrakill_difficulty, VIOLENT default) — sentry pattern.
function UKProvidence.GetDifficulty( ent )
  local d = IsValid( ent ) and ent.UltrakillBase_Difficulty
  if not isnumber( d ) and UltrakillBase and UltrakillBase.GetDifficulty then
    d = UltrakillBase.GetDifficulty()
  end
  return math.Clamp( isnumber( d ) and d or 3, 0, 5 )
end

-- Attacker-side damage scaling shared with the other test enemies.
function UKProvidence.ScaleAttackDamage( ent, damage )
  if not IsValid( ent ) then return damage end
  if ent:IsPlayer() then
    -- canon damage as-is: the beams must deal their wiki 20 (the global
    -- drg_ultrakill_plytakedmgmult was shrinking them to ~7)
    return damage
  end
  -- Pack NPCs run canon HP x 1000, but the 20/25 constants above are
  -- PLAYER-scale (canon beams are canHitPlayer-only, so there is no canon
  -- enemy-scale number). r11 set wiki/10 => x100 (orb 2500); r12 lowered it
  -- further => x50 (orb 1250 / beam 1000). The returned value is the
  -- FINAL landed damage: every deal-site must pre-divide it by the victim's
  -- base multiplier (see PreMultDamage below). r11 also dropped the old
  -- IsDrGNextbot catch-all — foreign DrGBase nextbots whose HP is NOT in
  -- the x1000 scale fall through to the dmgmult branch.
  if ent.IsUltrakillNextbot then return damage * 50 end
  local cv = GetConVar( "drg_ultrakill_dmgmult" )
  return damage * math.max( cv and cv:GetFloat() or 1, 0 )
end

-- The UK base rescales ANY damage TO a UK nextbot inside the victim's
-- DamageMultiplier by attacker type: player = plydmgmult*10, UK nextbot /
-- UK projectile = x20, everything else = takedmgmult. ScaleAttackDamage
-- returns the value we want LANDED, so deal-sites feed the pre-multiplier
-- number (power_spear recipe) — r12: without this the x20 turned the
-- "2000" beams into 40000 and every hit stayed a one-shot.
function UKProvidence.PreMultDamage( victim, attacker, amount )
  if not ( IsValid( victim ) and victim.IsUltrakillNextbot ) then return amount end
  local mult = isfunction( victim.GetDamageMultiplierConVar )
    and victim:GetDamageMultiplierConVar( attacker ) or 1
  return amount / math.max( mult, 0.01 )
end

-- The ParryCollide -> base Explosion -> DealDamage path nets a FIXED x40 on
-- UK-nextbot victims regardless of convars: UltrakillScaleDamage pre-scales
-- player-owned projectile damage by 40/(plydmgmult*10) and the victim's
-- DamageMultiplier then multiplies by plydmgmult*10 (stand-measured: fed
-- 266.67 landed 10666.7 at plydmgmult 3). Feed ORB_PARRY_DAMAGE / 40.
UKProvidence.PARRY_EXPLOSION_NET_MULT = 40

if SERVER then

  -- Shared beam damage helper: hurts everything alive within `radius` of the
  -- segment from..from+dir*length. hitCD is a per-inflictor table of
  -- [ent] = next allowed time. hitPlayers=false (parried orb: the beams turn
  -- friendly and only hurt NPCs). Returns the trace end position.
  function UKProvidence.DamageBeamSegment( owner, inflictor, from, dir, length, radius, damage, hitNPC, hitCD, hitPlayers )
    if hitPlayers == nil then hitPlayers = true end
    local tr = util.TraceLine( {
      start = from, endpos = from + dir * length,
      mask = MASK_SOLID_BRUSHONLY, filter = inflictor,
    } )
    local endpos = tr.HitPos
    local seg = endpos - from
    local seglen = seg:Length()
    if seglen < 1 then return endpos end
    local segdir = seg / seglen

    for _, ent in ipairs( ents.FindInBox(
      Vector( math.min( from.x, endpos.x ) - radius, math.min( from.y, endpos.y ) - radius, math.min( from.z, endpos.z ) - radius ),
      Vector( math.max( from.x, endpos.x ) + radius, math.max( from.y, endpos.y ) + radius, math.max( from.z, endpos.z ) + radius ) ) ) do
      if not IsValid( ent ) or ent == inflictor or ent == owner then continue end
      local isPlayer = ent:IsPlayer()
      if isPlayer and ( not hitPlayers or not ent:Alive() ) then continue end
      if not isPlayer then
        if not hitNPC then continue end
        if not ( ent:IsNPC() or ent:IsNextBot() ) then continue end
        -- canon safeEnemyType 38: HOSTILE beams never hurt fellow
        -- Providences; a parried (friendly, hitPlayers=false) cross DOES hurt
        -- them — r8: the returned + must damage everything
        if hitPlayers and ent:GetClass() == UKProvidence.CLASS.Regular then continue end
      end
      if hitCD[ ent ] and hitCD[ ent ] > CurTime() then continue end

      -- distance from entity center to the beam segment
      local p = ent:WorldSpaceCenter()
      local t = math.Clamp( ( p - from ):Dot( segdir ), 0, seglen )
      local closest = from + segdir * t
      local hitR = radius + ent:BoundingRadius() * 0.5
      if p:DistToSqr( closest ) > hitR * hitR then continue end

      -- one hit per target for the whole cast (in ULTRAKILL the player's
      -- post-hit invincibility makes beams effectively single-hit)
      hitCD[ ent ] = math.huge
      local attacker = IsValid( owner ) and owner or inflictor
      local dmg = DamageInfo()
      dmg:SetDamage( UKProvidence.PreMultDamage( ent, attacker,
        UKProvidence.ScaleAttackDamage( ent, damage ) ) )
      dmg:SetDamageType( DMG_ENERGYBEAM )
      dmg:SetAttacker( attacker )
      dmg:SetInflictor( IsValid( inflictor ) and inflictor or owner )
      dmg:SetDamagePosition( closest )
      dmg:SetDamageForce( vector_origin )
      ent:TakeDamageInfo( dmg )
    end
    return endpos
  end

end

if CLIENT then

  -- canon 'Providence Beam/Ring' particle system: magenta RageEffectWhite
  -- rings (canon color 1,0,0.5) travelling along each beam away from the
  -- source. Caller must render.SetMaterial() the ring material first.
  UKProvidence.BEAM_RING_COL = Color( 255, 0, 128, 255 )

  function UKProvidence.DrawBeamRings( from, dir, length, size, speed, spacing, alpha )
    local col = UKProvidence.BEAM_RING_COL
    if alpha and alpha < 1 then
      col = Color( col.r, col.g, col.b, 255 * alpha )
    end
    local d = ( CurTime() * speed ) % spacing
    while d < length do
      render.DrawQuadEasy( from + dir * d, dir, size, size, col, 0 )
      d = d + spacing
    end
  end

end
