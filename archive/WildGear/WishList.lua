local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Wish list: items you want, starred on the window's lists, kept per
-- character (ns.charDB.wish = { { id, suffix? }, ... } in the order starred)
-- and shown on screen in a small tracker you can move and fold.
--   * The star: on the Best in slot rows in place of the rank number, on the
--     Dungeon loot and Quests tab rows in the gutter left of the slot. It
--     shows on hover, empty (filled but fainter over the star itself;
--     click: wish for it), and stays, filled, on wished items (click: take
--     it off). In the theme's look (SetLook). No star on items you have
--     (worn, in bags or bank). Starring one flies it to the tracker
--     (WL.Added: a puff, a leaf or star in an arc, its line fading in).
--   * The tracker: one line per item: star, icon, name, gain for your main
--     spec at your level (or the level it unlocks at), and below where it
--     comes from (a quest with your progress on it, a boss and dungeon, a
--     profession, a BoE drop). Hover: the item's tooltip; click: the window
--     on its slot; right-click a quest's: pin its giver; shift/ctrl-click as
--     usual; its star takes it off. Drag the title to move it, click it to fold.
--   * An item you get (worn, in bags or bank) leaves the list by itself, with
--     a line in chat; in sight on the tracker, after playing Got it on its
--     line (Finish: a burst, the epic loot sound, a slow fade away).
--   * While the window is open the list is on it instead: a side panel
--     under My gear (in My gear's place while that is closed), with as many
--     lines as fit above the screen's bottom and the rest as a count. The
--     list moves there and back with a flourish (WL.Window): each line's
--     star flies across and its line fades in where it lands.
-- Settings' Shown on: Wish list switch hides the tracker (wishTracker =
-- false); so does its key binding. The window's panel shows either way.
-- The tracker shows TRACKER_LINES lines, then the rest as a count; a click
-- on the count shows them all (as many as fit on the screen).
-- Position, fold and that are for all characters (ns.db.wishPos,
-- ns.db.wishFolded, ns.db.wishExpanded; the panel's own fold:
-- ns.db.wishDockFolded).

local WL = {}
ns.WishList = WL

