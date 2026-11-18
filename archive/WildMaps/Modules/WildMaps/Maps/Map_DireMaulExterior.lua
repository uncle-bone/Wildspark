local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "dire_maul_exterior",
    name = "Dire Maul / Eldre'Thalas exterior complex",
    detection = {
        allowInInstance = false,
        spatial = true, -- Same visible coverage as the chevron; no alias fallback.
        -- Retained for manual name lookup; spatial maps ignore these at detection.
        zoneAliases = {
            "Dire Maul",
            "Eldre'Thalas",
            "Broken Commons",
            "Eldreth Row",
            "The Maul"
        }
    },
    position = {
        source = {
            uiMapID = 1414, -- Existing Kalimdor C_Map fallback, not the Map.db2 ID.
            name = "Kalimdor",
            continentID = 1, -- Expected outdoor world identity from the live APIs.
            validatedUnitWorld = true,
        },
        transform = {
            type = "world_minimap_tiles",
            -- Derived from the supplied JSON: 1600 world units across 3 tiles.
            -- top-left world Y + 28 tiles = top-left world X + 38 tiles.
            worldOrigin = 51200 / 3,
            tileWorldSize = 1600 / 3,
            tilePixelSize = 512,
            worldAxisOrder = "yx",
            -- Original uncropped source pixels; all presentation happens later.
            mosaic = {
                originTileX = 28,
                originTileY = 38,
                sourceWidth = 1536,
                sourceHeight = 1536,
            },
        },
        facingOffsetDegrees = 0, -- Native north-up artwork; use validated facing.
    },
    source = {
        -- Geographic base below is unchanged. The dev6 packaged artwork adds
        -- approved Passage01/02/03 and EntRuins02 textures from WMO 21065.
        sourceType = "world_minimap_mosaic",
        mapID = 1,
        worldMap = "Kalimdor",
        sourcePNG = "kalimdor_ef9574ac.png",
        sourceJSON = "kalimdor_ef9574ac.json",
        minimapTiles = {
            { name = "map28_38", gridX = 0, gridY = 0, width = 512, height = 512 },
            { name = "map29_38", gridX = 1, gridY = 0, width = 512, height = 512 },
            { name = "map30_38", gridX = 2, gridY = 0, width = 512, height = 512 },
            { name = "map28_39", gridX = 0, gridY = 1, width = 512, height = 512 },
            { name = "map29_39", gridX = 1, gridY = 1, width = 512, height = 512 },
            { name = "map30_39", gridX = 2, gridY = 1, width = 512, height = 512 },
            { name = "map28_40", gridX = 0, gridY = 2, width = 512, height = 512 },
            { name = "map29_40", gridX = 1, gridY = 2, width = 512, height = 512 },
            { name = "map30_40", gridX = 2, gridY = 2, width = 512, height = 512 },
        },
        composite = { width = 1536, height = 1536 },
        worldBounds = {
            topLeftX = -3200,
            topLeftY = 2133.3333333333335,
            bottomRightX = -4800,
            bottomRightY = 533.3333333333334,
        },
    },
    markers = {
        {
            type = "entrance_exit",
            name = "Dire Maul North Entrance",
            tooltip = "Dire Maul North Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 1035.255382978292, y = 301.1798216142814 },
        },
        {
            type = "entrance_exit",
            name = "Dire Maul East Side Entrance",
            tooltip = "Dire Maul East Side Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 1304.320116014659, y = 747.3787450605088 },
        },
        {
            type = "entrance_exit",
            name = "Dire Maul East Main Entrance",
            tooltip = "Dire Maul East Main Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 1151.85000760985, y = 516.4317473245769 },
        },
        {
            type = "entrance_exit",
            name = "Dire Maul West Entrance",
            tooltip = "Dire Maul West Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 846.9099832503033, y = 518.6739829496926 },
        },
        {
            type = "entrance_exit",
            name = "Dire Maul West Entrance",
            tooltip = "Dire Maul West Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 842.4255598067764, y = 619.5730464794356 },
        },
    },
    render = {
        -- Locked dev6 in-game crop; the full source artwork remains packaged.
        -- Original 1536x1536 render pixels, rotation 0; tracking stays in source space.
        presentationCrop = { left = 373, right = 195, top = 281, bottom = 320 },
        type = "tile_grid",
        sourceWidth = 1536,
        sourceHeight = 1536,
        displayRotationDegrees = 0,
        width = 1536,
        height = 1536,
        -- One continuous texture avoids subpixel gaps between separate tiles.
        -- 2048 is storage only; the full 1536x1536 artwork occupies UV 0..0.75.
        -- The presentation crop samples within it; source and tracking stay put.
        tileSize = 2048,
        columns = 1,
        rows = 1,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\DireMaulExterior\\map_"
    }
}, "Map_DireMaulExterior.lua")
