AddCSLuaFile()

-- Minotaur acid-meat projectile (canon MeatLow throw): lobbed glob that
-- splashes into a GoopLarge puddle where it lands. Direct hits sting once.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minotaur Meat"
ENT.Spawnable = false

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/misc/sphere025x025.mdl" )
    self:SetModelScale( 1.6, 0 )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    -- unlit canon-green glob (lit hunter plastic goes black in shade)
    self:SetMaterial( "models/ultrakill_prelude_test/minotaur/acid_glob" )
    self:SetRenderMode( RENDERMODE_TRANSCOLOR )
    self:SetColor( Color( 110, 230, 70, 235 ) )
    self:DrawShadow( false )

    self.UKMM_Vel = self.UKMM_Vel or Vector( 0, 0, -200 )
    self.UKMM_SpawnedAt = CurTime()
  end

  -- ballistic throw from current pos to target in flightTime seconds
  function ENT:UKMM_Setup( attacker, target, flightTime, acidOpts )
    self.UKMM_Attacker = attacker
    self.UKMM_AcidOpts = acidOpts
    flightTime = flightTime or 0.5
    local g = 900
    local delta = target - self:GetPos()
    self.UKMM_Vel = Vector( delta.x / flightTime, delta.y / flightTime,
      delta.z / flightTime + 0.5 * g * flightTime )
    self.UKMM_Gravity = g
  end

  function ENT:Think()
    local now = CurTime()
    local dt = 0.05
    if now - ( self.UKMM_SpawnedAt or now ) > 5 then
      self:UKMM_Splash( self:GetPos() )
      return
    end

    local pos = self:GetPos()
    local vel = self.UKMM_Vel
    vel.z = vel.z - ( self.UKMM_Gravity or 900 ) * dt
    local npos = pos + vel * dt

    local attacker = self.UKMM_Attacker
    local tr = util.TraceLine( {
      start = pos, endpos = npos,
      -- must fly out through the thrower's own body-collider boxes
      filter = function( ent )
        if ent == self or ent == attacker then return false end
        if ent.UKMinotaur_IsMinotaur then return false end
        return true
      end,
      mask = MASK_SOLID,
    } )
    if tr.Hit then
      self:UKMM_Splash( tr.HitPos + tr.HitNormal * 4 )
      return
    end

    self:SetPos( npos )
    self:NextThink( now + dt )
    return true
  end

  function ENT:UKMM_Splash( pos )
    if not self.UKMM_Splashed then
      self.UKMM_Splashed = true
      -- drop the pool onto the ground under the impact point
      local down = util.TraceLine( {
        start = pos, endpos = pos - Vector( 0, 0, 512 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      local ground = down.Hit and down.HitPos or pos
      local acid = ents.Create( UKMinotaur.CLASS.Acid )
      if IsValid( acid ) then
        acid:SetPos( ground )
        acid:Spawn()
        acid:UKMA_Setup( self.UKMM_AcidOpts or {
          mode = "puddle", attacker = self.UKMM_Attacker,
        } )
      end
      sound.Play( UKMinotaur.SOUND.MeatSquish, ground, 80, 90, 0.9 )
    end
    self:Remove()
  end

end

if CLIENT then

  function ENT:Think()
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = self:GetPos()
      dl.r, dl.g, dl.b = 110, 230, 70
      dl.brightness = 2
      dl.decay = 1000
      dl.size = 180
      dl.dietime = CurTime() + 0.15
    end
  end

end
