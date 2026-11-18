local _, addonNS = ...
local HM = addonNS.WildMaps

-- Candidate A: four navigational sections, not four measured Z-level floors.
-- Clean masters are baked exactly 90 degrees clockwise, with their 12-pixel
-- transparent margins intact. Render/source pixels below refer to that baked
-- artwork; no live player-position transform or additional rotation is applied.
HM.Registry:RegisterMap({
    schemaVersion = 1,
    id = "scholomance",
    name = "Scholomance",
    floorButtonAnchor = "BOTTOMRIGHT",
    detection = {
        allowInInstance = true,
        instanceIDs = {
            289
        }
    },
    source = {
        sourceType = "native_minimap_reconstruction",
        wmoID = 3293,
        sourcePackage = "Scholomance_Minimap_Reconstruction.zip",
        sourceDirectory = "A_FourSections/Masters/",
        bakedClockwiseDegrees = 90
    },
    render = {
        type = "tile_grid",
        sourceWidth = 486,
        sourceHeight = 783,
        displayRotationDegrees = 0,
        width = 486,
        height = 783,
        tileSize = 256,
        columns = 2,
        rows = 4,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\Scholomance\\main_halls_"
    },
    floors = {
        {
            name = "Main Halls",
            render = {
                type = "tile_grid",
                sourceWidth = 486,
                sourceHeight = 783,
                displayRotationDegrees = 0,
                width = 486,
                height = 783,
                tileSize = 256,
                columns = 2,
                rows = 4,
                texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\Scholomance\\main_halls_"
            }
        },
        {
            name = "Cellar",
            render = {
                type = "tile_grid",
                sourceWidth = 317,
                sourceHeight = 216,
                displayRotationDegrees = 0,
                width = 317,
                height = 216,
                tileSize = 256,
                columns = 2,
                rows = 1,
                texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\Scholomance\\cellar_"
            }
        },
        {
            name = "Upper Vaults",
            render = {
                type = "tile_grid",
                sourceWidth = 344,
                sourceHeight = 427,
                displayRotationDegrees = 0,
                width = 344,
                height = 427,
                tileSize = 256,
                columns = 2,
                rows = 2,
                texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\Scholomance\\upper_vaults_"
            }
        },
        {
            name = "Lower Vaults",
            render = {
                type = "tile_grid",
                sourceWidth = 274,
                sourceHeight = 393,
                displayRotationDegrees = 0,
                width = 274,
                height = 393,
                tileSize = 256,
                columns = 2,
                rows = 2,
                texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\Scholomance\\lower_vaults_"
            }
        }
    }
}, "Map_Scholomance.lua")
