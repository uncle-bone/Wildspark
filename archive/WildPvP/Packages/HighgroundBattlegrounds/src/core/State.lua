local ADDON, ns = ...
ns.Core = {}
ns.Commands = {}
local Core = ns.Core

-- Core state shared by every subsystem: the enemy table and sort order,
-- saved-setting defaults, feature switches. Other modules
-- read it through core/Exports.lua.
--
-- Retail and Forever (Midnight) rules: scoreboard name and class are
-- readable, spec comes from post-match history, health and most enemy auras
-- are secret and may only be displayed, never compared. Everything that
-- feeds the sort is non-secret; secrets go straight to widgets.

-- Name helpers (Canon, CanonUnit, DisplayName, issecret, plain): core/Names.lua.

-- Some clients lack globals that Blizzard's own UI documents (some Cata
-- 4.4.2 clients have no RequestBattlefieldScoreData), so look
-- them up at call time and never pass a possibly-nil global to C_Timer.
function Core.RequestScores()
  local f = RequestBattlefieldScoreData or (C_PvP and C_PvP.RequestBattlefieldScoreData)
  if f then
    pcall(f)
  end
end

-- Globals Highground calls; ADDON_LOADED records any this client lacks
-- (HighgroundDB.apiMissing, shown by /hg err) so a stripped one shows up at
-- once instead of as an error deep in a match.
Core.API_USED = {
  "GetNumBattlefieldScores", "GetBattlefieldScore", "SetBattlefieldScoreFaction", "RequestBattlefieldScoreData",
  "GetBattlefieldInstanceRunTime", "GetBattlefieldArenaFaction", "GetNumGroupMembers", "GetRaidRosterInfo",
  "IsInRaid", "UnitName", "UnitExists", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax", "UnitPowerMax",
  "UnitIsUnit", "GetRaidTargetIndex", "UnitClass", "UnitLevel", "UnitFactionGroup", "IsInInstance", "GetInstanceInfo",
  "GetNumClasses", "GetClassInfo", "GetSpecializationInfoForClassID", "GetSpecialization",
  "GetSpecializationInfo", "InCombatLockdown", "PlaySound", "PlaySoundFile", "GetNormalizedRealmName",
  "IsShiftKeyDown", "CombatLogGetCurrentEventInfo", "CreateColor",
}

-- Client rules. Retail and WoW Forever (Midnight) hide most enemy data behind
-- secret values; Cataclysm Classic exposes health, specs and the combat log,
-- so its settings catalog has extra live signals. Behavior that depends on
-- the API asks ns.Caps (config/Client.lua) instead.
Core.IS_RETAIL = ns.CLIENT == "retail"

Core.DEFAULTS = {
  rows = 40, -- show every enemy; /hg rows caps it
  scale = ns.UIConfig.scale.default,
  compact = false,
  bgAlpha = ns.UIConfig.opacity.default,
  locked = false,
  quickCalls = false,
  quickCallsDestinations = false,
  quickCallsRoutes = false,
  allBGs = ns.Caps.allBattlegrounds, -- every battleground on every client
  sound = true,
  sniper = true,
  pressure = true,
  pressureCount = 3,
  sniperY = -62,
  sniperVersion = 4,
  sniperColor = "magenta",
  callChannel = "s",
  markIcon = 8, -- raid marker index used by HighgroundMarkButton (8 = skull)
  markMode = ns.Caps.pings and "ping" or "icon", -- "ping" (team ping, Midnight client only) or "icon" (raid target icon)
  pingType = "attack",
  sniperScale = 1,
  sniperSound = 1, -- index into SNIPER_SOUNDS; 0 = off
  soundVersion = 2,
  history = {},
}

-- Window positions are saved per character (HighgroundCharDB); these keys
-- used to live in the account-wide HighgroundDB.
Core.POSITION_KEYS = { "point", "timersPoint", "basesPoint", "flagsPoint", "arenaPoint", "nearbyPoint", "quickCallsPoint" }

for _, option in ipairs(ns.OptionsConfig.behavior) do Core.DEFAULTS[option.key] = option.def end

-- Target recommendations switch: off removes every priority-driven output
-- (panel, hero, keybinds, GO sound, map mark); the scope follows your target.
function Core.PriorityOn()
  return Core.On("killorder")
end

-- Feature switches (config/Options.lua features): nil means on.
function Core.On(key)
  return not (Core.db and Core.db[key] == false)
end

Core.MAX_ROWS = 40 -- enemy rows at most: every enemy in the largest battlegrounds
Core.enemies = {} -- [canonName] = entry
Core.order = {} -- entries ranked by priority, independent of row positions
Core.displayOrder = {} -- stable roster order unless priority sorting is enabled
ns.Test = ns.Test or {}
ns.Test.order = Core.order
Core.unitFor = {} -- [canonName] = unit token visible this tick
Core.me = {}
Core.active, Core.testMode = false, false

-- Core.boundKey tracks the secure target; Core.lastError records the first guarded failure.

-- Readability counters, saved for diagnosis (HighgroundDB.liveStats).
function Core.Stat(group, kind)
  Core.db.liveStats = Core.db.liveStats or {}
  local g = Core.db.liveStats[group] or {}
  Core.db.liveStats[group] = g
  g[kind] = (g[kind] or 0) + 1
end

