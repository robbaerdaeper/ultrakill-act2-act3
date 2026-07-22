local UltrakillBase = UltrakillBase
local IsValid = IsValid
local AddCSLuaFile = AddCSLuaFile

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_power_shared.lua" )
ENT.Base = "ultrakillbase_projectile"

-- Power thrown spear (canon PowerThrownSpear): straight, speed 150 m/s,
-- 35 dmg, strong, explodes on impact (SkullExplosion). Parryable.

ENT.PrintName = "Power Spear"
ENT.Category = "UltrakillBase"
ENT.Models = { UKPower.MODEL_SPEAR }
ENT.ModelScale = 1
ENT.Spawnable = false

ENT.OnContactDelete = -1
ENT.UltrakillBase_CustomCollisionEnabled = true
ENT.UltrakillBase_CustomCollisionBounds = Vector( 20, 20, 20 )

if SERVER then

  function ENT:CustomInitialize()
    self.mInitOwner = self:GetOwner()
    SafeRemoveEntityDelayed( self, 8 )

    -- the feedbacker parries via a MASK_SHOT_HULL trace, but the projectile
    -- base leaves the entity not-solid (untraceable -> unparryable in game).
    -- Coin recipe: solid bbox in DEBRIS_TRIGGER — punch traces hit it, players
    -- and NPCs never collide with it. Applied a tick later because the DrG
    -- base re-inits physics right after CustomInitialize.
    timer.Simple( 0, function()
      if not IsValid( self ) then return end
      self:SetNotSolid( false )
      self:SetSolid( SOLID_BBOX )
      self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
      self:SetCollisionBounds( Vector( -35, -35, -35 ), Vector( 35, 35, 35 ) )
    end )
  end

  function ENT:CustomThink()
    -- Ultrakill Arms parry fix (owner swap breaks base relations)
    local owner = self:GetOwner()
    if owner ~= self.mInitOwner and IsValid( self.mInitOwner ) then
      self:SetOwner( self.mInitOwner )
    end
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

  -- canon parry: the spear whips back into its owner (strong projectile)
  function ENT:OnParry( ply, dmg )
    local owner = IsValid( self.mInitOwner ) and self.mInitOwner or self:GetOwner()
    UltrakillBase.SoundScript( "Ultrakill_Parry", ply:GetPos() )
    UltrakillBase.HitStop( 0.25 )
    UltrakillBase.OnParryPlayer( ply )
    if IsValid( owner ) then
      -- canon: flat 35 (x1000 pack scale) to the owner. His DamageMultiplier
      -- re-scales player-attributed damage (x10), so feed the pre-multiplier
      -- value — a raw 35000 here would land as 350000 and one-shot the Power
      local mult = math.max( isfunction( owner.GetDamageMultiplierConVar )
        and owner:GetDamageMultiplierConVar( ply ) or 1, 0.01 )
      local d = DamageInfo()
      d:SetDamage( UKPower.SPEAR_THROWN_DAMAGE * 1000 / mult )
      d:SetDamageType( DMG_ENERGYBEAM + DMG_DIRECT )
      d:SetAttacker( ply )
      d:SetInflictor( self )
      d:SetDamagePosition( owner:WorldSpaceCenter() )
      owner:TakeDamageInfo( d )
    end
    self:UKP_Explode( self:GetPos() )
    SafeRemoveEntityDelayed( self, engine.TickInterval() )
  end

  function ENT:OnContact( ent )
    if self:GetParried() then return self:ParryCollide( 300 ) end
    if IsValid( ent ) and ent.UKPower_IsPower then return end -- canon safeEnemyType

    if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then
      local amount = UKPower.ScaleAttackDamage( ent, UKPower.SPEAR_THROWN_DAMAGE )
      if not ent:IsPlayer() and ent.IsUltrakillNextbot then
        -- round-3 sweep (2026-07-10): was x1000 (landed 35000 = x10 over the
        -- convention) — canon x100 LANDED, pre-divided via the shared helper
        amount = UKNpcDmg.PreMult( ent, self:GetOwner(),
          UKPower.SPEAR_THROWN_DAMAGE * 100 )
      end
      self:DealDamage( ent, amount, nil, DMG_ENERGYBEAM )
    end
    self:UKP_Explode( self:GetPos() )
    SafeRemoveEntityDelayed( self, engine.TickInterval() )
  end

else

  -- r2 model is baked from the canon PowerThrownSpear prefab: tip = +X =
  -- entity forward, no render-angle hack needed

  function ENT:Draw()
    self:DrawModel()
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = self:GetPos()
      dl.r, dl.g, dl.b = 255, 180, 60
      dl.brightness = 1.5
      dl.size = 180
      dl.decay = 0
      dl.dietime = CurTime() + 0.1
    end
  end

end

AddCSLuaFile()
