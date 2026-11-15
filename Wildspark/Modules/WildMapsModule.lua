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
    if WorldMapFrame and type(WorldMapFrame.IsShown) == "function" and not WorldMapFrame:IsShown()
        and type(ShowUIPanel) == "function" then
        ShowUIPanel(WorldMapFrame)
    elseif type(ToggleWorldMap) == "function" then
        ToggleWorldMap()
    elseif WorldMapFrame and type(ShowUIPanel) == "function" then
        ShowUIPanel(WorldMapFrame)
    end
end

function module.GetMaps()
    local registry = ns.WildMaps and ns.WildMaps.Registry
    return registry and registry:GetMaps() or {}
end

function module.SelectMap(mapID)
    local map = ns.WildMaps and ns.WildMaps.Registry and ns.WildMaps.Registry:GetMap(mapID)
    if not map then return false end
    if not module.IsEnabled() then module.SetEnabled(true) end
    if ns.WildMaps.MapOverride then
        ns.WildMaps.MapOverride:Apply(map)
        return true
    end
    return false
end

function module.PlaceEntryMarker()
    local worldMap = ns.WildMaps and ns.WildMaps.WorldMap
    if not worldMap or not worldMap.BeginManualStartPlacement then return false end
    local ok = worldMap:BeginManualStartPlacement()
    if ok then module.Open() end
    return ok
end

