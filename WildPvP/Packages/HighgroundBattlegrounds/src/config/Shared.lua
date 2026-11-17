local _, ns = ...

-- Client-independent class armor and fallback scoring profiles.
ns.Armor = {
  DEATHKNIGHT = "plate", PALADIN = "plate", WARRIOR = "plate",
  HUNTER = "mail", SHAMAN = "mail", EVOKER = "mail",
  DRUID = "leather", MONK = "leather", ROGUE = "leather", DEMONHUNTER = "leather",
  MAGE = "cloth", PRIEST = "cloth", WARLOCK = "cloth",
}

-- Fallback when a spec is not in the table above (new spec, renamed spec).
ns.RoleDefaults = {
  HEALER = { k = 5, i = 8 },
  DAMAGER = { k = 5, i = 6 },
  TANK = { k = 2, i = 3 },
}

