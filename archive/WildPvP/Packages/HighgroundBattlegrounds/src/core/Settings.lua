local _, ns = ...
local Core = ns.Core

-- One schema for UI edits, commands, saved variables and profile imports.
Core.SettingDefs = { point = {}, weight = {}, option = {}, spec = {
  k = { min = 0, max = 15, unit = "rating" }, i = { min = 0, max = 15, unit = "rating" },
} }
for _, row in ipairs(Core.POINTS) do
  if row.key then
    row.min = row.min or (row.def < 0 and -500 or 0)
    row.max = row.max or (row.def < 0 and 0 or 500)
    row.unit = row.unit or "points"
    Core.SettingDefs.point[row.key] = row
  end
end
for _, row in ipairs(Core.WEIGHTS) do
  Core.SettingDefs.weight[row.key] = { min = 0, max = 5, def = 1, unit = "multiplier", cata = row.cata, retail = row.retail }
end
for _, row in ipairs(ns.OptionsConfig.behavior) do Core.SettingDefs.option[row.key] = row end
for _, list in pairs(ns.Kits or {}) do
  for _, entry in ipairs(list) do
    if entry[3] == "immune" or entry[3] == "def" then
      Core.SettingDefs.point["kit" .. entry[1]] = { min = 0, max = 500, unit = "points", component = "cooldowns", cata = true }
    end
  end
end

function Core.O(key)
  local value = Core.db and Core.db[key]
  if value ~= nil then return value end
  local def = Core.SettingDefs.option[key]
  return def and def.def
end

function Core.ValidateSetting(kind, key, value)
  if kind == "kitspell" then kind = "point" end
  local def = Core.SettingDefs[kind] and Core.SettingDefs[kind][key]
  if not def then return nil, "unknown setting " .. tostring(key) end
  if def.type == "boolean" then
    if type(value) == "boolean" then return value end
    return nil, key .. " must be true or false"
  end
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
    return nil, key .. " must be a finite number"
  end
  if value < def.min or value > def.max or (def.integer and value ~= math.floor(value)) then
    return nil, string.format("%s must be %s–%s %s%s", key, def.min, def.max, def.unit, def.integer and " (whole numbers)" or "")
  end
  return math.floor(value * 100 + 0.5) / 100
end

function Core.ValidateRelations(options, points)
  if options.goWindow > options.spentWindow then return false, "GO window must not exceed the defensive-spent window" end
  local min = points.dieResMin or Core.POINT_DEFAULT.dieResMin
  local max = points.dieResMax or Core.POINT_DEFAULT.dieResMax
  if min > max then return false, "Minimum resurrection time must not exceed the maximum" end
  return true
end

function Core.SetTuning(kind, key, value, specID)
  local normalized, err = Core.ValidateSetting(kind, kind == "spec" and key or (ns.OptionsConfig.pointAliases[key] or key), value)
  if normalized == nil then return false, err end
  if kind == "spec" and not Core.specInfo[specID] then return false, "unknown specialization" end
  key = ns.OptionsConfig.pointAliases[key] or key
  local options, points = {}, {}
  for name in pairs(Core.SettingDefs.option) do options[name] = Core.O(name) end
  for name, v in pairs(Core.db.points or {}) do points[name] = v end
  if kind == "option" then options[key] = normalized end
  if kind == "point" or kind == "kitspell" then points[key] = normalized end
  local ok, relation = Core.ValidateRelations(options, points)
  if not ok then return false, relation end
  if kind == "spec" then
    Core.db.specRatings = Core.db.specRatings or {}
    local ratings = Core.db.specRatings[specID] or {}
    ratings[key] = normalized ~= Core.BaseProfile(specID)[key] and normalized or nil
    Core.db.specRatings[specID] = next(ratings) and ratings or nil
    wipe(Core.profileCache)
  elseif kind == "option" then
    Core.db[key] = normalized
    if key == "executePct" then Core.BuildCurve() end
  else
    local name = kind == "weight" and "weights" or "points"
    Core.db[name] = Core.db[name] or {}
    local def = Core.SettingDefs[kind == "kitspell" and "point" or kind][key]
    Core.db[name][key] = (kind == "kitspell" or normalized ~= def.def) and normalized or nil
  end
  return true
end

