-- WildFishing: notify when fishing loot opens after a recent fishing cast.
-- The game does not expose an event for the bobber bite itself, so this can
-- remind the player to loot after clicking the bobber, but cannot signal the splash.

local _, addonNS = ...
local module = {}
addonNS.WildFishing = module

local defaults = { enabled = true, visual = true, sound = true }
local db
local fishingUntil = 0
local alertUntil = 0

function module.IsEnabled()
    return db ~= nil and db.enabled ~= false
end

function module.SetEnabled(enabled)
    if not db then return end
    db.enabled = enabled and true or false
    if not db.enabled and module.alert then module.alert:Hide() end
end

function module.GetVisualEnabled()
    return db ~= nil and db.visual ~= false
end

function module.SetVisualEnabled(enabled)
    if not db then return end
    db.visual = enabled and true or false
    if not db.visual and module.alert then module.alert:Hide() end
end

function module.GetSoundEnabled()
    return db ~= nil and db.sound ~= false
end

function module.SetSoundEnabled(enabled)
    if not db then return end
    db.sound = enabled and true or false
end

local function CreateAlert()
    if module.alert or not UIParent then return end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(560, 92)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 155)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetVertexColor(0.03, 0.025, 0.01, 0.88)
    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFont("Fonts\\FRIZQT__.TTF", 25, "OUTLINE")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1, 0.82, 0.1)
    frame.text = text
    frame:SetScript("OnUpdate", function(self)
        if alertUntil > 0 and GetTime() >= alertUntil then
            alertUntil = 0
            self:Hide()
        end
    end)
    frame:Hide()
    module.alert = frame
end

local function IsFishingSpell(...)
    local fishingName = GetSpellInfo and GetSpellInfo(7620)
    local wanted = type(fishingName) == "string" and fishingName:lower()
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value == 7620 then return true end
        if type(value) == "string" then
            local text = value:lower()
            if text == "fishing" or (wanted and text == wanted) then return true end
        end
    end
    return false
end

local function IsFishingBobberLoot()
    if not GetNumLootItems or GetNumLootItems() < 1 then return false end
    if not GetLootSourceInfo then return true end
    local sawSource = false
    for slot = 1, GetNumLootItems() do
        local ok, sourceGUID = pcall(GetLootSourceInfo, slot)
        if ok and type(sourceGUID) == "string" then
            sawSource = true
            return sourceGUID:match("^GameObject%-") ~= nil
        end
    end
    return not sawSource
end

local function NotifyLootReady()
    if not module.IsEnabled() or GetTime() > fishingUntil then return end
    if not IsFishingBobberLoot() then return end
    fishingUntil = 0
    if module.GetVisualEnabled() then
        CreateAlert()
        module.alert.text:SetText("FISHING LOOT READY!\nClick the loot window to collect your catch.")
        alertUntil = GetTime() + 5
        module.alert:SetAlpha(1)
        module.alert:Show()
    end
    if module.GetSoundEnabled() and PlaySound then
        pcall(PlaySound, 8959)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= "WildSpark" then return end
        WildFishingDB = WildFishingDB or {}
        db = WildFishingDB
        for key, value in pairs(defaults) do
            if db[key] == nil then db[key] = value end
        end
        CreateAlert()
        self:UnregisterEvent("ADDON_LOADED")
        self:RegisterEvent("UNIT_SPELLCAST_SENT")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self:RegisterEvent("LOOT_OPENED")
        return
    end

    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = ...
        if unit == "player" and IsFishingSpell(select(2, ...)) then
            fishingUntil = GetTime() + 90
        end
    elseif event == "LOOT_OPENED" then
        NotifyLootReady()
    end
end)
