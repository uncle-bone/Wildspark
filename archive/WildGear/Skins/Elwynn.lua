local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Elwynn Forest: an oak frame, brass-capped wooden buttons and an oak-leaf
-- emblem, with a forest painting behind the selectors and forest floor under
-- the lists (Theme.lua, T.RegisterSkin). All made for the addon (their
-- sources and prompts: skins\Elwynn, made into textures by tools\skinart.py).

local MEDIA = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\Elwynn\\"

ns.Theme.RegisterSkin("elwynn", {
    name = ns.L["Elwynn Forest"],
    accent = { 0.56, 0.82, 0.31 },
    band = { file = MEDIA .. "Band", y = 0.55, top = 0.5, bottom = 0.68 },
    floor = { file = MEDIA .. "Floor", tile = 320, dim = 0.4 },
    -- (the frame's art, 1231 x 1188 texels: its title bar 148 down, its
    -- corners' brackets 95 across, 195 down on top and 100 at the bottom, its
    -- sides 57 across; the bar's carving ends 235 in)
    frame = { file = MEDIA .. "Frame", size = { 1231, 1188 }, side = 95, top = 195, bottom = 100, edge = 235,
        bar = 148, scale = 0.2, rail = 12,
        railH = { file = MEDIA .. "RailH", size = 13 }, railV = { file = MEDIA .. "RailV", size = 12 } },
    -- (the frame's title bar past its carving, 920 x 134 texels)
    bar = { file = MEDIA .. "Bar", size = { 920, 134 }, dim = 0.55 },
    -- (each button's brass ends are 19 of its 256 texels across)
    button = { file = MEDIA .. "Button", hover = MEDIA .. "ButtonHover", glow = MEDIA .. "ButtonGlow",
        down = MEDIA .. "ButtonDown", size = { 256, 64 }, cap = 19, capWidth = 8 },
    close = { file = MEDIA .. "Close", size = { 26, 23 } },
    -- (the buttons' brass, and their pressed wood's middle)
    bubble = { rim = { 0.72, 0.56, 0.28 }, fill = { 0.22, 0.14, 0.08 } },
    -- (an oak wedge with a brass tip, its foot fading out across the 13-pixel
    -- rail; kept clear of the 20-pixel corner brackets)
    pointer = { file = MEDIA .. "Pointer", size = { 40, 22 }, depth = 10, inset = 36 },
    icons = { down = MEDIA .. "IconDown", up = MEDIA .. "IconUp", plus = MEDIA .. "IconPlus",
        minus = MEDIA .. "IconMinus" },
    -- (the switches: the buttons' wood, drawn size across and down with
    -- capWidth of brass at each end, and a brass stud of the icon buttons)
    toggle = { size = { 30, 12 }, capWidth = 4, knob = { file = MEDIA .. "Knob", size = 15 } },
    emblem = { file = MEDIA .. "Emblem", size = 46, small = MEDIA .. "EmblemSmall" },
    vine = { file = MEDIA .. "Vine", size = 120 },
    -- (on the floor: Riverpaw gnoll tracks, a miner's pickaxe and the kobolds'
    -- candles, a Defias bandana, a pouch of gold dust, a lantern)
    decals = { files = { MEDIA .. "Decal1", MEDIA .. "Decal2", MEDIA .. "Decal3", MEDIA .. "Decal4",
        MEDIA .. "Decal5", MEDIA .. "Decal6" }, count = 3, size = 64,
        -- (the candles' three wick tips, measured on the sheet's 512-texel
        -- cell; the flame is world/expansion07/doodads/fx/8fx_candleflame.m2,
        -- a first try, to tune with /wildgear fx flame)
        flame = { model = 1958358, box = { 24, 36 }, zoom = 1.5, alpha = 0.85, glow = MEDIA .. "Glow", glowAlpha = 0.14,
            wicks = { [3] = { { 0.355, 0.132 }, { 0.632, 0.303 }, { 0.454, 0.493 } } } } },
    leaves = { files = { MEDIA .. "Leaf1", MEDIA .. "Leaf2", MEDIA .. "Leaf3", MEDIA .. "Leaf4" }, count = 10,
        size = 18, alpha = 0.8 },
    check = { file = MEDIA .. "Leaf1", tilt = 45 }, -- (a green leaf marks the pick in a list, leaning right)
    -- (the wish list's star: an oak leaf, filled and its outline;
    -- skins\Elwynn\WishLeaf-prompts.md)
    star = { on = MEDIA .. "WishLeaf", off = MEDIA .. "WishLeafEmpty" },
    -- (Tanaan Jungle's light ray, world/expansion05/.../6tj_lightray01.m2;
    -- a first try, tuned with /wildgear fx light)
    light = { model = 1018016, zoom = 1, alpha = 0.6 },
    -- Harvest, for Thanksgiving (on in this version; a later one drops it):
    -- autumn leaves, a harvest garland, harvest things on the floor (a
    -- turkey's tracks and feathers, corn, a pumpkin, gourds, wheat), and the
    -- turkey itself wandering on the bottom bar. A switch there turns it off.
    seasons = {
        { key = "harvest", name = ns.L["Harvest"], art = {
            emblem = { file = MEDIA .. "HarvestEmblem", size = 46, small = MEDIA .. "HarvestEmblemSmall" }, -- (autumn oak frame, red-brown)
            leaves = { files = { MEDIA .. "HarvestLeaf1", MEDIA .. "HarvestLeaf2", MEDIA .. "HarvestLeaf3",
                MEDIA .. "HarvestLeaf4" }, count = 10, size = 18, alpha = 0.85 },
            check = { file = MEDIA .. "HarvestLeaf3", tilt = 45 },
            star = { on = MEDIA .. "HarvestWishLeaf", off = MEDIA .. "HarvestWishLeafEmpty" }, -- (a maple leaf)
            vine = { file = MEDIA .. "HarvestVine", size = 120 },
            decals = { files = { MEDIA .. "HarvestDecal1", MEDIA .. "HarvestDecal2", MEDIA .. "HarvestDecal3",
                MEDIA .. "HarvestDecal4", MEDIA .. "HarvestDecal5", MEDIA .. "HarvestDecal6" }, count = 3, size = 64 },
            -- (the game's turkey, creature/turkey/turkey.m2, and its call;
            -- the painted one if the model doesn't load)
            walker = { model = 126278, sound = 562924, box = { 70, 56 }, zoom = 1, facing = -1.2,
                file = MEDIA .. "Turkey", size = 46, speed = 14, trot = 70, run = 170 },
        } },
    },
})
