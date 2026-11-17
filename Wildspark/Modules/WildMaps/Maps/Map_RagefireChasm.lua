local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "ragefire_chasm",
    name = "Ragefire Chasm",
    frameLayout = "tall",
    detection = {
        allowInInstance = true,
        instanceIDs = {
            389
        }
    },
    source = {
        sourceType = "wmo",
        wmoID = 3433,
        fileDataID = 109483,
        minimap = {
            width = 1089,
            height = 965,
            pixelsPerUnit = 2,
            topLeftX = 102.9556655883789,
            topLeftY = -206.83008575439453,
            bottomRightX = -441.2587585449219,
            bottomRightY = 275.3790588378906
        },
        sourcePNG = "world/wmo/dungeon/kl_orgrimmarlavadungeon/lavadungeon_minimap.png",
        sourceJSON = "world/wmo/dungeon/kl_orgrimmarlavadungeon/lavadungeon_minimap.json"
    },
    markers = {
        -- Test marker positions use Ragefire Chasm instance-map coordinates.
        -- These are transformed through the source minimap, display rotation,
        -- and post-rotation crop at render time rather than stored as final pixels.
        {
            type = "entrance_exit",
            name = "Entrance/Exit",
            tooltip = "Entrance/Exit",
            position = { space = "instance_map", x = 0.797643, y = -8.23429 },
        },
        {
            type = "boss",
            name = "Oggleflint",
            tooltip = "Oggleflint",
            npcID = 11517,
            position = { space = "instance_map", x = -147.548, y = 38.7127 },
        },
        {
            type = "boss",
            name = "Taragaman the Hungerer",
            tooltip = "Taragaman the Hungerer",
            npcID = 11520,
            position = { space = "instance_map", x = -244.743, y = 150.085 },
        },
        {
            type = "boss",
            name = "Jergosh the Invoker",
            tooltip = "Jergosh the Invoker",
            npcID = 11518,
            position = { space = "instance_map", x = -376.811, y = 209.224 },
        },
        {
            type = "boss",
            name = "Bazzalan",
            tooltip = "Bazzalan",
            npcID = 11519,
            position = { space = "instance_map", x = -384.867, y = 146.045 },
        },
    },
    processing = {
        postRotationCrop = {
            mode = "manual_fraction",
            left = 0.0,
            top = 0.0,
            right = 0.2,
            bottom = 0.0,
            preCropWidth = 965,
            preCropHeight = 1089,
            cropLeftPixels = 0,
            cropTopPixels = 0,
            cropRightPixels = 193,
            cropBottomPixels = 0,
            finalWidth = 772,
            finalHeight = 1089
        }
    },
    render = {
        type = "tile_grid",
        sourceWidth = 1089,
        sourceHeight = 965,
        displayRotationDegrees = -90.0,
        width = 772,
        height = 1089,
        tileSize = 256,
        columns = 4,
        rows = 5,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\RagefireChasm\\map_"
    }
}, "Map_RagefireChasm.lua")
