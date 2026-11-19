local _, addonRoot = ...
local ns = addonRoot.WildGear

-- A green up arrow in the top right corner of every bag item that is an
-- upgrade for your main spec: an item whose tooltip box is green (Tip.Gain:
-- its gain over the gear the spec is compared with, by default what you
-- wear). The arrows bob gently, all in step, on a soft green glow. Drawn in
-- the game's own bags, in EllesmereUI's (bags, reagent bag and bank, grid
-- and list), in Bagnon's (bags, bank and guild bank) and in Baganator's (a
-- corner widget, listed with its own).
-- Baganator can also take the same items as its Upgrade detection (its
-- "upgrade" search and the categories made with it).
-- WildGearDB.bagMarks = false turns them off (Settings).

local BM = {}
ns.BagMarks = BM

local UPGRADE = 0.05 -- a gain item tooltips show with a green arrow
local MEDIA = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\"
local GREEN = { 0.2, 1, 0.6 } -- item tooltips' gain green
local INSET = 2 -- the arrow fills the slot's top right quarter, this far in from its edges
local SIZE = 15 -- its size in Baganator, which places it in the corner itself
-- The motion: the arrow rises BOB points to its spot and back every PERIOD
-- seconds (so it never pokes out over the slot's top edge), its glow
-- (GLOW_OUT points bigger than the arrow all round) brightening from
-- GLOW_LOW to GLOW_HIGH as it rises.
local BOB, PERIOD = 2, 1.6
local GLOW_LOW, GLOW_HIGH, GLOW_OUT = 0.1, 0.35, 5

---------------------------------------------------------------- judging

-- [link] = whether the item is an upgrade, until what that depends on
-- changes (Changed). An item that can't be judged yet isn't kept.
local known = {}
local player -- your character as the marks judge for it (ns.GetPlayer), until something changes
local waiting -- an item couldn't be judged yet (it, or your worn gear, still loading)

local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-- Whether item `id` goes in an equipment slot (the data's items all do).
local function IsGear(id)
    if ns.Items[id] then return true end
    local loc = Instant and select(4, Instant(id))
    return loc ~= nil and loc ~= "" and loc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

-- Whether the item `link` is an upgrade for your main spec; false while that
-- can't be told yet (`waiting`).
local function IsUpgrade(link)
    if not (link and ns.charDB) or ns.db.bagMarks == false then return false end
    local up = known[link]
    if up ~= nil then return up end
    local id = tonumber(link:match("item:(%d+)"))
    up = false
    if id and IsGear(id) then
        player = player or ns.GetPlayer()
        local gain, wait = ns.Tooltip.Gain(id, link, player)
        if wait then
            waiting = true
            return false
        end
        up = gain ~= nil and gain >= UPGRADE
    end
    known[link] = up
    return up
end

---------------------------------------------------------------- the arrow

local live = {} -- [arrow] = true while it's on screen
-- Moves the arrows on screen (shown while there are any). Timed by the
-- clock, not from when each one showed, so they all move in step.
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function()
    local up = 0.5 - 0.5 * math.cos(2 * math.pi * GetTime() / PERIOD) -- 0 to 1 and back
    local y = BOB * (up - 1)
    for m in pairs(live) do
        m.art:SetPoint("TOPLEFT", m, "TOPLEFT", 0, y)
        m.art:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, y)
        m.glow:SetAlpha(GLOW_LOW + (GLOW_HIGH - GLOW_LOW) * up)
    end
end)

-- Lets texture `t` move by fractions of a pixel, not in whole-pixel steps.
local function Smooth(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end

-- An arrow on `parent`, hidden, for the caller to size and place: item
-- tooltips' green up arrow on a dark copy a little larger (so it shows on
-- any icon), over a soft green glow.
local function NewArrow(parent)
    local m = CreateFrame("Frame", nil, parent)
    m:Hide()
    m.glow = m:CreateTexture(nil, "ARTWORK")
    m.glow:SetTexture(MEDIA .. "Glow")
    m.glow:SetBlendMode("ADD")
    m.glow:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
    m.glow:SetAlpha(GLOW_LOW)
    m.glow:SetPoint("TOPLEFT", m, "TOPLEFT", -GLOW_OUT, GLOW_OUT)
    m.glow:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", GLOW_OUT, -GLOW_OUT)
    m.art = CreateFrame("Frame", nil, m)
    m.art:SetPoint("TOPLEFT", m, "TOPLEFT", 0, -BOB)
    m.art:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 0, -BOB)
    local back = m.art:CreateTexture(nil, "OVERLAY", nil, 4)
    back:SetTexture(MEDIA .. "TipUp")
    back:SetVertexColor(0, 0, 0, 0.85)
    back:SetAllPoints()
    local arrow = m.art:CreateTexture(nil, "OVERLAY", nil, 5)
    arrow:SetTexture(MEDIA .. "TipUp")
    arrow:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
    arrow:SetPoint("TOPLEFT", m.art, "TOPLEFT", 1, -1)
    arrow:SetPoint("BOTTOMRIGHT", m.art, "BOTTOMRIGHT", -1, 1)
    Smooth(back)
    Smooth(arrow)
    m:SetScript("OnShow", function(self)
        live[self] = true
        driver:Show()
    end)
    m:SetScript("OnHide", function(self)
        live[self] = nil
        if not next(live) then driver:Hide() end
    end)
    return m
