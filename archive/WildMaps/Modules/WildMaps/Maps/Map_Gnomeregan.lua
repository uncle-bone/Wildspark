local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "gnomeregan",
    name = "Gnomeregan",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                90
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "Gnomeregan",
    },
    render = {
        type = "tile_grid",
        sourceWidth = 1024,
        sourceHeight = 768,
        displayRotationDegrees = 0,
        width = 1024,
        height = 768,
        tileSize = 256,
        columns = 4,
        rows = 3,
        texturePrefix = "Interface\\Worldmap\\Gnomeregan\\Gnomeregan1_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "Clockwerk Run",
            render = {
                type = "tile_grid",
                sourceWidth = 1024,
                sourceHeight = 768,
                displayRotationDegrees = 0,
                width = 1024,
                height = 768,
                tileSize = 256,
                columns = 4,
                rows = 3,
                texturePrefix = "Interface\\Worldmap\\Gnomeregan\\Gnomeregan1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Hall of Gears",
            render = {
                type = "tile_grid",
                sourceWidth = 1024,
                sourceHeight = 768,
                displayRotationDegrees = 0,
                width = 1024,
                height = 768,
                tileSize = 256,
                columns = 4,
                rows = 3,
                texturePrefix = "Interface\\Worldmap\\Gnomeregan\\Gnomeregan2_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Engineering Labs",
            render = {
                type = "tile_grid",
                sourceWidth = 1024,
                sourceHeight = 768,
                displayRotationDegrees = 0,
                width = 1024,
                height = 768,
                tileSize = 256,
                columns = 4,
                rows = 3,
                texturePrefix = "Interface\\Worldmap\\Gnomeregan\\Gnomeregan3_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Tinkers' Court",
            render = {
                type = "tile_grid",
                sourceWidth = 1024,
                sourceHeight = 768,
                displayRotationDegrees = 0,
                width = 1024,
                height = 768,
                tileSize = 256,
                columns = 4,
                rows = 3,
                texturePrefix = "Interface\\Worldmap\\Gnomeregan\\Gnomeregan4_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_Gnomeregan.lua")
