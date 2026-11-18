local _, addonNS = ...
local HM = addonNS.WildMaps

local function floorRender(page)
    return {
        type = "tile_grid",
        sourceWidth = 1024,
        sourceHeight = 768,
        displayRotationDegrees = 0,
        width = 1024,
        height = 768,
        tileSize = 256,
        columns = 4,
        rows = 3,
        texturePrefix = "Interface\\Worldmap\\BlackrockSpire\\BlackrockSpire" .. page .. "_",
        tileNaming = "blizzard_sequential",
    }
end

HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "lower_blackrock_spire",
    name = "Lower Blackrock Spire",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        zoneAliases = {
            "Hordemar City",
            "Skitterweb Tunnels",
            "Tazz'Alaor",
            "Halycon's Lair",
            "Mok'Doom",
            "The Storehouse"
        }
    },
    source = {
        sourceType = "blizzard_worldmap",
        folder = "BlackrockSpire",
    },
    render = floorRender(1),
    floors = {
        { name = "Lower Blackrock Spire 1", render = floorRender(1) },
        { name = "Lower Blackrock Spire 2", render = floorRender(2) },
        { name = "Lower Blackrock Spire 3", render = floorRender(3) },
        { name = "Lower Blackrock Spire 4", render = floorRender(4) },
        { name = "Lower Blackrock Spire 5", render = floorRender(5) },
        { name = "Lower Blackrock Spire 6", render = floorRender(6) },
    },
}, "Map_LowerBlackrockSpire.lua")