end

---------------------------------------------------------------- bag buttons

-- The game's, EllesmereUI's and Bagnon's item buttons: [button] = { host = the frame
-- its arrow goes on, link = the item it showed when last painted (nil:
-- none) }, and [button] = its arrow, made when first needed. Nothing is kept
-- on the buttons themselves: they are secure.
local shown = setmetatable({}, { __mode = "k" })
local arrows = setmetatable({}, { __mode = "k" })

-- Shows or hides button `btn`'s arrow for the item it shows.
local function Update(btn)
    local s = shown[btn]
    local on = IsUpgrade(s.link)
    local m = arrows[btn]
    if on and not m then
        m = NewArrow(s.host)
        m:SetFrameLevel(s.host:GetFrameLevel() + 2) -- (over the button's cooldown swipe)
        m:SetPoint("BOTTOMLEFT", s.host, "CENTER", INSET, INSET)
        m:SetPoint("TOPRIGHT", s.host, "TOPRIGHT", -INSET, -INSET)
        arrows[btn] = m
    end
    if m then
        if on then m:Show() else m:Hide() end
    end
end

-- Button `btn` now shows item `link` (nil: none); its arrow goes on `host`.
local function Paint(btn, host, link)
    local s = shown[btn] or {}
    s.host, s.link = host, link
    shown[btn] = s
    Update(btn)
end

local RefreshBaganator -- (set when Baganator is there)

-- For other addons, the same answers as the arrows and the Baganator plugin:
-- WildGear_API.IsUpgrade (API.lua), whose OnChanged listeners run
-- whenever the arrows are judged again.
ns.API.IsUpgrade = IsUpgrade

-- Every arrow again, for the items the buttons show.
local function Repaint()
    for btn in pairs(shown) do Update(btn) end
    if RefreshBaganator then RefreshBaganator() end
    ns.API.Fire()
end

-- The game's bags: a container frame's items, after the game updates them
-- (the combined bag's come from several bags).
local function PaintFrame(frame)
    local function One(btn)
        local bag = btn.GetBagID and btn:GetBagID() or btn:GetParent():GetID()
        Paint(btn, btn, bag and C_Container.GetContainerItemLink(bag, btn:GetID()))
    end
    if frame.EnumerateValidItems then
        for _, btn in frame:EnumerateValidItems() do One(btn) end
    else
        for _, btn in ipairs(frame.Items or {}) do
            if btn:IsShown() then One(btn) end
        end
    end
end

local function HookContainers()
    local frames = { ContainerFrameCombinedBags }
    local i = 1
    while _G["ContainerFrame" .. i] do
        frames[#frames + 1] = _G["ContainerFrame" .. i]
        i = i + 1
    end
    local hooked = false
    for _, frame in ipairs(frames) do
        if frame.UpdateItems then
            hooksecurefunc(frame, "UpdateItems", PaintFrame)
            hooked = true
        end
    end
    -- Older bags: one frame per bag, its buttons named after it.
    if not hooked and ContainerFrame_Update then
        hooksecurefunc("ContainerFrame_Update", function(frame)
            local name, bag = frame:GetName(), frame:GetID()
            for n = 1, frame.size or 0 do
                local btn = name and _G[name .. "Item" .. n]
                if btn then Paint(btn, btn, C_Container.GetContainerItemLink(bag, btn:GetID())) end
            end
        end)
    end
end

-- EllesmereUI's bags call this for every slot they paint: the arrow goes on
-- the overlay over the item's icon, as EllesmereUI asks.
local function HookEllesmere()
    if not (EUI_Bags and EUI_Bags.RegisterItemOverlayIcon) then return end
    EUI_Bags.RegisterItemOverlayIcon("WildGear", function(btn, data)
        Paint(btn, btn._textOverlay or btn, data.info and data.itemLink or nil)
    end)
end

-- Bagnon (and Bagnonium, on the same BagBrother code): its item buttons get
-- their methods copied onto them when made (Item:Bind), so the arrow follows
-- each button's own Update, the one way a slot changes item (laid out,
-- bag updates, item data loaded). Hooked on the buttons made so far and,
-- through Bind, on every one made later (the bank's and guild bank's too,
-- whose addons load later). Only your own bags, bank and guild bank: not
-- another character's, which Bagnon can show too.
local function HookBagnon()
    for _, name in ipairs({ "Bagnon", "Bagnonium" }) do
        local B = _G[name]
        local Item = type(B) == "table" and rawget(B, "Item")
        if type(Item) == "table" and type(rawget(Item, "Bind")) == "function" then
            local hooked = setmetatable({}, { __mode = "k" })
            local function OnUpdate(btn)
                local owner = btn.GetOwner and btn:GetOwner()
                local ours = owner == nil or owner == B.player or owner == B.guild
                Paint(btn, btn, ours and btn.info and btn.info.hyperlink or nil)
            end
            local function Attach(btn)
                if type(btn) ~= "table" or hooked[btn] or type(btn.Update) ~= "function" then return end
                hooked[btn] = true
                hooksecurefunc(btn, "Update", OnUpdate)
                if btn.info and btn:IsShown() then OnUpdate(btn) end
            end
            hooksecurefunc(Item, "Bind", function(_, btn) Attach(btn) end)
            for _, class in ipairs({ B.Item, B.ContainerItem, B.VaultItem, B.GuildItem }) do
                local frames = type(class) == "table" and rawget(class, "__frames")
                for k, v in pairs(frames or {}) do -- (in use: [button] = true; spare: [n] = button)
                    Attach(type(k) == "table" and k or v)
                end
            end
        end
    end
end

-- Baganator: a corner widget, first in the top right corner (its corner
-- settings list it by the addon's name). Baganator shows and places it.
-- And an upgrade plugin: its Upgrade detection setting lists the addon, and
-- picks it by itself while no other one is picked; Baganator's "upgrade"
-- search, and the categories made with it, then find the items with an arrow.
local ID = "forever_leveling_bis"
local function HookBaganator()
    local API = Baganator and Baganator.API
    if not API then return end
    if API.RegisterCornerWidget then
        API.RegisterCornerWidget("WildGear", ID, function(_, details)
            return IsUpgrade(details.itemLink)
        end, function(button)
            local m = NewArrow(button)
            m:SetSize(SIZE, SIZE)
            return m
        end, { corner = "top_right", priority = 1 })
    end
    if API.RegisterUpgradePlugin then API.RegisterUpgradePlugin("WildGear", ID, IsUpgrade) end
    -- Redraws the corner widgets and runs the searches again (the category
    -- view sorts its items into categories again), each only while in use.
    local reasons = Baganator.Constants and Baganator.Constants.RefreshReason
    RefreshBaganator = function()
        if not API.RequestItemButtonsRefresh then return end
        if not reasons then return API.RequestItemButtonsRefresh() end -- (everything)
        local ask = {}
        if not API.IsCornerWidgetActive or API.IsCornerWidgetActive(ID) then ask[#ask + 1] = reasons.ItemWidgets end
        if API.IsUpgradePluginActive and API.IsUpgradePluginActive(ID) then ask[#ask + 1] = reasons.Searches end
        if #ask > 0 then API.RequestItemButtonsRefresh(ask) end
    end
end

---------------------------------------------------------------- keeping them current

-- What the arrows depend on besides the events below: the switch, your main
-- spec, its weapon setup and stat weights (the profile picked, as edited in
-- the window), what it is compared with, Armor type, and your skills as far
-- as they change what you can wear (ns.SkillSignature).
local function Signature()
    local p = ns.GetPlayer()
    local setup = ns.GetWeaponSetupPref(p)
    local parts = { tostring(ns.db.bagMarks), p.spec, tostring(setup),
                    tostring(ns.Tooltip.Compare(p.spec)), tostring(ns.db.classArmorOnly), ns.SkillSignature() }
    local stats = ns.WeightProfiles.InUse(p.classFile, p.spec, p.level, setup) or {}
    local keys = {}
    for key in pairs(stats) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. tostring(stats[key]) end
    return table.concat(parts, ":")
end

local signature, scheduled

-- Judges the items again and redraws the arrows.
local function Changed()
    scheduled = false
    known, player, waiting = {}, nil, nil
    signature = ns.charDB and Signature()
    Repaint()
end

-- Changed, a frame later (once for a burst of events), when every handler
-- of the event has run: the item tooltips' states are rebuilt by then.
local function Schedule()
    if scheduled then return end
    scheduled = true
    if C_Timer and C_Timer.After then C_Timer.After(0, Changed) else Changed() end
end

-- After the window's settings change (UI.Refresh, Settings): judges again
-- when anything the arrows depend on did. (The window refreshes on every
-- burst of item data the game loads: judging again then would be wasted.)
function BM.Refresh()
    if ns.charDB and Signature() ~= signature then Schedule() end
end

local events = CreateFrame("Frame")
-- (Skills: Player.lua calls UI.Refresh, and so BM.Refresh, when one changes what you can wear.)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "EQUIPMENT_SETS_CHANGED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        HookContainers()
        HookEllesmere()
        HookBagnon()
        HookBaganator()
        Schedule() -- (a bag may have been drawn before your settings were there)
    elseif not ns.charDB then
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if waiting then Schedule() end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Each bag item is judged on its own against what you wear: only the
        -- best you carry, or a set (its items may be in your bags), changes.
        if ns.Tooltip.Compare((player or ns.GetPlayer()).spec) ~= "worn" then Schedule() end
    else
        Schedule()
    end
end)
