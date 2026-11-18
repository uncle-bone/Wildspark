local addon, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Drawing primitives under the theme (ui/Theme.lua): fonts, status bars,
-- fills, borders, class colours, surfaces and backdrops that follow the
-- Background opacity, Border and Frameless settings; Highground Macros
-- ships them too. The board metrics (Core.PIP chips, Core.ROW_H and the
-- other panel sizes) are Highground's own.
---------------------------------------------------------------------------
-- An addon embedding this file sets ns.MEDIA to where it ships the fonts.
local MEDIA = ns.MEDIA or ("Interface\\AddOns\\" .. addon .. "\\libs\\media\\")
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
-- Type faces a theme's type roles can name (config/Theme.lua).
local FONTS = {
  bold = MEDIA .. "BarlowCondensed-Bold.ttf",
  semi = MEDIA .. "BarlowCondensed-SemiBold.ttf",
  medium = MEDIA .. "BarlowCondensed-Medium.ttf",
  mono = MEDIA .. "JetBrainsMono-Bold.ttf",
  friz = "Fonts\\FRIZQT__.TTF", -- the game's own
}
Core.FACES = FONTS
Core.WHITE = "Interface\\Buttons\\WHITE8x8"
Core.CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
Core.ICON_LOCK = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
Core.TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
Core.THEME = ns.UIConfig
Core.ACCENT, Core.INK, Core.MUTED = Core.THEME.colors.accent, Core.THEME.colors.panel, Core.THEME.colors.muted

-- Readable status chips; highest priority wins. { label, r, g, b } from
-- the chip colour tokens, rebuilt in place when the theme changes.
local PIPS = { immune = { "IMMUNE", "chipImmune" }, def = { "DEF", "chipDef" }, cc = { "CC", "chipCc" },
  control = { "CC", "chipCc" },
  stun = { "STUN/SIL", "chipStun" }, -- Cata's combined stun/silence observation
  carrier = { "FLAG", "chipCarrier" }, spent = { "SPENT", "chipSpent" }, burst = { "BURST", "chipBurst" },
  purge = { "PURGE", "chipPurge" }, -- bursting with a buff you can remove (ui/BurstMarks.lua)
}
Core.PIP = {}
function Core.BuildPips()
  for key, def in pairs(PIPS) do
    local c = ns.ThemeTokens.color[def[2]]
    local pip = Core.PIP[key] or {}
    pip[1], pip[2], pip[3], pip[4], pip[5] = def[1], c[1], c[2], c[3], def[2] -- [5]: token name
    Core.PIP[key] = pip
  end
end
Core.BuildPips()

Core.ROW_H, Core.GAP, Core.PAD, Core.WIDTH = Core.THEME.main.row, Core.THEME.main.gap, Core.THEME.main.padding, Core.THEME.main.width
Core.HEAD_H, Core.HERO_H, Core.FOOT_H = Core.THEME.main.header, Core.THEME.main.hero, Core.THEME.main.footer
Core.LIST_TOP = Core.HEAD_H + Core.HERO_H + Core.PAD + Core.THEME.main.section
Core.TILE_W = Core.THEME.main.rankWidth
Core.METER_SEGS = 6

-- Bundled fonts are new files: the client only sees them after a full
-- restart (not /reload). Until then SetFont fails -> Arial Narrow.
-- Every face set here is remembered, so the Font and Text size settings
-- (ui/Appearance.lua) can restyle all text at once.
Core.fonts = setmetatable({}, { __mode = "k" })
-- Also available in standalones that do not load the HUD Appearance module.
function Core.FontScale()
  local style = Core.db and Core.db.style
  local value = type(style) == "table" and tonumber(style.fontScale)
  local range = Core.THEME.appearance.fontScale
  return value and value == value and math.max(range.min, math.min(range.max, value)) or 1
end

