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

local function IsQuestActive(questID)
    if ns.questsInLog and ns.questsInLog[questID] then return true end
    local isOnQuest = C_QuestLog and C_QuestLog.IsOnQuest
    if not isOnQuest then return false end
    local ok, active = pcall(isOnQuest, questID)
    return ok and active == true
end

local function MaskOverlaps(a, b)
    if type(a) ~= "number" or a == 0 then return true end
    if type(b) ~= "number" then return false end
    a, b = math.floor(a), math.floor(b)
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then return true end
        a, b = math.floor(a / 2), math.floor(b / 2)
    end
    return false
end

local function CanStartQuest(record)
    if not record.isStarter or IsQuestActive(record.questID) then return false end
    local completed = ns.IsQuestCompleted
    if completed then
        local ok, done = pcall(completed, record.questID)
        if ok and done then return false end
    end
    local level = UnitLevel and UnitLevel("player") or 0
    if type(record.requiredLevel) == "number" and record.requiredLevel > level then return false end

    local db = _G.LibQuestieDB
    local enums = db and db.Enum
    local classToken
    if UnitClass then local _, token = UnitClass("player"); classToken = token end
    local classMask = enums and enums.classKeys and classToken and enums.classKeys[classToken]
    if not MaskOverlaps(record.requiredClasses, classMask) then return false end

    local raceID
    if UnitRace then local _, _, id = UnitRace("player"); raceID = id end
    local raceMask = enums and enums.raceMaskById and raceID and enums.raceMaskById[raceID]
    if not MaskOverlaps(record.requiredRaces, raceMask) then return false end
    return true
end

-- Merge identical items and keep quest names only when the player can act on them.
local function AddQuestObjectiveDrops(rows, order, npcID)
    local records = ns.GetQuestItemDrops and ns.GetQuestItemDrops(npcID)
    if type(records) ~= "table" then return end
    for _, record in ipairs(records) do
        local id = tonumber(record.itemID)
        local activeQuest = IsQuestActive(record.questID)
        local startableQuest = CanStartQuest(record)
        local questRelevant = activeQuest or startableQuest
        local showRecord = (ns.db.showQuestDrops ~= false and questRelevant)
            or (ns.db.showNormalDrops ~= false and not record.questOnly)
        if id and showRecord then
            local row = rows[id]
            if not row then
                row = { itemID = id, percent = record.percent, rateSource = record.rateSource, questOnly = record.questOnly, quests = {}, questSet = {} }
                rows[id] = row
                order[#order + 1] = id
            elseif record.rateSource and record.rateSource ~= "Classic reference" then
                row.percent = record.percent
                row.rateSource = record.rateSource
            elseif not row.percent and record.percent then
                row.percent = record.percent
                row.rateSource = record.rateSource or row.rateSource
            end
            if record.rateSource and record.rateSource ~= "Classic reference" then row.rateSource = record.rateSource end
            if record.questOnly then row.questOnly = true end
            local name = questRelevant and record.questName
            if type(name) == "string" and name ~= "" and not row.questSet[name] then
                row.questSet[name] = true
                row.quests[#row.quests + 1] = name
            end
        end
    end
end

local function AddTooltipLines(tooltip, guid)
    if not ns.db or ns.db.enabled == false or ns.db.tooltip == false or tooltip ~= GameTooltip then return end
    local npcID = ns.GetNpcID(guid) -- nil for players, game objects, or an unreadable GUID
    if not npcID then return end

    local rows, order = {}, {}
    local drops = ns.db.showQuestDrops ~= false and ns.GetAvailableDrops(npcID)
    if drops then
        for _, drop in ipairs(drops) do
            local id = tonumber(drop[1])
            if id then
                local row = rows[id]
                if not row then
                row = { itemID = id, percent = drop[3], quests = {}, questSet = {} }
                    rows[id] = row
                    order[#order + 1] = id
                elseif not row.percent and drop[3] then
                    row.percent = drop[3]
                end
                local _, quest = ns.FormatDropParts(drop)
                if type(quest) == "string" and quest ~= "" and not row.questSet[quest] then
                    row.questSet[quest] = true
                    row.quests[#row.quests + 1] = quest
                end
            end
        end
    end
    AddQuestObjectiveDrops(rows, order, npcID)

    local added = false
    local maxRows = 8
    local shown = math.min(#order, maxRows)
    for i = 1, shown do
        local row = rows[order[i]]
        local chance = ns.FormatChance(row.percent)
        if not row.percent and ns.GetLocalDropRateEstimate then
            local estimate = ns.GetLocalDropRateEstimate(npcID, row.itemID)
            if estimate and estimate.percent then
                chance = string.format("|cffffd100~%.1f%% local estimate (%d/%d looted corpses)|r", estimate.percent, estimate.drops, estimate.samples)
            elseif estimate and estimate.samples then
                chance = string.format("|cff808080rate unknown; local sample %d/%d looted corpses|r", estimate.samples, estimate.needed or 10)
            end
        end
        if row.rateSource and row.rateSource ~= "Classic reference" then
            local label = row.percent and (row.rateSource .. " data") or ("no " .. row.rateSource .. " rate")
            chance = chance .. " |cff808080(" .. label .. ")|r"
        elseif row.rateSource == "Classic reference" then
            chance = chance .. " |cffffc857(Classic reference)|r"
        end
        if row.questOnly then chance = chance .. " |cff808080(quest-only)|r" end
        tooltip:AddDoubleLine(ns.GetItemName(row.itemID), chance)
        if #row.quests > 0 then
            local questText = row.quests[1]
            if #row.quests > 1 then questText = questText .. " |cffaaaaaa(+" .. (#row.quests - 1) .. " more quests)|r" end
            tooltip:AddLine("    |cffffd100For: " .. questText .. "|r")
        end
        added = true
    end
    if #order > shown then
        tooltip:AddLine("|cffaaaaaa…and " .. (#order - shown) .. " more unique drops|r")
        added = true
    end

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
