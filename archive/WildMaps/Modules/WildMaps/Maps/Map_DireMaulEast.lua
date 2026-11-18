local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "dire_maul_east",
    name = "Dire Maul East",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            zoneAliases = {
                "Warpwood Quarter",
                "The Shrine of Eldretharr",
                "The Hidden Reach",
                "The Conservatory"
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "Diremaul",
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
        texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul2_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "East – Gardens",
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
                texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul2_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "East – Prison of Immol'thar",
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
                texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul4_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_DireMaulEast.lua")
