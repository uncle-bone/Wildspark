local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "scarlet_graveyard",
    name = "Scarlet Monastery – Graveyard",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            zoneAliases = {
                "Chamber of Atonement",
                "Honor's Tomb",
                "Forlorn Cloister"
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
        texturePrefix = "Interface\\Worldmap\\ScarletMonastery\\ScarletMonastery1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_ScarletGraveyard.lua")
