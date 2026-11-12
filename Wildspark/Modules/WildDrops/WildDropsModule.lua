-- WildDrops: focused mob-tooltip integration for WildSpark.
-- The database records percentage chances. Rare-drop rows are enabled by default.
local _, addonNS = ...
local core = addonNS.WildDropsCore
local module = {}
addonNS.WildInfo = module
-- Keep the original API alias for older saved UI integrations.
addonNS.WildDrops = module

local function settings()
    return (core and core.db) or _G.WildDropsDB
end

function module.IsEnabled()
    local db = settings()
    return db ~= nil and db.enabled ~= false
end

function module.SetEnabled(enabled)
    local db = settings()
    if not db then return end
    db.enabled = enabled and true or false
    if core and core.Refresh then core.Refresh() end
end

function module.IsTooltipEnabled()
    local db = settings()
    return module.IsEnabled() and db.tooltip ~= false
end

function module.SetTooltipEnabled(enabled)
    local db = settings()
    if not db then return end
    db.tooltip = enabled and true or false
    if core and core.Refresh then core.Refresh() end
end

function module.GetShowRare()
    local db = settings()
    return db and db.showRare ~= false or false
end

function module.SetShowRare(enabled)
    local db = settings()
    if not db then return end
    db.showRare = enabled and true or false
    if core and core.Refresh then core.Refresh() end
end

function module.GetRespawnEnabled()
    local db = settings()
    return db ~= nil and db.respawnEnabled ~= false
end

function module.SetRespawnEnabled(enabled)
    local db = settings()
    if not db then return end
    db.respawnEnabled = enabled and true or false
    if core and core.Refresh then core.Refresh() end
    if addonNS.CampNet then addonNS.CampNet.Apply() end
end
