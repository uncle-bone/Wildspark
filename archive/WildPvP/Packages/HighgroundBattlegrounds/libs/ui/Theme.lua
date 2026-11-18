local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Theme API (ns.Theme): read design tokens by name (config/Theme.lua) and
-- draw with them. Regions made or painted here are remembered, so
-- Theme.Use and Core.ApplyStyle repaint them; nothing else has to know a
-- colour. The active theme is saved in Core.db.theme (HighgroundDB, or
-- HighgroundMacrosDB in Highground Macros).
---------------------------------------------------------------------------
local Theme = {}
ns.Theme = Theme
local Tokens = ns.ThemeTokens
local BASE = "highground"
local DEFAULT = ns.DEFAULT_THEME
local GROUPS = { "color", "type", "space", "size", "alpha", "motion" }

local painted = setmetatable({}, { __mode = "k" }) -- region -> true (wbToken, wbAlpha, wbMode)
local texts = setmetatable({}, { __mode = "k" }) -- fontstring -> true (wbRole)
local listeners = {}

local function Lookup(group, name)
  local v = Tokens[group][name]
  if v == nil then error("unknown " .. group .. " token: " .. tostring(name), 3) end
  return v
end

-- Reads ---------------------------------------------------------------------
-- r, g, b, a of a colour token; alpha overrides the token's own.
function Theme.Color(name, alpha)
  local c = Lookup("color", name)
  return c[1], c[2], c[3], alpha or c[4] or 1
end

-- The live colour table { r, g, b[, a] }. It changes in place on a theme
-- switch; read it, don't modify it.
function Theme.Rgb(name)
  return Lookup("color", name)
end

local function HexOf(c)
  local function byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x", byte(c[1]), byte(c[2]), byte(c[3]))
end

-- "|cffRRGGBB" for inline text in Highground's own frames.
function Theme.Hex(name)
  return HexOf(Lookup("color", name))
end

-- Colour for Blizzard's dark frames (GameTooltip, chat): a light theme names
-- the theme to use there (darkFrames, config/Theme.lua).
local function DarkColor(name)
  local own = Lookup("color", name)
  local theme = ns.Themes[Tokens.name]
  local dark = theme and ns.Themes[theme.darkFrames]
  local c = dark and dark.color and dark.color[name]
  if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then
    return c
  end
  return dark and ns.Themes[BASE].color[name] or own
end

-- r, g, b, a of a colour token on a tooltip line.
function Theme.TipColor(name, alpha)
  local c = DarkColor(name)
  return c[1], c[2], c[3], alpha or c[4] or 1
end

-- "|cffRRGGBB" for chat and tooltip text.
function Theme.TipHex(name)
  return HexOf(DarkColor(name))
end

-- Tooltip line (default GameTooltip). color: a token name, a live token
-- table, { r, g, b } or a class colour { r =, g =, b = }; default "text".
function Theme.TipLine(tt, text, color, wrap)
  local name = color == nil and "text" or type(color) == "string" and color or Theme.Token(color)
  local r, g, b
  if name then
    r, g, b = Theme.TipColor(name)
  else
    r, g, b = color[1] or color.r, color[2] or color.g, color[3] or color.b
  end
  ;(tt or GameTooltip):AddLine(text, r, g, b, wrap)
end

-- face, size, flags of a type role.
function Theme.Font(role)
  local t = Lookup("type", role)
  return t[1], t[2], t[3]
end

function Theme.Space(name) return Lookup("space", name) end
function Theme.Size(name) return Lookup("size", name) end
function Theme.Alpha(name) return Lookup("alpha", name) end
function Theme.Motion(name) return Lookup("motion", name) end

-- Name of a live colour table (Theme.Rgb, ns.UIConfig.colors), else nil.
-- The live tables never change identity, so the map is built once.
local byTable = {}
for name, c in pairs(Tokens.color) do byTable[c] = name end
function Theme.Token(value)
  return byTable[value]
end

