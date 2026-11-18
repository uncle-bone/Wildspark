local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "razorfen_downs_approach",
    name = "Razorfen Downs approach",
    detection = {
        allowInInstance = false,
        zoneAliases = {
            "Razorfen Downs"
        }
    },
    position = {
        source = {
            uiMapID = 1414,
            name = "Kalimdor",
            continentID = 1,
        },
        transform = {
            type = "world_minimap_tiles",

            -- Classic's native 64x64 terrain/minimap grid. With live API world
            -- coordinates, the first mapNN_MM filename index follows world Y
            -- and the second follows world X, hence the explicit "yx" mapping.
            worldOrigin = 17066.666015625,
            tileWorldSize = 533.33331298828125,
            tilePixelSize = 512,
            worldAxisOrder = "yx",

            -- Stable ORIGINAL source mosaic. Future visual crops/reframes should
            -- operate after these source coordinates are resolved.
            mosaic = {
                originTileX = 35,
                originTileY = 40,
                sourceWidth = 1024,
                sourceHeight = 768,
            },

            -- The lower-left 512x256 source quadrant is deliberately absent.
            validRegions = {
                { left = 0, top = 0, right = 1024, bottom = 512 },
                { left = 512, top = 512, right = 1024, bottom = 768 },
            },
        },
    },

    markers = {
        {
            type = "entrance_exit",
            name = "Razorfen Downs Entrance",
            tooltip = "Razorfen Downs Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 891, y = 377 },
        },
    },

    source = {
        sourceType = "world_minimap_mosaic",
        mapID = 1,
        worldMap = "Kalimdor",
        minimapTiles = {
            { name = "map35_40", gridX = 0, gridY = 0, width = 512, height = 512 },
            { name = "map36_40", gridX = 1, gridY = 0, width = 512, height = 512 },
            {
                name = "map36_41",
                gridX = 1,
                gridY = 1,
                width = 512,
                height = 256,
                crop = { left = 0, top = 0, right = 0, bottom = 256 }
            }
        },
        composite = {
            width = 1024,
            height = 768,
            note = "RFD world-minimap mosaic; lower-left quadrant intentionally empty. map36_41 retains upper 256 px only."
        }
    },
    render = {
        -- Locked in-game calibration; offsets in the existing oriented artwork.
        presentationCrop = { left = 265, right = 87, top = 76, bottom = 258 },
        type = "tile_grid",
        sourceWidth = 1024,
        sourceHeight = 768,
        displayRotationDegrees = 0,
        width = 1024,
        height = 768,
        tileSize = 256,
        columns = 4,
        rows = 3,

        -- Explicit clockwise content silhouette in source/display coordinates.
        -- Renderer defaults remain rectangular for maps without this metadata.
        edgeSilhouette = {
            width = 1024,
            height = 768,
            points = {
                { x = 0, y = 0 },
                { x = 1024, y = 0 },
                { x = 1024, y = 768 },
                { x = 512, y = 768 },
                { x = 512, y = 512 },
                { x = 0, y = 512 },
            },
        },

        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\RazorfenDownsApproach\\map_"
    }
}, "Map_RazorfenDownsApproach.lua")
