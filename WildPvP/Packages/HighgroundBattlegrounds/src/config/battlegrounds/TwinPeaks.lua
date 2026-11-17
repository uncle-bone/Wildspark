local _, ns = ...
ns.RegisterBattleground({
  id = "twin_peaks", name = "Twin Peaks", kind = "ctf", size = 10,
  clients = {
    retail = { ui = { 206 }, inst = { 726 } },
    cata = { ui = { 206 }, inst = { 726 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
      graveyards = {
        -- Actual match graveyards; 1726/1727 are the prematch flag-room spawns.
        -- Fallbacks come from Cata 4.3.0 WorldSafeLocs.dbc, projected using
        -- WorldMapArea.dbc row 626 (map 726). The live client ID/position wins.
        -- Map bounds: west 931.249939, east -283.333313,
        -- north 2266.666504, south 1456.25 (world X points north, Y west).
        -- "Middle" is the client data's "Center" graveyard, distinct from Base.
        static = {
          { id = 1729, team = "A", label = "Alliance Base Graveyard", x = 0.49334777, y = 0.12162438 },
          { id = 1749, team = "A", label = "Alliance Middle Graveyard", x = 0.40519161, y = 0.48063740 },
          { id = 1728, team = "H", label = "Horde Base Graveyard", x = 0.59155265, y = 0.87054800 },
          { id = 1750, team = "H", label = "Horde Middle Graveyard", x = 0.63492309, y = 0.55501894 },
        },
      },
    } },
  },
  rules = {
    callouts = { routes = { "Ramp", "Graveyard", "Water" } },
    objective = "flag", flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mapLabels = {
      ["wildhammer base"] = "A Base", ["dragonmaw base"] = "H Base",
      ["wildhammer stronghold"] = "A Base", ["dragonmaw stronghold"] = "H Base",
      ["mid, wildhammer side"] = "A Mid", ["mid, dragonmaw side"] = "H Mid",
    } },
    map = {
      bases = { A = "Wildhammer Stronghold", H = "Dragonmaw Stronghold" },
      sides = { A = "Wildhammer", H = "Dragonmaw" },
      anchors = { ["wildhammer stronghold"] = { 0.58, 0.2 }, ["dragonmaw stronghold"] = { 0.5, 0.84 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundTP.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = "Carrier tracking and stacks; four distinct Cata graveyards with independent observed clocks; recorded localized system-chat formats.",
})
