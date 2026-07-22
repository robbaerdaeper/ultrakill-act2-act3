local UltrakillBase = UltrakillBase
local IsValid = IsValid
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_insurrectionist_shared.lua" )
ENT.Base = "ultrakillbase_projectile"

-- Insurrectionist flying boulder (canon Cannonball, the dead Malicious Face).
-- Spawned only for the extended-arm attack phases; kinematic — it replays the
-- exact canon coroutine trajectories (OverheadSlamAttack / HorizontalSwing /
-- Stab / AirStab from Sisyphus.cs). Parryable: a parried boulder launches
-- along the parrier's aim; hitting its owner knocks the owner down (22 dmg).

ENT.PrintName = "Insurrectionist Boulder"
ENT.Category = "UltrakillBase"
ENT.Models = { UKSisy.MODEL_BOULDER }
ENT.ModelScale = 1
ENT.Spawnable = false

ENT.OnContactDelete = -1
ENT.UltrakillBase_CustomCollisionEnabled = true
-- match the visual mace (~±130 su) so feedbacker punch traces connect on
-- the surface the player actually sees
ENT.UltrakillBase_CustomCollisionBounds = Vector( 70, 70, 70 ) -- 2026-07-10: boulder model rescaled x0.5

local UNIT = UKSisy.UNIT

-- canon SwingCheck2 trigger on the hand: r 1.5 rig units = 3.75 m
local CONTACT_RADIUS = 3.75 * UNIT

