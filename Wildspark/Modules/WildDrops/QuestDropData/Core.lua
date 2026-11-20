-- QuestDropData-1.0: drop rates of quest items, mob by mob, and the number of
-- spawn points of every mob per zone (WoW Forever data from QuestieDB).
--
-- Shared by QuestDropRates and QuestLuck: both addons embed it, and LibStub keeps
-- a single copy (the newest), so the data is loaded and the work is done once even
-- when both addons are installed.
--
-- Data.lua (generated from QuestieDB) gives, for each quest, the items that drop
-- from mobs; for each item, the drop rate of every mob (WoW Forever data and
-- QuestLuck players); for each mob, its number of spawn points in each zone.

local MAJOR, MINOR = "QuestDropData-1.0", 13
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end   -- the same or a newer copy is already loaded
lib.pendingData = true       -- Data.lua, loaded next, fills lib.Data
lib.pendingBugReport = true  -- BugReport.lua, loaded after, builds the bug report window
lib.MINOR = MINOR

lib.UNKNOWN = "unknown"      -- source of the items dropped by mobs with no known rate

---------------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------------

-- This client can protect some values ("secret values"): they are never read.
local issecretvalue = issecretvalue
local function Plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end
lib.Plain = Plain

-- "31%", "18.5%", "3.4%", "0.25%" ("?" when there is no rate).
function lib.FormatPercent(x)
    if type(x) ~= "number" then return "?" end
    local text = (x < 1 and "%.2f" or "%.1f"):format(x)
    text = text:gsub("0+$", ""):gsub("%.$", "")
    return text .. "%"
end

-- "Gnoll Paw: 3/20" or "3/20 Gnoll Paw" -> name, current, required.
function lib.ParseObjective(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    local cur, req = text:match("(%d+)%s*/%s*(%d+)")
    local name = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%s*%d+%s*/%s*%d+%s*", "")
    name = name:gsub("\194\160", " "):match("^%s*(.-)%s*:?%s*$")
    if not name or name == "" then return nil end
    return name, tonumber(cur), tonumber(req)
end

-- Item name in the client language (loaded on demand: nil until the client has it).
function lib:ItemName(itemID)
    local name
    if C_Item and C_Item.GetItemNameByID then name = Plain(C_Item.GetItemNameByID(itemID)) end
    if not name and GetItemInfo then name = Plain((GetItemInfo(itemID))) end
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return name
end

-- Item name to show: the client's one, else the English name of the data (an item the
-- client has not loaded yet, e.g. in a quest offered by a quest giver).
function lib:ItemDisplayName(itemID)
    local d = self.Data.items[itemID]
    return self:ItemName(itemID) or (d and d[3])
end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------

-- Items of a quest that drop from mobs: { itemID, ... }, or nil if the quest has none.
function lib:GetQuestItems(questID)
    local q = lib.Data.quests[questID]
    if not q then return nil end
    local list = {}
    for i = 2, #q do list[#list + 1] = q[i] end
    return list
end

-- Zone of the quest (AreaTable ID), or nil.
function lib:GetQuestZone(questID)
    local q = lib.Data.quests[questID]
    local zone = q and q[1]
    return zone and zone > 0 and zone or nil
end

-- Drop rates of an item: { [npcID] = rate in % (0 = unknown) }, source; nil if the item is not covered.
function lib:GetItemRates(itemID)
    local d = lib.Data.items[itemID]
    if d then return d[2], d[1] end
end

function lib:NpcName(npcID)
    local n = lib.Data.npcs[npcID]
    return n and n[1] or ("Mob #%d"):format(npcID)
end

-- Number of spawn points of a mob in a zone (all zones if zone is nil).
function lib:NpcSpawns(npcID, zone)
    local n = lib.Data.npcs[npcID]
    if not n then return 0 end
    if zone then return n[2][zone] or 0 end
    local total = 0
    for _, count in pairs(n[2]) do total = total + count end
    return total
end

-- Zone name in the client language.
function lib:ZoneName(zone)
    if not zone then return "all zones" end
    if C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, zone)
        name = ok and Plain(name)
        if type(name) == "string" and name ~= "" then return name end
    end
    return ("zone %d"):format(zone)
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------

-- Names of the zone the player is in (lower case).
local function PlayerZoneNames()
    local names = {}
    local function Add(name)
        name = Plain(name)
        if type(name) == "string" and name ~= "" then names[name:lower()] = true end
    end
    if GetRealZoneText then Add(GetRealZoneText()) end
    if GetZoneText then Add(GetZoneText()) end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local map = Plain(C_Map.GetBestMapForUnit("player"))
        local info = map and C_Map.GetMapInfo(map)
        if info then Add(info.name) end
    end
    return names
end

