AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKLeviathan then include( "autorun/ultrakill_test_leviathan_shared.lua" ) end
if SERVER and not UKLeviathanStrikes then
  include( "autorun/ultrakill_test_leviathan_strikes.lua" )
end

-- Leviathan tail (canon LeviathanTail: "a re-purposed copy of the Leviathan",
-- SplineHook scale 15 vs the head's 20 -> ModelScale 0.75). Managed entirely
-- by the head entity: pops out of the "water" at canon spots, runs one
-- TailWhip (35 dmg, NOT parryable, high CCW / low CW), then submerges.
-- Damage taken is forwarded to the head (shared canon health pool).

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Leviathan Tail"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.Category = UKLeviathan.CATEGORY

ENT.Models = { UKLeviathan.MODEL }
ENT.ModelScale = 0.75
ENT.SpawnHealth = 999999
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy"
ENT.BloodColor = BLOOD_COLOR_RED

ENT.UKLev_IsLeviathan = true

ENT.MeleeAttackRange = 0
ENT.RangeAttackRange = 0
ENT.ReachEnemyRange = 99999
ENT.Acceleration = 0
ENT.Deceleration = 9999
ENT.WalkSpeed = 0
ENT.RunSpeed = 0
ENT.JumpHeight = 0
ENT.MaxYawRate = 0
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.WalkAnimation = "Idle"
ENT.RunAnimation = "Idle"
ENT.JumpAnimation = "Idle"

local UNIT = UKLeviathan.UNIT
local SND = UKLeviathan.SOUND

-- canon TailWhip events
local EV_SPLASH, EV_SWINGSTART, EV_SWINGEND, EV_OVER = 0.20, 2.34, 3.14, 5.21

-- Possession --

ENT.PossessionCrosshair = true

ENT.PossessionEnabled = true

ENT.PossessionMovement = POSSESSION_MOVE_CUSTOM

ENT.PossessionViews = {

  {

    -- sized for the 0.75-scale serpent copy; DrGBase multiplies offset/distance
    -- by the model scale, so ukleviathan_scale shrinks them too
    offset = Vector( 0, 225, 675 ),
    distance = 8500,
    eyepos = false

  },

  {

    -- the origin sits underwater, so the close view rides the whip tip bone
    offset = Vector( 400, 0, 100 ),
    distance = 0,
    bone = "Bone086"

  }

}


ENT.PossessionBinds = {

  [ IN_ATTACK ] = { { coroutine = true, onkeydown = function( self, Possessor )

    if self.UKLevTail_Dead or self.UKLevTail_Active then return end

    local head = self.UKLev_Head
    if not IsValid( head ) or head.UKLev_Dead then return end

    self:UKLevTail_ChangePosition()

    if self.UKLevTail_Active then
      -- player-initiated whip: must not advance the head's sub-phase chain
      self.UKLevTail_ManualWhip = true
    end

  end } }

}

if SERVER then

  function ENT:CustomInitialize()
    local head = self.UKLev_Head
    local scale = IsValid( head ) and head.UKLev_Scale or UKLeviathan.GetScale()
    self.UKLev_U = UNIT * scale
    self:SetModelScale( 0.75 * scale )

    local r, h = 10 * self.UKLev_U, 60 * self.UKLev_U
    self:SetCollisionBounds( Vector( -r, -r, 0 ), Vector( r, r, h ) )
    local sr = 180 * self.UKLev_U
    self:SetSurroundingBounds( Vector( -sr, -sr, -sr ), Vector( sr, sr, h ) )

    self:SetMaxHealth( 999999 )
    self:SetHealth( 999999 )
    self:SetParryable( false )

    self.UKLevTail_Active = false
    self.UKLevTail_PrevSpot = 0
    self.UKLevTail_Damaging = false
    self.UKLevTail_Hit = false

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
      phys:EnableMotion( false )
      phys:SetMass( 50000 )
    end
  end

  function ENT:UKLevTail_AnimSpeed()
    local head = self.UKLev_Head
    return UKLeviathan.TailAnimSpeed( UKLeviathan.GetDifficulty(
      IsValid( head ) and head or self ) )
  end

  -- canon LeviathanTail.ChangePosition
  function ENT:UKLevTail_ChangePosition()
    local head = self.UKLev_Head
    if not IsValid( head ) then return end
    local u = self.UKLev_U
    self.UKLevTail_ManualWhip = nil   -- controller-driven unless the bind re-flags
    local enemy = head:GetEnemy()
    -- possessed: the whip lines up on the possessor's lock-on, not the head's AI enemy
    if self:IsPossessed() then
      local locked = self:PossessionGetLockedOn()
      enemy = IsValid( locked ) and locked or NULL
    end

    local pos, faceFrom
    if head.UKLev_SecondPhase then
      -- nearest second-phase ring spot to the target
      local best, bestDist
      local tp = IsValid( enemy ) and enemy:GetPos() or head.UKLev_Anchor
      for _, s in ipairs( UKLeviathan.TAIL_SPOTS2 ) do
        local p = head:UKLev_SpotPos( s[ 1 ], s[ 2 ], UKLeviathan.TAIL_SPOT2_Y )
        local d = p:Distance( tp )
        if not bestDist or d < bestDist then best, bestDist = p, d end
      end
      pos = best
      faceFrom = IsValid( enemy ) and enemy:GetPos() or head:GetPos()
    else
      local n = #UKLeviathan.TAIL_SPOTS
      local idx = math.random( n )
      if idx == self.UKLevTail_PrevSpot then idx = idx % n + 1 end
      local s = UKLeviathan.TAIL_SPOTS[ idx ]
      local p = head:UKLev_SpotPos( s[ 1 ], s[ 2 ] )
      if not head:GetNoDraw() and p:Distance( head:GetPos() ) < 10 * u then
        idx = idx % n + 1
        s = UKLeviathan.TAIL_SPOTS[ idx ]
        p = head:UKLev_SpotPos( s[ 1 ], s[ 2 ] )
      end
      self.UKLevTail_PrevSpot = idx
      pos = p
      -- canon LeviathanTail: LookRotation(pos - target) — the whip visibly
      -- lines up on the player, not on the arena anchor
      faceFrom = IsValid( enemy ) and enemy:GetPos() or head.UKLev_Anchor
    end

    -- canon: high sweep sits 4.5 m under, low sweep 30.5 m under (mirrored in
    -- canon to flip the swing direction; mdl can't mirror — depth carries it)
    local low = math.Rand( 0, 1 ) > 0.5
    self.UKLevTail_Low = low
    pos = pos - Vector( 0, 0, ( low and 30.5 or 4.5 ) * u )
    self:SetPos( pos )
    -- possessed free aim without a lock-on: face where the possessor looks
    if self:IsPossessed() and not IsValid( enemy ) then
      local aim = self:GetPossessor():EyeAngles():Forward()
      faceFrom = pos + Vector( aim.x, aim.y, 0 ) * 100
    end
    local d = self:GetPos() - Vector( faceFrom.x, faceFrom.y, pos.z )
    d.z = 0
    if d:LengthSqr() < 1 then d = Vector( 1, 0, 0 ) end
    self:SetAngles( d:Angle() )
    self:UKLevTail_UpdateCollider( low )   -- after SetAngles: boxes ride the yaw

    self:SetNoDraw( false )
    self.UKLevTail_Active = true
    self.UKLevTail_Damaging = false
    self.UKLevTail_Hit = false

    local spd = self:UKLevTail_AnimSpeed()
    local seq = self:LookupSequence( "TailWhip" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( spd )
    end
    self.UKLevTail_Start = CurTime()
    self.UKLevTail_Speed = spd
    self.UKLevTail_EvIndex = 1
    self.UKLevTail_Events = {
      { EV_SPLASH, "splash" },
      { EV_SWINGSTART, "swingStart" },
      { EV_SWINGEND, "swingEnd" },
      { EV_OVER, "actionOver" },
    }

    -- canon spawn sounds: generic + difficulty hint (high/low) on d<=2
    self:EmitSound( SND.TailSpawn, 120, 100, 0.75 )
    local diff = UKLeviathan.GetDifficulty( IsValid( head ) and head or self )
    if diff <= 2 then
      self:EmitSound( low and SND.TailLow or SND.TailHigh, 120, 100, 0.85 )
    else
      self:EmitSound( SND.TailSpawn2, 120, 100, 0.85 )
    end
  end

  -- Static collision boxes along the visible body arc (BODY_ARC x 0.75 model
  -- scale, clipped at the waterline; the arc rises BEHIND the origin — an
  -- origin-centered box stands in empty water). Damage forwards to self, and
  -- the tail's own OnTakeDamage relays it to the head's shared pool.
  function ENT:UKLevTail_UpdateCollider( low )
    if self.UKLevTail_Colliders then
      for _, c in ipairs( self.UKLevTail_Colliders ) do
        if IsValid( c ) then c:Remove() end
      end
    end
    self.UKLevTail_Colliders = {}
    local u = self.UKLev_U
    local head = self.UKLev_Head
    local waterZ = IsValid( head ) and head.UKLev_WaterZ or self:GetPos().z
    local depth = low and 30.5 or 4.5      -- arena metres under the water
    local ms = 0.75                        -- tail model scale
    local hy = UKLeviathan.BODY_ARC_HALFY * ms
    local pos = self:GetPos()
    local ang = Angle( 0, self:GetAngles().yaw, 0 )
    for _, b in ipairs( UKLeviathan.BODY_ARC ) do
      local z0 = b.z0 * ms - depth
      local z1 = b.z1 * ms - depth
      if z1 > 0 then
        z0 = math.max( z0, 0 )
        local col = ents.Create( UKLeviathan.CLASS.Collider )
        if IsValid( col ) then
          col.UKLev_Mins = Vector( b.x0 * ms * u, -hy * u, z0 * u )
          col.UKLev_Maxs = Vector( b.x1 * ms * u, hy * u, z1 * u )
          col.UKLev_ForwardTo = self
          col:SetPos( Vector( pos.x, pos.y, waterZ ) )
          col:SetAngles( ang )
          col:Spawn()
          self:DeleteOnRemove( col )
          table.insert( self.UKLevTail_Colliders, col )
        end
      end
    end
  end

  function ENT:UKLevTail_SetCollidersSolid( solid )
    if not self.UKLevTail_Colliders then return end
    for _, c in ipairs( self.UKLevTail_Colliders ) do
      if IsValid( c ) then c:SetNotSolid( not solid ) end
    end
  end

  function ENT:UKLevTail_FireEvent( kind )
    local head = self.UKLev_Head
    if kind == "splash" then
      if IsValid( head ) then head:UKLev_Splash( self:GetPos() ) end

    elseif kind == "swingStart" then
      self.UKLevTail_Damaging = true
      self.UKLevTail_Hit = false
      self.UKLevTail_LastT = nil
      self:EmitSound( SND.SwingTail, 130, 100, 1 )

    elseif kind == "swingEnd" then
      self.UKLevTail_Damaging = false

    elseif kind == "actionOver" then
      self.UKLevTail_Active = false
      self.UKLevTail_Damaging = false
      self:SetNoDraw( true )
      self:UKLevTail_SetCollidersSolid( false )
      local manual = self.UKLevTail_ManualWhip
      self.UKLevTail_ManualWhip = nil
      if IsValid( head ) and not manual then head:UKLev_SubAttackOver() end
    end
  end

  -- 2D distance to the segment + a vertical band (see the head entity):
  -- a whip sweeping just over the player connects, side-dodges stay honest
  local function StrikeHitsPoint( ec, a, b, radius, ztol )
    local abx, aby = b.x - a.x, b.y - a.y
    local len = abx * abx + aby * aby
    local t = 0
    if len > 0 then
      t = math.Clamp( ( ( ec.x - a.x ) * abx + ( ec.y - a.y ) * aby ) / len, 0, 1 )
    end
    local dx = ec.x - ( a.x + abx * t )
    local dy = ec.y - ( a.y + aby * t )
    if dx * dx + dy * dy > radius * radius then return false end
    local cz = a.z + ( b.z - a.z ) * t
    return math.abs( ec.z - cz ) <= ztol
  end

  -- r4: the whip damage follows the SAMPLED TailWhip chain polyline (offline
  -- bake from leviathan_tailwhip.smd, lerped between frames) — only what the
  -- visible whip actually passes through gets hit. Points are model metres:
  -- x0.75 tail scale, rotated by the entity yaw, submerged segments skipped.
  -- r5: sub-stepped over the anim-time interval between thinks.
  function ENT:UKLevTail_PolylineAt( t )
    local D = UKLeviathanStrikes
    if not D then return end
    local fr = ( t * D.TAIL_FPS - D.TAIL_FRAME0 ) / D.TAIL_FSTEP + 1
    local n = #D.TAIL
    fr = math.Clamp( fr, 1, n )
    local i0 = math.floor( fr )
    local i1 = math.min( i0 + 1, n )
    local frac = fr - i0
    local r0, r1 = D.TAIL[ i0 ], D.TAIL[ i1 ]
    local u = self.UKLev_U
    local ms = 0.75
    local side = D.SIDE
    local pos = self:GetPos()
    local fwd, right = self:GetForward(), self:GetRight()
    local pts = {}
    for k = 1, #r0, 3 do
      local f = ( r0[ k ] + ( r1[ k ] - r0[ k ] ) * frac ) * ms
      local s = ( r0[ k + 1 ] + ( r1[ k + 1 ] - r0[ k + 1 ] ) * frac ) * ms * side
      local h = ( r0[ k + 2 ] + ( r1[ k + 2 ] - r0[ k + 2 ] ) * frac ) * ms
      pts[ #pts + 1 ] = pos + fwd * ( f * u ) + right * ( s * u ) + Vector( 0, 0, h * u )
    end
    return pts
  end

  function ENT:UKLevTail_ApplySwingDamage()
    if not self.UKLevTail_Damaging or self.UKLevTail_Hit then return end
    if not UKLeviathanStrikes or not self.UKLevTail_Start then return end
    local head = self.UKLev_Head
    local u = self.UKLev_U
    local waterZ = IsValid( head ) and head.UKLev_WaterZ or self:GetPos().z
    local radius = UKLeviathan.TAIL_RADIUS_M * 0.75 * u
    local center = self:GetPos()

    local spd = self.UKLevTail_Speed or 1
    local nowT = ( CurTime() - self.UKLevTail_Start ) * spd
    local fromT = self.UKLevTail_LastT or math.max( nowT - 0.05, 0 )
    self.UKLevTail_LastT = nowT

    -- candidates once per think
    local targets = {}
    for _, ent in ipairs( ents.FindInSphere(
        Vector( center.x, center.y, waterZ ), UKLeviathan.TAIL_REACH * u ) ) do
      if ent ~= self and IsValid( ent ) and not ent.UKLev_IsLeviathan
          and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        targets[ #targets + 1 ] = ent
      end
    end

    local debug = GetConVar( "ukleviathan_debug" ):GetBool()
    local victim
    local t = fromT
    while true do
      local pts = self:UKLevTail_PolylineAt( t )
      if pts and #pts >= 2 then
        if debug then
          for i = 1, #pts - 1 do
            debugoverlay.Line( pts[ i ], pts[ i + 1 ], 0.5, Color( 60, 160, 255 ), true )
          end
        end
        for _, ent in ipairs( targets ) do
          if not IsValid( ent ) then continue end
          local ec = ent:WorldSpaceCenter()
          for i = 1, #pts - 1 do
            local a, b = pts[ i ], pts[ i + 1 ]
            -- skip fully submerged whip segments
            if a.z >= waterZ - 2 * u or b.z >= waterZ - 2 * u then
              if StrikeHitsPoint( ec, a, b, radius, 12 * u ) then
                victim = ent
                break
              end
            end
          end
          if victim then break end
        end
      end
      if victim or t >= nowT then break end
      t = math.min( t + 0.02, nowT )
    end
    if not victim then return end

    do
      local ent = victim
      local amount
      if ent:IsPlayer() then
        amount = UKLeviathan.ScaleAttackDamage( ent, UKLeviathan.TAIL_DAMAGE )
      else
        -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
        amount = ent.IsUltrakillNextbot
          and UKNpcDmg.PreMult( ent, self, UKLeviathan.TAIL_DAMAGE * 100 )
          or UKLeviathan.TAIL_DAMAGE
      end
      local dmg = DamageInfo()
      dmg:SetDamage( amount )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( IsValid( head ) and head or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( Vector( 0, 0, 500 ) )
      ent:TakeDamageInfo( dmg )
      if ent:IsPlayer() then
        local dir = ( ent:WorldSpaceCenter() - center ):GetNormalized()
        dir.z = 0
        if dir:IsZero() then dir = self:GetForward() end
        ent:SetVelocity( dir:GetNormalized() * 800 + Vector( 0, 0, 350 ) )
      end

      -- canon TargetBeenHit: stop after the first landed hit
      self.UKLevTail_Hit = true
      self.UKLevTail_Damaging = false
      return
    end
  end

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKLevTail_Active and self.UKLevTail_Start then
      local t = ( CurTime() - self.UKLevTail_Start ) * ( self.UKLevTail_Speed or 1 )
      while self.UKLevTail_EvIndex <= #self.UKLevTail_Events do
        local ev = self.UKLevTail_Events[ self.UKLevTail_EvIndex ]
        if t < ev[ 1 ] then break end
        self.UKLevTail_EvIndex = self.UKLevTail_EvIndex + 1
        self:UKLevTail_FireEvent( ev[ 2 ] )
      end
    end
    self:UKLevTail_ApplySwingDamage()
  end

  function ENT:OnUpdateAnimation()
    local spd = self:UKLevTail_AnimSpeed()
    if self.UKLevTail_Dead then return "TailDeath", 1 end
    if self.UKLevTail_Active then return "TailWhip", spd end
    return "Idle", spd
  end

  function ENT:OnUpdateSpeed()
    return 0
  end

  function ENT:OnMeleeAttack( enemy )
    return
  end

  -- stationary limb: the controller/binds teleport it between canon spots, so
  -- possession movement keys do nothing
  function ENT:PossessionControls()
  end

  -- shared canon health pool: forward everything to the head
  function ENT:OnTakeDamage( dmg, hitgroup )
    local head = self.UKLev_Head
    if self.UKLevTail_Dead or self:GetNoDraw() then
      dmg:SetDamage( 0 )
      return
    end
    if IsValid( head ) and not head.UKLev_Dead then
      local fwd = DamageInfo()
      fwd:SetDamage( dmg:GetDamage() )
      fwd:SetDamageType( dmg:GetDamageType() )
      fwd:SetAttacker( dmg:GetAttacker() )
      fwd:SetInflictor( dmg:GetInflictor() )
      fwd:SetDamagePosition( dmg:GetDamagePosition() )
      -- canon: the second copy's heart is NOT a weak point -> plain hitgroup;
      -- the flag lets the hit through the head's underwater immunity
      head.UKLev_TailForward = true
      head:TakeDamageInfo( fwd )
      head.UKLev_TailForward = nil
    end
    dmg:SetDamage( 0 )
  end

  function ENT:UKLevTail_Death()
    self.UKLevTail_Dead = true
    self.UKLevTail_Active = false
    self.UKLevTail_Damaging = false
    self:UKLevTail_SetCollidersSolid( false )
    if self:GetNoDraw() then return end
    local seq = self:LookupSequence( "TailDeath" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end
  end

end

DrGBase.AddNextbot( ENT )
