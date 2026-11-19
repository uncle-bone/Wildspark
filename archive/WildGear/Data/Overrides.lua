local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Manual fixes applied on top of the generated Items.lua (which is overwritten
-- by every scraper run). Use this for items Wowhead lists as "source unknown".
--
--   [12345] = { sources = { { type = "quest", id = 999, name = "Some Quest", side = 3 } } },
--   [23456] = false, -- hide an item entirely
--
-- A table replaces the listed fields; a new id adds a whole item record
-- (same shape as Items.lua).
ns.Overrides = {
    -- Equip stats the in-game scan missed: its tooltip read came before the game had
    -- loaded the item's equip spell, so the line wasn't there, and the scan's stats
    -- win. Values from Wowhead's Forever tooltips (2026-11-17).
    [13965] = { stats = { critPct = 1 } },                                   -- Blackhand's Breadth
    [11121] = { stats = { atkpwr = 6 } },                                    -- Darkwater Talwar
    [18354] = { stats = { firsplpwr = 14, manargn = 9 } },                   -- Pimgib's Collar
    [18472] = { stats = { natres = 15, splheal = 22, spldmg = 7, manargn = 9 } }, -- Royal Seal of Eldre'Thalas
    [279892] = { stats = { armor = 37, int = 10, splheal = 14, spldmg = 5, manargn = 4 } }, -- Wisdom of Ursol
}
