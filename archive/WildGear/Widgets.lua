local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The window's building blocks, shared by UI.lua, QuestPanel.lua and
-- Settings.lua: flat dark frames and buttons, title bands, close buttons and
-- text boxes, choice rows, dropdown selectors with their popup list, tabs and
-- scroll bars. Colors come from
-- Theme.lua; what marks a selection takes the accent.
-- Built from plain frames and long-stable templates (no Ace3, no Blizzard
-- dropdowns, whose APIs keep changing between Retail versions).
-- In the Classic theme (T.Classic) each is made of the game's own frame art
-- instead (ART), as its classic windows are: stone borders, red panel
-- buttons, the dropdown frame, the Quest Log's highlights; the window itself
-- is the Auction House's frame (W.ClassicWindow).

local T = ns.Theme
local W = {}
ns.Widgets = W

local MEDIA = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\"

-- The Classic theme's art, by file id (Retail and Forever ship the same files).
local ART = {
    dialogBorder = 131072, dialogBg = 312922, -- UI-DialogBox-Border, UI-DialogBox-Background-Dark
    header = 131080, -- UI-DialogBox-Header: a stone plaque for the title
    tooltipBorder = 137057, tooltipBg = 137056, -- UI-Tooltip-Border, UI-Tooltip-Background
    button = 130828, buttonDown = 130825, buttonOff = 130824, -- UI-Panel-Button-Up, -Down, -Disabled
    buttonHighlight = 130826,
    close = 130832, closeDown = 130830, closeHighlight = 130831, -- UI-Panel-MinimizeButton-*
    corner = 131073, -- UI-DialogBox-Corner: the dialog border's box for a close button
    check = 130755, checkMark = 130751, -- UI-CheckBox-Up, UI-CheckBox-Check
    knob = 130849, -- UI-ScrollBar-Knob
    track = 136569, -- UI-Character-ScrollBar
    up = 130857, upDown = 130855, upOff = 130854, upHighlight = 130856, -- UI-ScrollBar-ScrollUpButton-*
    down = 130853, downDown = 130851, downOff = 130850, downHighlight = 130852, -- ...-ScrollDownButton-*
    dropdown = 131143, dropdownButton = 130952, -- CharacterCreate-LabelFrame, UI-ChatIcon-ScrollDown-Up
    mouseHighlight = 130757, -- UI-Common-MouseHilight
    selected = 136809, hover = 136810, -- UI-QuestLogTitleHighlight, UI-QuestTitleHighlight
    tab = 136564, tabOn = 136544, tabHighlight = 136580, -- UI-Character-InActiveTab, -ActiveTab, -Tab-Highlight
    input = 130975, -- Common-Input-Border
    slot = 130841, -- UI-Quickslot2
    plus = 130838, minus = 130821, -- UI-PlusButton-Up, UI-MinusButton-Up
    marble = 374154, -- UI-Background-Marble
    sliderBorder = 130859, sliderBg = 130858, sliderThumb = 130860, -- UI-SliderBar-Border, -Background, -Button-Horizontal
    portraitMask = 130924, -- TempPortraitAlphaMask
    -- UI-AuctionFrame-Browse-TopLeft, -Top, -TopRight, -BotLeft, -Bot, -BotRight
    tl = 130694, top = 130693, tr = 130695, bl = 130691, bot = 130690, br = 130692,
}

-- Three textures across `owner` in `layer` from a w x h texel file: the box
-- x0..x1, y0..y1 of it with caps of `cap` texels at both ends, drawn `capWidth`
-- wide, the middle stretching; `rise` (optional) lifts their top above the
-- owner's, and `flip` draws them upside down. Returns them as an object with
-- SetFile(file), SetColor(r, g, b, a), SetBlend(mode) and SetShown(on).
local function ThreeSlice(owner, layer, file, w, h, box, cap, capWidth, rise, flip)
    local x0, x1, y0, y1 = box[1], box[2], box[3], box[4]
    local cuts = { { x0, x0 + cap }, { x0 + cap, x1 - cap }, { x1 - cap, x1 } }
    local parts = {}
    for i = 1, 3 do parts[i] = owner:CreateTexture(nil, layer) end
    local left, mid, right = parts[1], parts[2], parts[3]
    left:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, rise or 0)
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(capWidth)
    right:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 0, rise or 0)
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(capWidth)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local top, bottom = y0 / h, y1 / h
    if flip then top, bottom = bottom, top end
    local s = {}
    function s.SetFile(f)
        for i, t in ipairs(parts) do
            t:SetTexture(f)
            t:SetTexCoord(cuts[i][1] / w, cuts[i][2] / w, top, bottom)
        end
    end
    function s.SetColor(r, g, b, a)
        for _, t in ipairs(parts) do t:SetVertexColor(r, g, b, a or 1) end
    end
    function s.SetBlend(mode)
        for _, t in ipairs(parts) do t:SetBlendMode(mode) end
    end
    function s.SetShown(on)
        for _, t in ipairs(parts) do
            if on then t:Show() else t:Hide() end
        end
    end
    s.SetFile(file)
    return s
end

-- ThreeSlice's three textures, three times down: the box's top `top` texels
-- and bottom `bottom` texels keep their height, drawn `scale` of it, and the
-- rows between stretch.
local function NineSlice(owner, layer, file, w, h, box, cap, capWidth, top, bottom, scale)
    local x0, x1, y0, y1 = box[1], box[2], box[3], box[4]
    local cuts = { { x0, x0 + cap }, { x0 + cap, x1 - cap }, { x1 - cap, x1 } }
    local rows = { { y0, y0 + top }, { y0 + top, y1 - bottom }, { y1 - bottom, y1 } }
    local grid = {}
    for r = 1, 3 do
        grid[r] = {}
        for c = 1, 3 do
            local t = owner:CreateTexture(nil, layer)
            t:SetTexture(file)
            t:SetTexCoord(cuts[c][1] / w, cuts[c][2] / w, rows[r][1] / h, rows[r][2] / h)
            grid[r][c] = t
        end
    end
    for r = 1, 3 do
        local left, mid, right = grid[r][1], grid[r][2], grid[r][3]
        left:SetWidth(capWidth)
        right:SetWidth(capWidth)
        if r == 1 then
            left:SetPoint("TOPLEFT")
            right:SetPoint("TOPRIGHT")
        elseif r == 3 then
            left:SetPoint("BOTTOMLEFT")
            right:SetPoint("BOTTOMRIGHT")
        else
            left:SetPoint("TOPLEFT", grid[1][1], "BOTTOMLEFT")
            left:SetPoint("BOTTOMLEFT", grid[3][1], "TOPLEFT")
            right:SetPoint("TOPRIGHT", grid[1][3], "BOTTOMRIGHT")
            right:SetPoint("BOTTOMRIGHT", grid[3][3], "TOPRIGHT")
        end
        if r ~= 2 then
            local height = (r == 1 and top or bottom) * scale
            left:SetHeight(height)
            right:SetHeight(height)
        end
        mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
        mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    end
end

-- A skin's own frame (T.Skin().frame) round `f`, at frame.scale: its corners
-- as drawn, its sides stretched between them. The top left corner is the top
-- right one mirrored and the top edge starts at frame.edge, past the carving
-- the art has at that end of its title bar (where the window's emblem and
-- the side panels' titles go). `plain` (the selectors' lists, the
-- questions): no title bar, the top edge the bottom one upside down.
-- Returns the title bar's height, drawn.
local function SkinFrame(f, fr, plain)
    local w, h, side, top, bottom = fr.size[1], fr.size[2], fr.side, fr.top, fr.bottom
    local function Piece(x0, x1, y0, y1, flip, upsideDown)
        local t = f:CreateTexture(nil, "BORDER")
        t:SetTexture(fr.file)
        if flip then x0, x1 = x1, x0 end
        if upsideDown then y0, y1 = y1, y0 end
        t:SetTexCoord(x0 / w, x1 / w, y0 / h, y1 / h)
        return t
    end
    local cw, th, bh = side * fr.scale, top * fr.scale, bottom * fr.scale
    local tl, tr, topEdge
    if plain then
        th = bh
        tl, tr = Piece(0, side, h - bottom, h, false, true), Piece(w - side, w, h - bottom, h, false, true)
        topEdge = Piece(side, w - side, h - bottom, h, false, true)
    else
        tl, tr = Piece(w - side, w, 0, top, true), Piece(w - side, w, 0, top)
        topEdge = Piece(fr.edge, w - side, 0, top)
    end
    local bl, br = Piece(0, side, h - bottom, h), Piece(w - side, w, h - bottom, h)
    for _, c in ipairs({ { tl, "TOPLEFT", th }, { tr, "TOPRIGHT", th }, { bl, "BOTTOMLEFT", bh }, { br, "BOTTOMRIGHT", bh } }) do
        c[1]:SetPoint(c[2])
        c[1]:SetSize(cw, c[3])
    end
    for _, e in ipairs({ { topEdge, tl, "TOPRIGHT", tr, "BOTTOMLEFT" },
                         { Piece(side, w - side, h - bottom, h), bl, "TOPRIGHT", br, "BOTTOMLEFT" },
                         { Piece(0, side, top, h - bottom), tl, "BOTTOMLEFT", bl, "TOPRIGHT" },
                         { Piece(w - side, w, top, h - bottom), tr, "BOTTOMLEFT", br, "TOPRIGHT" } }) do
        e[1]:SetPoint("TOPLEFT", e[2], e[3])
        e[1]:SetPoint("BOTTOMRIGHT", e[4], e[5])
    end
    return fr.bar * fr.scale
end

-- The skin's frame, if it has one (and the theme is Classic).
local function Framed()
    local skin = T.Classic() and T.Skin()
    return skin and skin.frame
end

-- The skin's small square buttons (T.Skin().icons: down, up, plus, minus),
-- if it has them (and the theme is Classic).
local function Icons()
    local skin = T.Classic() and T.Skin()
    return skin and skin.icons
end

-- Button `b` showing one of a skin's square buttons, `file` (its close
-- button, its icons): lighter on hover, pressed in a pixel, greyed while
-- disabled.
local function SkinIcon(b, file)
    b:SetNormalTexture(file)
    local pushed = b:CreateTexture(nil, "ARTWORK")
    pushed:SetTexture(file)
    pushed:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    pushed:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    pushed:SetVertexColor(0.8, 0.8, 0.8)
    b:SetPushedTexture(pushed)
    local off = b:CreateTexture(nil, "ARTWORK")
    off:SetTexture(file)
    off:SetAllPoints()
    off:SetDesaturated(true)
    off:SetVertexColor(0.6, 0.6, 0.6)
    b:SetDisabledTexture(off)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(file)
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.3)
end

-- How much further in a side panel's contents sit in the Classic theme, inside
-- its thick dialog border (none in the Modern one). A panel that has it is
-- that much wider on each side, so its contents keep their width.
function W.Inset()
    return T.Classic() and 8 or 0
end

