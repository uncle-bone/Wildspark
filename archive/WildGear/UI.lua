local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Main window with four tabs, all driven by the character selectors on top:
--   Best in slot: best item per slot on the left, and for the selected slot
--                 what you wear, then the top N quest / dungeon / crafted / BoE
--                 items on the right, each compared with what you wear (BoE
--                 only while Settings' BoE filter is on), or with List: All
--                 sources the top N of them all in one list.
--   Dungeon loot: dungeons on the left with their upgrade counts (those near
--                 your level; Earlier and Later fold the rest); on the
--                 right the selected dungeon in three views: Summary (its
--                 upgrades per slot, the quests to pick up, look-ahead
--                 upgrades), Bosses (each boss's gear) and Quests (every
--                 quest, with its gear rewards), with usability, slot rank and gain.
--   Crafting patterns: professions and a Filters box (Show, Slot) on the left; on the right
--                 the selected profession's patterns for rare or better gear,
--                 grouped by how to learn them (Waylaid Supplies vendor,
--                 trainer, dungeon drop), with the skill they need and their
--                 item's rank. Lists only gear usable at the profile's level
--                 unless Show: All patterns is picked.
--   Quests:       quest gear rewards by zone (QuestsTab.lua), in the loot list
--                 too (UI.List).
-- Its building blocks are in Widgets.lua, its colors and fonts in Theme.lua.

local UI = {}
ns.UI = UI
local L, W, T = ns.L, ns.Widgets, ns.Theme

local WIDTH = 860
local PAD = 14
local SELECTOR_Y = 40 -- top of the selector row
local TAB_Y = 90
local TAB_HEIGHT = 24
local TOP_HEIGHT = TAB_Y + TAB_HEIGHT + 10 -- everything above the lists
local BOTTOM = PAD -- below them (these and SELECTOR_Y, TAB_Y: the Classic theme's frame has its own, Create)
local SLOT_HEIGHT = 25
local DUNGEON_HEIGHT = 22
local LEFT_WIDTH = 250
local COLUMN_GAP = 16
local ROW_HEIGHT = 24
local HEADER_HEIGHT = 22
local SECTION_GAP = 14
local MAX_TOP = 10
local QUESTION_MARK = 134400 -- Interface\Icons\INV_Misc_QuestionMark
local FACTION_COLOR = { Alliance = "|cff4a9eff", Horde = "|cffff5050" }
local SOURCE_COLOR = { quest = { 1, 0.82, 0 }, drop = { 0.35, 0.65, 1 }, crafted = { 0.4, 0.9, 0.45 },
    boe = { 0.2, 0.8, 0.8 }, worn = { 0.8, 0.8, 0.8 }, all = { 0.7, 0.55, 1 } }
local UPGRADE = "|cff33ff99" -- look-ahead upgrades
local MAX_UPCOMING = 5 -- look-ahead rows per source section

local WORN_CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " -- slot's best item is worn

local LOOT_LINES = 22 -- visible lines in the loot list (scrolls), about the dungeon list's height
-- Above the loot lines: the title, then Dungeon loot's view tabs, or in their
-- row Crafting patterns' column headers (two numbers side by side there,
-- skill and price, need them).
local LOOT_TOP = 56

local frame, rightPanel, slotPanel, myCharButton, wornSection
local selectors, slotButtons, sections = {}, {}, {}
local ranked
local selectedSlot = "head"
local mode = "bis" -- "bis", "loot", "patterns" or "quests"
local tabs = {}
local dungeonPanel, lootPanel -- the loot list also shows the Crafting patterns tab's list
local dungeonButtons = {}
local selectedDungeon -- ns.Dungeons id (tools/scraper/dungeons.json); defaults to the one matching the profile's level
local lootOffset = 0 -- scroll position of the loot list
local listOffsets = {} -- [mode] = its loot list scroll position while another tab is shown
local professionPanel -- Crafting patterns' left column: professions, then the filters box
local professionButtons = {}
local patternFilters -- CreatePatternFilters()
local gearPanel -- worn gear side panel
local gear -- ns.GetEquipped: scored for the profile when it is your own class, else unscored
local worn -- `gear` while the profile is your own class, else nil (no comparisons)

-- Show top (Settings panel): items per source on Best in slot (with List: All
-- sources, in the one list), 1 to UI.MAX_TOP.
local function TopN()
    return ns.db.topN or 5
end
UI.TopN, UI.MAX_TOP = TopN, MAX_TOP

local function Sim()
    ns.charDB.sim = ns.charDB.sim or {}
    return ns.charDB.sim
end

-- Item `id`'s icon file; with `tex`, also shown on that texture, its ring
-- (W.IconRing) in the item's quality color.
local function ItemIcon(id, tex)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    icon = icon or QUESTION_MARK
    if tex then
        tex:SetTexture(icon)
        W.SetIconQuality(tex, ns.ItemQuality(id))
    end
    return icon
end
UI.ItemIcon = ItemIcon -- (QuestPanel.lua)

-- `suffix`: a ranked entry's random suffix (ns.Suffixes id).
local function ColoredName(id, suffix)
    return ns.QualityHex(ns.ItemQuality(id)) .. ns.ItemName(id, suffix) .. "|r"
end

-- Name of a worn item, which may not be in Data/Items.lua (see Equipped.lua).
local function WornName(w)
    if w.item then return ns.QualityHex(ns.ItemQuality(w.id)) .. ns.WornItemName(w) .. "|r" end
    return "|cff888888" .. L["loading item..."] .. "|r"
end

local function ClassColored(classFile, text)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return (c and c.colorStr) and ("|c" .. c.colorStr .. text .. "|r") or text
end

-- First source of the given type, or the first source overall.
local function SourceOf(entry, sourceType)
    for _, s in ipairs(entry.sources) do
        if s.type == sourceType then return s end
    end
    return entry.sources[1]
end

local function Changed()
    W.HidePopup()
    UI.Refresh()
end

---------------------------------------------------------------- item rows

local QUEST_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t "
local QUEST_LINK = "|cffffd100" -- hoverable quest names

-- Whether hovering quest source `s` has details to show.
local function HasQuestDetails(s)
    return s and s.type == "quest" and ns.Quests and ns.Quests[s.id] ~= nil
end

-- The quest's own tooltip (starter, zone, chain...), shown when hovering a
-- quest name rather than the item.
local function ShowQuestTooltip(owner, s)
    local lines = ns.QuestTooltipLines(s, ns.GetProfile())
    if #lines == 0 then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            GameTooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
        else
            GameTooltip:AddLine(line, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function ShowItemTooltip(owner)
    local entry = owner.entry
    if not entry then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    -- (a ranked item with random suffixes: the one it is ranked with; a worn
    -- one as the game shows it in its slot, with no comparison to itself)
    local link = entry.link or ns.SuffixLink(entry.id, entry.suffix)
    if entry.worn and entry.invSlot and GetInventoryItemID("player", entry.invSlot) == entry.id then
        GameTooltip:SetInventoryItem("player", entry.invSlot)
    else
        GameTooltip:SetHyperlink(link or ("item:" .. entry.id))
    end
    -- The block item tooltips show everywhere (Tooltip.lua), for the profile
    -- shown (beside the Character frame, your own); then what only the window
    -- knows: why a listed item isn't ranked, look-ahead upgrades, other
    -- picks, where to get it.
    local parent = owner:GetParent()
    local p = (parent and parent.sheet) and ns.GetPlayer() or ns.GetProfile()
    local r = ns.Tooltip.AddBlock(GameTooltip, entry.id, link, p)
    local lines = {} -- { text, grey level, wrap }
    local why = (entry.worn and not entry.item and L["loading item..."]) or (not entry.score and entry.why)
    if why and not (r and (r.cant or r.reason or r.unlock)) then lines[#lines + 1] = { why, 0.53 } end
    if owner.rankText then lines[#lines + 1] = { owner.rankText, 1, true } end
    for _, text in ipairs(owner.extraLines or {}) do lines[#lines + 1] = { text, 1, true } end
    -- Where to get it, but not where a BoE drops: the row says where, and a
    -- BoE can drop all over (each wing of Scarlet Monastery, from trash).
    local said = {}
    for _, s in ipairs(entry.sources) do
        local text = not (s.boe or s.type == "boe") and ns.DescribeSource(s)
        if text and not said[text] then lines[#lines + 1], said[text] = { text, 0.7, true }, true end
    end
    if owner.questHit and owner.questHit:IsShown() then
        lines[#lines + 1] = { L["Hover the quest name for its details; right-click to pin its quest giver"], 0.53 }
    end
    -- Apart from the block's boxes, or from the game's lines when there's no block.
    if not r then GameTooltip:AddLine(" ") elseif lines[1] then ns.Tooltip.Gap(GameTooltip) end
    local first = GameTooltip:NumLines() + 1
    for _, l in ipairs(lines) do GameTooltip:AddLine(l[1], l[2], l[2], l[2], l[3]) end
    ns.Tooltip.NormalFont(GameTooltip, first)
    ns.Tooltip.HintLast(GameTooltip)
    GameTooltip:Show()
end

-- Item lines show the item; quest header lines (Dungeon loot tab) the quest;
-- other lines their `tip`, if any.
local function OnLineEnter(self)
    if self.entry then
        ShowItemTooltip(self)
    elseif self.quest then
        ShowQuestTooltip(self, self.quest)
    elseif self.tip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tip, 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- Shift-click links the item in chat, ctrl-click previews it (standard behaviour).
-- Right-click on a quest reward row or quest header pins the quest giver on the
-- map; left-click on a quest header (no item) opens the quest panel.
local function OnItemClick(self, button)
    if button == "RightButton" then
        if self.quest then ns.PinQuest(self.quest) end
        return
    end
    if self.entry and IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        HandleModifiedItemClick(self.entry.link or ns.ItemLink(self.entry.id, self.entry.suffix))
    elseif not self.entry and self.quest then
        ns.QuestPanel.Show(self.quest)
    end
end

-- Whether the character wears item `id` (whatever profile is planned), with
-- random suffix `suffix` when given.
-- UI fields rather than locals: this file is near Lua's 200 locals limit.
function UI.IsWorn(id, suffix)
    for _, list in pairs(gear or {}) do
        for _, w in ipairs(list) do
            if w.id == id and not (suffix and w.suffix and w.suffix ~= suffix) then return true end
        end
    end
    return false
end

UI.WORN_RGB = { 0.4, 0.7, 1 }

-- Green tick before the name on a list row whose item is worn; call it after
-- the name is set. The name is the first shown of button.names (default
-- button.name). The Equipped section and the gear panel list only worn
-- items, so they stay plain.
function UI.MarkWorn(button)
    local entry = button.entry
    if not (entry and not entry.worn and UI.IsWorn(entry.id, entry.suffix)) then return end
    for _, fs in ipairs(button.names or { button.name }) do
        if fs:IsShown() then
            fs:SetText(WORN_CHECK .. (fs:GetText() or ""))
            return
        end
    end
end

local function SetupItemButton(button)
    W.AddHighlight(button)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnEnter", OnLineEnter)
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnClick", OnItemClick)
end

-- Hover area over a row's quest text: shows the quest tooltip instead of the
-- item's; a plain left-click opens the quest panel, other clicks (right-click
-- pin, shift/ctrl-click on the item) go to the row. Covers `text` up to its
-- string width (see FitQuestHit), with row.quest the quest source.
local function AddQuestHit(row, text)
    local hit = CreateFrame("Button", nil, row)
    hit:SetPoint("TOPLEFT", text, "LEFT", 0, ROW_HEIGHT / 2)
    hit:SetHeight(ROW_HEIGHT)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    W.AddHighlight(hit)
    hit:SetScript("OnEnter", function(self)
        local quest = self:GetParent().quest
        if quest then ShowQuestTooltip(self, quest) end
    end)
    hit:SetScript("OnLeave", HideTooltip)
    hit:SetScript("OnClick", function(self, button)
        local parent = self:GetParent()
        if button ~= "RightButton" and parent.quest and not (IsModifiedClick and IsModifiedClick()) then
            ns.QuestPanel.Show(parent.quest)
        else
            parent:GetScript("OnClick")(parent, button)
        end
    end)
    hit:Hide()
    row.questHit = hit
end

-- Shows row.questHit over the text just set on `text` when row.quest has details.
local function FitQuestHit(row, text)
    if not HasQuestDetails(row.quest) then
        row.quest = nil
        row.questHit:Hide()
        return
    end
    local width, room = text:GetStringWidth(), text:GetWidth()
    row.questHit:SetWidth(math.max(20, (room and room > 0) and math.min(width, room) or width))
    row.questHit:Show()
end

---------------------------------------------------------------- selectors

local function RaceById(id)
    for _, r in ipairs(ns.Races) do
        if r.id == id then return r end
    end
end

local classDef = {
    label = L["Class"], width = 110,
    options = function()
        local p = ns.GetProfile()
        local out = {}
        for _, c in ipairs(ns.Classes) do
            out[#out + 1] = { text = ClassColored(c.file, c.name), value = c.file, selected = c.file == p.classFile }
        end
        return out
    end,
    set = function(v)
        local real = ns.GetPlayer()
        local sim = Sim()
        sim.classFile = (v ~= real.classFile) and v or nil
        sim.spec = nil
        -- If the current race can't be the new class, switch to its first race.
        local race, class = RaceById(ns.GetProfile().raceId), nil
        for _, c in ipairs(ns.Classes) do
            if c.file == v then class = c break end
        end
        if class and not (race and ns.RaceAllowsClass(race, class.id)) then
            for _, r in ipairs(ns.Races) do
                if ns.RaceAllowsClass(r, class.id) then
                    sim.raceId = (r.id ~= real.raceId) and r.id or nil
                    break
                end
            end
        end
        Changed()
    end,
    fallback = function() return ns.GetProfile().className end,
}

local raceDef = {
    label = L["Race"], width = 126,
    -- Only races that can be the selected class (Forever changed some combos).
    options = function()
        local p = ns.GetProfile()
        local out = {}
        for _, r in ipairs(ns.Races) do
            if ns.RaceAllowsClass(r, p.classId) or r.id == p.raceId then
                out[#out + 1] = { text = FACTION_COLOR[r.faction] .. ns.RaceName(r) .. "|r", value = r.id,
                                  selected = r.id == p.raceId }
            end
        end
        return out
    end,
    set = function(v)
        Sim().raceId = (v ~= ns.GetPlayer().raceId) and v or nil
        Changed()
    end,
    fallback = function() return ns.GetProfile().raceName end,
}

-- Forever has no API for the talent spec: until one is picked, the class's
-- first spec is shown in orange. Each spec with its icon.
local specDef = {
    label = L["Talent spec"], width = 124,
    options = function()
        local p = ns.GetProfile()
        local out = {}
        for _, key in ipairs(ns.Specs[p.classFile]) do
            local guess = key == p.spec and p.specSource == "default"
            out[#out + 1] = { text = ns.Tooltip.SpecLabel(p, key, guess), value = key, selected = key == p.spec }
        end
        return out
    end,
    set = function(v)
        if ns.GetProfile().classFile == ns.GetPlayer().classFile then return UI.SetMainSpec(v) end
        Sim().spec = v
        Changed()
    end,
}

-- Your character's main spec `v`, saved for this character: the Talent spec
-- box while the window plans your own class, and the box beside the
-- Character frame (which leaves another class's planned spec alone).
function UI.SetMainSpec(v)
    ns.charDB.spec = v
    if ns.GetProfile().classFile == ns.GetPlayer().classFile then Sim().spec = nil end
    Changed()
end

-- Two-hander / dual wield / 1H + shield / 1H + off-hand, limited to what the
-- class, spec and level allow. Saved per class/spec. Setups weighted for a
-- weapon imbue (Enhancement) name it in the list and tooltip, and show its
-- icon in the box (`short`).
local weaponDef = {
    label = L["Weapons"], width = 200,
    options = function()
        local p = ns.GetProfile()
        local pref = ns.GetWeaponSetupPref(p)
        local out = {}
        for _, key in ipairs(ns.WeaponSetupOptions(p)) do
            out[#out + 1] = { text = ns.WeaponSetupLabel(p, key), short = ns.WeaponSetupLabel(p, key, true),
                              value = key, selected = key == pref }
        end
        return out
    end,
    set = function(v)
        ns.SetWeaponSetupPref(ns.GetProfile(), v)
        Changed()
    end,
}

local function SetLevel(level)
    Sim().level = (level ~= ns.GetPlayer().level) and level or nil
    Changed()
end

local levelDef = {
    label = L["Level"], width = 100,
    hint = L["Scroll to change"], -- (Shift moves 5 levels)
    options = function()
        local p, real = ns.GetProfile(), ns.GetPlayer()
        local seen = { [1] = true, [p.level] = true, [real.level] = true }
        for l = 5, ns.MAX_LEVEL, 5 do seen[l] = true end
        local levels = {}
        for l in pairs(seen) do levels[#levels + 1] = l end
        table.sort(levels)
        local out = {}
        for _, l in ipairs(levels) do
            out[#out + 1] = { text = (l == real.level) and string.format(L["%d (you)"], l) or tostring(l), value = l,
                              selected = l == p.level }
        end
        return out
    end,
    set = SetLevel,
    -- The wheel moves one level at a time, five with shift held.
    step = function(delta)
        local amount = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
        local top = math.max(ns.MAX_LEVEL, ns.GetPlayer().level)
        SetLevel(math.max(1, math.min(top, ns.GetProfile().level + delta * amount)))
    end,
}

local aheadDef = {
    label = L["Look ahead"], width = 100,
    hint = L["Scroll to change"],
    options = function()
        local current = ns.charDB.ahead or 0
        local out = {}
        for n = 0, 10 do
            local text = (n == 0) and L["None"] or ns.Plural(n, "+%d level", "+%d levels")
            out[#out + 1] = { text = text, value = n, selected = n == current }
        end
        return out
    end,
    set = function(v)
        ns.charDB.ahead = (v > 0) and v or nil
        Changed()
    end,
}


---------------------------------------------------------------- side panels

-- The Stat weights panel (WeightsPanel.lua), docked on the right.
local weightsPanel

-- The window's Talent spec box (the stat weights tour points at it).
function UI.SpecBox()
    for _, s in ipairs(selectors) do
        if s.def == specDef then return s.value end
    end
end

-- Only one panel (stat weights or quest details) docks on the right at a time;
-- each calls this from OnShow to close the other.
local sidePanel
function UI.ClaimSide(panel)
    if sidePanel and sidePanel ~= panel then sidePanel:Hide() end
    sidePanel = panel
    UI.DockSides()
end

---------------------------------------------------------------- left: slots

local function CreateSlotButton(parent, group, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(LEFT_WIDTH, SLOT_HEIGHT)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * SLOT_HEIGHT)
    b.group = group
    W.AddSelection(b)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", b, "LEFT", 7, 0)
    W.IconBorder(b.icon)

    b.label = b:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetWidth(58)
    b.label:SetJustifyH("LEFT")
    b.label:SetText(group.label)

    -- "lvl 24" when look-ahead finds an upgrade for this slot.
    b.next = b:CreateFontString(nil, "OVERLAY", "WildGearFontNormalSmall")
    b.next:SetPoint("RIGHT", b, "RIGHT", -6, 0)

    b.name = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    b.name:SetPoint("LEFT", b.label, "RIGHT", 4, 0)
    b.name:SetPoint("RIGHT", b.next, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    SetupItemButton(b)
    b:SetScript("OnClick", function(self)
        if self.entry and IsModifiedClick and IsModifiedClick() then
            OnItemClick(self)
            return
        end
        selectedSlot = self.group.key
        UI.Refresh()
    end)
    return b
end

---------------------------------------------------------------- right: sections

local function CreateRow(parent, index, width)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)

    -- Modern: every row on the card's light, so a section's rows make one card
    -- under its header (the game's lists have none)
    if not T.Classic() then
        local card = row:CreateTexture(nil, "BACKGROUND")
        card:SetAllPoints()
        card:SetColorTexture(unpack(T.CARD))
    end
    -- green tint for look-ahead upgrades
    row.upcoming = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.upcoming:SetAllPoints()
    row.upcoming:SetColorTexture(0.2, 1, 0.6, 0.06)
    row.upcoming:Hide()

    row.rank = row:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    row.rank:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.rank:SetWidth(20)
    row.rank:SetJustifyH("RIGHT")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.rank, "RIGHT", 6, 0)
    W.IconBorder(row.icon)

    -- (white in the Modern theme, so the green gains stand out; the game's gold in Classic)
    row.score = row:CreateFontString(nil, "OVERLAY", T.Classic() and "WildGearFontNormalSmall"
        or "WildGearFontHighlightSmall")
    row.score:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.score:SetWidth(44)
    row.score:SetJustifyH("RIGHT")

    -- score against the worn item it would replace
    row.delta = row:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    row.delta:SetPoint("RIGHT", row.score, "LEFT", T.Classic() and -4 or -8, 0) -- (Modern: room for the chips)
    row.delta:SetWidth(46)
    row.delta:SetJustifyH("RIGHT")
    W.GainChip(row.delta) -- (Modern: a gain on a green chip; and a look-ahead upgrade's score)
    W.GainChip(row.score)

    row.name = row:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetWidth(210)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.source = row:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    row.source:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.source:SetPoint("RIGHT", row.delta, "LEFT", -8, 0)
    row.source:SetJustifyH("LEFT")
    row.source:SetWordWrap(false)

    SetupItemButton(row)
    AddQuestHit(row, row.source)
    -- The wish list's star, in place of the rank number (WishList.lua).
    ns.WishList.Star(row, row.rank):SetPoint("RIGHT", row.rank, "RIGHT", 0, 0)
    return row
end

local function CreateSection(parent, sourceType, width, rowCount)
    rowCount = rowCount or (MAX_TOP + MAX_UPCOMING)
    local sec = CreateFrame("Frame", nil, parent)
    sec:SetSize(width, HEADER_HEIGHT + rowCount * ROW_HEIGHT)
    sec.type = sourceType
    local r, g, b = unpack(SOURCE_COLOR[sourceType] or T.GOLD)

    -- Colored marker per source type; the header text stays white, apart
    -- from the item names (in their quality colors) below it, and the rows'
    -- card sets the section apart (CreateRow).
    -- Classic: no marker, the header in the color, over a rule fading out.
    local classic = T.Classic()
    local marker = sec:CreateTexture(nil, "ARTWORK")
    marker:SetSize(3, 14)
    marker:SetPoint("TOPLEFT", sec, "TOPLEFT", 0, -2)
    marker:SetColorTexture(r, g, b, classic and 0 or 1)

    sec.header = sec:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    sec.header:SetPoint("LEFT", marker, "RIGHT", classic and 0 or 7, 0)
    if classic then sec.header:SetTextColor(r, g, b) else sec.header:SetTextColor(1, 1, 1) end

    if classic then
        local line = W.FadeRule(sec, r, g, b, 0.6)
        line:SetPoint("TOPLEFT", sec, "TOPLEFT", 0, -HEADER_HEIGHT + 2)
        line:SetPoint("TOPRIGHT", sec, "TOPRIGHT", 0, -HEADER_HEIGHT + 2)
    end

    sec.empty = sec:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    sec.empty:SetPoint("TOPLEFT", sec, "TOPLEFT", 26, -HEADER_HEIGHT - 6)
    sec.empty:SetText(L["No usable items for this slot."])

    sec.rows = {}
    for i = 1, rowCount do sec.rows[i] = CreateRow(sec, i, width) end
    return sec
end

---------------------------------------------------------------- worn gear

local GAIN, SAME = "|cff33ff99", "|cff888888"

local function ShowIf(widget, on)
    if on then widget:Show() else widget:Hide() end
end

local function SlotCount(key)
    for _, g in ipairs(ns.SlotGroups) do
        if g.key == key then return g.slots or 1 end
    end
    return 1
end

-- The worn item `entry` would replace in slot `key`: the only one, or the
-- weaker of two rings / trinkets. Nil when a slot is still free; the worn
-- entry and true when `entry` is itself worn. A two-hander replaces both
-- hands: with an off hand worn, one entry for the two (`hands`), their scores summed.
-- A second copy of a ring or trinket (`entry.copy`, ns.SlotPick) is worn
-- when both are, and else replaces the other one.
local function Replaced(key, entry)
    local list = worn and worn[key]
    if not list then return nil end
    local other, copies
    for _, w in ipairs(list) do
        -- (the same item with another random suffix is another item)
        if w.id ~= entry.id or (entry.suffix and w.suffix and w.suffix ~= entry.suffix) then
            other = w
        elseif not entry.copy then
            return w, true
        else
            copies = (copies or 0) + 1
            if copies == 2 then return w, true end
        end
    end
    if entry.copy and copies then
        if #list < SlotCount(key) then return nil end
        return other
    end
    local off = key == "mainhand" and entry.item and entry.item.slot == 17 and worn.offhand and worn.offhand[1]
    if off then
        local main = list[1]
        if not main then return off end
        return { id = main.id, item = main.item and off.item, hands = { main, off },
                 score = main.score and off.score and main.score + off.score }
    end
    if #list < SlotCount(key) then return nil end
    return list[#list]
end

-- On a two-hander setup, whether you hold an off hand: its row stays in My
-- gear (and, empty, in the slot list beside it), as a two-hander replaces it
-- too. `d`: a gear panel's data (UpdateGearPanel) for its own rankings, else the window's.
function UI.KeepOffRow(d)
    local ranked, gear = ranked, gear
    if d then ranked, gear = d.ranked, d.gear end
    return ranked ~= nil and not ranked.offhand and gear ~= nil and gear.offhand ~= nil and gear.offhand[1] ~= nil
end

-- A ranked entry against the worn item it would replace: short text for the
-- "vs worn" column ("+3.2", "-1.0", a grey "0.0" when worn or as good), a tooltip line, and whether the
-- entry is worn. Empty while planning another class.
local function WornDelta(key, entry)
    if not worn then return "", nil, false end
    local w, same = Replaced(key, entry)
    if same then return SAME .. "0.0|r", L["You are wearing this item"], true end
    if not w then
        return string.format("%s+%.1f|r", GAIN, entry.score), L["Fills an empty slot"], false
    end
    if not (w.score and w.item) then return "", nil, false end
    local d = entry.score - w.score
    local name = w.hands and (ns.WornItemName(w.hands[1]) .. " + " .. ns.WornItemName(w.hands[2])) or ns.WornItemName(w)
    if math.abs(d) < 0.05 then
        return SAME .. "0.0|r", string.format(L["Same score as your %s"], name), false
    end
    return string.format("%s%+.1f|r", d > 0 and GAIN or SAME, d),
        string.format(L["%+.1f vs your %s (%.1f)"], d, name, w.score), false
end

---------------------------------------------------------------- dungeon loot

local function SlotLabel(key)
    for _, g in ipairs(ns.SlotGroups) do
        if g.key == key then
            return (key == "mainhand" and ranked and ranked.weapons.setup == "twohand") and L["Two-Hand"]
                or ns.GroupLabel(g, ns.GetProfile())
        end
    end
    return key
end

-- Tooltip line for a look-ahead upgrade.
local function UpgradeText(e)
    return string.format(L["Upgrade at level %d: +%.1f"], e.level, e.gain)
end

-- Where each usable item ranks for the current profile, using the same
-- rankings as the Best in slot tab. Best slot wins for 1H weapons.
-- Look-ahead upgrades that aren't usable yet get upcoming = true instead of a
-- rank: an upgrade over all sources if it is one, else over its own source.
-- { [itemId] = { entry, key = slot group, slot = label, rank = overall rank, dropRank = rank among dungeon
--   drops, upcoming? } }
local function BuildRankMap()
    local map = {}
    if not ranked then return map end
    for _, g in ipairs(ns.SlotGroups) do
        local bucket = ranked[g.key]
        if bucket then
            local label = SlotLabel(g.key)
            local dropRank = {}
            for i, e in ipairs(bucket.drop) do dropRank[e.id] = i end
            local i = 0
            for _, e in ipairs(bucket.all) do
                if e.id ~= bucket.taken then -- (the other hand's row has the one copy)
                    i = i + 1
                    local cur = map[e.id]
                    if not cur or i < cur.rank then
                        map[e.id] = { entry = e, key = g.key, slot = label, rank = i, dropRank = dropRank[e.id] }
                    end
                end
            end
            local paths = ranked.upcoming and ranked.upcoming[g.key]
            for _, key in ipairs({ "all", unpack(ns.SourceTypes) }) do
                for _, e in ipairs(paths and paths[key] or {}) do
                    local cur = map[e.id]
                    if not cur or (cur.upcoming and cur.entry.sourceType
                        and (not e.sourceType or e.gain > cur.entry.gain)) then
                        map[e.id] = { entry = e, key = g.key, slot = label, upcoming = true }
                    end
                end
            end
        end
    end
    return map
end

local rankCache -- BuildRankMap() for the quest panel, cleared on every refresh

-- How item `id` ranks for the profile, for the quest panel's rewards:
-- { rank, slot, score, upcoming, level (for upcoming), gain (score over the
-- worn item it replaces; nil while planning another class), wornText }, or
-- nil when the item isn't usable or isn't gear.
function UI.RewardInfo(id)
    if not rankCache then rankCache = BuildRankMap() end
    local info = rankCache[id]
    if not info then return nil end
    local out = { rank = info.rank, slot = info.slot, score = info.entry.score, upcoming = info.upcoming,
                  level = info.entry.level }
    if not info.upcoming and worn then
        local w, same = Replaced(info.key, info.entry)
        out.wornText = same and ("|cffffd100" .. L["worn"] .. "|r") or WornDelta(info.key, info.entry)
        if same then
            out.gain = 0
        elseif not w then
            out.gain = info.entry.score
        elseif w.score then
            out.gain = info.entry.score - w.score
        end
    end
    return out
end

-- The dungeon whose level range is closest to `level`.
local function DefaultDungeon(level)
    local best, bestDist
    for _, d in ipairs(ns.Dungeons) do
        local lo, hi = d.minLevel or 0, d.maxLevel or 99
        local dist = (level < lo and lo - level) or (level > hi and level - hi) or 0
        if not bestDist or dist < bestDist then best, bestDist = d.id, dist end
    end
    return best
end

-- The quest source a dungeon quest reward is listed under: preferably one of
-- the dungeon's own quests (`own`: {[questId] = true}), then one open to the
-- profile, then one Wowhead calls a dungeon quest. Nil when the item has no
-- quest source.
local function DungeonQuest(item, own, p)
    local best, bestScore
    for _, s in ipairs(item.sources) do
        if s.type == "quest" then
            local q = ns.Quests and ns.Quests[s.id] or {}
            local score = (own[s.id] and 4 or 0)
                + (ns.QuestOpen(s, p) and ns.QuestOpen(q, p) and 2 or 0) + (q.type == "Dungeon" and 1 or 0)
            if not bestScore or score > bestScore then best, bestScore = s, score end
        end
    end
    return best
end

local function LevelRange(d)
    if d.minLevel and d.maxLevel then return d.minLevel .. "-" .. d.maxLevel end
    return "??"
end

-- (Sets: the game's word, as its Collections window has it; ItemSets.lua)
local LOOT_VIEWS = { { key = "summary", text = L["Summary"] }, { key = "bosses", text = L["Bosses"] },
                     { key = "quests", text = L["Quests"] }, { key = "sets", text = WARDROBE_SETS or "Sets" } }
local DIM = "|cff777777" -- headers with nothing for the profile

local collapsed = {} -- ["dungeon id:boss index"], ["patterns:skill line:group"] = true for headers folded this session
local showOtherFaction = false -- Quests view: the other faction's quests, shown this session
local showNoGear = false -- Quests view: your quests without gear rewards, likewise
local summaries = {} -- [dungeon id] = DungeonSummary(), for the dungeon list
local lootLines = {} -- the loot list's entries, built by RefreshLoot / RefreshPatterns, drawn by DrawLoot
local DrawLoot
local SetMode -- switches the window's tab (defined with the window)

local function LootView()
    local view = ns.db.lootView
    return (view == "bosses" or view == "quests" or view == "sets") and view or "summary"
end

local function Contains(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

local function QuestLevel(s)
    local q = ns.Quests and ns.Quests[s.id]
    return (q and q.level) or s.level or 0
end

-- Quest order on the Dungeon loot tab: the profile's faction first, then
-- quests for both factions, then the other faction's; lowest level first in each.
local function QuestBefore(a, b, p)
    local function SideRank(s)
        local q = ns.Quests and ns.Quests[s.id]
        local side, mine = (q and q.side) or s.side or 3, ns.FactionSide[p.faction]
        if side == 3 or not mine then return 2 end
        return side == mine and 1 or 3
    end
    local ra, rb = SideRank(a), SideRank(b)
    if ra ~= rb then return ra < rb end
    local la, lb = QuestLevel(a), QuestLevel(b)
    if la ~= lb then return la < lb end
    return a.id < b.id
end

-- A boss's loot table, not the quest rewards or the trash drops (which the
-- Dungeon loot tab leaves out).
local function IsBoss(boss)
    return not boss.quest and not (boss.name == "Trash" and not boss.id)
end

-- Rank map entry `info` against worn gear: the gain over the item it would
-- replace (nil when it is worn, or while planning another class), and whether
-- it counts as an upgrade: a gain, or with no worn gear to compare with, a top
-- N rank for its slot. Look-ahead entries are neither.
local function Verdict(info)
    if not info or info.upcoming then return nil, false end
    if not worn then return nil, info.rank <= TopN() end
    local w, same = Replaced(info.key, info.entry)
    if same then return nil, false end
    local gain
    if not w then
        gain = info.entry.score
    elseif w.score then
        gain = info.entry.score - w.score
    end
    return gain, gain ~= nil and gain >= 0.05
end

-- Summary order: the biggest gain (the best rank while planning another class).
local function BetterPick(a, b)
    if a.gain and b.gain and a.gain ~= b.gain then return a.gain > b.gain end
    return a.info.rank < b.info.rank
end

-- The dungeon's quests in QuestBefore order, one entry per quest chain (and
-- per quest offered in several versions of one name and side, such as
-- Gnomeregan's repeatable Sparklematic turn-ins), each with the quest rewards
-- listed under its quests (DungeonQuest), none for a quest without gear:
-- { {quest = source or nil, boss, drops = {{drop, quest}...}}... }, where each
-- drop keeps the quest that rewards it. An entry shows one of its quests:
-- one open to the profile, then one with gear, then the latest chain step
-- (its tooltip and Pin giver lead to the character's next step anyway).
local function DungeonQuestGroups(dungeon, p)
    local groups, order, own, hasGear = {}, {}, {}, {}
    local function Group(s)
        local q = s and ns.Quests and ns.Quests[s.id]
        local name = (q and q.name) or (s and s.name)
        local key = (not s and "none") or (q and q.chain and ("chain " .. q.chain.id))
            or (name and ("quest " .. name .. " " .. tostring((q and q.side) or s.side))) or s.id
        local g = groups[key]
        if not g then
            g = { members = {}, drops = {} }
            groups[key] = g
            order[#order + 1] = g
        end
        if s and not own[s.id] then
            own[s.id] = true
            g.members[#g.members + 1] = s
        end
        return g
    end
    for _, s in ipairs(dungeon.quests or {}) do Group(s) end
    for _, boss in ipairs(dungeon.bosses) do
        if boss.quest then
            for _, drop in ipairs(boss.items) do
                local item = ns.Items[drop.id]
                if item then
                    local s = DungeonQuest(item, own, p)
                    local g = Group(s)
                    g.boss = boss
                    g.drops[#g.drops + 1] = { drop = drop, quest = s }
                    if s then hasGear[s.id] = true end
                end
            end
        end
    end
    for _, g in ipairs(order) do
        local bestScore, bestStep
        for _, s in ipairs(g.members) do
            local q = ns.Quests and ns.Quests[s.id] or {}
            local score = (ns.QuestOpen(q, p) and ns.QuestOpen(s, p) and 2 or 0) + (hasGear[s.id] and 1 or 0)
            local step = q.chain and q.chain.step or 0
            if not g.quest or score > bestScore or (score == bestScore and step > bestStep) then
                g.quest, bestScore, bestStep = s, score, step
            end
        end
    end
    table.sort(order, function(a, b)
        if not (a.quest and b.quest) then return b.quest == nil and a.quest ~= nil end
        return QuestBefore(a.quest, b.quest, p)
    end)
    return order
end

-- What `dungeon` holds for the profile, for the Summary view and the dungeon list:
-- { now = {pick...}, later = {pick...}, quests = {quest source...} }
--   now: one upgrade per slot (BetterPick order), the slot's other upgrades in
--        pick.alts. A quest gives only one of its choices, so only its best
--        one counts; quests the character has completed are left out.
--   later: look-ahead upgrades, by the level they unlock at.
--   quests: the dungeon's quests to pick up before going, one per chain: open to
--           the profile, neither completed nor in the quest log, and not
--           started inside the dungeon; in QuestBefore order.
-- pick = { id, item, info (rank map entry), gain, drop, boss, quest (source) }
local function DungeonSummary(dungeon, p, map)
    local picks, later, seen = {}, {}, {}
    local function Consider(drop, boss, quest)
        local item, info = ns.Items[drop.id], map[drop.id]
        if not (item and info) or seen[drop.id] then return end
        seen[drop.id] = true
        if quest and ns.QuestState(quest.id) == "done" then return end
        local pick, up = { id = drop.id, item = item, info = info, drop = drop, boss = boss, quest = quest }
        pick.gain, up = Verdict(info)
        if info.upcoming then
            later[#later + 1] = pick
        elseif up then
            picks[#picks + 1] = pick
        end
    end
    for _, boss in ipairs(dungeon.bosses) do
        if IsBoss(boss) then
            for _, drop in ipairs(boss.items) do Consider(drop, boss) end
        end
    end
    local quests = {}
    for _, g in ipairs(DungeonQuestGroups(dungeon, p)) do
        for _, d in ipairs(g.drops) do Consider(d.drop, g.boss, d.quest) end
        -- The chain step to pick up before going: the latest one left that
        -- doesn't start inside the dungeon (those are taken there), as the
        -- earlier steps are often skippable breadcrumbs. Nor the steps after
        -- one that starts inside and isn't done (Lost Relic Carry's Titan Relic
        -- leads to Prehistoric Prism, given outside), nor the ones up to the
        -- latest step done or in the quest log (a skipped breadcrumb).
        local pickup, pickupStep, inside, reached
        for _, s in ipairs(g.members) do
            local q = ns.Quests and ns.Quests[s.id] or {}
            local step = q.chain and q.chain.step or 0
            local state = ns.QuestState(s.id)
            if q.start and q.start.zoneId == dungeon.zoneId and state ~= "done"
                and ns.QuestOpen(q, p) and ns.QuestOpen(s, p) and (not inside or step < inside) then
                inside = step
            end
            if q.chain and state and (not reached or step > reached) then reached = step end
        end
        for _, s in ipairs(g.members) do
            local q = ns.Quests and ns.Quests[s.id] or {}
            local step = q.chain and q.chain.step or 0
            if not ns.QuestState(s.id) and ns.QuestOpen(q, p) and ns.QuestOpen(s, p)
                and not (q.start and q.start.zoneId == dungeon.zoneId) and not (inside and step > inside)
                and not (reached and step <= reached) and (not pickup or step > pickupStep) then
                pickup, pickupStep = s, step
            end
        end
        if pickup then quests[#quests + 1] = pickup end
    end

    local bestChoice = {}
    for _, pick in ipairs(picks) do
        local q = pick.quest and ns.Quests and ns.Quests[pick.quest.id]
        if q and q.rewards and Contains(q.rewards.choices, pick.id) then
            pick.choice = true
            local cur = bestChoice[pick.quest.id]
            if not cur or BetterPick(pick, cur) then bestChoice[pick.quest.id] = pick end
        end
    end
    table.sort(picks, BetterPick)
    local now, bySlot = {}, {}
    for _, pick in ipairs(picks) do
        if not pick.choice or bestChoice[pick.quest.id] == pick then
            local first = bySlot[pick.info.key]
            if first then
                first.alts[#first.alts + 1] = pick
            else
                pick.alts = {}
                bySlot[pick.info.key] = pick
                now[#now + 1] = pick
            end
        end
    end

    table.sort(quests, function(a, b) return QuestBefore(a, b, p) end)
    table.sort(later, function(a, b)
        local ea, eb = a.info.entry, b.info.entry
        if ea.level ~= eb.level then return ea.level < eb.level end
        return ea.gain > eb.gain
    end)
    return { now = now, later = later, quests = quests }
end

local function ScrollLoot(delta)
    lootOffset = lootOffset - delta * 3
    DrawLoot()
end

local function SelectDungeon(id)
    selectedDungeon = id
    lootOffset = 0
    UI.Refresh()
end

local function ShowDungeonTooltip(self)
    local d, s = self.dungeon, summaries[self.dungeon.id]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.DungeonName(d))
    GameTooltip:AddLine(string.format(L["Levels %s"], LevelRange(d)), 1, 1, 1)
    if s then
        local quests = 0
        for _, pick in ipairs(s.now) do
            if pick.quest then quests = quests + 1 end
        end
        local what = worn and ns.Plural(#s.now, "%d upgrade over what you wear", "%d upgrades over what you wear")
            or string.format(L["%d items in the top %d for their slot"], #s.now, TopN())
        if #s.now > 0 then
            GameTooltip:AddLine(string.format(L["%s: %d from drops, %d from quests"], what, #s.now - quests, quests),
                0.2, 1, 0.6, true)
        else
            GameTooltip:AddLine(worn and L["Nothing here beats what you wear"] or L["Nothing here makes the top list"],
                0.6, 0.6, 0.6)
        end
        if #s.later > 0 then
            GameTooltip:AddLine(string.format(L["%d more within your look-ahead levels"], #s.later), 0.2, 1, 0.6)
        end
    end
    GameTooltip:Show()
end

-- A row of the left list on the Dungeon loot and Crafting patterns tabs: its
-- name, an upgrade count on a small green pill (b.badge, b.pill) and short
-- text at the right end (b.right, `rightFont`).
local function CreateListButton(parent, index, name, rightFont)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(LEFT_WIDTH, DUNGEON_HEIGHT)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * DUNGEON_HEIGHT)
    W.AddSelection(b)
    W.AddHighlight(b)

    b.right = b:CreateFontString(nil, "OVERLAY", rightFont or "WildGearFontDisableSmall")
    b.right:SetPoint("RIGHT", b, "RIGHT", -8, 0)

    b.pill = b:CreateTexture(nil, "ARTWORK")
    b.pill:SetSize(20, 14)
    b.pill:SetPoint("RIGHT", b, "RIGHT", -46, 0)
    b.badge = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    b.badge:SetPoint("CENTER", b.pill, "CENTER", 0, 0)
    if T.Classic() then
        b.pill:SetColorTexture(0.2, 1, 0.6, 0.18)
    else -- (as the gains' chips: the count in green on a faint green)
        b.pill:SetColorTexture(T.GAIN[1], T.GAIN[2], T.GAIN[3], 0.14)
        b.badge:SetTextColor(T.GAIN[1], T.GAIN[2], T.GAIN[3])
    end

    b.name = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    b.name:SetPoint("LEFT", b, "LEFT", 10, 0)
    b.name:SetPoint("RIGHT", b.pill, "LEFT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.name:SetText(name)

    b:SetScript("OnLeave", HideTooltip)
    return b
end

-- The dungeon list shows only the dungeons near the profile's level (in
-- range, or up to DUNGEONS_AHEAD levels before it); the ones below it and
-- above fold under Earlier and Later.
local DUNGEONS_AHEAD = 4

local function CreateDungeonButton(parent, d, index)
    local b = CreateListButton(parent, index, ns.DungeonName(d))
    b.dungeon = d
    b.right:SetText(LevelRange(d))
    b:SetScript("OnEnter", ShowDungeonTooltip)
    b:SetScript("OnClick", function(self) SelectDungeon(self.dungeon.id) end)
    return b
end

-- Earlier / Later: a fold row with the theme's plus or minus, the count of
-- its dungeons, and while folded their upgrades on the pill.
local function CreateDungeonFold(parent, key, text)
    local b = CreateListButton(parent, 1, text)
    b.key = key
    b.fold = W.FoldSign(b)
    b.fold:SetSize(14, 14)
    b.fold:SetPoint("CENTER", b, "LEFT", 14, 0)
    b.name:SetPoint("LEFT", b, "LEFT", 26, 0)
    b.name:SetTextColor(0.7, 0.7, 0.7)
    b.selected:Hide()
    b:SetScript("OnClick", function(self)
        parent.open[self.key] = not parent.open[self.key]
        UI.Refresh()
    end)
    return b
end

-- A one-line column of a loot line, after `anchor`. The columns fill a line
-- 556 wide; on another width (the Classic theme's list) the `flex` column,
-- the item names, takes up the difference (FitLine).
local function ColumnText(line, font, anchor, x, w, justify, flex)
    local fs = line:CreateFontString(nil, "OVERLAY", font)
    fs:SetPoint("LEFT", anchor, "RIGHT", x, 0)
    fs:SetWidth(w)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    if flex then
        line.flex = line.flex or {}
        line.flex[#line.flex + 1] = { fs, w }
    end
    return fs
end

-- Makes loot line (or column header row) `line` `width` wide, its flex columns
-- taking up the difference.
local function FitLine(line, width)
    if line.fit == width then return end
    line.fit = width
    line:SetWidth(width)
    for _, f in ipairs(line.flex or {}) do f[1]:SetWidth(f[2] + width - 556) end
end

-- The Bosses and Quests views' item columns: slot (weapon type for weapons),
-- icon, name, rank, score. `fonts` gives the font per column; returns icon,
-- name, kind (the slot), rank, score.
local function LootColumns(line, fonts)
    local kind = line:CreateFontString(nil, "OVERLAY", fonts.kind)
    kind:SetPoint("LEFT", line, "LEFT", 24, 0) -- (past the wish list star)
    kind:SetWidth(94)
    kind:SetJustifyH("LEFT")
    kind:SetWordWrap(false)
    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", kind, "RIGHT", 6, 0)
    W.IconRing(icon)
    local name = ColumnText(line, fonts.name, icon, 8, 254, nil, true)
    local rank = ColumnText(line, fonts.rank, name, 10, 90)
    local score = ColumnText(line, fonts.score, rank, 6, 50, "RIGHT")
    return icon, name, kind, rank, score
end

-- The Summary view's columns, likewise: slot, icon, name, source, gain.
local function SummaryColumns(line, fonts)
    local slot = line:CreateFontString(nil, "OVERLAY", fonts.slot)
    slot:SetPoint("LEFT", line, "LEFT", 24, 0) -- (past the wish list star)
    slot:SetWidth(64)
    slot:SetJustifyH("LEFT")
    slot:SetWordWrap(false)
    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", slot, "RIGHT", 6, 0)
    W.IconRing(icon)
    local name = ColumnText(line, fonts.name, icon, 8, 190, nil, true)
    local source = ColumnText(line, fonts.source, name, 10, 188)
    local gain = ColumnText(line, fonts.gain, source, 6, 50, "RIGHT")
    return slot, icon, name, source, gain
end

-- The Crafting patterns columns, likewise, shared by the column headers and
-- the pattern lines: icon, name, type, skill, source, rank, score.
local function PatternColumns(line, fonts)
    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", line, "LEFT", 14, 0)
    W.IconRing(icon)
    local name = ColumnText(line, fonts.name, icon, 8, 170, nil, true)
    local kind = ColumnText(line, fonts.kind, name, 8, 96)
    local skill = ColumnText(line, fonts.skill, kind, 4, 30, "RIGHT")
    local source = ColumnText(line, fonts.source, skill, 10, 100)
    local rank = ColumnText(line, fonts.rank, source, 6, 50)
    local score = ColumnText(line, fonts.score, rank, 0, 40, "RIGHT")
    return icon, name, kind, skill, source, rank, score
end

-- Headers with +/- fold their items, notes can open another dungeon or run
-- their action (the Quests view's other faction line), and
-- Crafting patterns dungeon headers open theirs on the Dungeon loot tab; the
-- rest work like item rows (OnItemClick).
local function OnLootClick(self, button)
    if button ~= "RightButton" and self.toggle then
        collapsed[self.toggle] = not self.isCollapsed
        UI.Refresh()
    elseif button ~= "RightButton" and self.gotoDungeon then
        SelectDungeon(self.gotoDungeon)
    elseif button ~= "RightButton" and self.action then
        self.action()
    elseif button ~= "RightButton" and self.openDungeon then
        selectedDungeon, listOffsets.loot = self.openDungeon, 0
        dungeonPanel.level = nil -- (a pick for the current level, see RefreshLoot)
        SetMode("loot")
    else
        OnItemClick(self, button)
    end
end

-- One line of the loot list, reused for every kind of entry (see Draw below):
-- section, boss and quest headers, item rows, summary rows and notes.
-- DrawLoot places it and sets its height.
local function CreateLootLine(parent, width)
    local line = CreateFrame("Button", nil, parent)
    line:SetSize(width, ROW_HEIGHT)
    -- Modern: every row under a header on the card's light, so they make one
    -- card; Classic: every other one, a stripe (DrawLoot restarts the count at
    -- each header).
    line.stripe = line:CreateTexture(nil, "BACKGROUND")
    line.stripe:SetAllPoints()
    if T.Classic() then line.stripe:SetColorTexture(1, 1, 1, 0.03) else line.stripe:SetColorTexture(unpack(T.CARD)) end

    -- Dungeon headers (Crafting patterns): gold name on a darker band.
    line.band = line:CreateTexture(nil, "BACKGROUND", nil, 1)
    line.band:SetAllPoints()
    line.band:SetColorTexture(T.GOLD[1], T.GOLD[2], T.GOLD[3], 0.07)
    -- Summary sections, pattern groups and boss / quest headers: a faint
    -- underline (Modern: none, the card under them is enough). Rows carry no
    -- color of their own beyond the item name and green gains.
    line.rule = W.Rule(line, 1, 1, 1, T.Classic() and 0.1 or 0)
    -- Fold sign of headers that fold (and of the other faction line): the
    -- theme's plus or minus (see ShowFold), clear of the header text at 16.
    line.fold = W.FoldSign(line)
    line.fold:SetSize(14, 14)
    line.fold:SetPoint("CENTER", line, "LEFT", 8, 0)
    line.rule:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 2)
    line.rule:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 2)

    line.header = line:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    line.header:SetJustifyH("LEFT")
    line.header:SetWordWrap(false)
    line.side = line:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    line.side:SetPoint("RIGHT", line, "RIGHT", -6, 0)

    -- Summary quests: where to pick them up (the giver of your next step, for
    -- a chain), and a button to pin that giver on the map.
    line.pin = W.FitButton(W.FlatButton(line, L["Pin giver"], 64, 18))
    line.pin:SetPoint("RIGHT", line, "RIGHT", -4, 0)
    line.pin:SetScript("OnClick", function(self)
        local quest = self:GetParent().quest
        if quest then ns.PinQuest(quest) end
    end)
    line.mid = line:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    line.mid:SetPoint("LEFT", line, "LEFT", 250, 0)
    line.mid:SetPoint("RIGHT", line.pin, "LEFT", -8, 0)
    line.mid:SetJustifyH("LEFT")
    line.mid:SetWordWrap(false)
    -- Quests tab quests: their giver, right-aligned before Pin giver; the best
    -- pick of a quest's choices, tinted.
    line.giver = line:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    line.giver:SetPoint("RIGHT", line.pin, "LEFT", -8, 0)
    line.giver:SetJustifyH("RIGHT")
    line.giver:SetWordWrap(false)
    line.tint = line:CreateTexture(nil, "BACKGROUND", nil, 2)
    line.tint:SetAllPoints()
    line.tint:SetColorTexture(0.2, 1, 0.6, 0.1)

    local hi, dim = "WildGearFontHighlightSmall", "WildGearFontDisableSmall"
    line.icon, line.name, line.kind, line.rank, line.score = LootColumns(line, {
        name = hi, kind = dim, rank = hi, score = hi,
    })
    line.slot, line.sIcon, line.sName, line.source, line.gain = SummaryColumns(line, {
        slot = dim, name = hi, source = dim, gain = hi,
    })
    line.pIcon, line.pName, line.pKind, line.pSkill, line.pSource, line.pRank, line.pScore = PatternColumns(line, {
        name = hi, kind = dim, skill = hi, source = dim, rank = hi, score = hi,
    })
    for _, fs in ipairs({ line.score, line.gain, line.pScore }) do W.GainChip(fs) end -- (Modern: gains on green chips)

    SetupItemButton(line)
    AddQuestHit(line, line.source)
    line:SetScript("OnClick", OnLootClick)
    line:EnableMouseWheel(true)
    line:SetScript("OnMouseWheel", function(_, delta) ScrollLoot(delta) end)
    FitLine(line, width)
    line.names = { line.name, line.sName, line.pName } -- for UI.MarkWorn
    -- The wish list's star, in the gutter left of the slot (WishList.lua).
    local star = ns.WishList.Star(line)
    star:SetPoint("CENTER", line, "LEFT", 11, 0)
    line.parts = { line.stripe, line.band, line.rule, line.fold, line.header, line.side, line.pin, line.mid,
        line.giver, line.tint, star,
        line.icon, line.name, line.kind, line.rank, line.score,
        line.slot, line.sIcon, line.sName, line.source, line.gain, line.questHit,
        line.pIcon, line.pName, line.pKind, line.pSkill, line.pSource, line.pRank, line.pScore }
    return line
end

local function CreateLootPanel(parent, width)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width, LOOT_TOP + LOOT_LINES * ROW_HEIGHT)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -4)

    -- View tabs (saved for all characters): Modern, choices on a track as
    -- Show's (W.SubTab), 18 tall in its 22; Classic, like the window's tabs.
    panel.tabs = {}
    panel.tabTrack = W.SubTabTrack(panel)
    local prev
    for _, v in ipairs(LOOT_VIEWS) do
        -- (at least 64 wide: four of them and Show fit side by side, in German too)
        local tab = W.SubTab(panel, v.text, "WildGearFontNormalSmall", 64)
        tab:SetHeight(panel.tabTrack and 18 or 22)
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        else
            tab:SetPoint("TOPLEFT", panel, "TOPLEFT", panel.tabTrack and 2 or 0, panel.tabTrack and -26 or -24)
        end
        tab.key = v.key
        tab:SetScript("OnClick", function()
            -- (the Quests tab's view is its own: Summary or Quests)
            if mode == "quests" then
                ns.db.questView = v.key ~= "summary" and v.key or nil
            else
                ns.db.lootView = v.key ~= "summary" and v.key or nil
            end
            lootOffset = 0
            UI.Refresh()
        end)
        panel.tabs[#panel.tabs + 1] = tab
        prev = tab
    end
    -- (under Crafting patterns' column headers too; it and Show reach out to
    -- the scroll bar's right edge in the Classic theme, where it is beside the list)
    local reach = T.Classic() and 4 + W.ScrollBarWidth() - 1 or 0
    local tabRule = W.Rule(panel, 1, 1, 1, 0.1)
    tabRule:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -46)
    tabRule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", reach, -46)

    -- Bosses and Quests views: everything, or only what the profile can use
    -- (saved for all characters; the Quests tab's on its own: For me at first).
    panel.show = W.Segmented(panel, L["Show"], {
        { key = "me", text = L["For me"], tip = L["Gear you can use now, plus look-ahead upgrades"] },
        { key = "all", text = L["All loot"] },
    }, 64, function(key)
        if mode == "quests" then
            ns.db.questsShowAll = key == "all" or nil
        else
            ns.db.lootUsableOnly = key == "me" or nil
        end
        lootOffset = 0
        UI.Refresh()
    end, true)
    panel.show:SetPoint("TOPRIGHT", panel, "TOPRIGHT", reach, -25)

    -- Crafting patterns' column headers, lined up with the pattern lines'
    -- columns, in the view tabs' row (over the same rule).
    local small = "WildGearFontDisableSmall"
    local cols = CreateFrame("Frame", nil, panel)
    cols:SetSize(width - 10, 16)
    cols:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -27)
    local pIcon, pName, pKind, pSkill, pSource, pRank, pScore = PatternColumns(cols, {
        name = small, kind = small, skill = small, source = small, rank = small, score = small,
    })
    pIcon:Hide() -- (no icon over the icons: its ring would show)
    pName:SetText(L["Item"])
    pKind:SetText(L["Type"])
    -- (right-aligned over the numbers, it may reach back over Type's column)
    pSkill:ClearAllPoints()
    pSkill:SetPoint("RIGHT", pKind, "RIGHT", 4 + 30, 0)
    pSkill:SetWidth(80)
    pSkill:SetText(L["Skill"])
    pSource:SetText(L["Source"])
    pRank:SetText(L["For you"])
    cols.score = pScore
    FitLine(cols, width - 10)
    panel.patCols = cols

    -- The lines' width beside the scroll bar, and without it (Classic: over its
    -- place, to 14 short of where the rule and Show end: as far in from the
    -- frame's edge as the columns start on the left; DrawLoot).
    panel.narrow, panel.wide = width - 10, T.Classic() and width + reach - 14 or width - 10
    panel.lines = {}
    for i = 1, LOOT_LINES do panel.lines[i] = CreateLootLine(panel, width - 10) end

    -- Scroll bar on the right edge (Classic: wider, so beside it, where Best in
    -- slot's is): drag the thumb, or use the mouse wheel anywhere.
    local bar = W.ScrollBar(panel)
    bar:SetHeight(LOOT_LINES * ROW_HEIGHT)
    if T.Classic() then
        bar:SetPoint("TOPLEFT", panel, "TOPRIGHT", 4, -LOOT_TOP)
    else
        bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -LOOT_TOP)
    end
    bar:SetObeyStepOnDrag(true)
    bar:SetScript("OnValueChanged", function(self, value)
        if self.updating then return end
        value = math.floor(value + 0.5)
        if value ~= lootOffset then
            lootOffset = value
            DrawLoot()
        end
    end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, delta) ScrollLoot(delta) end)
    panel.scroll = bar

    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta) ScrollLoot(delta) end)
    return panel
end

---------------------------------------------------------------- loot list entries

-- Header text from `x` up to `limit` (default: the right-hand text).
local function SetHeader(line, text, x, font, limit)
    local h = line.header
    h:SetFontObject(font or WildGearFontNormal)
    h:ClearAllPoints()
    h:SetPoint("LEFT", line, "LEFT", x, 0)
    h:SetPoint("RIGHT", limit or line.side, "LEFT", -8, 0)
    h:SetText(text)
    h:Show()
end

local function SetSide(line, text)
    line.side:SetText(text or "")
    line.side:Show()
end

local function ShowAll(...)
    for i = 1, select("#", ...) do select(i, ...):Show() end
end

-- The fold sign: a plus when `collapsed`, else a minus. Returns the x its
-- header text starts at.
local function ShowFold(line, collapsed)
    line.fold.Set(not collapsed)
    line.fold:Show()
    return 16
end

-- Where a summary pick comes from: the boss, or the quest icon and its name
-- (gold, hoverable); plain text for tooltips.
local function PickSource(k, plain)
    if k.quest then
        local name = ns.QuestName(k.quest.id, k.quest.name)
        if plain then return string.format(L["quest %s"], name) end
        local active = ns.QuestState(k.quest.id) == "active"
        return QUEST_ICON .. QUEST_LINK .. name .. "|r" .. (active and (SAME .. "  " .. L["in log"] .. "|r") or "")
    end
    return ns.BossName(k.boss)
end

---------------------------------------------------------------- crafting pattern helpers

local PATTERN_GROUPS = {
    { key = "waylaid", text = L["Waylaid Supplies vendor"] },
    { key = "trainer", text = L["Trainer"] },
    { key = "drops", text = L["Dungeon drops"] },
}
-- The slot filter's slots: ns.SlotGroups, whose weapon groups (filled per
-- weapon setup) get these inventory types, one-handers going to the main hand.
local WEAPON_INV = { mainhand = { [13] = true, [17] = true, [21] = true }, offhand = { [14] = true, [22] = true, [23] = true } }
local SLOT_FILTER_LABEL = { mainhand = L["Main Hand / Two-Hand"], ranged = L["Ranged / Relic"] }
-- The filter box under the profession list: rows (chips, switch) of FILTER_ROW,
-- FILTER_GAP apart, FILTER_PAD in from its border; slot chips in FILTER_COLS columns.
local FILTER_ROW, FILTER_GAP, FILTER_PAD, FILTER_COLS = 20, 3, 8, 3
local FAVOR_ICON = "|TInterface\\Icons\\Racial_Dwarf_FindTreasure:0|t" -- Merchant's Favor (currency 3402)
local RED = "|cffff5050"

local places, dungeonIds -- see PlaceOf

-- The dungeon that pattern drops in zone `zoneId` are listed under: { name,
-- minLevel, maxLevel, order (in the dungeon list), open (ns.Dungeons id to
-- open) }. A zone split into wings (Scarlet Monastery) is one place, named
-- after the zone. Also fills dungeonIds, the set of ns.Dungeons ids.
local function PlaceOf(zoneId)
    if not places then
        places, dungeonIds = {}, {}
        for i, d in ipairs(ns.Dungeons) do
            dungeonIds[d.id] = true
            local pl = places[d.zoneId]
            if pl then
                pl.name = ns.ZoneName(d.zoneId) or pl.name
                if d.minLevel then pl.minLevel = math.min(pl.minLevel or d.minLevel, d.minLevel) end
                if d.maxLevel then pl.maxLevel = math.max(pl.maxLevel or d.maxLevel, d.maxLevel) end
            else
                places[d.zoneId] = { name = ns.DungeonName(d), order = i, open = d.id, minLevel = d.minLevel,
                                     maxLevel = d.maxLevel }
            end
        end
    end
    return places[zoneId] or { name = ns.ZoneName(zoneId) or string.format(L["Zone %d"], zoneId), order = math.huge }
end

-- "Stondry Darkhammer, Redridge Mountains"
local function VendorText(v)
    local zone = ns.ZoneName(v.zoneId)
    return ns.NpcName(v.id, v.name) .. (zone and (L[", "] .. zone) or "")
end

-- The profession's Waylaid Supplies vendor for the profile's faction.
local function WaylaidVendor(prof, p)
    for _, v in ipairs(prof.vendors or {}) do
        if v.side == 3 or v.side == ns.FactionSide[p.faction] then return v end
    end
end

-- Tooltip lines for pattern `pat` of profession `prof`: the skill it needs
-- (and the character's, `rank`), then every way to learn it.
local function PatternWays(pat, prof, vendor, rank)
    local out = { string.format(L["Pattern: needs %s %d%s"], L[prof.name], pat.skill or 0,
        rank and string.format(L[" (yours: %d)"], rank) or "") }
    for _, d in ipairs(pat.drops or {}) do
        out[#out + 1] = string.format(L["Drops from %s in %s"],
            (not d.npcId and d.npc == "Trash") and L["trash mobs"] or ns.NpcName(d.npcId, d.npc), PlaceOf(d.zoneId).name)
    end
    if pat.waylaid then
        out[#out + 1] = string.format(L["Sold for %d %s%s"], pat.waylaid,
            ns.CurrencyName(3402, L["Merchant's Favor"]),
            vendor and string.format(L[" by %s"], VendorText(vendor)) or "")
    end
    if pat.trainer then
        out[#out + 1] = pat.trainer > 0 and string.format(L["Taught by trainers for %s"], ns.MoneyText(pat.trainer))
            or L["Taught by trainers"]
    end
    return out
end

-- Whether the profile can use `item` now, judged as the rankings do: class,
-- armor type (with Settings' Armor type: Class type) and required level, not the pattern's
-- skill (`reqLevel` overrides the item's own). If not, a short reason: "lvl N"
-- and N when it can later (ns.WearLevel: weapon training, mail and plate),
-- else why not.
local function Usable(item, p, reqLevel)
    local function At(level) return setmetatable({ level = level }, { __index = p }) end
    local level = math.max(p.level, reqLevel or item.reqLevel or 0)
    level = ns.WearLevel(item, At(level))
    if not level then return false, L["can't use"] end
    if ns.db.classArmorOnly and ns.IsLighterArmor(item, At(level)) then return false, L["not class armor"] end
    if level > p.level then return false, string.format(L["lvl %d"], level), level end
    return true
end

-- Rank column of an item the profile can't use now: its level in grey when it
-- can use it later, else blank (the reason is in the tooltip).
local function LaterLevel(at)
    return at and (SAME .. string.format(L["lvl %d"], at) .. "|r") or ""
end

-- The ns.SlotGroups key of the slot `item` goes in, for the slot filter.
local function SlotKey(item)
    for _, g in ipairs(ns.SlotGroups) do
        local inv = g.inv or WEAPON_INV[g.key]
        if inv and inv[item.slot] then return g.key end
    end
end

---------------------------------------------------------------- loot list drawing

-- Draw[kind](line, entry, profile) fills a reset line for one entry of lootLines.
local Draw = {}

function Draw.gap() end

-- Space before a boss or quest header, so each group's items read as its own
-- (DrawLoot gives it a third of a row).
function Draw.spacer() end

-- { text, gotoDungeon?, action? (called on click), folded? (a fold sign: plus when true, minus when false) }
function Draw.note(line, l)
    SetHeader(line, l.text, l.folded == nil and 14 or ShowFold(line, l.folded), WildGearFontHighlightSmall)
    line.gotoDungeon, line.action = l.gotoDungeon, l.action
end

-- Summary section: { text, hint, wish? }. wish: its picks ({ { id }, ... }),
-- for the wish list's star after the title: one click wishes for them all,
-- another takes them off (WishList.lua). After the title, not in the lines'
-- gutter: the section titles stay in line with each other.
function Draw.section(line, l)
    line.rule:Show()
    SetSide(line, l.hint and (SAME .. l.hint .. "|r"))
    SetHeader(line, l.text, 2)
    if l.wish then
        ns.WishList.SetStarAll(line, l.wish)
        line.star:ClearAllPoints()
        line.star:SetPoint("LEFT", line, "LEFT", 2 + (line.header:GetStringWidth() or 0) + 8, 0)
        line.starMoved = true
    end
end

-- Summary row: { pick, later? }
function Draw.pick(line, l)
    local k, info = l.pick, l.pick.info
    ShowAll(line.slot, line.sIcon, line.sName, line.source, line.gain)
    line.slot:SetText(info.slot)
    ItemIcon(k.id, line.sIcon)
    line.sName:SetText(ColoredName(k.id))
    line.entry = info.entry
    ns.WishList.SetStar(line, k.id)
    if l.later then
        line.source:SetText(string.format(L["lvl %d"], info.entry.level) .. "  " .. PickSource(k))
        line.gain:SetText(string.format("%s+%.1f|r", UPGRADE, info.entry.gain))
        line.rankText = UpgradeText(info.entry)
    else
        line.source:SetText(PickSource(k))
        line.gain:SetText(k.gain and string.format("%s+%.1f|r", GAIN, k.gain) or string.format("#%d", info.rank))
        line.rankText = nil
        local extra = {}
        for _, alt in ipairs(k.alts) do
            extra[#extra + 1] = string.format(L["Also for %s: %s (%s, %s)"], info.slot, ns.ItemName(alt.id),
                alt.gain and string.format("%+.1f", alt.gain) or ("#" .. alt.info.rank), PickSource(alt, true))
        end
        line.extraLines = extra
    end
    line.quest = k.quest
    FitQuestHit(line, line.source)
end

-- Summary quest to pick up: { quest (source) }. Its level is red while the
-- profile is below the level needed to take it.
function Draw.pickup(line, l, p)
    local s = l.quest
    local q = ns.Quests and ns.Quests[s.id] or {}
    local level, reqLevel = q.level or s.level, s.reqLevel or q.reqLevel or 0
    SetHeader(line, string.format("%s%s%s|r%s", QUEST_ICON, QUEST_LINK, ns.QuestName(s.id, s.name),
        level and string.format("  %s[%d]|r", reqLevel > p.level and "|cffff5050" or SAME, level) or ""),
        14, WildGearFontHighlightSmall, line.mid)
    -- Where to go: the quest giver of the character's next step.
    local info = ns.QuestInfo(s, p)
    local target = info and info.target
    local where
    if target and target.start then
        local zone = ns.ZoneName(target.start.zoneId)
        where = ns.StartName(target.start) .. (zone and (L[", "] .. zone) or "")
        if target.step and target.id ~= s.id then
            where = string.format(L["step %d/%d: %s"], target.step, target.steps, where)
        end
    end
    line.mid:SetText(where or "")
    line.mid:Show()
    if target and target.start and target.start.x then line.pin:Show() end
    line.quest = info and s or nil
end

-- Bosses view header: { boss, rows (items listed), toggle?, collapsed }
function Draw.boss(line, l)
    local b = l.boss
    local name = ns.BossName(b)
    local level = b.level and ("  " .. string.format(L["level %d"], b.level)) or ""
    line.rule:Show()
    -- (names line up with the foldable headers' text)
    if l.rows == 0 then
        SetHeader(line, DIM .. name .. level .. "|r", 16)
        return
    end
    local text = name .. SAME .. level .. "|r"
    if l.collapsed then text = text .. SAME .. "  " .. ns.Plural(l.rows, "%d item", "%d items") .. "|r" end
    SetHeader(line, text, ShowFold(line, l.collapsed))
    line.toggle, line.isCollapsed = l.toggle, l.collapsed
end

-- Quests view header: { quest (source, nil for rewards without one), q, rows, gear (has gear rewards), state,
-- other (the other faction's) }. The quest icon marks it, so its name goes
-- without "Quest:". A quest without gear says whether it rewards items the
-- addon doesn't rank (non-gear, or gear Forever's data lacks) or none at all.
-- On the right: your progress, else (for the other faction's) its faction.
function Draw.quest(line, l)
    local s, q = l.quest, l.q
    local name = s and ns.QuestName(s.id, s.name) or L["Other quest rewards"]
    local level = s and (q.level or s.level)
    level = level and ("  " .. string.format(L["level %d"], level)) or ""
    -- The character's progress shows on every quest, even one with nothing for you.
    local state = (l.state == "done" and (SAME .. L["completed"] .. "|r"))
        or (l.state == "active" and ns.ACTIVE_HEX .. L["in log"] .. "|r")
    line.rule:Show()
    if l.rows == 0 and l.gear then
        SetHeader(line, QUEST_ICON .. DIM .. name .. level .. "|r", 2)
        SetSide(line, state)
    else
        local r = q.rewards
        local hint = (l.gear and "") or ("  " .. ((r and (r.choices or r.items)) and L["no ranked gear"] or L["no gear reward"]))
        SetHeader(line, QUEST_ICON .. name .. SAME .. level .. hint .. "|r", 2)
        SetSide(line, state or (l.other and ns.QuestSideLabel(q.side or (s and s.side))))
    end
    line.quest = s and HasQuestDetails(s) and s or nil
end

-- Bosses / Quests view item: { item, drop, info, gain, up, quest?, questReward?, open?, bestPick?, tint? (an
-- upgrade to take: tinted), reason? (why it can't be used, in the rank column) }
function Draw.item(line, l, p)
    local item, info, drop = l.item, l.info, l.drop
    ShowAll(line.icon, line.name, line.kind, line.rank, line.score)
    ItemIcon(drop.id, line.icon)
    line.icon:SetAlpha(info and 1 or 0.4)
    -- Items the profile can't use now are dimmed, in their quality color.
    line.name:SetText(ColoredName(drop.id))
    line.name:SetAlpha(info and 1 or 0.5)
    line.kind:SetText(ns.ItemSlotLabel(item))
    ns.WishList.SetStar(line, drop.id)
    line.quest = l.quest and HasQuestDetails(l.quest) and l.quest or nil
    if info and info.upcoming then
        line.rank:SetText(SAME .. string.format(L["lvl %d"], info.entry.level) .. "|r")
        line.score:SetText(string.format("%s+%.1f|r", UPGRADE, info.entry.gain))
        line.entry = info.entry
        line.rankText = UpgradeText(info.entry)
    elseif info then
        line.rank:SetText(string.format("%s#%d|r", info.rank <= TopN() and "|cffffffff" or SAME, info.rank))
        line.score:SetText(worn and WornDelta(info.key, info.entry) or string.format("%.1f", info.entry.score))
        line.entry = info.entry
        line.rankText = info.dropRank and string.format(L["#%d among dungeon drops"], info.dropRank)
        if l.bestPick then line.extraLines = { L["Best pick of this quest's choices"] } end
        if l.tint then line.tint:Show() end
    else
        -- A quest reward also needs the quest's own level, whatever the item says.
        local usable, why, at = Usable(item, p, l.questReward and ns.ObtainLevel(item, p, "quest") or nil)
        if l.open == false then
            why, at = L["quest not open"], nil
        elseif at then
            why = L["level too high"]
        elseif usable then
            why = L["not ranked"]
        end
        line.rank:SetText(at and LaterLevel(at) or (l.reason and why and (SAME .. why .. "|r")) or "")
        line.score:SetText("")
        line.entry = { id = drop.id, sources = item.sources, why = why }
    end
end

-- Crafting patterns group header (how the patterns are learned):
-- { text, rows, ups, toggle?, collapsed }. On the right: how many make an
-- upgrade, or why it is empty.
function Draw.group(line, l)
    line.rule:Show()
    SetHeader(line, l.text, l.toggle and ShowFold(line, l.collapsed) or 2)
    local side
    if l.rows == 0 then
        side = SAME .. (ns.db.patternsShowAll and L["none"] or L["nothing for you"]) .. "|r"
    elseif l.ups > 0 then
        side = GAIN .. (worn and ns.Plural(l.ups, "%d upgrade", "%d upgrades")
            or ns.Plural(l.ups, "%d top pick", "%d top picks")) .. "|r"
    end
    SetSide(line, side)
    line.toggle, line.isCollapsed = l.toggle, l.collapsed
end

-- Crafting patterns dungeon header: { place (PlaceOf), open? }
function Draw.place(line, l)
    local pl = l.place
    local levels = pl.minLevel and pl.maxLevel and ("  " .. string.format(L["levels %s"], LevelRange(pl))) or ""
    SetHeader(line, pl.name .. SAME .. levels .. "|r", 14)
    line.band:Show()
    line.openDungeon = l.open
    line.tip = l.open and string.format(L["Click to open %s on the Dungeon loot tab"], pl.name)
end

-- Crafting patterns row: { pattern, prof, vendor?, item, info, up, usable, why?, at?, source, skillRank?, slot? }
-- The skill is green when the character has it, red when it needs more.
-- Items the profile can't use now are dimmed, unless they are look-ahead upgrades.
function Draw.pattern(line, l, p)
    local pat, item, info = l.pattern, l.item, l.info
    local shown = l.usable or info
    ShowAll(line.pIcon, line.pName, line.pKind, line.pSkill, line.pSource, line.pRank, line.pScore)
    ItemIcon(pat.item, line.pIcon)
    line.pIcon:SetAlpha(shown and 1 or 0.4)
    line.pName:SetText(ColoredName(pat.item))
    line.pName:SetAlpha(shown and 1 or 0.5)
    line.pKind:SetText(ns.ItemTypeLabel(item))
    local skill, rank = pat.skill or 0, l.skillRank
    line.pSkill:SetText(rank and string.format("%s%d|r", rank >= skill and GAIN or RED, skill) or tostring(skill))
    line.pSource:SetText(l.source)
    line.extraLines = PatternWays(pat, l.prof, l.vendor, rank)
    line.entry = { id = pat.item, sources = item.sources, why = l.why or L["not ranked"] }
    if info and info.upcoming then
        line.pRank:SetText(SAME .. string.format(L["lvl %d"], info.entry.level) .. "|r")
        line.pScore:SetText(string.format("%s+%.1f|r", UPGRADE, info.entry.gain))
        line.entry, line.rankText = info.entry, UpgradeText(info.entry)
    elseif info then
        line.pRank:SetText(string.format("%s#%d|r", info.rank <= TopN() and "|cffffffff" or SAME, info.rank))
        line.pScore:SetText(worn and WornDelta(info.key, info.entry) or string.format("%.1f", info.entry.score))
        line.entry = info.entry
        line.rankText = nil
    else
        line.pRank:SetText(LaterLevel(l.at))
        line.pScore:SetText("")
    end
end

local function ResetLine(line)
    line.entry, line.rankText, line.extraLines = nil, nil, nil
    line.quest, line.toggle, line.isCollapsed, line.gotoDungeon, line.action = nil, nil, nil, nil, nil
    line.openDungeon, line.tip, line.wishId, line.wishAll = nil, nil, nil, nil
    if line.starMoved then -- (a section's star, after its title: back in the gutter)
        line.starMoved = nil
        line.star:ClearAllPoints()
        line.star:SetPoint("CENTER", line, "LEFT", 11, 0)
    end
    line.side:SetText("")
    line.icon:SetAlpha(1)
    for _, part in ipairs(line.parts) do part:Hide() end
end

-- The loot list's lines are ROW_HEIGHT tall, spacers a third of that; the
-- list shows as many as fit in LOOT_LINES rows.
DrawLoot = function()
    local p = ns.GetProfile()
    local total = #lootLines
    local function Height(l) return l.kind == "spacer" and ROW_HEIGHT / 3 or ROW_HEIGHT end
    -- The last offset that still fills the list: as many lines from the end as fit.
    local room, maxOffset = LOOT_LINES * ROW_HEIGHT, total
    while maxOffset > 0 and room >= Height(lootLines[maxOffset]) do
        room = room - Height(lootLines[maxOffset])
        maxOffset = maxOffset - 1
    end
    lootOffset = math.max(0, math.min(lootOffset, maxOffset))
    -- A spacer at the top of the view is just a gap; skip it.
    local first = lootOffset + ((lootLines[lootOffset + 1] or {}).kind == "spacer" and 1 or 0)
    local width = maxOffset > 0 and lootPanel.narrow or lootPanel.wide
    FitLine(lootPanel.patCols, width)
    local y, n, stripe = 0, 0, 0
    for i = first + 1, total do
        local l = lootLines[i]
        local h = Height(l)
        if y + h > LOOT_LINES * ROW_HEIGHT then break end
        n = n + 1
        local line = lootPanel.lines[n]
        if not line then
            line = CreateLootLine(lootPanel, width)
            W.FitNewRow(lootPanel.lines, line) -- (the slot columns, fitted for the first lines)
            lootPanel.lines[n] = line
        end
        FitLine(line, width)
        ResetLine(line)
        line:SetHeight(h)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", lootPanel, "TOPLEFT", 0, -LOOT_TOP - y)
        y = y + h
        Draw[l.kind](line, l, p)
        UI.MarkWorn(line)
        local row = l.kind == "item" or l.kind == "pick" or l.kind == "pattern" or l.kind == "pickup"
            or l.kind == "zquest" or l.kind == "setpiece"
        stripe = row and stripe + 1 or 0
        if row and (stripe % 2 == 0 or not T.Classic()) then line.stripe:Show() end
        -- Only lines with something to hover or click light up.
        line:EnableMouse(l.kind ~= "gap" and l.kind ~= "spacer" and l.kind ~= "section"
            and (l.kind ~= "note" or l.gotoDungeon ~= nil or l.action ~= nil))
        line:Show()
    end
    for i = n + 1, #lootPanel.lines do lootPanel.lines[i]:Hide() end
    local bar = lootPanel.scroll
    if maxOffset > 0 then
        bar.updating = true
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetValue(lootOffset)
        bar.updating = false
        W.SizeThumb(bar, LOOT_LINES * ROW_HEIGHT * LOOT_LINES / total)
        bar:Show()
    else
        bar:Hide()
    end
end

---------------------------------------------------------------- loot list views

-- Summary: the dungeon's upgrades per slot, its quests still to pick up, and
-- look-ahead upgrades.
local function SummaryLines(dungeon, Add)
    local s = summaries[dungeon.id]
    Add({ kind = "section", text = worn and L["Upgrades now"] or L["Top picks"], wish = s.now })
    if #s.now == 0 then
        Add({ kind = "note", text = SAME .. ((not ranked and L["No rankings: this spec has no stat weights."])
            or (worn and L["Nothing here beats what you wear."]) or L["Nothing here makes the top list."]) .. "|r" })
        -- Point to the dungeon with the most.
        local best, most = nil, 0
        for _, d in ipairs(ns.Dungeons) do
            if #summaries[d.id].now > most then best, most = d, #summaries[d.id].now end
        end
        if best then
            local count = worn and ns.Plural(most, "%d upgrade", "%d upgrades")
                or ns.Plural(most, "%d top pick", "%d top picks")
            Add({ kind = "note", gotoDungeon = best.id, text = SAME .. string.format(L["Try %s: %s. Click to open it."],
                "|cffffd100" .. ns.DungeonName(best) .. "|r" .. SAME, count) .. "|r" })
        end
    end
    for _, pick in ipairs(s.now) do Add({ kind = "pick", pick = pick }) end
    if #s.quests > 0 then
        Add({ kind = "gap" })
        Add({ kind = "section", text = L["Pick up before you go"] })
        for _, q in ipairs(s.quests) do Add({ kind = "pickup", quest = q }) end
    end
    if #s.later > 0 then
        local ahead = ns.charDB.ahead or 0
        Add({ kind = "gap" })
        Add({ kind = "section", text = L["Coming up"],
              hint = ns.Plural(ahead, "within %d level (Look ahead)", "within %d levels (Look ahead)") })
        for _, pick in ipairs(s.later) do Add({ kind = "pick", pick = pick, later = true }) end
    end
end

-- Bosses: each boss's gear, with what is in it for the profile.
local function BossLines(dungeon, p, map, Add)
    local forMe = ns.db.lootUsableOnly
    local any = false
    for i, boss in ipairs(dungeon.bosses) do
        if IsBoss(boss) then
            local rows = {}
            for _, drop in ipairs(boss.items) do
                local item, info = ns.Items[drop.id], map[drop.id]
                if item then
                    local gain, up = Verdict(info)
                    if info or not forMe then
                        rows[#rows + 1] = { kind = "item", item = item, drop = drop, info = info, gain = gain, up = up }
                    end
                end
            end
            local key = dungeon.id .. ":" .. i
            local fold = collapsed[key] or false
            if any then Add({ kind = "spacer" }) end
            any = true
            Add({ kind = "boss", boss = boss, rows = #rows, collapsed = fold,
                  toggle = #rows > 0 and key or nil })
            if not fold then
                for _, r in ipairs(rows) do Add(r) end
            end
        end
    end
    if not any then Add({ kind = "note", text = SAME .. L["No boss loot known for this dungeon."] .. "|r" }) end
end

-- Whether quest source `s` is open to the profile (also its ns.Quests entry); true without a quest.
local function QuestOpenTo(s, p)
    return not s or (ns.QuestOpen(ns.Quests and ns.Quests[s.id] or {}, p) and ns.QuestOpen(s, p))
end

-- Quests: each quest (one per chain) with its gear rewards, the best pick of
-- each quest's choices marked. Your quests without gear rewards, then the
-- other faction's quests, go last, each behind a line that shows or hides
-- them (hidden at first in each session).
local function QuestLines(dungeon, p, map, Add)
    local forMe = ns.db.lootUsableOnly
    local groups = DungeonQuestGroups(dungeon, p)
    if #groups == 0 then
        Add({ kind = "note", text = SAME .. L["No quests known for this dungeon."] .. "|r" })
        return
    end
    local shown = 0
    -- `other`: one of the other faction's quests, with every reward whatever
    -- Show is set to, and its faction named.
    local function List(g, other)
        local s = g.quest
        local q = s and ns.Quests and ns.Quests[s.id] or {}
        local rows = {}
        for _, d in ipairs(g.drops) do
            local info = map[d.drop.id]
            if info or other or not forMe then
                local gain, up = Verdict(info)
                rows[#rows + 1] = { kind = "item", item = ns.Items[d.drop.id], drop = d.drop, info = info,
                    gain = gain, up = up, quest = d.quest, questReward = true, open = QuestOpenTo(d.quest, p) }
            end
        end
        -- The choice to take of each quest, as in the quest panel: the
        -- biggest gain, else the best rank.
        local best = {} -- [questId] = { row, key }
        for _, r in ipairs(rows) do
            local rq = r.quest and ns.Quests and ns.Quests[r.quest.id]
            local choices = rq and rq.rewards and rq.rewards.choices
            if choices and #choices > 1 and r.info and not r.info.upcoming and Contains(choices, r.drop.id) then
                local k, cur = r.gain or -r.info.rank, best[r.quest.id]
                if not cur or k > cur.key then best[r.quest.id] = { row = r, key = k } end
            end
        end
        for _, b in pairs(best) do b.row.bestPick = true end
        if shown > 0 then Add({ kind = "spacer" }) end
        Add({ kind = "quest", quest = s, q = q, rows = #rows, gear = #g.drops > 0,
              state = s and ns.QuestState(s.id), other = other })
        for _, r in ipairs(rows) do Add(r) end
        shown = shown + 1
    end
    -- A line with a fold sign that shows or hides `list` (`open`: shown now;
    -- `flip` changes that), then the list while shown.
    local function Fold(list, open, flip, text, other)
        Add({ kind = "spacer" })
        Add({ kind = "note", action = function()
                  flip()
                  UI.Refresh()
              end,
              folded = not open, text = text })
        if open then
            shown = 0 -- no spacer between the line and the first quest
            for _, g in ipairs(list) do List(g, other) end
        end
    end
    local mine, own, bare, other, otherSide = ns.FactionSide[p.faction], 0, {}, {}, nil
    for _, g in ipairs(groups) do
        local s = g.quest
        local side = (s and ns.Quests and ns.Quests[s.id] or {}).side or (s and s.side) or 3
        if mine and side ~= 3 and side ~= mine then
            other[#other + 1], otherSide = g, side
        else
            own = own + 1
            if QuestOpenTo(s, p) or not forMe then
                if #g.drops == 0 then bare[#bare + 1] = g else List(g) end
            end
        end
    end
    if shown == 0 and #bare == 0 then
        Add({ kind = "note", text = SAME .. ((own == 0 and L["No quests for your faction in this dungeon."])
            or ns.Plural(own, "This dungeon's quest isn't open to this profile. Show All loot to list it.",
                "None of this dungeon's %d quests are open to this profile. Show All loot to list them.")) .. "|r" })
    end
    if #bare > 0 then
        Fold(bare, showNoGear, function() showNoGear = not showNoGear end,
            showNoGear and L["Hide quests without gear"] or string.format(L["Show quests without gear (%d)"], #bare))
    end
    if #other > 0 then
        local label = ns.QuestSideLabel(otherSide)
        Fold(other, showOtherFaction, function() showOtherFaction = not showOtherFaction end,
            showOtherFaction and string.format(L["Hide %s quests"], label)
                or string.format(L["Show %s quests (%d)"], label, #other), true)
    end
end

-- The loot panel's header for the list it shows: "summary", "list" (Bosses
-- and Quests views) or "patterns". The Quests tab has no Bosses or Sets view
-- (its Quests one moves up beside Summary), and its Show lists all quests.
local function ShowListHeader(kind)
    local quests = mode == "quests"
    for _, tab in ipairs(lootPanel.tabs) do
        ShowIf(tab, kind ~= "patterns" and not (quests and (tab.key == "bosses" or tab.key == "sets")))
    end
    local tabs = lootPanel.tabs
    tabs[3]:ClearAllPoints()
    tabs[3]:SetPoint("LEFT", tabs[quests and 1 or 2], "RIGHT", 2, 0)
    if lootPanel.tabTrack then lootPanel.tabTrack.Fit(tabs) end
    lootPanel.show.buttons[2].text:SetText(quests and L["All quests"] or L["All loot"])
    ShowIf(lootPanel.show, kind == "list")
    ShowIf(lootPanel.patCols, kind == "patterns")
end

local function RefreshLoot(p)
    -- The dungeon follows the profile's level: a new level (leveling up, or
    -- the Level box) picks the one for it again. A dungeon picked by hand
    -- stays until then.
    if not selectedDungeon or (dungeonPanel.level and dungeonPanel.level ~= p.level) then
        selectedDungeon, lootOffset = DefaultDungeon(p.level), 0
    end
    dungeonPanel.level = p.level
    if not rankCache then rankCache = BuildRankMap() end
    local map = rankCache
    local dungeon
    local panel, level = dungeonPanel, p.level
    local groups = { early = {}, near = {}, late = {} }
    for _, b in ipairs(dungeonButtons) do
        local d = b.dungeon
        local s = DungeonSummary(d, p, map)
        summaries[d.id] = s
        b.badge:SetText(#s.now)
        ShowIf(b.badge, #s.now > 0)
        ShowIf(b.pill, #s.now > 0)
        local inRange = not (d.minLevel and d.maxLevel) or (level >= d.minLevel and level <= d.maxLevel)
        if inRange then b.name:SetTextColor(1, 1, 1) else b.name:SetTextColor(0.5, 0.5, 0.5) end
        if d.id == selectedDungeon then
            dungeon = d
            b.selected:Show()
        else
            b.selected:Hide()
        end
        local group = (d.maxLevel and level > d.maxLevel and "early")
            or (d.minLevel and level < d.minLevel - DUNGEONS_AHEAD and "late") or "near"
        b.group = group
        table.insert(groups[group], b)
    end
    -- A dungeon newly picked (by level, a "Try" note, a Crafting patterns
    -- header) unfolds its group; folding it again is left alone.
    if selectedDungeon ~= panel.shownSel then
        panel.shownSel = selectedDungeon
        for _, b in ipairs(dungeonButtons) do
            if b.dungeon.id == selectedDungeon and b.group ~= "near" then panel.open[b.group] = true end
        end
    end
    -- Lay the list out: Earlier, the dungeons near the level, Later.
    local y = 0
    local function Place(f)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -y)
        f:Show()
        y = y + DUNGEON_HEIGHT
    end
    local function Group(key)
        local fold, list = panel.folds[key], groups[key]
        local open = key == "near" or panel.open[key]
        if fold then
            ShowIf(fold, #list > 0)
            if #list > 0 then
                local ups = 0
                for _, b in ipairs(list) do ups = ups + #summaries[b.dungeon.id].now end
                fold.fold.Set(open)
                fold.right:SetText(#list)
                fold.badge:SetText(ups)
                ShowIf(fold.badge, not open and ups > 0)
                ShowIf(fold.pill, not open and ups > 0)
                Place(fold)
            end
        end
        for _, b in ipairs(list) do
            if open then Place(b) else b:Hide() end
        end
    end
    Group("early")
    Group("near")
    Group("late")
    panel:SetHeight(y)

    local view = LootView()
    local lines = {}
    local function Add(l) lines[#lines + 1] = l end
    if not dungeon then
        Add({ kind = "note", text = SAME .. L["No dungeon data."] .. "|r" })
    elseif view == "summary" then
        SummaryLines(dungeon, Add)
    elseif view == "bosses" then
        BossLines(dungeon, p, map, Add)
    elseif view == "sets" then
        ns.ItemSetLines.Add(dungeon, p, Add) -- (ItemSets.lua)
    else
        QuestLines(dungeon, p, map, Add)
    end
    lootLines = lines

    lootPanel.title:SetText(dungeon and (ns.DungeonName(dungeon) .. "  " .. SAME
        .. string.format(L["levels %s"], LevelRange(dungeon)) .. "|r") or "")
    for _, tab in ipairs(lootPanel.tabs) do W.SelectTab(tab, tab.key == view) end
    ShowListHeader((view == "summary" or view == "sets") and "summary" or "list")
    lootPanel.show.Update(ns.db.lootUsableOnly and "me" or "all")
    DrawLoot()
end

---------------------------------------------------------------- crafting patterns

-- The profession the Crafting patterns tab shows: the one picked on this
-- character, else its crafting profession with the highest skill, else the first.
local function PatternProfession(p)
    local best, bestRank
    for _, prof in ipairs(ns.Patterns or {}) do
        if prof.id == ns.charDB.patternProfession then return prof end
        local rank = p.professions[prof.id]
        if rank and (not bestRank or rank > bestRank) then best, bestRank = prof, rank end
    end
    return best or (ns.Patterns or {})[1]
end

-- How many of the profession's patterns make an upgrade for the profile (a
-- top pick while planning another class), for the profession list.
local function PatternUpgrades(prof, map)
    local n = 0
    for _, pat in ipairs(prof.patterns) do
        if select(2, Verdict(map[pat.item])) then n = n + 1 end
    end
    return n
end

-- Dungeon drop rows under a header per dungeon, in the dungeon list's order.
local function DropLines(rows, Add)
    local byPlace, order = {}, {}
    for _, r in ipairs(rows) do
        local z = r.drop.zoneId
        if not byPlace[z] then
            byPlace[z] = { place = PlaceOf(z), rows = {} }
            order[#order + 1] = byPlace[z]
        end
        table.insert(byPlace[z].rows, r)
    end
    table.sort(order, function(a, b) return a.place.order < b.place.order end)
    for _, g in ipairs(order) do
        local first = g.rows[1].drop.dungeon
        Add({ kind = "place", place = g.place, open = (first and dungeonIds[first]) and first or g.place.open })
        for _, r in ipairs(g.rows) do Add(r) end
    end
end

-- The profession's pattern rows per way to learn them: { [group key] = {row...} },
-- lowest skill first. A pattern learned several ways is in each group. Show:
-- For me (the default) keeps gear the profile can use now plus look-ahead upgrades.
local function PatternRows(prof, p, map)
    local showAll = ns.db.patternsShowAll
    local rank, vendor = p.professions[prof.id], WaylaidVendor(prof, p)
    local function Row(pat, source)
        local item = ns.Items[pat.item]
        if not item then return nil end
        local usable, why, at = Usable(item, p)
        local info = map[pat.item]
        if not (usable or info or showAll) then return nil end
        local _, up = Verdict(info)
        return { kind = "pattern", pattern = pat, prof = prof, vendor = vendor, item = item, info = info, up = up,
                 usable = usable, why = at and L["level too high"] or why, at = at, source = source, skillRank = rank, slot = SlotKey(item) }
    end
    local out = {}
    for _, g in ipairs(PATTERN_GROUPS) do
        local rows = {}
        for _, pat in ipairs(prof.patterns) do
            local how = pat[g.key]
            if g.key == "drops" then
                for _, d in ipairs(how or {}) do
                    local row = Row(pat, ns.NpcName(d.npcId, d.npc))
                    if row then
                        row.drop = d
                        rows[#rows + 1] = row
                    end
                end
            elseif how then
                local row = Row(pat, g.key == "waylaid" and string.format("%d %s", how, FAVOR_ICON)
                    or (how > 0 and ns.MoneyText(how) or ""))
                if row then rows[#rows + 1] = row end
            end
        end
        out[g.key] = rows
    end
    return out
end

-- Patterns (each counted once, however many ways it is learned) and upgrades
-- among PatternRows `rows`, per slot key and over all slots ("all").
local function SlotCounts(rows)
    local counts, ups, seen = {}, {}, {}
    for _, list in pairs(rows) do
        for _, r in ipairs(list) do
            if not seen[r.pattern] then
                seen[r.pattern] = true
                for _, key in ipairs({ r.slot or "other", "all" }) do
                    counts[key] = (counts[key] or 0) + 1
                    if r.up then ups[key] = (ups[key] or 0) + 1 end
                end
            end
        end
    end
    return counts, ups
end

-- The Crafting patterns list: a foldable header per way to learn the patterns
-- (PATTERN_GROUPS), the dungeon drops under a header per dungeon; only slot
-- `slot` when given.
local function PatternLines(prof, rows, slot, Add)
    for _, g in ipairs(PATTERN_GROUPS) do
        local list, ups = {}, 0
        for _, r in ipairs(rows[g.key]) do
            if not slot or r.slot == slot then
                list[#list + 1] = r
                if r.up then ups = ups + 1 end
            end
        end
        local key = "patterns:" .. prof.id .. ":" .. g.key
        local fold = collapsed[key] or false
        Add({ kind = "group", text = g.text, rows = #list, ups = ups, collapsed = fold,
              toggle = #list > 0 and key or nil })
        if not fold and g.key == "drops" then
            DropLines(list, Add)
        elseif not fold then
            for _, r in ipairs(list) do Add(r) end
        end
    end
end

-- The slot filter's label for slot key `key` ("All slots" for nil).
local function SlotFilterLabel(key)
    for _, g in ipairs(ns.SlotGroups) do
        if g.key == key then return SLOT_FILTER_LABEL[key] or g.label end
    end
    return L["All slots"]
end

local function RefreshPatterns(p)
    if not rankCache then rankCache = BuildRankMap() end
    local map = rankCache
    local prof = PatternProfession(p)
    -- Professions the character doesn't have are greyed, unless it has none of them.
    local mine = false
    for _, b in ipairs(professionButtons) do
        if p.professions[b.prof.id] then mine = true end
    end
    for _, b in ipairs(professionButtons) do
        b.ups = PatternUpgrades(b.prof, map)
        b.badge:SetText(b.ups)
        ShowIf(b.badge, b.ups > 0)
        ShowIf(b.pill, b.ups > 0)
        local rank = p.professions[b.prof.id]
        b.right:SetText(rank and tostring(rank) or "")
        if rank or not mine then b.name:SetTextColor(1, 1, 1) else b.name:SetTextColor(0.5, 0.5, 0.5) end
        if b.icon then
            b.icon:SetDesaturated(not (rank or not mine))
            b.icon:SetAlpha((rank or not mine) and 1 or 0.6)
        end
        if b.prof == prof then b.selected:Show() else b.selected:Hide() end
    end

    -- Filters: each slot chip's pattern count, green when some are upgrades;
    -- slots with none are dimmed.
    local rows = prof and PatternRows(prof, p, map) or {}
    local counts, ups = SlotCounts(rows)
    local slot = ns.charDB.patternSlot
    patternFilters.show.Update(ns.db.patternsShowAll and "all" or "me")
    for _, b in ipairs(patternFilters.chips) do
        local key = b.slotKey or "all"
        b.n, b.ups = counts[key] or 0, ups[key] or 0
        b.num:SetText((b.ups > 0 and GAIN or "") .. b.n .. (b.ups > 0 and "|r" or ""))
        W.StyleChoice(b, b.slotKey == slot)
        if b.slotKey ~= slot then
            local c = b.n > 0 and 0.9 or 0.4
            b.text:SetTextColor(c, c, c)
        end
    end

    local lines = {}
    local function Add(l) lines[#lines + 1] = l end
    if prof then
        PatternLines(prof, rows, slot, Add)
    else
        Add({ kind = "note", text = SAME .. L["No pattern data."] .. "|r" })
    end
    lootLines = lines

    local rank = prof and p.professions[prof.id]
    lootPanel.title:SetText(prof and (string.format(L["%s patterns"], L[prof.name]) .. SAME
        .. ((rank and ("  " .. string.format(L["your skill %d"], rank)))
            or (mine and ("  " .. L["not one of your professions"])) or "") .. "|r") or "")
    ShowListHeader("patterns")
    lootPanel.patCols.score:SetText(worn and L["vs worn"] or L["Score"])
    DrawLoot()
end

-- A skill point that changes nothing else (Player.lua): only the Crafting
-- patterns tab shows your ranks. Redrawn from the rankings already made.
function UI.ShowSkillRanks()
    if frame and frame:IsShown() and mode == "patterns" then RefreshPatterns(ns.GetProfile()) end
end

-- A profession's tooltip, only while some of its patterns make an upgrade:
-- what its green count means. (Its skill is on its row.)
local function ShowProfessionTooltip(self)
    if not (self.ups and self.ups > 0) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L[self.prof.name])
    GameTooltip:AddLine(worn and string.format(L["%d make an upgrade over what you wear"], self.ups)
        or string.format(L["%d make an item in the top %d for its slot"], self.ups, TopN()), 0.2, 1, 0.6, true)
    GameTooltip:Show()
end

local function CreateProfessionButton(parent, prof, index)
    local b = CreateListButton(parent, index, L[prof.name], "WildGearFontNormalSmall")
    b.prof = prof
    -- The profession's icon before its name (the trainer's spell icons).
    local icon = ({
        [164] = "Trade_BlackSmithing", [165] = "INV_Misc_ArmorKit_17", [197] = "Trade_Tailoring",
        [202] = "Trade_Engineering", [333] = "Trade_Engraving",
    })[prof.id]
    if icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", b, "LEFT", 8, 0)
        b.icon:SetTexture("Interface\\Icons\\" .. icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.name:ClearAllPoints()
        b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.name:SetPoint("RIGHT", b.pill, "LEFT", -4, 0)
    end
    b:SetScript("OnEnter", ShowProfessionTooltip)
    b:SetScript("OnClick", function(self)
        ns.charDB.patternProfession = self.prof.id
        lootOffset = 0
        UI.Refresh()
    end)
    return b
end

-- A slot filter chip: slot key `key` (nil for All slots) labelled `label`,
-- with its pattern count at the right (b.num). Its tooltip only when it adds
-- to the chip: the full name (Main Hand / Two-Hand, Ranged / Relic) or how
-- many of its patterns make an upgrade.
local function CreateSlotChip(parent, key, label, width)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, FILTER_ROW)
    W.AddHighlight(b)
    b.slotKey = key
    b.text = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.text:SetText(label)
    b.num = b:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    b.num:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b:SetScript("OnEnter", function(self)
        local name = SlotFilterLabel(self.slotKey)
        if name == label and not (self.ups and self.ups > 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(name)
        if self.ups and self.ups > 0 then
            GameTooltip:AddLine(worn and string.format(L["%d make an upgrade over what you wear"], self.ups)
                or string.format(L["%d make an item in the top %d for its slot"], self.ups, TopN()), 0.2, 1, 0.6, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", HideTooltip)
    b:SetScript("OnClick", function(self)
        ns.charDB.patternSlot = self.slotKey
        lootOffset = 0
        UI.Refresh()
    end)
    return b
end

-- Crafting patterns' filters, in a box of their own under the profession
-- list: Show (For me / All patterns, saved for all characters) and Slot
-- (saved per character), a chip per slot in a grid. Returns the box, with
-- box.show (Segmented) and box.chips (All slots first).
local function CreatePatternFilters(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Box(box)
    local inner = LEFT_WIDTH - 2 * FILTER_PAD
    local y = FILTER_PAD
    local function Label(text, font)
        local fs = box:CreateFontString(nil, "OVERLAY", font or "WildGearFontDisableSmall")
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", FILTER_PAD, -y)
        fs:SetText(text)
        y = y + 16
        return fs
    end
    Label(L["Filters"], "WildGearFontNormal")
    y = y + 2

    Label(L["Show"])
    box.show = W.Segmented(box, nil, {
        { key = "me", text = L["For me"],
          tip = L["Gear you can use now, whatever your skill, plus look-ahead upgrades"] },
        { key = "all", text = L["All patterns"] },
    }, (inner - 2) / 2, function(key)
        ns.db.patternsShowAll = key == "all" or nil
        lootOffset = 0
        UI.Refresh()
    end, true)
    box.show:SetPoint("TOPLEFT", box, "TOPLEFT", FILTER_PAD, -y)
    y = y + FILTER_ROW + 10

    Label(L["Slot"])
    box.chips = { CreateSlotChip(box, nil, L["All slots"], inner) }
    box.chips[1]:SetPoint("TOPLEFT", box, "TOPLEFT", FILTER_PAD, -y)
    y = y + FILTER_ROW + FILTER_GAP
    local labels = {}
    for i, g in ipairs(ns.SlotGroups) do
        box.chips[i + 1] = CreateSlotChip(box, g.key, g.label, 1)
        labels[i] = g.label
    end
    -- The slot chips in FILTER_COLS columns, or in 2 when the longest label
    -- and a two-digit count don't fit (German's slot names, a bigger text
    -- size), the box as tall as they need; again whenever the text size or
    -- font changes.
    local function Width(cols)
        return (inner - (cols - 1) * FILTER_GAP) / cols
    end
    T.Track(function()
        local need = W.TextWidth("WildGearFontHighlightSmall", labels)
            + W.TextWidth("WildGearFontDisableSmall", { "00" }) + 16 -- (6 in on each side, 4 between)
        local cols = need > Width(FILTER_COLS) and 2 or FILTER_COLS
        local width = Width(cols)
        for i = 2, #box.chips do
            local col, row = (i - 2) % cols, math.floor((i - 2) / cols)
            local chip = box.chips[i]
            chip:SetWidth(width)
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", box, "TOPLEFT", FILTER_PAD + col * (width + FILTER_GAP),
                -y - row * (FILTER_ROW + FILTER_GAP))
        end
        box:SetSize(LEFT_WIDTH, y + math.ceil(#ns.SlotGroups / cols) * (FILTER_ROW + FILTER_GAP) - FILTER_GAP + FILTER_PAD)
    end)
    return box
end

SetMode = function(newMode)
    if newMode ~= mode then
        listOffsets[mode], lootOffset = lootOffset, listOffsets[newMode] or 0
    end
    mode = newMode
    if mode == "quests" and tabs.quests.glow then
        tabs.quests.glow.Stop()
        tabs.quests.glow, ns.db.questsTabSeen = nil, true
    end
    W.HidePopup()
    UI.Refresh()
end

-- What the Quests tab (QuestsTab.lua) uses of the loot list and its helpers.
-- List.Show(lines, view, title) puts its lines in the list ("summary" or
-- "quests" view tab lit) under `title`.
UI.List = {
    Draw = Draw, Verdict = Verdict, BetterPick = BetterPick, Contains = Contains, ShowIf = ShowIf,
    CreateListButton = CreateListButton, SetHeader = SetHeader, ItemTooltip = ShowItemTooltip, Usable = Usable,
    SetSide = SetSide, ShowFold = ShowFold, ShowAll = ShowAll, ItemIcon = ItemIcon, ColoredName = ColoredName,
    LEFT_WIDTH = LEFT_WIDTH, DUNGEON_HEIGHT = DUNGEON_HEIGHT, VISIBLE_LINES = LOOT_LINES,
    RankMap = function()
        if not rankCache then rankCache = BuildRankMap() end
        return rankCache
    end,
    Worn = function() return worn end,
    Ranked = function() return ranked end,
    ResetScroll = function() lootOffset = 0 end,
    Offset = function(value) -- (the loot list's first line shown; `value` sets it)
        if value then lootOffset = value end
        return lootOffset
    end,
    Show = function(lines, view, title)
        lootLines = lines
        lootPanel.title:SetText(title or "")
        for _, tab in ipairs(lootPanel.tabs) do W.SelectTab(tab, tab.key == view) end
        ShowListHeader(view == "summary" and "summary" or "list")
        lootPanel.show.Update(ns.db.questsShowAll and "all" or "me")
        DrawLoot()
    end,
}

---------------------------------------------------------------- my gear panel

-- Side panel on the left of the window listing the character's worn gear for
-- reference. Toggled by the "My gear" button; saved for all characters. It
-- docks level with the window's top: a header (GearHeader) as tall as the
-- window's title, selectors and tabs, then the rows beside the Best in slot
-- tab's slot list. A second one sits beside the game's Character frame
-- (CharacterPanel.lua; panel.sheet): your gear for your main spec, whatever
-- the window plans, its header packed under the title band and its rows as
-- tall as fit the Character frame's height.
local GEAR_ROW = SLOT_HEIGHT
local GEAR_WIDTH = 290
local GEAR_TOP = TOP_HEIGHT
local GEAR_SLOT_LABEL = { [11] = L["Finger 1"], [12] = L["Finger 2"], [13] = L["Trinket 1"], [14] = L["Trinket 2"] }

-- Worn gear tiers, by how each worn item scores against the best available
-- item it could be swapped for (of a ring pair, the top ring not already
-- worn), in item quality colors: legendary with a glow when it is among the
-- best or within 3% of it (closer than the weights can tell apart), epic over
-- 85%, rare over 50%, none below.
local Tiers = {
    bis = { 1, 0.5, 0, fill = 0.32, hex = "|cffff8000", label = L["BiS"] },
    epic = { 0.64, 0.21, 0.93, fill = 0.26, hex = "|cffa335ee", label = "85%+" },
    rare = { 0, 0.44, 0.87, fill = 0.26, hex = "|cff0070dd", label = "50%+" },
}

-- { [invSlot] = { tier = Tiers entry or nil, text = tooltip line in its color } }
-- for the worn gear `worn` against the rankings `ranked` (a gear panel's
-- data: UpdateGearPanel); empty while planning another class. On a two-hander
-- setup a worn main and off hand, what a two-hander replaces, are measured
-- together (their scores summed) and both get the tier of the two.
function Tiers.ForWorn(worn, ranked)
    local out, lists = {}, {}
    for key, list in pairs(worn or {}) do lists[key] = list end
    local main, off = lists.mainhand and lists.mainhand[1], lists.offhand and lists.offhand[1]
    local pair = ranked and ranked.weapons.setup == "twohand" and main and off and main.score and off.score
    if pair then
        lists.mainhand, lists.offhand = { setmetatable({ score = main.score + off.score }, { __index = main }) }, nil
    end
    for key, list in pairs(lists) do
        -- Top: among the slot's best, worn items included (so both rings
        -- count); the others are measured against the best item to swap them for.
        -- An item fills as many places as the best picks it (two copies of a
        -- ring, ns.SlotPick) or you wear it, one at least; counts per item id.
        local bucket = ranked and ranked[key]
        local wearing, pool, cap, used, open, picked, top = {}, {}, {}, {}, {}, 0, {}
        for _, w in ipairs(list) do wearing[w.id] = (wearing[w.id] or 0) + 1 end
        for r = 1, bucket and SlotCount(key) or 0 do
            local e = ns.SlotPick(bucket, r)
            if e then pool[#pool + 1], cap[e.id] = e, (cap[e.id] or 0) + 1 end
        end
        if #pool > 0 then
            for _, w in ipairs(list) do pool[#pool + 1] = w.score and w or nil end
        end
        table.sort(pool, function(a, b) return a.score > b.score end)
        for _, e in ipairs(pool) do
            local n = used[e.id] or 0
            if picked < SlotCount(key) and n < math.max(cap[e.id] or 0, wearing[e.id] or 0, 1) then
                used[e.id], picked = n + 1, picked + 1
                if (wearing[e.id] or 0) > (top[e.id] or 0) then
                    top[e.id] = (top[e.id] or 0) + 1
                else
                    open[#open + 1] = e
                end
            end
        end
        for _, w in ipairs(list) do
            local tier, text
            local isTop = (top[w.id] or 0) > 0
            local ref = not isTop and table.remove(open, 1)
            if isTop then
                top[w.id] = top[w.id] - 1
                tier, text = Tiers.bis, L["Best in slot"]
            elseif ref and w.score then
                local ratio = ref.score > 0 and w.score / ref.score or 0
                tier = (ratio >= 0.97 and Tiers.bis) or (ratio > 0.85 and Tiers.epic)
                    or (ratio > 0.5 and Tiers.rare) or nil
                text = string.format(L["%d%% of the best: %s (%.1f)"], math.floor(ratio * 100),
                    ns.ItemName(ref.id, ref.suffix), ref.score)
            end
            out[w.invSlot] = { tier = tier, text = (tier and text) and (tier.hex .. text .. "|r") or text }
        end
    end
    if pair then out[off.invSlot] = out[main.invSlot] end
    return out
end

-- Tier look on a row: a stripe on the left edge in the tier's color and a fill
-- fading out by the start of the item name (a blue name on blue fill is hard
-- to read); for best in slot also a soft additive shine over the row and a
-- glow ring around `icon` (`size` across), steady after three quick pulses
-- when the row shows a new best-in-slot item.
function Tiers.AddTextures(row, icon, size)
    row.tint = row:CreateTexture(nil, "BACKGROUND")
    row.tint:SetPoint("TOPLEFT")
    row.tint:SetPoint("BOTTOMLEFT")
    row.tint:SetWidth(120)
    row.tint:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.tint:Hide()
    row.stripe = row:CreateTexture(nil, "BORDER")
    row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    row.stripe:SetWidth(2)
    row.stripe:Hide()
    row.glow = CreateFrame("Frame", nil, row)
    row.glow:SetAllPoints()
    row.glow.shine = row.glow:CreateTexture(nil, "ARTWORK")
    row.glow.shine:SetAllPoints()
    row.glow.shine:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.glow.shine:SetBlendMode("ADD")
    row.glow.ring = row.glow:CreateTexture(nil, "OVERLAY")
    row.glow.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    row.glow.ring:SetBlendMode("ADD")
    row.glow.ring:SetSize(size, size)
    row.glow.ring:SetPoint("CENTER", icon, "CENTER")
    -- None round an icon with a quality ring (W.IconRing; every theme's now):
    -- this round glow, added over that ring, turned a blue one white. The
    -- stripe, tint and shine still mark the row.
    if icon.ring then row.glow.ring:Hide() end
    local steady = 0.8
    row.glow:SetAlpha(steady)
    row.pulse = row.glow:CreateAnimationGroup()
    for i = 1, 6 do -- down and up three times, ending at the steady glow
        local fade = row.pulse:CreateAnimation("Alpha")
        fade:SetOrder(i)
        fade:SetFromAlpha(i % 2 == 1 and 1 or 0.35)
        fade:SetToAlpha(i % 2 == 1 and 0.35 or (i == 6 and steady or 1))
        fade:SetDuration(0.4)
        fade:SetSmoothing("IN_OUT")
    end
    row.glow:Hide()
end

-- Shows Tiers entry `tier` (nil: none) on a row made with Tiers.AddTextures,
-- for the item `id` it shows.
function Tiers.Show(row, tier, id)
    local function Fill(tex, c, from, to)
        local ok = CreateColor and pcall(tex.SetGradient, tex, "HORIZONTAL",
            CreateColor(c[1], c[2], c[3], from), CreateColor(c[1], c[2], c[3], to))
        if not ok then tex:SetVertexColor(c[1], c[2], c[3], from) end
    end
    ShowIf(row.tint, tier)
    ShowIf(row.stripe, tier)
    if tier then
        Fill(row.tint, tier, tier.fill, 0)
        row.stripe:SetColorTexture(tier[1], tier[2], tier[3], 1)
    end
    if tier == Tiers.bis then
        Fill(row.glow.shine, { 1, 0.75, 0.3 }, 0.16, 0)
        row.glow.ring:SetVertexColor(1, 0.7, 0.2, 0.9)
        row.glow:Show()
        if row.bisId ~= id then
            row.bisId = id
            row.pulse:Stop()
            row.pulse:Play()
        end
    else
        row.bisId = nil
        row.pulse:Stop()
        row.glow:Hide()
    end
end

-- The gear panel's header, lined up with the window's top: a title band like
-- the window's (with a note when you aren't wearing your main spec's set,
-- and Equip best while you carry better gear than you wear);
-- your character (beside the selectors' labels); while your gear
-- is scored, a bar for its total score against the best item for each slot
-- (beside the selector boxes); and a legend of the row colors (beside the
-- tabs). Hovering them gives the scores and how many slots have each color.
local GearHeader = { opens = {} } -- (opens: GearHeader.LightOpen)
local GEAR_BAR = GEAR_WIDTH - 2 * PAD - 40

-- The tag after a gear panel's title: the name of the weight profile its
-- scores use (WeightProfiles.lua), in the accent on a faint fill of it,
-- shown while one other than Default is picked (tag.Set(name), nil hides it).
function GearHeader.Tag(panel, title)
    local tag = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tag:SetHeight(16)
    tag:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    tag.text = tag:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    tag.text:SetPoint("CENTER", tag, "CENTER", 0, 0)
    -- (Classic: past the title's plaque, not over it)
    local plaque = T.Classic() and not panel.sheet and title:GetParent() ~= panel and title:GetParent()
    tag:SetPoint("LEFT", plaque or title, "RIGHT", plaque and 2 or 8, 0)
    tag.Set = function(name)
        if not name then return tag:Hide() end
        local r, g, b = T.Accent()
        tag.text:SetText(ns.WeightProfiles.ShortName(name, 16))
        tag.text:SetTextColor(r, g, b)
        tag:SetBackdropColor(r, g, b, 0.12)
        tag:SetBackdropBorderColor(r, g, b, 0.7)
        tag:SetWidth((tag.text:GetStringWidth() or 0) + 12)
        tag:Show()
    end
    tag:Hide()
    return tag
end

function GearHeader.Create(panel)
    -- (Beside the Character frame the title's place holds your character's
    -- name, Classic with no plaque, set by GearHeader.FitName: its rows say
    -- what the panel is, the addon's icon whose.)
    local title, band = W.TitleBand(panel, panel.sheet and "" or L["My gear"], "WildGearFontNormal",
        panel.sheet)
    panel.band = band
    if not panel.sheet then W.PanelIcon(title, band, "Gear") end -- (Modern: a helm before the title)
    -- (There, on a line of their own under the band, each only as wide as
    -- its text: the spec as a box, a pick making it your main spec as the
    -- window's Talent spec box does for your own class; and after it, while
    -- that spec and its weapon setup have weight profiles of yours, the one
    -- it scores with, as Settings' Weights box (Default, then the profiles).
    -- They take the tag's place. Placed with the header's lines, below.)
    if panel.sheet then
        panel.spec = W.Selector(panel, {
            width = 150, fit = true,
            options = function()
                local you, out = ns.GetPlayer(), {}
                for _, key in ipairs(ns.Specs[you.classFile] or {}) do
                    local guess = key == you.spec and you.specSource == "default"
                    out[#out + 1] = { text = ns.Tooltip.SpecLabel(you, key, guess), value = key,
                                      selected = key == you.spec }
                end
                return out
            end,
            set = UI.SetMainSpec,
        })
        local WP = ns.WeightProfiles
        panel.weights = W.Selector(panel, {
            width = 150, fit = true,
            options = function()
                local you = ns.GetPlayer()
                local setup = ns.GetWeaponSetupPref(you)
                local picked = WP.PickedId(you.classFile, you.spec, setup)
                local out = { { text = WP.Icon(you.classFile, you.spec, nil) .. " " .. L["Default"],
                                short = L["Default"], value = "default", selected = picked == nil } }
                for _, prof in ipairs(WP.List(you.classFile, you.spec, setup)) do
                    out[#out + 1] = { text = WP.Icon(you.classFile, you.spec, prof) .. " " .. prof.name,
                                      short = prof.name, value = prof.id, selected = prof.id == picked }
                end
                return out
            end,
            set = function(v)
                local you = ns.GetPlayer()
                WP.Pick(you.classFile, you.spec, ns.GetWeaponSetupPref(you), v ~= "default" and v or nil)
                ns.QuestWindow.Refresh() -- (as Settings' Weights box: the quest rewards' marks)
                Changed()
            end,
        })
        panel.weights:SetPoint("BOTTOMLEFT", panel.spec, "BOTTOMRIGHT", 6, 0)
        panel.weights:Hide()
        -- (and in the title's place, your character's name: GearHeader.FitName)
        panel.charName = title
        title:SetWordWrap(false)
    end
    panel.tag = GearHeader.Tag(panel, title)

    -- Beside the Character frame: a close button (panel.OnClose, from
    -- CharacterPanel.lua), and left of it a button with the addon's icon that
    -- opens and closes the window, lit while it's open (GearHeader.LightOpen);
    -- the band's other buttons go left of that (panel.right: where they end,
    -- as a SetPoint's relative frame, point and offsets).
    -- Classic: those two in the dialog border's corners, the close button in
    -- the top right one, the icon in the top left (W.IconButton), and the
    -- rest on their row: the spec right of the icon, the buttons ending 4
    -- short of the close button's box (29 in from the right).
    panel.right = { band, "RIGHT", -(PAD - 1), 0 }
    if panel.sheet then
        local classic = T.Classic()
        local close = W.CloseButton(panel, function() panel.OnClose() end)
        if not classic then close:SetPoint("RIGHT", band, "RIGHT", -(W.TITLE_HEIGHT - 20) / 2, 0) end
        local open = W.IconButton(panel, (T.Emblem()), 20) -- (Classic's or a skin's emblem, its season's while that shows)
        T.OnSeason(function() open.icon:SetTexture((T.Emblem())) end)
        -- (past either theme's close button)
        if not classic then open:SetPoint("RIGHT", band, "RIGHT", -(PAD - 1) - 18, 0) end
        open:SetScript("OnClick", function() UI.Toggle() end)
        open:SetScript("OnEnter", function(self) -- (as the minimap button's)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("WildGear")
            GameTooltip:AddLine(L["Click to open or close"], 1, 1, 1)
            GameTooltip:Show()
        end)
        open:SetScript("OnLeave", HideTooltip)
        panel.close, panel.open = close, open
        panel.right = { open, "LEFT", -6, 0 }
        if classic then
            title:SetPoint("LEFT", open, "RIGHT", 8, 0)
            local x, y = W.CornerButton() -- (the corner buttons' middle)
            panel.right = { panel, "TOPRIGHT", x - 15, y }
        end
        GearHeader.opens[#GearHeader.opens + 1] = open
        GearHeader.LightOpen()
    end

    -- While you carry better gear for your main spec than you wear (and the
    -- window shows your own character): Equip best (EquipBest.lua) at the
    -- band's right end, greyed in combat. Its hover lists each swap.
    -- GearHeader.UpdateEquip keeps it current.
    panel.equip = W.FitButton(W.FlatButton(panel, L["Equip best"], 72, 18))
    panel.equip:SetPoint("RIGHT", unpack(panel.right))
    panel.equip:SetScript("OnClick", function(self)
        if not (InCombatLockdown and InCombatLockdown()) then
            GameTooltip:Hide()
            GearHeader.from = panel -- (UI.EquipBestDone asks under its Save)
            ns.EquipBest(ns.EquipBestPlan())
        end
    end)
    panel.equip:SetScript("OnEnter", function(self) GearHeader.EquipTip(self) end)
    panel.equip:SetScript("OnLeave", HideTooltip)

    -- While your main spec is compared with one of your equipment sets
    -- (Settings: Compare with) and you wear something else: a note on the
    -- band (what differs on hover) and a button, greyed in combat, left of
    -- Equip best when that shows. Worse than the set somewhere: "Not wearing"
    -- the set in orange, and Wear puts it on. Else the set is out of date:
    -- "Better than" the set in green, and Save saves what you wear into it
    -- (so Equip best and Wear don't undo each other).
    -- GearHeader.UpdateSet keeps them current.
    panel.wear = W.FitButton(W.FlatButton(panel, L["Wear"], 46, 18))
    panel.wear:SetPoint("RIGHT", unpack(panel.right))
    panel.wear:SetScript("OnClick", function(self)
        if not self.setID or (InCombatLockdown and InCombatLockdown()) then return end
        if self.save then ns.SaveWornToSet(self.setID) else C_EquipmentSet.UseEquipmentSet(self.setID) end
    end)
    local note = CreateFrame("Frame", nil, panel)
    note:SetPoint("LEFT", title, "RIGHT", 10, 0)
    note:SetPoint("RIGHT", panel.wear, "LEFT", -8, 0)
    note:SetHeight(18)
    note:EnableMouse(true)
    note.text = note:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    note.text:SetAllPoints()
    note.text:SetJustifyH("RIGHT")
    note.text:SetWordWrap(false)
    note:SetScript("OnEnter", function(self) W.ShowBubble(self, self.tip) end)
    note:SetScript("OnLeave", W.HideBubble)
    -- (a hidden frame gets events too; one out of sight catches up on showing)
    note:SetScript("OnEvent", function()
        if not panel:IsVisible() then return end
        GearHeader.UpdateEquip(panel)
        GearHeader.UpdateSet(panel)
    end)
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED",
                         "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED" }) do
        pcall(note.RegisterEvent, note, e)
    end
    panel.setNote = note

    -- (These line up with the window's, from a top `drop` lower than its:
    -- UI.DockSides; Classic, further in from the sides: W.Inset. Beside the
    -- Character frame, two lines under the band: the spec and weights boxes,
    -- then the bar and its percentage, the legend on the right.) panel.top:
    -- the rows'.
    local inset = W.Inset()
    local pad, selectorY, barY, legendY, ruleY = PAD + inset
    panel.barWidth = GEAR_BAR
    if panel.sheet then
        -- (Classic: under the corner boxes, which end 29 down)
        selectorY = T.Classic() and 36 or W.TITLE_HEIGHT + 9
        local boxY = selectorY + 6 -- (the boxes' middle: their bottom 11 under it)
        panel.spec:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", pad, -boxY - 11)
        barY = boxY + 25
        legendY, ruleY = barY, barY + 12
        panel.top = ruleY + 6
    else
        local drop = frame.dock.top
        selectorY = SELECTOR_Y - drop
        barY = selectorY + 29 -- (the middle of the selector boxes)
        legendY = TAB_Y - drop + TAB_HEIGHT / 2 -- (the middle of the tabs)
        ruleY = TAB_Y - drop + TAB_HEIGHT
        panel.top = GEAR_TOP
    end

    -- Name on the left, level / race / class right-aligned; a long name gets
    -- cut, not the class. Beside the Character frame, which shows those: the
    -- spec it scores for, as a box in the title's place (above).
    if not panel.sheet then
        panel.who = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        panel.who:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -selectorY)
        panel.who:SetJustifyH("RIGHT")
        panel.who:SetWordWrap(false)
        panel.charName = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        panel.charName:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -selectorY)
        panel.charName:SetPoint("RIGHT", panel.who, "LEFT", -10, 0)
        panel.charName:SetJustifyH("LEFT")
        panel.charName:SetWordWrap(false)
    end

    panel.track = panel:CreateTexture(nil, "ARTWORK")
    panel.track:SetPoint("LEFT", panel, "TOPLEFT", pad, -barY)
    panel.track:SetSize(GEAR_BAR, 8)
    panel.track:SetColorTexture(1, 1, 1, 0.08)
    panel.fill = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    panel.fill:SetPoint("LEFT", panel.track, "LEFT")
    panel.fill:SetHeight(8)
    panel.pct = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    if panel.sheet then
        panel.pct:SetPoint("LEFT", panel.track, "RIGHT", 6, 0)
    else
        panel.pct:SetPoint("RIGHT", panel, "TOPRIGHT", -pad, -barY)
    end
    panel.note = panel:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    panel.note:SetPoint("LEFT", panel, "TOPLEFT", pad, -barY)

    -- (beside the Character frame, from the right: the last one first)
    panel.legend = {}
    local keys, prev = panel.sheet and { "rare", "epic", "bis" } or { "bis", "epic", "rare" }
    for _, key in ipairs(keys) do
        local tier = Tiers[key]
        local swatch = panel:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(8, 8)
        swatch:SetColorTexture(tier[1], tier[2], tier[3], 1)
        local text = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        if panel.sheet then
            text:SetPoint("RIGHT", prev or panel, prev and "LEFT" or "TOPRIGHT", prev and -12 or -pad, prev and 0 or -legendY)
            swatch:SetPoint("RIGHT", text, "LEFT", -5, 0)
            prev = swatch
        else
            if prev then
                swatch:SetPoint("LEFT", prev, "RIGHT", 12, 0)
            else
                swatch:SetPoint("LEFT", panel, "TOPLEFT", pad, -legendY)
            end
            text:SetPoint("LEFT", swatch, "RIGHT", 5, 0)
            prev = text
        end
        panel.legend[key] = { swatch = swatch, text = text }
    end
    local rule = W.Rule(panel, 1, 1, 1, 0.1)
    rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + inset, -ruleY)
    rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8 - inset, -ruleY)

    -- Hovering the bar or the legend explains them. (Its line only: beside
    -- the Character frame, not over the spec and weights boxes above it.)
    local hit = CreateFrame("Frame", nil, panel)
    hit:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + inset, panel.sheet and -barY + 8 or -barY + 10)
    hit:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", -8 - inset, -ruleY)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", function(self)
        local pr = panel.progress
        if not pr then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Gear progress"])
        GameTooltip:AddLine(string.format(L["Your gear scores %.1f of %.1f, the total of the best item for each slot "
            .. "at level %d."], pr.have, pr.total, pr.level), 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Rows are colored by how each item compares with the best one you could swap it for:"],
            1, 1, 1, true)
        -- each color with how many slots have it
        for _, t in ipairs({ { Tiers.bis, L["BiS: the best, or within 3% of it"] },
                             { Tiers.epic, L["85%+: over 85% of its score"] },
                             { Tiers.rare, L["50%+: over 50% of its score"] } }) do
            GameTooltip:AddDoubleLine(t[1].hex .. t[2] .. "|r", ns.Plural(pr.counts[t[1]] or 0, "%d slot", "%d slots"),
                1, 1, 1, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", HideTooltip)
end

-- Equip best (GearHeader.Create): shown while the window shows your own
-- character (beside the Character frame, always) and you carry better gear
-- for its main spec than you wear (ns.EquipBestPlan), greyed in combat. The
-- Wear button sits left of it then.
function GearHeader.UpdateEquip(panel)
    local plan = (panel.sheet or not ns.GetProfile().simulated) and ns.EquipBestPlan()
    local show = plan and plan.swaps[1] ~= nil
    ShowIf(panel.equip, show)
    panel.wear:ClearAllPoints()
    if show then
        panel.wear:SetPoint("RIGHT", panel.equip, "LEFT", -6, 0)
        local combat = InCombatLockdown and InCombatLockdown()
        if combat then panel.equip:Disable() else panel.equip:Enable() end
        panel.equip:SetAlpha(combat and 0.45 or 1)
    else
        panel.wear:SetPoint("RIGHT", unpack(panel.right))
    end
end

-- The window's buttons beside the Character frame (GearHeader.Create): lit
-- while it's open.
function GearHeader.LightOpen()
    for _, b in ipairs(GearHeader.opens) do W.SetActive(b, frame ~= nil and frame:IsShown()) end
end

-- Equip best's hover: the spec it's for, then a line per swap (what it
-- replaces, an arrow, the item that goes on; the gain on the right), then a
-- two-hander waiting on a free bag slot, and the upgrades left out because
-- they'd bind to you.
function GearHeader.EquipTip(owner)
    local plan = ns.EquipBestPlan()
    if not plan then return end
    local media = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\"
    local arrow = "|T" .. media .. "TipRight:0:0:0:0:32:32:0:32:0:32:136:136:136|t"
    local up = "|T" .. media .. "TipUp:0:0:0:0:32:32:0:32:0:32:51:255:153|t"
    local function Item(e) return "|T" .. ItemIcon(e.id) .. ":0|t " .. WornName(e) end
    local function Swap(s)
        local old = {}
        for _, w in ipairs(s.old) do old[#old + 1] = Item(w) end
        local from = old[1] and table.concat(old, "  +  ") or (SAME .. L["empty"] .. "|r")
        GameTooltip:AddDoubleLine(from .. "  " .. arrow .. "  " .. Item(s.new),
            up .. " " .. GAIN .. string.format("%+.1f", s.gain) .. "|r", 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddDoubleLine(L["Equip best"], ns.Tooltip.SpecLabel(plan.p, plan.p.spec), 1, 0.82, 0, 1, 1, 1)
    for _, s in ipairs(plan.swaps) do Swap(s) end
    if plan.noRoom then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(Item(plan.noRoom), "|cffff9900" .. L["Needs a free bag slot"] .. "|r",
            1, 1, 1, 1, 1, 1)
    end
    if plan.binds[1] then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Binds when equipped, not included"], 0.53, 0.53, 0.53)
        for _, s in ipairs(plan.binds) do Swap(s) end
    end
    GameTooltip:Show()
end

-- The band's set note and its Wear or Save button (GearHeader.Create): shown
-- while the set your main spec is compared with isn't what you wear; Save
-- while what you wear is as good as the set wherever they differ
-- (ns.WornBeatsSet).
-- Beside the Character frame: your character's name in the band's title
-- place, cut short of the band's buttons shown right of it (Wear, Equip
-- best, else the window's button; Classic, the close button), and to half
-- that room while the set note shows between them. (After UpdateEquip and
-- UpdateSet have placed and shown those.)
function GearHeader.FitName(panel)
    if not panel.sheet then return end
    local title = panel.charName
    title:SetText(GetUnitName("player", true) or UnitName("player") or "") -- (Forever's first + last name)
    local full = title.GetUnboundedStringWidth and title:GetUnboundedStringWidth() or title:GetStringWidth() or 0
    local right = (T.Classic() and panel.close or panel.open):GetLeft()
    for _, b in ipairs({ panel.equip, panel.wear }) do
        local l = b:IsShown() and b:GetLeft()
        if l and right then right = math.min(right, l) end
    end
    local left = title:GetLeft()
    if not (right and left) then return title:SetWidth(0) end -- (not laid out yet: its own width)
    local room = right - left - 10
    if panel.setNote:IsShown() then room = room / 2 end
    title:SetWidth(math.max(20, math.min(math.ceil(full) + 1, room)))
end

function GearHeader.UpdateSet(panel)
    local you = ns.GetPlayer()
    local id = ns.Tooltip.Compare(you.spec)
    local diffs = type(id) == "number" and ns.SetDifferences(id) or {}
    local show = #diffs > 0
    ShowIf(panel.setNote, show)
    ShowIf(panel.wear, show)
    GearHeader.FitName(panel)
    if not show then return end
    local name, slots = ns.EquipmentSetInfo(id), {}
    for _, g in ipairs(diffs) do slots[#slots + 1] = ns.GroupLabel(g, you) end
    local save = ns.WornBeatsSet(you, id, diffs)
    if save then
        panel.setNote.text:SetText(GAIN .. string.format(L["Better than %s"], name) .. "|r")
    else
        panel.setNote.text:SetText("|cffff9900" .. string.format(L["Not wearing %s"], name) .. "|r")
    end
    panel.setNote.tip = string.format(L["%s is compared with %s. Different now: %s"],
        ns.Tooltip.SpecLabel(you, you.spec), name, table.concat(slots, L[", "]))
    panel.wear:SetText(save and L["Save"] or L["Wear"])
    panel.wear.setID, panel.wear.save = id, save
    if not save then W.HideConfirm() end -- (UI.EquipBestDone's question)
    local combat = InCombatLockdown and InCombatLockdown()
    if combat then panel.wear:Disable() else panel.wear:Enable() end
    panel.wear:SetAlpha(combat and 0.45 or 1)
end

-- Equip best has put everything on (EquipBest.lua): while your main spec is
-- compared with a set that what you wear now beats (the band's Save), a
-- question under that Save button offers to save it right away (the Save of
-- the panel whose Equip best was clicked, else of the window's).
function UI.EquipBestDone()
    local panel = GearHeader.from
    if not (panel and panel:IsVisible()) then panel = gearPanel end
    if not (panel and panel:IsVisible()) then return end
    GearHeader.UpdateEquip(panel)
    GearHeader.UpdateSet(panel)
    local b = panel.wear
    if not (b:IsShown() and b.save) then return end
    local id = b.setID
    W.Confirm(b, string.format(L["Save what you wear to %s?"], T.AccentHex() .. (ns.EquipmentSetInfo(id) or "?") .. "|r"),
        L["Save"], L["Not now"], function() ns.SaveWornToSet(id) end, nil, true)
end

-- `d`: the panel's data (UpdateGearPanel); `have` / `total`: worn and best scores of
-- the shown rows; counts[tier] = rows in it.
function GearHeader.Update(panel, d, have, total, counts)
    GearHeader.UpdateEquip(panel)
    GearHeader.UpdateSet(panel)
    local you, worn = ns.GetPlayer(), d.worn
    local scored = panel.sheet and you or d.p
    local prof = scored and ns.WeightProfiles.Resolve(scored.classFile, scored.spec, ns.GetWeaponSetupPref(scored))
    panel.tag.Set(not panel.sheet and prof and prof.name or nil)
    if panel.sheet then
        panel.spec.Update()
        local mine = #ns.WeightProfiles.List(you.classFile, you.spec, ns.GetWeaponSetupPref(you)) > 0
        ShowIf(panel.weights, mine)
        if mine then -- (its name cut where it would pass the panel's side)
            panel.weights.Update()
            local room = panel:GetWidth() - 2 * (PAD + W.Inset()) - panel.spec:GetWidth() - 6
            panel.weights:SetWidth(math.max(40, math.min(panel.weights:GetWidth(), room)))
        end
    else
        panel.charName:SetText(GetUnitName("player", true) or UnitName("player") or "") -- (Forever's first + last name)
        panel.who:SetText(string.format(L["Level %d %s %s"],
            you.level, you.raceName or "", ClassColored(you.classFile, you.className or "")))
    end
    local ratio = worn and total > 0 and math.min(1, have / total)
    for _, part in ipairs({ panel.track, panel.fill, panel.pct }) do ShowIf(part, ratio) end
    for _, l in pairs(panel.legend) do
        ShowIf(l.swatch, ratio)
        ShowIf(l.text, ratio)
    end
    ShowIf(panel.note, not ratio)
    panel.progress = ratio and { have = have, total = total, level = d.p.level, counts = counts } or nil
    if not ratio then
        panel.note:SetText(worn and L["No stat weights for this spec."] or L["Scores only while planning your own class."])
        return
    end
    local c = (ratio >= 0.97 and Tiers.bis) or (ratio > 0.85 and Tiers.epic) or (ratio > 0.5 and Tiers.rare)
        or { 0.6, 0.6, 0.6 }
    for key, l in pairs(panel.legend) do l.text:SetText(Tiers[key].label) end
    if panel.sheet then
        -- (beside the Character frame the bar takes the room the legend
        -- leaves on its line: past its percentage, 12 short of the legend)
        local legend = 2 * 12
        for _, l in pairs(panel.legend) do legend = legend + 8 + 5 + l.text:GetStringWidth() end
        panel.barWidth = math.max(40, panel:GetWidth() - 2 * (PAD + W.Inset()) - legend - 52)
        panel.track:SetWidth(panel.barWidth)
    end
    panel.fill:SetColorTexture(c[1], c[2], c[3], 1)
    panel.fill:SetWidth(math.max(1, panel.barWidth * ratio))
    panel.pct:SetText(math.floor(ratio * 100) .. "%")
end

-- Gear panel `panel` from its data, panel.data: { p = the profile,
-- gear, worn, ranked } as the window's (UI.Refresh), or for your main spec
-- (CharacterPanel.lua).
local function UpdateGearPanel(panel)
    local d = panel and panel:IsShown() and panel.data
    if not d then return end
    local gear, ranked = d.gear, d.ranked
    local byInv, tiers = {}, Tiers.ForWorn(d.worn, ranked)
    for _, list in pairs(gear or {}) do
        for _, w in ipairs(list) do byInv[w.invSlot] = w end
    end
    local have, total, counts = 0, 0, {}
    -- Labels for your own class (a paladin's ranged slot is a relic), even while planning another.
    local me = { classId = select(3, UnitClass("player")) }
    -- The same slots as the Best in slot list (no off hand with a two-hander,
    -- unless you hold one: UI.KeepOffRow), so each row sits beside its slot
    -- there; beside the Character frame, as tall as fill its height
    -- (panel.RowFor: a fraction, each row's top rounded, so some are a
    -- point taller and the last ends at the bottom margin).
    local shown = 0
    for _, row in ipairs(panel.rows) do
        ShowIf(row, not (ranked and row.group.weapon and not ranked[row.key])
            or (row.key == "offhand" and UI.KeepOffRow(d)))
        if row:IsShown() then shown = shown + 1 end
    end
    local height = panel.RowFor and panel.RowFor(math.max(shown, 1)) or panel.row
    shown = 0
    for _, row in ipairs(panel.rows) do
        local w, t = byInv[row.invSlot], tiers[row.invSlot] or {}
        if row:IsShown() then
            shown = shown + 1
            local y = math.floor((shown - 1) * height + 0.5)
            row:SetHeight(math.floor(shown * height + 0.5) - y)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + W.Inset(), -panel.top - y)
            local best = ranked and ranked[row.key] and ns.SlotPick(ranked[row.key], row.place)
            total = total + (best and best.score or 0)
            have = have + (w and w.score or 0)
            if t.tier then counts[t.tier] = (counts[t.tier] or 0) + 1 end
        end
        row.label:SetText(GEAR_SLOT_LABEL[row.invSlot] or ns.GroupLabel(row.group, me))
        row.entry = w
        if w then
            ItemIcon(w.id, row.icon)
            row.icon:Show()
            row.name:SetText(WornName(w))
            row.score:SetText(d.worn and w.score and string.format("%.1f", w.score) or "")
        else
            row.icon:Hide()
            row.name:SetText("|cff666666" .. L["empty"] .. "|r")
            row.score:SetText("")
        end
        Tiers.Show(row, t.tier, w and w.id)
        row.label:SetTextColor(T.LabelColor(not panel.sheet and mode == "bis" and row.key == selectedSlot))
    end
    GearHeader.Update(panel, d, have, total, counts)
    -- (as tall as the window on Best in slot, or the Character frame)
    panel:SetHeight(math.max(panel.fit or 0, panel.top + math.floor(shown * height + 0.5) + panel.bottom))
end

-- The window's gear panel, or with `fit` the Character frame's (panel.sheet;
-- UI.NewGearPanel): at least `fit` tall (panel.fit), its rows as tall as
-- fill it down to the bottom margin (panel.RowFor(n) for n of them, 18 to
-- 30; panel.row for them all, rounded down), their icons smaller in rows
-- under 24. Its bottom margin (panel.bottom): the window's, but in the
-- Modern theme beside the Character frame its sides' (8), as there's no
-- window bottom to line up with and only a thin border.
local function CreateGearPanel(parent, fit)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel.sheet, panel.fit = fit ~= nil, fit
    panel.addsBlock = panel.sheet -- (out of the window: Tooltip.lua leaves its rows' tooltips to them)
    W.Window(panel)
    panel:SetClampedToScreen(true) -- placed by UI.DockSides (CharacterPanel.lua)
    panel:EnableMouse(true)

    GearHeader.Create(panel)
    local count = 0
    for _, g in ipairs(ns.SlotGroups) do count = count + #g.equip end
    panel.bottom = (fit and not T.Classic()) and 8 or PAD
    if fit then
        function panel.RowFor(n) -- (panel.fit: CharacterPanel.lua sets it anew on a frame of another height)
            return math.max(18, math.min(30, (panel.fit - panel.top - panel.bottom) / n))
        end
    end
    panel.row = fit and math.floor(panel.RowFor(count)) or GEAR_ROW
    local icon = math.min(20, panel.row - 4)

    panel.rows = {}
    for _, g in ipairs(ns.SlotGroups) do
        for place, invSlot in ipairs(g.equip) do
            local i = #panel.rows + 1
            local row = CreateFrame("Button", nil, panel)
            row:SetSize(GEAR_WIDTH - 16, panel.row)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + W.Inset(), -panel.top - (i - 1) * panel.row) -- UpdateGearPanel re-lays them out
            row.key, row.invSlot, row.group, row.place = g.key, invSlot, g, place

            row.label = row:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.label:SetWidth(52)
            row.label:SetJustifyH("LEFT")

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(icon, icon)
            row.icon:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
            W.IconBorder(row.icon)

            row.score = row:CreateFontString(nil, "OVERLAY", T.Classic() and "WildGearFontNormalSmall"
                or "WildGearFontHighlightSmall")
            row.score:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.score:SetWidth(36)
            row.score:SetJustifyH("RIGHT")

            row.name = row:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetPoint("RIGHT", row.score, "LEFT", -4, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)

            Tiers.AddTextures(row, row.icon, icon * 2)

            SetupItemButton(row)
            -- Click opens the slot on the window's Best in slot tab (and the
            -- window, from beside the Character frame); shift/ctrl-click as usual.
            row:SetScript("OnClick", function(self)
                if self.entry and IsModifiedClick and IsModifiedClick() then
                    OnItemClick(self)
                    return
                end
                selectedSlot = self.key
                SetMode("bis")
                if not (frame and frame:IsShown()) then UI.Toggle() end
            end)
            panel.rows[i] = row
        end
    end
    panel:SetSize(GEAR_WIDTH + 2 * W.Inset(), math.max(fit or 0, panel.top + #panel.rows * panel.row + panel.bottom))
    panel:SetScript("OnShow", function(self)
        UpdateGearPanel(self)
        if not self.sheet then UI.DockSides() end
    end)
    if not panel.sheet then panel:SetScript("OnHide", function() UI.DockSides() end) end
    panel:Hide()
    return panel
end

-- Every slot name a gear panel's or the slot list's label column may show.
function UI.SlotTexts()
    local texts = { L["Two-Hand"], L["Relic"] }
    for _, g in ipairs(ns.SlotGroups) do texts[#texts + 1] = g.label end
    for _, text in pairs(GEAR_SLOT_LABEL) do texts[#texts + 1] = text end
    return texts
end

-- My gear beside the Character frame (CharacterPanel.lua): a gear panel on
-- `parent` with its rows fitting `height`, filled by UI.UpdateGearPanel.
function UI.NewGearPanel(parent, height)
    if not frame then T.Apply() end -- (the fonts, before any text is measured, as Create)
    local panel = CreateGearPanel(parent, height)
    W.FitColumn(panel.rows, "label", "WildGearFontDisableSmall", UI.SlotTexts(), 90)
    return panel
end
UI.UpdateGearPanel = UpdateGearPanel

-- Docks the side panels: My gear on the window's left (its rows line up with
-- the slot list), and stat weights or quest details on the right.
-- A panel without room on its side goes to the other side when there is room
-- there (beside any panel already on it). With room on neither it takes a free
-- side and stays on screen over the window's edge, never on another panel.
-- 4 out from the window, level with its top (Classic: frame.dock).
function UI.DockSides()
    if not frame then return end
    -- (in the window's units: it and its panels have the Scale setting on top of UIParent's)
    local left, right, screen = frame:GetLeft(), frame:GetRight(), UIParent:GetWidth() / frame:GetScale()
    local room = { left = left or math.huge, right = (right and screen) and screen - right or math.huge }
    local used = { left = 0, right = 0 }
    local dock = frame.dock
    local function Place(panel, side)
        local w = panel:GetWidth() + 4
        local other = side == "left" and "right" or "left"
        if used[side] + w > room[side] and (used[other] + w <= room[other] or (used[side] > 0 and used[other] == 0)) then
            side = other
        end
        panel:ClearAllPoints()
        if side == "left" then
            panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -(used.left + dock.left), -dock.top)
        else
            panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", used.right + dock.right, -dock.top)
        end
        used[side] = used[side] + w
    end
    -- (the wish list's panel while it shows, WishList.lua: under My gear and
    -- as wide, over its bottom edge; in its place while My gear is closed)
    local wish = ns.WishList.Dock()
    if wish and gearPanel then
        wish:SetWidth(gearPanel:GetWidth())
        wish:SetFrameLevel(gearPanel:GetFrameLevel() + 3)
    end
    if gearPanel and gearPanel:IsShown() then
        Place(gearPanel, "left")
        if wish then
            wish:ClearAllPoints()
            wish:SetPoint("TOPLEFT", gearPanel, "BOTTOMLEFT", 0, -wish.gap)
        end
    elseif wish then
        Place(wish, "left")
    end
    if sidePanel and sidePanel:IsShown() then Place(sidePanel, "right") end
    if wish then ns.WishList.Docked() end
end

---------------------------------------------------------------- window

-- The display settings changed (Theme.Apply): rescale the window about its
-- top-left corner, which stays put, and redraw.
function UI.ApplyDisplay()
    if not frame then return end
    local old, new = frame:GetScale(), T.Get("scale")
    if math.abs(new - old) > 0.001 then
        local x, y = frame:GetLeft(), frame:GetTop()
        frame:SetScale(new)
        if x and y then
            ns.db.window = { x = x * old / new, y = y * old / new }
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ns.db.window.x, ns.db.window.y)
        end
    end
    UI.Refresh()
end

-- Back to the default spot, top center.
function UI.ResetPosition()
    ns.db.window = nil
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120 / frame:GetScale())
    UI.DockSides()
end

local function Create()
    T.Apply() -- (the fonts, before any text is measured)
    frame = CreateFrame("Frame", "WildGearFrame", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, 500)
    frame:SetScale(T.Get("scale")) -- (before placing it: the saved position is in its units)
    -- The Classic theme's frame (W.ClassicWindow) has its own places for the
    -- selectors, the lists and the buttons, and docks the side panels lower
    -- (frame.dock: UI.DockSides); they follow its top (My gear's rows beside
    -- the slot list, its legend just above them).
    local classic = T.Classic()
    local geo
    frame.dock = { top = 0, bottom = 0, left = 4, right = 4 }
    if classic then
        geo = W.ClassicWindow(frame, WIDTH, LEFT_WIDTH)
        SELECTOR_Y, TOP_HEIGHT, BOTTOM = geo.selectorY, geo.top, geo.bottom
        TAB_Y, GEAR_TOP = geo.top - TAB_HEIGHT, geo.top - geo.dock.top
        frame.dock = geo.dock
    else
        W.Window(frame)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    -- Classic: the tabs hang below the frame (32 tall, their top tabY above
    -- its bottom) and the title plaque sticks out above it (40 tall, centred
    -- 4 + dock.top below its top); keep both on screen too.
    if classic then
        frame:SetClampRectInsets(0, 0, math.max(0, 16 - geo.dock.top), -(32 - geo.tabY))
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Anchor by the top-left corner so the window grows downward when "Show top" changes.
        ns.db.window = { x = self:GetLeft(), y = self:GetTop() }
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ns.db.window.x, ns.db.window.y)
        UI.DockSides()
    end)
    frame:SetScript("OnMouseDown", function() W.HidePopup() end)
    -- (the wish list moves onto the window while it is open: WishList.lua)
    frame:SetScript("OnHide", function()
        W.HidePopup()
        GearHeader.LightOpen()
        ns.WishList.Window(false)
    end)
    frame:SetScript("OnShow", function()
        UI.Refresh()
        GearHeader.LightOpen()
        ns.WishList.Window(true)
    end)
    local pos = ns.db.window
    if pos and pos.x then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -120 / frame:GetScale())
    end
    table.insert(UISpecialFrames, "WildGearFrame") -- close with Escape

    -- Title bar: darker band with the title, buttons on the right, the close
    -- button as far from the band's edges as it is tall. Classic: the title in
    -- a plaque as the side panels', the close button in the frame's corner,
    -- the buttons in the bottom bar.
    local title, bar
    if classic then
        title, bar = W.TitleBand(frame, "WildGear", "WildGearFontNormal", nil, geo.dock.top)
    else
        title, bar = W.TitleBand(frame, "WildGear", "WildGearFontNormalLarge")
    end
    -- (Modern: the addon's emblem before the title)
    local logo = W.TitleIcon(title, bar, "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Icon", 20)

    -- The title drags the window, its emblem too (Classic: the whole plaque,
    -- which sticks out above the window's top).
    local info = CreateFrame("Frame", nil, frame)
    if classic then
        info:SetAllPoints(title:GetParent())
    else
        info:SetPoint("LEFT", logo or title, "LEFT")
        info:SetPoint("RIGHT", title, "RIGHT")
        info:SetHeight(W.TITLE_HEIGHT)
    end
    info:EnableMouse(true)
    info:RegisterForDrag("LeftButton")
    info:SetScript("OnDragStart", function() frame:StartMoving() end)
    info:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)
    info:SetScript("OnMouseDown", function() W.HidePopup() end)

    local close = W.CloseButton(frame, nil, true)
    if classic then
        close:SetPoint("CENTER", frame, "TOPRIGHT", geo.closeX, geo.closeY)
    else
        close:SetPoint("RIGHT", bar, "RIGHT", -(W.TITLE_HEIGHT - 20) / 2, 0)
    end
    frame.close = close -- (as the quest panel's: the smoketest clicks it last)

    local settingsButton = W.FitButton(W.FlatButton(frame, L["Settings"], 70))
    if classic then
        settingsButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, geo.barY)
    else
        settingsButton:SetPoint("RIGHT", close, "LEFT", -6, 0)
    end
    settingsButton:SetScript("OnClick", function() ns.Settings.Toggle() end)

    weightsPanel = ns.WeightsPanel.Create()
    local weightsButton = W.FitButton(W.FlatButton(frame, L["Stat weights"], 90))
    weightsButton:SetPoint("RIGHT", settingsButton, "LEFT", -6, 0)
    weightsButton:SetScript("OnClick", function()
        if weightsPanel:IsShown() then weightsPanel:Hide() else weightsPanel:Show() end
    end)

    gearPanel = CreateGearPanel(frame)
    local gearButton = W.FitButton(W.FlatButton(frame, L["My gear"], 70))
    gearButton:SetPoint("RIGHT", weightsButton, "LEFT", -6, 0)
    gearButton:SetScript("OnClick", function()
        ns.db.showGear = not gearPanel:IsShown() -- false once closed; nil (never toggled) shows it
        if ns.db.showGear then gearPanel:Show() else gearPanel:Hide() end
    end)

    -- Each panel's button stays lit while its panel is open.
    local function Lit(button, panel)
        local function Paint() W.SetActive(button, panel:IsShown()) end
        panel:HookScript("OnShow", Paint)
        panel:HookScript("OnHide", Paint)
        T.Track(Paint)
    end
    Lit(settingsButton, ns.Settings.Panel())
    Lit(weightsButton, weightsPanel)
    Lit(gearButton, gearPanel)
    if ns.db.showGear ~= false then gearPanel:Show() end

    -- Only shown while planning another character.
    myCharButton = W.FitButton(W.FlatButton(frame, L["Back to my character"], 130))
    myCharButton:SetPoint("RIGHT", gearButton, "LEFT", -6, 0)
    myCharButton:SetScript("OnClick", function()
        ns.charDB.sim = nil
        Changed()
    end)

    -- Selectors in one row, on the columns below: Class and Race over the left
    -- list, the rest over the right side from its edge, Look ahead ending flush
    -- with the tab rule. (Show top is in the Settings panel.) Classic: in the
    -- frame's stone band right of the portrait, a little narrower and closer.
    local x = classic and geo.selectorX or PAD
    for _, def in ipairs({ classDef, raceDef, specDef, levelDef, weaponDef, aheadDef }) do
        if classic then def.width = math.floor(def.width * 0.94) end
        local s = W.Selector(frame, def)
        s:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -SELECTOR_Y)
        s.def = def
        selectors[#selectors + 1] = s
        x = x + def.width + (classic and 11 or def == raceDef and COLUMN_GAP or 14)
    end

    -- Tab strip above the lists. Classic: the game's tabs hanging below the
    -- frame, each overlapping the one before.
    local prevTab
    for _, t in ipairs({ { key = "bis", text = L["Best in slot"] }, { key = "loot", text = L["Dungeon loot"] },
                         { key = "patterns", text = L["Crafting patterns"] }, { key = "quests", text = L["Quests"] } }) do
        local tab = W.Tab(frame, t.text, "WildGearFontNormal", 120, classic)
        tab:SetHeight(classic and 32 or TAB_HEIGHT)
        if prevTab then
            tab:SetPoint("LEFT", prevTab, "RIGHT", classic and geo.tabGap or 2, 0)
        elseif classic then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 14, geo.tabY)
        else
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TAB_Y)
        end
        tab:SetScript("OnClick", function() SetMode(t.key) end)
        tabs[t.key] = tab
        prevTab = tab
    end
    -- The Quests tab, being new, glows until it is first opened (saved for all characters: SetMode).
    if not ns.db.questsTabSeen then tabs.quests.glow = W.TabGlow(tabs.quests, classic) end
    if not classic then
        local tabRule = W.Rule(frame, 1, 1, 1, 0.1)
        tabRule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TAB_Y - TAB_HEIGHT)
        tabRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TAB_Y - TAB_HEIGHT)
    end

    -- Left column: the slot / dungeon list on a card (Classic: in the frame's
    -- left inset).
    local leftX = classic and geo.left or PAD
    local function LeftColumn()
        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftX, -TOP_HEIGHT)
        if not classic then
            local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints()
            bg:SetColorTexture(unpack(T.CARD))
        end
        return panel
    end

    slotPanel = LeftColumn()
    -- One button per slot: rings and trinkets get two, the slot's #1 and #2.
    for _, g in ipairs(ns.SlotGroups) do
        for place = 1, g.slots or 1 do
            local b = CreateSlotButton(slotPanel, g, #slotButtons + 1)
            b.place = place
            slotButtons[#slotButtons + 1] = b
        end
    end
    slotPanel:SetSize(LEFT_WIDTH, #slotButtons * SLOT_HEIGHT)

    local rightX = classic and geo.right or PAD + LEFT_WIDTH + COLUMN_GAP
    local rightWidth = classic and geo.rightWidth or WIDTH - rightX - PAD
    -- The Best in slot sections scroll once they are taller than the screen
    -- allows (top 10 with look ahead): mouse wheel, or the bar on the right.
    local view = CreateFrame("ScrollFrame", nil, frame)
    view:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -TOP_HEIGHT)
    view:SetSize(rightWidth, 10)
    rightPanel = CreateFrame("Frame", nil, view)
    rightPanel:SetSize(rightWidth, 10)
    view:SetScrollChild(rightPanel)
    rightPanel.view = view
    local bar = W.ScrollBar(frame)
    bar:SetPoint("TOPLEFT", view, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", view, "BOTTOMRIGHT", 4, 0)
    bar:SetScript("OnValueChanged", function(_, value) view:SetVerticalScroll(value) end)
    bar:Hide()
    rightPanel.bar = bar
    local function Wheel(_, delta)
        if bar:IsShown() then bar:SetValue((bar:GetValue() or 0) - delta * 3 * ROW_HEIGHT) end
    end
    for _, f in ipairs({ view, bar }) do
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", Wheel)
    end
    wornSection = CreateSection(rightPanel, "worn", rightWidth, 2)
    for i, t in ipairs(ns.SourceTypes) do
        sections[i] = CreateSection(rightPanel, t, rightWidth)
    end
    sections[#sections + 1] = CreateSection(rightPanel, "all", rightWidth) -- (List: All sources, in their place)
    for _, sec in ipairs({ wornSection, unpack(sections) }) do
        for _, row in ipairs(sec.rows) do
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", Wheel)
        end
    end

    -- Dungeon loot tab
    dungeonPanel = LeftColumn()
    dungeonPanel:SetSize(LEFT_WIDTH, #ns.Dungeons * DUNGEON_HEIGHT)
    for i, d in ipairs(ns.Dungeons) do
        dungeonButtons[i] = CreateDungeonButton(dungeonPanel, d, i)
    end
    -- The Earlier and Later folds (RefreshLoot places them).
    dungeonPanel.open = {} -- [fold key] = true while unfolded (this session)
    dungeonPanel.folds = { early = CreateDungeonFold(dungeonPanel, "early", L["Earlier"]),
                           late = CreateDungeonFold(dungeonPanel, "late", L["Later"]) }
    lootPanel = CreateLootPanel(frame, rightWidth)
    lootPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", rightX, -TOP_HEIGHT)
    dungeonPanel:Hide()
    lootPanel:Hide()

    -- Columns of slot names fit the longest one in the client's language and
    -- the text size: in the slot list and My gear the item names beside them
    -- make room, in the loot list the column after the item names.
    local slotTexts = UI.SlotTexts()
    local dim = "WildGearFontDisableSmall"
    W.FitColumn(slotButtons, "label", dim, slotTexts, 90)
    W.FitColumn(gearPanel.rows, "label", dim, slotTexts, 90)
    W.FitColumn(lootPanel.lines, "slot", dim, slotTexts, 100, "source")
    W.FitColumn(lootPanel.lines, "kind", dim, ns.SlotLabels(), 134, "rank")

    -- Crafting patterns tab: on the left the professions (a list like the
    -- dungeons'), then the filters in a box of their own; the patterns go in
    -- the loot list.
    professionPanel = CreateFrame("Frame", nil, frame)
    professionPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftX, -TOP_HEIGHT)
    local profList = CreateFrame("Frame", nil, professionPanel)
    profList:SetPoint("TOPLEFT", professionPanel, "TOPLEFT", 0, 0)
    profList:SetSize(LEFT_WIDTH, #(ns.Patterns or {}) * DUNGEON_HEIGHT)
    if not classic then
        local profBg = profList:CreateTexture(nil, "BACKGROUND", nil, -1)
        profBg:SetAllPoints()
        profBg:SetColorTexture(unpack(T.CARD))
    end
    for i, prof in ipairs(ns.Patterns or {}) do
        professionButtons[i] = CreateProfessionButton(profList, prof, i)
    end
    patternFilters = CreatePatternFilters(professionPanel)
    patternFilters:SetPoint("TOPLEFT", profList, "BOTTOMLEFT", 0, -SECTION_GAP)
    T.Track(function() -- (after the filters' own, which sizes them)
        professionPanel:SetSize(LEFT_WIDTH, profList:GetHeight() + SECTION_GAP + patternFilters:GetHeight())
    end)
    professionPanel:Hide()

    -- Quests tab: its zones and filters on the left (QuestsTab.lua); its quests go in the loot list.
    ns.QuestsTab.Create(frame, leftX, TOP_HEIGHT)

    -- Keep the window current while it shows, once per burst of events:
    -- ranked again when your level or gear changes, or a worn item it waited
    -- on has loaded; else (names loaded, quest progress) just redrawn. Hidden,
    -- it does nothing: it refreshes on showing, and the tooltips, bag arrows,
    -- My gear and the wish list follow these events themselves. (UI.Refresh
    -- here threw away every tooltip's rankings on each burst of items
    -- loading, and they were all ranked again.)
    local pending, rerank
    frame:SetScript("OnEvent", function(_, event, id)
        if not frame:IsShown() then return end
        if event == "PLAYER_LEVEL_UP" or event == "PLAYER_EQUIPMENT_CHANGED"
            or (event == "GET_ITEM_INFO_RECEIVED" and ns.WornWaiting(worn, id)) then
            rerank = true
        end
        if pending then return end
        pending = true
        local function Run()
            pending = false
            local again = rerank
            rerank = nil
            UI.RefreshWindow(again)
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.5, Run) else Run() end
    end)
    for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", -- (skills: Player.lua)
                         "QUEST_DATA_LOAD_RESULT", -- (item and quest names loaded, see Locale.lua)
                         "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do -- (quest progress marks)
        pcall(frame.RegisterEvent, frame, e)
    end

    frame:Hide()
end

function UI.Refresh()
    ns.Tooltip.Invalidate() -- spec, weights, weapon setup or a setting may have changed
    ns.BagMarks.Refresh() -- (the bag items' upgrade arrows, likewise)
    ns.Settings.Update() -- (its off-spec list leaves out your main spec)
    if ns.CharacterPanel then ns.CharacterPanel.Refresh() end -- (My gear beside the Character frame)
    if ns.WishList then ns.WishList.Refresh() end -- (the gains on the wish list's tracker)
    UI.RefreshWindow(true)
end

-- The window's part of UI.Refresh, while it shows: with `rerank` (or nothing
-- ranked yet), its profile ranked again; else redrawn from the rankings it
-- has (the game loaded names, quest progress: neither changes them).
function UI.RefreshWindow(rerank)
    if not (frame and frame:IsShown()) then return end
    local p = ns.GetProfile()
    if rerank or not ranked then
        -- Worn gear is only scored and compared for the character's own class,
        -- and then ranks among the best as gear the character already owns.
        local ownClass = select(2, UnitClass("player")) == p.classFile
        gear = ns.GetEquipped(ownClass and p or nil)
        worn = ownClass and gear or nil
        ranked = ns.Rank(p, { ahead = ns.charDB.ahead, classArmorOnly = ns.db.classArmorOnly, owned = worn })
        rankCache = nil
        gearPanel.data = { p = p, gear = gear, worn = worn, ranked = ranked }
    end
    if ns.QuestPanel then ns.QuestPanel.Refresh() end
    for _, s in ipairs(selectors) do s.Update() end

    local setup = ranked and ranked.weapons
    if p.simulated then myCharButton:Show() else myCharButton:Hide() end

    ns.WeightsPanel.Update()
    UpdateGearPanel(gearPanel)
    UI.DockSides()
    for key, tab in pairs(tabs) do W.SelectTab(tab, key == mode) end
    ShowIf(slotPanel, mode == "bis")
    ShowIf(rightPanel.view, mode == "bis")
    if mode ~= "bis" then rightPanel.bar:Hide() end
    ShowIf(dungeonPanel, mode == "loot")
    ShowIf(professionPanel, mode == "patterns")
    ns.QuestsTab.Show(mode == "quests")
    ShowIf(lootPanel, mode ~= "bis")
    if mode == "loot" then
        RefreshLoot(p)
        frame:SetHeight(TOP_HEIGHT + math.max(dungeonPanel:GetHeight(), lootPanel:GetHeight()) + BOTTOM)
        return
    elseif mode == "patterns" then
        RefreshPatterns(p)
        frame:SetHeight(TOP_HEIGHT + math.max(professionPanel:GetHeight(), lootPanel:GetHeight()) + BOTTOM)
        return
    elseif mode == "quests" then
        frame:SetHeight(TOP_HEIGHT + ns.QuestsTab.Refresh(p, lootPanel:GetHeight()) + BOTTOM)
        return
    end

    -- With a two-hander there is no off hand: hide that slot (left empty while
    -- you hold an off hand, beside My gear's: UI.KeepOffRow) and relabel the main hand.
    local twoHand = setup and setup.setup == "twohand"
    if selectedSlot == "offhand" and ranked and not ranked.offhand then selectedSlot = "mainhand" end
    local shown = 0
    for _, b in ipairs(slotButtons) do
        local key = b.group.key
        local empty = ranked and b.group.weapon and not ranked[key]
        if empty and not (key == "offhand" and UI.KeepOffRow()) then
            b:Hide()
        else
            shown = shown + 1
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", 0, -(shown - 1) * SLOT_HEIGHT)
            b:Show()
            b.label:SetText((key == "mainhand" and twoHand) and L["Two-Hand"]
                or (b.group.slots and GEAR_SLOT_LABEL[b.group.equip[b.place]])
                or ns.GroupLabel(b.group, ns.GetProfile()))
            local best = ranked and ranked[key] and ns.SlotPick(ranked[key], b.place)
            local _, isWorn
            b.entry = best
            if best then _, _, isWorn = WornDelta(key, best) end
            if best then
                ItemIcon(best.id, b.icon)
            else
                b.icon:SetTexture(not empty and QUESTION_MARK or nil)
                W.SetIconQuality(b.icon, nil)
            end
            b.name:SetText(best and ((isWorn and WORN_CHECK or "") .. (best.owned and WornName(best)
                or ColoredName(best.id, best.suffix)))
                or (empty and "" or ("|cff666666" .. L["none"] .. "|r")))
            local nextUp = b.place == 1 and ranked and ranked.upcoming and ranked.upcoming[key] and ranked.upcoming[key].all[1]
            b.next:SetText(nextUp and (UPGRADE .. string.format(L["lvl %d"], nextUp.level) .. "|r") or "")
            b.rankText = nextUp and string.format(L["Next upgrade at level %d: %s (+%.1f)"],
                nextUp.level, ns.ItemName(nextUp.id, nextUp.suffix), nextUp.gain) or nil
            if key == selectedSlot then
                b.selected:Show()
                b.label:SetTextColor(T.LabelColor(true))
            else
                b.selected:Hide()
                b.label:SetTextColor(T.LabelColor(false))
            end
        end
    end
    slotPanel:SetHeight(shown * SLOT_HEIGHT)

    -- Each source section: its top N now, then (with look ahead) its upgrades
    -- in the order they unlock, in green with the level and the score gain.
    local n = TopN()
    local y = 0
    local bucket = ranked and ranked[selectedSlot]
    local paths = ranked and ranked.upcoming and ranked.upcoming[selectedSlot]

    -- What is worn in the slot, marked BiS in orange as in My gear (both
    -- hands for a two-hander, which replaces them both).
    local wornList = worn and worn[selectedSlot]
    if wornList and selectedSlot == "mainhand" and twoHand and worn.offhand and worn.offhand[1] then
        wornList = wornList[1] and { wornList[1], worn.offhand[1] } or worn.offhand
    end
    ShowIf(wornSection, wornList ~= nil)
    if wornList then
        local tiers = Tiers.ForWorn(worn, ranked)
        wornSection:ClearAllPoints()
        wornSection:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 0, 0)
        wornSection.header:SetText(L["Equipped"])
        wornSection.empty:SetText(L["Nothing worn in this slot."])
        ShowIf(wornSection.empty, #wornList == 0)
        for i, row in ipairs(wornSection.rows) do
            local w = wornList[i]
            row.entry, row.rankText, row.quest = w, nil, nil
            row.upcoming:Hide()
            if w then
                local bis = tiers[w.invSlot] and tiers[w.invSlot].tier == Tiers.bis
                row.rank:SetText("")
                ItemIcon(w.id, row.icon)
                row.name:SetText(WornName(w))
                local s = w.item and w.item.sources and w.item.sources[1]
                row.source:SetText(s and ns.DescribeSource(s, nil, QUEST_ICON)
                    or (w.item and ns.ItemTypeLabel(w.item)) or "")
                row.delta:SetText(bis and (Tiers.bis.hex .. L["BiS"] .. "|r") or "")
                row.score:SetText(w.score and string.format("%.1f", w.score) or "")
                ns.WishList.SetStar(row, nil)
                FitQuestHit(row, row.source)
                row:Show()
            else
                row:Hide()
            end
        end
        y = HEADER_HEIGHT + math.max(#wornList, 1) * ROW_HEIGHT + SECTION_GAP
    end
    -- (each source only while its Settings filter is on; with List: All
    -- sources, one list of them all in their place, the worn item at its rank)
    local combined = ns.db.allSources == true
    for _, sec in ipairs(sections) do
        if sec.type == "all" then ShowIf(sec, combined) else ShowIf(sec, not combined and ns.SourceOn(sec.type)) end
        if sec:IsShown() then
            sec:ClearAllPoints()
            sec:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 0, -y)
            local list = bucket and bucket[sec.type] or {}
            -- (an item with random suffixes on a line per suffix)
            local lines = ns.SuffixRows(list, p, n, selectedSlot == "offhand")
            local upcoming = paths and paths[sec.type] or {}
            local nowRows = math.min(#lines, n)
            local upRows = math.min(#upcoming, MAX_UPCOMING)
            local count = #list > n and string.format(L["top %d of %d usable"], n, #list)
                or string.format(L["%d usable"], #list)
            local header = (ns.SourceLabels[sec.type] or L["All sources"]) .. "  |cff888888" .. count .. "|r"
            if #upcoming > 0 then
                header = header .. "  " .. UPGRADE .. string.format(L["%d coming up"], #upcoming) .. "|r"
            end
            sec.header:SetText(header)
            sec.empty:SetText(ranked and L["No usable items for this slot."] or L["No stat weights for this spec."])
            if #list == 0 then sec.empty:Show() else sec.empty:Hide() end
            local first = math.max(nowRows, 1) + 1 -- upgrades go below the list, or below the "no items" note
            for i, row in ipairs(sec.rows) do
                local entry, up
                if i <= nowRows then
                    entry = lines[i]
                elseif i >= first and i < first + upRows then
                    entry, up = upcoming[i - first + 1], true
                end
                row.entry, row.rankText, row.quest = entry, nil, nil
                if entry then
                    row.delta:SetText(up and "" or WornDelta(selectedSlot, entry))
                    ItemIcon(entry.id, row.icon)
                    row.name:SetText(entry.owned and WornName(entry) or ColoredName(entry.id, entry.suffix))
                    UI.MarkWorn(row)
                    -- (an upgrade names the source it opens up from first; a worn
                    -- item the data doesn't offer, in the All list, its type)
                    local s = SourceOf(entry, up and entry.opensBy or sec.type)
                    row.quest = s and s.type == "quest" and s or nil
                    -- (the Quest section's header already says quest)
                    local source = s and ns.DescribeSource(s, HasQuestDetails(s) and QUEST_LINK or nil,
                        sec.type == "quest" and "" or QUEST_ICON) or (entry.item and ns.ItemTypeLabel(entry.item)) or ""
                    if up then
                        row.rank:SetText("")
                        row.source:SetText(UPGRADE .. string.format(L["lvl %d"], entry.level) .. "|r  " .. source)
                        row.score:SetText(string.format("%s+%.1f|r", UPGRADE, entry.gain))
                        row.rankText = UpgradeText(entry)
                        row.upcoming:Show()
                    else
                        row.rank:SetText(i .. ".")
                        row.source:SetText(source)
                        -- green score = boosted by a racial weapon specialization
                        row.score:SetText(string.format(entry.racialBonus and "|cff33ff99%.1f|r" or "%.1f", entry.score))
                        row.upcoming:Hide()
                    end
                    ns.WishList.SetStar(row, entry.id, entry.suffix)
                    FitQuestHit(row, row.source)
                    row:Show()
                else
                    row:Hide()
                end
            end
            local rows = upRows > 0 and (first - 1 + upRows) or n
            y = y + HEADER_HEIGHT + math.max(rows, n) * ROW_HEIGHT + SECTION_GAP
        end
    end

    -- Scroll what doesn't fit on screen; back to the top for another slot.
    local view, bar = rightPanel.view, rightPanel.bar
    local room = math.max(shown * SLOT_HEIGHT, (UIParent:GetHeight() or 0) / frame:GetScale() - TOP_HEIGHT - BOTTOM - 20)
    local height = math.min(y, room)
    rightPanel:SetHeight(math.max(y, 1))
    view:SetHeight(math.max(height, 1))
    if rightPanel.slot ~= selectedSlot then bar:SetValue(0) end
    rightPanel.slot = selectedSlot
    if y > height then
        bar:SetMinMaxValues(0, y - height)
        bar:SetValue(math.min(bar:GetValue() or 0, y - height))
        view:SetVerticalScroll(bar:GetValue() or 0)
        W.SizeThumb(bar, height * height / y)
        bar:Show()
    else
        bar:SetMinMaxValues(0, 0)
        bar:SetValue(0)
        view:SetVerticalScroll(0)
        bar:Hide()
    end
    frame:SetHeight(TOP_HEIGHT + math.max(shown * SLOT_HEIGHT, height) + BOTTOM)
end

function UI.Frame()
    return frame
end

function UI.Toggle()
    if not frame then Create() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Opens the window on the Dungeon loot tab's `view` ("summary", "bosses",
-- "quests" or "sets"; What's new).
function UI.ShowLoot(view)
    if not frame then Create() end
    ns.db.lootView = view ~= "summary" and view or nil
    lootOffset = 0
    if not frame:IsShown() then frame:Show() end
    SetMode("loot")
end

-- Opens the window on the Best in slot tab's slot `key` (an ns.SlotGroups
-- key; the wish list's tracker).
function UI.ShowSlot(key)
    if not frame then Create() end
    selectedSlot = key
    if not frame:IsShown() then frame:Show() end
    SetMode("bis")
end

-- Minimap addon-compartment entry (## AddonCompartmentFunc in the TOC).
function WildGear_OnAddonCompartmentClick()
    UI.Toggle()
end
