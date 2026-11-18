local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry = {
    mapsByID = {},
    maps = {},
    aliasIndex = {},
    instanceIndex = {},
    errors = {},
}

local Registry = HM.Registry

local function fail(message)
    error(message, 0)
end

local function expectTable(value, path)
    if type(value) ~= "table" then
        fail(path .. " must be a table")
    end
end

local function expectString(value, path)
    if type(value) ~= "string" or value == "" then
        fail(path .. " must be a non-empty string")
    end
end

local function expectNumber(value, path)
    if type(value) ~= "number" then
        fail(path .. " must be a number")
    end
end

local function normalize(text)
    if not text or text == "" then
        return ""
    end

    text = string.lower(text)
    text = string.gsub(text, "[%s%p]", "")
    return text
end

Registry.Normalize = normalize

local function validateMap(map)
    expectTable(map, "map")

    if map.schemaVersion ~= 1 then
        fail("schemaVersion must be 1")
    end

    expectString(map.id, "id")
    if not string.match(map.id, "^[a-z0-9_]+$") then
        fail("id may contain only lowercase letters, numbers, and underscores")
    end

    expectString(map.name, "name")

    expectTable(map.detection, "detection")
    if map.detection.allowInInstance ~= nil and type(map.detection.allowInInstance) ~= "boolean" then
        fail("detection.allowInInstance must be boolean when supplied")
    end

    local hasAliasDetection = type(map.detection.zoneAliases) == "table" and #map.detection.zoneAliases > 0
    local hasInstanceDetection = type(map.detection.instanceIDs) == "table" and #map.detection.instanceIDs > 0
    local hasInstanceNameDetection = type(map.detection.instanceNames) == "table" and #map.detection.instanceNames > 0

    if not hasAliasDetection and not hasInstanceDetection and not hasInstanceNameDetection then
        fail("detection must provide zoneAliases, instanceIDs and/or instanceNames")
    end

    -- Opt-in name detection is only for actual party instances, never zone aliases.
    if hasInstanceNameDetection then
        if map.detection.allowInInstance ~= true then
            fail("instanceNames require detection.allowInInstance=true")
        end
        for i, name in ipairs(map.detection.instanceNames) do
            expectString(name, "detection.instanceNames[" .. i .. "]")
        end
    end

    if hasAliasDetection then
        for i, alias in ipairs(map.detection.zoneAliases) do
            expectString(alias, "detection.zoneAliases[" .. i .. "]")
        end
    end

    if hasInstanceDetection then
        for i, instanceID in ipairs(map.detection.instanceIDs) do
            expectNumber(instanceID, "detection.instanceIDs[" .. i .. "]")
        end
    end

    -- Position is optional. Instance maps may render accurately before a usable
    -- player-localization source has been discovered.
    if map.position ~= nil then
        expectTable(map.position, "position")
        expectTable(map.position.source, "position.source")
        expectNumber(map.position.source.uiMapID, "position.source.uiMapID")
        expectString(map.position.source.name, "position.source.name")

        expectTable(map.position.transform, "position.transform")

        local transform = map.position.transform
        if transform.type == "wmo_minimap" then
            expectNumber(transform.clientWorldHalf, "position.transform.clientWorldHalf")

            expectTable(transform.placement, "position.transform.placement")
            expectNumber(transform.placement.positionX, "position.transform.placement.positionX")
            expectNumber(transform.placement.positionY, "position.transform.placement.positionY")
            expectNumber(transform.placement.positionZ, "position.transform.placement.positionZ")
            expectNumber(transform.placement.rotationY, "position.transform.placement.rotationY")
            expectNumber(transform.placement.scale, "position.transform.placement.scale")

            expectTable(transform.minimap, "position.transform.minimap")
            expectNumber(transform.minimap.width, "position.transform.minimap.width")
            expectNumber(transform.minimap.height, "position.transform.minimap.height")
            expectNumber(transform.minimap.pixelsPerUnit, "position.transform.minimap.pixelsPerUnit")
            expectNumber(transform.minimap.topLeftX, "position.transform.minimap.topLeftX")
            expectNumber(transform.minimap.topLeftY, "position.transform.minimap.topLeftY")
            expectNumber(transform.minimap.bottomRightX, "position.transform.minimap.bottomRightX")
            expectNumber(transform.minimap.bottomRightY, "position.transform.minimap.bottomRightY")
        elseif transform.type == "world_minimap_tiles" then
            expectNumber(transform.worldOrigin, "position.transform.worldOrigin")
            expectNumber(transform.tileWorldSize, "position.transform.tileWorldSize")
            expectNumber(transform.tilePixelSize, "position.transform.tilePixelSize")

            if transform.worldAxisOrder ~= "xy" and transform.worldAxisOrder ~= "yx" then
                fail("position.transform.worldAxisOrder must be 'xy' or 'yx'")
            end

            expectTable(transform.mosaic, "position.transform.mosaic")
            expectNumber(transform.mosaic.originTileX, "position.transform.mosaic.originTileX")
            expectNumber(transform.mosaic.originTileY, "position.transform.mosaic.originTileY")
            expectNumber(transform.mosaic.sourceWidth, "position.transform.mosaic.sourceWidth")
            expectNumber(transform.mosaic.sourceHeight, "position.transform.mosaic.sourceHeight")

            if transform.validRegions ~= nil then
                expectTable(transform.validRegions, "position.transform.validRegions")
                for i, region in ipairs(transform.validRegions) do
                    expectTable(region, "position.transform.validRegions[" .. i .. "]")
                    expectNumber(region.left, "position.transform.validRegions[" .. i .. "].left")
                    expectNumber(region.top, "position.transform.validRegions[" .. i .. "].top")
                    expectNumber(region.right, "position.transform.validRegions[" .. i .. "].right")
                    expectNumber(region.bottom, "position.transform.validRegions[" .. i .. "].bottom")
                    if region.right <= region.left or region.bottom <= region.top then
                        fail("position.transform.validRegions[" .. i .. "] must have positive area")
                    end
                end
            end
        else
            fail("position.transform.type must be 'wmo_minimap' or 'world_minimap_tiles'")
        end
    end

    expectTable(map.render, "render")
    if map.render.type ~= "tile_grid" then
        fail("render.type must currently be 'tile_grid'")
    end
    expectNumber(map.render.sourceWidth, "render.sourceWidth")
    expectNumber(map.render.sourceHeight, "render.sourceHeight")
    expectNumber(map.render.displayRotationDegrees, "render.displayRotationDegrees")
    expectNumber(map.render.width, "render.width")
    expectNumber(map.render.height, "render.height")
    expectNumber(map.render.tileSize, "render.tileSize")
    expectNumber(map.render.columns, "render.columns")
    expectNumber(map.render.rows, "render.rows")
    expectString(map.render.texturePrefix, "render.texturePrefix")

    return true
