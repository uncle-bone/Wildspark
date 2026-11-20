-- WildMaps target/focus tracking integration.
-- Adapted and modified from Forever Minimap Target v1.0.1 by Ashtar Senior.
-- Modified for WildSpark's per-character settings and WildMaps options on 2026-11-20.
-- This file is licensed under GPL-3.0-or-later; see ForeverMinimapTarget-LICENSE.txt.
local _, ns = ...
local Tracking = {}
ns.WildMapsTracking = Tracking

local FILTERS = { "Target", "Focus" }
local DEFAULTS = { Target = true }
local MENU_ID = "MENU_MINIMAP_TRACKING"

local function db()
  WildsparkCharDB = type(WildsparkCharDB) == "table" and WildsparkCharDB or {}
  WildsparkCharDB.wildMapsTracking = type(WildsparkCharDB.wildMapsTracking) == "table" and WildsparkCharDB.wildMapsTracking or {}
  return WildsparkCharDB.wildMapsTracking
end

local function showAll()
  if C_CVar and type(C_CVar.GetCVarBool) == "function" then
    local ok, value = pcall(C_CVar.GetCVarBool, "minimapTrackingShowAll")
    return ok and value == true
  end
  return false
end

local function filterID(key)
  return Enum and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter[key]
end

local function findIndex(key)
  if not C_Minimap or type(C_Minimap.GetNumTrackingTypes) ~= "function" or type(C_Minimap.GetTrackingFilter) ~= "function" then return nil end
  local id = filterID(key)
  if id == nil then return nil end
  local ok, count = pcall(C_Minimap.GetNumTrackingTypes)
  if not ok or type(count) ~= "number" then return nil end
  for index = 1, count do
    local okFilter, filter = pcall(C_Minimap.GetTrackingFilter, index)
    if okFilter and type(filter) == "table" and filter.filterID == id then return index end
  end
end

local function infoFor(key)
  local index = findIndex(key)
  if not index or not C_Minimap or type(C_Minimap.GetTrackingInfo) ~= "function" then return nil end
  local ok, info = pcall(C_Minimap.GetTrackingInfo, index)
  return ok and type(info) == "table" and info or nil
end

local function isActive(key)
  local info = infoFor(key)
  return info ~= nil and info.active == true
end

local function setActive(key, enabled)
  local index = findIndex(key)
  if not index or not C_Minimap or type(C_Minimap.SetTracking) ~= "function" then return false end
  if isActive(key) == (enabled == true) then return true end
  local ok = pcall(C_Minimap.SetTracking, index, enabled == true)
  return ok
end

function Tracking:IsEnabled(key)
  local saved = db()[key]
  if type(saved) == "boolean" then return saved end
  if DEFAULTS[key] ~= nil then return DEFAULTS[key] end
  return isActive(key)
end

function Tracking:SetEnabled(key, enabled)
  if key ~= "Target" and key ~= "Focus" then return end
  enabled = enabled == true
  db()[key] = enabled
  setActive(key, enabled)
end

function Tracking:Toggle(key)
  self:SetEnabled(key, not isActive(key))
end

local function apply()
  local saved = db()
  -- With Blizzard's complete tracking menu enabled, let its own entries manage these filters.
  if showAll() then return end
  for _, key in ipairs(FILTERS) do
    local value = saved[key]
    if value == nil then value = DEFAULTS[key] end
    if type(value) == "boolean" then setActive(key, value) end
  end
end

local function modifyTrackingMenu(_, rootDescription)
  if not rootDescription or showAll() then return end
  local entries = {}
  for _, key in ipairs(FILTERS) do
    local info = infoFor(key)
    if info then entries[#entries + 1] = { key = key, info = info } end
  end
  if #entries == 0 then return end
  rootDescription:CreateDivider()
  for _, entry in ipairs(entries) do
    local key, info = entry.key, entry.info
    local label = info.name or key
    local description = rootDescription:CreateCheckbox(label,
      function(savedKey) return Tracking:IsEnabled(savedKey) end,
      function(savedKey) Tracking:Toggle(savedKey) end,
      key)
    if description and type(description.AddInitializer) == "function" then
      description:AddInitializer(function(button)
        local icon = button:AttachTexture()
        icon:SetSize(20, 20)
        icon:SetPoint("RIGHT")
        icon:SetTexture(info.texture)
        local fontString = button.fontString
        if fontString then
          fontString:SetPoint("RIGHT", icon, "LEFT")
          return fontString:GetUnboundedStringWidth() + 60, 20
        end
        return 120, 20
      end)
    end
  end
end

if Menu and type(Menu.ModifyMenu) == "function" then
  Menu.ModifyMenu(MENU_ID, modifyTrackingMenu)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    local saved = db()
    if saved.Target == nil then saved.Target = true end
  end
  apply()
  if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(3, apply) end
end)

return Tracking
