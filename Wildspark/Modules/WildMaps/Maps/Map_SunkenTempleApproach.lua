local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "sunken_temple_approach",
    name = "Sunken Temple approach",
    detection = {
        allowInInstance = false,
        spatial = true,
        requireIndoors = true,
        -- Retained for manual lookup. Spatial detection never falls back to names.
        zoneAliases = {
            "The Temple of Atal'Hakkar",
            "Temple of Atal'Hakkar",
            "Sunken Temple"
        }
    },
    source = {
        sourceType = "approach_wmo",
        wmoID = 21140,
        fileDataID = 7962739,
        sourceWMO = "world/wmo/autogen-names/unknown/21140.wmo",
        sourcePNG = "Sources/SunkenTempleApproach/21140_minimap.png",
        sourceJSON = "Sources/SunkenTempleApproach/21140_minimap.json",
        sourceModelJSON = "Sources/SunkenTempleApproach/21140.json",
        sourcePlacementCSV = "Sources/SunkenTempleApproach/adt_39_51_ModelPlacementInformation.csv",
        minimap = {
            width = 872,
            height = 734,
            pixelsPerUnit = 2,
            topLeftX = -4.279385089874268,
            topLeftY = -134.67905378341675,
            bottomRightX = -440.20562744140625,
            bottomRightY = 231.98963928222656,
        },
    },
    position = {
        source = {
            uiMapID = 1435, -- Swamp of Sorrows; separate from native world identity.
            name = "Swamp of Sorrows",
            continentID = 0, -- Eastern Kingdoms outdoor world.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            clientWorldHalf = 17066.666666666668, -- Universal ADT extent: 51200/3.
            fileDataID = 7962739,
            -- Supplied ADT 39,51 CSV: model 21140_set0.obj, placement 362609.
            -- CSV Y is altitude; X/Z form the horizontal placement plane.
            placement = {
                modelID = 362609,
                positionX = 20889.546875,
                positionY = 17.95456886291504,
                positionZ = 27513.01953125,
                rotationX = 0,
                rotationY = 165.674560546875,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 872,
                height = 734,
                pixelsPerUnit = 2,
                topLeftX = -4.279385089874268,
                topLeftY = -134.67905378341675,
                bottomRightX = -440.20562744140625,
                bottomRightY = 231.98963928222656,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 1.825439453125,
    },
    -- Locked dev10 entrance, GetServerTime 1791965126, from WildMaps(10).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Sunken Temple Entrance",
            tooltip = "Sunken Temple Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 593.8345278540327, y = 467.0149169381878 },
        },
    },
    render = {
        -- Locked dev10 crop, GetServerTime 1791965190, from WildMaps(10).lua.
        -- Absolute render-pixel margins; source coordinates remain unchanged.
        presentationCrop = { left = 219, right = 93, top = 357, bottom = 98 },
        type = "tile_grid",
        sourceWidth = 872,
        sourceHeight = 734,
        -- Baked once into the texture; shared position/POI math uses this angle.
        -- Positive angles are counterclockwise in the existing screen-space math.
        displayRotationDegrees = 77.5,
        width = 906,
        height = 1012,
        -- Established single-texture grid convention; storage padding is excluded.
        tileSize = 1024,
        columns = 1,
        rows = 1,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\SunkenTempleApproach\\map_"
    }
}, "Map_SunkenTempleApproach.lua")