end

local function recordError(sourceName, message)
    Registry.errors[#Registry.errors + 1] = {
        source = sourceName or "<unknown>",
        message = message,
    }
    HM:Print("map rejected:", sourceName or "<unknown>", "-", message)
end

function Registry:RegisterMap(map, sourceName)
    local ok, message = pcall(validateMap, map)
    if not ok then
        recordError(sourceName, tostring(message))
        return false
    end

    if self.mapsByID[map.id] then
        recordError(sourceName, "duplicate map id '" .. map.id .. "'")
        return false
    end

    map._sourceName = sourceName or map.id

    self.mapsByID[map.id] = map
    self.maps[#self.maps + 1] = map

    if map.detection.zoneAliases then
        for _, alias in ipairs(map.detection.zoneAliases) do
            local key = normalize(alias)
            if key ~= "" then
                self.aliasIndex[key] = self.aliasIndex[key] or {}
                self.aliasIndex[key][#self.aliasIndex[key] + 1] = map
            end
        end
    end

    if map.detection.instanceIDs then
        for _, instanceID in ipairs(map.detection.instanceIDs) do
            self.instanceIndex[instanceID] = self.instanceIndex[instanceID] or {}
            self.instanceIndex[instanceID][#self.instanceIndex[instanceID] + 1] = map
        end
    end

    return true
end

function Registry:GetMap(id)
    return self.mapsByID[id]
end

function Registry:GetMaps()
    return self.maps
end

function Registry:GetMapsForAlias(alias)
    return self.aliasIndex[normalize(alias)] or nil
end

function Registry:GetMapsForInstanceID(instanceID)
    return self.instanceIndex[instanceID] or nil
end

function Registry:GetErrors()
    return self.errors
end
