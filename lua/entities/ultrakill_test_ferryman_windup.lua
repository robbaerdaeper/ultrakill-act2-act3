AddCSLuaFile()

-- Canon "LightningBoltWindupFollow Variant": a thin vertical silhouette pillar
-- spawned at the predicted player position. Follows the target horizontally
-- (Follow XZ, speed 5 m/s x difficulty mult), snaps to the target's ground
-- height instantly (Follow Y, speed 0). Quick cast (diff>=4): pillar visual
-- appears 3 s in (ObjectActivator.delay=3), WindupOver auto-fires at 5 s
-- (Invoke, real seconds). Normal cast: pillar visible immediately, WindupOver
-- comes from the Ferryman's animation event. Strike = WindupOver + 0.5 s.
-- RemoveOnTime 10 s failsafe.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ferryman Lightning Windup"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- metre length comes from the shared module (24 after the r3 rescale, NOT the
-- pre-rescale 40) and is read at call time so load order vs autorun is moot

function ENT:SetupDataTables()
  self:NetworkVar( "Bool", 0, "PillarVisible" )
  self:NetworkVar( "Bool", 1, "FlashActive" )
  -- canon ScaleTransform: the pillar thickens 0.1 -> 1.0 at 0.35/s from the
  -- moment it becomes visible; the client needs the start time to replicate
  self:NetworkVar( "Float", 0, "PillarStart" )
