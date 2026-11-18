-- WildPvP feature launcher. The player-facing identity is WildPvP; the
-- component command IDs are internal compatibility hooks for bundled code.
local _, ns = ...
local module = {}
ns.WildPvP = module

local COMPONENTS = {
    { id = "nearby", command = "SPY", args = "config" },
    { id = "timers", command = "Capping", args = "" },
    { id = "intel", command = "HIGHGROUNDBATTLEGROUNDS", args = "config" },
    { id = "enemyframes", command = "BattleGroundEnemies", args = "" },
}

function module.IsInstalled()
    return true
end

local function inPvpInstance()
    if type(IsInInstance) ~= "function" then return false end
    local inside, kind = IsInInstance()
    return inside and (kind == "pvp" or kind == "arena")
end
module.IsActive = inPvpInstance

function module.OpenComponent(id)
    for _, component in ipairs(COMPONENTS) do
        if component.id == id then
            local handler = SlashCmdList and SlashCmdList[component.command]
            if type(handler) == "function" then handler(component.args); return true end
            return false
        end
    end
    return false
end

function module.Open()
    if type(ns.OpenModulePage) == "function" then
        ns.OpenModulePage("pvp")
        return true
    end
    return false
end
