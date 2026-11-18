local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "upper_blackrock_spire",
    name = "Upper Blackrock Spire",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        zoneAliases = {
            "Dragonspire Hall",
            "Hall of Binding",
            "Hall of Blackhand",
            "The Rookery",
            "Blackrock Stadium",
            "The Furnace",
            "Spire Throne",
            "Chamber of Battle"
        }
    },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "BlackrockSpire",
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
        texturePrefix = "Interface\\Worldmap\\BlackrockSpire\\BlackrockSpire7_",
        tileNaming = "blizzard_sequential",
    },
}, "Map_UpperBlackrockSpire.lua")
