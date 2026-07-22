-- lua/autorun/client/ultrakill_bossbar_stack.lua
-- Канонное сжатие стека босс-баров + клиентский приёмник тулгана Boss Bar.
--
-- 1) В ULTRAKILL (BossBarManager.RecalculateStretch) при >2 барах контейнер
--    сжимается по вертикали: scale = max(0.3, 0.82 - (count-2)*0.14), а текст
--    уменьшается равномерно (BossHealthBarTemplate.ScaleChanged). У базы
--    Кевина шаг стека фиксированный — 12 баров уезжают за середину экрана.
--    Заменяем HUDPaint-хук "UltrakillBase_HealthBar" расширенной копией
--    ProcessHud (рецепт замены хука — как у цветных сабтитров в
--    ultrakill_mdk_hud.lua). Рендер полос 1:1 как у базы, меняются только
--    вертикальный шаг, высота, тряска и шрифт.
--
-- 2) UltrakillBase.UKToolAddBoss — приёмник CallOnClient для тулгана:
--    переприменение бара сохраняет secondary-бар энтити (GetSecondaryBarValues
--    у Geryon определён только на клиенте, с сервера не проверить).
--
-- Кастомные бары (MDK) регистрируют счётчик в UKBossBarStack.Extra и берут
-- геометрию из UKBossBarStack.GetGeometry(), чтобы сжатие было общим.

if SERVER then return end

UKBossBarStack = UKBossBarStack or {}
UKBossBarStack.Extra = UKBossBarStack.Extra or {} -- имя -> function() -> число доп. баров

-- канон BossBarManager (декомпил): overflowShrinkFactor / minimumSize / baseOverflowedSize
local OVERFLOW_SHRINK = 0.14
local MIN_SIZE = 0.3
local BASE_OVERFLOW_SIZE = 0.82

function UKBossBarStack.GetStretch( count )

  if count <= 2 then return 1 end

  return math.max( MIN_SIZE, BASE_OVERFLOW_SIZE - ( count - 2 ) * OVERFLOW_SHRINK )

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


function UKBossBarStack.TotalBars()

  local n = CountBaseBars()
  for _, fn in pairs( UKBossBarStack.Extra ) do
    local ok, extra = pcall( fn )
    if ok and isnumber( extra ) then n = n + extra end
  end
  return n

end


-- Шрифты: копия формулы базы (42 * ResolutionDelta) * scale; scale дискретен
-- (1 / 0.82 / 0.68 / 0.54 / 0.40 / 0.3), кэш чистится при смене разрешения.

local FontCache = {}

local function ResolutionDelta()

  local d = ( ScrW() + ScrH() ) * 0.5 / 1500
  if d < 1 then d = d * 1.1 end
  return d

end

function UKBossBarStack.GetFont( scale )

  if scale >= 0.999 then return "Ultrakill_Font" end

  local name = "UKBB_Font_" .. math.Round( scale * 100 )
  if not FontCache[ name ] then
    surface.CreateFont( name, {
      font = "VCR OSD Mono",
      size = 42 * ResolutionDelta() * scale,
      weight = 600,
      antialias = true,
    } )
    FontCache[ name ] = true
  end
  return name

end

hook.Add( "OnScreenSizeChanged", "UKBossBarStack_Fonts", function()
  FontCache = {}
end )


function UKBossBarStack.GetGeometry()

  local scale = UKBossBarStack.GetStretch( UKBossBarStack.TotalBars() )
  local w, h = ScrW(), ScrH()

  return {
    scale = scale,
    posY0 = h * 0.0333333333,
    step = h * 0.096153846 * scale,
    scaleW = w * 0.934579439,
    scaleH = h * 0.0763491237 * scale,
    font = UKBossBarStack.GetFont( scale ),
  }

end


