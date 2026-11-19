local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Settings panel, docked on the right of the window like Stat weights (one
-- side panel at a time, UI.ClaimSide), in four boxes that fold (Section), each
-- on its own. Filters, with Show top (how many items each source lists on Best
-- in slot, WildGearDB.topN), List (By source, or All sources:
-- allSources = true, one list of them all there), Armor type (classArmorOnly, on every
-- tab) and Sources, a switch per source type (quest, drop, crafted, boe =
-- false when off; Scoring.lua's ns.SourceOn), with under Quest, while on, how
-- far above your level a quest may be (questAbove, +0 to +10, nil = +3;
-- Scoring.lua's ns.QuestAbove; its last choice No limit, questAnyLevel = true:
-- any level) and Dungeon quests (questDungeon = false when off: the
-- quests the game files as Dungeon ones count no more), under Crafted, while on, your professions, whose
-- bind-on-pickup crafts count (each on or off, this character's: learned
-- ones on until switched off, charDB.professions; Player.lua's
-- ns.HasProfession), and under BoE, while on, blue and purple ones and the
-- dungeons' own (boeRare, boeEpic, boeDungeon = false when off). Modern: each
-- source on a card of its own, its own filters in it as chips (W.Chip), and
-- Show top on one line; Classic: a row each, its filters indented. Display, with
-- the theme (Modern or
-- Classic, on a reload), the window's scale, the wish list's (its size),
-- background opacity and accent color (not Classic), font (with a UI addon)
-- and text size
-- (Theme.lua). All saved for all
-- characters. Both folded at first. Then your specs, which item
-- tooltips and quest rewards go by, one list of lines for this character:
-- first the main spec and its weapon setup (the window's Talent spec and
-- Weapons), its weights (the profile picked for it, as the Stat weights
-- panel picks) and the gear it is compared with (charDB.compare), then the
-- off specs scored too (Tooltip.lua's entries, charDB.offSpecs), each the
-- same: a spec and weapon setup with a remove button, its weights and what
-- it is compared with; Add off spec (while there are fewer than 3) adds the
-- next one. An off spec the same as the main spec's line or an earlier one is
-- greyed out (it doesn't score). With dual talent learned, each line also has
-- the talent set it is linked to (None, Primary or Secondary, the active one
-- dotted; Tooltip.lua's Tip.LinkTalents): the line linked to the active set is
-- the main spec, so a swap in game, or linking an off spec to the active set,
-- trades it with the main spec's line. Last, Shown on, switches for what uses
-- them: item tooltips (Tooltip.lua; tooltip = false when off), the upgrade
-- arrows on bag items (BagMarks.lua; bagMarks = false), My gear beside the
-- Character frame (CharacterPanel.lua; characterPanel = false), the wish list's
-- tracker (WishList.lua; wishTracker = false), the marks on quest rewards
-- (QuestWindow.lua; questMarks = false), and under it, while on, its
-- off-spec suggestions (questOffSpec = false).
-- The panel is as tall as the window at most (Fit): the boxes scroll in it
-- when they don't fit, under the title, the Reset buttons staying at the bottom.
-- Opened by the window's Settings button or /wildgear settings.

local UI, W, T, L = ns.UI, ns.Widgets, ns.Theme, ns.L
local S = {}
ns.Settings = S

local WIDTH = 250
local PAD = 14
local INNER = WIDTH - 2 * PAD
-- The boxes: their padding, and the width inside them.
local BOX_PAD = 8
local BOX_INNER = INNER - 2 * BOX_PAD
local TOP = W.TITLE_HEIGHT + 10 -- the first box's top, under the title band (level with the window's selectors)
local GAP = 10 -- between the boxes
local FOOT = 16 + 22 + PAD -- under the boxes: the Reset buttons
local MIN_HEIGHT = 360 -- the panel's height cap with a window shorter than that
local WHEEL_STEP = 40
local panel

-- While the boxes scroll (the bar shown), the mouse wheel scrolls them. A
-- scroll that reaches a selector goes on scrolling over it (W.Selector's
-- def.scroller) until the wheel rests SCROLL_HOLD seconds; a wheel turn that
-- starts on a selector steps its value, as when nothing scrolls.
local SCROLL_HOLD = 0.6
local scrolledAt -- GetTime() of the last scroll step

local function Scroll(delta)
    local bar = panel.bar
    if not bar:IsShown() then return end
    W.HidePopup()
    W.HideBubble()
    bar:SetValue((bar:GetValue() or 0) - delta * WHEEL_STEP)
    scrolledAt = GetTime()
end

local function Scroller()
    return panel and panel.bar:IsShown() and scrolledAt and GetTime() - scrolledAt < SCROLL_HOLD and Scroll or nil
end

local function Percent(v)
    return string.format("%d%%", math.floor(v * 100 + 0.5))
end

-- Selector options from `from` to `to` by `step`, as percentages.
local function PercentSteps(key, from, to, step)
    return function()
        local current, out = T.Get(key), {}
        for i = 0, math.floor((to - from) / step + 0.5) do
            local v = math.floor((from + i * step) * 100 + 0.5) / 100
            out[#out + 1] = { text = Percent(v), value = v, selected = math.abs(v - current) < 0.001 }
        end
        return out
    end
end

local function PercentSelector(parent, key, label, from, to, step)
    return W.Selector(parent, {
        label = label, width = (BOX_INNER - 10) / 2,
        hint = L["Scroll to change"], scroller = Scroller,
        options = PercentSteps(key, from, to, step),
        set = function(v) T.Set(key, v) end,
        fallback = function() return Percent(T.Get(key)) end,
    })
end

-- 1 to UI.MAX_TOP items.
local topDef = {
    label = L["Show top"], width = BOX_INNER,
    hint = L["Scroll to change"], scroller = Scroller,
    options = function()
        local out = {}
        for n = 1, UI.MAX_TOP do
            out[#out + 1] = { text = tostring(n), value = n, selected = n == UI.TopN() }
        end
        return out
    end,
    set = function(v)
        ns.db.topN = v
        UI.Refresh()
        panel.top.Update()
    end,
}

-- Under the Quest source: up to how many levels above yours a quest's rewards
-- count, +0 to +10 and then No limit (any level), in a box this wide on the
-- right of its row. Either way a quest your level can't accept yet (its
-- required level) never counts: the tip says so, on hover of the row (under
-- it, as wide), for the choice made.
local ABOVE_W = 84
local ABOVE_TIP = L["Count quests up to this many levels higher than you. Only quests you can already accept."]
local ANY_TIP = L["Count quests of any level. Only quests you can already accept."]
local function AboveTip() return ns.db.questAnyLevel and ANY_TIP or ABOVE_TIP end
local aboveDef = {
    width = ABOVE_W, hint = L["Scroll to change"], scroller = Scroller,
    tip = AboveTip, tipAnchor = function() return panel.above end,
    options = function()
        local any = ns.db.questAnyLevel == true
        local current, out = ns.QuestAbove(), {}
        for n = 0, ns.QUEST_ABOVE_MAX do
            out[#out + 1] = { text = ns.Plural(n, "+%d level", "+%d levels"), short = "+" .. n, value = n,
                              selected = not any and n == current }
        end
        out[#out + 1] = { text = L["No limit"], value = "any", selected = any } -- (the last choice, past the most levels)
        return out
    end,
    set = function(v)
        if v == "any" then -- (the number picked before stays saved, for when the limit is back)
            ns.db.questAnyLevel = true
        else
            ns.db.questAnyLevel = nil
            ns.db.questAbove = v ~= ns.QUEST_ABOVE and v or nil
        end
        ns.QuestWindow.Refresh()
        UI.Refresh() -- (the window's lists, item tooltips, bag arrows and this panel)
    end,
}

-- Main spec (Tooltip.lua) and its weapon setup: the same as the window's
-- Talent spec and Weapons (its choice for that spec), each spec with the
-- setups the window offers it at your level.
local mainDef = {
    label = L["Main spec"], width = BOX_INNER, scroller = Scroller,
    options = function()
        local p, out = ns.GetPlayer(), {}
        local current = ns.GetWeaponSetupPref(p)
        for _, spec in ipairs(ns.Specs[p.classFile] or {}) do
            local label = ns.Tooltip.SpecLabel(p, spec, spec == p.spec and p.specSource == "default")
            for _, setup in ipairs(ns.WeaponSetupOptions(ns.Tooltip.Profile(p, spec))) do
                out[#out + 1] = { text = label .. " · " .. ns.WeaponSetups[setup].label, value = spec .. ":" .. setup,
                                  selected = spec == p.spec and setup == current }
            end
        end
        return out
    end,
    set = function(value)
        local spec, setup = value:match("^(%w+):(%w+)$")
        ns.charDB.spec = spec
        if ns.charDB.sim then ns.charDB.sim.spec = nil end
        ns.SetWeaponSetupPref(ns.Tooltip.Profile(ns.GetPlayer(), spec), setup)
        W.HidePopup()
        UI.Refresh()
    end,
}

local OFF_TIP = L["Score items for another spec, weapon setup or weight profile as well.\n\n"
    .. "Item tooltips show its score, and quest rewards show its upgrades when your main spec has none."]

-- What a spec is compared with (Tooltip.lua's Tip.Compare), `current` marked:
-- what you wear, the best of what you wear and carry, or one of your
-- equipment manager's sets.
local function CompareOptions(current)
    local out = {}
    local function Add(text, value) out[#out + 1] = { text = text, value = value, selected = value == current } end
    Add(L["Worn"], "worn")
    Add(L["Worn + bags"], "bags")
    for _, set in ipairs(ns.EquipmentSets()) do
        Add((set.icon and ("|T" .. set.icon .. ":0|t ") or "") .. set.name, set.id)
    end
    return out
end

-- The weights class/spec/setup can score with (WeightProfiles.lua), `current`
-- (a profile id; nil, or one deleted since, for Default) marked: Default,
-- then its profiles.
local function WeightOptions(classFile, spec, setup, current)
    local WP = ns.WeightProfiles
    local out, found = {}, false
    for _, prof in ipairs(WP.List(classFile, spec, setup)) do
        found = found or prof.id == current
        out[#out + 1] = { text = WP.Icon(classFile, spec, prof) .. " " .. prof.name, short = prof.name,
                          value = prof.id, selected = prof.id == current }
    end
    table.insert(out, 1, { text = WP.Icon(classFile, spec, nil) .. " " .. L["Default"], short = L["Default"],
                           value = "default", selected = not found })
    return out
end

-- The talent sets a line can be linked to (Tooltip.lua's Tip.LinkTalents),
-- `current` (1, 2 or nil) marked: None, Primary, Secondary, the active one
-- with an accent dot.
local DOT = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Dot"
local function TalentOptions(current)
    local active = ns.Tooltip.ActiveTalentSet()
    local r, g, b = T.Accent()
    local dot = string.format(" |T%s:12:12:0:0:32:32:0:32:0:32:%d:%d:%d|t", DOT, r * 255, g * 255, b * 255)
    local out = { { text = L["None"], value = "none", selected = current == nil } }
    for set, name in ipairs({ L["Primary"], L["Secondary"] }) do
        out[#out + 1] = { text = name .. (set == active and dot or ""), value = set, selected = current == set }
    end
    return out
end

-- After a change to your specs: the quest rewards' marks, item tooltips,
-- the bag arrows and this panel again.
local function SpecsChanged()
    ns.QuestWindow.Refresh()
    UI.Refresh()
end

-- A row in `parent` (the Specs box's inside): `label` on the left (`indent`
-- in), and in a column on the right a selector, W.Selector(def) (its width
-- set here).
local LABEL_W, ROW_H = 96, 22
local function SelectRow(parent, indent, label, def)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(BOX_INNER, ROW_H)
    row.label = row:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 1 + indent, 0)
    row.label:SetWidth(LABEL_W - 6 - indent)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetText(label)
    def.width, def.scroller = BOX_INNER - LABEL_W, Scroller
    row.select = W.Selector(row, def)
    row.select:SetHeight(ROW_H)
    row.select:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    return row
end

-- The off spec rows (Tooltip.lua's Tip.OffList entries, per character), one
-- set per entry (EntryRows): a selector of its spec and setup with a remove
-- button, then what it scores with (Weights) and is compared with. Made as
-- needed, reused after, each set by Update to its entry's place in the list
-- (rows.index).

-- The entry `rows` are for.
local function Entry(rows)
    return rows.index and ns.Tooltip.OffList()[rows.index]
end

-- Adds the Weights and Compare with rows under an entry to `rows`.
local function DetailRows(rows, body)
    rows.weights = SelectRow(body, 12, L["Weights"], {
        options = function()
            local p, e = ns.GetPlayer(), Entry(rows)
            return e and WeightOptions(p.classFile, e.spec, e.setup, e.weights) or {}
        end,
        set = function(value)
            local e = Entry(rows)
            if e then e.weights = value ~= "default" and value or nil end
            SpecsChanged()
        end,
    })
    rows.compare = SelectRow(body, 12, L["Compare with"], {
        options = function()
            local e = Entry(rows)
            return CompareOptions(e and ns.Tooltip.EntryCompare(e))
        end,
        set = function(value)
            local e = Entry(rows)
            if e then e.compare = value ~= "bags" and value or nil end
            SpecsChanged()
        end,
    })
    rows.talents = SelectRow(body, 12, L["Talents"], {
        options = function() return TalentOptions(rows.index and ns.Tooltip.LinkedTalents(rows.index)) end,
        set = function(value)
            if not Entry(rows) then return end
            ns.Tooltip.LinkTalents(rows.index, value ~= "none" and value or nil)
            SpecsChanged()
        end,
    })
end

local function EntryRows(i)
    local rows = panel.entryRows[i]
    if rows then return rows end
    local body = panel.specs.body
    rows = {}
    rows.spec = W.Selector(body, {
        width = BOX_INNER - ROW_H - 4, scroller = Scroller,
        options = function()
            local p, e, out = ns.GetPlayer(), Entry(rows) or {}, {}
            for _, spec in ipairs(ns.Specs[p.classFile] or {}) do
                for _, setup in ipairs(ns.SpecSetups(p.classFile, spec)) do
                    local label = ns.Tooltip.SpecLabel(p, spec) .. " · " .. ns.WeaponSetups[setup].label
                    out[#out + 1] = { text = label, value = spec .. ":" .. setup,
                                      selected = e.spec == spec and ns.WeightProfiles.SetupKey(p.classFile, spec, e.setup) == setup }
                end
            end
            return out
        end,
        set = function(value)
            local e = Entry(rows)
            if not e then return end
            local spec, setup = value:match("^(%w+):(%w+)$")
            if e.spec ~= spec or e.setup ~= setup then e.spec, e.setup, e.weights = spec, setup, nil end
            SpecsChanged()
        end,
    })
    rows.spec:SetHeight(ROW_H)
    rows.remove = W.FlatButton(body, "", ROW_H, ROW_H)
    local cross = rows.remove:CreateTexture(nil, "OVERLAY")
    cross:SetSize(10, 10)
    cross:SetPoint("CENTER")
    cross:SetTexture("Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Close")
    cross:SetVertexColor(0.75, 0.75, 0.75)
    rows.remove:SetPoint("LEFT", rows.spec, "RIGHT", 4, 0)
    rows.remove:SetScript("OnClick", function()
        local list = ns.Tooltip.OffList()
        if Entry(rows) then table.remove(list, rows.index) end
        if #list == 0 then ns.charDB.offSpecs = nil end
        SpecsChanged()
    end)
    DetailRows(rows, body)
    panel.entryRows[i] = rows
    return rows
end

-- Adds an off spec entry (Tooltip.lua's Tip.NextEntry: your next spec not
-- listed yet, else another setup or weights of one), while there's room.
local function AddEntry()
    local e = ns.Tooltip.NextEntry(ns.GetPlayer())
    if not e then return end
    local list = ns.Tooltip.OffList()
    list[#list + 1] = e
    ns.charDB.offSpecs = list
    SpecsChanged()
end

local HEAD_H = 32 -- a folding box's header row
local BODY_GAP = 8 -- between the header row and the first control under it

-- Whether folding box `key` is open, saved for all characters where it
-- differs from how the boxes start (WildGearDB.settingsOpen[key]):
-- Filters and Display folded, Specs and Shown on open.
local OPEN_AT_FIRST = { specs = true, switches = true }
local function IsOpen(key)
    local open = ns.db.settingsOpen and ns.db.settingsOpen[key]
    if open == nil then return OPEN_AT_FIRST[key] or false end
    return open
end

local function SetOpen(key, open)
    local saved = ns.db.settingsOpen or {}
    if open == (OPEN_AT_FIRST[key] or false) then saved[key] = nil else saved[key] = open end
    ns.db.settingsOpen = next(saved) and saved or nil
end

-- Shows folding box `box` (Section) folded or open; returns its height.
local function FitSection(box)
    local open = IsOpen(box.key)
    if open then box.body:Show() else box.body:Hide() end
    box.fold.Set(open)
    box.body:SetHeight(math.max(1, box.bodyHeight))
    local height = open and (HEAD_H + BODY_GAP + box.bodyHeight + BOX_PAD) or HEAD_H
    box:SetHeight(height)
    return height
end

-- The panel as tall as its boxes, up to the window's height (at least
-- MIN_HEIGHT); past that the boxes scroll, with the bar in the right margin
-- (Classic: the game's bar is wider than that, so the panel widens to hold it).
local function Fit()
    local content, view, bar = panel.content, panel.view, panel.bar
    local y = content:GetHeight()
    -- (the window's height but where the panel docks lower and ends higher: UI.DockSides)
    local window, dock = UI.Frame(), UI.Frame().dock
    local height = math.max(1, math.min(y, math.max(window:GetHeight() - dock.top - dock.bottom, MIN_HEIGHT) - TOP - FOOT))
    view:SetHeight(height)
    panel.viewHeight = height
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
    panel:SetHeight(TOP + height + FOOT)
    local width = WIDTH + ((T.Classic() and bar:IsShown()) and W.ScrollBarWidth() + 3 or 0)
    if math.abs(panel:GetWidth() - width) > 0.5 then
        panel:SetWidth(width)
        UI.DockSides()
    end
end

-- Modern: a source's card in the Filters box, at `y` in `body`: its switch row
-- and, while the source is `on`, its own filters `subs` under it, a box row
-- first (Quest's levels), then the chips, as many to a line as fit. Returns
-- the card's height.
local CARD_PAD = 7 -- from the card's sides (the switch row's label and switch are as far in) and bottom
local CARD_GAP = 5 -- between the cards
local CARD_HEAD = 24 -- the switch row, 2 from the card's top and bottom
local CHIP_GAP = 4
local function FitCard(card, body, y, on, subs)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    local height, width = CARD_HEAD, BOX_INNER - 2 * CARD_PAD
    local line, x -- the chips' line: its top, and where its next chip goes
    for _, sub in ipairs(subs or {}) do
        sub:ClearAllPoints()
        if not on then
            sub:Hide()
        elseif sub.chip then
            local w = sub.Fit(width)
            if not line then
                line, x = height + (height > CARD_HEAD and 6 or 1), 0
            elseif x + w > width then
                line, x = line + 20 + CHIP_GAP, 0
            end
            sub:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + x, -line)
            sub:Show()
            x = x + w + CHIP_GAP
            height = line + 20
        else
            sub:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -(height + 1))
            sub:Show()
            height = height + 1 + 22
        end
    end
    if height > CARD_HEAD then height = height + CARD_PAD end
    card:SetHeight(height)
    return height
end

local function Update()
    if not (panel and panel:IsShown()) then return end
    panel.top.Update()
    panel.list.Update(ns.db.allSources and "all" or "source")
    panel.armor.Update(ns.db.classArmorOnly and "class" or "all")
    -- The sources, each with its own filters while it's on: Quest's levels
    -- above yours and its dungeon quests, Crafted's professions, BoE's
    -- qualities and the dungeons' own. Modern: each source on a card of its
    -- own, its filters in it (FitCard). Classic: a row each, its filters
    -- indented under it (the box row a little apart from the switches).
    panel.above.select.Update()
    for _, key in ipairs({ "questDungeon", "boeRare", "boeEpic", "boeDungeon" }) do panel[key].Update(ns.db[key] ~= false) end
    local p = ns.GetPlayer()
    for _, row in ipairs(panel.professions) do row.Update(ns.HasProfession(p, row.prof.id)) end
    local body, y = panel.filters.body, panel.sourcesTop
    for _, t in ipairs(ns.SourceTypes) do
        local on, row = ns.SourceOn(t), panel.sources[t]
        row.Update(on)
        if row.card then
            y = y + FitCard(row.card, body, y, on, panel.under[t]) + CARD_GAP
        else
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", body, "TOPLEFT", -4, -y)
            y = y + 22
            for _, sub in ipairs(panel.under[t] or {}) do
                sub:ClearAllPoints()
                if not on then
                    sub:Hide()
                elseif sub.toggle then
                    sub:SetPoint("TOPLEFT", body, "TOPLEFT", -4 + 12, -y)
                    sub:Show()
                    y = y + 22
                else
                    sub:SetPoint("TOPLEFT", body, "TOPLEFT", 12, -(y + 1))
                    sub:Show()
                    y = y + (sub.step or 26)
                end
            end
        end
    end
    panel.filters.bodyHeight = y - (T.Classic() and 2 or CARD_GAP)
    panel.theme.Update()
    panel.scale.Update()
    panel.wishScale.Update()
    panel.opacity.Update()
    if panel.accent then panel.accent.Update(T.Get("accent")) end
    if panel.font then panel.font.Update(T.Get("font")) end
    panel.textSize.Update(T.Get("textSize"))

    -- Specs: the main one, what it scores with and is compared with, then
    -- each off spec entry the same way, greyed out while it doesn't score
    -- (the same line as the main spec's or an earlier one's), and Add off
    -- spec while there's room for another.
    -- With dual talent, each line has its Talents row too.
    panel.main.Update()
    panel.mainWeights.select.Update()
    panel.mainCompare.select.Update()
    local body = panel.specs.body
    local p = ns.GetPlayer()
    local dual = ns.Tooltip.TalentSets() > 1
    local y = panel.mainTop
    if dual then
        panel.mainTalents:ClearAllPoints()
        panel.mainTalents:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 4))
        panel.mainTalents.select.Update()
        panel.mainTalents:Show()
        y = y + 4 + ROW_H
    else
        panel.mainTalents:Hide()
    end
    panel.offLabel:ClearAllPoints()
    panel.offLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 1, -(y + 10))
    local list, skipped = ns.Tooltip.OffList(), ns.Tooltip.Skipped(p)
    y = y + 26
    for i = 1, #list do
        local rows = EntryRows(i)
        rows.index = i
        y = y + 2
        rows.spec:ClearAllPoints()
        rows.spec:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        rows.spec.Update()
        rows.spec:Show()
        rows.remove:Show()
        y = y + ROW_H + 4
        for _, row in ipairs({ rows.weights, rows.compare, dual and rows.talents or nil }) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            row.select.Update()
            row:Show()
            y = y + ROW_H + 4
        end
        if not dual then rows.talents:Hide() end
        -- (the remove button and the link stay lit: a swap still makes it the main spec)
        local alpha = skipped[i] and 0.4 or 1
        for _, part in ipairs({ rows.spec, rows.weights, rows.compare }) do part:SetAlpha(alpha) end
        y = y + 4
    end
    for i = #list + 1, #panel.entryRows do
        local rows = panel.entryRows[i]
        rows.index = nil
        for _, part in ipairs({ rows.spec, rows.remove, rows.weights, rows.compare, rows.talents }) do part:Hide() end
    end
    y = y + 2
    panel.addOff:ClearAllPoints()
    panel.addOff:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    if ns.Tooltip.NextEntry(p) then
        panel.addOff:Show()
        y = y + 22
    else
        panel.addOff:Hide()
        y = y - 4
    end
    panel.specs.bodyHeight = y

    -- The switches; the off-spec suggestions' only while quest rewards are marked.
    local quests = ns.db.questMarks ~= false
    panel.tooltips.Update(ns.db.tooltip ~= false)
    panel.bags.Update(ns.db.bagMarks ~= false)
    panel.character.Update(ns.db.characterPanel ~= false)
    panel.wish.Update(ns.db.wishTracker ~= false)
    panel.quests.Update(quests)
    panel.questOff.Update(ns.db.questOffSpec ~= false)
    if quests then panel.questOff:Show() else panel.questOff:Hide() end
    panel.switches.bodyHeight = (quests and 6 or 5) * 22 - 2

    local height = 0
    for i, box in ipairs(panel.boxes) do
        if i > 1 then height = height + GAP end
        box.y = height
        box.height = FitSection(box)
        height = height + box.height
    end
    panel.content:SetHeight(height)
    Fit()
end

-- Scrolls a box just opened into view, when it ends below the panel's
-- bottom: up to its end, but not past its header.
local function ScrollTo(box)
    local bar = panel.bar
    if not bar:IsShown() then return end
    local value = bar:GetValue() or 0
    if box.y + box.height > value + panel.viewHeight then value = box.y + box.height - panel.viewHeight end
    bar:SetValue(math.min(value, box.y))
end

-- A box of settings that folds: a header row with its title on the left and,
-- in line with the selectors' chevrons, the window's fold sign (a plus while
-- folded, a minus while open). A click on the header folds or unfolds it,
-- saved for all characters (IsOpen). `build(body)` makes the
-- controls in `body`, the box's inside, and returns their height (or 0 for
-- Update to set box.bodyHeight, when it changes).
local function Section(key, title, build)
    local box = CreateFrame("Frame", nil, panel.content, "BackdropTemplate")
    W.Box(box)
    box:SetWidth(INNER)
    box.key = key
    local head = CreateFrame("Button", nil, box)
    head:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -1)
    head:SetHeight(HEAD_H - 2)
    W.AddHighlight(head)
    -- Modern: the title row on a band a step lighter than the box, so each
    -- box's title stands apart from its controls.
    if not T.Classic() then -- (on the box, flush with its edges, under the header's hover light)
        local band = box:CreateTexture(nil, "ARTWORK", nil, -8)
        band:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        band:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0)
        band:SetHeight(HEAD_H)
        band:SetColorTexture(1, 1, 1, 0.05)
    end
    head.text = head:CreateFontString(nil, "OVERLAY",
        T.Classic() and "WildGearFontNormal" or "WildGearFontHighlightSmall")
    head.text:SetPoint("LEFT", head, "LEFT", BOX_PAD - 1, 0)
    head.text:SetText(title)
    box.fold = W.FoldSign(head)
    box.fold:SetPoint("CENTER", head, "RIGHT", -(BOX_PAD + 10), 0)
    head:SetScript("OnClick", function()
        W.HidePopup() -- (a selector's list, maybe in the box that folds)
        local opening = not IsOpen(key)
        SetOpen(key, opening)
        Update()
        if opening then ScrollTo(box) end
    end)
    box.head = head
    box.body = CreateFrame("Frame", nil, box)
    box.body:SetPoint("TOPLEFT", box, "TOPLEFT", BOX_PAD, -(HEAD_H + BODY_GAP))
    box.body:SetWidth(BOX_INNER)
    box.bodyHeight = build(box.body)
    box.body:SetHeight(math.max(1, box.bodyHeight))
    return box
end

local function Create()
    panel = CreateFrame("Frame", nil, UI.Frame(), "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true) -- placed by UI.DockSides
    W.Window(panel)
    panel:EnableMouse(true)

    local title, band = W.TitleBand(panel, L["Settings"], "WildGearFontNormal")
    W.PanelIcon(title, band, "Settings") -- (Modern: a cog before the title)

    -- The boxes, in a frame that scrolls when they don't fit (Fit): with the
    -- mouse wheel, or the bar in the right margin.
    local view = CreateFrame("ScrollFrame", nil, panel)
    view:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -TOP)
    view:SetSize(INNER, 1)
    local content = CreateFrame("Frame", nil, view)
    content:SetSize(INNER, 1)
    view:SetScrollChild(content)
    local bar = W.ScrollBar(panel)
    bar:SetPoint("TOPLEFT", view, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", view, "BOTTOMRIGHT", 4, 0)
    bar:SetScript("OnValueChanged", function(_, value) view:SetVerticalScroll(value) end)
    bar:Hide()
    for _, f in ipairs({ view, bar }) do
        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    end
    panel.view, panel.content, panel.bar = view, content, bar

    -- A grey label (Classic: gold) at `y` in `parent`; returns the y under it.
    local function Label(parent, text, y)
        local fs = parent:CreateFontString(nil, "OVERLAY", W.LabelFont())
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -y)
        fs:SetText(text)
        return y + 16
    end
    local pair = (BOX_INNER - 2) / 2 -- (a choice of two)

    -- Filters: how many items each source lists on Best in slot, for armor
    -- purists armor lighter than the class's own type hidden on every tab, and
    -- which sources count (quests, dungeons, crafting, BoE), with under Quest
    -- (while it's on) how far above your level a quest may be, under Crafted
    -- your professions, and under BoE blue and purple ones and the dungeons'
    -- own (all placed by Update).
    panel.filters = Section("filters", L["Filters"], function(body)
        local modern = not T.Classic()
        local y
        if modern then -- (on one line: its label, then the box on the right, as Quest's levels)
            topDef.label, topDef.width = nil, ABOVE_W
            local row = CreateFrame("Frame", nil, body)
            row:SetSize(BOX_INNER, 22)
            row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
            local label = row:CreateFontString(nil, "OVERLAY", W.LabelFont())
            label:SetPoint("LEFT", row, "LEFT", 1, 0)
            label:SetText(L["Show top"])
            panel.top = W.Selector(row, topDef)
            panel.top:SetHeight(22)
            panel.top:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            y = Label(body, L["List"], 22 + 12)
        else
            panel.top = W.Selector(body, topDef)
            panel.top:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
            y = Label(body, L["List"], 40 + 12)
        end
        panel.list = W.Segmented(body, nil, {
            { key = "source", text = L["By source"] },
            { key = "all", text = L["All sources"] },
        }, pair, function(key)
            ns.db.allSources = key == "all" or nil
            UI.Refresh()
            Update()
        end, true)
        panel.list:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = Label(body, L["Armor type"], y + 20 + 12)
        panel.armor = W.Segmented(body, nil, {
            { key = "class", text = L["Class type"], tip = L["Only your class's own armor type, nothing lighter, on "
                .. "every tab: e.g. a warrior sees mail before level 40 and plate from 40. Cloaks, jewelry, shields "
                .. "and relics are unaffected."] },
            { key = "all", text = L["All types"] },
        }, pair, function(key)
            ns.db.classArmorOnly = key == "class" or nil
            UI.Refresh()
            Update()
        end, true)
        panel.armor:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        panel.sourcesTop = Label(body, L["Sources"], y + 20 + 12)
        local function Changed()
            ns.QuestWindow.Refresh()
            UI.Refresh() -- (the window's lists, item tooltips, bag arrows and this panel)
        end
        -- (on by default: ns.db[key] = false when off)
        local function Flip(key)
            return function()
                if ns.db[key] == false then ns.db[key] = nil else ns.db[key] = false end
                Changed()
            end
        end
        -- A switch per source. Modern: each on a card of its own, which holds
        -- the source's own filters too (placed by Update: FitCard).
        panel.sources = {}
        for _, t in ipairs(ns.SourceTypes) do
            local row
            if modern then
                local card = CreateFrame("Frame", nil, body)
                card:SetSize(BOX_INNER, CARD_HEAD)
                local fill = card:CreateTexture(nil, "BACKGROUND")
                fill:SetAllPoints()
                fill:SetColorTexture(T.CARD[1], T.CARD[2], T.CARD[3], T.CARD[4])
                row = W.ToggleRow(card, BOX_INNER - 6, Flip(t))
                row:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -2)
                row.card = card
            else
                row = W.ToggleRow(body, BOX_INNER + 8, Flip(t))
            end
            row.label:SetText(ns.SourceLabels[t])
            panel.sources[t] = row
        end
        -- One of source `t`'s own filters, on or off. Modern: a chip in the
        -- source's card. Classic: a switch row, indented under the source's.
        local function Option(t, label, onClick)
            local o
            if modern then
                o = W.Chip(panel.sources[t].card, onClick)
            else
                o = W.ToggleRow(body, BOX_INNER + 8 - 12, onClick)
            end
            o.label:SetText(label)
            return o
        end

        -- Under Quest: its label and, on the right, the levels box (No limit its last choice).
        local holder = modern and panel.sources.quest.card or body
        local above = CreateFrame("Frame", nil, holder)
        above:SetSize(modern and BOX_INNER - 2 * CARD_PAD or BOX_INNER - 12, 22)
        local label = above:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
        label:SetPoint("LEFT", above, "LEFT", 1, 0)
        label:SetPoint("RIGHT", above, "RIGHT", -(ABOVE_W + 6), 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(L["Above your level"])
        above:EnableMouse(true)
        above:SetScript("OnEnter", function(self) W.ShowBubble(self, AboveTip(), { pointAt = label }) end)
        above:SetScript("OnLeave", W.HideBubble)
        above.select = W.Selector(above, aboveDef)
        above.select:SetHeight(22)
        above.select:SetPoint("RIGHT", above, "RIGHT", 0, 0)
        panel.above = above
        panel.questDungeon = Option("quest", L["Dungeon quests"], Flip("questDungeon"))

        panel.boeRare = Option("boe", ns.QualityHex(3) .. L["Rare"] .. "|r", Flip("boeRare"))
        panel.boeEpic = Option("boe", ns.QualityHex(4) .. L["Epic"] .. "|r", Flip("boeEpic"))
        panel.boeDungeon = Option("boe", L["Dungeon drops"], Flip("boeDungeon"))
        -- Under Crafted: your professions, each on or off.
        panel.professions = {}
        local crafted = {}
        for _, prof in ipairs(ns.Patterns or {}) do
            local row = Option("crafted", L[prof.name], function(self)
                ns.ToggleProfession(ns.GetPlayer(), self.prof.id)
                Changed()
            end)
            row.prof = prof
            panel.professions[#panel.professions + 1] = row
            crafted[#crafted + 1] = row
        end
        panel.under = { quest = { above, panel.questDungeon }, crafted = crafted,
                        boe = { panel.boeRare, panel.boeEpic, panel.boeDungeon } }
        return 0
    end)
    panel.filters:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    -- Display: the window's look (Theme.lua). First the theme, Modern, Classic
    -- (the game's own frame art) or a skin (Classic in a place's own art), in
    -- a list, which takes a reload: picking another one than this session's
    -- asks, under the list, to reload now (so the mouse wheel doesn't step
    -- through it).
    -- The Classic theme's frames are the game's solid art and what it marks
    -- is in the game's gold (or the skin's color), so it has no Background or
    -- Accent color.
    panel.display = Section("display", L["Display"], function(body)
        panel.theme = W.Selector(body, {
            label = L["Theme"], width = BOX_INNER, scroller = Scroller, step = function() end,
            -- (each with its icon: Modern the addon's emblem, Classic its
            -- obsidian one, a skin skin.icon or its own emblem (its season's
            -- while that shows, for the skin in use); in the list
            -- W.ShowPopup's, in the box 18 across before the name)
            options = function()
                local theme = T.Get("theme")
                local list = {}
                local function Add(value, name, icon, crop)
                    local short = name
                    if icon then
                        short = "|T" .. icon .. (crop and ":18:18:0:0:64:64:5:59:5:59|t " or ":18:18|t ") .. name
                    end
                    list[#list + 1] = { text = name, short = short, value = value, selected = theme == value,
                                        icon = icon, crop = crop }
                end
                Add("modern", L["Modern"], "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Icon")
                Add("classic", L["Classic"], "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Classic\\EmblemSmall")
                for _, skin in ipairs(T.Skins()) do
                    local icon = skin.icon or (skin.emblem and (skin.emblem.small or skin.emblem.file))
                    if not skin.icon and skin.emblem and skin.key == T.Theme() then icon = T.Emblem() end
                    Add(skin.key, skin.name, icon)
                end
                return list
            end,
            set = function(key)
                T.Set("theme", key)
                panel.theme.Update()
                if key ~= T.Theme() then
                    W.Confirm(panel.theme, L["Reload the interface to switch to this theme?"], L["Reload"],
                        L["Not now"], function()
                            ns.db.reopenSettings = true -- (back here after the reload: the end of this file)
                        end, "/reload") -- (ReloadUI from the addon is blocked: a secure button runs it)
                else
                    W.HideConfirm()
                end
            end,
        })
        panel.theme:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
        T.OnSeason(function() panel.theme.Update() end) -- (the skin in use: its season's emblem or its own)
        local y = 40 + 12
        panel.scale = PercentSelector(body, "scale", L["Scale"], 0.7, 1.5, 0.05)
        panel.scale:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        panel.opacity = PercentSelector(body, "opacity", L["Background"], 0.5, 1, 0.05)
        panel.opacity:SetPoint("TOPLEFT", panel.scale, "TOPRIGHT", 10, 0)
        if T.Classic() then -- (Scale alone, across the row)
            panel.opacity:Hide()
            panel.scale:SetWidth(BOX_INNER)
        end
        y = y + 40 + 12
        -- (the wish list's tracker, on its own: WishList.lua)
        panel.wishScale = PercentSelector(body, "wishScale", L["Wish list size"], 0.8, 2, 0.1)
        panel.wishScale:SetWidth(BOX_INNER)
        panel.wishScale:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + 40 + 12
        if not T.Classic() then
            y = Label(body, L["Accent color"], y)
            panel.accent = W.Segmented(body, nil, {
                { key = "gold", text = L["Gold"] },
                { key = "class", text = L["Class color"] },
            }, pair, function(key) T.Set("accent", key) end, true)
            panel.accent:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            y = y + 20 + 12
        end

        -- With a UI addon that has a font of its own: that font (the default),
        -- or the game's (Theme.lua). On hover: the font's name (and the
        -- addon's), then what the choice is.
        if T.HasUIFont() then
            local function FontTip(note, name, from)
                local head = name and (name .. (from and ("  |cff999999" .. from .. "|r") or "") .. "\n") or ""
                return head .. "|cff999999" .. note .. "|r"
            end
            y = Label(body, L["Font"], y)
            panel.font = W.Segmented(body, nil, {
                { key = "ui", text = L["UI font"],
                  tip = function() return FontTip(L["The font your UI addon uses. Changes with it."], T.UIFontName()) end },
                { key = "game", text = L["Blizzard font"],
                  tip = function() return FontTip(L["The font the game's own interface uses."], T.GameFontName()) end },
            }, pair, function(key) T.Set("font", key) end, true)
            panel.font:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            y = y + 20 + 12
        end

        y = Label(body, L["Text size"], y)
        local sizes = {
            { key = -2, text = L["Smaller"] }, { key = -1, text = L["Small"] },
            { key = 0, text = L["Normal"] }, { key = 1, text = L["Large"] },
        }
        panel.textSize = W.Segmented(body, nil, sizes, (BOX_INNER - 6) / 4, function(key) T.Set("textSize", key) end,
            true)
        panel.textSize:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        return y + 20
    end)
    panel.display:SetPoint("TOPLEFT", panel.filters, "BOTTOMLEFT", 0, -GAP)

    -- Your specs: the main spec and its setup, what it scores with and is
    -- compared with, then the off specs in the same shape (rows laid out by
    -- Update). Item tooltips and quest rewards both go by them.
    panel.specs = Section("specs", L["Specs"], function(body)
        local y = 0
        panel.main = W.Selector(body, mainDef)
        panel.main:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + 40 + 6
        -- (the main spec's weights: the profile picked for it and its weapon
        -- setup, as the Stat weights panel picks; indented as an off spec's)
        panel.mainWeights = SelectRow(body, 12, L["Weights"], {
            options = function()
                local p = ns.GetPlayer()
                local setup = ns.GetWeaponSetupPref(p)
                return WeightOptions(p.classFile, p.spec, setup, ns.WeightProfiles.PickedId(p.classFile, p.spec, setup))
            end,
            set = function(value)
                local p = ns.GetPlayer()
                ns.WeightProfiles.Pick(p.classFile, p.spec, ns.GetWeaponSetupPref(p), value ~= "default" and value or nil)
                SpecsChanged()
            end,
        })
        panel.mainWeights:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        y = y + ROW_H + 4
        panel.mainCompare = SelectRow(body, 12, L["Compare with"], {
            options = function()
                local p = ns.GetPlayer()
                return CompareOptions(ns.Tooltip.Compare(p.spec))
            end,
            set = function(value)
                local p = ns.GetPlayer()
                ns.charDB.compare = ns.charDB.compare or {}
                ns.charDB.compare[p.spec] = value
                SpecsChanged() -- (this panel, and My gear's note on your main spec's set)
            end,
        })
        panel.mainCompare:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        -- (the Talents row, with dual talent, and Off specs under it: laid out by Update)
        panel.mainTop = y + ROW_H
        panel.mainTalents = SelectRow(body, 12, L["Talents"], {
            options = function() return TalentOptions(ns.Tooltip.LinkedTalents()) end,
            set = function(value)
                ns.Tooltip.LinkTalents(nil, value ~= "none" and value or nil)
                SpecsChanged()
            end,
        })
        panel.offLabel = body:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
        panel.offLabel:SetText(L["Off specs"])
        panel.entryRows = {}
        panel.addOff = W.FitButton(W.FlatButton(body, L["Add off spec"], 100, 22))
        panel.addOff:SetScript("OnClick", AddEntry)
        panel.addOff:SetScript("OnEnter", function(self) W.ShowBubble(self, OFF_TIP, { width = 260 }) end)
        panel.addOff:SetScript("OnLeave", function() W.HideBubble() end)
        return 0
    end)
    panel.specs:SetPoint("TOPLEFT", panel.display, "BOTTOMLEFT", 0, -GAP)

    -- Shown on, switches for what uses them: item tooltips everywhere in the
    -- game (Tooltip.lua), the upgrade arrows on bag items (BagMarks.lua), My
    -- gear beside the Character frame (CharacterPanel.lua), the minimap
    -- button (Minimap.lua), the wish list's tracker (WishList.lua), the marks on
    -- quest rewards (QuestWindow.lua), and under the latter, indented and
    -- shown while it's on, its off-spec suggestions.
    panel.switches = Section("switches", L["Shown on"], function(body)
        local function Switch(key, label, row, indent, tip)
            local s = W.ToggleRow(body, BOX_INNER + 8 - indent, function()
                if ns.db[key] == false then ns.db[key] = nil else ns.db[key] = false end
                ns.QuestWindow.Refresh()
                ns.BagMarks.Refresh()
                ns.CharacterPanel.Refresh()
                ns.WishList.Refresh()
                Update()
            end, tip)
            s.label:SetText(label)
            s:SetPoint("TOPLEFT", body, "TOPLEFT", -4 + indent, -((row - 1) * 22))
            return s
        end
        panel.tooltips = Switch("tooltip", L["Item tooltips"], 1, 0)
        panel.bags = Switch("bagMarks", L["Bag upgrades"], 2, 0)
        panel.character = Switch("characterPanel", L["Character Info"], 3, 0)
        panel.wish = Switch("wishTracker", L["Wish list"], 4, 0)
        panel.quests = Switch("questMarks", L["Quest rewards"], 5, 0)
        panel.questOff = Switch("questOffSpec", L["Off-spec upgrades"], 6, 12,
            L["When no reward is an upgrade for your main spec, suggests one for your off specs, "
                .. "each against the gear it is compared with."])
        return 0
    end)
    panel.switches:SetPoint("TOPLEFT", panel.specs, "BOTTOMLEFT", 0, -GAP)
    panel.boxes = { panel.filters, panel.display, panel.specs, panel.switches }

    local half = (INNER - 6) / 2
    local position = W.FlatButton(panel, L["Reset position"], half, 22)
    position:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
    position:SetScript("OnClick", function() UI.ResetPosition() end)
    local reset = W.FlatButton(panel, L["Reset to defaults"], half, 22)
    reset:SetPoint("LEFT", position, "RIGHT", 6, 0)
    reset:SetScript("OnClick", function()
        ns.db.topN, ns.db.classArmorOnly, ns.db.tooltip, ns.charDB.offSpecs = nil, nil, nil, nil
        ns.db.allSources = nil
        for _, t in ipairs(ns.SourceTypes) do ns.db[t] = nil end
        ns.db.boeRare, ns.db.boeEpic, ns.db.boeDungeon = nil, nil, nil
        ns.db.questAbove, ns.db.questAnyLevel, ns.db.questDungeon = nil, nil, nil
        ns.db.questMarks, ns.db.questOffSpec, ns.db.bagMarks, ns.charDB.compare = nil, nil, nil, nil
        ns.db.characterPanel, ns.charDB.professions, ns.db.minimapButton = nil, nil, nil
        ns.db.wishTracker, ns.charDB.mainTalents = nil, nil
        T.Reset()
        ns.QuestWindow.Refresh()
        UI.Refresh() -- (the window's lists, this panel, My gear's set note)
    end)
    -- Half each, unless one's text needs more and the other's leaves it room.
    T.Track(function()
        local font = "WildGearFontHighlightSmall"
        local need = W.TextWidth(font, { L["Reset position"] }) + 16
        local other = W.TextWidth(font, { L["Reset to defaults"] }) + 16
        local width = half
        if need > half and other <= half then
            width = math.min(need, INNER - 6 - other)
        elseif other > half and need <= half then
            width = math.max(need, INNER - 6 - other)
        end
        position:SetWidth(width)
        reset:SetWidth(INNER - 6 - width)
    end)

    panel:SetScript("OnShow", function(self)
        UI.ClaimSide(self)
        Update()
    end)
    -- (The window's height changes with its tab and Show top, after UI.Refresh has updated this panel.)
    UI.Frame():HookScript("OnSizeChanged", function()
        if panel:IsShown() then Fit() end
    end)
    panel:Hide()
    T.Track(Update)
end

S.Update = Update -- (UI.Refresh: the main spec may have changed)

-- The panel, made with the window (its Settings button stays lit while the panel is open).
function S.Panel()
    if not panel then Create() end
    return panel
end

function S.Toggle()
    if not UI.Frame() then return end
    if not panel then Create() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- Opens the window if needed, then the panel; with `section` (a folding
-- box's key: "filters", "display", "specs", "switches"), that box open;
-- `only`: the others folded.
function S.Show(section, only)
    if not (UI.Frame() and UI.Frame():IsShown()) then UI.Toggle() end
    if not panel then Create() end
    if section then SetOpen(section, true) end
    if section and only then
        for _, box in ipairs(panel.boxes) do
            if box.key ~= section then SetOpen(box.key, false) end
        end
    end
    if panel:IsShown() then Update() else panel:Show() end
    for _, box in ipairs(panel.boxes) do
        if box.key == section then ScrollTo(box) end
    end
end

-- Opens the panel on its Display box, the others folded, and its Theme list
-- with theme `key` lit (What's new's Try it now). A frame on, once the box
-- has opened and scrolled into view, so the list drops from where its box is.
function S.ShowTheme(key)
    S.Show("display", true)
    C_Timer.After(0, function()
        if panel and panel:IsShown() and panel.theme then panel.theme.OpenList(key) end
    end)
end

-- After the reload a theme change asked for (Display: Theme), the window
-- opens again on this panel's Display box: on the next frame after login, once
-- the other files have set up the character.
local reopen = CreateFrame("Frame")
reopen:RegisterEvent("PLAYER_LOGIN")
reopen:SetScript("OnEvent", function()
    if not ns.db.reopenSettings then return end
    ns.db.reopenSettings = nil
    C_Timer.After(0, function() S.Show("display") end)
end)
