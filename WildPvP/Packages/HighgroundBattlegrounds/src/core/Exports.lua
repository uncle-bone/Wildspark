local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Public core API for subsystems loaded after core (map, timers, flags,
-- focus). Prefer these names over ns.Core fields in new code; arena and
-- world still read some ns.Core fields directly. Tables are live and
-- read-only for callers; functions are safe to call before ADDON_LOADED
-- unless noted.
---------------------------------------------------------------------------

-- [canonName] = enemy entry (core/Roster.lua). Same table for the session.
ns.enemies = Core.enemies
-- [specID] = { name, icon, role, class }, filled on ADDON_LOADED.
ns.specInfo = Core.specInfo
-- Unit token -> "Name-Realm", or nil when unreadable.
ns.CanonUnit = Core.CanonUnit

-- Spec details for a specID, or nil.
function ns.GetSpecInfo(specID)
  return specID and Core.specInfo[specID]
end

-- specID for a class token and localized spec name, or nil.
function ns.SpecByName(class, specName)
  local byName = class and Core.specByName[class]
  return byName and specName and byName[specName]
end

-- HighgroundDB (account) and HighgroundCharDB (character positions); nil
-- before ADDON_LOADED.
function ns.GetDB() return Core.db end
function ns.GetPositions() return Core.pos end

-- In a live battleground Highground tracks (not the /hg test preview).
function ns.IsActive() return Core.active and not Core.testMode end
-- The /hg test preview is running.
function ns.IsTestMode() return Core.testMode end

-- The sticky kill target entry, nil when target recommendations are off.
function ns.GetKillNow() return Core.PriorityOn() and Core.killNow or nil end
-- Battleground faction index (0 Horde, 1 Alliance) of your team, or nil.
function ns.GetAllyFaction() return Core.allyFaction end
-- Resolved battleground (config/Battlegrounds.lua) or nil outside one.
function ns.GetBG() return Core.currentBG end
-- Resolved rules are immutable configuration for the current client and mode.
function ns.GetBGRules() return Core.currentBG and Core.currentBG.rules end

ns.FlagStacks = Core.FlagStacks
-- Point value of a scoring setting (Core.P).
ns.P = Core.P
