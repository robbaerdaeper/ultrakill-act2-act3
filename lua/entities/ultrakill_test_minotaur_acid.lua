AddCSLuaFile()

-- Minotaur acid zone (canon Goop / GoopCloud): flat DoT sphere.
-- mode "puddle" = GoopLarge floor pool (Acid Splash), mode "cloud" =
-- GoopCloud airborne sphere (Acid Bomb). Canon tick damage 3/7/15 by
-- difficulty, ~10 s lifetime, doubled on Brutal (GoopLong prefabs).
--
-- Visuals follow the canon prefabs (visual dump 2026-07-07): GoopLarge =
-- flat bright-green cylinder + rising gas particles + green point light +
-- sizzle loop; GoopCloud = translucent green sphere shells ('Water 9':
-- color 0.19 1 0, opacity ~0.2, vertex warping). Everything is drawn
-- UNLIT client-side — lit hunter-model spheres went near-black on dark
-- maps, which is why the old puddle was invisible.

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Minotaur Acid"
ENT.Spawnable = false

function ENT:SetupDataTables()
  self:NetworkVar( "Float", 0, "Radius" )
  self:NetworkVar( "Float", 1, "DieTime" )
  self:NetworkVar( "Bool", 0, "IsCloud" )
end

if SERVER then

  function ENT:Initialize()
    self:SetModel( "models/hunter/misc/sphere025x025.mdl" )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:DrawShadow( false )

    self.UKMA_NextTick = CurTime() + 0.1
  end

  -- opts: mode ("puddle"/"cloud"), radius, lifetime, tickDamage, attacker,
  -- tickInterval (default UKMinotaur.ACID_TICK_INTERVAL), immuneFlags (list of
  -- entity-field names to skip — lets other owners reuse the zone, e.g. the
  -- Mirror Reaper acid missiles)
  function ENT:UKMA_Setup( opts )
    self.UKMA_Mode = opts.mode or "puddle"
    self.UKMA_TickDamage = opts.tickDamage or 15
    self.UKMA_Attacker = opts.attacker
    self.UKMA_TickInterval = opts.tickInterval
    self.UKMA_ImmuneFlags = opts.immuneFlags
    self:SetRadius( opts.radius or ( UKMinotaur and UKMinotaur.PUDDLE_RADIUS or 48 ) )
    self:SetDieTime( CurTime() + ( opts.lifetime or 10 ) )
    self:SetIsCloud( self.UKMA_Mode == "cloud" )

    if self.UKMA_Mode == "puddle" then
      self:SetPos( self:GetPos() + Vector( 0, 0, 2 ) )
    end

    -- canon Goop prefabs carry a 'Sizzle' audio source
    self:EmitSound( "ambient/gas/steam_loop1.wav", 70, 130, 0.35 )
  end

  function ENT:OnRemove()
    self:StopSound( "ambient/gas/steam_loop1.wav" )
  end

  function ENT:Think()
    local now = CurTime()
    if now >= self:GetDieTime() then
      self:Remove()
      return
    end

    if now >= ( self.UKMA_NextTick or 0 ) then
      self.UKMA_NextTick = now + ( self.UKMA_TickInterval or UKMinotaur.ACID_TICK_INTERVAL or 0.5 )
      local center = self:UKMA_Center()
      local r = self:GetRadius()
      for _, ent in ipairs( ents.FindInSphere( center, r ) ) do
        if not IsValid( ent ) then continue end
        if not ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then continue end
        if ent.UKMinotaur_IsMinotaur then continue end
        if self.UKMA_ImmuneFlags then
          local immune = false
          for _, flag in ipairs( self.UKMA_ImmuneFlags ) do
            if ent[ flag ] then immune = true break end
          end
          if immune then continue end
        end
        -- puddle only bites entities near the floor plane
        if self.UKMA_Mode == "puddle"
            and ent:GetPos().z > self:GetPos().z + 48 then continue end

        local dmg = DamageInfo()
        dmg:SetDamage( UKMinotaur.ScaleAttackDamage( ent, self.UKMA_TickDamage, self.UKMA_Attacker ) )
        dmg:SetDamageType( DMG_ACID )
        local att = IsValid( self.UKMA_Attacker ) and self.UKMA_Attacker or self
        dmg:SetAttacker( att )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( ent:WorldSpaceCenter() )
        ent:TakeDamageInfo( dmg )
      end
    end

    self:NextThink( now + 0.1 )
    return true
  end

  function ENT:UKMA_Center()
    if self.UKMA_Mode == "puddle" then
      return self:GetPos() + Vector( 0, 0, 24 )
    end
    return self:GetPos()
  end

end

