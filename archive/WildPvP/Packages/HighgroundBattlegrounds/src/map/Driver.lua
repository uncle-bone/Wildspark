local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Map intel driver: the scan and share ticker, game events, the received
-- intel messages (core/Comms.lua) and /hg intel status.
---------------------------------------------------------------------------
local Util = ns.Util
local Pins = ns.MapPins -- nil when Pins.xml failed to load

local function Running()
  return ns.IsActive() and Intel.Enabled()
end

-- Status snapshot in the saved data (readable after /reload or logout).
local function Snapshot()
  local db = Intel.DB()
  if not db then return end
  local ok, line = pcall(Intel.Status)
  db.diag = { t = date("%H:%M:%S"), intel = ok and line or ("status error: " .. tostring(line)),
    timers = ns.TimersStatus and select(2, pcall(ns.TimersStatus)) or "n/a",
    pinErr = Pins and Pins.stats.lastError, providers = Pins and Pins.Providers() or 0 }
end

-- Every second: scan; every SEND_EVERY seconds: share; every 5s: snapshot.
local sendT, diagT = 0, 0
Intel.ticker = Util.Every(1, function(elapsed)
  if not Running() then
    Intel.ResetIntel(nil)
    sendT, diagT = 0, 0
    return
  end
  sendT, diagT = sendT + elapsed, diagT + elapsed
  if diagT >= 5 then
    diagT = 0
    Util.Guard("intel status", Snapshot)
  end
  Intel.Try("scan", Intel.Scan)
  if sendT >= Intel.SEND_EVERY then
    sendT = 0
    Intel.Try("send", Intel.Send)
  end
end, "intel tick")

-- Handlers that only run in an active battleground with the map on.
local function WhileRunning(fn)
  return function(...)
    if Running() then fn(...) end
  end
end

local handlers = {
  PLAYER_LOGIN = function()
    Intel.myName = UnitName("player")
  end,
  PLAYER_ENTERING_WORLD = function()
    Intel.ResetIntel(nil)
    sendT, diagT = 0, 0
    Intel.ticker.Start()
  end,
  -- A loading screen can expose only part of the landmark list. Retry
  -- when the client fills it in instead of caching that subset for the match.
  AREA_POIS_UPDATED = WhileRunning(function()
    wipe(Intel.poiCache)
  end),
  CHAT_MSG_BG_SYSTEM_ALLIANCE = WhileRunning(function(event, message)
    Intel.Try("node announcement", Intel.OnNodeChat, event, message)
  end),
}
handlers.CHAT_MSG_BG_SYSTEM_HORDE = handlers.CHAT_MSG_BG_SYSTEM_ALLIANCE
if CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = WhileRunning(function()
    Intel.Try("combatlog", Intel.OnCombatLog)
  end)
end
Intel.events = Util.Events(handlers, "intel events")
ns.Comms.Listen(Intel.PREFIX, WhileRunning(function(text, _, sender)
  Intel.Try("receive", Intel.Receive, text, sender)
end), "intel events")

-- /hg intel test toggles a test pin mid-map.
function Intel.ToggleTestPin()
  Intel.testPins = not Intel.testPins
  return Intel.testPins
end

-- What this client gives us, for /hg intel.
function Intel.Probe()
  local missing = {}
  for _, path in ipairs({ "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition", "C_AreaPoiInfo.GetAreaPOIForMap",
    "C_ChatInfo.SendAddonMessage", "GetSubZoneText", "GetBattlefieldFlagPosition", "GetAreaSpiritHealerTime",
    "CombatLogGetCurrentEventInfo", "UnitIsGhost", "C_DeathInfo.GetDeathReleasePosition" }) do
    local space, fn = path:match("^(.-)%.?([^.]+)$")
    local t = space ~= "" and _G[space] or _G
    if type(t) ~= "table" or type(t[fn]) ~= "function" then
      missing[#missing + 1] = path
    end
  end
  return #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or "all APIs present"
end

function Intel.Status()
  local known, fresh, placed = 0, 0, 0
  for _, it in pairs(Intel.intel) do
    if not it.dead then
      known = known + 1
      if it.x then
        placed = placed + 1
      end
      if GetTime() - it.t < Intel.FRESH then
        fresh = fresh + 1
      end
    end
  end
  local mapID = Intel.MapID()
  local x, _, area
  if mapID then
    x, _, area = Intel.Locate(mapID, "player", Intel.myName)
  end
  local _, _, how = Intel.AreaXY(mapID, area)
  if x and not how then
    how = select(4, Intel.Locate(mapID, "player", Intel.myName)) or "coords"
  end
  local ps = Pins and Pins.stats or {}
  local db = Intel.DB()
  local seen = {}
  for a, n in pairs(db and db.areasSeen and mapID and db.areasSeen[mapID] or {}) do
    seen[#seen + 1] = { a, n }
  end
  table.sort(seen, function(p, q)
    return p[2] > q[2]
  end)
  for i = 1, #seen do
    seen[i] = i <= 8 and string.format("%s %d", seen[i][1], seen[i][2]) or nil
  end
  local rx = Intel.ReleaseXY(mapID or 0)
  local bg = ns.GetBG()
  local srcLine = string.format(" | node announcements %d | recent-area guesses %d | client %s / rules %s | release spot: now %s, seen alive %d / dead %d | areas: %s",
    Intel.stats.node or 0, Intel.stats.recent or 0, tostring(ns.CLIENT or "unknown"), tostring(bg and bg.rulesKey or "none"),
    rx and "yes" or "no", Intel.src.releaseAlive, Intel.src.releaseDead, #seen > 0 and table.concat(seen, ", ") or "none")
  return string.format("map %s | you: %s%s | enemies known %d (now %d, on map %d) | sightings: yours %d, combat log %d, teammates' targets %d, flag %d | bases learned %d | messages sent %d, received %d | map pins %d (redraws %d) | %s%s%s",
    tostring(mapID), tostring(area or "no area"), x and (" @ " .. (how or "coords")) or " (no spot: not pinned)", known, fresh,
    placed, Intel.stats.mine, Intel.stats.log, Intel.stats.ally, Intel.stats.flag, Intel.stats.learned, Intel.stats.sent, Intel.stats.recv, ps.pins or 0,
    ps.draws or 0, Intel.Probe() .. srcLine,
    Intel.stats.lastError and (" | " .. ns.Theme.TipHex("error") .. "error x" .. Intel.stats.errors .. ": " .. Intel.stats.lastError .. "|r") or "",
    ps.lastError and (" | " .. ns.Theme.TipHex("error") .. "pin error: " .. ps.lastError .. "|r") or "")
end

-- Older names used by commands and the UI.
ns.IntelTest = Intel.ToggleTestPin
ns.IntelStatus = Intel.Status
