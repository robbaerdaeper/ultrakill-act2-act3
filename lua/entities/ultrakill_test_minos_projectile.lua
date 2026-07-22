AddCSLuaFile()

-- Minos parasite spread projectile (canon 'Projectile Spread' child): straight
-- flight, speed = max(65, dist) m/s, 25 dmg to players / 2.5 (x1000) to NPCs.
-- Trace-moved (no physics), 5 s lifetime.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minos Projectile"
ENT.Spawnable = false

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/misc/sphere025x025.mdl" )
    self:SetModelScale( 0.6 )
    self:SetMoveType( MOVETYPE_NOCLIP )
    self:SetSolid( SOLID_NONE )
    self:SetNoDraw( true )
    self:DrawShadow( false )
    self.UKProj_Speed = self.UKProj_Speed or 65 * 40
    self.UKProj_Damage = self.UKProj_Damage or 25
    self.UKProj_Die = CurTime() + 5
  end

  function ENT:Think()
    local now = CurTime()
    if now >= self.UKProj_Die then
      self:Remove()
      return
    end
    local dt = math.min( now - ( self.UKProj_LastThink or ( now - FrameTime() ) ), 0.1 )
    self.UKProj_LastThink = now

    local from = self:GetPos()
    local to = from + self:GetForward() * self.UKProj_Speed * dt
    local owner = self:GetOwner()

    local tr = util.TraceLine( {
      start = from, endpos = to,
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self or ent == owner then return false end
        if ent.UKMinos_IsMinos or ent:GetClass() == self:GetClass() then return false end
        return true
      end,
    } )

    if tr.Hit then
      local ent = tr.Entity
      if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        local amount
        if ent:IsPlayer() then
          amount = UKMinos.ScaleAttackDamage( ent, self.UKProj_Damage )
        else
          -- round-3 sweep: canon x100 LANDED, pre-divided (was x20 over)
          amount = ent.IsUltrakillNextbot
            and UKNpcDmg.PreMult( ent, owner, self.UKProj_Damage * 100 )
            or self.UKProj_Damage
        end
        local dmg = DamageInfo()
        dmg:SetDamage( amount )
        dmg:SetDamageType( DMG_ENERGYBEAM )
        dmg:SetAttacker( IsValid( owner ) and owner or self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( tr.HitPos )
        dmg:SetDamageForce( self:GetForward() * 800 )
        ent:TakeDamageInfo( dmg )
      end
      local fx = EffectData()
      fx:SetOrigin( tr.HitPos )
      fx:SetNormal( tr.HitNormal )
      util.Effect( "AntlionGib", fx, true, true )
      self:Remove()
      return
    end

    self:SetPos( to )
    self:NextThink( now )
    return true
  end

end

if CLIENT then

  local matGlow = CreateMaterial( "UKMinos_ProjGlow_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "sprites/light_glow02_add_noz",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )

  function ENT:Draw()
    local pos = self:GetPos()
    render.SetMaterial( matGlow )
    render.DrawQuadEasy( pos, EyePos() - pos, 60, 60, Color( 255, 120, 60, 255 ), 0 )
    render.DrawQuadEasy( pos, EyePos() - pos, 26, 26, Color( 255, 230, 180, 255 ), 0 )

    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = pos
      dl.r, dl.g, dl.b = 255, 140, 60
      dl.brightness = 1.5
      dl.size = 150
      dl.decay = 0
      dl.dietime = CurTime() + 0.1
    end
  end

end
