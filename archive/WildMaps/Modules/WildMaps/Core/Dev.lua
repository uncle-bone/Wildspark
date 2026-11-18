local _, addonNS = ...
local HM = addonNS.WildMaps

-- Calibration access is deliberately session-only; never restore it from SavedVariables.
HM.Dev = { developerEnabled = false }
local Dev = HM.Dev

function Dev:IsDeveloperEnabled()
    return self.developerEnabled == true
end

function Dev:RequireDeveloperTools()
    if self:IsDeveloperEnabled() then return true end
    HM:Print("calibration tools are disabled; use /wm dev on to enable them for this session.")
    return false
end

function Dev:SetDeveloperEnabled(enabled)
    self.developerEnabled = enabled == true
    local stopped = false
    if not self.developerEnabled then
        if HM.CropCalibration and HM.CropCalibration.session then
            HM.CropCalibration:Stop("developer tools disabled", true)
            stopped = true
        end
        if HM.EntranceCalibration and HM.EntranceCalibration.session then
            HM.EntranceCalibration:Stop("developer tools disabled", true)
            stopped = true
        end
    end
    HM:Print("calibration tools", self.developerEnabled and "ON for this session; /reload disables them" or "OFF")
    if stopped then
        HM:Print("calibration ended; /wmmap off returns to live detection.")
    end
end

local function printSignals(signals)
    HM:Print("minimap=", signals.minimap ~= "" and signals.minimap or "<empty>")
    HM:Print("subzone=", signals.subzone ~= "" and signals.subzone or "<empty>")
    HM:Print("realZone=", signals.realZone ~= "" and signals.realZone or "<empty>")
    HM:Print("zone=", signals.zone ~= "" and signals.zone or "<empty>")
end

function Dev:Status()
    local map, signals = HM.Detection:FindCurrentMap()
    local bestMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil

    HM:Print("version", HM.version)
    HM:Print("map", map and map.id or "<none>")
    HM:Print("registered maps", #HM.Registry:GetMaps(), "rejected", #HM.Registry:GetErrors())
    HM:Print("bestMap", bestMap or "<none>")
    if GetInstanceInfo then
        local instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
        HM:Print("instance", tostring(instanceID or "<none>"), tostring(instanceType or "<none>"), tostring(instanceName or "<none>"))
    end
    printSignals(signals)

    if map and map.position then
        local x, y = HM.Position:GetSourcePosition(map)
        if x then
            HM:Print(map.position.source.name, string.format("%.6f %.6f", x, y))
        else
            HM:Print(map.position.source.name, "position unavailable")
        end

        local continentID, worldX, worldY = HM.Position:GetAreaWorldPosition(map)
        if worldX then
            HM:Print("C_Map world", string.format("continent=%s x=%.6f y=%.6f", tostring(continentID), worldX, worldY))
        else
            HM:Print("C_Map world", "unavailable")
        end

        local instanceID, unitX, unitY, unitZ = HM.Position:GetUnitWorldPosition()
        if unitX then
            HM:Print("UnitPosition", string.format("instance=%s x=%.6f y=%.6f z=%.6f", tostring(instanceID), unitX, unitY, unitZ or 0))
        else
            HM:Print("UnitPosition", "unavailable")
        end

        local pixelX, pixelY = HM.Position:GetRawMapPixel(map)
        if pixelX then
            HM:Print("source pixel", string.format("x=%.2f y=%.2f", pixelX, pixelY))
        else
            HM:Print("source pixel", "unavailable")
        end

        local renderX, renderY = HM.Position:GetRenderedMapPixel(map)
        if renderX then
            HM:Print("rendered pixel", string.format("x=%.2f y=%.2f", renderX, renderY))
        end

        local facing = HM.Position:GetPlayerFacing()
        if facing then
            HM:Print("raw player facing", string.format("%.4f rad / %.1f deg", facing, math.deg(facing)))
        end
    end
end

function Dev:ListMaps()
    HM:Print("registered maps:", #HM.Registry:GetMaps())
    for _, map in ipairs(HM.Registry:GetMaps()) do
        HM:Print("-", map.id, "(" .. map._sourceName .. ")")
    end

    local errors = HM.Registry:GetErrors()
    if #errors > 0 then
        HM:Print("rejected maps:", #errors)
        for _, item in ipairs(errors) do
            HM:Print("-", item.source, item.message)
        end
    end
end

function Dev:ToggleDebug()
    WildMapsDB.debug = not WildMapsDB.debug
    HM:Print("debug", WildMapsDB.debug and "ON" or "OFF")
    HM.WorldMap:RefreshDebugBadge()
end

function Dev:HandleSlash(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))

    -- Keep advanced calibration access out of the ordinary support-command help.
    if command == "dev" or command:match("^dev%s") then
        local action = command:match("^dev%s+(%S+)$")
        if action == "on" then
            self:SetDeveloperEnabled(true)
        elseif action == "off" then
            self:SetDeveloperEnabled(false)
        elseif command == "dev" or action == "status" then
            HM:Print("calibration tools", self:IsDeveloperEnabled() and "ON for this session" or "OFF")
        else
            HM:Print("/wm dev on | off | status (session-only calibration access)")
        end
        return
    end

    if command == "" or command == "status" then
        self:Status()
        return
    end

    if command == "maps" then
        self:ListMaps()
        return
    end

    if command == "debug" then
        self:ToggleDebug()
        return
    end

    HM:Print("commands: /wm status, /wm maps, /wm debug")
end

SLASH_WILDMAPS1 = "/wildmaps"
SLASH_WILDMAPS2 = "/wm"
SlashCmdList.WILDMAPS = function(message)
    Dev:HandleSlash(message)
end
