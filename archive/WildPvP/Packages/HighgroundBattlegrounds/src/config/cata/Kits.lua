local _, ns = ...

-- Class kits: the cooldowns that decide a kill, tracked per enemy from the
-- combat log (cast -> down for `cd` seconds). There is no API to read an
-- enemy's cooldowns, so timers assume base Cata values: talents/glyphs that
-- shorten a cooldown make "down" end a little early in reality.
--   { spellId, cd, kind, label, spec = talent-tree index, alt = { other IDs
--     the same ability shows up as }, resets = { IDs it brings back } }
--   vs = "phys"/"magic": only answers that damage; scores nothing when it
--   can't touch your damage and half when you deal mixed damage
-- kind: trinket / immune / def / external / interrupt / cc / burst
--   mark = burst marker default while its buff is on an enemy (Burst
--   markers page): "auto" = PURGE when you can remove it, else CC;
--   "purge" = only when you can remove it (team buffs like Bloodlust, where
--   CC misses the point); "cc"; "off" (too short, consumed instantly, or
--   the buff makes them immune to CC). No mark = no buff to see.
-- Chosen per class: the cooldowns whose absence opens a kill or whose use
-- swings a fight. Big defensives (Anti-Magic Shell and Icebound Fortitude
-- leave a Death Knight exposed), offensive cooldowns, and crowd control or
-- silences on a long cooldown (Blind, Hammer of Justice, Strangulate). Kicks,
-- short CC, escapes and utility come back too often to be worth showing.
-- Scoring: trinket +8, immune +14, def +6 while down; the rest is shown.
ns.KitCommon = {
  { 42292, 120, "trinket", "Trinket", alt = { 59752 } }, -- PvP trinket; Every Man for Himself
}
ns.Kits = {
  ROGUE = {
    { 31224, 90, "immune", "Cloak", vs = "magic" },
    { 5277, 180, "def", "Evasion", vs = "phys" },
    { 1856, 120, "def", "Vanish", alt = { 11327 } },
    { 74001, 120, "def", "Combat Readiness", vs = "phys" },
    { 2094, 180, "cc", "Blind" },
    { 76577, 180, "cc", "Smoke Bomb" },
    { 14185, 300, "burst", "Preparation", spec = 3, resets = { 1856, 5277, 2983, 36554, 51722 } },
    { 51713, 60, "burst", "Shadow Dance", spec = 3, mark = "auto" },
    { 13750, 180, "burst", "Adrenaline Rush", spec = 2, mark = "auto" },
    { 51690, 120, "burst", "Killing Spree", spec = 2, mark = "off" },
    { 79140, 120, "burst", "Vendetta", spec = 1 },
  },
  MAGE = {
    { 45438, 300, "immune", "Ice Block" },
    { 87023, 60, "immune", "Cauterize", spec = 2 }, -- "Cauterized" debuff = the death save fired
    { 55342, 180, "def", "Mirror Image" },
    { 66, 180, "def", "Invisibility", alt = { 32612 } },
    { 82676, 120, "cc", "Ring of Frost" },
    { 11958, 480, "def", "Cold Snap", spec = 3, resets = { 45438, 11426, 122, 44572, 12472 } },
    { 12472, 180, "burst", "Icy Veins", spec = 3, mark = "auto" },
    { 11129, 120, "burst", "Combustion", spec = 2 },
    { 12042, 84, "burst", "Arcane Power", spec = 1, mark = "auto" },
    { 12043, 120, "burst", "Presence of Mind", spec = 1, mark = "off" },
    { 80353, 300, "burst", "Time Warp", mark = "purge" },
  },
  PRIEST = {
    { 47585, 120, "immune", "Dispersion", spec = 3 },
    { 33206, 180, "external", "Pain Suppression", spec = 1 },
    { 47788, 180, "external", "Guardian Spirit", spec = 2 },
    { 62618, 180, "external", "Barrier", spec = 1, alt = { 81782 } },
    { 19236, 120, "def", "Desperate Prayer" },
    { 64044, 120, "cc", "Psychic Horror", spec = 3 },
    { 10060, 120, "burst", "Power Infusion", spec = 1, mark = "purge" },
    { 34433, 300, "burst", "Shadowfiend" },
  },
  PALADIN = {
    { 642, 300, "immune", "Bubble" },
    { 1022, 300, "external", "Hand of Protection" },
    { 6940, 120, "external", "Sacrifice" },
    { 498, 60, "def", "Divine Protection" },
    { 31850, 180, "def", "Ardent Defender", spec = 2 },
    { 86150, 300, "def", "Ancient Kings", alt = { 86659, 86669, 86698 } },
    { 633, 600, "def", "Lay on Hands" },
    { 31821, 120, "external", "Aura Mastery", spec = 1 },
    { 853, 60, "cc", "Hammer of Justice" },
    { 20066, 60, "cc", "Repentance", spec = 3 },
    { 31884, 180, "burst", "Wings", mark = "auto" },
    { 85696, 120, "burst", "Zealotry", spec = 3, mark = "auto" },
    { 31842, 180, "burst", "Divine Favor", spec = 1, mark = "purge" },
  },
  WARRIOR = {
    { 871, 300, "def", "Shield Wall" },
    { 55694, 180, "def", "Enraged Regen" },
    { 23920, 25, "def", "Spell Reflect", vs = "magic" },
    { 12975, 180, "def", "Last Stand", spec = 3 },
    { 5246, 120, "cc", "Intimidating Shout" },
    { 676, 60, "cc", "Disarm" },
    { 46924, 90, "burst", "Bladestorm", spec = 1, mark = "off" },
    { 85730, 120, "burst", "Deadly Calm", spec = 1, mark = "off" },
    { 12292, 180, "burst", "Death Wish", spec = 2, mark = "auto" },
    { 1719, 300, "burst", "Recklessness", mark = "auto" },
  },
  DEATHKNIGHT = {
    { 48707, 45, "def", "AMS", vs = "magic" },
    { 48792, 180, "def", "Icebound" },
    { 49039, 120, "def", "Lichborne" },
    { 51052, 120, "external", "AMZ", spec = 3, alt = { 50461 } },
    { 47476, 120, "interrupt", "Strangulate" },
    { 49203, 60, "cc", "Hungering Cold", spec = 2 },
    { 51271, 60, "burst", "Pillar of Frost", spec = 2, mark = "auto" },
    { 49206, 180, "burst", "Gargoyle", spec = 3 },
    { 49016, 180, "burst", "Unholy Frenzy", spec = 3, mark = "auto" },
  },
  HUNTER = {
    { 19263, 120, "immune", "Deterrence" },
    { 19386, 60, "cc", "Wyvern Sting", spec = 3 },
    { 19577, 60, "cc", "Intimidation", spec = 1 },
    { 3045, 300, "burst", "Rapid Fire", mark = "auto" },
    { 19574, 120, "burst", "Bestial Wrath", spec = 1, mark = "off" },
    { 23989, 180, "burst", "Readiness", spec = 2, resets = { 19263, 5384, 781, 34490, 19503, 1499, 3045, 51753 } },
  },
  DRUID = {
    { 22812, 60, "def", "Barkskin" },
    { 61336, 180, "def", "Survival Instincts", spec = 2 },
    { 22842, 180, "def", "Frenzied Regen", spec = 2 },
    { 78675, 60, "interrupt", "Solar Beam", spec = 1 },
    { 5211, 60, "cc", "Bash" },
    { 17116, 180, "burst", "Nature's Swiftness", spec = 3 },
    { 33891, 180, "burst", "Tree of Life", spec = 3, mark = "auto" },
    { 740, 480, "burst", "Tranquility" },
    { 48505, 90, "burst", "Starfall", spec = 1, mark = "auto" },
    { 50334, 180, "burst", "Berserk", spec = 2, mark = "auto" },
    { 29166, 180, "burst", "Innervate", mark = "purge" },
  },
  SHAMAN = {
    { 30823, 60, "def", "Shamanistic Rage", spec = 2 },
    { 98008, 180, "external", "Spirit Link", spec = 3 },
    { 16188, 120, "burst", "Nature's Swiftness", spec = 3 },
    { 16166, 180, "burst", "Elemental Mastery", spec = 1, mark = "auto" },
    { 51533, 120, "burst", "Feral Spirit", spec = 2 },
    { 16190, 180, "burst", "Mana Tide", spec = 3 },
    { 2825, 300, "burst", "Bloodlust", alt = { 32182 }, mark = "purge" },
  },
  WARLOCK = {
    { 6789, 120, "cc", "Death Coil" },
    { 47241, 180, "burst", "Metamorphosis", spec = 2, mark = "auto" },
    { 77801, 120, "burst", "Demon Soul", alt = { 79460, 79462, 79463, 79464 }, mark = "auto" },
  },
}

-- Cast-bar spells worth interrupting on healers are simply "any heal cast";
-- these channels/casts are flagged as top-priority kicks anywhere.
ns.KickPriority = {
  [2060] = true, [2061] = true, [2050] = true, [596] = true, [64843] = true, [32546] = true, -- priest heals, Divine Hymn, Binding Heal
  [82326] = true, [635] = true, [19750] = true, [82327] = true, -- Divine Light, Holy Light, Flash of Light, Holy Radiance
  [77472] = true, [8004] = true, [331] = true, [1064] = true, -- Greater Healing Wave, Healing Surge, Healing Wave, Chain Heal
  [50464] = true, [5185] = true, [8936] = true, [740] = true, -- Nourish, Healing Touch, Regrowth, Tranquility
  [118] = true, [51514] = true, [5782] = true, [33786] = true, [605] = true, -- Polymorph, Hex, Fear, Cyclone, Mind Control
  [50796] = true, [48181] = true, -- Chaos Bolt, Haunt
}
