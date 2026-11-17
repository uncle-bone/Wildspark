local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "maraudon_approach",
    name = "Maraudon non-instanced approach caves",
    detection = {
        allowInInstance = false,
        requireIndoors = true,
        zoneAliases = {
            "Maraudon",
            "Ambershard Cavern",
            "Shadowshard Cavern",
            "Shrine of the Five Khans"
        }
    },
    source = {
        sourceType = "wmo",
        wmoID = 1376,
        fileDataID = 109381,
        minimap = {
            width = 1171,
            height = 1181,
            pixelsPerUnit = 2,
            topLeftX = 213.55899047851562,
            topLeftY = -234.2970733642578,
            bottomRightX = -371.86293029785156,
            bottomRightY = 355.814453125
        },
        sourcePNG = "world/wmo/dungeon/kl_maraudon/kl_maraudon_minimap.png",
        sourceJSON = "world/wmo/dungeon/kl_maraudon/kl_maraudon_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1443, -- Desolace UiMap; not the coordinate-world identity.
            name = "Desolace",
            continentID = 1, -- Kalimdor UnitPosition map ID.
            validatedUnitWorld = true,
            requireAltitude = true, -- The exported 1-degree tilt needs live Z.
        },
        transform = {
            type = "wmo_minimap",
            clientWorldHalf = 17066.666666666668, -- Universal ADT extent: 51200/3.
            fileDataID = 109381,
            -- wow.export adt_26_34_ModelPlacementInformation(2).csv, data row 4.
            -- kl_maraudon_set0.obj; CSV Y is height, X/Z are horizontal.
            placement = {
                modelID = 492637,
                positionX = 14175.28125,
                positionY = 132.92724609375,
                positionZ = 18491.05078125,
                rotationX = 0,
                rotationY = 186,
                rotationZ = 1,
                scale = 1,
            },
            fullPlacementRotation = true,
            minimap = {
                width = 1171,
                height = 1181,
                pixelsPerUnit = 2,
                topLeftX = 213.55899047851562,
                topLeftY = -234.2970733642578,
                bottomRightX = -371.86293029785156,
                bottomRightY = 355.814453125,
            },
            requireSourceBounds = true,
        },
    },
    -- WildMaps(4).lua entranceCalibrationLog[7], LOCK at 1791741071.
    -- Captured after the renderer-only 180-degree fix. Its old click inverse
    -- omitted that turn: recover stable source via (1040-logX, 1350-logY).
    -- These points project to the exact original clicked positions and labels.
    markers = {
        {
            type = "entrance_exit",
            name = "Maraudon Purple Entrance",
            tooltip = "Maraudon Purple Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 910.3116676516954, y = 569.004775821691 },
        },
        {
            type = "entrance_exit",
            name = "Maraudon Orange Entrance",
            tooltip = "Maraudon Orange Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 259.3765531223219, y = 1007.9495082232088 },
        },
        {
            type = "entrance_exit",
            name = "Princess Portal",
            tooltip = "Princess Portal",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 521.2471712695944, y = 419.3644276221237 },
        },
    },
    render = {
        -- Locked in-game calibration; offsets in the existing oriented artwork.
        presentationCrop = { left = 2, right = 171, top = 0, bottom = 131 },
        type = "tile_grid",
        sourceWidth = 1171,
        sourceHeight = 1181,
        displayRotationDegrees = -90.0,
        width = 1181,
        height = 1171,
        tileSize = 256,
        columns = 5,
        rows = 5,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\MaraudonApproach\\map_"
    }
}, "Map_MaraudonApproach.lua")
