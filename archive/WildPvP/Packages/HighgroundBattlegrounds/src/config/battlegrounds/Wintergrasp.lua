local _, ns = ...
ns.RegisterBattleground({
  id = "wintergrasp", name = "Wintergrasp", kind = "epic", size = 40,
  clients = { retail = { ui = { 1334 }, inst = { 2118 } } },
  rules = { graveyards = { mode = "names", names = { "graveyard", "workshop", "keep" } } },
  coverage = "Instanced Retail battleground, resurrection waves, visible siege/round status and recent announcements. Cata outdoor PvP is not implemented.",
})
