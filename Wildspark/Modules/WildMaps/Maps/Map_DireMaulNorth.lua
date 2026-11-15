local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "dire_maul_north",
    name = "Dire Maul North",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            zoneAliases = {
                "Gordok's Seat",
                "Halls of Destruction"
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
        texturePrefix = "Interface\\Worldmap\\Diremaul\\Diremaul1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_DireMaulNorth.lua")