-- =========================================================================
-- Копия ProcessHud базы (ultrakillbase_healthbar.lua) с масштабом стека.
-- Логика/лерпы/цвета 1:1, включая причуды оригинала (LerpHP_Lost — глобал).
-- BossTable/BossEntityData/конвар биндятся в Install() — AddBoss/RemoveBoss
-- базы продолжают работать нетронутыми.
-- =========================================================================

local HealthLostColor = Color( 255, 161, 0, 255 )
local HealthColor = Color( 255, 0, 0, 255 )
local HealthGainedColor = Color( 0, 255, 0, 255 )
local BackgroundColor = Color( 0, 0, 0, 99.45 )
local HealthBackgroundColor = Color( 0, 0, 0, 170 )

local MaxHealthBarsPerRender = 12

local BossTable, BossEntityData, HealthBarConVar


local function DefaultSecondaryBarFunction( self )

  return 0, UltrakillBase.DefaultSecondaryBarColor

end


local function HudInit( Ent )

  local EntityData = BossEntityData[ Ent ]

  if not EntityData then return end

  if not IsValid( Ent ) or EntityData.Main_Initialized then return end

  EntityData.Main_Intro = true
  EntityData.Main_IntroTime = CurTime() + 1.25
  EntityData.Main_DieTime = CurTime()
  EntityData.Main_LerpTime = 1.25
  EntityData.Main_LerpTime_Lost = 1.25
  EntityData.Main_CurHP = Ent:Health()
  EntityData.Main_CurHP_Lost = Ent:Health()
  EntityData.Main_PrevHP = 0
  EntityData.Main_PrevHP_Lost = 0
  EntityData.Main_Delay = 0
  EntityData.Main_Segmented = {}
  EntityData.Main_HPGainedTime = 0
  EntityData.Main_HPGain = 0
  EntityData.Main_Initialized = true

end


local function HudInitS( Ent )

  local EntityData = BossEntityData[ Ent ]

  if not EntityData or not IsValid( Ent ) or EntityData.Secondary_Initialized then return end

  local DeclareFunction = Ent.GetSecondaryBarValues or DefaultSecondaryBarFunction

  EntityData.Secondary_DieTime = CurTime()
  EntityData.Secondary_LerpTime = 0.333333
  EntityData.Secondary_Cur = DeclareFunction( Ent )
  EntityData.Secondary_Prev = 0
  EntityData.Secondary_Initialized = true

end


local function HPLostFormulas( LerpHP, HP, MaxHP )

  local HPDiff = LerpHP - HP

  local Time = math.Clamp( HPDiff / ( MaxHP * 0.2 ), 0.1, 0.65 )
  local Delay = math.Clamp( HPDiff / ( MaxHP * 0.45 ), 0.25, 0.45 )

  return Time, Delay

end


local function HudUpdate( Ent, HP, MaxHP, LerpHP, LerpHPLost )

  local EntityData = BossEntityData[ Ent ]

  if EntityData.Main_Intro then

    if HP ~= MaxHP then

      EntityData.Main_CurHP = HP
      EntityData.Main_CurHP_Lost = HP
      EntityData.Main_Intro = false
      EntityData.Main_LerpTime = 0.1

    end

    if CurTime() > EntityData.Main_IntroTime then

      EntityData.Main_Intro = false

    end

  end

  if EntityData.Main_CurHP ~= HP then

    if LerpHP ~= HP then

      EntityData.Main_CurHP = LerpHP

    end

    if not EntityData.Main_Intro then

      EntityData.Main_LerpTime = 0.1

    end

    if EntityData.Main_CurHP < HP then

      EntityData.Main_LerpTime = 0.2
      EntityData.Main_HPGainedTime = CurTime()
      EntityData.Main_HPGain = EntityData.Main_CurHP

      EntityData.Main_LerpTime_Lost = 0
      EntityData.Main_Delay = 0
      EntityData.Main_PrevHP_Lost = EntityData.Main_CurHP
      EntityData.Main_CurHP_Lost = EntityData.Main_CurHP

    else

      EntityData.Main_HPGainedTime = 0
      EntityData.Main_HPGain = 0

    end

    EntityData.Main_PrevHP = EntityData.Main_CurHP
    EntityData.Main_DieTime = CurTime()
    EntityData.Main_CurHP = HP

  end

  if EntityData.Main_CurHP_Lost ~= HP then

    if LerpHP_Lost ~= HP then

      EntityData.Main_CurHP_Lost = LerpHPLost

    end

    if not EntityData.Main_Intro then

      EntityData.Main_LerpTime_Lost, EntityData.Main_Delay = HPLostFormulas( LerpHPLost, HP, MaxHP )

    end

    EntityData.Main_PrevHP_Lost = EntityData.Main_CurHP_Lost
    EntityData.Main_CurHP_Lost = HP

  end

