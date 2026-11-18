local _, ns = ...
ns.RegisterBattleground({
  id = "warsong_gulch", name = "Warsong Gulch", kind = "ctf", size = 10,
  clients = {
    retail = { ui = { 1339, 1460 }, inst = { 2106, 489 } },
    cata = { ui = { 1339, 1460 }, inst = { 489 }, rules = {
      flags = { firstStackSeconds = 180, stackInterval = 60, maxStacks = 10 },
      graveyards = {
        -- Match resurrection points; 769/770 are prematch flag-room spawns.
        -- Cata 4.3.0 WorldSafeLocs.dbc, projected using WorldMapArea.dbc
        -- row 443 (map 489): west 2041.666626, east 895.833313,
        -- north 1627.083252, south 862.499939. Live positions win by ID.
        static = {
          { id = 771, team = "A", label = "Alliance Base Graveyard", x = 0.41622721, y = 0.28830137 },
          { id = 772, team = "H", label = "Horde Base Graveyard", x = 0.57999419, y = 0.73959668 },
        },
      },
      -- Flag rooms: flag spawns from BattlegroundWS.h, same projection.
      map = { anchors = {
        ["silverwing flag room"] = { 0.48903, 0.11335 },
        ["warsong flag room"] = { 0.52998, 0.93000 },
      } },
    } },
  },
  rules = {
    callouts = { routes = { "Ramp", "Graveyard", "Tunnel" } },
    objective = "flag",
    flags = { firstStackSeconds = 30, stackInterval = 30 },
    graveyards = { mode = "none", single = true, mapLabels = {
      ["silverwing base"] = "A Base", ["warsong base"] = "H Base",
      ["silverwing hold"] = "A Base", ["warsong lumber mill"] = "H Base",
      ["mid, silverwing side"] = "A Mid", ["mid, warsong side"] = "H Mid",
    } },
    map = {
      bases = { A = "Silverwing Hold", H = "Warsong Lumber Mill" },
      sides = { A = "Silverwing", H = "Warsong" },
      anchors = { ["silverwing hold"] = { 0.5, 0.15 }, ["warsong lumber mill"] = { 0.5, 0.85 }, ["warsong gulch"] = { 0.5, 0.5 } },
    },
  },
  blitz = { flags = { firstStackSeconds = 15, stackInterval = 15 } },
  -- Original Cata timing; custom servers may differ.
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://news.blizzard.com/en-us/article/24010909/get-ready-for-the-battleground-blitz-brawl",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundWS.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = "Carrier tracking and stacks; one fixed Cata graveyard per faction with observed clocks; recorded localized system-chat formats.",
})
