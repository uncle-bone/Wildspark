local _, ns = ...
ns.RegisterBattleground({
  id = "isle_of_conquest", name = "Isle of Conquest", kind = "epic", size = 40,
  clients = {
    retail = { ui = { 169 }, inst = { 628 } },
    cata = { ui = { 169 }, inst = { 628 } },
  },
  rules = { capture = { seconds = 60 }, graveyards = { mode = "names", names = { "docks", "hangar", "workshop", "keep", "courtyard", "graveyard" } } },
  coverage = "POI capture countdowns, resurrection waves, visible gate/vehicle/objective status and recent announcements. No inferred gate, vehicle or boss timers.",
})
