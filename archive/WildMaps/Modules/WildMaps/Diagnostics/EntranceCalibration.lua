local _, addonNS = ...
local HM = addonNS.WildMaps

-- Developer measurement only: log raw source pixels, never rewrite map data.
HM.EntranceCalibration = {}
local Entrance = HM.EntranceCalibration
local LOG_LIMIT = 50

local function finite(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function copyData(value)
    if type(value) == "table" then
        local result = {}
        for key, child in pairs(value) do
            if type(key) == "string" or finite(key) then result[key] = copyData(child) end
        end
        return result
    end
    if type(value) == "string" or type(value) == "boolean" or finite(value) then return value end
end

local function safeNumber(fn)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok and finite(value) then return value end
end

function Entrance:IsSuitable(map)
    return HM.CropCalibration:IsSuitable(map)
end

function Entrance:Stop(reason, quiet)
    self.session = nil
    self:ClearHover()
    self:CloseLabelDialog()
    if self.overlay then
        pcall(self.overlay.EnableMouse, self.overlay, false)
        pcall(self.overlay.EnableMouseWheel, self.overlay, false)
        pcall(self.overlay.Hide, self.overlay)
    end
    if self.panel then
        if self.panel.StopMovingOrSizing then pcall(self.panel.StopMovingOrSizing, self.panel) end
        pcall(self.panel.Hide, self.panel)
    end
    -- Clear before refreshing so an error cannot leave an active candidate.
    HM.MapMarkers.entrancePreview = nil
    pcall(HM.MapMarkers.Refresh, HM.MapMarkers)
    if not quiet then HM:Print("entrance calibration ended:", reason or "cancelled", "(locked records retained)") end
end

function Entrance:RestoreStart()
    local previous = self.startRestore
    self.startRestore = nil
    if not previous then return end
    HM.MapOverride.active, HM.MapOverride.expiresAt = previous.active, previous.expiresAt
    HM.currentMap = previous.currentMap
    local area = HM.Experiments and HM.Experiments.WCCurrentArea
    if area then area.enabled = previous.areaEnabled end
    HM.WorldMap:SetMap(previous.map)
end

function Entrance:Safe(action, fn, ...)
    local ok, result = pcall(fn, self, ...)
    if not ok then
        self:Stop(nil, true)
        if self.startRestore then pcall(self.RestoreStart, self) end
        HM:Print("entrance calibration stopped:", action, "-", tostring(result))
        return false
    end
    return result
end

function Entrance:CheckSession()
    local s = self.session
    if not s then return nil end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        self:Stop("World Map closed"); return nil
    end
    local world = HM.WorldMap
    if world.map ~= s.map or world:GetEffectiveMap() ~= s.map or world.renderer ~= s.renderer
        or HM.MapOverride.active ~= s.override or HM.Renderer.calibrationMap
        or s.map.render ~= s.render or s.render.width ~= s.width or s.render.height ~= s.height
        or s.render.sourceWidth ~= s.sourceWidth or s.render.sourceHeight ~= s.sourceHeight
        or (s.render.displayRotationDegrees or 0) ~= s.rotation then
        self:Stop("map, override or coordinate basis changed"); return nil
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

function Entrance:EnsureUI(renderer)
    if not self.uiReady then
        local overlay = CreateFrame("Button", nil, renderer)
        self.overlay = overlay
        overlay:Hide()
        overlay:EnableMouse(false)
        overlay:RegisterForClicks("LeftButtonUp")
        overlay:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then Entrance:Safe("click", Entrance.Click) end
        end)
        overlay:SetScript("OnMouseDown", function() end)
        overlay:SetScript("OnMouseWheel", function() end)

        local panel = CreateFrame("Frame", nil, UIParent)
        self.panel = panel
        panel:Hide()
        panel:SetSize(400, 304)
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        panel:EnableMouse(true)
        panel:SetMovable(true)
        panel:SetClampedToScreen(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", function() Entrance:Safe("move panel", function() panel:StartMoving() end) end)
        panel:SetScript("OnDragStop", function() Entrance:Safe("move panel", function() panel:StopMovingOrSizing() end) end)
        local background = panel:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.035, 0.045, 0.065, 0.97)
        font(panel, "GameFontNormalLarge", 14, -14, 372):SetText("WildMaps Entrance Calibration")
        self.mapText = font(panel, "GameFontNormalSmall", 14, -44, 372)
        local multiple = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        self.multipleCheck = multiple
        multiple:SetSize(24, 24)
        multiple:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -81)
        font(panel, "GameFontNormal", 42, -87, 344):SetText("Multiple entrances")
        multiple:SetScript("OnClick", function(b)
            Entrance:Safe("mode", Entrance.SetMultiple, b:GetChecked())
        end)
        self.valuesText = font(panel, "GameFontNormal", 14, -116, 372)
        self.noticeText = font(panel, "GameFontNormalSmall", 14, -190, 372)
        font(panel, "GameFontNormalSmall", 14, -244, 372):SetText("Drag this box to uncover the map.")
        local function button(label, x, callback)
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(84, 24)
            b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, 10)
            b:SetText(label)
            b:SetScript("OnClick", callback)
            return b
        end
        self.lockButton = button("LOCK", 14, function() Entrance:Safe("lock", Entrance.Lock) end)
        self.undoButton = button("UNDO LAST", 110, function() Entrance:Safe("undo", Entrance.Undo) end)
        button("RESET", 206, function() Entrance:Safe("reset", Entrance.Reset) end)
        button("CANCEL", 302, function() Entrance:Safe("cancel", Entrance.Stop, "cancelled") end)

        local dialog = CreateFrame("Frame", nil, panel)
        self.labelDialog = dialog
        dialog:Hide()
        dialog:SetSize(400, 148)
        dialog:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -8)
        dialog:SetClampedToScreen(true)
        dialog:EnableMouse(true)
        local dialogBackground = dialog:CreateTexture(nil, "BACKGROUND")
        dialogBackground:SetAllPoints()
        dialogBackground:SetColorTexture(0.035, 0.045, 0.065, 1)
        font(dialog, "GameFontNormal", 14, -14, 372):SetText("Entrance label:")
        local edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
        self.labelEdit = edit
        edit:SetSize(360, 24)
        edit:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -43)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(160)
        edit:SetScript("OnEnterPressed", function() Entrance:Safe("save label", Entrance.SaveLabel) end)
        edit:SetScript("OnEscapePressed", function() Entrance:Safe("cancel label", Entrance.CancelLabel) end)
        self.labelError = font(dialog, "GameFontNormalSmall", 14, -80, 372)
        local function labelButton(label, x, fn)
            local b = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
            b:SetSize(180, 24)
            b:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", x, 12)
            b:SetText(label)
            b:SetScript("OnClick", function() Entrance:Safe(label .. " label", fn) end)
            return b
        end
        self.labelSaveButton = labelButton("SAVE", 14, Entrance.SaveLabel)
        self.labelCancelButton = labelButton("CANCEL", 206, Entrance.CancelLabel)
        self.uiReady = true
    end
    self.overlay:SetParent(renderer)
    self.overlay:ClearAllPoints()
    self.overlay:SetAllPoints(renderer)
    self.overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    self.panel:SetFrameStrata("FULLSCREEN_DIALOG")
    if self.hookedWorldMap ~= WorldMapFrame then
        WorldMapFrame:HookScript("OnHide", function()
            if Entrance.session then Entrance:Safe("map closed", Entrance.Stop, "World Map closed") end
        end)
        self.hookedWorldMap = WorldMapFrame
    end
