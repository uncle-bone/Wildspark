local _, ns = ...
ns.RegisterBattleground({
  id = "deepwind_gorge", name = "Deepwind Gorge", kind = "nodes", size = 15,
  clients = { retail = { ui = { 1576 }, inst = { 2245 } } },
  rules = {
    callouts = { destinations = { "Market", "Farm", "Ruins", "Shrine", "Quarry" } },
    capture = { seconds = 60 },
    graveyards = { mode = "names", iconFamilies = { 16, 21, 26, 31, 36 },
      names = { "market", "farm", "ruins", "shrine", "quarry" } },
    scoring = { bases = 5, noun = "base", predict = true },
  },
  blitz = { capture = { seconds = 30, holdSeconds = 45, resetSeconds = 5 }, scoring = { predict = false } },
  sources = { "https://news.blizzard.com/en-gb/article/23227147/visions-of-nzoth-content-update-notes" },
  coverage = "Modern five-base map; legacy three-base/cart variant deliberately not matched.",
})
