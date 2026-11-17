local _, ns = ...
ns.RegisterBattleground({
  id = "alterac_valley", name = "Alterac Valley", kind = "epic", size = 40,
  clients = {
    retail = { ui = { 91, 1537 }, inst = { 30, 2197 } },
    cata = { ui = { 91 }, inst = { 30 } },
  },
  rules = { capture = { seconds = 240 }, graveyards = { mode = "names", names = { "graveyard", "aid station", "relief hut" },
    mapLabels = { stormpike = "SP", stonehearth = "SH", snowfall = "SF", iceblood = "IB", frostwolf = "FW",
      ["stormpike aid station"] = "Aid", ["frostwolf relief hut"] = "Relief", ["aid station"] = "Aid", ["relief hut"] = "Relief" } } },
  coverage = "POI capture countdowns, resurrection waves, visible reinforcement/objective status and recent announcements. No boss or reinforcement victory prediction.",
})