end

function Entrance:RefreshBox()
    local s = self.session
    if not s then return end
    self.mapText:SetText("Map: " .. s.map.name .. "\nID: " .. s.map.id)
    local point = s.pending or s.entrances[#s.entrances]
    local coordinates = point and string.format("Latest source X: %.6f   Y: %.6f", point.sourceX, point.sourceY)
        or "Latest source X: --   Y: --"
    self.valuesText:SetText(string.format("Entrances selected: %d\n%s\n%s", #s.entrances, coordinates,
        s.pending and "Waiting for label / NOT SAVED" or (s.locked and "LOCKED / SAVED" or "NOT LOCKED")))
    self.noticeText:SetText(s.waiting and "Waiting for usable map geometry; selections retained."
        or (s.pending and "Enter hover text, then SAVE.\nDialog CANCEL discards only the new point."
        or (s.locked and "Saved. RESET starts a new selection; CANCEL ends preview."
        or (s.multiple and "Left-click to ADD an entrance, then enter its hover text.\nUNDO LAST removes the latest selection; LOCK saves all."
        or "Left-click to place/move the entrance and enter hover text.\nLOCK saves source coordinates and text."))))
    self.lockButton:SetEnabled(#s.entrances > 0 and not s.pending and not s.locked and not s.waiting)
    self.undoButton:SetEnabled((#s.entrances > 0 or s.pending ~= nil) and not s.locked)
    self.multipleCheck:SetChecked(s.multiple)
    -- Require undo/reset before going back to single mode; never silently drop
    -- multiple labeled selections when a checkbox is clicked accidentally.
    self.multipleCheck:SetEnabled(not s.locked and not s.pending and #s.entrances <= 1)
end

function Entrance:MakeMarker(s, point)
    -- Copy the existing entrance treatment, or the proven RFD style for maps
    -- without one. Never change the reference marker or its source position.
    local reference
    for _, marker in ipairs(s.map.markers or {}) do
        if marker.type == "entrance_exit" then reference = marker; break end
    end
    if not reference then
        local rfd = HM.Registry:GetMap("razorfen_downs_approach")
        for _, marker in ipairs(rfd and rfd.markers or {}) do
            if marker.type == "entrance_exit" then reference = marker; break end
        end
    end
    if not reference then error("reference entrance icon is unavailable") end
    local marker = copyData(reference)
    marker.name = point.label or "Entrance label pending"
    marker.tooltip = marker.name
    marker.showLabel = false
    marker.position = { space = "source_pixels", x = point.sourceX, y = point.sourceY }
    return marker
end

function Entrance:ShowCandidate()
    local s = self.session
    local markers = {}
    if s then
        -- In single mode the provisional icon replaces the old preview, but
        -- the old labeled selection is retained until SAVE commits the move.
        if s.multiple or not s.pending then
            for _, point in ipairs(s.entrances) do markers[#markers + 1] = self:MakeMarker(s, point) end
        end
        if s.pending then markers[#markers + 1] = self:MakeMarker(s, s.pending) end
    end
    HM.MapMarkers:SetEntrancePreviews(s and s.map, markers)
end

function Entrance:ClearHover()
    if self.hoveredPreview and self.overlay and GameTooltip and GameTooltip.GetOwner
        and GameTooltip:GetOwner() == self.overlay then
        GameTooltip:Hide()
    end
    self.hoveredPreview = nil
end

function Entrance:UpdateHover(s)
    if s.locked or s.waiting or s.pending then self:ClearHover(); return end
    local x, y = GetCursorPosition()
    local hovered
    if HM.CropCalibration:CursorInFrame(self.panel, x, y) == nil then
        for _, button in ipairs(HM.MapMarkers.buttons) do
            if button:IsShown() and HM.CropCalibration:CursorInFrame(button, x, y) ~= nil then
                hovered = button; break
            end
        end
    end
    if self.hoveredPreview ~= hovered then
        self:ClearHover()
        if hovered and GameTooltip then
            GameTooltip:SetOwner(self.overlay, "ANCHOR_CURSOR")
            GameTooltip:SetText(hovered._hiddenMapsTooltip or "")
            GameTooltip:Show()
            self.hoveredPreview = hovered
        end
    end
end

function Entrance:Update()
    local s = self:CheckSession()
    if not s then return end
    local r = s.renderer
    local w, h = r:GetSize()
    local scale, left, top = r:GetEffectiveScale(), r:GetLeft(), r:GetTop()
    local waiting = not r:IsShown() or not finite(w) or not finite(h) or w <= 0 or h <= 0
        or not finite(scale) or scale <= 0 or not finite(left) or not finite(top)
    self.overlay:SetFrameLevel(r:GetFrameLevel() + 100)
    self.panel:SetFrameLevel(self.overlay:GetFrameLevel() + 100)
    self.labelDialog:SetFrameLevel(self.panel:GetFrameLevel() + 10)
    self.overlay:EnableMouse(not waiting and not s.locked)
    self.overlay:EnableMouseWheel(not waiting and not s.locked)
    if waiting then self.overlay:Hide() else self.overlay:Show() end
    if s.waiting ~= waiting then s.waiting = waiting; self:RefreshBox() end
    self:UpdateHover(s)
end

function Entrance:GetCursorSource()
    local s = self.session
    if not s or type(GetCursorPosition) ~= "function" then return nil end
    local x, y = GetCursorPosition()
    -- Reuse the crop tool's effective-scale-aware, top-left frame conversion.
    if self.panel:IsShown() and HM.CropCalibration:CursorInFrame(self.panel, x, y) ~= nil then return nil end
    if self.labelDialog:IsShown() and HM.CropCalibration:CursorInFrame(self.labelDialog, x, y) ~= nil then return nil end
    local u, v = HM.CropCalibration:CursorInFrame(s.renderer, x, y)
    if u == nil then return nil end
    return HM.MapCoordinates:FrameFractionToSource(s.map, u, v)
end

function Entrance:Click()
    self:Update()
    local s = self.session
    if not s or s.locked or s.waiting or s.pending then return false end
    local x, y = self:GetCursorSource()
    if x == nil then return false end
    s.pending = { sourceX = x, sourceY = y }
    self:ClearHover()
    self:ShowCandidate()
    self.labelError:SetText("")
    local previous = not s.multiple and s.entrances[1]
    self.labelEdit:SetText(previous and previous.label or "")
    self.labelDialog:Show()
    self.labelEdit:SetFocus()
    self.labelEdit:HighlightText()
    self:RefreshBox()
    return true
end

function Entrance:CloseLabelDialog()
    if self.labelEdit then pcall(self.labelEdit.ClearFocus, self.labelEdit) end
    if self.labelDialog then pcall(self.labelDialog.Hide, self.labelDialog) end
end

function Entrance:SaveLabel()
    local s = self:CheckSession()
    if not s or not s.pending or s.locked then return false end
    local label = (self.labelEdit:GetText() or ""):match("^%s*(.-)%s*$")
    if label == "" or label:find("[%c]") then
        self.labelError:SetText("Enter a non-empty, single-line hover label.")
        self.labelEdit:SetFocus()
        return false
    end
    s.pending.label = label
    if not s.multiple then s.entrances = {} end
    s.entrances[#s.entrances + 1] = s.pending
    s.pending = nil
    self:CloseLabelDialog()
    self:ShowCandidate()
    self:RefreshBox()
    return true
end

function Entrance:CancelLabel()
    local s = self:CheckSession()
    if not s or not s.pending then return false end
    s.pending = nil
    self:CloseLabelDialog()
    self:ShowCandidate()
    self:RefreshBox()
    return true
end

function Entrance:SetMultiple(enabled)
    local s = self:CheckSession()
    if not s then return false end
    if s.locked or s.pending or (not enabled and #s.entrances > 1) then
        self:RefreshBox(); return false
    end
    s.multiple = not not enabled
    self:RefreshBox()
    return true
end

function Entrance:Undo()
    local s = self:CheckSession()
    if not s or s.locked then return false end
    if s.pending then return self:CancelLabel() end
    if #s.entrances == 0 then return false end
    table.remove(s.entrances)
    self:ClearHover()
    self:ShowCandidate()
    self:RefreshBox()
    return true
end

function Entrance:Reset()
    local s = self:CheckSession()
    if not s then HM:Print("entrance: no active session; use /wmentrance <map>."); return false end
    s.entrances, s.pending, s.locked = {}, nil, false
    self:ClearHover()
    self:CloseLabelDialog()
    self:ShowCandidate()
    self:Update()
    self:RefreshBox()
    return true
end

function Entrance:Lock()
    self:Update()
    local s = self.session
    if not s or #s.entrances == 0 or s.pending or s.locked or s.waiting then
        HM:Print("entrance: save each point's label first; each selection can be locked once."); return false
    end
    if WildMapsDB == nil then WildMapsDB = {} end
    if type(WildMapsDB) ~= "table" or (WildMapsDB.entranceCalibrationLog ~= nil
        and type(WildMapsDB.entranceCalibrationLog) ~= "table") then
        HM:Print("entrance: SavedVariables log is not a table; nothing was saved."); return false
    end
    local stamp, stampSource = safeNumber(GetServerTime), "GetServerTime"
    if not stamp then stamp, stampSource = safeNumber(time), "time" end
    local markers = {}
    for _, point in ipairs(s.entrances) do markers[#markers + 1] = self:MakeMarker(s, point) end
    local single = not s.multiple and s.entrances[1]
    local record = {
        schemaVersion = 2, addonVersion = HM.version, mapID = s.map.id, mapName = s.map.name,
        timestamp = stamp, timestampSource = stamp and stampSource or nil,
        coordinateSpace = "source_pixels", origin = "top_left", yDirection = "down",
        sourceWidth = s.sourceWidth, sourceHeight = s.sourceHeight,
        multiple = s.multiple, entrances = copyData(s.entrances),
        -- Retain the old single-point fields for existing log consumers.
        sourceX = single and single.sourceX or nil, sourceY = single and single.sourceY or nil,
        renderWidth = s.width, renderHeight = s.height, rotation = s.rotation,
        presentationCrop = copyData(s.render.presentationCrop),
        postRotationCrop = copyData(s.map.processing and s.map.processing.postRotationCrop),
        approachPadding = HM.Renderer.approachPadding, texturePrefix = s.render.texturePrefix,
        sourceMetadata = copyData(s.map.source), positionConfiguration = copyData(s.map.position),
        marker = single and copyData(markers[1]) or nil, markers = copyData(markers), manuallyForced = true,
    }
    local log = WildMapsDB.entranceCalibrationLog or {}
    log[#log + 1] = record
    while #log > LOG_LIMIT do table.remove(log, 1) end
    WildMapsDB.entranceCalibrationLog = log
    s.locked = true
    self:ClearHover()
    self:ShowCandidate()
    self:Update()
    self:RefreshBox()
    HM:Print(string.format("Entrance Lock: map=%s count=%d source=%dx%d version=%s",
        record.mapID, #record.entrances, record.sourceWidth, record.sourceHeight, tostring(record.addonVersion)))
    for i, point in ipairs(record.entrances) do
        HM:Print(string.format('%d: x=%.6f y=%.6f text=%q', i, point.sourceX, point.sourceY, point.label))
    end
    HM:Print("saved in WildMapsDB.entranceCalibrationLog")
    return true
end

function Entrance:Start(query)
    if not HM.Dev:RequireDeveloperTools() then return false end
    if string.lower(query) == "rfd_approach" then query = "rfda" end
    local map, matches = HM.MapOverride:Resolve(query)
    if not map then
        HM:Print("entrance:", matches and #matches > 1 and "ambiguous map; use an exact ID:" or "unknown map:", query)
        if matches then for _, candidate in ipairs(matches) do HM:Print("-", candidate.id) end end
        return false
    end
    if not self:IsSuitable(map) then HM:Print("entrance: unsupported map; use /wmentrance list."); return false end
    if not UIParent or not WorldMapFrame or not WorldMapFrame.ScrollContainer
        or type(GetCursorPosition) ~= "function" or not HM.WorldMap:Ensure() then
        HM:Print("entrance: World Map/cursor unavailable; open the map once, then retry."); return false
    end
    if not WorldMapFrame:IsShown() and type(ShowUIPanel) ~= "function" then
        HM:Print("entrance: World Map opening API unavailable."); return false
    end
    if HM.CropCalibration.session then HM.CropCalibration:Stop("entrance calibration started") end
    if self.session then self:Stop("restarting", true) end
    local area = HM.Experiments and HM.Experiments.WCCurrentArea
    self.startRestore = {
        active = HM.MapOverride.active, expiresAt = HM.MapOverride.expiresAt,
        currentMap = HM.currentMap, map = HM.WorldMap.map, areaEnabled = area and area.enabled,
    }
    HM.MapOverride:Apply(map)
    if not WorldMapFrame:IsShown() then
        local ok = pcall(ShowUIPanel, WorldMapFrame)
        if not ok or not WorldMapFrame:IsShown() then
            self:RestoreStart()
            HM:Print("entrance: World Map could not open; retry outside combat."); return false
        end
    end
    local renderer = HM.WorldMap.renderer
    if not renderer or not renderer.GetEffectiveScale or not renderer.GetLeft or not renderer.GetTop then
        self:RestoreStart(); HM:Print("entrance: usable renderer unavailable."); return false
    end
    self:EnsureUI(renderer)
    self.session = {
        map = map, render = map.render, renderer = renderer, override = HM.MapOverride.active,
        width = map.render.width, height = map.render.height,
        sourceWidth = map.render.sourceWidth, sourceHeight = map.render.sourceHeight,
        rotation = map.render.displayRotationDegrees or 0,
        multiple = false, entrances = {},
    }
    self.panel:Show()
    self:Reset()
    self.startRestore = nil
    HM:Print("entrance calibration:", map.id, "click, enter hover text, SAVE, then LOCK. Check Multiple entrances to add points. /wmmap off restores detection.")
    return true
end

function Entrance:HandleSlash(message)
    if not HM.Dev:RequireDeveloperTools() then return false end
    local query = (message or ""):match("^%s*(.-)%s*$")
    local command = string.lower(query)
    if command == "cancel" then self:Stop("cancelled")
    elseif command == "reset" then self:Reset()
    elseif command == "undo" then self:Undo()
    elseif command == "lock" then self:Lock()
    elseif command == "status" then
        local s = self:CheckSession()
        if s then
            HM:Print("entrance map=" .. s.map.id, "count=" .. #s.entrances, "multiple=" .. tostring(s.multiple),
                "labelPending=" .. tostring(s.pending ~= nil), "locked=" .. tostring(s.locked or false))
            for i, point in ipairs(s.entrances) do
                HM:Print(string.format('%d: x=%.6f y=%.6f text=%q', i, point.sourceX, point.sourceY, point.label))
            end
        else HM:Print("entrance calibration: OFF") end
    elseif command == "list" then
        HM:Print("entrance-calibration maps:")
        for _, map in ipairs(HM.Registry:GetMaps()) do if self:IsSuitable(map) then HM:Print("-", map.id) end end
    elseif query == "" then
        HM:Print("/wmentrance <map> | lock | undo | reset | cancel | status | list; e.g. /wmentrance wca")
    else self:Start(query) end
end

SLASH_WILDMAPSENTRANCE1 = "/wmentrance"
SlashCmdList.WILDMAPSENTRANCE = function(message) Entrance:Safe("command", Entrance.HandleSlash, message) end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function()
    if Entrance.session then Entrance:Safe("update", Entrance.Update) end
end)
if hooksecurefunc and HM.WorldMap and HM.WorldMap.RefreshMap then
    hooksecurefunc(HM.WorldMap, "RefreshMap", function()
        if Entrance.session then Entrance:Safe("map refresh", Entrance.Update) end
    end)
end