if SERVER then

  function ENT:CustomInitialize()
    self.mInitOwner = self:GetOwner()
    self.UKSB_Mode = "idle"
    self.UKSB_Hits = {}
    self.UKSB_Spin = Angle( math.Rand( -30, 30 ), math.Rand( -60, 60 ), 0 )
    self.UKSB_LastPos = self:GetPos()

    self:SetHealth( 1e9 ) -- canon: shooting the Malicious Face mace does nothing

    -- no trail: canon has none, the red GMod smoke streak read as a fake arm

    self:EmitSound( UKSisy.SOUND.SwingLoop, 95, 100, 1, CHAN_STATIC )
  end

  function ENT:OnRemove()
    self:StopSound( UKSisy.SOUND.SwingLoop )
  end

  function ENT:UKSB_Parent()
    local p = self.mInitOwner
    return IsValid( p ) and p or nil
  end

  --------------------------------------------------------------------------
  -- Launch API (called by the Insurrectionist)
  -- opts: mode, T (flight seconds), sas, target (Vector), targetEnt,
  --       dist (su, to target at launch)
  --------------------------------------------------------------------------

  function ENT:UKSB_Fly( opts )
    -- canon ArmStretcher: while the boulder swings/rests/returns the arm
    -- visually stretches after it (client bone-manip in the shared file)
    self:SetNW2Bool( "UKSB_ArmLinked", true )
    self.UKSB_Mode = opts.mode
    self.UKSB_T = math.max( opts.T or 0.5, 0.05 )
    self.UKSB_Sas = opts.sas or 0.2
    self.UKSB_Start = self:GetPos()
    self.UKSB_Target = opts.target
    self.UKSB_TargetEnt = opts.targetEnt
    self.UKSB_Dist = opts.dist or 400
    self.UKSB_T0 = CurTime()
    self.UKSB_Hits = {}
    self.UKSB_Damaging = true
    self.UKSB_Impacted = false
    self.UKSB_RestUntil = nil
    self.UKSB_DescendUntil = nil
  end

  function ENT:UKSB_Retract( time )
    if self.UKSB_Mode == "return" or self.UKSB_Mode == "parried" then return end
    self.UKSB_Mode = "return"
    self.UKSB_T = math.max( time or 1, 0.15 )
    self.UKSB_T0 = CurTime()
    self.UKSB_Start = self:GetPos()
    self.UKSB_Damaging = false
    self:StopSound( UKSisy.SOUND.SwingLoop )
  end

  --------------------------------------------------------------------------
  -- Helpers
  --------------------------------------------------------------------------

  local function EnvSweep( from, to, radius )
    local tr = util.TraceHull( {
      start = from, endpos = to,
      mins = Vector( -radius, -radius, -radius ),
      maxs = Vector( radius, radius, radius ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    return tr.Hit and tr.HitPos or nil
  end

  function ENT:UKSB_LiveTargetPos()
    local te = self.UKSB_TargetEnt
    if IsValid( te ) then return te:WorldSpaceCenter() end
    return self.UKSB_Target
  end

  -- canon boulder-impact explosion scales x0.66 below VIOLENT
  function ENT:UKSB_Explode( pos )
    local parent = self:UKSB_Parent()
    local diff = UKSisy.GetDifficulty( parent )
    local mult = ( diff <= 2 ) and 0.66 or 1.0
    UKSisy.Explode( parent or self, pos, mult )
  end

  -- direct SwingCheck2 contact: 30 dmg, kb 500, once per flight per victim
  function ENT:UKSB_ContactDamage()
    if not self.UKSB_Damaging then return end
    local parent = self:UKSB_Parent()
    for _, ent in ipairs( ents.FindInSphere( self:GetPos(), CONTACT_RADIUS ) ) do
      if not IsValid( ent ) or ent == self or ent == parent then continue end
      if self.UKSB_Hits[ ent ] then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
      if ent.UKSisy_IsSisy then continue end

      self.UKSB_Hits[ ent ] = true
      local atk = IsValid( parent ) and parent or self
      local amount
      if not ent:IsPlayer() and ent.IsUltrakillNextbot then
        -- landed NPC target, pre-divided by the victim's base multiplier
        -- (the old raw 30*1000 double-dipped into the base's x20 and
        -- landed ~600k = one-shot for anything in the pack)
        amount = UKSisy.PreMultDamage( ent, atk, UKSisy.SWING_DAMAGE_NPC )
      else
        amount = UKSisy.ScaleAttackDamage( ent, UKSisy.SWING_DAMAGE )
      end
      local dmg = DamageInfo()
      dmg:SetDamage( amount )
      dmg:SetDamageType( DMG_CLUB )
      dmg:SetAttacker( atk )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      local dir = ( self:GetPos() - self.UKSB_LastPos )
      if dir:IsZero() then dir = ent:WorldSpaceCenter() - self:GetPos() end
      dir:Normalize()
      dmg:SetDamageForce( dir * 8000 )
      ent:TakeDamageInfo( dmg )
      -- canon knockBackForce 500
      if ent:IsPlayer() then
        ent:SetVelocity( dir * 700 + Vector( 0, 0, 200 ) )
      end
    end
  end

  function ENT:UKSB_Impact( pos, explode )
    self.UKSB_Impacted = true
    self.UKSB_Damaging = false
    self:StopSound( UKSisy.SOUND.SwingLoop )
    if explode then self:UKSB_Explode( pos ) end
    local parent = self:UKSB_Parent()
    if IsValid( parent ) and parent.UKS_BoulderImpact then
      parent:UKS_BoulderImpact( pos )
    end
  end

  --------------------------------------------------------------------------
  -- Trajectories (canon coroutines)
  --------------------------------------------------------------------------

  function ENT:CustomThink()
    -- Ultrakill Arms parry fix (owner swap breaks base relations)
    local owner = self:GetOwner()
    if owner ~= self.mInitOwner and IsValid( self.mInitOwner ) then
      self:SetOwner( self.mInitOwner )
    end

    local parent = self:UKSB_Parent()
    local mode = self.UKSB_Mode
    local now = CurTime()
    local pos = self:GetPos()
    self:SetAngles( self:GetAngles() + self.UKSB_Spin * FrameTime() )

    if mode == "idle" then return end

    if mode == "parried" then
      local newPos = pos + self.UKSB_ParryDir * UKSisy.CANNONBALL_SPEED * FrameTime()
      -- owner hit -> canon Knockdown + 22 dmg
      if IsValid( parent )
          and newPos:Distance( parent:WorldSpaceCenter() ) < 170 then
        local ply = self.UKSB_Parrier
        local atk = IsValid( ply ) and ply or self
        local dmg = DamageInfo()
        -- canon 22 => 22000 pack-scale landed (pre-divided: the attacker is
        -- the parrying player, so the base would multiply by plydmgmult*10)
        dmg:SetDamage( UKSisy.PreMultDamage( parent, atk,
          UKSisy.CANNONBALL_OWNER_DAMAGE ) )
        dmg:SetDamageType( DMG_CLUB + DMG_DIRECT )
        dmg:SetAttacker( atk )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( parent:WorldSpaceCenter() )
        parent:TakeDamageInfo( dmg )
        if parent.UKS_Knockdown then parent:UKS_Knockdown( newPos ) end
        self:UKSB_Break( newPos )
        return
      end
      -- other victims: canon Cannonball.Collide DeliverDamage(22)
      for _, ent in ipairs( ents.FindInSphere( newPos, 130 ) ) do
        if IsValid( ent ) and ent ~= parent and not self.UKSB_Hits[ ent ]
            and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
          self.UKSB_Hits[ ent ] = true
          local ply = self.UKSB_Parrier
          local atk = IsValid( ply ) and ply or self
          local amount
          if not ent:IsPlayer() and ent.IsUltrakillNextbot then
            -- parry reward parity (VCR seeker 10000 / GT mine 10500), landed
            amount = UKSisy.PreMultDamage( ent, atk, UKSisy.CANNONBALL_PARRY_NPC )
          else
            amount = UKSisy.ScaleAttackDamage( ent, UKSisy.CANNONBALL_DAMAGE )
          end
          local dmg = DamageInfo()
          dmg:SetDamage( amount )
          dmg:SetDamageType( DMG_CLUB )
          dmg:SetAttacker( atk )
          dmg:SetInflictor( self )
          ent:TakeDamageInfo( dmg )
        end
      end
      local hit = EnvSweep( pos, newPos, 60 )
      if hit then
        self:UKSB_Break( hit )
        return
      end
      self:SetPos( newPos )
      self.UKSB_LastPos = pos
      if now - self.UKSB_T0 > 4 then self:UKSB_Break( newPos ) end
      return
    end

    if mode == "return" then
      local frac = math.Clamp( ( now - self.UKSB_T0 ) / self.UKSB_T, 0, 1 )
      local home = self.UKSB_Start
      if IsValid( parent ) then
        local id = parent:LookupAttachment( "boulder" )
        local att = id and id > 0 and parent:GetAttachment( id )
        home = att and att.Pos or parent:WorldSpaceCenter()
      end
      self:SetPos( LerpVector( frac, self.UKSB_Start, home ) )
      if frac >= 1 then
        if IsValid( parent ) and parent.UKS_BoulderReturned then
          parent:UKS_BoulderReturned()
        end
        self:Remove()
      end
      return
    end

    if self.UKSB_Impacted then
      -- resting after a slam; the Insurrectionist decides when to retract
      return
    end

    local t = now - self.UKSB_T0
    local T = self.UKSB_T
    local newPos = pos

    if mode == "overheadslam" then
      if self.UKSB_DescendUntil then
        -- canon: keep pushing the boulder down at sas*400 m/s until env hit
        newPos = pos - Vector( 0, 0, self.UKSB_Sas * 400 * UNIT * FrameTime() )
        local hit = EnvSweep( pos, newPos, 5 * UNIT )
        if hit or now >= self.UKSB_DescendUntil then
          self:SetPos( hit or newPos )
          self:UKSB_Impact( hit or newPos, hit ~= nil )
          return
        end
        self:SetPos( newPos )
      else
        -- canon arc: lerp to the live slam point + sin bump
        local target = self.UKSB_Target
        if IsValid( parent ) then
          local live = self:UKSB_LiveTargetPos()
          local ppos = parent:GetPos()
          local flat = Vector( live.x - ppos.x, live.y - ppos.y, 0 )
          local d = flat:Length()
          flat:Normalize()
          target = ppos + flat * math.max( d - 0.5 * UNIT, 0 )
          target.z = live.z
        end
        self.UKSB_Target = target
        local frac = math.Clamp( t / T, 0, 1 )
        newPos = LerpVector( frac, self.UKSB_Start, target )
        newPos.z = newPos.z + self.UKSB_Start:Distance( target )
          * math.sin( frac * math.pi )
        self:SetPos( newPos )
        if t >= T then
          local hit = EnvSweep( newPos, newPos - Vector( 0, 0, 8 ), 5 * UNIT )
          if hit then
            self:UKSB_Impact( newPos, true )
          else
            self.UKSB_DescendUntil = now + 1.5
          end
        end
      end

    elseif mode == "horizontalswing" then
      local ppos = IsValid( parent ) and parent:GetPos() or self.UKSB_Start
      local fwd = IsValid( parent ) and parent:GetForward() or Vector( 1, 0, 0 )
      local right = IsValid( parent ) and parent:GetRight() or Vector( 0, -1, 0 )
      local live = self:UKSB_LiveTargetPos()
      local radius = math.max( Vector( live.x - ppos.x, live.y - ppos.y, 0 ):Length()
        - 3 * UNIT, 4 * UNIT )
      local phase1 = T / 3
      local phase2 = T / 1.5
      if t < phase1 then
        -- windmill out to the left at chest height
        local L = ppos + Vector( 0, 0, 5 * UNIT ) - right * radius
        newPos = LerpVector( math.Clamp( t / phase1, 0, 1 ), self.UKSB_Start, L )
      else
        -- sweep left -> front -> right, dropping to the target's height
        local frac = math.Clamp( ( t - phase1 ) / phase2, 0, 1 )
        local yaw = -90 + 180 * frac
        local dir = fwd * 1
        dir:Rotate( Angle( 0, -yaw, 0 ) )
        newPos = ppos + dir * radius
        local h0 = ppos.z + 5 * UNIT
        local h1 = live.z + 2 * UNIT
        newPos.z = Lerp( math.min( frac * 2, 1 ), h0, h1 )
        if frac >= 1 then
          self:UKSB_Retract( 1 )
          return
        end
      end
      -- canon SwingCheck: 0.75 m env overlap ends the swing with an explosion
      local hit = EnvSweep( pos, newPos, 0.75 * UNIT )
      if hit then
        self:SetPos( hit )
        self:UKSB_Impact( hit, true )
        return
      end
      self:SetPos( newPos )

    elseif mode == "stab" then
      -- canon LerpUnclamped: flies THROUGH the target point and keeps going
      local frac = t / T
      newPos = self.UKSB_Start + ( self.UKSB_Target - self.UKSB_Start ) * frac
      local travelled = self.UKSB_Start:Distance( newPos )
      if travelled >= 20 * UNIT then
        local hit = EnvSweep( pos, newPos, 2 * UNIT )
        if hit then
          self:SetPos( hit )
          self:UKSB_Impact( hit, true )
          return
        end
      end
      self:SetPos( newPos )
      if travelled > 300 * UNIT then -- runaway safety (canon retract event ends it)
        self:UKSB_Retract( 1 )
        return
      end

    elseif mode == "airstab" then
      local frac = t / T
      newPos = self.UKSB_Start + ( self.UKSB_Target - self.UKSB_Start ) * frac
      local hit = EnvSweep( pos, newPos, 3.75 * UNIT )
      if hit then
        self:SetPos( hit )
        self:UKSB_Impact( hit, true )
        return
      end
      self:SetPos( newPos )
      if frac > 3 then
        self:UKSB_Retract( 0.4 )
        return
      end
    end

    self:UKSB_ContactDamage()
    self.UKSB_LastPos = pos
  end

  --------------------------------------------------------------------------
  -- Parry (canon Cannonball: launchable during swings; GotParried on owner)
  --------------------------------------------------------------------------

  -- canon launchable window: the whole attack — swings AND the short
  -- ground rest after a slam; not while returning / idle / already parried
  local PARRY_MODES = {
    overheadslam = true, horizontalswing = true, stab = true, airstab = true,
  }

  function ENT:OnTakeDamage( dmg )
    if not PARRY_MODES[ self.UKSB_Mode ] then return end
    self:CheckParry( dmg )
    if self.UKSB_Mode == "parried" then return end
    -- base CheckParry measures 250 su to the mace CENTRE — on a ~3 m ball
    -- that gate silently eats legit surface punches (ukarms already
    -- flashed and hit-stopped, so it reads as a swallowed parry); redo
    -- the same gate from the collision surface instead
    local ply = dmg:GetAttacker()
    if IsValid( ply ) and ply:IsPlayer()
        and dmg:IsDamageType( bit.bor( DMG_CLUB, DMG_SLASH ) )
        and self:GetParryable() and not self:GetParried() then
      local eye = ply:EyePos()
      if eye:Distance( self:NearestPoint( eye ) ) <= 250 then
        self:OnParry( ply, dmg )
      end
    end
  end

  function ENT:OnParry( ply, dmg )
    if self.UKSB_Mode == "parried" then return end
    self:SetParried( true ) -- keep the base NW2 state in sync
    -- canon GotParried: the mace is knocked off the arm, the arm snaps back
    self:SetNW2Bool( "UKSB_ArmLinked", false )
    UltrakillBase.SoundScript( "Ultrakill_Parry", ply:GetPos() )
    UltrakillBase.HitStop( 0.25 )
    UltrakillBase.OnParryPlayer( ply )

    self.UKSB_Mode = "parried"
    self.UKSB_T0 = CurTime()
    self.UKSB_Hits = {}
    self.UKSB_Damaging = false
    self.UKSB_Parrier = ply
    self.UKSB_ParryDir = IsValid( ply ) and ply:GetAimVector() or self:GetForward()
    self:StopSound( UKSisy.SOUND.SwingLoop )

    local parent = self:UKSB_Parent()
    if IsValid( parent ) and parent.UKS_OnBoulderParried then
      parent:UKS_OnBoulderParried()
    end
  end

  -- canon Cannonball.Break: pop, break effect, owner SwingStop
  function ENT:UKSB_Break( pos )
    sound.Play( UKSisy.SOUND.BoulderBreak, pos, 95, 100, 1 )
    local fx = EffectData()
    fx:SetOrigin( pos )
    util.Effect( "ThumperDust", fx, true, true )
    util.ScreenShake( pos, 6, 40, 0.5, 900 )
    local parent = self:UKSB_Parent()
    if IsValid( parent ) and parent.UKS_BoulderBroken then
      parent:UKS_BoulderBroken()
    end
    self:Remove()
  end

  function ENT:OnContact( ent )
    -- movement is fully kinematic; contacts handled in CustomThink
  end

else

  function ENT:Draw()
    self:DrawModel()
  end

end

AddCSLuaFile()
