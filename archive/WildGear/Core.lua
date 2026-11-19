local addonName, addonRoot = ...
local ns = addonRoot.WildGear

ns.name = "WildGear"

local PREFIX = "|cff33ff99WildGear|r: "

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

function ns.Printf(fmt, ...)
    ns.Print(string.format(fmt, ...))
end

-- Item quality colours, with a fallback in case ITEM_QUALITY_COLORS is missing.
local QUALITY_HEX = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" }

-- "|cffRRGGBB" colour prefix for an item quality.
function ns.QualityHex(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return color and color.hex or ("|c" .. (QUALITY_HEX[quality] or QUALITY_HEX[1]))
end

local requested = {} -- item ids asked from the server this session, so a missing item isn't asked forever

-- Asks the server for an item's data, once per session. The windows redraw on
-- GET_ITEM_INFO_RECEIVED, so asking again on every redraw would loop for an
-- item the server answers without loading.
function ns.RequestItem(id)
    if not requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requested[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
end

-- An item's quality: the game's own once it has the item loaded, else the
-- data's. Forever lowered some quest rewards from rare to uncommon that
-- Wowhead still lists as rare (Tarnished Locket). The window refreshes on
-- GET_ITEM_INFO_RECEIVED, so names recolor once the item loads.
function ns.ItemQuality(id)
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if quality then return quality end
    ns.RequestItem(id)
    local item = ns.Items[id]
    return item and item.quality or 1
end

-- The item string of item `id` with random suffix `suffix` (an ns.Suffixes
-- id, which is the bonus list the game puts in the link), else nil.
function ns.SuffixLink(id, suffix)
    return suffix and string.format("item:%d::::::::::::1:%d", id, suffix) or nil
end

-- Item `id`'s link (with random suffix `suffix`, if given).
function ns.ItemLink(id, suffix)
    local itemString = ns.SuffixLink(id, suffix) or string.format("item:%d::::::::::::", id)
    local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(suffix and itemString or id))
    if link then return link end
    ns.RequestItem(id)
    return string.format("%s|H%s|h[%s]|h|r", ns.QualityHex(ns.ItemQuality(id)), itemString, ns.ItemName(id, suffix))
end

-- Merge Data/Overrides.lua on top of the generated item table.
local function ApplyOverrides()
    for id, ov in pairs(ns.Overrides or {}) do
        if ov == false then
            ns.Items[id] = nil
        elseif ns.Items[id] then
            for k, v in pairs(ov) do ns.Items[id][k] = v end
        else
            ns.Items[id] = ov
        end
    end
    -- What each item's effect (a proc, an on-use or equip spell) is worth per spec, as
    -- stats (Data/ItemEffects.lua): the item carries it, so copies of it (worn gear,
    -- random suffixes) do too, and the scoring adds it for the spec (Scoring.lua).
    for id, effects in pairs(ns.ItemEffects or {}) do
        if ns.Items[id] then ns.Items[id].effects = effects end
    end
end

local function DeepCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = type(v) == "table" and DeepCopy(v) or v end
    return out
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WildGearDB = WildGearDB or ForeverLevelingBiSDB or {}
        WildGearDB.chars = WildGearDB.chars or {}
        ns.db = WildGearDB
        ApplyOverrides()
    elseif event == "PLAYER_LOGIN" then
        -- Keyed by the full name: Forever's characters have a first and last
        -- name, and UnitName gives only the first, so alts sharing it shared
        -- one entry (and another class's spec was cleared at login). Up to
        -- 1.2.0 the key was the first name: a character without its own entry
        -- yet starts from a copy of that one, left for its namesakes.
        local realm = GetRealmName()
        local short = UnitName("player")
        local key = (GetUnitName("player", true) or short) .. "-" .. realm
        local old = ns.db.chars[short .. "-" .. realm]
        if not ns.db.chars[key] and old then ns.db.chars[key] = DeepCopy(old) end
        ns.db.chars[key] = ns.db.chars[key] or {}
        ns.charDB = ns.db.chars[key]
        ns.Printf(ns.L["loaded %d items (data %s). Type /wildgear to open the window."],
            ns.DataInfo.itemCount, ns.DataInfo.generated)
    end
end)
