local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
ns.Hud = {}
local Hud = ns.Hud

---------------------------------------------------------------------------
-- Pieces shared by the HUD windows (arena enemies, flag carriers, nearby
-- enemies, timers): row surfaces, class-coloured names, the secure unit row
-- and the "target/focus by name" macro binding. The windows themselves
-- come from Timers.MakeWindow (timers/Windows.lua).
---------------------------------------------------------------------------
local CLICK_HINT = "Left-click: target   Right-click: focus"

-- Display health even when the game keeps its numbers secret. Only the
-- status bar receives those values; callers get a readable fraction or nil.
function Hud.Health(bar, unit, dead, preview)
  local U = ns.Util
  local fraction = preview or (unit and U.HealthFraction(unit))
  if dead or fraction then
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(dead and 0 or fraction)
    return fraction, true
  end
  if unit then
    local pct = U.call(UnitHealthPercent, unit, true)
    if type(pct) ~= "nil" then
      bar:SetMinMaxValues(0, 1)
      if pcall(bar.SetValue, bar, pct) then return nil, true end
    end
    local hp, maximum = U.call(UnitHealth, unit), U.call(UnitHealthMax, unit)
    if type(hp) ~= "nil" and type(maximum) ~= "nil" then
      local ok = pcall(function() bar:SetMinMaxValues(0, maximum); bar:SetValue(hp) end)
      if ok then return nil, true end
    end
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  return nil, false
end

-- Row background: the surface colour, following Background opacity.
function Hud.Surface(parent, layer)
  return Theme.Paint(Core.Surface(parent, layer), "surface")
end

-- An optional full-row class surface. Separate from health so it also
-- works with empty/hidden health bars and the board's thin-line layout.
-- Register with opacity, and repaint idle rows without touching bindings.
local enemySurfaces = setmetatable({}, { __mode = "k" })
function Hud.PaintEnemy(surface, color)
  surface.wbEnemyColor = color
  if color and Theme.Alpha("classRow") > 0 then
    Theme.Unpaint(surface)
    local c = Theme.EnemyRowColor(color)
    surface:SetColorTexture(c[1], c[2], c[3], 1)
  else
    Theme.Paint(surface, "surface", 0)
  end
end

function Hud.EnemySurface(parent)
  local surface = Core.Surface(parent, "BACKGROUND", 1)
  surface:SetAllPoints()
  enemySurfaces[surface] = true
  Hud.PaintEnemy(surface)
  return surface
end

Theme.OnChange(function()
  for surface in pairs(enemySurfaces) do Hud.PaintEnemy(surface, surface.wbEnemyColor) end
end)

-- Text in a class colour (game data, not themed), else the text token.
function Hud.PaintClass(fs, cc)
  if cc then
    Core.ClassPaint(fs, cc)
  else
    Theme.Paint(fs, "text")
  end
end

-- Secure row of a HUD window: a click target with a surface, an icon and a
-- name. opts:
--   height    row height (else set by the window's layout)
--   unit      unit token: left-click targets it, right-click focuses it;
--             without one both buttons run macros (Core.SetTargetFocus)
--   bar       true: a status bar fills the row and holds the regions
--             (r.bar); the row's own regions otherwise
--   enemy     true: adds r.classBg, painted with Hud.PaintEnemy
--   restore   true: macros return to the previous target (Core.WrapRestore)
--   nameRole  type role of r.name ("rowNameLarge")
--   tip(self) tooltip title, plus optional extra lines ({ text, token,
--             wrap }, unwrapped by default);
--             the click hint follows
-- Returns the button with .unit, .bar (opts.bar), .icon and .name.
function Hud.UnitRow(parent, name, opts)
  local r = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  if opts.height then r:SetHeight(opts.height) end
  -- Same down/up registration as the kill-order rows (ActionButtonUseKeyDown).
  r:RegisterForClicks("AnyDown", "AnyUp")
  if opts.unit then
    r.unit = opts.unit
    r:SetAttribute("unit", opts.unit)
    r:SetAttribute("type1", "target")
    r:SetAttribute("type2", "focus")
  else
    r:SetAttribute("type1", "macro")
    r:SetAttribute("type2", "macro")
  end
  if opts.restore then Core.WrapRestore(r) end
  local host = r
  if opts.bar then
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetAllPoints()
    Core.StatusBar(r.bar)
    r.bar:SetMinMaxValues(0, 1)
    r.bar:EnableMouse(false)
    host = r.bar
  end
  Hud.Surface(host, "BACKGROUND"):SetAllPoints()
  if opts.enemy then r.classBg = Hud.EnemySurface(host) end
  r.icon = host:CreateTexture(nil, "OVERLAY")
  r.name = Theme.Text(host, opts.nameRole or "rowNameLarge")
  r.name:SetJustifyH("LEFT")
  if opts.tip then
    Kit.Tooltip(r, function(self)
      local title, extra = opts.tip(self)
      local lines = { { title, "gold", false } }
      for _, line in ipairs(extra or {}) do lines[#lines + 1] = { line[1], line[2], line[3] or false } end
      lines[#lines + 1] = { CLICK_HINT, "textMuted", false }
      lines[#lines + 1] = { "Focus keeps a second target for abilities and tracking.", "textMuted", true }
      return lines
    end, { anchor = "ANCHOR_RIGHT" })
  end
  return r
end

---------------------------------------------------------------------------
-- Target and focus by name. Secure attributes: call out of combat only.
---------------------------------------------------------------------------
function Core.TargetMacro(name)
  return name and ("/targetexact " .. name) or nil
end

-- /focus takes a unit, not a name: target by exact name, then focus that.
function Core.FocusMacro(name)
  return name and ("/targetexact " .. name .. "\n/focus") or nil
end

-- Left-click targets name, right-click focuses it and returns to the
-- previous target (Core.SetReturnMacro). name nil clears both; the left
-- macro is then set to empty ("" for the board rows, nil for the nearby
-- rows: each keeps the value it always had).
function Core.SetTargetFocus(btn, name, empty)
  btn:SetAttribute("macrotext1", Core.TargetMacro(name) or empty)
  Core.SetReturnMacro(btn, "macrotext2", Core.FocusMacro(name))
end
