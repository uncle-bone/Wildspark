local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "wailing_caverns_instance",
    name = "Wailing Caverns",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                43,
            },
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "WailingCaverns",
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
        texturePrefix = "Interface\\Worldmap\\WailingCaverns\\WailingCaverns1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_WailingCavernsInstance.lua")
