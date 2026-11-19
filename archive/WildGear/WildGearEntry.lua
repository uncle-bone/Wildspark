local _, addonRoot = ...
local module = addonRoot.WildGear

module.Open = function()
    if module.UI and module.UI.Toggle then
        module.UI.Toggle()
        return true
    end
    if addonRoot.Print then addonRoot.Print("WildGear is still initializing or failed to load. Check the WildSpark error log.") end
    return false
end

module.OpenSettings = function()
    if module.Settings and module.Settings.Show then
        module.Settings.Show()
        return true
    end
    return module.Open()
end

module.OpenEnhancements = function()
    if module.EnhancementGuide and module.EnhancementGuide.Show then
        module.EnhancementGuide.Show()
        return true
    end
    if addonRoot.Print then addonRoot.Print("WildGear's enhancement guide is still initializing.") end
    return false
end
