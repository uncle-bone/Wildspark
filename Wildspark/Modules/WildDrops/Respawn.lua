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

local function SamplesForNpc(npcID)
    EnsureSamples()
    if not ns.db then return end
    local samples = ns.db.respawnSamples[npcID]
    if type(samples) == "table" then return samples end
    local count, oldestID, oldestAt = 0, nil, nil
    for id, records in pairs(ns.db.respawnSamples) do
        count = count + 1
        local newest = 0
        if type(records) == "table" then
            for _, record in ipairs(records) do
                if type(record) == "table" and type(record.at) == "number" and record.at > newest then
                    newest = record.at
                end
            end
        end
        if not oldestAt or newest < oldestAt then oldestID, oldestAt = id, newest end
    end
    if count >= MAX_NPC_RECORDS and oldestID then ns.db.respawnSamples[oldestID] = nil end
    samples = {}
    ns.db.respawnSamples[npcID] = samples
    return samples
end

local function SampleBucket(stamp)
    local serverTime = GetServerTime and GetServerTime() or stamp or time()
    if type(serverTime) ~= "number" then serverTime = stamp or time() end
    return math.floor(serverTime / 30)
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

    local samples = SamplesForNpc(npcID)
    if not samples then return false end
    samples[#samples + 1] = {
        seconds = math.floor(seconds + 0.5), at = now, source = "local", bucket = SampleBucket(now),
    }

    -- Keep the newest bounded set so saved variables stay small and estimates stay current.
    while #samples > MAX_SAMPLES_PER_NPC do
        table.remove(samples, 1)
    end
    if ns.RefreshRespawnTooltip then ns.RefreshRespawnTooltip() end
    return true
end

function ns.IsRespawnSharingEnabled()
    return ns.db ~= nil and ns.db.enabled ~= false and ns.db.respawnEnabled ~= false
end

function ns.ReceiveSharedRespawn(npcID, seconds, bucket, sender)
    if not ns.IsRespawnSharingEnabled() then return false end
    npcID, seconds, bucket = tonumber(npcID), tonumber(seconds), tonumber(bucket)
    if not npcID or npcID < 1 or npcID > 999999999
        or not seconds or seconds < MIN_RESPAWN_SECONDS or seconds > MAX_RESPAWN_SECONDS
        or not bucket or bucket < 1 or type(sender) ~= "string" or sender == "" then return false end
    local now = time()
    local currentBucket = SampleBucket(now)
    if bucket < currentBucket - 2880 or bucket > currentBucket + 2 then return false end
    local samples = SamplesForNpc(npcID)
    if not samples then return false end
    -- Multiple nearby clients can report the same NPC appearance; count that spawn once.
    for _, sample in ipairs(samples) do
        if sample.bucket == bucket then return false end
    end
    samples[#samples + 1] = {
        seconds = math.floor(seconds + 0.5), at = now, source = "shared", bucket = bucket,
    }
    while #samples > MAX_SAMPLES_PER_NPC do table.remove(samples, 1) end
    if ns.RefreshRespawnTooltip then ns.RefreshRespawnTooltip() end
    return true
end

local function ShareSample(npcID, seconds, stamp)
    if not ns.IsRespawnSharingEnabled() then return end
    local net = addonNS.CampNet
    if net and net.ShareRespawnSample then
        net.ShareRespawnSample(npcID, seconds, SampleBucket(stamp))
    end
end

local function OnNameplateAdded(unit)
    RemovePlate(unit)
    local npcID, guid = GetNpcIDFromUnit(unit)
    if not npcID then return end

    platesByUnit[unit] = { npcID = npcID, guid = guid }
    visibleByNpc[npcID] = (visibleByNpc[npcID] or 0) + 1

    local queue = pendingDeaths[npcID]
    if type(queue) ~= "table" then return end

    local now = time()
    local bestIndex, bestElapsed
    for index = #queue, 1, -1 do
        local death = queue[index]
        local elapsed = now - death.at
        if elapsed > MAX_RESPAWN_SECONDS or elapsed < 0 then
            table.remove(queue, index)
        elseif elapsed >= MIN_RESPAWN_SECONDS and (not bestElapsed or elapsed < bestElapsed) then
            -- Pair this appearance with the closest eligible death of this NPC ID.
            -- Multiple identical mobs can die before any of them respawn.
            bestIndex, bestElapsed = index, elapsed
        end
    end
    if bestIndex then
        table.remove(queue, bestIndex)
        if AddSample(npcID, bestElapsed, now) then ShareSample(npcID, bestElapsed, now) end
    end
    if #queue == 0 then pendingDeaths[npcID] = nil end