end

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/plates/plate.mdl" )
    -- NOT SetNoDraw: that would suppress the clientside Draw/DrawTranslucent
    -- hooks entirely; the model itself stays hidden via the empty CLIENT Draw.
    self:SetSolid( SOLID_NONE )
    self:SetMoveType( MOVETYPE_NONE )
    self:DrawShadow( false )

    self.UKFW_SpawnTime = CurTime()
    self.UKFW_StruckAt = nil
    self:SetPillarVisible( not self.UKFW_Quick )
    self:SetPillarStart( CurTime() )

    -- canon windup AudioSource: rumble at pitch 0.5, play on awake
    self:EmitSound( UKFerryman.SOUND.WindupRumble, 90, 50, 1 )

    -- RemoveOnTime 10 (failsafe if the owner dies mid-cast without cancel)
    timer.Simple( 10, function()
      if IsValid( self ) and not self.UKFW_StruckAt then self:Remove() end
    end )

    if self.UKFW_Quick then
      timer.Simple( 3, function()
        if IsValid( self ) then
          self:SetPillarVisible( true )
          self:SetPillarStart( CurTime() )
        end
      end )
      timer.Simple( 5, function()
        if IsValid( self ) then self:WindupOver() end
      end )
    end
  end

  -- diff 0: no tracking; 1: x0.5; 2: x2; 3+: x3 (canon Follow speed scaling)
  local FOLLOW_MULT = { [0] = 0, [1] = 0.5, [2] = 2 }

  function ENT:UKFW_Setup( owner, target, quick, difficulty, speedMod )
    self.UKFW_Owner = owner
    self.UKFW_Target = target
    self.UKFW_Quick = quick or false
    -- canon Follow.speed 5 (m/s)
    self.UKFW_FollowSpeed = 5 * UKFerryman.UNIT * ( FOLLOW_MULT[ difficulty ] or 3 ) * ( speedMod or 1 )
  end

  function ENT:Think()
    if self.UKFW_StruckAt then return end

    local target = self.UKFW_Target
    local tpos
    if IsValid( target ) then
      tpos = target:GetPos()
    else
      -- possessed cast with no lock-on: canon aiming recipe — the strike
      -- point is the point under the possessor's crosshair, so the pillar
      -- follows it (at the same canon Follow speed) instead of freezing at
      -- the windup-time snapshot
      local owner = self.UKFW_Owner
      if IsValid( owner ) and owner.IsPossessed and owner:IsPossessed()
          and owner.PossessorTrace then
        local tr = owner:PossessorTrace()
        if tr then tpos = tr.HitPos end
      end
    end
    if tpos then
      local dt = FrameTime()
      local pos = self:GetPos()

      -- Follow XZ at canon speed
      local to = Vector( tpos.x - pos.x, tpos.y - pos.y, 0 )
      local dist = to:Length()
      local step = self.UKFW_FollowSpeed * dt
      if dist > 1 then
        if step >= dist then
          pos.x, pos.y = tpos.x, tpos.y
        else
          to:Mul( step / dist )
          pos:Add( to )
        end
      end

      -- Follow Y instant: pillar base sits on the ground under the target
      local tr = util.TraceLine( {
        start = Vector( pos.x, pos.y, tpos.z + 10 ),
        endpos = Vector( pos.x, pos.y, tpos.z - 4000 ),
        mask = MASK_SOLID_BRUSHONLY,
      } )
      pos.z = tr.Hit and tr.HitPos.z or tpos.z

      self:SetPos( pos )
    end

    self:NextThink( CurTime() )
    return true
  end

  -- Called by the Ferryman's LightningBoltWindupOver anim event (normal cast)
  -- or by the internal 5 s Invoke (quick cast). Canon: huge unparryable flash
  -- above the pillar, strike lands 0.5 s later.
  function ENT:WindupOver()
    if self.UKFW_WindupOver or self.UKFW_StruckAt then return end
    self.UKFW_WindupOver = true
    self:SetPillarVisible( true )
    self:SetFlashActive( true )

    local owner = self.UKFW_Owner
    if IsValid( owner ) and owner.CreateAlert then
      owner:CreateAlert( self:GetPos() + Vector( 0, 0, 300 ), 2, 6 )
    end

    timer.Simple( 0.5, function()
      if IsValid( self ) then self:Strike() end
    end )
  end

  -- Canon LightningStrikeExplosive.Start coin branch: a live revolver coin
  -- ABOVE the target and within 2 m (XZ) of the strike point reflects the
  -- bolt ("Ride the Lightning" chargeback) instead of exploding.
  function ENT:UKFW_FindChargebackCoin( pos )
    local target = self.UKFW_Target
    local minZ = IsValid( target ) and target:GetPos().z or pos.z
    for _, coin in ipairs( ents.FindByClass( "ultrakill_coin" ) ) do
      if not IsValid( coin ) then continue end
      if coin.GetDead and coin:GetDead() then continue end
      local cp = coin:GetPos()
      if cp.z > minZ
          and Vector( cp.x - pos.x, cp.y - pos.y, 0 ):Length() < 2 * UKFerryman.UNIT then
        return coin
      end
    end
  end

  function ENT:Strike()
    if self.UKFW_StruckAt then return end
    self.UKFW_StruckAt = CurTime()

    local pos = self:GetPos()
    local owner = self.UKFW_Owner

    if IsValid( owner ) and owner.UKFerryman_OnLightningStrike then
      owner:UKFerryman_OnLightningStrike()
    end

    local coin = self:UKFW_FindChargebackCoin( pos )
    if IsValid( coin ) then
      -- the bolt lands ON the coin; ukcoin's own ricochet logic does the rest.
      -- Canon reflected prefab = ultraRicocheter railcannon RevolverBeam, so
      -- the coin is put into RAILCANNON state (piercing beam + coin chaining).
      local cpos = coin:GetPos()
      -- coins carry no thrower record; the tracked target (the player dodging
      -- the bolt) is the one who tossed it — canon beams are player-owned
      local attacker = IsValid( self.UKFW_Target ) and self.UKFW_Target or game.GetWorld()

      local fx = EffectData()
      fx:SetOrigin( cpos )
      util.Effect( "ultrakill_test_ferryman_bolt", fx, true, true )
      sound.Play( UKFerryman.SOUND.Thunder, cpos, 140, 115, 1 )
      util.ScreenShake( cpos, 8, 60, 0.6, 1200 )

      -- the chargeback bolt still detonates where it landed: full ULTRAKILL
      -- explosion at the coin — safe for the player riding the trick,
      -- electric, hurts everything else around
      UKFerryman.Explode( IsValid( owner ) and owner or nil, cpos,
        UKFerryman.LIGHTNING_RADIUS, UKFerryman.LIGHTNING_DAMAGE,
        { electric = true, safeForPlayer = true } )

      coin:SetCoinState( "RAILCANNON" )
      -- the railcannon beam fires synchronously inside TakeDamageInfo below;
      -- flag the owner so his OnTakeDamage caps the self-hit (canon: massive
      -- damage, not an instakill)
      if IsValid( owner ) then owner.UKF_ChargebackUntil = CurTime() + 0.3 end
      local dmg = DamageInfo()
      dmg:SetDamage( UKFerryman.CHARGEBACK_DAMAGE )
      dmg:SetDamageType( DMG_BULLET )
      dmg:SetAttacker( attacker )
      dmg:SetInflictor( attacker )
      dmg:SetDamagePosition( cpos )
      coin:TakeDamageInfo( dmg )

      self:Remove()
      return
    end

    UKFerryman.Explode( IsValid( owner ) and owner or nil, pos,
      UKFerryman.LIGHTNING_RADIUS, UKFerryman.LIGHTNING_DAMAGE, { electric = true } )

    local fx = EffectData()
    fx:SetOrigin( pos )
    util.Effect( "ultrakill_test_ferryman_bolt", fx, true, true )

    sound.Play( UKFerryman.SOUND.Thunder, pos, 140, 100, 1 )
    util.ScreenShake( pos, 8, 60, 0.6, 1200 )

    self:Remove()
  end

  function ENT:Cancel()
    if self.UKFW_StruckAt then return end
    self:Remove()
  end

  function ENT:OnRemove()
    self:StopSound( UKFerryman.SOUND.WindupRumble )
  end
