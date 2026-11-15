local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Renderer = {}
local Renderer = HM.Renderer

-- UI units per side, after the permanent crop. Calibrated approach maps share
-- this safe area; uncropped maps (including Dire Maul) keep their existing fit.
Renderer.approachPadding = 24
local PLAYER_MARKER_SIZE = 24

-- Only the approach chevron's dimensions follow the artwork's fitted scale.
-- Keep a normal-view viewport reference, not a map-specific position or scale.
-- This also lets a different approach open at the correct size while maximized.
local function playerMarkerSize(frame, map, pw, ph, width, height, cropped)
    local world = WorldMapFrame
    if not map.position or not map.detection or map.detection.allowInInstance ~= false
        or map.frameLayout or map.render.tileNaming == "blizzard_sequential"
        or not world or type(world.IsMaximized) ~= "function" then
        return PLAYER_MARKER_SIZE
    end

    if not world:IsMaximized() then
        frame.playerMarkerNormalWidth, frame.playerMarkerNormalHeight = pw, ph
        return PLAYER_MARKER_SIZE
    end

    local normalW, normalH = frame.playerMarkerNormalWidth, frame.playerMarkerNormalHeight
    if not normalW or not normalH then
        -- First open may already be maximized. Forever exposes its minimized
        -- outer-frame dimensions; subtract the live outer-to-viewport insets
        -- (title/border/side panel), which use the same anchors in both modes.
        -- Do not use the artwork's 1002x668 storage size as a UI-size reference.
        local minimizedW, minimizedH = tonumber(world.minimizedWidth), tonumber(world.minimizedHeight)
        if not minimizedW or not minimizedH then return PLAYER_MARKER_SIZE end
        normalW = minimizedW - (world:GetWidth() - pw)
        normalH = minimizedH - (world:GetHeight() - ph)
    end

    local padding = cropped and 2 * Renderer.approachPadding or 0
    if normalW ~= normalW or normalH ~= normalH or normalW >= math.huge or normalH >= math.huge
        or normalW <= padding or normalH <= padding then
        return PLAYER_MARKER_SIZE
    end
    frame.playerMarkerNormalWidth, frame.playerMarkerNormalHeight = normalW, normalH

    local normalScale = math.min((normalW - padding) / width, (normalH - padding) / height)
    local currentScale = math.min(frame:GetWidth() / width, frame:GetHeight() / height)
    return PLAYER_MARKER_SIZE * currentScale / normalScale
end

-- Presentation offsets are measured in the existing, already-oriented artwork
-- pixels. Never change render/source dimensions or the positioning transforms.
-- Calibration temporarily displays the complete artwork without editing data.
function Renderer:GetPresentationRect(map)
    return HM.MapCoordinates:GetPresentationRect(map, self.calibrationMap == map)
end

-- Shared final projection for player positions and static POIs. The renderer
-- itself supplies the centered origin; all offsets use the same fitted bounds.
function Renderer:RenderedPixelToFrame(frame, map, x, y)
    local u, v = HM.MapCoordinates:RenderedToVisibleFraction(map, x, y, self.calibrationMap == map)
    if u == nil then return nil end
    return u * frame:GetWidth(), v * frame:GetHeight()
end

