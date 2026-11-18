local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "scarlet_monastery_grounds",
    name = "Scarlet Monastery entrance / grounds",
    detection = {
        allowInInstance = false,
        requireIndoors = true,
        spatial = true,
        zoneAliases = {
            "Scarlet Monastery",
            "The Grand Vestibule",
            "Whispering Gardens",
            "Terrace of Repose"
        }
    },
    source = {
        sourceType = "wmo",
        wmoID = 60,
        fileDataID = 107218,
        minimap = {
            width = 587,
            height = 388,
            pixelsPerUnit = 2,
            topLeftX = 174.62139892578125,
            topLeftY = -151.64080810546875,
            bottomRightX = -118.42881202697754,
            bottomRightY = 41.909210205078125
        },
        sourcePNG = "world/wmo/azeroth/buildings/scarlet_monestary/scarlet_monestary_minimap.png",
        sourceJSON = "world/wmo/azeroth/buildings/scarlet_monestary/scarlet_monestary_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1420,
            name = "Tirisfal Glades",
            continentID = 0, -- Eastern Kingdoms world map, not a UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            -- Universal ADT world-grid half extent (51200/3), not WC calibration.
            clientWorldHalf = 17066.666666666668,
            fileDataID = 107218,
            -- Forever wow.export adt_33_26_ModelPlacementInformation(1).csv.
            -- CSV Y is altitude; CSV X/Z form the horizontal placement plane.
            placement = {
                modelID = 129262,
                positionX = 17758.65625,
                positionY = 141.6554718017578,
                positionZ = 14222.65234375,
                rotationX = 0,
                rotationY = 292.5,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 587,
                height = 388,
                pixelsPerUnit = 2,
                topLeftX = 174.62139892578125,
                topLeftY = -151.64080810546875,
                bottomRightX = -118.42881202697754,
                bottomRightY = 41.909210205078125,
            },
            requireSourceBounds = true,
        },
        -- The retained artwork is not north-up. Rotate the existing facing
        -- by displayRotation - (placementRotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 67.5,
    },
    -- Locked dev7 entranceCalibrationLog[1], GetServerTime 1791030924.
    -- Exact source coordinates and hover text from the user's WildMaps(1).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Scarlet Monastery Graveyard",
            tooltip = "Scarlet Monastery Graveyard",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 90.74820321568376, y = 360.8848864727892 },
        },
        {
            type = "entrance_exit",
            name = "Scarlet Monastery Cathedral",
            tooltip = "Scarlet Monastery Cathedral",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 49.82254184089867, y = 335.9736331208122 },
        },
        {
            type = "entrance_exit",
            name = "Scarlet Monastery Armory",
            tooltip = "Scarlet Monastery Armory",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 50.71231811457721, y = 265.6882579823973 },
        },
        {
            type = "entrance_exit",
            name = "Scarlet Monastery Library",
            tooltip = "Scarlet Monastery Library",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 90.74820321568376, y = 244.3357660182077 },
        },
    },
    render = {
        -- Locked in-game calibration; offsets in the existing oriented artwork.
        presentationCrop = { left = 0, right = 219, top = 0, bottom = 216 },
        type = "tile_grid",
        sourceWidth = 587,
        sourceHeight = 388,
        displayRotationDegrees = -90.0,
        width = 388,
        height = 587,
        tileSize = 256,
        columns = 2,
        rows = 3,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\ScarletMonasteryGrounds\\map_"
    }
}, "Map_ScarletMonasteryGrounds.lua")
