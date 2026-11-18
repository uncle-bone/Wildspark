local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "zul_farrak",
    name = "Zul'Farrak",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        instanceIDs = {
            209
        }
    },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "ZulFarrak",
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
        -- Zul'Farrak is one of Blizzard's older no-floor-prefix map sets:
        -- ZulFarrak1 ... ZulFarrak12 rather than ZulFarrak1_1 ... 1_12.
        texturePrefix = "Interface\\Worldmap\\ZulFarrak\\ZulFarrak",
        tileNaming = "blizzard_sequential",
    },
}, "Map_ZulFarrak.lua")
