local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "stratholme",
    name = "Stratholme",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                329
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "Stratholme",
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
        texturePrefix = "Interface\\Worldmap\\Stratholme\\Stratholme1_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "Living Side",
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
                texturePrefix = "Interface\\Worldmap\\Stratholme\\Stratholme1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Undead Side",
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
                texturePrefix = "Interface\\Worldmap\\Stratholme\\Stratholme2_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_Stratholme.lua")
