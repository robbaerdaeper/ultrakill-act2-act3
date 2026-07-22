-- lua/autorun/client/ultrakill_test_idol_render.lua
if not CLIENT then return end

UKIdol = UKIdol or {}
UKIdol.Blessed = UKIdol.Blessed or {}
UKIdol.FlashState = UKIdol.FlashState or {}    -- [ent] = { [hbox] = { time, weakspot } }


hook.Add( "Think", "UKIdol_RebuildLocalRegistry", function()
  local m = {}
  for _, idol in ipairs( ents.FindByClass( "ultrakill_test_idol" ) ) do
    local t = idol:GetNW2Entity( "UKIdol_Target" )
    if IsValid( t ) then m[ t ] = idol end
  end
  UKIdol.Blessed = m
end )


function UKIdol.GetFlashState( ent, hbox )
  local s = UKIdol.FlashState[ ent ] and UKIdol.FlashState[ ent ][ hbox ]
  if not s then return 0 end
  local t = CurTime() - s.time
  if t > 0.3 then return 0 end
  return 1 - t / 0.3
end


function UKIdol.GetWeakspotFlash( ent, hbox )
  local s = UKIdol.FlashState[ ent ] and UKIdol.FlashState[ ent ][ hbox ]
  if not s or not s.weakspot then return 0 end
  local t = CurTime() - s.time
  if t > 0.6 then return 0 end
  return 1 - t / 0.6
end


net.Receive( "UKIdol_HitFlash", function()
  local ent  = net.ReadEntity()
  local hbox = net.ReadUInt( 8 )
  local weak = net.ReadBool()
  if not IsValid( ent ) then return end

  UKIdol.FlashState[ ent ] = UKIdol.FlashState[ ent ] or {}
  UKIdol.FlashState[ ent ][ hbox ] = { time = CurTime(), weakspot = weak }

  -- Sound: lower pitch on weak/extremity hit (more impactful), higher on torso (sharper)
  ent:EmitSound( "ultrakill/idol_hit.wav", 70, weak and 90 or 110, 1, CHAN_STATIC )
end )


-- Task 19: faint translucent beam idol → blessed target
local matBeam = Material( "effects/ukidol_beam" )


hook.Add( "PostDrawTranslucentRenderables", "UKIdol_Beam", function( bDepth, bSky, b3DSky )
  if bSky or b3DSky then return end

  for ent, idol in pairs( UKIdol.Blessed ) do
    if not ( IsValid( ent ) and IsValid( idol ) ) then continue end

    local from = idol:LocalToWorld( idol:OBBCenter() + Vector( 0, 0, 35 ) )
    local to   = ent:WorldSpaceCenter()

    render.SetMaterial( matBeam )
    cam.IgnoreZ( true )
    render.DrawBeam( from, to, 2.5, 0, CurTime() * 0.3, Color( 220, 240, 255, 60 ) )
    cam.IgnoreZ( false )
  end
end )


-- Canon-faithful blessed visualization: instead of a uniform model tint we
-- spawn a soft cyan glow sprite on EACH hitbox/limb position (matches
-- ULTRAKILL's EnemyIdentifier.Bless() which instantiates a `blessingGlow`
-- prefab at every EnemyIdentifierIdentifier — i.e. per body part).
--
-- Per-limb glows are sized to the limb bounds, pulsed independently, and
-- cycle through the canon cyan palette so the "patch per body part" reads
-- as separate glowing zones rather than one flat tint.
local matBlessGlow = Material( "sprites/light_glow02_add" )
local matBlessHit  = Material( "effects/ukidol_hit" )    -- canon BlessingHit sprite

local BLESS_HIT_SPIN_SPEED   = 720   -- degrees/sec (clockwise sprite spin)
local BLESS_HIT_SIZE_FACTOR  = 0.7   -- sprite size = limb size × factor

-- Canon-ish cyan palette (RGB).  Listed lightest → most saturated.
local BLESS_COLORS = {
  Color( 215, 239, 255 ),    -- #D7EFFF
  Color( 191, 239, 255 ),    -- #BFEFFF
  Color( 151, 239, 255 ),    -- #97EFFF
  Color( 183, 255, 255 ),    -- #B7FFFF
}
local BLESS_COL_COUNT = #BLESS_COLORS


