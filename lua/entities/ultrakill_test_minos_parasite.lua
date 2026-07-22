AddCSLuaFile()

-- Minos parasite (phase-2 eye snake). Not a standalone enemy: mounted on the
-- corpse's head, shoots the canon projectile pair (Shoot1 = 9-shot 3° spread,
-- Shoot2 = homing), damage taken transfers to the corpse x1.5 (canon
-- weakPoint). Rotation: canon RotateTowards with angle-proportional speed.
-- Clip events: Spawn StopAction@0.992; Shoot1 Spawn@1.116 Shoot@2.602
-- StopAction@3.604; Shoot2 Spawn@0.436 Shoot@1.488 StopAction@3.293.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minos Parasite"
ENT.Spawnable = false
ENT.UKMinos_IsMinos = true

local UNIT = 40

if SERVER then

  function ENT:Initialize()
    self:SetModel( UKMinos.MODEL_PARASITE )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_BBOX )
    self:SetCollisionBounds( Vector( -300, -300, -300 ), Vector( 300, 300, 700 ) )
    self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    self:SetHealth( 1e9 )
    self:SetMaxHealth( 1e9 )

    self.UKPar_InAction = true
    self.UKPar_Cooldown = math.Rand( 0, 3 )
    self.UKPar_ActionUntil = nil
    self.UKPar_Events = nil
    self.UKPar_EvIndex = 1
    self.UKPar_ShootType = 0
    self.UKPar_Yaw = self:GetAngles().yaw
    self.UKPar_Pitch = 0

    -- burst out of the eye
    self:UKPar_PlaySeq( "Spawn", 0.992 )
    self:EmitSound( UKMinos.SOUND.ParasiteWindup, 130, 100, 0.65 )
  end

  function ENT:UKPar_PlaySeq( name, dur, events )
    local seq = self:LookupSequence( name )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end
    self.UKPar_InAction = true
    self.UKPar_ActionStart = CurTime()
    self.UKPar_ActionUntil = CurTime() + dur
    self.UKPar_Events = events or {}
    self.UKPar_EvIndex = 1
  end

  function ENT:UKPar_Idle()
    local seq = self:LookupSequence( "Idle" )
    if seq and seq >= 0 then
      self:ResetSequence( seq )
      self:ResetSequenceInfo()
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
    end
  end

  local CV_IGNOREPLY = GetConVar( "ai_ignoreplayers" )

  function ENT:UKPar_Target()
    local corpse = self.UKPar_Corpse
    if IsValid( corpse ) and corpse.GetEnemy then
      local e = corpse:GetEnemy()
      if IsValid( e ) then return e end
    end
    -- fallback: closest player — MUST respect ai_ignoreplayers (the sandbox
    -- "Ignore Players" option), otherwise the parasite shoots despite it
    if CV_IGNOREPLY and CV_IGNOREPLY:GetBool() then return nil end
    local best, bestD = nil, math.huge
    for _, ply in ipairs( player.GetAll() ) do
      if ply:Alive() then
        local d = ply:GetPos():DistToSqr( self:GetPos() )
        if d < bestD then best, bestD = ply, d end
      end
    end
    return best
  end

  function ENT:UKPar_MuzzlePos()
    local id = self:LookupAttachment( "muzzle" )
    if id and id > 0 then
      local att = self:GetAttachment( id )
      if att then return att.Pos end
    end
    return self:WorldSpaceCenter() + self:GetForward() * 200
  end

  function ENT:Think()
    local corpse = self.UKPar_Corpse
    if not IsValid( corpse ) then
      self:Remove()
      return
    end

    local now = CurTime()
    local dt = math.min( now - ( self.UKPar_LastThink or now ), 0.25 )
    self.UKPar_LastThink = now

    -- stay mounted on the head
    local headPos, headAng
    if corpse.UKMC_AttPos then
      headPos, headAng = corpse:UKMC_AttPos( "head" )
    end
    if headPos then
      self:SetPos( LocalToWorld( self.UKPar_MountLocal or vector_origin, angle_zero,
        headPos, headAng or corpse:GetAngles() ) )
    end

    -- ai_disabled: stay mounted but stop tracking/shooting (the corpse gates
    -- its own CustomThink the same way)
    if corpse.IsAIDisabled and corpse:IsAIDisabled() then
      self:NextThink( now )
      return true
    end

    -- canon rotation: RotateTowards, speed = (angle + 1) deg/s (proportional)
    local target = self:UKPar_Target()
    if IsValid( target ) then
      local want = ( target:WorldSpaceCenter() - self:WorldSpaceCenter() ):Angle()
      local dYaw = math.AngleDifference( want.yaw, self.UKPar_Yaw )
      local dPit = math.AngleDifference( want.pitch, self.UKPar_Pitch )
      local ang = math.max( math.abs( dYaw ), math.abs( dPit ) )
      local step = ( ang + 1 ) * dt
      self.UKPar_Yaw = self.UKPar_Yaw + math.Clamp( dYaw, -step, step )
      self.UKPar_Pitch = math.Clamp( self.UKPar_Pitch + math.Clamp( dPit, -step, step ), -80, 80 )
      self:SetAngles( Angle( self.UKPar_Pitch, self.UKPar_Yaw, 0 ) )
    end

    -- action events
    if self.UKPar_Events then
      local t = now - ( self.UKPar_ActionStart or 0 )
      while self.UKPar_EvIndex <= #self.UKPar_Events do
        local ev = self.UKPar_Events[ self.UKPar_EvIndex ]
        if t < ev[ 1 ] then break end
        self.UKPar_EvIndex = self.UKPar_EvIndex + 1
        self:UKPar_FireEvent( ev[ 2 ] )
      end
    end

    if self.UKPar_InAction then
      if self.UKPar_ActionUntil and now >= self.UKPar_ActionUntil then
        self.UKPar_InAction = false
        self.UKPar_ActionUntil = nil
        self.UKPar_Events = nil
        self:UKPar_Idle()
      end
    elseif IsValid( target ) then
      -- canon cooldown tick (x0.75 LENIENT, x0.5 HARMLESS)
      local d = UKMinos.GetDifficulty( corpse )
      local mult = 1
      if d == 1 then mult = 0.75 elseif d == 0 then mult = 0.5 end
      if self.UKPar_Cooldown > 0 then
        self.UKPar_Cooldown = math.max( self.UKPar_Cooldown - dt * mult, 0 )
      else
        self.UKPar_Cooldown = math.Rand( 2, 4 )
        self:EmitSound( UKMinos.SOUND.ParasiteWindup, 120, 100, 0.65 )
        if math.Rand( 0, 1 ) > 0.5 or d < 2 then
          self.UKPar_ShootType = 0
          self:UKPar_PlaySeq( "Shoot1", 3.604, {
            { 1.116, "charge" }, { 2.602, "shoot" },
          } )
        else
          self.UKPar_ShootType = 1
          self:UKPar_PlaySeq( "Shoot2", 3.293, {
            { 0.436, "charge" }, { 1.488, "shoot" },
          } )
        end
      end
    end

    self:NextThink( now )
    return true
  end

  function ENT:UKPar_FireEvent( kind )
    if kind == "charge" then
      self:EmitSound( UKMinos.SOUND.ProjCharge, 110, 100, 0.6 )
    elseif kind == "shoot" then
      self:StopSound( UKMinos.SOUND.ProjCharge )
      self:UKPar_Shoot()
    end
  end

  function ENT:UKPar_Shoot()
    local target = self:UKPar_Target()
    if not IsValid( target ) then return end
    local pos = self:UKPar_MuzzlePos()
    local corpse = self.UKPar_Corpse
    local aim = ( target:WorldSpaceCenter() - pos ):GetNormalized()

    if self.UKPar_ShootType == 1 then
      -- canon Projectile Homing (mannequin pattern: act1 mindflayer seeker)
      local proj = ents.Create( UKMinos.CLASS.Homing )
      if IsValid( proj ) then
        proj:SetPos( pos )
        proj:SetAngles( aim:Angle() )
        proj:SetOwner( IsValid( corpse ) and corpse or self )
        proj:Spawn()
        if proj.SetEnemy and IsValid( target ) then proj:SetEnemy( target ) end
      end
      return
    end

    -- canon Projectile Spread: centre + 8 in a 3° cone, speed max(65, dist) m/s
    local distM = pos:Distance( target:WorldSpaceCenter() ) / UNIT
    local speed = math.max( UKMinos.PARASITE_PROJ_SPEED, distM ) * UNIT
    local d = UKMinos.GetDifficulty( corpse )
    if d == 1 then speed = speed * 0.75 elseif d == 0 then speed = speed * 0.5 end

    local ang = aim:Angle()
    local function fire( dir )
      local proj = ents.Create( UKMinos.CLASS.Projectile )
      if not IsValid( proj ) then return end
      proj:SetPos( pos )
      proj:SetAngles( dir:Angle() )
      proj:SetOwner( IsValid( corpse ) and corpse or self )
      proj.UKProj_Speed = speed
      proj.UKProj_Damage = UKMinos.PARASITE_SPREAD_DAMAGE
      proj:Spawn()
    end

    fire( aim )
    for i = 1, UKMinos.PARASITE_SPREAD_COUNT do
      local a = Angle( ang.pitch, ang.yaw, ang.roll )
      a:RotateAroundAxis( a:Right(), math.Rand( -UKMinos.PARASITE_SPREAD_ANGLE, UKMinos.PARASITE_SPREAD_ANGLE ) )
      a:RotateAroundAxis( a:Up(), math.Rand( -UKMinos.PARASITE_SPREAD_ANGLE, UKMinos.PARASITE_SPREAD_ANGLE ) )
      fire( a:Forward() )
    end
    self:EmitSound( UKMinos.SOUND.ProjLoop, 120, 100, 0.8 )
  end

  -- canon: parasites are the weak point — damage transfers to the corpse x1.5
  function ENT:OnTakeDamage( dmg )
    local corpse = self.UKPar_Corpse
    if not IsValid( corpse ) or corpse:Health() <= 0 then return end
    local xfer = DamageInfo()
    xfer:SetDamage( dmg:GetDamage() * 1.5 )
    xfer:SetDamageType( dmg:GetDamageType() )
    xfer:SetAttacker( IsValid( dmg:GetAttacker() ) and dmg:GetAttacker() or game.GetWorld() )
    xfer:SetInflictor( IsValid( dmg:GetInflictor() ) and dmg:GetInflictor() or game.GetWorld() )
    xfer:SetDamagePosition( self:WorldSpaceCenter() )
    corpse:TakeDamageInfo( xfer )

    local fx = EffectData()
    fx:SetOrigin( dmg:GetDamagePosition() )
    fx:SetMagnitude( 2 )
    fx:SetScale( 2 )
    fx:SetFlags( 3 )
    util.Effect( "bloodspray", fx, true, true )
  end

end

if CLIENT then
  function ENT:Draw()
    self:DrawModel()
  end
end
