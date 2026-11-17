local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,

    id = "wailing_caverns_approach",
    name = "Wailing Caverns Approach",

    detection = {
        -- This hidden map is for the non-instanced approach only.
        allowInInstance = false,
        requireIndoors = true,

        -- Known Classic Era aliases remain required in addition to indoor status.
        zoneAliases = {
            "Wailing Caverns",
            "The Wailing Caverns",
            "Cavern of Mists",
            "Caverns of Mists",
        },
    },

    position = {
        source = {
            uiMapID = 1413,
            name = "The Barrens",
        },

        transform = {
            type = "wmo_minimap",

            -- WoW live continent coordinates <-> wow.export ADT placement basis.
            clientWorldHalf = 17066.666666666668,

            -- wow.export ADT 36,33 placement for WailingCaverns.wmo.
            fileDataID = 109550,
            placement = {
                positionX = 19161.916015625,
                positionY = 87.65638732910156,
                positionZ = 17995.37109375,
                rotationY = 186,
                scale = 1,
            },

            -- wow.export WMO minimap metadata.
            minimap = {
                width = 871,
                height = 1011,
                pixelsPerUnit = 2,
                topLeftX = -65.49764251708984,
                topLeftY = -167.7774887084961,
                bottomRightX = -500.9462127685547,
                bottomRightY = 337.2889709472656,
            },
        },
    },

    -- Locked dev11 entranceCalibrationLog[6], GetServerTime 1791298227.
    -- Exact source coordinates and hover text from WildMaps(3).lua.
    markers = {
        {
            type = "entrance_exit",
            name = "Wailing Caverns Entrance",
            tooltip = "Wailing Caverns Entrance",
            showLabel = false,
            size = 18,
            texture = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Markers\\rfd_instance_entrance.tga",
            position = { space = "source_pixels", x = 205.7531485608767, y = 607.34260353504 },
        },
    },

    render = {
        -- Locked in-game calibration; offsets in the existing oriented artwork.
        presentationCrop = { left = 204, right = 39, top = 253, bottom = 71 },
        type = "tile_grid",

        -- Raw wow.export minimap dimensions.
        sourceWidth = 871,
        sourceHeight = 1011,

        -- Confirmed in-game orientation. DO NOT MODIFY without explicit retesting.
        displayRotationDegrees = 96.0,

        -- North-up development artwork dimensions after rotation.
        width = 1097,
        height = 973,

        tileSize = 256,
        columns = 5,
        rows = 4,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsApproach\\wc_north_",
    },
}, "Map_WailingCavernsApproach.lua")
