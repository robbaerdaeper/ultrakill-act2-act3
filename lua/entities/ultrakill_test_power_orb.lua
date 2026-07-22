AddCSLuaFile()

if not UKPower then include( "autorun/ultrakill_test_power_shared.lua" ) end

-- Power zweihander Hell orb (canon 'Projectile Beamable', Violent+ only).
-- Two orbs fly in parallel, 25 dmg each; an unparryable beam joins the pair
-- (ContinuousBeam, 35 dmg). Trace-moved like the Minos projectile.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Power Hell Orb"
ENT.Spawnable = false

local UNIT = UKPower and UKPower.UNIT or 40

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/misc/sphere025x025.mdl" )
    self:SetModelScale( 0.8 )
    self:SetMoveType( MOVETYPE_NOCLIP )
    self:SetSolid( SOLID_NONE )
    self:SetNoDraw( true )
    self:DrawShadow( false )
    self.UKOrb_Speed = UKPower.ORB_SPEED * UNIT
    self.UKOrb_Die = CurTime() + 5 -- canon RemoveOnTime 5 s
    self.UKOrb_BeamHits = {}
    self:EmitSound( UKPower.SOUND.Orb, 80, 100, 0.5 )
  end

  function ENT:UKOrb_Hit( ent, damage, dmgtype )
    if not IsValid( ent ) then return end
    if ent.UKPower_IsPower then return end
    local amount
    if ent:IsPlayer() then
      amount = UKPower.ScaleAttackDamage( ent, damage )
    elseif ent.IsUltrakillNextbot then
      -- round-3 sweep (2026-07-10): x1000 without pre-division landed
      -- 500k-700k on pack NPCs (victim multiplies x20 itself) — convention
      -- is canon x100 LANDED, pre-divided via UKNpcDmg.PreMult
      amount = UKNpcDmg.PreMult( ent, self:GetOwner(), damage * 100 )
    else
      amount = damage
    end
    local dmg = DamageInfo()
    dmg:SetDamage( amount )
    dmg:SetDamageType( dmgtype )
    local owner = self:GetOwner()
    dmg:SetAttacker( IsValid( owner ) and owner or self )
    dmg:SetInflictor( self )
    dmg:SetDamagePosition( ent:WorldSpaceCenter() )
    dmg:SetDamageForce( self:GetForward() * 600 )
    ent:TakeDamageInfo( dmg )
  end

  function ENT:Think()
    local now = CurTime()
    if now >= self.UKOrb_Die then
      self:Remove()
      return
    end
    local dt = math.min( now - ( self.UKOrb_LastThink or ( now - FrameTime() ) ), 0.1 )
    self.UKOrb_LastThink = now

    local from = self:GetPos()
    local to = from + self:GetForward() * self.UKOrb_Speed * dt
    local owner = self:GetOwner()

    local tr = util.TraceLine( {
      start = from, endpos = to,
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self or ent == owner then return false end
        if ent.UKPower_IsPower or ent:GetClass() == self:GetClass() then return false end
        return true
      end,
    } )

    if tr.Hit then
      local ent = tr.Entity
      if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        self:UKOrb_Hit( ent, UKPower.ORB_DAMAGE, DMG_ENERGYBEAM )
      end
      local fx = EffectData()
      fx:SetOrigin( tr.HitPos )
      fx:SetNormal( tr.HitNormal )
      util.Effect( "ManhackSparks", fx, true, true )
      self:Remove()
      return
    end
    self:SetPos( to )

    -- canon ContinuousBeam: the unparryable link between the pair (35 dmg,
    -- once per victim per pair — canon beams don't re-tick a standing player)
    local partner = self.UKOrb_Partner
    if self.UKOrb_BeamMaster and IsValid( partner ) then
      local btr = util.TraceLine( {
        start = self:GetPos(), endpos = partner:GetPos(),
        mask = MASK_SHOT,
        filter = function( ent )
          if ent == self or ent == partner or ent == owner then return false end
          if ent.UKPower_IsPower or ent:GetClass() == self:GetClass() then return false end
          return true
        end,
      } )
      local ent = btr.Entity
      if btr.Hit and IsValid( ent ) and not self.UKOrb_BeamHits[ ent ]
          and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
        self.UKOrb_BeamHits[ ent ] = true
        self:UKOrb_Hit( ent, UKPower.BEAM_DAMAGE, DMG_SHOCK )
      end
    end

    self:NextThink( now )
    return true
  end

end

if CLIENT then

  local matGlow = CreateMaterial( "UKPower_OrbGlow_v1", "UnlitGeneric", {
    [ "$basetexture" ] = "sprites/light_glow02_add_noz",
    [ "$additive" ] = "1",
    [ "$vertexcolor" ] = "1",
    [ "$vertexalpha" ] = "1",
    [ "$nocull" ] = "1",
  } )
  local matBeam = Material( "sprites/laserbeam" )

  function ENT:Draw()
    local pos = self:GetPos()
    render.SetMaterial( matGlow )
    render.DrawQuadEasy( pos, EyePos() - pos, 55, 55, Color( 255, 200, 60, 255 ), 0 )
    render.DrawQuadEasy( pos, EyePos() - pos, 24, 24, Color( 255, 245, 200, 255 ), 0 )

    local partner = self.UKOrb_Partner
    if not IsValid( partner ) then
      -- entity refs don't replicate; find the twin by class near the owner
      for _, e in ipairs( ents.FindByClass( self:GetClass() ) ) do
        if e ~= self and e:GetOwner() == self:GetOwner()
            and e:GetPos():DistToSqr( pos ) < ( 12 * UNIT ) ^ 2 then
          partner = e
          self.UKOrb_Partner = e
          break
        end
      end
    end
    if IsValid( partner ) and self:EntIndex() < partner:EntIndex() then
      render.SetMaterial( matBeam )
      render.DrawBeam( pos, partner:GetPos(), 12, 0, 1, Color( 255, 190, 40, 235 ) )
    end

    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = pos
      dl.r, dl.g, dl.b = 255, 190, 50
      dl.brightness = 1.2
      dl.size = 160
      dl.decay = 0
      dl.dietime = CurTime() + 0.1
    end
  end

end
