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

-- Full quest-objective drop rates come from the optional LibQuestDB database.
-- Its Forever package covers the Classic quests shared with Era; WildSpark's local
-- rows remain as a fallback for newer/custom Forever quest items.
local function AddQuestObjectiveDrops(tooltip, npcID, seen)
    if not (LibStub and C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return false end
    local ok, questDB = pcall(LibStub, "LibQuestDB-1.0", true)
    if not ok or not questDB or not questDB.GetQuest or not questDB.GetDropRate then return false end
    if questDB.IsReady then
        local readyOK, ready = pcall(questDB.IsReady, questDB)
        if not readyOK or not ready then return false end
    end

    local added = false
    local countOK, count = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not countOK or type(count) ~= "number" then return false end
    for index = 1, count do
        local infoOK, info = pcall(C_QuestLog.GetInfo, index)
        local questID = infoOK and type(info) == "table" and not info.isHeader and info.questID
        if type(questID) == "number" and not (C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID)) then
            local questOK, quest = pcall(questDB.GetQuest, questDB, questID)
            local objectives = questOK and type(quest) == "table" and quest.objectives
            local items = type(objectives) == "table" and objectives.items
            if type(items) == "table" then
                for _, objective in pairs(items) do
                    if type(objective) == "table" then
                        local itemID = objective.id or objective.itemID or objective.itemId or objective[1]
                        if type(itemID) == "number" then
                            local key = tostring(itemID) .. ":" .. tostring(questID)
                            if not seen[key] then
                                local dropOK, percent, questOnly = pcall(questDB.GetDropRate, questDB, itemID, npcID)
                                if dropOK and type(percent) == "number" and percent > 0 then
                                    local item = ns.GetItemName(itemID)
                                    local chance = ns.FormatChance(percent)
                                    if questOnly then chance = chance .. " |cff808080(quest-only)|r" end
                                    tooltip:AddDoubleLine(item, chance)
                                    local questName = quest.name or quest.title
                                    if type(questName) ~= "string" and C_QuestLog.GetTitleForQuestID then
                                        local titleOK, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
                                        if titleOK then questName = title end
                                    end
                                    if type(questName) == "string" and questName ~= "" then
                                        tooltip:AddLine("    |cffffd100for: " .. questName .. "|r")
                                    end
                                    seen[key] = true
                                    added = true
                                end
                            end
                        end
                    end
                end
            end
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
