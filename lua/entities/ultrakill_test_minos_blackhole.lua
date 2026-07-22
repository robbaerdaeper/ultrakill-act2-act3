AddCSLuaFile()

-- Minos black hole (canon BlackHoleProjectile, enemy=true): fades in at the
-- spawn pos, on Activate() homes at the target (rotate 10*speed deg/s, fly
-- forward at 8 m/s x difficulty). Contact with a player = canon 99 hard
-- damage: hp>10 -> drop to 1 HP, else lethal 10. Persists until exploded
-- (phase change / owner death) — no self-collapse.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minos Black Hole"
ENT.Spawnable = false
ENT.UKMinos_IsMinos = true

local CONTACT_RADIUS = 80    -- su (canon trigger r=0.5 x2 root scale = 1 m core + margin)

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/misc/sphere075x075.mdl" )
    self:SetMoveType( MOVETYPE_NOCLIP )
    self:SetSolid( SOLID_NONE )
    self:SetNoDraw( true )    -- rendered clientside (sphere + halo)
    self:DrawShadow( false )

    self.UKBH_Activated = false
    self.UKBH_FadingIn = false
    self.UKBH_Scale = 1
    self.UKBH_Speed = 8 * 40
    self.UKBH_Yaw = self:GetAngles().yaw
    self.UKBH_Pitch = 0

    self.UKBH_Loop = CreateSound( self, UKMinos.SOUND.BlackHoleLoop )
    self.UKBH_Loop:PlayEx( 1, 100 )

    self:SetNW2Float( "UKBH_Scale", 0 )
    self:SetNW2Bool( "UKBH_Active", false )
  end

  function ENT:FadeIn()
    self.UKBH_FadingIn = true
    self.UKBH_FadeStart = CurTime()
  end

  function ENT:Activate()
    self.UKBH_Activated = true
    self.UKBH_FadingIn = false
    self:SetNW2Float( "UKBH_Scale", 1 )
    self:SetNW2Bool( "UKBH_Active", true )
  end

  local CV_IGNOREPLY = GetConVar( "ai_ignoreplayers" )

  function ENT:UKBH_Target()
    local owner = self.UKMinos_Owner
    if IsValid( owner ) and owner.GetEnemy then
      local e = owner:GetEnemy()
      if IsValid( e ) then return e end
    end
    -- fallback: closest player — MUST respect ai_ignoreplayers (the sandbox
    -- "Ignore Players" option), otherwise the hole homes in despite it
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

  function ENT:Think()
    local now = CurTime()
    local dt = math.min( now - ( self.UKBH_LastThink or now ), 0.25 )
    self.UKBH_LastThink = now

    if self.UKBH_FadingIn then
      local f = math.Clamp( ( now - ( self.UKBH_FadeStart or now ) ) / 1.5, 0, 1 )
      self:SetNW2Float( "UKBH_Scale", f )
      if f >= 1 then self.UKBH_FadingIn = false end
    end

    if self.UKBH_Activated then
      local target = self:UKBH_Target()
      if IsValid( target ) then
        -- canon: RotateTowards at 10 * speed deg/s, then fly forward
        local want = ( target:WorldSpaceCenter() - self:GetPos() ):Angle()
        local rate = 10 * ( self.UKBH_Speed / 40 ) * dt
        self.UKBH_Yaw = self.UKBH_Yaw
          + math.Clamp( math.AngleDifference( want.yaw, self.UKBH_Yaw ), -rate, rate )
        self.UKBH_Pitch = self.UKBH_Pitch
          + math.Clamp( math.AngleDifference( want.pitch, self.UKBH_Pitch ), -rate, rate )
        self:SetAngles( Angle( self.UKBH_Pitch, self.UKBH_Yaw, 0 ) )
      end
      self:SetPos( self:GetPos() + self:GetForward() * self.UKBH_Speed * dt )

      -- contact check (players only, canon BlackHoleTrigger)
      for _, ply in ipairs( player.GetAll() ) do
        if not ply:Alive() then continue end
        if ply:WorldSpaceCenter():DistToSqr( self:GetPos() ) > CONTACT_RADIUS * CONTACT_RADIUS then continue end
        -- canon: hp>10 -> down to 1 HP (hard damage), else lethal
        local dmg = DamageInfo()
        dmg:SetDamageType( DMG_DISSOLVE )
        dmg:SetAttacker( IsValid( self.UKMinos_Owner ) and self.UKMinos_Owner or self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ply:WorldSpaceCenter() )
        dmg:SetDamage( ply:Health() > 10 and ( ply:Health() - 1 ) or 10 )
        ply:TakeDamageInfo( dmg )
        self:Explode()
        return
      end
    end

    self:NextThink( now )
    return true
  end

  function ENT:Explode()
    if self.UKBH_Exploded then return end
    self.UKBH_Exploded = true
    local fx = EffectData()
    fx:SetOrigin( self:GetPos() )
    fx:SetAngles( angle_zero )
    fx:SetRadius( 500 )
    util.Effect( "ultrakill_test_softexplosion", fx, true, true )
    sound.Play( UKMinos.SOUND.PunchExplosion, self:GetPos(), 140, 70, 1 )
    self:Remove()
  end

  function ENT:OnRemove()
    if self.UKBH_Loop then self.UKBH_Loop:Stop() end
  end

end

if CLIENT then

  local matHalo = CreateMaterial( "UKMinos_BHHalo_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "sprites/light_glow02_add_noz",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )
  local matCore = CreateMaterial( "UKMinos_BHCore_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "vgui/white",
    [ "$vertexcolor" ] = "1",
    [ "$nocull" ] = "1",
  } )

  function ENT:Draw()
    local scale = self:GetNW2Float( "UKBH_Scale", 1 )
    if scale <= 0.01 then return end
    local pos = self:GetPos()

    -- pitch-black core (canon: 2 m sphere)
    render.SetMaterial( matCore )
    render.DrawSphere( pos, 45 * scale, 24, 24, Color( 2, 0, 6, 255 ) )

    -- purple aura sprite (canon: x5 sprite child)
    render.SetMaterial( matHalo )
    local jitter = VectorRand() * 4 * scale
    render.DrawQuadEasy( pos + jitter, EyePos() - pos, 420 * scale, 420 * scale,
      Color( 120, 40, 200, 200 ), 0 )
    render.DrawQuadEasy( pos - jitter, EyePos() - pos, 240 * scale, 240 * scale,
      Color( 200, 120, 255, 160 ), 0 )

    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = pos
      dl.r, dl.g, dl.b = 140, 60, 220
      dl.brightness = 2
      dl.size = math.Rand( 400, 700 ) * scale
      dl.decay = 0
      dl.dietime = CurTime() + 0.2
    end
  end

end