local fontScaleListeners = {}
function Core.OnFontScaleChange(fn) fontScaleListeners[#fontScaleListeners + 1] = fn end

function Core.SetFontScale(value)
  value = tonumber(value)
  if not Core.db or not value or value ~= value or math.abs(value) == math.huge then return false end
  local range = Core.THEME.appearance.fontScale
  if type(Core.db.style) ~= "table" then Core.db.style = {} end
  Core.db.style.fontScale = math.max(range.min, math.min(range.max,
    math.floor(value / range.step + 0.5) * range.step))
  for fs in pairs(Core.fonts) do Core.SetFace(fs, fs.wbFace, fs.wbSize, fs.wbFlags) end
  for _, fn in ipairs(fontScaleListeners) do fn() end
  return true
end

function Core.SetFace(fs, face, size, flags)
  fs.wbFace, fs.wbSize, fs.wbFlags = face, size, flags
  Core.fonts[fs] = true
  local choice = Core.StyleChoice and Core.StyleChoice("font")
  local file = choice and choice.file or FONTS[face] or FONT_FALLBACK
  size = size * (Core.FontScale and Core.FontScale() or 1)
  local okCall, ok = pcall(fs.SetFont, fs, file, size, flags or "")
  if not (okCall and ok) then
    fs:SetFont(FONT_FALLBACK, size, flags or "")
  end
end

-- Status bars drawn with the Bar texture setting.
Core.bars = {}
function Core.BarFile()
  return Core.StyleChoice and Core.StyleChoice("bar").file or Core.WHITE
end
function Core.StatusBar(bar)
  Core.bars[#Core.bars + 1] = bar
  bar:SetStatusBarTexture(Core.BarFile())
  return bar
end

function Core.Text(parent, face, size, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  Core.SetFace(fs, face, size, flags)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(unpack(ns.ThemeTokens.color.shadow))
  fs:SetWordWrap(false)
  return fs
end

function Core.Border(parent, r, g, b, a, size)
  size = size or 1
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", -size, size)
  f:SetPoint("BOTTOMRIGHT", size, -size)
  f:SetBackdrop({ edgeFile = Core.WHITE, edgeSize = size })
  f:SetBackdropBorderColor(r, g, b, a or 1)
  return f
end

-- Theme helpers for per-tick drawing (ns.Theme loads after this file).
local tokenBorders = setmetatable({}, { __mode = "k" })
local hex = {}
local hooked = false
local function BorderColor(token, alpha)
  if type(alpha) == "string" then alpha = ns.Theme.Alpha(alpha) end
  return ns.Theme.Color(token, alpha)
end
local function Hook()
  if hooked then return end
  hooked = true
  ns.Theme.OnChange(function()
    wipe(hex)
    for f in pairs(tokenBorders) do f:SetBackdropBorderColor(BorderColor(f.wbBorderToken, f.wbBorderAlpha)) end
  end)
end

-- Core.Border in a colour token (alpha: number or alpha token), repainted
-- on a theme switch.
function Core.TokenBorder(parent, token, alpha, size)
  Hook()
  local r, g, b, a = BorderColor(token, alpha)
  local f = Core.Border(parent, r, g, b, a, size)
  f.wbBorderToken, f.wbBorderAlpha = token, alpha
  tokenBorders[f] = true
  return f
end

-- Theme.Hex, cached until the theme changes.
function Core.Hex(name)
  local v = hex[name]
  if not v then
    Hook()
    v = ns.Theme.Hex(name)
    hex[name] = v
  end
  return v
end

-- Class colour ({ r, g, b }) on a texture or text. Not a token: the region
-- stops being repainted on theme switches.
function Core.ClassPaint(region, c)
  ns.Theme.Unpaint(region)
  if region:GetObjectType() == "Texture" then
    region:SetColorTexture(c.r, c.g, c.b, 1)
  else
    ns.Theme.PaintClass(region, c)
  end
end

function Core.Fill(parent, layer, r, g, b, a, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Panel backgrounds follow the Background opacity setting (ui/Compact.lua):
-- registered surfaces take its alpha, backdrops its fill alpha.
Core.surfaces, Core.backdrops = {}, {}
function Core.Surface(parent, layer, sub)
  local t = ns.Theme.Fill(parent, layer, "surface", nil, sub)
  t.wbSurface = true
  Core.surfaces[#Core.surfaces + 1] = t
  t:SetAlpha(Core.BgAlpha and Core.BgAlpha() or 1)
  return t
end

-- Panel fill and border, following Background opacity, Border and the
-- Frameless setting (no fill, border or header: just the rows).
-- f.wbBackdrop (set by Theme.Backdrop) changes this per frame:
--   fill = colour token (default "bg"), alpha = fixed fill alpha (default:
--   Background opacity), border = colour token used while the Border colour
--   setting is the default, borderAlpha, frameless = false to stay drawn.
function Core.PaintBackdrop(f)
  local o = f.wbBackdrop or {}
  local T = ns.ThemeTokens.color
  local a = o.alpha or (Core.BgAlpha and Core.BgAlpha() or Core.THEME.opacity.default)
  if type(a) == "string" then a = ns.Theme.Alpha(a) end
  local edge = Core.BorderSize and Core.BorderSize() or 1
  if o.frameless ~= false and Core.Frameless and Core.Frameless() then
    f:SetBackdrop(nil)
    return
  end
  f:SetBackdrop({ bgFile = Core.WHITE, edgeFile = edge > 0 and Core.WHITE or nil, edgeSize = edge })
  local fill = T[o.fill or "bg"] or T.bg
  f:SetBackdropColor(fill[1], fill[2], fill[3], a)
  if edge > 0 then
    local custom = Core.StyleChoice and Core.StyleChoice("borderColor").key ~= "default"
    if o.border and T[o.border] and not custom then
      local b = T[o.border]
      f:SetBackdropBorderColor(b[1], b[2], b[3], o.borderAlpha or 1)
    elseif Core.BorderColor then
      f:SetBackdropBorderColor(Core.BorderColor(a))
    else
      local b = T.border
      f:SetBackdropBorderColor(b[1], b[2], b[3], math.min(1, a + 0.25))
    end
  end
end

function Core.Backdrop(f)
  Core.backdrops[#Core.backdrops + 1] = f
  Core.PaintBackdrop(f)
end

-- Header pieces honor Frameless unless the host exposes drag handles.
Core.chrome = {}
function Core.Chrome(...)
  for i = 1, select("#", ...) do
    local region = select(i, ...)
    Core.chrome[#Core.chrome + 1] = region
    if Core.Frameless and Core.Frameless() and not (ns.ShowPanelHeaders and ns.ShowPanelHeaders()) then region:SetAlpha(0) end
  end
end

-- Preserve the information in an animated cue when motion is reduced.
-- The proxy remembers requested playback so changing the setting takes
-- effect immediately, without moving or hiding any secure frame.
local motions = {}
function Core.ReducedMotion() return Core.db and Core.db.reducedMotion == true or false end

function Core.MotionGroup(group, target, steadyAlpha, looping)
  local motion = { group = group, target = target, steadyAlpha = steadyAlpha }
  function motion:Play()
    self.reduced = Core.ReducedMotion()
    self.wanted = looping or not self.reduced
    if self.reduced then
      self.group:Stop()
      if self.steadyAlpha then self.target:SetAlpha(self.steadyAlpha) end
    else
      self.group:Play()
    end
  end
  function motion:Stop() self.wanted = false; self.group:Stop() end
  function motion:IsPlaying() return self.wanted and (Core.ReducedMotion() or self.group:IsPlaying()) end
  -- One-shot groups must not replay when the preference changes later.
  group:HookScript("OnFinished", function() motion.wanted = false end)
  motions[#motions + 1] = motion
  return motion
end

function Core.RefreshMotion()
  if ns.Motion then ns.Motion.Refresh() end
  for _, motion in ipairs(motions) do
    if motion.wanted and motion.reduced ~= Core.ReducedMotion() then motion:Play() end
  end
end

function Core.SetReducedMotion(on)
  if Core.db then Core.db.reducedMotion = on and true or nil end
  Core.RefreshMotion()
end

function Core.Bounce(target, from, to, dur)
  local g = target:CreateAnimationGroup()
  g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetDuration(dur)
  a:SetSmoothing("IN_OUT")
  return Core.MotionGroup(g, target, from, true)
end
