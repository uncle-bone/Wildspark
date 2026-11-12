-- WildInfo local respawn observations.
-- A cycle is learned only when this client observes an NPC die and later sees a
-- different GUID for the same NPC ID appear on a nameplate. Estimates are local
-- and approximate; they are never presented as server-provided timings.

local _, addonNS = ...
local ns = addonNS.WildDropsCore or {}
addonNS.WildDropsCore = ns

local MIN_RESPAWN_SECONDS = 10
local MAX_RESPAWN_SECONDS = 7 * 24 * 60 * 60
local SAMPLE_RETENTION_SECONDS = 90 * 24 * 60 * 60
local MAX_SAMPLES_PER_NPC = 10
local MAX_NPC_RECORDS = 500

local pendingDeaths = {} -- [npcID] = { at = time, guid = guid }; session-only to avoid offline gaps
local platesByUnit = {}  -- [nameplate unit] = { npcID, guid }
local visibleByNpc = {}  -- [npcID] = number of currently visible plates

local function EnsureSamples()
    if not ns.db then return end
    if type(ns.db.respawnSamples) ~= "table" then
        ns.db.respawnSamples = {}
    end
end

local function GetNpcIDFromUnit(unit)
    if not unit or type(UnitGUID) ~= "function" then return end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not guid or ns.IsSecret(guid) then return end
    return ns.GetNpcID(guid), guid
end

local function RemovePlate(unit)
    local old = platesByUnit[unit]
    if not old then return end
    platesByUnit[unit] = nil
    visibleByNpc[old.npcID] = math.max(0, (visibleByNpc[old.npcID] or 1) - 1)
end

