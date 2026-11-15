local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "deadmines",
    name = "Deadmines",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                36
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "TheDeadmines",
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
        texturePrefix = "Interface\\Worldmap\\TheDeadmines\\TheDeadmines1_",
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
                texturePrefix = "Interface\\Worldmap\\TheDeadmines\\TheDeadmines1_",
                tileNaming = "blizzard_sequential",
            },
        },
        {
            name = "Floor 2",
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
                texturePrefix = "Interface\\Worldmap\\TheDeadmines\\TheDeadmines2_",
                tileNaming = "blizzard_sequential",
            },
        },
    },
}, "Map_Deadmines.lua")
