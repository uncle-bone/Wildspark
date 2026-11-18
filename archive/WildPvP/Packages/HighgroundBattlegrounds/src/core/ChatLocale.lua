local _, ns = ...
ns.ChatLocaleData = {}
local U = ns.Util
local patterns = {}
-- AreaTable identifiers let the client resolve nominative map names even
-- when an announcement uses a declined noun or a different plural form.
-- Source: jenascore/DBC-Maps-Vmaps-430, dbc/AreaTable.dbc (name field 11).
local AREAS = {
  ["irondeep mine"] = { 2957 }, ["coldtooth mine"] = { 2963 }, ["snowfall graveyard"] = { 3301 },
  farm = { 3420 }, blacksmith = { 3421 }, ["lumber mill"] = { 3422 }, mine = { 3423, 5452 }, stables = { 3424 },
  ["mage tower"] = { 3869 }, ["blood elf tower"] = { 3870 }, ["draenei ruins"] = { 3871 }, ["fel reaver ruins"] = { 3872 },
  workshop = { 4747 }, quarry = { 4748 }, docks = { 4749 }, hangar = { 4750 }, ["oil refinery"] = { 4751 },
  ["horde keep"] = { 4752 }, ["alliance keep"] = { 4753 }, lighthouse = { 5450 }, waterworks = { 5451 }, mines = { 5452 },
}

local function Clean(text)
  return text:gsub("|H[^|]+|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    :gsub("|3%-%d%((.-)%)", "%1"):gsub(" ", " "):gsub("%s+", " "):gsub("%s+([!！])", "%1")
end
local function Pattern(format)
  -- Korean grammatical suffixes can arrive unresolved or rendered as one
  -- of their alternatives. They never change the captured player's name.
  format = Clean(format)
  return "^" .. format:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    :gsub("%%%$n", "(.-)") .. "$"
end
local function Area(message, canonical)
  local nodes = ns.Timers and ns.Timers.nodes or {}
  for _, id in ipairs(AREAS[canonical] or {}) do
    local name = U.read(C_Map and C_Map.GetAreaInfo or GetAreaInfo, id)
    if type(name) == "string" and nodes[name] then return name end
  end
  local best
  local lower = message:lower()
  for name in pairs(nodes) do
    if lower:find(name:lower(), 1, true) and (not best or #name > #best) then best = name end
  end
  return best
end

function ns.LocalizedChat(message)
  if type(message) ~= "string" or U.secret(message) then return message end
  message = Clean(message)
  local locale = GetLocale and GetLocale() or "enUS"
  if not patterns[locale] then
    patterns[locale] = {}
    for _, row in ipairs(ns.ChatLocaleData[locale] or {}) do
      local function add(format)
        patterns[locale][#patterns[locale] + 1] = { Pattern(format), row[2], row[1]:find("$n", 1, true) ~= nil, row[3] }
      end
      add(row[1])
      if row[1]:find("|1", 1, true) then
        add((row[1]:gsub("|1([^;]+);[^;]+;", "%1")))
        add((row[1]:gsub("|1[^;]+;([^;]+);", "%1")))
      end
    end
  end
  for _, row in ipairs(patterns[locale]) do
    local name = message:match(row[1])
    if name then
      local area = row[2]:find("$AREA", 1, true) and Area(message, row[4])
      if not row[2]:find("$AREA", 1, true) or area then
        return (row[2]:gsub("%$n", function() return row[3] and name or "" end):gsub("%$AREA", function() return area or "" end))
      end
    end
  end
  return message
end
