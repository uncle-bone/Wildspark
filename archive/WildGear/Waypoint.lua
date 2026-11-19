local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Right-click on a quest (or the quest panel's pin buttons): pin the quest
-- giver of the character's next step (ns.QuestPinTarget) or of a given quest
-- as the map's user waypoint, track it, add a TomTom waypoint when TomTom is
-- installed, and open the world map there.
-- Quest data has Wowhead zone ids, not UiMapIDs, so maps are matched by name
-- against the client's own map tree, whose names are in the game's language:
-- the zone's name from the game itself, else the addon's (Chinese or English).

local mapByName -- lower-cased map name -> UiMapID

local function BuildMapIndex()
    mapByName = {}
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapChildrenInfo) then return end
    local root = (C_Map.GetFallbackWorldMapID and C_Map.GetFallbackWorldMapID())
        or (C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player"))
    if not root then return end
    -- Climb to the top of the tree (the cosmic map) so both continents are included.
    local info = C_Map.GetMapInfo(root)
    while info and info.parentMapID and info.parentMapID > 0 do
        root = info.parentMapID
        info = C_Map.GetMapInfo(root)
    end
    local canPin = C_Map.CanSetUserWaypointOnMap
    for _, m in ipairs(C_Map.GetMapChildrenInfo(root, nil, true) or {}) do
        local key = m.name and m.name:lower()
        if key then
            -- Several maps can share a name (a zone and its dungeon level); keep a pinnable one.
            local old = mapByName[key]
            if not old or (canPin and not canPin(old) and canPin(m.mapID)) then mapByName[key] = m.mapID end
        end
    end
end

-- The UiMapID for Wowhead zone `zoneId`, and the zone's name for messages.
local function MapFor(zoneId)
    local name = ns.ZoneName(zoneId)
    if not name then return nil end
    if not mapByName then BuildMapIndex() end
    local area = zoneId > 0 and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(zoneId)
    for _, candidate in ipairs({ area or "", name, ns.ZoneNames[zoneId] or "" }) do
        local mapId = mapByName[candidate:lower()]
        if mapId then return mapId, name end
    end
    return nil, name
end

-- Whether you play with a gamepad (the game's gamepad mode is on).
local function GamePadActive()
    if C_GamePad and C_GamePad.IsEnabled then
        local ok, on = pcall(C_GamePad.IsEnabled)
        if ok and on then return true end
    end
    return GetCVarBool ~= nil and GetCVarBool("GamePadEnable") == true
end

-- Pins target = {name, start, step, steps, pending} (see ns.QuestPinTarget).
local function PinTarget(target)
    local what = target.step and string.format(L["%s (step %d of %d)"], target.name, target.step, target.steps)
        or target.name
    local start = target.start
    local giver = start and ns.StartName(start)
    if not start then
        ns.Printf(L["No known quest giver for %s."], what)
        return
    elseif start.kind == "item" then
        ns.Printf(L["%s starts from an item: %s."], what, giver)
        return
    elseif not start.x then
        ns.Printf(L["%s starts at %s; no map location known."], what, giver)
        return
    end

    local mapId, zone = MapFor(start.zoneId)
    if not mapId then
        ns.Printf(L["%s starts at %s in %s (%.1f, %.1f), but that zone wasn't found on the map."], what, giver,
            zone or L["an unknown zone"], start.x, start.y)
        return
    end
    local x, y = start.x / 100, start.y / 100
    local pinned = false
    if C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(mapId) and UiMapPoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapId, x, y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
        pinned = true
    end
    if TomTom and TomTom.AddWaypoint then
        TomTom:AddWaypoint(mapId, x, y, { title = giver .. ": " .. target.name, from = "WildGear" })
        pinned = true
    end
    if not pinned then
        ns.Printf(L["%s starts at %s in %s (%.1f, %.1f); this map doesn't allow pins."], what, giver, zone,
            start.x, start.y)
        return
    end
    if target.pending then
        ns.Printf(L["Hand in step %d first; it's in your quest log."], target.pending)
    end
    ns.Printf(L["Pinned %s in %s (%.1f, %.1f) for %s."], giver, zone, start.x, start.y, what)
    -- Not with a gamepad: the map opened by an addon is blamed for the
    -- protected calls its gamepad handling makes ("blocked from an action
    -- only available to the Blizzard UI"). The pin is set: you open the map.
    if OpenWorldMap and not (InCombatLockdown and InCombatLockdown()) and not GamePadActive() then
        OpenWorldMap(mapId)
    end
end

-- The quest giver of the character's next step for quest source `s`.
function ns.PinQuest(s)
    local target, state = ns.QuestPinTarget(s, ns.GetProfile())
    local name = ns.QuestName(s.id, s.name)
    if state == "done" then
        ns.Printf(L["You have already completed %s."], name)
    elseif state == "active" then
        ns.Printf(L["%s is already in your quest log."], name)
    else
        PinTarget(target)
    end
end

-- The quest giver of quest `id` itself, whatever the character's progress.
function ns.PinQuestGiver(id)
    local q = ns.Quests[id] or {}
    local chain = q.chain and ns.QuestChains and ns.QuestChains[q.chain.id]
    PinTarget({ name = ns.QuestName(id), start = q.start, step = chain and q.chain.step, steps = chain and #chain })
end
