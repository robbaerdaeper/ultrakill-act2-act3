-- lua/autorun/client/ultrakill_mdk_hud.lua
-- 1) Цветные сабтитры: замена HUDPaint-хука UltrakillBase_Subtitles на
--    расширенную копию, понимающую префикс "<#RRGGBB>" в строке (канонные
--    цвета MDK: рыцарь #FFC49E, сова #9EE6FF). Строки без префикса рендерятся
--    в точности как в базе (белым).
-- 2) Уникальный босс-бар MDK: канонные цвета слоёв из BossBarManager.layers
--    (полный -> пустой): тёмно-фиолетовый (63,0,62) -> маджента (219,0,163) ->
--    бордовый (70,13,0) -> стандартный красный (255,0,0). Рисуется в стиле
--    базового бара и стакается ПОСЛЕ баров UltrakillBase.BossTable (у базы
--    цвета захардкожены, поэтому свой рендер).

if SERVER then return end

-- =========================================================================
-- Сабтитры с цветом
-- =========================================================================

local HoldTimePerChar = 0.11
local FadeInPerChar = 0.0025
local FadeOutPerChar = 0.005
local BaseFadeIn = 0.2
local BaseHoldTime = 1.5
local BaseFadeOut = 2
local SubtitlesPerRender = 12
local SubtitleBGColor = Color( 0, 0, 0, 130 )

local ColorCache = {}

-- "<#RRGGBB>Текст" -> Color, "Текст"; без префикса -> белый.
local function ParseSubtitle( s )
  local hex, rest = string.match( s, "^<#(%x%x%x%x%x%x)>(.*)" )
  if not hex then return nil, s end
  local clr = ColorCache[ hex ]
  if not clr then
    clr = Color( tonumber( hex:sub( 1, 2 ), 16 ),
                 tonumber( hex:sub( 3, 4 ), 16 ),
                 tonumber( hex:sub( 5, 6 ), 16 ) )
    ColorCache[ hex ] = clr
  end
  return clr, rest
end

local function LerpOutCubic( x, from, to ) return Lerp( math.ease.OutCubic( x ), from, to ) end
local function LerpInCubic( x, from, to ) return Lerp( math.ease.InCubic( x ), from, to ) end

local function RenderSubtitle( i, text, clr, alpha )
  surface.SetFont( "Ultrakill_SubFont" )
  local w = surface.GetTextSize( text )

  local posX = ScrW() * 0.5
  local posY = ScrH() * 0.860215054 - ( i - 1 ) * ScrH() * 0.0714285714
  local scaleW = w / #text * 1.5 + w * 1.05
  local scaleH = ScrH() * 0.0625 * 0.925

  SubtitleBGColor.a = 130 * alpha
  draw.RoundedBox( 8, posX - scaleW * 0.5, posY - scaleH * 0.881057269, scaleW, scaleH, SubtitleBGColor )

  surface.SetTextPos( posX - w * 0.5, posY - scaleH * 0.606060606 )
  surface.SetTextColor( clr.r, clr.g, clr.b, 255 * alpha )
  surface.DrawText( text )
end

local WHITE = Color( 255, 255, 255 )

local function InstallSubtitleHook()
  if not UltrakillBase or not UltrakillBase.SubtitlesTable then return false end
  local Subtitles = UltrakillBase.SubtitlesTable
  local cv = GetConVar( "drg_ultrakill_subtitles" )

  hook.Add( "HUDPaint", "UltrakillBase_Subtitles", function()
    if cv and not cv:GetBool() then return end

    for i = 1, #Subtitles do
      local info = Subtitles[ i ]
      if not info then continue end

      local clr, text = ParseSubtitle( info.String )
      local lifeTime = info.LifeTime
      local holdTime = info.HoldTime or BaseHoldTime + #text * HoldTimePerChar
      local fadeIn = BaseFadeIn + #text * FadeInPerChar
      local fadeOut = BaseFadeOut + #text * FadeOutPerChar

      if CurTime() > lifeTime + fadeIn + holdTime + fadeOut then
        table.remove( Subtitles, i )
        continue
      end
      if i > SubtitlesPerRender then continue end

      local fadeInDelta = ( CurTime() - lifeTime ) / fadeIn
      local fadeOutDelta = ( CurTime() - ( lifeTime + holdTime + fadeIn ) ) / fadeOut
      local alpha = LerpOutCubic( fadeOutDelta, 1, 0 ) * LerpInCubic( fadeInDelta, 0, 1 )

      RenderSubtitle( i, text, clr or WHITE, alpha )
    end
  end )
  return true