local function AddSample(npcID, seconds, now)
    EnsureSamples()
    if not ns.db or ns.db.respawnEnabled == false then return end
    if seconds < MIN_RESPAWN_SECONDS or seconds > MAX_RESPAWN_SECONDS then return end

    local samples = ns.db.respawnSamples[npcID]
    if type(samples) ~= "table" then
        local recordCount = 0
        local oldestID, oldestAt
        for id, records in pairs(ns.db.respawnSamples) do
            recordCount = recordCount + 1
            local newestAt = 0
            if type(records) == "table" then
                for _, record in ipairs(records) do
                    if type(record) == "table" and type(record.at) == "number" and record.at > newestAt then
                        newestAt = record.at
                    end
                end
            end
            if not oldestAt or newestAt < oldestAt then
                oldestID, oldestAt = id, newestAt
            end
        end
        if recordCount >= MAX_NPC_RECORDS and oldestID then
            ns.db.respawnSamples[oldestID] = nil
        end
        samples = {}
        ns.db.respawnSamples[npcID] = samples
    end
    samples[#samples + 1] = { seconds = math.floor(seconds + 0.5), at = now }

    -- Keep the newest bounded set so saved variables stay small and estimates stay current.
    while #samples > MAX_SAMPLES_PER_NPC do
        table.remove(samples, 1)
    end
end

local function OnNameplateAdded(unit)
    RemovePlate(unit)
    local npcID, guid = GetNpcIDFromUnit(unit)
    if not npcID then return end

    platesByUnit[unit] = { npcID = npcID, guid = guid }
    visibleByNpc[npcID] = (visibleByNpc[npcID] or 0) + 1

    local death = pendingDeaths[npcID]
    if not death or death.guid == guid then return end

    local now = time()
    local elapsed = now - death.at
    if elapsed >= MIN_RESPAWN_SECONDS and elapsed <= MAX_RESPAWN_SECONDS then
        -- If another same-ID NPC was already visible when the death happened, we did
        -- not keep that death as a sample. This reduces false matches for common mobs.
        AddSample(npcID, elapsed, now)
        pendingDeaths[npcID] = nil
    elseif elapsed > MAX_RESPAWN_SECONDS then
        pendingDeaths[npcID] = nil
    end
end

local function OnNameplateRemoved(unit)
    RemovePlate(unit)
end

local function OnCombatLog()
    if not ns.db or ns.db.enabled == false or ns.db.respawnEnabled == false then return end
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local _, subevent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if subevent ~= "UNIT_DIED" and subevent ~= "UNIT_DESTROYED" then return end
    if not destGUID or ns.IsSecret(destGUID) then return end

    local npcID = ns.GetNpcID(destGUID)
    if not npcID or not ns.db or ns.db.enabled == false or ns.db.respawnEnabled == false then return end

    -- When several identical NPCs are already visible, this death cannot be paired
    -- confidently with the next plate. Don't turn it into a respawn observation.
    local visibleCount = visibleByNpc[npcID] or 0
    if visibleCount > 1 then
        pendingDeaths[npcID] = nil
        return
    end
    if visibleCount == 1 then
        local matchingPlate = false
        for _, plate in pairs(platesByUnit) do
            if plate.npcID == npcID and plate.guid == destGUID then
                matchingPlate = true
                break
            end
        end
        if not matchingPlate then return end
    end

    pendingDeaths[npcID] = { at = time(), guid = destGUID }
end

local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return string.format("%dh %dm", hours, minutes)
    elseif seconds >= 60 then
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    end
    return string.format("%ds", seconds)
end

local function GetMedian(samples)
    local values = {}
    local now = time()
    for _, sample in ipairs(samples) do
        if type(sample) == "table"
            and type(sample.seconds) == "number"
            and type(sample.at) == "number"
            and now - sample.at <= SAMPLE_RETENTION_SECONDS
            and sample.seconds >= MIN_RESPAWN_SECONDS
            and sample.seconds <= MAX_RESPAWN_SECONDS then
            values[#values + 1] = sample.seconds
        end
    end
    table.sort(values)
    local count = #values
    if count == 0 then return nil, 0 end
    local middle = math.floor((count + 1) / 2)
    if count % 2 == 1 then
        return values[middle], count
    end
    return (values[middle] + values[middle + 1]) / 2, count
end

function ns.GetRespawnText(npcID)
    if not ns.db or ns.db.enabled == false or ns.db.respawnEnabled == false then return end
    local samplesByNpc = ns.db.respawnSamples
    local samples = type(samplesByNpc) == "table" and samplesByNpc[npcID]
    if type(samples) ~= "table" then return end

    local estimate, count = GetMedian(samples)
    if not estimate then return end

    local death = pendingDeaths[npcID]
    if death then
        local remaining = estimate - (time() - death.at)
        if remaining > 0 then
            return string.format("Respawn estimate: about %s (%d local observation%s)", Duration(remaining), count, count == 1 and "" or "s")
        end
        return string.format("Respawn estimate: due or overdue (%d local observation%s)", count, count == 1 and "" or "s")
    end

    return string.format("Respawn estimate: about %s (%d local observation%s)", Duration(estimate), count, count == 1 and "" or "s")
end

-- Register during file load, before PLAYER_LOGIN lockdown. Registering these through
-- the deferred login callback can taint Frame:RegisterEvent on the Forever client.
ns.RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
ns.RegisterEvent("NAME_PLATE_UNIT_ADDED", OnNameplateAdded)
ns.RegisterEvent("NAME_PLATE_UNIT_REMOVED", OnNameplateRemoved)
ns.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() wipe(pendingDeaths) end)

ns.OnLogin(function()
    EnsureSamples()
    if not ns.db then return end

    -- Drop malformed and stale samples during login, not from tooltip code.
    local now = time()
    for npcID, samples in pairs(ns.db.respawnSamples) do
        if type(samples) ~= "table" then
            ns.db.respawnSamples[npcID] = nil
        else
            for index = #samples, 1, -1 do
                local sample = samples[index]
                if type(sample) ~= "table"
                    or type(sample.seconds) ~= "number"
                    or type(sample.at) ~= "number"
                    or now - sample.at > SAMPLE_RETENTION_SECONDS then
                    table.remove(samples, index)
                end
            end
            if #samples == 0 then ns.db.respawnSamples[npcID] = nil end
        end
    end
end)
