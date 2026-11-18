local _, addonNS = ...
local HM = addonNS.WildMaps

HM.MapMarkers = HM.MapMarkers or {}
local MapMarkers = HM.MapMarkers

MapMarkers.buttons = MapMarkers.buttons or {}
MapMarkers.initialized = false

local BOSS_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local ENTRANCE_TEXTURE = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\entrance_exit.tga"

-- Deliberately compact. These are navigational annotations, not combat raid markers.
local BOSS_ICON_SIZE = 16
local ENTRANCE_ICON_SIZE = 18
local APPROACH_ENTRANCE_SIZE_MULTIPLIER = 2

local function sourcePointToRenderedPixel(map, marker)
    local position = marker and marker.position
    local render = map and map.render
    if not position or not render then
        return nil
    end

    local rawX, rawY
    local sourceW = tonumber(render.sourceWidth)
    local sourceH = tonumber(render.sourceHeight)

    if position.space == "source_pixels" then
        -- Stable source-image coordinates. This keeps markers attached to the
        -- original map artwork regardless of World Map display scaling.
        rawX = tonumber(position.x)
        rawY = tonumber(position.y)
        sourceW = sourceW or tonumber(render.width)
        sourceH = sourceH or tonumber(render.height)
        if not rawX or not rawY or not sourceW or not sourceH then
            return nil
        end
    elseif position.space == "instance_map" then
        local minimap = map and map.source and map.source.minimap
        if not minimap then
            return nil
        end

        local x = tonumber(position.x)
        local y = tonumber(position.y)
        local ppu = tonumber(minimap.pixelsPerUnit)
        if not x or not y or not ppu or ppu == 0 then
            return nil
        end

        -- RFC's instance coordinates and Blizzard WMO-minimap local coordinates
        -- share the same XY space. Convert that source coordinate to the original
        -- minimap bitmap before applying display rotation and post-rotation crop.
        rawX = (minimap.topLeftX - x) * ppu
        rawY = (y - minimap.topLeftY) * ppu

        sourceW = sourceW or tonumber(minimap.width)
        sourceH = sourceH or tonumber(minimap.height)
        if not sourceW or not sourceH then
            return nil
        end
    else
        return nil
    end

    return HM.MapCoordinates:SourceToRendered(map, rawX, rawY)
end

local function configureButton(button, marker, map)
    local markerType = marker.type or "boss"
    local defaultSize = markerType == "entrance_exit" and ENTRANCE_ICON_SIZE or BOSS_ICON_SIZE
    local size = tonumber(marker.size) or defaultSize
    -- Multiply the resolved size so both defaults and explicit map sizes grow
    -- around their existing CENTER anchor. Interior icons and chevrons do not.
    if markerType == "entrance_exit" and map.detection and map.detection.allowInInstance == false
        and map.render.tileNaming ~= "blizzard_sequential" then
        size = size * APPROACH_ENTRANCE_SIZE_MULTIPLIER
    end
    button:SetSize(size, size)

    if marker.texture then
        button.icon:SetTexture(marker.texture)
        button.icon:SetTexCoord(0, 1, 0, 1)
    elseif markerType == "entrance_exit" then
        button.icon:SetTexture(ENTRANCE_TEXTURE)
        button.icon:SetTexCoord(0, 1, 0, 1)
    else
        button.icon:SetTexture(BOSS_TEXTURE)
        button.icon:SetTexCoord(0, 1, 0, 1)
    end

    button._hiddenMapsTooltip = marker.tooltip or marker.name or ""
    if button.label then
        button.label:SetText(marker.name or marker.tooltip or "")
    end
end

-- A calibration candidate is an ephemeral overlay only. Registered map data
-- and SavedVariables never become production marker overrides in this build.
function MapMarkers:SetEntrancePreview(map, marker)
    self:SetEntrancePreviews(map, marker and { marker } or nil)
end

function MapMarkers:SetEntrancePreviews(map, markers)
    self.entrancePreview = markers and #markers > 0 and { map = map, markers = markers } or nil
    self:Refresh()
end

