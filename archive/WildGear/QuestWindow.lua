local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Marks on a quest's reward choices wherever the game shows them: the NPC's
-- quest window (when the quest is offered and when you turn it in), the
-- quest log and the map's quest details.
--   * Every reward that is an upgrade for your main spec, a choice or an
--     item you always get (its biggest gain over the gear the spec is
--     compared with, as item tooltips judge it: by default what you wear;
--     among what you can wear now; your class's own armor
--     type only with Armor type: Class type): in the tile's top right corner,
--     over the end of the name (not on the item icon), the green up arrow its
--     tooltip shows the gain with rises and fades, then the icon of its line
--     (its weight profile's, else the spec's: Tooltip.lua) shows for a
--     moment, in a loop.
--   * Off-spec suggestions: when none of the choices (or none of the items
--     you always get) is an upgrade for your main spec, the upgrades among
--     them for the off specs picked in Settings, each against the gear it
--     is compared with (by default the best of what you wear and carry in
--     your bags for it), get the same mark with the off spec line's icon.
--   * The best pick among two choices or more, with a line on its tooltip
--     (Tooltip.lua): the biggest upgrade for your main spec, else for an off
--     spec, with a green outline and the quest panel's faint green tint on
--     its tile (green quality borders are on the icon only, so the two don't
--     mix up). With no upgrade at all, the choice that sells for the most,
--     in gold, with a gold coin in its top right corner. The outline gives
--     way to the game's gold highlight once you've picked that choice.
-- In the quest log's list (on the map), the same animated mark goes after
-- the title of each quest with an upgrade among its rewards (choices or not),
-- from the addon's quest data, else from what the game says; off specs the
-- same way. Settings' Quest rewards box turns it all off (questMarks = false)
-- or only the off-spec suggestions (questOffSpec = false).
-- DaylightUI's own NPC quest window and quest journal (its quest pages and
-- its list) get all the same marks: see the DaylightUI section.

local L = ns.L
local QW = {}
ns.QuestWindow = QW

local ARROW = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\TipUp" -- item tooltips' green up arrow
local GREEN = { 0.2, 1, 0.6 } -- the quest panel's best pick
local GOLD = { 1, 0.82, 0 } -- a pick for its price
local COIN = "Interface\\MoneyFrame\\UI-GoldIcon"
local OUTSET = 2 -- the outline's distance outside the tile
local UPGRADE = 0.05 -- a gain item tooltips show with a green arrow
local RISE = 6 -- how far the upgrade arrow rises each time

local overlays = {} -- [reward tile] = a frame over it with its marks, made on first use
local shown = {} -- [rewards frame] = whether it last showed a quest log quest, to mark it again
local pending -- a choice's item, or your worn gear, hadn't loaded: mark again when it does

-- The outline's sides, `px` thick (the side edges stop short of the corners).
local function Outline(o, px)
    local top, bottom, left, right = o.edges[1], o.edges[2], o.edges[3], o.edges[4]
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", o, "TOPLEFT", 0, -px)
    left:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 0, px)
    left:SetWidth(px)
    right:SetPoint("TOPRIGHT", o, "TOPRIGHT", 0, -px)
    right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, px)
    right:SetWidth(px)
end

-- The upgrade mark's loop, 2.6 seconds: the arrow fades in as it rises RISE
-- through its spot, then fades out; while it's hidden, the spec icon fades
-- in, holds and fades out. Two groups, started together; each step sets the
-- alpha from and to, so none relies on how an earlier step ended.
local function Animate(m)
    local function Step(group, order, duration, fromAlpha, toAlpha, rise)
        local a = group:CreateAnimation("Alpha")
        a:SetOrder(order)
        a:SetDuration(duration)
        a:SetFromAlpha(fromAlpha)
        a:SetToAlpha(toAlpha)
        if rise then
            local t = group:CreateAnimation("Translation")
            t:SetOrder(order)
            t:SetDuration(duration)
            t:SetOffset(0, rise)
        end
    end
    local up = m.arrowFrame:CreateAnimationGroup()
    up:SetLooping("REPEAT")
    Step(up, 1, 0.25, 0, 1, RISE * 0.3) -- (a steady rise over the first 0.8 s)
    Step(up, 2, 0.25, 1, 1, RISE * 0.3)
    Step(up, 3, 0.3, 1, 0, RISE * 0.4)
    Step(up, 4, 1.8, 0, 0)
    local spec = m.specFrame:CreateAnimationGroup()
    spec:SetLooping("REPEAT")
    Step(spec, 1, 0.8, 0, 0)
    Step(spec, 2, 0.2, 0, 1)
    Step(spec, 3, 1.3, 1, 1)
    Step(spec, 4, 0.3, 1, 0)
    m.anims = { up, spec }
end