-- Painting ------------------------------------------------------------------
local function Apply(region, c, alpha, mode)
  if type(alpha) == "string" then alpha = Lookup("alpha", alpha) end
  local r, g, b, a = c[1] or c.r, c[2] or c.g, c[3] or c.b, alpha or c[4] or 1
  local kind = region.GetObjectType and region:GetObjectType()
  if mode == "vertex" then
    region:SetVertexColor(r, g, b, a)
  elseif kind == "StatusBar" then
    region:SetStatusBarColor(r, g, b, a)
  elseif kind == "Texture" or kind == "Line" then
    region:SetColorTexture(r, g, b, a)
  else
    region:SetTextColor(r, g, b, a) -- FontString, EditBox
  end
end

-- Colour a texture (SetColorTexture), status bar (SetStatusBarColor) or
-- text (SetTextColor). color is a token name, a live token table, or any
-- { r, g, b[, a] } or class colour { r =, g =, b = } (not repainted).
-- alpha: a number or an alpha token name (re-read on every repaint).
-- mode "vertex" tints a textured region with SetVertexColor instead.
-- A painted region is repainted on every theme change: recolour it with
-- Theme.Paint, or call Theme.Unpaint before colouring it directly.
function Theme.Paint(region, color, alpha, mode)
  region.wbClass = nil
  local name = type(color) == "string" and color or Theme.Token(color)
  if name then
    region.wbToken, region.wbAlpha, region.wbMode = name, alpha, mode
    painted[region] = true
    Apply(region, Lookup("color", name), alpha, mode)
  else
    region.wbToken = nil
    painted[region] = nil
    Apply(region, color, alpha, mode)
  end
  return region
end

function Theme.Tint(region, color, alpha)
  return Theme.Paint(region, color, alpha, "vertex")
end

-- Stop repainting a region (its colour stays as it is).
function Theme.Unpaint(region)
  painted[region] = nil
  region.wbToken = nil
  region.wbClass = nil
end

