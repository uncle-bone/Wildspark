local _, addonNS = ...
local HM = addonNS.WildMaps

HM.WorldMap = {}
local WorldMap = HM.WorldMap

WorldMap.initialized = false
WorldMap.map = nil
WorldMap.floorSelections = {}
-- Display-only, never saved and never substituted for the detected map.
WorldMap.bypassUntilClose = false

local function readableMapID(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0 then
        return value
    end
end

local function nativeMapID()
    if not WorldMapFrame or type(WorldMapFrame.GetMapID) ~= "function" then return nil end
    local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
    return ok and readableMapID(id) or nil
end

local function nativeParentID(id)
    if not id or not C_Map or type(C_Map.GetMapInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if not ok or (type(issecretvalue) == "function" and issecretvalue(info)) then return nil end
    return type(info) == "table" and readableMapID(info.parentMapID) or nil
end

local function isNativeAncestor(fromID, toID)
    if not fromID or not toID or fromID == toID then return false end
    local seen = { [fromID] = true }
    for _ = 1, 32 do
        fromID = nativeParentID(fromID)
        if not fromID or seen[fromID] then return false end
        if fromID == toID then return true end
        seen[fromID] = true
    end
    return false
end

function WorldMap:IsPresentationShown()
    return self.map and self.renderer and WorldMapFrame and WorldMapFrame:IsShown()
        and self.renderer:IsShown()
        and ((self.host and self.host:IsShown()) or (self.presentationHost and self.presentationHost:IsShown()))
end

function WorldMap:HidePresentation()
    for _, key in ipairs({ "host", "backgroundHost", "presentationHost", "interactionLayer", "floorSelector",
        "locationHint", "legacyRenderer", "customRenderer" }) do
        if self[key] then self[key]:Hide() end
    end
    self.renderer = self.legacyRenderer
    if HM.MapMarkers then HM.MapMarkers:HideAll() end
end

-- Forever 1.60.1 (70235): both NavigateToParentMap and NavBar:GoToMap
-- call SetMapID synchronously. Observe the resulting ID, then let a secure
-- post-hook on those native routes confirm it. SetMapID alone never bypasses
-- WildMaps (opening, quest updates, floor changes and other addons use it).
function WorldMap:RecordNativeMapChange()
    local previous, current = self.nativeMapID, nativeMapID()
    self.nativeMapID = current
    self.pendingNavigation = nil
    if self.bypassUntilClose or not self.navigationSessionOpen or not self:IsPresentationShown()
        or not previous or not current or previous == current
        or not C_Timer or type(C_Timer.After) ~= "function" then return end

    local change = { from = previous, to = current }
    self.pendingNavigation = change
    -- A later no-op navigation must not consume an unrelated earlier change.
    C_Timer.After(0, function()
        if WorldMap.pendingNavigation == change then WorldMap.pendingNavigation = nil end
    end)
end

function WorldMap:ObserveNativeNavigation(allowNonAncestor)
    local change = self.pendingNavigation
    self.pendingNavigation = nil
    if self.bypassUntilClose or not self.navigationSessionOpen or not self:IsPresentationShown()
        or not change or nativeMapID() ~= change.to or (not allowNonAncestor and not isNativeAncestor(change.from, change.to)) then return end

    self.bypassUntilClose = true
    self:RefreshMap()
    self:RefreshFloorSelector()
end

function WorldMap:EnsureNavigationHooks()
    if type(hooksecurefunc) ~= "function" or not WorldMapFrame then return end
    if not self.navigationHooked and type(WorldMapFrame.SetMapID) == "function"
        and type(WorldMapFrame.GetMapID) == "function" and type(WorldMapFrame.NavigateToParentMap) == "function" then
        self.nativeMapID = nativeMapID()
        self.navigationSessionOpen = WorldMapFrame:IsShown()
        hooksecurefunc(WorldMapFrame, "SetMapID", function() WorldMap:RecordNativeMapChange() end)
        hooksecurefunc(WorldMapFrame, "NavigateToParentMap", function() WorldMap:ObserveNativeNavigation() end)
        self.navigationHooked = true
    end
    local navBar = WorldMapFrame.NavBar
    if self.navigationHooked and navBar and self.hookedNavBar ~= navBar and type(navBar.GoToMap) == "function" then
        hooksecurefunc(navBar, "GoToMap", function() WorldMap:ObserveNativeNavigation(true) end)
        self.hookedNavBar = navBar
    end
end

function WorldMap:ForwardParentNavigation(button)
    if HM.Compatibility and HM.Compatibility:HandleParentNavigation(button, nativeParentID(nativeMapID())) then return end
    if button ~= "RightButton" or self.bypassUntilClose or not self:IsPresentationShown()
        or not self.navigationHooked or not nativeParentID(nativeMapID()) then return end
    local scroll = WorldMapFrame.ScrollContainer
    if type(scroll.ShouldNavigateOnClick) ~= "function" or not scroll:ShouldNavigateOnClick()
        or (type(scroll.ShouldNavigateIgnoreZoneMapPositionData) == "function"
            and scroll:ShouldNavigateIgnoreZoneMapPositionData()) then return end
    self.pendingNavigation = nil
    -- Keep hidden pins blocked. Do not pass raw clicks through the shield or
    -- run their canvas click handlers; invoke Blizzard's parent action itself.
    WorldMapFrame:NavigateToParentMap()
end

-- One full-canvas decorative background is shared by every HiddenMap. It sits
-- below the actual map renderer, so full-frame maps naturally cover it while
-- smaller, cropped, or irregular maps reveal it only where needed.
WorldMap.backgroundTexture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Decor\\hiddenmaps_background.tga"

-- Presentation classes describe the intended map artwork aspect ratio. The
-- outer Blizzard World Map frame remains untouched; WildMaps only controls
-- the full-canvas presentation layer inside Blizzard's map canvas.
WorldMap.frameLayouts = {
    wide = { width = 640, height = 480 },
    square = { width = 560, height = 560 },
    tall = { width = 420, height = 560 },
}

local function getFloorCount(map)
    if not map or type(map.floors) ~= "table" then
        return 0
    end
    return #map.floors
end

local function getFrameLayout(map)
    if not map or type(map.frameLayout) ~= "string" then
        return nil
    end
    return WorldMap.frameLayouts[map.frameLayout]
end

local function makeSolidTexture(parent, layer, r, g, b, a)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetColorTexture(r, g, b, a)
    return texture
end

function WorldMap:GetSelectedFloorIndex(map)
    map = map or self.map
    local count = getFloorCount(map)
    if count <= 0 then
        return nil
    end

    local index = self.floorSelections[map.id] or 1
    if index < 1 or index > count then
        index = 1
        self.floorSelections[map.id] = index
    end
    return index
end

function WorldMap:GetEffectiveMap()
    local map = self.map
    if not map then
        return nil
    end

    local count = getFloorCount(map)
    if count <= 0 then
        return map
    end

    local index = self:GetSelectedFloorIndex(map)
    local floor = map.floors[index]
    if not floor then
        return map
    end

    local effective = setmetatable({}, { __index = map })
    effective.render = floor.render or map.render
    if floor.position ~= nil then
        effective.position = floor.position
    end
    if floor.source ~= nil then
        effective.source = floor.source
    end
    effective._hiddenMapsFloorIndex = index
    effective._hiddenMapsFloorCount = count
    return effective
end

function WorldMap:SetFloor(index)
    local map = self.map
    local count = getFloorCount(map)
    if count <= 1 or type(index) ~= "number" or index < 1 or index > count then
        return false
    end

    self.floorSelections[map.id] = index
    self:RefreshMap()
    self:RefreshFloorSelector()
    self:RefreshDebugBadge()
    return true
end

function WorldMap:EnsureFloorButtons(count)
    local selector = self.floorSelector
    if not selector then
        return
    end

    selector.buttons = selector.buttons or {}
    while #selector.buttons < count do
        local index = #selector.buttons + 1
        local button = CreateFrame("Button", nil, selector, "UIPanelButtonTemplate")
        button:SetSize(28, 24)
        button:SetText(tostring(index))
        button:SetScript("OnClick", function()
            WorldMap:SetFloor(index)
        end)
        selector.buttons[index] = button
    end
end

function WorldMap:IsAdaptivePresentationMap(map)
    return getFrameLayout(map or self.map) ~= nil
end

function WorldMap:RefreshFloorSelector()
    if not self.initialized or not self.floorSelector then
        return
    end

    local count = getFloorCount(self.map)
    if count <= 1 or self.bypassUntilClose or not WorldMapFrame:IsShown() then
        self.floorSelector:Hide()
        return
    end

    -- Adaptive maps need their multi-floor controls above the full-canvas
    -- artwork and interaction shield. Legacy maps keep the original
    -- outer-frame selector parent and compatibility layering.
    local adaptive = self:IsAdaptivePresentationMap(self.map)
    local vertical = self.map.floorButtonLayout == "vertical"
    local selectorParent = adaptive and self.interactionLayer or WorldMapFrame
    selectorParent = selectorParent or WorldMapFrame
    if self.floorSelector:GetParent() ~= selectorParent then
        self.floorSelector:SetParent(selectorParent)
    end

    self.floorSelector:SetFrameStrata("HIGH")
    self.floorSelector:ClearAllPoints()
    if adaptive and self.interactionLayer then
        local baseLevel = self.interactionLayer:GetFrameLevel() or 0
        self.floorSelector:SetFrameLevel(baseLevel + 100)
        -- Opt-in narrow stack below the title, attached to the live canvas.
        self.floorSelector:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -12, vertical and -48 or -8)
    else
        self.floorSelector:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 30)
        self.floorSelector:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -54, -33)
    end

    -- Opt in only where the artwork leaves this canvas corner clear.
    if self.map.floorButtonAnchor == "BOTTOMRIGHT" then
        self.floorSelector:ClearAllPoints()
        self.floorSelector:SetPoint("BOTTOMRIGHT", WorldMapFrame.ScrollContainer, "BOTTOMRIGHT", -20, 20)
    end

    self:EnsureFloorButtons(count)
    local selected = self:GetSelectedFloorIndex(self.map) or 1
    local spacing = 4
    local buttonWidth = 28
    local width = count * buttonWidth + (count - 1) * spacing + 12
    local buttonHeight = 24
    if vertical then
        self.floorSelector:SetSize(buttonWidth + 12, count * buttonHeight + (count - 1) * spacing + 12)
    else
        self.floorSelector:SetSize(width, 34)
    end

    for i, button in ipairs(self.floorSelector.buttons) do
        button:ClearAllPoints()
        if i <= count then
            if vertical then
                button:SetPoint("TOPLEFT", self.floorSelector, "TOPLEFT", 6, -6 - (i - 1) * (buttonHeight + spacing))
            else
                button:SetPoint("LEFT", self.floorSelector, "LEFT", 6 + (i - 1) * (buttonWidth + spacing), 0)
            end
            button:SetEnabled(i ~= selected)
            button:Show()
        else
            button:Hide()
        end
    end

    self.floorSelector:Show()
