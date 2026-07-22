AddCSLuaFile()
include( "autorun/ultrakill_test_gutterman_shared.lua" )

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Gutterman (Pod Drop)"
ENT.Author = "ultragmod"
ENT.Category = "ULTRAKILL - Secrets"
ENT.Spawnable = true
ENT.AdminOnly = false

-- Canon 7-2 AutoDropper: a bombshell pod whistles down from the sky, slams
-- into the ground with an explosion, the door blows off and a Gutterman
-- steps out. The empty pod stays in the world.

local POD_MODEL = "models/ultrakill_prelude_test/gutterman_pod.mdl"
local DROP_HEIGHT = 2300
local FALL_SPEED = 2800
local CRUSH_RADIUS = 140
local DOOR_DELAY = 0.9
local SPAWN_DELAY = 1.05

if SERVER then
  function ENT:SpawnFunction( ply, tr, className )
    if not tr.Hit then return end

    local ent = ents.Create( className )
    if not IsValid( ent ) then return end

    -- door side (+forward) faces the player who called the drop
    local yaw = IsValid( ply ) and ( ply:GetPos() - tr.HitPos ):Angle().y or math.Rand( 0, 360 )
    ent.UKGutterman_LandPos = tr.HitPos
    ent:SetPos( tr.HitPos + Vector( 0, 0, DROP_HEIGHT ) )
    ent:SetAngles( Angle( 0, yaw, 0 ) )
    ent:Spawn()
    ent:Activate()
    return ent
  end

  function ENT:Initialize()
    self:SetModel( POD_MODEL )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:DrawShadow( true )

    self.UKGutterman_PodSpawnClass = self.UKGutterman_PodSpawnClass or UKGutterman.CLASS.Regular
    self.UKGutterman_Falling = false
    self.UKGutterman_Landed = false

    -- Defer the drop setup one tick: NPC-menu spawns reposition the entity
    -- after Spawn(), and SpawnFunction-based spawns already set the land pos.
    timer.Simple( 0, function()
      if IsValid( self ) then self:UKGutterman_BeginDrop() end
    end )
  end

  function ENT:UKGutterman_BeginDrop()
    if self.UKGutterman_Falling or self.UKGutterman_Landed then return end

    if not self.UKGutterman_LandPos then
      -- spawned via NPC menu / ents.Create: current pos marks the landing spot
      local base = self:GetPos()
      local down = util.TraceLine( {
        start = base + Vector( 0, 0, 16 ),
        endpos = base - Vector( 0, 0, 16384 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      local ground = down.Hit and down.HitPos or base
      self.UKGutterman_LandPos = ground

      -- drop from as high as the ceiling allows
      local up = util.TraceLine( {
        start = ground + Vector( 0, 0, 32 ),
        endpos = ground + Vector( 0, 0, DROP_HEIGHT + 32 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      local height = up.Hit and math.max( up.HitPos.z - ground.z - 540, 300 ) or DROP_HEIGHT
      self:SetPos( ground + Vector( 0, 0, height ) )
    end

    self.UKGutterman_Falling = true
    -- canon BombFalling whistle while dropping
    self:EmitSound( UKGutterman.SOUND.PodFalling, 130, 100, 1 )
    self:NextThink( CurTime() )
  end

  function ENT:Think()
    if self.UKGutterman_Falling then
      self:UKGutterman_FallStep()
      self:NextThink( CurTime() )
      return true
    end

    if self.UKGutterman_Landed and not self.UKGutterman_Opened then
      local t = CurTime() - self.UKGutterman_LandTime
      if not self.UKGutterman_DoorPopped and t >= DOOR_DELAY then
        self:UKGutterman_PopDoor()
      end
      if t >= SPAWN_DELAY then
        self:UKGutterman_ReleaseGutterman()
      end
      self:NextThink( CurTime() + 0.05 )
      return true
    end
  end

  function ENT:UKGutterman_FallStep()
    local step = FALL_SPEED * FrameTime()
    local pos = self:GetPos()
    local target = self.UKGutterman_LandPos

    local tr = util.TraceLine( {
      start = pos,
      endpos = pos - Vector( 0, 0, step + 8 ),
      mask = MASK_SOLID_BRUSHONLY,
      filter = self,
    } )

    local landZ = target and target.z or -16384
    if tr.Hit and tr.HitPos.z >= landZ - 4 then
      self:UKGutterman_Land( tr.HitPos )
    elseif target and pos.z - step <= landZ then
      self:UKGutterman_Land( Vector( pos.x, pos.y, landZ ) )
    else
      self:SetPos( pos - Vector( 0, 0, step ) )
    end
  end

  function ENT:UKGutterman_Land( pos )
    self.UKGutterman_Falling = false
    self.UKGutterman_Landed = true
    self.UKGutterman_LandTime = CurTime()

    self:StopSound( UKGutterman.SOUND.PodFalling )
    self:SetPos( pos )

    -- the bombshell top detonates on impact — that's the landing explosion
    local bg = self:FindBodygroupByName( "bomb" )
    if bg and bg >= 0 then self:SetBodygroup( bg, 1 ) end

    self:SetSolid( SOLID_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_NONE )
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then phys:EnableMotion( false ) end

    local fx = EffectData()
    fx:SetOrigin( pos )
    fx:SetRadius( 220 )
    util.Effect( "Ultrakill_Explosion", fx, true, true )
    if UltrakillBase and UltrakillBase.SoundScript then
      UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    end

    local dust = EffectData()
    dust:SetOrigin( pos )
    dust:SetScale( 180 )
    dust:SetNormal( Vector( 0, 0, 1 ) )
    util.Effect( "ThumperDust", dust, true, true )
    util.ScreenShake( pos, 10, 60, 0.8, 800 )

    -- canon: the impact crushes whatever it lands on
    for _, ent in ipairs( ents.FindInSphere( pos, CRUSH_RADIUS ) ) do
      if not IsValid( ent ) or ent == self then continue end
      if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end

      local dmg = DamageInfo()
      dmg:SetDamage( 1000000 )
      dmg:SetDamageType( DMG_CRUSH )
      dmg:SetAttacker( self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( ent:WorldSpaceCenter() )
      ent:TakeDamageInfo( dmg )
    end
  end

  function ENT:UKGutterman_PopDoor()
    self.UKGutterman_DoorPopped = true

    local bg = self:FindBodygroupByName( "door" )
    if bg and bg >= 0 then self:SetBodygroup( bg, 1 ) end

    local door = ents.Create( "prop_physics" )
    if IsValid( door ) then
      door:SetModel( POD_MODEL )
      door:SetPos( self:GetPos() + Vector( 0, 0, 4 ) )
      door:SetAngles( self:GetAngles() )
      door:Spawn()

      local bgBody = door:FindBodygroupByName( "body" )
      if bgBody and bgBody >= 0 then door:SetBodygroup( bgBody, 1 ) end
      local bgBomb = door:FindBodygroupByName( "bomb" )
      if bgBomb and bgBomb >= 0 then door:SetBodygroup( bgBomb, 1 ) end

      -- door mesh occupies the +X (forward) curved side: x 0..90, y +-90, z 45..285
      door:PhysicsInitBox( Vector( 0, -90, 20 ), Vector( 90, 90, 285 ) )
      local phys = door:GetPhysicsObject()
      if IsValid( phys ) then
        phys:SetMass( 150 )
        phys:Wake()
        -- blast the door out of the doorway (+forward side)
        phys:SetVelocity( self:GetForward() * 750 + Vector( 0, 0, 220 ) )
        phys:AddAngleVelocity( Vector( math.Rand( -200, 200 ), math.Rand( 100, 400 ), 0 ) )
      end

      door:EmitSound( "physics/metal/metal_box_break2.wav", 85, 90 )
      SafeRemoveEntityDelayed( door, 30 )
    end
  end

  function ENT:UKGutterman_ReleaseGutterman()
    self.UKGutterman_Opened = true

    local cls = self.UKGutterman_PodSpawnClass
    local gm = ents.Create( cls )
    if IsValid( gm ) then
      gm:SetPos( self:GetPos() + self:GetForward() * 150 )
      gm:SetAngles( Angle( 0, self:GetAngles().y, 0 ) )
      gm:Spawn()
      gm:Activate()
    end
  end
end

if CLIENT then
  function ENT:Draw()
    self:DrawModel()
  end
end

-- Shared NPC-list registration so the ULTRAKILL Q-menu tab picks the pod up.
list.Set( "NPC", "ultrakill_test_gutterman_pod", {
  Name = "Gutterman (Pod Drop)",
  Class = "ultrakill_test_gutterman_pod",
  Category = "ULTRAKILL - Secrets",
} )