-- Invalid saved values fall back to defaults; interactive imports reject
-- invalid data before applying anything. Retired keys are dropped here.
function Core.NormalizeTuning(db)
  db.points = type(db.points) == "table" and db.points or {}
  ns.NormalizePointSettings(db.points)
  for field, kind in pairs({ points = "point", weights = "weight" }) do
    local clean = {}
    for key, value in pairs(type(db[field]) == "table" and db[field] or {}) do
      local checked = Core.ValidateSetting(kind, key, value)
      if checked ~= nil then clean[key] = checked end
    end
    db[field] = clean
  end
  local ratings = {}
  for id, values in pairs(type(db.specRatings) == "table" and db.specRatings or {}) do
    if Core.specInfo[id] and type(values) == "table" then
      local clean = {}
      for stat, value in pairs(values) do clean[stat] = Core.ValidateSetting("spec", stat, value) end
      if next(clean) then ratings[id] = clean end
    end
  end
  db.specRatings = ratings
  for key, def in pairs(Core.SettingDefs.option) do
    local value = Core.ValidateSetting("option", key, db[key])
    if value == nil then value = def.def end
    db[key] = value
  end
  if db.goWindow > db.spentWindow then db.goWindow = db.spentWindow end
  if not Core.ValidateRelations(db, db.points) then db.points.dieResMin, db.points.dieResMax = nil, nil end
  wipe(Core.profileCache)
end

-- Shapes of the plain saved settings (Core.DEFAULTS and a few UI keys).
-- A value of the wrong type, out of range or not in oneOf is reset on load
-- to Core.DEFAULTS[key] (nil when there is none). max and oneOf may be
-- functions: their tables come from modules that load later.
local UI = ns.UIConfig
Core.SavedDefs = {
  rows = { type = "number", min = 1, max = function() return Core.MAX_ROWS end, integer = true },
  scale = { type = "number", min = UI.scale.min, max = UI.scale.max },
  compact = { type = "boolean" },
  quickCalls = { type = "boolean" },
  quickCallsDestinations = { type = "boolean" },
  quickCallsRoutes = { type = "boolean" },
  bgAlpha = { type = "number", min = UI.opacity.min, max = UI.opacity.max },
  sound = { type = "boolean" },
  pressureCount = { type = "number", min = 1, integer = true,
    max = function() return ns.FocusConfig and ns.FocusConfig.limit end },
  sniperY = { type = "number", min = -200, max = 120 },
  sniperColor = { type = "string", oneOf = function() return Core.SNIPER_COLORS end },
  callChannel = { type = "string", oneOf = function() return Core.CALL_CHANNELS end },
  markIcon = { type = "number", min = 1, max = 8, integer = true },
  markMode = { type = "string", oneOf = { ping = true, icon = true } },
  pingType = { type = "string", oneOf = { attack = true, warning = true, assist = true, onmyway = true } },
  sniperScale = { type = "number", min = 0.5, max = 3 },
  sniperSound = { type = "number", min = 0, integer = true,
    max = function() return Core.SNIPER_SOUNDS and #Core.SNIPER_SOUNDS end },
  minimapAngle = { type = "number", min = -360, max = 360 },
  hubSection = { type = "string" },
  theme = { type = "string" },
}

local function Resolve(v)
  if type(v) == "function" then return v() end
  return v
end

-- True when value fits def (a Core.SavedDefs entry).
function Core.SavedValid(def, value)
  if type(value) ~= def.type then return false end
  if def.type == "number" then
    if value ~= value or value == math.huge or value == -math.huge then return false end
    local min, max = Resolve(def.min), Resolve(def.max)
    if (min and value < min) or (max and value > max) then return false end
    if def.integer and value ~= math.floor(value) then return false end
  end
  local oneOf = Resolve(def.oneOf)
  return type(oneOf) ~= "table" or oneOf[value] ~= nil
end

-- Reset damaged plain settings to their defaults. Returns the reset keys.
function Core.ValidateSaved(db)
  local reset = {}
  for key, def in pairs(Core.SavedDefs) do
    local value = db[key]
    if value ~= nil and not Core.SavedValid(def, value) then
      db[key] = Core.DEFAULTS[key]
      reset[#reset + 1] = key
    end
  end
  table.sort(reset)
  return reset
end
