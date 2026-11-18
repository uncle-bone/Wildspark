local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Player names, shared with the standalone addons. A key is "Name-Realm"
-- with the realm's spaces removed; Core.myRealm (set on login) is the
-- player's own realm, shown without it.
---------------------------------------------------------------------------
Core.issecret = issecretvalue or function() return false end
Core.plain = ns.Util.plain

function Core.Canon(name)
  if type(name) ~= "string" or Core.issecret(name) or name == "" then
    return nil
  end
  local short, realm = name:match("^([^-]+)-(.+)$")
  if short then
    return short .. "-" .. realm:gsub("%s", "")
  end
  return name .. "-" .. (Core.myRealm or "")
end

function Core.DisplayName(key)
  local short, realm = key:match("^([^-]+)-(.+)$")
  if realm == Core.myRealm then
    return short
  end
  return key
end

-- Let the client assemble its name. Forever's second UnitName result is
-- a surname, not a realm: joining it with "-" breaks /targetexact and
-- matching a visible unit to the scoreboard's "First Last" name.
function Core.FullUnitName(unit)
  local ok, name, realm = pcall(UnitName, unit)
  if not ok or not Core.plain(name) or Core.issecret(realm) then return nil end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
  if type(GetUnitName) == "function" then
    name = ns.Util.read(GetUnitName, unit, true)
  elseif type(realm) == "string" and realm ~= "" then
    name = name .. "-" .. realm
  end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  return name
end

function Core.CanonUnit(unit)
  return Core.Canon(Core.FullUnitName(unit))
end