end


local function HudUpdateS( Ent, SValue, SLerp )

  local EntityData = BossEntityData[ Ent ]

  if not EntityData or not EntityData.Secondary then return end

  if EntityData.Secondary_Cur ~= SValue then

    if SLerp ~= SValue then

      EntityData.Secondary_Cur = SLerp

    end

    EntityData.Secondary_Prev = EntityData.Secondary_Cur
    EntityData.Secondary_DieTime = CurTime()
    EntityData.Secondary_Cur = SValue

  end

end


local function HudCalculateHPRange( I, EntityData, Splits, LerpHP, LerpHPLost, MaxHP )

  local Threshold = I / Splits
  local NextThreshold = ( I - 1 ) / Splits

  local SegmentHP = math.Clamp( LerpHP / MaxHP, NextThreshold, Threshold )
  local SegmentHPLost = math.Clamp( LerpHPLost / MaxHP, NextThreshold, Threshold )

  return SegmentHP, SegmentHPLost, NextThreshold, Threshold

end


local function HudRender( Ent, PosX, PosY, ScaleX, ScaleY, PosY_NoStack, RandomShake, LerpHP, LerpHPLost, MaxHP, Gained )

  local EntityData = BossEntityData[ Ent ]
  local Splits = EntityData.Splits
  local GainHP = EntityData.Main_HPGain

  for I = 1, Splits do

    local SegmentHP, SegmentHPLost, SegmentMin, SegmentMax = HudCalculateHPRange( I, EntityData, Splits, LerpHP, LerpHPLost, MaxHP )
    local SegmentGain = math.Clamp( GainHP / MaxHP, SegmentMin, SegmentMax )

    HealthColor.r = 255 / I

    local Delta = math.Remap( SegmentHP, SegmentMin, SegmentMax, 0, 1 )
    local DeltaLost = math.Remap( SegmentHPLost, SegmentMin, SegmentMax, 0, 1 )
    local DeltaGain = math.Remap( SegmentGain, SegmentMin, SegmentMax, 0, 1 )

    if Delta <= 0 and DeltaLost <= 0 then continue end

    if Delta < DeltaLost and Gained <= 0 then

      draw.RoundedBox( 6, PosX, PosY + RandomShake, ScaleX * DeltaLost, ScaleY, HealthLostColor )

    end

    draw.RoundedBox( 6, PosX, PosY + RandomShake, ScaleX * Delta, ScaleY, HealthColor )

    if DeltaGain < 1 and Gained > 0 then

      local GainScaleMult = Lerp( Gained, 1, 1.3 )
      HealthGainedColor.a = Lerp( Gained ^ 0.65, 0, 255 )

      draw.RoundedBox( 6, PosX, PosY - ( PosY_NoStack * ( GainScaleMult - 1 ) ) + RandomShake, ScaleX * Delta, ScaleY * GainScaleMult, HealthGainedColor )

    end

  end

end