end

function WorldMap:CreateAdaptivePresentationHost()
    if self.presentationHost then
        return
    end

    -- Private presentation objects: foreign addons must not acquire them by global name.
    local frame = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    frame:SetAllPoints(WorldMapFrame.ScrollContainer)
    frame:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 50)
    frame:EnableMouse(false)
    frame:Hide()

    -- The adaptive host itself must not paint an opaque backing. The universal
    -- full-canvas background lives below this frame and should remain visible
    -- anywhere the actual HiddenMap does not cover the canvas.
    local background = makeSolidTexture(frame, "BACKGROUND", 0, 0, 0, 0)
    background:SetAllPoints()
    frame.background = background

    local leftStrip = frame:CreateTexture(nil, "ARTWORK")
    leftStrip:SetVertTile(false)
    leftStrip:SetHorizTile(false)
    frame.leftStrip = leftStrip

    local rightStrip = frame:CreateTexture(nil, "ARTWORK")
    rightStrip:SetVertTile(false)
    rightStrip:SetHorizTile(false)
    frame.rightStrip = rightStrip

    local viewport = CreateFrame("Frame", nil, frame)
    viewport:SetClipsChildren(true)
    viewport:EnableMouse(false)
    frame.viewport = viewport

    self.presentationHost = frame
    self.customViewport = viewport
    self.customRenderer = HM.Renderer:Create(viewport)

    -- Mouse interaction is deliberately separated from the artwork. The
    -- Blizzard map and third-party map pins (Questie, etc.) still exist below
    -- WildMaps, so an opaque visual layer alone does not stop their hover
    -- handlers. This transparent sibling covers the complete live map canvas
    -- and wins hit-testing while an adaptive HiddenMap is active. Marker
    -- buttons are parented above it so their own tooltips remain interactive.
    local interactionLayer = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    interactionLayer:SetAllPoints(WorldMapFrame.ScrollContainer)
    interactionLayer:SetFrameLevel(frame:GetFrameLevel() + 200)
    interactionLayer:EnableMouse(true)
    interactionLayer:SetScript("OnMouseUp", function(frame, button)
        if frame:IsMouseOver() then WorldMap:ForwardParentNavigation(button) end
    end)
    interactionLayer:Hide()
    self.interactionLayer = interactionLayer
