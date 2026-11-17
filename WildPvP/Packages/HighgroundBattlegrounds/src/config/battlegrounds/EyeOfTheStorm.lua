local _, ns = ...
local rated = { id = "rated", rules = { capture = { seconds = 60, contestedAtlases = {
  ["eots_capPts-leftIcon2-state1"] = "A", ["eots_capPts-leftIcon3-state1"] = "A",
  ["eots_capPts-leftIcon4-state1"] = "A", ["eots_capPts-leftIcon5-state1"] = "A",
  ["eots_capPts-rightIcon2-state1"] = "H", ["eots_capPts-rightIcon3-state1"] = "H",
  ["eots_capPts-rightIcon4-state1"] = "H", ["eots_capPts-rightIcon5-state1"] = "H",
} } } }
ns.RegisterBattleground({
  id = "eye_of_the_storm", name = "Eye of the Storm", kind = "carry", size = 15,
  clients = {
    retail = { ui = { 112, 397, 1956 }, inst = { 566, 968 }, variants = { [968] = rated } },
    cata = { ui = { 112, 397, 1956 }, inst = { 566, 968 }, variants = { [968] = rated } },
  },
  rules = {
    callouts = { destinations = { "Fel Reaver Ruins", "Blood Elf Tower", "Draenei Ruins", "Mage Tower" } },
    objective = "carry", flags = { respawnSeconds = 21 },
    -- Normal instance 566 uses proximity; rated instance 968 has timed flags.
    graveyards = { mode = "names", names = { "fel reaver", "blood elf", "draenei", "mage tower" },
      mapLabels = { ["fel reaver ruins"] = "FR", ["blood elf tower"] = "BE", ["draenei ruins"] = "DR", ["mage tower"] = "MT" } },
    scoring = { bases = 4, noun = "tower", predict = true },
    map = { zoneCenter = { 0.5, 0.5 } },
  },
  -- Midnight restored four continuously active towers in Blitz.
  sources = { "https://news.blizzard.com/en-gb/article/24244455/midnight-pre-expansion-content-update-notes", "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/EyeOfTheStorm.lua" },
  coverage = "Carrier, tower ownership and resource trend; future flag deliveries are not predictable.",
})
