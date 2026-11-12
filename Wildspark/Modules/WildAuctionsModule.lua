local _, ns = ...
local M = _G.WildAuctions or {}
_G.WildAuctions = M
ns.WildAuctions = M

function M.IsEnabled()
    return not (WildsparkDB and WildsparkDB.modules and WildsparkDB.modules.wildAuctions == false)
end

function M.SetEnabled(value)
    local enabled = value and true or false
    WildsparkDB = WildsparkDB or {}
    WildsparkDB.modules = WildsparkDB.modules or {}
    WildsparkDB.modules.wildAuctions = enabled

    local core = M.M
    if not core then return end

    if not enabled then
        if core.frame then core.frame:Hide() end
        if AuctionHouseFrame and AuctionHouseFrame:IsShown()
            and type(core.set_blizzard_frame_shown) == "function" then
            core.set_blizzard_frame_shown(true)
        end
    end

    if type(core.update_native_open_button) == "function" then
        core.update_native_open_button()
    end
end

function M.Open()
    if not M.IsEnabled() then return end
    local core = M.M
    if not core then return end

    if AuctionHouseFrame and AuctionHouseFrame:IsShown()
        and type(core.open_wild_auctions) == "function" then
        core.open_wild_auctions()
    elseif core.frame then
        core.frame:Show()
    end
end
