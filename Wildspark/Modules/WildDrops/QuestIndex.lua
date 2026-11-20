-- Combines QuestieDB's current quest/item relationships with LibQuestDB drop
-- rates and QuestDropRates' name-based rates. The index is built in small timed
-- batches so a full database pass never runs inside a tooltip callback.

local _, addonNS = ...
local ns = addonNS.WildDropsCore or {}
addonNS.WildDropsCore = ns

local function SafeCall(fn, ...)
    if fn == nil then return end
    local result = { pcall(fn, ...) }
    if result[1] then return unpack(result, 2) end
end

local function NormalizeName(name)
    if type(name) ~= "string" then return "" end
    return name:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("^collect%s+", "")
end

local function QuestDropRate(itemID, npcID, itemName, npcName)
    local static = ns.QuestDropRatesByName
    local entry = static and static[NormalizeName(itemName)]
    if not entry then return end
    local wanted = NormalizeName(npcName)
    for _, source in ipairs(entry.sources or {}) do
        if NormalizeName(source.mob) == wanted and type(source.rate) == "number" and source.rate > 0 then
            return source.rate, "Legacy QuestDropRates"
        end
    end
    if NormalizeName(entry.bestMob) == wanted and type(entry.rate) == "number" and entry.rate > 0 then
        return entry.rate, "Legacy QuestDropRates"
    end
end

local function QuestDropDataRates(itemID)
    local stub = _G.LibStub
    local lib = stub and stub.GetLibrary and SafeCall(stub.GetLibrary, stub, "QuestDropData-1.0", true)
    if not lib or type(lib.GetItemRates) ~= "function" then return end
    local rates, source = SafeCall(lib.GetItemRates, lib, itemID)
    if type(rates) == "table" then return rates, source or "Forever" end
end

local function AddItemQuest(itemQuests, itemID, questID, questName, kind, requirements)
    itemID, questID = tonumber(itemID), tonumber(questID)
    if not itemID or itemID < 1 or not questID or questID < 1 then return end
    local quests = itemQuests[itemID]
    if not quests then
        quests = {}
        itemQuests[itemID] = quests
    end
    local old = quests[questID]
    if old then
        if old.name == "" and type(questName) == "string" then old.name = questName end
        if kind == "starter" then old.isStarter = true end
        if kind == "objective" then old.isObjective = true end
        if requirements then
            old.requiredRaces = requirements.requiredRaces
            old.requiredClasses = requirements.requiredClasses
            old.requiredLevel = requirements.requiredLevel
        end
        return
    end
    quests[questID] = {
        name = type(questName) == "string" and questName or "",
        isStarter = kind == "starter",
        isObjective = kind == "objective",
        requiredRaces = requirements and requirements.requiredRaces,
        requiredClasses = requirements and requirements.requiredClasses,
        requiredLevel = requirements and requirements.requiredLevel,
    }
end

function ns.GetQuestItemDrops(npcID)
    return ns.questItemDropsByNpc and ns.questItemDropsByNpc[npcID]
end

