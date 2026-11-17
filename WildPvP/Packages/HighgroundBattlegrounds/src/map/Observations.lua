local _, ns = ...
local Intel = ns.Intel

-- Local sightings (1/s), combat log, sharing (every 2s)
---------------------------------------------------------------------------
Intel.mine = {} -- [key] = true: direct sightings / deaths to broadcast
local lastMap

function Intel.ResetIntel(mapID)
  wipe(Intel.intel)
  wipe(Intel.mine)
  wipe(Intel.keyCache)
  wipe(Intel.allyArea)
  wipe(Intel.allyUnit)
  wipe(Intel.poiCache)
  wipe(Intel.corners)
  wipe(Intel.lastAnchor)
  Intel.cachedMap, lastMap, Intel.lastMapForRecord = mapID, mapID, mapID
end

function Intel.EnsureMap(mapID)
  if mapID ~= lastMap then Intel.ResetIntel(mapID) end
end

-- Which area names this battleground reports (for /hg intel and tuning).
function Intel.LogArea(mapID, area)
  local db = Intel.DB()
  if not (db and mapID and area) then
    return
  end
  db.areasSeen = db.areasSeen or {}
  local m = db.areasSeen[mapID] or {}
  db.areasSeen[mapID] = m
  if not m[area] then
    local n = 0
    for _ in pairs(m) do
      n = n + 1
    end
    if n >= 60 then
      return
    end
  end
  m[area] = math.min((m[area] or 0) + 1, 1e6)
end

function Intel.Scan()
  local mapID = Intel.MapID()
  Intel.EnsureMap(mapID)
  Intel.RebuildAllies()
  if not mapID or not ns.enemies then
    return
  end
  local now = GetTime()
  Intel.lastMapForRecord = mapID
  local mx, my, marea, mhow, mextra, mnear = Intel.Guess(mapID, "player", Intel.myName, now)
  Intel.LogArea(mapID, Intel.MyArea())
  for key, e in pairs(ns.enemies) do
    if e.dead then
      local cur = Intel.intel[key]
      if cur and not cur.dead then
        Intel.Died(key, now)
        Intel.mine[key] = true
      end
    elseif e.unit then
      local x, y = Intel.UnitXY(mapID, e.unit)
      local yards = Intel.plain(e.yards) and type(e.yards) == "number" and e.yards >= 0 and e.yards or nil
      local nearby = e.plateUnit or (yards and yards <= 40)
      local recorded
      if x then
        recorded = Intel.Record(key, x, y, 3, Intel.myName, now, nil, "coords")
      elseif nearby then
        local how = mhow == "coords" and "nearby" or mhow
        local r = how == "recent" and mextra or how == "area" and 80 or yards or 40
        recorded = Intel.Record(key, mx, my, r, Intel.myName, now, marea, how, mnear)
      end
      if recorded then
        Intel.mine[key] = true
        Intel.stats.mine = Intel.stats.mine + 1
      end
    end
  end
  -- A teammate may keep a distant enemy targeted. Only that enemy's own
  -- coordinates justify a position; the teammate's location does not.
  for name, unit in pairs(Intel.allyUnit) do
    if unit ~= "player" then
      local key = ns.CanonUnit and ns.CanonUnit(unit .. "target")
      local e = key and ns.enemies[key]
      if e and not e.dead then
        local ax, ay = Intel.UnitXY(mapID, unit .. "target")
        if ax and Intel.Record(key, ax, ay, 3, name, now, nil, "coords") then
          Intel.stats.ally = Intel.stats.ally + 1
        end
      end
    end
  end
  Intel.ScanFlags(mapID, now)
end

-- Named banner interactions prove the player was at that node when the
-- announcement arrived. The later faction-only ownership message does not.
-- English templates: Firelands broadcast_text 10199-10202, 10284-10287,
-- 45887-45894 and 45903-45910 (Arathi / Gilneas).
local NODE_ACTIONS = {
  "^(.+) has assaulted the (.-)!$",
  "^(.+) has defended the (.-)!$",
  "^(.+) claims the (.-)!",
}
local function AnnouncedEnemy(name)
  if name:find("-", 1, true) then return ns.enemies[name] and name end
  local found
  for key in pairs(ns.enemies) do
    if key:match("^[^-]+") == name then
      if found then return nil end -- ambiguous names across realms
      found = key
    end
  end
  return found
end

function Intel.OnNodeChat(event, message)
  -- Only named enemies are recorded. The channel is the character's faction,
  -- which in cross-faction games is not the team, so it is not a filter.
  if not (event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE")
    or not Intel.plain(message) or type(message) ~= "string" or not ns.enemies then return end
  local mapID = Intel.MapID()
  local rules = Intel.RulesForMap(mapID)
  if not (rules and rules.capture and rules.capture.seconds) then return end
  local clean = message:gsub("|H[^|]+|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local who, area
  for _, pattern in ipairs(NODE_ACTIONS) do
    who, area = clean:match(pattern)
    if who then break end
  end
  Intel.RebuildAllies()
  if who and Intel.allyUnit[who:match("^[^-]+")] then return end -- a teammate sharing an enemy's name
  local key = who and AnnouncedEnemy(who)
  if not key or not area or area == "" then return end
  Intel.EnsureMap(mapID)
  local x, y = Intel.AreaXY(mapID, area)
  if not Intel.ValidXY(x, y) then return end
  if Intel.Record(key, x, y, 10, "battleground announcement", GetTime(), area, "objective") then
    ns.enemies[key].dead = false
    Intel.stats.node = (Intel.stats.node or 0) + 1
  end
end

-- Swings and configured targeted casts prove proximity at the event time.
-- Periodic damage, projectiles and aura events can continue after the enemy
-- leaves, so arbitrary damage events cannot refresh intel.
local MELEE = { SWING_DAMAGE = true, SWING_MISSED = true }
function Intel.OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName, _, _, spellID = CombatLogGetCurrentEventInfo()
  local radius = MELEE[sub] and 8 or (ns.CombatSightRadius and ns.CombatSightRadius(sub, spellID))
  if not radius or not (srcName and dstName) or not ns.enemies then
    return
  end
  Intel.RebuildAllies()
  local srcShort, dstShort = srcName:match("^[^-]+"), dstName:match("^[^-]+")
  local enemyName, allyName
  if Intel.allyUnit[dstShort] and not Intel.allyUnit[srcShort] then
    enemyName, allyName = srcName, dstShort
  elseif Intel.allyUnit[srcShort] and not Intel.allyUnit[dstShort] then
    enemyName, allyName = dstName, srcShort
  else
    return
  end
  local key = Intel.EnemyKey(enemyName)
  local e = key and ns.enemies[key]
  if not e or e.dead then
    return
  end
  local mapID = Intel.MapID()
  if not mapID then
    return
  end
  local now = GetTime()
  local x, y, area, how, extra, near = Intel.Guess(mapID, Intel.allyUnit[allyName], allyName, now)
  if how == "recent" then
    radius = extra
  elseif how == "area" then
    radius = 80 + extra
  elseif how == "coords" then
    radius = radius + extra
  end
  local ex, ey
  if e.unit then ex, ey = Intel.UnitXY(mapID, e.unit) end
  if ex then
    x, y, area, how, radius, near = ex, ey, nil, "coords", 3, nil
  else
    how = how == "coords" and "nearby" or how
  end
  if Intel.Record(key, x, y, radius, allyName, now, area, how, near) then
    Intel.stats.log = Intel.stats.log + 1
    if allyName == Intel.myName then
      Intel.mine[key] = true
    end
  end
end
