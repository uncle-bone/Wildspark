local _, addonRoot = ...
local ns = addonRoot.WildGear

-- My gear beside the game's Character frame: a second of the window's gear
-- panels (UI.NewGearPanel), with your gear scored for your main spec at your
-- level whatever the window plans (its spec box under the band changes your
-- main spec, UI.SetMainSpec, and its weights box the profile it scores
-- with: GearHeader.Create), and Equip best and the set note
-- as on the window's; a row opens the window on its slot. In the theme's look
-- (Widgets.lua), made when the Character frame first opens.
-- It opens with the Character frame, every time: its close button puts it
-- away until the frame opens again. It docks on the frame's right, level
-- with its top and at least as tall, or on its left without room there, and
-- steps aside while another of the game's windows (the spell book,
-- talents...) takes that place; other addons' panels on the frame's side
-- (TinyInspect's item list...) it docks beyond.
-- Settings' Shown on: Character Info switch turns it off (characterPanel =
-- false), at once.
-- DaylightUI draws a character window of its own (DaylightUICharacter): it
-- parks the game's frame under a hidden frame, shown but out of sight (and
-- so without OnShow), and shows its own in its place. While it does, the
-- panel goes on that one instead (Host).

local UI, T = ns.UI, ns.Theme

local P = {}
ns.CharacterPanel = P

local GAP = 4 -- between the Character frame's edge and the panel's, as between the window and its panels
-- The Classic theme's dialog border is see-through for its outer 4 points:
-- the panel reaches that much beyond the edges it lines up with.
local function Edge()
    return T.Classic() and 4 or 0
end

-- holder: the panel's parent, hidden while another window takes its place.
local holder, panel

local function On()
    return ns.db.characterPanel ~= false
end

-- The character window in sight: DaylightUI's while it shows, else the
-- game's Character frame. (Below, "the Character frame" is this one.)
local function Host()
    local daylight = rawget(_G, "DaylightUICharacter")
    if type(daylight) == "table" and daylight.IsShown and daylight:IsShown() then return daylight end
    return CharacterFrame
end

-- Whether the character window is open: the game's frame, parked or not.
local function Opened()
    return CharacterFrame and CharacterFrame:IsShown()
end

-- The Character frame's drawn edges, in from its own: none, but where its
-- hit rect leaves out a see-through margin (a classic frame's art has one).
-- Returns left, right, top, bottom.
local function Insets()
    local l, r, t, b = Host():GetHitRectInsets()
    return l or 0, r or 0, t or 0, b or 0
end

---------------------------------------------------------------- data

-- Your gear, scored and ranked for your main spec at your level (as the
-- window's for your own character: UI.Refresh).
local function Redraw()
    if not (panel and panel:IsVisible()) then return end
    local p = ns.GetPlayer()
    local gear = ns.GetEquipped(p)
    panel.data = { p = p, gear = gear, worn = gear,
                   ranked = ns.Rank(p, { classArmorOnly = ns.db.classArmorOnly, owned = gear }) }
    UI.UpdateGearPanel(panel)
end

local Open

-- Redraws it while in sight, once per burst of calls: on every change the
-- window makes (UI.Refresh: your spec, its settings) and on gear events.
-- With the Character frame open, puts the switch's change in place first.
local pending
function P.Refresh()
    if Opened() and (panel or On()) then Open() end
    if not (panel and panel:IsVisible()) then return end
    if not (C_Timer and C_Timer.After) then return Redraw() end
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        Redraw()
    end)
end

---------------------------------------------------------------- other addons' panels

local Later -- (docks again, a frame later: below)

-- Other addons' panels on the Character frame's sides (TinyInspect's item
-- list...): frames in the frame's own tree (three levels down: its panes'
-- children), or of UIParent's anchored to that tree, that lie out past its
-- drawn edges beside it; not tooltips (the game's goes beside it hovering a
-- slot: the panel would jump out and back). Found anew on the frame's
-- showing and three times more soon after (some show a moment later:
-- Rescan); each followed once found, to dock again when it shows, hides or
-- changes size.
local neighbors, followed = {}, {}

local function Tooltip(f)
    return f:IsObjectType("GameTooltip") or f:GetFrameStrata() == "TOOLTIP"
end

-- Frame `f`'s edges in the Character frame's units (`scale`: its effective
-- scale): left, right, top, bottom; nil while it has none.
local function Rect(f, scale)
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not (l and r and t and b) then return nil end
    local k = f:GetEffectiveScale() / scale
    return l * k, r * k, t * k, b * k
end

-- Whether frame `f` (not a tooltip) lies out past the drawn edge `x0` (left
-- side) or `x1` (right side) of the frame, beside it between `y0` (bottom)
-- and `y1` (top).
local function Beside(f, x0, x1, y0, y1, scale)
    if Tooltip(f) then return false end
    local l, r, t, b = Rect(f, scale)
    if not l or math.min(t, y1) - math.max(b, y0) < 20 then return false end
    return l >= x1 - 2 or r <= x0 + 2