local function HudRenderS( Ent, RandomShake, PosX, PosY, ScaleW, ScaleH, SColor, SLerp )

  local EntityData = BossEntityData[ Ent ]

  if not EntityData or not EntityData.Secondary then return end

  local SPosX = PosX - ScaleW * 0.483775937
  local SPosY = PosY + ScaleH * 0.71
  local SScaleX = ScaleW * 0.971276
  local SScaleY = ScaleH * 0.1

  draw.RoundedBox( 6, SPosX, SPosY + RandomShake, SScaleX, SScaleY, HealthBackgroundColor )
  draw.RoundedBox( 6, SPosX, SPosY + RandomShake, SScaleX * SLerp, SScaleY, SColor or UltrakillBase.DefaultSecondaryBarColor )

end


local function HudShake( HP, LerpHPLost, MaxHP )

  local Delta = ScreenScaleH( 0.444444444 )

  if HP <= 0 then

    return math.Clamp( math.Rand( -1, 1 ) * Delta * 8, -8, 8 )

  end

  local Shake = math.Clamp( ( LerpHPLost - HP ) / ( MaxHP * 0.05 ), 0, 8 )

  return math.Clamp( math.Rand( -1, 1 ) * Delta * Shake, -Shake, Shake )

end


local function HudRemove( self )

  local EntityData = BossEntityData[ self ]

  if not EntityData or EntityData.IsDeleting then return end

  EntityData.IsDeleting = true

  timer.Simple( 0, function()

    if not BossEntityData[ self ] then return end

    table.RemoveByValue( BossTable, self )
    BossEntityData[ self ] = nil

  end )

end


local function ProcessHud()

  if not HealthBarConVar:GetBool() then return end

  -- масштаб стека — один на кадр, по общему числу баров (база + кастомные)
  local Geo = UKBossBarStack.GetGeometry()
  local Scale = Geo.scale

  for I = 1, #BossTable do

    local Ent = BossTable[ I ]

    if not IsValid( Ent ) then HudRemove( Ent ) end

    HudInit( Ent )
    HudInitS( Ent )

    local EntityData = BossEntityData[ Ent ]

    if not EntityData or not EntityData.Main_Initialized then continue end

    local HP = IsValid( Ent ) and Ent:Health() or 0
    local MaxHP = IsValid( Ent ) and Ent:GetMaxHealth() or 1

    local fCurTime = CurTime()
    local Delta = math.ease.OutCubic( math.Clamp( ( fCurTime - EntityData.Main_DieTime ) / EntityData.Main_LerpTime, 0, 1 ) )
    local DeltaLost = math.ease.OutCubic( math.Clamp( ( fCurTime - ( EntityData.Main_DieTime + EntityData.Main_Delay ) ) / EntityData.Main_LerpTime_Lost, 0, 1 ) )
    local DeltaGain = math.ease.OutCubic( 1 - math.Clamp( ( fCurTime - EntityData.Main_HPGainedTime ) / 0.6, 0, 1 ) )

    local LerpHP = Lerp( Delta, EntityData.Main_PrevHP, EntityData.Main_CurHP )
    local LerpHPLost = Lerp( DeltaLost, EntityData.Main_PrevHP_Lost, EntityData.Main_CurHP_Lost )
    local Title = EntityData.Title

    local SDeclareFunc = Ent.GetSecondaryBarValues or DefaultSecondaryBarFunction
    local SValue, SColor = SDeclareFunc( Ent )

    local SDelta = math.ease.OutCubic( math.Clamp( ( fCurTime - EntityData.Secondary_DieTime ) / EntityData.Secondary_LerpTime, 0, 1 ) )
    local SLerp = math.min( Lerp( SDelta, EntityData.Secondary_Prev, EntityData.Secondary_Cur ), 1 )

    HudUpdate( Ent, HP, MaxHP, LerpHP, LerpHPLost )
    HudUpdateS( Ent, SValue, SLerp )

    if I > MaxHealthBarsPerRender then continue end

    local RandomShake = HudShake( HP, LerpHPLost, MaxHP ) * Scale

    local fWidth, fHeight = ScrW(), ScrH()

    local PosX = fWidth * 0.5
    local PosY = Geo.posY0 + ( I - 1 ) * Geo.step

    local ScaleW = Geo.scaleW
    local ScaleH = Geo.scaleH

    local BackgroundPosX = PosX - ScaleW * 0.5
    local BackgroundPosY = PosY - ScaleH * 0.25

    local BarPosX = PosX - ScaleW * 0.483675937
    local BarPosY = PosY - ScaleH * 0.0952380952
    local BarPosY_NoStacking = Geo.posY0 - ScaleH * 0.0952380952

    local BarScaleX = ScaleW * 0.971276
    local BarScaleY = ScaleH * 0.727848

    local TextPosX = PosX * 1.005

    local AdditiveBackgroundScaleH = EntityData.Secondary and fHeight * 0.0125 * Scale or 0

    draw.RoundedBox( 2, BackgroundPosX, BackgroundPosY, ScaleW, ScaleH + AdditiveBackgroundScaleH, BackgroundColor )
    draw.RoundedBox( 6, BarPosX, BarPosY + RandomShake, BarScaleX, BarScaleY, HealthBackgroundColor )

    HudRenderS( Ent, RandomShake, PosX, PosY, ScaleW, ScaleH, SColor, SLerp )
    HudRender( Ent, BarPosX, BarPosY, BarScaleX, BarScaleY, BarPosY_NoStacking, RandomShake, LerpHP, LerpHPLost, MaxHP, DeltaGain )

    surface.SetFont( Geo.font )
    local SubWidth = surface.GetTextSize( Title )

    TextPosX = TextPosX - SubWidth * 0.5

    surface.SetTextPos( TextPosX + RandomShake, PosY + RandomShake )
    surface.SetTextColor( 255, 255, 255, 255 )

    surface.DrawText( Title )

  end

