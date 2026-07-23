local UltrakillBase = UltrakillBase
local IsValid = IsValid
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_power_shared.lua" )
ENT.Base = "ultrakillbase_projectile"

-- Power thrown glaive spinner (canon PowerSpinnerThrown): speed 50 m/s,
-- homing turnSpeed 66 deg/s, 35 dmg (x0.25 vs enemies), ignores explosions,
-- explodes on impact. Parryable — canon parry heals and returns it.

ENT.PrintName = "Power Glaive"
ENT.Category = "UltrakillBase"
ENT.Models = { UKPower.MODEL_SPINNER }
ENT.ModelScale = 1
ENT.Spawnable = false

ENT.OnContactDelete = -1
ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 60, 60, 60 )

if SERVER then

  function ENT:CustomInitialize()
    self.mInitOwner = self:GetOwner()
    self:EmitSound( UKPower.SOUND.SwingLoop, 80, 100, 0.8 )
    SafeRemoveEntityDelayed( self, 10 )

    -- coin recipe so the feedbacker's MASK_SHOT_HULL trace can parry it
    -- (the projectile base leaves entities not-solid = untraceable)
    timer.Simple( 0, function()
      if not IsValid( self ) then return end
      self:SetNotSolid( false )
      self:SetSolid( SOLID_BBOX )
      self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
      self:SetCollisionBounds( Vector( -35, -35, -35 ), Vector( 35, 35, 35 ) )
    end )
  end

  -- canon homing: rotate the velocity toward the target at turnSpeed deg/s
  function ENT:CustomThink()
    local owner = self:GetOwner()
    if owner ~= self.mInitOwner and IsValid( self.mInitOwner ) then
      self:SetOwner( self.mInitOwner )
      owner = self.mInitOwner
    end
    if self:GetParried() then return end

    local target = IsValid( owner ) and owner.GetEnemy and owner:GetEnemy() or nil
    if not IsValid( target ) then return end

    local vel = self:GetVelocity()
    local speed = vel:Length()
    if speed < 1 then return end

    local want = ( UltrakillBase.GetEntityEyePos and
      UltrakillBase.GetEntityEyePos( target ) or target:WorldSpaceCenter() )
      - self:GetPos()
    local cur = vel:Angle()
    local goal = want:Angle()
    local step = UKPower.SPINNER_TURNRATE * self:GetUpdateInterval()
    cur.p = math.ApproachAngle( cur.p, goal.p, step )
    cur.y = math.ApproachAngle( cur.y, goal.y, step )
    self:SetVelocity( cur:Forward() * speed )
    self:SetAngles( cur )
  end

  function ENT:UKP_Explode( pos )
    sound.Play( UKPower.SOUND.ProjExplosion, pos, 90, 100, 1 )
    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetRadius( 2 * UKPower.UNIT )
    util.Effect( "Explosion", fx, true, true )
  end

  function ENT:OnTakeDamage( dmg )
    self:CheckParry( dmg )
  end

  -- canon: parrying the out-of-turn glaive is a free heal + return-to-sender
  function ENT:OnParry( ply, dmg )
    local owner = IsValid( self.mInitOwner ) and self.mInitOwner or self:GetOwner()
    dmg:SetDamage( UKPower.SPINNER_THROWN_DAMAGE * 1000 )
    dmg:SetDamageType( dmg:GetDamageType() + DMG_DIRECT )
    UltrakillBase.SoundScript( "Ultrakill_Parry", ply:GetPos() )
    UltrakillBase.HitStop( 0.25 )
    UltrakillBase.OnParryPlayer( ply )
    if IsValid( owner ) then owner:TakeDamageInfo( dmg ) end
    self:UKP_Explode( self:GetPos() )
    SafeRemoveEntityDelayed( self, engine.TickInterval() )
  end

  function ENT:OnContact( ent )
    if self:GetParried() then return self:ParryCollide( 300 ) end

  UltrakillBase.SoundScript( "Ultrakill_Explosion_1", self:GetPos() )

  self:ScreenShake( 2500, 10, 1.5, 6500 )
  self:Explosion( self:GetPos(), 200, vForce, 130, 0.25 )
  self:CreateExplosion( self:GetPos(), self:GetAngles(), 1.25 )
  SafeRemoveEntityDelayed( self, engine.TickInterval() )
  end

else

  -- rolling saw: r2 model bakes the canon PowerSpinnerThrown disk in the
  -- engine XY plane (frisbee, canon 10-degree tilt) — spin around Up
  function ENT:GetRenderAngles()
    local ang = self:GetAngles()
    ang:RotateAroundAxis( ang:Up(), CurTime() * 720 % 360 )
    return ang
  end

  function ENT:Draw()
    self:DrawModel()
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = self:GetPos()
      dl.r, dl.g, dl.b = 255, 180, 60
      dl.brightness = 1.5
      dl.size = 200
      dl.decay = 0
      dl.dietime = CurTime() + 0.1
    end
  end

end

AddCSLuaFile()
