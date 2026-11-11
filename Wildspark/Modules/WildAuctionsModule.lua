local ADDON, ns = ...
local M = _G.WildAuctions or {}
_G.WildAuctions = M
ns.WildAuctions = M
function M.IsEnabled() return not (WildsparkDB and WildsparkDB.modules and WildsparkDB.modules.wildAuctions == false) end
function M.SetEnabled(value)
 WildsparkDB = WildsparkDB or {}
 WildsparkDB.modules = WildsparkDB.modules or {}
 WildsparkDB.modules.wildAuctions = value and true or false
 local core = M.M
 if not value and core and core.frame then core.frame:Hide() end
end
function M.Open()
 if not M.IsEnabled() then M.SetEnabled(true) end
 local core = M.M
 if core and core.frame then core.frame:Show() end
end
