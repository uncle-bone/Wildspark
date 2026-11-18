local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "sunken_temple",
    name = "Temple of Atal'Hakkar / Sunken Temple",
    frameLayout = "wide",
    detection = {
            allowInInstance = true,
            instanceIDs = {
                109
            }
        },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "TheTempleofAtalhakkar",
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
        texturePrefix = "Interface\\Worldmap\\TheTempleofAtalhakkar\\TheTempleofAtalhakkar1_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_SunkenTemple.lua")
