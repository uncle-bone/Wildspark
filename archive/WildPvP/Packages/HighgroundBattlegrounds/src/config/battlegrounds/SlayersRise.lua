local _, ns = ...
ns.RegisterBattleground({
  id = "slayers_rise", name = "Slayer's Rise", kind = "epic", size = 40,
  -- 2444 is the outdoor zone; match the BG by its instance ID instead.
  clients = { retail = { inst = { 2799 } } },
  rules = {
    capture = { seconds = 60, contestedAtlases = {
      ["capPts-refinery-assaulted-alliance"] = "A", ["capPts-stadium-assaulted-alliance"] = "A",
      ["capPts-refinery-assaulted-horde"] = "H", ["capPts-stadium-assaulted-horde"] = "H",
    } },
    graveyards = { mode = "names", names = { "graveyard" } },
  },
  sources = { "https://raw.githubusercontent.com/BigWigsMods/Capping/master/Modules/SlayersRise.lua" },
  coverage = "Capture POIs and observed resurrection waves; siege/boss victory mechanics remain partial.",
})
