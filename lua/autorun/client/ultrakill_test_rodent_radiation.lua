if SERVER then return end

local LocalPlayer = LocalPlayer
local IsValid = IsValid
local FindByClass = ents.FindByClass
local Clamp = math.Clamp
local random = math.random
local floor = math.floor
local ScrW = ScrW
local ScrH = ScrH
local DrawRect = surface.DrawRect
local SetDrawColor = surface.SetDrawColor

-- MAX = distance where intensity starts; MIN = distance where intensity = 1.
local RAD_PROFILES = {
  [ "ultrakill_test_rodent" ]      = { MAX = 280,  MIN = 50  },
  [ "ultrakill_test_rodent_big" ]  = { MAX = 550,  MIN = 120 },
}


local function ComputeIntensity()

  local ply = LocalPlayer()
  if not IsValid( ply ) or not ply:Alive() then return 0 end

  local eye = ply:EyePos()
  local maxI = 0

  for class, prof in pairs( RAD_PROFILES ) do

    local list = FindByClass( class )

    for i = 1, #list do

      local ent = list[ i ]
      if not IsValid( ent ) then continue end

      local d = eye:Distance( ent:WorldSpaceCenter() )
      if d > prof.MAX then continue end

      local t = ( prof.MAX - d ) / ( prof.MAX - prof.MIN )
      t = Clamp( t, 0, 1 )

      if t > maxI then maxI = t end

    end

  end

  return maxI

end


-- Soft radial vignette: concentric rectangle frames, dark at edges, transparent center.
local function DrawVignette( intensity )

  local sw, sh = ScrW(), ScrH()

  local BANDS = 48
  local INNER_FRAC = 0.4   -- Inner 40% of screen radius stays clear.
  local MAX_ALPHA = 200

  for i = 0, BANDS - 1 do

    -- Frame between two nested rects, normalized to screen size.
    local outerR = 1 - i / BANDS         -- 1.0 = full screen edge ring, 0.0 = center
    local innerR = 1 - ( i + 1 ) / BANDS

    if outerR < INNER_FRAC then continue end

    -- fade: 0 at INNER_FRAC, 1 at edge.
    local fade = ( outerR - INNER_FRAC ) / ( 1 - INNER_FRAC )
    fade = fade * fade   -- ease-in for smoother roll-off

    local alpha = floor( fade * MAX_ALPHA * intensity )
    if alpha <= 0 then continue end

    local outerW = outerR * sw
    local outerH = outerR * sh
    local innerW = innerR * sw
    local innerH = innerR * sh

    local ox = ( sw - outerW ) * 0.5
    local oy = ( sh - outerH ) * 0.5
    local ix = ( sw - innerW ) * 0.5
    local iy = ( sh - innerH ) * 0.5

    SetDrawColor( 5, 35, 5, alpha )

    -- 4 strips forming the frame band.
    DrawRect( ox, oy, outerW, iy - oy )                                   -- top
    DrawRect( ox, iy + innerH, outerW, ( oy + outerH ) - ( iy + innerH ) ) -- bottom
    DrawRect( ox, iy, ix - ox, innerH )                                   -- left
    DrawRect( ix + innerW, iy, ( ox + outerW ) - ( ix + innerW ), innerH ) -- right

  end

end


local function DrawTint( intensity )

  local alpha = floor( 50 * intensity )
  if alpha <= 0 then return end
  SetDrawColor( 25, 70, 25, alpha )
  DrawRect( 0, 0, ScrW(), ScrH() )

end


local function DrawScanlines( intensity )

  local sw, sh = ScrW(), ScrH()
  local alpha = floor( 70 * intensity )
  if alpha <= 0 then return end

  SetDrawColor( 0, 25, 0, alpha )

  for y = 0, sh, 4 do
    DrawRect( 0, y, sw, 1 )
  end

end


-- Tile-grid noise: every CELL×CELL block has a chance to render.
-- Caps density at MAX_COVERAGE so view is never fully obscured.
local function DrawStatic( intensity )

  local sw, sh = ScrW(), ScrH()
  local CELL = 6
  local MAX_COVERAGE = 0.55     -- at full intensity, only ~55% of cells render
  local skip_threshold = 1 - ( intensity * MAX_COVERAGE )

  for y = 0, sh, CELL do

    for x = 0, sw, CELL do

      if random() < skip_threshold then continue end

      local g = random( 40, 110 )       -- dark forest green, never toxic neon
      local r = floor( g * 0.25 )
      local b = floor( g * 0.15 )
      local a = random( 50, 110 )       -- low alpha so background stays readable

      SetDrawColor( r, g, b, a )
      DrawRect( x, y, CELL, CELL )

    end

  end

end


hook.Add( "HUDPaint", "UltrakillTestRodent_Radiation", function()

  local intensity = ComputeIntensity()
  if intensity <= 0 then return end

  DrawTint( intensity )
  DrawScanlines( intensity )
  DrawStatic( intensity )
  DrawVignette( intensity )

end )
