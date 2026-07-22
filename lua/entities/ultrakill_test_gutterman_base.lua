AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )
local DrGBase = DrGBase
local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "nextbot"
ENT.Base = "ultrakillbase_nextbot"
ENT.PrintName = "Gutterman Base"
ENT.Author = "ultragmod"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Category = UKGutterman.CATEGORY

ENT.Models = { UKGutterman.MODEL }
ENT.ModelScale = 1.0
ENT.SpawnHealth = UKGutterman.HP_REGULAR
-- Half-extents from origin: hull (-x,-y,0)..(x,y,z). Torso is ~70 su across,
-- model ~174 su tall; 64 made a player-x4 box that clipped map water pools.
ENT.CollisionBounds = Vector( 36, 36, 176 )
ENT.SurroundingBounds = Vector( 160, 160, 230 )
ENT.RagdollOnDeath = false
ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.UltrakillBase_WeightClass = "Superheavy" -- canon (ultrakill.wiki.gg/wiki/Enemies)

-- Canon scale: compiled model ~174 su tall vs ~4.4 m in ULTRAKILL => ~40 su/m.
local UNIT = UKGutterman.UNIT

-- Canon nav destination is the target position itself (mach.SetDestination
-- (eid.target.position) every SlowUpdate) — the Gutterman walks INTO the
-- target. Keeping this at BASH_RANGE made him stop 12 m away and whiff his
-- bash into the air forever.
ENT.MeleeAttackRange = 3 * UKGutterman.UNIT
ENT.RangeAttackRange = 4000
ENT.ReachEnemyRange = 3 * UKGutterman.UNIT
ENT.AvoidEnemyRange = 0

ENT.Acceleration = 8 * UNIT -- canon acceleration 8
ENT.Deceleration = 900
ENT.WalkSpeed = UKGutterman.MOVE_SPEED
ENT.RunSpeed = UKGutterman.MOVE_SPEED
ENT.MaxYawRate = 120 -- canon angular speed
ENT.JumpHeight = 80
ENT.UseWalkframes = false

ENT.IdleAnimation = "Idle"
ENT.IdleAnimRate = 1
ENT.WalkAnimation = "Walk"
ENT.WalkAnimRate = 1
ENT.RunAnimation = "Walk"
ENT.RunAnimRate = 1
ENT.JumpAnimation = "Walk"
ENT.JumpAnimRate = 1
ENT.FallingAnimation = "Walk"
ENT.FallingAnimRate = 1

ENT.UKGutterman_HasShield = true
ENT.UKGutterman_Windup = 0
ENT.UKGutterman_LOSTimer = 0
ENT.UKGutterman_SlowMode = false
ENT.UKGutterman_Firing = false
ENT.UKGutterman_Dead = false
ENT.UKGutterman_ActionSequence = nil

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    -- hull 36x36x176, ~2.4x the workshop humanoid presets (0/11.5/34.5, 115)
    offset = Vector( 0, 25, 76 ),
    distance = 250,
    eyepos = false

  },

  {

    -- no eye bone: EyePos sits inside the chest armor, the forward offset
    -- has to clear the hull (halfwidth 36)
    offset = Vector( 40, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  -- cannon trigger: hold to spin up, release to spool down. Instant flag
  -- writes (no coroutine) — the possession branch of CustomThink feeds the
  -- flag into the canon windup/slowMode/firing machinery, which also drives
  -- the NW windup the client barrel spin reads.
  [ IN_ATTACK ] = { {

    onkeydown = function( self )
      self.UKGutterman_PossessTrigger = true
    end,

    onkeyup = function( self )
      self.UKGutterman_PossessTrigger = false
    end

  } },

  -- bash (shield bash / shieldless smack): same gates the AI trigger in
  -- UKGutterman_CanonUpdate applies — StartBash itself only checks InAction,
  -- and LastParried carries both the 5 s post-parry lock and the canon
  -- post-bash chain lock on STANDARD and below
  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self )

    if self.UKGutterman_Dead or not self:IsOnGround() then return end
    if CurTime() - self.UKGutterman_LastParried <= 5 then return end
    if CurTime() < self.UKGutterman_NextBash then return end

    self:UKGutterman_StartBash()

  end } },

}

-- Action timings: Unity clip-event seconds divided by the QC sequence speed
-- (ShieldBash x1.5, Smack x1.25, ShieldBreak x1.0, Death x0.65).
local ACTION = {
  ShieldBash = {
    duration = 1.208, -- StopAction 1.8124183 / 1.5
    active = 0.663,   -- ShieldBashActive 0.9949019 / 1.5
    stop = 0.771,     -- ShieldBashStop 1.1568627 / 1.5
  },
  Smack = {
    duration = 0.963, -- StopAction 1.2031372 / 1.25
    active = 0.376,   -- ShieldBashActive 0.46939564 / 1.25
    stop = 0.558,     -- ShieldBashStop 0.6972195 / 1.25
  },
  ShieldBreak = { duration = 1.820 },
  Death = {
    duration = 1.795,    -- clip 1.1666667 / 0.65
    fallStart = 1.101,   -- FallStart 0.715817 / 0.65
    fallOver = 1.310,    -- FallOver 0.85124177 / 0.65
  },
}

local EXPLOSIVE_WORDS = {
  rocket = true,
  grenade = true,
  missile = true,
  bomb = true,
  explosive = true,
}

local function DamageStackHasKnuckleblasterArm()
  if not debug or not debug.getinfo or not debug.getlocal then return false end

  for level = 2, 10 do
    local info = debug.getinfo( level, "S" )
    local src = info and string.lower( info.short_src or "" ) or ""
    if string.find( src, "vmanipfeedbacker", 1, true ) then
      for idx = 1, 32 do
        local name, value = debug.getlocal( level, idx )
        if not name then break end
        if name == "arm" and string.upper( tostring( value ) ) == "KNUCKLEBLASTER" then
          return true
        end
      end
    end
  end

  return false
end

-- Shared (server aims, client draws the tracer/flash from the same point).
-- Canon shootPoint = Barrels_end, a stub ~30% past the Barrels bone.
-- Bone matrices on nextbots can go stale/garbage (same failure the shield
-- helper guards against): a garbage muzzle silently fired every beam from
-- nowhere, so any muzzle further than 250 su from the body falls back to the
-- fixed entity-space gun offset.
local MUZZLE_DRIFT_SQR = 250 * 250

function ENT:UKGutterman_GetMuzzle()
  local bBarrels = self:LookupBone( "Barrels" )
  local bArmEnd = self:LookupBone( "Arm_R_End" )
  if bBarrels then
    local m = self:GetBoneMatrix( bBarrels )
    if m then
      local p = m:GetTranslation()
      if p:DistToSqr( self:WorldSpaceCenter() ) < MUZZLE_DRIFT_SQR then
        if bArmEnd then
          local m0 = self:GetBoneMatrix( bArmEnd )
          if m0 then
            local dir = p - m0:GetTranslation()
            if dir:LengthSqr() > 1 then
              dir:Normalize()
              return p + dir * 30, dir
            end
          end
        end
        return p, self:GetForward()
      end
    end
  end
  return self:GetPos() + self:GetForward() * 110 + self:GetRight() * 29 + self:GetUp() * 100,
    self:GetForward()
end

