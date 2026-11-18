local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Labels for the timer windows and map pins: team colours, and what to
-- call a graveyard (full name for rows and hovers, short one for pins).
---------------------------------------------------------------------------
local Theme = ns.Theme

-- Live colour of a team's side (unknown: the enemy's).
function Timers.TeamColor(team)
  return Timers.FACTION_COLOR[team] or Timers.FACTION_COLOR[Timers.Other(Timers.MyTeam())]
end

-- "|cffRRGGBB" of a theme colour (live table or token name).
function Timers.Hex(c)
  return Theme.Hex(type(c) == "string" and c or Theme.Token(c) or "text")
end

-- Alias of Theme.TipLine(tt, text, color[, wrap]), kept for the timer,
-- arena, flag and nearby windows.
Timers.TipLine = Theme.TipLine

-- The game's graveyard list for this map (name + spot), if it gives one.
Timers.GameGraveyards = function(mapID, refresh)
  if not mapID then
    return false
  end
  if not refresh and Timers.gameGYs[mapID] ~= nil then
    return Timers.gameGYs[mapID]
  end
  local out = {}
  local f = C_DeathInfo and C_DeathInfo.GetGraveyardsForMap
  local ok, list = false, nil
  if f then
    ok, list = pcall(f, mapID)
  end
  for _, g in ipairs(ok and type(list) == "table" and list or {}) do
    local p = g.position
    local x, y
    if type(p) == "table" then
      x, y = p.x, p.y
      if x == nil and p.GetXY then
        x, y = p:GetXY()
      end
    end
    if Timers.plain(x) and Timers.plain(y) and type(x) == "number" and type(y) == "number"
      and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
      out[#out + 1] = { id = Timers.plain(g.graveyardID) and g.graveyardID or nil,
        name = Timers.plain(g.name) and g.name ~= "" and g.name or nil, x = x, y = y }
    end
  end
  Timers.gameGYs[mapID] = #out > 0 and out or false
  return Timers.gameGYs[mapID]
end

-- Flag maps: graveyards named by side. Each team's base -> "<side> base",
-- between them -> "mid" (or "mid, <side> side" when clearly on one half).
function Timers.SideName(g)
  local rules = Timers.Rules()
  local sides = rules.map and rules.map.sides
  if not sides then
    return nil
  end
  if not g.x then
    return rules.graveyards and rules.graveyards.single and g.team and (sides[g.team] .. " base") or nil
  end
  local bases, m = rules.map.bases, Timers.MapID()
  local ax, ay, hx, hy
  if bases and ns.AreaXY and m then
    ax, ay = ns.AreaXY(m, bases.A)
    hx, hy = ns.AreaXY(m, bases.H)
  end
  if not (ax and hx) then
    return nil
  end
  local dA = math.sqrt((g.x - ax) ^ 2 + (g.y - ay) ^ 2)
  local dH = math.sqrt((g.x - hx) ^ 2 + (g.y - hy) ^ 2)
  local span = math.sqrt((ax - hx) ^ 2 + (ay - hy) ^ 2)
  if math.min(dA, dH) <= span * 0.25 then
    return sides[dA < dH and "A" or "H"] .. " base"
  end
  if math.abs(dA - dH) <= span * 0.15 then
    return "mid"
  end
  return "mid, " .. sides[dA < dH and "A" or "H"] .. " side"
end

local ROUGH_WORDS = { ["?"] = true, mid = true, north = true, ["north-east"] = true, east = true,
  ["south-east"] = true, south = true, ["south-west"] = true, west = true, ["north-west"] = true }

-- What to call a graveyard: base/node name > the game's graveyard name >
-- a real area name > side of a flag map > rough compass > "".
function Timers.GYName(g)
  if g.configured then return g.label end
  if g.node then
    return g.node
  end
  if g.x then
    local list = Timers.GameGraveyards(Timers.MapID())
    local best, bestD
    for _, gg in ipairs(list or {}) do
      local d = (gg.x - g.x) ^ 2 + (gg.y - g.y) ^ 2
      if gg.name and (not bestD or d < bestD) then
        best, bestD = gg.name, d
      end
    end
    if best and bestD <= 0.06 ^ 2 then
      return best
    end
  end
  if g.label and g.label ~= "graveyard" and not g.fromPlace then
    return g.label
  end
  -- next to a map landmark (a base / node): its name
  local near = g.x and Timers.Place(g.x, g.y)
  if near and not ROUGH_WORDS[near] then
    return near
  end
  local side = Timers.SideName(g)
  if side then
    return side
  end
  if g.x then
    return Timers.Place(g.x, g.y)
  end
  return ""
end
ns.Test = ns.Test or {}
ns.Test.GYName = Timers.GYName

-- Pins use compact names; identity matching, timer rows and hover text keep
-- the full name. BG-specific abbreviations live with the battleground rules.
local GY_MAP_WORDS = { graveyard = "", alliance = "A", horde = "H", starting = "Start", middle = "Mid" }
function Timers.GYMapName(g)
  local name = (Timers.GYName(g) or ""):gsub("%a+", function(word)
    return GY_MAP_WORDS[word:lower()] or word
  end):gsub("%s+", " "):match("^%s*(.-)%s*$")
  local config = Timers.Rules().graveyards
  local labels = config and config.mapLabels
  return labels and labels[name:lower()] or name
end