-- Clip the retained source silhouette against the selected rectangle. This
-- removes cropped-away edges and adds edges along the new crop boundaries.
local function clipPolygon(points, axis, boundary, keepGreater)
    local result = {}
    if #points == 0 then return result end
    local previous = points[#points]
    local function inside(p)
        if keepGreater then return p[axis] >= boundary end
        return p[axis] <= boundary
    end
    for _, current in ipairs(points) do
        local currentInside, previousInside = inside(current), inside(previous)
        if currentInside ~= previousInside then
            local fraction = (boundary - previous[axis]) / (current[axis] - previous[axis])
            local intersection = {
                x = previous.x + (current.x - previous.x) * fraction,
                y = previous.y + (current.y - previous.y) * fraction,
            }
            intersection[axis] = boundary
            result[#result + 1] = intersection
        end
        if currentInside then result[#result + 1] = current end
        previous = current
    end
    return result
end

-- A restrained universal edge treatment keeps WildMaps artwork visually
-- separate from the full-canvas decorative background without baking borders
-- into individual map assets. The treatment is entirely inset: it never fills
-- transparent map regions and does not change renderer geometry or positioning.
local EDGE_STYLES = {
    { thickness = 8, alpha = 0.08, r = 0, g = 0, b = 0 },
    { thickness = 4, alpha = 0.14, r = 0, g = 0, b = 0 },
    { thickness = 1.5, alpha = 0.78, r = 0.10, g = 0.07, b = 0.035 },
}

local function createInsetEdgeBand(frame, thickness, alpha, r, g, b)
    local band = {}

    local top = frame:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(r, g, b, alpha)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(thickness)
    band.top = top

    local bottom = frame:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(r, g, b, alpha)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(thickness)
    band.bottom = bottom

    local left = frame:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(r, g, b, alpha)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(thickness)
    band.left = left

    local right = frame:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(r, g, b, alpha)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(thickness)
    band.right = right

    return band
end

local function setBandShown(band, shown)
    for _, texture in pairs(band) do
        if shown then
            texture:Show()
        else
            texture:Hide()
        end
    end
end

local function setRectEdgeTreatmentShown(frame, shown)
    if not frame.edgeTreatment then
        return
    end

    setBandShown(frame.edgeTreatment.soft, shown)
    setBandShown(frame.edgeTreatment.mid, shown)
    setBandShown(frame.edgeTreatment.border, shown)
end

local function hideSilhouetteEdgeTreatment(frame)
    if not frame.silhouetteEdgeTextures then
        return
    end

    for _, texture in ipairs(frame.silhouetteEdgeTextures) do
        texture:Hide()
    end
end

local function ensureSilhouetteEdgeTextures(frame, count)
    frame.silhouetteEdgeTextures = frame.silhouetteEdgeTextures or {}

    while #frame.silhouetteEdgeTextures < count do
        local texture = frame:CreateTexture(nil, "OVERLAY")
        frame.silhouetteEdgeTextures[#frame.silhouetteEdgeTextures + 1] = texture
    end
end

local function layoutSilhouetteEdgeTreatment(frame, map, drawW, drawH)
    local data = map.render
    -- Supplied complete artwork already has its own border/attribution.
    if data and data.hideEdgeTreatment == true then
        hideSilhouetteEdgeTreatment(frame)
        setRectEdgeTreatmentShown(frame, false)
        return
    end
    local silhouette = data and data.edgeSilhouette
    local points = silhouette and silhouette.points

    if not silhouette or type(points) ~= "table" or #points < 3 then
        hideSilhouetteEdgeTreatment(frame)
        setRectEdgeTreatmentShown(frame, true)
        return
    end

    local coordinateW = tonumber(silhouette.width) or data.width
    local coordinateH = tonumber(silhouette.height) or data.height
    if not coordinateW or not coordinateH or coordinateW <= 0 or coordinateH <= 0 then
        hideSilhouetteEdgeTreatment(frame)
        setRectEdgeTreatmentShown(frame, true)
        return
    end

    local left, top, width, height, cropped = Renderer:GetPresentationRect(map)
    if cropped then
        local normalized = {}
        for _, point in ipairs(points) do
            normalized[#normalized + 1] = { x = point.x / coordinateW * data.width,
                y = point.y / coordinateH * data.height }
        end
        points = clipPolygon(normalized, "x", left, true)
        points = clipPolygon(points, "x", left + width, false)
        points = clipPolygon(points, "y", top, true)
        points = clipPolygon(points, "y", top + height, false)
        local rectangle = #points == 4
        for _, point in ipairs(points) do
            if (point.x ~= left and point.x ~= left + width)
                or (point.y ~= top and point.y ~= top + height) then rectangle = false end
        end
        if rectangle then
            -- RFD's locked crop ends above the missing lower-left quadrant.
            -- Keep the original silhouette data for full-source calibration.
            hideSilhouetteEdgeTreatment(frame)
            setRectEdgeTreatmentShown(frame, true)
            return
        end
        coordinateW, coordinateH = width, height
    end

    -- Explicit silhouette metadata replaces only the universal rectangular
    -- treatment. Map art, transparency, and player geometry are unchanged.
    setRectEdgeTreatmentShown(frame, false)

    local segmentCount = #points
    local textureCount = #EDGE_STYLES * segmentCount
    ensureSilhouetteEdgeTextures(frame, textureCount)

    local scaleX = drawW / coordinateW
    local scaleY = drawH / coordinateH
    local textureIndex = 1

    -- Points are expected clockwise in screen coordinates (Y grows downward),
    -- so map content lies on the right side of every directed edge.
    for _, style in ipairs(EDGE_STYLES) do
        local thickness = style.thickness

        for i = 1, segmentCount do
            local p1 = points[i]
            local p2 = points[(i % segmentCount) + 1]
            local x1 = ((tonumber(p1.x) or 0) - left) * scaleX
            local y1 = ((tonumber(p1.y) or 0) - top) * scaleY
            local x2 = ((tonumber(p2.x) or 0) - left) * scaleX
            local y2 = ((tonumber(p2.y) or 0) - top) * scaleY

            local texture = frame.silhouetteEdgeTextures[textureIndex]
            textureIndex = textureIndex + 1
            texture:ClearAllPoints()
            texture:SetColorTexture(style.r, style.g, style.b, style.alpha)

            if math.abs(y2 - y1) < 0.01 and math.abs(x2 - x1) >= 0.01 then
                -- Horizontal edge. Eastward => content below; westward => above.
                local left = math.min(x1, x2)
                local width = math.abs(x2 - x1)
                local top = y1
                if x2 < x1 then
                    top = y1 - thickness
                end

                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
                texture:SetSize(width, thickness)
                texture:Show()
            elseif math.abs(x2 - x1) < 0.01 and math.abs(y2 - y1) >= 0.01 then
                -- Vertical edge. Downward => content left; upward => right.
                local top = math.min(y1, y2)
                local height = math.abs(y2 - y1)
                local left = x1
                if y2 > y1 then
                    left = x1 - thickness
                end

                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
                texture:SetSize(thickness, height)
                texture:Show()
            else
                -- Current metadata contract is intentionally conservative:
                -- only axis-aligned explicit silhouettes are supported.
                texture:Hide()
            end
        end
    end

    for i = textureIndex, #frame.silhouetteEdgeTextures do
        frame.silhouetteEdgeTextures[i]:Hide()
    end
end

function Renderer:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:Hide()
    frame.tiles = {}

    -- Renderer-local backing must stay transparent. A universal WildMaps
    -- background is owned by Core/WorldMap.lua and fills the complete live
    -- World Map canvas. Keeping this layer transparent lets irregular maps
    -- (for example the L-shaped RFD approach mosaic) reveal that artwork
    -- through unused/transparent source regions instead of showing black.
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0)
    frame.background = background

    -- Three nested bands produce a soft inward shade and a crisp final edge.
    -- Because these are edge-only OVERLAY textures, transparent source regions
    -- (such as the RFD approach notch) continue to reveal the universal artwork.
    frame.edgeTreatment = {
        soft = createInsetEdgeBand(frame, 8, 0.08, 0, 0, 0),
        mid = createInsetEdgeBand(frame, 4, 0.14, 0, 0, 0),
        border = createInsetEdgeBand(frame, 1.5, 0.78, 0.10, 0.07, 0.035),
    }

    local marker = CreateFrame("Frame", nil, frame)
    marker:SetSize(PLAYER_MARKER_SIZE, PLAYER_MARKER_SIZE)
    marker:SetFrameLevel(frame:GetFrameLevel() + 20)

    local arrow = marker:CreateTexture(nil, "OVERLAY")
    arrow:SetAllPoints()
    arrow:SetTexture("Interface\\MINIMAP\\MiniMap-DeadArrow")
    marker.arrow = arrow

    frame.marker = marker
    return frame
end

function Renderer:Clear(frame)
    for _, tile in ipairs(frame.tiles) do
        tile:Hide()
        tile:SetTexture(nil)
    end
    frame.marker:Hide()
    frame:Hide()
end

function Renderer:EnsureTiles(frame, count)
    while #frame.tiles < count do
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetTexCoord(0, 1, 0, 1)
        frame.tiles[#frame.tiles + 1] = texture
    end
end

function Renderer:Layout(frame, map)
    local data = map and map.render
    if not data or data.type ~= "tile_grid" then
        self:Clear(frame)
        return
    end

    local parent = frame:GetParent()
    local pw, ph = parent:GetWidth(), parent:GetHeight()
    if not pw or not ph or pw <= 0 or ph <= 0 then
        if data.presentationCrop or map.artworkCredit then self:Clear(frame) end
        return
    end

    -- Only credited maps reserve footer space; existing map geometry is unchanged.
    local creditHeight = HM.MapCredits and HM.MapCredits:Reserve(frame, map, pw) or 0
    ph = ph - creditHeight
    if creditHeight > 0 and ph <= 0 then self:Clear(frame); return end

    local cropLeft, cropTop, cropWidth, cropHeight, cropped = self:GetPresentationRect(map)
    local drawW, drawH
    if data.tileNaming == "blizzard_sequential" then
        -- Blizzard's dungeon artwork is authored for the World Map canvas.
        -- The live Classic ScrollContainer is only approximately 4:3 and can
        -- differ slightly between normal/maximized layouts. Letterboxing these
        -- 1024x768 assets leaves visible black bands, so static Blizzard maps
        -- deliberately fill the WildMaps viewport exactly. The small aspect
        -- adjustment is preferable to exposing the covered Blizzard map below.
        drawW, drawH = pw, ph
    elseif cropped then
        -- Fit the entire crop inside symmetric padding. Centering below stays
        -- unchanged, so all existing overlays inherit the same inset display.
        local usableW = pw - 2 * self.approachPadding
        local usableH = ph - 2 * self.approachPadding
        if usableW <= 0 or usableH <= 0 then
            self:Clear(frame)
            return
        end
        local scale = math.min(usableW / cropWidth, usableH / cropHeight)
        drawW, drawH = cropWidth * scale, cropHeight * scale
    else
        -- Keep the existing fit for maps without a presentation crop.
        local aspect = data.width / data.height
        drawW, drawH = pw, pw / aspect
        if drawH > ph then
            drawH = ph
            drawW = ph * aspect
        end
    end

    frame:ClearAllPoints()
    frame:SetSize(drawW, drawH)
    frame:SetPoint("CENTER", parent, "CENTER", 0, creditHeight / 2)

    local markerSize = playerMarkerSize(frame, map, pw, ph, cropWidth, cropHeight, cropped)
    frame.marker:SetSize(markerSize, markerSize)

    layoutSilhouetteEdgeTreatment(frame, map, drawW, drawH)

    local count = data.columns * data.rows
    self:EnsureTiles(frame, count)

    -- Blizzard's classic WorldMap detail canvas is 1002x668 even though its
    -- artwork is physically stored in a 4x3 grid of 256px textures (1024x768
    -- addressable pixels). The unused right/bottom portions of that storage
    -- grid are transparent/black padding, not part of the map artwork. Crop
    -- them at render time before scaling so static dungeon art fills the live
    -- WildMaps canvas without a black band. Stitched/WMO crops remain in
    -- their original declared artwork coordinate system.
    local visibleW = cropWidth
    local visibleH = cropHeight
    if data.tileNaming == "blizzard_sequential" then
        visibleW = tonumber(data.visibleWidth) or 1002
        visibleH = tonumber(data.visibleHeight) or 668
    end

    local sx = drawW / visibleW
    local sy = drawH / visibleH
    local index = 1

    for row = 1, data.rows do
        for col = 1, data.columns do
            local tile = frame.tiles[index]
            index = index + 1

            local sourceX = (col - 1) * data.tileSize
            local sourceY = (row - 1) * data.tileSize
            local left = math.max(sourceX, cropLeft)
            local top = math.max(sourceY, cropTop)
            local sourceW = math.min(sourceX + data.tileSize, cropLeft + visibleW) - left
            local sourceH = math.min(sourceY + data.tileSize, cropTop + visibleH) - top

            tile:ClearAllPoints()
            if sourceW > 0 and sourceH > 0 then
                tile:SetSize(sourceW * sx, sourceH * sy)
                tile:SetPoint("TOPLEFT", frame, "TOPLEFT", (left - cropLeft) * sx, -(top - cropTop) * sy)
            end
            if data.tileNaming == "blizzard_sequential" then
                -- Blizzard's classic dungeon WorldMap artwork is stored as a
                -- 4x3 grid numbered sequentially from 1 to 12. SetTexture
                -- accepts the in-client path without an explicit extension.
                tile:SetTexture(data.texturePrefix .. (index - 1))
            else
                -- Existing WildMaps stitched-map path. Approach maps and
                -- archived WMO maps continue using row/column TGA tiles.
                tile:SetTexture(data.texturePrefix .. row .. "_" .. col .. ".tga")
            end
            if sourceW > 0 and sourceH > 0 then
                tile:SetTexCoord((left - sourceX) / data.tileSize, (left - sourceX + sourceW) / data.tileSize,
                    (top - sourceY) / data.tileSize, (top - sourceY + sourceH) / data.tileSize)
                if map.id == "maraudon_approach" then
                    -- Turn only the already-cropped artwork; source/position math stays unchanged.
                    tile:ClearAllPoints()
                    tile:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(left - cropLeft) * sx, (top - cropTop) * sy)
                    tile:SetTexCoord((left - sourceX + sourceW) / data.tileSize, (left - sourceX) / data.tileSize,
                        (top - sourceY + sourceH) / data.tileSize, (top - sourceY) / data.tileSize)
                end
                tile:Show()
            else
                tile:Hide()
            end
        end
    end

    for i = count + 1, #frame.tiles do
        frame.tiles[i]:Hide()
    end

    frame:Show()
end

function Renderer:UpdateMarker(frame, map)
    if not frame:IsShown() or not map or not map.render then
        frame.marker:Hide()
        return
    end

    local u, v
    local isLivePosition = false
    if map.position then
        u, v = HM.Position:GetVisibleMapPosition(map, self.calibrationMap == map)
        isLivePosition = u ~= nil
    end
    if u == nil and HM.WorldMap and HM.WorldMap.GetManualStartPosition then
        u, v = HM.WorldMap:GetManualStartPosition(map)
    end
    if u == nil and map.entryPosition then
        u, v = tonumber(map.entryPosition.u), tonumber(map.entryPosition.v)
    end
    if u == nil or v == nil then
        frame.marker:Hide()
        return
    end

    local x, y = u * frame:GetWidth(), v * frame:GetHeight()
    frame.marker:ClearAllPoints()
    frame.marker:SetPoint("CENTER", frame, "TOPLEFT", x, -y)

    -- Indoor saved points are explicitly amber and fixed at the player's
    -- approximate entry location; only mapped outdoor points use a live arrow.
    if frame.marker.arrow then
        if isLivePosition then
            frame.marker.arrow:SetVertexColor(1, 1, 1, 1)
            local facing = HM.Position:GetPlayerFacing(map)
            frame.marker.arrow:SetRotation(facing or 0)
        else
            frame.marker.arrow:SetVertexColor(1, 0.62, 0.12, 1)
            frame.marker.arrow:SetRotation(0)
        end
    end

    frame.marker:Show()
end
