local _, ns = ...

---------------------------------------------------------------------------
-- Design tokens. Neutral surfaces carry the content; accent is for actions
-- and selection, gold for rewards, signals for labelled tactical states.
-- Colours are sRGB, alpha is explicit. The shipped palettes are checked
-- against their composited surfaces by the accessibility simulations.
---------------------------------------------------------------------------
function ns.ThemeColor(hex, alpha)
  return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255, alpha }
end
local C = ns.ThemeColor

ns.Themes = {
  highground = {
    label = "Highground",
    description = "Cool slate, soft teal and clear, neutral text.",
    color = {
      -- Surfaces: wells, panel, cards, raised controls.
      bg = C("171c22"),
      surface = C("202830"),
      surfaceRaised = C("2b343e"),
      well = C("12171d"),
      chipBg = C("171c22"), -- opaque: status ink is isolated from health fills
      border = C("465461"), -- decorative dividers
      borderAccent = C("4f716e"),
      controlBorder = C("8393a2"), -- meaningful field / checkbox boundary
      focus = C("a8c9ef"),
      overlaySubtle = C("ffffff", 0.025),
      overlayHover = C("ffffff", 0.045),
      overlaySelected = C("8cc8bf", 0.12),
      overlayStrong = C("ffffff", 0.07),
      shadow = C("000000", 0.55),
      black = C("000000"),
      white = C("ffffff"),
      -- Text: dim is still readable; disabled opacity is a separate state.
      text = C("e2e8ed"),
      titleText = C("e2e8ed"),
      textMuted = C("bac6d0"),
      textDim = C("aebbc7"),
      onAccent = C("171c22"),
      -- Low-saturation signals, shared by the dark themes.
      accent = C("8cc8bf"),
      gold = C("dcc086"),
      success = C("a2d4b1"),
      warning = C("e4c18a"),
      pending = C("dcb595"),
      danger = C("efa6a6"),
      kill = C("f2acac"),
      info = C("a8c9ef"),
      brand = C("8cc8bf"),
      bounty = C("dcc086"),
      error = C("efa6a6"),
      factionA = C("a8c9ef"),
      factionH = C("efa6a6"),
      scopeGeneral = C("8cc8bf"),
      scopeCharacter = C("c9b8e5"),
      healer = C("83e8a2"),
      healerEnemy = C("f26b6b"),
      chipImmune = C("efa6a6"),
      chipDef = C("dcc086"),
      chipCc = C("a8c9ef"),
      chipStun = C("e4c18a"),
      chipCarrier = C("c9b8e5"),
      chipSpent = C("a2d4b1"),
      chipBurst = C("efa6a6"),
      chipPurge = C("98d2de"),
      -- World overlays always retain bright ink and a dark backing,
      -- including in Parchment. They do not sit on the panel palette.
      hudText = C("e2e8ed"),
      hudBg = C("171c22"),
      hudGold = C("e8cb8e"),
      hudWarning = C("edc28c"),
      hudDanger = C("f2acac"),
      capPlate = C("edb477"),
      capPlateAlly = C("98c7f0"),
      mapMark = C("edb477"),
      mapLabel = C("c5ced8"),
      dead = C("aebbc7"),
      -- Player-selected scope colours are identical in all themes.
      sniperMagenta = { 1, 0.15, 0.85 },
      sniperCyan = { 0.1, 0.95, 1 },
      sniperYellow = { 1, 0.95, 0.1 },
      sniperLime = { 0.55, 1, 0.1 },
      sniperOrange = { 1, 0.45, 0.05 },
    },
    -- Barlow for prose and labels, tabular JetBrains Mono for data.
    -- No role below 10px at 100% text size. All themes keep these sizes.
    type = {
      caption = { "semi", 10 },
      captionOutline = { "mono", 10, "OUTLINE" },
      label = { "mono", 10 },
      labelOutline = { "mono", 10, "OUTLINE" },
      code = { "mono", 11 },
      codeLarge = { "mono", 11 },
      timerSmall = { "mono", 11 },
      stat = { "mono", 12 },
      figure = { "mono", 13 },
      figureLarge = { "mono", 14 },
      readoutSmall = { "mono", 15 },
      timer = { "mono", 16 },
      badgeCount = { "mono", 16, "OUTLINE" },
      readout = { "mono", 24 },
      note = { "medium", 11 },
      body = { "medium", 12 },
      bodySmall = { "medium", 12 },
      bodyLarge = { "medium", 14 },
      detailSmall = { "semi", 11 },
      detail = { "semi", 12 },
      badgeLabel = { "semi", 11, "OUTLINE" },
      control = { "semi", 13 },
      input = { "semi", 14 },
      rowNameSmall = { "semi", 14 },
      rowName = { "semi", 15 },
      rowNameLarge = { "semi", 16 },
      headingSmall = { "bold", 11 },
      titleSmall = { "bold", 12 },
      heading = { "bold", 13 },
      cardName = { "bold", 15 },
      title = { "bold", 16 },
      cardTitle = { "bold", 17 },
      number = { "bold", 22 },
      display = { "bold", 24 },
      displayLarge = { "bold", 26 },
    },
    space = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 },
    -- Seconds: quick feedback, a little more time to orient to new content.
    motion = { press = 0.06, hover = 0.12, focus = 0.14, select = 0.16, enter = 0.18,
      menu = 0.20, page = 0.20, expand = 0.24, exit = 0.10 },
    size = {
      control = 24, input = 26, header = 56, tab = 28, tabWidth = 84, accentBar = 3,
      close = 26, chip = 16, toggle = 16, row = 24, icon = 16, portrait = 32,
      strip = 3, line = 1, underline = 2, scrollbar = 3, chipWidth = 62, headerSmall = 40,
    },
    -- Solid reading surfaces are deliberate. Only small decorative layers
    -- use transparency. Player-selected HUD opacity still takes precedence.
    alpha = { button = 1, card = 1, dialog = 1, menu = 1, chip = 0.10, bar = 0.65, band = 0.05,
      disabled = 0.55, panelCog = 0.25, zebraEven = 0.02, zebraOdd = 0.035, row = 1, page = 1,
      healthFill = 0.12, healthUnseen = 0.04, classRow = 0, topTint = 0.05, bevelLight = 0, bevelShade = 0,
      enter = 0.88, menuEnter = 0, pageEnter = 0.94, markEnter = 0.55 },
  },
}

local function Copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
  return out
end

-- Resolve shipped palettes once. Each gets independent, complete tables;
-- shared typography, geometry and semantic colours cannot silently drift.
function ns.DefineTheme(name, definition)
  local theme = Copy(ns.Themes.highground)
  for key, value in pairs(definition) do
    if type(value) == "table" and type(theme[key]) == "table" then
      for token, v in pairs(value) do theme[key][token] = type(v) == "table" and Copy(v) or v end
    else
      theme[key] = value
    end
  end
  ns.Themes[name] = theme
end

-- Stable live tables: references kept by the UI survive a theme switch.
ns.DEFAULT_THEME = "classcolors"
ns.ThemeTokens = Copy(ns.Themes.highground)
ns.ThemeTokens.name = "highground"
