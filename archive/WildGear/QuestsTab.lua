local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The main window's Quests tab: quest gear rewards by zone. On the left a
-- region switch (Eastern Kingdoms / Kalimdor), the region's zones, each with
-- its upgrade count and the game's icon for its kind (All zones first, then
-- Zephras Isle for Skyborne, the capital cities under a rule, then under
-- another the dungeons and raids, with the quests filed under them) and,
-- pinned to the column's bottom, the
-- filters: the quest level range, the quest types (Raid off at first) and
-- Hide completed. On the right, in the loot list (UI.List), the zone in two
-- views: Summary (its upgrades per slot, the quests that give them in level
-- order, look-ahead upgrades) and Quests (each gear quest the filters let
-- through, its rewards ranked, the best pick of its choices tinted).
-- What counts as an upgrade is the rankings' own, Settings' Above your level
-- included. The level range only picks which other quests are listed: a quest
-- with an upgrade now is listed whatever its level, and its zone shows. The
-- types and Hide completed decide what counts too (Raid off: raid quests
-- don't count). Zones whose quests none of the filters let through are hidden.

local UI, W, T, L = ns.UI, ns.Widgets, ns.Theme, ns.L
local Q = {}
ns.QuestsTab = Q

local ZEPHRAS = 16593 -- Zephras Isle, the Skyborne's own
local SKYBORNE = { [95] = true, [96] = true }
local REGION_MAP = { [0] = 1415, [1] = 1414 } -- UiMap ids: Eastern Kingdoms, Kalimdor (their names)
local REGION_NAME = { [0] = L["Eastern Kingdoms"], [1] = L["Kalimdor"] }
-- Where a character starts out: Night Elves in Kalimdor, the Forsaken in the
-- Eastern Kingdoms, else their faction's lands.
local HOME_REGION = { [4] = 1, [5] = 0 }
local FACTION_REGION = { Alliance = 0, Horde = 1 }
local TYPES = {
    { key = "solo", text = L["Solo"] }, { key = "elite", text = L["Elite"] },
    { key = "dungeon", text = L["Dungeon"] }, { key = "raid", text = L["Raid"] },
}
local TYPE_ON = { solo = true, elite = true, dungeon = true, raid = false } -- at first
local RANGE_BELOW = 8 -- the level range starts this far below the profile's level at first
local PAD = 8 -- in from the filters box's border
local ROW = 20 -- a filter row (chips, switches)
local GAP = 3 -- between chips
-- A quest's line: its rewards' icons, then the reward it shows and its gain,
-- in columns from the right edge.
local ICON, ICON_GAP, MAX_ICONS = 18, 3, 6
local TOP_NAME_W, TOP_GAIN_W = 150, 46
local DETAIL_X = 16 -- an open quest's giver line, in from the left (under the quest's name)
-- Before each zone's name, the game's icon for its kind (client atlases): a
-- pine for a zone, the world map's city tower, the quest log's dungeon and raid swirls.
local KIND_ICON = { zone = "Front-Tree-Icon", city = "poi-majorcity",
                    dungeon = "questlog-questtypeicon-dungeon", raid = "questlog-questtypeicon-raid" }
local KIND_ICON_SIZE = 14

local panel, region, list, filters
local rules = {} -- [kind] = the rule above the list's first city ("city") and first dungeon or raid ("instance")
local zoneButtons = {} -- [zone id] = list button
local selected, selectedAt -- the zone shown (an ns.Zones id or "all"), and the profile level it was picked at
local showOther, showBare = false, false -- Quests view: the other faction's quests, your quests without gear for you
local openQuest, scrollToOpen -- Quests view: the quest opened (one at a time), and whether to bring it into view
local index -- the gear quests (Index)
local zoneById

local function Lib() return UI.List end

-- A ns.Zones entry's kind: "zone", "city", "dungeon" or "raid".
local function ZoneKind(z)
    return (z.city and "city") or (z.dungeon and "dungeon") or (z.raid and "raid") or "zone"
end

---------------------------------------------------------------- data

-- The gear quests, built once: { id, q, gear = {itemId...}, type }.
local function QuestType(q)
    local t = q.type
    return (t == "Raid" and "raid") or (t == "Dungeon" and "dungeon") or ((t == "Elite" or t == "Group") and "elite")
        or "solo"
end

