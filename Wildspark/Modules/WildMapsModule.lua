-- WildMaps controls exposed in WildSpark's module pane.
local _, ns = ...
local module = {}
ns.WildMapsModule = module

local function settings()
    local db = _G.WildsparkDB
    if type(db) ~= "table" then return nil end
    db.modules = type(db.modules) == "table" and db.modules or {}
    db.modules.wildMaps = type(db.modules.wildMaps) == "table" and db.modules.wildMaps or {}
    local value = db.modules.wildMaps
    if value.enabled == nil then value.enabled = true end
    return value
end

function module.IsEnabled()
    local value = settings()
    return not value or value.enabled ~= false
end

function module.SetEnabled(enabled)
    local value = settings()
    if value then value.enabled = enabled == true end
    if ns.WildMaps and ns.WildMaps.RefreshMap then
        ns.WildMaps:RefreshMap("WildMaps enabled state changed")
    end
end

function module.GetMapCount()
    local registry = ns.WildMaps and ns.WildMaps.Registry
    return registry and #registry:GetMaps() or 0
end

function module.Open()
    if type(ToggleWorldMap) == "function" then
        ToggleWorldMap()
    elseif WorldMapFrame and type(ShowUIPanel) == "function" then
        ShowUIPanel(WorldMapFrame)
    end
end

