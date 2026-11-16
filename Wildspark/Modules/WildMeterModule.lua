-- WildMeter: configurable presentation for Blizzard's live damage meter.
-- Design and data-category mapping adapted from Details! Damage Meter's Forever parser
-- (core/parser_nocleu.lua), used with permission from the user, who reports author authorization.
-- Details! source: https://github.com/Tercioo/Details-Damage-Meter
-- Upstream LICENSE states "All rights reserved"; this adaptation does not change that notice.
-- WildMeter keeps C_DamageMeter enabled and delegates secret combat values to Blizzard's UI.
local _, ns = ...
local module = {}
ns.WildMeterModule = module

local DAMAGE_METER
local API = _G.C_DamageMeter
local ENUM = _G.Enum and Enum.DamageMeterType
local STYLE = _G.Enum and Enum.DamageMeterStyle
local NUMBERS = _G.Enum and Enum.DamageMeterNumbers
local SESSION = _G.Enum and Enum.DamageMeterSessionType

-- Categories correspond to the Forever C_DamageMeter types used by Details' no-combat-log parser.
local METRICS = {
    { key = "DamageDone", enum = "DamageDone" },
    { key = "Dps", enum = "Dps" },
    { key = "DamageTaken", enum = "DamageTaken" },
    { key = "EnemyDamageTaken", enum = "EnemyDamageTaken" },
    { key = "AvoidableDamageTaken", enum = "AvoidableDamageTaken" },
    { key = "HealingDone", enum = "HealingDone" },
    { key = "Hps", enum = "Hps" },
    { key = "Absorbs", enum = "Absorbs" },
    { key = "Interrupts", enum = "Interrupts" },
    { key = "Dispels", enum = "Dispels" },
}

local function db()
    local root = _G.WildsparkDB
    if type(root) ~= "table" then return nil end
    root.modules = type(root.modules) == "table" and root.modules or {}
    root.modules.wildMeter = type(root.modules.wildMeter) == "table" and root.modules.wildMeter or {}
    local value = root.modules.wildMeter
    if value.style == nil then value.style = "Default" end
    if value.numbers == nil then value.numbers = "Compact" end
    if value.barHeight == nil then value.barHeight = 18 end
    if value.barSpacing == nil then value.barSpacing = 2 end
    if value.textScale == nil then value.textScale = 1 end
    if value.windowAlpha == nil then value.windowAlpha = 1 end
    if value.backgroundAlpha == nil then value.backgroundAlpha = 0.85 end
    if value.classColor == nil then value.classColor = true end
    if value.icons == nil then value.icons = true end
    if value.session == nil then value.session = "Current" end
    if value.metric == nil then value.metric = "DamageDone" end
    return value
end

local function apiReady()
    DAMAGE_METER = DAMAGE_METER or _G.DamageMeter
    return API and DAMAGE_METER and ENUM and STYLE and NUMBERS and SESSION
        and type(API.IsDamageMeterAvailable) == "function"
        and type(DAMAGE_METER.SetStyle) == "function"
end

function module.IsAvailable()
    return apiReady()
end

