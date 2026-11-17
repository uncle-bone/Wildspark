local _, ns = ...

-- What each game's API allows. The class configuration sets ns.CLIENT
-- ("retail" or "cata", selects data) and, on WoW Forever, ns.GAME. Classic
-- Era ("classic") and The Burning Crusade ("tbc") run only Highground Macros,
-- which sets them itself (addons/HighgroundMacros/Bootstrap.lua).
-- Runtime code checks ns.Caps, not client names.
ns.GAME = ns.GAME or ns.CLIENT

local GAMES = {
  -- Midnight: enemy health, power, auras and casts are secret; no combat log.
  retail = {
    addonChannel = true,    -- addon messages can use a custom realm channel
    combatLog = false,       -- COMBAT_LOG_EVENT_UNFILTERED reaches addons
    enemyStats = false,      -- enemy health and power are readable numbers
    classicSpecs = false,    -- specs are classic talent trees (IDs from the client)
    pings = true,            -- team pings can mark the kill target
    blitz = true,            -- solo rated battlegrounds exist
    allBattlegrounds = true, -- track every battleground by default, not only rated ones
    spellRanks = false,      -- spells have ranks (each rank its own spell ID)
  },
  -- Midnight client, classic content, no rated play.
  forever = {
    addonChannel = true,
    -- Some Forever builds omit the compiler used by RestrictedExecution.
    -- WrapScript still succeeds there, but its first click fails before
    -- SecureActionButton can run. Re-enable snippets if the client fixes it.
    secureSnippets = type(loadstring_untainted) == "function",
    combatLog = false,
    enemyStats = false,
    classicSpecs = true,
    pings = true,
    blitz = false,
    allBattlegrounds = false,
    spellRanks = true,
  },
  cata = {
    addonChannel = false,   -- discover on custom chat, send data by whisper
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = false,
    spellRanks = false, -- ranks were removed in 4.0
  },
  classic = {
    addonChannel = false,
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = false,
    spellRanks = true,
  },
}
GAMES.tbc = GAMES.classic

ns.Caps = assert(GAMES[ns.GAME], "no capabilities for this game: " .. tostring(ns.GAME))
ns.GameCaps = GAMES -- every game's, for checks about another game (macro compiler)

-- What each game is called and what it holds, for any addon of the
-- repository. name: in sentences; label: upper-case UI label; arenaSize:
-- largest arena bracket (nil: no arenas); contentOf: the game whose spells
-- and presets it shares when it has none of its own.
ns.Games = {
  retail = { name = "Retail", label = "RETAIL", arenaSize = 3 },
  forever = { name = "WoW Forever", label = "WOW FOREVER" },
  cata = { name = "Cataclysm", label = "CATACLYSM", arenaSize = 5 },
  classic = { name = "Classic Era", label = "CLASSIC ERA", contentOf = "forever" },
  tbc = { name = "The Burning Crusade", label = "BURNING CRUSADE", arenaSize = 5, contentOf = "forever" },
}
