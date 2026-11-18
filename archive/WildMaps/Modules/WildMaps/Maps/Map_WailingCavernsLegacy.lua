local _, addonNS = ...
local HM = addonNS.WildMaps

HM.Registry:RegisterMap({
    schemaVersion = 1,

    id = "wailing_caverns_instance_legacy",
    name = "Wailing Caverns (legacy WMO localisation)",
    hiddenDiagnostic = true,

    detection = {
        allowInInstance = true,
        zoneAliases = {
            "__WildMaps WC WMO Legacy__",
        },
    },

    -- No position block yet. Accurate in-instance player localization remains
    -- a research problem; the renderer will intentionally show no marker.

    source = {
        mapID = 43,
        wmoID = 1143,
        fileDataID = 109567,
        pixelsPerUnit = 2,

        minimap = {
            width = 1517,
            height = 2094,
            topLeftX = 187.50392150878906,
            topLeftY = -492.38482666015625,
            bottomRightX = -570.5714263916016,
            bottomRightY = 554.3612060546875,
            minZ = -194.91378784179688,
            maxZ = 56.4967155456543,
        },

        -- Global-WMO placement supplied by wow.export for map 43.
        modf = {
            positionX = 0,
            positionY = 0,
            positionZ = 0,
            rotationX = 0,
            rotationY = 0,
            rotationZ = 0,
            scale = 1024,
        },
    },

    render = {
        type = "tile_grid",

        -- User-confirmed in-game orientation.
        -- The raw wow.export image must be rotated 90 degrees clockwise.
        sourceWidth = 1517,
        sourceHeight = 2094,
        displayRotationDegrees = -90,

        width = 2094,
        height = 1517,

        tileSize = 256,
        columns = 9,
        rows = 6,
        texturePrefix = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\wc_instance_",
    },
}, "Map_WailingCavernsLegacy.lua")