end

function WorldMap:LayoutAdaptivePresentation(map)
    local layout = getFrameLayout(map)
    local layoutName = map and map.frameLayout or nil
    local host = self.presentationHost
    local viewport = self.customViewport
    if not layout or not host or not viewport then
        return false
    end

    local canvas = WorldMapFrame and WorldMapFrame.ScrollContainer
    if not canvas then
        return false
    end

    local canvasWidth, canvasHeight = canvas:GetSize()
    if not canvasWidth or not canvasHeight or canvasWidth <= 0 or canvasHeight <= 0 then
        return false
    end

    host:ClearAllPoints()
    host:SetAllPoints(canvas)

    -- 4:3 is the native Blizzard World Map presentation class. It deliberately
    -- fills the complete canvas and uses no decorative strips.
    if layoutName == "wide" then
        viewport:ClearAllPoints()
        viewport:SetAllPoints(host)
        host.leftStrip:Hide()
        host.rightStrip:Hide()
        return true
    end

    local aspect = layout.width / layout.height
    local drawWidth = canvasWidth
    local drawHeight = drawWidth / aspect
    if drawHeight > canvasHeight then
        drawHeight = canvasHeight
        drawWidth = drawHeight * aspect
    end

    viewport:ClearAllPoints()
    viewport:SetSize(drawWidth, drawHeight)
    viewport:SetPoint("CENTER", host, "CENTER", 0, 0)

    -- Decorative side strips are superseded by the universal full-canvas
    -- background. Keeping these textures hidden means every uncovered region
    -- (including future crops and irregular silhouettes) uses one consistent
    -- presentation system.
    host.leftStrip:Hide()
    host.rightStrip:Hide()

    return true