local function Index()
    if index then return index end
    index, zoneById = {}, {}
    for _, z in ipairs(ns.Zones or {}) do zoneById[z.id] = z end
    for id, q in pairs(ns.Quests or {}) do
        local r, gear = q.rewards, {}
        for _, key in ipairs({ "choices", "items" }) do
            for _, item in ipairs(r and r[key] or {}) do
                if ns.Items[item] and ns.Items[item].slot then gear[#gear + 1] = item end
            end
        end
        if #gear > 0 then index[#index + 1] = { id = id, q = q, gear = gear, type = QuestType(q) } end
    end
    table.sort(index, function(a, b)
        local la, lb = a.q.level or 0, b.q.level or 0
        if la ~= lb then return la < lb end
        return (a.q.name or "") < (b.q.name or "")
    end)
    return index
end

-- The zone (ns.Zones id) a quest is listed under: the one the game's quest log
-- files it under (q.zoneId; a dungeon or raid has its own row), else where its
-- giver is for the profile's faction; for a giver inside a dungeon or raid
-- without a row, the zone of its entrance. Nil when unknown or not in the list.
local function ZoneOf(q, p)
    local start = (p.faction == "Horde" and q.startHorde) or q.start
    local z = q.zoneId or (start and start.zoneId)
    if z and not zoneById[z] then z = ns.InstanceZones and ns.InstanceZones[z] end
    return z and zoneById[z] and z or nil
end

-- The quest as an item source, for the loot list's quest hovers and Pin giver.
local function Source(e, zone)
    local q = e.q
    return { type = "quest", id = e.id, name = q.name, level = q.level, reqLevel = q.reqLevel, side = q.side,
             minLevel = q.minLevel, zoneId = zone }
end

local function TypeOn(key)
    local saved = ns.db.questTypes and ns.db.questTypes[key]
    if saved == nil then return TYPE_ON[key] end
    return saved
end

local function HideDone()
    return ns.db.questShowDone ~= true
end

local function ZoneName(z)
    return ns.ZoneName(z.id) or z.name
end

local function RegionName(r)
    local info = ns.translated and C_Map and C_Map.GetMapInfo and REGION_MAP[r] and C_Map.GetMapInfo(REGION_MAP[r])
    return (info and info.name and info.name ~= "" and info.name) or REGION_NAME[r]
end

local function Region(p)
    local saved = ns.charDB.questRegion
    if saved == 0 or saved == 1 then return saved end
    return HOME_REGION[p.raceId] or FACTION_REGION[p.faction] or 0
end

-- The quest level range: picked on the slider for the profile's level, else
-- from RANGE_BELOW under it to the highest quest that can count (Settings'
-- Above your level, plus Look ahead).
local function AutoRange(p)
    local top = ns.db.questAnyLevel and ns.MAX_LEVEL or (p.level + ns.QuestAbove() + (ns.charDB.ahead or 0))
    return math.max(1, p.level - RANGE_BELOW), math.min(ns.MAX_LEVEL, top)
end

local function Range(p)
    local saved = ns.charDB.questLevels
    if saved and saved.level == p.level then return saved[1], saved[2] end
    return AutoRange(p)
end

-- Which of quest entry `x`'s rewards the profile would take (r.take): every
-- upgrade it gives, but of its choices only the best one (the biggest gain,
-- else the best rank), and so whether it is an upgrade; r.best marks that
-- choice. x.top is the reward its line shows: the biggest upgrade taken, else
-- the first look-ahead one (by level).
local function Picks(x)
    local choices = x.q.rewards and x.q.rewards.choices
    local best
    for _, r in ipairs(x.rows) do
        r.choice = choices and Lib().Contains(choices, r.item)
        if r.choice and r.info and not r.info.upcoming then
            local k = r.gain or -r.info.rank
            if not best or k > best.k then best = { r = r, k = k } end
        end
    end
    for _, r in ipairs(x.rows) do
        r.best = best ~= nil and best.r == r and #choices > 1
        r.take = r.up and (not r.choice or best.r == r)
        local top = x.top
        if r.take and (not top or not top.take or (r.gain or 0) > (top.gain or 0)) then
            x.top = r
        elseif not (top and top.take) and r.info and r.info.upcoming and x.open
            and (not top or r.info.entry.level < top.info.entry.level) then
            x.top = r
        end
    end
end

-- Everything the tab shows for the profile, from the rank map `map`:
-- { [zone id] = {x...} } of the gear quests per zone, each entry x = the
-- index entry plus zone, open (to the profile's faction, class and race),
-- state (ns.QuestState), rows = { {item, info, gain, up, take, best}... }, top
-- (Picks), and up, later (an upgrade now / a look-ahead one among them).
local function Build(p, map)
    local V = Lib().Verdict
    local byZone = {}
    for _, e in ipairs(Index()) do
        local zone = ZoneOf(e.q, p)
        if zone then
            local x = { id = e.id, q = e.q, gear = e.gear, type = e.type, zone = zone, rows = {},
                        open = ns.QuestOpen(e.q, p), state = ns.QuestState(e.id) }
            x.source = Source(e, zone)
            for _, item in ipairs(e.gear) do
                local info = map[item]
                local gain, up = V(info)
                x.rows[#x.rows + 1] = { item = item, info = info, gain = gain, up = up and x.open }
                if up and x.open then x.up = true end
                if info and info.upcoming and x.open then x.later = true end
            end
            Picks(x)
            byZone[zone] = byZone[zone] or {}
            table.insert(byZone[zone], x)
        end
    end
    return byZone
end

-- Whether quest entry `x` counts for the zone's upgrades and the summary:
-- open to the profile, its type on, and not completed.
local function Counts(x)
    return x.open and TypeOn(x.type) and x.state ~= "done"
end

-- Whether `x` is listed: its type on, completed only without Hide completed,
-- and in the level range, or giving an upgrade now.
local function Listed(x, lo, hi)
    if not TypeOn(x.type) or (x.state == "done" and HideDone()) then return false end
    local level = x.q.level or 0
    return (level >= lo and level <= hi) or (x.up and x.state ~= "done")
end

-- The quests' upgrades, as the Dungeon loot summary has them: { now = {pick...}
-- (one per slot, the slot's others in pick.alts, a quest's best choice only),
-- later = {pick...} (look-ahead, by level), quests = {x...} (those giving the
-- slots' picks, in level order) }; pick = { id, info, gain, quest (source), x }.
local function Summarize(quests)
    local lib = Lib()
    local picks, later, seen = {}, {}, {}
    for _, x in ipairs(quests) do
        if Counts(x) then
            for _, r in ipairs(x.rows) do
                if r.info and not seen[r.item] then
                    seen[r.item] = true
                    local pick = { id = r.item, info = r.info, gain = r.gain, quest = x.source, x = x }
                    if r.info.upcoming then
                        later[#later + 1] = pick
                    elseif r.up then
                        local choices = x.q.rewards and x.q.rewards.choices
                        pick.choice = choices and lib.Contains(choices, r.item)
                        picks[#picks + 1] = pick
                    end
                end
            end
        end
    end
    local bestChoice = {}
    for _, pick in ipairs(picks) do
        if pick.choice then
            local cur = bestChoice[pick.x.id]
            if not cur or lib.BetterPick(pick, cur) then bestChoice[pick.x.id] = pick end
        end
    end
    table.sort(picks, lib.BetterPick)
    local now, bySlot, givers, quests = {}, {}, {}, {}
    for _, pick in ipairs(picks) do
        if not pick.choice or bestChoice[pick.x.id] == pick then
            local first = bySlot[pick.info.key]
            if first then
                first.alts[#first.alts + 1] = pick
            else
                pick.alts = {}
                bySlot[pick.info.key] = pick
                now[#now + 1] = pick
                if not givers[pick.x.id] then
                    givers[pick.x.id] = true
                    quests[#quests + 1] = pick.x
                end
            end
        end
    end
    table.sort(quests, function(a, b)
        local la, lb = a.q.level or 0, b.q.level or 0
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
    table.sort(later, function(a, b)
        local ea, eb = a.info.entry, b.info.entry
        if ea.level ~= eb.level then return ea.level < eb.level end
        return ea.gain > eb.gain
    end)
    return { now = now, later = later, quests = quests }
end

---------------------------------------------------------------- loot list lines

local SAME, GAIN, DIM = "|cff888888", "|cff33ff99", "|cff777777"
local QUEST_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t "
local QUEST_LINK = "|cffffd100"

-- The quest's level as "[22]" in the game's difficulty colors for the
-- profile's level: red 5 or more above, orange 3 or more, yellow within 2,
-- green below that, grey once it gives little experience.
local function LevelTag(level, p)
    if not level then return "" end
    local d, lv = level - p.level, p.level
    local grey = lv <= 5 and 0 or (lv <= 39 and lv - math.floor(lv / 10) - 5) or (lv - math.floor(lv / 5) - 1)
    local color = (d >= 5 and "|cffff1a1a") or (d >= 3 and "|cffff8040") or (d >= -2 and "|cffffff00")
        or (level > grey and "|cff40c040") or "|cff808080"
    return color .. "[" .. level .. "]|r"
end

-- After the name: the quest's type (but Solo) and its chain step, in grey.
local function Tags(q)
    local tags = {}
    if q.type and q.type ~= "Group" then tags[#tags + 1] = L[q.type] end
    local chain = q.chain and ns.QuestChains and ns.QuestChains[q.chain.id]
    if chain and #chain > 1 then tags[#tags + 1] = string.format(L["step %d/%d"], q.chain.step, #chain) end
    return #tags > 0 and ("  " .. SAME .. table.concat(tags, " · ") .. "|r") or ""
end

-- "Gryan Stoutmantle  56, 48": a giver and where in its zone.
local function Giver(start)
    if not start then return "" end
    local coords = start.x and string.format("  %s%.0f, %.0f|r", DIM, start.x, start.y) or ""
    return ns.StartName(start) .. coords
end

-- The quest's level, name, tags and progress from `x0` up to `limit`; a quest
-- the profile can't take, dimmed.
local function QuestHeader(line, x, p, font, x0, limit)
    local q = x.q
    local state = (x.state == "done" and ("  " .. SAME .. L["completed"] .. "|r"))
        or (x.state == "active" and ("  " .. ns.ACTIVE_HEX .. L["in log"] .. "|r")) or ""
    local text = QUEST_ICON .. LevelTag(q.level, p) .. " " .. QUEST_LINK .. ns.QuestName(x.id, q.name) .. "|r"
        .. Tags(q) .. state
    Lib().SetHeader(line, (x.open or x.state) and text or (DIM .. text:gsub("|c%x%x%x%x%x%x%x%x", "") .. "|r"),
        x0, font, limit)
end

local function ItemText(id)
    return ns.QualityHex(ns.ItemQuality(id)) .. ns.ItemName(id) .. "|r"
end

-- Why reward `r` of quest `x` isn't ranked for the profile, as the loot list's rows say it.
local function Why(r, x, p)
    local item = ns.Items[r.item]
    local usable, why, at = Lib().Usable(item, p, ns.ObtainLevel(item, p, "quest"))
    if not x.open then return L["quest not open"] end
    if at then return L["level too high"] end
    return usable and L["not ranked"] or why
end

-- The loot line's parts for a quest line, made the first time it shows one:
-- the reward icons (each its item's tooltip on hover; a click works as on the
-- line, shift-click links the item), the reward shown and its gain, and the
-- open quest's Details button. In line.parts, so every redraw hides them first.
local function Parts(line)
    if line.qp then return line.qp end
    local qp = { icons = {} }
    qp.gain = line:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    qp.gain:SetPoint("RIGHT", line, "RIGHT", -6, 0)
    qp.gain:SetWidth(TOP_GAIN_W)
    qp.gain:SetJustifyH("RIGHT")
    qp.name = line:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    qp.name:SetPoint("RIGHT", qp.gain, "LEFT", -6, 0)
    qp.name:SetWidth(TOP_NAME_W)
    qp.name:SetJustifyH("LEFT")
    qp.name:SetWordWrap(false)
    local parts = { qp.gain, qp.name }
    for i = 1, MAX_ICONS do
        local b = CreateFrame("Button", nil, line)
        b:SetSize(ICON, ICON)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.edge = b:CreateTexture(nil, "BACKGROUND")
        b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        b.edge:SetColorTexture(0, 0, 0, 0.8)
        b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 1) -- (an upgrade to take: a green frame)
        b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b.glow:SetColorTexture(0.2, 1, 0.6, 0.9)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b:SetScript("OnEnter", function(self) Lib().ItemTooltip(self) end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self, button)
            if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick and self.entry then
                HandleModifiedItemClick(ns.ItemLink(self.entry.id))
                return
            end
            local click = line:GetScript("OnClick")
            if click then click(line, button) end
        end)
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta)
            local wheel = line:GetScript("OnMouseWheel")
            if wheel then wheel(line, delta) end
        end)
        qp.icons[i] = b
        parts[#parts + 1] = b
    end
    qp.details = W.FitButton(W.FlatButton(line, L["Details"], 56, 18))
    qp.details:SetScript("OnClick", function()
        if line.quest then ns.QuestPanel.Show(line.quest) end
    end)
    parts[#parts + 1] = qp.details
    for _, part in ipairs(parts) do
        part:Hide()
        line.parts[#line.parts + 1] = part
    end
    line.qp = qp
    return qp
end

local function Toggle(id)
    openQuest = openQuest ~= id and id or nil
    scrollToOpen = openQuest ~= nil
    UI.Refresh()
end

local function Register(Draw)
    -- Quests view quest, one line: the fold sign (the open quest: minus, on
    -- a band), its level, name and tags; on the right its rewards' icons (one
    -- to take that is an upgrade framed in green, ones the profile can't use
    -- greyed), then its best upgrade and the gain, else its first look-ahead
    -- one. A click opens or closes it. { x, open }
    function Draw.zquest(line, l, p)
        local x, lib = l.x, Lib()
        local qp = Parts(line)
        line.fold.Set(l.open)
        line.fold:Show()
        if l.open then line.band:Show() end
        local n = math.min(#x.rows, MAX_ICONS)
        for i = 1, n do
            local r, b = x.rows[i], qp.icons[i]
            b:ClearAllPoints()
            b:SetPoint("RIGHT", qp.name, "LEFT", -10 - (n - i) * (ICON + ICON_GAP), 0)
            b.tex:SetTexture(UI.ItemIcon(r.item))
            b.tex:SetDesaturated(r.info == nil)
            b.tex:SetAlpha(r.info and 1 or 0.45)
            lib.ShowIf(b.glow, r.take == true)
            b.entry = r.info and r.info.entry
                or { id = r.item, sources = ns.Items[r.item].sources, why = Why(r, x, p) }
            b.rankText = r.info and r.info.upcoming and string.format(L["Upgrade at level %d: +%.1f"],
                r.info.entry.level, r.info.entry.gain) or nil
            b.extraLines = r.best and { L["Best pick of this quest's choices"] } or nil
            b:Show()
        end
        local top = x.top
        if top then
            local e = top.info.entry
            if top.info.upcoming then
                qp.name:SetText(SAME .. string.format(L["lvl %d"], e.level) .. "|r  " .. ItemText(top.item))
                qp.gain:SetText(GAIN .. string.format("+%.1f", e.gain) .. "|r")
            else
                qp.name:SetText(ItemText(top.item))
                qp.gain:SetText(top.gain and (GAIN .. string.format("+%.1f", top.gain) .. "|r")
                    or (SAME .. "#" .. top.info.rank .. "|r"))
            end
            qp.name:Show()
            qp.gain:Show()
        end
        QuestHeader(line, x, p, nil, 16, n > 0 and qp.icons[1] or qp.name)
        line.quest = x.source
        line.action = function() Toggle(x.id) end
    end

    -- The open quest's giver (where it starts, if not from an NPC), with
    -- Details (the quest panel) and Pin giver. { x }
    function Draw.zgiver(line, l, p)
        local x = l.x
        local qp = Parts(line)
        local start = (p.faction == "Horde" and x.q.startHorde) or x.q.start
        local text = SAME .. L["Quest giver"] .. "|r  " .. SAME .. "?|r"
        if start then
            local label = (start.kind == "object" and L["Starts at"]) or (start.kind == "item" and L["Starts from item"])
                or L["Quest giver"]
            local zone = start.zoneId ~= x.zone and ns.ZoneName(start.zoneId)
            text = SAME .. label .. "|r  " .. Giver(start) .. (zone and ("  " .. SAME .. zone .. "|r") or "")
        end
        qp.details:ClearAllPoints()
        if start and start.x then
            line.pin:Show()
            qp.details:SetPoint("RIGHT", line.pin, "LEFT", -4, 0)
        else
            qp.details:SetPoint("RIGHT", line, "RIGHT", -4, 0)
        end
        qp.details:Show()
        Lib().SetHeader(line, text, DETAIL_X, WildGearFontHighlightSmall, qp.details)
        line.quest = x.source
    end

    -- Summary quest to do: { x }, with where its next step is given (a chain's
    -- next step for the character) and Pin giver.
    function Draw.todo(line, l, p)
        local x = l.x
        local info = ns.QuestInfo(x.source, p)
        local target = info and info.target
        local where = target and Giver(target.start) or ""
        if target and target.step and target.id ~= x.id then
            -- (a step whose giver is unknown: its name)
            where = string.format(L["step %d/%d: %s"], target.step, target.steps,
                where ~= "" and where or (QUEST_LINK .. (target.name or "") .. "|r"))
        end
        line.giver:SetText(where)
        line.giver:Show()
        if target and target.start and target.start.x then line.pin:Show() end
        QuestHeader(line, x, p, WildGearFontHighlightSmall, 2, line.giver)
        line.quest = x.source
    end

    -- All zones, Quests view: a zone's band; a click opens the zone. { zone, action }
    function Draw.zone(line, l)
        local z = l.zone
        local levels = z.minLevel and ("  " .. SAME .. string.format(L["levels %s"], z.minLevel .. "-" .. z.maxLevel)
            .. "|r") or ""
        Lib().SetHeader(line, ZoneName(z) .. levels, 14)
        line.band:Show()
        line.action = l.action
    end
end

---------------------------------------------------------------- the list

local function Select(id)
    selected = id
    Lib().ResetScroll()
    UI.Refresh()
end

-- A quest's line; the open one's details under it: its giver, then every
-- reward ranked, an upgrade to take tinted, why one can't be used in grey.
local function AddQuest(x, Add)
    local open = openQuest == x.id
    Add({ kind = "zquest", x = x, open = open })
    if not open then return end
    Add({ kind = "zgiver", x = x })
    for _, r in ipairs(x.rows) do
        Add({ kind = "item", item = ns.Items[r.item], drop = { id = r.item }, info = r.info, gain = r.gain, up = r.up,
              quest = x.source, questReward = true, open = x.open, bestPick = r.best, tint = r.take, reason = true })
    end
    Add({ kind = "spacer" })
end

-- The Quests view of `quests` (one zone's, or with `zones` the region's,
-- under a band per zone): yours first, then behind folds, your quests with no
-- gear for you (For me) and the other faction's.
local function QuestLines(quests, p, lo, hi, Add, zones)
    local forMe = not ns.db.questsShowAll
    local mine, bare, other, otherSide = {}, {}, {}, nil
    local side = ns.FactionSide[p.faction]
    for _, x in ipairs(quests) do
        if Listed(x, lo, hi) then
            local qs = x.q.side or 3
            if side and qs ~= 3 and qs ~= side then
                other[#other + 1], otherSide = x, qs
            elseif x.open or not forMe then
                local any = false
                for _, r in ipairs(x.rows) do any = any or r.info ~= nil end
                if forMe and not any then bare[#bare + 1] = x else mine[#mine + 1] = x end
            end
        end
    end
    -- (with `zones`, each zone's band before its first quest, a spacer before
    -- all but the first)
    local function List(xs)
        local lastZone
        for i, x in ipairs(xs) do
            if zones and x.zone ~= lastZone then
                lastZone = x.zone
                if i > 1 then Add({ kind = "spacer" }) end
                Add({ kind = "zone", zone = zoneById[x.zone], action = function() Select(x.zone) end })
            end
            AddQuest(x, Add)
        end
    end
    if zones then
        -- (by zone in the list's order, each zone's quests by level as they came)
        local order = {}
        for i, z in ipairs(zones) do order[z.id] = i end
        for _, xs in ipairs({ mine, bare, other }) do
            local keyed = {}
            for i, x in ipairs(xs) do keyed[x] = i end
            table.sort(xs, function(a, b)
                local za, zb = order[a.zone] or math.huge, order[b.zone] or math.huge
                if za ~= zb then return za < zb end
                return keyed[a] < keyed[b]
            end)
        end
    end
    List(mine)
    if #mine == 0 then
        Add({ kind = "note", text = SAME .. L["No quests here match the filters."] .. "|r" })
    end
    local function Fold(xs, open, flip, text)
        Add({ kind = "spacer" })
        Add({ kind = "note", folded = not open, text = text, action = function()
            flip()
            UI.Refresh()
        end })
        if open then List(xs) end
    end
    if #bare > 0 then
        Fold(bare, showBare, function() showBare = not showBare end, showBare and L["Hide quests without gear for you"]
            or string.format(L["Show quests without gear for you (%d)"], #bare))
    end
    if #other > 0 then
        local label = ns.QuestSideLabel(otherSide)
        Fold(other, showOther, function() showOther = not showOther end,
            showOther and string.format(L["Hide %s quests"], label) or string.format(L["Show %s quests (%d)"], label, #other))
    end
end

-- Summary: the upgrades per slot, the quests that give them, look-ahead upgrades.
local function SummaryLines(s, p, Add, best)
    local worn = Lib().Worn()
    Add({ kind = "section", text = worn and L["Upgrades now"] or L["Top picks"], wish = s.now }) -- (a star for them all)
    if #s.now == 0 then
        Add({ kind = "note", text = SAME .. ((not Lib().Ranked() and L["No rankings: this spec has no stat weights."])
            or (worn and L["Nothing here beats what you wear."]) or L["Nothing here makes the top list."]) .. "|r" })
        if best then
            local count = worn and ns.Plural(best.n, "%d upgrade", "%d upgrades")
                or ns.Plural(best.n, "%d top pick", "%d top picks")
            Add({ kind = "note", action = function() Select(best.zone.id) end,
                  text = SAME .. string.format(L["Try %s: %s. Click to open it."],
                      "|cffffd100" .. ZoneName(best.zone) .. "|r" .. SAME, count) .. "|r" })
        end
    end
    for _, pick in ipairs(s.now) do Add({ kind = "pick", pick = pick }) end
    if #s.quests > 0 then
        Add({ kind = "gap" })
        Add({ kind = "section", text = L["Quests to do"], hint = L["in level order"] })
        for _, x in ipairs(s.quests) do Add({ kind = "todo", x = x }) end
    end
    if #s.later > 0 then
        local ahead = ns.charDB.ahead or 0
        Add({ kind = "gap" })
        Add({ kind = "section", text = L["Coming up"],
              hint = ns.Plural(ahead, "within %d level (Look ahead)", "within %d levels (Look ahead)") })
        for _, pick in ipairs(s.later) do Add({ kind = "pick", pick = pick, later = true }) end
    end
end

---------------------------------------------------------------- the left column

local function ShowZoneTooltip(self)
    local s = self.summary
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.zone and ZoneName(self.zone) or L["All zones"])
    if self.zone and self.zone.minLevel then
        GameTooltip:AddLine(string.format(L["Levels %s"], self.zone.minLevel .. "-" .. self.zone.maxLevel), 1, 1, 1)
    end
    if s then
        local worn = Lib().Worn()
        if #s.now > 0 then
            GameTooltip:AddLine(worn and ns.Plural(#s.now, "%d upgrade over what you wear", "%d upgrades over what you wear")
                or string.format(L["%d items in the top %d for their slot"], #s.now, UI.TopN()), 0.2, 1, 0.6, true)
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

local function ZoneButton(key, zone, name)
    local b = Lib().CreateListButton(list, 1, name)
    b.key, b.zone = key, zone
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(KIND_ICON_SIZE, KIND_ICON_SIZE)
    b.icon:SetPoint("LEFT", b, "LEFT", 8, 0)
    if zone then b.icon:SetAtlas(KIND_ICON[ZoneKind(zone)]) end
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 5, 0) -- (All zones, without one, lines up with the names)
    if zone and zone.minLevel then b.right:SetText(zone.minLevel .. "-" .. zone.maxLevel) end
    b:SetScript("OnEnter", ShowZoneTooltip)
    b:SetScript("OnClick", function(self) Select(self.key) end)
    return b
end

-- A type's chip (Modern; a skin with switches: its button) or check box
-- (Classic), with how many of the zone's quests of that type give an upgrade
-- now on the right (b.num).
local function TypeControl(parent, t, width)
    local function Toggle()
        ns.db.questTypes = ns.db.questTypes or {}
        ns.db.questTypes[t.key] = not TypeOn(t.key)
        if ns.db.questTypes[t.key] == TYPE_ON[t.key] then ns.db.questTypes[t.key] = nil end
        if not next(ns.db.questTypes) then ns.db.questTypes = nil end
        Lib().ResetScroll()
        UI.Refresh()
    end
    local b
    if not W.Switches() then
        b = W.ToggleRow(parent, width + 4, Toggle)
        b.label:SetText(t.text)
        b.label:SetPoint("RIGHT", b, "RIGHT", -24, 0)
        b.num = b:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
        b.num:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.Paint = function(on) b.Update(on) end
    else
        if T.Classic() then
            b = W.FlatButton(parent, nil, width, ROW)
            b.choice = true -- (its art shows the selection, not a press)
        else
            b = CreateFrame("Button", nil, parent, "BackdropTemplate")
            b:SetSize(width, ROW)
            W.AddHighlight(b)
        end
        -- (a skin's button: in from its brass ends)
        local pad = b.art and b.art.capWidth + 5 or 6
        b.text = b:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        b.text:SetPoint("LEFT", b, "LEFT", pad, 0)
        b.text:SetText(t.text)
        b.num = b:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
        b.num:SetPoint("RIGHT", b, "RIGHT", -pad, 0)
        b:SetScript("OnClick", Toggle)
        b.Paint = function(on) W.StyleChoice(b, on) end
    end
    b:HookScript("OnEnter", function(self)
        if not (self.ups and self.ups > 0) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(t.text)
        GameTooltip:AddLine(ns.Plural(self.ups, "%d quest with an upgrade for you", "%d quests with an upgrade for you"),
            0.2, 1, 0.6, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    b.key = t.key
    return b
end

-- The filters box: Quest level (its range on the right, the slider under
-- it), Type, Hide completed.
local function CreateFilters(parent, width)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Box(box)
    local inner = width - 2 * PAD
    local y = PAD
    local function Label(text, font)
        local fs = box:CreateFontString(nil, "OVERLAY", font or W.LabelFont())
        fs:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -y)
        fs:SetText(text)
        return fs
    end
    Label(L["Filters"], "WildGearFontNormal")
    y = y + 20
    Label(L["Quest level"])
    box.range = box:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    box.range:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -y)
    y = y + 16
    local function RangeText(lo, hi) box.range:SetText(lo == hi and tostring(lo) or (lo .. " - " .. hi)) end
    box.slider = W.RangeSlider(box, inner, 1, ns.MAX_LEVEL, RangeText, function(lo, hi)
        ns.charDB.questLevels = { lo, hi, level = ns.GetProfile().level }
        Lib().ResetScroll()
        UI.Refresh()
    end)
    box.slider:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -(y + (T.Classic() and 6 or 2)))
    box.RangeText = RangeText
    y = y + (T.Classic() and 34 or 26)
    Label(L["Type"])
    y = y + 18
    box.types = {}
    local half = (inner - GAP) / 2
    for i, t in ipairs(TYPES) do
        local b = TypeControl(box, t, half)
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        b:SetPoint("TOPLEFT", box, "TOPLEFT", PAD + col * (half + GAP) - (W.Switches() and 0 or 4),
            -(y + row * (ROW + GAP)))
        box.types[i] = b
    end
    y = y + 2 * (ROW + GAP) + 4
    box.done = W.ToggleRow(box, inner + 8, function()
        ns.db.questShowDone = not ns.db.questShowDone or nil
        Lib().ResetScroll()
        UI.Refresh()
    end)
    box.done.label:SetText(L["Hide completed"])
    box.done:SetPoint("TOPLEFT", box, "TOPLEFT", PAD - 4, -y)
    y = y + ROW + PAD
    box:SetSize(width, y)
    return box
end

-- Made with the window (UI.lua's Create), at `x` on the left, `top` down:
-- hidden until the tab is picked.
function Q.Create(frame, x, top)
    local lib = Lib()
    local width = lib.LEFT_WIDTH
    panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -top)
    panel:SetSize(width, 100)
    region = W.Segmented(panel, nil, { { key = 0, text = RegionName(0) }, { key = 1, text = RegionName(1) } },
        (width - 2) / 2, function(key)
            ns.charDB.questRegion = key
            selected = nil
            lib.ResetScroll()
            UI.Refresh()
        end)
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -30)
    list:SetSize(width, 10)
    if not T.Classic() then
        local bg = list:CreateTexture(nil, "BACKGROUND", nil, -1)
        bg:SetAllPoints()
        bg:SetColorTexture(unpack(T.CARD))
    end
    Index()
    zoneButtons.all = ZoneButton("all", nil, L["All zones"])
    for _, z in ipairs(ns.Zones or {}) do zoneButtons[z.id] = ZoneButton(z.id, z, ZoneName(z)) end
    for _, kind in ipairs({ "city", "instance" }) do
        rules[kind] = W.Rule(list, 1, 1, 1, 0.1)
        rules[kind]:SetHeight(1)
    end
    filters = CreateFilters(panel, width)
    filters:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
    Register(lib.Draw)
    panel:Hide()
end

function Q.Show(on)
    if not panel then return end
    if on then panel:Show() else panel:Hide() end
end

-- The zone to open: the shown one with the most upgrades now, then the one
-- whose levels fit the profile's best (cities, dungeons and raids last); All
-- zones without one.
local function DefaultZone(shown, sums, p)
    local best, bestKey
    for _, z in ipairs(shown) do
        local n = #sums[z.id].now
        local dist = ZoneKind(z) ~= "zone" and 100 or ((p.level < z.minLevel and z.minLevel - p.level)
            or (p.level > z.maxLevel and p.level - z.maxLevel) or 0)
        local key = n * 1000 - dist
        if not bestKey or key > bestKey then best, bestKey = z.id, key end
    end
    return best or "all"
end

-- Updates the tab for profile `p` (the loot list included); `minHeight`, the
-- loot list's height, is the least the column takes. Returns its height.
function Q.Refresh(p, minHeight)
    local lib = Lib()
    local map = lib.RankMap()
    local byZone = Build(p, map)
    local r = Region(p)
    local lo, hi = Range(p)
    local skyborne = SKYBORNE[p.raceId]

    -- The region's zones the filters let through, with their summaries.
    local shown, sums, all = {}, {}, {}
    for _, z in ipairs(ns.Zones or {}) do
        if (z.id == ZEPHRAS and skyborne) or z.region == r then
            local quests = byZone[z.id] or {}
            local any = false
            for _, x in ipairs(quests) do
                if x.open and Listed(x, lo, hi) then any = true end
                all[#all + 1] = x
            end
            sums[z.id] = Summarize(quests)
            if any then shown[#shown + 1] = z end
        end
    end
    -- (Zephras Isle first, then as ns.Zones has them: the cities, dungeons and raids last)
    local order = {}
    for i, z in ipairs(ns.Zones or {}) do order[z.id] = i end
    table.sort(shown, function(a, b)
        if (a.id == ZEPHRAS) ~= (b.id == ZEPHRAS) then return a.id == ZEPHRAS end
        return order[a.id] < order[b.id]
    end)
    sums.all = Summarize(all)

    -- The zone shown follows the profile's level: a new level picks the one
    -- for it again; one picked by hand stays until then, while it's listed.
    local listed = { all = true }
    for _, z in ipairs(shown) do listed[z.id] = true end
    if selectedAt ~= p.level or not (selected and listed[selected]) then
        selected = DefaultZone(shown, sums, p)
        lib.ResetScroll()
    end
    selectedAt = p.level

    -- The list: All zones, the zones, a rule, the cities, a rule, the dungeons and raids.
    local H = lib.DUNGEON_HEIGHT
    for _, b in pairs(zoneButtons) do b:Hide() end
    local y = 0
    local function Place(b, s)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        b.summary = s
        b.badge:SetText(#s.now)
        lib.ShowIf(b.badge, #s.now > 0)
        lib.ShowIf(b.pill, #s.now > 0)
        lib.ShowIf(b.selected, b.key == selected)
        b:Show()
        y = y + H
    end
    Place(zoneButtons.all, sums.all)
    for _, rule in pairs(rules) do rule:Hide() end
    for _, z in ipairs(shown) do
        local kind = ZoneKind(z)
        local rule = rules[kind == "city" and "city" or (kind ~= "zone" and "instance")]
        if rule and not rule:IsShown() then
            rule:ClearAllPoints()
            rule:SetPoint("TOPLEFT", list, "TOPLEFT", 8, -(y + 4))
            rule:SetPoint("TOPRIGHT", list, "TOPRIGHT", -8, -(y + 4))
            rule:Show()
            y = y + 9
        end
        Place(zoneButtons[z.id], sums[z.id])
    end
    list:SetHeight(y)
    region.Update(r)

    -- The filters: the range, each type's quests with an upgrade now in the zone.
    if not filters.slider.Dragging() then -- (a refresh mid-drag, from an event, leaves the thumbs be)
        filters.slider.Set(lo, hi)
        filters.RangeText(lo, hi)
    end
    local zoneQuests = selected == "all" and all or (byZone[selected] or {})
    for _, b in ipairs(filters.types) do
        local ups = 0
        for _, x in ipairs(zoneQuests) do
            if x.type == b.key and x.up and x.state ~= "done" then ups = ups + 1 end
        end
        b.ups = ups
        local on = TypeOn(b.key)
        b.num:SetText((ups > 0 and on and GAIN or "") .. ups .. "|r")
        b.Paint(on)
    end
    filters.done.Update(HideDone())

    -- The right side. (No spacer first or right after another.)
    local lines = {}
    local function Add(l)
        if l.kind == "spacer" and (#lines == 0 or lines[#lines].kind == "spacer") then return end
        lines[#lines + 1] = l
    end
    local view = ns.db.questView == "quests" and "quests" or "summary"
    local zone = selected ~= "all" and zoneById[selected] or nil
    if view == "summary" then
        local best
        if #sums[selected].now == 0 then
            for _, z in ipairs(shown) do
                local n = #sums[z.id].now
                if n > 0 and (not best or n > best.n) then best = { zone = z, n = n } end
            end
        end
        SummaryLines(sums[selected], p, Add, best)
    else
        QuestLines(zoneQuests, p, lo, hi, Add, not zone and shown or nil)
        -- A quest just opened: scrolled so its details show, its line staying in view.
        for i, l in ipairs(scrollToOpen and lines or {}) do
            if l.kind == "zquest" and l.open then
                local last = i
                while lines[last + 1] and (lines[last + 1].kind == "zgiver" or lines[last + 1].kind == "item") do
                    last = last + 1
                end
                local offset, room = lib.Offset(), lib.VISIBLE_LINES - 1
                if last > offset + room then offset = math.min(i - 1, last - room) end
                lib.Offset(math.min(offset, i - 1))
                break
            end
        end
    end
    scrollToOpen = false
    local title = zone and (ZoneName(zone) .. (zone.minLevel and ("  " .. SAME .. string.format(L["levels %s"],
        zone.minLevel .. "-" .. zone.maxLevel) .. "|r") or "")) or (RegionName(r) .. "  " .. SAME .. L["All zones"] .. "|r")
    lib.Show(lines, view, title)

    local height = math.max(minHeight or 0, 30 + y + 14 + filters:GetHeight())
    panel:SetHeight(height)
    return height
end
