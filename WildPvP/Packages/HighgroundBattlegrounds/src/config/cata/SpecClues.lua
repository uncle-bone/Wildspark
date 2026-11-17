local _, ns = ...

-- Cata spec clues beyond personal buffs (config/cata/Classes.lua). Values are
-- talent-tree indexes, independent of the client's spec IDs.
--
-- casts: talent-tree abilities. Only that tree's players have them, so an
-- enemy casting one (combat log, in or out of sight) shows its spec. Keyed
-- by English spell name: the combat log names the spell on every client
-- build, while spell IDs vary between Cata builds.
--
-- mana: melee hybrids carry no Intellect, so at level 85 their mana pool sits
-- near the class base (~20-26k); casters and healers carry 60k+. Pools in
-- the gap decide nothing. Lightning Shield separates Elemental from
-- Restoration (Water Shield, a personal-buff clue) among high-mana shamans.
ns.SpecInferenceConfig.casts = {
  DEATHKNIGHT = {
    ["Heart Strike"] = 1, ["Vampiric Blood"] = 1, ["Dancing Rune Weapon"] = 1, ["Rune Tap"] = 1,
    ["Frost Strike"] = 2, ["Howling Blast"] = 2, ["Pillar of Frost"] = 2, ["Hungering Cold"] = 2,
    ["Scourge Strike"] = 3, ["Summon Gargoyle"] = 3, ["Dark Transformation"] = 3, ["Unholy Frenzy"] = 3,
    ["Anti-Magic Zone"] = 3,
  },
  DRUID = {
    ["Starsurge"] = 1, ["Starfall"] = 1, ["Typhoon"] = 1, ["Force of Nature"] = 1, ["Solar Beam"] = 1,
    ["Moonkin Form"] = 1,
    ["Mangle"] = 2, ["Berserk"] = 2, ["Feral Charge"] = 2, ["Pulverize"] = 2,
    ["Swiftmend"] = 3, ["Wild Growth"] = 3, ["Tree of Life"] = 3, ["Nature's Swiftness"] = 3,
  },
  HUNTER = {
    ["Intimidation"] = 1, ["Bestial Wrath"] = 1, ["Focus Fire"] = 1,
    ["Aimed Shot"] = 2, ["Chimera Shot"] = 2, ["Silencing Shot"] = 2, ["Readiness"] = 2,
    ["Explosive Shot"] = 3, ["Black Arrow"] = 3, ["Wyvern Sting"] = 3,
  },
  MAGE = {
    ["Arcane Barrage"] = 1, ["Arcane Power"] = 1, ["Presence of Mind"] = 1, ["Slow"] = 1,
    ["Pyroblast"] = 2, ["Living Bomb"] = 2, ["Blast Wave"] = 2, ["Dragon's Breath"] = 2, ["Combustion"] = 2,
    ["Summon Water Elemental"] = 3, ["Deep Freeze"] = 3, ["Ice Barrier"] = 3, ["Icy Veins"] = 3, ["Cold Snap"] = 3,
  },
  PALADIN = {
    ["Holy Shock"] = 1, ["Beacon of Light"] = 1, ["Divine Favor"] = 1, ["Light of Dawn"] = 1,
    ["Avenger's Shield"] = 2, ["Shield of the Righteous"] = 2, ["Hammer of the Righteous"] = 2,
    ["Ardent Defender"] = 2,
    ["Templar's Verdict"] = 3, ["Divine Storm"] = 3, ["Zealotry"] = 3, ["Repentance"] = 3,
  },
  PRIEST = {
    ["Penance"] = 1, ["Power Infusion"] = 1, ["Pain Suppression"] = 1, ["Power Word: Barrier"] = 1,
    ["Circle of Healing"] = 2, ["Guardian Spirit"] = 2, ["Chakra"] = 2, ["Lightwell"] = 2,
    ["Mind Flay"] = 3, ["Vampiric Touch"] = 3, ["Dispersion"] = 3, ["Shadowform"] = 3, ["Silence"] = 3,
    ["Psychic Horror"] = 3,
  },
  ROGUE = {
    ["Mutilate"] = 1, ["Cold Blood"] = 1, ["Vendetta"] = 1,
    ["Blade Flurry"] = 2, ["Adrenaline Rush"] = 2, ["Killing Spree"] = 2,
    ["Shadowstep"] = 3, ["Shadow Dance"] = 3, ["Premeditation"] = 3, ["Hemorrhage"] = 3,
  },
  SHAMAN = {
    ["Thunderstorm"] = 1, ["Elemental Mastery"] = 1,
    ["Lava Lash"] = 2, ["Stormstrike"] = 2, ["Feral Spirit"] = 2, ["Shamanistic Rage"] = 2,
    ["Riptide"] = 3, ["Earth Shield"] = 3, ["Mana Tide Totem"] = 3, ["Spirit Link Totem"] = 3,
    ["Nature's Swiftness"] = 3,
  },
  WARLOCK = {
    ["Unstable Affliction"] = 1, ["Haunt"] = 1,
    ["Summon Felguard"] = 2, ["Metamorphosis"] = 2, ["Hand of Gul'dan"] = 2,
    ["Conflagrate"] = 3, ["Chaos Bolt"] = 3, ["Shadowfury"] = 3,
  },
  WARRIOR = {
    ["Mortal Strike"] = 1, ["Bladestorm"] = 1, ["Sweeping Strikes"] = 1, ["Throwdown"] = 1,
    ["Bloodthirst"] = 2, ["Raging Blow"] = 2, ["Death Wish"] = 2,
    ["Shield Slam"] = 3, ["Devastate"] = 3, ["Shockwave"] = 3, ["Concussion Blow"] = 3,
  },
}

-- Always-on personal buffs (added to the cooldown-buff clues).
ns.SpecInferenceConfig.auras.SHAMAN[52127] = { 3, "Water Shield" }
ns.SpecInferenceConfig.auras.PALADIN[25780] = { 2, "Righteous Fury" }

-- Buffs that only qualify a mana reading (never a spec by themselves).
ns.SpecInferenceConfig.markers = { SHAMAN = { [324] = "lightningShield" } }

ns.SpecInferenceConfig.role = {
  level = 85, low = 40000, high = 50000,
  -- class = { low mana tree, high mana tree (+ required marker) }
  SHAMAN = { low = 2, high = 1, highNeeds = "lightningShield" },
  PALADIN = { low = 3 }, -- Protection shows Righteous Fury, which outranks this
  DRUID = { low = 2 }, -- only readable in caster form
}