end

function WorldMap:Ensure()
    if self.initialized then
        self:EnsureNavigationHooks()
        return true
    end

    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        return false
    end

    -- Universal visual backdrop. This is deliberately a sibling below both
    -- WildMaps renderer paths rather than a child of either renderer, so it
    -- always fills the complete Blizzard map canvas regardless of map size,
    -- crop, aspect ratio, or transparent holes in the map artwork.
    local backgroundHost = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    backgroundHost:SetAllPoints(WorldMapFrame.ScrollContainer)
    backgroundHost:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 40)
    backgroundHost:EnableMouse(false)
    backgroundHost:Hide()

    local backgroundArt = backgroundHost:CreateTexture(nil, "BACKGROUND")
    backgroundArt:SetAllPoints()
    backgroundArt:SetTexture(self.backgroundTexture)
    backgroundArt:SetTexCoord(0, 1, 0, 1)
    backgroundHost.art = backgroundArt
    self.backgroundHost = backgroundHost

    -- Legacy renderer path: retained for maps that have not opted into the
    -- adaptive full-canvas presentation layer. This protects the proven WC path.
    local host = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    host:SetAllPoints(WorldMapFrame.ScrollContainer)
    host:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 50)
    host:EnableMouse(false)
    host:Hide()
    self.host = host

    self.legacyRenderer = HM.Renderer:Create(host)
    self.legacyRenderer:SetAllPoints(host)
    self.renderer = self.legacyRenderer

    self:CreateAdaptivePresentationHost()

    -- Keep the current room signal visible even where Forever supplies no
    -- dungeon coordinates. This is descriptive zone text, never a guessed pin.
    local locationHint = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    locationHint:SetSize(420, 44)
    locationHint:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", 8, 8)
    locationHint:SetFrameStrata(WorldMapFrame:GetFrameStrata())
    locationHint:SetFrameLevel(WorldMapFrame.ScrollContainer:GetFrameLevel() + 500)
    locationHint:EnableMouse(false)
    locationHint:Hide()
    local locationBackground = locationHint:CreateTexture(nil, "BACKGROUND")
    locationBackground:SetAllPoints()
    locationBackground:SetColorTexture(0, 0, 0, 0.72)
    locationHint.background = locationBackground
    local locationText = locationHint:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    locationText:SetPoint("TOPLEFT", locationHint, "TOPLEFT", 8, -5)
    locationText:SetPoint("BOTTOMRIGHT", locationHint, "BOTTOMRIGHT", -8, 5)
    locationText:SetJustifyH("LEFT")
    locationText:SetJustifyV("MIDDLE")
    locationText:SetTextColor(1, 1, 1, 1)
    if locationText.SetWordWrap then locationText:SetWordWrap(true) end
    locationHint.text = locationText
    self.locationHint = locationHint

    local floorSelector = CreateFrame("Frame", nil, WorldMapFrame)
    floorSelector:SetPoint("TOPRIGHT", WorldMapFrame.ScrollContainer, "TOPRIGHT", -12, -8)
    floorSelector:EnableMouse(true)
    floorSelector:Hide()

    local floorBg = floorSelector:CreateTexture(nil, "BACKGROUND")
    floorBg:SetAllPoints()
    floorBg:SetColorTexture(0, 0, 0, 0.72)
    floorSelector.background = floorBg
    floorSelector.buttons = {}
    self.floorSelector = floorSelector

    WorldMapFrame.ScrollContainer:HookScript("OnSizeChanged", function()
        if WorldMapFrame:IsShown() then
            WorldMap:RefreshMap()
            WorldMap:RefreshFloorSelector()
        end
    end)

    WorldMapFrame:HookScript("OnShow", function()
        WorldMap.navigationSessionOpen = true
        WorldMap.nativeMapID = nativeMapID()
        WorldMap.pendingNavigation = nil
        WorldMap:RefreshMap()
        WorldMap:RefreshFloorSelector()
        WorldMap:RefreshDebugBadge()
        WorldMap:RefreshLocationHint()
    end)

    WorldMapFrame:HookScript("OnHide", function()
        WorldMap.bypassUntilClose = false
        WorldMap.navigationSessionOpen = false
        WorldMap.nativeMapID = nil
        WorldMap.pendingNavigation = nil
        if WorldMap.host then
            WorldMap.host:Hide()
        end
        if WorldMap.backgroundHost then
            WorldMap.backgroundHost:Hide()
        end
        if WorldMap.presentationHost then
            WorldMap.presentationHost:Hide()
        end
        if WorldMap.interactionLayer then
            WorldMap.interactionLayer:Hide()
        end
        if WorldMap.floorSelector then
            WorldMap.floorSelector:Hide()
        end
        if WorldMap.locationHint then
            WorldMap.locationHint:Hide()
        end
        WorldMap.renderer = WorldMap.legacyRenderer
    end)

    self:EnsureNavigationHooks()
    self.initialized = true
    return true
