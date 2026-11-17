local _, ns = ...
ns.RegisterBattleground({
  id = "battle_for_gilneas", name = "Battle for Gilneas", kind = "nodes", size = 10,
  clients = {
    retail = { ui = { 275 }, inst = { 761 } },
    cata = { ui = { 275 }, inst = { 761 }, rules = {
      -- Starting gate positions from BattlegroundBFG.h, projected with
      -- WorldMapArea row 736 (bounds below). Capture areas reuse node points.
      map = { anchors = {
        ["gilnean stronghold"] = { 0.31425966, 0.78938248 },
        ["horde landing"] = { 0.59039461, 0.23965079 },
      } },
      graveyards = {
        -- Cata WorldSafeLocs destinations, projected with WorldMapArea row 736:
        -- west 1745.833252, east 443.749969, north 1604.166626, south 735.416626.
        -- 1798/1799 are prematch spawn points, not the match's starting GYs.
        -- Live graveyardID coordinates override these original client fallbacks.
        static = {
          { id = 1740, team = "A", label = "Alliance Starting Graveyard", x = 0.31275517, y = 0.80102750 },
          { id = 1739, team = "H", label = "Horde Starting Graveyard", x = 0.59036796, y = 0.23342345 },
        },
        -- Capture flags and their graveyards occupy different map positions.
        -- Node positions also identify localized POIs without English names.
        nodes = {
          { id = 1736, label = "Lighthouse Graveyard", x = 0.31507454, y = 0.65536308,
            node = { name = "Lighthouse", x = 0.35904251, y = 0.62878461 } },
          { id = 1738, label = "Waterworks Graveyard", x = 0.62092516, y = 0.82485021,
            node = { name = "Waterworks", x = 0.61219299, y = 0.71837309 } },
          { id = 1735, label = "Mine Graveyard", x = 0.69833187, y = 0.40510693,
            node = { name = "Mine", x = 0.60478025, y = 0.40649971 } },
        },
      },
    } },
  },
  rules = {
    callouts = { destinations = { "Lighthouse", "Waterworks", "Mine" }, aliases = { mines = "mine" } },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36, 136, 141, 146, 151 },
      names = { "lighthouse", "waterworks", "mine" },
      mapLabels = { lighthouse = "LH", waterworks = "WW", mine = "Mine" } },
    scoring = { bases = 3, noun = "base", predict = true },
  },
  blitz = { capture = { seconds = 30 } },
  sources = {
    "https://worldofwarcraft.blizzard.com/en-gb/news/9984237",
    "https://github.com/FirelandsProject/firelands-cata/blob/master/src/server/game/Battlegrounds/Zones/BattlegroundBFG.h",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldSafeLocs.dbc",
    "https://github.com/jenascore/DBC-Maps-Vmaps-430/blob/master/dbc/WorldMapArea.dbc",
  },
  coverage = "Node captures and learned resource rates; Cata has two permanent starting graveyards plus three ownership-controlled node graveyards.",
})
