local _, ns = ...
local Intel = ns.Intel

---------------------------------------------------------------------------
-- Map layer: one pin per known enemy, faded by time since last seen, with
-- a hover that says who, where and how sure. An enemy with no position,
-- not even a rough one, gets no pin.
---------------------------------------------------------------------------
Intel.testPins = false
-- Tooltip line in a colour token or a class colour.
local Line = ns.Theme.TipLine

local AddLayer = ns.MapPins and ns.MapPins.Add or function() end -- Pins.xml failed to load: intel still runs
AddLayer(function(mapID, width, height)
  width, height = width and width > 0 and width or 1000, height and height > 0 and height or 667
  local items = {}
  if Intel.testPins then
    items[1] = { x = 0.5, y = 0.5, ring = "mapMark", icon = "classicon-rogue", label = "TEST", size = 26,
      tooltip = function(tt)
        tt:AddLine("Highground test pin: map pins work")
      end }
  end
  -- Inactive: the driver resets intel within a second; hide it at once.
  if not (Intel.Enabled() and ns.IsActive() and ns.enemies and mapID == Intel.MapID()) then
    return items
  end
  local now = GetTime()
  local killNow = ns.GetKillNow and ns.GetKillNow()
  for key, it in pairs(Intel.intel) do
    local e = ns.enemies[key]
    local age = now - it.t
    if e and it.x and not it.dead and age < Intel.KEEP then
      local fresh = age < Intel.FRESH
      local objective = it.how == "objective"
      local approximate = it.how ~= "coords" and it.by ~= "flag"
      local c = ns.Util.ClassColor(e.class)
      -- Greys, fades and shrinks with time since last seen, fastest at first:
      -- half way (fade 0.5) after a quarter of KEEP.
      local fade = fresh and 0 or math.sqrt(math.min(1, (age - Intel.FRESH) / (Intel.KEEP - Intel.FRESH)))
      local dim = 0.35 + 0.3 * (1 - fade)
      local function Ring(v) return (v * (1 - fade) + 0.5 * fade) * dim end -- class colour -> grey
      items[#items + 1] = {
        sortKey = key,
        x = it.x, y = it.y,
        size = fresh and 24 or math.floor(22 - 6 * fade),
        ring = c and (fresh and { c.r, c.g, c.b } or { Ring(c.r), Ring(c.g), Ring(c.b) }) or "textDim",
        icon = "classicon-" .. e.class:lower(),
        desat = fresh and 0 or 0.5 + 0.5 * fade,
        alpha = fresh and 1 or (0.85 - 0.65 * fade),
        label = (approximate and "~" or "") .. (fresh and not objective and "" or string.format("%ds", age)),
        labelColor = "mapLabel",
        mark = killNow and killNow.key == key,
        tooltip = function(tt)
          Line(tt, e.display, c or "white")
          local si = e.specID and ns.specInfo and ns.specInfo[e.specID]
          Line(tt, (si and (si.name .. " ") or "") .. ns.Util.ClassName(e.class), "textMuted")
          if it.area then
            Line(tt, "Area: " .. it.area, "info")
          end
          Line(tt, fresh and not objective and ("Seen now by " .. it.by) or string.format("Last seen %ds ago by %s", age, it.by),
            "textMuted")
          if it.by == "flag" then
            Line(tt, "Carrying your flag: exact position", "gold")
          elseif approximate then
            Line(tt, objective and "At the node when announced; current position unknown"
              or it.how == "area" and "Approximate area anchor, not an exact position"
              or it.how == "recent" and string.format("Approximate: observer left %s moments before", it.near or "a known area")
              or "Approximate: near the observer", "textDim")
          end
        end,
      }
    end
  end
  -- Spread enemies sharing an anchor in stable, screen-sized slots. A
  -- fixed normalized circle overlaps badly on the small battlefield map.
  local stacks = {}
  for _, item in ipairs(items) do
    local k = string.format("%.3f,%.3f", item.x, item.y)
    stacks[k] = stacks[k] or {}
    table.insert(stacks[k], item)
  end
  for _, group in pairs(stacks) do
    if #group > 1 then
      table.sort(group, function(a, b) return (a.sortKey or "") < (b.sortKey or "") end)
      local cols = math.ceil(math.sqrt(#group))
      local rows = math.ceil(#group / cols)
      local dx, dy = 40 / width, 42 / height
      local spanX, spanY = (cols - 1) * dx, (rows - 1) * dy
      local left = math.max(dx / 2, math.min(1 - dx / 2 - spanX, group[1].x - spanX / 2))
      local top = math.max(dy / 2, math.min(1 - dy / 2 - spanY, group[1].y - spanY / 2))
      for i, item in ipairs(group) do
        item.x, item.y = left + ((i - 1) % cols) * dx, top + math.floor((i - 1) / cols) * dy
      end
    end
  end
  return items
end)
