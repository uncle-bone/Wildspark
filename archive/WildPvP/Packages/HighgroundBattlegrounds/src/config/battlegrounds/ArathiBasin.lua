local _, ns = ...
ns.RegisterBattleground({
  id = "arathi_basin", name = "Arathi Basin", kind = "nodes", size = 15,
  clients = {
    retail = { ui = { 1366, 93, 1461 }, inst = { 2107, 529 } },
    cata = { ui = { 93, 1461 }, inst = { 529 }, rules = {
      -- Observed Cata calibration; learned capture times replace it (timers/Nodes.lua).
      capture = { seconds = 65 },
      scoring = { seedRates = { [0] = 0, 0.8333, 1.1111, 1.6667, 3.3333, 30 } },
      -- Approximate area anchors when unit coordinates / POIs are unavailable.
      -- Capture flags and starting gates from BattlegroundAB.h, projected
      -- with Cata WorldMapArea row 461: west 1858.333252, east 102.083328,
      -- north 1508.333252, south 337.5. Live landmarks take precedence.
      map = { anchors = {
        stables = { 0.3748, 0.2917 }, blacksmith = { 0.4622, 0.4538 }, farm = { 0.5603, 0.5997 },
        ["lumber mill"] = { 0.4039, 0.5570 }, ["gold mine"] = { 0.5752, 0.3087 },
        ["trollbane hall"] = { 0.3286, 0.1911 }, ["defiler's den"] = { 0.6547, 0.6835 },
      } },
    } },
  },
  rules = {
    callouts = { destinations = { "Stables", "Farm", "Blacksmith", "Lumber Mill", "Gold Mine" } },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36 },
      names = { "stables", "farm", "blacksmith", "lumber mill", "gold mine" },
      mapLabels = { stables = "ST", farm = "Farm", blacksmith = "BS", ["lumber mill"] = "LM", ["gold mine"] = "GM",
        ["trollbane hall"] = "A Start", ["defiler's den"] = "H Start" } },
    scoring = { bases = 5, noun = "base", predict = true },
    map = { anchors = { ["trollbane hall"] = { 0.38, 0.17 }, ["defiler's den"] = { 0.62, 0.86 } } },
  },
  blitz = { capture = { seconds = 30, holdSeconds = 45, resetSeconds = 5 }, scoring = { predict = false } },
  sources = {
    "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/ArathiBasin.lua",
    "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundAB.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = "Node captures and graveyards. Standard score prediction learns each mode separately; Blitz win prediction disabled for rotating ownership.",
})
