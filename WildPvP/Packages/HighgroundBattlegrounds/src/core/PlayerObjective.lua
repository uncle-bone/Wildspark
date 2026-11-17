local _, ns = ...
local U = ns.Util
-- Own objective auras plus objective unit tokens cover flags and orbs even
-- when the pickup announcement was missed (joining late or reloading).
local AURAS = { [23333] = true, [23335] = true, [34976] = true, [121164] = true,
  [121175] = true, [121176] = true, [121177] = true, [156621] = true, [156618] = true,
  [301091] = true, [301089] = true }
function ns.PlayerHasObjective()
  local bg = ns.GetBG and ns.GetBG()
  if not bg or not bg.rules.objective then return false end
  for i = 1, 4 do if U.read(UnitIsUnit, "player", "arena" .. i) then return true end end
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 40 do
      local a = U.call(get, "player", i, filter)
      if not a then break end
      if AURAS[U.value(a.spellId) or 0] then return true end
    end
  end
  -- Bridge the short delay between a pickup announcement and its aura or
  -- objective token becoming visible. Never retain a stale pickup forever.
  if ns.Core.playerObjective and not U.read(UnitIsDeadOrGhost, "player") then
    return GetTime() - ns.Core.playerObjective < 3
  end
  return false
end