end

-- =========================================================================
-- Босс-бар MDK
-- =========================================================================

-- canon BossBarManager.layers, слои от полного к пустому
local LAYER_COLORS = {
  Color( 63, 0, 62 ),     -- тёмно-фиолетовый (4/4 HP)
  Color( 219, 0, 163 ),   -- маджента (hot pink)
  Color( 70, 13, 0 ),     -- бордовый
  Color( 255, 0, 0 ),     -- стандартный красный
}
local LOST_COLOR = Color( 255, 157, 0 )       -- canon afterImageColor
local BG_COLOR = Color( 0, 0, 0, 99 )
local BAR_BG_COLOR = Color( 0, 0, 0, 170 )
local TITLE = "MYSTERIOUS DRUID KNIGHT (& OWL)"
local SPLITS = 4

local MDKBars = {}       -- ent -> { CurHP, LostHP }
local MDKList = {}
local NextScan = 0

local function ScanMDK()
  MDKList = ents.FindByClass( "ultrakill_test_mdk" )
  for ent in pairs( MDKBars ) do
    if not IsValid( ent ) then MDKBars[ ent ] = nil end
  end
end

local function CountBaseBars()
  local t = UltrakillBase and UltrakillBase.BossTable
  if not t then return 0 end
  local n = 0
  for _, e in ipairs( t ) do
    if IsValid( e ) then n = n + 1 end
  end
  return n
end

