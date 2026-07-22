local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
ENT.Base = "ultrakillbase_nextbot"

-- Misc --

ENT.PrintName = "Idol"
ENT.Author    = "ULTRAKILL port"
ENT.Category  = "ULTRAKILL - Enemies"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Models = { "models/ultrakill_idol/idol.mdl" }
ENT.Skins  = { 0 }

ENT.ModelScale       = 1.0
ENT.CollisionBounds  = Vector( 10, 10, 35 )    -- mesh ~14x14x64, slight padding
ENT.SurroundingBounds = Vector( 40, 40, 80 )   -- wider for halo/beam effects
ENT.RagdollOnDeath    = false
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)

-- Stats --
-- 1 HP: ANY melee hit one-shots (crowbar, Feedbacker, Knuckleblaster, Hammer, ground slam).
-- Idol's defence is the reflect filter, not its HP pool. Matches ULTRAKILL feel.
ENT.SpawnHealth = 1

-- AI / locomotion: stationary --

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange  = 99999
ENT.Acceleration     = 0
ENT.Deceleration     = 9999
ENT.WalkSpeed        = 0
ENT.RunSpeed         = 0
ENT.JumpHeight       = 0
ENT.MaxYawRate       = 90     -- degrees per second — soft but noticeable drift
ENT.UseWalkframes    = false

-- Animations --

ENT.WalkAnimation = "Idle"
ENT.RunAnimation  = "Idle"
ENT.IdleAnimation = "Idle"
ENT.JumpAnimation = "Idle"

-- Detection --

ENT.EyeBone = "root"

-- Tuning --

ENT.IdolFaceSpeed = 90    -- degrees per second (linear, no easing) — soft but visible drift

ENT.UKIdol_IsIdolStatue = true    -- marker for the physgun anchor hooks

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 10, 30 ),
    distance = 100,
    eyepos = false

  },

  {

    -- EyeBone is "root" (model base) — the z offset lifts the camera to head height
    offset = Vector( 6, 0, 50 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  -- Bless the aimed-at NPC (manual bond, same path as the Tool Gun). Lock-on
  -- target has priority; otherwise the crosshair trace picks one (lock-on is
  -- usually the closest hostile = a player, which IsValidTarget rejects).
  -- IsValidTarget also rejects NULL/supports and anything already blessed —
  -- including our own current bond, which doubles as the held-key anti-repeat.
  [ IN_ATTACK ] = { { coroutine = false, onkeydown = function( self, Possessor )

    local Target = self:PossessionGetLockedOn()

    if not UKIdol.IsValidTarget( Target ) then

      local Trace = self:PossessorTrace()

      Target = Trace and Trace.Entity or NULL

      if not UKIdol.IsValidTarget( Target ) then return end

    end

    UKIdol.Bind( self, Target, true )

  end } },

  -- Release the current bond and hand target selection back to the auto-scan
  [ IN_RELOAD ] = { { coroutine = false, onkeydown = function( self, Possessor )

    if UKIdol.Bonds[ self ] == nil then return end

    UKIdol.Unbind( self )
    self.UKIdol_ManualBond = false

  end } }

}


if SERVER then


local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )


function ENT:OnSpawn()

  BaseClass.OnSpawn( self )

  -- SetTurning(true) keeps client-side angle interpolation enabled. We don't have
  -- an enemy or movement, so DrGBase's auto-rotation doesn't fight us — but the
  -- network layer interpolates yaw smoothly, killing the per-tick visual jitter.
  self:SetTurning( true )
  self:SetGravity( 1 )

  -- Anchor: idol is immovable by physics (explosions, props, etc.).
  local phys = self:GetPhysicsObject()
  if IsValid( phys ) then
    phys:EnableMotion( false )
    phys:SetMass( 50000 )
  end

  -- Seed the delta-time tracker used by CustomThink for rate-limited yaw.
  self._IdolLastFaceTime = CurTime()

  -- Slow tick — retarget every 0.2s (matches Idol.cs)
  self.SlowTimerID = "UKIdol_Slow_" .. self:EntIndex()
  timer.Create( self.SlowTimerID, 0.2, 0, function()
    if not IsValid( self ) then return end
    -- ai_disabled / per-bot disable: an inert idol projects no blessing and
    -- stops retargeting; the NW2 flag also freezes the client face tracking
    -- (ai_disabled is a server-only convar, unreadable client-side)
    local disabled = self:IsAIDisabled()
    self:SetNW2Bool( "UKIdol_AIDisabled", disabled )
    if disabled then
      if UKIdol.Bonds[ self ] ~= nil then UKIdol.Unbind( self ) end
      return
    end
    -- possessed: the possessor owns target selection (IN_ATTACK bless bind) —
    -- the auto-rescan would override their pick every 0.2s. Current bond stays.
    if self:IsPossessed() then return end
    self:SlowUpdate()
  end )

