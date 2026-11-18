local _, addonNS = ...
local HM = addonNS.WildMaps

-- Measurement only. Never edit a registered map definition, transform or POI.
-- Coordinates are pixels of render.width x render.height: the already oriented
-- artwork. Raw pre-rotation source dimensions are logged separately (notably WC).
HM.CropCalibration = {}
local Crop = HM.CropCalibration
local STAGES = { "LEFT", "RIGHT", "TOP", "BOTTOM", "COMPLETE" }
local LOG_LIMIT = 50

local function finite(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function positive(value)
    return finite(value) and value > 0
end

local function safeNumber(fn)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok and finite(value) then return value end
end

local function copyScalars(source)
    if type(source) ~= "table" then return nil end
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "string" or type(value) == "boolean" or finite(value) then
            copy[key] = value
        end
    end
    return copy
end

local function readRect(frame)
    if not frame or not frame.GetLeft or not frame.GetTop or not frame.GetEffectiveScale then return nil end
    local width, height = frame:GetSize()
    local left, top, scale = frame:GetLeft(), frame:GetTop(), frame:GetEffectiveScale()
    if not positive(width) or not positive(height) or not positive(scale)
        or not finite(left) or not finite(top) then return nil end
    return left, top, width, height, scale
end

-- GetCursorPosition is in physical pixels with a bottom-left origin. Region
-- geometry is in that region's effective UI scale. Convert to top-left first.
function Crop:CursorInFrame(frame, cursorX, cursorY)
    if not finite(cursorX) or not finite(cursorY) then return nil end
    local left, top, width, height, scale = readRect(frame)
    if not left then return nil end
    local x, y = cursorX / scale - left, top - cursorY / scale
    if not finite(x) or not finite(y) or x < 0 or y < 0 or x > width or y > height then return nil end
    return x / width, y / height
end

function Crop:IsSuitable(map)
    local render = map and map.render
    local detection = map and map.detection
    return map and not map.hiddenDiagnostic and detection and detection.allowInInstance == false
        and not (detection.instanceIDs and #detection.instanceIDs > 0)
        and not (map.floors and #map.floors > 0)
        and render and render.type == "tile_grid" and render.tileNaming ~= "blizzard_sequential"
        and type(render.texturePrefix) == "string"
        and string.find(render.texturePrefix, "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\", 1, true) == 1
        and positive(render.width) and positive(render.height)
        and render.width == math.floor(render.width) and render.height == math.floor(render.height)
end

function Crop:Stop(reason, quiet)
    self.session = nil -- Clear first: cleanup cannot leave a live click handler.
    if self.overlay then
        pcall(self.overlay.EnableMouse, self.overlay, false)
        pcall(self.overlay.EnableMouseWheel, self.overlay, false)
        pcall(self.overlay.Hide, self.overlay)
    end
    if self.panel then
        if self.panel.StopMovingOrSizing then pcall(self.panel.StopMovingOrSizing, self.panel) end
        pcall(self.panel.Hide, self.panel)
    end
    if HM.Renderer and HM.Renderer.calibrationMap then
        HM.Renderer.calibrationMap = nil
        -- Restore packaged presentation even after an interrupted selection.
        if HM.WorldMap then pcall(HM.WorldMap.RefreshMap, HM.WorldMap) end
    end
    if not quiet then HM:Print("crop calibration ended:", reason or "cancelled", "(no new record saved)") end
end

function Crop:Safe(action, fn, ...)
    local ok, result = pcall(fn, self, ...)
    if not ok then
        self:Stop(nil, true)
        if self.startRestore then pcall(self.RestoreStart, self) end
        HM:Print("crop calibration stopped:", action, "-", tostring(result))
        return false
    end
    return result
end

function Crop:RestoreStart()
    local previous = self.startRestore
    self.startRestore = nil
    if not previous then return end
    if HM.Renderer then HM.Renderer.calibrationMap = nil end
    -- Failure-only transaction rollback: preserve the prior override's exact
    -- identity and deadline rather than restarting its timeout with Apply().
    HM.MapOverride.active, HM.MapOverride.expiresAt = previous.active, previous.expiresAt
    HM.currentMap = previous.currentMap
    local area = HM.Experiments and HM.Experiments.WCCurrentArea
    if area then area.enabled = previous.areaEnabled end
    HM.WorldMap:SetMap(previous.map)
end

function Crop:CheckSession()
    local s = self.session
    if not s then return nil end
    local world = HM.WorldMap
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer or not WorldMapFrame:IsShown() then
        self:Stop("World Map closed or unavailable")
        return nil
    end
    local effective = world and world:GetEffectiveMap()
    if not world or world.map ~= s.map or not effective or effective.render ~= s.render
        or world.renderer ~= s.renderer or not HM.MapOverride or HM.MapOverride.active ~= s.override
        or s.render.width ~= s.width or s.render.height ~= s.height then
        self:Stop("map or override changed")
        return nil
    end
    return s
end

local function font(parent, template, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end

function Crop:EnsureUI(renderer)
    if not self.uiReady then
        local overlay = CreateFrame("Button", nil, renderer)
        self.overlay = overlay
        overlay:Hide()
        overlay:EnableMouse(false)
        overlay:RegisterForClicks("LeftButtonUp")
        overlay:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then Crop:Safe("click", Crop.Click) end
        end)
        -- Capture gestures only within this addon-owned rectangle. No Blizzard
        -- script, pin, provider or mouse-enable flag is changed.
        overlay:SetScript("OnMouseDown", function() end)
        overlay:EnableMouseWheel(true)
        overlay:SetScript("OnMouseWheel", function() end)
        self.lines = {}
        for index = 1, 4 do
            local line = overlay:CreateTexture(nil, "OVERLAY")
            line:Hide()
            self.lines[index] = line
        end

        local panel = CreateFrame("Frame", nil, UIParent)
        self.panel = panel
        panel:Hide()
        panel:SetSize(360, 316)
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        panel:EnableMouse(true)
        panel:SetMovable(true)
        panel:SetClampedToScreen(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", function() Crop:Safe("move panel", function() panel:StartMoving() end) end)
        panel:SetScript("OnDragStop", function() Crop:Safe("move panel", function() panel:StopMovingOrSizing() end) end)
        local background = panel:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.035, 0.045, 0.065, 0.97)
        font(panel, "GameFontNormalLarge", 14, -14, 332):SetText("WildMaps Crop Calibration")
        self.mapText = font(panel, "GameFontNormalSmall", 14, -44, 332)
        self.basisText = font(panel, "GameFontNormalSmall", 14, -78, 332)
        self.valuesText = font(panel, "GameFontNormal", 14, -108, 332)
        self.packagedText = font(panel, "GameFontNormalSmall", 14, -207, 332)
        self.noticeText = font(panel, "GameFontNormalSmall", 14, -239, 332)
        font(panel, "GameFontNormalSmall", 14, -264, 332):SetText("Drag this box to uncover the map.")

        local function button(label, x, callback)
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(104, 24)
            b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 10)
            b:SetText(label)
            b:SetScript("OnClick", callback)
            return b
        end
        self.lockButton = button("Lock", 14, function() Crop:Safe("lock", Crop.Lock) end)
        button("Reset", 128, function() Crop:Safe("reset", Crop.Reset) end)
        button("Cancel", 242, function() Crop:Stop("cancelled") end)
        self.uiReady = true
    end
    self.overlay:SetParent(renderer)
    self.overlay:ClearAllPoints()
    self.overlay:SetAllPoints(renderer)
    self.overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    self.overlay:SetFrameLevel(renderer:GetFrameLevel() + 100)
    self.panel:SetFrameStrata("FULLSCREEN_DIALOG")
    self.panel:SetFrameLevel(self.overlay:GetFrameLevel() + 100)
    if self.hookedWorldMap ~= WorldMapFrame then
        WorldMapFrame:HookScript("OnHide", function()
            if Crop.session then Crop:Stop("World Map closed") end
        end)
        self.hookedWorldMap = WorldMapFrame
    end
end

function Crop:RefreshBox()
    local s = self.session
    if not s then return end
    self.mapText:SetText("Map: " .. s.map.name .. "\nID: " .. s.map.id)
    self.basisText:SetText(string.format("Artwork pixels: %dx%d; rotation: %s", s.width, s.height, tostring(s.rotation)))
    self.valuesText:SetText(string.format("Left:   %d\nRight:  %d\nTop:    %d\nBottom: %d\n\nSelecting: %s",
        s.crop.left, s.crop.right, s.crop.top, s.crop.bottom, STAGES[s.stage]))
    local c = s.packagedCrop
    if c then
        self.packagedText:SetText(string.format("Packaged crop: L=%s R=%s T=%s B=%s (separate)",
            tostring(c.left or c.cropLeftPixels or 0), tostring(c.right or c.cropRightPixels or 0),
            tostring(c.top or c.cropTopPixels or 0), tostring(c.bottom or c.cropBottomPixels or 0)))
    else
        self.packagedText:SetText("New session offsets; map definition is unchanged.")
    end
    self.noticeText:SetText(s.notice or (s.locked and "Locked and recorded. Reset starts a new selection."
        or "Gold: moving boundary. Cyan: selected boundary."))
    self.lockButton:SetEnabled(s.stage == 5 and not s.locked and not s.waiting)
end

function Crop:LayoutLines()
    local s = self.session
    if not s then return end
    local width, height = s.renderer:GetSize()
    for index, line in ipairs(self.lines) do
        line:Hide()
        local value
        if index < s.stage then
            value = ({s.crop.left, s.width - s.crop.right, s.crop.top, s.height - s.crop.bottom})[index]
            line:SetColorTexture(0.15, 0.95, 1, 1)
        elseif index == s.stage then
            value = s.preview
            line:SetColorTexture(1, 0.8, 0.15, 1)
        end
        if value ~= nil then
            line:ClearAllPoints()
            if index <= 2 then
                line:SetPoint("TOP", self.overlay, "TOPLEFT", value / s.width * width, 0)
                line:SetSize(2, height)
            else
                line:SetPoint("LEFT", self.overlay, "TOPLEFT", 0, -value / s.height * height)
                line:SetSize(width, 2)
            end
            line:Show()
        end
    end
end

function Crop:GetCursorPixel()
    local s = self.session
    if not s or type(GetCursorPosition) ~= "function" then return nil end
    local cursorX, cursorY = GetCursorPosition()
    -- The control box and every child button are explicitly excluded even if
    -- an OnClick somehow reaches the map overlay through another UI layer.
    if self.panel:IsShown() and self:CursorInFrame(self.panel, cursorX, cursorY) ~= nil then return nil end
    local x, y = self:CursorInFrame(s.renderer, cursorX, cursorY)
    if x == nil then return nil end
    return math.min(s.width, math.floor(x * s.width + 0.5)), math.min(s.height, math.floor(y * s.height + 0.5))
end

function Crop:Update()
    local s = self:CheckSession()
    if not s then return end
    if not s.renderer:IsShown() or not readRect(s.renderer) then
        self.overlay:EnableMouse(false)
        self.overlay:EnableMouseWheel(false)
        self.overlay:Hide()
        if not s.waiting then
            s.waiting = true
            s.notice = "Waiting for a usable map rectangle; values retained."
            self:RefreshBox()
        end
        return
    end
    if s.waiting then s.waiting = false; s.notice = nil; self:RefreshBox() end
    self.overlay:SetFrameLevel(s.renderer:GetFrameLevel() + 100)
    self.panel:SetFrameLevel(self.overlay:GetFrameLevel() + 100)
    self.overlay:EnableMouse(not s.locked)
    self.overlay:EnableMouseWheel(not s.locked)
    self.overlay:Show()
    if s.stage <= 4 and not s.locked then
        local x, y = self:GetCursorPixel()
        if x ~= nil then s.preview = s.stage <= 2 and x or y end
    end
    self:LayoutLines()
end

function Crop:Click()
    local s = self:CheckSession()
    if not s or s.locked or s.stage > 4 or s.waiting then return false end
    local x, y = self:GetCursorPixel() -- Re-read on click; never accept stale hover coordinates.
    if x == nil then return false end
    local reason
    if s.stage == 1 and x >= s.width then reason = "LEFT must leave at least one pixel of width."
    elseif s.stage == 2 and x <= s.crop.left then reason = "RIGHT must be to the right of LEFT."
    elseif s.stage == 3 and y >= s.height then reason = "TOP must leave at least one pixel of height."
    elseif s.stage == 4 and y <= s.crop.top then reason = "BOTTOM must be below TOP." end
    if reason then
        HM:Print("crop:", reason)
        s.notice = reason
        self:RefreshBox()
        return false
    end
    if s.stage == 1 then s.crop.left = x
    elseif s.stage == 2 then s.crop.right = s.width - x
    elseif s.stage == 3 then s.crop.top = y
    elseif s.stage == 4 then s.crop.bottom = s.height - y end
    s.stage = s.stage + 1
    s.preview = ({0, s.width, 0, s.height})[s.stage]
    s.notice = nil
    self:RefreshBox()
    self:LayoutLines()
    return true
end

function Crop:Reset()
    local s = self:CheckSession()
    if not s then HM:Print("crop: no active calibration; use /wmcrop <map>."); return false end
    s.crop = {left = 0, right = 0, top = 0, bottom = 0}
    s.stage, s.preview, s.locked, s.notice = 1, 0, false, nil
    self:RefreshBox()
    self:Update()
    return true
end

function Crop:Lock()
    local s = self:CheckSession()
    if not s or s.stage ~= 5 or s.locked then
        HM:Print("crop: select all four boundaries; each selection can be locked once.")
        return false
    end
    self:Update()
    if not self.session or s.waiting then return false end
    if WildMapsDB == nil then WildMapsDB = {} end
    if type(WildMapsDB) ~= "table" or (WildMapsDB.cropCalibrationLog ~= nil
        and type(WildMapsDB.cropCalibrationLog) ~= "table") then
        HM:Print("crop: SavedVariables log is not a table; nothing was saved.")
        return false
    end
    local stamp, stampSource = safeNumber(GetServerTime), "GetServerTime"
    if not stamp then stamp, stampSource = safeNumber(time), "time" end
    local record = {
        schemaVersion = 1, addonVersion = HM.version, mapID = s.map.id, mapName = s.map.name,
        timestamp = stamp, timestampSource = stamp and stampSource or nil,
        coordinateSpace = "render_pixels_top_left", precision = "nearest_integer_pixel",
        sourceWidth = s.width, sourceHeight = s.height,
        rawSourceWidth = s.render.sourceWidth, rawSourceHeight = s.render.sourceHeight,
        left = s.crop.left, right = s.crop.right, top = s.crop.top, bottom = s.crop.bottom,
        rotation = s.rotation, manuallyForced = true,
        packagedCrop = copyScalars(s.packagedCrop), texturePrefix = s.render.texturePrefix,
    }
    local log = WildMapsDB.cropCalibrationLog or {}
    log[#log + 1] = record
    while #log > LOG_LIMIT do table.remove(log, 1) end
    WildMapsDB.cropCalibrationLog = log
    s.locked = true
    self.overlay:EnableMouse(false)
    self.overlay:EnableMouseWheel(false)
    self:RefreshBox()
    HM:Print(string.format("crop locked: map=%s basis=render_pixels source=%dx%d left=%d right=%d top=%d bottom=%d rotation=%s",
        record.mapID, record.sourceWidth, record.sourceHeight, record.left, record.right,
        record.top, record.bottom, tostring(record.rotation)))
    HM:Print(string.format("crop basis=render_pixels_top_left rawSource=%sx%s; saved in WildMapsDB.cropCalibrationLog",
        tostring(record.rawSourceWidth), tostring(record.rawSourceHeight)))
    return true
end

function Crop:Start(query)
    if not HM.Dev:RequireDeveloperTools() then return false end
    if not HM.MapOverride or not HM.MapOverride.Resolve then
        HM:Print("crop: map override resolver unavailable."); return false
    end
    -- Convenience spelling from the crop workflow; still resolve via the
    -- existing override/registry path. Production aliases are not changed.
    if string.lower(query) == "rfd_approach" then query = "rfda" end
    local map, matches = HM.MapOverride:Resolve(query)
    if not map then
        HM:Print("crop:", matches and #matches > 1 and "ambiguous map; use an exact ID:" or "unknown map:", query)
        if matches then for _, candidate in ipairs(matches) do HM:Print("-", candidate.id) end end
        return false
    end
    if not self:IsSuitable(map) then
        HM:Print("crop:", map.id, "is not a supported custom approach/open-world map. Use /wmcrop list.")
        return false
    end
    if not UIParent or not WorldMapFrame or not WorldMapFrame.ScrollContainer
        or type(GetCursorPosition) ~= "function" or not HM.WorldMap then
        HM:Print("crop: World Map, canvas or cursor API unavailable; open the map once, then retry.")
        return false
    end
    if not WorldMapFrame:IsShown() and type(ShowUIPanel) ~= "function" then
        HM:Print("crop: World Map opening API unavailable; no calibration started.")
        return false
    end
    if not HM.WorldMap:Ensure() then HM:Print("crop: renderer initialization unavailable."); return false end
    if HM.EntranceCalibration and HM.EntranceCalibration.session then
        HM.EntranceCalibration:Stop("crop calibration started")
    end
    if self.session then self:Stop("restarting", true) end
    local area = HM.Experiments and HM.Experiments.WCCurrentArea
    self.startRestore = {
        active = HM.MapOverride.active, expiresAt = HM.MapOverride.expiresAt,
        currentMap = HM.currentMap, map = HM.WorldMap.map, areaEnabled = area and area.enabled,
    }
    -- Use the existing force and expiry machinery, then open the native map.
    -- Cancel exits calibration only; /wmmap off restores live detection.
    -- Re-measure the full original artwork, not the previously packaged crop.
    HM.Renderer.calibrationMap = map
    HM.MapOverride:Apply(map)
    -- ShowUIPanel is used instead of toggling, so an already-open map stays open.
    if not WorldMapFrame:IsShown() then
        local ok = pcall(ShowUIPanel, WorldMapFrame)
        if not ok or not WorldMapFrame:IsShown() then
            self:RestoreStart()
            HM:Print("crop: World Map could not open in this context; retry outside combat.")
            return false
        end
    end
    local renderer = HM.WorldMap.renderer
    if not renderer or not renderer.GetEffectiveScale or not renderer.GetLeft or not renderer.GetTop then
        self:RestoreStart()
        HM:Print("crop: usable renderer coordinates unavailable; no calibration started.")
        return false
    end
    self:EnsureUI(renderer)
    self.session = {
        map = map, render = map.render, renderer = renderer, override = HM.MapOverride.active,
        width = map.render.width, height = map.render.height,
        rotation = map.render.displayRotationDegrees or 0,
        packagedCrop = copyScalars(map.render.presentationCrop
            or (map.processing and map.processing.postRotationCrop)),
    }
    self.panel:Show()
    self:Reset()
    self.startRestore = nil
    HM:Print("crop calibration:", map.id, "click LEFT, RIGHT, TOP, BOTTOM, then Lock; /wmcrop cancel exits.")
    return true
end

function Crop:HandleSlash(message)
    if not HM.Dev:RequireDeveloperTools() then return false end
    local query = (message or ""):match("^%s*(.-)%s*$")
    local command = string.lower(query)
    if command == "cancel" then self:Stop("cancelled")
    elseif command == "reset" then self:Reset()
    elseif command == "lock" then self:Lock()
    elseif command == "status" then
        local s = self.session
        if s then
            HM:Print(string.format("crop map=%s selecting=%s left=%d right=%d top=%d bottom=%d locked=%s",
                s.map.id, STAGES[s.stage], s.crop.left, s.crop.right, s.crop.top, s.crop.bottom, tostring(s.locked or false)))
        else HM:Print("crop calibration: OFF") end
    elseif command == "list" then
        HM:Print("crop-compatible maps:")
        for _, map in ipairs(HM.Registry:GetMaps()) do
            if self:IsSuitable(map) then HM:Print("-", map.id) end
        end
    elseif query == "" then
        HM:Print("/wmcrop <map> | reset | cancel | lock | status | list; e.g. /wmcrop rfda")
    else self:Start(query) end
end

SLASH_WILDMAPSCROP1 = "/wmcrop"
SlashCmdList.WILDMAPSCROP = function(message) Crop:Safe("command", Crop.HandleSlash, message) end

-- Always-live driver can recover after a transient zero-size canvas even while
-- the capture overlay is hidden. It does no UI work outside crop mode.
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if Crop.session then Crop:Safe("update", Crop.Update) end
end)
if hooksecurefunc and HM.WorldMap and HM.WorldMap.RefreshMap then
    hooksecurefunc(HM.WorldMap, "RefreshMap", function()
        if Crop.session then Crop:Safe("map refresh", Crop.Update) end
    end)
end
