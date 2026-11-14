-- Mob tooltips: item, drop chance and the quest it starts.

local _, addonNS = ...
local ns = addonNS.WildDropsCore or {}
addonNS.WildDropsCore = ns

ns.tooltipHook = "none" -- which hook is in use, shown by /qd target

-- The GUID of the unit a tooltip shows, or nil. Newer clients may hand addons a
-- secret unit token, and addon code may not even pass that to UnitGUID.
local function GetTooltipUnitGUID(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit or ns.IsSecret(unit) then return end
    return UnitGUID(unit)
end

local hasOurLines = false -- the shown GameTooltip contains our lines (cleared on hide)

function ns.RefreshRespawnTooltip()
    if not hasOurLines or not GameTooltip:IsShown() then return end
    if GameTooltip.RefreshData then
        pcall(GameTooltip.RefreshData, GameTooltip)
        return
    end
    local _, unit = GameTooltip:GetUnit()
    if unit and not ns.IsSecret(unit) then
        pcall(GameTooltip.SetUnit, GameTooltip, unit)
    end
end

-- Quest objective and starter drops are indexed across the full bundled database,
-- so the tooltip can show quests that are not currently in the player's quest log.
local function AddQuestObjectiveDrops(tooltip, npcID, seen)
    local records = ns.GetQuestItemDrops and ns.GetQuestItemDrops(npcID)
    if type(records) ~= "table" then return false end
    local added = false
    for _, record in ipairs(records) do
        local key = tostring(record.itemID) .. ":" .. tostring(record.questID)
        if not seen[key] then
            local chance = ns.FormatChance(record.percent)
            if record.questOnly then chance = chance .. " |cff808080(quest-only)|r" end
            tooltip:AddDoubleLine(ns.GetItemName(record.itemID), chance)
            if type(record.questName) == "string" and record.questName ~= "" then
                tooltip:AddLine("    |cffffd100for: " .. record.questName .. "|r")
            end
            seen[key] = true
            added = true
        end
    end
    return added
end

local function AddTooltipLines(tooltip, guid)
    if not ns.db or ns.db.enabled == false or ns.db.tooltip == false or tooltip ~= GameTooltip then return end
    local npcID = ns.GetNpcID(guid) -- nil for players, game objects, or an unreadable GUID
    if not npcID then return end

    local added = false
    local seen = {}
    local drops = ns.GetAvailableDrops(npcID)
    if drops then
        for _, drop in ipairs(drops) do
            local item, quest = ns.FormatDropParts(drop)
            tooltip:AddDoubleLine(item, ns.FormatChance(drop[3]))
            tooltip:AddLine(quest)
            seen[tostring(drop[1]) .. ":" .. tostring(drop[2])] = true
            added = true
        end
    end
    if AddQuestObjectiveDrops(tooltip, npcID, seen) then added = true end

    local respawnText = ns.GetRespawnText and ns.GetRespawnText(npcID)
    if respawnText then
        tooltip:AddLine("|cff66ccffWildInfo:|r " .. respawnText, nil, nil, nil, true)
        added = true
    end

    if not added then return end
    hasOurLines = true
    tooltip:Show()
end

ns.OnLogin(function()
    if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            local guid = data and data.guid
            -- The tooltip data may carry a secret GUID; the unit's own one may be readable.
            if not guid or ns.IsSecret(guid) then
                guid = GetTooltipUnitGUID(tooltip)
            end
            AddTooltipLines(tooltip, guid)
        end)
        ns.tooltipHook = "TooltipDataProcessor"
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            AddTooltipLines(tooltip, GetTooltipUnitGUID(tooltip))
        end)
        ns.tooltipHook = "OnTooltipSetUnit"
    end
    GameTooltip:HookScript("OnHide", function() hasOurLines = false end)
end)

-- An item name in our open tooltip lines loaded late: rebuild the tooltip so it
-- shows the name in its quality colour.
ns.OnItemInfoLoaded(function()
    if not hasOurLines or not GameTooltip:IsShown() then return end
    if GameTooltip.RefreshData then
        GameTooltip:RefreshData() -- rebuilds from the tooltip's own data, no unit token needed
        return
    end
    local _, unit = GameTooltip:GetUnit()
    if unit and not ns.IsSecret(unit) then
        GameTooltip:SetUnit(unit)
    end
end)
