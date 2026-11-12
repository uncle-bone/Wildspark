-- Short, addon-drawn minimap pulse; intentionally avoids the protected native PingLocation call.
local _, ns = ...
local pulse, lastKey, lastAt
local sin, cos, sqrt, atan2, min, max = math.sin, math.cos, math.sqrt, math.atan2, math.min, math.max

local function Safe(func, ...)
    if ns.SafeCall then return ns.SafeCall(func, ...) end
    if not func then return nil end
    local ok, result = pcall(func, ...)
    if not ok then return nil end
    return result
end

local function Secret(value)
    return ns.IsSecret and ns.IsSecret(value) or false
end

local function Position(mapID, unit)
    if not (C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
    if not ok or type(position) ~= "table" or not position.GetXY then return nil end
    local read, x, y = pcall(position.GetXY, position)
    if not read or Secret(x) or Secret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y
end

local function Offset(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapWorldSize and C_Minimap and C_Minimap.GetViewRadius and Minimap) then return 0, 0 end
    local mapID = Safe(C_Map.GetBestMapForUnit, "player")
    if type(mapID) ~= "number" then return 0, 0 end
    local px, py = Position(mapID, "player")
    local tx, ty = Position(mapID, unit)
    if not (px and py and tx and ty) then return 0, 0 end
    local ok, wide, tall = pcall(C_Map.GetMapWorldSize, mapID)
    if not ok or Secret(wide) or Secret(tall) or type(wide) ~= "number" or type(tall) ~= "number" or wide <= 0 or tall <= 0 then return 0, 0 end
    local radius = Safe(C_Minimap.GetViewRadius)
    if type(radius) ~= "number" or radius <= 0 then return 0, 0 end
    local east, north = (tx - px) * wide, (py - ty) * tall
    local distance = sqrt(east * east + north * north)
    if distance == 0 then return 0, 0 end
    local angle = atan2(east, north)
    local rotating = C_CVar and C_CVar.GetCVar and Safe(C_CVar.GetCVar, "rotateMinimap") == "1"
    if rotating and C_Minimap.IsRotateMinimapIgnored and Safe(C_Minimap.IsRotateMinimapIgnored) == true then rotating = false end
    if rotating then
        local facing = Safe(GetPlayerFacing)
        if type(facing) == "number" then angle = angle + facing end
    end
    local pixels = distance / radius * (Minimap:GetWidth() / 2)
    local x, y = pixels * sin(angle), pixels * cos(angle)
    local limit = max(0, Minimap:GetWidth() / 2 - 30)
    if pixels > limit and pixels > 0 then x, y = x * limit / pixels, y * limit / pixels end
    return x, y
end

local function Texture(texture, path)
    local ok, result = pcall(texture.SetTexture, texture, path)
    if not ok or result == false then texture:SetTexture("Interface\\Cooldown\\star4") end
end

local function Show(unit, color, scale)
    if not (Minimap and color) then return end
    if not pulse then
        pulse = CreateFrame("Frame", nil, Minimap)
        pulse:SetSize(360, 360)
        pulse:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 20)
        pulse.center = pulse:CreateTexture(nil, "OVERLAY", nil, 2)
        pulse.expand = pulse:CreateTexture(nil, "OVERLAY", nil, 3)
        pulse.expand2 = pulse:CreateTexture(nil, "OVERLAY", nil, 2)
        Texture(pulse.center, "Interface\\Minimap\\UI-Minimap-Ping-Center")
        Texture(pulse.expand, "Interface\\Minimap\\UI-Minimap-Ping-Expand")
        Texture(pulse.expand2, "Interface\\Minimap\\UI-Minimap-Ping-Expand")
        pulse.center:SetPoint("CENTER")
        pulse.expand:SetPoint("CENTER")
        pulse.expand2:SetPoint("CENTER")
        pulse:Hide()
    end
    local x, y = Offset(unit)
    pulse:ClearAllPoints()
    pulse:SetPoint("CENTER", Minimap, "CENTER", x, y)
    pulse.center:SetSize(12, 12)
    pulse.expand:SetSize(18, 18)
    pulse.expand2:SetSize(18, 18)
    pulse.center:SetVertexColor(color[1], color[2], color[3])
    pulse.expand:SetVertexColor(color[1], color[2], color[3])
    pulse.expand2:SetVertexColor(color[1], color[2], color[3])
    pulse.center:SetAlpha(1)
    pulse.expand:SetAlpha(1)
    pulse.expand2:SetAlpha(0)
    pulse.elapsed = 0
    pulse.scale = scale or 130
    pulse:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        local strength = max(0.5, (frame.scale or 130) / 100)
        local progress = min(1, frame.elapsed / 1.15)
        frame.expand:SetSize((22 + 58 * progress) * strength, (22 + 58 * progress) * strength)
        frame.expand:SetAlpha(1 * (1 - progress))
        local second = min(1, max(0, (frame.elapsed - 0.22) / 0.93))
        frame.expand2:SetSize((22 + 58 * second) * strength, (22 + 58 * second) * strength)
        frame.expand2:SetAlpha(0.95 * (1 - second))
        frame.center:SetSize((18 + 12 * progress) * strength, (18 + 12 * progress) * strength)
        frame.center:SetAlpha(1 - progress)
        if progress >= 1 then frame:Hide(); frame:SetScript("OnUpdate", nil) end
    end)
    pulse:Show()
end

function ns.PingMinimap(unit, name, category, visualEnabled, color, visualScale, soundEnabled, soundVolume)
    if not visualEnabled and not soundEnabled then return end
    local guid = Safe(UnitGUID, unit)
    local key = tostring(guid or (category .. ":" .. (name or "")))
    local now = GetTime()
    if key == lastKey or now - (lastAt or -10) < 0.8 then return end
    lastKey, lastAt = key, now
    if visualEnabled then Show(unit, color, visualScale) end
    if soundEnabled and PlaySoundFile then
        local level = max(0, min(100, math.floor((tonumber(soundVolume) or 70) / 10 + 0.5) * 10))
        if level > 0 then
            local path = "Interface\\AddOns\\WildSpark\\Media\\Ping\\ping" .. string.format("%03d", level) .. ".ogg"
            pcall(PlaySoundFile, path, "Master")
        end
    end
end