if SERVER then
  function ENT:CustomInitialize()
    local health = self.SpawnHealth or UKGutterman.HP_REGULAR

    -- DrGBase already applied ENT.Models; calling SetModel here AGAIN would
    -- reset the engine hull to the model's own bounds (map-sized while the
    -- compiled bboxes are broken) AFTER DrGBase set the proper hull.
    -- Re-assert the intended hull defensively instead.
    local cb = self.CollisionBounds
    self:SetCollisionBounds( Vector( -cb.x, -cb.y, 0 ), Vector( cb.x, cb.y, cb.z ) )

    self:SetMaxHealth( health )
    self:SetHealth( health )

    self.UKGutterman_HasShield = true
    self.UKGutterman_Windup = 0
    self.UKGutterman_LOSTimer = 0
    self.UKGutterman_SlowMode = false
    self.UKGutterman_Firing = false
    self.UKGutterman_PossessTrigger = false
    self.UKGutterman_Dead = false
    self.UKGutterman_BulletCooldown = 0
    self.UKGutterman_FireRamp = 0
    self.UKGutterman_TrackingSpeed = UKGutterman.TRACK_DEFAULT
    self.UKGutterman_TrackingPos = nil
    self.UKGutterman_LastKnownPos = nil
    self.UKGutterman_LastParried = -10
    self.UKGutterman_ParryWindowUntil = nil
    self:SetParryable( false )
    self.UKGutterman_NextBash = 0
    self.UKGutterman_ActionUntil = nil
    self.UKGutterman_ActionSequence = nil
    self.UKGutterman_ActionStart = 0
    self.UKGutterman_ActionName = nil
    self.UKGutterman_ActionHits = nil
    self.UKGutterman_CorpseSpawned = false
    self.UKGutterman_LastWalkCycle = 0
    self.UKGutterman_PlayerHitGate = {}
    self.UKGutterman_NextCoinScan = nil
    self.UKGutterman_CoinBlocked = false
    self.UKGutterman_LastFiringNW = nil
    self:SetNWBool( "UKG_Firing", false )

    self:SetBodygroupByNameSafe( "shield", 0 )
    self:SetBodygroupByNameSafe( "casket_door", self.UKGutterman_Casketless and 1 or 0 )
    self:SetBodygroupByNameSafe( "body", self.UKGutterman_Casketless and 1 or 0 )

    self:UKGutterman_CreateShield()

    if self.UKGutterman_Boss and UltrakillBase.AddBoss then
      UltrakillBase.AddBoss( self, UKGutterman.BOSS_TITLE )
    end
  end

  function ENT:OnSpawn()
    BaseClass.OnSpawn( self )
    self:SetTurning( true )
  end

  function ENT:OnRemove()
    self:UKGutterman_StopWindupSound()
    self:UKGutterman_RemoveShield()
    if self.UKGutterman_Boss and UltrakillBase.RemoveBoss then
      UltrakillBase.RemoveBoss( self )
    end
  end

  function ENT:SetBodygroupByNameSafe( name, value )
    local id = self:FindBodygroupByName( name )
    if id and id >= 0 then self:SetBodygroup( id, value ) end
  end

  -- Shield helper ----------------------------------------------------------

  function ENT:UKGutterman_CreateShield()
    if IsValid( self.UKGutterman_Shield ) then return end

    local shield = ents.Create( UKGutterman.CLASS.Shield )
    if not IsValid( shield ) then return end

    shield:SetGuttermanOwner( self )
    shield:SetPos( self:WorldSpaceCenter() + self:GetForward() * 60 )
    shield:Spawn()
    self.UKGutterman_Shield = shield
  end

  function ENT:UKGutterman_RemoveShield()
    if IsValid( self.UKGutterman_Shield ) then
      self.UKGutterman_Shield:Remove()
    end
    self.UKGutterman_Shield = nil
  end

  -- Difficulty profiles (canon SetSpeed): windupSpeed 0.5/0.75/1,
  -- trackingSpeedMultiplier 0.35/0.5/0.8/1. UltrakillBase difficulty enum:
  -- 0 HARMLESS / 1 LENIENT / 2 STANDARD / 3+ VIOLENT and up.
  local WINDUP_BY_DIFF = { [0] = 0.5, [1] = 0.75 }
  local TRACKMULT_BY_DIFF = { [0] = 0.35, [1] = 0.5, [2] = 0.8 }

  function ENT:UKGutterman_GetDifficulty()
    return self.UltrakillBase_Difficulty or 3
  end

  function ENT:UKGutterman_GetWindupSpeed()
    return WINDUP_BY_DIFF[ self:UKGutterman_GetDifficulty() ] or UKGutterman.WINDUP_SPEED
  end

  function ENT:UKGutterman_GetTrackingMult()
    return TRACKMULT_BY_DIFF[ self:UKGutterman_GetDifficulty() ] or 1
  end

  -- Canon turn rates: nav 120 deg/s, bash windup (trackInAction) 360 deg/s,
  -- lunge 90 deg/s, slowMode aim = instant snap onto the tracking position.
  function ENT:UKGutterman_SetYawRate( rate )
    if self.UKGutterman_YawRate ~= rate then
      self.UKGutterman_YawRate = rate
      self:SetMaxYawRate( rate )
    end
  end

  -- Actions ------------------------------------------------------------------

  function ENT:UKGutterman_PlayAction( name, sequence, duration )
    local seq = self:LookupSequence( sequence )
    if seq and seq >= 0 then
      self.UKGutterman_ActionSequence = sequence
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end
    self.UKGutterman_ActionName = name
    self.UKGutterman_ActionStart = CurTime()
    self.UKGutterman_ActionUntil = CurTime() + duration
    self.UKGutterman_ActionHits = {}
    self.UKGutterman_Firing = false
  end

  function ENT:UKGutterman_InAction()
    if self.UKGutterman_ActionUntil and self.UKGutterman_ActionUntil > CurTime() then return true end
    self.UKGutterman_ActionUntil = nil
    self.UKGutterman_ActionSequence = nil
    self.UKGutterman_ActionName = nil
    return false
  end

  function ENT:UKGutterman_ActionTime()
    return CurTime() - ( self.UKGutterman_ActionStart or 0 )
  end

  -- Animation ----------------------------------------------------------------

  function ENT:OnUpdateAnimation()
    if self.UKGutterman_ActionSequence and self:UKGutterman_InAction() then
      return self.UKGutterman_ActionSequence, 1
    end

    local rate = self.CalculateRate and self:CalculateRate() or 1
    -- Canon Walking animator bool: nav velocity > 2.5 m/s (100 su/s).
    local moving = ( self:IsRunning() or self:IsMoving() )
      and self.loco:GetVelocity():Length() > 100
    -- Canon: animator WalkSpeed parameter halves the walk cycle in slow mode.
    local walkRate = ( self.UKGutterman_SlowMode and 0.5 or 1 ) * rate

    if self.UKGutterman_Firing then
      if self.UKGutterman_HasShield then
        if moving then return "ShootWalk", walkRate end
        return "ShootIdle", rate
      end
      if moving then return "ShootWalkShieldless", walkRate end
      return "ShootIdleShieldless", rate
    end

    if not self.UKGutterman_HasShield then
      if moving then return "WalkShieldless", walkRate end
      return "IdleShieldless", rate
    end

    if moving then return "Walk", walkRate end
    return "Idle", rate
  end

  function ENT:OnUpdateSpeed()
    local rate = self.CalculateRate and self:CalculateRate() or 1
    -- Canon: nav agent speed is halved while in slow mode (aiming/firing).
    local speed = self.UKGutterman_SlowMode and ( UKGutterman.MOVE_SPEED * 0.5 ) or UKGutterman.MOVE_SPEED
    return speed * rate
  end

  -- Damage ---------------------------------------------------------------------

  function ENT:UKGutterman_IsKnuckleblasterDamage( dmg )
    local attacker = dmg:GetAttacker()
    local inflictor = dmg:GetInflictor()
    local dtype = dmg:GetDamageType()

    if ( dtype == DMG_ALWAYSGIB or dmg:IsDamageType( DMG_ALWAYSGIB ) )
        and IsValid( attacker ) and attacker:IsPlayer() then
      return true
    end

    -- Canon: a parried Landmine breaks the shield. Our stand-in is the
    -- Guttertank mine — any mine blast reaching the shield pops it.
    if dmg:IsExplosionDamage() then
      local icls = IsValid( inflictor ) and string.lower( inflictor:GetClass() or "" ) or ""
      local acls = IsValid( attacker ) and string.lower( attacker:GetClass() or "" ) or ""
      if string.find( icls, "mine", 1, true ) or string.find( acls, "mine", 1, true ) then
        return true
      end
    end

    if not IsValid( attacker ) or not attacker:IsPlayer() then return false end

    local wep = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or NULL
    local cls = IsValid( wep ) and string.lower( wep:GetClass() or "" ) or ""

    -- canon OnDamage: hitter "hammer" breaks the shield too — the dredux
    -- Impact Hammers (weapon_dredux_uk_impact_*) hit with DMG_CLUB and the
    -- weapon itself as inflictor.
    if string.find( cls, "impact", 1, true ) and dmg:IsDamageType( DMG_CLUB )
        and ( not IsValid( inflictor ) or inflictor == attacker or inflictor == wep ) then
      return true
    end

    if IsValid( inflictor ) and inflictor ~= attacker then return false end

    if string.find( cls, "knuckle", 1, true ) then return true end

    if dtype == DMG_GENERIC or dmg:IsDamageType( DMG_CLUB ) then
      return DamageStackHasKnuckleblasterArm()
    end

    return false
  end

  function ENT:UKGutterman_TryShieldBreak( dmg )
    if not self.UKGutterman_HasShield then return false end
    if not self:UKGutterman_IsKnuckleblasterDamage( dmg ) then return false end
    self:UKGutterman_BreakShield( dmg:GetAttacker() )
    return true
  end

  function ENT:UKGutterman_BreakShield( breaker )
    if not self.UKGutterman_HasShield then return end

    self.UKGutterman_HasShield = false
    self.UKGutterman_Firing = false
    self.UKGutterman_SlowMode = false
    self.UKGutterman_Windup = 0
    self.UKGutterman_TrackingSpeed = UKGutterman.TRACK_DEFAULT

    self:UKGutterman_RemoveShield()
    self:SetBodygroupByNameSafe( "shield", 1 )
    self:EmitSound( UKGutterman.SOUND.ShieldBreak )
    self:EmitSound( UKGutterman.SOUND.Bonk )

    -- Canon ShieldBreak calls NewMovement.Parry(null, "GUARD BREAK"): the
    -- breaker gets the full parry feedback — flash, hitstop, heal/stamina.
    local flashPos = self:UKGutterman_GetShieldFlashPos()
    if UltrakillBase.HitStop then UltrakillBase.HitStop( 0.25 ) end
    if UltrakillBase.SoundScript then UltrakillBase.SoundScript( "Ultrakill_Parry", flashPos ) end
    if IsValid( breaker ) and breaker:IsPlayer() and UltrakillBase.OnParryPlayer then
      UltrakillBase.OnParryPlayer( breaker )
    end
    if self.CreateAlert then self:CreateAlert( flashPos, 1, 4 ) end

    self:UKGutterman_PlayAction( "ShieldBreak", "ShieldBreak", ACTION.ShieldBreak.duration )

    -- canon Gutterman.ShieldBreak: `if (difficulty >= 4) Enrage()` — on Brutal
    -- and above losing the shield sends him into a rage
    -- (workshop report 2026-07-10: this branch was missing)
    if self:UKGutterman_GetDifficulty() >= 4 then self:UKGutterman_Enrage() end
  end

  -- Canon Gutterman.Enrage: 10 s of rage (red aura, enrage scream + loop);
  -- the gameplay bite is the smack turning unparryable while it lasts. No
  -- canon speed/damage buff, so all multipliers stay neutral.
  -- Visual = canon EnemySimplifier texture swap: slot 0 (the body atlas)
  -- switches to T_GuttermanEnraged (fullbright red repaint, extracted from
  -- models.bundle); the skeleton slot stays stock — round 2 2026-07-10.
  function ENT:UKGutterman_SetRageSkin( on )
    if on then
      local slots = {}
      for i, m in ipairs( self:GetMaterials() ) do
        if not string.find( string.lower( m ), "skeleton", 1, true ) then
          slots[ #slots + 1 ] = i - 1
          self:SetSubMaterial( i - 1,
            "models/ultrakill_prelude_test/gutterman/gutterman_enraged" )
        end
      end
      self.UKGutterman_RageSlots = slots
    else
      for _, idx in ipairs( self.UKGutterman_RageSlots or {} ) do
        self:SetSubMaterial( idx )
      end
      self.UKGutterman_RageSlots = nil
    end
  end

  function ENT:UKGutterman_Enrage()
    if self.UKGutterman_Dead then return end
    self.UKGutterman_EnrageUntil = CurTime() + 10
    if UKEnrage and UKEnrage.Apply then
      UKEnrage.Apply( self, { dmgMult = 1, speedMult = 1, animRate = 1 } )
    elseif self.SetEnraged then
      self:SetEnraged( true )
    end
    self:UKGutterman_SetRageSkin( true )
    timer.Create( "UKGutterman_Enrage_" .. self:EntIndex(), 10, 1, function()
      if not IsValid( self ) or self.UKGutterman_Dead then return end
      if ( self.UKGutterman_EnrageUntil or 0 ) > CurTime() then return end
      if UKEnrage and UKEnrage.Remove then
        UKEnrage.Remove( self )
      elseif self.SetEnraged then
        self:SetEnraged( false )
      end
      self:UKGutterman_SetRageSkin( false )
    end )
  end

  function ENT:UKGutterman_GotParried()
    -- Canon GotParried: stagger anim, bonk, reset windup/tracking, 5 s bash lock.
    self:UKGutterman_PlayAction( "ShieldBreak", "ShieldBreak", ACTION.ShieldBreak.duration )
    self.UKGutterman_LastParried = CurTime()
    self.UKGutterman_Windup = 0
    self.UKGutterman_SlowMode = false
    self.UKGutterman_Firing = false
    self.UKGutterman_TrackingSpeed = UKGutterman.TRACK_DEFAULT
    self:EmitSound( UKGutterman.SOUND.Bonk )

    -- canon Gutterman.GotParried: Brutal+ answers a parry with the same rage
    if self:UKGutterman_GetDifficulty() >= 4 then self:UKGutterman_Enrage() end
  end

  -- Standard UltrakillBase parry: base OnParry adds 5000 + DMG_DIRECT, plays
  -- the parry sound, hitstops and clears the Parryable flag; we bolt the canon
  -- Gutterman reaction on top.
  function ENT:OnParry( ply, dmg )
    BaseClass.OnParry( self, ply, dmg )
    self.UKGutterman_ParryWindowUntil = nil
    self:UKGutterman_GotParried()
  end

  function ENT:OnTakeDamage( dmg, hitgroup )
    if self.UKGutterman_Dead then return end

    -- Parry (melee/point-blank-shotgun while the SetParryable window is open)
    -- runs inside BaseClass.OnTakeDamage AFTER DamageMultiplier; an earlier
    -- CheckParry would put the flat +5000 bonus under the x10 multiplier.

    if self.UKGutterman_HasShield then
      if not self:UKGutterman_TryShieldBreak( dmg ) then
        if self:UKGutterman_ShieldCoversDamage( dmg ) then
          -- The shield is a wall: damage sourced from its far side (railcannon
          -- and rocket blasts bursting on the shield face, grenades bounced
          -- off it) is eaten entirely. Breakers were already handled above.
          dmg:SetDamage( 0 )
        else
          -- Canon: body hits are softened while the shield is up; the breaking
          -- hit itself goes through at full damage.
          dmg:SetDamage( dmg:GetDamage() / 1.5 )
        end
      end
    end

    BaseClass.OnTakeDamage( self, dmg, hitgroup or HITGROUP_GENERIC )
  end

  -- True when the live shield stands between the damage source and the body,
  -- so frontal blasts don't splash through the wall. Uses the damage position
  -- (blast origin) and falls back to the attacker when the position is
  -- degenerate (some weapons stamp the victim's own center on the DamageInfo).
  function ENT:UKGutterman_ShieldCoversDamage( dmg )
    local shield = self.UKGutterman_Shield
    if not IsValid( shield ) then return false end

    local center = self:WorldSpaceCenter()
    local src = dmg:GetDamagePosition()
    if src:IsZero() or src:DistToSqr( center ) < 4 then
      local att = IsValid( dmg:GetAttacker() ) and dmg:GetAttacker() or dmg:GetInflictor()
      if not IsValid( att ) then return false end
      src = att:WorldSpaceCenter()
    end

    local hit = util.IntersectRayWithOBB(
      src, center - src,
      shield:GetPos(), shield:GetAngles(),
      UKGutterman.SHIELD_MINS, UKGutterman.SHIELD_MAXS )
    if not hit then return false end

    if shield.UKGutterman_ShieldHitFeedback then
      shield:UKGutterman_ShieldHitFeedback( hit )
    end
    return true
  end

  -- Vision / windup -----------------------------------------------------------

  -- Canon VisionSourcePosition = the chest bone (mach.chest).
  function ENT:UKGutterman_GetEyePos()
    local b = self:LookupBone( "Spine_03" )
    if b then
      local m = self:GetBoneMatrix( b )
      if m then return m:GetTranslation() end
    end
    return self:WorldSpaceCenter() + self:GetUp() * 30
  end

  function ENT:UKGutterman_GetTargetHead( enemy )
    -- Players: canon aims at the head.
    if enemy:IsPlayer() then
      local ok, pos = pcall( enemy.EyePos, enemy )
      if ok and isvector( pos ) then return pos end
    end
    -- NPC/nextbot targets: EyePos on nextbots often floats above the actual
    -- hitboxes, which sent every beam whistling over their heads (zero
    -- minigun damage vs NPCs). Mass center is always inside the hitboxes.
    return enemy:WorldSpaceCenter()
  end

  function ENT:UKGutterman_HasLineOfSight( enemy )
    if not IsValid( enemy ) then return false end

    local tr = util.TraceLine( {
      start = self:UKGutterman_GetEyePos(),
      endpos = self:UKGutterman_GetTargetHead( enemy ),
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self then return false end
        if ent == self.UKGutterman_Shield then return false end
        return true
      end,
    } )

    return not tr.Hit or tr.Entity == enemy
  end

  function ENT:UKGutterman_StartWindupSound()
    if self.UKGutterman_WindupSound then return end
    self.UKGutterman_WindupSound = CreateSound( self, UKGutterman.SOUND.GunWindup )
  end

  function ENT:UKGutterman_StopWindupSound()
    if self.UKGutterman_WindupSound then
      self.UKGutterman_WindupSound:Stop()
      self.UKGutterman_WindupSound = nil
    end
  end

  function ENT:UKGutterman_UpdateWindupSound()
    local windup = self.UKGutterman_Windup
    if windup <= 0 then
      if self.UKGutterman_WindupSound then self.UKGutterman_WindupSound:Stop() end
      return
    end
    self:UKGutterman_StartWindupSound()
    local snd = self.UKGutterman_WindupSound
    if not snd then return end
    if not snd:IsPlaying() then snd:Play() end
    -- Canon: windup audio pitch = windup * 3.
    snd:ChangePitch( math.Clamp( windup * 300, 30, 255 ), 0.05 )
    snd:ChangeVolume( math.Clamp( 0.3 + windup * 0.7, 0, 1 ), 0.05 )
  end

  -- Canon Update/AttackUpdate/SetFiring ---------------------------------------

  function ENT:UKGutterman_CanonUpdate( enemy, dt )
    local hasVision = self:UKGutterman_HasLineOfSight( enemy )
    local pos = self:GetPos()
    local headPos = self:UKGutterman_GetTargetHead( enemy )

    -- lineOfSightTimer
    self.UKGutterman_LOSTimer = math.Approach( self.UKGutterman_LOSTimer, hasVision and 1 or 0, dt * 2 )

    -- windup
    local windupSpeed = self:UKGutterman_GetWindupSpeed()
    if self.UKGutterman_LOSTimer >= 0.9 or ( self.UKGutterman_SlowMode and self.UKGutterman_LOSTimer > 0 ) then
      self.UKGutterman_Windup = math.Approach( self.UKGutterman_Windup, 1, dt * windupSpeed )
    else
      self.UKGutterman_Windup = math.Approach( self.UKGutterman_Windup, 0, dt * windupSpeed )
    end

    if self:UKGutterman_InAction() then
      self.UKGutterman_Firing = false
      -- canon: low difficulties dump the windup while in an action
      if self:UKGutterman_GetDifficulty() <= 1 then self.UKGutterman_Windup = 0 end
      return
    end

    -- slowMode latch (enter at windup >= 0.5, leave only at windup 0)
    if self.UKGutterman_Windup >= 0.5 then
      if not self.UKGutterman_SlowMode then
        -- snap tracking ahead of him so the aim has to drag onto the target
        self.UKGutterman_TrackingPos = pos + self:GetForward()
          * math.max( 30 * UNIT, pos:Distance( headPos ) )
        self.UKGutterman_TrackingPos.z = pos.z + ( headPos.z - pos.z )
      end
      self.UKGutterman_SlowMode = true
    elseif self.UKGutterman_SlowMode and self.UKGutterman_Windup <= 0 then
      self.UKGutterman_SlowMode = false
      self:EmitSound( UKGutterman.SOUND.Release )
    end

    if self.UKGutterman_Firing and not self:IsOnGround() then
      self.UKGutterman_Firing = false
    end

    if self.UKGutterman_SlowMode then
      -- tracking ramps up while firing; faster without the shield
      if self.UKGutterman_Firing then
        self.UKGutterman_TrackingSpeed = self.UKGutterman_TrackingSpeed
          + dt * ( self.UKGutterman_HasShield and 2 or 5 ) * UNIT * self:UKGutterman_GetTrackingMult()
      end

      if self.UKGutterman_LOSTimer > 0 then
        self.UKGutterman_LastKnownPos = headPos
      end

      local lastKnown = self.UKGutterman_LastKnownPos or headPos
      local track = self.UKGutterman_TrackingPos or lastKnown
      local step = ( headPos:Distance( track ) + self.UKGutterman_TrackingSpeed ) * dt
      local toTarget = lastKnown - track
      local dist = toTarget:Length()
      if dist <= step then
        track = lastKnown
      else
        track = track + toTarget * ( step / dist )
      end
      self.UKGutterman_TrackingPos = track

      -- canon: body rotation snaps straight onto the tracking position every
      -- frame (transform.rotation = LookRotation); the lag lives in the
      -- tracking point itself, not in a turn-rate clamp. FaceTowards alone
      -- loses the fight against DrGBase's own path-facing (he walked at the
      -- target SIDEWAYS while firing), so hard-assign the yaw like canon
      -- hard-assigns transform.rotation.
      self:UKGutterman_SetYawRate( 3600 )
      local flat = Vector( track.x, track.y, pos.z )
      self:FaceTowards( flat )
      local toTrack = flat - pos
      if toTrack:LengthSqr() > 1 then
        local ang = self:GetAngles()
        ang.y = toTrack:Angle().y
        self:SetAngles( ang )
      end
    else
      self.UKGutterman_TrackingSpeed = UKGutterman.TRACK_DEFAULT
      self.UKGutterman_TrackingPos = nil
      self:UKGutterman_SetYawRate( 120 )
    end

    -- canon SetFiring
    self:UKGutterman_UpdateFiring( enemy, headPos )

    -- canon ShieldBash trigger
    if hasVision and self.UKGutterman_LOSTimer >= 0.5
        and CurTime() - self.UKGutterman_LastParried > 5
        and CurTime() >= self.UKGutterman_NextBash
        and self:IsOnGround()
        and headPos:Distance( pos ) < UKGutterman.BASH_RANGE then
      self:UKGutterman_StartBash()
    end
  end

  function ENT:UKGutterman_UpdateFiring( enemy, headPos )
    local windup = self.UKGutterman_Windup
    local want = IsValid( enemy )
      and self.UKGutterman_SlowMode
      and windup >= 0.5
      and ( self.UKGutterman_Firing or windup >= 1 )
      and self:IsOnGround()

    if not want then
      self.UKGutterman_Firing = false
      return
    end

    -- canon FiringEnemyCheck: hold fire if another living non-target NPC
    -- (that is not us / our shield / a corpse) blocks the line of fire.
    local start = self:GetPos() + Vector( 0, 0, UNIT ) + self:GetForward() * ( 3 * UNIT )
    local tr = util.TraceLine( {
      start = start,
      endpos = headPos,
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self or ent == self.UKGutterman_Shield then return false end
        return true
      end,
    } )

    local hit = tr.Entity
    if IsValid( hit ) and hit ~= enemy and ( hit:IsNPC() or hit:IsNextBot() )
        and ( hit.Health and hit:Health() > 0 ) and not hit.UKGutterman_Corpse then
      self.UKGutterman_Firing = false
      return
    end

    -- Canon: a Coin in the line of fire fails FiringEnemyCheck -> the cannon
    -- spools down while a coin is between the Gutterman and his target. The
    -- canon check runs on the slow update, so rescan on a slow cadence — a
    -- coin tossed mid-burst still eats a beam (chargeback) before he stops.
    local now = CurTime()
    if not self.UKGutterman_NextCoinScan or now >= self.UKGutterman_NextCoinScan then
      self.UKGutterman_NextCoinScan = now + 0.35
      self.UKGutterman_CoinBlocked = IsValid( UKGutterman.FindBeamCoin( start, headPos ) )
    end
    if self.UKGutterman_CoinBlocked then
      self.UKGutterman_Firing = false
      return
    end

    self.UKGutterman_Firing = true
  end

  -- Possession stand-in for UKGutterman_CanonUpdate: the held trigger
  -- replaces the LOS timer as the windup driver, the aim point is the
  -- lock-on head (crosshair hit when nothing is locked — the canon tracking
  -- drag exists to give the target a dodge window, pointless against the
  -- possessor's own aim), and the bash starts from its bind only.
  function ENT:UKGutterman_PossessionUpdate( enemy, dt )
    local windupSpeed = self:UKGutterman_GetWindupSpeed()
    self.UKGutterman_Windup = math.Approach( self.UKGutterman_Windup,
      self.UKGutterman_PossessTrigger and 1 or 0, dt * windupSpeed )

    if self:UKGutterman_InAction() then
      self.UKGutterman_Firing = false
      self:UKGutterman_ProcessAction( enemy, dt )
      return
    end

    -- canon slowMode latch (enter at windup >= 0.5, leave only at windup 0)
    if self.UKGutterman_Windup >= 0.5 then
      self.UKGutterman_SlowMode = true
    elseif self.UKGutterman_SlowMode and self.UKGutterman_Windup <= 0 then
      self.UKGutterman_SlowMode = false
      self:EmitSound( UKGutterman.SOUND.Release )
    end

    if self.UKGutterman_SlowMode then
      local aim
      if IsValid( enemy ) then
        aim = self:UKGutterman_GetTargetHead( enemy )
      else
        -- the crosshair ray must skip the solid shield helper hanging in
        -- front of the body (a custom filter replaces the default one, so
        -- self and the possessor go back in)
        local filter = { self, self:GetPossessor() }
        if IsValid( self.UKGutterman_Shield ) then filter[ #filter + 1 ] = self.UKGutterman_Shield end
        aim = self:PossessorTrace( { filter = filter } ).HitPos
      end
      self.UKGutterman_TrackingPos = aim
      self.UKGutterman_LastKnownPos = aim

      -- canon slow mode hard-assigns the body yaw onto the aim point —
      -- DrGBase's own path-facing wins otherwise, same fight the AI branch
      -- solves in UKGutterman_CanonUpdate
      self:UKGutterman_SetYawRate( 3600 )
      local pos = self:GetPos()
      local flat = Vector( aim.x, aim.y, pos.z )
      self:FaceTowards( flat )
      local toTrack = flat - pos
      if toTrack:LengthSqr() > 1 then
        local ang = self:GetAngles()
        ang.y = toTrack:Angle().y
        self:SetAngles( ang )
      end
    else
      self.UKGutterman_TrackingSpeed = UKGutterman.TRACK_DEFAULT
      self.UKGutterman_TrackingPos = nil
      self:UKGutterman_SetYawRate( 120 )
    end

    -- canon SetFiring latch minus the AI-only friendly-fire/coin line checks;
    -- TrackingPos is the beam target when nothing is locked on, so it gates
    self.UKGutterman_Firing = self.UKGutterman_SlowMode
      and self.UKGutterman_Windup >= 0.5
      and ( self.UKGutterman_Firing or self.UKGutterman_Windup >= 1 )
      and self:IsOnGround()
      and self.UKGutterman_TrackingPos ~= nil

    self:UKGutterman_FireMinigun( enemy, dt )
  end

  -- Minigun --------------------------------------------------------------------

  function ENT:UKGutterman_FireMinigun( enemy, dt )
    -- possessed with nothing locked on: enemy is NULL but the possession
    -- update always supplies a tracking position for the beams
    if not self.UKGutterman_Firing or ( not IsValid( enemy ) and not self:IsPossessed() ) then
      -- spool the NPC damage-gate ramp back down twice as fast as it built up
      local ramp = math.max( ( self.UKGutterman_FireRamp or 0 ) - dt * 2, 0 )
      self.UKGutterman_FireRamp = ramp
      if ramp <= 0 then self.UKGutterman_NpcHitGate = nil end
      self.UKGutterman_BulletCooldown = math.max( ( self.UKGutterman_BulletCooldown or 0 ) - dt, 0 )
      return
    end

    self.UKGutterman_FireRamp = ( self.UKGutterman_FireRamp or 0 ) + dt

    local windup = math.max( self.UKGutterman_Windup, 0.5 )
    local interval = 0.05 / windup
    local cooldown = ( self.UKGutterman_BulletCooldown or 0 ) - dt
    local shots = 0

    while cooldown <= 0 and shots < 6 do
      self:UKGutterman_FireBeam( enemy )
      shots = shots + 1
      cooldown = cooldown + interval
    end

    self.UKGutterman_BulletCooldown = math.max( cooldown, 0 )
  end

  -- The longer the cannon stays spun up, the faster the NPC damage gate
  -- ticks: NPC_HIT_COOLDOWN_START at trigger pull, ~half after
  -- NPC_GATE_HALVE_TIME seconds of sustained fire, floored at the MIN.
  -- Players are exempt (canon i-frames: flat ~10 HP per second).
  function ENT:UKGutterman_GetNpcGateInterval()
    local ramp = self.UKGutterman_FireRamp or 0
    return math.max(
      UKGutterman.NPC_HIT_COOLDOWN_START / ( 1 + ramp / UKGutterman.NPC_GATE_HALVE_TIME ),
      UKGutterman.NPC_HIT_COOLDOWN_MIN )
  end

  function ENT:UKGutterman_FireBeam( enemy )
    local muzzle = self:UKGutterman_GetMuzzle()
    local target = self.UKGutterman_TrackingPos or self:UKGutterman_GetTargetHead( enemy )

    local dir = target - muzzle
    if dir:LengthSqr() < 1 then dir = self:GetForward() else dir:Normalize() end

    -- canon: random rotate -1..1 degrees per axis
    local ang = dir:Angle()
    ang:RotateAroundAxis( ang:Right(), math.Rand( -1, 1 ) )
    ang:RotateAroundAxis( ang:Up(), math.Rand( -1, 1 ) )
    dir = ang:Forward()

    local filter = function( ent )
      if ent == self then return false end
      if ent == self.UKGutterman_Shield then return false end
      return true
    end

    -- canon FixedUpdate: if anything sits within 4 m in front of a point 4 m
    -- behind the muzzle, the beam fires from back there (point-blank targets
    -- still get hit); otherwise from the muzzle jittered +-0.2 m right/up.
    local back = muzzle - dir * ( 4 * UNIT )
    local blockTr = util.TraceLine( { start = back, endpos = muzzle, mask = MASK_SHOT, filter = filter } )
    local start = blockTr.Hit and back
      or ( muzzle + ang:Right() * math.Rand( -8, 8 ) + ang:Up() * math.Rand( -8, 8 ) )

    local tr = util.TraceLine( {
      start = start,
      endpos = start + dir * 12000,
      mask = MASK_SHOT,
      filter = filter,
    } )

    local hitPos = tr.HitPos

    -- COIN CHARGEBACK (canon RevolverBeam: an enemy beam that hits a Coin is
    -- deflected — the coin mod runs its own Ricoshot into the nearest valid
    -- target, us included, when we damage the coin with the thrower as
    -- attacker). Reflected damage is canon-"abysmal": 0.5 enemy units.
    local coin = UKGutterman.FindBeamCoin( start, hitPos )
    if IsValid( coin ) then
      hitPos = coin:GetPos()
      self:UKGutterman_EmitBeamFx( muzzle, hitPos )

      local owner = coin:GetOwner()
      if not ( IsValid( owner ) and owner:IsPlayer() ) then
        local best, bd = nil, math.huge
        for _, ply in ipairs( player.GetAll() ) do
          local d = ply:GetPos():DistToSqr( hitPos )
          if d < bd then best, bd = ply, d end
        end
        owner = best
      end

      local dmg = DamageInfo()
      dmg:SetDamage( UKGutterman.BEAM_COIN_DAMAGE )
      dmg:SetDamageType( DMG_BULLET )
      dmg:SetAttacker( IsValid( owner ) and owner or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( hitPos )
      dmg:SetReportedPosition( hitPos )
      dmg:SetDamageForce( dir )
      coin:TakeDamageInfo( dmg )
      return
    end

    self:UKGutterman_EmitBeamFx( muzzle, hitPos )

    if not tr.Hit then return end

    if tr.HitWorld or ( IsValid( tr.Entity ) and not ( tr.Entity:IsPlayer() or tr.Entity:IsNPC() or tr.Entity:IsNextBot() ) ) then
      local imp = EffectData()
      imp:SetOrigin( tr.HitPos )
      imp:SetStart( muzzle )
      imp:SetSurfaceProp( tr.SurfaceProps or 0 )
      imp:SetDamageType( DMG_BULLET )
      imp:SetHitBox( tr.HitBox or 0 )
      imp:SetEntity( tr.Entity )
      util.Effect( "Impact", imp )
    end

    local hit = tr.Entity
    if not IsValid( hit ) then return end
    if hit.UKGutterman_IsShieldHelper then return end
    if self:UKGutterman_TryDetonateProjectile( hit, tr.HitPos ) then return end
    if not ( hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot() or hit.UKGutterman_Corpse ) then return end

    -- Canon player hit: GetHurt(damage x10, invincible: true) — every hit
    -- grants i-frames, so sustained fire deals ~10 damage per second, not
    -- 10 per bullet at 20 bullets/sec. NPCs tick on the same kind of gate,
    -- but theirs spins up with the cannon (UKGutterman_GetNpcGateInterval)
    -- and each tick hits much harder than a single canon beam.
    local now = CurTime()
    if hit:IsPlayer() then
      self.UKGutterman_PlayerHitGate = self.UKGutterman_PlayerHitGate or {}
      local gate = self.UKGutterman_PlayerHitGate[ hit ]
      if gate and gate > now then return end
      self.UKGutterman_PlayerHitGate[ hit ] = now + UKGutterman.PLAYER_HIT_COOLDOWN
    else
      self.UKGutterman_NpcHitGate = self.UKGutterman_NpcHitGate or {}
      local gate = self.UKGutterman_NpcHitGate[ hit ]
      if gate and gate > now then return end
      self.UKGutterman_NpcHitGate[ hit ] = now + self:UKGutterman_GetNpcGateInterval()
    end

    local dmg = DamageInfo()
    if hit:IsPlayer() then
      dmg:SetDamage( UKGutterman.ScaleDamage( hit, UKGutterman.BEAM_DAMAGE_PLAYER ) )
    else
      dmg:SetDamage( UKGutterman.ScaleDamage( hit,
        UKGutterman.BEAM_NPC_TICK_PLAYER_UNITS, UKGutterman.BEAM_NPC_TICK_UNITS ) )
    end
    dmg:SetDamageType( DMG_BULLET )
    dmg:SetAttacker( self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( tr.HitPos )
    dmg:SetDamageForce( dir * 400 )
    hit:TakeDamageInfo( dmg )
  end

  function ENT:UKGutterman_EmitBeamFx( muzzle, hitPos )
    -- canon Gutterman Beam: 0.5 m white->yellow line + warm light
    local fx = EffectData()
    fx:SetStart( muzzle )
    fx:SetOrigin( hitPos )
    fx:SetEntity( self )
    util.Effect( "ultrakill_test_gutterman_tracer", fx, true, true )

    -- canon beam AudioSource: MachineGun3B, volume 0.35, RandomPitch 0.7+-0.1
    self:EmitSound( UKGutterman.SOUND.Fire, 85, math.random( 60, 80 ), 0.4 )
  end

  function ENT:UKGutterman_IsHellOrbLike( ent )
    if not IsValid( ent ) then return false end
    local cls = string.lower( ent:GetClass() or "" )
    if UKGutterman.EXCLUDED_ORB_CLASS[ cls ] then return true end
    return string.find( cls, "hell", 1, true ) and string.find( cls, "orb", 1, true )
  end

  function ENT:UKGutterman_IsExplosiveProjectile( ent )
    if not IsValid( ent ) or self:UKGutterman_IsHellOrbLike( ent ) then return false end
    if ent.UKGutterman_ExplosiveProjectile == true then return true end

    local cls = string.lower( ent:GetClass() or "" )
    for word in pairs( EXPLOSIVE_WORDS ) do
      if string.find( cls, word, 1, true ) then return true end
    end

    return false
  end

  function ENT:UKGutterman_TryDetonateProjectile( ent, hitPos )
    if not self:UKGutterman_IsExplosiveProjectile( ent ) then return false end

    if ent.UKRocket_Explode then ent:UKRocket_Explode( hitPos, self ) return true end
    if ent.Detonate then ent:Detonate( hitPos, self ) return true end
    if ent.Explode then ent:Explode( hitPos, self ) return true end
    if ent.UKExplode then ent:UKExplode( hitPos, self ) return true end

    ent:Remove()
    return true
  end

  -- Melee ----------------------------------------------------------------------

  function ENT:UKGutterman_GetShieldFlashPos()
    local bone = self:LookupBone( "Shield 1" )
    if bone then
      local m = self:GetBoneMatrix( bone )
      if m then return m:GetTranslation() + self:GetForward() * 50 end
    end
    return self:WorldSpaceCenter() + self:GetForward() * 70
  end

  function ENT:UKGutterman_StartBash()
    if self:UKGutterman_InAction() then return end
    self.UKGutterman_NextBash = CurTime() + 0.4

    -- canon: at STANDARD and below a shielded bash sets lastParried = 3, which
    -- gates the next bash for ~2 s; VIOLENT+ can chain bashes immediately
    if self:UKGutterman_GetDifficulty() <= 2 and self.UKGutterman_HasShield then
      self.UKGutterman_LastParried = CurTime() - 3
    end

    -- canon: flash at shield[0] + forward, x15 scale; with shield OR enraged ->
    -- unparryable (blue, alert type 2), plain shieldless smack -> parryable
    -- (yellow, type 1) — Gutterman.ShieldBash: (hasShield || enraged)
    local unparryable = self.UKGutterman_HasShield or self:IsEnraged()
    if self.CreateAlert then
      self:CreateAlert( self:UKGutterman_GetShieldFlashPos(), unparryable and 2 or 1, 3 )
    end

    if self.UKGutterman_HasShield then
      self:UKGutterman_PlayAction( "ShieldBash", "ShieldBash", ACTION.ShieldBash.duration )
    else
      self:UKGutterman_PlayAction( "Smack", "Smack", ACTION.Smack.duration )
      -- canon: shieldless smack is parryable from windup until ShieldBashStop —
      -- unless raging (canon: `if (!hasShield && !enraged) mach.parryable = true`)
      if not self:IsEnraged() then
        self:SetParryable( true )
        self.UKGutterman_ParryWindowUntil = CurTime() + ACTION.Smack.stop
      end
    end
  end

  function ENT:UKGutterman_ProcessAction( enemy, dt )
    local name = self.UKGutterman_ActionName
    if not name then return end
    local t = self:UKGutterman_ActionTime()
    local cfg = ACTION[ name ]
    if not cfg then return end

    if name == "ShieldBash" or name == "Smack" then
      if t < cfg.active then
        -- canon trackInAction: turn onto the target at 360 deg/s before the swing
        self:UKGutterman_SetYawRate( 360 )
        if IsValid( enemy ) then self:FaceTowards( enemy ) end
      elseif t <= cfg.stop then
        -- canon moveForward: keep correcting at 90 deg/s during the lunge
        self:UKGutterman_SetYawRate( 90 )
        if IsValid( enemy ) then self:FaceTowards( enemy ) end
        -- canon ShieldBashActive: lunge forward + damage window.
        -- Canon speeds are 25/45 m/s, but on GMod-scale arenas that read as
        -- him rocketing way past the target — cooled to ~60% per live
        -- feedback (still a clear lunge, no more fly-by).
        local lunge = ( self.UKGutterman_HasShield and 15 or 27 ) * UNIT
        local ahead = self:GetPos() + Vector( 0, 0, UNIT ) + self:GetForward() * UNIT
        local ground = util.TraceLine( {
          start = ahead,
          endpos = ahead - Vector( 0, 0, 22 * UNIT ),
          mask = MASK_SOLID_BRUSHONLY,
        } )
        if ground.Hit then
          self.loco:SetVelocity( self:GetForward() * lunge )
        else
          self.loco:SetVelocity( vector_origin )
        end
        self:UKGutterman_DoMeleeDamage( UKGutterman.MELEE[ name ] )
      end
    end
  end

  -- Canon damage comes from a SwingCheck2 trigger collider on the shield /
  -- hand — contact only. Approximate it with a tight frontal zone tested
  -- against the target's closest hull point, not its origin, so big targets
  -- still register on touch while distant ones never take phantom hits.
  function ENT:UKGutterman_DoMeleeDamage( melee )
    if not melee then return end
    local fwd = self:GetForward()
    local center = self:WorldSpaceCenter()
    local origin = center + fwd * UKGutterman.BASH_HIT_FORWARD
    local hits = self.UKGutterman_ActionHits or {}
    self.UKGutterman_ActionHits = hits

    for _, ent in ipairs( ents.FindInSphere( origin, UKGutterman.BASH_HIT_RADIUS ) ) do
      if ent == self or not IsValid( ent ) or hits[ ent ] then continue end
      if ent == self.UKGutterman_Shield then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

      -- contact check: nearest point of the target hull must be inside the
      -- swing zone and in front of us
      local nearest = ent:NearestPoint( origin )
      if nearest:DistToSqr( origin ) > UKGutterman.BASH_HIT_RADIUS * UKGutterman.BASH_HIT_RADIUS then continue end
      if fwd:Dot( nearest - center ) < 0 then continue end

      hits[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( UKGutterman.ScaleDamage( ent, melee.player, melee.units ) )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      dmg:SetDamageForce( fwd * 1500 + Vector( 0, 0, 300 ) )
      ent:TakeDamageInfo( dmg )
    end
  end

  function ENT:OnMeleeAttack( enemy )
    -- canon bash is triggered from the think update with its own gates
    return
  end

  function ENT:OnRangeAttack( enemy )
    -- minigun runs from CustomThink; the base scheduler must not double-fire
    return
  end

  -- Footsteps -------------------------------------------------------------------

  local WALK_STEPS = { 0.218, 0.736 } -- Walk_3 footstep events / 1.3 s clip

  function ENT:UKGutterman_UpdateFootsteps()
    if not ( self:IsMoving() or self:IsRunning() ) then return end
    local seqName = self:GetSequenceName( self:GetSequence() ) or ""
    if not string.find( seqName, "Walk", 1, true ) then return end

    local cycle = self:GetCycle()
    local last = self.UKGutterman_LastWalkCycle or 0
    for _, mark in ipairs( WALK_STEPS ) do
      local crossed = ( last < mark and cycle >= mark )
        or ( cycle < last and ( mark >= last or mark < cycle ) ) -- wrap
      if crossed then
        self:EmitSound( UKGutterman.SOUND.Step, 90, math.random( 95, 105 ) )
        break
      end
    end
    self.UKGutterman_LastWalkCycle = cycle
  end

  -- Think -------------------------------------------------------------------------

  function ENT:CustomThink()
    if CLIENT then return end
    if self.UKGutterman_Dead then return end
    -- ai_disabled / per-bot disable (DrGBase keeps possession alive under it)
    if self:IsAIDisabled() and not self:IsPossessed() then
      -- don't freeze mid-burst: the minigun state, loop sound and the client
      -- barrel spin (NW windup) would stick on
      if self.UKGutterman_Firing then
        self.UKGutterman_Firing = false
        self.UKGutterman_LastFiringNW = false
        self:SetNWBool( "UKG_Firing", false )
      end
      if self.UKGutterman_Windup > 0 then
        self.UKGutterman_Windup = 0
        self:SetNWFloat( "UKG_Windup", 0 )
      end
      self:UKGutterman_StopWindupSound()
      return
    end

    local now = CurTime()
    local dt = now - ( self.UKGutterman_LastThink or now )
    self.UKGutterman_LastThink = now
    if dt <= 0 then dt = FrameTime() end
    dt = math.min( dt, 0.25 )

    -- close the standard-framework parry window when its timer runs out
    if self.UKGutterman_ParryWindowUntil and now >= self.UKGutterman_ParryWindowUntil then
      self.UKGutterman_ParryWindowUntil = nil
      self:SetParryable( false )
    end

    -- possessed: the base GetEnemy override returns the lock-on target
    -- (NULL entity when nothing is locked)
    local enemy = self:GetEnemy()

    if self:IsPossessed() then
      -- no autonomous windup/firing/bash decisions; ProcessAction keeps
      -- running inside so bind-started actions still execute
      self:UKGutterman_PossessionUpdate( enemy, dt )
    elseif IsValid( enemy ) then
      self:UKGutterman_CanonUpdate( enemy, dt )
      if self:UKGutterman_InAction() then
        self:UKGutterman_ProcessAction( enemy, dt )
      else
        self:UKGutterman_FireMinigun( enemy, dt )
      end
    else
      self.UKGutterman_Firing = false
      self.UKGutterman_LOSTimer = math.Approach( self.UKGutterman_LOSTimer, 0, dt * 2 )
      self.UKGutterman_Windup = math.Approach( self.UKGutterman_Windup, 0, dt * self:UKGutterman_GetWindupSpeed() )
      self:UKGutterman_SetYawRate( 120 )
      if self.UKGutterman_SlowMode and self.UKGutterman_Windup <= 0 then
        self.UKGutterman_SlowMode = false
        self:EmitSound( UKGutterman.SOUND.Release )
      end
      if self:UKGutterman_InAction() then
        self:UKGutterman_ProcessAction( enemy, dt )
      end
    end

    self:UKGutterman_UpdateAimPitch( dt )
    self:UKGutterman_UpdateWindupSound()
    self:UKGutterman_UpdateFootsteps()
    self:SetNWFloat( "UKG_Windup", self.UKGutterman_Windup )
    if self.UKGutterman_LastFiringNW ~= self.UKGutterman_Firing then
      self.UKGutterman_LastFiringNW = self.UKGutterman_Firing
      self:SetNWBool( "UKG_Firing", self.UKGutterman_Firing )
    end
  end

  -- Canon LateUpdate: torso/gun lean toward the tracking position. Driven via
  -- the aim_pitch blend baked into the Shoot combo sequences (positive = up).
  function ENT:UKGutterman_UpdateAimPitch( dt )
    local target = 0

    if self.UKGutterman_SlowMode and self.UKGutterman_TrackingPos and not self:UKGutterman_InAction() then
      local from = self:WorldSpaceCenter() + self:GetUp() * 30
      local diff = self.UKGutterman_TrackingPos - from
      local horiz = math.sqrt( diff.x * diff.x + diff.y * diff.y )
      target = math.Clamp( math.deg( math.atan2( diff.z, math.max( horiz, 1 ) ) ), -45, 45 )
    end

    local cur = self.UKGutterman_AimPitch or 0
    -- canon slowModeLerp ramps at 2.5/s; 120 deg/s gives a similar feel
    cur = math.Approach( cur, target, dt * 120 )
    self.UKGutterman_AimPitch = cur
    self:SetPoseParameter( "aim_pitch", cur )
  end

  -- Death ---------------------------------------------------------------------------

  function ENT:OnDeath( dmg, hitgroup )
    self.UKGutterman_Dead = true
    self.UKGutterman_Firing = false
    self:SetNWBool( "UKG_Firing", false )
    self.UKGutterman_ParryWindowUntil = nil
    self:SetParryable( false )
    self:UKGutterman_StopWindupSound()
    self:UKGutterman_RemoveShield()
    self:EmitSound( UKGutterman.SOUND.Death, 95 )
    self:UKGutterman_PlayAction( "Death", "Death", ACTION.Death.duration )

    local startTime = CurTime()
    local fallStart = startTime + ACTION.Death.fallStart
    local fallOver = startTime + ACTION.Death.fallOver
    -- The corpse pose is the FINAL Death frame. Swapping at the FallOver
    -- event (73% of the clip) made the body visibly snap to the settled pose
    -- mid-fall — play the animation to the end and swap on its last frame.
    local deathEnd = startTime + ACTION.Death.duration
    local crushed = {}
    local fellOver = false

    while IsValid( self ) and CurTime() < deathEnd do
      if CurTime() >= fallStart and CurTime() < fallOver then
        self:UKGutterman_CrushUnderFall( crushed )
      end
      if not fellOver and CurTime() >= fallOver then
        fellOver = true
        self:UKGutterman_FallOverEffect()
      end
      self:YieldCoroutine()
    end

    if IsValid( self ) then
      if not fellOver then self:UKGutterman_FallOverEffect() end
      self:UKGutterman_SpawnCorpse( dmg )
      -- corpse creation and this NoDraw land in the same snapshot: whatever
      -- the framework does with the dying nextbot afterwards stays invisible
      self:SetNoDraw( true )
    end

    return dmg
  end

  function ENT:UKGutterman_GetChestPos()
    local b = self:LookupBone( "Spine_03" )
    if b then
      local m = self:GetBoneMatrix( b )
      if m then return m:GetTranslation() end
    end
    return self:WorldSpaceCenter()
  end

  function ENT:UKGutterman_CrushUnderFall( crushed )
    -- canon fallingKillTrigger: anything under the falling body dies
    local chest = self:UKGutterman_GetChestPos()
    local base = self:GetPos()

    for _, ent in ipairs( ents.FindInSphere( chest, 3 * UNIT ) ) do
      if ent == self or not IsValid( ent ) or crushed[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent:GetPos().z > chest.z + 20 then continue end

      crushed[ ent ] = true
      local dmg = DamageInfo()
      dmg:SetDamage( 1000000 )
      dmg:SetDamageType( DMG_CRUSH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      ent:TakeDamageInfo( dmg )
    end
  end

  function ENT:UKGutterman_FallOverEffect()
    local chest = self:UKGutterman_GetChestPos()
    local ground = Vector( chest.x, chest.y, self:GetPos().z )

    local fx = EffectData()
    fx:SetOrigin( ground )
    fx:SetScale( 160 )
    fx:SetNormal( Vector( 0, 0, 1 ) )
    util.Effect( "ThumperDust", fx, true, true )

    util.ScreenShake( ground, 10, 60, 0.7, 700 )
    -- canon GuttermanBonk on the body hitting the ground
    self:EmitSound( UKGutterman.SOUND.Bonk, 95 )
    sound.Play( "physics/metal/metal_largebox_impact_hard3.wav", ground, 90, 70 )
  end

  -- Jumping while standing on the living Gutterman: the engine keeps
  -- re-snapping the player onto the moving nextbot hull, so the jump impulse
  -- dies the same tick. Re-apply it manually when the ground entity is a
  -- live Gutterman (the corpse is ordinary VPhysics and jumps fine).
  hook.Add( "KeyPress", "UKGutterman_HeadJump", function( ply, key )
    if key ~= IN_JUMP or not ply:Alive() then return end
    local ground = ply:GetGroundEntity()
    if not IsValid( ground ) or ground.UKGutterman_Corpse then return end
    if not string.find( ground:GetClass() or "", "ultrakill_test_gutterman", 1, true ) then return end
    ply:SetVelocity( Vector( 0, 0, ply:GetJumpPower() ) )
  end )

  function ENT:UKGutterman_SpawnCorpse( dmg )
    if self.UKGutterman_CorpseSpawned then return end
    self.UKGutterman_CorpseSpawned = true

    local corpse = ents.Create( UKGutterman.CLASS.Corpse )
    if not IsValid( corpse ) then return end

    corpse:SetPos( self:GetPos() )
    corpse:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )
    corpse.UKGutterman_Casketless = self.UKGutterman_Casketless
    -- keep the shield on the corpse if he died with it up, or it pops out of
    -- existence on the swap frame
    corpse.UKGutterman_HadShield = self.UKGutterman_HasShield
    corpse:Spawn()
  end
end

if CLIENT then
  -- THE canon ULTRAKILL star — the same particles/ultrakill/muzzleflash
  -- texture the UltrakillBase attack alert flashes use, not a hand-drawn
  -- glow sphere.
  local STAR_MAT = Material( "particles/ultrakill/muzzleflash" )

  -- (enraged look = canon texture swap, handled server-side via
  -- SetSubMaterial in UKGutterman_Enrage — no client tint needed)

  -- Canon: every beam spawns a muzzle flash; at 10-20 beams/sec it reads as
  -- a steady flickering star + warm light hanging on the barrels. Drawn every
  -- frame from the live bone position so it never lags the gun; random roll
  -- per frame mirrors the canon random rotation of each spawned flash.
  function ENT:CustomDraw()
    if not self:GetNWBool( "UKG_Firing", false ) then return end

    local muzzle = self:UKGutterman_GetMuzzle()
    if not muzzle then return end

    local toEye = EyePos() - muzzle
    toEye:Normalize()
    local size = 46 * math.Rand( 0.8, 1.2 )
    render.SetMaterial( STAR_MAT )
    render.DrawQuadEasy( muzzle + toEye * 6, toEye, size, size,
      color_white, math.Rand( 0, 360 ) )

    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = muzzle
      dl.r = 255
      dl.g = 238
      dl.b = 170
      dl.brightness = 3
      dl.size = 400 -- canon light range 10 m
      dl.decay = 1000
      dl.dietime = CurTime() + 0.1
    end
  end

  -- Barrel spin: canon windupBarrel rotates at -3600 deg/s * windup.
  -- DrGBase calls CustomThink from its shared Think in both realms.
  function ENT:CustomThink()
    local windup = self:GetNWFloat( "UKG_Windup", 0 )
    if windup > 0 then
      local bone = self:LookupBone( "Barrels" )
      if bone then
        self.UKGutterman_BarrelSpin = ( ( self.UKGutterman_BarrelSpin or 0 )
          + 3600 * windup * FrameTime() ) % 360
        -- Barrels bone: barrel axis is its local Y (pitch component).
        self:ManipulateBoneAngles( bone, Angle( self.UKGutterman_BarrelSpin, 0, 0 ) )
      end
    elseif self.UKGutterman_BarrelSpin and self.UKGutterman_BarrelSpin ~= 0 then
      local bone = self:LookupBone( "Barrels" )
      if bone then self:ManipulateBoneAngles( bone, angle_zero ) end
      self.UKGutterman_BarrelSpin = 0
    end
  end
end

DrGBase.AddNextbot( ENT )