end


function ENT:OnRemove()

  if self.SlowTimerID then timer.Remove( self.SlowTimerID ) end
  if UKIdol and UKIdol.Unbind then UKIdol.Unbind( self ) end

end


-- Face-tracking runs purely client-side (see the CLIENT block), so CustomThink
-- only enforces the anchor. The frozen phys object does NOT stop explosions:
-- the base blast knockback writes nextbot loco velocity directly
-- (ultrakillbase Explosion → SetVelocity), so blasts crept the statue around
-- the map (workshop report 2026-07-10). Snap back to the settle point every
-- tick; adopt single-tick jumps (tool teleports) as the new anchor and let go
-- while a physgun holds us.
function ENT:CustomThink()

  if self._UKIdolHeld then
    -- safety: if the pickup was denied or the drop event got lost, a holder
    -- who no longer wields a physgun releases the latch
    local h = self._UKIdolHolder
    if not IsValid( h ) or not IsValid( h:GetActiveWeapon() )
      or h:GetActiveWeapon():GetClass() ~= "weapon_physgun" then
      self._UKIdolHeld = false
    end
    self._UKIdolAnchor = nil
    return
  end

  local pos = self:GetPos()
  if not self._UKIdolAnchor then
    -- settle after spawn/drop: anchor once we're standing on ground
    if self.loco and self.loco:IsOnGround() then self._UKIdolAnchor = pos end
    return
  end

  local distSqr = pos:DistToSqr( self._UKIdolAnchor )
  if distSqr == 0 then return end
  -- a legit teleport (toolgun etc.) sets position WITHOUT imparting velocity;
  -- a blast shove always arrives with loco velocity — round 2 finding: the
  -- old distance-only test adopted big single-tick blast jumps as "teleports"
  -- and the statue sailed away with the rocket
  local vel = self.loco and self.loco:GetVelocity() or vector_origin
  if distSqr > 300 * 300 and vel:LengthSqr() < 25 then
    self._UKIdolAnchor = pos
    return
  end

  self:SetPos( self._UKIdolAnchor )
  if self.loco then self.loco:SetVelocity( vector_origin ) end

end


hook.Add( "PhysgunPickup", "UKIdol_AnchorHold", function( ply, ent )
  if ent.UKIdol_IsIdolStatue then
    ent._UKIdolHeld   = true
    ent._UKIdolHolder = ply
  end
end )

hook.Add( "PhysgunDrop", "UKIdol_AnchorHold", function( _, ent )
  if ent.UKIdol_IsIdolStatue then
    ent._UKIdolHeld   = false
    ent._UKIdolAnchor = nil    -- re-settle wherever we were dropped
    -- deathcatcher variant: its anchor must stay a valid vector (the opening
    -- SetModel pin reads it) — re-seed at the drop position immediately
    if ent.UKDC_AnchorPos then ent.UKDC_AnchorPos = ent:GetPos() end
  end
end )


