local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "dire_maul_west",
    name = "Dire Maul West",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            zoneAliases = {
                "Capital Gardens",
                "The Athenaeum",
                "Prison of Immol'thar",
                "Court of the Highborne"
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
        texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul5_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "West – Warpwood Quarter",
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
                texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul5_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "West – Conservatory",
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
                texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul6_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_DireMaulWest.lua")
