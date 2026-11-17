local _, ns = ...

-- Settings catalog. Client visibility and page identity live here so the
-- same value has one canonical control across both clients. This file holds
-- what every addon shares; each feature adds its settings in
-- config/catalog/<Feature>.lua (ns.OptionsAdd), loaded only by the addons
-- that ship it, so changing them never makes the other addons release.
ns.OptionsConfig = {
  -- Applied only when no saved settings exist. Nil on an older installation
  -- still means the historical default; upgrading must not change its setup.
  firstRun = { alerts = { mode = "essential", channels = {} } },
  pointAliases = {},
  pages = {
    general = { name = "General", order = -1, stepper = false, hint = "Choose the panels and alerts you want. Changes save automatically." },
    tools = { name = "Help and previews", order = -0.75, stepper = false, hint = "Try panels with example data outside a match. Click the same preview again to stop it." },
    appearance = { name = "Appearance", order = -0.5, stepper = false, hint = "Theme, panel scales, sizes and spacing, enemy row elements, font, bars and borders. Applies instantly; sizes change out of combat. Shift-click -/+ for bigger steps." },
  },
  behavior = {},
  -- Groups sort by their order on the General page.
  features = {
    { group = "Layout and sound", order = 1 },
    { key = "minimap", label = "Minimap button", desc = "Button at the minimap: left-click settings, right-click macros, bounty board and previews" },
    { key = "compact", label = "Compact layout", desc = "Slim one-line rows; battleground panels dock under the main panel and move together" },
    { key = "sound", label = "Sounds", desc = "Every Highground sound: GO, lock-on, capture, resurrection, sap call, nearby enemy and bounty alerts" },
  },
  weights = {},
  points = {},
}

-- A feature's settings: pages and point aliases by key; behavior, weights
-- and points appended; each feature group ({ group, order } header, then its
-- switches) goes before the first group with a higher order.
function ns.OptionsAdd(part)
  local C = ns.OptionsConfig
  for k, v in pairs(part.firstRun or {}) do C.firstRun[k] = v end
  for k, v in pairs(part.pages or {}) do C.pages[k] = v end
  for k, v in pairs(part.pointAliases or {}) do C.pointAliases[k] = v end
  for _, list in ipairs({ "behavior", "weights", "points" }) do
    for _, row in ipairs(part[list] or {}) do C[list][#C[list] + 1] = row end
  end
  for _, block in ipairs(part.features or {}) do
    local at = #C.features + 1
    for i, row in ipairs(C.features) do
      if row.group and row.order > block[1].order then
        at = i
        break
      end
    end
    for j, row in ipairs(block) do table.insert(C.features, at + j - 1, row) end
  end
end

function ns.ApplyFirstRunDefaults(db)
  local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = Copy(child) end
    return out
  end
  for key, value in pairs(ns.OptionsConfig.firstRun) do db[key] = Copy(value) end
end

-- Whether a settings entry applies to this game (caps, cata, retail, retired).
function ns.OptionAvailable(option)
  if option.retired then return false end
  if option.caps and not (ns.Caps and ns.Caps[option.caps]) then return false end
  local retail = ns.CLIENT == "retail"
  return not (option.cata and retail) and not (option.retail and not retail)
end
