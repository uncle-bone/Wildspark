local _, addonRoot = ...
local ns = addonRoot.WildGear

-- What's new: the first login after an update to a release with notes (NOTES
-- below) shows a small window of its headline changes, each with an icon. A
-- click on one opens the window on it; Open (with the addon's emblem) opens
-- the window. /wildgear news shows it again. In the theme's look (Widgets.lua).
--   WildGear                          x
--   [EMBLEM] What's new in 1.3.0         (accent glow)
--   ============================== (accent rule, fading)
--   |+------------------------------------------+
--   ||[icon] Harvest time in Elwynn             | (a card per note,
--   ||       Elwynn enters harvest time ...     |  lit from the left)
--   ||       [Try it now]                       |
--   |+------------------------------------------+
--   ...
--                  [emblem Open]
-- WildGearDB.notesSeen: the version of the notes last shown, for
-- all characters, so each set shows once. A release without notes of its own
-- (a fix or data update) leaves NOTES as they are, and shows nothing.

local W, T, L = ns.Widgets, ns.Theme, ns.L

local N = {}
ns.WhatsNew = N

-- The release's headline changes, three or four (the /release command writes
-- them): icon (a texture, or a function of the player returning one; nil:
-- a note; badge: a round badge, drawn whole, without the icon's border),
-- open (what a click on it opens), and title and text in each language, a
-- short name and one or two short sentences (English when the client's
-- language is missing). try (optional): a button under the text, "Try it
-- now", while try.shown() (to try what the note is about), running try.run.
-- paint (optional, in place of icon): draws the icon on its texture itself.
local ELWYNN = "elwynn"
-- The harvest season (Elwynn's): from another theme, Settings' Theme list
-- with Elwynn lit; in Elwynn with the season switched off, it on again.
local function HarvestHidden()
    if T.Theme() ~= ELWYNN then return true end
    return T.Season() ~= nil and not T.SeasonOn()
end
local function TryHarvest()
    if T.Theme() ~= ELWYNN then return ns.Settings.ShowTheme(ELWYNN) end
    T.SetSeasonOn(true)
    N.OpenWindow()
end
N.NOTES = {
    version = "1.3.0",
    items = {
        {
            paint = function(tex) ns.WishList.PaintStar(tex) end, -- (the theme's star)
            badge = true,
            open = function() N.OpenWindow() end,
            title = {
                enUS = "Wish list",
                zhCN = "愿望清单",
                zhTW = "願望清單",
                deDE = "Wunschliste",
                koKR = "위시리스트",
                esES = "Lista de deseos",
                esMX = "Lista de deseos",
                ruRU = "Список желаний",
            },
            text = {
                enUS = "Star the items you want on any list. A tracker on screen shows where each one comes "
                    .. "from, and it leaves the list once you have it.",
                zhCN = "在任意列表中为想要的物品加星标。屏幕上的追踪器会显示每件物品的来源，获得后自动移出清单。",
                zhTW = "在任意列表中為想要的物品加星號。螢幕上的追蹤器會顯示每件物品的來源，取得後自動移出清單。",
                deDE = "Markiert gewünschte Gegenstände in jeder Liste mit einem Stern. Ein Tracker zeigt, "
                    .. "woher sie kommen, und entfernt sie, sobald Ihr sie habt.",
                koKR = "원하는 아이템을 어느 목록에서든 별표로 표시하세요. 화면의 추적기가 얻는 곳을 보여 주고, "
                    .. "얻으면 목록에서 빠집니다.",
                esES = "Marca con una estrella los objetos que quieras en cualquier lista. Un rastreador en pantalla "
                    .. "muestra de dónde sale cada uno y lo quita de la lista cuando lo consigues.",
                esMX = "Marca con una estrella los objetos que quieras en cualquier lista. Un rastreador en pantalla "
                    .. "muestra de dónde sale cada uno y lo quita de la lista cuando lo consigues.",
                ruRU = "Отмечайте звездочкой нужные предметы в любом списке. Окно на экране покажет, где добыть "
                    .. "каждый, и уберет его из списка, когда он будет у вас.",
            },
        },
        {
            icon = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Elwynn\\Turkey",
            badge = true,
            open = function() if HarvestHidden() then TryHarvest() else N.OpenWindow() end end,
            try = { shown = HarvestHidden, run = TryHarvest },
            title = {
                enUS = "Harvest time in Elwynn",
                zhCN = "艾尔文森林的丰收时节",
                zhTW = "艾爾文森林的豐收時節",
                deDE = "Erntezeit im Wald von Elwynn",
                koKR = "엘윈 숲의 추수철",
                esES = "Tiempo de cosecha en Elwynn",
                esMX = "Tiempo de cosecha en Elwynn",
                ruRU = "Время урожая в Элвиннском лесу",
            },
            text = {
                enUS = "Elwynn enters harvest time and the maple leaves fall... but something feathered "
                    .. "has invaded the bottom bar. Catch it if you can!",
                zhCN = "艾尔文森林迎来丰收时节，枫叶纷飞……可底栏似乎被什么带羽毛的家伙入侵了。有本事就抓住它！",
                zhTW = "艾爾文森林迎來豐收時節，楓葉紛飛……可底欄似乎被什麼帶羽毛的傢伙入侵了。有本事就抓住它！",
                deDE = "Im Wald von Elwynn ist Erntezeit, Ahornblätter fallen … doch etwas Gefiedertes hat "
                    .. "die untere Leiste besetzt. Fangt es, wenn Ihr könnt!",
                koKR = "엘윈 숲에 추수철이 찾아와 단풍잎이 흩날립니다... 그런데 깃털 달린 무언가가 "
                    .. "아래쪽 막대를 점령했습니다. 잡을 수 있으면 잡아 보세요!",
                esES = "Llega la cosecha al Bosque de Elwynn y caen las hojas de arce... pero algo con plumas "
                    .. "ha invadido la barra inferior. ¡Atrápalo si puedes!",
                esMX = "Llega la cosecha al Bosque de Elwynn y caen las hojas de arce... pero algo con plumas "
                    .. "invadió la barra inferior. ¡Atrápalo si puedes!",
                ruRU = "В Элвиннском лесу пора урожая, падают кленовые листья... но что-то пернатое "
                    .. "захватило нижнюю панель. Поймайте его, если сможете!",
            },
        },
    },
}

local EMBLEM = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Icon"
local EMBLEM_SIZE = 18 -- on Open
local HERO_SIZE = 36 -- the emblem left of the heading
local NOTE_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local WIDTH = 460
local PAD = 18
local ICON = 40
local GAP = 14 -- between an icon and its text
local CARD_PAD = 12 -- inside a note's card, around its icon and text
local STRIPE = 3 -- the accent stripe down a card's left edge (Modern)
local CARD_GAP = 10 -- between cards
local HEAD_TOP = 14 -- above the heading, under the title band
local HEAD_GAP = 12 -- between the heading and the accent rule under it
local RULE_GAP = 14 -- between that rule and the first card
local OPEN_GAP = 16 -- above Open
local TITLE_GAP = 5 -- between a note's name and its text
local LINE_SPACING = 2 -- between the lines of a note's text
local TRY_GAP = 8 -- above a note's Try it now
local DELAY = 4 -- seconds after login, once the game's own windows have come up

local frame

-- A note's text in the client's language, else English.
local function Text(t)
    return t[ns.locale] or t.enUS or ""
end

local function Icon(item)
    local icon = item.icon
    if type(icon) == "function" then
        local ok, path = pcall(icon, ns.GetPlayer())
        icon = ok and path or nil
    end
    return icon or NOTE_ICON
end

-- Opens the window, unless it's open already (UI.Toggle would close it).
function N.OpenWindow()
    if not (ns.UI.Frame() and ns.UI.Frame():IsShown()) then ns.UI.Toggle() end
end

-- Where the title band ends, down from the frame's top: a skin's frame has
-- its title bar for one (W.TitleBand).
local function BandBottom()
    local fr = T.Classic() and T.Skin() and T.Skin().frame
    if fr then return fr.bar * fr.scale end
    return 1 + W.Inset() + W.TITLE_HEIGHT
end

-- The accent on `tex`, fading from alpha a1 to a2 (left to right, or bottom
-- to top); flat at a1 where gradients are missing.
local function Fade(tex, orient, a1, a2)
    local r, g, b = T.Accent()
    local ok = CreateColor and pcall(tex.SetGradient, tex, orient, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
    if not ok then tex:SetColorTexture(r, g, b, a1) end
end

-- `fs` in font object `object`'s font, `plus` points bigger (so it follows
-- the text size and font settings).
local function Bigger(fs, object, plus)
    local path, size, flags = object:GetFont()
    if path and size then fs:SetFont(path, math.floor(size + 0.5) + plus, flags or "") end
end

-- Sizes the cards to their wrapped text and the frame to its cards, again on
-- a change of text size, font or accent: the heading (the version in the
-- accent) by the emblem, a glow rising to the accent rule under it, then the
-- cards, then Open.
local function Layout()
    local inset = W.Inset()
    local left = PAD + inset
    local inner = WIDTH - 2 * PAD -- a card's width
    local textWidth = inner - 2 * CARD_PAD - ICON - GAP
    frame:SetScale(T.Get("scale"))
    frame:SetSize(WIDTH + 2 * inset, 100)

    local y = BandBottom() + HEAD_TOP
    frame.hero:ClearAllPoints()
    frame.hero:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -y)
    Bigger(frame.heading, WildGearFontNormalLarge, 4)
    frame.heading:SetText(string.format(L["What's new in %s"], T.AccentHex() .. N.NOTES.version .. "|r"))
    y = y + math.max(HERO_SIZE, frame.heading:GetStringHeight() or 20) + HEAD_GAP
    frame.rule:ClearAllPoints()
    frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -y)
    frame.rule:SetWidth(inner)
    Fade(frame.rule, "HORIZONTAL", 0.9, 0)
    frame.glow:ClearAllPoints()
    frame.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + inset, -BandBottom())
    frame.glow:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -1 - inset, -y)
    Fade(frame.glow, "VERTICAL", 0.16, 0)
    y = y + 1 + RULE_GAP

    for _, row in ipairs(frame.rows) do
        Bigger(row.title, WildGearFontNormal, 1)
        Bigger(row.text, WildGearFontHighlightSmall, 1) -- (as the bubbles')
        row.title:SetWidth(textWidth)
        row.text:SetWidth(textWidth)
        local h = (row.title:GetStringHeight() or 12) + TITLE_GAP + (row.text:GetStringHeight() or 12)
        if row.try then
            local shown = row.item.try.shown()
            row.try:SetShown(shown)
            if shown then
                W.SetActive(row.try, true)
                h = h + TRY_GAP + row.try:GetHeight()
            end
        end
        h = math.max(ICON, h) + 2 * CARD_PAD
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -y)
        row:SetSize(inner, h)
        row.wash:SetWidth(inner * 0.6)
        Fade(row.wash, "HORIZONTAL", 0.14, 0)
        if row.stripe then row.stripe:SetColorTexture(T.Accent()) end
        y = y + h + CARD_GAP
    end

    local open = frame.open
    open:SetWidth(math.max(140, (open.label:GetStringWidth() or 0) + EMBLEM_SIZE + 6 + 40))
    W.SetActive(open, true) -- (lit: what the window is for)
    if not T.Classic() then open.label:SetTextColor(T.Accent()) end -- (Classic: the button's gold)
    frame:SetHeight(y - CARD_GAP + OPEN_GAP + open:GetHeight() + PAD + inset)
end

-- One of the notes: a card (a box as the Settings panel's, lit from the left
-- in the accent, with an accent stripe in the Modern theme) with its icon,
-- its name (in gold) and its text under it; a click opens what it's about,
-- in place of this window.
local function Row(item)
    local row = CreateFrame("Button", nil, frame, "BackdropTemplate")
    W.Box(row)
    local edge = T.Classic() and 4 or 1 -- (inside the box's border)
    row.wash = row:CreateTexture(nil, "BORDER")
    row.wash:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -edge)
    row.wash:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", edge, edge)
    row.wash:SetTexture("Interface\\Buttons\\WHITE8X8")
    if not T.Classic() then
        row.stripe = row:CreateTexture(nil, "ARTWORK")
        row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -edge)
        row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", edge, edge)
        row.stripe:SetWidth(STRIPE)
    end
    W.AddHighlight(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD, -CARD_PAD)
    if item.badge then
        -- (whole: its own round rim; as big as the others with their border
        -- (Classic, W.IconBorder: 39/31) or crop (Modern), on their middle)
        local size = math.floor(ICON * (T.Classic() and 39 / 31 or 1.12) + 0.5)
        row.icon:SetSize(size, size)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("CENTER", row, "TOPLEFT", CARD_PAD + ICON / 2, -(CARD_PAD + ICON / 2))
        row.icon:SetTexCoord(0, 1, 0, 1)
    elseif T.Classic() then
        W.IconBorder(row.icon)
    else
        row.icon:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64)
    end
    row.title = row:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_PAD + ICON + GAP, -CARD_PAD) -- (past the icon's place)
    row.title:SetJustifyH("LEFT")
    row.title:SetText(Text(item.title))
    row.text = row:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -TITLE_GAP)
    row.text:SetJustifyH("LEFT")
    row.text:SetSpacing(LINE_SPACING)
    row.text:SetTextColor(0.85, 0.85, 0.85)
    row.text:SetText(Text(item.text))
    row.item = item
    row:SetScript("OnClick", function()
        frame:Hide()
        if item.open then item.open() else N.OpenWindow() end
    end)
    if item.try then -- (under the text, lit as Open: what the note asks)
        row.try = W.FitButton(W.FlatButton(row, "", 90, 22))
        row.try:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -TRY_GAP)
        row.try:SetText(L["Try it now"])
        row.try:SetScript("OnClick", function()
            frame:Hide()
            item.try.run()
        end)
    end
    return row
