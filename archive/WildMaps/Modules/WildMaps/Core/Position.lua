local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Position = {}
local Position = HM.Position

local function finite(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function unpackVector2(position)
    if not position then
        return nil
    end

    if position.GetXY then
        return position:GetXY()
    end

    return position.x, position.y
end

function Position:GetMapPosition(uiMapID)
    if not uiMapID or not C_Map or not C_Map.GetPlayerMapPosition then
        return nil
    end

    local ok, position = pcall(C_Map.GetPlayerMapPosition, uiMapID, "player")
    if not ok or not position then
        return nil
    end

    local x, y = unpackVector2(position)
    if not x or not y or (x == 0 and y == 0) then
        return nil
    end

    return x, y
end

function Position:GetWorldPosition(uiMapID, validateCoordinates)
    if not uiMapID or not C_Map or not C_Map.GetPlayerMapPosition or not C_Map.GetWorldPosFromMapPos then
        return nil
    end

    local okPos, mapPosition = pcall(C_Map.GetPlayerMapPosition, uiMapID, "player")
    if not okPos or not mapPosition then
        return nil
    end

    local x, y = unpackVector2(mapPosition)
    if not x or not y or (x == 0 and y == 0) then
        return nil
    end

    if validateCoordinates and (not finite(x) or not finite(y) or x < 0 or x > 1 or y < 0 or y > 1) then
        return nil
    end

    local okWorld, continentID, worldPosition = pcall(C_Map.GetWorldPosFromMapPos, uiMapID, mapPosition)
    if not okWorld or not worldPosition then
        return nil
    end

    local worldX, worldY = unpackVector2(worldPosition)
    if not worldX or not worldY then
        return nil
    end

    return continentID, worldX, worldY
end

function Position:GetUnitWorldPosition()
    if not UnitPosition then
        return nil
    end

    local ok, x, y, z, instanceID = pcall(UnitPosition, "player")
    if not ok or not x or not y then
        return nil
    end

    return instanceID, x, y, z
end

function Position:GetSourcePosition(map)
    local source = map and map.position and map.position.source
    if not source then
        return nil
    end

    return self:GetMapPosition(source.uiMapID)
end

function Position:GetAreaWorldPosition(map)
    local source = map and map.position and map.position.source
    if not source then
        return nil
    end

    local validateCoordinates = source.validatedUnitWorld and map.position.transform.type == "world_minimap_tiles"
    return self:GetWorldPosition(source.uiMapID, validateCoordinates)
end

-- Opt-in validation for outdoor WMOs/mosaics. The established WC/RFD
-- source selection remains unchanged. Never mix coordinates across continents.
function Position:GetValidatedUnitWorldPosition(map)
    local source = map.position.source
    if type(IsInInstance) == "function" then
        local ok, inside = pcall(IsInInstance)
        if not ok or inside then return nil end
    end
    local ok, continent, x, y, z = pcall(self.GetUnitWorldPosition, self)
    if ok and finite(continent) and finite(x) and finite(y) then
        if continent == source.continentID then
            if source.requireAltitude then
                if finite(z) then return continent, x, y, z end
                return nil
            end
            return continent, x, y
        end
        return nil
    end
    -- A tilted WMO needs the live height; the 2D UiMap fallback cannot supply it.
    if source.requireAltitude then return nil end
    -- Wrap the complete conversion, including vector unpacking. Unavailable,
    -- malformed, secret or non-finite positions must not reach the transform.
    ok, continent, x, y = pcall(self.GetAreaWorldPosition, self, map)
    if ok and finite(continent) and continent == source.continentID and finite(x) and finite(y) then
        return continent, x, y
    end
end

-- Opt-in completion of the existing yaw inverse for tilted WMO placements.
-- MODF's XYZ Euler fields map to Y/Z/X axes: Rz(Y-180) * Ry(X) * Rx(Z).
-- Inputs have already had translation, yaw and uniform scale removed.
local function inverseWMOTilt(placement, x, y, z)
    local pitch, roll = math.rad(placement.rotationX or 0), math.rad(placement.rotationZ or 0)
    local cp, sp, cr, sr = math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
    local localX, tiltedZ = cp * x - sp * z, sp * x + cp * z
    return localX, cr * y + sr * tiltedZ
end

local function pointInValidRegions(pixelX, pixelY, regions)
    if not regions then
        return true
    end

    for _, region in ipairs(regions) do
        if pixelX >= region.left and pixelX <= region.right
            and pixelY >= region.top and pixelY <= region.bottom then
            return true
        end
    end

    return false
end

function Position:GetRawMapPixel(map)
    local transform = map and map.position and map.position.transform
    if not transform then
        return nil
    end

    if transform.type == "world_minimap_tiles" then
        -- Outdoor world-minimap mosaics use the native 64x64 ADT/minimap grid.
        -- Prefer UnitPosition because it supplies live continent world coordinates
        -- directly; the UiMap conversion remains a conservative fallback.
        local validated = map.position.source.validatedUnitWorld
        local worldX, worldY
        if validated then
            local _, x, y = self:GetValidatedUnitWorldPosition(map)
            worldX, worldY = x, y
        else
            -- Retain the established acquisition path for existing mosaics.
            local _, x, y = self:GetUnitWorldPosition()
            worldX, worldY = x, y
            if not worldX then
                _, worldX, worldY = self:GetAreaWorldPosition(map)
            end
        end

        if not worldX or not worldY then
            return nil
        end

        local worldOrigin = transform.worldOrigin
        local tileWorldSize = transform.tileWorldSize
        local tilePixelSize = transform.tilePixelSize
        local mosaic = transform.mosaic

        if tileWorldSize == 0 or tilePixelSize <= 0 then
            return nil
        end

        local horizontalWorld = worldX
        local verticalWorld = worldY
        if transform.worldAxisOrder == "yx" then
            horizontalWorld = worldY
            verticalWorld = worldX
        end

        local tileX = (worldOrigin - horizontalWorld) / tileWorldSize
        local tileY = (worldOrigin - verticalWorld) / tileWorldSize

        local pixelX = (tileX - mosaic.originTileX) * tilePixelSize
        local pixelY = (tileY - mosaic.originTileY) * tilePixelSize

        if validated then
            -- Subtracting global tile indices can place an exact JSON boundary
            -- a few trillionths of a pixel outside. Clamp roundoff only.
            local epsilon = 0.000001
            if not finite(pixelX) or not finite(pixelY) or pixelX < -epsilon or pixelY < -epsilon
                or pixelX > mosaic.sourceWidth + epsilon or pixelY > mosaic.sourceHeight + epsilon then
                return nil
            end
            pixelX = math.max(0, math.min(mosaic.sourceWidth, pixelX))
            pixelY = math.max(0, math.min(mosaic.sourceHeight, pixelY))
        end

        if pixelX < 0 or pixelY < 0
            or pixelX > mosaic.sourceWidth or pixelY > mosaic.sourceHeight then
            return nil
        end

        if not pointInValidRegions(pixelX, pixelY, transform.validRegions) then
            return nil
        end

        return pixelX, pixelY, worldX, worldY
    end

    if transform.type ~= "wmo_minimap" then
        return nil
    end

    local worldX, worldY, worldZ
    if map.position.source.validatedUnitWorld then
        local _, x, y, z = self:GetValidatedUnitWorldPosition(map)
        worldX, worldY, worldZ = x, y, z
    else
        local _, x, y = self:GetAreaWorldPosition(map)
        worldX, worldY = x, y
        if not worldX then
            local _, unitX, unitY = self:GetUnitWorldPosition()
            worldX, worldY = unitX, unitY
        end
    end

    if not worldX or not worldY then
        return nil
    end

    local placement = transform.placement
    local minimap = transform.minimap
    local worldHalf = transform.clientWorldHalf

    local originWorldX = worldHalf - placement.positionZ
    local originWorldY = worldHalf - placement.positionX

    local dx = worldX - originWorldX
    local dy = worldY - originWorldY

    -- Generic wow.export WMO placement conversion.
    local angle = math.rad(placement.rotationY - 180)
    local c = math.cos(angle)
    local s = math.sin(angle)

    local scale = placement.scale or 1
    if scale == 0 then
        return nil
    end

    -- Inverse placement scale. WC uses 1.0, so this does not alter its proven
    -- transform; it makes the engine safe for future scaled WMO placements.
    local localX = (c * dx + s * dy) / scale
    local localY = (-s * dx + c * dy) / scale
    if transform.fullPlacementRotation then
        if not finite(worldZ) then return nil end
        localX, localY = inverseWMOTilt(placement, localX, localY, (worldZ - placement.positionY) / scale)
    end

    local minimapWorldX = -localX
    local minimapWorldY = -localY

    local pixelX = (minimap.topLeftX - minimapWorldX) * minimap.pixelsPerUnit
    local pixelY = (minimapWorldY - minimap.topLeftY) * minimap.pixelsPerUnit

    if transform.requireSourceBounds then
        -- JSON bounds can end before the final ceil-rounded canvas pixel.
        local maxX = math.min(minimap.width, (minimap.topLeftX - minimap.bottomRightX) * minimap.pixelsPerUnit)
        local maxY = math.min(minimap.height, (minimap.bottomRightY - minimap.topLeftY) * minimap.pixelsPerUnit)
        if not finite(pixelX) or not finite(pixelY) or pixelX < 0 or pixelY < 0
            or pixelX > maxX or pixelY > maxY then return nil end
    end

    return pixelX, pixelY, worldX, worldY
end

function Position:GetRenderedMapPixel(map)
    local pixelX, pixelY, worldX, worldY = self:GetRawMapPixel(map)
    local render = map and map.render
    if not pixelX or not render then
        return nil
    end

    local degrees = render.displayRotationDegrees or 0
    if degrees == 0 then
        return pixelX, pixelY, worldX, worldY
    end

    local sourceW = render.sourceWidth
    local sourceH = render.sourceHeight
    local destW = render.width
    local destH = render.height

    local angle = math.rad(degrees)
    local c = math.cos(angle)
    local s = math.sin(angle)

    local dx = pixelX - sourceW / 2
    local dy = pixelY - sourceH / 2

    -- Screen-space rotation: Y grows downward.
    local displayX = c * dx + s * dy + destW / 2
    local displayY = -s * dx + c * dy + destH / 2

    return displayX, displayY, worldX, worldY
end

-- Reuse the proven source transform and orientation, then apply the same
-- map-space coverage gate as the renderer. No renderer/frame is needed here.
function Position:GetVisibleMapPosition(map, fullArtwork)
    local x, y, worldX, worldY = self:GetRenderedMapPixel(map)
    if x == nil then return nil end
    local u, v = HM.MapCoordinates:RenderedToVisibleFraction(map, x, y, fullArtwork)
    if u == nil then return nil end
    return u, v, worldX, worldY
end

function Position:GetPlayerFacing(map)
    if not GetPlayerFacing then
        return nil
    end

    local ok, facing = pcall(GetPlayerFacing)
    if not ok then
        return nil
    end

    local transform = map and map.position and map.position.transform
    if transform and transform.fullPlacementRotation then
        if not finite(facing) then return nil end
        -- Project the horizontal facing vector through the same placement
        -- inverse as position. Tilt changes its direction slightly, so a
        -- constant yaw offset alone would not describe the displayed heading.
        local angle = facing - math.rad(transform.placement.rotationY - 180)
        local x, y = inverseWMOTilt(transform.placement, math.cos(angle), math.sin(angle), 0)
        local display = (map.render.displayRotationDegrees or 0) - 90
        if map.id == "maraudon_approach" then display = display + 180 end
        return (math.atan2(y, x) + math.rad(display)) % (2 * math.pi)
    end

    local offset = map and map.position and map.position.facingOffsetDegrees
    if offset then
        if not finite(facing) then return nil end
        return (facing + math.rad(offset)) % (2 * math.pi)
    end
    return facing
end
