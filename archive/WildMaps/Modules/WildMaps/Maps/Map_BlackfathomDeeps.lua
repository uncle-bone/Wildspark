local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "blackfathom_deeps",
    name = "Blackfathom Deeps",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                48
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "BlackfathomDeeps",
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
        texturePrefix = "Interface\\Worldmap\\BlackfathomDeeps\\BlackfathomDeeps1_",
        tileNaming = "blizzard_sequential",
    },
    floors = {
        {
            name = "Deeps",
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
                texturePrefix = "Interface\\Worldmap\\BlackfathomDeeps\\BlackfathomDeeps1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Moonshrine Ruins",
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
                texturePrefix = "Interface\\Worldmap\\BlackfathomDeeps\\BlackfathomDeeps2_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Forgotten Pool",
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
                texturePrefix = "Interface\\Worldmap\\BlackfathomDeeps\\BlackfathomDeeps3_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_BlackfathomDeeps.lua")
