-- lua/entities/ultrakill_test_providence_proj.lua
-- Magenta Cross Projectile (canon 'Projectile Providence', Layer 8).
-- Straight-flying magenta hell orb (speed 65 m/s, damage 25, lifetime 5 s)
-- with 4 perpendicular cross beams (damage 20, until geometry, players only).
-- Orb is parryable/reflectable via the ultrakillbase projectile framework.

local UltrakillBase = UltrakillBase

if not DrGBase or not UltrakillBase then return end
if not UKProvidence then include( "autorun/ultrakill_test_providence_shared.lua" ) end

ENT.Base = "ultrakillbase_projectile"

ENT.PrintName = "Providence Magenta Cross"
ENT.Category = UKProvidence.CATEGORY
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 0.8
ENT.Spawnable = false

-- straight flight, no homing (canon turnSpeed 0)
ENT.UltrakillBase_HomingType = -1

ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 10, 10, 10 )

local SND = UKProvidence.SOUND
local MAGENTA = UKProvidence.MAGENTA

-- 4 cross directions perpendicular to the flight direction
local function CrossDirs( dir )
  local right = dir:Cross( Vector( 0, 0, 1 ) )
  if right:LengthSqr() < 0.01 then right = dir:Cross( Vector( 0, 1, 0 ) ) end
  right:Normalize()
  local up = right:Cross( dir )
  up:Normalize()
  return { up, -up, right, -right }
end

if SERVER then

  function ENT:CustomInitialize()
    -- canon: opaque magenta skull texture ('skull2 compressed 6'), no tint
    self:SetMaterial( "models/ultrakill_prelude_test/providence/providence_orb" )

    -- canon TrailRenderer: white alpha-blended streak behind the orb
    util.SpriteTrail( self, 0, Color( 255, 255, 255, 160 ), false,
      18, 0, 0.3, 1 / 18 * 0.5, "trails/laser.vmt" )

    self.UKOrb_HitCD = {}
    self.UKOrb_NextBeamTick = 0

    -- canon orb audio: AnimeSlash on the root (vol 0.5) + the charge clip;
    -- the electricity loop only hums quietly at the beam ENDS in canon, so no
    -- loud loop on the orb itself (it read as a generic drone projectile)
    self:EmitSound( SND.ProjFly, 75, 100, 0.5 )

    SafeRemoveEntityDelayed( self, UKProvidence.ORB_LIFETIME )
  end

  function ENT:OnTakeDamage( CDamageInfo )
    self:CheckReflect( CDamageInfo )
    self:CheckParry( CDamageInfo )
  end

  function ENT:CustomThink()
    -- parried: the cross beams STAY on the returned orb (canon) but turn
    -- friendly — no player damage (the base OnParry re-owned us to the
    -- parrying player, so kill credit is his)
    local parried = self:GetParried()

    if CurTime() < self.UKOrb_NextBeamTick then return end
    self.UKOrb_NextBeamTick = CurTime() + ( parried and 0 or 0.1 )

    local vel = self:GetVelocity()
    if vel:LengthSqr() < 1 then return end
    local dir = vel:GetNormalized()
    local owner = self:GetOwner()

    -- continuous sweep (canon ContinuousBeam behaviour): damage-check the
    -- cross at interpolated positions along the path travelled since the
    -- last tick — discrete ticks strode right past targets (a parried orb
    -- covers ~333 su between DrGBase projectile thinks)
    local pos = self:GetPos()
    local last = self.UKOrb_LastBeamPos or pos
    self.UKOrb_LastBeamPos = pos
    local travel = pos - last
    local steps = math.Clamp( math.ceil( travel:Length() / 50 ), 1, 12 )
    local dirs = CrossDirs( dir )
    for s = 1, steps do
      local p = last + travel * ( s / steps )
      for _, d in ipairs( dirs ) do
        -- canon sides: hostile orb -> players only; parried orb plays for
        -- the player -> NPCs only (incl. Providences)
        UKProvidence.DamageBeamSegment( owner, self, p, d,
          UKProvidence.CROSS_BEAM_RANGE, UKProvidence.CROSS_BEAM_RADIUS,
          UKProvidence.CROSS_BEAM_DAMAGE,
          parried or UKProvidence.CROSS_BEAMS_HIT_NPC,
          self.UKOrb_HitCD, not parried )
      end
    end
  end

  function ENT:OnContact( mEntity )
    if self:GetParried() then
      -- r12: parry reward, NOT a one-shot — the ParryCollide explosion path
      -- nets a fixed x40 on UK-nextbot victims (see PARRY_EXPLOSION_NET_MULT),
      -- so feed the pre-multiplier value (lands 8000 = half the Providence
      -- HP; the old flat 25000 landed as 1000000)
      return self:ParryCollide( UKProvidence.ORB_PARRY_DAMAGE / UKProvidence.PARRY_EXPLOSION_NET_MULT )
    end

    -- r7: no explosion FX/sound on hit — the canon orb just pops
    self:StopSound( SND.BeamLoop )

    if IsValid( mEntity ) and ( mEntity:IsPlayer() or mEntity:IsNPC() or mEntity:IsNextBot() )
       and mEntity:GetClass() ~= UKProvidence.CLASS.Regular then
      local owner = self:GetOwner()
      local attacker = IsValid( owner ) and owner or self
      local dmg = DamageInfo()
      dmg:SetDamage( UKProvidence.PreMultDamage( mEntity, attacker,
        UKProvidence.ScaleAttackDamage( mEntity, UKProvidence.ORB_DAMAGE ) ) )
      dmg:SetDamageType( DMG_ENERGYBEAM )
      dmg:SetAttacker( attacker )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( self:GetPos() )
      dmg:SetDamageForce( vector_origin )
      mEntity:TakeDamageInfo( dmg )
    end
  end

  function ENT:OnRemove()
    self:StopSound( SND.BeamLoop )
  end

