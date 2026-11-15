local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "stockade",
    name = "The Stockade",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                34
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "TheStockade",
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
        texturePrefix = "Interface\\Worldmap\\TheStockade\\TheStockade1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_Stockade.lua")
