-- WildGroups integration shim for WildSpark.
local _, ns = ...
local groups = ns.WildGroups
local function settings()
    local db = ns.db or _G.WildsparkDB
    if type(db) ~= "table" then return nil end
    db.modules = db.modules or {}
    db.modules.wildGroups = db.modules.wildGroups or {}
    return db.modules.wildGroups
end
function groups.IsEnabled()
    local s = settings()
    return not s or s.enabled ~= false
end
function groups.SetEnabled(enabled)
    local isEnabled = enabled and true or false
    local s = settings()
    if s then s.enabled = isEnabled end
    if not isEnabled and groups.CloseWindow then groups.CloseWindow() end
    if groups.UpdateBlizzardTab then groups.UpdateBlizzardTab() end
    if groups.UpdateMinimapButton then groups.UpdateMinimapButton() end
end
function groups.Open()
    if groups.IsEnabled() and groups.OpenWindow then groups.OpenWindow() end
end
function groups.InitializeSavedVariables()
    local db = ns.db or _G.WildsparkDB
    if type(db) == "table" then
        db.modules = db.modules or {}
        db.modules.wildGroups = db.modules.wildGroups or { enabled = true }
        if db.modules.wildGroups.enabled == nil then db.modules.wildGroups.enabled = true end
    end
    if groups.UpdateBlizzardTab then groups.UpdateBlizzardTab() end
    if groups.UpdateMinimapButton then groups.UpdateMinimapButton() end
end
function groups.OpenSettings()
    if groups.settingsCategory and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(groups.settingsCategory:GetID())
    end
end