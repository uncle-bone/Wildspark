local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "gnomeregan_approach",
    name = "Gnomeregan approach / exterior tunnels",
    detection = {
        allowInInstance = false,
        requireIndoors = true,
        spatial = true,
        zoneAliases = {
            "Gnomeregan",
            "Train Depot",
            "Loading Room",
            "Workshop Entrance"
        }
    },
    source = {
        sourceType = "wmo",
        wmoID = 1220,
        fileDataID = 109593,
        minimap = {
            width = 1148,
            height = 1009,
            pixelsPerUnit = 2,
            topLeftX = -5.294620037078857,
            topLeftY = -120.30203151702881,
            bottomRightX = -579.0942687988281,
            bottomRightY = 383.7392272949219
        },
        sourcePNG = "world/wmo/dungeon/kz_gnomeragon/kz_gnomeragon_minimap.png",
        sourceJSON = "world/wmo/dungeon/kz_gnomeragon/kz_gnomeragon_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1426,
            name = "Dun Morogh",
            continentID = 0, -- Native world ID; separate from UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            -- Universal ADT world-grid half extent (51200/3).
            clientWorldHalf = 17066.666666666668,
            fileDataID = 109593,
            -- Supplied adt_30_41_ModelPlacementInformation(2).csv.
            -- CSV Y is altitude; CSV X/Z are the horizontal placement plane.
            placement = {
                modelID = 324550,
                positionX = 16460.017578125,
                positionY = 410.0280456542969,
                positionZ = 22250.119140625,
                rotationX = 0,
                rotationY = 265.5,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 1148,
                height = 1009,
                pixelsPerUnit = 2,
                topLeftX = -5.294620037078857,
                topLeftY = -120.30203151702881,
                bottomRightX = -579.0942687988281,
                bottomRightY = 383.7392272949219,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 4.5,
    },
    -- Locked dev8 entranceCalibrationLog[4], GetServerTime 1791094030.
    -- Exact source coordinates and hover text from WildMaps(2).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Gnomeregan Entrance",
            tooltip = "Gnomeregan Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 628.5467372338343, y = 236.6114709967403 },
        },
    },
    render = {
        -- Dev8 presentation rotated 90 degrees clockwise; same selected source content.
        -- Crop edges are mechanically permuted, not recalibrated.
        presentationCrop = { left = 170, right = 0, top = 2, bottom = 205 },
        type = "tile_grid",
        sourceWidth = 1148,
        sourceHeight = 1009,
        displayRotationDegrees = -180,
        width = 1148,
        height = 1009,
        tileSize = 256,
        columns = 5,
        rows = 4,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\GnomereganApproach\\map_"
    }
}, "Map_GnomereganApproach.lua")