-- Per-entity bless visualization. Called by status_layering coordinator (Task 14).
-- Does NOT iterate or hook itself.
function UKIdol.RenderBlessLayer( ent )
  if not IsValid( ent ) then return end
  local idol = UKIdol.Blessed[ ent ]
  if not idol then return end
  if not IsValid( idol ) then return end

  local limbs = UKIdol.GetLimbPositions( ent )
  if #limbs == 0 then return end

  local t      = CurTime()
  local eyePos = EyePos()

  -- Per-ent seed so two blessed enemies don't pulse in lockstep
  local entSeed = ( ent:EntIndex() % 23 ) * 0.37

  -- ----------------------------------------------------------------
  -- Pass 1: soft cyan glow sprite per limb (matBlessGlow)
  -- ----------------------------------------------------------------
  render.SetMaterial( matBlessGlow )
  for i, lim in ipairs( limbs ) do
    -- Color cycling: smooth lerp between adjacent palette entries, phase
    -- offset per limb so different body parts show different shades.
    local cyclePhase = t * 0.9 + entSeed + i * 0.55
    local idxF       = cyclePhase % BLESS_COL_COUNT
    local idx1       = math.floor( idxF )
    local idx2       = ( idx1 + 1 ) % BLESS_COL_COUNT
    local f          = idxF - idx1
    local c1 = BLESS_COLORS[ idx1 + 1 ]
    local c2 = BLESS_COLORS[ idx2 + 1 ]
    local r = c1.r + ( c2.r - c1.r ) * f
    local g = c1.g + ( c2.g - c1.g ) * f
    local b = c1.b + ( c2.b - c1.b ) * f

    -- Soft independent pulse per limb so glows don't synchronize
    local pulse  = 0.65 + 0.35 * math.sin( t * 2.2 + i * 1.31 + entSeed * 1.7 )
    local alpha  = math.floor( 180 * pulse )
    local glowSz = lim.size * 1.8 * ( 0.85 + 0.15 * pulse )

    render.DrawSprite( lim.pos, glowSz, glowSz, Color( r, g, b, alpha ) )
  end

  -- ----------------------------------------------------------------
  -- Pass 2: BlessingHit spinning sprite per limb (matBlessHit)
  -- Head gets an oversized sprite (canon highlights the head most prominently).
  -- ----------------------------------------------------------------
  -- Detect head = highest-Z limb (upscale sprite there for canon emphasis).
  -- Detect torso = biggest-volume hitbox (also gets upscaled — without it
  -- the chest sprite reads as tiny compared to the torso's actual size).
  local headIdx, headZ      = 1, -math.huge
  local torsoIdx, torsoVol  = 1, -math.huge
  for i, lim in ipairs( limbs ) do
    if lim.pos.z > headZ then headZ, headIdx = lim.pos.z, i end
    local mins, maxs = ent:GetHitBoxBounds( lim.hbox, ent:GetHitboxSet() )
    if mins and maxs then
      local vol = ( maxs.x - mins.x ) * ( maxs.y - mins.y ) * ( maxs.z - mins.z )
      if vol > torsoVol then torsoVol, torsoIdx = vol, i end
    end
  end

  render.SetMaterial( matBlessHit )
  for i, lim in ipairs( limbs ) do
    -- Negative angle = clockwise rotation from camera POV.
    -- Per-limb phase offset so different body parts aren't synced.
    local rotDeg = ( -t * BLESS_HIT_SPIN_SPEED + i * 47 ) % 360
    local sizeFactor
    if i == headIdx then
      sizeFactor = 1.8
    elseif i == torsoIdx then
      sizeFactor = 1.5
    else
      sizeFactor = BLESS_HIT_SIZE_FACTOR
    end
    local sz = lim.size * sizeFactor
    render.DrawQuadEasy(
      lim.pos, eyePos - lim.pos,
      sz, sz,
      Color( 220, 240, 255, 110 ),
      rotDeg
    )
  end

  -- ----------------------------------------------------------------
  -- Pass 3: Blue DynamicLight above the entity
  -- (replaces the orbiting halo spheres' worldlight contribution after
  -- they were removed). Positioned ABOVE the model so the entity's own
  -- geometry doesn't occlude the light from certain camera angles.
  -- ----------------------------------------------------------------
  local dl = DynamicLight( ent:EntIndex() + 32000 )
  if dl then
    dl.pos        = ent:LocalToWorld( Vector( 0, 0, ent:OBBMaxs().z + 25 ) )
    dl.r          = 140
    dl.g          = 200
    dl.b          = 255
    dl.brightness = 1.5
    dl.size       = 300
    dl.decay      = 0
    dl.dietime    = CurTime() + 0.2
  end
end


