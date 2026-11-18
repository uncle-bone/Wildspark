local _, addonNS = ...
local HM = addonNS.WildMaps

-- Artwork by Santiago Reyes — Atlas de Azeroth: Forever.
-- Used according to the creator's published usage guidelines:
-- https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever
-- Complete supplied image and embedded watermark preserved, without resizing.
-- Map.db2 ID 2998 is provenance only; runtime instanceID/UiMapID are unconfirmed.
HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "excavation_site_wetlands",
    name = "Excavation Site: Wetlands",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        instanceNames = { "Excavation Site: Wetlands" },
    },
    source = {
        sourceType = "third_party_artwork",
        artist = "Santiago Reyes",
        project = "Atlas de Azeroth: Forever",
        originalFile = "esw(1).jpg",
        originalSHA256 = "4ac4749f4a3e5fe19e26a93d6655b9bd78e776d0b0d8586bc2ae0dfdaf647c6f",
        mapDBID = 2998,
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
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\ExcavationSiteWetlands\\tile_",
        hideEdgeTreatment = true,
    },
}, "Map_ExcavationSiteWetlands.lua")
