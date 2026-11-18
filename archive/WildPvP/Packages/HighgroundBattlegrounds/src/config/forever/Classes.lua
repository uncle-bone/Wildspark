local _, ns = ...

-- WoW Forever class configuration. Forever runs the Midnight (retail) client
-- with its own game type ("camelot") and interface 16001, so Highground.toc
-- loads on it like on retail and every Midnight restriction applies: enemy
-- health, auras and casts are secret in a match, there is no combat log for
-- addons, and the scoreboard's talentSpec is only readable after the match.
-- What differs is the content: nine classes with three classic talent trees
-- each, level 60 battlegrounds (Warsong Gulch, Arathi Basin, Alterac Valley,
-- Darkspear Islands) and classic spells.
-- Sources: Gethe/wow-ui-source "forever" branch (generated API docs);
-- Osso/wow-ui-sim docs/wowforever-1.60.1-ui-api-deltas.md.
--
-- Highground.toc serves both retail and Forever, and the client reports
-- interface 16001 here (retail is 12xxxx): this file and
-- config/retail/Classes.lua each load only for their own game.
local build = type(GetBuildInfo) == "function" and select(4, GetBuildInfo())
ns.IS_FOREVER = type(build) == "number" and build < 100000
if not ns.IS_FOREVER then return end

ns.CLIENT = "retail" -- the Midnight API rules apply
ns.GAME = "forever"
ns.ClassIDs = { 1, 2, 3, 4, 5, 7, 8, 9, 11 } -- no Death Knight, Monk, Demon Hunter or Evoker

ns.Specs = {} -- filled from SpecsByIndex, like Cata's talent trees
ns.PreferSpecFallbacks = true -- trees by the fixed IDs below, named by the client

-- Talent trees in order, for clients whose spec APIs disagree with the
-- three-tree layout. { spec ID, name, role, icon, optional name alias }
ns.SpecFallbacks = {
  DRUID = {
    { 102, "Balance", "DAMAGER", 136096 },
    { 103, "Feral Combat", "DAMAGER", 132115, "Feral" },
    { 105, "Restoration", "HEALER", 136041 },
  },
  HUNTER = {
    { 253, "Beast Mastery", "DAMAGER", 461112 },
    { 254, "Marksmanship", "DAMAGER", 236179 },
    { 255, "Survival", "DAMAGER", 461113 },
  },
  MAGE = {
    { 62, "Arcane", "DAMAGER", 135932 },
    { 63, "Fire", "DAMAGER", 135810 },
    { 64, "Frost", "DAMAGER", 135846 },
  },
  PALADIN = {
    { 65, "Holy", "HEALER", 135920 },
    { 66, "Protection", "TANK", 236264 },
    { 70, "Retribution", "DAMAGER", 135873 },
  },
  PRIEST = {
    { 256, "Discipline", "HEALER", 135940 },
    { 257, "Holy", "HEALER", 237542 },
    { 258, "Shadow", "DAMAGER", 136207 },
  },
  ROGUE = {
    { 259, "Assassination", "DAMAGER", 236270 },
    { 260, "Combat", "DAMAGER", 236286 },
    { 261, "Subtlety", "DAMAGER", 132320 },
  },
  SHAMAN = {
    { 262, "Elemental", "DAMAGER", 136048 },
    { 263, "Enhancement", "DAMAGER", 237581 },
    { 264, "Restoration", "HEALER", 136052 },
  },
  WARLOCK = {
    { 265, "Affliction", "DAMAGER", 136145 },
    { 266, "Demonology", "DAMAGER", 136172 },
    { 267, "Destruction", "DAMAGER", 136186 },
  },
  WARRIOR = {
    { 71, "Arms", "DAMAGER", 132355 },
    { 72, "Fury", "DAMAGER", 132347 },
    { 73, "Protection", "TANK", 132341 },
  },
}

