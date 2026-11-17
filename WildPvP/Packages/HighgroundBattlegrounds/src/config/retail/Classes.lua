local _, ns = ...
if ns.IS_FOREVER then return end -- WoW Forever: config/forever/Classes.lua

ns.CLIENT = "retail"
ns.ClassIDs = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }

-- Per-spec PvP profile, tuned for Midnight Season 2 (patch 12.1) battlegrounds.
--   k      killability 1-10 (higher = easier to burst: armor, self-heal, defensives, mobility)
--   i      kill impact 1-10 (healers and S-tier damage dealers score high)
--   dmg    damage profile when *you* play this spec: "phys" or "magic"
--   melee  true if *you* need to stay in melee range on this spec
--   kite   target kites melee well (ranged + mobile)
--   physDR target has a strong answer to physical damage (Evasion, Turtle, BoP, Karma...)
--   magDR  target has a strong answer to magic damage (Cloak, AMS, Dispersion, Netherwalk...)
--   range  optional attackYards/reachYards/bands overrides for YOUR spec
--   note   what to bait / watch before committing
--
-- Season 2 context: 20% healing reduction in battlegrounds, CC immunity after
-- 2 DR applications, broad slow nerfs (melee stick worse to kiters).
ns.Specs = {
  -- Death Knight
  [250] = { k = 1, i = 2, dmg = "magic", melee = true, physDR = false, magDR = true, note = "Blood: ignore unless isolated" },
  [251] = { k = 4, i = 6, dmg = "magic", melee = true, magDR = true, note = "Bait Icebound/AMS; Lichborne vs fear" },
  [252] = { k = 4, i = 8, dmg = "magic", melee = true, magDR = true, note = "S-tier pressure; bait AMS + Icebound" },
  -- Demon Hunter
  [577] = { k = 5, i = 7, dmg = "magic", melee = true, physDR = true, magDR = true, note = "Blur + Netherwalk; leech heavy" },
  [581] = { k = 2, i = 3, dmg = "magic", melee = true, note = "Tank: skip" },
  [1480] = { k = 6, i = 7, dmg = "magic", note = "Devourer: ranged DH, squishier than Havoc" },
  -- Druid
  [102] = { k = 6, i = 8, dmg = "magic", kite = true, note = "Barkskin/Bear shift; S-tier dmg" },
  [103] = { k = 5, i = 7, dmg = "phys", melee = true, note = "Survival Instincts, stealth resets" },
  [104] = { k = 1, i = 3, dmg = "phys", melee = true, note = "Tank: skip" },
  [105] = { k = 4, i = 8, dmg = "magic", kite = true, note = "Hard to kill: shapeshift, HoTs. Kill only in CC" },
  -- Evoker
  [1467] = { k = 6, i = 7, dmg = "magic", kite = true, note = "Obsidian Scales, Renewing Blaze" },
  [1468] = { k = 7, i = 10, dmg = "magic", kite = true, note = "S-tier healer: Temporal Barrier +30%; bait Scales/Blaze" },
  [1473] = { k = 7, i = 6, dmg = "magic", kite = true, note = "Aug: squishy, buffs team" },
  -- Hunter
  [253] = { k = 5, i = 6, dmg = "phys", kite = true, physDR = true, magDR = true, note = "Turtle (Aspect of the Turtle)" },
  [254] = { k = 6, i = 8, dmg = "phys", kite = true, physDR = true, magDR = true, note = "S-tier: bait Turtle, Survival of the Fittest" },
  [255] = { k = 5, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Turtle" },
  -- Mage
  [62] = { k = 7, i = 6, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Ice Block / Alter Time" },
  [63] = { k = 6, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Block + Cauterize: needs 2 kill windows" },
  [64] = { k = 6, i = 7, dmg = "magic", kite = true, physDR = true, magDR = true, note = "Ice Block, Ice Barrier" },
  -- Monk
  [268] = { k = 2, i = 3, dmg = "phys", melee = true, note = "Tank: skip" },
  [269] = { k = 5, i = 6, dmg = "phys", melee = true, physDR = true, note = "Touch of Karma = stop hitting" },
  [270] = { k = 6, i = 9, dmg = "magic", note = "S-tier healer: mobile, Fortifying Brew, Revival" },
  -- Paladin
  [65] = { k = 4, i = 7, dmg = "magic", physDR = true, magDR = true, note = "Bubble + BoP; kill after Divine Shield used" },
  [66] = { k = 2, i = 3, dmg = "magic", melee = true, note = "Tank: skip" },
  [70] = { k = 3, i = 8, dmg = "magic", melee = true, physDR = true, magDR = true, note = "S-tier but plate + bubble + Word of Glory" },
  -- Priest
  [256] = { k = 6, i = 8, dmg = "magic", note = "Pain Suppression, Rapture shields" },
  [257] = { k = 7, i = 8, dmg = "magic", note = "Highest throughput; Guardian Spirit / Ray of Hope" },
  [258] = { k = 6, i = 8, dmg = "magic", magDR = true, note = "Dispersion; S-tier dmg" },
  -- Rogue
  [259] = { k = 6, i = 6, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Cloak vs magic, Evasion vs phys" },
  [260] = { k = 6, i = 5, dmg = "phys", melee = true, physDR = true, magDR = true, note = "Cloak / Evasion" },
  [261] = { k = 6, i = 8, dmg = "phys", melee = true, physDR = true, magDR = true, note = "S-tier: Cloak, Evasion, vanish resets" },
  -- Shaman
  [262] = { k = 6, i = 7, dmg = "magic", kite = true, note = "Astral Shift" },
  [263] = { k = 5, i = 6, dmg = "phys", melee = true, note = "Astral Shift, self-heals" },
  [264] = { k = 6, i = 7, dmg = "magic", note = "Astral Shift, Spirit Link" },
  -- Warlock
  [265] = { k = 6, i = 7, dmg = "magic", note = "Unending Resolve, Dark Pact" },
  [266] = { k = 6, i = 5, dmg = "magic", note = "Unending Resolve" },
  [267] = { k = 6, i = 7, dmg = "magic", note = "Unending Resolve; big burst" },
  -- Warrior
  [71] = { k = 4, i = 8, dmg = "phys", melee = true, note = "Die by the Sword vs phys" },
  [72] = { k = 4, i = 6, dmg = "phys", melee = true, note = "Enraged Regeneration" },
  [73] = { k = 2, i = 3, dmg = "phys", melee = true, note = "Tank: skip" },
}

-- Hand-tuned matchups for YOUR spec. Each listed opponent replaces its
-- generic phys/magic/melee adjustment; missing opponents use the fallback.
-- Each value adjusts enemy killability (k) and explains why.
ns.Matchups = {
  -- Frost Death Knight (12.1): mostly Frost (magic) damage; burst = Pillar of
  -- Frost + Breath/Frostwyrm. RBG kit: Strangulate, Death Grip, Asphyxiate,
  -- Mind Freeze, Delirium/Deathchill slows+roots. No purge, no healing
  -- reduction, no gap closer besides grip -> wants immobile casters.
  [251] = {
    [1468] = { 0.5, "Pres: grip off hover, Strangulate/Mind Freeze long casts" },
    [270] = { -0.5, "MW: rolls/Torpedo out of melee, Diffuse Magic vs Frost" },
    [257] = { 1.0, "Holy Priest: stands to cast, no immunity; Strangulate + Asphyxiate" },
    [256] = { 0.0, "Disc: Pillar AFTER Pain Suppression is gone" },
    [105] = { -1.0, "Resto Druid: kites, HoTs out-heal you (no healing reduction)" },
    [264] = { 0.5, "Resto Shaman: easy to stick; only Astral Shift" },
    [65] = { -0.5, "Holy Pala: Bubble/BoP, Freedom breaks your roots" },
    [62] = { -0.5, "Mage: Blink/Shimmer + Ice Block; Frost Nova roots you" },
    [63] = { -0.5, "Mage: Blink + Ice Block + Cauterize" },
    [64] = { -0.5, "Mage: Blink + Ice Block; roots you" },
    [253] = { -1.0, "Hunter: Disengage + Turtle deflects; kites you" },
    [254] = { -1.0, "MM: Disengage + Turtle; kites you" },
    [255] = { -0.5, "Survival: Turtle, but stays in melee" },
    [259] = { -0.7, "Rogue: Cloak makes most of your Frost dmg miss" },
    [260] = { -0.7, "Rogue: Cloak vs Frost" },
    [261] = { -0.7, "Sub: Cloak vs Frost, vanish resets" },
    [265] = { 1.0, "Warlock: immobile turret, grippable, no immunity" },
    [266] = { 1.0, "Warlock: immobile, no immunity" },
    [267] = { 1.0, "Destro: long casts -> Mind Freeze, no immunity" },
    [258] = { 0.0, "Shadow: Dispersion (bait it)" },
    [102] = { 0.3, "Balance: cast-reliant; Barkskin/bear only" },
    [262] = { 0.5, "Ele: turret caster, Astral Shift only" },
    [1467] = { 0.3, "Dev: grip off hover; Obsidian Scales" },
    [1473] = { 0.5, "Aug: squishy, stays back -> grip" },
    [577] = { -0.5, "Havoc: Netherwalk + Blur + leech" },
    [1480] = { 0.0, "Devourer: ranged DH, no Netherwalk data yet" },
    [103] = { 0.0, "Feral: stealth resets, Survival Instincts" },
    [263] = { 0.0, "Enhance: Astral Shift + self-heals" },
    [269] = { -1.0, "WW: Touch of Karma - never Pillar into Karma" },
    [70] = { -0.5, "Ret: Bubble, Word of Glory, Freedom" },
    [71] = { 0.0, "Arms: Die by the Sword parries Obliterate" },
    [72] = { 0.3, "Fury: stays in melee, no immunity" },
    [251] = { -0.5, "Frost DK mirror: AMS eats your Frost dmg" },
    [252] = { -0.5, "Unholy: AMS eats your Frost dmg, Icebound" },
  },
}

-- Distance bands for YOUR class, nearest first. Each band = yards + spells
-- whose range is about that far; the first spell that gives an answer wins.
-- attackYards = where you actually deal damage (green range pip).
-- reachYards  = farthest an enemy may be and still be picked as the live kill
--               target (gap-closer / main ranged range). Anyone farther is
--               never "kill now", however you target them.
ns.RangeBands = {
  DEATHKNIGHT = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 49143, 49020, 85948, 55090, 206930 } }, -- Frost Strike, Obliterate, Festering/Scourge/Heart Strike
    { 15, { 47528 } }, -- Mind Freeze
    { 20, { 221562 } }, -- Asphyxiate (talent; skipped if not known)
    { 30, { 49576, 45524, 56222 } }, -- Death Grip, Chains of Ice, Dark Command
    { 40, { 47541 } }, -- Death Coil
  } },
  WARRIOR = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 6552, 12294, 23881, 1464 } }, -- Pummel, Mortal Strike, Bloodthirst, Slam
    { 25, { 100 } }, -- Charge
    { 30, { 57755 } }, -- Heroic Throw
  } },
  PALADIN = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 96231, 35395 } }, -- Rebuke, Crusader Strike
    { 10, { 853 } }, -- Hammer of Justice
    { 30, { 20271 } }, -- Judgment
  } },
  ROGUE = { attackYards = 5, reachYards = 25, bands = {
    { 5, { 1766, 1752, 1329, 53 } }, -- Kick, Sinister Strike, Mutilate, Backstab
    { 25, { 36554 } }, -- Shadowstep
    { 30, { 185565, 114014 } }, -- Poisoned Knife, Shuriken Toss
  } },
  DEMONHUNTER = { attackYards = 5, reachYards = 30, bands = {
    { 5, { 162794, 162243 } }, -- Chaos Strike, Demon's Bite
    { 10, { 183752 } }, -- Disrupt
    { 30, { 185123 } }, -- Throw Glaive
  } },
  MONK = { attackYards = 5, reachYards = 20, bands = {
    { 5, { 100780, 116705 } }, -- Tiger Palm, Spear Hand Strike
    { 20, { 115078 } }, -- Paralysis
    { 40, { 117952 } }, -- Crackling Jade Lightning
  } },
  DRUID = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 5221, 1822, 33917 } }, -- Shred, Rake, Mangle
    { 25, { 102401 } }, -- Wild Charge
    { 40, { 8921, 5176 } }, -- Moonfire, Wrath
  } },
  SHAMAN = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 17364 } }, -- Stormstrike
    { 30, { 57994 } }, -- Wind Shear
    { 40, { 188196, 188389 } }, -- Lightning Bolt, Flame Shock
  } },
  HUNTER = { attackYards = 40, reachYards = 40, bands = {
    { 5, { 186270, 187707 } }, -- Raptor Strike, Muzzle
    { 40, { 185358, 19434, 147362 } }, -- Arcane Shot, Aimed Shot, Counter Shot
  } },
  MAGE = { attackYards = 40, reachYards = 40, bands = {
    { 40, { 116, 133, 30451, 2139 } }, -- Frostbolt, Fireball, Arcane Blast, Counterspell
  } },
  WARLOCK = { attackYards = 40, reachYards = 40, bands = {
    { 40, { 686, 29722, 172 } }, -- Shadow Bolt, Incinerate, Corruption
  } },
  PRIEST = { attackYards = 40, reachYards = 40, bands = {
    { 30, { 15487 } }, -- Silence
    { 40, { 589, 585 } }, -- Shadow Word: Pain, Smite
  } },
  EVOKER = { attackYards = 25, reachYards = 25, bands = {
    { 25, { 361469, 351338 } }, -- Living Flame, Quell
  } },
}