-- The font of a control's label (above a selector, before a choice row): grey,
-- or the game's gold in the Classic theme.
function W.LabelFont()
    return T.Classic() and "WildGearFontNormalSmall" or "WildGearFontDisableSmall"
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- Flat background with a 1px border.
function W.Backdrop(f, r, g, b, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
end

-- Flat background without a visible border (it takes the fill's color): the
-- Modern theme's controls and boxes. A border color set later (W.SetActive, a
-- focused text box) still shows.
function W.Fill(f, r, g, b)
    W.Backdrop(f, r, g, b, 1)
    f:SetBackdropBorderColor(r, g, b, 1)
end

-- The side panels' backdrop, at the opacity setting (and the window's, but in
-- the Classic theme: W.ClassicWindow); Classic, the game's dialog boxes' (on
-- a skin's floor, if it has one), or a skin's own frame (on a `popup`, the
-- selectors' lists and the questions, without its title bar).
function W.Window(f, popup)
    if T.Classic() then
        local floor = T.Skin() and T.Skin().floor
        local fr = Framed()
        if fr then
            f:SetBackdrop({ bgFile = floor and floor.file or ART.dialogBg, tile = true,
                tileSize = floor and floor.tile or 32, insets = { left = 6, right = 6, top = popup and 6 or 10, bottom = 6 } })
            if floor then f:SetBackdropColor(floor.dim, floor.dim, floor.dim, 1) end
            SkinFrame(f, fr, popup)
            return
        end
        f:SetBackdrop({ bgFile = floor and floor.file or ART.dialogBg, edgeFile = ART.dialogBorder, tile = true,
            tileSize = floor and floor.tile or 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        if floor then f:SetBackdropColor(floor.dim, floor.dim, floor.dim, 1) end
        -- (The dark background is a little see-through, and a sliver shows
        -- between it and the border on the right and bottom: black under it,
        -- out to the border's solid middle, 8 in, covers both.)
        local under = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        under:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
        under:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
        under:SetColorTexture(0, 0, 0, 1)
        if f.Center then f.Center:SetDrawLayer("BACKGROUND", -7) end
        return
    end
    W.Backdrop(f, T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], 1)
    T.Track(function() f:SetBackdropColor(T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], T.Get("opacity")) end)
end

-- A box of controls in a panel (the Settings panel's): a card a step lighter
-- than the panel, no border; Classic,
-- the game's tooltip border, as its options boxes have. A skin with bubbles
-- (T.Skin().bubble) tints it in their brass, over a darker wash of their wood,
-- so its floor shows faintly and the text on it stays easy to read.
function W.Box(f)
    if T.Classic() then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = ART.tooltipBorder, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        local bubble = T.Skin() and T.Skin().bubble
        if bubble then
            local rim, fill = bubble.rim, bubble.fill
            -- (the border's art is grey: lifted, so the tint shows as brass, not bronze)
            f:SetBackdropBorderColor(math.min(1, rim[1] * 1.3), math.min(1, rim[2] * 1.3), math.min(1, rim[3] * 1.3), 1)
            f:SetBackdropColor(fill[1] * 0.55, fill[2] * 0.55, fill[3] * 0.55, 0.62)
            return
        end
        f:SetBackdropColor(0, 0, 0, 0.3)
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        return
    end
    W.Fill(f, T.BOX[1], T.BOX[2], T.BOX[3])
end

-- Hover look of rows and list items: a faint light; Classic, the Quest Log's.
function W.AddHighlight(button)
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    if T.Classic() then
        hl:SetTexture(ART.hover)
        hl:SetBlendMode("ADD")
        return
    end
    hl:SetColorTexture(1, 1, 1, 0.08)
end

-- The Classic theme's buttons: the game's red panel button, darker while
-- pressed, grey while disabled, with its glow on hover (and, locked, while
-- what it opens is open: W.SetActive). b.face swaps the art (W.StyleChoice).
-- A skin's buttons (T.Skin().button) instead: its normal and pressed art,
-- dimmed while disabled, lit on hover by its glow (the hover art's light
-- added over the normal art: the highlight layer is drawn over the text).
local function SkinButton(b, art)
    local box = { 0, art.size[1], 0, art.size[2] }
    local face = ThreeSlice(b, "BACKGROUND", art.file, art.size[1], art.size[2], box, art.cap, art.capWidth)
    ThreeSlice(b, "HIGHLIGHT", art.glow, art.size[1], art.size[2], box, art.cap, art.capWidth).SetBlend("ADD")
    b.face, b.art = face, art
    b:HookScript("OnMouseDown", function(self)
        if self:IsEnabled() and not self.choice then face.SetFile(art.down) end
    end)
    b:HookScript("OnMouseUp", function(self)
        if self:IsEnabled() and not self.choice then face.SetFile(art.file) end
    end)
    b:HookScript("OnDisable", function()
        face.SetFile(art.file)
        face.SetColor(0.5, 0.5, 0.5)
    end)
    b:HookScript("OnEnable", function(self)
        face.SetColor(1, 1, 1)
        if not self.choice then face.SetFile(art.file) end
    end)
    return b
end

local function ClassicButton(parent, width, height, capWidth)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.classic = true
    local art = T.Skin() and T.Skin().button
    if art then return SkinButton(b, art) end
    local face = ThreeSlice(b, "BACKGROUND", ART.button, 128, 32, { 0, 80, 0, 22 }, 12, capWidth or 10)
    b.face = face
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ART.buttonHighlight)
    hl:SetTexCoord(0, 0.625, 0, 0.6875)
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    b:HookScript("OnMouseDown", function(self)
        if self:IsEnabled() and not self.choice then face.SetFile(ART.buttonDown) end
    end)
    b:HookScript("OnMouseUp", function(self)
        if self:IsEnabled() and not self.choice then face.SetFile(ART.button) end
    end)
    b:HookScript("OnDisable", function() face.SetFile(ART.buttonOff) end)
    b:HookScript("OnEnable", function(self)
        if not self.choice then face.SetFile(ART.button) end
    end)
    return b
end

-- Flat dark button matching the window, in place of the red UIPanelButtonTemplate
-- (Classic: that red button, ClassicButton).
function W.FlatButton(parent, text, width, height)
    if T.Classic() then
        local b = ClassicButton(parent, width, height or 22)
        b:SetNormalFontObject(WildGearFontNormalSmall)
        b:SetHighlightFontObject(WildGearFontHighlightSmall)
        b:SetDisabledFontObject(WildGearFontDisableSmall)
        b:SetText(text)
        return b
    end
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height or 20)
    W.Fill(b, T.SURFACE[1], T.SURFACE[2], T.SURFACE[3])
    W.AddHighlight(b)
    b:SetNormalFontObject(WildGearFontHighlightSmall)
    b:SetText(text)
    return b
end

-- A square button `size` across showing the texture `file`: a FlatButton
-- around it, placed by the caller. Classic: placed here, in a side panel's
-- top left corner as W.CloseButton's in its top right, in the box the dialog
-- border has there turned round, 18 across as the close button's cross, with
-- the game's glow on hover. Lit by W.SetActive as the others.
function W.IconButton(parent, file, size)
    local b, inset
    if T.Classic() then
        b = CreateFrame("Button", nil, parent)
        b:SetSize(18, 18)
        b.classic, inset = true, 0
        local x, y = W.CornerButton()
        b:SetPoint("CENTER", parent, "TOPLEFT", -x, y)
        if not Framed() then -- (a skin's frame: on its title bar)
            local box = b:CreateTexture(nil, "BACKGROUND")
            box:SetTexture(ART.corner)
            box:SetTexCoord(1, 0, 0, 1)
            box:SetSize(32, 32)
            box:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -7)
        end
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(ART.mouseHighlight)
        hl:SetBlendMode("ADD")
    else
        b = W.FlatButton(parent, "", size, size)
        inset = 2
    end
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
    icon:SetTexture(file)
    b.icon = icon
    return b
end

-- The width of the widest of `texts` in the font object named `font`. The
-- ruler is hidden by its own frame's alpha: SetFontObject gives a font string
-- its font's alpha, so its own SetAlpha(0) left the last text measured
-- showing in the screen's corner.
local ruler
function W.TextWidth(font, texts)
    if not ruler then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:SetPoint("TOPLEFT")
        holder:SetSize(1, 1)
        holder:SetAlpha(0)
        ruler = holder:CreateFontString(nil, "OVERLAY")
        ruler:SetPoint("TOPLEFT")
    end
    ruler:SetFontObject(font)
    local width = 0
    for _, text in ipairs(texts) do
        ruler:SetText(text)
        width = math.max(width, ruler:GetStringWidth())
    end
    return width
end

-- Keeps a FlatButton at least as wide as it is now and wide enough for its
-- text in every language, again whenever the text, its size or the font
-- changes. Returns the button.
function W.FitButton(b)
    local minWidth = b:GetWidth()
    local pad = T.Classic() and 24 or 16 -- (the red button's ends take more)
    local function Fit()
        b:SetWidth(math.max(minWidth, W.TextWidth("WildGearFontHighlightSmall", { b:GetText() or "" }) + pad))
    end
    hooksecurefunc(b, "SetText", Fit)
    T.Track(Fit)
    return b
end

-- Widens the font strings row[key] of `rows` (a column, as wide as its first
-- one now) to fit the widest of `texts` in `font`, up to `maxWidth`, again
-- whenever the text size or font changes. The column row[giver], if given,
-- gives up the width it takes.
function W.FitColumn(rows, key, font, texts, maxWidth, giver)
    local base = rows[1][key]:GetWidth()
    local giverBase = giver and rows[1][giver]:GetWidth()
    local width = base
    local function Fit(row)
        row[key]:SetWidth(width)
        if giver then row[giver]:SetWidth(giverBase - (width - base)) end
    end
    -- (rows made later get the same widths: W.FitNewRow)
    rows.fits = rows.fits or {}
    rows.fits[#rows.fits + 1] = Fit
    T.Track(function()
        width = math.min(maxWidth, math.max(base, math.ceil(W.TextWidth(font, texts)) + 2))
        for _, row in ipairs(rows) do Fit(row) end
    end)
end

-- Gives `row`, made after W.FitColumn fitted `rows`, the columns' widths.
function W.FitNewRow(rows, row)
    for _, Fit in ipairs(rows.fits or {}) do Fit(row) end
end

-- A choice-like button's look (`text` its label): tinted toward the accent,
-- the label in it, when `on`; else dark with the label in `off` (r, g, b).
-- No outline either way.
local function Light(b, text, on, off)
    if on then
        local r, g, bl = T.Accent()
        local s = T.SURFACE
        local fr, fg, fb = s[1] + (r - s[1]) * 0.2, s[2] + (g - s[2]) * 0.2, s[3] + (bl - s[3]) * 0.2
        b:SetBackdropColor(fr, fg, fb, 1)
        b:SetBackdropBorderColor(fr, fg, fb, 1)
        if text then text:SetTextColor(r, g, bl) end
    else
        b:SetBackdropColor(T.SURFACE[1], T.SURFACE[2], T.SURFACE[3], 1)
        b:SetBackdropBorderColor(T.SURFACE[1], T.SURFACE[2], T.SURFACE[3], 1)
        if text then text:SetTextColor(off[1], off[2], off[3]) end
    end
end

-- A FlatButton lit in the accent, as a selected choice is, while what it opens
-- is open (Classic: its glow stays on).
function W.SetActive(b, on)
    if b.classic then
        if on then b:LockHighlight() else b:UnlockHighlight() end
        return
    end
    Light(b, b:GetFontString(), on, { 1, 1, 1 })
end

-- Where a side panel's close button's middle is in the Classic theme, from
-- its top right corner (x, y; its icon button's is as far in from the top
-- left): in the dialog border's corner box (the close button's box is 6 in
-- and 7 down from the corner; its hole's middle 20 texels across, 11.5
-- down), or at the end of a skin's frame's title bar.
function W.CornerButton()
    local fr = Framed()
    if fr then return -(fr.side * fr.scale + 15), -fr.bar * fr.scale / 2 end
    return -18, -18.5
end

-- A flat close button: a grey cross that takes the accent on hover, as the
-- selectors' chevron does (Classic: the game's red one; on the window,
-- `framed`, in its frame's box for it, placed by the caller; on a side panel,
-- placed here, in its dialog border's top right corner, on the corner piece
-- the game's dialog boxes have there). A click hides `parent`, or calls onClick.
function W.CloseButton(parent, onClick, framed)
    local art = T.Classic() and T.Skin() and T.Skin().close
    if art then -- (a skin's: one picture, lighter on hover, pressed in a pixel)
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(art.size[1], art.size[2])
        SkinIcon(b, art.file)
        if not framed then
            local x, y = W.CornerButton()
            b:SetPoint("CENTER", parent, "TOPRIGHT", x, y)
        end
        b:SetScript("OnClick", onClick or function() parent:Hide() end)
        return b
    end
    if T.Classic() then
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(framed and 30 or 32, framed and 30 or 32)
        b:SetNormalTexture(ART.close)
        b:SetPushedTexture(ART.closeDown)
        b:SetHighlightTexture(ART.closeHighlight, "ADD")
        if not framed then
            b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -3)
            local corner = b:CreateTexture(nil, "BACKGROUND")
            corner:SetTexture(ART.corner)
            corner:SetSize(32, 32)
            corner:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -7)
        end
        b:SetScript("OnClick", onClick or function() parent:Hide() end)
        return b
    end
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(20, 20)
    W.Fill(b, T.SURFACE[1], T.SURFACE[2], T.SURFACE[3])
    W.AddHighlight(b)
    local cross = b:CreateTexture(nil, "OVERLAY")
    cross:SetSize(10, 10)
    cross:SetPoint("CENTER", b, "CENTER", 0, 0)
    cross:SetTexture(MEDIA .. "Close")
    cross:SetVertexColor(0.75, 0.75, 0.75)
    b:SetScript("OnEnter", function() cross:SetVertexColor(T.Accent()) end)
    b:SetScript("OnLeave", function() cross:SetVertexColor(0.75, 0.75, 0.75) end)
    b:SetScript("OnClick", onClick or function() parent:Hide() end)
    return b
end

-- A flat text box like the selector boxes, a border in the accent while it
-- has focus (Classic: the game's input box); Enter and Escape let go of it.
-- Callers add focus scripts with HookScript, which keeps these.
function W.EditBox(parent, width, height)
    local classic = T.Classic()
    local box = CreateFrame("EditBox", nil, parent, not classic and "BackdropTemplate" or nil)
    box:SetSize(width, height)
    if classic then
        ThreeSlice(box, "BACKGROUND", ART.input, 128, 32, { 0, 128, 0, 20 }, 8, 6)
    else
        W.Fill(box, T.FIELD[1], T.FIELD[2], T.FIELD[3])
    end
    box:SetFontObject(WildGearFontHighlightSmall)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetScript("OnEditFocusGained", function(self)
        if not classic then self:SetBackdropBorderColor(T.Accent()) end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        if not classic then self:SetBackdropBorderColor(T.FIELD[1], T.FIELD[2], T.FIELD[3], 1) end
        self:HighlightText(0, 0)
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

-- The dark band across the top of the window and of each side panel, which
-- dock level with it, so the bands line up in one strip; `text` on the left
-- in `font`. Returns the title and the band.
-- Classic: the band is only a place for what goes on it, inside the thick
-- border (W.Inset), and the title is in the game's stone plaque (or the
-- skin's) over the panel's top edge, as wide as the title (`drop` lower for a
-- frame whose top edge is that far into it: the window's); or, `plain` (a
-- panel that places its title itself), on the left as here.
W.TITLE_HEIGHT = 30
function W.TitleBand(f, text, font, plain, drop)
    local inset = W.Inset()
    local band = f:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + inset, -1 - inset)
    band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1 - inset, -1 - inset)
    band:SetHeight(W.TITLE_HEIGHT)
    local fr = Framed()
    if fr then -- (a skin's frame: the band is its title bar, the title in the middle of it)
        local bar = fr.bar * fr.scale
        band:SetPoint("TOPLEFT", f, "TOPLEFT", 1 + inset, 0)
        band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1 - inset, 0)
        band:SetHeight(bar)
        band:SetColorTexture(0, 0, 0, 0)
        local title
        if plain then
            title = f:CreateFontString(nil, "OVERLAY", font)
            title:SetPoint("LEFT", band, "LEFT", 12, 0)
        else
            -- (in a frame of its own as wide as the title and a little more,
            -- which the window's title takes the hover and the drag on)
            local holder = CreateFrame("Frame", nil, f)
            holder:SetPoint("TOP", f, "TOP", 0, 0)
            holder:SetHeight(bar)
            title = holder:CreateFontString(nil, "OVERLAY", font)
            title:SetPoint("CENTER", holder, "CENTER", 0, 1)
            local function Fit() holder:SetWidth((title:GetStringWidth() or 0) + 24) end
            hooksecurefunc(title, "SetText", Fit)
            T.Track(Fit)
        end
        title:SetText(text)
        return title, band
    end
    if T.Classic() then
        band:SetColorTexture(0, 0, 0, 0)
        if plain then
            local title = f:CreateFontString(nil, "OVERLAY", font)
            title:SetPoint("LEFT", band, "LEFT", 12, 0)
            title:SetText(text)
            return title, band
        end
        local plaque = CreateFrame("Frame", nil, f)
        plaque:SetPoint("CENTER", f, "TOP", 0, -4 - (drop or 0))
        plaque:SetHeight(40)
        local p = T.Skin() and T.Skin().plaque
        if p then
            ThreeSlice(plaque, "ARTWORK", p.file, p.size[1], p.size[2], p.box, p.cap, p.capWidth)
        else
            ThreeSlice(plaque, "ARTWORK", ART.header, 512, 128, { 118, 394, 2, 80 }, 32, 16)
        end
        local title = plaque:CreateFontString(nil, "OVERLAY", font)
        title:SetPoint("CENTER", plaque, "CENTER", 0, 1)
        title:SetWordWrap(false)
        if p and p.color then title:SetTextColor(p.color[1], p.color[2], p.color[3]) end
        local function Fit()
            local room = math.max(110, (f:GetWidth() or 0) - 40)
            plaque:SetWidth(math.min(room, math.max(110, (title:GetStringWidth() or 0) + (p and p.pad or 56))))
            title:SetWidth(math.min(room - 40, (title:GetStringWidth() or 0) + 4))
        end
        hooksecurefunc(title, "SetText", Fit)
        f:HookScript("OnSizeChanged", Fit)
        T.Track(Fit)
        title:SetText(text)
        return title, band
    end
    band:SetColorTexture(0, 0, 0, 0.35)
    local rule = W.Rule(f, 1, 1, 1, 0.08)
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
    local title = f:CreateFontString(nil, "OVERLAY", font)
    title:SetPoint("LEFT", band, "LEFT", 12, 0) -- (a pixel left of the content, 14 in)
    title:SetTextColor(T.TITLE[1], T.TITLE[2], T.TITLE[3])
    title:SetText(text)
    return title, band
end

-- Modern: an icon (texture `file`, `size` across) at the start of the title
-- band `band` (W.TitleBand's), its title `title` moved past it. Returns the
-- icon; nil in the Classic theme, whose window has its portrait ring and
-- side panels their plaques.
function W.TitleIcon(title, band, file, size)
    if T.Classic() then return nil end
    local icon = band:GetParent():CreateTexture(nil, "OVERLAY")
    icon:SetSize(size, size)
    icon:SetPoint("LEFT", band, "LEFT", 10, 0)
    icon:SetTexture(file)
    title:ClearAllPoints()
    title:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    return icon
end

-- Modern: a side panel's own drawn icon before its title, as W.TitleIcon:
-- Media\Panel<name> (flat white, drawn by tools/panelicons.py), in the
-- accent (gold or the class color: Settings). Returns the icon; nil in Classic.
function W.PanelIcon(title, band, name)
    local icon = W.TitleIcon(title, band, "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Panel" .. name, 18)
    if not icon then return nil end
    T.Track(function() icon:SetVertexColor(T.Accent()) end)
    return icon
end

-- Selected-row look for the left lists: faint fill with an accent bar on the
-- left; Classic, the Quest Log's selected title, in the accent.
function W.AddSelection(button)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    if T.Classic() then
        fill:SetTexture(ART.selected)
        fill:SetBlendMode("ADD")
        T.Track(function() fill:SetVertexColor(T.Accent()) end)
        fill:Hide()
        button.selected = fill
        return
    end
    local bar = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetWidth(2)
    T.Track(function()
        fill:SetColorTexture(T.Accent(0.1))
        bar:SetColorTexture(T.Accent())
    end)
    button.selected = {
        Show = function() fill:Show() bar:Show() end,
        Hide = function() fill:Hide() bar:Hide() end,
    }
end

-- Thin horizontal rule.
function W.Rule(parent, r, g, b, a)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(r, g, b, a)
    line:SetHeight(1)
    return line
end

-- A rule fading out to the right (the Classic theme's section headers).
function W.FadeRule(parent, r, g, b, a)
    local line = W.Rule(parent, 1, 1, 1, 1)
    local ok = CreateColor and pcall(line.SetGradient, line, "HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
    if not ok then line:SetColorTexture(r, g, b, a) end
    return line
end

-- The fold sign of a header that folds, centered where the caller puts it: a
-- plus while folded, a minus while open, of two grey bars (Classic: the
-- game's red plus and minus buttons, or a skin's). Returns it, with sign.Set(open).
function W.FoldSign(parent)
    local sign = CreateFrame("Frame", nil, parent)
    sign:SetSize(16, 16)
    if T.Classic() then
        local t = sign:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        local icons = Icons()
        local plus, minus = icons and icons.plus or ART.plus, icons and icons.minus or ART.minus
        sign.Set = function(open)
            sign.open = open
            t:SetTexture(open and minus or plus)
        end
    else
        local h = W.Rule(sign, 0.7, 0.7, 0.7, 1)
        h:SetSize(8, 2)
        h:SetPoint("CENTER")
        local v = W.Rule(sign, 0.7, 0.7, 0.7, 1)
        v:SetSize(2, 8)
        v:SetPoint("CENTER")
        sign.Set = function(open)
            sign.open = open
            if open then v:Hide() else v:Show() end
        end
    end
    sign.Set(false)
    return sign
end

-- An item icon (a texture of the caller's, sized already) in a ring of its
-- item's quality color (W.SetIconQuality), which shows, hides and fades with
-- the icon. Modern: the icon cropped of its own dark edge, in a square 1px
-- ring behind it, so the icon covers all but the ring. Classic and the skins:
-- a 1px ring drawn over the icon's own edge (the icon keeps its art), there
-- only for an uncommon item or better, as the game's own item borders. (Not
-- the game's border art, Interface\Common\WhiteIconFrame: at these sizes only
-- its top edge showed.)
local RING_IDLE = { 0.25, 0.27, 0.31 } -- (no item, or its quality not known yet)

-- Makes texture `tex` show, hide and fade with region `owner` (`shown`, if
-- given, also has to say yes when the owner shows).
local function Follow(tex, owner, shown)
    local function Sync() tex:SetShown(owner:IsShown() and (not shown or shown())) end
    Sync()
    tex:SetAlpha(owner:GetAlpha())
    hooksecurefunc(owner, "Show", Sync)
    hooksecurefunc(owner, "Hide", Sync)
    hooksecurefunc(owner, "SetShown", Sync)
    hooksecurefunc(owner, "SetAlpha", function(_, a) tex:SetAlpha(a) end)
    return Sync
end

function W.IconRing(icon)
    if T.Classic() then
        -- (four lines over the icon's own edge, above a slot frame round it:
        -- W.IconBorder; the sides between the top and bottom lines)
        local parent, parts = icon:GetParent(), {}
        for i = 1, 4 do parts[i] = parent:CreateTexture(nil, "OVERLAY", nil, 2) end
        local top, bottom, left, right = parts[1], parts[2], parts[3], parts[4]
        top:SetPoint("TOPLEFT", icon, "TOPLEFT")
        top:SetPoint("TOPRIGHT", icon, "TOPRIGHT")
        bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
        left:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, -1)
        left:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 1)
        right:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, -1)
        right:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)
        top:SetHeight(1)
        bottom:SetHeight(1)
        left:SetWidth(1)
        right:SetWidth(1)
        local ring = {}
        function ring:SetShown(on) for _, t in ipairs(parts) do t:SetShown(on) end end
        function ring:SetAlpha(a) for _, t in ipairs(parts) do t:SetAlpha(a) end end
        function ring:SetColor(r, g, b) for _, t in ipairs(parts) do t:SetColorTexture(r, g, b, 1) end end
        ring.Sync = Follow(ring, icon, function() return ring.lit end)
        icon.ring = ring
        return ring
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ring = icon:GetParent():CreateTexture(nil, "ARTWORK", nil, -2)
    ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    ring:SetColorTexture(RING_IDLE[1], RING_IDLE[2], RING_IDLE[3], 1)
    Follow(ring, icon)
    icon.ring = ring
    return ring
end

-- Modern: a square chip behind font string `fs` (a number column, right- or
-- left-justified) while its text is a gain, "|cff33ff99+...": a faint green
-- fill as wide as the text and a little more, so a gain stands out from the
-- grey losses beside it. It follows the text's changes, showing and alpha.
-- Nothing in the Classic theme.
local GAIN_PREFIX = "^|c%x%x33ff99%+"
function W.GainChip(fs)
    if T.Classic() then return end
    local chip = fs:GetParent():CreateTexture(nil, "BACKGROUND", nil, 3)
    chip:SetColorTexture(T.GAIN[1], T.GAIN[2], T.GAIN[3], 0.14)
    chip:SetHeight(16)
    local function IsGain()
        local text = fs:GetText()
        return text ~= nil and text:find(GAIN_PREFIX) ~= nil
    end
    local Sync = Follow(chip, fs, IsGain)
    hooksecurefunc(fs, "SetText", function()
        chip:ClearAllPoints()
        local width = math.ceil(fs:GetStringWidth() or 0) + 10
        chip:SetWidth(width)
        if fs:GetJustifyH() == "LEFT" then
            chip:SetPoint("LEFT", fs, "LEFT", -5, 0)
        else
            chip:SetPoint("RIGHT", fs, "RIGHT", 5, 0)
        end
        Sync()
    end)
    fs.chip = chip
    return chip
end

-- Colors an icon's ring (W.IconRing) for item quality `quality` (nil: none):
-- uncommon and up in their color, common a soft white, poor grey. Classic:
-- only uncommon and up have one.
function W.SetIconQuality(icon, quality)
    local ring = icon.ring
    if not ring then return end
    local c = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if ring.Sync then -- (Classic: its four lines)
        ring.lit = c and true or false
        if c then ring:SetColor(c.r, c.g, c.b) end
        return ring.Sync()
    end
    if c then
        ring:SetColorTexture(c.r, c.g, c.b, 0.85)
    elseif quality == 1 then
        ring:SetColorTexture(0.6, 0.6, 0.6, 1)
    elseif quality == 0 then
        ring:SetColorTexture(0.38, 0.38, 0.38, 1)
    else
        ring:SetColorTexture(RING_IDLE[1], RING_IDLE[2], RING_IDLE[3], 1)
    end
end

-- Classic: the game's item slot frame around an item icon (a texture of the
-- caller's, sized already), there for an empty slot too, and inside it the
-- icon's quality ring (W.IconRing). Modern: its ring alone.
function W.IconBorder(icon)
    if not T.Classic() then return W.IconRing(icon) end
    local border = icon:GetParent():CreateTexture(nil, "OVERLAY")
    border:SetTexture(ART.slot)
    border:SetTexCoord(12 / 64, 51 / 64, 12 / 64, 51 / 64) -- (its opening is 31 of these 39 texels)
    local w, h = icon:GetSize()
    border:SetSize((w or 20) * 39 / 31, (h or 20) * 39 / 31)
    border:SetPoint("CENTER", icon, "CENTER")
    W.IconRing(icon)
    return border
end

---------------------------------------------------------------- choices

-- Look of a choice button (Segmented, the slot filter): accent when selected,
-- else dark with grey text (b.text). Classic: a Segmented one is the red panel
-- button with gold text when selected, else the grey (disabled) one; one of
-- its own (a slot chip) gets the list's selected look and white text.
function W.StyleChoice(b, selected)
    if b.segment then -- (Modern, a W.Segmented row's: the selected one raised off its track)
        if selected then
            b:SetBackdropColor(T.RAISED[1], T.RAISED[2], T.RAISED[3], 1)
            b:SetBackdropBorderColor(T.RAISED[1], T.RAISED[2], T.RAISED[3], 1)
            b.text:SetTextColor(T.Accent())
        else
            b:SetBackdropColor(0, 0, 0, 0)
            b:SetBackdropBorderColor(0, 0, 0, 0)
            b.text:SetTextColor(T.DIM[1], T.DIM[2], T.DIM[3])
        end
        return
    end
    if T.Classic() then
        if b.art then -- (a skin's: the hover look, else dimmed)
            b.face.SetFile(selected and b.art.hover or b.art.file)
            b.face.SetColor(selected and 1 or 0.55, selected and 1 or 0.55, selected and 1 or 0.55)
            if selected then b.text:SetTextColor(T.GOLD[1], T.GOLD[2], T.GOLD[3]) else b.text:SetTextColor(0.62, 0.62, 0.62) end
            return
        end
        if b.face then
            b.face.SetFile(selected and ART.button or ART.buttonOff)
            if selected then b.text:SetTextColor(T.GOLD[1], T.GOLD[2], T.GOLD[3]) else b.text:SetTextColor(0.62, 0.62, 0.62) end
            return
        end
        if not b.classicSelected then
            b.classicSelected = b:CreateTexture(nil, "BACKGROUND")
            b.classicSelected:SetAllPoints()
            b.classicSelected:SetTexture(ART.selected)
            b.classicSelected:SetBlendMode("ADD")
        end
        b.classicSelected:SetVertexColor(T.Accent())
        if selected then b.classicSelected:Show() else b.classicSelected:Hide() end
        b.text:SetTextColor(T.LabelColor(selected))
        return
    end
    Light(b, b.text, selected, T.DIM)
end

-- A row of buttons, one per option, the selected one in the accent. Unlike a
-- single toggle button, every choice stays in view, so it is clear what a
-- click does. options = { {key, text, tip}... }; `label` (optional) goes in
-- grey to the left, shown and hidden with the row; an option's `tip` (if
-- any: text, or a function returning it) shows on hover, in a bubble under the
-- row when `bubble` is set (the Settings panel). Returns the row, with row.Update(selectedKey).
-- Modern: one piece, a sunk track as big as the row, the choices on it 2
-- apart and 2 in from its edges, the selected one raised (W.StyleChoice).
function W.Segmented(parent, label, options, width, onPick, bubble)
    local classic = T.Classic()
    local row = CreateFrame("Frame", nil, parent, not classic and "BackdropTemplate" or nil)
    row:SetSize(#options * (width + 2) - 2, 20)
    if not classic then W.Fill(row, T.TRACK[1], T.TRACK[2], T.TRACK[3]) end
    if label then
        row.label = row:CreateFontString(nil, "OVERLAY", W.LabelFont())
        row.label:SetPoint("RIGHT", row, "LEFT", -6, 0)
        row.label:SetText(label)
    end
    row.buttons = {}
    for i, opt in ipairs(options) do
        local b
        if classic then
            b = ClassicButton(row, width, 20, 8)
            b.choice = true -- (its art shows the selection, not a press)
        else
            b = CreateFrame("Button", nil, row, "BackdropTemplate")
            b:SetSize(width, 16) -- (widths and places: Layout below)
            W.Fill(b, T.RAISED[1], T.RAISED[2], T.RAISED[3])
            W.AddHighlight(b)
            b.segment = true
        end
        b.key = opt.key
        b.text = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.text:SetText(opt.text)
        b:SetScript("OnClick", function() onPick(opt.key) end)
        if opt.tip then
            b:SetScript("OnEnter", function(self)
                local tip = type(opt.tip) == "function" and opt.tip() or opt.tip
                if bubble then return W.ShowBubble(row, tip, { pointAt = self }) end
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(opt.text)
                GameTooltip:AddLine(tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function()
                HideTooltip()
                W.HideBubble()
            end)
        end
        row.buttons[i] = b
    end
    -- Even widths while every text fits its share; otherwise each choice as
    -- wide as its text plus an even share of what is left (long words in some
    -- languages), and if even that won't fit, the texts scaled down to fit.
    -- Again on every Update: the text size can change while the row is up.
    local function Layout()
        local n = #row.buttons
        local room = row:GetWidth() - (classic and 0 or 4) - 2 * (n - 1)
        local pad = classic and 16 or 8
        local need, sum, most = {}, 0, 0
        for i, b in ipairs(row.buttons) do
            if b.text.SetTextScale then b.text:SetTextScale(1) end
            need[i] = b.text:GetUnboundedStringWidth() + pad
            sum, most = sum + need[i], math.max(most, need[i])
        end
        local x = classic and 0 or 2
        for i, b in ipairs(row.buttons) do
            local w
            if most <= room / n then
                w = room / n
            elseif sum <= room then
                w = need[i] + (room - sum) / n
            else
                w = room * need[i] / sum
                if b.text.SetTextScale then b.text:SetTextScale(math.max(0.7, room / sum)) end
            end
            b:SetWidth(w)
            b:ClearAllPoints()
            b:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + w + 2
        end
    end
    Layout()
    row.Update = function(key)
        Layout()
        for _, b in ipairs(row.buttons) do W.StyleChoice(b, b.key == key) end
    end
    return row
end

-- A row with a label on the left and an on/off switch on the right; a click
-- anywhere on the row calls onClick. The switch's knob is in the accent when
-- on, and the label dims when off. `tip` (optional) shows in a bubble under the row on hover.
-- Classic: the game's check box, before the label. A skin with a toggle
-- (T.Skin().toggle) keeps the switch, in its own art: its pressed button wood
-- for the track, lit by its glow in the accent when on, and a brass knob.
-- Returns the row, with row.label and row.Update(on).
local function WoodSwitch(row, wood, art)
    local track = CreateFrame("Frame", nil, row)
    track:SetSize(wood.size[1], wood.size[2])
    track:SetPoint("RIGHT", row, "RIGHT", -4 - (wood.knob.size - wood.size[2]) / 2, 0)
    local box = { 0, art.size[1], 0, art.size[2] }
    local face = ThreeSlice(track, "BORDER", art.down, art.size[1], art.size[2], box, art.cap, wood.capWidth)
    local lit = ThreeSlice(track, "ARTWORK", art.glow, art.size[1], art.size[2], box, art.cap, wood.capWidth)
    lit.SetBlend("ADD")
    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(wood.knob.file)
    knob:SetSize(wood.knob.size, wood.knob.size)
    local inset = wood.size[2] / 2 -- (the knob's middle over the track's rounded end)
    row.Update = function(on)
        row.on = on and true or false
        knob:ClearAllPoints()
        if on then
            local r, g, b = T.Accent()
            face.SetFile(art.file)
            face.SetColor(1, 1, 1)
            lit.SetColor(r, g, b, 0.9)
            lit.SetShown(true)
            knob:SetPoint("CENTER", track, "RIGHT", -inset, 0)
            knob:SetDesaturated(false)
            knob:SetVertexColor(1, 1, 1)
        else
            face.SetFile(art.down)
            face.SetColor(0.6, 0.6, 0.6)
            lit.SetShown(false)
            knob:SetPoint("CENTER", track, "LEFT", inset, 0)
            knob:SetDesaturated(true)
            knob:SetVertexColor(0.8, 0.8, 0.8)
        end
        row.label:SetAlpha(on and 1 or 0.55)
    end
    return wood.size[1] + 8 + wood.knob.size - wood.size[2] -- (the label stops this far from the row's right)
end

-- Whether this session's on/off controls are switches, as the Modern theme's
-- (a skin with its own: T.Skin().toggle), not the Classic theme's check boxes.
function W.Switches()
    if not T.Classic() then return true end
    local skin = T.Skin()
    return skin and skin.toggle and skin.button and true or false
end

function W.ToggleRow(parent, width, onClick, tip)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, 20)
    row.toggle = true
    W.AddHighlight(row)
    row.label = row:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row:SetScript("OnClick", onClick)
    if tip then
        row:SetScript("OnEnter", function(self) W.ShowBubble(self, tip) end)
        row:SetScript("OnLeave", W.HideBubble)
    end

    if T.Classic() and W.Switches() then
        local skin = T.Skin()
        row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -WoodSwitch(row, skin.toggle, skin.button), 0)
        row.Update(false)
        return row
    end
    if T.Classic() then
        local box = row:CreateTexture(nil, "ARTWORK")
        box:SetSize(24, 24)
        box:SetPoint("LEFT", row, "LEFT", 0, 0)
        box:SetTexture(ART.check)
        local mark = row:CreateTexture(nil, "OVERLAY")
        mark:SetAllPoints(box)
        mark:SetTexture(ART.checkMark)
        row.label:SetPoint("LEFT", box, "RIGHT", 2, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.Update = function(on)
            row.on = on and true or false
            if on then mark:Show() else mark:Hide() end
            row.label:SetAlpha(on and 1 or 0.55)
        end
        row.Update(false)
        return row
    end
    row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -38, 0)

    -- (square and quiet: a sunk track with a thin edge, the same on and off;
    -- on, its knob at the right end in the accent; off, a grey one at the left)
    local track = CreateFrame("Frame", nil, row, "BackdropTemplate")
    track:SetSize(28, 14)
    track:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    W.Fill(track, T.TRACK[1], T.TRACK[2], T.TRACK[3])
    track:SetBackdropBorderColor(T.RAISED[1], T.RAISED[2], T.RAISED[3], 1)
    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetSize(8, 8)

    row.Update = function(on)
        row.on = on and true or false
        knob:ClearAllPoints()
        if on then
            knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
            knob:SetColorTexture(T.Accent())
            row.label:SetAlpha(1)
        else
            knob:SetPoint("LEFT", track, "LEFT", 3, 0)
            knob:SetColorTexture(0.35, 0.38, 0.43, 1)
            row.label:SetAlpha(0.55)
        end
    end
    row.Update(false)
    return row
end

-- Modern: a small square chip, for one of a few options that are each on or
-- off (a source's own filters in the Settings panel), several to a line: its
-- label after a dot. On, raised with the dot in the accent; off, sunk and
-- dimmed. A click calls onClick. Returns the chip, with chip.label,
-- chip.Update(on) and chip.Fit(max): sizes it to its label, `max` wide at
-- most, and returns its width.
function W.Chip(parent, onClick)
    local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
    chip:SetSize(40, 20)
    chip.toggle, chip.chip = true, true
    W.Fill(chip, T.TRACK[1], T.TRACK[2], T.TRACK[3])
    W.AddHighlight(chip)
    local dot = chip:CreateTexture(nil, "OVERLAY")
    dot:SetSize(6, 6)
    dot:SetPoint("LEFT", chip, "LEFT", 7, 0)
    chip.label = chip:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    chip.label:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    chip.label:SetPoint("RIGHT", chip, "RIGHT", -7, 0)
    chip.label:SetJustifyH("LEFT")
    chip.label:SetWordWrap(false)
    chip:SetScript("OnClick", onClick)
    chip.Fit = function(max)
        local t = chip.label
        local text = t.GetUnboundedStringWidth and t:GetUnboundedStringWidth() or t:GetStringWidth() or 0
        local width = math.min(max, math.ceil(text) + 27) -- (the dot and the space round it and the label)
        chip:SetWidth(width)
        return width
    end
    chip.Update = function(on)
        chip.on = on and true or false
        local fill = on and T.RAISED or T.TRACK
        chip:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        chip:SetBackdropBorderColor(fill[1], fill[2], fill[3], 1)
        if on then
            dot:SetColorTexture(T.Accent())
        else
            dot:SetColorTexture(T.RAISED[1], T.RAISED[2], T.RAISED[3], 1)
        end
        chip.label:SetAlpha(on and 1 or 0.55)
    end
    chip.Update(false)
    return chip
end

-- A range of whole numbers, `minV` to `maxV`, on a track `width` wide: two
-- thumbs, the part between them lit in the accent. Drag a thumb, or click the
-- track to bring the nearer thumb there. onChange(lo, hi) runs while a thumb
-- moves (each step), onDone(lo, hi) when it is let go. Classic: the game's
-- options slider and its gem thumbs, the range lit in the accent (a skin's
-- color). Returns the slider, with slider.Set(lo, hi).
function W.RangeSlider(parent, width, minV, maxV, onChange, onDone)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s:EnableMouse(true)
    s.lo, s.hi = minV, maxV
    local classic = T.Classic()
    local track = CreateFrame("Frame", nil, s, "BackdropTemplate")
    track:SetPoint("LEFT", s, "LEFT", 0, 0)
    track:SetPoint("RIGHT", s, "RIGHT", 0, 0)
    local inset -- (how far in from each end a thumb's middle stops)
    if classic then
        track:SetHeight(17)
        track:SetBackdrop({ bgFile = ART.sliderBg, edgeFile = ART.sliderBorder, tile = true, tileSize = 8,
            edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
        inset = 8
    else
        track:SetHeight(6)
        W.Fill(track, T.FIELD[1], T.FIELD[2], T.FIELD[3])
        inset = 5
    end
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(classic and 5 or 4)
    local thumbs = {}
    for i = 1, 2 do
        local t = CreateFrame("Button", nil, s, not classic and "BackdropTemplate" or nil)
        if classic then
            t:SetSize(32, 32)
            t:SetNormalTexture(ART.sliderThumb)
        else
            t:SetSize(10, 16)
            t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            t:SetBackdropBorderColor(0.04, 0.05, 0.09, 1)
        end
        t:SetFrameLevel(track:GetFrameLevel() + 2)
        thumbs[i] = t
    end
    T.Track(function()
        local r, g, b = T.Accent()
        fill:SetColorTexture(r, g, b, classic and 0.6 or 1)
        if not classic then
            for _, t in ipairs(thumbs) do t:SetBackdropColor(r, g, b, 1) end
        end
    end)

    local function X(v)
        return inset + (v - minV) / math.max(1, maxV - minV) * (s:GetWidth() - 2 * inset)
    end
    local function Place()
        local a, b = X(s.lo), X(s.hi)
        for i, t in ipairs(thumbs) do
            t:ClearAllPoints()
            t:SetPoint("CENTER", s, "LEFT", i == 1 and a or b, 0)
        end
        fill:ClearAllPoints()
        fill:SetPoint("LEFT", s, "LEFT", a, 0)
        fill:SetWidth(math.max(1, b - a))
    end

    -- The value under the cursor (nil without one).
    local function ValueAt()
        local cx = GetCursorPosition and GetCursorPosition()
        local left = s:GetLeft()
        if not (cx and left) then return nil end
        local f = (cx / s:GetEffectiveScale() - left - inset) / math.max(1, s:GetWidth() - 2 * inset)
        return math.floor(minV + math.max(0, math.min(1, f)) * (maxV - minV) + 0.5)
    end
    local dragging
    local function Move(v)
        if not v then return end
        -- (thumbs on one value: the one dragged is the one on the side moved to)
        if s.lo == s.hi then dragging = (v < s.lo and 1) or (v > s.hi and 2) or dragging end
        local lo, hi = s.lo, s.hi
        if dragging == 1 then s.lo = math.min(v, s.hi) else s.hi = math.max(v, s.lo) end
        if s.lo ~= lo or s.hi ~= hi then
            Place()
            if onChange then onChange(s.lo, s.hi) end
        end
    end
    local function Stop()
        if not dragging then return end
        dragging = nil
        s:SetScript("OnUpdate", nil)
        if onDone then onDone(s.lo, s.hi) end
    end
    local function Start(i)
        dragging = i
        s:SetScript("OnUpdate", function()
            if not (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then return Stop() end
            Move(ValueAt())
        end)
    end
    for i, t in ipairs(thumbs) do
        t:SetScript("OnMouseDown", function() Start(i) end)
        t:SetScript("OnMouseUp", Stop)
    end
    s:SetScript("OnMouseDown", function()
        local v = ValueAt()
        if not v then return end
        Start(math.abs(v - s.lo) <= math.abs(v - s.hi) and v <= s.hi and 1 or 2)
        Move(v)
    end)
    s:SetScript("OnMouseUp", Stop)
    s:SetScript("OnHide", Stop)

    s.Set = function(lo, hi)
        s.lo, s.hi = math.max(minV, math.min(lo, maxV)), math.max(minV, math.min(hi, maxV))
        if s.lo > s.hi then s.lo, s.hi = s.hi, s.lo end
        Place()
    end
    s.Dragging = function() return dragging ~= nil end
    s.thumbs = thumbs
    Place()
    return s
end

---------------------------------------------------------------- popup list

local popup

function W.HidePopup()
    if popup then popup:Hide() end
end

-- The window `f` lies in: its ancestor that UIParent holds (the addon's
-- window, the game's Character frame...), else its topmost one.
local function TopWindow(f)
    while f:GetParent() and f:GetParent() ~= UIParent do f = f:GetParent() end
    return f
end

-- The list a selector opens under `anchor`: options = { {text, value, selected, icon?, crop?}... }.
-- Classic: in the game's dialog border (or a skin's frame), the selected one checked.
-- icon: a texture before the text, POPUP_ICON across (crop: a game icon's
-- border trimmed), its list's rows then ICON_ROW tall.
-- It goes in the window the box lies in (not in any scrolling list there,
-- which would cut it), at the box's own scale: beside the Character frame,
-- the game's, not the addon's window's; and hides with that window.
local POPUP_ICON, ICON_ROW = 20, 24
function W.ShowPopup(anchor, options, onPick)
    local classic = T.Classic()
    local inset = classic and 14 or 4
    local rowH, lead = 18, classic and 20 or 18 -- (lead: past the check, or the Modern theme's ">")
    for _, opt in ipairs(options) do
        if opt.icon then rowH = ICON_ROW end
    end
    if not popup then
        popup = CreateFrame("Frame", nil, ns.UI.Frame(), "BackdropTemplate")
        if classic then
            W.Window(popup, true)
        else
            W.Backdrop(popup, 0.05, 0.05, 0.05, 0.97)
        end
        popup.buttons = {}
        popup.notNeighbor = true -- (in the Character frame: not another addon's panel to make room for)
    end
    if popup:IsShown() and popup.anchor == anchor then
        popup:Hide()
        return
    end
    local top = TopWindow(anchor)
    if popup:GetParent() ~= top then popup:SetParent(top) end
    popup:SetScale(anchor:GetEffectiveScale() / top:GetEffectiveScale())
    popup:SetFrameStrata("DIALOG") -- (again: a new parent's would be taken)
    for i, opt in ipairs(options) do
        local b = popup.buttons[i]
        if not b then
            b = CreateFrame("Button", nil, popup)
            b.text = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetSize(POPUP_ICON, POPUP_ICON)
            b.icon:SetPoint("LEFT", b, "LEFT", lead, 0)
            if classic then
                b.check = b:CreateTexture(nil, "ARTWORK")
                b.check:SetSize(16, 16)
                b.check:SetPoint("LEFT", b, "LEFT", 1, 0)
            else
                b.mark = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
                b.mark:SetPoint("LEFT", b, "LEFT", 6, 0)
            end
            W.AddHighlight(b)
            popup.buttons[i] = b
        end
        -- (opt.spot: the option pointed out, under a soft light in the
        -- accent, breathing, until the list closes)
        if opt.spot and not b.spot then
            b.spot = CreateFrame("Frame", nil, b)
            b.spot:SetAllPoints()
            b.spot.shine = b.spot:CreateTexture(nil, "BACKGROUND")
            b.spot.shine:SetAllPoints()
            b.spot.shine:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.spot.shine:SetBlendMode("ADD")
            b.spot.pulse = b.spot:CreateAnimationGroup()
            b.spot.pulse:SetLooping("BOUNCE")
            local fade = b.spot.pulse:CreateAnimation("Alpha")
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0.3)
            fade:SetDuration(0.75)
            fade:SetSmoothing("IN_OUT")
        end
        if opt.spot then
            local r, g, bl = T.Accent()
            b.spot.shine:SetVertexColor(r, g, bl, 0.35)
            b.spot:Show()
            b.spot.pulse:Play()
        elseif b.spot then
            b.spot.pulse:Stop()
            b.spot:Hide()
        end
        b:SetHeight(rowH)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", popup, "TOPLEFT", inset, -inset - (i - 1) * rowH)
        b:SetPoint("RIGHT", popup, "RIGHT", -inset, 0)
        b.text:ClearAllPoints()
        if opt.icon then
            b.icon:SetTexture(opt.icon)
            if opt.crop then b.icon:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64) else b.icon:SetTexCoord(0, 1, 0, 1) end
            b.icon:Show()
            b.text:SetPoint("LEFT", b, "LEFT", lead + POPUP_ICON + 5, 0)
        else
            b.icon:Hide()
            b.text:SetPoint("LEFT", b, "LEFT", lead, 0)
        end
        b.text:SetText(opt.text)
        if classic then
            local mark = T.SkinPart("check") -- (a skin's own: Elwynn's oak leaf)
            b.check:SetTexture(mark and mark.file or ART.checkMark)
            b.check:SetRotation(mark and mark.tilt and -math.rad(mark.tilt) or 0) -- (clockwise)
            if opt.selected then b.check:Show() else b.check:Hide() end
        else
            b.mark:SetText(opt.selected and (T.AccentHex() .. ">|r") or "")
        end
        b:SetScript("OnClick", function()
            popup:Hide()
            onPick(opt.value)
        end)
        b:Show()
    end
    for i = #options + 1, #popup.buttons do popup.buttons[i]:Hide() end
    local width = math.max(anchor:GetWidth(), 150)
    local room = 2 * inset + lead + 6
    for i = 1, #options do
        local icon = options[i].icon and POPUP_ICON + 5 or 0
        width = math.max(width, popup.buttons[i].text:GetStringWidth() + icon + room)
    end
    popup:SetSize(width, #options * rowH + 2 * inset)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    popup.anchor = anchor
    popup:Show()
end

---------------------------------------------------------------- selectors

-- The mouse wheel icon before a selector's hint at the end of its tooltip, in grey as the line.
local WHEEL_GREY = "|TInterface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\MouseWheel:0:0:0:0:32:32:0:32:0:32:153:153:153|t "

---------------------------------------------------------------- bubbles

-- Small tooltips in the window's look, all alike: a bubble under `anchor`, as
-- wide as it (at least opts.width, or BUBBLE_MIN), its pointer at the middle of opts.pointAt
-- (default: the anchor). Its text wraps, a point over the window's small text,
-- on the window's background tinted a little toward the accent color, so it
-- stands apart from the text around it. opts.icon (a selector's "Scroll to
-- change") puts the mouse wheel icon before the text, in a soft glow of the
-- accent color. One bubble, moved to what is hovered.
local NOTCH_W, NOTCH_H, BUBBLE_MIN, PAD_X, PAD_Y = 10, 5, 100, 8, 7
local bubble
-- (Classic: the game's tooltip, its pointer bigger and on the tooltip
-- border's line, 3 pixels in (TIP_LINE): as light as the line's top edge,
-- filled as dark as the tooltip looks, the fill down over the line and its
-- shadow; a skin's with buttons (T.Skin().button, .bubble): their pressed
-- wood in a brass rim, pointer and all.)
local TIP_NOTCH_W, TIP_NOTCH_H, TIP_LINE, TIP_CORNER = 16, 8, 3, 14
local function Bubble()
    if bubble then return bubble end
    bubble = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    local skin = T.Classic() and T.Skin()
    if skin and skin.button and skin.bubble then
        local art = skin.button
        bubble:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        bubble.wood = bubble:CreateTexture(nil, "BACKGROUND")
        bubble.wood:SetPoint("TOPLEFT", bubble, "TOPLEFT", 2, -2)
        bubble.wood:SetPoint("BOTTOMRIGHT", bubble, "BOTTOMRIGHT", -2, 2)
        bubble.wood:SetTexture(art.down)
        local cap = art.cap / art.size[1] -- (its middle: no brass ends, no rim)
        bubble.wood:SetTexCoord(cap, 1 - cap, 0.25, 0.75)
        bubble.skin = skin.bubble
    elseif T.Classic() then
        bubble:SetBackdrop({ bgFile = ART.tooltipBg, edgeFile = ART.tooltipBorder, tile = true, tileSize = 16,
            edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    else
        W.Backdrop(bubble, T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], 0.97)
    end
    -- The pointer: a border-colored triangle above the bubble, and a fill one
    -- over it that also covers the bubble's top border beneath it.
    bubble.edge = bubble:CreateTexture(nil, "OVERLAY", nil, 1)
    bubble.edge:SetSize(NOTCH_W + 2, NOTCH_H + 1)
    bubble.edge:SetTexture(MEDIA .. "Notch")
    bubble.edge:SetVertexColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
    bubble.fill = bubble:CreateTexture(nil, "OVERLAY", nil, 2)
    bubble.fill:SetSize(NOTCH_W, NOTCH_H)
    bubble.fill:SetTexture(MEDIA .. "Notch")
    if T.Classic() and not bubble.skin then
        bubble.edge:SetSize(TIP_NOTCH_W, TIP_NOTCH_H)
        bubble.fill:SetSize(TIP_NOTCH_W, TIP_NOTCH_H)
    end
    bubble.fill:SetVertexColor(T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], 1)
    bubble.icon = bubble:CreateTexture(nil, "OVERLAY")
    bubble.icon:SetSize(10, 10)
    bubble.icon:SetPoint("TOPLEFT", bubble, "TOPLEFT", PAD_X - 1, -(PAD_Y + 1)) -- (by the first line)
    bubble.icon:SetTexture(MEDIA .. "MouseWheel")
    bubble.glow = bubble:CreateTexture(nil, "ARTWORK")
    bubble.glow:SetSize(22, 22)
    bubble.glow:SetPoint("CENTER", bubble.icon, "CENTER", 0, 0)
    bubble.glow:SetTexture(MEDIA .. "Glow")
    bubble.glow:SetBlendMode("ADD")
    bubble.text = bubble:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    bubble.text:SetJustifyH("LEFT")
    bubble.text:SetWordWrap(true)
    bubble.text:SetSpacing(2)
    return bubble
end

-- `base` (a palette color) moved `share` of the way to the accent.
local function TowardAccent(base, share)
    local r, g, b = T.Accent()
    return base[1] + (r - base[1]) * share, base[2] + (g - base[2]) * share, base[3] + (b - base[3]) * share
end

function W.ShowBubble(anchor, text, opts)
    opts = opts or {}
    local b = Bubble()
    -- (It goes with the anchor; in a frame that scrolls, which would cut it
    -- off, with the frame around that.)
    local parent, up = anchor, anchor:GetParent()
    while up do
        if up:IsObjectType("ScrollFrame") then
            parent = up:GetParent()
            break
        end
        up = up:GetParent()
    end
    b:SetParent(parent)
    b:SetFrameStrata("TOOLTIP")
    local width = math.max(anchor:GetWidth() or 0, opts.width or BUBBLE_MIN)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(NOTCH_H + 2))
    b:SetWidth(width)

    -- The pointer under the middle of opts.pointAt, kept off the corners.
    local x = 0
    local left, mid = anchor:GetLeft(), (opts.pointAt or anchor):GetCenter()
    local corner = (T.Classic() and not b.skin) and TIP_CORNER or 8
    if left and mid then x = math.max(-(width / 2 - corner), math.min(width / 2 - corner, mid - left - width / 2)) end
    b.edge:ClearAllPoints()
    b.edge:SetPoint("BOTTOM", b, "TOP", x, 0)
    b.fill:ClearAllPoints()
    b.fill:SetPoint("BOTTOM", b, "TOP", x, -1)

    -- The tint, on the bubble and on its pointer alike (it follows the accent
    -- setting); Classic, the game's tooltip colors; a skin's, its own.
    if b.skin then
        local rim, fill = b.skin.rim, b.skin.fill
        b:SetBackdropBorderColor(rim[1], rim[2], rim[3], 1)
        b.edge:SetVertexColor(rim[1], rim[2], rim[3], 1)
        b.fill:SetVertexColor(fill[1], fill[2], fill[3], 1)
        b.fill:ClearAllPoints()
        b.fill:SetPoint("BOTTOM", b, "TOP", x, -2) -- (over the rim's 2 pixels)
    elseif T.Classic() then
        b:SetBackdropColor(0.09, 0.09, 0.19, 0.95)
        b:SetBackdropBorderColor(1, 1, 1, 1)
        b.edge:SetVertexColor(0.91, 0.91, 0.91, 1)
        b.fill:SetVertexColor(0.05, 0.05, 0.105, 1) -- (the tooltip's grey tile, tinted as above)
        b.edge:ClearAllPoints()
        b.edge:SetPoint("BOTTOM", b, "TOP", x, -TIP_LINE)
        b.fill:ClearAllPoints()
        b.fill:SetPoint("BOTTOM", b, "TOP", x, -(TIP_LINE + 2))
    else
        local fr, fg, fb = TowardAccent(T.WINDOW, 0.12)
        local er, eg, eb = TowardAccent(T.BORDER, 0.3)
        b:SetBackdropColor(fr, fg, fb, 0.97)
        b:SetBackdropBorderColor(er, eg, eb, 1)
        b.fill:SetVertexColor(fr, fg, fb, 1)
        b.edge:SetVertexColor(er, eg, eb, 1)
    end
    b.glow:SetVertexColor(T.Accent(0.6))
    if opts.icon then b.icon:Show() b.glow:Show() else b.icon:Hide() b.glow:Hide() end

    local t = b.text
    t:ClearAllPoints()
    t:SetFontObject(WildGearFontHighlightSmall)
    local path, size, flags = WildGearFontHighlightSmall:GetFont()
    if path and size then t:SetFont(path, math.floor(size + 0.5) + 1, flags or "") end
    t:SetText(text)
    t:SetPoint("TOPLEFT", b, "TOPLEFT", opts.icon and (PAD_X + 10 + 3) or PAD_X, -PAD_Y)
    t:SetPoint("TOPRIGHT", b, "TOPRIGHT", -PAD_X, -PAD_Y)
    b:SetHeight(math.max(18, (t:GetStringHeight() or 10) + 2 * PAD_Y))
    b:Show()
end

function W.HideBubble()
    if bubble then bubble:Hide() end
end

-- A question that's hard to miss, right where you are: a box under `anchor`
-- (its right edge lined up with the anchor's, its pointer at the anchor's
-- middle) on the bubbles' tinted background, its border in the accent and a
-- halo around it in the accent, pulsing. `text` (it wraps), then two
-- buttons: `yes` lit in the accent, which runs onYes, and `no`; either
-- closes it. The game's invite sound plays as it opens. It goes when the
-- anchor hides. One at a time.
-- (Classic: in the game's dialog border, as its own questions are, which
-- takes more room around the text and buttons: CONFIRM_EDGE.)
local CONFIRM_W, CONFIRM_BUTTON = 240, 70
local CONFIRM_EDGE = 0
local confirm, coach

-- (Classic: the pointer is art of its own, a wedge of the dialog border's
-- metal (a skin with a frame: skin.pointer, of its wood; none: no pointer),
-- drawn over the border with its base `depth` in, across the bar, where it
-- fades out (tools\skinart.py, FADES): it grows out of the bar. The halo goes
-- under it. Its middle is kept `inset` from the box's corners, clear of the
-- corner pieces: by a narrower anchor the box moves out past it.)
local CLASSIC_POINTER = { file = MEDIA .. "Classic\\DialogPointer", size = { 38, 21 }, depth = 11, inset = 26 }
local function BoxPointer()
    if not T.Classic() then return nil end
    local skin = T.Skin()
    if skin and skin.frame then return skin.pointer end
    return CLASSIC_POINTER
end
-- The box (W.Confirm's, W.Coach's): text, `yes` (runs c.onYes) and `no`
-- (c.onNo) at its foot, either closing it first.
local function QuestionBox()
    local c = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    if T.Classic() then
        W.Window(c, true)
        CONFIRM_EDGE = 8
    else
        W.Backdrop(c, T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], 0.98)
    end
    c:SetWidth(CONFIRM_W + 2 * CONFIRM_EDGE)
    c:EnableMouse(true)
    c.halo = CreateFrame("Frame", nil, c, "BackdropTemplate")
    c.halo:SetPoint("TOPLEFT", c, "TOPLEFT", -3, 3)
    c.halo:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 3, -3)
    c.halo:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    c.pulse = c.halo:CreateAnimationGroup()
    c.pulse:SetLooping("BOUNCE")
    local fade = c.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.9)
    fade:SetToAlpha(0.15)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    c.edge = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.edge:SetSize(NOTCH_W + 2, NOTCH_H + 1)
    c.edge:SetTexture(MEDIA .. "Notch")
    c.fill = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.fill:SetSize(NOTCH_W, NOTCH_H)
    c.fill:SetTexture(MEDIA .. "Notch")
    local tab = BoxPointer()
    if tab then
        c.tab = c:CreateTexture(nil, "ARTWORK") -- (over the border's every piece)
        c.tab:SetTexture(tab.file)
        c.tab:Hide()
    end
    local edge = CONFIRM_EDGE
    -- (its width set, not taken from the box's corners: measured before the
    -- box was placed, it came out one line, the rest cut off with "...")
    c.text = c:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    c.text:SetPoint("TOPLEFT", c, "TOPLEFT", PAD_X + 2 + edge, -(PAD_Y + 3 + edge))
    c.text:SetWidth(CONFIRM_W - 2 * (PAD_X + 2))
    c.text:SetJustifyH("LEFT")
    c.text:SetWordWrap(true)
    c.text:SetSpacing(2)
    c.yes = W.FitButton(W.FlatButton(c, "", CONFIRM_BUTTON, 20)) -- (wider for a long word: "Überspringen")
    c.yes:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -(PAD_X + edge), PAD_Y + 1 + edge)
    c.yes:SetScript("OnClick", function()
        c:Hide()
        if c.macro then -- (the secure button wasn't there: combat)
            if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
        elseif c.onYes then
            c.onYes()
        end
    end)
    c.no = W.FitButton(W.FlatButton(c, "", CONFIRM_BUTTON, 20))
    c.no:SetPoint("RIGHT", c.yes, "LEFT", -6, 0)
    c.no:SetScript("OnClick", function()
        c:Hide()
        if c.onNo then c.onNo() end
    end)
    c:SetScript("OnHide", function()
        c.pulse:Stop()
        if c.secure and not InCombatLockdown() then
            c.secure:Hide()
            c.secure:ClearAllPoints()
        end
    end)
    return c
end

local function Confirm()
    if not confirm then
        confirm = QuestionBox()
        confirm.isConfirm = true
    end
    return confirm
end

-- A `yes` that runs a protected command (ReloadUI is one: called from the
-- addon it's blocked, "Interface action failed because of an AddOn") runs
-- it as a macro from an invisible secure button over `yes`, its PreClick
-- running onYes first. The button hangs off UIParent so the window doesn't
-- become protected, and goes (with its anchor) as combat starts; in combat
-- `yes` says so.
local function SecureYes(c)
    if c.secure then return c.secure end
    local s = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    s:SetFrameStrata("DIALOG")
    s:RegisterForClicks("LeftButtonUp", "LeftButtonDown") -- (it acts on the one ActionButtonUseKeyDown picks)
    s:SetAttribute("type", "macro")
    s:SetScript("PreClick", function() if c.onYes then c.onYes() end end)
    s:SetScript("OnEnter", function() c.yes:LockHighlight() end)
    s:SetScript("OnLeave", function() if not c.yes.classic then c.yes:UnlockHighlight() end end) -- (Classic: locked lit)
    s:RegisterEvent("PLAYER_REGEN_DISABLED")
    s:SetScript("OnEvent", function(self)
        self:Hide()
        self:ClearAllPoints()
    end)
    s:Hide()
    c.secure = s
    return s
end

-- Its parent is the anchor (a font string: its frame), so it scales and goes
-- with it, unless the anchor is in a scroll frame, which would cut it off:
-- then that frame's parent, and it goes when the anchor hides. Returns the
-- parent, and the anchor's frame.
local function ConfirmParent(anchor)
    if anchor.GetObjectType and anchor:GetObjectType() == "FontString" then anchor = anchor:GetParent() end
    local parent, f = anchor, anchor
    while f do
        if f.GetObjectType and f:GetObjectType() == "ScrollFrame" then parent = f:GetParent() end
        f = f:GetParent()
    end
    if parent ~= anchor and not anchor.confirmHooked then
        anchor.confirmHooked = true
        anchor:HookScript("OnHide", function(self)
            if confirm and confirm.anchor == self then confirm:Hide() end
            if coach and coach.anchor == self then coach:Hide() end
        end)
    end
    return parent, anchor
end

-- Shows box `c` by `anchor`: under it (o.above, or an anchor near the
-- screen's bottom: over it, the pointer turned over), its right edge lined
-- up with the anchor's (o.left: its left edge),
-- its pointer at the anchor's middle; `text` in it, then the buttons o.yes
-- and o.no (nil: left out), and their row (o.row: kept without them).
local function ShowBox(c, anchor, text, o)
    local parent, frame = ConfirmParent(anchor)
    c:SetParent(parent)
    c.anchor = frame
    c:SetFrameStrata("DIALOG")
    c:ClearAllPoints()
    local side = o.left and "LEFT" or "RIGHT"
    -- (over the anchor too when that is low on the screen, where a box under
    -- it would run off the bottom: the wish list panel's Clear all. 120: a
    -- question of three lines with its buttons and pointer.)
    local low = anchor.GetBottom and anchor:GetBottom()
    local above = o.above or (low ~= nil and low < 120)
    local corner = (above and "BOTTOM" or "TOP") .. side
    local tab = c.tab and BoxPointer()
    if tab then c.halo:SetFrameLevel(math.max(0, c:GetFrameLevel() - 1)) end -- (under the pointer, not across it)
    local half = (anchor:GetWidth() or 20) / 2
    local x = math.max(tab and tab.inset or 10, half)
    local gap = tab and (tab.size[2] - tab.depth + 2) or NOTCH_H + 3
    local shift = tab and (half - x) or 0 -- (the box out past a narrow anchor)
    if not o.left then x, shift = -x, -shift end
    if above then
        c:SetPoint(corner, anchor, "TOP" .. side, shift, gap)
    else
        c:SetPoint(corner, anchor, "BOTTOM" .. side, shift, -gap)
    end
    c.edge:ClearAllPoints()
    c.fill:ClearAllPoints()
    if above then
        c.edge:SetPoint("TOP", c, corner, x, 0)
        c.fill:SetPoint("TOP", c, corner, x, 1)
        c.edge:SetTexCoord(0, 1, 1, 0)
        c.fill:SetTexCoord(0, 1, 1, 0)
    else
        c.edge:SetPoint("BOTTOM", c, corner, x, 0)
        c.fill:SetPoint("BOTTOM", c, corner, x, -1)
        c.edge:SetTexCoord(0, 1, 0, 1)
        c.fill:SetTexCoord(0, 1, 0, 1)
    end
    if tab then
        c.tab:ClearAllPoints()
        c.tab:SetSize(tab.size[1], tab.size[2])
        if above then
            c.tab:SetPoint("TOP", c, corner, x, tab.depth)
            c.tab:SetTexCoord(0, 1, 1, 0)
        else
            c.tab:SetPoint("BOTTOM", c, corner, x, -tab.depth)
            c.tab:SetTexCoord(0, 1, 0, 1)
        end
        c.tab:Show()
    elseif c.tab then
        c.tab:Hide()
    end

    local fr, fg, fb = TowardAccent(T.WINDOW, 0.15)
    local r, g, b = T.Accent()
    c.halo:SetBackdropBorderColor(r, g, b, 1)
    if T.Classic() then -- (the dialog border's own colors, and no pointer)
        c.edge:Hide()
        c.fill:Hide()
    else
        c:SetBackdropColor(fr, fg, fb, 0.98)
        c:SetBackdropBorderColor(r, g, b, 1)
        c.edge:SetVertexColor(r, g, b, 1)
        c.fill:SetVertexColor(fr, fg, fb, 1)
    end

    local path, size, flags = WildGearFontHighlightSmall:GetFont()
    if path and size then c.text:SetFont(path, math.floor(size + 0.5) + 1, flags or "") end
    c.text:SetText(text)
    for key, button in pairs({ yes = c.yes, no = c.no }) do
        if o[key] then
            button:SetText(o[key])
            button:Show()
        else
            button:Hide()
        end
    end
    W.SetActive(c.yes, true)
    local row = (o.yes or o.no or o.row) and 8 + 20 + 1 or 0
    c:SetHeight(math.ceil(c.text:GetStringHeight() or 12) + 2 * PAD_Y + 3 + row + 2 * CONFIRM_EDGE)
    c:Show()
    c.pulse:Play()
end

-- macro: the protected command `yes` runs ("/reload"), after onYes (SecureYes).
-- alert: play the invite sound too, for a question that comes up by itself
-- (Equip best's Save); one that follows a click (the theme's Reload) is quiet.
function W.Confirm(anchor, text, yes, no, onYes, macro, alert)
    local c = Confirm()
    c.onYes, c.onNo = onYes, nil
    ShowBox(c, anchor, text, { yes = yes, no = no })
    c.macro = macro
    if not InCombatLockdown() then
        if macro then
            local s = SecureYes(c)
            s:SetAttribute("macrotext", macro)
            s:ClearAllPoints()
            s:SetAllPoints(c.yes)
            s:SetFrameLevel(c.yes:GetFrameLevel() + 10)
            s:Show()
        elseif c.secure then
            c.secure:Hide()
            c.secure:ClearAllPoints()
        end
    end
    if alert and PlaySound and SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE then PlaySound(SOUNDKIT.IG_PLAYER_INVITE) end
end

function W.HideConfirm()
    if confirm then confirm:Hide() end
end

-- A step of a tour (the Stat weights panel's): the question's box by
-- `anchor` (opts.above, opts.left as ShowBox's), `text`, and at its foot
-- opts.step ("2/5") in grey, then opts.next lit, which runs opts.onNext, and
-- opts.skip (opts.onSkip), either left out. One at a time, apart from the
-- question's.
-- opts.spot (a button that's easy to miss): the button lit by the game's
-- action button glow in the accent, pulsing.
local function Unspot(c)
    if not c.spot then return end
    c.spot.pulse:Stop()
    c.spot:Hide()
end

local function Spot(c, anchor)
    if not c.spot then
        c.spot = CreateFrame("Frame", nil, UIParent)
        c.spot.glow = c.spot:CreateTexture(nil, "OVERLAY")
        c.spot.glow:SetPoint("CENTER")
        c.spot.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        c.spot.glow:SetBlendMode("ADD")
        local pulse = c.spot:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.35)
        fade:SetDuration(0.6)
        fade:SetSmoothing("IN_OUT")
        c.spot.pulse = pulse
        c:HookScript("OnHide", Unspot)
    end
    local r, g, b = T.Accent()
    -- (on the button, over it: it scales and goes with it)
    local s = c.spot
    s:SetParent(anchor)
    s:ClearAllPoints()
    s:SetAllPoints(anchor)
    s:SetFrameLevel(anchor:GetFrameLevel() + 5)
    s.glow:SetSize((anchor:GetWidth() or 24) * 1.8, (anchor:GetHeight() or 24) * 1.8)
    s.glow:SetVertexColor(r, g, b, 1)
    s:Show()
    s.pulse:Play()
end

function W.Coach(anchor, text, opts)
    if not coach then
        coach = QuestionBox()
        coach.isCoach = true
        coach.step = coach:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
        coach.step:SetPoint("LEFT", coach, "BOTTOMLEFT", PAD_X + 2 + CONFIRM_EDGE, PAD_Y + 1 + CONFIRM_EDGE + 10)
    end
    coach.step:SetText(opts.step or "")
    coach.onYes, coach.onNo = opts.onNext, opts.onSkip
    ShowBox(coach, anchor, text, { yes = opts.next, no = opts.skip, above = opts.above, left = opts.left, row = true })
    if opts.spot then Spot(coach, anchor) else Unspot(coach) end
end

function W.HideCoach()
    if coach then coach:Hide() end
end

-- Whether the mouse is on the tour's box (a click there is for its buttons).
function W.CoachUnderMouse()
    return coach ~= nil and coach:IsShown() and coach:IsMouseOver() or false
end

-- A labelled box with the value and a chevron. Clicking it opens a list; the
-- mouse wheel steps through it (or calls def.step if given).
-- def = { label, width, options() -> { {text, value, selected}, ... }, set(value), step?, fallback?,
--         tooltip?, hint?, tip?, scroller? }: tooltip() fills the hover tooltip; hint (number boxes:
--         "Scroll to change") follows a mouse wheel icon: in grey at the tooltip's end, or with no
--         tooltip() in a bubble under the box (W.ShowBubble); tip (text, or a function returning
--         it: nil for none) shows in a bubble instead, the hint in grey at its end, under
--         tipAnchor() if given (e.g. the box's row), its pointer at the box. scroller() returns, while the
--         box's panel scrolls, the panel's wheel handler (delta): the wheel then scrolls the
--         panel instead, and the hint is left out. fit: the box only as wide as its text, up to
--         width (no label: beside the Character frame).
-- Returns the box, with f.Update() (shows the selected option) and f.SetEnabled(on).
function W.Selector(parent, def)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(def.width, 40)

    local classic = T.Classic()
    local label = f:CreateFontString(nil, "OVERLAY", W.LabelFont())
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 1, 0)
    label:SetText(def.label or "")

    local function Step(delta)
        local opts = def.options()
        local idx = 1
        for i, o in ipairs(opts) do
            if o.selected then idx = i end
        end
        local target = opts[math.max(1, math.min(#opts, idx + delta))]
        if target and not target.selected then def.set(target.value) end
    end
    local step = def.step or Step

    local function Wheel(_, delta)
        local scroll = def.scroller and def.scroller()
        if scroll then return scroll(delta) end
        if f.disabled then return end
        step(delta > 0 and 1 or -1)
    end

    -- (22 tall, taller for a big font, its middle staying put: callers line
    -- things up with it. Sized below, once its text is made.)
    local value = CreateFrame("Button", nil, f, not classic and "BackdropTemplate" or nil)
    value:SetHeight(22)
    value:SetPoint("LEFT", f, "BOTTOMLEFT", 0, 11)
    value:SetPoint("RIGHT", f, "BOTTOMRIGHT", 0, 11)

    -- A grey chevron on the right marks the list; it takes the accent on hover.
    -- Classic: the game's dropdown frame, and its gold arrow button that glows
    -- on hover; a skin's: its pressed (sunken) button and its down button.
    local caret = value:CreateTexture(nil, "OVERLAY")
    local art, icons = classic and T.Skin() and T.Skin().button, Icons()
    local caretIn = classic and 0 or 6 -- (from the box's right: def.fit)
    if art and icons then
        local size = art.size
        ThreeSlice(value, "BACKGROUND", art.down, size[1], size[2], { 0, size[1], 0, size[2] }, art.cap, art.capWidth)
        caret:SetSize(20, 20)
        caret:SetPoint("RIGHT", value, "RIGHT", -1, 0)
        caretIn = 1
        caret:SetTexture(icons.down)
        local glow = value:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(caret)
        glow:SetTexture(icons.down)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.3)
    elseif classic then
        -- (Its borders keep their height as a big font makes it taller.)
        NineSlice(value, "BACKGROUND", ART.dropdown, 128, 64, { 17, 112, 16, 43 }, 8, 7, 8, 5, 22 / 27)
        caret:SetSize(22, 22)
        caret:SetPoint("RIGHT", value, "RIGHT", 0, 0)
        caret:SetTexture(ART.dropdownButton)
        caret:SetTexCoord(2 / 32, 29 / 32, 3 / 32, 29 / 32)
        local glow = value:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(caret)
        glow:SetTexture(ART.mouseHighlight)
        glow:SetBlendMode("ADD")
    else
        W.Fill(value, T.FIELD[1], T.FIELD[2], T.FIELD[3])
        W.AddHighlight(value)
        caret:SetSize(10, 10)
        caret:SetPoint("RIGHT", value, "RIGHT", -6, 0)
        caret:SetTexture("Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Caret")
        caret:SetVertexColor(0.5, 0.5, 0.5)
    end
    local function Tint(on)
        if classic then return end
        if on then caret:SetVertexColor(T.Accent()) else caret:SetVertexColor(0.5, 0.5, 0.5) end
    end

    local textIn = art and icons and 10 or 7 -- (past a skin's brass end)
    value.text = value:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    value.text:SetPoint("LEFT", value, "LEFT", textIn, 0)
    value.text:SetPoint("RIGHT", caret, "LEFT", -4, 0)
    value.text:SetJustifyH("LEFT")
    value.text:SetWordWrap(false)
    -- (22 holds a text up to 12 points, a Chinese client's default; past
    -- that it grows 1.4 points a point, its letters and the spec icon at the
    -- text's height taller than its dark field grows; the game's dropdown
    -- frame, whose thick borders leave less of it dark, 2.) Classic, the
    -- arrow button grows with it, as tall as the box (a skin's, 2 less).
    local grow = classic and not (art and icons) and 2 or 1.4
    T.Track(function()
        local size = select(2, value.text:GetFont()) or 0
        local height = math.floor(22 + math.max(0, size - 12) * grow + 0.5)
        value:SetHeight(height)
        if classic then
            local button = art and icons and height - 2 or height
            caret:SetSize(button, button)
        end
    end)
    value:EnableMouseWheel(true)
    value:SetScript("OnMouseWheel", Wheel)
    value:SetScript("OnClick", function(self)
        W.HideBubble()
        HideTooltip()
        W.ShowPopup(self, def.options(), def.set)
    end)
    -- Opens the list (unless it's open), the option of value `spot` lit
    -- (W.ShowPopup's opt.spot): to point it out, as What's new's Try it now.
    f.OpenList = function(spot)
        if f.disabled then return end
        local opts = def.options()
        for _, o in ipairs(opts) do o.spot = o.value == spot or nil end
        W.HideBubble()
        HideTooltip()
        if not (popup and popup:IsShown() and popup.anchor == value) then W.ShowPopup(value, opts, def.set) end
    end
    value:SetScript("OnEnter", function(self)
        if f.disabled then return end
        Tint(true)
        local hint = not (def.scroller and def.scroller()) and def.hint
        local tip = def.tip and (type(def.tip) == "function" and def.tip() or def.tip)
        if def.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            def.tooltip()
            if hint then GameTooltip:AddLine(WHEEL_GREY .. hint, 0.6, 0.6, 0.6, true) end
            GameTooltip:Show()
        elseif tip then
            if hint then tip = tip .. "\n" .. WHEEL_GREY .. "|cff999999" .. hint .. "|r" end
            W.ShowBubble(def.tipAnchor and def.tipAnchor() or self, tip, { pointAt = self })
        elseif hint then
            W.ShowBubble(self, hint, { icon = true })
        end
    end)
    value:SetScript("OnLeave", function()
        Tint(false)
        HideTooltip()
        W.HideBubble()
    end)

    local function Show(text)
        value.text:SetText(text)
        if not def.fit then return end
        local t = value.text
        local width = t.GetUnboundedStringWidth and t:GetUnboundedStringWidth() or t:GetStringWidth() or 0
        f:SetWidth(math.min(def.width, math.ceil(textIn + width + 4 + caret:GetWidth() + caretIn + 1)))
    end
    f.Update = function()
        for _, o in ipairs(def.options()) do
            if o.selected then return Show(o.short or o.text) end
        end
        Show(def.fallback and def.fallback() or "?")
    end
    -- Off: dimmed, its list and the mouse wheel off (the wheel still scrolls its panel).
    f.SetEnabled = function(on)
        f.disabled = not on or nil
        value:SetEnabled(on and true or false)
        f:SetAlpha(on and 1 or 0.45)
    end
    f.value = value -- (the box, under the label)
    return f
end

---------------------------------------------------------------- tabs and scroll bars

-- The Classic theme's tabs: the game's character pane's, as an object's two
-- looks (tab.on, tab.off) that W.SelectTab picks between: `bottom` hanging
-- under a window, the selected one rising into it; else upside down on top of
-- a list, the selected one as big as the others (its art without the part
-- that joins the window). Their text in the game's small gold, white while selected.
-- A skin's (T.Skin().button): its buttons, the selected one in their hover
-- look, the others darker and, hanging, shorter (the selected one reaches
-- further up, to the window's edge).
local function ClassicTab(parent, text, minWidth, bottom)
    local tab = CreateFrame("Button", nil, parent)
    tab.classic = true
    tab.text = tab:CreateFontString(nil, "OVERLAY", "WildGearFontNormalSmall")
    tab.text:SetText(text)
    local art = T.Skin() and T.Skin().button
    if art then
        tab.text:SetPoint("CENTER", tab, "CENTER", 0, bottom and -2 or 0)
        local size, box, short = art.size, { 0, art.size[1], 0, art.size[2] }, bottom and -5 or nil
        tab.off = ThreeSlice(tab, "BACKGROUND", art.file, size[1], size[2], box, art.cap, art.capWidth, short)
        tab.off.SetColor(0.75, 0.75, 0.75)
        tab.on = ThreeSlice(tab, "BACKGROUND", art.hover, size[1], size[2], box, art.cap, art.capWidth)
        ThreeSlice(tab, "HIGHLIGHT", art.glow, size[1], size[2], box, art.cap, art.capWidth, short).SetBlend("ADD")
    else
        tab.text:SetPoint("CENTER", tab, "CENTER", 0, bottom and 2 or -1)
        local flip = not bottom
        tab.off = ThreeSlice(tab, "BACKGROUND", ART.tab, 128, 32, { 7, 121, 0, 32 }, 18, 16, nil, flip)
        if bottom then
            -- (Its top up to the frame's bottom edge, the light line there,
            -- which it breaks: the tab opens into the frame. The art's top rows
            -- are left out, as their dark would cut into the bar above.)
            tab.on = ThreeSlice(tab, "BACKGROUND", ART.tabOn, 128, 64, { 5, 123, 5, 40 }, 18, 16, 3)
        else
            tab.on = ThreeSlice(tab, "BACKGROUND", ART.tabOn, 128, 64, { 5, 123, 7, 39 }, 18, 16, nil, true)
        end
        local hl = tab:CreateTexture(nil, "HIGHLIGHT")
        hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, bottom and -4 or -6)
        hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, bottom and 6 or 4)
        hl:SetTexture(ART.tabHighlight)
        if flip then hl:SetTexCoord(0, 1, 1, 0) end
        hl:SetBlendMode("ADD")
    end
    tab.on.SetShown(false)
    if minWidth then
        T.Track(function() tab:SetWidth(math.max(minWidth, tab.text:GetStringWidth() + 40)) end)
    end
    return tab
end

-- A tab: centered text (tab.text, in `font`) over an accent underline, shown
-- when selected (W.SelectTab). With `minWidth` the tab fits its text, at
-- least that wide, and refits when the text size changes; else the caller sizes it.
-- Classic: the game's tabs (ClassicTab), the character pane's when `bottom`.
function W.Tab(parent, text, font, minWidth, bottom)
    if T.Classic() then return ClassicTab(parent, text, minWidth, bottom) end
    local tab = CreateFrame("Button", nil, parent)
    tab.text = tab:CreateFontString(nil, "OVERLAY", font)
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, 1)
    tab.text:SetText(text)
    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetPoint("BOTTOMLEFT")
    tab.underline:SetPoint("BOTTOMRIGHT")
    tab.underline:SetHeight(2)
    T.Track(function()
        tab.underline:SetColorTexture(T.Accent())
        if minWidth then tab:SetWidth(math.max(minWidth, tab.text:GetStringWidth() + 24)) end
    end)
    W.AddHighlight(tab)
    return tab
end

-- A tab of a second row under the window's tabs (the Dungeon loot views):
-- Modern, a choice on a sunk track (W.SubTabTrack), the selected one raised
-- with its text in the accent, as W.Segmented's, so they don't look like
-- the window's own tabs; Classic, W.Tab's.
function W.SubTab(parent, text, font, minWidth)
    local tab = W.Tab(parent, text, font, minWidth)
    if tab.classic then return tab end
    tab.segment = true
    tab.underline:Hide()
    tab.fill = tab:CreateTexture(nil, "BACKGROUND")
    tab.fill:SetAllPoints()
    tab.fill:SetColorTexture(T.RAISED[1], T.RAISED[2], T.RAISED[3], 1)
    tab.fill:Hide()
    return tab
end

-- The track under a row of W.SubTab's in `parent` (Modern; nil in Classic),
-- 2 out from them. track.Fit(tabs) spans it from the first shown one to the
-- last shown one (tabs side by side, in order), hidden with none shown.
function W.SubTabTrack(parent)
    if T.Classic() then return nil end
    local track = parent:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(T.TRACK[1], T.TRACK[2], T.TRACK[3], 1)
    track.Fit = function(tabs)
        local first, last
        for _, tab in ipairs(tabs) do
            if tab:IsShown() then
                first = first or tab
                last = tab
            end
        end
        track:ClearAllPoints()
        if not first then return track:Hide() end
        track:SetPoint("TOPLEFT", first, "TOPLEFT", -2, 2)
        track:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 2, -2)
        track:Show()
    end
    return track
end

-- A slow pulse of light on tab `tab` (W.Tab; `bottom` as there), to point
-- out a new one, until glow.Stop(): Modern, a soft glow in the accent behind
-- its text; Classic, the game's tab highlight; a skin's, its buttons' glow.
-- (In a frame of its own, over the tab, letting clicks through.)
function W.TabGlow(tab, bottom)
    local g = CreateFrame("Frame", nil, tab)
    g:SetAllPoints(tab)
    local art = tab.classic and T.Skin() and T.Skin().button
    if art then
        local size = art.size
        ThreeSlice(g, "ARTWORK", art.glow, size[1], size[2], { 0, size[1], 0, size[2] }, art.cap, art.capWidth,
            bottom and -5 or nil).SetBlend("ADD")
    elseif tab.classic then
        local t = g:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, bottom and -4 or -6)
        t:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, bottom and 6 or 4)
        t:SetTexture(ART.tabHighlight)
        if not bottom then t:SetTexCoord(0, 1, 1, 0) end
        t:SetBlendMode("ADD")
    else
        local t = g:CreateTexture(nil, "ARTWORK")
        t:SetPoint("TOPLEFT", tab, "TOPLEFT", -8, 6)
        t:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 8, -6)
        t:SetTexture(MEDIA .. "Glow")
        t:SetBlendMode("ADD")
        T.Track(function() t:SetVertexColor(T.Accent()) end)
    end
    -- (one breath every 1.5 seconds: up in 0.75, down in 0.75)
    local pulse = g:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(0.15)
    a:SetToAlpha(0.9)
    a:SetDuration(0.75)
    a:SetSmoothing("IN_OUT")
    pulse:Play()
    return { pulse = pulse, Stop = function()
        pulse:Stop()
        g:Hide()
    end }
end

function W.SelectTab(tab, selected)
    if tab.classic then
        tab.on.SetShown(selected)
        tab.off.SetShown(not selected)
        tab.text:SetTextColor(T.LabelColor(selected))
        -- (over its neighbours, which it overlaps)
        tab:SetFrameLevel(tab:GetParent():GetFrameLevel() + (selected and 3 or 1))
        return
    end
    if selected then
        tab.text:SetTextColor(T.Accent())
    else
        tab.text:SetTextColor(T.DIM[1], T.DIM[2], T.DIM[3])
    end
    local mark = tab.segment and tab.fill or tab.underline -- (W.SubTab's: raised off its track)
    if selected then mark:Show() else mark:Hide() end
end

-- The Classic theme's scroll bar, the game's own (its Quest Log's): a stone
-- track with arrow buttons at its ends, each a turn of the bar's mouse wheel
-- (OnMouseWheel, the caller's), greyed at that end of the range, and the knob
-- between them, which keeps its size (W.SizeThumb). The caller places all of
-- it, W.ScrollBarWidth() wide: the slider's own points and height go in by
-- the track's sides and the arrows (SCROLL_IN).
local SCROLL_IN = { left = 8, right = 7, top = 21, bottom = 18 }
local function ClassicScrollBar(parent)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetValueStep(1)
    bar:SetThumbTexture(ART.knob)
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetSize(18, 24)
        thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875)
    end

    -- The track: two pieces side by side in its file, the top one and the
    -- bottom one; their ends (the arrows' places) as drawn, the middle
    -- stretching. A skin's (with icons and a frame): a strip of its frame's
    -- wood, darkened, from the top arrow to the bottom one.
    local icons, fr = Icons(), Framed()
    if icons and fr then
        local t = bar:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(fr.railV.file)
        t:SetVertexColor(0.55, 0.55, 0.55)
        t:SetPoint("TOP", bar, "TOP", 0, 16)
        t:SetPoint("BOTTOM", bar, "BOTTOM", 0, -16)
        t:SetWidth(fr.railV.size)
    else
        local function Track(x0, y0, y1)
            local t = bar:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(ART.track)
            t:SetTexCoord(x0 / 64, (x0 + 31) / 64, y0 / 256, y1 / 256)
            t:SetWidth(31)
            return t
        end
        local top, bottom = Track(0, 0, 32), Track(33, 89, 106)
        top:SetHeight(32)
        top:SetPoint("TOPLEFT", bar, "TOPLEFT", -SCROLL_IN.left, SCROLL_IN.top)
        bottom:SetHeight(17)
        bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -SCROLL_IN.left, -SCROLL_IN.bottom)
        local middle = Track(0, 32, 256)
        middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
        middle:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
    end

    local function Arrow(up)
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(18, 16)
        if up then b:SetPoint("BOTTOM", bar, "TOP") else b:SetPoint("TOP", bar, "BOTTOM") end
        if icons then -- (a skin's: square, the arrow's middle 16 of its 18)
            b:SetSize(16, 16)
            SkinIcon(b, up and icons.up or icons.down)
            b:SetScript("OnClick", function()
                local wheel = bar:GetScript("OnMouseWheel")
                if wheel then wheel(bar, up and 1 or -1) end
            end)
            return b
        end
        local art = up and { ART.up, ART.upDown, ART.upOff, ART.upHighlight }
            or { ART.down, ART.downDown, ART.downOff, ART.downHighlight }
        b:SetNormalTexture(art[1])
        b:SetPushedTexture(art[2])
        b:SetDisabledTexture(art[3])
        b:SetHighlightTexture(art[4], "ADD")
        for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture(), b:GetHighlightTexture() }) do
            t:SetTexCoord(0.2, 0.8, 0.25, 0.75)
        end
        b:SetScript("OnClick", function()
            local wheel = bar:GetScript("OnMouseWheel")
            if wheel then wheel(bar, up and 1 or -1) end
        end)
        return b
    end
    local upArrow, downArrow = Arrow(true), Arrow(false)
    local function Ends()
        local low, high = bar:GetMinMaxValues()
        local v = bar:GetValue() or 0
        if v > (low or 0) + 0.5 then upArrow:Enable() else upArrow:Disable() end
        if v < (high or 0) - 0.5 then downArrow:Enable() else downArrow:Disable() end
    end
    hooksecurefunc(bar, "SetValue", Ends)
    hooksecurefunc(bar, "SetMinMaxValues", Ends)
    bar:HookScript("OnMouseUp", Ends) -- (after dragging the knob)

    local setPoint, setHeight = bar.SetPoint, bar.SetHeight
    function bar:SetPoint(point, rel, relPoint, x, y)
        x = (x or 0) + (point:find("LEFT") and SCROLL_IN.left or point:find("RIGHT") and -SCROLL_IN.right or 0)
        y = (y or 0) + (point:find("TOP") and -SCROLL_IN.top or point:find("BOTTOM") and SCROLL_IN.bottom or 0)
        setPoint(self, point, rel, relPoint, x, y)
    end
    function bar:SetHeight(height)
        setHeight(self, height - SCROLL_IN.top - SCROLL_IN.bottom)
    end
    return bar
end

-- How wide W.ScrollBar is: the room to leave for it.
function W.ScrollBarWidth()
    return T.Classic() and 31 or 6
end

-- A scroll bar's thumb `height` tall (at least 24): the share of the list in
-- view. The Classic theme's knob keeps the game's size.
function W.SizeThumb(bar, height)
    if T.Classic() then return end
    local thumb = bar:GetThumbTexture()
    if thumb then thumb:SetHeight(math.max(24, height)) end
end

-- A thin vertical scroll bar: faint track, a quiet grey thumb (Classic: the
-- game's, ClassicScrollBar). The caller places it and sets its range and OnValueChanged.
function W.ScrollBar(parent)
    if T.Classic() then return ClassicScrollBar(parent) end
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.03)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetWidth(6)
        thumb:SetVertexColor(T.THUMB[1], T.THUMB[2], T.THUMB[3], 1)
    end
    bar:SetValueStep(1)
    return bar
end

---------------------------------------------------------------- the Classic window

-- The Classic theme's window frame `f`: the Auction House's browse frame
-- (six pieces of 256 x 256 texels, three on top and three below: its
-- portrait ring, title strip, stone band for the controls, a bluish inset on
-- the left and a marble one on the right, a bar along the bottom) fitted to
-- `width` at any height. Its plain runs stretch and the rest stays as drawn:
-- across, the left inset widens to hold a list `leftWidth` wide and the
-- middle piece takes up the rest; down, the rows between the band and the
-- bottom stretch. The title strip is cut out (the title is in a plaque, as
-- the side panels': W.TitleBand with dock.top), the band's stone stretching
-- up to the top edge, but for the ring's and the close box's columns. The
-- insets' insides, where a stretch would show, are the game's tiling marble
-- instead (the left one lightened as the frame's), and the bottom bar leaves
-- out the Auction House's money and button boxes.
-- The portrait is the addon's icon. A skin (T.Skin) puts its own art on it:
-- the portrait, a painting in the band, a floor in the insets and a corner
-- piece. Returns where the window's parts go:
-- close (the close button's middle, from the top right), left / right /
-- rightWidth (the lists), top (above the lists) and bottom (below them),
-- selectorX / selectorY (the selector row, right of the portrait), barY (the
-- bottom bar's buttons, from the bottom), tabY (the tabs' top, above the
-- bottom: they hang below) and dock (UI.DockSides: the side panels `top`
-- lower than the frame, their top edges level with its, and `left` / `right`
-- out from its sides, as far from its edges on both: the ring sticks out on
-- the left).
-- A skin with a frame of its own (skin.frame) has its own window instead,
-- with the same parts in the same order (W.ClassicWindow returns this):
-- its frame round it, the title in the frame's bar (W.TitleBand); below
-- that the painting behind the selectors, rails of the frame's wood under
-- them, above the bottom bar and down between the two lists (on its floor),
-- the bottom bar's board (skin.bar), and the skin's emblem on the top left corner, sticking out as the ring
-- does. Every side panel has the frame too (W.Window), so they dock level
-- with the window's top, only clear of the emblem on the left.
-- A skin's falling leaves (skin.leaves) in `f` between x0 and x1, from `top`
-- down to `bottom` above its bottom edge: over its floor, painting and rails,
-- under its frame and everything on it. Each drifts down, swaying, turning
-- and tumbling (narrowed as it turns edge on), fades in at the top and out at
-- the bottom, and waits a while before falling again somewhere else. They
-- only move while the window shows. Returns SetArt(art, quiet): the leaves
-- falling fade out quickly and all of them start again as its, spread over
-- the height, fading in (quiet: at once); the count stays.
local function Leaves(f, art, x0, x1, top, bottom)
    local rnd, sin, cos, abs, min = math.random, math.sin, math.cos, math.abs, math.min
    local edge = 30 -- (the widest sway and half a leaf, so none leaves the frame)
    local function Height()
        return math.max(1, (f:GetHeight() or 0) - top - bottom)
    end
    local function Start(l, y)
        l.x = x0 + edge + rnd() * (x1 - x0 - 2 * edge)
        l.y = y
        l.fall = 14 + rnd() * 16
        l.sway, l.swayRate, l.phase = 6 + rnd() * 12, 0.6 + rnd() * 0.8, rnd() * 6.28
        l.turn, l.spin = rnd() * 6.28, (rnd() - 0.5) * 2.4
        l.flip, l.flipRate = rnd() * 6.28, 1 + rnd() * 2
        l.size = art.size * (0.7 + rnd() * 0.5)
        l.tex:SetTexture(art.files[rnd(#art.files)])
    end
    local leaves = {}
    for i = 1, art.count do
        local l = { tex = f:CreateTexture(nil, "BACKGROUND", nil, 2) }
        Start(l, rnd() * Height())
        leaves[i] = l
    end
    -- (swap: art for the leaves after the old ones fade out; fade: all the
    -- leaves' alpha, 0 to 1, out and back in round a swap)
    local swap, fade = nil, 1
    local function Restart(new)
        art = new
        for _, l in ipairs(leaves) do Start(l, rnd() * Height()) end
    end
    local driver = CreateFrame("Frame", nil, f)
    driver:SetScript("OnUpdate", function(_, elapsed)
        local e, h = min(elapsed, 0.1), Height()
        if swap then
            fade = fade - e / 0.35
            if fade <= 0 then
                fade = 0
                Restart(swap)
                swap = nil
            end
        elseif fade < 1 then
            fade = min(1, fade + e / 0.6)
        end
        for _, l in ipairs(leaves) do
            l.y, l.phase, l.turn, l.flip = l.y + l.fall * e, l.phase + l.swayRate * e, l.turn + l.spin * e,
                l.flip + l.flipRate * e
            if l.y > h then Start(l, -rnd() * h * 0.6) end
            local t = l.tex
            t:SetAlpha(art.alpha * fade * math.max(0, min(1, l.y / 24, (h - l.y) / 32)))
            t:ClearAllPoints()
            t:SetPoint("CENTER", f, "TOPLEFT", l.x + l.sway * sin(l.phase), -(top + l.y))
            t:SetSize(l.size * (0.25 + 0.75 * abs(cos(l.flip))), l.size)
            t:SetRotation(l.turn)
        end
    end)
    return function(new, quiet)
        if new == art and not swap then return end
        if quiet or not f:IsVisible() then
            swap, fade = nil, 1
            Restart(new)
        else
            swap = new
        end
    end
end

-- A skin's ground decals (skin.decals): a few things lying on the lists'
-- floor (Elwynn: a gnoll's tracks, a pickaxe, kobold candles...), `count` of
-- them, each a different file, somewhere new every time the window opens: in
-- `areas` (each x0, x1 across `f`), from `top` down to `bottom` above its
-- bottom edge, clear of the edges and of each other, turned a little and
-- dimmed by `dim`. Placed a frame after the window shows, its height set by
-- then; one a smaller height leaves off the floor hides until it grows back.
-- A file with wicks (art.flame.wicks[its index]) isn't turned, and each wick
-- lights now and then on its own (one of the game's flame models in a small
-- box on the wick, a warm glow round the decal) and goes out again; some are
-- lit as the window opens. They only burn while the window shows.
-- f.skinFlame, the flames' zoom, x / y / z, facing and alpha changed and
-- Place() called, moves them; SetShown(true) keeps a decal with wicks out and
-- all its wicks lit (/wildgear fx flame, dev addon). Returns SetArt(art): places
-- its things instead, at once (as many; flames only if `art` was the first's
-- or has the same flame).
-- (Driven by a child frame: UI.lua sets the window's own OnShow later.)
local function Decals(f, art, areas, top, bottom, dim)
    local rnd, sin = math.random, math.sin
    local half = art.size * 0.6 -- (half the largest drawn, 1.15 times size, and a little)
    local flame, first = art.flame, art.flame
    local list, models = {}, {}
    for i = 1, art.count do
        local t = f:CreateTexture(nil, "BACKGROUND", nil, -4) -- (over the floor, under the rails)
        t:SetVertexColor(dim, dim, dim)
        t.flames = {}
        list[i] = t
    end
    local fx = flame and { zoom = flame.zoom or 1, x = flame.x or 0, y = flame.y or 0, z = flame.z or 0,
        facing = flame.facing or 0, alpha = flame.alpha or 1, model = flame.model }
    local function Look(m)
        m:SetCamDistanceScale(1 / fx.zoom)
        m:SetPosition(fx.x, fx.y, fx.z)
        m:SetFacing(fx.facing)
    end
    -- The model on wick j of decal t: made the first time it is needed, at
    -- the window's own frame level, so over the floor and under the lists.
    local function Model(t, j)
        local m = t.flames[j]
        if not m then
            m = CreateFrame("PlayerModel", nil, f)
            m:EnableMouse(false)
            if m.SetKeepModelOnHide then m:SetKeepModelOnHide(true) end
            m:SetScript("OnModelLoaded", Look) -- (loading resets the camera)
            m:SetFrameLevel(f:GetFrameLevel())
            m:Hide()
            m:SetModel(fx.model)
            Look(m)
            t.flames[j] = m
            models[#models + 1] = m
        end
        return m
    end
    local function Floor() return (f:GetHeight() or 0) - bottom end -- (the floor's bottom, from the top)
    local placed, Place -- (placed: once there was a floor to place them on)
    local function Fit()
        if not placed then return Place() end
        local y1 = Floor()
        for _, t in ipairs(list) do t:SetShown(t.y ~= nil and t.y + half <= y1) end
    end
    -- A wick's next turn: lit for a while, or out for a while.
    local function Turn(m, on)
        m.on = on
        m.wait = on and 12 + rnd() * 30 or 5 + rnd() * 25
    end
    function Place()
        placed = Floor() - top > 2 * half
        if not placed then
            for _, t in ipairs(list) do t:Hide() end
            return
        end
        local files = {}
        for i = 1, #art.files do files[i] = i end
        for i = #files, 2, -1 do
            local j = rnd(i)
            files[i], files[j] = files[j], files[i]
        end
        if fx and fx.forced then -- (one with wicks first)
            table.sort(files, function(a, b) return (flame.wicks[a] and 1 or 0) > (flame.wicks[b] and 1 or 0) end)
        end
        local total = 0
        for _, a in ipairs(areas) do total = total + math.max(0, a[2] - a[1] - 2 * half) end
        local down, spots = Floor() - top - 2 * half, {}
        for i, t in ipairs(list) do
            local file = files[(i - 1) % #files + 1]
            local wicks = flame and flame.wicks[file]
            local s = art.size * (0.85 + rnd() * 0.3)
            t:SetTexture(art.files[file])
            t:SetSize(s, s)
            t:SetRotation(wicks and 0 or (rnd() - 0.5) * 0.7)
            t.y, t.wicks = nil, nil
            for _, m in ipairs(t.flames) do
                m.wick = false
                m:Hide()
            end
            if t.glow then t.glow:SetAlpha(0) end
            for _ = 1, 12 do -- (a few tries at a spot clear of the others)
                local across = rnd() * total
                local x
                for _, a in ipairs(areas) do
                    local w = math.max(0, a[2] - a[1] - 2 * half)
                    if across <= w then x = a[1] + half + across break end
                    across = across - w
                end
                local y = top + half + rnd() * down
                local clear = x ~= nil
                for _, p in ipairs(spots) do
                    if clear and (p[1] - x) ^ 2 + (p[2] - y) ^ 2 < (art.size * 1.5) ^ 2 then clear = false end
                end
                if clear then
                    spots[#spots + 1] = { x, y }
                    t.y, t.wicks = y, wicks
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", f, "TOPLEFT", x, -y)
                    -- its wicks' flames, each box centered on a wick's tip
                    -- (u, v across and down the decal), and its glow
                    for j, w in ipairs(wicks or {}) do
                        local m = Model(t, j)
                        m:ClearAllPoints()
                        m:SetPoint("CENTER", f, "TOPLEFT", x + (w[1] - 0.5) * s, -y - (w[2] - 0.5) * s)
                        m:SetSize(flame.box[1] * s / art.size, flame.box[2] * s / art.size)
                        m.wick, m.level = true, 0
                        Turn(m, fx.forced or rnd() < 0.5)
                        if m.on then m.level = 1 end
                    end
                    if wicks then
                        if not t.glow then
                            t.glow = f:CreateTexture(nil, "BACKGROUND", nil, -3)
                            t.glow:SetTexture(flame.glow)
                            t.glow:SetBlendMode("ADD")
                            t.glow:SetVertexColor(1, 0.62, 0.28)
                        end
                        t.glow:ClearAllPoints()
                        t.glow:SetPoint("CENTER", f, "TOPLEFT", x, -y + s * 0.15)
                        t.glow:SetSize(s * 1.6, s * 1.6)
                    end
                    break
                end
            end
        end
        Fit()
    end
    -- Each frame: the wicks' turns, a flame fading in over a second and out
    -- over 1.5, and the glow following them, breathing a little.
    local clock = 0
    local function Burn(e)
        clock = clock + e
        for _, t in ipairs(list) do
            if t.wicks then
                local shown, sum = t:IsShown(), 0
                for _, m in ipairs(t.flames) do
                    if m.wick then
                        m.wait = m.wait - e
                        if m.wait <= 0 then Turn(m, fx.forced or not m.on) end
                        m.level = m.on and math.min(1, m.level + e) or math.max(0, m.level - e / 1.5)
                        local a = shown and m.level or 0
                        m:SetShown(a > 0)
                        if a > 0 and m.SetModelAlpha then m:SetModelAlpha(a * fx.alpha) end
                        sum = sum + a
                    end
                end
                t.glow:SetAlpha(flame.glowAlpha * math.min(1, sum / 2) * (0.9 + 0.1 * sin(clock * 2.3)))
            end
        end
    end
    local driver, pending = CreateFrame("Frame", nil, f), true
    driver:SetScript("OnShow", function()
        pending = true
        for _, m in ipairs(models) do m:SetFrameLevel(f:GetFrameLevel()) end
    end)
    driver:SetScript("OnUpdate", function(_, elapsed)
        if pending then
            pending = false
            Place()
        end
        if flame then Burn(math.min(elapsed, 0.1)) end
    end)
    f:HookScript("OnSizeChanged", Fit)
    if fx then
        function fx.Place()
            for _, m in ipairs(models) do Look(m) end
        end
        function fx.GetModelFileID() return fx.model end
        function fx.SetModel(id)
            fx.model = id
            for _, m in ipairs(models) do m:SetModel(id) end
        end
        function fx.IsShown() return fx.forced end
        function fx.SetShown(_, on)
            fx.forced = on and true or nil
            Place()
        end
        f.skinFlame = fx
    end
    return function(new)
        art, flame, half = new, new.flame == first and first or nil, new.size * 0.6
        for _, t in ipairs(list) do
            if t.glow then t.glow:SetAlpha(0) end
        end
        if placed then Place() end
    end
end

-- A skin's light (skin.light): one of the game's own light-shaft models in
-- `f` between x0 and x1, from `top` down to `bottom` above its bottom edge,
-- the leaves' area. A model is a frame, drawn over its parent's textures: at
-- the window's own frame level it lies over the floor, the painting and the
-- leaves (and is cut to its rectangle, so off the frame's art), under the
-- lists and everything else on it. f.skinLight, its zoom, x / y / z, facing
-- and alpha changed and Place() called, moves it (/wildgear fx light, dev addon).
local function Light(f, art, x0, x1, top, bottom)
    local m = CreateFrame("PlayerModel", nil, f)
    m:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -top)
    m:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", x1, bottom)
    m:EnableMouse(false)
    if m.SetKeepModelOnHide then m:SetKeepModelOnHide(true) end
    m.zoom, m.x, m.y, m.z = art.zoom or 1, art.x or 0, art.y or 0, art.z or 0
    m.facing, m.alpha = art.facing or 0, art.alpha or 1
    function m.Place()
        m:SetCamDistanceScale(1 / m.zoom)
        m:SetPosition(m.x, m.y, m.z)
        m:SetFacing(m.facing)
        if m.SetModelAlpha then m:SetModelAlpha(m.alpha) end
    end
    m:SetScript("OnModelLoaded", m.Place) -- (loading resets the camera)
    local function Level() m:SetFrameLevel(f:GetFrameLevel()) end
    f:HookScript("OnShow", Level)
    Level()
    m:SetModel(art.model)
    m.Place()
    f.skinLight = m
end

-- A skin's walker (skin.walker): a creature wandering on the window's bottom
-- bar, its feet `y` up from the bottom, its middle between x0 and x1 across.
-- It walks to some spot, stands there a while, and walks on, turning to face
-- the way it goes. Clicked, it calls out (art.sound) and bolts off the bar:
-- out past the window's left edge (`left`, or its right one, `right`, behind
-- the buttons, when it is near the left already), cut off at the edge, and
-- walks back in from an edge a while later. It is the game's own model
-- (art.model, its walk (else its run) and stand animations, seen from the
-- side and a little from the front), wandering in short trots at art.trot,
-- which keeps its feet in step, or, if that never loads, the painted art
-- (art.file, facing left, mirrored going right; bobbing at each step) at
-- art.speed. Over the bar's board and rail, under the buttons; only moving
-- while the window shows (f.skinWalker.trot: the trot's speed, for /wildgear fx
-- walker). Returns SetOn(on, quiet): off, it bolts (quiet: is gone at once)
-- and stays away; on again, it walks back in. f.skinWalker (the model), its zoom,
-- x / y / z, facing (looking left) changed and Place() called, moves it
-- (/wildgear fx walker, dev addon).
local ANIM_STAND, ANIM_WALK, ANIM_RUN = 0, 4, 5
local function Walker(f, art, x0, x1, y, left, right)
    local rnd, abs, sin, min, max = math.random, math.abs, math.sin, math.min, math.max
    local w, h = art.box[1], art.box[2]
    -- (the bar, edge to edge and as high as the creature: what shows of it)
    local clip = CreateFrame("Frame", nil, f)
    clip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, y - 4)
    clip:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", right, y + h + 4)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local body = CreateFrame("Button", nil, clip)
    body:SetSize(w, h)
    local outLeft, outRight = left - w / 2 - 4, right + w / 2 + 4 -- (where it is out of sight)
    local function Level()
        clip:SetFrameLevel(f:GetFrameLevel() + 1)
        body:SetFrameLevel(f:GetFrameLevel() + 1)
    end
    f:HookScript("OnShow", Level)
    Level()

    local sprite = body:CreateTexture(nil, "ARTWORK")
    sprite:SetTexture(art.file)
    sprite:SetSize(art.size, art.size)
    sprite:SetPoint("BOTTOM")
    sprite:Hide()

    local m = CreateFrame("PlayerModel", nil, body)
    m:SetAllPoints()
    m:EnableMouse(false)
    if m.SetKeepModelOnHide then m:SetKeepModelOnHide(true) end
    m.zoom, m.x, m.y, m.z = art.zoom or 1, art.x or 0, art.y or 0, art.z or 0
    m.facing, m.alpha = art.facing or -1.2, 1
    m.trot = art.trot or art.speed -- (the dev pad changes it, to match the feet)
    local loaded, anim, turned = false, nil, nil -- (turned: the facing now)
    local noWalk = false -- (no walk animation: it wanders on its run)
    local function Animate(id)
        if id ~= anim and loaded and m.SetAnimation then
            anim = id
            m:SetAnimation(id)
        end
    end
    function m.Place()
        m:SetCamDistanceScale(1 / m.zoom)
        m:SetPosition(m.x, m.y, m.z)
        if turned then m:SetFacing(turned) end
    end
    m:SetScript("OnModelLoaded", function()
        loaded, anim = true, nil -- (loading resets the camera and animation)
        noWalk = m.HasAnimation and not m:HasAnimation(ANIM_WALK) or false
        sprite:Hide()
        m:Show()
        m.Place()
    end)
    m:SetModel(art.model)
    f.skinWalker = m

    -- state: "stand", "walk" (to `goal`), "flee" (to `goal`, out of sight),
    -- "gone" (until `wait` runs out, if it is on)
    local x, dir, state, wait, goal, step = x0 + rnd() * (x1 - x0), rnd(2) == 1 and -1 or 1, "stand",
        1 + rnd() * 2, nil, 0
    local on, clock = true, 0
    local function Call()
        if art.sound and PlaySoundFile then PlaySoundFile(art.sound, "SFX") end
    end
    -- Off the bar: out the left, or the right when near the left already.
    local function Flee()
        state = "flee"
        goal = (x - left > 120) and outLeft or outRight
        dir = goal < x and -1 or 1
    end
    body:SetScript("OnClick", function()
        if state == "flee" or state == "gone" then return end
        Call()
        Flee()
    end)

    local driver = CreateFrame("Frame", nil, f)
    driver:SetScript("OnUpdate", function(_, elapsed)
        local e = min(elapsed, 0.1)
        clock = clock + e
        -- (the painted art, until the model loads; for good after 3 seconds)
        if not loaded and clock > 3 and not sprite:IsShown() then
            m:Hide()
            sprite:Show()
        end
        local speed = 0
        if state == "stand" then
            wait = wait - e
            if wait <= 0 then
                repeat goal = x0 + rnd() * (x1 - x0) until abs(goal - x) > 40
                if loaded and not sprite:IsShown() and abs(goal - x) > 200 then -- (a short trot)
                    goal = x + (goal > x and 1 or -1) * (80 + rnd() * 120)
                end
                state, dir = "walk", goal > x and 1 or -1
            end
        elseif state == "walk" or state == "flee" then
            speed = state == "flee" and art.run or (loaded and not sprite:IsShown()) and m.trot or art.speed
            x = x + dir * speed * e
            if (goal - x) * dir <= 0 then
                x = goal
                if state == "flee" then
                    state, wait = "gone", 8 + rnd() * 12
                    body:Hide()
                else
                    state, wait = "stand", 2 + rnd() * 5
                end
            end
        elseif state == "gone" and on then
            wait = wait - e
            if wait <= 0 then -- (back in from an edge)
                x = rnd(2) == 1 and outLeft or outRight
                dir = x < x0 and 1 or -1
                goal = x0 + (0.2 + rnd() * 0.6) * (x1 - x0)
                state, turned = "walk", nil
                body:Show()
                -- (a model hidden may have let go of its model: loaded again,
                -- OnModelLoaded sets the camera and animation again)
                if loaded then m:SetModel(art.model) end
            end
        end
        if state == "gone" then return end

        step = speed > 0 and step + e * 3.2 or 0
        local bob = (sprite:IsShown() and speed > 0) and abs(sin(step * math.pi)) * 1.5 or 0
        body:ClearAllPoints()
        body:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, y + bob)
        if sprite:IsShown() then
            if dir < 0 then sprite:SetTexCoord(0, 1, 0, 1) else sprite:SetTexCoord(1, 0, 0, 1) end
        elseif loaded then
            -- (turns through facing the front, quickly when bolting)
            local want = dir < 0 and m.facing or -m.facing
            turned = turned or want
            local rate = (state == "flee" and 14 or 5) * e
            turned = turned + max(-rate, min(rate, want - turned))
            m:SetFacing(turned)
            Animate((state == "flee" or state == "walk" and noWalk) and ANIM_RUN
                or state == "walk" and ANIM_WALK or ANIM_STAND)
        end
    end)

    return function(now, quiet)
        on = now and true or false
        if not on and quiet then -- (out of sight at once)
            state = "gone"
            body:Hide()
        elseif not on and (state == "stand" or state == "walk") then
            Call()
            Flee()
        elseif on and state == "gone" then
            wait = math.min(wait, 0.5 + rnd())
        end
    end
end

local function SkinWindow(f, width, leftWidth, skin)
    local fr = skin.frame
    local bar, side = SkinFrame(f, fr), fr.rail
    local bandY, railH, barTop = 88, fr.railH.size, 54 -- (barTop: the bottom bar's top, from the bottom)
    local left = side + 3
    local divider = left + leftWidth + 3
    local right = divider + fr.railV.size + 3

    local fill = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -10)
    fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    fill:SetColorTexture(0.07, 0.055, 0.04, 1)

    -- The lists' floor, its tile `floor.tile` across at any height (the
    -- window's follows Show top), dimmed.
    local floor = skin.floor
    for _, r in ipairs({ { side, divider + 2 }, { divider + fr.railV.size - 2, width - side } }) do
        local m = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        m:SetPoint("TOPLEFT", f, "TOPLEFT", r[1], -bandY)
        m:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", r[2], barTop)
        if floor then
            m:SetTexture(floor.file, "REPEAT", "REPEAT")
            m:SetVertexColor(floor.dim, floor.dim, floor.dim)
            local function Tile()
                local h = math.max(1, (f:GetHeight() or 0) - bandY - barTop)
                m:SetTexCoord(r[1] / floor.tile, r[2] / floor.tile, 0, h / floor.tile)
            end
            f:HookScript("OnSizeChanged", Tile)
            Tile()
        else
            m:SetColorTexture(0.05, 0.05, 0.05, 1)
        end
    end

    -- The bottom bar's board, from the frame's bottom edge up under the rail,
    -- its shape kept, every other one mirrored so the joins don't show (each
    -- starts where the one before ends); dimmed. Without one, the fill.
    if skin.bar then
        local art = skin.bar
        local y0, h = 12, barTop - railH + 3 - 12
        local across = h * art.size[1] / art.size[2]
        local x, i = side, 0
        while x < width - side do
            local w = math.min(across, width - side - x)
            local u = w / across
            local t = f:CreateTexture(nil, "BACKGROUND", nil, -5)
            t:SetTexture(art.file)
            if i % 2 == 1 then t:SetTexCoord(1, 1 - u, 0, 1) else t:SetTexCoord(0, u, 0, 1) end
            t:SetVertexColor(art.dim, art.dim, art.dim)
            t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y0)
            t:SetSize(w, h)
            x, i = x + w, i + 1
        end
    end

    -- The painting behind the selectors, its slice of the picture as wide
    -- as the band, darkened from `top` to `bottom`.
    if skin.band then
        local x0, x1, y0, y1 = side, width - side, bar - 2, bandY + 2
        local span = (y1 - y0) / ((x1 - x0) / 4)
        local paint = f:CreateTexture(nil, "BACKGROUND", nil, -4)
        paint:SetTexture(skin.band.file)
        paint:SetTexCoord(0, 1, skin.band.y - span / 2, skin.band.y + span / 2)
        paint:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y0)
        paint:SetSize(x1 - x0, y1 - y0)
        local shade = f:CreateTexture(nil, "BACKGROUND", nil, -3)
        shade:SetAllPoints(paint)
        shade:SetColorTexture(1, 1, 1, 1)
        if CreateColor then
            shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, skin.band.bottom), CreateColor(0, 0, 0, skin.band.top))
        end
    end

    -- The rails, their ends under the frame's sides; the one down between
    -- the lists under the two across.
    local function Rail(art, sublevel)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        t:SetTexture(art.file)
        return t
    end
    for _, y in ipairs({ { "TOPLEFT", "TOPRIGHT", -(bandY - 2) }, { "BOTTOMLEFT", "BOTTOMRIGHT", barTop - railH + 2 } }) do
        local t = Rail(fr.railH, 1)
        t:SetPoint(y[1], f, y[1], 4, y[3])
        t:SetPoint(y[2], f, y[2], -4, y[3])
        t:SetHeight(railH)
    end
    local down = Rail(fr.railV, 0)
    down:SetPoint("TOPLEFT", f, "TOPLEFT", divider, -bandY)
    down:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", divider, barTop)
    down:SetWidth(fr.railV.size)

    -- The emblem, corner piece, ground decals, leaves and walker: the skin's,
    -- or its season's while that shows (T.SkinPart), swapped as the switch at
    -- the bottom bar's left end turns it off and on.
    local season = T.Season()
    local seasonal = season and season.art or {}
    local emblem = skin.emblem and f:CreateTexture(nil, "ARTWORK", nil, 7)
    if emblem then emblem:SetPoint("CENTER", f, "TOPLEFT", 19, -19) end -- (a rounded square: 4 out past both edges at 46)
    local function Emblem(art)
        if not emblem then return end
        emblem:SetTexture(art.file)
        emblem:SetSize(art.size, art.size)
    end
    local vine = (skin.vine or seasonal.vine) and f:CreateTexture(nil, "ARTWORK")
    if vine then
        vine:SetTexCoord(1, 0, 0, 1)
        vine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 6, 8)
    end
    local function Vine(art)
        if not vine then return end
        vine:SetShown(art ~= nil)
        if art then
            vine:SetTexture(art.file)
            vine:SetSize(art.size, art.size)
        end
    end
    local setDecals, setLeaves, setWalker
    local decals = skin.decals or seasonal.decals
    if decals then
        setDecals = Decals(f, decals, { { side, divider }, { divider + fr.railV.size, width - side } },
            bandY + railH, barTop + railH, decals.dim or (floor and floor.dim) or 1)
    end
    local leaves = skin.leaves or seasonal.leaves
    if leaves then setLeaves = Leaves(f, leaves, side, width - side, bar, barTop) end
    if skin.light then Light(f, skin.light, side, width - side, bar, barTop) end
    -- (the switch at the bar's left end, its label as wide as it takes; the
    -- walker right of it to well clear of the buttons on the right, which are
    -- longer in some languages)
    local walkFrom = side + 4
    if season then
        local switch = W.ToggleRow(f, 120, function() T.SetSeasonOn(not T.SeasonOn()) end)
        switch.label:SetText(season.name)
        switch:SetWidth(math.ceil(switch.label:GetStringWidth() or 0) + 52)
        switch:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", side + 6, 17)
        switch:SetFrameLevel(f:GetFrameLevel() + 3)
        f.seasonSwitch = switch
        walkFrom = side + 6 + switch:GetWidth() + 6
    end
    local walker = skin.walker or seasonal.walker
    if walker then
        setWalker = Walker(f, walker, walkFrom + walker.box[1] / 2, width - 380, 12, side, width - side)
    end
    -- (quiet: as the window is made, nothing bolting)
    local function Season(on, quiet)
        local function Part(key) return on and seasonal[key] or skin[key] end
        Emblem(Part("emblem"))
        Vine(Part("vine"))
        if setDecals and Part("decals") then setDecals(Part("decals")) end
        if setLeaves and Part("leaves") then setLeaves(Part("leaves"), quiet) end
        if setWalker then setWalker(Part("walker") ~= nil, quiet) end
        if f.seasonSwitch then f.seasonSwitch.Update(on) end
    end
    if season then T.OnSeason(Season) end
    Season(T.SeasonOn(), true)

    local closeX, closeY = W.CornerButton()
    return {
        closeX = closeX, closeY = closeY,
        left = left, right = right, rightWidth = width - side - right - 6 - W.ScrollBarWidth(),
        top = bandY + railH, bottom = barTop + 2, selectorX = 50, selectorY = bar + 7, barY = 16, tabY = 1,
        tabGap = 3, dock = { top = 0, bottom = 0, left = 14, right = 4 },
    }
end

function W.ClassicWindow(f, width, leftWidth)
    local own = T.Skin()
    if own and own.frame then return SkinWindow(f, width, leftWidth, own) end
    local leftStretch = leftWidth + 4 - 81 -- (the left inset's inside: 60 + stretch + 21)
    local midStretch = width - 80 - leftStretch - 96 - 256
    local function Piece(key, x0, x1, y0, y1, layer)
        local t = f:CreateTexture(nil, "BACKGROUND", nil, layer or -6)
        t:SetTexture(ART[key])
        t:SetTexCoord(x0 / 256, x1 / 256, y0 / 256, y1 / 256)
        return t
    end
    -- Columns: the top piece, the bottom one, its texels x0..x1, the width
    -- drawn, and whether its band is drawn whole, title strip and all (the
    -- ring's and the close box's). (Below its top rows the middle piece is
    -- shaded unevenly on its left: there it stretches from its right half.)
    -- Band rows, texels y0..y1 drawn from y0' to y1': whole, or the top edge
    -- (to 15), then the stone under the strip (from 34) stretched up to it.
    local whole, cut = { { 0, 120, 0, 120 } }, { { 0, 15, 0, 15 }, { 34, 90, 15, 90 }, { 90, 120, 90, 120 } }
    local x = 0
    for _, c in ipairs({ { "tl", "bl", 0, 70, 70, true }, { "tl", "bl", 70, 80, 10 },
                         { "tl", "bl", 80, 160, leftStretch }, { "tl", "bl", 160, 256, 96 },
                         { "top", "bot", 0, 256, midStretch }, { "tr", "br", 0, 230, 230 },
                         { "tr", "br", 230, 256, 26, true } }) do
        local top, bottom, x0, x1, w, keep = unpack(c)
        for _, r in ipairs(keep and whole or cut) do
            local band = Piece(top, x0, x1, r[1], r[2])
            band:SetPoint("TOPLEFT", f, "TOPLEFT", x, -r[3])
            band:SetSize(w, r[4] - r[3])
        end
        local middle = Piece(top, x0, x1, 120, 256)
        middle:SetPoint("TOPLEFT", f, "TOPLEFT", x, -120)
        middle:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", x + w, 52)
        local bx0 = bottom == "bot" and 130 or x0
        for _, r in ipairs({ { 139, 155, 36 }, { 177, 191, 0 } }) do -- the insets' bottom edge, the frame's
            -- (Past the insets' seam, at 189, the bottom left piece's inset edge
            -- is the top of the Auction House's money box, a light double line:
            -- from there the right inset's edge is the bottom piece's, as along
            -- the rest of it.)
            local seam = r[3] == 36 and bottom == "bl" and x1 == 256 and 189
            local p = Piece(bottom, bx0, seam or x1, r[1], r[2])
            p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, r[3])
            p:SetSize(seam and seam - x0 or w, r[2] - r[1])
            if seam then
                local rest = Piece("bot", 130, 256, r[1], r[2])
                rest:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x + seam - x0, r[3])
                rest:SetSize(w - (seam - x0), r[2] - r[1])
            end
        end
        x = x + w
    end
    -- The bottom bar: its ends, and between them its plain middle, tiled as
    -- drawn (stretched, its grain smeared into streaks).
    for _, s in ipairs({ { "bl", 0, 20, 0, 20 }, { "br", 246, 256, width - 10, 10 } }) do
        local p = Piece(s[1], s[2], s[3], 155, 177)
        p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", s[4], 14)
        p:SetSize(s[5], 22)
    end
    for x0 = 20, width - 11, 126 do
        local w = math.min(126, width - 10 - x0)
        local p = Piece("bot", 130, 130 + w, 155, 177)
        p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x0, 14)
        p:SetSize(w, 22)
    end
    -- The outer edge's rims along the top and the bottom, drawn again over the
    -- pieces from a run of them without the art's notches (the title strip's
    -- rivets on top, fainter ones below, which the stretched columns widen
    -- into bumps), tiled as drawn: on top from the ring's join to the close
    -- box, below between the corners. Each: its piece, texels x0..x1 and
    -- y0..y1, drawn from x to x', at y from the anchor.
    for _, r in ipairs({ { "top", 110, 226, 13, 15, 72, width - 29, "TOPLEFT", -13 },
                         { "bot", 104, 143, 177, 180, 18, width - 8, "BOTTOMLEFT", 11 } }) do
        local key, x0, x1, y0, y1, from, to, anchor, y = unpack(r)
        for x = from, to - 1, x1 - x0 do
            local w = math.min(x1 - x0, to - x)
            local p = Piece(key, x0, x0 + w, y0, y1, -5)
            p:SetPoint(anchor, f, anchor, x, y)
            p:SetSize(w, y1 - y0)
        end
    end

    -- The insets' insides (inside their edges: from 104 down to 39 above the
    -- bottom); a skin's floor instead, its tile `floor.tile` across at any
    -- height (the window's follows Show top), dimmed.
    local skin = T.Skin() or {}
    local floor = skin.floor
    local left = { 20, 80 + leftStretch + 21 }
    local right = { 80 + leftStretch + 29, width - 11 }
    for i, r in ipairs({ left, right }) do
        local m = f:CreateTexture(nil, "BACKGROUND", nil, -5)
        m:SetPoint("TOPLEFT", f, "TOPLEFT", r[1], -104)
        m:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", r[2], 39)
        if floor then
            m:SetTexture(floor.file, "REPEAT", "REPEAT")
            m:SetVertexColor(floor.dim, floor.dim, floor.dim)
            local w = r[2] - r[1]
            local function Tile()
                local h = math.max(1, (f:GetHeight() or 0) - 143)
                -- (offset by its left edge, so the two insets don't start alike)
                m:SetTexCoord(r[1] / floor.tile, (r[1] + w) / floor.tile, 0, h / floor.tile)
            end
            f:HookScript("OnSizeChanged", Tile)
            Tile()
        else
            m:SetTexture(ART.marble, "REPEAT", "REPEAT")
            m:SetHorizTile(true)
            m:SetVertTile(true)
        end
        if i == 1 and not floor then
            local light = f:CreateTexture(nil, "BACKGROUND", nil, -4)
            light:SetAllPoints(m)
            light:SetColorTexture(0.07, 0.07, 0.094, 1)
            light:SetBlendMode("ADD")
        end
    end

    -- The portrait ring (see-through inside: 55 across, its middle 37 in and
    -- 36 down). A skin's portrait: its icon, round, behind the ring, its edge
    -- under it. Else the round emblem over it, rim and all: the ring's old art
    -- has a stepped edge (all or nothing alpha), which shows when the UI is
    -- drawn larger than its texels; the emblem's disc is 68 across (its
    -- texture 1180 for the disc's 1164, tools\skinart.py), covering the ring
    -- (about 65) with a little to spare.
    if skin.portrait then
        local portrait = f:CreateTexture(nil, "BACKGROUND", nil, -7)
        portrait:SetSize(58, 58)
        portrait:SetPoint("CENTER", f, "TOPLEFT", 37, -36)
        portrait:SetTexture(skin.portrait)
        portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- (an icon's border)
        local mask = f.CreateMaskTexture and f:CreateMaskTexture()
        if mask then
            mask:SetTexture(ART.portraitMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(portrait)
            portrait:AddMaskTexture(mask)
        end
    else
        local medallion = f:CreateTexture(nil, "BORDER", nil, 7)
        medallion:SetSize(69, 69)
        medallion:SetPoint("CENTER", f, "TOPLEFT", 37, -36)
        medallion:SetTexture(MEDIA .. "Classic\\Medallion")
    end

    -- A skin's painting in the stone band (15 to 101 down, from the frame's
    -- left edge to the close box's column), its slice of the picture as wide
    -- as the band, darkened from `top` to `bottom`; shown through BandMask
    -- (tools\skinart.py, at this width), which leaves out the portrait ring and
    -- fades it in round the ring and at both ends.
    local band = skin.band
    if band then
        local x0, x1, y0, y1 = 12, width - 26, 15, 101
        local span = (y1 - y0) / ((x1 - x0) / 4) -- (the slice's share of the 4:1 picture's height)
        local paint = f:CreateTexture(nil, "BACKGROUND", nil, -4)
        paint:SetTexture(band.file)
        paint:SetTexCoord(0, 1, band.y - span / 2, band.y + span / 2)
        paint:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y0)
        paint:SetSize(x1 - x0, y1 - y0)
        local shade = f:CreateTexture(nil, "BACKGROUND", nil, -3)
        shade:SetAllPoints(paint)
        shade:SetColorTexture(1, 1, 1, 1)
        if CreateColor then
            shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, band.bottom), CreateColor(0, 0, 0, band.top))
        end
        local mask = f.CreateMaskTexture and f:CreateMaskTexture()
        if mask then
            mask:SetTexture(MEDIA .. "BandMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(paint)
            paint:AddMaskTexture(mask)
            shade:AddMaskTexture(mask)
        end
    end

    -- A skin's corner piece on the top right, mirrored, over the frame's edge.
    if skin.vine then
        local vine = f:CreateTexture(nil, "ARTWORK")
        vine:SetTexture(skin.vine.file)
        vine:SetTexCoord(1, 0, 0, 1)
        vine:SetSize(skin.vine.size, skin.vine.size)
        vine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 6, 8)
    end

    -- (Its top edge is 13 in, a panel's dialog border 4. Its sides are 12 in on
    -- the left, the ring 3, and 2 on the right: with the borders 4 in, both
    -- gaps are 13, the left panel 4 from the ring. Its bottom edge is 11 in,
    -- under its shadow: a panel as tall as it can be ends level with it 7
    -- above its bottom, dock.bottom.)
    return {
        closeX = -14, closeY = -23,
        -- (the right list leaves room for a scroll bar 4 beyond it, up to the inset's edge)
        left = left[1] + 2, right = right[1] + 4, rightWidth = right[2] - right[1] - 8 - W.ScrollBarWidth(),
        top = 108, bottom = 44, selectorX = 74, selectorY = 47, barY = 14, tabY = 11, tabGap = -14,
        dock = { top = 9, bottom = 7, left = -3, right = 7 },
    }
end