end

local function Scan()
    local cf = Host()
    local scale = cf:GetEffectiveScale()
    local il, ir, it, ib = Insets()
    local x0, x1 = (cf:GetLeft() or 0) + il, (cf:GetRight() or 0) - ir
    local y0, y1 = (cf:GetBottom() or 0) + ib, (cf:GetTop() or 0) - it
    local tree, level, found = { [cf] = true }, { cf }, {}
    for _ = 1, 3 do
        local deeper = {}
        for _, f in ipairs(level) do
            for _, kid in ipairs({ f:GetChildren() }) do
                if kid ~= holder and not kid.notNeighbor then -- (nor our selectors' list: W.ShowPopup)
                    tree[kid] = true
                    deeper[#deeper + 1] = kid
                    found[#found + 1] = kid
                end
            end
        end
        level = deeper
    end
    for _, f in ipairs({ UIParent:GetChildren() }) do
        local ok, anchored = pcall(function()
            for i = 1, f:GetNumPoints() or 0 do
                local _, rel = f:GetPoint(i)
                if rel and tree[rel] then return true end
            end
        end)
        if ok and anchored and not tree[f] then found[#found + 1] = f end
    end
    neighbors = {}
    for _, f in ipairs(found) do
        local ok, beside = pcall(Beside, f, x0, x1, y0, y1, scale)
        if ok and beside then
            neighbors[f] = true
            if not followed[f] then
                followed[f] = true
                for _, script in ipairs({ "OnShow", "OnHide", "OnSizeChanged" }) do f:HookScript(script, Later) end
            end
        end
    end
end

-- How far the shown ones reach out past the frame's drawn edges: left, right.
local function Reach()
    local cf = Host()
    local scale = cf:GetEffectiveScale()
    local il, ir = Insets()
    local x0, x1 = (cf:GetLeft() or 0) + il, (cf:GetRight() or 0) - ir
    local left, right = 0, 0
    for f in pairs(neighbors) do
        local ok, l, r = pcall(Rect, f, scale)
        if ok and l and f:IsVisible() then
            if l >= x1 - 2 then right = math.max(right, r - x1) end
            if r <= x0 + 2 then left = math.max(left, x0 - l) end
        end
    end
    return left, right
end

---------------------------------------------------------------- docking

-- The game's windows beside the Character frame (its panel layout:
-- GetUIPanel), each watched, once seen, to dock again when it closes.
local watched = {}

-- The game's bank windows. Bag addons (DaylightUI's bags, Bagnon...) park
-- them out of sight, under a hidden, see-through or shrunk frame, and show
-- their own bank somewhere else; the game still counts them open, where
-- they would have been. Other windows parked by a UI addon stay where the
-- game puts them, its own drawn in their place (DaylightUI's spellbook,
-- talents, NPC windows): those still take that place.
local BANKS = { BankFrame = true, GuildBankFrame = true, VoidStorageFrame = true }

-- Whether window `f` takes its place: shown, and a bank window only while
-- in sight (shown all the way up, not see-through, not shrunk away).
local function Takes(f)
    if not f:IsShown() then return false end
    if not BANKS[f:GetName() or ""] then return true end
    if not f:IsVisible() then return false end
    if f.GetEffectiveAlpha and f:GetEffectiveAlpha() < 0.01 then return false end
    return f:GetEffectiveScale() >= 0.01 * UIParent:GetEffectiveScale()
end

-- A shown window of the game's covering the Character frame's units x0..x1
-- across, else nil.
local function Blocker(x0, x1)
    if not GetUIPanel then return nil end
    local host = Host()
    local scale = host:GetEffectiveScale()
    for _, key in ipairs({ "left", "center", "right", "doublewide" }) do
        local ok, f = pcall(GetUIPanel, key)
        if ok and f and f ~= CharacterFrame and f ~= host and Takes(f) and f:GetLeft() then
            local k = f:GetEffectiveScale() / scale
            if f:GetLeft() * k < x1 and f:GetRight() * k > x0 then
                if not watched[f] then
                    watched[f] = true
                    f:HookScript("OnHide", Later)
                end
                return f
            end
        end
    end
end

-- On the right where it fits on screen and no other window is there, else on
-- the left the same way, else on the right but for another window there
-- (it stays on screen, over the frame's edge), else out of sight; beyond
-- other addons' panels on that side.
local Settle

local function Dock()
    if not (panel and Opened() and On()) then return end
    Settle()
    local cf, edge = Host(), Edge()
    local l, r, t = Insets()
    local width = panel:GetWidth() - 2 * edge + GAP
    local reachLeft, reachRight = Reach()
    local left, right = (cf:GetLeft() or 0) + l - reachLeft, (cf:GetRight() or 0) - r + reachRight
    local screen = UIParent:GetWidth() * UIParent:GetEffectiveScale() / cf:GetEffectiveScale()
    local free = {
        right = not Blocker(right, right + width) and right + width <= screen,
        left = not Blocker(left - width, left) and left - width >= 0,
    }
    local side = (free.right and "right") or (free.left and "left")
        or (not Blocker(right, right + width) and "right") or nil
    panel:ClearAllPoints()
    if side == "left" then
        panel:SetPoint("TOPRIGHT", cf, "TOPLEFT", l - reachLeft - GAP + edge, -t + edge)
    else
        panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", -r + reachRight + GAP - edge, -t + edge)
    end
    if side then holder:Show() else holder:Hide() end
end

-- (after the game has placed its windows)
Later = function()
    if C_Timer and C_Timer.After then C_Timer.After(0, Dock) else Dock() end
end

-- Other addons' panels looked for again, then docking: now, a frame later,
-- and twice more soon after (some show a moment after the frame does).
local function Rescan()
    local function Again()
        if not (holder and Opened() and On()) then return end
        Scan()
        Dock()
    end
    Again()
    if not (C_Timer and C_Timer.After) then return end
    for _, delay in ipairs({ 0, 0.5, 1.5 }) do C_Timer.After(delay, Again) end
end

---------------------------------------------------------------- setup

-- The height the panel's rows fill: the Character frame's drawn height.
local function Fit()
    local _, _, t, b = Insets()
    return Host():GetHeight() - t - b + 2 * Edge()
end

local function Create()
    holder = CreateFrame("Frame", nil, Host())
    holder:SetAllPoints()
    panel = UI.NewGearPanel(holder, Fit())
    panel.OnClose = function() panel:Hide() end
    panel:SetScript("OnShow", Redraw)
    panel:Show()
end

-- The panel on the character window in sight (DaylightUI's or the game's),
-- its rows filling that one's height.
Settle = function()
    local host = Host()
    if holder:GetParent() == host then return end
    holder:SetParent(host)
    holder:ClearAllPoints()
    holder:SetAllPoints(host)
    panel.fit = Fit()
    if panel:IsVisible() and panel.data then UI.UpdateGearPanel(panel) end
end

-- With the Character frame showing: the panel in place, or while switched
-- off, out of sight (made only once wanted).
Open = function()
    if not On() then
        if holder then holder:Hide() end
        return
    end
    if not panel then Create() end
    Dock()
end

local function Shown()
    if panel then panel:Show() end -- (closed only until the frame opens again)
    Open()
    Rescan()
end

-- DaylightUI's character window, made as DaylightUI starts (at login): it
-- shows and hides in step with the game's parked frame, a frame after it.
local daylightHooked
local function HookDaylight()
    local daylight = rawget(_G, "DaylightUICharacter")
    if daylightHooked or type(daylight) ~= "table" or not daylight.HookScript then return end
    daylightHooked = true
    daylight:HookScript("OnShow", Shown)
    daylight:HookScript("OnHide", Later) -- (back on the game's frame, should it show instead)
    daylight:HookScript("OnSizeChanged", Later)
    if daylight:IsShown() then Shown() end
end

local hooked
local function Hook()
    HookDaylight()
    if hooked or not CharacterFrame then return end
    hooked = true
    CharacterFrame:HookScript("OnShow", Shown)
    CharacterFrame:HookScript("OnSizeChanged", Dock) -- (its stats pane folds out and in)
    for _, name in ipairs({ "ShowUIPanel", "HideUIPanel" }) do
        if _G[name] then hooksecurefunc(name, Later) end
    end
end

-- Redraws it from the rankings it has, once per burst of calls: the game
-- loaded names, or quest progress changed (its rows' marks). Neither
-- changes the rankings: ranking again (Redraw) on each was a lag spike.
local repaint
local function Repaint()
    if repaint or not (panel and panel:IsVisible() and panel.data) then return end
    repaint = true
    local function Run()
        repaint = false
        if panel:IsVisible() and panel.data then UI.UpdateGearPanel(panel) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Run) else Run() end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, id)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        return Hook() -- (in case the Character frame loads late; DaylightUI's window is made at login)
    end
    if event == "GET_ITEM_INFO_RECEIVED" and panel and panel.data and not ns.WornWaiting(panel.data.gear, id)
        or event:find("^QUEST_") then
        return Repaint()
    end
    P.Refresh()
end)
-- (Skills: Player.lua calls UI.Refresh, and so P.Refresh, when one changes what you can wear.)
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP",
                     "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED",
                     "QUEST_DATA_LOAD_RESULT", -- (item and quest names loaded, see Locale.lua)
                     "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do -- (quest progress marks)
    pcall(events.RegisterEvent, events, e)
end
Hook()