end

local function Create()
    if not ns.UI.Frame() then T.Apply() end -- (the fonts, before any text is measured: UI.lua's Create)
    frame = CreateFrame("Frame", "WildGearWhatsNew", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH + 2 * W.Inset(), 100)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    W.Window(frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- (again a frame after it shows, in case text measured while hidden came out short)
    frame:SetScript("OnShow", function() if C_Timer and C_Timer.After then C_Timer.After(0, Layout) end end)
    table.insert(UISpecialFrames, "WildGearWhatsNew") -- close with Escape

    local _, band = W.TitleBand(frame, "WildGear", "WildGearFontNormal")
    local close = W.CloseButton(frame)
    if not T.Classic() then close:SetPoint("RIGHT", band, "RIGHT", -(W.TITLE_HEIGHT - 20) / 2, 0) end
    frame.close = close

    -- The heading: the emblem, big, and "What's new in 1.3.0" by it, over a
    -- glow in the accent rising to a rule under them.
    frame.glow = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.rule = W.Rule(frame, 1, 1, 1, 1)
    frame.hero = frame:CreateTexture(nil, "ARTWORK")
    frame.hero:SetSize(HERO_SIZE, HERO_SIZE)
    frame.hero:SetTexture(EMBLEM)
    frame.heading = frame:CreateFontString(nil, "OVERLAY", "WildGearFontNormalLarge")
    frame.heading:SetPoint("LEFT", frame.hero, "RIGHT", 10, 0)
    frame.heading:SetTextColor(1, 1, 1)

    frame.rows = {}
    for i, item in ipairs(N.NOTES.items) do
        frame.rows[i] = Row(item) -- (placed by Layout)
    end

    -- Open: the window, the addon's emblem left of its label (both its own,
    -- so they center together).
    local open = W.FlatButton(frame, "", 140, 26)
    open:SetPoint("BOTTOM", frame, "BOTTOM", 0, PAD + W.Inset())
    open.label = open:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    open.label:SetPoint("CENTER", open, "CENTER", (EMBLEM_SIZE + 6) / 2, 0)
    open.label:SetText(L["Open"])
    open.emblem = open:CreateTexture(nil, "OVERLAY")
    open.emblem:SetSize(EMBLEM_SIZE, EMBLEM_SIZE)
    open.emblem:SetPoint("RIGHT", open.label, "LEFT", -6, 0)
    open.emblem:SetTexture(EMBLEM)
    open:SetScript("OnClick", function()
        frame:Hide()
        N.OpenWindow()
    end)
    frame.open = open

    frame:Hide()
    T.Track(Layout)
end

-- Shows the notes (/wildgear news).
function N.Show()
    if not N.NOTES then return end
    if not frame then Create() end
    for _, row in ipairs(frame.rows) do -- (your spec may have changed)
        if row.item.paint then row.item.paint(row.icon) else row.icon:SetTexture(Icon(row.item)) end
    end
    Layout()
    frame:Show()
    ns.db.notesSeen = N.NOTES.version -- (seen once it's up)
end

function N.Frame()
    return frame
end

-- At login, the notes not shown yet, a few seconds on, out of combat.
local events = CreateFrame("Frame")
local function ShowDue()
    if not N.NOTES or ns.db.notesSeen == N.NOTES.version then return end
    if InCombatLockdown() then return events:RegisterEvent("PLAYER_REGEN_ENABLED") end
    N.Show()
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then self:UnregisterEvent(event) end
    if C_Timer and C_Timer.After then C_Timer.After(event == "PLAYER_LOGIN" and DELAY or 1, ShowDue) else ShowDue() end
end)
