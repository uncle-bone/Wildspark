local _, addonRoot = ...
local ns = addonRoot.WildGear

-- /wildgear opens the integrated gear planner; settings and news are also available here.
SLASH_WILDGEAR1 = "/wildgear"
SlashCmdList.WILDGEAR = function(msg)
    msg = msg and msg:lower() or ""
    if msg:match("^%s*settings") then
        ns.Settings.Show()
    elseif msg:match("^%s*news") then
        ns.WhatsNew.Show()
    else
        ns.UI.Toggle()
    end
end