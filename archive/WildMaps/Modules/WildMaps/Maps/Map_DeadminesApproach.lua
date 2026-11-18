local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "deadmines_approach",
    name = "Deadmines approach / pre-instance mines",
    detection = {
        allowInInstance = false,
        spatial = true,
        zoneAliases = {
            "The Deadmines",
            "Deadmines",
            "Defias Hideout"
        }
    },
    source = {
        sourceType = "shared_compound_wmo",
        wmoID = 499,
        fileDataID = 108444,
        minimap = {
            width = 695,
            height = 758,
            pixelsPerUnit = 2,
            topLeftX = 78.66931915283203,
            topLeftY = -348.7746887207031,
            bottomRightX = -268.4500427246094,
            bottomRightY = 30.155942916870117
        },
        sourcePNG = "world/wmo/dungeon/az_deadmines/az_deadmines_a_minimap.png",
        sourceJSON = "world/wmo/dungeon/az_deadmines/az_deadmines_a_minimap.json"
    },
    position = {
        source = {
            uiMapID = 1436,
            name = "Westfall",
            continentID = 0, -- Native world ID; separate from UiMap ID.
            validatedUnitWorld = true,
        },
        transform = {
            type = "wmo_minimap",
            -- Universal ADT world-grid half extent (51200/3).
            clientWorldHalf = 17066.666666666668,
            fileDataID = 108444,
            -- Supplied adt_29_52_ModelPlacementInformation(1).csv.
            -- CSV Y is altitude; CSV X/Z are the horizontal placement plane.
            placement = {
                modelID = 35530,
                positionX = 15538.4404296875,
                positionY = 45.27324676513672,
                positionZ = 28165.39453125,
                rotationX = 0,
                rotationY = 269,
                rotationZ = 0,
                scale = 1,
            },
            minimap = {
                width = 695,
                height = 758,
                pixelsPerUnit = 2,
                topLeftX = 78.66931915283203,
                topLeftY = -348.7746887207031,
                bottomRightX = -268.4500427246094,
                bottomRightY = 30.155942916870117,
            },
            requireSourceBounds = true,
        },
        -- Display rotation - (placement RotationY - 180) - 90, modulo 360.
        facingOffsetDegrees = 1,
    },
    -- Locked dev8 entranceCalibrationLog[2], GetServerTime 1791064594.
    -- Exact source coordinates and hover text from WildMaps(2).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Deadmines Entrance",
            tooltip = "Deadmines Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 450.8560578187549, y = 472.5395805340646 },
        },
    },
    render = {
        -- Dev8 presentation rotated 90 degrees clockwise; same selected source content.
        -- Crop edges are mechanically permuted, not recalibrated.
        presentationCrop = { left = 187, right = 1, top = 0, bottom = 181 },
        type = "tile_grid",
        sourceWidth = 695,
        sourceHeight = 758,
        displayRotationDegrees = -180,
        width = 695,
        height = 758,
        tileSize = 256,
        columns = 3,
        rows = 3,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\DeadminesApproach\\map_"
    }
}, "Map_DeadminesApproach.lua")
