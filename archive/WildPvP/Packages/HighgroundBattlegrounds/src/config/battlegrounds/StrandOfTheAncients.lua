local _, ns = ...
ns.RegisterBattleground({
  id = "strand_of_the_ancients", name = "Strand of the Ancients", kind = "epic", size = 15,
  clients = { cata = { ui = { 128 }, inst = { 607 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard" } } },
  coverage = "Observed graveyards, visible round/gate/relic status and recent objective announcements. No inferred gate destruction or vehicle cooldowns.",
})
