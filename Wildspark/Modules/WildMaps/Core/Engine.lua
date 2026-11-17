local addonName, addonNS = ...
local HM = addonNS.WildMaps

local eventFrame = CreateFrame("Frame")
local updateAccumulator = 0
local lastIndoorStatus

local function initializeDatabase()
    -- Carry settings forward from a previous standalone HiddenMaps install.
    if type(WildMapsDB) ~= "table" and type(HiddenMapsDB) == "table" then
        WildMapsDB = HiddenMapsDB
    end
    HiddenMapsDB = nil
    WildMapsDB = WildMapsDB or {}
    if WildMapsDB.debug == nil then
        WildMapsDB.debug = false
    end
end

function HM:RefreshMap(reason)
    local enabled = not addonNS.WildMapsModule or addonNS.WildMapsModule.IsEnabled()
    local map = enabled and HM.Detection:FindCurrentMap() or nil
    local changed = map ~= HM.currentMap

    HM.currentMap = map
    if HM.ZoneMap and HM.ZoneMap.SetMap then HM.ZoneMap:SetMap(map) end
    if HM.ZoneMap and HM.ZoneMap.Refresh and HM.ZoneMap.frame and HM.ZoneMap.frame:IsShown() then HM.ZoneMap:Refresh() end

    if changed and HM:IsDebugEnabled() then
        HM:Print(reason or "map update", "->", map and map.name or "none")
    end
end

local function initialize()
    if HM.initialized then
        return
    end

    initializeDatabase()
    HM:RefreshMap("initialize")

    HM.initialized = true
    if HM:IsDebugEnabled() then
        HM:Print("loaded", HM.version, "-", #HM.Registry:GetMaps(), "map(s)")
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            initializeDatabase()
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        initialize()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED_INDOORS" then
        HM:RefreshMap(event)
    end
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not HM.initialized then
        return
    end

    updateAccumulator = updateAccumulator + elapsed

    if updateAccumulator >= 0.10 then
        updateAccumulator = 0
        -- Movement can cross spatial coverage without changing any zone text.
        -- Reuse the 10 Hz tick so the compact Zone Map stays current.
        if not addonNS.WildMapsModule or addonNS.WildMapsModule.IsEnabled() then
            local indoorStatus = HM.Detection:GetIndoorStatus()
            local indoorChanged = indoorStatus ~= lastIndoorStatus
            lastIndoorStatus = indoorStatus
            local spatialMap, ambiguous = HM.Detection:FindSpatialMap()
            local current = HM.currentMap
            if spatialMap ~= current and (spatialMap or ambiguous or (current and current.detection.spatial == true)) then
                HM:RefreshMap("spatial coverage changed")
            elseif indoorChanged then
                -- Alias-based opt-in maps also follow indoor transitions with
                -- the map closed. Preserve all existing selection priorities.
                local detected = HM.Detection:FindCurrentMap()
                if detected ~= current and ((detected and detected.detection.requireIndoors == true)
                    or (current and current.detection.requireIndoors == true)) then
                    HM:RefreshMap("indoor status changed")
                end
            end
        end
    end

end)
