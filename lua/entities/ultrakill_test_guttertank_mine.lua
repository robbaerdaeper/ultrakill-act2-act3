AddCSLuaFile()

local UltrakillBase = UltrakillBase
local Material = Material
local Color = Color
local RSetMaterial = CLIENT and render.SetMaterial
local RDrawSprite = CLIENT and render.DrawSprite

if not DrGBase or not UltrakillBase then return end
include( "autorun/ultrakill_test_guttertank_shared.lua" )

-- Guttertank landmine (canon Landmine prefab bake, ProBuilder mesh). Placed
-- under its feet, mostly when it lacks line of sight. The model is never
-- tinted — all state lives in the beacon lamp on top: soft red standby ->
-- proximity Activate: canon yellow parryable flash, the lamp goes THE parry
-- yellow, hop to player height, beep (pitch 1.5 baked) — and it explodes the
-- moment it touches the ground (or its victim) on the way down. Parry
-- (UKBase standard: base OnParry does flash/hitstop/velocity): cyan lamp,
-- flies dead straight until it hits ANYTHING, super explosion (canon
-- '+SERVED' / '+LANDYOURS'). Mines persist after the Guttertank dies (canon).

ENT.Base = "ultrakillbase_projectile"
ENT.PrintName = "Guttertank Landmine"
ENT.Category = "ULTRAKILL"
ENT.Models = { UKGuttertank.MINE_MODEL }
-- standalone-spawnable: a hand-placed mine is wild (no owner) — it arms
-- against everyone who comes near, including the player who placed it
ENT.Spawnable = true
ENT.Gravity = true
ENT.Physgun = true -- a lying mine can be picked up and relocated
ENT.UltrakillBase_Parryable = false -- armed on Activate only (canon parryZone)
ENT.UltrakillBase_CustomCollisionEnabled = false
-- base Contact() removes the projectile unless OnContact returns false or
-- this is negative; a mine must survive landing on the ground
ENT.OnContactDelete = -1

local HOP_APEX = 76      -- player height: hop peaks at eye level
local PARRY_SPEED = 4200 -- canon 250 m/s, Source clamp (rocket convention)

