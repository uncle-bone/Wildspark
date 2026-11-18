local _, ns = ...
ns.RegisterBattleground({
  id = "deephaul_ravine", name = "Deephaul Ravine", kind = "carts", size = 10,
  clients = { retail = { ui = { 2345 }, inst = { 2656 } } },
  rules = { objective = "carry" },
  coverage = "Carrier tokens, observed resurrection waves, cart landmarks, visible objective widgets and recent announcements. No inferred cart arrival or crystal respawn duration.",
})
