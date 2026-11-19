local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The window's look in one place: its palette, the accent color, its fonts and
-- the display settings (WildGearDB.display, saved for all characters
-- and set in the Settings panel, Settings.lua):
--   scale     window scale on top of the game's UI scale
--   wishScale the wish list tracker's scale (WishList.lua), on its own: 0.8 to 2
--   opacity   background opacity of the window and its side panels
--   accent    "gold" or "class" (the player's class color): selected rows,
--             tabs and choice buttons, and the scroll thumbs. The Classic
--             theme has no such setting: its accent is the game's gold, or
--             its skin's color.
--   textSize  points added to the game's font sizes, -2 to 1. The game's
--             sizes are cramped in the window's rows, so it defaults to one
--             point smaller. A Chinese client's font runs larger
--             (ns.language.bigFont): there every choice is one point smaller
--             still (FONT_SHIFT), and the default is -2, three points under
--             the game's.
--   font      "ui" (the font of your UI addon, EllesmereUI, DaylightUI or
--             ElvUI, when one is loaded: UI_ADDONS) or "game" (the game's own
--             fonts, as they were before a UI addon gave them its own). The
--             window follows a change to the UI font at once. A UI addon
--             picks its font for the client's language itself: EllesmereUI
--             and DaylightUI, where their fonts lack the letters (Chinese,
--             Korean, Russian), use the client's. The Classic theme
--             defaults to the game's (a skin to the UI font).
--   theme     "modern" (the flat dark frames above), "classic" (the game's
--             own frame art: Widgets.lua) or a skin's key (the Classic layout
--             in a place's own art: Skins\*.lua, T.Skin). Unlike the rest it
--             picks how the widgets are made, so it takes a reload (T.Classic;
--             the Settings panel offers one), and Reset leaves it.
-- Gold stays gold where it is the game's own text color (headers, quest
-- names, tooltip titles); only what marks a selection follows the accent.

local T = {}
ns.Theme = T

