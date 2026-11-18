local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "blackrock_depths",
    name = "Blackrock Depths",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                230
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "BlackrockDepths",
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
        texturePrefix = "Interface\\Worldmap\\BlackrockDepths\\BlackrockDepths1_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "Detention Block",
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
                texturePrefix = "Interface\\Worldmap\\BlackrockDepths\\BlackrockDepths1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Domicile",
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
                texturePrefix = "Interface\\Worldmap\\BlackrockDepths\\BlackrockDepths2_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_BlackrockDepths.lua")
