local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "scarlet_library",
    name = "Scarlet Monastery – Library",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            zoneAliases = {
                "Gallery of Treasures",
                "Athenaeum",
                "Huntsman's Cloister"
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "ScarletMonastery",
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
        texturePrefix = "Interface\\Worldmap\\ScarletMonastery\\ScarletMonastery2_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_ScarletLibrary.lua")
