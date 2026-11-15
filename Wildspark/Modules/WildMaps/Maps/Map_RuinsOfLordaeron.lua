local _, addonNS = ...
local HM = addonNS.WildMaps

-- Artwork by Santiago Reyes — Atlas de Azeroth: Forever.
-- Used according to the creator's published usage guidelines:
-- https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever
-- Complete supplied image and embedded watermark preserved, without resizing.
-- Map.db2 ID 2999 is provenance only; runtime instanceID/UiMapID are unconfirmed.
HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "ruins_of_lordaeron",
    name = "Ruins of Lordaeron",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        instanceNames = { "Ruins of Lordaeron" },
    },
    source = {
        sourceType = "third_party_artwork",
        artist = "Santiago Reyes",
        project = "Atlas de Azeroth: Forever",
        originalFile = "rol(1).jpg",
        originalSHA256 = "ab80800f505917814e20ac120f453e2a7433253e65830248a9fbb947b94b6240",
        mapDBID = 2999,
        usageGuidelines = "https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever",
    },
    artworkCredit = "Map by Santiago Reyes — Atlas de Azeroth: Forever",
    render = {
        type = "tile_grid",
        sourceWidth = 1600,
        sourceHeight = 1067,
        displayRotationDegrees = 0,
        width = 1600,
        height = 1067,
        tileSize = 256,
        columns = 7,
        rows = 5,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\RuinsOfLordaeron\\tile_",
        hideEdgeTreatment = true,
    },
}, "Map_RuinsOfLordaeron.lua")