if CLIENT then

  -- alpha-blended geometry must live in the translucent pass, or the sort
  -- order against the world is undefined (can vanish entirely on some maps)
  ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

  local MAT_ACID = CreateMaterial( "UKMinotaurAcidFlat", "UnlitGeneric", {
    [ "$basetexture" ] = "vgui/white",
    [ "$vertexcolor" ] = 1,
    [ "$vertexalpha" ] = 1,
    [ "$translucent" ] = 1,
    [ "$nocull" ] = 1,
  } )

  local COL = UKMinotaur and UKMinotaur.ACID_COLOR or Color( 49, 255, 0 )

  function ENT:UKMA_GetWobble()
    -- lazy: Draw can outrun Initialize on full updates / lua refresh
    if not self.UKMA_Wobble then
      self.UKMA_Wobble = {}
      for i = 0, 40 do
        self.UKMA_Wobble[ i ] = 0.82 + 0.18 * math.abs( math.sin( i * 2.39 + self:EntIndex() * 0.7 ) )
      end
    end
    return self.UKMA_Wobble
  end

  function ENT:Initialize()
    self.UKMA_Emitter = ParticleEmitter( self:GetPos() )
    self.UKMA_NextPuff = 0
    self:UKMA_GetWobble()
  end

  function ENT:OnRemove()
    if self.UKMA_Emitter then
      self.UKMA_Emitter:Finish()
      self.UKMA_Emitter = nil
    end
  end

  function ENT:UKMA_Fade()
    -- fade out over the last second
    return math.Clamp( self:GetDieTime() - CurTime(), 0, 1 )
  end

  ------------------------------------------------------------------------------
  -- Puddle: flat blob disc hugging the floor (canon GoopLarge cylinder)
  ------------------------------------------------------------------------------

  function ENT:UKMA_DrawPuddle( fade )
    local pos = self:GetPos() + Vector( 0, 0, 1.5 )
    local r = self:GetRadius()
    local seg = 28
    local wob = self:UKMA_GetWobble()
    local t = CurTime()

    local coreA = 235 * fade
    local rimA = 160 * fade

    render.SetMaterial( MAT_ACID )
    mesh.Begin( MATERIAL_TRIANGLES, seg * 3 )
    for i = 0, seg - 1 do
      local a0 = ( i / seg ) * math.pi * 2
      local a1 = ( ( i + 1 ) / seg ) * math.pi * 2
      local w0 = wob[ i % 40 ] + 0.03 * math.sin( t * 1.7 + i )
      local w1 = wob[ ( i + 1 ) % 40 ] + 0.03 * math.sin( t * 1.7 + i + 1 )
      local p0i = pos + Vector( math.cos( a0 ), math.sin( a0 ), 0 ) * ( r * 0.55 )
      local p1i = pos + Vector( math.cos( a1 ), math.sin( a1 ), 0 ) * ( r * 0.55 )
      local p0o = pos + Vector( math.cos( a0 ), math.sin( a0 ), 0 ) * ( r * w0 )
      local p1o = pos + Vector( math.cos( a1 ), math.sin( a1 ), 0 ) * ( r * w1 )

      -- inner fan (solid core)
      mesh.Position( pos ) mesh.Color( 120, 255, 40, coreA ) mesh.AdvanceVertex()
      mesh.Position( p0i ) mesh.Color( COL.r, COL.g, COL.b, coreA ) mesh.AdvanceVertex()
      mesh.Position( p1i ) mesh.Color( COL.r, COL.g, COL.b, coreA ) mesh.AdvanceVertex()

      -- rim quad (fades to the blobby edge)
      mesh.Position( p0i ) mesh.Color( COL.r, COL.g, COL.b, coreA ) mesh.AdvanceVertex()
      mesh.Position( p0o ) mesh.Color( COL.r, COL.g, COL.b, rimA * 0.35 ) mesh.AdvanceVertex()
      mesh.Position( p1o ) mesh.Color( COL.r, COL.g, COL.b, rimA * 0.35 ) mesh.AdvanceVertex()

      mesh.Position( p0i ) mesh.Color( COL.r, COL.g, COL.b, coreA ) mesh.AdvanceVertex()
      mesh.Position( p1o ) mesh.Color( COL.r, COL.g, COL.b, rimA * 0.35 ) mesh.AdvanceVertex()
      mesh.Position( p1i ) mesh.Color( COL.r, COL.g, COL.b, coreA ) mesh.AdvanceVertex()
    end
    mesh.End()
  end

  ------------------------------------------------------------------------------
  -- Cloud: two translucent sphere shells with vertex warping (canon Water 9)
  ------------------------------------------------------------------------------

  local function DrawSphereShell( origin, radius, alpha, t, seed )
    local stacks, slices = 9, 16
    render.SetMaterial( MAT_ACID )
    mesh.Begin( MATERIAL_TRIANGLES, stacks * slices * 2 )
    local pts = {}
    for st = 0, stacks do
      pts[ st ] = {}
      local phi = ( st / stacks ) * math.pi
      for sl = 0, slices do
        local theta = ( sl / slices ) * math.pi * 2
        local warp = 1 + 0.06 * math.sin( t * 2 + seed + st * 1.1 + sl * 0.7 )
        local rr = radius * warp
        pts[ st ][ sl ] = origin + Vector(
          math.sin( phi ) * math.cos( theta ) * rr,
          math.sin( phi ) * math.sin( theta ) * rr,
          math.cos( phi ) * rr )
      end
    end
    for st = 0, stacks - 1 do
      for sl = 0, slices - 1 do
        local a, b = pts[ st ][ sl ], pts[ st ][ sl + 1 ]
        local c, d = pts[ st + 1 ][ sl ], pts[ st + 1 ][ sl + 1 ]
        mesh.Position( a ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
        mesh.Position( b ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
        mesh.Position( c ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
        mesh.Position( b ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
        mesh.Position( d ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
        mesh.Position( c ) mesh.Color( COL.r, COL.g, COL.b, alpha ) mesh.AdvanceVertex()
      end
    end
    mesh.End()
  end

  function ENT:Draw()
    local fade = self:UKMA_Fade()
    if fade <= 0 then return end
    local r = self:GetRadius()
    self:SetRenderBounds( Vector( -r, -r, -r ), Vector( r, r, r * 1.5 ) )

    if self:GetIsCloud() then
      local t = CurTime()
      local seed = self:EntIndex() * 1.3
      DrawSphereShell( self:GetPos(), r * 0.68, 110 * fade, t, seed )
      DrawSphereShell( self:GetPos(), r, 55 * fade, t, seed + 2.1 )
    else
      self:UKMA_DrawPuddle( fade )
    end
  end

  -- RENDERGROUP_TRANSLUCENT entities render through DrawTranslucent
  ENT.DrawTranslucent = ENT.Draw

  function ENT:Think()
    -- the model is a 12 su sphere: without widened bounds the whole zone
    -- gets culled long before Draw ever runs
    local r = math.max( self:GetRadius(), 32 )
    self:SetRenderBounds( Vector( -r, -r, -r ), Vector( r, r, r * 1.5 ) )

    -- green glow (canon Goop point light)
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = self:GetPos() + Vector( 0, 0, self:GetIsCloud() and 0 or 16 )
      dl.r, dl.g, dl.b = 60, 255, 30
      dl.brightness = 1.6 * self:UKMA_Fade()
      dl.decay = 1000
      dl.size = r * 2.2
      dl.dietime = CurTime() + 0.15
    end

    if not self.UKMA_Emitter then return end
    if CurTime() < ( self.UKMA_NextPuff or 0 ) then return end
    self.UKMA_NextPuff = CurTime() + 0.1

    local cloud = self:GetIsCloud()
    local origin = self:GetPos()
    -- rising acid gas (canon GasParticle), soft green puffs
    for _ = 1, 3 do
      local off = VectorRand()
      off.z = cloud and off.z * 0.8 or 0
      local p = self.UKMA_Emitter:Add( "particle/particle_smokegrenade",
        origin + off * r * ( cloud and 0.7 or 0.8 ) + Vector( 0, 0, cloud and 0 or 4 ) )
      if p then
        p:SetVelocity( Vector( math.Rand( -6, 6 ), math.Rand( -6, 6 ), math.Rand( 14, 34 ) ) )
        p:SetDieTime( math.Rand( 0.7, 1.4 ) )
        p:SetStartAlpha( 70 * self:UKMA_Fade() )
        p:SetEndAlpha( 0 )
        p:SetStartSize( math.Rand( 6, 12 ) )
        p:SetEndSize( math.Rand( 18, 30 ) )
        p:SetColor( 70, 220, 30 )
        p:SetLighting( false )
      end
    end
    -- occasional bright bubble
    if math.random( 3 ) == 1 then
      local off = VectorRand()
      off.z = cloud and off.z * 0.6 or 0
      local p = self.UKMA_Emitter:Add( "sprites/light_glow02_add",
        origin + off * r * 0.6 + Vector( 0, 0, cloud and 0 or 3 ) )
      if p then
        p:SetVelocity( Vector( 0, 0, math.Rand( 20, 45 ) ) )
        p:SetDieTime( math.Rand( 0.4, 0.8 ) )
        p:SetStartAlpha( 160 * self:UKMA_Fade() )
        p:SetEndAlpha( 0 )
        p:SetStartSize( math.Rand( 2, 5 ) )
        p:SetEndSize( 1 )
        p:SetColor( 130, 255, 60 )
      end
    end
  end

end