-- A class may contain both melee and ranged specs. Missing range fields
-- inherit the class defaults; a supplied bands table replaces the class list.
ns.Specs[103].range = { attackYards = 5, reachYards = 25 } -- Feral
ns.Specs[104].range = { attackYards = 5, reachYards = 25 } -- Guardian
ns.Specs[263].range = { attackYards = 5, reachYards = 25, bands = { -- Enhancement
  { 5, { 17364, 60103 } }, -- Stormstrike, Lava Lash
  { 25, { 196884 } }, -- Feral Lunge; absent when not learned
  ns.RangeBands.SHAMAN.bands[2],
  ns.RangeBands.SHAMAN.bands[3],
} }
ns.Specs[255].range = { attackYards = 5, reachYards = 30, bands = { -- Survival
  ns.RangeBands.HUNTER.bands[1],
  { 30, { 190925 } }, -- Harpoon
  ns.RangeBands.HUNTER.bands[2],
} }
-- Consume and Void Ray both have a 25-yard range. Devourer cannot use
-- Havoc's melee probes as its primary attack range.
ns.Specs[1480].range = { attackYards = 25, reachYards = 25, bands = {
  { 25, { 473662, 473728 } }, -- Consume, Void Ray
} }
ns.Specs[65].range = { attackYards = 30, reachYards = 30 } -- Holy: Judgment
ns.Specs[270].range = { attackYards = 40, reachYards = 40 } -- Mistweaver: Crackling Jade Lightning

-- Proximity bonus for the live kill target, by nearest band reached.
ns.ProximityBonus = {
  { 5, 30 }, { 10, 26 }, { 15, 22 }, { 20, 18 }, { 25, 16 }, { 30, 14 }, { 40, 8 },
}