if SERVER then

  -- Q-menu spawn: mark the mine hand-placed (no sandbox-cleanup timer) BEFORE
  -- Spawn so CustomInitialize sees it. Deliberately NO owner: like the
  -- ULTRAKILL sandbox spawner, a hand-placed mine is wild — it arms against
  -- everyone who comes near, INCLUDING the player who placed it (an owner
  -- never triggers his own mine, which read as "не агрится" in testing).
  function ENT:SpawnFunction( ply, tr, class )
    if not tr.Hit then return end
    local mine = ents.Create( class )
    if not IsValid( mine ) then return end
    mine.UKGT_PlayerPlaced = true
    mine:SetPos( tr.HitPos + tr.HitNormal * 8 )
    mine:Spawn()
    mine:Activate()
    return mine
  end

  function ENT:CustomInitialize()
    self:SetNW2Int( "UKGT_MineState", 0 ) -- 0 standby, 1 armed
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )

    -- trace-solid (physgun/bullets) AND body-solid: victims must be able to
    -- bump it — the WEAPON group made it ghost through every NPC, so armed
    -- mines fell straight through their targets. The default group collides
    -- with world, players and NPCs; the 10-su plate is below step height,
    -- so nobody actually gets stuck on it.
    self:SetNotSolid( false )
    self:SetSolid( SOLID_VPHYSICS )

    self.UKGT_Settled = false
    self.UKGT_Activated = false
    self.UKGT_ActivatedAt = 0
    self.UKGT_ExplodeAt = nil
    self.UKGT_ParryDir = nil

    -- canon Landmine idle: the DroneScan clip at PITCH 2.5, half volume — at
    -- pitch 1.0 it just sounded like a drone hovering nearby (round 2,
    -- 2026-07-10: "мины издают звуки дронов")
    self.UKGT_ScanSound = CreateSound( self, UKGuttertank.SOUND.MineScan )
    self.UKGT_ScanSound:PlayEx( 0.5, 250 )

    -- canon mines persist; cap lifetime to keep sandbox maps clean —
    -- but never reap mines the player placed by hand from the Q-menu
    if not self.UKGT_PlayerPlaced then
      SafeRemoveEntityDelayed( self, 180 )
    end
  end

  -- The base projectile is VPhysics-backed: freeze/launch through the phys
  -- object (canon isKinematic = EnableMotion(false); movetype hacks do
  -- nothing here). OnContact runs inside a physics callback, so the state
  -- changes are deferred one tick (uk_magnet pattern).
  -- idempotent: also re-freezes after a physgun relocation drops it back down
  function ENT:UKGT_Settle()
    self.UKGT_Settled = true
    timer.Simple( 0, function()
      if not IsValid( self ) or self.UKGT_Exploded then return end
      local phys = self:GetPhysicsObject()
      if IsValid( phys ) then
        phys:SetVelocity( vector_origin )
        phys:EnableMotion( false )
      else
        self:SetMoveType( MOVETYPE_NONE )
      end
    end )
  end

  function ENT:UKGT_Activate()
    if self.UKGT_Activated then return end
    self.UKGT_Activated = true
    self.UKGT_ActivatedAt = CurTime()
    -- canon Activate: the scan loop's clip is REPLACED by BeepBeep_high and
    -- keeps looping until detonation — THAT loop is the mine's jump sound
    -- (round 2: "у мины есть свой звук когда подпрыгивает").
    -- mine_beep.wav is a ~0.2 s one-shot, so loop it with a repeating timer.
    if self.UKGT_ScanSound then self.UKGT_ScanSound:Stop() end
    self:EmitSound( UKGuttertank.SOUND.MineBeep, 85, 100, 1 )
    local beepTimer = "UKGT_MineBeep_" .. self:EntIndex()
    timer.Create( beepTimer, 0.22, 0, function()
      if not IsValid( self ) or self.UKGT_Exploded then
        timer.Remove( beepTimer )
        return
      end
      self:EmitSound( UKGuttertank.SOUND.MineBeep, 85, 100, 1 )
    end )
    self:SetNW2Int( "UKGT_MineState", 1 )
    -- failsafe only (landed on nothing); the real trigger is ground contact
    self.UKGT_ExplodeAt = CurTime() + 3
    -- canon parryZone opens: THE yellow flash (parryable projectile alert)
    if self.CreateAlert then
      self:CreateAlert( self:GetPos() + Vector( 0, 0, 24 ), 3, 2 )
    end
    timer.Simple( 0, function()
      if not IsValid( self ) or self.UKGT_Exploded then return end
      -- canon Activate: hop up to player height, tumble, parry window opens
      local phys = self:GetPhysicsObject()
      if IsValid( phys ) then
        local g = math.abs( physenv.GetGravity().z )
        if g < 1 then g = 600 end
        phys:EnableMotion( true )
        phys:EnableGravity( true )
        phys:Wake()
        phys:SetVelocity( Vector( 0, 0, math.sqrt( 2 * g * HOP_APEX ) ) )
        phys:AddAngleVelocity( VectorRand() * 120 )
      else
        self:SetMoveType( MOVETYPE_FLY )
        self:SetVelocity( Vector( 0, 0, math.sqrt( 2 * 600 * HOP_APEX ) ) )
      end
      self:SetParryable( true )
    end )
  end

  function ENT:UKGT_Explode( super )
    if self.UKGT_Exploded then return end
    self.UKGT_Exploded = true
    -- OnContact runs inside a physics callback: spawning the explosion and
    -- removing the entity there is crash bait — detonate next tick
    timer.Simple( 0, function()
      if not IsValid( self ) then return end
      UltrakillBase.SoundScript(
        super and "Ultrakill_Explosion_2" or "Ultrakill_Explosion_1", self:GetPos() )
      -- canon: landmine explosion is twice the rocket's size (maxSize 12 vs 6)
      local dmg = UKGuttertank.MINE_DAMAGE * ( super and 1.5 or 1 )
      local radius = super and 380 or 300
      -- blast-gated HL2 heavies (helicopter/gunship/strider) get their
      -- engine-shaped damage; the filter keeps the base blast off them
      -- (fed the raw nominal — their gate is owner-independent)
      local owner = self:GetOwner()
      local ignore = UKGuttertank.BlastCompat( self, owner,
        self:GetPos(), radius, dmg )
      if IsValid( owner ) and owner:IsPlayer() then
        -- player-owned blast (parried serve / shot-down mine): the base path
        -- nets a fixed x40 on UK-nextbot victims, so feed the landed NPC
        -- target / 40 (Providence recipe). The base owner filter keeps the
        -- blast off the player himself, so the small fed number never
        -- shortchanges a player victim on this branch.
        dmg = ( super and UKGuttertank.MINE_PARRY_DAMAGE_NPC
          or UKGuttertank.MINE_DAMAGE_NPC ) / UKGuttertank.PARRY_EXPLOSION_NET_MULT
      end
      self:Explosion( self:GetPos(), dmg, nil, radius, 0.2,
        owner, super, ignore )
      self:CreateExplosion( self:GetPos(), self:GetAngles(), super and 1.3 or 1 )
      self:Remove()
    end )
  end

  function ENT:UKGT_IsTriggeredBy( ent )
    if not IsValid( ent ) then return false end
    -- the owner never triggers his own mine: neither the tank that laid it,
    -- nor the player who claimed it with a hammer knock
    local owner = self:GetOwner()
    if ent == owner then return false end
    -- possessed tank: the possessor rides inside the owner, so the tank's
    -- own mines must not arm against him (he "is" the tank right now)
    if IsValid( owner ) and owner.IsPossessed and owner:IsPossessed()
        and ent == owner:GetPossessor() then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:Health() <= 0 then return false end
    if not ent:IsNPC() and not ent:IsNextBot() then return false end
    if IsValid( owner ) and owner.IsAlly and owner:IsAlly( ent ) then return false end
    return true
  end

  function ENT:CustomThink()
    if self.UKGT_Exploded then return end

    if self:GetParried() then
      -- canon FixedUpdate while parried: constant-speed straight flight
      -- (base OnParry already killed phys gravity)
      if not self.UKGT_ParryDir then
        local v = self:GetVelocity()
        self.UKGT_ParryDir = v:LengthSqr() > 1 and v:GetNormalized() or self:GetForward()
      end
      local phys = self:GetPhysicsObject()
      if IsValid( phys ) then
        phys:SetVelocity( self.UKGT_ParryDir * PARRY_SPEED )
      else
        self:SetVelocity( self.UKGT_ParryDir * PARRY_SPEED )
      end
      return
    end

    if self.UKGT_ExplodeAt and CurTime() >= self.UKGT_ExplodeAt then
      self:UKGT_Explode( false )
      return
    end

    -- settle safety net: a mine that came to rest without a clean world
    -- contact (spawned flush with the floor, toolgun, dupes) still arms
    if not self.UKGT_Activated and not self.UKGT_Settled
        and self:GetVelocity():LengthSqr() < 25 then
      self:UKGT_Settle()
    end

    if not self.UKGT_Activated and self.UKGT_Settled then
      -- canon OnTriggerEnter: player (or the tank's target) walks in
      -- (the plate itself is 46 su wide — trigger reaches past its rim)
      for _, ent in ipairs( ents.FindInSphere( self:GetPos(), 120 ) ) do
        if self:UKGT_IsTriggeredBy( ent ) then
          self:UKGT_Activate()
          break
        end
      end
    end
  end

  function ENT:OnParry( ply, dmg )
    -- UKBase standard parry (flash/hitstop/owner/velocity), canon extras:
    -- fuse canceled, cyan lamp (client reads GetParried), straight
    -- constant-speed flight until it hits something (no timer)
    baseclass.Get( "ultrakillbase_projectile" ).OnParry( self, ply, dmg )
    self.UKGT_ExplodeAt = nil
    self.UKGT_ParryDir = nil -- captured from the parry velocity next think
  end

  function ENT:OnContact( mEntity )
    if self.UKGT_Exploded then return false end
    if self:GetParried() then
      -- canon OnCollisionEnter while parried: super explosion on ANYTHING
      -- except the parrier (serve!)
      if mEntity == self:GetOwner() then return false end
      self:UKGT_Explode( true )
      return false
    end
    if not self.UKGT_Activated then
      if mEntity:IsWorld() then
        self:UKGT_Settle()
      elseif self:UKGT_IsTriggeredBy( mEntity ) then
        self:UKGT_Settle()
        self:UKGT_Activate()
      end
      return false
    end
    -- armed: victim bump = boom; touching the ground on the way down = boom
    if self:UKGT_IsTriggeredBy( mEntity ) then
      self:UKGT_Explode( false )
    elseif mEntity:IsWorld()
        and CurTime() - self.UKGT_ActivatedAt > 0.2
        and self:GetVelocity().z <= 10 then
      self:UKGT_Explode( false )
    end
    return false
  end

  function ENT:OnTakeDamage( dmg )
    self:CheckParry( dmg )
    if self:GetParried() then return end
    local attacker = dmg:GetAttacker()
    if ( dmg:IsDamageType( DMG_CLUB ) or dmg:IsDamageType( DMG_SLASH ) )
        and IsValid( attacker ) and attacker:IsPlayer() then
      -- Impact Hammer / melee on a standby mine = a full parry serve:
      -- un-freeze the settled plate and let the canon parry take it —
      -- cyan lamp, straight flight along the aim, super explosion on
      -- whatever it hits. Armed mines never reach here (CheckParry above
      -- already handled them, they're the parryable ones).
      local phys = self:GetPhysicsObject()
      if IsValid( phys ) then
        phys:EnableMotion( true )
        phys:Wake()
      end
      self.UKGT_Settled = false
      self:OnParry( attacker, dmg )
      -- don't trust the frozen-plate impulse: aim the straight flight now
      self.UKGT_ParryDir = attacker:GetAimVector()
      return
    end
    -- canon: mines are shootable
    self:SetOwner( dmg:GetAttacker() )
    self:UKGT_Explode( false )
  end

  function ENT:OnRemove()
    if self.UKGT_ScanSound then self.UKGT_ScanSound:Stop() end
  end

else

  local SpriteMaterial = Material( "particles/ultrakill/Charge" )

  local GLOW_IDLE = Color( 255, 60, 40, 110 )    -- soft red standby lamp
  local GLOW_ARMED = Color( 255, 230, 80, 255 )  -- THE parry-flash yellow
  local GLOW_PARRIED = Color( 0, 255, 255, 255 ) -- canon (0, 1, 1)

  function ENT:CustomDraw()
    self:DrawModel()
    -- beacon lamp on the top knob (local offset tracks the hop tumble)
    local pos = self:LocalToWorld( Vector( 0, 0, 10 ) )
    RSetMaterial( SpriteMaterial )
    if self:GetParried() then
      RDrawSprite( pos, 22, 22, GLOW_PARRIED )
    elseif self:GetNW2Int( "UKGT_MineState", 0 ) >= 1 then
      local s = 18 + math.sin( CurTime() * 24 ) * 4 -- fast danger pulse
      RDrawSprite( pos, s, s, GLOW_ARMED )
    else
      local s = 9 + math.sin( CurTime() * 3 ) * 1.5 -- slow breathing
      RDrawSprite( pos, s, s, GLOW_IDLE )
    end
  end

end

AddCSLuaFile()