-- Per class, by talent-tree index. Ratings for level 60 battlegrounds:
-- k = how easy to kill (1-10), i = value of the kill; healers above 10.
ns.SpecsByIndex = {
  DRUID = {
    { short = "BAL", k = 6, i = 7, dmg = "magic", kite = true, note = "Roots and shifts; squishy in caster form" },
    { short = "FERAL", k = 5, i = 6, dmg = "phys", melee = true, note = "Shifts out of slows; flag runner" },
    { short = "RESTO", k = 3, i = 12, healer = true, dmg = "magic", kite = true, note = "Very hard to kill: HoTs, shifts. Kill only in CC" },
  },
  HUNTER = {
    { short = "BM", k = 5, i = 7, dmg = "phys", kite = true, note = "Bestial Wrath; pet pressure" },
    { short = "MM", k = 6, i = 8, dmg = "phys", kite = true, note = "Aimed Shot burst, Scatter Shot; squishy up close" },
    { short = "SURV", k = 5, i = 6, dmg = "phys", kite = true, note = "Traps, Deterrence" },
  },
  MAGE = {
    { short = "ARCANE", k = 7, i = 7, dmg = "magic", kite = true, note = "Presence of Mind burst; Ice Block" },
    { short = "FIRE", k = 7, i = 8, dmg = "magic", kite = true, note = "Squishy burst: Pyroblast, Combustion" },
    { short = "FROST", k = 5, i = 7, dmg = "magic", kite = true, note = "Ice Barrier, Ice Block, Cold Snap; slows everything" },
  },
  PALADIN = {
    { short = "HOLY", k = 3, i = 12, healer = true, dmg = "magic", note = "Plate + Divine Shield: kill after the bubble" },
    { short = "PROT", k = 2, i = 4, dmg = "magic", melee = true, note = "Tank: skip" },
    { short = "RET", k = 4, i = 7, dmg = "phys", melee = true, note = "Burst windows; bubble" },
  },
  PRIEST = {
    { short = "DISC", k = 4, i = 12, healer = true, dmg = "magic", note = "Shields and Power Infusion: hardest priest to kill" },
    { short = "HOLY", k = 6, i = 11, healer = true, dmg = "magic", note = "Big heals, squishier than Disc" },
    { short = "SHADOW", k = 5, i = 8, dmg = "magic", note = "Shadowform; Psychic Scream, Silence" },
  },
  ROGUE = {
    { short = "SIN", k = 5, i = 7, dmg = "phys", melee = true, note = "Cold Blood burst; Vanish, Evasion" },
    { short = "COMBAT", k = 6, i = 6, dmg = "phys", melee = true, note = "Adrenaline Rush, Blade Flurry; Evasion" },
    { short = "SUB", k = 4, i = 8, dmg = "phys", melee = true, note = "Preparation resets: double Vanish, Blind" },
  },
  SHAMAN = {
    { short = "ELE", k = 7, i = 8, dmg = "magic", note = "Squishy turret caster; Elemental Mastery burst" },
    { short = "ENH", k = 5, i = 7, dmg = "phys", melee = true, note = "Windfury burst; shocks" },
    { short = "RESTO", k = 5, i = 11, healer = true, dmg = "magic", note = "Nature's Swiftness, totems, Purge" },
  },
  WARLOCK = {
    { short = "AFF", k = 5, i = 8, dmg = "magic", note = "DoTs, fears, Death Coil; drains keep it alive" },
    { short = "DEMO", k = 4, i = 7, dmg = "magic", note = "Soul Link: tankiest warlock" },
    { short = "DESTRO", k = 7, i = 8, dmg = "magic", note = "Squishy turret: Shadowburn, Conflagrate burst" },
  },
  WARRIOR = {
    { short = "ARMS", k = 4, i = 8, dmg = "phys", melee = true, note = "Mortal Strike: cuts healing" },
    { short = "FURY", k = 5, i = 7, dmg = "phys", melee = true, note = "Death Wish burst; squishier than Arms" },
    { short = "PROT", k = 2, i = 4, dmg = "phys", melee = true, note = "Tank: skip" },
  },
}

-- No hand-tuned matchups yet: the generic phys/magic/melee rules apply.
ns.Matchups = {}

-- Classic spell ranges. A spell you don't know answers nil and is skipped.
ns.RangeBands = {
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 78, 1715 } }, -- Pummel, Mortal Strike, Bloodthirst, Heroic Strike, Hamstring
    { 25, { 100, 20252 } }, -- Charge, Intercept
  } },
  PALADIN = { attackYards = 5, reachYards = 10, bands = {
    { 5, { 20271 } }, -- Judgement
    { 10, { 853 } }, -- Hammer of Justice
  } },
  ROGUE = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 1766, 1752, 53, 1776, 16511 } }, -- Kick, Sinister Strike, Backstab, Gouge, Hemorrhage
    { 10, { 2094 } }, -- Blind
    { 30, { 2764 } }, -- Throw
  } },
  DRUID = { attackYards = 30, reachYards = 30, bands = {
    { 5, { 1082, 5221, 6807 } }, -- Claw, Shred, Maul
    { 30, { 5176, 8921, 339 } }, -- Wrath, Moonfire, Entangling Roots
  } },
  SHAMAN = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 8042, 8056, 8050 } }, -- Earth, Frost, Flame Shock
    { 30, { 403, 370 } }, -- Lightning Bolt, Purge
  } },
  HUNTER = { attackYards = 35, reachYards = 35, bands = {
    { 5, { 2973, 2974 } }, -- Raptor Strike, Wing Clip
    { 35, { 3044, 1978, 5116, 19503 } }, -- Arcane Shot, Serpent Sting, Concussive Shot, Scatter Shot (15)
  } },
  MAGE = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 2136, 2139 } }, -- Fire Blast, Counterspell
    { 30, { 116, 133, 118 } }, -- Frostbolt, Fireball, Polymorph
  } },
  WARLOCK = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 5782, 6789 } }, -- Fear, Death Coil
    { 30, { 686, 172, 348 } }, -- Shadow Bolt, Corruption, Immolate
  } },
  PRIEST = { attackYards = 30, reachYards = 30, bands = {
    { 20, { 15407, 15487 } }, -- Mind Flay, Silence
    { 30, { 589, 585, 8092 } }, -- Shadow Word: Pain, Smite, Mind Blast
  } },
}

-- Melee trees of caster classes must not count a ranged spell as in reach.
ns.SpecsByIndex.DRUID[2].range = { attackYards = 5, reachYards = 25 }
ns.SpecsByIndex.SHAMAN[2].range = { attackYards = 5, reachYards = 20 }

ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 15, 22 }, { 20, 18 }, { 25, 16 }, { 30, 14 }, { 40, 8 },
}
