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
    HM.WorldMap:SetMap(map)

    if changed and HM:IsDebugEnabled() then
        HM:Print(reason or "map update", "->", map and map.name or "none")
    end
end

local function initialize()
    if HM.initialized then
        return
    end

    initializeDatabase()
    HM.WorldMap:Ensure()
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
        elseif arg1 == "Blizzard_WorldMap" then
            HM.WorldMap:Ensure()
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
        -- Reuse the existing 10 Hz tick, including while the World Map is shut.
        -- Explicit diagnostic/calibration overrides retain their old behavior.
        if (not addonNS.WildMapsModule or addonNS.WildMapsModule.IsEnabled())
            and not (HM.MapOverride and HM.MapOverride:IsActive()) then
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
        if HM.WorldMap.initialized and WorldMapFrame and WorldMapFrame:IsShown() then
            HM.WorldMap:UpdateMarker()
            HM.WorldMap:RefreshLocationHint()
        end
    end

end)