-- Solid texture in a colour token.
function Theme.Fill(parent, layer, color, alpha, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  return Theme.Paint(t, color, alpha)
end

-- FontString in a type role and colour token (default "text"). The role
-- sets face, size and flags (outline). Follows the Font and Text size
-- settings (Core.SetFace) and theme switches.
function Theme.Text(parent, role, color)
  local face, size, flags = Theme.Font(role)
  local fs = Core.Text(parent, face, size, flags)
  fs.wbRole, fs.wbRoleFace, fs.wbRoleSize = role, face, size
  texts[fs] = true
  return Theme.Paint(fs, color or "text")
end

-- Change the role of a Theme.Text (or any FontString or EditBox). A later
-- Core.SetFace with another face or size detaches the role.
function Theme.SetRole(fs, role)
  local face, size, flags = Theme.Font(role)
  fs.wbRole, fs.wbRoleFace, fs.wbRoleSize = role, face, size
  texts[fs] = true
  Core.SetFace(fs, face, size, flags)
end

-- Text shadow in a colour token other than "shadow" (text over the world).
function Theme.Shadow(fs, color)
  fs.wbShadow = color
  fs:SetShadowColor(Theme.Color(color))
  return fs
end

-- Panel or dialog backdrop: Background opacity, Border size and colour,
-- Frameless. opts (all optional): fill = colour token ("bg"), alpha = fixed
-- fill alpha (default Background opacity), border = colour token while the
-- Border colour setting is the default, borderAlpha, frameless = false to
-- stay drawn when Frameless is on. Repainted by ns.ApplyOpacity.
function Theme.Backdrop(frame, opts)
  frame.wbBackdrop = opts or {}
  if frame.wbBackdropRegistered then
    Core.PaintBackdrop(frame)
  else
    frame.wbBackdropRegistered = true
    Core.Backdrop(frame)
  end
  return frame
end

-- fn() runs after every repaint (for state kept outside regions).
function Theme.OnChange(fn)
  listeners[#listeners + 1] = fn
end

-- Repaint everything registered with the current tokens. deferFonts: only
-- record the new faces (Core.ApplyStyle sets every font right after).
-- Sizes and spacing are read when a widget is built; a switch does not
-- move or resize existing frames.
function Theme.Repaint(deferFonts)
  if Core.BuildPips then Core.BuildPips() end
  for fs in pairs(texts) do
    if fs.wbFace == fs.wbRoleFace and fs.wbSize == fs.wbRoleSize then
      if deferFonts then
        local face, size, flags = Theme.Font(fs.wbRole)
        fs.wbFace, fs.wbSize, fs.wbFlags, fs.wbRoleFace, fs.wbRoleSize = face, size, flags, face, size
      else
        Theme.SetRole(fs, fs.wbRole)
      end
      fs:SetShadowColor(Theme.Color(fs.wbShadow or "shadow"))
    else
      texts[fs] = nil -- resized with Core.SetFace since: that size wins
    end
  end
  for region in pairs(painted) do
    Apply(region, Lookup("color", region.wbToken), region.wbAlpha, region.wbMode)
  end
  -- Standalone addons do not all have ApplyStyle / ApplyOpacity.
  for _, frame in ipairs(Core.backdrops or {}) do Core.PaintBackdrop(frame) end
  if Core.RefreshMotion then Core.RefreshMotion() end
  for _, fn in ipairs(listeners) do fn() end
end

-- Themes --------------------------------------------------------------------
local function Valid(group, v)
  if group == "motion" then
    return type(v) == "number" and v == v and v >= 0 and v <= 1
  elseif group == "color" then
    return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
      and (v[4] == nil or type(v[4]) == "number")
  elseif group == "type" then
    return type(v) == "table" and type(v[1]) == "string" and (not Core.FACES or Core.FACES[v[1]] ~= nil)
      and type(v[2]) == "number" and v[2] > 0
      and (v[3] == nil or type(v[3]) == "string")
  end
  return type(v) == "number"
end

-- Copy a theme into the live token tables; missing or invalid tokens take
-- the base theme's value.
local function Load(name)
  local base, theme = ns.Themes[BASE], ns.Themes[name] or ns.Themes[BASE]
  for _, group in ipairs(GROUPS) do
    local own = type(theme[group]) == "table" and theme[group] or {}
    for key, fallback in pairs(base[group]) do
      local v = own[key]
      if not Valid(group, v) then v = fallback end
      if type(v) == "table" then
        local live = Tokens[group][key]
        live[1], live[2], live[3], live[4] = v[1], v[2], v[3], v[4]
      else
        Tokens[group][key] = v
      end
    end
  end
  Tokens.name = ns.Themes[name] and name or BASE
end

-- Add or replace a theme: { label?, color?, type?, space?, size?, alpha?, motion? }.
function Theme.Register(name, tokens)
  if type(name) ~= "string" or name == "" or type(tokens) ~= "table" then return false end
  if name == BASE and ns.Themes[BASE] ~= tokens then return false end -- the base stays complete
  ns.Themes[name] = tokens
  local saved = Core.db and Core.db.theme
  if Tokens.name == name or saved == name then
    Load(name)
    Theme.Repaint()
  end
  return true
end

function Theme.Current() return Tokens.name end

-- Theme names, the default first. The inheritance base stays Highground.
function Theme.Names()
  local list = {}
  for name in pairs(ns.Themes) do
    if name ~= DEFAULT then list[#list + 1] = name end
  end
  table.sort(list)
  table.insert(list, 1, DEFAULT)
  return list
end

function Theme.Label(name)
  local t = ns.Themes[name]
  return t and t.label or name
end

function Theme.Description(name)
  local t = ns.Themes[name or Tokens.name]
  return t and t.description or ""
end

-- Saved choice -> live tokens, then repaint. Core.ApplyStyle calls this
-- first (deferFonts), so one call re-skins everything. A saved name that is
-- not registered (yet) uses the default theme but stays saved: Theme.Register
-- applies it when it arrives. A saved value that is not a name is dropped.
function Theme.Sync(deferFonts)
  local db = Core.db
  if db then
    if db.theme ~= nil and type(db.theme) ~= "string" then db.theme = nil end
    local wanted = db.theme and ns.Themes[db.theme] and db.theme or DEFAULT
    if wanted ~= Tokens.name then Load(wanted) end
  end
  Theme.Repaint(deferFonts)
end

-- Switch theme and save it. False when the theme does not exist.
function Theme.Use(name)
  if type(name) ~= "string" or not ns.Themes[name] then return false end
  if Core.db then
    Core.db.theme = name ~= DEFAULT and name or nil
  else
    Load(name)
  end
  if Core.db and Core.ApplyStyle then
    Core.ApplyStyle()
  else
    Theme.Sync()
  end
  return true
end

-- Shipped palettes are loaded before the UI, including frames made before
-- saved settings are available. Keep their initial colours consistent too.
Load(DEFAULT)
