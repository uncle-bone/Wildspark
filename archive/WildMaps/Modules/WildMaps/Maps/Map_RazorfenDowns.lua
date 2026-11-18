local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "razorfen_downs",
    name = "Razorfen Downs",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                129
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "RazorfenDowns",
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
        texturePrefix = "Interface\\Worldmap\\RazorfenDowns\\RazorfenDowns1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_RazorfenDowns.lua")
