local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "blackfathom_deeps_approach",
    name = "Blackfathom Deeps approach",
    detection = {
        allowInInstance = false,
        requireIndoors = true,
        spatial = true,
        zoneAliases = {
            "Blackfathom Deeps",
            "Blackfathom Ruins"
        }
    },
    source = {
        sourceType = "approach_wmo",
        wmoID = 726,
        fileDataID = 109179,
        minimap = {
            width = 662,
            height = 753,
            pixelsPerUnit = 2,
            topLeftX = 15.81554126739502,
            topLeftY = -167.40029525756836,
            bottomRightX = -314.7711181640625,
            bottomRightY = 208.67523193359375
        },
        sourcePNG = "world/wmo/dungeon/kl_blackfathom/blackfathom_minimap.png",
        sourceJSON = "WildMaps_ExportPack/world/wmo/dungeon/kl_blackfathom/blackfathom_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1440,
            name = "Ashenvale",
            continentID = 1, -- Native world ID; separate from UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            -- Universal ADT world-grid half extent (51200/3).
            clientWorldHalf = 17066.666666666668,
            fileDataID = 109179,
            -- Supplied adt_30_24_ModelPlacementInformation(1).csv.
            -- CSV Y is altitude; CSV X/Z are the horizontal placement plane.
            placement = {
                modelID = 574320,
                positionX = 16167.8642578125,
                positionY = 17.17609405517578,
                positionZ = 12929.984375,
                rotationX = 0,
                rotationY = 164,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 662,
                height = 753,
                pixelsPerUnit = 2,
                topLeftX = 15.81554126739502,
                topLeftY = -167.40029525756836,
                bottomRightX = -314.7711181640625,
                bottomRightY = 208.67523193359375,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 16,
    },
    -- Locked dev8 entranceCalibrationLog[3], GetServerTime 1791065095.
    -- Exact source coordinates and hover text from WildMaps(2).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Blackfathom Deeps Entrance",
            tooltip = "Blackfathom Deeps Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 332.0000386356379, y = 557.9998942758152 },
        },
    },
    render = {
        -- Dev8 presentation rotated 90 degrees counterclockwise; same selected source content.
        -- Crop edges are mechanically permuted, not recalibrated.
        presentationCrop = { left = 58, right = 0, top = 144, bottom = 1 },
        type = "tile_grid",
        sourceWidth = 662,
        sourceHeight = 753,
        displayRotationDegrees = 90,
        width = 753,
        height = 662,
        tileSize = 256,
        columns = 3,
        rows = 3,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\BlackfathomDeepsApproach\\map_"
    }
}, "Map_BlackfathomDeepsApproach.lua")
