-- Mob tooltips: item, drop chance and the quest it starts.

local _, addonNS = ...
local ns = addonNS.WildDropsCore or {}
addonNS.WildDropsCore = ns

ns.tooltipHook = "none" -- which hook is in use, shown by /qd target

-- The GUID of the unit a tooltip shows, or nil. Newer clients may hand addons a
-- secret unit token, and addon code may not even pass that to UnitGUID.
local function GetTooltipUnitGUID(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit or ns.IsSecret(unit) then return end
    return UnitGUID(unit)
end

local hasOurLines = false -- the shown GameTooltip contains our lines (cleared on hide)

local function AddTooltipLines(tooltip, guid)
    if not ns.db or ns.db.enabled == false or ns.db.tooltip == false or tooltip ~= GameTooltip then return end
    local drops = ns.GetAvailableDrops(ns.GetNpcID(guid)) -- nil for a secret GUID
    if not drops then return end
    for _, drop in ipairs(drops) do
        local item, quest = ns.FormatDropParts(drop)
        tooltip:AddDoubleLine(item, ns.FormatChance(drop[3]))
        tooltip:AddLine(quest)
    end
    hasOurLines = true
    tooltip:Show()
end

ns.OnLogin(function()
    if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            local guid = data and data.guid
            -- The tooltip data may carry a secret GUID; the unit's own one may be readable.
            if not guid or ns.IsSecret(guid) then
                guid = GetTooltipUnitGUID(tooltip)
            end
            AddTooltipLines(tooltip, guid)
        end)
        ns.tooltipHook = "TooltipDataProcessor"
    elseif GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            AddTooltipLines(tooltip, GetTooltipUnitGUID(tooltip))
        end)
        ns.tooltipHook = "OnTooltipSetUnit"
    end
    GameTooltip:HookScript("OnHide", function() hasOurLines = false end)
end)

-- An item name in our open tooltip lines loaded late: rebuild the tooltip so it
-- shows the name in its quality colour.
ns.OnItemInfoLoaded(function()
    if not hasOurLines or not GameTooltip:IsShown() then return end
    if GameTooltip.RefreshData then
        GameTooltip:RefreshData() -- rebuilds from the tooltip's own data, no unit token needed
        return
    end
    local _, unit = GameTooltip:GetUnit()
    if unit and not ns.IsSecret(unit) then
        GameTooltip:SetUnit(unit)
    end
end)
