local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Detection = {}
local Detection = HM.Detection

function Detection:GetIndoorStatus()
    if type(IsIndoors) ~= "function" then return false end

    -- Opt-in maps require a confirmed indoor signal; unavailable/error is not enough.
    local ok, indoors = pcall(IsIndoors)
    return ok and indoors == true
end

local function meetsIndoorRequirement(map)
    return map.detection.requireIndoors ~= true or Detection:GetIndoorStatus()
end

function Detection:GetSignals()
    return {
        minimap = GetMinimapZoneText and GetMinimapZoneText() or "",
        subzone = GetSubZoneText and GetSubZoneText() or "",
        realZone = GetRealZoneText and GetRealZoneText() or "",
        zone = GetZoneText and GetZoneText() or "",
    }
end

-- Opt-in maps use the live chevron's map-space coverage, even before any map
-- UI exists. No alias or alive/dead state can substitute for a valid position.
function Detection:FindSpatialMap(inInstance)
    if inInstance == nil then inInstance = IsInInstance and select(1, IsInInstance()) or false end
    local match
    for _, map in ipairs(HM.Registry:GetMaps()) do
        if map.detection.spatial == true and (not inInstance or map.detection.allowInInstance == true)
            and meetsIndoorRequirement(map) then
            local u = HM.Position:GetVisibleMapPosition(map)
            if u ~= nil then
                -- Conflicting coverage must not depend on registry order.
                -- The second return also prevents an alias from masking it.
                if match then return nil, true end
                match = map
            end
        end
    end
    return match
end

-- These opt-in maps lack confirmed runtime instanceIDs. Match GetInstanceInfo's
-- actual instance name only inside a party instance. Never probe UiMap/world IDs
-- or treat an outdoor zone/subzone with the same name as a dungeon.
function Detection:FindNamedInstanceMap(inInstance)
    if inInstance ~= true or type(GetInstanceInfo) ~= "function" then return nil end
    local ok, name, instanceType = pcall(GetInstanceInfo)
    if not ok then return nil end
    if type(issecretvalue) == "function" and (issecretvalue(name) or issecretvalue(instanceType)) then return nil end
    if instanceType ~= "party" or type(name) ~= "string" then return nil end
    local key = string.lower(name:match("^%s*(.-)%s*$"))
    local match
    for _, map in ipairs(HM.Registry:GetMaps()) do
        if map.detection.allowInInstance == true and map.detection.instanceNames then
            for _, candidate in ipairs(map.detection.instanceNames) do
                if key == string.lower(candidate) then
                    if match and match ~= map then return nil end
                    match = map
                end
            end
        end
    end
    return match
end

function Detection:FindCurrentMap()
    local inInstance = IsInInstance and select(1, IsInInstance()) or false
    local signals = self:GetSignals()

    -- InstanceID is language-independent and is the preferred detector for
    -- true dungeon/raid maps.
    if inInstance and GetInstanceInfo then
        local instanceID = select(8, GetInstanceInfo())
        if instanceID then
            local candidates = HM.Registry:GetMapsForInstanceID(instanceID)
            if candidates and #candidates > 0 then
                return candidates[1], signals
            end
        end
    end

    local namedInstanceMap = self:FindNamedInstanceMap(inInstance)
    if namedInstanceMap then return namedInstanceMap, signals end

    local spatialMap, ambiguous = self:FindSpatialMap(inInstance)
    if spatialMap then return spatialMap, signals end
    if ambiguous then return nil, signals end

    -- Existing maps retain alias detection. Opt-in spatial maps cannot fall
    -- back to broad aliases after a failed coverage/position check.
    local signalOrder = { "minimap", "subzone", "realZone", "zone" }

    for _, source in ipairs(signalOrder) do
        local candidates = HM.Registry:GetMapsForAlias(signals[source])
        if candidates then
            for _, map in ipairs(candidates) do
                if map.detection.spatial ~= true and (not inInstance or map.detection.allowInInstance == true)
                    and meetsIndoorRequirement(map) then
                    return map, signals
                end
            end
        end
    end

    return nil, signals
end
