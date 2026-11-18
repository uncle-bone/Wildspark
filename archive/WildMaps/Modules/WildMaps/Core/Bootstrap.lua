local addonName, addonNS = ...
local HM = addonNS.WildMaps or {}
addonNS.WildMaps = HM

HM.name = "WildMaps"
HM.currentMap = nil
HM.initialized = false

local function getVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, addonName, "X-WildMaps-Version")
        if ok and value then
            return value
        end
    end

    if GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, addonName, "X-WildMaps-Version")
        if ok and value then
            return value
        end
    end

    return "unknown"
end

HM.version = getVersion()

function HM:Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print("|cff66ccffWildMaps|r:", table.concat(parts, " "))
end

function HM:IsDebugEnabled()
    return WildMapsDB and WildMapsDB.debug == true
end
