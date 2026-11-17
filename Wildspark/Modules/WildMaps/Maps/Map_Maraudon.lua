local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "maraudon",
    name = "Maraudon",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                349
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "Maraudon",
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
        texturePrefix = "Interface\\Worldmap\\Maraudon\\Maraudon1_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "Floor 1",
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
                texturePrefix = "Interface\\Worldmap\\Maraudon\\Maraudon1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Earth Song Falls / Zaetar's Grave",
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
                texturePrefix = "Interface\\Worldmap\\Maraudon\\Maraudon2_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_Maraudon.lua")