ns.OnLogin(function()
    if not (LibStub and C_Timer and C_Timer.After) then return end
    local questDB = SafeCall(LibStub, "LibQuestDB-1.0", true)
    local questieDB = _G.LibQuestieDB
    if not questDB or not questDB.GetItemDrops or not questDB.GetDropRate then return end

    local itemQuests = {}
    local questIDs = questieDB and questieDB.Quest and SafeCall(questieDB.Quest.GetAllIds) or {}
    if type(questIDs) ~= "table" then questIDs = {} end
    local questIndex = 1
    local itemIDs = {}
    local itemSeen = {}
    local phase = "quests"
    local sourceIndex = 1
    local building = {}

    local function AddItemID(itemID)
        itemID = tonumber(itemID)
        if itemID and itemID > 0 and not itemSeen[itemID] then
            itemSeen[itemID] = true
            itemIDs[#itemIDs + 1] = itemID
        end
    end

    local function AddQuestItemSource(itemID, questID, questName, kind, requirements)
        AddItemQuest(itemQuests, itemID, questID, questName, kind, requirements)
        AddItemID(itemID)
    end

    local function AddGroupItems(questID, questName, items, kind, requirements)
        if type(items) ~= "table" then return end
        for _, objective in pairs(items) do
            if type(objective) == "table" then
                AddQuestItemSource(objective[1] or objective.id or objective.itemID, questID, questName, kind, requirements)
            elseif type(objective) == "number" then
                AddQuestItemSource(objective, questID, questName, kind, requirements)
            end
        end
    end

    local function AddItemSources(itemID, questID, questName)
        local sourceNPCs, rates = {}, {}
        local foreverRates, foreverSource = QuestDropDataRates(itemID)
        local itemEntity = questieDB and questieDB.Item
        local itemName = itemEntity and SafeCall(itemEntity.Get, itemID, "name") or ns.Items[itemID]
        local npcIDs = itemEntity and SafeCall(itemEntity.Get, itemID, "npcDrops")
        if type(npcIDs) == "table" then
            for _, npcID in pairs(npcIDs) do
                npcID = tonumber(npcID)
                if npcID then sourceNPCs[npcID] = true end
            end
        end

        if foreverRates then
            for npcID in pairs(foreverRates) do
                npcID = tonumber(npcID)
                if npcID then sourceNPCs[npcID] = true end
            end
        end

        local dropData = SafeCall(questDB.GetItemDrops, questDB, itemID)
        local npcDrops = type(dropData) == "table" and dropData.npcs
        if type(npcDrops) == "table" then
            for _, source in ipairs(npcDrops) do
                local npcID = type(source) == "table" and tonumber(source.id)
                if npcID then
                    sourceNPCs[npcID] = true
                    if type(source.percent) == "number" and source.percent ~= 0 then
                        rates[npcID] = { percent = math.abs(source.percent), questOnly = source.questOnly, rateSource = "Classic reference" }
                    end
                end
            end
        end

        for npcID in pairs(sourceNPCs) do
            local rateInfo
            if foreverRates then
                local percent = tonumber(foreverRates[npcID])
                rateInfo = {
                    percent = percent and percent > 0 and percent or nil,
                    rateSource = foreverSource,
                    explicitUnknown = not (percent and percent > 0),
                }
            else
                rateInfo = rates[npcID]
            end
            if not rateInfo then
                local percent, questOnly = SafeCall(questDB.GetDropRate, questDB, itemID, npcID)
                if type(percent) == "number" and percent > 0 then
                    rateInfo = { percent = math.abs(percent), questOnly = questOnly, rateSource = "Classic reference" }
                end
            end
            if not rateInfo or (not rateInfo.explicitUnknown and not rateInfo.percent) then
                local npcName = itemEntity and SafeCall(questieDB.Npc.Get, npcID, "name")
                local percent, rateSource = QuestDropRate(itemID, npcID, itemName, npcName)
                if percent then rateInfo = { percent = percent, rateSource = rateSource } end
            end

            local quests = itemQuests[itemID]
            if quests then
                for linkedQuestID, info in pairs(quests) do
                    local recordKey = tostring(itemID) .. ":" .. tostring(linkedQuestID)
                    local npcRows = building[npcID]
                    if not npcRows then
                        npcRows = {}
                        building[npcID] = npcRows
                    end
                    if not npcRows[recordKey] then
                        local questName = info.name
                        if questName == "" and questieDB and questieDB.Quest then
                            questName = SafeCall(questieDB.Quest.Get, linkedQuestID, "name") or ""
                        end
                        npcRows[recordKey] = {
                            itemID = itemID,
                            questID = linkedQuestID,
                            questName = questName,
                            isStarter = info.isStarter,
                            isObjective = info.isObjective,
                            requiredRaces = info.requiredRaces,
                            requiredClasses = info.requiredClasses,
                            requiredLevel = info.requiredLevel,
                            percent = rateInfo and rateInfo.percent or nil,
                            questOnly = rateInfo and rateInfo.questOnly or false,
                            rateSource = rateInfo and rateInfo.rateSource,
                        }
                    elseif rateInfo and rateInfo.percent then
                        npcRows[recordKey].percent = rateInfo.percent
                        npcRows[recordKey].questOnly = rateInfo.questOnly or false
                        npcRows[recordKey].rateSource = rateInfo.rateSource
                    elseif rateInfo and rateInfo.explicitUnknown then
                        npcRows[recordKey].percent = nil
                        npcRows[recordKey].rateSource = rateInfo.rateSource
                    end
                end
            end
        end
    end

    local dbItemIDs = SafeCall(questDB.GetQuestItemIds, questDB)
    if type(dbItemIDs) == "table" then
        for _, itemID in ipairs(dbItemIDs) do
            AddItemID(itemID)
            local linkedQuests = SafeCall(questDB.GetQuestsInvolvingItem, questDB, itemID)
            if type(linkedQuests) == "table" then
                for _, questID in ipairs(linkedQuests) do
                    local row = SafeCall(questDB.GetQuest, questDB, questID)
                    AddItemQuest(itemQuests, itemID, questID, type(row) == "table" and (row.name or row.title) or "")
                end
            end
        end
    end

    local function BuildChunk()
        if phase == "quests" then
            local stop = math.min(questIndex + 39, #questIDs)
            while questIndex <= stop do
                local questID = questIDs[questIndex]
                questIndex = questIndex + 1
                local questEntity = questieDB.Quest
                local questName = SafeCall(questEntity.Get, questID, "name") or ""
                local requirements = {
                    requiredRaces = SafeCall(questEntity.Get, questID, "requiredRaces"),
                    requiredClasses = SafeCall(questEntity.Get, questID, "requiredClasses"),
                    requiredLevel = SafeCall(questEntity.Get, questID, "requiredLevel"),
                }
                local objectives = SafeCall(questEntity.Get, questID, "objectives")
                if type(objectives) == "table" then AddGroupItems(questID, questName, objectives[3], "objective", requirements) end
                local startedBy = SafeCall(questEntity.Get, questID, "startedBy")
                if type(startedBy) == "table" then AddGroupItems(questID, questName, startedBy[3], "starter", requirements) end
            end
            if questIndex <= #questIDs then
                C_Timer.After(0.02, BuildChunk)
                return
            end
            phase = "sources"
        end

        local stop = math.min(sourceIndex + 79, #itemIDs)
        while sourceIndex <= stop do
            AddItemSources(itemIDs[sourceIndex], nil, nil)
            sourceIndex = sourceIndex + 1
        end
        if sourceIndex <= #itemIDs then
            C_Timer.After(0.02, BuildChunk)
            return
        end

        for npcID, rows in pairs(building) do
            local list = {}
            for _, row in pairs(rows) do list[#list + 1] = row end
            table.sort(list, function(a, b)
                if a.itemID ~= b.itemID then return a.itemID < b.itemID end
                return a.questID < b.questID
            end)
            building[npcID] = list
        end
        ns.questItemDropsByNpc = building
        if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
            pcall(GameTooltip.RefreshData, GameTooltip)
        end
    end

    C_Timer.After(0.1, BuildChunk)
end)