-- Zone of the mobs to list for an item: the quest zone if some of these mobs spawn
-- there, otherwise the zone the player is in if some of them spawn there,
-- otherwise nil (all zones).
function lib:PickZone(questID, itemID)
    local rates = self:GetItemRates(itemID)
    if not rates then return nil end
    local zones = {}
    for npc in pairs(rates) do
        local n = lib.Data.npcs[npc]
        if n then for zone in pairs(n[2]) do zones[zone] = true end end
    end
    local questZone = questID and self:GetQuestZone(questID)
    if questZone and zones[questZone] then return questZone end
    local here = PlayerZoneNames()
    for zone in pairs(zones) do
        if here[self:ZoneName(zone):lower()] then return zone end
    end
    return nil
end

-- Drop details of an item:
--   zone      zone of the listed mobs (nil = all zones)
--   source    "Forever", "players", "Forever+players" or lib.UNKNOWN
--   mobs      { { npc, name, rate (nil if unknown), spawns }, ... }, highest rate first
--   lo, hi    lowest and highest known rate of these mobs
--   focus     the mob with the highest rate
--   weighted  average rate of these mobs weighted by their number of spawn points
--             (nil without spawn data)
-- zone: a zone ID, false for all zones, nil to pick it (lib:PickZone).
function lib:GetDropInfo(questID, itemID, zone)
    local rates, source = self:GetItemRates(itemID)
    if not rates then return nil end
    if zone == nil then zone = self:PickZone(questID, itemID) or false end
    local info = { zone = zone or nil, source = source, known = source ~= self.UNKNOWN, mobs = {} }
    local spawnSum, weightedSum = 0, 0
    for npc, rate in pairs(rates) do
        local spawns = self:NpcSpawns(npc, zone or nil)
        if not zone or spawns > 0 then
            local m = { npc = npc, name = self:NpcName(npc), rate = rate > 0 and rate or nil, spawns = spawns }
            info.mobs[#info.mobs + 1] = m
            if m.rate then
                info.lo = math.min(info.lo or m.rate, m.rate)
                info.hi = math.max(info.hi or m.rate, m.rate)
                spawnSum = spawnSum + spawns
                weightedSum = weightedSum + spawns * m.rate
            end
        end
    end
    -- A zone where none of these mobs spawn (saved by an older version): all zones.
    if zone and #info.mobs == 0 then return self:GetDropInfo(questID, itemID, false) end
    table.sort(info.mobs, function(a, b)
        if (a.rate or -1) ~= (b.rate or -1) then return (a.rate or -1) > (b.rate or -1) end
        if a.spawns ~= b.spawns then return a.spawns > b.spawns end
        return a.name < b.name
    end)
    if info.mobs[1] and info.mobs[1].rate then info.focus = info.mobs[1] end
    if spawnSum > 0 then info.weighted = weightedSum / spawnSum end
    return info
end

---------------------------------------------------------------------------
-- Quest log
---------------------------------------------------------------------------

-- Quests in the log: { { questID, title, level, index }, ... }.
function lib:GetLogQuests()
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetNumQuestLogEntries and Q.GetInfo then
        for i = 1, Plain(Q.GetNumQuestLogEntries()) or 0 do
            local info = Q.GetInfo(i)
            local id = info and Plain(info.questID)
            if info and not info.isHeader and type(id) == "number" and id > 0 then
                list[#list + 1] = { questID = id, title = Plain(info.title), level = Plain(info.level), index = i }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, Plain(GetNumQuestLogEntries()) or 0 do
            local title, level, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
            id = Plain(id)
            if not isHeader and type(id) == "number" and id > 0 then
                list[#list + 1] = { questID = id, title = Plain(title), level = Plain(level), index = i }
            end
        end
    end
    return list
end

local function LogIndex(questID)
    if GetQuestLogIndexByID then
        local index = Plain(GetQuestLogIndexByID(questID))
        if type(index) == "number" and index > 0 then return index end
    end
    for _, q in ipairs(lib:GetLogQuests()) do
        if q.questID == questID then return q.index end
    end
end

-- "Item" objectives of a quest in the log: { { name, cur, req }, ... }.
local function RawItemObjectives(questID, logIndex)
    local list = {}
    local Q = C_QuestLog
    if Q and Q.GetQuestObjectives then
        for _, o in ipairs(Q.GetQuestObjectives(questID) or {}) do
            if Plain(o.type) == "item" then
                local name, cur, req = lib.ParseObjective(o.text)
                cur = Plain(o.numFulfilled) or cur
                req = Plain(o.numRequired) or req
                if name and cur and req then list[#list + 1] = { name = name, cur = cur, req = req } end
            end
        end
    elseif GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        logIndex = logIndex or LogIndex(questID)
        if not logIndex then return list end
        for i = 1, Plain(GetNumQuestLeaderBoards(logIndex)) or 0 do
            local text, kind = GetQuestLogLeaderBoard(i, logIndex)
            if Plain(kind) == "item" then
                local name, cur, req = lib.ParseObjective(text)
                if name and cur and req then list[#list + 1] = { name = name, cur = cur, req = req } end
            end
        end
    end
    return list
end

-- Objectives of a quest in the log whose item drops from mobs:
-- { { name, cur, req, itemID }, ... }. Items are recognized by name (same
-- language as the client); a quest with a single such item needs no name.
lib.RawItemObjectives = RawItemObjectives

-- Single items that do not always drop (listed in tools/data/keep_single.json): kept
-- although the quest asks for only one.
function lib:KeepsSingleItem(itemID)
    return self.Data.keepSingle and self.Data.keepSingle[itemID] or false
end

-- Objectives asking for a single item ("0/1": a boss head, a key...) are left out,
-- except the items of Data.keepSingle:
-- such items almost always drop every time, there is no luck to measure.
function lib:GetItemObjectives(questID, logIndex)
    local ids = self:GetQuestItems(questID)
    if not ids then return {} end
    local objectives = RawItemObjectives(questID, logIndex)
    local matched = {}
    if #ids == 1 and #objectives == 1 then
        objectives[1].itemID = ids[1]
        matched = objectives
    else
        for _, obj in ipairs(objectives) do
            for _, id in ipairs(ids) do
                local name = self:ItemName(id)
                if name and name:lower() == obj.name:lower() then
                    obj.itemID = id
                    matched[#matched + 1] = obj
                    break
                end
            end
        end
    end
    local kept = {}
    for _, obj in ipairs(matched) do
        if obj.req > 1 or lib:KeepsSingleItem(obj.itemID) then kept[#kept + 1] = obj end
    end
    return kept
end

-- A quest in the log that needs this item: questID, objective.
function lib:FindQuestForItem(itemID)
    for _, q in ipairs(self:GetLogQuests()) do
        local ids = self:GetQuestItems(q.questID)
        if ids then
            for _, id in ipairs(ids) do
                if id == itemID then
                    for _, o in ipairs(self:GetItemObjectives(q.questID, q.index)) do
                        if o.itemID == itemID then return q.questID, o end
                    end
                    return q.questID
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Kills
---------------------------------------------------------------------------

-- NPC ID of a creature GUID.
function lib.NpcID(guid)
    guid = Plain(guid)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

-- True for you, your pet, and your group members and their pets.
function lib.IsGroupGUID(guid)
    if guid == Plain(UnitGUID("player")) or guid == Plain(UnitGUID("pet")) then return true end
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return false
    end
    for i = 1, count do
        if guid == Plain(UnitGUID(prefix .. i)) or guid == Plain(UnitGUID(prefix .. "pet" .. i)) then
            return true
        end
    end
    return false
end

-- Sharing between the two addons. When QuestLuck is installed it counts the kills
-- and gives its own kills-to-go estimate (with your share in a group);
-- QuestDropRates then reads them instead of counting a second time.
--   counter(questID, itemID) returns the number of mobs killed for an objective.
--   provider(questID, objective, info) returns an estimated number of kills to go.
function lib:SetKillCounter(counter) self.killCounter = counter end
function lib:SetKillsToGoProvider(provider) self.killsProvider = provider end

-- Estimated kills to finish an objective: items still needed divided by the average
-- drop rate of the zone's mobs weighted by their spawn points (plain average of the
-- rates without spawn data). nil when the objective is complete or the rate unknown.
function lib:KillsToGo(questID, objective, info)
    local left = (objective.req or 0) - (objective.cur or 0)
    if left <= 0 then return nil end
    if self.killsProvider then
        local ok, kills = pcall(self.killsProvider, questID, objective, info)
        if ok and type(kills) == "number" then return kills end
    end
    local rate = info.weighted
    if not rate then
        local sum, count = 0, 0
        for _, m in ipairs(info.mobs) do
            if m.rate then sum, count = sum + m.rate, count + 1 end
        end
        rate = count > 0 and sum / count or nil
    end
    if not rate or rate <= 0 then return nil end
    return math.ceil(left / (rate / 100))
end

---------------------------------------------------------------------------
-- Item names: loaded in advance for the quests in the log, so that objectives
-- are recognized as soon as the quest log opens.
---------------------------------------------------------------------------

lib.frame = lib.frame or CreateFrame("Frame")
local frame = lib.frame
local function Preload()
    for _, q in ipairs(lib:GetLogQuests()) do
        for _, id in ipairs(lib:GetQuestItems(q.questID) or {}) do lib:ItemName(id) end
    end
end
frame:SetScript("OnEvent", function()
    pcall(Preload)
end)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_ACCEPTED")
