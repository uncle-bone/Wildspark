local _, ns = ...
local Intel, Comms = ns.Intel, ns.Comms

---------------------------------------------------------------------------
-- Intel sharing (prefix HighgroundI, group channel). Message v3:
--   3:mapID:@,myArea;key,x,y,r,age,how,area;key,D;...
-- x/y in 1/10000 of the map, 0 = unknown; age in seconds so clocks don't
-- need to agree; how keeps the position's provenance, unknown included.
-- Legacy v2 could send a release graveyard as the observer's position:
-- its area and death reports are accepted, its bare coordinates never.
---------------------------------------------------------------------------
local Clean = ns.Util.Clean

function Intel.Send()
  local chan = Comms.GroupChannel()
  local mapID = Intel.MapID()
  if not (chan and mapID and Intel.On("intelShare")) then
    wipe(Intel.mine)
    return
  end
  local now = GetTime()
  local head = "3:" .. mapID .. ":"
  local parts, len = {}, #head
  local function flush()
    if #parts > 0 then
      Comms.Send(Intel.PREFIX, head .. table.concat(parts, ";"), chan)
      Intel.stats.sent = Intel.stats.sent + 1
    end
    parts, len = {}, #head
  end
  local function add(tok)
    if len + #tok + 1 > 250 then
      flush()
    end
    parts[#parts + 1] = tok
    len = len + #tok + 1
  end
  local area = Intel.MyArea()
  if area then
    add("@," .. Clean(area))
  end
  for key in pairs(Intel.mine) do
    local it = Intel.intel[key]
    if it and it.dead then
      add(key .. ",D")
    elseif it and it.by == Intel.myName then
      add(string.format("%s,%d,%d,%d,%d,%s,%s", key, (it.x or 0) * 10000, (it.y or 0) * 10000, it.r,
        math.max(0, now - it.t), it.how or (it.x and "nearby" or "unknown"), Clean(it.area)))
    end
  end
  flush()
  wipe(Intel.mine)
end

function Intel.Receive(text, sender)
  local short = sender and sender:match("^[^-]+")
  if short == Intel.myName then
    return
  end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if (ver ~= "2" and ver ~= "3") or tonumber(map) ~= Intel.MapID() then
    return
  end
  local now = GetTime()
  Intel.stats.recv = Intel.stats.recv + 1
  for tok in body:gmatch("[^;]+") do
    local key, rest = tok:match("^([^,]+),(.+)$")
    if key == "@" then
      Intel.allyArea[short] = { area = rest, t = now }
    elseif key and ns.enemies and ns.enemies[key] then
      if rest == "D" then
        Intel.Died(key, now)
      else
        local x, y, r, age, detail = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
        if x then
          x, y = tonumber(x) / 10000, tonumber(y) / 10000
          local how, area
          if ver == "3" then how, area = detail:match("^([^,]+),(.*)$") else area = detail end
          area = area ~= "" and area or nil
          if ver == "2" then
            x, y = Intel.AreaXY(tonumber(map), area)
            how = x and "area" or "unknown"
          elseif how == "unknown" or not Intel.ValidXY(x, y) then
            x, y, how = nil, nil, "unknown"
          elseif how ~= "coords" and how ~= "nearby" and how ~= "area" and how ~= "recent" then
            x, y, how = nil, nil, "unknown"
          end
          Intel.Record(key, x, y, tonumber(r), short, now - tonumber(age), area, how)
        end
      end
    end
  end
end

-- Short text for tooltips / the hero card, or nil when unknown.
function Intel.Where(key)
  local it = Intel.intel[key]
  if not it or it.dead or not Intel.Enabled() then
    return nil
  end
  local age = GetTime() - it.t
  if age > Intel.KEEP then
    return nil
  end
  local where
  if not it.x then
    where = (it.area and ("in " .. it.area .. "; ") or "") .. "position unknown"
  else
    where = ((it.how == "nearby" or it.how == "recent") and "near " or "at ")
      .. (it.how == "recent" and it.near or it.area or Intel.Place(it.x, it.y))
    if it.how == "area" or it.how == "objective" or it.how == "recent" then where = where .. " (approx.)" end
  end
  if it.how == "objective" then
    return string.format("last seen %s, %ds ago (node announcement)", where, age)
  end
  if age < Intel.FRESH then
    return where .. (it.by ~= Intel.myName and (" (" .. it.by .. ")") or "")
  end
  return string.format("last seen %s, %ds ago", where, age)
end
ns.MapWhere = Intel.Where
