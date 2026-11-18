local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Graveyards as they stand: one per spot (a saved one and a live one, or a
-- base that changed hands, collapse into the best one: current owner, then
-- a known wave). Located ones first; withUnlocated adds graveyards with a
-- wave but no spot. -> list of { g, nw, est }
function Timers.LiveGYs(mapID, now, withUnlocated)
  Timers.UpdateNodePhases(now)
  local list = {}
  for _, g in ipairs(Timers.gys) do
    if not g.configured and not g.x and g.label and ns.AreaXY then
      g.x, g.y = ns.AreaXY(mapID, g.label) -- anchor learned since
    end
    if g.x and Timers.Available(g) then
      local nw, est = Timers.NextWave(g, now)
      -- the team that owns the base on this spot now wins over a stale one
      local owner
      for _, nd in pairs(Timers.nodes) do
        if nd.x and nd.owner and (nd.name == g.node or (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2) then
          owner = nd.owner
        end
      end
      list[#list + 1] = { g = g, nw = nw, est = est,
        rank = (owner == g.team and 16 or 0) + (nw and not est and 8 or nw and 4 or 0) + (g.node and 2 or 0)
          + (g.exact and 1 or 0) }
    end
  end
  table.sort(list, function(a, b)
    return a.rank > b.rank
  end)
  local placed = {}
  for _, it in ipairs(list) do
    local g, dup = it.g, false
    for _, p in ipairs(placed) do
      if not (g.configured or p.g.configured)
        and (p.g.x - g.x) ^ 2 + (p.g.y - g.y) ^ 2 < 0.035 ^ 2 then
        dup = true
        break
      end
    end
    g.stale = dup or nil -- lost to another graveyard on the same spot
    if not dup then
      placed[#placed + 1] = it
    end
  end
  if withUnlocated then
    for _, g in ipairs(Timers.gys) do
      if not g.x and Timers.Available(g) then
        local nw, est = Timers.NextWave(g, now)
        if nw or g.configured then
          placed[#placed + 1] = { g = g, nw = nw, est = est }
        end
      end
    end
  end
  return placed
end

-- Res timers window rows; the bar fills up as the wave approaches:
--   YOU    [=======     ] 12s Stables     your team's next res wave
--   ENEMY  [===         ] 24s Farm        enemy team's soonest wave
-- "~" = estimated. YOU turns red with DIE when it's a good time to die.
---------------------------------------------------------------------------
function Timers.Rows(now)
  local list = Timers.LiveGYs(Timers.MapID(), now, true) -- also marks stale graveyards
  local mine = Timers.PickWaves(now)
  -- YOU identifies a known destination even before its clock is observed.
  -- Other friendly graveyards remain OURS; unknown clocks remain unknown.
  local myG = Timers.ConfiguredGYs() and Timers.MyGraveyard(now) or (mine and mine[1])
  local die = Timers.DieAlert(now)
  local me = Timers.MyTeam()
  if myG then
    local found = false
    for _, it in ipairs(list) do
      found = found or it.g == myG
    end
    if not found then
      local nw, est = Timers.NextWave(myG, now)
      list[#list + 1] = { g = myG, nw = nw, est = est }
    end
  end
  -- yours first, then your team's by next wave, then the enemy's; unknown last
  local function key(it)
    return (it.g == myG and 0 or it.g.team == me and 1 or 2) * 1000 + (it.nw and (it.nw - now) or 999)
  end
  table.sort(list, function(a, b)
    return key(a) < key(b)
  end)
  local out = {}
  for _, it in ipairs(list) do
    if #out >= 8 then
      break
    end
    local g = it.g
    local ours = g.team == me
    local row = { tag = g == myG and "YOU" or ours and "OURS" or "THEIRS", color = Timers.TeamColor(g.team),
      left = it.nw and it.nw - now, total = Timers.WavePeriod(), est = it.est or g.conf == "cap" }
    local name = Timers.GYName(g)
    row.text = name ~= "" and name or "spot unknown"
    if g == myG and die then
      row.tag, row.color, row.die, row.text = "SOON", ns.Theme.Rgb("warning"), true, row.text
    end
    out[#out + 1] = row
  end
  if #out == 0 then
    out[1] = { tag = "RES", color = Timers.TeamColor(me), text = "Waiting for a graveyard timer" }
  end
  return out
end
