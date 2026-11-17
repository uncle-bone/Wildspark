local _, ns = ...
ns.Intel = {}
local Intel = ns.Intel

-- Battleground intel map: rough enemy locations, shared with teammates who
-- run Highground, drawn on the world map and the battlefield map (Shift+M)
-- through the pin layer in map/Pins.lua.
--
-- Inside battlegrounds this client hides coordinates from addons: map
-- position and UnitPosition both return nil (Blizzard draws teammates on
-- the map natively). What IS readable, and what this is built on:
--   * your own sub-zone name ("Stables", "Silverwing Hold", "Lumber Mill")
--   * map landmark positions (bases / nodes)
--   * flag positions (the game's own flag API)
-- So a location is an AREA: an enemy you see is "in your area"; it's pinned
-- at that area's anchor: the landmark of the same name, positions sampled
-- while carrying a flag (saved for next time), or a rough built-in spot.
-- Enemy flag carriers are pinned at the exact flag.
-- Map-only guesses (Intel.Guess): a teammate in range of you is in your
-- area; an observer on a road is near the anchored area just left.
-- Enemies still without a spot get no pin: no marker beats a wrong one.
-- Sources, all automatic: readable enemy coordinates, nearby nameplates or
-- measured spell ranges, targeted Cata casts and melee attacks, and teammates
-- running Highground (their sightings, deaths
-- and current area, every 2s). Coordinates are still used when a client
-- does provide them (outside instances, other clients).
-- Pins: fresh (seen in the last 4s) = full color; not seen since = greyer,
-- fainter and smaller the older it gets, with "last seen" age (vanish,
-- stealth, LoS); a new sighting replaces it;
-- death removes it; anything older than 2 minutes is dropped.

Intel.PREFIX = "HighgroundI"
Intel.FRESH = 4 -- seconds a sighting counts as "here now"
Intel.KEEP = 120 -- seconds a last-seen pin stays
Intel.SEND_EVERY = 2

Intel.intel = {} -- [enemyKey] = { x, y, r, t, by, area } or { dead = true, t }
ns.Test = ns.Test or {}
ns.Test.intel = Intel.intel
Intel.stats = { sent = 0, recv = 0, mine = 0, ally = 0, log = 0, flag = 0, learned = 0 }

Intel.plain = ns.Util.plain

function Intel.ValidXY(x, y)
  return Intel.plain(x) and Intel.plain(y) and type(x) == "number" and type(y) == "number"
    and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0)
end

function Intel.DB()
  return ns.GetDB()
end

-- Feature switches (Options): nil means on. False before the saved data loads.
function Intel.On(key)
  return Intel.DB() ~= nil and ns.Core.On(key)
end

function Intel.Enabled()
  return Intel.On("intel")
end

-- Util.Guard, plus the first failure kept in stats and HighgroundDB.intelErr
-- (shown by /hg intel, read after /reload).
function Intel.Try(stage, fn, ...)
  local ok, err = ns.Util.Guard("intel " .. stage, fn, ...)
  if not ok then
    Intel.stats.errors = (Intel.stats.errors or 0) + 1
    Intel.stats.lastError = Intel.stats.lastError or (stage .. ": " .. tostring(err):match("^[^\n]*"))
    local db = Intel.DB()
    if db then
      db.intelErr = Intel.stats.lastError
    end
  end
end

Intel.MyTeam = ns.Util.MyTeam

---------------------------------------------------------------------------
-- Map ID and coordinates (when the client gives them)
---------------------------------------------------------------------------
-- Map ID: the game's answer, or the last good one (it can come back nil
-- for a moment, e.g. right after a loading screen).

function Intel.MapID()
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and Intel.plain(id) and id then
    Intel.cachedMap = id
    return id
  end
  if ns.IsActive() then
    return Intel.cachedMap
  end
end
ns.CurrentMapID = Intel.MapID

-- Map position 0-1: C_Map.GetPlayerMapPosition, else UnitPosition projected
-- through the map's world-space corners. Both are nil in battlegrounds on
-- some Cata clients; kept for clients/places where they work.
Intel.corners = {}
function Intel.Corners(mapID)
  if Intel.corners[mapID] then
    return Intel.corners[mapID]
  end
  if C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local ok1, instance, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local ok2, otherInstance, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0.5, 0.5))
    -- Both APIs return north/south first, east/west second. Normalized map
    -- x is the SECOND world axis. Never guess an orientation that fits.
    -- Use the center: the (1,1) edge is inaccurate on some maps.
    -- Reference: HereBeDragons-2.0 processMap/GetUnitWorldPosition.
    if ok1 and ok2 and a and b and Intel.plain(instance) and Intel.plain(otherInstance) and instance == otherInstance
      and Intel.plain(a.x) and Intel.plain(a.y) and Intel.plain(b.x) and Intel.plain(b.y)
      and type(a.x) == "number" and type(a.y) == "number"
      and type(b.x) == "number" and type(b.y) == "number" and a.x ~= b.x and a.y ~= b.y then
      Intel.corners[mapID] = { north = a.x, west = a.y, height = 2 * (b.x - a.x),
        width = 2 * (b.y - a.y), instance = instance }
    end
  end
  return Intel.corners[mapID]
end

function Intel.UnitXY(mapID, unit)
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
  if ok and pos then
    local x, y = pos.x, pos.y
    if Intel.ValidXY(x, y) then
      return x, y
    end
  end
  local okU, north, west, _, instance = pcall(UnitPosition, unit)
  local c = okU and Intel.plain(north) and Intel.plain(west) and type(north) == "number" and type(west) == "number"
    and Intel.plain(instance) and Intel.Corners(mapID)
  if c and instance == c.instance then
    local u, v = (west - c.west) / c.width, (north - c.north) / c.height
    if Intel.ValidXY(u, v) then return u, v end
  end
end
ns.UnitXY = Intel.UnitXY