-- An upgrade mark on `parent`, `size` high, placed by the caller where the
-- spec icon shows: a green up arrow (item tooltips' gain arrow, on a dark
-- copy a little larger so it shows on any background) rises and fades, then
-- your main spec's icon (on a dark square) shows for a moment, over and over.
local function NewMark(parent, size)
    local m = CreateFrame("Frame", nil, parent)
    m:SetSize(size, size)
    local px = PixelUtil and PixelUtil.GetNearestPixelSize(1, m:GetEffectiveScale(), 1) or 1
    m.arrowFrame = CreateFrame("Frame", nil, m)
    m.arrowFrame:SetSize(size, size)
    m.arrowFrame:SetPoint("CENTER", m, "CENTER", 0, -RISE / 2)
    local back = m.arrowFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    back:SetTexture(ARROW)
    back:SetVertexColor(0, 0, 0, 0.85)
    back:SetAllPoints()
    local arrow = m.arrowFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    arrow:SetTexture(ARROW)
    arrow:SetVertexColor(GREEN[1], GREEN[2], GREEN[3], 1)
    arrow:SetSize(size - 2, size - 2)
    arrow:SetPoint("CENTER")
    m.specFrame = CreateFrame("Frame", nil, m)
    m.specFrame:SetAllPoints()
    m.specFrame:SetAlpha(0) -- (only the animation shows it)
    local square = m.specFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    square:SetColorTexture(0, 0, 0, 0.9)
    square:SetAllPoints()
    m.spec = m.specFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    m.spec:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64) -- (cropped of its border, as in text)
    m.spec:SetPoint("TOPLEFT", px, -px)
    m.spec:SetPoint("BOTTOMRIGHT", -px, px)
    Animate(m)
    return m
end

-- Shows upgrade mark `m` with icon `icon` (default: that of profile `p`'s
-- line, Tooltip.lua's), its loop from the start (marks started together stay
-- in step), or hides it (`on` false).
local function ShowMark(m, p, on, icon)
    m.spec:SetTexture(icon or ns.Tooltip.LineIcon(p))
    if on then m:Show() else m:Hide() end
    for _, anim in ipairs(m.anims) do
        anim:Stop()
        if on then anim:Play() end
    end
end

-- Shows upgrade marks `marks` ({ [mark] = icon }) for profile `p`, in step:
-- their loops start over together when one of them shows anew (or has
-- stopped), else they run on (the lists and tiles they're on update often,
-- such as on every hover of a quest on the map, and a loop started over
-- each time would only flicker).
local function ShowMarks(marks, p)
    local restart = false
    for m in pairs(marks) do
        if not (m:IsShown() and m.anims[1]:IsPlaying()) then restart = true end
    end
    for m, icon in pairs(marks) do
        if restart then
            ShowMark(m, p, true, icon)
        else
            m.spec:SetTexture(icon or ns.Tooltip.LineIcon(p))
        end
    end
end

-- A frame's size or position as a plain number (Midnight may hand out secret values).
local function Num(v)
    if type(v) ~= "number" or (issecretvalue and issecretvalue(v)) then return 0 end
    return v
end

-- How far reward tile `tile`, with its outline, goes past the left and the
-- right edge of the scroll frame it sits in, which cuts off what's beyond:
-- the NPC window's second column does on the right by some 7 (its tiles end
-- at 305, the frame at 300), DaylightUI's first column on the left.
local function Overhang(tile)
    local clip = tile:GetParent()
    while clip and not (clip:IsObjectType("ScrollFrame") or (clip.DoesClipChildren and clip:DoesClipChildren())) do
        clip = clip:GetParent()
    end
    if not clip then return 0, 0 end
    local scale = Num(tile:GetEffectiveScale())
    if scale == 0 then return 0, 0 end
    local k = Num(clip:GetEffectiveScale()) / scale
    local left, right = Num(tile:GetLeft()), Num(tile:GetRight())
    local edgeL, edgeR = Num(clip:GetLeft()), Num(clip:GetRight())
    local l = (left ~= 0 and edgeL ~= 0) and math.max(0, edgeL * k - (left - OUTSET)) or 0
    local r = (right ~= 0 and edgeR ~= 0) and math.max(0, right + OUTSET - edgeR * k) or 0
    return l, r
end

-- What DaylightUI filled one of its item tiles with (DaylightUI section
-- below), nil on the game's tiles.
local function Spec(tile)
    local spec = rawget(tile, "spec")
    return type(spec) == "table" and spec or nil
end

