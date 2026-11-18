local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- Quiet, static metal inlays. A sampled logarithmic scroll is drawn with
-- short rotated textures, so it scales with the UI and needs no bitmap.
-- Only the margin is decorated; the frame never intercepts input.
function Kit.Inlay(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:EnableMouse(false)
  -- An inner rim and a low, symmetric flourish suggest worked metal.
  -- Confined to the empty margin: no texture or movement behind prose.
  local rim = CreateFrame("Frame", nil, f)
  rim:SetAllPoints(); rim:EnableMouse(false)
  Kit.Bevel(rim, 1)
  local edges = Kit.Outline(rim, "border", 3)
  for _, edge in ipairs(edges) do edge:SetAlpha(0.55) end
  for _, sx in ipairs({ -1, 1 }) do
    local px, py = 14, 6
    for i = 1, 24 do
      local x = 14 + i * 2
      local y = 6 + 2 * math.sin(i * math.pi / 24) * math.sin(i * math.pi / 12)
      local dx, dy = sx * (x - px), y - py
      local t = Theme.Fill(rim, "ARTWORK", "borderAccent")
      t:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, 1)
      t:SetPoint("CENTER", rim, "BOTTOM", sx * (x + px) / 2, (y + py) / 2)
      t:SetRotation(math.atan2(dy, dx))
      px, py = x, y
    end
  end
  for i = -1, 1 do
    local gem = Theme.Fill(rim, "ARTWORK", "borderAccent")
    gem:SetSize(i == 0 and 4 or 2, i == 0 and 4 or 2)
    gem:SetPoint("CENTER", rim, "BOTTOM", i * 8, 6)
    gem:SetRotation(math.pi / 4)
  end
  for _, corner in ipairs({ { "TOPLEFT", 1, 1 }, { "TOPRIGHT", -1, 1 },
    { "BOTTOMLEFT", 1, -1 }, { "BOTTOMRIGHT", -1, -1 } }) do
    local anchor, sx, sy = corner[1], corner[2], corner[3]
    local function stroke(x1, y1, x2, y2)
      x1, y1, x2, y2 = x1 * 0.65, y1 * 0.65, x2 * 0.65, y2 * 0.65
      local dx, dy = sx * (x2 - x1), -sy * (y2 - y1)
      local t = Theme.Fill(f, "ARTWORK", "borderAccent")
      t:SetSize(math.sqrt(dx * dx + dy * dy) + 0.5, 1)
      t:SetPoint("CENTER", f, anchor, sx * (x1 + x2) / 2, -sy * (y1 + y2) / 2)
      t:SetRotation(math.atan2(dy, dx))
    end
    stroke(7, 32, 7, 18)
    stroke(18, 7, 40, 7)
    local px, py = 7, 18
    for i = 1, 18 do
      local angle = math.pi + i * math.pi * 2 / 18
      local radius = 11 * math.exp(-i / 9)
      local x, y = 18 + radius * math.cos(angle), 18 + radius * math.sin(angle)
      stroke(px, py, x, y)
      px, py = x, y
    end
  end
  local function refresh()
    rim:SetShown(Theme.Current() == "azeroth")
    f:SetAlpha(Theme.Current() == "azeroth" and 1 or 0.45)
  end
  Theme.OnChange(refresh)
  refresh()
  return f
end
