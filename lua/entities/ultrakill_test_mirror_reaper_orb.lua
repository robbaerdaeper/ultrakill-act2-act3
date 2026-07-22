local UltrakillBase = UltrakillBase
local SafeRemoveEntityDelayed = SafeRemoveEntityDelayed
local CurTime = CurTime
local ParticleEffect = ParticleEffect
local Vector = Vector
local Material = Material
local Color = Color
local RSetMaterial = CLIENT and render.SetMaterial
local RDrawSprite = CLIENT and render.DrawSprite
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_mirror_reaper_shared.lua" )
ENT.Base = "ultrakillbase_projectile"

-- Mirror Reaper Acid Missile: dark red homing orb; direct 30, bursts into a
-- poison cloud (15/tick). Canon: homing lost after 2 s; cannot be parried but
-- detonated by shots (Breakable via projectile base collision damage).

ENT.PrintName = "Mirror Reaper Acid Missile"
ENT.Category = "UltrakillBase Test"
ENT.Models = { "models/ultrakill/mesh/effects/sphere/Sphere_16.mdl" }
ENT.ModelScale = 0.5
ENT.Spawnable = false

ENT.UltrakillBase_HomingType = 0
ENT.UltrakillBase_HomingSpeed = 8
ENT.UltrakillBase_HomingTurningMultiplier = 1.2

ENT.UltrakillBase_CustomCollisionEnabled = true

local UNIT = UKMirrorReaper and UKMirrorReaper.UNIT or 40

if SERVER then

  function ENT:CustomInitialize()
    self:ParticleEffectSlot( "Projectile_Trail", "Ultrakill_HomingOrb", { parent = self } )
    self.UKMR_SpawnedAt = CurTime()
    self.UKMR_HomingLost = false
    SafeRemoveEntityDelayed( self, 8 )
  end

  function ENT:CustomThink()
    -- canon: homing lost after 2 s of flight
    if not self.UKMR_HomingLost
        and CurTime() - ( self.UKMR_SpawnedAt or 0 ) > UKMirrorReaper.ORB_HOMING_TIME then
      self.UKMR_HomingLost = true
      self.UltrakillBase_HomingTurningMultiplier = 0
      self.UltrakillBase_HomingSpeed = 0
    end
  end

  function ENT:OnTakeDamage( CDamageInfo )
    -- canon: cannot be parried, but shots detonate it
    self:UKMR_Burst( nil )
  end

  function ENT:OnContact( mEntity )
    self:UKMR_Burst( mEntity )
  end

  function ENT:UKMR_Burst( directHit )
    if self.UKMR_Bursted then return end
    self.UKMR_Bursted = true
    local pos = self:GetPos()
    local owner = self.UKMR_Owner

    UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
    ParticleEffect( "Ultrakill_ExplosionSmokeLinger", pos, self:GetAngles() )

    -- direct hit: canon 30
    if IsValid( directHit ) and ( directHit:IsPlayer() or directHit:IsNPC() or directHit:IsNextBot() )
        and not directHit.UKMR_IsMirrorReaper and not directHit.UKMR_IsHand then
      -- round-3 sweep: canon number in, x100 LANDED out (was x1000 raw = 600k)
      local damage = UKMirrorReaper.ORB_DAMAGE
      local dmg = DamageInfo()
      dmg:SetDamage( UKMirrorReaper.ScaleAttackDamage( directHit, damage,
        IsValid( owner ) and owner or self ) )
      dmg:SetDamageType( DMG_ACID )
      dmg:SetAttacker( IsValid( owner ) and owner or self )
      dmg:SetInflictor( self )
      dmg:SetDamagePosition( directHit:WorldSpaceCenter() )
      dmg:SetDamageForce( self:GetVelocity():GetNormalized() * 600 )
      directHit:TakeDamageInfo( dmg )
    end

    -- poison cloud: canon 15/tick over ~3 s. Reuses the Minotaur Goop zone
    -- (ultrakill_test_minotaur_acid) — canon-green gas sphere, glow, sizzle.
    local radius = UKMirrorReaper.CLOUD_RADIUS
    local cloudPos = pos
    -- hug the floor like the Minotaur's Acid Bomb does (clouds spawned mid-air
    -- at a wall-impact point would hover uselessly out of reach)
    local down = util.TraceLine( {
      start = pos,
      endpos = pos - Vector( 0, 0, 40 * UNIT ),
      mask = MASK_SOLID_BRUSHONLY,
    } )
    if down.Hit then
      cloudPos = Vector( pos.x, pos.y, math.min( pos.z, down.HitPos.z + radius * 0.6 ) )
    end
    local acid = ents.Create( "ultrakill_test_minotaur_acid" )
    if IsValid( acid ) then
      acid:SetPos( cloudPos )
      acid:Spawn()
      acid:UKMA_Setup( {
        mode = "cloud",
        attacker = IsValid( owner ) and owner or nil,
        tickDamage = UKMirrorReaper.CLOUD_DAMAGE,
        tickInterval = 1.0, -- canon 15/тик раз в секунду (у Минотавра 0.5 с)
        lifetime = 3.5,
        radius = radius,
        immuneFlags = { "UKMR_IsMirrorReaper", "UKMR_IsHand" },
      } )
    end

    self:Remove()
  end

else

  function ENT:CustomThink()
    self:AngleFollowVelocity()
  end

  local SpriteMaterial = Material( "particles/ultrakill/Charge" )
  local SpriteColor = Color( 170, 25, 25, 255 ) -- canon: dark red orbs

  function ENT:CustomDraw()
    RSetMaterial( SpriteMaterial )
    RDrawSprite( self:GetPos(), 28, 28, SpriteColor )
  end

end

AddCSLuaFile()