end

if CLIENT then

  -- Canon 'LightningBoltWindup' prefab: a DARK translucent silhouette cylinder
  -- (MinosSearchLights material, colour 0.082/0.052/0.113) that thickens from
  -- scale 0.1 to 1.0 at 0.35/s (ScaleTransform), with small additive lightning
  -- arcs ('lightning2' particles) crawling over it and a faint white light.
  local pillarMat = Material( "effects/ukferryman_pillar" )
  local arcMat = Material( "effects/ukferryman_arc" )
  local glowMat = Material( "sprites/light_glow02_add" )

  local PILLAR_H = 2600
  -- canon cylinder ~2 m across at full scale => 80 su
  local PILLAR_W = 80

  function ENT:Initialize()
    self:SetRenderBounds( Vector( -200, -200, 0 ), Vector( 200, 200, 3000 ) )
  end

  function ENT:Draw()
  end

  function ENT:DrawTranslucent()
    if not self:GetPillarVisible() then return end

    local base = self:GetPos()
    local top = base + Vector( 0, 0, PILLAR_H )

    -- canon ScaleTransform growth 0.1 -> 1.0 at 0.35/s
    local t = CurTime() - self:GetPillarStart()
    local scale = math.min( 0.1 + 0.35 * math.max( t, 0 ), 1 )
    local width = PILLAR_W * scale

    if self:GetFlashActive() then
      -- canon WindupOver flash: the silhouette blows out to white
      render.SetMaterial( pillarMat )
      render.DrawBeam( base, top, width * 1.6, 0, 1, Color( 255, 255, 255, 235 ) )
      render.SetMaterial( glowMat )
      render.DrawSprite( base + Vector( 0, 0, 40 ), 260, 260,
        Color( 255, 255, 255, 255 ) )
      return
    end

    -- dark silhouette pillar (canon colour 0.082/0.052/0.113 => 21/13/29)
    render.SetMaterial( pillarMat )
    render.DrawBeam( base, top, width, 0, 1, Color( 21, 13, 29, 210 ) )

    -- small lightning arcs flickering across the pillar
    render.SetMaterial( arcMat )
    for i = 1, 2 do
      local seed = math.floor( CurTime() * 12 ) * 7 + i * 131
      local rz = ( ( seed * 97 ) % 1000 ) / 1000
      local ry = ( ( seed * 61 ) % 360 )
      local h = 30 + rz * 500
      local dir = Angle( 0, ry, 0 ):Forward()
      local half = dir * ( width * 1.4 )
      local mid = base + Vector( 0, 0, h )
      render.DrawBeam( mid - half, mid + half, 26, 0, 1,
        Color( 200, 230, 255, 180 ) )
    end

    render.SetMaterial( glowMat )
    local pulse = 0.75 + 0.25 * math.sin( CurTime() * 18 )
    render.DrawSprite( base + Vector( 0, 0, 8 ), 70 * pulse, 70 * pulse,
      Color( 220, 235, 255, 130 ) )
  end
end