else -- CLIENT

  -- canon renderers: striped MindflayerBeam3 lines, RageEffectWhite end rings,
  -- 'charge magenta' quad on the orb (visual dump: Projectile Providence)
  local MAT_BEAM = Material( "effects/ukprovidence_beam" )
  local MAT_RING = Material( "effects/ukprovidence_ring" )
  local MAT_CHARGE = Material( "effects/ukprovidence_charge" )
  local COL_WHITE = Color( 255, 255, 255, 255 )
  local COL_RING = Color( 255, 140, 200, 255 )
  local BEAM_WIDTH = 25       -- canon LineRenderer widthMultiplier 1.0 unit
  local RING_SIZE = 55        -- canon Ring scale 2.0-2.5 units
  local CHARGE_SIZE = 50      -- canon ChargeEffect quad scale (2,2,1) units
  local RB = Vector( 4200, 4200, 4200 )

  function ENT:CustomInitialize()
    self:SetRenderBounds( -RB, RB )
    self.UKOrb_DLight = DynamicLight( self:EntIndex() )
  end

  function ENT:CustomThink()
    self:AngleFollowVelocity()
    local dl = self.UKOrb_DLight
    if dl then
      dl.pos = self:GetPos()
      dl.r, dl.g, dl.b = MAGENTA.r, MAGENTA.g, MAGENTA.b
      dl.brightness = 3
      dl.size = 250
      dl.decay = 1000
      dl.dietime = CurTime() + 0.2
    end
  end

  function ENT:CustomDraw()
    local pos = self:GetPos()

    -- cross beams: persist through a parry (canon — the returned orb keeps
    -- its plus shape, the beams just turn friendly server-side)
    local vel = self:GetVelocity()
    if vel:LengthSqr() > 1 then
      local dir = vel:GetNormalized()
      local beams = {}
      for _, d in ipairs( CrossDirs( dir ) ) do
        local tr = util.TraceLine( {
          start = pos, endpos = pos + d * UKProvidence.CROSS_BEAM_RANGE,
          mask = MASK_SOLID_BRUSHONLY,
        } )
        beams[#beams + 1] = { dir = d, endpos = tr.HitPos,
          len = tr.HitPos:Distance( pos ), hit = tr.Hit }
      end
      -- canon LineRenderer textureMode=Stretch: the striped MindflayerBeam3
      -- texture is stretched ONCE over the whole beam (pinstripes running
      -- along it), never tiled — tiling gave blocky white/magenta bands
      render.SetMaterial( MAT_BEAM )
      for _, b in ipairs( beams ) do
        render.DrawBeam( pos, b.endpos, BEAM_WIDTH, 0, 1, COL_WHITE )
      end
      -- canon Ring particles travelling along each beam + a ring where a
      -- beam meets geometry
      render.SetMaterial( MAT_RING )
      for _, b in ipairs( beams ) do
        UKProvidence.DrawBeamRings( pos, b.dir, b.len, 60, 500, 130 )
        if b.hit then
          render.DrawSprite( b.endpos - b.dir * 4, RING_SIZE, RING_SIZE, COL_RING )
        end
      end
    end

    -- canon ChargeEffect: 'charge magenta' quad billboarded on the orb
    render.SetMaterial( MAT_CHARGE )
    render.DrawSprite( pos, CHARGE_SIZE, CHARGE_SIZE, COL_WHITE )
  end

end

AddCSLuaFile()
