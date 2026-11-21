-- WildLayer integration: keeps module preferences in WildSparkDB and exposes
-- controls to WildSpark's module tab while retaining AutoLayerDB settings.
local _, ns = ...
local module = {}
ns.WildLayer = module

local function savedSettings()
    local db = ns.db or _G.WildsparkDB
    if type(db) ~= "table" then return nil end
    db.modules = type(db.modules) == "table" and db.modules or {}
    db.modules.wildLayer = type(db.modules.wildLayer) == "table" and db.modules.wildLayer or {}
    local s = db.modules.wildLayer
    if s.enabled == nil then s.enabled = true end
    if s.autoInvites == nil then s.autoInvites = false end
    return s
end

function module.IsEnabled()
    local s = savedSettings()
    return not s or s.enabled ~= false
end

function module.SetEnabled(enabled)
    local s = savedSettings()
    if s then s.enabled = enabled and true or false end
    if _G.WildLayer and _G.WildLayer.db then
        _G.WildLayer:SetEnabled(nil, enabled)
    end
end

function module.GetAutoInvites()
    local s = savedSettings()
    if s then return s.autoInvites == true end
    return false
end

function module.SetAutoInvites(enabled)
    local s = savedSettings()
    if s then s.autoInvites = enabled and true or false end
    if _G.WildLayer and _G.WildLayer.db then
        _G.WildLayer:SetAllowAutoInvites(nil, enabled)
    end
end

function module.GetMinimapButton()
    local addon = _G.WildLayer
    return not (addon and addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.hide)
end

function module.SetMinimapButton(enabled)
    local addon = _G.WildLayer
    if addon and addon.db and addon.db.profile then
        addon:SetMinimapHidden(nil, not enabled)
    end
end

function module.Open()
    if not module.IsEnabled() then return end
    if _G.WildLayer and _G.WildLayer.HopGUI then _G.WildLayer:HopGUI() end
end

function module.OpenSettings()
    local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
    if dialog and dialog.Open then dialog:Open("WildLayer") end
end

local applyAttempts = 0
function module.InitializeSavedVariables()
    local s = savedSettings()
    if not s then return end
    local addon = _G.WildLayer
    if not (addon and addon.db and addon.db.profile) then
        if C_Timer and applyAttempts < 20 then
            applyAttempts = applyAttempts + 1
            C_Timer.After(0.25, module.InitializeSavedVariables)
        end
        return
    end
    applyAttempts = 0
    addon:SetAllowAutoInvites(nil, s.autoInvites)
    addon:SetEnabled(nil, s.enabled)
    -- AutoLayer settings may already exist from a standalone installation;
    -- WildSpark's explicit module preference is the single source of truth.
    if addon.db.profile.allowAutoInvites ~= s.autoInvites then
        addon:SetAllowAutoInvites(nil, s.autoInvites)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "WildSpark" then
        if C_Timer then C_Timer.After(0, module.InitializeSavedVariables) else module.InitializeSavedVariables() end
    end
end)
