local _, ns = ...

ns.CLIENT = "cata"
-- Class IDs have a gap: Cata has no monk (10), but druids are still 11.
ns.ClassIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

-- Cataclysm Classic (4.4.2) class configuration.
-- Loaded only by Highground_Cata.toc, independently of Retail class data.
--
-- What 4.4.2 gives an addon that Midnight doesn't (no secret values):
--   * scoreboard talentSpec is readable LIVE when the server supplies it
--   * enemy UnitHealth / UnitHealthMax are plain -> health + gear can score
--   * the combat log exists -> enemy defensive cooldowns can be tracked
--   * auras carry spellIds -> defensives / CC / burst come from spell lists
--     below instead of retail's BIG_DEFENSIVE / CROWD_CONTROL filters
-- Not in 4.4.2: C_UnitAuras.GetUnitAuras, C_PvP.GetScoreInfo, /ping,
-- UnitHealthPercent / color curves.

ns.Specs = {} -- filled from SpecsByIndex using client metadata or the fallback below

-- Cata clients may omit the specialization enumeration APIs. Keep a complete
-- catalog in talent-tree order so scoreboard names and the player's selected
-- tree still resolve to a profile. Client metadata supplies localized names
-- when available; these English names remain aliases for custom scoreboards.
-- { stable spec ID, name, role, icon, optional name alias }
-- IDs/icons: https://github.com/ascott18/TellMeWhen/blob/master/Components/Core/Utils.lua
-- Cata keeps Combat, one Feral tree, and Blood's tank role.
ns.SpecFallbacks = {
  DEATHKNIGHT = {
    { 250, "Blood", "TANK", 135770 },
    { 251, "Frost", "DAMAGER", 135773 },
    { 252, "Unholy", "DAMAGER", 135775 },
  },
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

-- Personal, spec-specific helpful auras only. Shared buffs, Earth Shield,
-- Power Infusion, stances, seals, and ordinary cat/bear forms prove no spec.
-- Entries are { talent-tree index, evidence label }; never treat a recipient
-- of an external defensive as its caster. Existing kit IDs are listed below;
-- form/Bone Shield references: https://github.com/wowsims/cata/tree/master/sim
ns.SpecInferenceConfig = {
  auras = {
    DEATHKNIGHT = { [49222] = { 1, "Bone Shield" }, [51271] = { 2, "Pillar of Frost" } },
    DRUID = { [24858] = { 1, "Moonkin Form" }, [50334] = { 2, "Berserk" },
      [61336] = { 2, "Survival Instincts" }, [33891] = { 3, "Tree of Life" } },
    MAGE = { [12042] = { 1, "Arcane Power" }, [11426] = { 3, "Ice Barrier" },
      [12472] = { 3, "Icy Veins" } },
    PALADIN = { [31842] = { 1, "Divine Favor" }, [31850] = { 2, "Ardent Defender" },
      [85696] = { 3, "Zealotry" } },
    PRIEST = { [15473] = { 3, "Shadowform" }, [47585] = { 3, "Dispersion" } },
    ROGUE = { [13750] = { 2, "Adrenaline Rush" }, [51713] = { 3, "Shadow Dance" } },
    SHAMAN = { [30823] = { 2, "Shamanistic Rage" } },
    WARLOCK = { [47241] = { 2, "Metamorphosis" }, [91711] = { 3, "Nether Ward" } },
    WARRIOR = { [46924] = { 1, "Bladestorm" }, [12292] = { 2, "Death Wish" },
      [12975] = { 3, "Last Stand" } },
  },
  mana = { minSamples = 3, sampleLimit = 30, tolerance = 0.10, observationSeconds = 10 },
}

-- Per class, by talent-tree index, independent of the client's spec IDs.
-- Ratings tuned for Cataclysm (4.4) battlegrounds. range optionally overrides
-- the class attackYards/reachYards/bands for this talent tree.
-- dmg "mixed": a large share of both physical and magic damage (Templar's
-- Verdict + Holy, Stormstrike + shocks, Obliterate + Frost Strike, Explosive
-- Shot + autos); phys- and magic-only answers each count half.
-- Healer impact sits above the 0-10 DPS band: each killability point is worth
-- 1.5 impact points, so tanky healers need i > 10 to rank with squishy casters.
ns.SpecsByIndex = {
  DEATHKNIGHT = {
    { short = "BLOOD", k = 2, i = 3, dmg = "magic", melee = true, magDR = true, note = "Tank: skip unless isolated" },
    { short = "FROST", k = 4, i = 7, dmg = "mixed", melee = true, magDR = true, note = "Bait IBF/AMS; Lichborne vs fear" },
    { short = "UNHOLY", k = 4, i = 8, dmg = "magic", melee = true, magDR = true, note = "Gargoyle burst; bait AMS + IBF" },
  },
  DRUID = {
    { short = "BAL", k = 6, i = 7, dmg = "magic", kite = true, note = "Barkskin; Starfall burst" },
    { short = "FERAL", k = 5, i = 7, dmg = "phys", melee = true, note = "Survival Instincts, stealth resets" },
    { short = "RESTO", k = 3, i = 12, healer = true, dmg = "magic", kite = true, note = "Very hard to kill: HoTs, shifts. Kill only in CC" },
  },
  HUNTER = {
    { short = "BM", k = 5, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Bestial Wrath; Deterrence" },
    { short = "MM", k = 6, i = 7, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Squishiest hunter (no pet tanking); Deterrence, Silencing Shot" },
    { short = "SURV", k = 5, i = 6, dmg = "mixed", kite = true, physDR = true, magDR = true, note = "Deterrence, traps" },
  },
  MAGE = {
    { short = "ARCANE", k = 8, i = 6, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Squishiest mage: no Ice Barrier, no Cauterize, no Cold Snap. Ice Block + Blink only" },
    { short = "FIRE", k = 6, i = 8, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Cauterize = 2nd life after Ice Block; Combustion burst" },
    { short = "FROST", k = 4, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Tankiest mage: Ice Barrier, Cold Snap = 2nd Ice Block, Deep Freeze peel" },
  },
  PALADIN = {
    { short = "HOLY", k = 3, i = 12, healer = true, dmg = "magic", physDR = true, magDR = true, note = "Plate + bubble: kill after Divine Shield" },
    { short = "PROT", k = 2, i = 4, dmg = "magic", melee = true, note = "Tank: skip" },
    { short = "RET", k = 4, i = 8, dmg = "mixed", melee = true, physDR = true, magDR = true, note = "Zealotry/Wings burst; bubble" },
  },
  PRIEST = {
    { short = "DISC", k = 4, i = 12, healer = true, dmg = "magic", note = "Shields + Pain Suppression: hardest priest to kill; top BG healer" },
    { short = "HOLY", k = 6, i = 10, healer = true, dmg = "magic", note = "Guardian Spirit; Spirit of Redemption" },
    { short = "SHADOW", k = 5, i = 8, dmg = "magic", magDR = true, note = "Dispersion (bait it)" },
  },
  ROGUE = {
    { short = "SIN", k = 5, i = 7, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Cloak vs magic, Evasion vs phys" },
    { short = "COMBAT", k = 6, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Fewest escapes of the rogues; Killing Spree, Cloak/Evasion" },
    { short = "SUB", k = 4, i = 8, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Slipperiest rogue: Vanish/Preparation resets, Shadowstep" },
  },
  SHAMAN = {
    { short = "ELE", k = 7, i = 7, dmg = "magic", note = "Squishy turret caster; Thunderstorm knockback" },
    { short = "ENH", k = 5, i = 7, dmg = "mixed", melee = true, note = "Shamanistic Rage, wolves" },
    { short = "RESTO", k = 5, i = 11, healer = true, dmg = "magic", note = "Spirit Link, Nature's Swiftness, grounding" },
  },
  WARLOCK = {
    { short = "AFF", k = 5, i = 8, dmg = "magic", note = "Self-heals (Drain Life, Fel Armor); DoT pressure, fears" },
    { short = "DEMO", k = 4, i = 7, dmg = "magic", note = "Tankiest lock: Soul Link, Metamorphosis armor" },
    { short = "DESTRO", k = 7, i = 8, dmg = "magic", note = "Squishiest lock: turret caster; Chaos Bolt burst, Nether Ward" },
  },
  WARRIOR = {
    { short = "ARMS", k = 4, i = 8, dmg = "phys", melee = true, note = "Bladestorm (CC immune); Shield Wall" },
    { short = "FURY", k = 5, i = 7, dmg = "phys", melee = true, note = "Squishier than Arms (no Bladestorm); Enraged Regeneration" },
    { short = "PROT", k = 2, i = 4, dmg = "phys", melee = true, note = "Tank: skip" },
  },
}

-- No hand-tuned matchups for Cata yet: the generic phys/magic/melee rules apply.
ns.Matchups = {}

-- Cata spell ranges. A spell you don't know answers nil and is skipped.
ns.RangeBands = {
  DEATHKNIGHT = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 49143, 49020, 55050, 55090, 45462, 47528 } }, -- Frost/Heart/Scourge/Plague Strike, Obliterate, Mind Freeze
    { 20, { 45524, 45477 } }, -- Chains of Ice, Icy Touch
    { 30, { 49576, 47476, 47541 } }, -- Death Grip, Strangulate, Death Coil
  } },
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 1464, 78 } }, -- Pummel, Mortal Strike, Bloodthirst, Slam, Heroic Strike
    { 25, { 100, 20252 } }, -- Charge, Intercept
    { 30, { 57755 } }, -- Heroic Throw
  } },
  PALADIN = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 35395, 96231, 85256 } }, -- Crusader Strike, Rebuke, Templar's Verdict
    { 10, { 853, 20271 } }, -- Hammer of Justice, Judgement
    { 30, { 879, 62124 } }, -- Exorcism, Hand of Reckoning
  } },
  ROGUE = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 1766, 1752, 1329, 53, 16511 } }, -- Kick, Sinister Strike, Mutilate, Backstab, Hemorrhage
    { 25, { 36554 } }, -- Shadowstep
    { 30, { 26679, 2764 } }, -- Deadly Throw, Throw
  } },
  DRUID = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 5221, 1822, 33876, 22568 } }, -- Shred, Rake, Mangle (Cat), Ferocious Bite
    { 25, { 49376, 33786 } }, -- Feral Charge (Cat), Cyclone (20)
    { 40, { 8921, 5176, 2912 } }, -- Moonfire, Wrath, Starfire
  } },
  SHAMAN = { attackYards = 30, reachYards = 30, bands = {
    { 5, { 17364, 60103 } }, -- Stormstrike, Lava Lash
    { 25, { 57994, 8050, 8042 } }, -- Wind Shear, Flame Shock, Earth Shock
    { 30, { 403, 51514 } }, -- Lightning Bolt, Hex
  } },
  HUNTER = { attackYards = 35, reachYards = 35, bands = {
    { 5, { 2973, 2974 } }, -- Raptor Strike, Wing Clip
    { 35, { 3044, 56641, 5116, 34490 } }, -- Arcane, Steady, Concussive, Silencing Shot
  } },
  MAGE = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 2139, 118 } }, -- Counterspell, Polymorph
    { 40, { 133, 30451, 116, 44614 } }, -- Fireball, Arcane Blast, Frostbolt, Frostfire Bolt
  } },
  WARLOCK = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 5782, 6789 } }, -- Fear, Death Coil
    { 40, { 686, 29722, 172 } }, -- Shadow Bolt, Incinerate, Corruption
  } },
  PRIEST = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 15487 } }, -- Silence
    { 40, { 589, 585, 8092 } }, -- Shadow Word: Pain, Smite, Mind Blast
  } },
}

-- These classes share caster range probes but their melee trees must not
-- count a ranged utility spell as being in melee attack range.
ns.SpecsByIndex.DRUID[2].range = { attackYards = 5, reachYards = 25 }
ns.SpecsByIndex.SHAMAN[2].range = { attackYards = 5, reachYards = 5 }
ns.SpecsByIndex.PALADIN[1].range = { attackYards = 30, reachYards = 30 } -- Exorcism

ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 20, 20 }, { 25, 16 }, { 30, 14 }, { 35, 10 }, { 40, 8 },
}