end

local function RecordNpcDeath(destGUID)
    if not ns.db or ns.db.enabled == false or ns.db.respawnEnabled == false then return end
    if not destGUID or ns.IsSecret(destGUID) then return end

    local npcID = ns.GetNpcID(destGUID)
    if not npcID then return end

    -- Combat log, UNIT_HEALTH and nameplate removal may report the same kill.
    -- Keep one queue per NPC ID so groups of identical quest mobs are not discarded.
    local queue = pendingDeaths[npcID]
    if type(queue) ~= "table" then
        queue = {}
        pendingDeaths[npcID] = queue
    end
    local now = time()
    for index = #queue, 1, -1 do
        local death = queue[index]
        if now - death.at > MAX_RESPAWN_SECONDS or now < death.at then
            table.remove(queue, index)
        elseif death.guid == destGUID then
            return
        end
    end
    queue[#queue + 1] = { at = now, guid = destGUID }
end

local function OnNameplateRemoved(unit, isDead)
    if isDead then
        local _, guid = GetNpcIDFromUnit(unit)
        if guid then RecordNpcDeath(guid) end
    end
    RemovePlate(unit)
end

local function OnZoneChanged()
    wipe(pendingDeaths)
    wipe(platesByUnit)
    wipe(visibleByNpc)
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
    local values, sharedCount = {}, 0
    local now = time()
    for _, sample in ipairs(samples) do
        if type(sample) == "table"
            and type(sample.seconds) == "number"
            and type(sample.at) == "number"
            and now - sample.at <= SAMPLE_RETENTION_SECONDS
            and sample.seconds >= MIN_RESPAWN_SECONDS
            and sample.seconds <= MAX_RESPAWN_SECONDS then
            values[#values + 1] = sample.seconds
            if sample.source == "shared" then sharedCount = sharedCount + 1 end
        end
    end
    table.sort(values)
    local count = #values
    if count == 0 then return nil, 0, 0 end
    local middle = math.floor((count + 1) / 2)
    if count % 2 == 1 then return values[middle], count, sharedCount end
    return (values[middle] + values[middle + 1]) / 2, count, sharedCount
end

local function ObservationLabel(count, sharedCount)
    if sharedCount == 0 then
        return string.format("(%d local observation%s)", count, count == 1 and "" or "s")
    elseif sharedCount == count then
        return string.format("(%d shared observation%s)", count, count == 1 and "" or "s")
    end
    return string.format("(%d observations; %d shared)", count, sharedCount)
end

function ns.GetRespawnText(npcID)
    if not ns.db or ns.db.enabled == false or ns.db.respawnEnabled == false then return end
    local samplesByNpc = ns.db.respawnSamples
    local samples = type(samplesByNpc) == "table" and samplesByNpc[npcID]
    if type(samples) ~= "table" then
        return "Learning respawn time (needs a death and return)"
    end

    local estimate, count, sharedCount = GetMedian(samples)
    if not estimate then
        return "Learning respawn time (needs a death and return)"
    end
    local observations = ObservationLabel(count, sharedCount)
    local queue = pendingDeaths[npcID]
    local death = type(queue) == "table" and queue[#queue]
    if death then
        local remaining = estimate - (time() - death.at)
        if remaining > 0 then
            return string.format("Respawn estimate: about %s %s", Duration(remaining), observations)
        end
        return string.format("Respawn estimate: due or overdue %s", observations)
    end
    return string.format("Respawn estimate: about %s %s", Duration(estimate), observations)
end

-- Reuse WildSpark's existing event owners instead of registering more frame events.
-- Forever can reject additional RegisterEvent calls from addon code.
local leashHelper = _G.LeashHelper
if leashHelper and leashHelper.RegisterRespawnListener then
    leashHelper.RegisterRespawnListener({
        onDeath = RecordNpcDeath,
        onNameplateAdded = OnNameplateAdded,
        onNameplateRemoved = OnNameplateRemoved,
        onZoneChanged = OnZoneChanged,
    })
end

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