end


-- =========================================================================
-- Установка: база грузит свой модуль (и создаёт BossTable/конвар) позже
-- нашего autorun — ставим сейчас + на InitPostEntity (+таймер), как сабтитры.
-- =========================================================================

local function Install()

  if not UltrakillBase or not UltrakillBase.BossTable then return end

  BossTable = UltrakillBase.BossTable
  BossEntityData = UltrakillBase.BossEntityData
  HealthBarConVar = GetConVar( "drg_ultrakill_healthbar" )

  if not HealthBarConVar then return end

  -- приёмник тулгана: переприменение с сохранением secondary-бара.
  -- Имена HL2-нипов в спавн-меню — токены локализации ("#npc_zombie"),
  -- переводим здесь (у каждого клиента свой язык); upper = канон (ToUpper).
  function UltrakillBase.UKToolAddBoss( ent, title, splits )

    if not IsValid( ent ) or not isstring( title ) then return end

    if title:sub( 1, 1 ) == "#" then
      title = language.GetPhrase( title:sub( 2 ) )
    end
    title = string.upper( title )

    -- secondary ТОЛЬКО от уже существующего бара (Geryon: heat-метр).
    -- НЕ выводить из наличия ent.GetSecondaryBarValues: базовый
    -- ultrakillbase_nextbot определяет его ВСЕМ врагам (жёлтый стамина-метр),
    -- но показывается он лишь у боссов, явно передавших Secondary в AddBoss.
    local prev = BossEntityData[ ent ]
    local secondary = prev and prev.Secondary

    UltrakillBase.RemoveBoss( ent )
    UltrakillBase.AddBoss( ent, title, splits, secondary )

  end

  hook.Add( "HUDPaint", "UltrakillBase_HealthBar", ProcessHud )

end

Install()

hook.Add( "InitPostEntity", "UKBossBarStack_Install", function()
  timer.Simple( 1, Install )
end )