function MapMarkers:GetVisibleMarkers(map)
    local preview = self.entrancePreview
    if not preview or preview.map ~= map then return map and map.markers end
    local markers = {}
    for _, marker in ipairs(map.markers or {}) do
        if marker.type ~= "entrance_exit" then markers[#markers + 1] = marker end
    end
    for _, marker in ipairs(preview.markers) do markers[#markers + 1] = marker end
    return markers
end

function MapMarkers:EnsureButton(index, parent)
    local button = self.buttons[index]
    if not button then
        button = CreateFrame("Button", nil, parent)
        button:EnableMouse(true)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnMouseUp", function(frame, mouseButton)
            if frame:IsMouseOver() then HM.WorldMap:ForwardParentNavigation(mouseButton) end
        end)

        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        button.icon = icon

        -- Optional always-visible labels supplement the working hover tooltips.
        -- Maps control label visibility; RFC uses labels and approaches hide them.
        -- Keep text outside the button bounds without changing icon dimensions
        -- or marker coordinates.
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("CENTER")
        label:SetTextColor(1, 0.82, 0, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        button.label = label

        button:SetScript("OnEnter", function(self)
            local text = self._hiddenMapsTooltip
            if not text or text == "" or not GameTooltip then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(text)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)

        self.buttons[index] = button
    elseif button:GetParent() ~= parent then
        button:SetParent(parent)
    end

    -- Keep marker buttons above the WildMaps artwork/presentation frame so
    -- they win mouse hit-testing as well as drawing order.
    local presentationLevel = HM.WorldMap and HM.WorldMap.presentationHost
        and HM.WorldMap.presentationHost:GetFrameLevel() or 0
    button:SetFrameLevel(math.max(parent:GetFrameLevel() or 0, presentationLevel) + 100)
    return button
end

function MapMarkers:HideAll()
    for _, button in ipairs(self.buttons) do
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == button then
            GameTooltip:Hide()
        end
        button:Hide()
    end
end

local LABEL_GAP = 2
local LABEL_MARGIN = 2

local LABEL_CANDIDATES = {
    { id = "below", anchor = "TOP", relative = "BOTTOM", dx = 0, dy = -LABEL_GAP, mode = "below" },
    { id = "above", anchor = "BOTTOM", relative = "TOP", dx = 0, dy = LABEL_GAP, mode = "above" },
    { id = "right", anchor = "LEFT", relative = "RIGHT", dx = LABEL_GAP, dy = 0, mode = "right" },
    { id = "left", anchor = "RIGHT", relative = "LEFT", dx = -LABEL_GAP, dy = 0, mode = "left" },
    { id = "lower_right", anchor = "TOPLEFT", relative = "BOTTOMRIGHT", dx = LABEL_GAP, dy = -LABEL_GAP, mode = "lower_right" },
    { id = "lower_left", anchor = "TOPRIGHT", relative = "BOTTOMLEFT", dx = -LABEL_GAP, dy = -LABEL_GAP, mode = "lower_left" },
    { id = "upper_right", anchor = "BOTTOMLEFT", relative = "TOPRIGHT", dx = LABEL_GAP, dy = LABEL_GAP, mode = "upper_right" },
    { id = "upper_left", anchor = "BOTTOMRIGHT", relative = "TOPLEFT", dx = -LABEL_GAP, dy = LABEL_GAP, mode = "upper_left" },
}

local function rectanglesOverlap(a, b)
    return a.left < b.right and a.right > b.left and a.top < b.bottom and a.bottom > b.top
end

local function candidateRect(mode, x, y, iconW, iconH, labelW, labelH)
    local halfW, halfH = iconW / 2, iconH / 2
    local left, top
    if mode == "below" then
        left = x - labelW / 2
        top = y + halfH + LABEL_GAP
    elseif mode == "above" then
        left = x - labelW / 2
        top = y - halfH - LABEL_GAP - labelH
    elseif mode == "right" then
        left = x + halfW + LABEL_GAP
        top = y - labelH / 2
    elseif mode == "left" then
        left = x - halfW - LABEL_GAP - labelW
        top = y - labelH / 2
    elseif mode == "lower_right" then
        left = x + halfW + LABEL_GAP
        top = y + halfH + LABEL_GAP
    elseif mode == "lower_left" then
        left = x - halfW - LABEL_GAP - labelW
        top = y + halfH + LABEL_GAP
    elseif mode == "upper_right" then
        left = x + halfW + LABEL_GAP
        top = y - halfH - LABEL_GAP - labelH
    else -- upper_left
        left = x - halfW - LABEL_GAP - labelW
        top = y - halfH - LABEL_GAP - labelH
    end
    return { left = left, top = top, right = left + labelW, bottom = top + labelH }
end

local function rectFitsMap(rect, mapW, mapH)
    return rect.left >= LABEL_MARGIN and rect.top >= LABEL_MARGIN
        and rect.right <= mapW - LABEL_MARGIN and rect.bottom <= mapH - LABEL_MARGIN
end

local function rectIsFree(rect, occupied)
    for _, other in ipairs(occupied) do
        if rectanglesOverlap(rect, other) then
            return false
        end
    end
    return true
end

local function addIconRect(occupied, x, y, w, h)
    occupied[#occupied + 1] = {
        left = x - w / 2,
        top = y - h / 2,
        right = x + w / 2,
        bottom = y + h / 2,
    }
end

local function placeLabel(button, marker, x, y, mapW, mapH, occupied)
    local label = button.label
    if not label then
        return
    end

    label:ClearAllPoints()
    if marker.showLabel == false then
        label:Hide()
        return
    end
    local text = marker.name or marker.tooltip or ""
    if text == "" then
        label:Hide()
        return
    end

    label:SetText(text)
    label:Show()
    local labelW = math.max(1, label:GetStringWidth() or 1)
    local labelH = math.max(1, label:GetStringHeight() or 1)
    local iconW, iconH = button:GetWidth(), button:GetHeight()

    local preferred = marker.labelPosition
    local ordered = {}
    if preferred then
        for _, candidate in ipairs(LABEL_CANDIDATES) do
            if candidate.id == preferred then
                ordered[#ordered + 1] = candidate
                break
            end
        end
    end
    for _, candidate in ipairs(LABEL_CANDIDATES) do
        if not preferred or candidate.id ~= preferred then
            ordered[#ordered + 1] = candidate
        end
    end

    local chosen, chosenRect
    for _, candidate in ipairs(ordered) do
        local rect = candidateRect(candidate.mode, x, y, iconW, iconH, labelW, labelH)
        if rectFitsMap(rect, mapW, mapH) and rectIsFree(rect, occupied) then
            chosen, chosenRect = candidate, rect
            break
        end
    end

    -- Extremely crowded maps may have no collision-free candidate. Prefer a
    -- position that remains inside the artwork rather than allowing text to
    -- spill outside the map; manual labelPosition remains available per marker.
    if not chosen then
        for _, candidate in ipairs(ordered) do
            local rect = candidateRect(candidate.mode, x, y, iconW, iconH, labelW, labelH)
            if rectFitsMap(rect, mapW, mapH) then
                chosen, chosenRect = candidate, rect
                break
            end
        end
    end
    chosen = chosen or ordered[1]
    chosenRect = chosenRect or candidateRect(chosen.mode, x, y, iconW, iconH, labelW, labelH)

    label:SetPoint(chosen.anchor, button, chosen.relative, chosen.dx, chosen.dy)
    occupied[#occupied + 1] = chosenRect
end

function MapMarkers:Refresh()
    if not HM.WorldMap or not HM.WorldMap.initialized or not WorldMapFrame or not WorldMapFrame:IsShown() then
        self:HideAll()
        return
    end

    local map = HM.WorldMap:GetEffectiveMap()
    local renderer = HM.WorldMap.renderer
    local markers = self:GetVisibleMarkers(map)
    if not map or not renderer or not renderer:IsShown() or type(markers) ~= "table" or #markers == 0 then
        self:HideAll()
        return
    end

    local rendererW, rendererH = renderer:GetSize()
    if not rendererW or not rendererH or rendererW <= 0 or rendererH <= 0 then
        self:HideAll()
        return
    end

    local used = 0
    local placements = {}
    local occupied = {}

    -- First place every geographically meaningful icon and reserve its area.
    -- Labels are deliberately *not* allowed to move the actual marker.
    for _, marker in ipairs(markers) do
        local pixelX, pixelY, mapW, mapH = sourcePointToRenderedPixel(map, marker)
        local x, y = HM.Renderer:RenderedPixelToFrame(renderer, map, pixelX, pixelY)
        if x ~= nil and y ~= nil and mapW and mapH then
            used = used + 1
            -- Parent markers to the layer that is actually active for the
            -- current renderer. The shared interaction layer also shields a
            -- fitted approach crop, but stays hidden for uncropped legacy maps.
            -- Never parent a marker to an inactive shield.
            local markerParent
            if HM.WorldMap.interactionLayer
                and HM.WorldMap.interactionLayer:IsShown() then
                markerParent = HM.WorldMap.interactionLayer
            else
                markerParent = WorldMapFrame.ScrollContainer
            end

            local button = self:EnsureButton(used, markerParent)
            configureButton(button, marker, map)

            button:ClearAllPoints()
            button:SetPoint("CENTER", renderer, "TOPLEFT", x, -y)
            button:Show()

            placements[#placements + 1] = { button = button, marker = marker, x = x, y = y }
            addIconRect(occupied, x, y, button:GetWidth(), button:GetHeight())
        end
    end

    -- Then fit labels around the fixed icons, avoiding both icons and labels
    -- already committed earlier in the pass.
    for _, placement in ipairs(placements) do
        placeLabel(
            placement.button,
            placement.marker,
            placement.x,
            placement.y,
            rendererW,
            rendererH,
            occupied
        )
    end

    for i = used + 1, #self.buttons do
        self.buttons[i]:Hide()
    end
end

function MapMarkers:Initialize()
    if self.initialized then
        return
    end

    if hooksecurefunc and HM.WorldMap and HM.WorldMap.RefreshMap then
        hooksecurefunc(HM.WorldMap, "RefreshMap", function()
            MapMarkers:Refresh()
        end)
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnHide", function()
            MapMarkers:HideAll()
        end)
    end

    self.initialized = true
end

MapMarkers:Initialize()