local function NewOverlay(tile)
    local o = CreateFrame("Frame", nil, tile)
    o:SetPoint("TOPLEFT", tile, "TOPLEFT", -OUTSET, OUTSET)
    o:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", OUTSET, -OUTSET) -- (both pulled in by Update when cut off)
    -- The best pick's mark (colored by Paint): the tint leaves the icon
    -- alone, so its colors (and its quality border) stay true. DaylightUI's
    -- icon (its quality outline, `edge`) sits centred in its tile: the tint
    -- starts right of it, from the top.
    o.fill = o:CreateTexture(nil, "BACKGROUND")
    local daylight = Spec(tile) and rawget(tile, "edge")
    if daylight then
        local x = Num(daylight:GetRight()) - Num(tile:GetLeft())
        o.fill:SetPoint("TOPLEFT", tile, "TOPLEFT", x > 0 and x or 4 + Num(daylight:GetWidth()), OUTSET)
    elseif tile.Icon then
        o.fill:SetPoint("TOPLEFT", tile.Icon, "TOPRIGHT", 0, OUTSET)
    else
        o.fill:SetPoint("TOPLEFT")
    end
    o.fill:SetPoint("BOTTOMRIGHT")
    o.edges = {}
    for i = 1, 4 do o.edges[i] = o:CreateTexture(nil, "OVERLAY") end
    -- The upgrade mark in the tile's top right corner, over the end of the
    -- name: 13 high on the NPC window's tiles (and DaylightUI's), 11 on the
    -- quest log's and the map's smaller ones. The gold coin of a pick for its
    -- price goes there too. (On the overlay, not the tile, so they move in
    -- with its right edge. PlaceMarkOn puts them.)
    local size = (daylight or (tile.Icon and tile.Icon:GetHeight() or 0) >= 36) and 13 or 11
    o.mark = NewMark(o, size)
    o.coin = o:CreateTexture(nil, "OVERLAY", nil, 6)
    o.coin:SetTexture(COIN)
    o.coin:SetSize(size, size)
    return o
end

-- Puts overlay `o`'s upgrade mark and coin in its top right corner, left of
-- DaylightUI's own mark (its coin on the choice that sells for the most, at
-- the tile's right end) when the tile shows one.
local function PlaceMarkOn(o, tile)
    local spec = Spec(tile)
    local theirs = spec and spec.mark and rawget(tile, "mark")
    local x = -3 - OUTSET - (theirs and Num(theirs:GetWidth()) + 10 or 0)
    for _, t in ipairs({ o.mark, o.coin }) do
        t:ClearAllPoints()
        t:SetPoint("TOPRIGHT", o, "TOPRIGHT", x, -3 - OUTSET)
    end
end

-- The best pick's outline and tint in color `c`.
local function Paint(o, c)
    o.fill:SetColorTexture(c[1], c[2], c[3], 0.12)
    for _, e in ipairs(o.edges) do e:SetColorTexture(c[1], c[2], c[3], 0.9) end
end

local function ShowAll(textures, on)
    for _, t in ipairs(textures) do
        if on then t:Show() else t:Hide() end
    end
end

-- Whether the game's gold highlight of the choice you've picked is on `tile`
-- (on DaylightUI's tiles: its own).
local function Picked(tile)
    if Spec(tile) then return rawget(tile, "picked") == true end
    local h = QuestInfoItemHighlight
    return h and h:IsShown() and select(2, h:GetPoint(1)) == tile or false
end

-- The best pick's outline, but not on the choice you've picked: the game's
-- highlight frames it there, and two borders on top of each other look muddy
-- (the tint and the mark stay).
local function ShowOutline(o, tile)
    ShowAll(o.edges, o.best and not Picked(tile))
end

-- The item id among a reward info call's returns: (name, texture, count,
-- quality, usable, itemID, itemLevel) on this client, one place later while
-- the name hasn't loaded, so the largest number from the 6th on (as the dev
-- scan reads them).
local function InfoItemId(...)
    local id
    for i = 6, math.min(select("#", ...), 9) do
        local v = select(i, ...)
        if type(v) == "number" and (not id or v > id) then id = v end
    end
    return id
end