-- Shotgun pellets pass through the statues with a gunshot reaction instead of
-- popping them. Round 3 (2026-07-10): entity-level OnTakeDamage gates proved
-- unreliable (DrGBase's AddNextbot wrapper + its internal HP application) —
-- the engine-level EntityTakeDamage hook fires BEFORE anything applies and
-- `return true` blocks the hit outright.
-- Detector: HL2 pellets carry DMG_BUCKSHOT; dredux/uk shotguns fire plain
-- DMG_BULLET with ammo "none", so those are recognized by the attacker's
-- drawn weapon class. NB: dmg:IsBulletDamage() keys off the ammo type and
-- is false for ammo-less bullets — only explicit bit checks work here.
local function IsShotgunPellet( dmg )
  if dmg:IsDamageType( DMG_BLAST ) then return false end
  if dmg:IsDamageType( DMG_BUCKSHOT ) then return true end
  if not dmg:IsDamageType( DMG_BULLET ) then return false end
  local atk = dmg:GetAttacker()
  if not ( IsValid( atk ) and atk.GetActiveWeapon ) then return false end
  local wep = atk:GetActiveWeapon()
  return IsValid( wep ) and string.find( wep:GetClass(), "shotgun", 1, true ) ~= nil
end

hook.Add( "EntityTakeDamage", "UKIdol_PelletBounce", function( ent, dmg )
  if not ent.UKIdol_IsIdolStatue then return end
  if not IsShotgunPellet( dmg ) then return end
  local hitPos = dmg:GetDamagePosition()
  if not hitPos or hitPos:IsZero() then hitPos = ent:WorldSpaceCenter() end
  local fx = EffectData()
  fx:SetOrigin( hitPos )
  fx:SetNormal( ( hitPos - ent:WorldSpaceCenter() ):GetNormalized() )
  fx:SetMagnitude( 1 )
  fx:SetScale( 0.6 )
  fx:SetRadius( 2 )
  util.Effect( "Sparks", fx, true, true )
  if ( ent._UKIdolNextPlink or 0 ) <= CurTime() then
    ent._UKIdolNextPlink = CurTime() + 0.1
    sound.Play( "weapons/fx/rics/ric" .. math.random( 1, 5 ) .. ".wav",
      hitPos, 72, math.random( 96, 108 ), 0.7 )
  end
  return true
end )


-- uk_whiplash's grab trace skips any entity whose GetRidingEntity() is valid
-- (Providence r7 trick). The idol is Light for the base, so a successful hook
-- reels the whole statue into the player's face — blocked unless the Funny
-- Bugs toggle explicitly allows it.
function ENT:GetRidingEntity()
  if UKIdol and UKIdol.IsWhiplashPullEnabled and UKIdol.IsWhiplashPullEnabled() then return end
  return self
end


-- Bypass UltrakillBase ×40/×20 scaling — idol takes raw weapon damage
function ENT:GetDamageMultiplierConVar( attacker )

  return 1

end


function ENT:SlowUpdate()

  -- Manual bond from Tool Gun: hold until target dies/removed, then revert to auto
  if self.UKIdol_ManualBond then
    local cur = UKIdol.Bonds[ self ]
    if IsValid( cur ) and cur:Health() > 0 then return end
    self.UKIdol_ManualBond = false
    -- fall through to PickNewTarget
  end

  -- Always rescan: PickNewTarget keeps the current bond if it's still the highest-rank
  -- closest valid target, or upgrades to a better one if it spawned later.
  self:PickNewTarget()

end


function ENT:PickNewTarget()

  local bestRank, bestEnt, bestDistSqr = 0, nil, math.huge
  local myPos = self:GetPos()
  local current = UKIdol.Bonds[ self ]

  for _, ent in ipairs( ents.GetAll() ) do
    -- IsValidTarget excludes anyone already blessed; allow our own current target so
    -- it competes against new candidates (it's the only ent that can be skipped here).
    if ent ~= current and not UKIdol.IsValidTarget( ent ) then continue end
    if ent == current then
      if not IsValid( ent ) or ent:Health() <= 0 then continue end
      if UKIdol.GetRank( ent ) <= 0 then continue end
    end
    local rank = UKIdol.GetRank( ent )
    if rank < bestRank then continue end
    local d = ent:GetPos():DistToSqr( myPos )
    if rank == bestRank and d >= bestDistSqr then continue end
    bestRank, bestEnt, bestDistSqr = rank, ent, d
  end

  if IsValid( bestEnt ) then
    if bestEnt ~= current then UKIdol.Bind( self, bestEnt ) end
  else
    UKIdol.Unbind( self )
  end

end


function ENT:GetClosestPlayer()

  local best, bestDistSqr = nil, math.huge
  local myPos = self:WorldSpaceCenter()
  for _, ply in ipairs( player.GetAll() ) do
    if not ply:Alive() then continue end
    local d = ply:EyePos():DistToSqr( myPos )
    if d < bestDistSqr then best, bestDistSqr = ply, d end
  end
  return best

end




function ENT:OnDeath( dmg, hitGroup )

  UKIdol.Unbind( self )

  local atk = dmg and dmg:GetAttacker() or nil
  if IsValid( atk ) and atk:IsPlayer() then
    -- +90 HP heal for the killer
    atk:SetHealth( math.min( atk:GetMaxHealth(), atk:Health() + 90 ) )
    -- (+80 Iconoclasm style would go here once UltrakillBase exposes a style HUD;
    -- chat-print suppressed.)
  end

  -- Launch all nearby players away as if from a small shockwave (matches game).
  local epicenter = self:WorldSpaceCenter()
  local RADIUS    = 350
  for _, ply in ipairs( player.GetAll() ) do
    if not ply:Alive() then continue end
    local diff = ply:WorldSpaceCenter() - epicenter
    local dist = diff:Length()
    if dist > RADIUS then continue end
    local dir = dist > 1 and ( diff / dist ) or Vector( 0, 0, 1 )
    local falloff = 1 - ( dist / RADIUS )
    local launch = dir * 900 * falloff + Vector( 0, 0, 350 * falloff )
    ply:SetVelocity( launch )
  end

  -- ULTRAKILL blood spray (CreateBlood trails + splatter) — 5 bursts at small
  -- random offsets around the idol's center.
  if UltrakillBase and UltrakillBase.CreateBlood then
    UltrakillBase.CreateBlood( epicenter, 48 )
    for i = 1, 4 do
      UltrakillBase.CreateBlood( epicenter + VectorRand() * math.Rand( 12, 40 ), 48 )
    end
  end

  -- Transparent shockwave explosion (canon ULTRAKILL soft_explosion without
  -- the virtue gib shards). Radius is in centiunits — 150 = scale 1.5.
  local fx = EffectData()
  fx:SetOrigin( epicenter )
  fx:SetAngles( self:GetAngles() )
  fx:SetRadius( 150 )
  util.Effect( "ultrakill_test_softexplosion", fx )

  if UltrakillBase and UltrakillBase.SoundScript then
    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )
  end

  self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

end


end    -- if SERVER


if CLIENT then


-- Canon ULTRAKILL idol halo — single sprite (effects/ukidol_halo_canon), extracted
-- from `idolhalo.png` in the live game via Idol.cs. 128×128 cyan double-ring with
-- pixel-art edges via $pointsamplemagfilter on the VTF.
local matHaloCanon = Material( "effects/ukidol_halo_canon" )

local HALO_SIZE = 60   -- ring at head height

-- Additive material for the procedural 4-point sparkle particles.
local matSparkle = CreateMaterial( "UKIdol_Sparkle_v1", "UnlitGeneric", {
  [ "$basetexture" ] = "vgui/white",
  [ "$additive" ]    = "1",
  [ "$vertexcolor" ] = "1",
  [ "$vertexalpha" ] = "1",
  [ "$nocull" ]      = "1",
} )

local SPARK_RATE       = 28     -- particles per second
local SPARK_LIFE       = 0.9    -- seconds
local SPARK_SPEED_MIN  = 80     -- minimum radial speed (units/s)
local SPARK_SPEED_MAX  = 130
local SPARK_GRAVITY    = 0      -- no falling — they keep flying outward
local SPARK_SIZE_MIN   = 1.5
local SPARK_SIZE_MAX   = 3
local SPARK_ARM_T      = 0.18   -- thickness at the BASE of each pointed arm

-- Sharp spikes — radial cyan needles that grow out softly, hold, then fade
local SPIKE_RATE       = 12     -- spikes spawned per second
local SPIKE_GROW_TIME  = 0.8    -- slow soft growth
local SPIKE_HOLD_TIME  = 1.8
local SPIKE_FADE_TIME  = 1.0
local SPIKE_LIFE       = SPIKE_GROW_TIME + SPIKE_HOLD_TIME + SPIKE_FADE_TIME
local SPIKE_LEN_MIN    = 40
local SPIKE_LEN_MAX    = 105
local SPIKE_WIDTH      = 2.8    -- base width
local SPIKE_COL_R      = 128    -- #80FFFF — pure cyan
local SPIKE_COL_G      = 255
local SPIKE_COL_B      = 255


function ENT:UKIdol_DrawAura( center )

  render.SetMaterial( matHaloCanon )
  render.DrawQuadEasy(
    center, EyePos() - center,
    HALO_SIZE, HALO_SIZE,
    Color( 200, 245, 255, 255 ),
    0
  )

end


function ENT:UKIdol_UpdateSparkles( now, origin )

  self.UKIdol_Sparkles  = self.UKIdol_Sparkles  or {}
  self.UKIdol_LastSpark = self.UKIdol_LastSpark or now

  -- Spawn new sparkles at SPARK_RATE per second — radial emission in all directions
  local interval = 1 / SPARK_RATE
  while now - self.UKIdol_LastSpark >= interval do
    self.UKIdol_LastSpark = self.UKIdol_LastSpark + interval
    local dir   = VectorRand():GetNormalized()
    local speed = SPARK_SPEED_MIN + math.random() * ( SPARK_SPEED_MAX - SPARK_SPEED_MIN )
    table.insert( self.UKIdol_Sparkles, {
      pos   = origin + VectorRand() * 4,
      vel   = dir * speed,
      birth = now,
      size  = SPARK_SIZE_MIN + math.random() * ( SPARK_SIZE_MAX - SPARK_SIZE_MIN ),
    } )
  end

  -- Update existing sparkles
  local dt = FrameTime()
  for i = #self.UKIdol_Sparkles, 1, -1 do
    local p   = self.UKIdol_Sparkles[ i ]
    local age = now - p.birth
    if age >= SPARK_LIFE then
      table.remove( self.UKIdol_Sparkles, i )
    else
      p.vel.z = p.vel.z + SPARK_GRAVITY * dt
      p.pos   = p.pos + p.vel * dt
    end
  end

end


function ENT:UKIdol_DrawSparkles( now )

  local list = self.UKIdol_Sparkles
  if not list or #list == 0 then return end

  local eyeAng = EyeAngles()
  local right  = eyeAng:Right()
  local up     = eyeAng:Up()

  render.SetMaterial( matSparkle )
  mesh.Begin( MATERIAL_TRIANGLES, #list * 4 )    -- 4 sharp arms × 1 tri = 4 per sparkle

  for _, p in ipairs( list ) do
    local lifeT = ( now - p.birth ) / SPARK_LIFE
    local alpha = math.floor( ( 1 - lifeT ) * 255 )
    if alpha > 0 then
      local s   = p.size
      local arm = s * SPARK_ARM_T

      local alphaBase = math.floor( alpha * 0.6 )
      -- Each arm = single triangle, sharp tip at distance `s`, base width `arm*2` at center
      local function armTri( tipDir, baseDir )
        local tip   = p.pos + tipDir * s
        local baseL = p.pos - baseDir * arm
        local baseR = p.pos + baseDir * arm
        mesh.Position( tip   ); mesh.Color( 255, 220, 80, alpha     ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
        mesh.Position( baseL ); mesh.Color( 255, 220, 80, alphaBase ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
        mesh.Position( baseR ); mesh.Color( 255, 220, 80, alphaBase ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
      end

      armTri( up,            right )    -- up arm
      armTri( right,         up    )    -- right arm
      armTri( -up,           right )    -- down arm
      armTri( -right,        up    )    -- left arm
    end
  end

  mesh.End()

end


function ENT:UKIdol_UpdateSpikes( now, origin )

  self.UKIdol_Spikes     = self.UKIdol_Spikes     or {}
  self.UKIdol_LastSpike  = self.UKIdol_LastSpike  or now

  -- The idol faces the player on the client (UKIdol_VisualYaw). "Behind" the
  -- idol is the back hemisphere — spikes shoot only into that half so they
  -- read as a halo of rays fanning out from behind the statue's head.
  local yaw      = self.UKIdol_VisualYaw or self:GetAngles().yaw
  local backDir  = -Angle( 0, yaw, 0 ):Forward()

  -- Spawn new spikes — random direction constrained to back hemisphere
  local interval = 1 / SPIKE_RATE
  while now - self.UKIdol_LastSpike >= interval do
    self.UKIdol_LastSpike = self.UKIdol_LastSpike + interval
    local dir = VectorRand():GetNormalized()
    if dir:Dot( backDir ) < 0 then dir = -dir end    -- flip to back hemisphere
    table.insert( self.UKIdol_Spikes, {
      base   = origin,
      dir    = dir,
      maxLen = SPIKE_LEN_MIN + math.random() * ( SPIKE_LEN_MAX - SPIKE_LEN_MIN ),
      birth  = now,
    } )
  end

  -- Cull expired spikes
  for i = #self.UKIdol_Spikes, 1, -1 do
    if now - self.UKIdol_Spikes[ i ].birth >= SPIKE_LIFE then
      table.remove( self.UKIdol_Spikes, i )
    end
  end

end


function ENT:UKIdol_DrawSpikes( now )

  local list = self.UKIdol_Spikes
  if not list or #list == 0 then return end

  local eyePos = EyePos()

  render.SetMaterial( matSparkle )
  mesh.Begin( MATERIAL_TRIANGLES, #list )

  for _, sp in ipairs( list ) do
    local age = now - sp.birth

    -- Animate length and alpha across the three phases
    local len, alpha
    if age < SPIKE_GROW_TIME then
      -- Soft smoothstep growth: 3g² - 2g³ — slow start, slow end, no abrupt pop
      local g = age / SPIKE_GROW_TIME
      len   = sp.maxLen * ( g * g * ( 3 - 2 * g ) )
      alpha = 255
    elseif age < SPIKE_GROW_TIME + SPIKE_HOLD_TIME then
      len   = sp.maxLen
      alpha = 255
    else
      len = sp.maxLen
      local f = ( age - SPIKE_GROW_TIME - SPIKE_HOLD_TIME ) / SPIKE_FADE_TIME
      alpha = math.floor( ( 1 - f ) * 255 )
    end

    -- Billboard the spike's width axis toward the camera
    local mid    = sp.base + sp.dir * ( len * 0.5 )
    local camDir = ( mid - eyePos ):GetNormalized()
    local perp   = sp.dir:Cross( camDir )
    if perp:LengthSqr() < 0.0001 then
      perp = sp.dir:Cross( vector_up )
    end
    perp:Normalize()

    local tip   = sp.base + sp.dir * len
    local baseL = sp.base + perp * ( SPIKE_WIDTH * 0.5 )
    local baseR = sp.base - perp * ( SPIKE_WIDTH * 0.5 )

    local alphaBase = math.floor( alpha * 0.5 )    -- soft fade at base for "glowing" needle
    mesh.Position( tip   ); mesh.Color( SPIKE_COL_R, SPIKE_COL_G, SPIKE_COL_B, alpha     ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
    mesh.Position( baseL ); mesh.Color( SPIKE_COL_R, SPIKE_COL_G, SPIKE_COL_B, alphaBase ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
    mesh.Position( baseR ); mesh.Color( SPIKE_COL_R, SPIKE_COL_G, SPIKE_COL_B, alphaBase ); mesh.TexCoord( 0, 0, 0 ); mesh.AdvanceVertex()
  end

  mesh.End()

end


-- NOTE: do NOT define ENT:Initialize on client — it would override the DrGBase base
-- initializer (which sets _DrGBaseBaseThinkDelay, _DrGBaseSequenceEvents and other
-- fields the engine reads each tick). Initialize lazy state inside Draw on first call.

-- Per-frame face tracking on the LOCAL client. Bypasses network angle interpolation
-- entirely by using SetRenderAngles, which only affects rendering — server's actual
-- ENT.Angles stays at default and never desyncs through network jitter.
function ENT:UKIdol_UpdateClientYaw()

  -- Possessed: the possessor steers the real angles server-side
  -- (PossessionFaceForward) — the local-player override would pin the statue
  -- on whoever renders it. SetRenderAngles persists until cleared with nil;
  -- nil'ing UKIdol_VisualYaw re-snaps the lerp on dispossession.
  if self:IsPossessed() then
    if self.UKIdol_VisualYaw ~= nil then
      self.UKIdol_VisualYaw     = nil
      self.UKIdol_LastFaceFrame = nil
      self:SetRenderAngles( nil )
    end
    return
  end

  local now = RealTime()
  local dt  = now - ( self.UKIdol_LastFaceFrame or now )
  self.UKIdol_LastFaceFrame = now
  if dt <= 0 then return end

  -- frozen statue: server mirrors ai_disabled into this NW2 flag
  if self:GetNW2Bool( "UKIdol_AIDisabled", false ) then return end

  local ply = LocalPlayer()
  if not IsValid( ply ) or not ply:Alive() then return end

  local toTarget = ( ply:EyePos() - self:WorldSpaceCenter() ):Angle()

  -- First frame: snap straight to target yaw so the idol spawns already
  -- facing the player. Without this it briefly shows its default-spawn
  -- orientation before the lerp catches up.
  if self.UKIdol_VisualYaw == nil then
    self.UKIdol_VisualYaw = toTarget.yaw
  end

  local curYaw = self.UKIdol_VisualYaw
  local delta  = math.AngleDifference( toTarget.yaw, curYaw )

  -- Exponential lerp (ease-out): step proportional to remaining delta, so the
  -- idol rotates fast when far from target and decelerates smoothly as it
  -- closes in. `IdolFaceRate` controls convergence speed (~10/s ≈ "feels
  -- alive"; lower is more sluggish, higher is snappier).
  local rate = self.IdolFaceRate or 10
  local f = 1 - math.exp( -rate * dt )

  self.UKIdol_VisualYaw = math.NormalizeAngle( curYaw + delta * f )

  self:SetRenderAngles( Angle( 0, self.UKIdol_VisualYaw, 0 ) )

end


function ENT:Draw()

  self:UKIdol_UpdateClientYaw()
  self:DrawModel()

  local now      = CurTime()
  local headPos  = self:LocalToWorld( Vector( 0, 0, self:OBBMaxs().z + 25 ) )
  -- Aura anchored at upper-torso height — matches canon where the halo
  -- surrounds the body, not floating above the head.
  local auraPos  = self:LocalToWorld( Vector( 0, 0, self:OBBMaxs().z * 1.15 ) )

  self:UKIdol_DrawAura( auraPos )

  -- Yellow 4-point sparkle particles emitted from the upper body
  local sparkOrigin = self:LocalToWorld( Vector( 0, 0, self:OBBMaxs().z * 0.7 ) )
  self:UKIdol_UpdateSparkles( now, sparkOrigin )
  self:UKIdol_DrawSparkles( now )

  -- Sharp cyan spikes growing out of the body center
  self:UKIdol_UpdateSpikes( now, sparkOrigin )
  self:UKIdol_DrawSpikes( now )

  -- Dynamic light
  local dl = DynamicLight( self:EntIndex() )
  if dl then
    dl.pos       = headPos
    dl.r         = 140
    dl.g         = 200
    dl.b         = 255
    dl.brightness = 1.5
    dl.size      = 200
    dl.decay     = 0
    dl.dietime   = CurTime() + 0.2
  end

end


end    -- if CLIENT


-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (doubled impact sounds/blood on every hit).
if SERVER then
  -- (shotgun pellets are blocked engine-side by the EntityTakeDamage hook
  -- "UKIdol_PelletBounce" above — this stub only keeps the double-call gate)
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    baseclass.Get( "ultrakillbase_nextbot" ).OnTakeDamage( self, dmg, hitgroup )
  end
end

AddCSLuaFile()
DrGBase.AddNextbot( ENT )
