local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Racial traits that change which gear is best, keyed by race id. Hand-written
-- from Blizzard's Forever development notes (last: the racial pass of 26 Oct);
-- Data/Tables.lua's trait text (ns.Races[..].traits) comes from Wowhead and lags.
-- Check them again when Blizzard changes racials.
--
--   weaponCrit: +pct% crit with spells and attacks while a weapon of one of these
--               subclasses is equipped (0/1 axe, 4/5 mace, 7/8 sword); spell = the trait's
--               spell id (its name in the game's language). No race has one since the
--               15 Oct beta build turned the weapon specializations into flat bonuses.
--   statMult:   multiplies an item stat's value (e.g. +10% Spirit)
--
-- Flat bonuses that don't depend on gear (Human Ruthless +1% crit, Dwarf Artisan's
-- Precision +1% hit, Tauren Endurance +5% health, Night Elf +1% dodge, Skyborne
-- +2% haste, Orc Command pet damage, slayer damage) don't change rankings and are
-- left out.
ns.Racials = {
    [1] = { -- Human
        statMult = { spi = 1.10 }, -- The Human Spirit
    },
    [7] = { -- Gnome: Expansive Mind, +5% max mana
        statMult = { int = 1.05 },
    },
}
