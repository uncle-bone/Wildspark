local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Flags: exact positions (carried / dropped flags)
---------------------------------------------------------------------------
function Intel.FlagTeam(tex)
  if type(tex) == "string" then
    if tex:find("Alliance") then
      return "A"
    elseif tex:find("Horde") then
      return "H"
    end
  end
end

function Intel.Flags()
  local out = {}
  if not (GetNumBattlefieldFlagPositions and GetBattlefieldFlagPosition) then
    return out
  end
  local okN, n = pcall(GetNumBattlefieldFlagPositions)
  for i = 1, okN and n or 0 do
    local ok, x, y, tex = pcall(GetBattlefieldFlagPosition, i)
    if ok and Intel.ValidXY(x, y) then
      out[#out + 1] = { x = x, y = y, team = Intel.FlagTeam(tex) }
    end
  end
  return out
end

-- Am I carrying a flag? (Warsong / Silverwing / Netherstorm flag auras)
local FLAG_AURAS = { [23333] = true, [23335] = true, [34976] = true }
function Intel.ICarryFlag()
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not get then
    return false
  end
  for i = 1, 40 do
    local ok, a = pcall(get, "player", i, "HELPFUL")
    if not (ok and a) then
      return false
    end
    if Intel.plain(a.spellId) and FLAG_AURAS[a.spellId] then
      return true
    end
  end
  return false
end

-- A real position for the area I'm in: learn it (only named sub-zones;
-- the zone-wide name covers too much ground to average).
function Intel.LearnMyArea(mapID, x, y)
  local area = Intel.MyArea()
  if area and not Intel.IsZoneName(mapID, area) then
    Intel.LearnAnchor(mapID, area, x, y)
  end
end

-- The enemy carrying OUR flag sits exactly on it. While I carry a flag,
-- its position is mine: learn my area's spot.
function Intel.ScanFlags(mapID, now)
  if Intel.ICarryFlag() then
    local flags, pick = Intel.Flags(), nil
    for _, f in ipairs(flags) do
      if f.team ~= Intel.MyTeam() then
        pick = pick and "many" or f
      end
    end
    if pick and pick ~= "many" then
      Intel.LearnMyArea(mapID, pick.x, pick.y)
    end
  end
  local carrier
  for key, e in pairs(ns.enemies) do
    if e.carrier and not e.dead then
      carrier = carrier and "many" or key
    end
  end
  if not carrier or carrier == "many" then
    return
  end
  local flags = Intel.Flags()
  local mine
  for _, f in ipairs(flags) do
    if f.team == Intel.MyTeam() then
      mine = f
    end
  end
  if not mine and #flags == 1 and flags[1].team == nil then
    mine = flags[1]
  end
  if mine and Intel.Record(carrier, mine.x, mine.y, 3, "flag", now) then
    Intel.stats.flag = Intel.stats.flag + 1
  end
end
