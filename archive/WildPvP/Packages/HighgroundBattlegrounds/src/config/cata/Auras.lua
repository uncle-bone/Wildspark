local _, ns = ...

-- Defensive cooldowns: aura spellId -> { cooldown seconds, immunity = "all"? }.
-- Only immunity = "all" blocks every attack. Other protections remain
-- reductions: a damage-profile guess cannot establish full immunity.
-- Up = penalty; fading = "defensive spent: GO"; on cooldown (combat log) =
-- bonus, strongest for immunities.
--   scale  share of the "defensive active" penalty (1 = full; Barkskin-size
--          reductions ~0.5)
--   vs     only answers "phys" or "magic" damage; ignored when it can't
--          touch your damage, halved for mixed damage
ns.Defensives = {
  [642] = { 300, immunity = "all" }, -- Divine Shield
  [45438] = { 300, immunity = "all" }, -- Ice Block
  [19263] = { 120 }, -- Deterrence: parries melee/ranged and deflects spells
  [31224] = { 90, vs = "magic" }, -- Cloak of Shadows
  [47585] = { 120 }, -- Dispersion
  [1022] = { 300, external = true, vs = "phys" }, -- Hand of Protection
  [5277] = { 180, vs = "phys", scale = 0.8 }, -- Evasion
  [48707] = { 45, vs = "magic", scale = 0.8 }, -- Anti-Magic Shell
  [48792] = { 180, scale = 0.6 }, -- Icebound Fortitude
  [49039] = { 120, scale = 0.4 }, -- Lichborne: fear immunity + self-heals
  [871] = { 300, scale = 0.8 }, -- Shield Wall
  [12975] = { 180, scale = 0.5 }, -- Last Stand
  [55694] = { 180, scale = 0.6 }, -- Enraged Regeneration
  [23920] = { 25, vs = "magic", scale = 0.6 }, -- Spell Reflection
  [74001] = { 120, vs = "phys", scale = 0.6 }, -- Combat Readiness: stacks from melee/ranged hits
  [61336] = { 180 }, -- Survival Instincts
  [22812] = { 60, scale = 0.5 }, -- Barkskin
  [498] = { 60, scale = 0.5 }, -- Divine Protection
  [30823] = { 60, scale = 0.6 }, -- Shamanistic Rage
  [31850] = { 180, scale = 0.6 }, -- Ardent Defender
  [86659] = { 300 }, -- Guardian of Ancient Kings (Prot)
  [33206] = { 180, external = true }, -- Pain Suppression
  [47788] = { 180, external = true }, -- Guardian Spirit
  [6940] = { 120, external = true, scale = 0.6 }, -- Hand of Sacrifice
  [98008] = { 180, external = true, scale = 0.6 }, -- Spirit Link Totem
  [81782] = { 180, external = true, scale = 0.6 }, -- Power Word: Barrier
  [50461] = { 120, external = true, vs = "magic", scale = 0.8 }, -- Anti-Magic Zone
}

-- Immune control is never eligible, even when breaking CC is allowed.
ns.ImmuneCC = { [33786] = true, [710] = true } -- Cyclone, Banish

-- Breakable CC: preserved by the target policy by default.
ns.SoftCC = {
  [118] = true, [28271] = true, [28272] = true, [61305] = true, [61721] = true, [61780] = true, -- Polymorph
  [6770] = true, [2094] = true, [1776] = true, -- Sap, Blind, Gouge
  [5782] = true, [5484] = true, [8122] = true, [5246] = true, [6358] = true, [10326] = true, -- fears, Seduction, Turn Evil
  [51514] = true, [2637] = true, [20066] = true, [9484] = true, -- Hex, Hibernate, Repentance, Shackle
  [3355] = true, [19386] = true, [19503] = true, [31661] = true, [605] = true, -- Freezing Trap, Wyvern, Scatter, Dragon's Breath, MC
}

-- Stuns / silences on the enemy: free damage (bonus).
ns.HardCC = {
  [853] = true, [408] = true, [1833] = true, [44572] = true, [47481] = true, [5211] = true, -- HoJ, Kidney, Cheap Shot, Deep Freeze, Gnaw, Bash
  [22570] = true, [9005] = true, [12809] = true, [46968] = true, [7922] = true, [20253] = true, -- Maim, Pounce, Concussion Blow, Shockwave, Charge/Intercept stun
  [47476] = true, [15487] = true, [1330] = true, [55021] = true, [78675] = true, [34490] = true, -- Strangulate, Silence, Garrote, Counterspell, Solar Beam, Silencing Shot
  [64044] = true, [87204] = true, [30283] = true, [85388] = true, [20170] = true, -- Psychic Horror, Sin and Punishment, Shadowfury, Throwdown, Seal of Justice
}

-- Offensive cooldowns (bursting: pressure forces a defensive).
ns.Burst = {
  [31884] = true, [85696] = true, [12472] = true, [12042] = true, [1719] = true, [12292] = true, -- Wings, Zealotry, Icy Veins, Arcane Power, Recklessness, Death Wish
  [2825] = true, [32182] = true, [80353] = true, [51271] = true, [49016] = true, [51713] = true, -- Lust, Heroism, Time Warp, Pillar, Unholy Frenzy, Shadow Dance
  [13750] = true, [51690] = true, [50334] = true, [19574] = true, [3045] = true, [47241] = true, -- AR, Killing Spree, Berserk, Bestial Wrath, Rapid Fire, Meta
  [10060] = true, [16166] = true, [48505] = true, [79460] = true, [79462] = true, [79463] = true, [79464] = true, -- PI, EM, Starfall, Demon Soul
}