end

function WorldMap:SetMap(map)
    local previous = self.map
    self.map = map

    if map and map ~= previous and getFloorCount(map) > 0 and self.floorSelections[map.id] == nil then
        self.floorSelections[map.id] = 1
    end

    if self:Ensure() then
        self:RefreshMap()
        self:RefreshFloorSelector()
        self:RefreshDebugBadge()
        self:RefreshLocationHint()
    end
end

local function readableSignal(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value ~= "" and value or nil
end

local function currentRoomName(map)
    local candidates = {}
    if type(GetSubZoneText) == "function" then candidates[#candidates + 1] = GetSubZoneText end
    if type(GetMinimapZoneText) == "function" then candidates[#candidates + 1] = GetMinimapZoneText end
    for _, getter in ipairs(candidates) do
        local ok, value = pcall(getter)
        value = ok and readableSignal(value) or nil
        if value and string.lower(value) ~= string.lower(map.name or "") then return value end
    end
    return nil
end

function WorldMap:RefreshLocationHint()
    local hint = self.locationHint
    if not hint then return end
    local map = self.map
    if not map or self.bypassUntilClose or not WorldMapFrame or not WorldMapFrame:IsShown()
        or not ((self.host and self.host:IsShown()) or (self.presentationHost and self.presentationHost:IsShown())) then
        hint:Hide()
        return
    end

    local room = currentRoomName(map)
    local hasApproximateMarker = false
    if map.position and HM.Position then
        local ok, u = pcall(HM.Position.GetVisibleMapPosition, HM.Position, map)
        hasApproximateMarker = ok and type(u) == "number"
    end

    local area = room and ("Area: " .. room) or "Area name unavailable"
    local position = hasApproximateMarker
        and "Approximate player marker available"
        or "Position unavailable; use room, floor, and map markers"
    hint.text:SetText((map.name or "Dungeon map") .. "\n" .. area .. "  •  " .. position)
    hint:Show()
end

function WorldMap:RefreshMap()
    if not self.initialized or not WorldMapFrame:IsShown() then
        return
    end

    if self.bypassUntilClose then
        self:HidePresentation()
        self:RefreshLocationHint()
        return
    end

    local effectiveMap = self:GetEffectiveMap()
    if not effectiveMap or not effectiveMap.render then
        if self.host then self.host:Hide() end
        if self.backgroundHost then self.backgroundHost:Hide() end
        if self.presentationHost then self.presentationHost:Hide() end
        if self.interactionLayer then self.interactionLayer:Hide() end
        self.renderer = self.legacyRenderer
        self:RefreshLocationHint()
        return
    end

    if self.backgroundHost then
        self.backgroundHost:ClearAllPoints()
        self.backgroundHost:SetAllPoints(WorldMapFrame.ScrollContainer)
        self.backgroundHost:Show()
    end

    local useAdaptivePresentation = self:LayoutAdaptivePresentation(effectiveMap)

    if useAdaptivePresentation then
        self.host:Hide()
        self.presentationHost:Show()
        if self.interactionLayer then
            self.interactionLayer:ClearAllPoints()
            self.interactionLayer:SetAllPoints(WorldMapFrame.ScrollContainer)
            self.interactionLayer:Show()
        end
        self.renderer = self.customRenderer
        HM.Renderer:Layout(self.customRenderer, effectiveMap)
        HM.Renderer:UpdateMarker(self.customRenderer, effectiveMap)
    else
        if self.presentationHost then self.presentationHost:Hide() end
        if self.interactionLayer then self.interactionLayer:Hide() end
        self.renderer = self.legacyRenderer
        self.host:Show()
        HM.Renderer:Layout(self.legacyRenderer, effectiveMap)
        HM.Renderer:UpdateMarker(self.legacyRenderer, effectiveMap)
        -- Calibrated approaches use the entire legacy canvas for maximum fit.
        -- Shield only the fitted crop, and keep static marker buttons above it.
        -- Uncalibrated legacy maps retain their existing interaction behavior.
        local _, _, _, _, cropped = HM.Renderer:GetPresentationRect(effectiveMap)
        if cropped and self.legacyRenderer:IsShown() and self.interactionLayer then
            self.interactionLayer:ClearAllPoints()
            self.interactionLayer:SetAllPoints(self.legacyRenderer)
            self.interactionLayer:Show()
        end
    end
    self:RefreshLocationHint()
end

function WorldMap:UpdateMarker()
    if self.bypassUntilClose then return end
    local renderer = self.renderer
    if self.initialized and renderer and renderer:IsShown() and self.map then
        HM.Renderer:UpdateMarker(renderer, self:GetEffectiveMap())
    end
end

function WorldMap:RefreshDebugBadge()
    -- The large on-map diagnostic badge is intentionally disabled.
    -- Slash-command and chat diagnostics remain available through Core/Dev.lua.
end
