local _, ns = ...
local Core = ns.Core

-- Scoring
---------------------------------------------------------------------------
function Core.MatchupEdge(specID, class, reasons)
  local p = Core.Profile(specID)
  local edge = 0
  local matchups = Core.me.specID and ns.Matchups[Core.me.specID]
  local m = matchups and matchups[specID]
  if m then
    if reasons then table.insert(reasons, m[2]) end
    return m[1]
  end
  -- Mixed damage takes half of both the physical and the magic adjustments.
  local phys, magic = ns.DamageShare(Core.me.dmg, "phys"), ns.DamageShare(Core.me.dmg, "magic")
  if phys > 0 then
    local armor = ns.Armor[class]
    if armor == "plate" then
      edge = edge - 0.7 * phys
      if reasons then table.insert(reasons, "plate vs your physical dmg") end
    elseif armor == "cloth" then
      edge = edge + 0.5 * phys
      if reasons then table.insert(reasons, "cloth: good vs physical") end
    end
    if p.physDR then
      edge = edge - 0.6 * phys
      if reasons then table.insert(reasons, "has physical immunity/DR") end
    end
  end
  if magic > 0 and p.magDR then
    edge = edge - 0.6 * magic
    if reasons then table.insert(reasons, "has magic immunity/DR") end
  end
  if Core.me.melee and p.kite then
    edge = edge - 0.8
    if reasons then table.insert(reasons, "kites melee") end
  end
  return edge
end

-- Score components. Each is multiplied by its coefficient (db.weights,
-- default 1.0; /hg weight NAME X). BASE parts order the list, LIVE parts only
-- drive icons and the GO alert (unless /hg live).
Core.WEIGHTS = ns.OptionsConfig.weights

-- Every point value the scoring uses, editable in Options > AddOns >
-- Highground (or /hg points). Overrides live in HighgroundDB.points; a value
-- set back to its default is dropped. cata = only meaningful on Cata Classic.
Core.POINTS = ns.OptionsConfig.points
do
  -- Distance bands come from your client's data (retail and Cata differ).
  local list = {}
  for _, row in ipairs(Core.POINTS) do
    if row.range then
      for _, b in ipairs(ns.ProximityBonus) do
        list[#list + 1] = { key = "range" .. b[1], component = "range", def = b[2], desc = string.format("Within %d yd", b[1]) }
      end
    else
      list[#list + 1] = row
    end
  end
  Core.POINTS = list
end
Core.POINT_DEFAULT = {}
for _, row in ipairs(Core.POINTS) do
  if row.key then
    Core.POINT_DEFAULT[row.key] = row.def
  end
end
-- ns.OptionAvailable (which settings apply to this game): config/Options.lua.

-- A legacy per-spell trinket value used to shadow the general trinket
-- setting. Keep that effective value and remove the duplicate on load/import.
function ns.NormalizePointSettings(points)
  if not points then return end
  for old, key in pairs(ns.OptionsConfig.pointAliases) do
    if points[old] ~= nil then
      points[key], points[old] = points[old], nil
    end
  end
end

function Core.P(key)
  local v = Core.db.points and Core.db.points[key]
  if v ~= nil then
    return v
  end
  return Core.POINT_DEFAULT[key] or 0
end

function Core.W(key)
  local w = (Core.db.weights and Core.db.weights[key]) or 1
  if Core.currentProfile and Core.currentProfile[key] then
    w = w * Core.currentProfile[key]
  end
  return w
end
