local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "blackrock_mountain_interior",
    name = "Blackrock Mountain interior",
    detection = {
        allowInInstance = false,
        spatial = true,
        requireIndoors = true,
        -- Retained for manual lookup. Spatial detection never falls back to names.
        zoneAliases = {
            "Blackrock Mountain",
            "Blackrock Spire",
            "The Molten Span",
            "Forgewright's Tomb",
            "The Grinding Quarry"
        }
    },
    source = {
        sourceType = "compound_wmo",
        wmoID = 560,
        fileDataID = 108238,
        minimap = {
            width = 1658,
            height = 1216,
            pixelsPerUnit = 2,
            topLeftX = 581.1018676757812,
            topLeftY = -469.7065124511719,
            bottomRightX = -247.58843231201172,
            bottomRightY = 138.21165466308594
        },
        sourcePNG = "world/wmo/dungeon/az_blackrock/blackrock_minimap.png",
        sourceJSON = "world/wmo/dungeon/az_blackrock/blackrock_minimap.json",
        -- Lossless inverse of the existing -90-degree tiles; retain their Era colors.
        recoveredPNG = "Sources/BlackrockMountainInterior/blackrock_minimap_era_recovered.png",
        -- Identical local bounds/PPU; source silhouettes match at the same pixels.
        forever = {
            wmoID = 21070,
            fileDataID = 7952336,
            sourceWMO = "world/wmo/autogen-names/unknown/21070.wmo",
            sourcePNG = "Sources/BlackrockMountainInterior/21070_minimap.png",
            sourceJSON = "Sources/BlackrockMountainInterior/21070_minimap.json",
            sourcePlacementCSV = "Sources/BlackrockMountainInterior/adt_34_46_ModelPlacementInformation.csv",
        },
    },
    position = {
        source = {
            uiMapID = 1427, -- Searing Gorge; only the existing C_Map fallback uses this.
            name = "Searing Gorge",
            continentID = 0, -- Eastern Kingdoms world identity, not a UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            clientWorldHalf = 17066.666666666668, -- Universal ADT extent: 51200/3.
            fileDataID = 7952336,
            -- Supplied Forever ADT 34,46: 21070_set0.obj, placement 373730.
            -- CSV X/Z are horizontal; zero pitch/roll makes height unnecessary.
            placement = {
                modelID = 373730,
                positionX = 18086.48828125,
                positionY = 235.9007110595703,
                positionZ = 24693.9375,
                rotationX = 0,
                rotationY = 7,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 1658,
                height = 1216,
                pixelsPerUnit = 2,
                topLeftX = 581.1018676757812,
                topLeftY = -469.7065124511719,
                bottomRightX = -247.58843231201172,
                bottomRightY = 138.21165466308594,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90 = 3 degrees.
        facingOffsetDegrees = 3,
    },
    -- Permanent source-pixel markers from the dev15 calibration (1792058304).
    -- Blackrock Spire is the shared physical entrance for LBRS and UBRS.
    markers = {
        {
            type = "entrance_exit",
            name = "Blackrock Depths Entrance",
            tooltip = "Blackrock Depths Entrance",
            position = { space = "source_pixels", x = 245.3731679170506, y = 1016.017215451735 },
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            size = 18,
            showLabel = false,
        },
        {
            type = "entrance_exit",
            name = "Blackrock Spire Entrance",
            tooltip = "Blackrock Spire Entrance",
            position = { space = "source_pixels", x = 1000.383246431267, y = 471.7907145353092 },
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            size = 18,
            showLabel = false,
        },
        {
            type = "entrance_exit",
            name = "Exit to Burning Steppes",
            tooltip = "Exit to Burning Steppes",
            position = { space = "source_pixels", x = 1454.20504086284, y = 753.1876635163042 },
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\outdoor_exit.tga",
            size = 18,
            showLabel = false,
        },
        {
            type = "entrance_exit",
            name = "Exit to Searing Gorge",
            tooltip = "Exit to Searing Gorge",
            position = { space = "source_pixels", x = 701.2024543782723, y = 714.9985720397501 },
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\outdoor_exit.tga",
            size = 18,
            showLabel = false,
        },
    },
    render = {
        -- Calibrated with /wmcrop on dev14; offsets use the full render canvas.
        presentationCrop = { left = 91, right = 265, top = 361, bottom = 230 },
        type = "tile_grid",
        sourceWidth = 1658,
        sourceHeight = 1216,
        displayRotationDegrees = -80.0,
        width = 1486,
        height = 1844,
        tileSize = 256,
        columns = 6,
        rows = 8,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\BlackrockMountainInterior\\map_"
    }
}, "Map_BlackrockMountainInterior.lua")
