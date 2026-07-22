-- Hookpoint (canon GrapplePoint, Violence-layer whiplash anchor).
--
-- Canon (HookPoint.cs + GrapplePoint prefabs, gameprefabs bundle):
--   green  (type Normal):    pull player, on reach reset momentum + gentle
--                            up-push (canon 15 m/s vs pull 60 m/s = 1:4);
--   blue   (type Slingshot): on reach keep momentum (prefab slingShotForce=0
--                            -> velocity untouched), player flies through;
--   pink   (Providence drop, Slingshot + healPlayer): blue behaviour +
--                            explosion (canon Explosion dmg 50, wiki 10 -> UK
--                            scale 100) that hurts ONLY enemies + full heal.
-- Orb = Sphere004 x5, translucent shell, two ProBuilder arches, blue/pink add
-- a pyramid (apex up / apex down). Spin speeds 100 deg/s idle, 450 hooked
-- (canon Hooked()). Unhookable when the player is closer than 5 m (200 u).
-- Whiplash catch assist: canon SphereCastAll radius min(dist/15, 5 m).
--
-- Integration: ukarms REVAMPED (workshop 3733243381) uk_whiplash entity. We
-- are SOLID_NONE (canon "no collision except the whiplash spear"), so the
-- whiplash never trace-captures us; instead our Think snaps flying whiplashes
-- onto us (aim assist) and installs a per-instance StopReel override (the
-- OnKilled instance-stub pattern) for the canon per-type reach outcome.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Hookpoint"
ENT.Author = "ultragmod"
ENT.Category = "ULTRAKILL"
ENT.Spawnable = true

ENT.Variant = 0  -- 0 green / 1 blue / 2 pink

local MODEL = "models/ultrakill_prelude_test/hookpoint.mdl"
local SND = "ultrakill_prelude_test/hookpoint/"

local CORE_R = 45           -- core sphere radius (0.2236 m * 5 * 40)
local SCALE = 0.5           -- overall size trim (make hookpoints smaller)
local UNHOOKABLE = 200      -- canon 5 m
local ASSIST_MAX = 200      -- canon SphereCast radius cap 5 m
-- green reach boost = base whiplash StopReel (350 up ~= canon 15 m/s)
local EXPLOSION_RADIUS = 300
local EXPLOSION_DMG = 100   -- wiki 10 x10 (UKBase damage scale)

-- canon material / light colours per variant
local VARIANTS = {
  [0] = {
    name = "Hookpoint (Green)",
    yaw = 90,                              -- was showing side-on; face the viewer
    light = Color( 125, 255, 0 ),          -- Light (0.49,1,0)
    glow = Color( 64, 191, 0, 128 ),       -- Square sprite (0.25,0.75,0,0.5)
    ring1 = { axis = Vector( 0, 0, 1 ) },  -- unity (0,-1,0)
    ring2 = { axis = Vector( 0, 0, -1 ) }, -- unity (0,1,0)
  },
  [1] = {
    name = "Hookpoint (Blue)",
    light = Color( 0, 135, 255 ),          -- Light (0,0.53,1)
    glow = Color( 0, 121, 191, 128 ),      -- Square (0,0.47,0.75,0.5)
    ring1 = { axis = Vector( 0, -1, 0 ) }, -- unity (0,0,-1)
    ring2 = { axis = Vector( 0, 1, 0 ) },  -- unity (0,0,1)
  },
  [2] = {
    name = "Hookpoint (Pink)",
    light = Color( 255, 196, 252 ),        -- Light (1,0.77,0.99)
    glow = Color( 207, 91, 162, 128 ),     -- Square (0.81,0.36,0.63,0.5)
    -- unity local rot (-0.354,+-0.354,+-0.146,0.854) -> model quat (see port
    -- notes: mirror_X component rule + Rx90 basis conjugation)
    ring1 = { axis = Vector( 0.7071, 0, 0.7071 ),  -- unity (1,-1,0)
              pre = { -0.354, 0.146, -0.354, 0.854 } },
    ring2 = { axis = Vector( 0.7071, 0, -0.7071 ), -- unity (1,1,0)
              pre = { -0.354, -0.146, 0.354, 0.854 } },
  },
}
-- core spin: unity (0.1,0.25,0) normalized -> model space
local CORE_AXIS = Vector( 0.371, 0, -0.928 )
local SHELL_AXIS = Vector( 0, 1, 0 )  -- unity (0,0,1)

