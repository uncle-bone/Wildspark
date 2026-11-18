local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S = Theme.Space

---------------------------------------------------------------------------
-- A standalone addon's settings page, built from the same catalog as
-- Highground's (config/Options.lua): feature switches become toggles,
-- behavior settings toggles or number steppers, point values (thresholds
-- such as the resurrection alert's) number steppers. Registered under the
-- addon's title in Blizzard's settings; /<command> config opens it.
--   Settings.Page({ hint = text, keys = { "nearby", "nearbyRows", ... },
--     buttons = { { label, onClick }, ... } })
---------------------------------------------------------------------------
local Settings_ = {}
ns.StandaloneSettings = Settings_

local DEFS = {}
for _, def in ipairs(ns.OptionsConfig.features) do if def.key then DEFS[def.key] = def end end
for _, def in ipairs(ns.OptionsConfig.behavior) do DEFS[def.key] = DEFS[def.key] or def end
local POINTS = {}
for _, def in ipairs(ns.OptionsConfig.points) do
  if def.key and not DEFS[def.key] then DEFS[def.key], POINTS[def.key] = def, true end
end

-- A number setting: a point value (Core.P, Core.SetPoint) or an option.
local function Get(def)
  if POINTS[def.key] then return Core.P(def.key) end
  return Core.O(def.key)
end
local function Set(def, v)
  local ok, err
  if POINTS[def.key] then ok, err = Core.SetPoint(def.key, v) else ok, err = Core.SetOption(def.key, v) end
  if ok == false and err then ns.Util.Say(err) end -- rejected: the stepper snaps back
end

local function Toggle(parent, def)
  local t = Kit.Toggle(parent, def.label or def.desc, { desc = def.label and def.desc or nil, width = 520,
    onChange = function(_, on) Core.SetFeature(def.key, on) end })
  -- Behavior booleans read their value (default may be off); switches Core.On.
  function t.Refresh()
    local on
    if def.type == "boolean" then on = Core.O(def.key) else on = Core.On(def.key) end
    t:SetChecked(on and true or false, true)
  end
  t.label:SetWordWrap(true); t.desc:SetWordWrap(true)
  t.definition = def
  return t
end

local function Stepper(parent, def)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(520, Theme.Size("control"))
  row.stepper = Kit.Stepper(row, { min = def.min, max = def.max, step = def.step or (def.integer and 1 or nil),
    width = 120, onChange = function(_, v) Set(def, v) end })
  row.stepper:SetPoint("LEFT")
  row.label = Theme.Text(row, "control")
  row.label:SetPoint("LEFT", row.stepper, "RIGHT", S("md"), 0)
  row.label:SetPoint("RIGHT")
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(true)
  row.label:SetText(def.desc .. (def.unit and (" (" .. def.unit .. ")") or ""))
  function row.Refresh() row.stepper:SetValue(Get(def), true) end
  return row
end

-- Common actions and a small set of switches come first. Extra tuning and
-- appearance controls stay folded, while all controls keep their saved values.
function Settings_.Page(opts)
  local f = CreateFrame("Frame")
  f:Hide(); f.name = ns.LABEL
  Theme.Fill(f, "BACKGROUND", "bg"):SetAllPoints()
  local title = Theme.Text(f, "title", "titleText")
  title:SetPoint("TOPLEFT", S("xl"), -S("xl")); title:SetText(ns.LABEL)
  local hint = Theme.Text(f, "body", "textMuted")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S("md")); hint:SetPoint("RIGHT", -S("xl"), 0)
  hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); hint:SetText(opts.hint or "")
  f.hint, f.rows, f.buttons = hint, {}, {}
  local scroll = Kit.ScrollArea(f)
  scroll:SetPoint("BOTTOMRIGHT", -S("xl"), S("md"))
  f.scroll, f.body = scroll, scroll.body
  local body, basic = scroll.body, {}
  for _, key in ipairs(opts.basic or opts.keys) do basic[key] = true end
  local items = {}
  local function Item(region, extra, gap)
    items[#items + 1] = { region = region, extra = extra, gap = gap or 12 }
    return region
  end
  for _, b in ipairs(opts.buttons or {}) do
    if not b.advanced then
      local button = Item(Kit.Button(body, b[1], 240, 30, { onClick = b[2] }))
      f.buttons[#f.buttons + 1] = button
    end
  end
  for _, key in ipairs(opts.keys) do
    local def = DEFS[key]
    if def and ns.OptionAvailable(def) then
      local row = (def.type == "boolean" or not def.min) and Toggle(body, def) or Stepper(body, def)
      row.key, row.definition = key, def
      f.rows[#f.rows + 1] = row
    end
  end
  for _, row in ipairs(f.rows) do if basic[row.key] then Item(row) end end
  f.more = Item(Kit.Button(body, "More settings", 240, 30, { onClick = function()
    f.expanded = not f.expanded; f.Refresh()
  end }), false, 20)
  for _, row in ipairs(f.rows) do if not basic[row.key] then Item(row, true) end end
  Item(Kit.Section(body, "Appearance"), true, 20)
  local choices = {}
  local function ThemeChoices()
    wipe(choices)
    for _, name in ipairs(Theme.Names()) do choices[#choices + 1] = { key = name, label = Theme.Label(name) } end
    return choices
  end
  f.themeSelect = Item(Kit.Select(body, { choices = ThemeChoices(), menu = true, width = 240,
    onChange = function(_, key) Theme.Use(key) end }), true)
  local themeHint = Item(Theme.Text(body, "body", "textMuted"), true, 6)
  themeHint:SetJustifyH("LEFT"); themeHint:SetWordWrap(true)
  local function RefreshTheme()
    f.themeSelect:SetChoices(ThemeChoices()); f.themeSelect:SetValue(Theme.Current(), true)
    themeHint:SetText(Theme.Description())
  end
  Theme.OnChange(function() RefreshTheme(); if f.Layout then f.Layout() end end)
  f.motionToggle = Item(Kit.Toggle(body, "Reduced motion", {
    desc = "Keep indicators steady and make interface transitions instant.",
    onChange = function(_, on) Core.SetReducedMotion(on) end }), true)
  local fontRange = Core.THEME.appearance.fontScale
  f.fontSize = Kit.Stepper(body, { label = "Text size (%)", width = 180, min = fontRange.min * 100,
    max = fontRange.max * 100, step = fontRange.step * 100,
    onChange = function(_, value) Core.SetFontScale(value / 100) end })
  Item(f.fontSize.caption, true); Item(f.fontSize, true, 4)
  for _, b in ipairs(opts.buttons or {}) do
    if b.advanced then Item(Kit.Button(body, b[1], 240, 30, { onClick = b[2] }), true) end
  end
  function f.Layout()
    if f.layingOut then return end
    f.layingOut = true
    scroll:SetPoint("TOPLEFT", 0, -math.max(84, 54 + hint:GetStringHeight()))
    local width = math.max(280, body:GetWidth() - 32)
    local top = 0
    for _, item in ipairs(items) do
      local region, visible = item.region, not item.extra or f.expanded == true
      region:SetShown(visible)
      if visible then
        top = top + item.gap
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", S("xl"), -top)
        if region.label and region.desc then
          region:SetWidth(width)
          region:SetHeight(math.max(30, region.label:GetStringHeight() +
            (region.desc:IsShown() and region.desc:GetStringHeight() + 4 or 0) + 8))
        elseif region.stepper then
          region:SetWidth(width); region:SetHeight(math.max(30, region.label:GetStringHeight() + 8))
        elseif region:GetObjectType() == "FontString" then
          region:SetWidth(width); region:SetHeight(math.max(18, region:GetStringHeight()))
        elseif region ~= f.fontSize then region:SetWidth(math.min(width, 260 * Core.FontScale())) end
        top = top + region:GetHeight()
      end
    end
    body:SetHeight(top + 16); scroll:Refresh()
    f.layingOut = nil
  end
  function f.Refresh()
    RefreshTheme()
    f.motionToggle:SetChecked(Core.ReducedMotion(), true); f.fontSize:SetValue(Core.FontScale() * 100, true)
    for _, row in ipairs(f.rows) do
      row.Refresh()
      if not row.stepper then
        local parent, enabled = row.definition.parent, true
        while parent do
          if not Core.On(parent) then enabled = false end
          parent = DEFS[parent] and DEFS[parent].parent
        end
        row:SetEnabled(enabled)
      end
    end
    f.more:SetText(f.expanded and "Fewer settings" or "More settings")
    f.Layout()
  end
  f:SetScript("OnShow", f.Refresh); f:HookScript("OnSizeChanged", f.Layout)
  Core.OnFontScaleChange(f.Layout)
  Settings_.frame = f
  if Settings and Settings.RegisterCanvasLayoutCategory then
    Settings_.category = Settings.RegisterCanvasLayoutCategory(f, ns.LABEL)
    Settings.RegisterAddOnCategory(Settings_.category)
  elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(f) end
  return f
end

function Settings_.Open()
  if Settings_.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(Settings_.category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory and Settings_.frame then
    InterfaceOptionsFrame_OpenToCategory(Settings_.frame)
    InterfaceOptionsFrame_OpenToCategory(Settings_.frame)
  end
end

function Settings_.Refresh()
  if Settings_.frame and Settings_.frame:IsShown() then Settings_.frame.Refresh() end
end
