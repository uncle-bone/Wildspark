-- WildDrops: focused mob-tooltip integration for WildSpark.
-- The database records percentage chances. Rare-drop rows are enabled by default.
local _, ns = ...
local module = {}
ns.WildDrops = module

local function settings()
    return ns.db or _G.WildDropsDB
end

function module.IsEnabled()
    local db = settings()
    return db ~= nil and db.enabled ~= false
end

function module.SetEnabled(enabled)
    local db = settings()
    if not db then return end
    db.enabled = enabled and true or false
    if ns.Refresh then ns.Refresh() end
end

function module.IsTooltipEnabled()
    local db = settings()
    return module.IsEnabled() and db.tooltip ~= false
end

function module.SetTooltipEnabled(enabled)
    local db = settings()
    if not db then return end
    db.tooltip = enabled and true or false
    if ns.Refresh then ns.Refresh() end
end

function module.GetShowRare()
    local db = settings()
    return db and db.showRare ~= false or false
end

function module.SetShowRare(enabled)
    local db = settings()
    if not db then return end
    db.showRare = enabled and true or false
    if ns.Refresh then ns.Refresh() end
end
