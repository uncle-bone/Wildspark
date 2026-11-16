-- WildMeter compatibility page for Blizzard's live damage meter.
-- Details! source attribution and permission notice are retained below as required.
-- Design/category references: Details! Damage Meter, core/parser_nocleu.lua.
-- https://github.com/Tercioo/Details-Damage-Meter
-- Upstream LICENSE states "All rights reserved"; permission to adapt was reported by the user.
-- Do not call Blizzard damage-meter setters from addon code on Forever: refreshing entry
-- rows can compare secret specIconID values under WildSpark taint.
local _, ns = ...
local module = {}
ns.WildMeterModule = module

function module.IsAvailable()
    local api = _G.C_DamageMeter
    return api and type(api.IsDamageMeterAvailable) == "function"
end

-- Deliberately do not open, refresh, or restyle Blizzard meter windows from this module.
-- Blizzard's native UI remains responsible for live data and its own rendering.
function module.Open()
    return false
end

function module.OpenPopout()
    return false
end

SLASH_WILDMETER1 = "/wmeter"
SlashCmdList.WILDMETER = function()
    if ns.ToggleMenu then ns.ToggleMenu() end
    if ns.OpenMenuPage then ns.OpenMenuPage("wildmeter") end
    print("|cff66ccffWildMeter|r: use Blizzard's native damage meter controls; addon-driven refresh is disabled on this client to avoid secret-value taint.")
end
