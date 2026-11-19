local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Round button on the minimap edge that opens the window. Drag it to move it
-- around the minimap; the angle is saved for all characters (db.minimapAngle).
-- Plain frames instead of LibDBIcon, like the rest of the UI.
-- Settings' Shown on: Minimap button switch or /wildgear minimap hides it
-- (minimapButton = false); the addon compartment entry and /wildgear still open
-- the window.

local ICON = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\MinimapIcon"
local DEFAULT_ANGLE = 225 -- degrees counterclockwise from the right: bottom left
local EDGE_OFFSET = 5 -- how far the button's centre sits outside the minimap edge

local button
local M = {}
ns.Minimap = M

local function SetAngle(angle)
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    -- Addons that make the minimap square define GetMinimapShape; follow its edge.
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        x * (Minimap:GetWidth() / 2 + EDGE_OFFSET), y * (Minimap:GetHeight() / 2 + EDGE_OFFSET))
end

-- Angle from the minimap centre to the cursor.
local function CursorAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    return math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
end

local function OnUpdate()
    ns.db.minimapAngle = CursorAngle()
    SetAngle(ns.db.minimapAngle)
end

local function Create()
    button = CreateFrame("Button", "WildGearMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Same layers as the standard minimap buttons: dark disc, icon, gold ring.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("CENTER", button, "CENTER")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture(ICON)
    icon:SetPoint("CENTER", button, "CENTER")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", button, "TOPLEFT")

    button:SetScript("OnClick", function() ns.UI.Toggle() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("WildGear")
        GameTooltip:AddLine(ns.L["Click to open or close"], 1, 1, 1)
        GameTooltip:AddLine(ns.L["Drag to move"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", OnUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    SetAngle(ns.db.minimapAngle or DEFAULT_ANGLE)
end

function M.Shown()
    return ns.db.minimapButton ~= false
end

-- Shows or hides the button by the setting.
function M.Refresh()
    if ns.Options then ns.Options.Refresh() end -- (the switch in the game's Options > AddOns)
    if not button then return end
    if M.Shown() then button:Show() else button:Hide() end
end

-- /wildgear minimap: switches the button on or off.
function M.Toggle()
    if M.Shown() then ns.db.minimapButton = false else ns.db.minimapButton = nil end
    M.Refresh()
    ns.Settings.Update() -- (its switch, while the panel is open)
    print("WildGear: " .. (M.Shown() and ns.L["Minimap button shown."]
        or ns.L["Minimap button hidden. /wildgear minimap shows it again."]))
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if Minimap then
        Create()
        M.Refresh()
    end
end)
