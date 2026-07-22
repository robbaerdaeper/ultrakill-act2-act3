AddCSLuaFile()

local UltrakillBase = UltrakillBase
local Material = Material
local Color = Color
local RSetMaterial = CLIENT and render.SetMaterial
local RDrawSprite = CLIENT and render.DrawSprite

if not DrGBase or not UltrakillBase then return end

-- Big Johninator landmine (canon Landmine.cs). Dropped every ~4 s under the
-- boss (MineLayer/MineLayerDelay cycle). Green idle (DroneScan loop) ->
-- proximity Activate: hop, beep (pitch 1.5), orange, 1 s fuse -> explode.
-- Parryable (UKBase standard: base OnParry does flash/hitstop/velocity);
-- a parried mine flies straight, cyan, super-explodes on an enemy (canon
-- 'ultrakill.landyours' serve) or after 3 s.

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Johninator Landmine"
ENT.Category = "UltrakillBase"
ENT.Models = { "models/props_combine/combine_mine01.mdl" }
ENT.ModelScale = 0.9
ENT.Spawnable = false
ENT.Gravity = true
ENT.UltrakillBase_Parryable = false -- armed on Activate only (canon parryZone)
ENT.UltrakillBase_CustomCollisionEnabled = false

local COLOR_IDLE = Color( 60, 255, 60 )
local COLOR_ARMED = Color( 255, 168, 0 )   -- canon (1, 0.66, 0)
local COLOR_PARRIED = Color( 0, 255, 255 ) -- canon (0, 1, 1)

if SERVER then

  function ENT:CustomInitialize()
    self:SetColor( COLOR_IDLE )
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )

    self.UKJ_Settled = false
    self.UKJ_Activated = false
    self.UKJ_ExplodeAt = nil

    self.UKJ_ScanSound = CreateSound( self, UKJohninator.SOUND.MineScan )
    self.UKJ_ScanSound:PlayEx( 0.25, 100 )

    -- canon mines persist; cap lifetime to keep sandbox maps clean
    SafeRemoveEntityDelayed( self, 120 )
  end

  function ENT:UKJ_Settle()
    if self.UKJ_Settled then return end
    self.UKJ_Settled = true
    self:SetVelocity( vector_origin )
    self:SetMoveType( MOVETYPE_NONE )
  end

  function ENT:UKJ_Activate()
    if self.UKJ_Activated then return end
    self.UKJ_Activated = true
    -- canon Activate: hop up, beep at pitch 1.5 (baked), parry window opens
    self:SetMoveType( MOVETYPE_FLY )
    self:SetVelocity( Vector( 0, 0, 220 ) )
    self:EmitSound( UKJohninator.SOUND.MineBeep, 85, 100, 1 )
    self:SetColor( COLOR_ARMED )
    self:SetParryable( true )
    self.UKJ_ExplodeAt = CurTime() + 1
  end

  function ENT:UKJ_Explode( super )
    if self.UKJ_Exploded then return end
    self.UKJ_Exploded = true
    UltrakillBase.SoundScript(
      super and "Ultrakill_Explosion_2" or "Ultrakill_Explosion_1", self:GetPos() )
    local dmg = UKJohninator.MINE_DAMAGE * ( super and 1.5 or 1 )
    self:Explosion( self:GetPos(), dmg, nil, super and 250 or 200, 0.2,
      self:GetOwner(), super )
    self:CreateExplosion( self:GetPos(), self:GetAngles(), super and 1.3 or 1 )
    self:Remove()
  end

  function ENT:UKJ_IsTriggeredBy( ent )
    if not IsValid( ent ) then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:Health() <= 0 then return false end
    local owner = self:GetOwner()
    if ent == owner then return false end
    if not ent:IsNPC() and not ent:IsNextBot() then return false end
    if IsValid( owner ) and owner.IsAlly and owner:IsAlly( ent ) then return false end
    return true
  end

  function ENT:CustomThink()
    if self.UKJ_Exploded then return end

    -- manual gravity for the activation hop (MOVETYPE_FLY has none)
    if self.UKJ_Activated and not self:GetParried() then
      local v = self:GetVelocity()
      self:SetVelocity( Vector( v.x, v.y, v.z - 600 * FrameTime() * 4 ) )
    end

    if self.UKJ_ExplodeAt and CurTime() >= self.UKJ_ExplodeAt then
      self:UKJ_Explode( false )
      return
    end

    if not self.UKJ_Activated and self.UKJ_Settled then
      -- canon OnTriggerEnter: player (or the boss's target) walks in
      for _, ent in ipairs( ents.FindInSphere( self:GetPos(), 90 ) ) do
        if self:UKJ_IsTriggeredBy( ent ) then
          self:UKJ_Activate()
          break
        end
      end
    end
  end

  function ENT:OnParry( ply, dmg )
    -- UKBase standard parry (flash/hitstop/owner/velocity), canon extras:
    -- fuse canceled, cyan, straight flight, 3 s failsafe
    -- (lazy baseclass.Get: entities register alphabetically, the base is later)
    baseclass.Get( "ultrakillbase_projectile" ).OnParry( self, ply, dmg )
    self:SetColor( COLOR_PARRIED )
    self.UKJ_ExplodeAt = CurTime() + 3
  end

  function ENT:OnContact( mEntity )
    if self.UKJ_Exploded then return end
    if self:GetParried() then
      -- canon OnCollisionEnter while parried: super explosion (serve!)
      self:UKJ_Explode( true )
      return
    end
    if not self.UKJ_Activated then
      if mEntity:IsWorld() then
        self:UKJ_Settle()
      elseif self:UKJ_IsTriggeredBy( mEntity ) then
        self:UKJ_Settle()
        self:UKJ_Activate()
      end
      return
    end
    -- armed mine bumped by its victim: explode immediately
    if self:UKJ_IsTriggeredBy( mEntity ) then
      self:UKJ_Explode( false )
    end
  end

  function ENT:OnTakeDamage( dmg )
    self:CheckParry( dmg )
    if self:GetParried() then return end
    -- canon: mines are shootable
    self:SetOwner( dmg:GetAttacker() )
    self:UKJ_Explode( false )
  end

  function ENT:OnRemove()
    if self.UKJ_ScanSound then self.UKJ_ScanSound:Stop() end
  end

else

  local SpriteMaterial = Material( "particles/ultrakill/Charge" )

  function ENT:CustomDraw()
    self:DrawModel()
    local col = self:GetColor()
    RSetMaterial( SpriteMaterial )
    RDrawSprite( self:GetPos() + Vector( 0, 0, 6 ), 18, 18,
      Color( col.r, col.g, col.b, 255 ) )
  end

end

AddCSLuaFile()