-- The item id of reward `i` of kind `kind` ("choice", or "reward" for one
-- you always get), and its link when the game gives one (random suffixes).
-- `questLog`: the quest log's or the map's quest, else the NPC's.
-- `questID`: that log quest (DaylightUI's journal), else the selected one.
local function RewardItem(kind, i, questLog, questID)
    local GetLink = questLog and GetQuestLogItemLink or GetQuestItemLink
    local link = not questID and GetLink and GetLink(kind, i)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then return id, link end
    if not questLog then return GetQuestItemInfo and InfoItemId(GetQuestItemInfo(kind, i)) end
    local Info = kind == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
    return Info and InfoItemId(Info(i, questID))
end

-- What reward `i` of kind `kind` (item `id`, `link`) sells to a vendor for:
-- its price times how many the quest gives (from the reward info, as for
-- RewardItem). Nil, and `pending`, while the game hasn't loaded the item.
local function SellValue(id, link, kind, i, questLog, questID)
    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local price = id and GetInfo and select(11, GetInfo(link or id))
    if not price then
        pending = true
        return nil
    end
    local count
    if questLog then
        local Info = kind == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
        count = Info and select(3, Info(i, questID))
    elseif GetQuestItemInfo then
        count = select(3, GetQuestItemInfo(kind, i))
    end
    count = tonumber(count)
    return price * ((count and count >= 1) and count or 1)
end

-- What taking item `id` gains profile `p` (as its tooltip says, Tip.Gain), or
-- nil when it can't wear it now or it isn't gear. Sets `pending` while it can't tell.
local function Gain(id, link, p)
    if not id then
        pending = true
        return nil
    end
    local gain, wait = ns.Tooltip.Gain(id, link, p)
    if wait then pending = true end
    return gain
end

-- The upgrades among items `items` ({ { id, link } }): for your main spec
-- (`p`), else (Settings permitting) for your off specs, each against the
-- gear it is compared with. Returns { [index] = { gain, icon, label } }
-- (the line's icon and label, as item tooltips show them; an item that is
-- one for several off specs: its biggest gain), and the main spec's gain per
-- index (nil: not wearable now or not gear).
local function Upgrades(items, p)
    local ups, gains = {}, {}
    for i, it in ipairs(items) do
        gains[i] = Gain(it.id, it.link, p)
        if (gains[i] or 0) >= UPGRADE then ups[i] = { gain = gains[i], line = 1 } end
    end
    local lines = { p }
    if not next(ups) and ns.db.questOffSpec ~= false then
        for _, e in ipairs(ns.Tooltip.OffEntries(p)) do
            local profile = ns.Tooltip.EntryProfile(p, e)
            lines[#lines + 1] = profile
            for i, it in ipairs(items) do
                local gain = Gain(it.id, it.link, profile)
                if gain and gain >= UPGRADE and (not ups[i] or gain > ups[i].gain) then
                    ups[i] = { gain = gain, line = #lines, off = true }
                end
            end
        end
    end
    if next(ups) then
        local labels = ns.Tooltip.LineLabels(lines)
        for _, up in pairs(ups) do
            up.icon, up.label = ns.Tooltip.LineIcon(lines[up.line]), labels[up.line]
        end
    end
    return ups, gains
end

-- Marks reward tiles: the upgrades among the choices and among the items you
-- always get, the best pick among the choices. `entries`: the item tiles
-- shown, { tile, kind ("choice" or "reward"), index (the game's), questLog,
-- questID (a log quest that isn't the selected one), id and link (when
-- known) }. `all`: every tile that may have marks from before.
local function Mark(all, entries)
    local used, marks = {}, {} -- marks: [the mark of a tile with an upgrade] = its icon
    local p = ns.GetPlayer()
    -- The overlays not used this time go, their marks stopped (to start in
    -- step with the rest when they show again). The others stay up, so their
    -- marks' loops run on.
    local function Done()
        for _, tile in ipairs(all) do
            local o = overlays[tile]
            if o and not used[o] then
                o.lines, o.best = nil, nil
                if o.mark:IsShown() then ShowMark(o.mark, p, false) end
                o:Hide()
            end
        end
        ShowMarks(marks, p)
    end
    if #entries == 0 or ns.db.questMarks == false then return Done() end
    local items = {}
    for i, e in ipairs(entries) do
        if e.id then
            items[i] = { id = e.id, link = e.link }
        else
            local id, link = RewardItem(e.kind, e.index, e.questLog, e.questID)
            items[i] = { id = id, link = link }
        end
    end
    -- The choices and the items you always get each on their own, so an
    -- upgrade for your main spec among the latter doesn't hide an off-spec
    -- one among the choices.
    local ups = {}
    for _, kind in ipairs({ "choice", "reward" }) do
        local group, at = {}, {}
        for i, e in ipairs(entries) do
            if e.kind == kind then group[#group + 1], at[#at + 1] = items[i], i end
        end
        for j, up in pairs((Upgrades(group, p))) do ups[at[j]] = up end
    end
    -- The best pick among the choices: the biggest upgrade for your main
    -- spec, else for an off spec; with none, the one that sells for the most.
    local mainTop, offTop, valueTop, values, choices = nil, nil, nil, {}, 0
    for i, e in ipairs(entries) do
        local up = e.kind == "choice" and ups[i]
        if e.kind == "choice" then choices = choices + 1 end
        if up and not up.off and (not mainTop or up.gain > ups[mainTop].gain) then mainTop = i end
        if up and up.off and (not offTop or up.gain > ups[offTop].gain) then offTop = i end
    end
    local top = mainTop or offTop
    if not top then
        for i, e in ipairs(entries) do
            if e.kind == "choice" then
                values[i] = SellValue(items[i].id, items[i].link, e.kind, e.index, e.questLog, e.questID)
                if (values[i] or 0) > 0 and (not valueTop or values[i] > values[valueTop]) then valueTop = i end
            end
        end
        top = valueTop
    end
    if choices < 2 then top = nil end
    for i, e in ipairs(entries) do
        local tile = e.tile
        local best, up = i == top, ups[i]
        if best or up then
            local o = overlays[tile] or NewOverlay(tile)
            overlays[tile] = o
            used[o] = true
            o:SetFrameLevel(tile:GetFrameLevel() + 5) -- over UI addons' borders on the tile
            -- Its left and right edges where the scroll frame still shows them.
            local cutL, cutR = Overhang(tile)
            o:SetPoint("TOPLEFT", tile, "TOPLEFT", cutL - OUTSET, OUTSET)
            o:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", OUTSET - cutR, -OUTSET)
            PlaceMarkOn(o, tile)
            local forPrice = best and i == valueTop
            o.best = best
            ShowAll({ o.fill }, best)
            ShowOutline(o, tile)
            if best then
                Paint(o, forPrice and GOLD or GREEN)
                Outline(o, PixelUtil and PixelUtil.GetNearestPixelSize(1, o:GetEffectiveScale(), 2) or 1)
            end
            -- (DaylightUI's NPC window puts a coin of its own on that choice.)
            local spec = Spec(tile)
            ShowAll({ o.coin }, forPrice and not (spec and spec.mark))
            if up then
                marks[o.mark] = up.icon
            elseif o.mark:IsShown() then
                ShowMark(o.mark, p, false)
            end
            o.lines = nil
            if forPrice then
                o.lines = { L["No upgrade for your specs: this one sells for the most"] }
            elseif best and i == offTop then
                o.lines = { string.format(L["Best pick of this quest's choices for %s"], up.label) }
            elseif best then
                o.lines = { L["Best pick of this quest's choices"] }
            end
            o:Show()
        end
    end
    Done()
end

-- Marks the item tiles of the game's rewards frame `frame`.
local function Update(frame, questLog)
    local all, entries = frame.RewardButtons or {}, {}
    for _, tile in ipairs(all) do
        if (tile.type == "choice" or tile.type == "reward") and tile.objectType == "item" and tile:IsShown() then
            entries[#entries + 1] = { tile = tile, kind = tile.type, index = tile:GetID(), questLog = questLog }
        end
    end
    Mark(all, entries)
end

-- Whether the reward of the NPC's quest with link `link` gets the upgrade
-- mark, by the tiles' rule: an upgrade for your main spec, else (when none of
-- its group, the choices or the items you always get, is one) for an off
-- spec. Second result: false while that can't be told yet. (Dialogue UI's
-- reward buttons: DialogueUI.lua.)
function QW.IsRewardUpgrade(link)
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if not id or ns.db.questMarks == false then return false, id ~= nil end
    local group, at
    for _, kind in ipairs({ "choice", "reward" }) do
        local Count = kind == "choice" and GetNumQuestChoices or GetNumQuestRewards
        local items = {}
        for i = 1, (Count and Count()) or 0 do
            local rid, rlink = RewardItem(kind, i, false)
            items[i] = { id = rid, link = rlink }
            if not at and (rlink == link or (not rlink and rid == id)) then at = i end
        end
        if at then
            group = items
            break
        end
    end
    if not group then group, at = { { id = id, link = link } }, 1 end
    local was = pending
    pending = nil
    local ups = Upgrades(group, ns.GetPlayer())
    local ready = not pending
    pending = was or pending
    return ups[at] ~= nil, ready
end

-- What reward tile `tile`'s marks mean, for its tooltip: lines of text, or
-- nil when it has none.
function QW.TipLines(tile)
    local o = overlays[tile]
    return o and o:IsShown() and tile:IsVisible() and o.lines or nil
end

---------------------------------------------------------------- the quest log's list

-- The item ids of quest `questID`'s rewards (choices and the rest): the
-- addon's quest data, else what the game says for a quest in your log.
local function RewardIds(questID)
    local q = ns.Quests and ns.Quests[questID]
    local r = q and q.rewards
    if r then
        local ids = {}
        for _, list in ipairs({ r.choices or {}, r.items or {} }) do
            for _, id in ipairs(list) do ids[#ids + 1] = id end
        end
        return ids
    end
    local ids = {}
    if GetNumQuestLogChoices and GetQuestLogChoiceInfo then
        for i = 1, GetNumQuestLogChoices(questID, true) or 0 do
            ids[#ids + 1] = InfoItemId(GetQuestLogChoiceInfo(i, questID))
        end
    end
    if GetNumQuestLogRewards and GetQuestLogRewardInfo then
        for i = 1, GetNumQuestLogRewards(questID) or 0 do
            ids[#ids + 1] = InfoItemId(GetQuestLogRewardInfo(i, questID))
        end
    end
    return ids
end

-- The icon of the line quest `questID`'s rewards hold an upgrade for: your
-- main spec's, else that of the off spec with the biggest one; nil when none.
local function UpgradeIcon(questID, p)
    local items = {}
    for i, id in ipairs(RewardIds(questID)) do items[i] = { id = id } end
    local ups = Upgrades(items, p)
    local best
    for i in ipairs(items) do
        if ups[i] and (not best or ups[i].gain > best.gain) then best = ups[i] end
    end
    return best and best.icon
end

-- The quest of a row of the quest log's list, nil for a header.
local function RowQuest(row)
    if row.questID then return row.questID end
    if row.info and row.info.questID then return row.info.questID end
    local info = row.questLogIndex and C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetInfo(row.questLogIndex)
    return info and not info.isHeader and info.questID or nil
end

-- The rows of the list that show a quest's title: the title pool's, else
-- each quest's topmost row (its objectives' rows, below it, have its id too).
local function TitleRows(contents)
    local rows = {}
    local pool = QuestScrollFrame.titleFramePool
    if pool and pool.EnumerateActive then
        for row in pool:EnumerateActive() do
            if row.Text and RowQuest(row) then rows[#rows + 1] = row end
        end
        return rows
    end
    local top = {} -- [questID] = its topmost row
    for _, row in ipairs({ contents:GetChildren() }) do
        local questID = row:IsShown() and row.Text and RowQuest(row)
        if questID and (not top[questID] or Num(row:GetTop()) > Num(top[questID]:GetTop())) then
            top[questID] = row
        end
    end
    for _, row in pairs(top) do rows[#rows + 1] = row end
    return rows
end

-- [questID] = the quest's upgrade mark in the list, made on first use. On the
-- list, not on a row: the game hands its rows out afresh on every update of
-- the list (hiding them all first), and a mark that stays with its quest
-- runs on through that.
local rowMarks = {}

-- Puts the list's upgrade mark `m` where the first line of its row's title
-- ends: the title's whole width, unless it wraps.
local function PlaceMark(m)
    local text = m.row.Text
    local width = math.min(Num(text:GetStringWidth()), Num(text:GetWidth()))
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", text, "TOPLEFT", width + 3, 0)
end

local function PlaceMarks()
    for _, m in pairs(rowMarks) do
        if m:IsShown() and m.row:IsShown() then PlaceMark(m) end
    end
end

-- The upgrade mark (as on the reward tiles) right after the title of each
-- quest in the list with an upgrade among its rewards, on the title's first
-- line, as tall as its text. (Left of the title is the quest's own icon,
-- right of the row its tracking box.) All of them in step.
local function MarkRows()
    local contents = QuestScrollFrame and QuestScrollFrame.Contents
    if not contents then return end
    local p = ns.GetPlayer()
    local want = {} -- [questID] = its row
    local marks = {} -- [mark] = its icon
    if ns.db.questMarks ~= false then
        for _, row in ipairs(TitleRows(contents)) do
            local questID = RowQuest(row)
            local icon = UpgradeIcon(questID, p)
            if icon then
                local m = rowMarks[questID]
                if not m then
                    local _, size = row.Text:GetFont()
                    m = NewMark(contents, math.floor(Num(size) > 0 and size + 0.5 or 12))
                    m:Hide()
                    rowMarks[questID] = m
                end
                m.row = row
                m:SetFrameLevel(row:GetFrameLevel() + 2) -- over its row
                PlaceMark(m)
                want[questID], marks[m] = row, icon
            end
        end
    end
    for questID, m in pairs(rowMarks) do
        if not want[questID] and m:IsShown() then ShowMark(m, p, false) end
    end
    ShowMarks(marks, p)
end

---------------------------------------------------------------- DaylightUI

-- DaylightUI (a UI suite) draws windows of its own in place of the game's:
-- the NPC's quest window (DaylightUINpc, its API.GetFrame("npc")) and the
-- quest log over the map (DaylightUIQuestJournal, with a list page and a
-- quest page). Their rewards are its window kit's item tiles: Buttons with
-- `spec` (what the tile was filled with; its link() gives the item's link),
-- `edge` (the icon's quality outline), `picked` and `mark` (its own coin on
-- the choice that sells for the most); the list's rows have `quest` ({ id })
-- and `title`. DaylightUI asks addons not to hook its functions and has no
-- call for these windows, so while one of them shows we look at it a few
-- times a second and mark it again when what it shows has changed (each fill
-- hands its tiles new specs). Same marks, same rules as on the game's windows.

local daylightSeen = {} -- [page] = what it showed when last marked
local questOpen -- the NPC is on a quest (DaylightUI's NPC window also does gossip, vendors and trainers)

-- The shown frames under `root` that pass `test` (not looking inside those).
local function Find(root, test, out)
    for _, c in ipairs({ root:GetChildren() }) do
        if c:IsShown() then
            if test(c) then out[#out + 1] = c else Find(c, test, out) end
        end
    end
    return out
end

local function IsTile(c)
    local spec = Spec(c)
    return spec ~= nil and type(spec.link) == "function" and rawget(c, "edge") ~= nil
end

local function IsRow(c)
    local q = rawget(c, "quest")
    return type(q) == "table" and type(q.id) == "number" and type(rawget(c, "title")) == "table"
end

-- A tile's item link and item id; nil while the item hasn't loaded (or isn't one).
local function TileLink(tile)
    local ok, link = pcall(Spec(tile).link)
    local id = ok and type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then return link, id end
end

-- What a page's tiles or rows show, to tell when to mark it again.
local function Seen(frames)
    local parts = {}
    for i, f in ipairs(frames) do
        local q, title = rawget(f, "quest"), rawget(f, "title")
        parts[i] = tostring(f) .. tostring(Spec(f) or q and q.id) .. (rawget(f, "picked") and "+" or "")
            .. (q and title and tostring(title:GetText()) or "")
    end
    return table.concat(parts, ";")
end

-- The NPC window's tiles, matched to the quest's rewards by their links.
local function NpcEntries(tiles)
    local entries, rewards = {}, {}
    if not questOpen then return entries end
    for _, kind in ipairs({ "choice", "reward" }) do
        local Count = kind == "choice" and GetNumQuestChoices or GetNumQuestRewards
        for i = 1, (Count and Count()) or 0 do
            local link = GetQuestItemLink and GetQuestItemLink(kind, i)
            if link then
                rewards[#rewards + 1] = { kind = kind, index = i, link = link }
            else
                pending = true
            end
        end
    end
    for _, tile in ipairs(tiles) do
        local link, id = TileLink(tile)
        for _, r in ipairs(rewards) do
            if link and not r.used and r.link == link then
                r.used = true
                entries[#entries + 1] = { tile = tile, kind = r.kind, index = r.index, id = id, link = link }
                break
            end
        end
    end
    return entries
end

-- Top to bottom, then left to right.
local function Order(a, b)
    local ay, by = Num(a:GetTop()), Num(b:GetTop())
    if math.abs(ay - by) > 1 then return ay > by end
    return Num(a:GetLeft()) < Num(b:GetLeft())
end

-- The item ids of log quest `questID`'s rewards of kind `kind` (false: not loaded).
local function LogRewardIds(questID, kind)
    local Count = kind == "choice" and GetNumQuestLogChoices or GetNumQuestLogRewards
    local Info = kind == "choice" and GetQuestLogChoiceInfo or GetQuestLogRewardInfo
    local ids = {}
    if not (Count and Info) then return ids end
    local n = kind == "choice" and Count(questID, true) or Count(questID)
    for i = 1, tonumber(n) or 0 do ids[i] = InfoItemId(Info(i, questID)) or false end
    return ids
end

-- The journal's quest page: its tiles, in the order shown, are the quest's
-- items you always get, then its choices. The quest is the one in your log
-- whose rewards are exactly these items (the page doesn't say which it is).
local function JournalEntries(tiles)
    local entries, links, ids = {}, {}, {}
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return entries end
    table.sort(tiles, Order)
    for i, tile in ipairs(tiles) do
        links[i], ids[i] = TileLink(tile)
        if not ids[i] then
            pending = true
            return entries
        end
    end
    for n = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
        local info = C_QuestLog.GetInfo(n)
        local questID = info and not info.isHeader and info.questID
        if questID then
            local given, choices = LogRewardIds(questID, "reward"), LogRewardIds(questID, "choice")
            local match = #given + #choices == #tiles
            for i = 1, match and #tiles or 0 do
                if (i <= #given and given[i] or choices[i - #given]) ~= ids[i] then
                    match = false
                    break
                end
            end
            if match then
                for i, tile in ipairs(tiles) do
                    local choice = i > #given
                    entries[i] = { tile = tile, kind = choice and "choice" or "reward",
                        index = choice and i - #given or i, questLog = true, questID = questID,
                        id = ids[i], link = links[i] }
                end
                return entries
            end
        end
    end
    return entries
end

-- [questID] = its upgrade mark on the journal's list, made on first use.
local daylightRowMarks = {}

-- The journal's list: the upgrade mark right after the title of each quest
-- with an upgrade among its rewards, as on the game's list (MarkRows).
local function MarkDaylightRows(rows)
    local p = ns.GetPlayer()
    local want, marks = {}, {}
    if ns.db.questMarks ~= false then
        for _, row in ipairs(rows) do
            local questID, title = row.quest.id, row.title
            local icon = UpgradeIcon(questID, p)
            if icon then
                local m = daylightRowMarks[questID]
                if not m then
                    local _, size = title:GetFont()
                    m = NewMark(row:GetParent(), math.floor(Num(size) > 0 and size + 0.5 or 12))
                    m:Hide()
                    daylightRowMarks[questID] = m
                end
                if m:GetParent() ~= row:GetParent() then m:SetParent(row:GetParent()) end
                m:SetFrameLevel(row:GetFrameLevel() + 2) -- over its row
                local width = math.min(Num(title:GetStringWidth()), Num(title:GetWidth()))
                m:ClearAllPoints()
                m:SetPoint("LEFT", title, "LEFT", width + 3, 0)
                want[questID], marks[m] = true, icon
            end
        end
    end
    for questID, m in pairs(daylightRowMarks) do
        if not want[questID] and m:IsShown() then ShowMark(m, p, false) end
    end
    ShowMarks(marks, p)
end

-- Marks page `key` (`frame`, its tiles or rows passing `test`) with `mark`
-- when it shows and what it shows has changed.
local function Page(key, frame, test, mark)
    if type(frame) ~= "table" or not frame:IsVisible() then
        daylightSeen[key] = nil
        return
    end
    local found = Find(frame, test, {})
    local seen = Seen(found)
    if seen == daylightSeen[key] then return end
    daylightSeen[key] = seen
    mark(found)
end

local function DaylightLook()
    local API = rawget(_G, "DaylightUI") and DaylightUI.API
    local npc = API and API.GetFrame and API.GetFrame("npc") or rawget(_G, "DaylightUINpc")
    Page("npc", npc, IsTile, function(tiles) Mark(tiles, NpcEntries(tiles)) end)
    local journal = rawget(_G, "DaylightUIQuestJournal")
    if type(journal) == "table" then
        Page("quest", rawget(journal, "quest"), IsTile, function(tiles) Mark(tiles, JournalEntries(tiles)) end)
        Page("list", rawget(journal, "list"), IsRow, MarkDaylightRows)
    end
end

---------------------------------------------------------------- hooks

local reported -- report the first error only: it would repeat on every quest
local function Safe(fn, ...)
    if not (ns.db and ns.charDB) then return end -- (the quest log updates while the game loads)
    local ok, err = pcall(fn, ...)
    if not ok and not reported then
        reported = true
        if geterrorhandler then geterrorhandler()(err) else error(err) end
    end
end

-- QuestInfo_Display(template, parentFrame, acceptButton, material, mapView)
-- fills the tiles of QuestInfoFrame.rewardsFrame: the map's own frame with
-- mapView, else the one the NPC's window and the quest log share.
local function OnDisplay(_, _, _, _, mapView)
    local frame = QuestInfoFrame and QuestInfoFrame.rewardsFrame
        or (mapView and MapQuestInfoRewardsFrame or QuestInfoRewardsFrame)
    if not frame then return end
    shown[frame] = (QuestInfoFrame and QuestInfoFrame.questLog) and true or false
    pending = nil
    Safe(Update, frame, shown[frame])
end

local queued
local function Refresh()
    queued = nil
    pending = nil
    for frame, questLog in pairs(shown) do
        if frame:IsVisible() then Safe(Update, frame, questLog) end
    end
    if QuestScrollFrame and QuestScrollFrame:IsVisible() then Safe(MarkRows) end
    daylightSeen = {} -- (DaylightUI's windows: marked again on the next look)
end
QW.Refresh = Refresh -- (Settings: the Quest rewards switches)

-- The game's quest code may load after this addon: hook it once it's there.
local hooked = {}
local function Hook()
    if not hooked.display and type(QuestInfo_Display) == "function" then
        hooked.display = true
        hooksecurefunc("QuestInfo_Display", OnDisplay)
    end
    if not hooked.pick and type(QuestInfoItem_OnClick) == "function" then
        hooked.pick = true
        hooksecurefunc("QuestInfoItem_OnClick", function()
            Safe(function()
                for tile, o in pairs(overlays) do ShowOutline(o, tile) end
            end)
        end)
    end
    if not hooked.list and type(QuestLogQuests_Update) == "function" then
        hooked.list = true
        -- Right away, so no mark shows by a row handed to another quest; and
        -- placed again a frame later, after other addons' changes to the
        -- titles (a level prefix such as "[30]").
        hooksecurefunc("QuestLogQuests_Update", function()
            Safe(MarkRows)
            C_Timer.After(0, function() Safe(PlaceMarks) end)
        end)
    end
    if not hooked.daylight and rawget(_G, "DaylightUI") then
        hooked.daylight = true
        -- DaylightUI's windows: a look five times a second (DaylightUI section).
        local wait = 0
        CreateFrame("Frame"):SetScript("OnUpdate", function(_, elapsed)
            wait = wait - elapsed
            if wait > 0 then return end
            wait = 0.2
            Safe(DaylightLook)
        end)
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "EQUIPMENT_SETS_CHANGED",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        Hook()
    elseif event:find("^QUEST_") then
        questOpen = event ~= "QUEST_FINISHED"
    elseif (pending or event ~= "GET_ITEM_INFO_RECEIVED") and not queued then
        -- A moment later: after Tooltip.lua has dropped its rankings (bags
        -- and sets: the gear compared with), and once per burst of items
        -- loading or bag changes.
        queued = true
        C_Timer.After(0.1, Refresh)
    end
end)