local WIDTH = 230
local HEADER_H = 20
local LINE_H = 30 -- (at least: Draw makes it fit the name and source's font, FitLineHeight)
local ICON = 22
local STAR = 14
local TRACKER_LINES = 8 -- the tracker's lines at most; the rest as a count under them ("+4")
local MORE_H = 18 -- that count's line
local FOOT_H = 22 -- the window's panel's foot: that count, and Clear all
local GREEN, GREY = "|cff33ff99", "|cff888888"
local QUEST_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:0|t "

local STAR_ON = "auctionhouse-icon-favorite" -- (the Classic theme's)
local STAR_FALLBACK = "PetJournal-FavoritesIcon"
local STAR_FILE = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Star" -- (the Modern theme's)
local STAR_EMPTY_FILE = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\StarEmpty"
local ownArt -- whether the client has the Auction House stars (looked up once)

---------------------------------------------------------------- the list

local function List()
    local db = ns.charDB
    if not db then return {} end
    db.wish = db.wish or {}
    return db.wish
end

-- The list can hold an item more than once, a line per random suffix (the
-- same green "of the Monkey" and "of the Eagle"); an entry without a suffix
-- stands for the item with any, and is then its only one.

-- Where item `id` with random suffix `suffix` is on the list (nil: the entry
-- without one), or nil.
local function IndexOf(id, suffix)
    for i, e in ipairs(List()) do
        if e.id == id and e.suffix == suffix then return i end
    end
end

-- The first entry of item `id`, any suffix.
local function FirstOf(id)
    for i, e in ipairs(List()) do
        if e.id == id then return i end
    end
end

-- Whether item `id` is on the list: without `suffix`, with any suffix; with
-- it, with that one (or as the item with any).
function WL.Has(id, suffix)
    if id == nil then return false end
    if suffix == nil then return FirstOf(id) ~= nil end
    return (IndexOf(id, suffix) or IndexOf(id, nil)) ~= nil
end

-- Item `id`'s link has random suffix `suffix` (nil: any).
local function IsIt(link, id, suffix)
    if not (link and tonumber(link:match("item:(%d+)")) == id) then return false end
    return suffix == nil or ns.LinkSuffix(link, ns.Items[id]) == suffix
end

-- Whether this character has item `id`: worn, in the bags or in the bank.
-- With random suffix `suffix`, that one: worn or in the bags (the bank's
-- links aren't at hand; a copy put in the bank was in the bags first, and
-- left the list then).
local function Owned(id, suffix)
    local Count = (C_Item and C_Item.GetItemCount) or GetItemCount
    local worn = C_Item and C_Item.IsEquippedItem and C_Item.IsEquippedItem(id)
    if not worn and not (Count and (Count(id, true) or 0) > 0) then return false end
    if suffix == nil then return true end
    for invSlot = 1, 19 do
        if IsIt(GetInventoryItemLink and GetInventoryItemLink("player", invSlot), id, suffix) then return true end
    end
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemLink) then return false end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            if IsIt(C.GetContainerItemLink(bag, slot), id, suffix) then return true end
        end
    end
    return false
end

local stars = {} -- every row with a star, to repaint when the list changes

local Paint
local function Changed()
    for _, row in ipairs(stars) do
        if row:IsVisible() then Paint(row) end
    end
    WL.Refresh()
end

-- Puts item `id` (random suffix `suffix`, an ns.Suffixes id) on the list,
-- or takes it off: without a suffix, every entry of the item; with one, that
-- one (or the item's entry without a suffix). On it with another suffix, it
-- gets a line for this one too. Returns whether it is on the list now.
function WL.Toggle(id, suffix)
    if not (id and ns.charDB) then return false end
    local list = List()
    local on = not WL.Has(id, suffix)
    if on then
        list[#list + 1] = { id = id, suffix = suffix }
    elseif suffix == nil then
        for i = #list, 1, -1 do
            if list[i].id == id then table.remove(list, i) end
        end
    else
        table.remove(list, IndexOf(id, suffix) or IndexOf(id, nil))
    end
    Changed()
    return on
end

-- Items you got leave the list, each with a line in chat. `animate`: they
-- stay on it a moment, their tracker lines playing Got it (Finish, below),
-- and their entries are returned; else they go at once.
local tracker -- (the tracker's frame, made when first shown: below)
local dock -- (the window's panel, likewise: the list is on it while the window is open)
local finishing = {} -- entry -> true while its line plays (not saved: a reload just drops it)

local function WindowOpen()
    local window = _G.WildGearFrame
    return window ~= nil and window:IsShown()
end

-- The frame the list is on now (nil before it's made): the window's panel
-- while the window is open, else the tracker.
local function Live()
    if WindowOpen() then return dock end
    return tracker
end

-- (`limit`: how many lines are in sight; an item further down goes at once)
local function DropOwned(animate, limit)
    local list, started = List(), {}
    for i = #list, 1, -1 do
        local e = list[i]
        if not finishing[e] and Owned(e.id, e.suffix) then
            ns.Printf(L["Got %s: off your wish list."], ns.ItemLink(e.id, e.suffix))
            if animate and i <= limit then
                finishing[e] = true
                started[#started + 1] = e
            else
                table.remove(list, i)
                -- (its line folded away: just the sound; not at login, when no frame is made yet)
                local live = Live()
                if live and live:IsVisible() then WL.Chime() end
            end
        end
    end
    return started
end

---------------------------------------------------------------- the star

-- The star's look, by theme (tools\starart.py draws the textures). Wished:
-- filled. Over the star itself: filled, fainter (what a click does). Over
-- the row: empty.
--   Modern: a flat star, the accent for wished, light grey for empty.
--   Classic: the game's Auction House star, without its color for empty (its
--     own outline one is too dark to see on the window).
--   A skin with a star (T.SkinPart("star"): { on, off }, its season's while
--     that shows): its own, as drawn.
local function SetLook(tex, on, over)
    local T = ns.Theme
    local skin = T.SkinPart("star")
    local filled = on or over
    if skin then
        tex:SetTexture(filled and skin.on or skin.off)
        tex:SetVertexColor(1, 1, 1)
    elseif T.Classic() then
        if ownArt == nil then
            ownArt = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(STAR_ON) ~= nil or false
        end
        tex:SetAtlas(ownArt and STAR_ON or STAR_FALLBACK)
        tex:SetDesaturated(not filled)
        tex:SetAlpha((on and 1) or (over and 0.75) or 0.9)
        return
    else
        tex:SetTexture(filled and STAR_FILE or STAR_EMPTY_FILE)
        if filled then tex:SetVertexColor(T.Accent()) else tex:SetVertexColor(0.85, 0.85, 0.85) end
    end
    tex:SetAlpha((on and 1) or (over and 0.7) or 1)
end

-- A filled star in the theme's look on texture `tex` (What's new's icon).
function WL.PaintStar(tex)
    SetLook(tex, true)
end

-- Whether every item of `entries` ({ { id, suffix? }, ... }) is on the list.
local function AllWished(entries)
    for _, e in ipairs(entries) do
        if not WL.Has(e.id, e.suffix) then return false end
    end
    return true
end

Paint = function(row)
    local b, id = row.star, row.wishId
    if row.wishAll then -- (a star for several items: always in sight, filled once all are wished)
        SetLook(b.tex, AllWished(row.wishAll), b:IsMouseOver())
        b:Show()
        return
    end
    local on = WL.Has(id, row.wishSuffix)
    if id and (on or row:IsMouseOver()) then
        SetLook(b.tex, on, b:IsMouseOver())
        b:Show()
        if row.starCover then row.starCover:SetAlpha(0) end
    else
        b:Hide()
        if row.starCover then row.starCover:SetAlpha(1) end
    end
end

-- A star on list row `row` (placed by the caller), shown over `cover` (the
-- rank number, hidden while the star shows) or on its own. WL.SetStar
-- gives it its item.
function WL.Star(row, cover)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(STAR, STAR)
    b:SetFrameLevel(row:GetFrameLevel() + 3)
    b.tex = b:CreateTexture(nil, "OVERLAY")
    b.tex:SetAllPoints()
    b:RegisterForClicks("LeftButtonUp")
    -- A star for several items says what a click does, in a bubble under it.
    local function Tip()
        if not (row.wishAll and b:IsMouseOver()) then return end
        ns.Widgets.ShowBubble(b, AllWished(row.wishAll) and L["Take all of these off your wish list."]
            or L["Add all of these to your wish list."], { width = 200 })
    end
    b:SetScript("OnClick", function()
        if row.wishAll then
            WL.ToggleAll(row)
            return Tip() -- (the other way round now)
        end
        local id = row.wishId
        if WL.Toggle(id, row.wishSuffix) and not row.inTracker then WL.Added(row, id, row.wishSuffix) end
    end)
    -- Still over the row: its tooltip stays.
    b:SetScript("OnEnter", function()
        local enter = row:GetScript("OnEnter")
        if enter then enter(row) end
        Tip()
        Paint(row)
    end)
    b:SetScript("OnLeave", function()
        local leave = row:GetScript("OnLeave")
        if leave then leave(row) end
        if row.wishAll then ns.Widgets.HideBubble() end
        Paint(row)
    end)
    row:HookScript("OnEnter", Paint)
    row:HookScript("OnLeave", Paint)
    b:Hide()
    row.star, row.starCover = b, cover
    stars[#stars + 1] = row
    return b
end

-- Gives row `row`'s star item `id` (nil: no star), with random suffix
-- `suffix`. Items you have (with that suffix) get none, unless on the list already.
function WL.SetStar(row, id, suffix)
    if id and not WL.Has(id, suffix) and Owned(id, suffix) then id = nil end
    row.wishId, row.wishSuffix, row.wishAll = id, suffix, nil
    Paint(row)
end

-- Makes row `row`'s star stand for several items, `items` ({ { id, suffix? },
-- ... }; a Summary section's picks, on its header): a click wishes for them
-- all, or, all wished, takes them all off (WL.ToggleAll). Items you have
-- don't count, as they get no star; with none left, no star (nil too).
function WL.SetStarAll(row, items)
    local entries, seen = {}, {}
    for _, e in ipairs(items or {}) do
        local key = e.id .. ":" .. (e.suffix or "")
        if not seen[key] and (WL.Has(e.id, e.suffix) or not Owned(e.id, e.suffix)) then
            seen[key] = true
            entries[#entries + 1] = { id = e.id, suffix = e.suffix }
        end
    end
    row.wishId, row.wishSuffix, row.wishAll = nil, nil, entries[1] and entries or nil
    Paint(row)
end

---------------------------------------------------------------- the tracker

local function On()
    return ns.db and ns.db.wishTracker ~= false
end

-- The window's slot (ns.SlotGroups key) an item goes in.
local function SlotKey(item)
    local inv = item and item.slot
    if inv == 14 or inv == 22 or inv == 23 then return "offhand" end
    if inv == 13 or inv == 17 or inv == 21 then return "mainhand" end
    for _, g in ipairs(ns.SlotGroups) do
        if g.inv and g.inv[inv] then return g.key end
    end
end

-- The source to show: a quest in your log (one ready to turn in first),
-- else the first one.
local function PickSource(item)
    local best, active
    for _, s in ipairs(item and item.sources or {}) do
        if s.type == "quest" then
            local ready = C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(s.id)
            if ready then return s, "ready" end
            if not active and ns.QuestState(s.id) == "active" then best, active = s, "active" end
        end
    end
    if best then return best, active end
    local s = item and item.sources and item.sources[1]
    return s, s and s.type == "quest" and ns.QuestState(s.id) or nil
end

local STATE_TEXT = {
    ready = function() return GREEN .. L["ready to turn in"] .. "|r" end,
    active = function() return ns.ACTIVE_HEX .. L["in log"] .. "|r" end,
    done = function() return GREY .. L["completed"] .. "|r" end,
}

local function SourceText(s, state)
    if not s then return "" end
    local text = ns.DescribeSource(s, nil, s.type == "quest" and QUEST_ICON or nil)
    if state and STATE_TEXT[state] then text = text .. "  " .. STATE_TEXT[state]() end
    return text
end

-- Its gain for your main spec at your level, or the level it unlocks at.
local function GainText(e, item)
    local need = item and item.reqLevel or 0
    if need > (UnitLevel("player") or 0) then return GREY .. string.format(L["lvl %d"], need) .. "|r" end
    local gain = ns.Tooltip.Gain(e.id, ns.SuffixLink(e.id, e.suffix))
    if not gain then return "" end
    if gain >= 0.05 then return GREEN .. string.format("+%.1f", gain) .. "|r" end
    return GREY .. string.format("%.1f", gain) .. "|r"
end

local function OnLineEnter(line)
    local e = line.e
    if not e then return end
    GameTooltip:SetOwner(line, "ANCHOR_LEFT")
    GameTooltip:SetHyperlink(ns.ItemLink(e.id, e.suffix))
    GameTooltip:Show()
end

local function OnLineClick(line, button)
    local e = line.e
    if not e then return end
    if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        HandleModifiedItemClick(ns.ItemLink(e.id, e.suffix))
    elseif button == "RightButton" then
        if line.src and line.src.type == "quest" then ns.PinQuest(line.src) end
    else
        local key = SlotKey(ns.Items[e.id])
        if key then ns.UI.ShowSlot(key) end
    end
end

-- A line of `parent`, the tracker or the window's panel (line.host).
local function CreateLine(parent)
    local line = CreateFrame("Button", nil, parent)
    line.host = parent
    line:SetSize(parent.lineWidth, LINE_H)
    line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.Widgets.AddHighlight(line)
    line:SetScript("OnEnter", OnLineEnter)
    line:SetScript("OnLeave", function() GameTooltip:Hide() end)
    line:SetScript("OnClick", OnLineClick)

    local star = WL.Star(line)
    star:SetPoint("LEFT", line, "LEFT", 2, 0)
    line.inTracker = true
    line.icon = line:CreateTexture(nil, "ARTWORK")
    line.icon:SetSize(ICON, ICON)
    line.icon:SetPoint("LEFT", line, "LEFT", STAR + 6, 0)
    ns.Widgets.IconBorder(line.icon)

    -- The name just above the line's middle and the source just under it, so
    -- a taller font (zhCN, zhTW, koKR, or a bigger text size) spreads them
    -- apart instead of over each other.
    line.gain = line:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    line.gain:SetPoint("BOTTOMRIGHT", line, "RIGHT", -2, 1)
    line.gain:SetJustifyH("RIGHT")
    line.name = line:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    line.name:SetPoint("BOTTOMLEFT", line.icon, "RIGHT", 6, 1)
    line.name:SetPoint("BOTTOMRIGHT", line.gain, "BOTTOMLEFT", -6, 0)
    line.name:SetJustifyH("LEFT")
    line.name:SetWordWrap(false)
    line.source = line:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    line.source:SetPoint("TOPLEFT", line.icon, "RIGHT", 6, -1)
    line.source:SetPoint("TOPRIGHT", line, "RIGHT", -2, -1)
    line.source:SetJustifyH("LEFT")
    line.source:SetWordWrap(false)
    return line
end

local Place -- (below)

-- Saved by the top edge, so the list grows downwards (StopMovingOrSizing
-- anchors to the nearest screen point: BOTTOM* low on the screen grew it
-- upwards, CENTER both ways); clamped to the screen, a long list that meets
-- the bottom is pushed up, and comes back down when it shrinks.
local function SavePosition(f)
    local left, right, top = f:GetLeft(), f:GetRight(), f:GetTop()
    if not (left and top) then return end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local point, x
    if (left + right) / 2 > w / 2 then
        point, x = "TOPRIGHT", right - w
    else
        point, x = "TOPLEFT", left
    end
    ns.db.wishPos = { point = point, rel = point, x = x, y = top - h }
    Place(f)
end

function Place(f)
    f:ClearAllPoints()
    local pos = ns.db.wishPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.rel, pos.x, pos.y)
    else
        local k = f:GetScale() -- (offsets are in its own units)
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90 / k, -330 / k) -- under the quest tracker's first lines
    end
end

-- Settings' Wish list size (the display setting wishScale): the tracker
-- rescaled about its saved corner, which stays put on the screen.
local function ApplyScale(f)
    local old, new = f:GetScale(), ns.Theme.Get("wishScale")
    if math.abs(new - old) < 0.001 then return end
    local pos = ns.db.wishPos
    if pos then pos.x, pos.y = pos.x * old / new, pos.y * old / new end
    f:SetScale(new)
    Place(f)
end

local Draw -- (below)

-- Line `i`'s place on its frame, `dy` lower.
local function PlaceLine(line, i, dy)
    local host = line.host
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", host, "TOPLEFT", host.lineX, -host.top - (i - 1) * LINE_H - (dy or 0))
end

---------------------------------------------------------------- got it

-- An item you got plays out on its line before it leaves, in slow motion:
-- the star swells and settles with a gold burst spinning out behind it (a
-- skin with leaves: a handful of them, PlayLeaves) and a green bloom, the
-- epic loot sound; the line flashes green while a shine sweeps across it and
-- the gain says Got it; a short pause, then it flashes green again with a
-- second shine as it fades slowly where it is, and the lines under it slide
-- up into its place.
-- How much slower than the times written below it all plays (one knob for
-- the whole show; the lines sliding up after stay quick).
local SLOW = 1.8
-- The line fades from FADE_FROM to FINISH_TIME, seconds as played (not slowed).
local FADE_FROM, FINISH_TIME = 3.1, 4.8
local BURST = "Interface\\Cooldown\\star4"
local BLOOM = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Elwynn\\Glow" -- (a round white glow)
local SWEEP_W = 70

local function Anim(group, kind, delay, duration, smoothing)
    local a = group:CreateAnimation(kind)
    a:SetStartDelay(delay * SLOW)
    a:SetDuration(duration * SLOW)
    if smoothing then a:SetSmoothing(smoothing) end
    return a
end

local function Fade(group, from, to, delay, duration, smoothing)
    local a = Anim(group, "Alpha", delay, duration, smoothing)
    a:SetFromAlpha(from)
    a:SetToAlpha(to)
    return a
end

-- (scales in one group multiply: each `from` is where the one before ended)
local function Grow(group, from, to, delay, duration, smoothing)
    local a = Anim(group, "Scale", delay, duration, smoothing)
    if a.SetScaleFrom then
        a:SetScaleFrom(from, from)
        a:SetScaleTo(to, to)
    else
        a:SetScale(to / from, to / from)
    end
    a:SetOrigin("CENTER", 0, 0)
    return a
end

local function Move(group, x, y, delay, duration, smoothing)
    local a = Anim(group, "Translation", delay, duration, smoothing)
    a:SetOffset(x, y)
    return a
end

-- A white band fading in and out across, added on what's under it.
local function Sheen(parent)
    local band = CreateFrame("Frame", nil, parent)
    band:SetSize(SWEEP_W, LINE_H)
    local Color = CreateColor
    for half = 1, 2 do
        local t = band:CreateTexture(nil, "OVERLAY")
        t:SetSize(SWEEP_W / 2, LINE_H)
        t:SetPoint(half == 1 and "LEFT" or "RIGHT")
        t:SetColorTexture(1, 1, 1, 1)
        t:SetBlendMode("ADD")
        if Color and t.SetGradient then
            local clear, lit = Color(1, 1, 1, 0), Color(1, 1, 1, 0.45)
            t:SetGradient("HORIZONTAL", half == 1 and clear or lit, half == 1 and lit or clear)
        else
            t:SetAlpha(0.2)
        end
    end
    return band
end

-- The line's effects and their timeline, made when it first plays.
local function FinishFx(line)
    if line.fx then return line.fx end
    local fx = {}
    local star = line.star

    local flash = line:CreateTexture(nil, "BACKGROUND")
    flash:SetAllPoints()
    flash:SetColorTexture(0.2, 1, 0.6, 1)
    flash:SetAlpha(0)
    -- (a flash gone with the first shine; a pause; a second flash with the
    -- second shine, held while the line fades: the line's fade takes it along)
    local g = flash:CreateAnimationGroup()
    local again = FADE_FROM / SLOW
    Fade(g, 0, 0.35, 0, 0.15, "OUT")
    Fade(g, 0.35, 0, 0.6, 0.6, "IN")
    -- (ending at none, the line all but gone by then: the alpha an animation
    -- ends on can stay on the line, which shows the next item after)
    local hold = FINISH_TIME / SLOW - again - 0.12 - 0.15
    Fade(g, 0, 0.3, again, 0.12, "OUT")
    Fade(g, 0.3, 0.3, again + 0.12, hold)
    Fade(g, 0.3, 0, again + 0.12 + hold, 0.15)
    fx[#fx + 1] = g
    fx.flash = flash

    -- (the shines only show over the line: one with the flash, one as the
    -- line fades, fading with it)
    local clip = CreateFrame("Frame", nil, line)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    for _, sweep in ipairs({ { 0.1, 1.1 }, { FADE_FROM / SLOW, (FINISH_TIME - FADE_FROM) / SLOW } }) do
        local sheen = Sheen(clip)
        sheen:SetPoint("RIGHT", clip, "LEFT", 0, 0)
        g = sheen:CreateAnimationGroup()
        Move(g, (line:GetWidth() or WIDTH) + SWEEP_W, 0, sweep[1], sweep[2], "IN_OUT")
        fx[#fx + 1] = g
    end

    local bloom = line:CreateTexture(nil, "ARTWORK")
    bloom:SetTexture(BLOOM)
    bloom:SetBlendMode("ADD")
    bloom:SetVertexColor(0.3, 1, 0.55)
    bloom:SetSize(44, 44)
    bloom:SetPoint("CENTER", star, "CENTER")
    bloom:SetAlpha(0)
    g = bloom:CreateAnimationGroup()
    Fade(g, 0, 0.9, 0, 0.12)
    Fade(g, 0.9, 0, 0.3, 0.8, "IN")
    Grow(g, 0.4, 1.8, 0, 1.1, "OUT")
    fx[#fx + 1] = g

    local burst = line:CreateTexture(nil, "OVERLAY", nil, 7)
    burst:SetTexture(BURST)
    burst:SetBlendMode("ADD")
    burst:SetVertexColor(1, 0.85, 0.4)
    burst:SetSize(52, 52)
    burst:SetPoint("CENTER", star, "CENTER")
    burst:SetAlpha(0)
    g = burst:CreateAnimationGroup()
    Fade(g, 0, 1, 0, 0.08)
    Fade(g, 1, 0, 0.15, 0.7, "IN")
    Grow(g, 0.3, 1.7, 0, 0.85, "OUT")
    Anim(g, "Rotation", 0, 0.85, "OUT"):SetDegrees(-120)
    fx.burst = g -- (played unless the skin has leaves: PlayLeaves)

    -- The star swells, then settles back to its size: its texture, not its
    -- button (a frame's Scale animation ignores the origin, growing it from
    -- its bottom left corner: off to the top right).
    g = star.tex:CreateAnimationGroup()
    Grow(g, 1, 1.9, 0, 0.18, "OUT")
    Grow(g, 1, 1 / 1.9, 0.18, 0.35, "IN_OUT")
    fx[#fx + 1] = g

    -- Then the line fades slowly where it is (and stays gone till it's taken off).
    g = line:CreateAnimationGroup()
    g:SetToFinalAlpha(true)
    Fade(g, 1, 0, FADE_FROM / SLOW, (FINISH_TIME - FADE_FROM) / SLOW, "IN")
    fx[#fx + 1] = g
    fx.line = g

    line.fx = fx
    return fx
end

-- A skin with falling leaves (T.SkinPart("leaves"), its season's while that
-- shows: Elwynn's oak leaves, the harvest's autumn ones) throws a handful of
-- them from the star in place of the gold burst. Each is moved frame by frame
-- as a light leaf falls, like the window's own falling leaves (Widgets.lua,
-- Leaves):
--   * thrown up (within LEAF_CONE of straight up), gravity slowing it, the
--     air taking its speed (LEAF_DRAG: the sideways push dies away, and the
--     fall can't pass its own steady speed, LEAF_SPEED);
--   * fluttering as it falls: swinging side to side about once a second, the
--     swings growing once it falls, tipping into each; turning; and flipping
--     over (narrowed as it turns edge on);
--   * in slow motion at first (with the line's Got it), easing to real time;
--   * down to the bottom of the screen, where it fades.
-- They fall on a layer over the whole screen, not on the line, so they keep
-- falling after it has gone; one driver moves them all while any falls.
local LEAVES = 12
local LEAF_SPEED = { 55, 95 } -- pixels a second, the steady fall
local LEAF_CONE = 35 -- degrees either side of straight up, the throw
local LEAF_THROW = { 200, 320 } -- pixels a second, the throw's speed
local GRAVITY = 300 -- pixels a second squared
local LEAF_DRAG_SIDE = 2.6 -- how fast the air takes the sideways speed (per second)
local SLOW_FOR = 1.5 -- seconds from slow motion (1 / SLOW) to real time

local leafLayer, freeLeaves, falling = nil, {}, {}

-- (in real seconds, not slowed: the add flourish)
local function RealAnim(group, kind, delay, duration, smoothing)
    local a = group:CreateAnimation(kind)
    a:SetStartDelay(delay)
    a:SetDuration(duration)
    if smoothing then a:SetSmoothing(smoothing) end
    return a
end

-- Moves every falling leaf a frame on; stops when none is left.
local function Step(_, elapsed)
    local rnd, sin, cos, abs, exp, min = math.random, math.sin, math.cos, math.abs, math.exp, math.min
    local e = min(elapsed, 0.05)
    for i = #falling, 1, -1 do
        local l = falling[i]
        l.age = l.age + e
        local dt = e * min(1, 1 / SLOW + (1 - 1 / SLOW) * l.age / SLOW_FOR)
        -- Gravity, and drag toward the steady fall (linear: its pull grows
        -- with the speed, so the fall settles at l.speed).
        l.vy = l.vy + (-GRAVITY - GRAVITY / l.speed * l.vy) * dt
        l.vx = l.vx * exp(-LEAF_DRAG_SIDE * dt)
        l.x, l.y = l.x + l.vx * dt, l.y + l.vy * dt
        -- The flutter grows from the top of the throw over a second.
        if l.vy < 0 then l.flutter = min(1, l.flutter + dt) end
        l.phase = l.phase + l.swayRate * dt
        l.spin = l.spin * exp(-1.5 * dt) + l.drift * (1 - exp(-1.5 * dt))
        l.turn = l.turn + l.spin * dt
        l.flip = l.flip + l.flipRate * dt
        local t = l.tex
        if l.y < -l.size then
            t:Hide()
            table.remove(falling, i)
            freeLeaves[#freeLeaves + 1] = t
        else
            t:ClearAllPoints()
            t:SetPoint("CENTER", leafLayer, "BOTTOMLEFT", l.x + l.sway * l.flutter * sin(l.phase), l.y)
            t:SetSize(l.size * (0.25 + 0.75 * abs(cos(l.flip))), l.size)
            t:SetRotation(l.turn + 0.45 * l.flutter * cos(l.phase))
            t:SetAlpha(min(1, l.age / 0.08, math.max(l.y, 0) / 40))
        end
    end
    if #falling == 0 then leafLayer:SetScript("OnUpdate", nil) end
end

local function Layer()
    if not leafLayer then
        leafLayer = CreateFrame("Frame", nil, UIParent)
        leafLayer:SetAllPoints(UIParent)
        leafLayer:SetFrameStrata("DIALOG") -- (over the window, HIGH: a leaf flies across it)
        leafLayer:SetFrameLevel(1)
    end
    return leafLayer
end

local function Between(range)
    return range[1] + math.random() * (range[2] - range[1])
end

local function PlayLeaves(line, art)
    local x, y = line.star:GetCenter()
    if not (x and y) then return end
    local layer = Layer()
    local k = (line.star:GetEffectiveScale() or 1) / (layer:GetEffectiveScale() or 1)
    x, y = x * k, y * k
    local rnd, files = math.random, art.files
    for _ = 1, LEAVES do
        local t = table.remove(freeLeaves) or layer:CreateTexture(nil, "OVERLAY")
        t:SetTexture(files[rnd(#files)])
        t:SetAlpha(0)
        t:Show()
        local lean, throw = math.rad((rnd() * 2 - 1) * LEAF_CONE), Between(LEAF_THROW)
        falling[#falling + 1] = {
            tex = t, x = x, y = y, age = 0, size = rnd(11, 17) * k, -- (as big as the tracker is scaled)
            vx = math.sin(lean) * throw, vy = math.cos(lean) * throw, speed = Between(LEAF_SPEED),
            flutter = 0, sway = 8 + rnd() * 12, swayRate = 5 + rnd() * 2, phase = rnd() * 6.28,
            turn = rnd() * 6.28, spin = (rnd() * 2 - 1) * 7, drift = (rnd() - 0.5) * 2.4,
            flip = rnd() * 6.28, flipRate = 1.5 + rnd() * 2.5,
        }
    end
    layer:SetScript("OnUpdate", Step)
end

---------------------------------------------------------------- added

-- Starring an item, a short flourish (not slowed): the star pops and a puff
-- goes off round it, one sprite flies in an arc from it to the item's new
-- tracker line (to the title while folded), and the line fades in there
-- with a soft green flash and another puff. A skin with leaves (Elwynn): a
-- puff of its leaves and its wish leaf flying, lit; else a gold sparkle and
-- the star itself flying. With the list out of sight, just the pop and the puff.
local FLIGHT_TIME = 0.8
local arriving = {} -- "id:suffix" -> { id, suffix, x, y: where its star was clicked, on the leaf layer }, till the tracker draws it

local freeSprites = {}

local function ScaleRange(a, from, to)
    if a.SetScaleFrom then
        a:SetScaleFrom(from, from)
        a:SetScaleTo(to, to)
    else
        a:SetScale(to / from, to / from)
    end
    a:SetOrigin("CENTER", 0, 0)
end

local function NewSprite()
    local t = Layer():CreateTexture(nil, "OVERLAY")
    t:SetAlpha(0)
    local g = t:CreateAnimationGroup()
    local s = { tex = t, group = g }
    s.fadeIn = RealAnim(g, "Alpha", 0, 0.05)
    s.fadeIn:SetFromAlpha(0)
    s.fadeIn:SetToAlpha(1)
    s.grow = RealAnim(g, "Scale", 0, 0.3, "OUT")
    s.move1 = RealAnim(g, "Translation", 0, 0.4, "OUT")
    s.move2 = RealAnim(g, "Translation", 0.4, 0.4, "IN")
    s.spin = RealAnim(g, "Rotation", 0, 0.6)
    s.fadeOut = RealAnim(g, "Alpha", 0.3, 0.3, "IN")
    s.fadeOut:SetFromAlpha(1)
    s.fadeOut:SetToAlpha(0)
    return s
end

-- A sprite drawn by `look` (sets its texture), `size` across at x, y on the
-- leaf layer, back in the pool after `life` seconds. Its animations are set
-- by the caller, then Play().
local function Sprite(look, size, x, y, life)
    local s = table.remove(freeSprites) or NewSprite()
    local t = s.tex
    s.group:Stop()
    -- (as new: a flight's trail starts late and stays faint, Flight)
    s.fadeIn:SetStartDelay(0)
    s.fadeIn:SetToAlpha(1)
    s.grow:SetStartDelay(0)
    s.move1:SetStartDelay(0)
    s.spin:SetStartDelay(0)
    s.fadeOut:SetFromAlpha(1)
    look(t)
    t:SetAlpha(0)
    t:SetSize(size, size)
    t:ClearAllPoints()
    t:SetPoint("CENTER", Layer(), "BOTTOMLEFT", x, y)
    C_Timer.After(life + 0.1, function()
        s.group:Stop()
        freeSprites[#freeSprites + 1] = s
    end)
    return s
end

local function LeafLook(files)
    return function(t)
        t:SetTexture(files[math.random(#files)])
        t:SetTexCoord(0, 1, 0, 1)
        t:SetBlendMode("BLEND")
        t:SetDesaturated(false)
        t:SetVertexColor(1, 1, 1)
    end
end

local function SparkLook(t)
    t:SetTexture(BURST)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetBlendMode("ADD")
    t:SetDesaturated(false)
    t:SetVertexColor(1, 0.85, 0.4)
end

local function StarLook(t)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetBlendMode("BLEND")
    t:SetDesaturated(false)
    SetLook(t, true, false)
end

-- (a soft warm light, behind a skin's flying leaf)
local function GlowLook(t)
    t:SetTexture(BLOOM)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetBlendMode("ADD")
    t:SetDesaturated(false)
    t:SetVertexColor(1, 0.8, 0.35)
end

-- The theme's sprites: the puff's look and count, the flying one's look, and
-- whether it flies lit (Flight). A skin with leaves puffs them, and what
-- flies is its star, the wish leaf drawn to be read small (a falling leaf
-- only fills the middle of its texture and is lost over the game); without
-- a star of its own, one of the leaves.
local function Looks()
    local leaves = ns.Theme.SkinPart("leaves")
    if leaves and leaves.files and #leaves.files > 0 then
        local look = LeafLook(leaves.files)
        return look, 6, ns.Theme.SkinPart("star") and StarLook or look, true
    end
    return SparkLook, 1, StarLook, false
end

-- A puff at x, y: leaves out in all directions, spinning and fading; or one
-- gold sparkle opening and turning.
local function Puff(x, y)
    if not x then return end
    local look, count = Looks()
    for _ = 1, count do
        if count == 1 then
            local s = Sprite(look, 34, x, y, 0.6)
            ScaleRange(s.grow, 0.3, 1.3)
            s.grow:SetDuration(0.5)
            s.move1:SetOffset(0, 0)
            s.move2:SetOffset(0, 0)
            s.spin:SetDuration(0.6)
            s.spin:SetDegrees(-90)
            s.fadeOut:SetStartDelay(0.2)
            s.fadeOut:SetDuration(0.4)
            s.group:Play()
        else
            local s = Sprite(look, math.random(9, 13), x, y, 0.65)
            local angle, reach = math.rad(math.random(0, 359)), math.random(14, 28)
            ScaleRange(s.grow, 0.5, 1)
            s.grow:SetDuration(0.3)
            s.move1:SetDuration(0.5)
            s.move1:SetOffset(math.cos(angle) * reach, math.sin(angle) * reach)
            s.move2:SetOffset(0, -math.random(4, 10)) -- (and settling a little)
            s.move2:SetStartDelay(0.3)
            s.move2:SetDuration(0.35)
            s.spin:SetDuration(0.65)
            s.spin:SetDegrees(math.random(90, 300) * (math.random(2) == 1 and 1 or -1))
            s.fadeOut:SetStartDelay(0.3)
            s.fadeOut:SetDuration(0.35)
            s.group:Play()
        end
    end
end

-- One sprite from x0, y0 to x1, y1 in an arc, spinning, in `time` seconds
-- (else FLIGHT_TIME); then done(). A skin's leaf flies lit, so it shows over
-- the game: turning less, a small warm light behind it and LEAF_TRAIL
-- fainter copies of it following.
-- (its size: as large on screen as the falling leaves flew at first, which
-- fill half of their texture at 18; that size was right, only the leaf was
-- lost over the game. At 26 with a wide light it loomed.)
local LEAF_FLIES = 12
local LEAF_GLOW = { size = 1.6, alpha = 0.4 } -- the light: how much wider than the leaf, and how strong
local LEAF_TRAIL = { gap = 0.035, alpha = { 0.5, 0.25 } } -- seconds from one copy to the next, and how faint each is
local function Flight(x0, y0, x1, y1, done, time)
    time = time or FLIGHT_TIME
    local _, _, look, lit = Looks()
    local dx, dy = x1 - x0, y1 - y0
    local lift = 30 + math.abs(dx) * 0.12
    local half = time / 2
    local turn = (lit and math.random(200, 400) or math.random(360, 720)) * (math.random(2) == 1 and 1 or -1)
    -- One sprite along the arc, `delay` seconds after the first.
    local function Launch(paint, size, alpha, delay, degrees)
        local s = Sprite(paint, size, x0, y0, time + delay)
        s.fadeIn:SetStartDelay(delay)
        s.fadeIn:SetToAlpha(alpha)
        ScaleRange(s.grow, lit and 0.7 or 0.6, lit and 1 or 1.15) -- (a leaf doesn't swell past its size)
        s.grow:SetStartDelay(delay)
        s.grow:SetDuration(half)
        s.move1:SetStartDelay(delay)
        s.move1:SetDuration(half)
        s.move1:SetOffset(dx / 2, dy / 2 + lift)
        s.move2:SetStartDelay(delay + half)
        s.move2:SetDuration(half)
        s.move2:SetOffset(dx / 2, dy / 2 - lift)
        s.spin:SetStartDelay(delay)
        s.spin:SetDuration(time)
        s.spin:SetDegrees(degrees)
        s.fadeOut:SetFromAlpha(alpha)
        s.fadeOut:SetStartDelay(delay + time - 0.12)
        s.fadeOut:SetDuration(0.12)
        s.group:Play()
    end
    if lit then
        Launch(GlowLook, LEAF_FLIES * LEAF_GLOW.size, LEAF_GLOW.alpha, 0, 0)
        for k = #LEAF_TRAIL.alpha, 1, -1 do
            Launch(look, LEAF_FLIES * (1 - 0.15 * k), LEAF_TRAIL.alpha[k], k * LEAF_TRAIL.gap, turn)
        end
        Launch(look, LEAF_FLIES, 1, 0, turn)
    else
        Launch(look, 18, 1, 0, turn)
    end
    C_Timer.After(time, done)
end

-- Where frame `f`'s middle is on the leaf layer (nil before it's laid out).
local function LayerPoint(f)
    local x, y = f:GetCenter()
    if not (x and y) then return nil end
    local k = (f:GetEffectiveScale() or 1) / (Layer():GetEffectiveScale() or 1)
    return x * k, y * k
end

local function Pop(tex)
    if not tex.pop then
        tex.pop = tex:CreateAnimationGroup()
        local up = RealAnim(tex.pop, "Scale", 0, 0.12, "OUT")
        ScaleRange(up, 1, 1.6)
        local down = RealAnim(tex.pop, "Scale", 0.12, 0.25, "IN_OUT")
        ScaleRange(down, 1, 1 / 1.6)
    end
    tex.pop:Stop()
    tex.pop:Play()
end

-- The new line comes in: fades in with a green flash.
local function Arrive(line)
    if not line.arrive then
        local flash = line:CreateTexture(nil, "BACKGROUND", nil, 1)
        flash:SetAllPoints()
        flash:SetColorTexture(0.2, 1, 0.6, 1)
        flash:SetAlpha(0)
        local g = flash:CreateAnimationGroup()
        local a = RealAnim(g, "Alpha", 0, 0.1)
        a:SetFromAlpha(0)
        a:SetToAlpha(0.3)
        a = RealAnim(g, "Alpha", 0.1, 0.6, "IN")
        a:SetFromAlpha(0.3)
        a:SetToAlpha(0)
        line.arriveFlash = g
        line.arrive = line:CreateAnimationGroup()
        a = RealAnim(line.arrive, "Alpha", 0, 0.3, "OUT")
        a:SetFromAlpha(0)
        a:SetToAlpha(1)
    end
    line:SetAlpha(1)
    line.arrive:Stop()
    line.arrive:Play()
    line.arriveFlash:Stop()
    line.arriveFlash:Play()
end

-- A row's star was clicked and its item is on the list now (WL.Star).
function WL.Added(row, id, suffix)
    local x, y = LayerPoint(row.star)
    Pop(row.star.tex)
    Puff(x, y)
    if x then arriving[id .. ":" .. (suffix or "")] = { id = id, suffix = suffix, x = x, y = y } end
    Draw() -- (at once, not after the usual pause: the flight starts now)
end

-- A star standing for several items was clicked (WL.SetStarAll: a Summary
-- section's): all wished already, they all come off the list; else those
-- that aren't go on it, each flying from its own row's star (from this one,
-- for a row out of sight), one after another.
local ALL_STAGGER = 0.06 -- seconds from one take-off to the next
function WL.ToggleAll(row)
    local entries = row.wishAll
    if not (entries and ns.charDB) then return end
    local list = List()
    if AllWished(entries) then
        for _, e in ipairs(entries) do
            for i = #list, 1, -1 do
                local w = list[i]
                if w.id == e.id and (e.suffix == nil or w.suffix == nil or w.suffix == e.suffix) and not finishing[w] then
                    table.remove(list, i)
                end
            end
        end
        Changed()
        return
    end
    local added = {}
    for _, e in ipairs(entries) do
        if not WL.Has(e.id, e.suffix) then
            list[#list + 1] = { id = e.id, suffix = e.suffix }
            added[#added + 1] = e
        end
    end
    Changed() -- (the rows' stars show now)
    for k, e in ipairs(added) do
        local from = row
        for _, r in ipairs(stars) do
            if r.wishId == e.id and r.wishSuffix == e.suffix and not r.inTracker and r:IsVisible() then
                from = r
                break
            end
        end
        local x, y = LayerPoint(from.star)
        if x then
            local delay = (k - 1) * ALL_STAGGER
            arriving[e.id .. ":" .. (e.suffix or "")] = { id = e.id, suffix = e.suffix, x = x, y = y, delay = delay }
            C_Timer.After(delay, function()
                Pop(from.star.tex)
                Puff(x, y)
            end)
        end
    end
    Draw()
end

-- Takes everything off the list (the window's panel's Clear all, after its
-- question), each line in sight going with a puff.
function WL.Clear()
    if not ns.charDB then return end
    local host = Live()
    if host and host:IsVisible() then
        for i = 1, host.count do Puff(LayerPoint(host.lines[i].star)) end
    end
    local list = List()
    for i = #list, 1, -1 do list[i] = nil end
    for e in pairs(finishing) do finishing[e] = nil end
    Changed()
    Draw()
end

-- Draw's part: each item just starred flies to its line on `host`, the
-- frame the list is on (to the count of those out of sight; folded, to the title).
local function Fly(host)
    for key, from in pairs(arriving) do
        arriving[key] = nil
        local i = IndexOf(from.id, from.suffix)
        local line = i and i <= host.count and host.lines[i]
        local target = line and line.star or (host.more and host.more:IsShown() and host.more) or host.title
        if target and host:IsShown() then
            if line then line:SetAlpha(0) end
            -- (a frame later: the line just made has its place by then; one
            -- of several starred at once, after those before it: WL.ToggleAll)
            C_Timer.After(from.delay or 0, function()
                local x1, y1 = LayerPoint(target)
                if not x1 then
                    if line then line:SetAlpha(1) end
                    return
                end
                Flight(from.x, from.y, x1, y1, function()
                    if line then Arrive(line) end
                    Puff(x1, y1)
                end)
            end)
        end
    end
end

local playing = 0 -- lines playing now

-- Takes the items that played off the list, once the last has, and slides
-- the lines under the first of them up into place.
local function TakeOffFinished()
    local list, first = List(), nil
    for i = #list, 1, -1 do
        if finishing[list[i]] then
            table.remove(list, i)
            first = i
        end
    end
    for e in pairs(finishing) do finishing[e] = nil end
    for _, host in pairs({ tracker = tracker, dock = dock }) do
        for _, line in ipairs(host.lines) do
            if line.fx then -- (all of it: the line shows another item now)
                for _, g in ipairs(line.fx) do g:Stop() end
                line.fx.burst:Stop()
                line.fx.flash:SetAlpha(0)
            end
            if line.got then
                line.got = nil
                line:SetAlpha(1)
            end
            line:EnableMouse(true)
            line.star:EnableMouse(true)
        end
    end
    for _, row in ipairs(stars) do
        if row:IsVisible() then Paint(row) end
    end
    Draw()
    local host = Live()
    if not (first and host and host:IsShown()) then return end
    for i = first, host.count do
        local line = host.lines[i]
        if line and line:IsShown() then
            PlaceLine(line, i, LINE_H) -- (where it was, a line lower, then up into place)
            line.slide = line.slide or line:CreateAnimationGroup()
            line.slide:Stop()
            if not line.slideMove then line.slideMove = Move(line.slide, 0, 0, 0, 0.35 / SLOW, "OUT") end
            line.slideMove:SetOffset(0, LINE_H)
            line.slide:SetScript("OnFinished", function() PlaceLine(line, line.index) end)
            line.slide:Play()
        end
    end
end

-- The game's epic loot sound.
function WL.Chime()
    local sound = SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST or 31578
    if PlaySound then pcall(PlaySound, sound, "SFX") end
end

local function Finish(line)
    playing = playing + 1
    line.got = line.e -- (till it's taken off: Draw leaves the line alone)
    local fx = FinishFx(line)
    line:EnableMouse(false)
    line.star:EnableMouse(false)
    GameTooltip:Hide()
    line.gain:SetText(GREEN .. L["Got it!"] .. "|r")
    SetLook(line.star.tex, true, false)
    line.star:Show()
    for _, g in ipairs(fx) do
        g:Stop()
        g:Play()
    end
    local leaves = ns.Theme.SkinPart("leaves")
    if leaves and leaves.files and #leaves.files > 0 then
        PlayLeaves(line, leaves)
    else
        fx.burst:Stop()
        fx.burst:Play()
    end
    WL.Chime()
    C_Timer.After(FINISH_TIME, function()
        playing = playing - 1
        if playing <= 0 then
            playing = 0
            TakeOffFinished()
        end
    end)
end

local function Create()
    local f = CreateFrame("Frame", "WildGearWishList", UIParent)
    f:SetSize(WIDTH, HEADER_H)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("LOW")
    f:SetScale(ns.Theme.Get("wishScale")) -- (before placing it: the saved position is in its units)
    Place(f)

    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT")
    head:SetSize(WIDTH, HEADER_H)
    head:RegisterForClicks("LeftButtonUp")
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() f:StartMoving() end)
    head:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        SavePosition(f)
    end)
    head:SetScript("OnClick", function()
        ns.db.wishFolded = not ns.db.wishFolded or nil
        WL.Refresh()
    end)
    head.fold = ns.Widgets.FoldSign(head)
    head.fold:SetSize(14, 14)
    head.fold:SetPoint("CENTER", head, "LEFT", 9, 0)
    -- (the emblem before the title: T.Emblem, the theme's, its season's while
    -- that shows; Classic's or a skin's fills its texture to the edge, so
    -- smaller and a pixel up, clear of the rule under the header, over it
    -- anyway)
    head.logo = head:CreateTexture(nil, "ARTWORK", nil, 2)
    local logo, framed = ns.Theme.Emblem()
    head.logo:SetTexture(logo)
    if framed then
        head.logo:SetSize(16, 16)
        head.logo:SetPoint("LEFT", head, "LEFT", 20, 1)
    else
        head.logo:SetSize(18, 18)
        head.logo:SetPoint("LEFT", head, "LEFT", 19, 0)
    end
    head.text = head:CreateFontString(nil, "OVERLAY", "WildGearFontNormal")
    head.text:SetPoint("LEFT", head, "LEFT", 19 + 18 + 4, 0) -- (where it was by the 18 px logo)
    head.text:SetText(L["Wish list"]) -- (no count after it: the user found it ugly, here and on the window's panel)
    head.rule = ns.Widgets.Rule(head, 1, 0.82, 0, 0.35)
    head.rule:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 1)
    head.rule:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 1)
    f.head, f.title = head, head.text
    -- (what Draw goes by, the same on the window's panel: where the lines
    -- start, how wide they are, how many show: f.count)
    f.lines, f.count, f.lineX, f.top, f.lineWidth = {}, 0, 0, HEADER_H + 2, WIDTH
    -- Under the lines, the count of the rest ("+4"): click it for them all
    -- (as many as fit on the screen; ns.db.wishExpanded), and the minus
    -- sign in its place to go back to TRACKER_LINES.
    f.foot = CreateFrame("Button", nil, f)
    f.foot:SetSize(WIDTH, MORE_H)
    f.foot:RegisterForClicks("LeftButtonUp")
    ns.Widgets.AddHighlight(f.foot)
    f.foot:SetScript("OnClick", function()
        ns.db.wishExpanded = not ns.db.wishExpanded or nil
        WL.Refresh()
    end)
    f.foot:Hide()
    f.less = ns.Widgets.FoldSign(f.foot)
    f.less:SetSize(14, 14)
    f.less:SetPoint("CENTER", f.foot, "LEFT", 9, 0)
    f.less.Set(true)
    f.more = f.foot:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    f.more:Hide()
    -- `n` items on it, `folded` or not: returns how many lines show.
    function f.Lay(n, folded)
        head.fold.Set(not folded)
        -- (lines that fit on the screen under the title and the foot, in
        -- the tracker's own units)
        local fit = math.max(1, math.floor((UIParent:GetHeight() / f:GetScale() - f.top - MORE_H - 4) / LINE_H))
        local short = math.min(TRACKER_LINES, fit)
        local expanded = ns.db.wishExpanded and n > short
        local shown = folded and 0 or math.min(n, expanded and fit or short)
        local more = folded and 0 or n - shown
        local foot = not folded and (more > 0 or expanded)
        if foot then
            f.foot:ClearAllPoints()
            f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -f.top - shown * LINE_H)
            if expanded then f.less:Show() else f.less:Hide() end
            f.more:SetText(GREY .. "+" .. more .. "|r")
            f.more:ClearAllPoints()
            f.more:SetPoint("LEFT", f.foot, "LEFT", expanded and 19 or STAR + 6, 0)
            if more > 0 then f.more:Show() else f.more:Hide() end
            f.foot:Show()
        else
            f.more:Hide()
            f.foot:Hide()
        end
        f:SetHeight(HEADER_H + (folded and 0 or (2 + shown * LINE_H + (foot and MORE_H or 0))))
        return shown
    end
    return f
end

-- The window's panel: a side panel of the window, as wide as My gear and
-- placed by UI.DockSides (under My gear; in its place while that is closed),
-- with the theme's title and, in the Modern theme, its own icon. Click the
-- title to fold it (ns.db.wishDockFolded, on its own: the tracker's fold is
-- for the screen). It has as many lines as fit above the screen's bottom (one
-- at least); under them its foot: the count of the rest, and Clear all,
-- which asks first (WL.Clear). Classic: the title's plaque sits over the seam
-- with My gear, so the panel is a little further under it (f.gap) and drawn
-- over it.
local drawing -- while Draw shows it (UI.DockSides places it then: WL.Docked)
local function CreateDock()
    local window = _G.WildGearFrame
    if not window then return nil end
    local W, T = ns.Widgets, ns.Theme
    local f = CreateFrame("Frame", "WildGearWishDock", window, "BackdropTemplate")
    W.Window(f)
    f:EnableMouse(true)
    f:SetFrameLevel(window:GetFrameLevel() + 4)
    local inset = W.Inset()
    f:SetSize(290 + 2 * inset, 60) -- (UI.DockSides gives it My gear's width)
    local title, band = W.TitleBand(f, L["Wish list"], "WildGearFontNormal")
    W.PanelIcon(title, band, "Wish") -- (Modern: a star before the title)
    local framed = T.Classic() and T.Skin() and T.Skin().frame -- (a skin's frame: the title is in its bar)
    local plaque = T.Classic() and not framed -- (the title in a plaque over the top edge)
    f.top = plaque and 28 or math.floor((band:GetHeight() or 30) + 0.5) + (framed and 8 or 7)
    f.bottom = T.Classic() and 14 or 10
    f.gap = plaque and 6 or 4
    f.folded = (framed and 60) or (plaque and 44) or f.top - 6
    f.lines, f.count, f.lineX, f.lineWidth = {}, 0, 8 + inset, 290 - 16
    f.title = title

    local over = plaque and 16 or 0 -- (the plaque's part above the panel folds it too)
    local head = CreateFrame("Button", nil, f)
    head:SetPoint("TOPLEFT", f, "TOPLEFT", 0, over)
    head:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, over)
    head:SetHeight(f.top - 2 + over)
    head:RegisterForClicks("LeftButtonUp")
    head:SetScript("OnClick", function()
        ns.db.wishDockFolded = not ns.db.wishDockFolded or nil
        Draw()
    end)
    head.fold = W.FoldSign(head)
    head.fold:SetSize(14, 14)
    if plaque then
        head.fold:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -9)
    else
        head.fold:SetPoint("RIGHT", band, "RIGHT", framed and -22 or -10, 0)
    end
    f.head = head

    f.more = f:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    f.more:SetPoint("LEFT", f, "BOTTOMLEFT", f.lineX + STAR + 6, f.bottom + FOOT_H / 2)
    f.more:Hide()
    f.clear = W.FitButton(W.FlatButton(f, L["Clear all"], 56, 18))
    f.clear:SetPoint("RIGHT", f, "BOTTOMRIGHT", -f.lineX, f.bottom + FOOT_H / 2)
    f.clear:SetScript("OnClick", function(self)
        W.Confirm(self, L["Clear your wish list?"], L["Clear all"], L["Cancel"], function() WL.Clear() end)
    end)

    function f.Lay(n, folded)
        head.fold.Set(not folded)
        -- (no count after the title: the lines are all here, and those that
        -- don't fit are counted under them)
        f.lineWidth = (f:GetWidth() or 290) - 2 * f.lineX
        local shown, more = 0, 0
        if not folded then
            local top = f:GetTop() -- (in its own units, from the screen's bottom)
            local fit = top and math.floor((top - 4 - f.top - FOOT_H - f.bottom) / LINE_H) or n
            shown = math.max(1, math.min(n, fit))
            more = n - shown
        end
        f.more:SetText(more > 0 and (GREY .. "+" .. more .. "|r") or "")
        if more > 0 then f.more:Show() else f.more:Hide() end
        if folded then f.clear:Hide() else f.clear:Show() end
        f:SetHeight(folded and f.folded or f.top + shown * LINE_H + FOOT_H + f.bottom)
        return shown
    end

    f:SetScript("OnShow", function() ns.UI.DockSides() end)
    f:Hide()
    return f
end

-- LINE_H for the window's fonts now (they follow the text size and the
-- locale's font): room for the name and the source, 2 px apart, with 2 px
-- over and under them; 30 at least (the icon and star's room).
local measure
local function FitLineHeight(host)
    if not measure then
        measure = host:CreateFontString(nil, "OVERLAY")
        measure:Hide()
    end
    local h = 0
    for _, font in ipairs({ "WildGearFontHighlightSmall", "WildGearFontDisableSmall" }) do
        measure:SetFontObject(font)
        measure:SetText("Ag")
        h = h + (measure:GetStringHeight() or 0)
    end
    LINE_H = math.max(30, math.ceil(h) + 6)
end

Draw = function()
    if not ns.charDB then return end
    local open = WindowOpen()
    -- (an item got while its line is in sight plays Got it; else, or at login, it just goes)
    local live = Live()
    local inSight = live ~= nil and live:IsVisible() and live.count > 0
    local started = DropOwned(inSight, inSight and live.count or 0)
    local list = List()
    -- On the window's panel while the window is open, else on the tracker
    -- (unless that is switched off). A tracker whose stars are taking off
    -- (WL.Window) hides by itself after.
    local onDock, onTracker = open and #list > 0, not open and On() and #list > 0
    if tracker and not onTracker and not tracker.leaving then tracker:Hide() end
    if dock and not onDock then dock:Hide() end
    local host
    if onDock then
        dock = dock or CreateDock()
        host = dock
    elseif onTracker then
        tracker = tracker or Create()
        host = tracker
    end
    if not host then
        for id in pairs(arriving) do arriving[id] = nil end
        return
    end
    drawing = true
    host:Show() -- (first: the panel is placed as it shows, and what fits goes by its place)
    drawing = false
    FitLineHeight(host)
    local shown = host.Lay(#list, ns.db[open and "wishDockFolded" or "wishFolded"])
    for i = 1, shown do
        local e = list[i]
        local line = host.lines[i]
        if not line then
            line = CreateLine(host)
            host.lines[i] = line
        end
        line.index = i
        line:SetSize(host.lineWidth, LINE_H)
        if not (line.slide and line.slide:IsPlaying()) then PlaceLine(line, i) end
        if line.got ~= e then -- (a line playing Got it is left as it is)
            local item = ns.Items[e.id]
            local s, state = PickSource(item)
            line.e, line.src = e, s
            ns.UI.ItemIcon(e.id, line.icon)
            line.name:SetText(ns.QualityHex(ns.ItemQuality(e.id)) .. ns.ItemName(e.id, e.suffix) .. "|r")
            line.gain:SetText(GainText(e, item))
            line.source:SetText(SourceText(s, state))
            WL.SetStar(line, e.id, e.suffix)
        end
        line:Show()
    end
    for i = shown + 1, #host.lines do
        host.lines[i]:Hide()
        host.lines[i].e = nil
    end
    host.count = shown
    -- (a position saved before it went by the top edge: moved over where it shows)
    local pos = ns.db.wishPos
    if host == tracker and pos and not (pos.point or ""):find("^TOP") then SavePosition(tracker) end
    Fly(host)
    for _, e in ipairs(started) do
        local i = IndexOf(e.id, e.suffix)
        if i and i <= shown then Finish(host.lines[i]) end
    end
    -- (one whose line went out of sight since: off the list without playing)
    if playing == 0 and next(finishing) then TakeOffFinished() end
end

---------------------------------------------------------------- docking

-- The window opens or closes and the list moves between the tracker and the
-- window's panel, carried by its stars (not slowed):
--   * where it was, each line's star takes off with a puff, one after
--     another, its line fading behind it (the tracker's; the panel is gone
--     with the window);
--   * the stars fly across in arcs, a skin's leaves in place of stars
--     (Flight), up to DOCK_FLIGHTS of them, the further the longer;
--   * where each lands its line fades in with the green flash and a puff
--     (Arrive), the lines without a star after them; then a shine sweeps
--     the title.
-- Folded at either end, a few stars leave from or land on the title. With
-- nowhere to take off from (the tracker switched off) the panel's lines just
-- fade in one after another. Opening or closing again mid-flight goes
-- straight to the end.
local DOCK_STAGGER = 0.04 -- seconds from one star's take-off to the next
local DOCK_FLIGHT = { 0.45, 0.75 } -- a flight's seconds, the shortest and the longest
local DOCK_SPEED = 3000 -- pixels a second, between those
local DOCK_FLIGHTS = 8 -- stars at most
local DOCK_LIFT = 0.15 -- seconds a line takes to fade behind its star
local DOCK_FADE = 0.18 -- seconds the panel takes to show
local moving, busy = 0, false -- the move's number (a newer one ends the timers of the last), and whether one plays

-- `f` fades out after `delay` seconds, and stays gone.
local function FadeAway(f, delay)
    if not f.leave then
        f.leave = f:CreateAnimationGroup()
        f.leave:SetToFinalAlpha(true)
        f.leaveFade = RealAnim(f.leave, "Alpha", 0, DOCK_LIFT, "IN")
        f.leaveFade:SetFromAlpha(1)
        f.leaveFade:SetToAlpha(0)
    end
    f.leaveFade:SetStartDelay(delay)
    f.leave:Stop()
    f.leave:Play()
end

-- `host` (the tracker, the panel) as it is at rest: all of it in sight.
local function Still(host)
    if not host then return end
    host.leaving = nil
    if host.head.leave then host.head.leave:Stop() end
    host.head:SetAlpha(1)
    if host.fadeIn then host.fadeIn:Stop() end
    for _, line in ipairs(host.lines) do
        if line.leave then line.leave:Stop() end
        if not line.got then line:SetAlpha(1) end -- (one playing Got it fades by itself)
    end
end

-- Ends a move where it is: what flies still lands nowhere.
local function Settle()
    moving = moving + 1
    busy = false
    Still(tracker)
    Still(dock)
end

-- Where `host`'s stars are on the leaf layer, the first DOCK_FLIGHTS of
-- them: { { x, y }, ... }; folded, its title, for up to three.
local function Points(host)
    local points = {}
    if host.count > 0 then
        for i = 1, math.min(host.count, DOCK_FLIGHTS) do
            local x, y = LayerPoint(host.lines[i].star)
            if not x then break end
            points[i] = { x, y }
        end
    else
        local x, y = LayerPoint(host.title)
        for i = 1, x and math.min(#List(), 3) or 0 do points[i] = { x, y } end
    end
    return points
end

local function FlightTime(a, b)
    local far = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
    return math.max(DOCK_FLIGHT[1], math.min(DOCK_FLIGHT[2], far / DOCK_SPEED))
end

-- A shine across `host`'s title.
local function Shine(host)
    local head = host.head
    if not head.shine then
        local clip = CreateFrame("Frame", nil, head)
        clip:SetAllPoints()
        clip:SetClipsChildren(true)
        local sheen = Sheen(clip)
        sheen:SetPoint("RIGHT", clip, "LEFT", 0, 0)
        head.shine = sheen:CreateAnimationGroup()
        head.shineMove = RealAnim(head.shine, "Translation", 0, 0.5, "IN_OUT")
    end
    head.shineMove:SetOffset((head:GetWidth() or WIDTH) + SWEEP_W, 0)
    head.shine:Stop()
    head.shine:Play()
end

-- The window opened (`open`) or closed: UI.lua, after it has redrawn.
function WL.Window(open)
    if not ns.charDB then return end
    local was = busy
    Settle()
    if was then return Draw() end
    local id = moving
    local old = dock -- (where the list was)
    if open then old = tracker end
    local from = old and old:IsShown() and Points(old) or {}
    if open and #from > 0 then
        tracker.leaving = true
        local last = 0
        for i = 1, tracker.count do
            last = (math.min(i, DOCK_FLIGHTS) - 1) * DOCK_STAGGER
            FadeAway(tracker.lines[i], last)
        end
        FadeAway(tracker.head, last)
        C_Timer.After(last + DOCK_LIFT, function()
            if id ~= moving then return end
            Still(tracker)
            tracker:Hide()
        end)
    end
    Draw()
    -- (closed without the panel showing: nothing moves. The window hides once
    -- as it is made, just before its first opening, which would else find a
    -- move playing and skip its own)
    if not open and #from == 0 then return end
    local new = Live()
    if not (new and new:IsShown()) then return end -- (nothing on it, or the tracker is switched off)
    busy = true
    for i = 1, new.count do
        if not new.lines[i].got then new.lines[i]:SetAlpha(0) end
    end
    if open then
        if not new.fadeIn then
            new.fadeIn = new:CreateAnimationGroup()
            local a = RealAnim(new.fadeIn, "Alpha", 0, DOCK_FADE, "OUT")
            a:SetFromAlpha(0)
            a:SetToAlpha(1)
        end
        new.fadeIn:Play()
    end
    -- (a frame later: the lines just made have their places by then)
    C_Timer.After(0, function()
        if id ~= moving then return end
        local to = Points(new)
        local flights = math.min(#from, #to)
        local air = 0 -- the longest flight: the lines without a star come in after it
        for i = 1, flights do air = math.max(air, FlightTime(from[i], to[i])) end
        local last = air
        for i = 1, math.max(new.count, flights) do
            local line = i <= new.count and new.lines[i] or nil
            local a, b = from[i], to[i]
            local flies = i <= flights
            local delay = (i - 1) * DOCK_STAGGER + (flies and 0 or air)
            local time = flies and FlightTime(a, b) or 0
            last = math.max(last, delay + time)
            C_Timer.After(delay, function()
                if id ~= moving then return end
                if not flies then
                    if line then Arrive(line) end
                    return
                end
                Puff(a[1], a[2])
                Flight(a[1], a[2], b[1], b[2], function()
                    if id ~= moving then return end
                    if line then Arrive(line) end
                    Puff(b[1], b[2])
                end, time)
            end)
        end
        C_Timer.After(last, function()
            if id ~= moving then return end
            busy = false
            Shine(new)
        end)
    end)
end

-- The window's panel while it shows, for UI.DockSides to place.
function WL.Dock()
    return dock and dock:IsShown() and dock or nil
end

-- UI.DockSides placed it: what fits on it may have changed.
function WL.Docked()
    if not drawing then WL.Refresh() end
end

-- Redraws the list once per burst of calls (gear, bags, quests, the
-- window's changes: UI.Refresh).
local pending
function WL.Refresh()
    if not (C_Timer and C_Timer.After) then return Draw() end
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        Draw()
    end)
end

-- The key binding (Bindings.xml) and Settings' switch.
function WL.ToggleTracker()
    if ns.db.wishTracker == false then ns.db.wishTracker = nil else ns.db.wishTracker = false end
    if ns.Settings and ns.Settings.Update then ns.Settings.Update() end
    WL.Refresh()
end
WildGear_ToggleWishList = WL.ToggleTracker

-- The season's switch (the bottom bar): every star in its new look at once,
-- the window's and the tracker's (a skin's season can have its own star).
ns.Theme.OnSeason(function()
    for _, row in ipairs(stars) do Paint(row) end
    if tracker then tracker.head.logo:SetTexture((ns.Theme.Emblem())) end
end)

-- The display settings changed (Theme.Apply): Wish list size.
ns.Theme.Track(function()
    if tracker then ApplyScale(tracker) end
end)

local events = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "GET_ITEM_INFO_RECEIVED" }) do
    events:RegisterEvent(e)
end
events:SetScript("OnEvent", function(_, event)
    -- (bag counts settle a moment after login)
    local live = Live()
    if event ~= "GET_ITEM_INFO_RECEIVED" or (live and live:IsShown()) then WL.Refresh() end
end)
