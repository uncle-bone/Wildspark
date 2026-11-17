-- Local estimates for quest-item drops whose published chance is unknown.
-- Only LOOT_OPENED is observed: this client forbids registering the combat-log
-- event, so the sample is explicitly looted corpses rather than every kill.
local _, addonNS = ...
local ns = addonNS.WildDropsCore
local MIN_SAMPLES, MAX_AGE = 10, 3600
local observedCorpses = {}

local function enabled()
    return ns.db and ns.db.enabled ~= false and ns.db.estimateDropRates ~= false
end

local function EnsureNPC(npcID)
    local db = _G.WildInfoDropRatesDB
    if type(db) ~= "table" then return end
    local row = db[npcID]
    if type(row) ~= "table" then row = { samples = 0, items = {} }; db[npcID] = row end
    row.samples = tonumber(row.samples) or 0
    row.items = type(row.items) == "table" and row.items or {}
    return row
end

local function EnsureUnknownItems(npcID, row)
    local records = ns.GetQuestItemDrops and ns.GetQuestItemDrops(npcID)
    if type(records) ~= "table" then return end
    for _, record in ipairs(records) do
        local id = tonumber(record.itemID)
        if id and not tonumber(record.percent) and type(row.items[id]) ~= "table" then
            row.items[id] = { drops = 0 }
        end
    end
end

local function OnLootOpened()
    if not enabled() or type(GetNumLootItems) ~= "function" or type(GetLootSourceInfo) ~= "function" then return end
    local now = GetTime and GetTime() or time()
    local sources = {}
    for slot = 1, (GetNumLootItems() or 0) do
        local link = GetLootSlotLink and GetLootSlotLink(slot)
        local itemID = type(link) == "string" and tonumber(link:match("|Hitem:(%d+)"))
        local sourceInfo = { GetLootSourceInfo(slot) }
        for index = 1, #sourceInfo, 2 do
            local guid = sourceInfo[index]
            local npcID = guid and ns.GetNpcID(guid)
            if npcID then
                local entry = sources[guid]
                if not entry then entry = { npcID = npcID, items = {} }; sources[guid] = entry end
                if itemID then entry.items[itemID] = true end
            end
        end
    end

    for guid, source in pairs(sources) do
        if not observedCorpses[guid] then
            observedCorpses[guid] = now
            local row = EnsureNPC(source.npcID)
            if row then
                row.samples = row.samples + 1
                EnsureUnknownItems(source.npcID, row)
                for itemID in pairs(source.items) do
                    local stats = row.items[itemID]
                    if stats then stats.drops = (tonumber(stats.drops) or 0) + 1 end
                end
            end
        end
    end
    for guid, stamp in pairs(observedCorpses) do
        if now - stamp > MAX_AGE then observedCorpses[guid] = nil end
    end
end

-- Register this non-combat event at file load; never request the protected
-- COMBAT_LOG_EVENT_UNFILTERED event on this client.
ns.RegisterEvent("LOOT_OPENED", OnLootOpened)

function ns.GetLocalDropRateEstimate(npcID, itemID)
    local db = _G.WildInfoDropRatesDB
    local row = type(db) == "table" and db[npcID]
    local stats = type(row) == "table" and type(row.items) == "table" and row.items[itemID]
    if type(row) ~= "table" or type(stats) ~= "table" then return nil end
    local samples, drops = tonumber(row.samples) or 0, tonumber(stats.drops) or 0
    drops = math.min(samples, drops)
    if samples >= MIN_SAMPLES then
        return { percent = drops * 100 / samples, drops = drops, samples = samples }
    end
    if samples > 0 then return { drops = drops, samples = samples, needed = MIN_SAMPLES } end
end

ns.OnLogin(function()
    _G.WildInfoDropRatesDB = type(_G.WildInfoDropRatesDB) == "table" and _G.WildInfoDropRatesDB or {}
end)
