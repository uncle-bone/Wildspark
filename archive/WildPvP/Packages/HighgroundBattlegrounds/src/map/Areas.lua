local _, ns = ...
local Intel = ns.Intel
local Util = ns.Util

---------------------------------------------------------------------------
-- Areas: sub-zone names and where they are on the map
---------------------------------------------------------------------------
Intel.poiCache = {}
function Intel.Landmarks(mapID)
  if Intel.poiCache[mapID] then
    return Intel.poiCache[mapID]
  end
  local list = {}
  if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo then
    local ids = Util.call(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
      local info = Util.call(C_AreaPoiInfo.GetAreaPOIInfo, mapID, id)
      if info and type(info.name) == "string" and info.name ~= "" and info.position
        and Intel.ValidXY(info.position.x, info.position.y) then
        list[#list + 1] = { name = info.name, x = info.position.x, y = info.position.y }
      end
    end
  end
  if #list > 0 then
    Intel.poiCache[mapID] = list
  end
  return list
end

-- Positions belong to the active client's battleground configuration.
-- Do not reuse them while a different map is open or loading.
function Intel.RulesForMap(mapID)
  local bg = ns.GetBG()
  if not bg then return nil end
  local matches = false
  for _, id in ipairs(bg.ui or {}) do
    if id == mapID then matches = true; break end
  end
  if not matches then return nil end
  return ns.GetBGRules() or bg.rules
end

-- Lower-case names that mean "the battleground in general" (no sub-zone): the open
-- middle in Eye of the Storm / Warsong Gulch, roads elsewhere -> centre.
function Intel.IsZoneKey(mapID, key)
  local names = {}
  local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  names[#names + 1] = info and info.name
  names[#names + 1] = GetZoneText and GetZoneText()
  names[#names + 1] = GetRealZoneText and GetRealZoneText()
  local bg = ns.GetBG()
  names[#names + 1] = bg and bg.name
  names[#names + 1] = (Util.call(GetInstanceInfo))
  for i = 1, 5 do
    local n = names[i]
    if type(n) == "string" and n ~= "" then
      n = n:lower()
      if n == key or n:find(key, 1, true) or key:find(n, 1, true) then
        return true
      end
    end
  end
  return key == ""
end
-- IsZoneKey for an area name in any case (nil is not a zone name).
function Intel.IsZoneName(mapID, area)
  return area ~= nil and Intel.IsZoneKey(mapID, area:lower())
end
ns.IsZoneName = Intel.IsZoneName

-- The spirit healer you would release to, from the death system: your
-- graveyard when dead, the nearest one while alive if the client answers.
Intel.src = { releaseAlive = 0, releaseDead = 0 }
function Intel.DeathPos(fn, mapID)
  local f = C_DeathInfo and C_DeathInfo[fn]
  if not (f and mapID) then
    return nil
  end
  local pos = Util.call(f, mapID)
  if type(pos) == "table" then
    local x, y = pos.x, pos.y
    if x == nil and pos.GetXY then
      x, y = pos:GetXY()
    end
    if Intel.plain(x) and Intel.plain(y) and x and y and (x ~= 0 or y ~= 0) then
      return x, y
    end
  end
end
function Intel.ReleaseXY(mapID)
  local x, y = Intel.DeathPos("GetDeathReleasePosition", mapID)
  if x then
    local k = UnitIsDeadOrGhost("player") and "releaseDead" or "releaseAlive"
    Intel.src[k] = Intel.src[k] + 1
  end
  return x, y
end
ns.ReleaseXY = Intel.ReleaseXY

local function MatchesArea(key, name)
  local n = name:lower()
  return n == key or key:find(n, 1, true) or n:find(key, 1, true)
end

function Intel.AreaXY(mapID, area)
  if not (mapID and area) then
    return nil
  end
  local key = area:lower()
  local db = Intel.DB()
  -- Legacy anchors included guessed flag-room samples from dropped-flag
  -- pickups. Keep that saved data untouched, but do not reuse its positions.
  local l = db and db.observedAnchors and db.observedAnchors[mapID] and db.observedAnchors[mapID][key]
  if l then
    return l[1], l[2], "learned"
  end
  for _, p in ipairs(Intel.Landmarks(mapID)) do
    if MatchesArea(key, p.name) then
      return p.x, p.y, "landmark"
    end
  end
  local rules = Intel.RulesForMap(mapID)
  local map = rules and rules.map
  local r = map and map.anchors and map.anchors[key]
  if r then
    return r[1], r[2], "rough"
  end
  -- Reuse configured capture points when live landmarks are unavailable.
  -- Only the control node locates the area; the graveyard itself does not.
  -- Use the same name matching as live POIs (e.g. Mine / Mines).
  for _, graveyard in ipairs(rules and rules.graveyards and rules.graveyards.nodes or {}) do
    local node = graveyard.node
    if node and node.name and Intel.ValidXY(node.x, node.y) and MatchesArea(key, node.name) then
      return node.x, node.y, "rough"
    end
  end
  if map and map.zoneCenter and Intel.IsZoneKey(mapID, key) then
    return map.zoneCenter[1], map.zoneCenter[2], "centre"
  end
end
ns.AreaXY = Intel.AreaXY

-- Learned spots are running averages of the player's known flag position
-- in that area. A pickup anywhere on the map cannot locate a flag room.
function Intel.LearnAnchor(mapID, area, x, y)
  local db = Intel.DB()
  if not (db and mapID and area and x) then
    return
  end
  db.observedAnchors = db.observedAnchors or {}
  db.observedAnchors[mapID] = db.observedAnchors[mapID] or {}
  local key = area:lower()
  local a = db.observedAnchors[mapID][key]
  local n = a and math.min(a[3] or 1, 30) or 0
  if a then
    db.observedAnchors[mapID][key] = { (a[1] * n + x) / (n + 1), (a[2] * n + y) / (n + 1), n + 1 }
  else
    db.observedAnchors[mapID][key] = { x, y, 1 }
  end
  Intel.stats.learned = Intel.stats.learned + 1
end

function Intel.MyArea()
  local a = GetSubZoneText and GetSubZoneText()
  if not a or a == "" then
    a = GetMinimapZoneText and GetMinimapZoneText()
  end
  return (a and a ~= "") and a or nil
end
ns.MyArea = Intel.MyArea

Intel.myName = UnitName("player")
Intel.allyArea = {} -- [teammate name] = { area, t } from their broadcasts
function Intel.AllyArea(name)
  local a = Intel.allyArea[name]
  return a and GetTime() - a.t < 15 and a.area or nil
end

-- Where a unit is: coordinates if available, else its area (+ anchor).
-- A resurrection destination is not the unit's current location. Timers
-- query ReleaseXY separately when they actually need a spirit guide.
function Intel.Locate(mapID, unit, name)
  local x, y = Intel.UnitXY(mapID, unit)
  if x then
    return x, y, nil, "coords"
  end
  local area = unit == "player" and Intel.MyArea() or Intel.AllyArea(name)
  local ax, ay
  if area then
    ax, ay = Intel.AreaXY(mapID, area)
  end
  return ax, ay, area, ax and "area" or "unknown"
end
ns.Locate = Intel.Locate

-- Map-only inference on top of Locate. Timers keep using Locate: a guess
-- here must never pass for a resurrection graveyard.
--   * A teammate without Highground (no area broadcast) who is in group range
--     of you is in your area.
--   * An observer in a broad or unanchored area (roads, "Arathi Basin",
--     "Twin Peaks") just left the last anchored area they were in; for a
--     few seconds that anchor is a fair guess, with a growing radius.
Intel.RECENT = 15 -- seconds a left anchor still locates its observer
Intel.lastAnchor = {} -- [observer name] = { x, y, area, t }

function Intel.NearPlayer(unit)
  if not unit or unit == "player" then
    return false
  end
  if UnitInRange then
    local inRange, checked = Util.call(UnitInRange, unit)
    if Intel.plain(inRange) and Intel.plain(checked) and checked then
      return inRange and true or false
    end
  end
  if CheckInteractDistance then
    if Util.read(CheckInteractDistance, unit, 4) then -- ~28 yards
      return true
    end
  end
  return false
end

function Intel.Guess(mapID, unit, name, now)
  local x, y, area, how = Intel.Locate(mapID, unit, name)
  local radius = 0
  if not area and how == "unknown" and Intel.NearPlayer(unit) then
    x, y, area, how = Intel.Locate(mapID, "player", Intel.myName)
    unit, name, radius = "player", Intel.myName, 40
  end
  if Util.read(UnitIsDeadOrGhost, unit) then
    Intel.lastAnchor[name or ""] = nil -- a resurrection breaks the trail
  elseif how == "area" and area and not Intel.IsZoneName(mapID, area) then
    Intel.lastAnchor[name or ""] = { x = x, y = y, area = area, t = now }
  elseif not x and name then
    local last = Intel.lastAnchor[name]
    local age = last and now - last.t
    if age and age >= 0 and age <= Intel.RECENT then
      return last.x, last.y, area, "recent", radius + 80 + 7 * age, last.area
    end
  end
  return x, y, area, how, radius
end

-- Text for a spot: its area name, else nearest landmark, else compass.
local COMPASS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
function Intel.Place(x, y)
  if not x then
    return "?"
  end
  local mapID = Intel.MapID()
  local best, bestD
  for _, l in ipairs(mapID and Intel.Landmarks(mapID) or {}) do
    local d = (l.x - x) ^ 2 + (l.y - y) ^ 2
    if not bestD or d < bestD then
      best, bestD = l.name, d
    end
  end
  if best and bestD < 0.15 ^ 2 then
    return best
  end
  local dx, dy = x - 0.5, 0.5 - y
  if dx * dx + dy * dy < 0.1 ^ 2 then
    return "mid"
  end
  local angle = math.deg(math.atan2(dx, dy)) % 360
  return COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1]
end
ns.Place = Intel.Place
