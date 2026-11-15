local _, addonNS = ...
local HM = addonNS.WildMaps

-- Artwork by Santiago Reyes — Atlas de Azeroth: Forever.
-- Used according to the creator's published usage guidelines:
-- https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever
-- Complete supplied image and embedded watermark preserved, without resizing.
-- Map.db2 ID 3065 is provenance only; runtime instanceID/UiMapID are unconfirmed.
HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "hall_of_thanes",
    name = "The Hall of Thanes",
    frameLayout = "wide",
    detection = {
        allowInInstance = true,
        instanceNames = { "The Hall of Thanes", "Hall of Thanes" },
    },
    source = {
        sourceType = "third_party_artwork",
        artist = "Santiago Reyes",
        project = "Atlas de Azeroth: Forever",
        originalFile = "hot(1).jpg",
        originalSHA256 = "d0f5c3590e9f2bddaebe3447f921ae49cf0212d97c2651861de3847ab275bebd",
        mapDBID = 3065,
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
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\HallOfThanes\\tile_",
        hideEdgeTreatment = true,
    },
}, "Map_HallOfThanes.lua")
