local _, ns = ...
ns.RegisterBattleground({
  id = "ashran", name = "Ashran", kind = "epic", size = 35,
  clients = { retail = { ui = { 1478, 588 }, inst = { 1191 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = "Roster, resurrection waves, visible event/lane status, objective landmarks and recent announcements. No predicted event or commander timings.",
})