T.GOLD = { 1, 0.82, 0 }
-- The Modern theme's title bars (the window's and the side panels'): the
-- game's gold, softened so it sits on the flat dark frames.
T.TITLE = { 0.91, 0.77, 0.35 }
-- The Modern theme's surfaces, a little cool, each step lighter than the one
-- under it: the window, the lists' cards on it, the controls. Controls have no
-- outline (W.Fill); only what floats (the window, popups, bubbles) has an edge.
T.WINDOW = { 0.059, 0.067, 0.082 } -- window and side panels
T.CARD = { 1, 1, 1, 0.035 } -- the lists' cards: a light over the window, so they follow its opacity
T.BOX = { 0.082, 0.094, 0.118 } -- boxes of controls (the Settings panel's), as a card on the window
T.SURFACE = { 0.125, 0.141, 0.173 } -- buttons, switches
T.FIELD = { 0.125, 0.141, 0.173 } -- selector and text boxes
T.TRACK = { 0.035, 0.039, 0.05 } -- sunk under the window: choice rows', sub-tabs' and switches' tracks
T.RAISED = { 0.165, 0.184, 0.224 } -- the selected choice on a track
T.GAIN = { 0.2, 1, 0.6 } -- gains (UI.lua's green, |cff33ff99), and their chips
T.BORDER = { 0.2, 0.22, 0.26 } -- the edge of what floats
T.THUMB = { 0.23, 0.25, 0.3 } -- scroll bars' thumbs
T.DIM = { 0.6, 0.63, 0.68 } -- tabs and labels that aren't selected

local DEFAULTS = { scale = 1, wishScale = 1, opacity = 0.95, accent = "gold",
    textSize = ns.language.bigFont and -2 or -1, font = "ui", theme = "modern" }
local FONT_SHIFT = ns.language.bigFont and -1 or 0

-- The skins, in the order their files register them (Settings lists them so).
-- A skin is a table of the art it puts on the Classic layout; each part is
-- optional (Widgets.lua: W.ClassicWindow, W.TitleBand, W.Window):
--   name      its name in the Theme list
--   accent    r, g, b of what marks a selection (else the game's gold)
--   portrait  the portrait ring's icon (a file id), its border trimmed
--   band      the painting in the stone band behind the selectors: file (4:1),
--             y (where the band's slice of it is centered, 0 top to 1
--             bottom), top / bottom (how dark it is made there, 0 to 1)
--   floor     the lists' and side panels' background: file (a seamless
--             tile), tile (its size across), dim (its brightness, 0 to 1)
--   plaque    the title plaque: file, size (texels across, down), box (the
--             plaque in it: x0, x1, y0, y1), cap (its ends' texels, which
--             keep their shape), capWidth (drawn), pad (beside the title),
--             color (the title's)
--   vine      a top-left corner piece, drawn mirrored on the window's top
--             right: file, size
--   frame     a frame of its own for the window and the side panels, in place
--             of the Auction House's and the dialog border (and of the
--             portrait and the plaque: the title goes in its bar): file,
--             size (texels), side / top / bottom (its corners' texels),
--             edge (where its top edge starts), bar (its title bar's height),
--             scale (drawn), rail (its sides' width, drawn), railH / railV
--             (its wood across and down, for the window's dividers: file,
--             size drawn)
--   bar       with a frame, the bottom bar's board, as tall as the bar and
--             tiled across, every other one mirrored: file, size (its texels
--             across, down: its shape), dim (its brightness, 0 to 1)
--   button   its buttons and tabs: file, hover (lit), glow (hover's light
--             over file, added on hover), down, size, cap, capWidth
--   close     its close button: file, size
--   bubble    with button, the bubbles (small tooltips) in its pressed wood:
--             rim (the border's and pointer's color), fill (the pointer's
--             inside, as the wood)
--   pointer   with a frame, the question boxes' pointer (tip up, base on the
--             texture's bottom edge, its foot faded by tools\skinart.py),
--             drawn over the frame: file, size (drawn), depth (how far its
--             base reaches in across the frame's edge), inset (its middle's
--             least distance from a corner)
--   icons    its small square buttons, each a file: down (the selectors'
--             and the scroll bars'; with button, the selectors' box is its
--             pressed look), up (the scroll bars'), plus / minus (fold signs);
--             with a frame too, the scroll bars' track is its railV, darkened
--   toggle    with button, on/off switches (as the Modern theme's) in place
--             of the game's check boxes: the button's pressed art for the
--             track, lit by its glow in the accent when on: size (drawn),
--             capWidth, knob (file, size: a disc on a shadow, tools\skinart.py)
--   emblem    with a frame, the badge on the window's top left: file, size,
--             small (optional: a 32 px copy for small buttons and headers,
--             T.Emblem; tools\skinart.py)
--   icon      (optional) its small icon in Settings' Theme list (default:
--             the emblem's small file, else its file)
--   check     (optional) what marks the selected option in a dropdown
--             list, in place of the game's check mark: file, tilt
--             (degrees, clockwise)
--   star      (optional) the wish list's star (WishList.lua), drawn as it
--             is: on (wished, filled), off (empty); each a file
--             (tools\starart.py). Without it, the Classic theme's (the
--             game's Auction House star)
--   decals    with a frame, a few things lying on the lists' floor, placed
--             anew each time the window opens: files (each used once at a
--             time), count, size (across, drawn), dim (default: the floor's),
--             flame (optional: candles that light and go out now and then:
--             model (a game flame model's file id), box (each flame's model
--             frame, drawn on a decal `size` across, centered on its wick),
--             zoom, x / y / z, facing, alpha (as light's), glow (a round
--             glow, white), glowAlpha, wicks (by file index, each wick's tip:
--             u, v across and down the decal, 0 to 1))
--   leaves    with a frame, leaves falling behind the window's lists: files
--             (one picked per fall), count, size (across, drawn), alpha
--   light     with a frame, a game model (a light shaft) over the leaves,
--             under the lists: model (its file id), zoom, x / y / z (toward
--             the camera, across, up), facing (radians), alpha
--   walker    with a frame, a creature wandering on the bottom bar, left of
--             its buttons, that bolts when clicked: model (a game model's
--             file id: walk, run and stand animations), box (its frame, drawn
--             across, down; feet on the bottom), zoom, x / y / z (as light's),
--             facing (radians, looking left), sound (a file id, played when
--             clicked), file (painted art if the model doesn't load: facing
--             left, feet on the bottom edge), size (drawn, square), speed /
--             trot / run (pixels a second: the painted art wandering /
--             the model wandering, its feet in step / bolting)
--   seasons   (optional) art for a time of year in place of the skin's own
--             emblem, leaves, check, vine, decals and walker, and a switch on the
--             bottom bar that turns it off and on again (saved:
--             display.seasonOff): a list of { key, name (the switch's
--             label), art = { field = value }, and optionally from = { month,
--             day }, to = { month, day } (else on while the version that has
--             it is) }; the dev addon's /wildgear season forces one or none
local skins, order = {}, {}
function T.RegisterSkin(key, def)
    def.key = key
    skins[key] = def
    order[#order + 1] = def
end

function T.Skins()
    return order
end

-- This session's theme: the setting as it was when the first widget was made
-- (the saved variables are in by then); a skin no longer installed is Classic.
local session
function T.Theme()
    if session == nil and ns.db then
        session = (ns.db.display and ns.db.display.theme) or DEFAULTS.theme
        if session ~= "modern" and session ~= "classic" and not skins[session] then session = "classic" end
    end
    return session or DEFAULTS.theme
end

-- Whether this session's widgets are the Classic theme's (a skin's too).
function T.Classic()
    return T.Theme() ~= "modern"
end

-- A skin's season (def.seasons) that is on (one without dates always is),
-- or the one the dev addon forces (WildGearDevDB.season, "none"
-- for none): def.season, found once a session.
local function Season(def)
    if def.seasoned or not def.seasons then return end
    def.seasoned = true
    local forced = type(WildGearDevDB) == "table" and WildGearDevDB.season
    local now = date("*t")
    local today = now.month * 100 + now.day
    for _, s in ipairs(def.seasons) do
        local on
        if forced then
            on = forced == s.key
        elseif not (s.from and s.to) then
            on = true
        else
            local from, to = s.from[1] * 100 + s.from[2], s.to[1] * 100 + s.to[2]
            if from <= to then
                on = today >= from and today <= to
            else -- (over the new year)
                on = today >= from or today <= to
            end
        end
        if on then
            def.season = s
            return
        end
    end
end

-- This session's skin, or nil.
function T.Skin()
    local skin = skins[T.Theme()]
    if skin and session then Season(skin) end
    return skin
end

-- This session's skin's season (def.seasons' entry), or nil.
function T.Season()
    local skin = T.Skin()
    return skin and skin.season
end

-- Whether its season's art shows (the bottom bar's switch).
function T.SeasonOn()
    return T.Season() ~= nil and not (ns.db.display and ns.db.display.seasonOff)
end

-- Turns the season's art off or on (saved), and tells what showed it
-- (T.OnSeason).
local seasonHooks = {}
function T.SetSeasonOn(on)
    local d = ns.db.display or {}
    d.seasonOff = not on or nil
    ns.db.display = next(d) and d or nil
    for _, fn in ipairs(seasonHooks) do fn(T.SeasonOn()) end
end

function T.OnSeason(fn)
    seasonHooks[#seasonHooks + 1] = fn
end

-- The skin's part `key`, its season's while that shows.
function T.SkinPart(key)
    local skin = T.Skin()
    if not skin then return nil end
    local s = skin.season
    if s and s.art[key] ~= nil and T.SeasonOn() then return s.art[key] end
    return skin[key]
end

-- The emblem small buttons and headers show (the Character frame's My gear,
-- the wish list's tracker): the skin's, its season's while that shows, the
-- Classic theme's (obsidian and gold), else (Modern) the addon's own icon.
-- Those redraw on T.OnSeason. framed: a rounded-square badge to the edge of
-- its texture (Classic's and a skin's), not the icon with room round it.
-- (Their 32 px copies: drawn this small, the 128 px ones have a rough edge.)
function T.Emblem()
    local emblem = T.SkinPart("emblem")
    if emblem then return emblem.small or emblem.file, true end
    if T.Classic() then return "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Classic\\EmblemSmall", true end
    return "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Icon", false
end

function T.Default(key)
    if key == "font" and T.Theme() == "classic" then return "game" end
    return DEFAULTS[key]
end

function T.Get(key)
    local v = ns.db and ns.db.display and ns.db.display[key]
    if v == nil then return T.Default(key) end
    return v
end

-- Saves a setting (defaults aren't stored) and applies it.
function T.Set(key, value)
    local d = ns.db.display or {}
    if value == T.Default(key) then value = nil end
    d[key] = value
    ns.db.display = next(d) and d or nil
    T.Apply()
end

-- (The theme stays: it takes a reload. A season switched off is on again.)
function T.Reset()
    local theme = ns.db.display and ns.db.display.theme
    ns.db.display = theme and { theme = theme } or nil
    T.Apply()
    T.SetSeasonOn(true)
end

-- r, g, b, alpha (default 1) of the accent (a skin's own, if it has one).
function T.Accent(alpha)
    if T.Get("accent") == "class" and not T.Classic() then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if c then return c.r, c.g, c.b, alpha or 1 end
    end
    local skin = T.Skin()
    local c = skin and skin.accent or T.GOLD
    return c[1], c[2], c[3], alpha or 1
end

-- r, g, b of a list's label (a slot's name): the selected one's in the accent,
-- the rest grey; in the Classic theme, as the game's lists, white and gold.
function T.LabelColor(selected)
    if T.Classic() then
        if selected then return 1, 1, 1 end
        return T.GOLD[1], T.GOLD[2], T.GOLD[3]
    end
    if selected then return T.Accent() end
    return T.DIM[1], T.DIM[2], T.DIM[3]
end

-- "|cffRRGGBB" of the accent.
function T.AccentHex()
    local r, g, b = T.Accent()
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

-- Colors set once when a widget is made: `paint` runs now and again on every
-- settings change. Colors set on each redraw just read T.Accent().
local painters = {}
function T.Track(paint)
    painters[#painters + 1] = paint
    paint()
end

-- The window's own copies of the game fonts it uses, named after them
-- (GameFontNormal -> WildGearFontNormal), so text size and font can
-- change without touching the rest of the game's UI. Font strings follow their
-- font object, so a change shows at once.
local FONTS = { "GameFontNormal", "GameFontNormalLarge", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontDisableSmall" }
-- `native`: each one's own font file, read as this file loads. A UI addon can
-- give the game's fonts its own (EllesmereUI's "Apply to All Game Text", at
-- login, after every addon has loaded), and "game" means the game's, not that.
local fonts, native = {}, {}
for _, base in ipairs(FONTS) do
    local font = CreateFont("WildGear" .. base:sub(5))
    if _G[base] then
        font:CopyFontObject(_G[base])
        native[base] = (_G[base]:GetFont())
    end
    fonts[base] = font
end
-- Left alone (exactly the game's fonts) until the size or font first changes;
-- `face`: the font file in use instead of the game's (nil: the game's).
local changed, face

-- The UI font: the font of a UI addon that has one of its own, which it
-- doesn't necessarily give the game's fonts (one that does is followed by the
-- game's fonts already). Per addon: its object (nil when not loaded), its
-- font file, the font's name as its own settings show it, and the function it
-- calls when its font settings change (hooked, so the window follows). The
-- first one loaded wins. The game has no setting of its own for this.
local NON_LATIN = { koKR = true, zhCN = true, zhTW = true }
-- DaylightUI's font pick for windows: its Window font's, else ("general") its font's.
local function DaylightPick(D)
    local g = D.DB and D.DB.General and D.DB.General()
    if type(g) ~= "table" then return nil end
    local key = g.windowFont
    if type(key) ~= "string" or key == "" or key == "general" then key = g.font end
    return key
end
local UI_ADDONS = {
    {
        title = "EllesmereUI",
        get = function() return _G.EllesmereUI end,
        path = function(E) return E.GetFontPath() end,
        -- Its picker's names, or the Blizzard or system font it can use instead
        -- (the system font is what it uses for a script its fonts lack).
        name = function(E, path)
            local name = E.GetFontName and E.GetFontName()
            if name == E.BLIZZARD_FONT_KEY then return ns.L["Blizzard font"] end
            if name == E.SYSTEM_FONT_KEY or path == E.LOCALE_FONT_FALLBACK then return ns.L["System font"] end
            if name == E.EXPRESSWAY_FORCED_KEY then return "Expressway" end
            return name and (E.FONT_DISPLAY_NAMES and E.FONT_DISPLAY_NAMES[name] or name)
        end,
        changed = "InvalidateFontCache",
    },
    -- DaylightUI (its public API, DaylightUI.API): the font it gives windows,
    -- its Window font (its own windows' text and the game's windows it
    -- restyles), else its font. Its own fonts have Latin letters only: on a
    -- Chinese or Korean client it uses the game's with "Use my language's
    -- font" on, and the window does even with it off. `listen`: it says when
    -- its look changes (it asks addons not to hook its functions).
    {
        title = "DaylightUI",
        get = function()
            local D = rawget(_G, "DaylightUI")
            return type(D) == "table" and type(D.API) == "table" and type(D.API.FontFile) == "function" and D or nil
        end,
        path = function(D)
            local path = D.API.FontFile(DaylightPick(D))
            if type(path) ~= "string" then return nil end
            if NON_LATIN[ns.locale] and path:find("AddOns[\\/]DaylightUI[\\/]") then return native.GameFontNormal end
            return path
        end,
        -- Its picker's names: its own fonts', a shared font's, or the game's.
        name = function(D, path)
            if NON_LATIN[ns.locale] and not path:find("AddOns[\\/]") then return ns.L["System font"] end
            local key = DaylightPick(D)
            local shared = type(key) == "string" and key:match("^lsm:(.+)$")
            if shared then return shared end
            local f = D.Style and D.Style.FONTS and D.Style.FONTS[key]
            if f and f.game then return ns.L["Blizzard font"] end
            return f and f.label
        end,
        listen = function(D, fn)
            D.API.On("StyleChanged", fn, "WildGear")
            D.API.On("Login", fn, "WildGear")
        end,
    },
    {
        title = "ElvUI",
        get = function() return _G.ElvUI and _G.ElvUI[1] end,
        path = function(E) return E.media and E.media.normFont end,
        name = function(E) return E.db and E.db.general and E.db.general.font end,
        changed = "UpdateMedia",
    },
}

-- The UI font's file and its addon, or nil without such an addon.
local function UIFont()
    for _, a in ipairs(UI_ADDONS) do
        local obj = a.get()
        if obj then
            local ok, path = pcall(a.path, obj)
            if ok and path then return path, a, obj end
        end
    end
end

-- Whether there is a UI font to pick (Settings shows the choice).
function T.HasUIFont()
    return UIFont() ~= nil
end

-- The font file the window uses instead of the game's, or nil.
local function WantedFont()
    return T.Get("font") == "ui" and (UIFont()) or nil
end

-- The game's fonts' names (by file): the Latin clients'.
local GAME_FONT_NAMES = { FRIZQT__ = "Friz Quadrata", FRIZQT___CYR = "Friz Quadrata", ARIALN = "Arial Narrow",
    MORPHEUS = "Morpheus", SKURRI = "Skurri" }
local function FileName(path)
    return path:match("([^\\/]+)%.%w+$") or path
end

-- Font `path` of `a` by name: its own, else the game font's it is, else its file's.
local function NameOf(path, a, obj)
    local ok, name = pcall(a.name, obj, path)
    return (ok and name) or GAME_FONT_NAMES[FileName(path):upper()] or FileName(path), a.title
end

-- The UI font's name (else its file's) and its addon's, for Settings.
function T.UIFontName()
    local path, a, obj = UIFont()
    if not path then return nil end
    return NameOf(path, a, obj)
end

-- The game's font's name, for Settings: the Latin clients' fonts; nil for another.
function T.GameFontName()
    local path = native.GameFontNormal
    return path and GAME_FONT_NAMES[FileName(path):upper()]
end

local Follow

-- Whether a UI addon has given the window's copies a font of its own
-- (EllesmereUI's "Apply to All Game Text" takes every named font object).
local function Swapped()
    for base, font in pairs(fonts) do
        if native[base] and font:GetFont() ~= native[base] then return true end
    end
    return false
end

local function ApplyFonts()
    local add = T.Get("textSize") + FONT_SHIFT
    local want = WantedFont()
    Follow()
    if add == 0 and not want and not changed and not Swapped() then return end
    changed, face = true, want
    for base, font in pairs(fonts) do
        local path, size, flags
        if _G[base] then path, size, flags = _G[base]:GetFont() end
        if path and size then font:SetFont(face or native[base] or path, size + add, flags or "") end
    end
end

-- When a UI addon's font settings change, the window takes the new UI font
-- (once per burst of calls, and only when the font did change). Hooked when
-- the fonts are first applied, after every addon has loaded.
local hooked
Follow = function()
    if hooked or not (hooksecurefunc and C_Timer and C_Timer.After) then return end
    hooked = true
    local pending
    local function Changed()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if WantedFont() ~= face then T.Apply() end
        end)
    end
    for _, a in ipairs(UI_ADDONS) do
        local obj = a.get()
        if obj and a.listen then
            pcall(a.listen, obj, Changed)
        elseif obj and type(obj[a.changed]) == "function" then
            hooksecurefunc(obj, a.changed, Changed)
        end
    end
end

-- Applies the settings: fonts, tracked colors, then the window's scale and a redraw.
function T.Apply()
    ApplyFonts()
    for _, paint in ipairs(painters) do paint() end
    if ns.UI and ns.UI.ApplyDisplay then ns.UI.ApplyDisplay() end
end
