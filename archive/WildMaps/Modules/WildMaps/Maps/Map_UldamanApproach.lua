local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "uldaman_approach",
    name = "Uldaman approach",
    detection = {
        allowInInstance = false,
        requireIndoors = true,
        spatial = true,
        zoneAliases = {
            "Uldaman"
        }
    },
    source = {
        sourceType = "approach_wmo",
        wmoID = 1218,
        fileDataID = 109758,
        minimap = {
            width = 804,
            height = 712,
            pixelsPerUnit = 2,
            topLeftX = -7.56120491027832,
            topLeftY = -253.98882293701172,
            bottomRightX = -409.1759338378906,
            bottomRightY = 101.9658203125
        },
        sourcePNG = "world/wmo/dungeon/kz_uldaman/kz_uldaman_a_minimap.png",
        sourceJSON = "WildMaps_ExportPack/world/wmo/dungeon/kz_uldaman/kz_uldaman_a_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1418,
            name = "Badlands",
            continentID = 0, -- Native world ID; separate from UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            -- Universal ADT world-grid half extent (51200/3).
            clientWorldHalf = 17066.666666666668,
            fileDataID = 109758,
            -- Supplied adt_37_43_ModelPlacementInformation(1).csv.
            -- CSV Y is altitude; CSV X/Z are the horizontal placement plane.
            placement = {
                modelID = 180253,
                positionX = 20251.458984375,
                positionY = 255.78746032714844,
                positionZ = 23157.859375,
                rotationX = 0,
                rotationY = 273,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 804,
                height = 712,
                pixelsPerUnit = 2,
                topLeftX = -7.56120491027832,
                topLeftY = -253.98882293701172,
                bottomRightX = -409.1759338378906,
                bottomRightY = 101.9658203125,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 357,
    },
    -- Locked dev8 entranceCalibrationLog[5], GetServerTime 1791094324.
    -- Exact source coordinates and hover text from WildMaps(2).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Uldaman Entrance",
            tooltip = "Uldaman Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 441.189495558565, y = 583.9016352374558 },
        },
    },
    render = {
        -- Dev8 presentation rotated 180 degrees clockwise; same selected source content.
        -- Crop edges are mechanically permuted, not recalibrated.
        presentationCrop = { left = 173, right = 0, top = 6, bottom = 107 },
        type = "tile_grid",
        sourceWidth = 804,
        sourceHeight = 712,
        displayRotationDegrees = -180,
        width = 804,
        height = 712,
        tileSize = 256,
        columns = 4,
        rows = 3,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\UldamanApproach\\map_"
    }
}, "Map_UldamanApproach.lua")
