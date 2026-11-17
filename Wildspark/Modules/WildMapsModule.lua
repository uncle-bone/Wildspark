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
    local zone = module.ZoneMap or (ns.WildMaps and ns.WildMaps.ZoneMap)
    if not enabled and zone and zone.frame then zone.frame:Hide() end
    if ns.WildMaps and ns.WildMaps.RefreshMap then
        ns.WildMaps:RefreshMap("WildMaps enabled state changed")
    end
end

function module.GetMapCount()
    local registry = ns.WildMaps and ns.WildMaps.Registry
    return registry and #registry:GetMaps() or 0
end

module.ZoneMap = ns.WildMaps and ns.WildMaps.ZoneMap

function module.Open()
    if not module.IsEnabled() then return false end
    local zone = module.ZoneMap or (ns.WildMaps and ns.WildMaps.ZoneMap)
    if zone and zone.Show then zone:Show() else return false end
    return true
end
function module.GetMaps()
    local registry = ns.WildMaps and ns.WildMaps.Registry
    return registry and registry:GetMaps() or {}
end

function module.SelectMap(mapID)
    if not module.IsEnabled() then return false end
    local wildMaps = ns.WildMaps
    local map = wildMaps and wildMaps.Registry and wildMaps.Registry:GetMap(mapID)
    local zone = module.ZoneMap or (wildMaps and wildMaps.ZoneMap)
    if not map or not zone then return false end
    zone.pinnedMap = map.id
    if zone.frame then zone.frame:Show() elseif zone.Show then zone:Show(); zone.pinnedMap = map.id end
    if zone.Refresh then zone:Refresh() end
    return true
end