function module.GetMetrics()
    local result = {}
    if not ENUM then return result end
    for _, item in ipairs(METRICS) do
        local id = ENUM[item.enum]
        if type(id) == "number" then
            result[#result + 1] = { key = item.key, id = id }
        end
    end
    return result
end

local function metricID(key)
    if not ENUM then return nil end
    for _, item in ipairs(METRICS) do
        if item.key == key then return ENUM[item.enum] end
    end
end

local function apply()
    if not apiReady() then return false end
    local value = db()
    if not value then return false end
    local style = STYLE[value.style]
    local numbers = NUMBERS[value.numbers]
    if style ~= nil then DAMAGE_METER:SetStyle(style) end
    if numbers ~= nil then DAMAGE_METER:SetNumberDisplayType(numbers) end
    DAMAGE_METER:SetUseClassColor(value.classColor == true)
    DAMAGE_METER:SetShowBarIcons(value.icons == true)
    DAMAGE_METER:SetBarHeight(value.barHeight)
    DAMAGE_METER:SetBarSpacing(value.barSpacing)
    DAMAGE_METER:SetTextScale(value.textScale)
    DAMAGE_METER:SetWindowAlpha(value.windowAlpha)
    DAMAGE_METER:SetBackgroundAlpha(value.backgroundAlpha)
    return true
end

function module.Apply()
    return apply()
end

function module.GetSetting(key)
    local value = db()
    return value and value[key]
end

function module.SetSetting(key, newValue)
    local value = db()
    if not value then return end
    value[key] = newValue
    apply()
end

function module.GetMetricChoices()
    local choices = {}
    for _, item in ipairs(module.GetMetrics()) do
        choices[#choices + 1] = { item.key, item.key }
    end
    return choices
end

function module.GetSessionChoices()
    return { { "Current", "Current" }, { "Overall", "Overall" } }
end

function module.SetSessionChoice(value)
    if value ~= "Current" and value ~= "Overall" then return end
    module.SetSetting("session", value)
end

function module.SetMetricChoice(value)
    if not metricID(value) then return end
    module.SetSetting("metric", value)
end

-- A secondary native session window is a true popout. The native collector remains enabled;
-- no combat-log parsing, sorting, or arithmetic on secret combat values is performed here.
function module.OpenPopout()
    if not apiReady() then return false end
    local metric = metricID(module.GetSetting("metric") or "DamageDone")
    if not metric or type(DAMAGE_METER.ShowNewSecondarySessionWindow) ~= "function" then return false end

    local before = {}
    local windows = DAMAGE_METER.GetWindowDataList and DAMAGE_METER:GetWindowDataList() or {}
    for index, data in pairs(windows) do
        if data and data.sessionWindow and data.sessionWindow:IsShown() then before[index] = true end
    end

    DAMAGE_METER:ShowNewSecondarySessionWindow()
    local created
    for index, data in pairs(windows) do
        if index ~= 1 and data and data.sessionWindow and data.sessionWindow:IsShown() and not before[index] then
            created = data.sessionWindow
            break
        end
    end
    if not created then return false end

    local session = module.GetSetting("session") == "Overall" and SESSION.Overall or SESSION.Current
    local owner = created.GetDamageMeterOwner and created:GetDamageMeterOwner() or DAMAGE_METER
    if owner.SetSessionWindowDamageMeterType then
        owner:SetSessionWindowDamageMeterType(created, metric)
    else
        created:SetDamageMeterType(metric)
    end
    if owner.SetSessionWindowSessionID then
        owner:SetSessionWindowSessionID(created, session, nil)
    else
        created:SetSession(session, nil)
    end
    if created.RefreshLayout then created:RefreshLayout() end
    return true
end

function module.Open()
    if not apiReady() then return false end
    if DAMAGE_METER:IsShown() then
        DAMAGE_METER:Hide()
    else
        DAMAGE_METER:Show()
    end
    return true
end

local slash = CreateFrame("Frame")
slash:RegisterEvent("PLAYER_LOGIN")
slash:RegisterEvent("ADDON_LOADED")
slash:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
slash:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
slash:RegisterEvent("DAMAGE_METER_RESET")
slash:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, apply)
    elseif event == "ADDON_LOADED" then
        C_Timer.After(0, apply)
    elseif apiReady() then
        -- The native window refreshes itself. Re-apply only presentation settings, never data state.
        apply()
    end
end)

SLASH_WILDMETER1 = "/wmeter"
SlashCmdList.WILDMETER = function(message)
    message = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if message == "popout" then
        if not module.OpenPopout() then print("|cff66ccffWildMeter|r: no free Blizzard meter popout is available.") end
    elseif message == "show" then
        module.Open()
    else
        if ns.ToggleMenu then ns.ToggleMenu() end
        if ns.OpenMenuPage then ns.OpenMenuPage("wildmeter") end
        print("|cff66ccffWildMeter|r: use the WildMeter tab; /wmeter popout opens a second native meter window.")
    end
end