local function DrawMDKBar( ent, slot )
  local hp = math.max( ent:Health(), 0 )
  local maxHP = math.max( ent:GetMaxHealth(), 1 )

  local st = MDKBars[ ent ]
  if not st then
    st = { CurHP = hp, LostHP = hp }
    MDKBars[ ent ] = st
  end
  local ft = FrameTime()
  -- быстрый лерп основной полоски, медленный — оранжевого следа (стиль базы)
  st.CurHP = math.Approach( st.CurHP, hp, math.max( maxHP * 4 * ft, math.abs( st.CurHP - hp ) * 12 * ft ) )
  st.LostHP = math.Approach( st.LostHP, hp, maxHP * 0.6 * ft )
  if st.LostHP < st.CurHP then st.LostHP = st.CurHP end

  local shakeAmp = math.Clamp( ( st.LostHP - hp ) / ( maxHP * 0.05 ), 0, 8 )

  -- общий канонный масштаб стека (>2 баров -> сжатие к верху экрана),
  -- геометрия из ultrakill_bossbar_stack.lua — та же, что у баров базы
  local geo = UKBossBarStack and UKBossBarStack.GetGeometry and UKBossBarStack.GetGeometry() or nil
  local scale = geo and geo.scale or 1

  local shake = math.Rand( -1, 1 ) * ScreenScaleH( 0.444444444 ) * shakeAmp * scale

  local fWidth, fHeight = ScrW(), ScrH()
  local posX = fWidth * 0.5
  local posY = fHeight * 0.0333333333 + ( slot - 1 ) * fHeight * 0.096153846 * scale
  local scaleW = fWidth * 0.934579439
  local scaleH = fHeight * 0.0763491237 * scale

  local barPosX = posX - scaleW * 0.483675937
  local barPosY = posY - scaleH * 0.0952380952
  local barScaleX = scaleW * 0.971276
  local barScaleY = scaleH * 0.727848

  draw.RoundedBox( 2, posX - scaleW * 0.5, posY - scaleH * 0.25, scaleW, scaleH, BG_COLOR )
  draw.RoundedBox( 6, barPosX, barPosY + shake, barScaleX, barScaleY, BAR_BG_COLOR )

  -- активный слой: 1 = верхний (полный HP). Под текущим слоем на всю ширину
  -- виден цвет следующего (в UK слои — стопка слайдеров).
  local frac = math.Clamp( st.CurHP / maxHP, 0, 1 )
  local fracLost = math.Clamp( st.LostHP / maxHP, 0, 1 )
  local layer = math.Clamp( SPLITS - math.ceil( frac * SPLITS - 1e-9 ) + 1, 1, SPLITS )

  local segMax = ( SPLITS - layer + 1 ) / SPLITS
  local segMin = segMax - 1 / SPLITS

  if layer < SPLITS then
    draw.RoundedBox( 6, barPosX, barPosY + shake, barScaleX, barScaleY, LAYER_COLORS[ layer + 1 ] )
  end

  local lostDelta = math.Clamp( ( math.min( fracLost, segMax ) - segMin ) / ( 1 / SPLITS ), 0, 1 )
  if lostDelta > 0 then
    draw.RoundedBox( 6, barPosX, barPosY + shake, barScaleX * lostDelta, barScaleY, LOST_COLOR )
  end

  local delta = math.Clamp( ( frac - segMin ) / ( 1 / SPLITS ), 0, 1 )
  if delta > 0 then
    draw.RoundedBox( 6, barPosX, barPosY + shake, barScaleX * delta, barScaleY, LAYER_COLORS[ layer ] )
  end

  surface.SetFont( geo and geo.font or "Ultrakill_Font" )
  local w = surface.GetTextSize( TITLE )
  surface.SetTextPos( posX * 1.005 - w * 0.5 + shake, posY + shake )
  surface.SetTextColor( 255, 255, 255, 255 )
  surface.DrawText( TITLE )
end

-- наш бар участвует в общем канонном сжатии стека: регистрируем счётчик
-- живых MDK в UKBossBarStack.Extra (stack-файл грузится раньше по алфавиту,
-- но на случай смены порядка — повтор на InitPostEntity)
local function CountAliveMDK()
  local n = 0
  for _, ent in ipairs( MDKList ) do
    if IsValid( ent ) and ent:Health() > 0 then n = n + 1 end
  end
  return n
end

local function RegisterExtraBars()
  if UKBossBarStack and UKBossBarStack.Extra then
    UKBossBarStack.Extra.mdk = CountAliveMDK
  end
end

RegisterExtraBars()
hook.Add( "InitPostEntity", "UKMDK_RegisterExtraBars", RegisterExtraBars )

hook.Add( "HUDPaint", "UKMDK_BossBar", function()
  local cv = GetConVar( "drg_ultrakill_healthbar" )
  if cv and not cv:GetBool() then return end

  if CurTime() > NextScan then
    NextScan = CurTime() + 0.5
    ScanMDK()
  end
  if #MDKList == 0 then return end

  local slot = CountBaseBars()
  for _, ent in ipairs( MDKList ) do
    if not IsValid( ent ) or ent:Health() <= 0 then continue end
    slot = slot + 1
    if slot > 12 then break end
    DrawMDKBar( ent, slot )
  end
end )

-- =========================================================================
-- Установка сабтитр-хука: база грузит свой модуль позже нашего autorun,
-- поэтому ставим на InitPostEntity (+ немедленная попытка на lua_openscript).
-- =========================================================================

InstallSubtitleHook()
hook.Add( "InitPostEntity", "UKMDK_InstallSubtitles", function()
  timer.Simple( 1, InstallSubtitleHook )
end )