-- translucent shell + sprites: single translucent pass (DrawTranslucent
-- draws the model; BOTH would draw it twice)
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:VariantData()
  return VARIANTS[ self.Variant ] or VARIANTS[ 0 ]
end

function ENT:SetupDataTables()
  self:NetworkVar( "Bool", 0, "UKHooked" )
  self:NetworkVar( "Int", 0, "UKReachFX" ) -- bumps on every reach (client flash)
end

--------------------------------------------------------------------------
if SERVER then

  function ENT:Initialize()
    self:SetModel( MODEL )
    self:SetSkin( self.Variant )
    local bg = self:FindBodygroupByName( "pyramid" )
    if bg >= 0 then self:SetBodygroup( bg, self.Variant > 0 and 1 or 0 ) end
    self:SetModelScale( SCALE )

    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_NONE )
    self:SetCollisionBounds( Vector( -CORE_R, -CORE_R, -CORE_R ),
                             Vector( CORE_R, CORE_R, CORE_R ) )
    -- whiplash requires Health() > 0 to keep holding on (uk_whiplash Think)
    self:SetMaxHealth( 1 )
    self:SetHealth( 1 )
    self:NextThink( CurTime() )
  end

  -- float in the air in front of the spawner instead of sitting on the ground
  function ENT:SpawnFunction( ply, tr, class )
    if not tr.Hit then return end
    local ent = ents.Create( class )
    ent:SetPos( tr.HitPos + tr.HitNormal * 120 )
    ent:Spawn()
    ent:Activate()
    return ent
  end

  -- canon: hookpoints are indestructible level objects
  function ENT:OnTakeDamage() end

  ------------------------------------------------------------------------
  -- whiplash integration
  ------------------------------------------------------------------------

  -- canon HookPoint.Hooked()/Unhooked()
  function ENT:SetHookedState( hooked )
    if self:GetUKHooked() == hooked then return end
    self:SetUKHooked( hooked )
  end

  -- per-type reach outcome (canon HookArm.FixedUpdate reach block +
  -- HookPoint.Reached). Runs after the base StopReel cleanup.
  function ENT:OnReelEnd( wl )
    local owner = IsValid( wl ) and wl:GetOwner() or nil
    self:SetUKReachFX( self:GetUKReachFX() + 1 )
    self:SetHookedState( false )
    self.HookedWL = nil

    if self.Variant == 0 then
      -- green: base StopReel already did the canon thing (momentum reset +
      -- up boost when airborne) because we kept AttachedEnt valid.
      return
    end

    -- blue/pink: momentum preserved (we cleared AttachedEnt before the base
    -- StopReel so it never touched the player's velocity). World-played so the
    -- sound survives the pink point's removal below.
    local pos = self:WorldSpaceCenter()
    sound.Play( SND .. "slingshot.wav", pos, 90, math.random( 98, 102 ), 0.7 )

    if self.Variant == 2 then
      -- pink: canon one-shot Providence drop — explode in place (enemies
      -- only), heal the player to 100, then the point is CONSUMED
      if UltrakillBase and UltrakillBase.SoundScript then
        UltrakillBase.SoundScript( "Ultrakill_Explosion_1", pos )
      end
      local ed = EffectData()
      ed:SetOrigin( pos )
      ed:SetRadius( EXPLOSION_RADIUS )
      util.Effect( "Ultrakill_Explosion", ed, true, true )
      util.ScreenShake( pos, 6, 20, 0.6, 800 )

      for _, e in ipairs( ents.FindInSphere( pos, EXPLOSION_RADIUS ) ) do
        if not IsValid( e ) or e == self then continue end
        if not ( e:IsNPC() or e:IsNextBot() ) then continue end
        local dmg = DamageInfo()
        dmg:SetDamage( EXPLOSION_DMG )
        dmg:SetDamageType( DMG_BLAST )
        dmg:SetAttacker( IsValid( owner ) and owner or self )
        dmg:SetInflictor( self )
        dmg:SetDamagePosition( pos )
        dmg:SetDamageForce( ( e:WorldSpaceCenter() - pos ):GetNormalized() * 6000 )
        e:TakeDamageInfo( dmg )
      end

      if IsValid( owner ) and owner:IsPlayer() and owner:Alive() then
        owner:SetHealth( math.max( owner:Health(),
          math.max( owner:GetMaxHealth(), 100 ) ) )
      end

      self:SetNoDraw( true )
      SafeRemoveEntityDelayed( self, 0.1 )
    end
  end

  -- attach a flying whiplash to us (canon layer-22 catch in HookArm)
  function ENT:SnapWhiplash( wl )
    local hp = self
    wl:SetPos( self:WorldSpaceCenter() )
    wl.AttachedEnt = self
    wl.ReelBackTime = CurTime()
    wl.FullReelBackTime = CurTime()
    wl:StopSound( "vmanip/feedbacker/whiplashFlying.wav" )
    wl:EmitSound( SND .. "grab.wav", 90, math.random( 95, 105 ), 1 )

    -- instance StopReel stub: suppress the base momentum reset for
    -- slingshot types, then run the canon per-type outcome
    local orig = wl.StopReel
    wl.StopReel = function( s )
      local wasUs = ( s.AttachedEnt == hp )
      if wasUs and IsValid( hp ) and hp.Variant ~= 0 then
        s.AttachedEnt = nil
      end
      orig( s )
      if wasUs and IsValid( hp ) then hp:OnReelEnd( s ) end
    end

    self.HookedWL = wl
    self:SetHookedState( true )
  end

  function ENT:Think()
    -- lost the whiplash without a reach (wall block / manual release /
    -- owner death) -> canon Unhooked()
    if self:GetUKHooked() then
      local wl = self.HookedWL
      if not IsValid( wl ) or wl.AttachedEnt ~= self or wl:GetReturning() then
        self:SetHookedState( false )
        self.HookedWL = nil
      end
    end

    -- aim assist: catch flying whiplashes aimed at us
    if not self:GetUKHooked() then
      local center = self:WorldSpaceCenter()
      for _, wl in ipairs( ents.FindByClass( "uk_whiplash" ) ) do
        if not IsValid( wl ) or wl.AttachedEnt or wl.Collided then continue end
        if wl.GetReturning and wl:GetReturning() then continue end
        local owner = wl:GetOwner()
        if not IsValid( owner ) or not owner:IsPlayer() then continue end
        -- canon: unhookable when the arm is closer than 5 m
        if owner:WorldSpaceCenter():Distance( center ) < UNHOOKABLE then continue end

        local wpos = wl:GetPos()
        local toUs = center - wpos
        local dist = toUs:Length()
        local phys = wl:GetPhysicsObject()
        local vel = IsValid( phys ) and phys:GetVelocity() or wl:GetVelocity()
        if vel:LengthSqr() < 1 then continue end
        local vdir = vel:GetNormalized()
        if toUs:Dot( vdir ) <= 0 then continue end  -- flying away

        -- canon assist radius: min(dist(arm, hook tip)/15, 5 m)
        local assist = math.min( owner:WorldSpaceCenter():Distance( wpos ) / 15
                                 + CORE_R, ASSIST_MAX )
        local perp = ( toUs - vdir * toUs:Dot( vdir ) ):Length()
        if perp > assist then continue end
        if dist > 900 then continue end  -- snap only near the pass-by segment

        -- canon: closer targets win the SphereCast — if the whiplash would hit
        -- a wall or a live target on its own before reaching us, leave it alone
        local tr = util.TraceHull( {
          start = wpos,
          endpos = wpos + vdir * math.max( toUs:Dot( vdir ) - CORE_R, 0 ),
          mins = Vector( -16, -16, -16 ),
          maxs = Vector( 16, 16, 16 ),
          filter = { wl, owner },
          mask = MASK_SHOT_HULL,
        } )
        if tr.Hit and ( tr.HitWorld
            or ( IsValid( tr.Entity ) and tr.Entity:Health() > 0 ) ) then
          continue
        end

        self:SnapWhiplash( wl )
        break
      end
    end

    self:NextThink( CurTime() )
    return true
  end

end

--------------------------------------------------------------------------
if CLIENT then

  -- round, soft additive halo (replaces the hard square hp_glow sprite)
  local MAT_GLOW = Material( "sprites/light_glow02_add" )

  -- quaternion helpers (bones need arbitrary-axis spin + static pre-rotation)
  local function QMul( a, b )
    local ax, ay, az, aw = a[ 1 ], a[ 2 ], a[ 3 ], a[ 4 ]
    local bx, by, bz, bw = b[ 1 ], b[ 2 ], b[ 3 ], b[ 4 ]
    return {
      aw * bx + ax * bw + ay * bz - az * by,
      aw * by - ax * bz + ay * bw + az * bx,
      aw * bz + ax * by - ay * bx + az * bw,
      aw * bw - ax * bx - ay * by - az * bz,
    }
  end

  local function QAxisAngle( axis, deg )
    local h = math.rad( deg ) * 0.5
    local s = math.sin( h )
    return { axis.x * s, axis.y * s, axis.z * s, math.cos( h ) }
  end

  local function QToAngle( q )
    local x, y, z, w = q[ 1 ], q[ 2 ], q[ 3 ], q[ 4 ]
    local fwd = Vector( 1 - 2 * ( y * y + z * z ), 2 * ( x * y + z * w ), 2 * ( x * z - y * w ) )
    local up = Vector( 2 * ( x * z + y * w ), 2 * ( y * z - x * w ), 1 - 2 * ( x * x + y * y ) )
    return fwd:AngleEx( up )
  end

  local QFLIP = QAxisAngle( Vector( 1, 0, 0 ), 180 )  -- pink pyramid apex down

  function ENT:Initialize()
    self.SpinPhase = math.Rand( 0, 360 )
    self.ShellScale = 1
    self.CoreScale = 1
    self.FlashT = -1
    self.LastReachFX = self:GetUKReachFX()
    self.WasHooked = false
    -- the idle sequence is skeleton-only => engine bbox is degenerate; without
    -- explicit render bounds the model culls whenever the origin leaves view
    self:SetRenderBounds( Vector( -260, -260, -260 ), Vector( 260, 260, 260 ) )
    self:SetNextClientThink( CurTime() )
  end

  function ENT:OnRemove()
    if self.HumSnd then self.HumSnd:Stop() self.HumSnd = nil end
  end

  local BONES = { "hp_core", "hp_ring1", "hp_ring2", "hp_shell", "hp_pyr" }

  function ENT:LookupBones()
    self.Bones = {}
    for _, b in ipairs( BONES ) do
      local id = self:LookupBone( b )
      if not id then return false end
      self.Bones[ b ] = id
    end
    return true
  end

  function ENT:Think()
    -- client Think runs per tick, not per frame — derive dt from CurTime()
    local now = CurTime()
    local dt = now - ( self.LastThink or now )
    self.LastThink = now
    local v = self:VariantData()

    if not self.Bones and not self:LookupBones() then
      self.Bones = nil
      self:SetNextClientThink( CurTime() )
      return true
    end

    -- hum loop (canon AudioSource vol 0.35, base pitch baked into the wav;
    -- canon Update: far 1.0x, closer than 5 m 0.5x, hooked 1.5x)
    if not self.HumSnd then
      self.HumSnd = CreateSound( self, SND .. "hum.wav" )
      self.HumSnd:PlayEx( 0.35, 100 )
    end

    local ply = LocalPlayer()
    local center = self:WorldSpaceCenter()
    local plyDist = IsValid( ply ) and ply:EyePos():Distance( center ) or 10000
    local hooked = self:GetUKHooked()
    local close = plyDist < UNHOOKABLE and not hooked

    if self.HumSnd then
      local pitch = hooked and 150 or ( close and 50 or 100 )
      self.HumSnd:ChangePitch( pitch, 0.15 )
    end

    -- grab/reach flash triggers
    if hooked and not self.WasHooked then self.FlashT = CurTime() end
    self.WasHooked = hooked
    local fx = self:GetUKReachFX()
    if fx ~= self.LastReachFX then
      self.LastReachFX = fx
      self.FlashT = CurTime()
    end

    -- billboard: model -Y (canon unity +Z, AlwaysLookAtCamera) at the viewer
    if IsValid( ply ) then
      local dir = ( ply:EyePos() - self:GetPos() ):GetNormalized()
      local ang = dir:Angle()
      ang:RotateAroundAxis( ang:Up(), 90 + ( v.yaw or 0 ) )
      self:SetRenderAngles( ang )
    end

    -- spins: canon Spin 100 deg/s idle, 450 while hooked
    local speed = hooked and 450 or 100
    self.SpinPhase = ( self.SpinPhase + speed * dt ) % 360
    local ph = self.SpinPhase

    local b = self.Bones
    self:ManipulateBoneAngles( b.hp_core, QToAngle( QAxisAngle( CORE_AXIS, ph ) ) )
    self:ManipulateBoneAngles( b.hp_shell, QToAngle( QAxisAngle( SHELL_AXIS, ph ) ) )

    for i, ring in ipairs( { v.ring1, v.ring2 } ) do
      local q = QAxisAngle( ring.axis, ph )
      if ring.pre then q = QMul( ring.pre, q ) end
      self:ManipulateBoneAngles( b[ i == 1 and "hp_ring1" or "hp_ring2" ], QToAngle( q ) )
    end

    if self.Variant > 0 then
      local q = QAxisAngle( SHELL_AXIS, ph )
      if self.Variant == 2 then q = QMul( QFLIP, q ) end
      self:ManipulateBoneAngles( b.hp_pyr, QToAngle( q ) )
    end

    -- canon orb scale states (Update: MoveTowards 50/s on 0..5 => 10/s here)
    local shellTarget = hooked and 0 or ( close and 0.5 or 1 )
    local coreTarget = close and 0 or 1
    self.ShellScale = math.Approach( self.ShellScale, shellTarget, 10 * dt )
    self.CoreScale = math.Approach( self.CoreScale, coreTarget, 10 * dt )
    local ss = math.max( self.ShellScale, 0.001 )
    local cs = math.max( self.CoreScale, 0.001 )
    self:ManipulateBoneScale( b.hp_shell, Vector( ss, ss, ss ) )
    self:ManipulateBoneScale( b.hp_core, Vector( cs, cs, cs ) )

    -- canon Light range 10 m, 20 m while hooked
    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = center
      dl.r, dl.g, dl.b = v.light.r, v.light.g, v.light.b
      dl.brightness = 2
      dl.decay = 1000
      dl.size = hooked and 800 or 400
      dl.dietime = CurTime() + 0.2
    end

    self:SetNextClientThink( CurTime() )
    return true
  end

  function ENT:DrawTranslucent()
    self:DrawModel()
    local v = self:VariantData()
    local center = self:WorldSpaceCenter()

    render.SetMaterial( MAT_GLOW )
    -- soft round halo (canon Square sprite), sized with the model trim
    local base = 190 * SCALE
    render.DrawSprite( center, base, base,
      Color( v.glow.r, v.glow.g, v.glow.b, v.glow.a ) )

    -- grab/reach flash (canon HookPointGrab: ScaleNFade sprite burst)
    if self.FlashT and self.FlashT > 0 then
      local t = ( CurTime() - self.FlashT ) / 0.25
      if t < 1 then
        local size = ( 190 + 320 * t ) * SCALE
        render.DrawSprite( center, size, size,
          Color( v.light.r, v.light.g, v.light.b, 200 * ( 1 - t ) ) )
      end
    end
  end

end

--------------------------------------------------------------------------
-- proper display name for the spawn menu (green base class)
ENT.PrintName = VARIANTS[ 0 ].name
