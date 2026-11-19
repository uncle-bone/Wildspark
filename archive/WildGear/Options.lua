local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Our page in the game's Options > AddOns (Esc menu): a button that opens
-- the window, a line saying /wildgear does too, the minimap button's switch
-- (minimapButton = false when off, as Settings' Shown on switch) and the
-- key that opens or closes the window (Bindings.xml's binding, also under
-- Options > Keybindings > AddOns): click its button, then press a key, mouse
-- button or gamepad button, with modifiers (Esc, a plain click or moving off
-- the button cancels; a key bound to something else asks first); Clear,
-- beside it, unbinds it. Everything else is set
-- in the window.
-- Blizzard's own fonts and templates, like the pages around it.

local O = {}
ns.Options = O

local L = ns.L
local PAD = 16
local ACTION = "WILDGEAR_TOGGLE"
BINDING_HEADER_WILDGEAR = "WildGear"
_G["BINDING_NAME_" .. ACTION] = L["Open or close the window"]
BINDING_NAME_WILDGEAR_WISHLIST = L["Show or hide the wish list"] -- (WishList.lua)

-- Pressed alone, these only start a combination.
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true }

-- Gamepad buttons set to act as Shift, Ctrl or Alt (they make IsShiftKeyDown
-- and the others true, as the keys do).
local PAD_MODIFIER_CVARS = { "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }

-- Mouse buttons as bindings name them. Left and right click only bind with a
-- modifier (as in the game's own Keybindings): plain, they cancel.
local MOUSE = { LeftButton = "BUTTON1", RightButton = "BUTTON2", MiddleButton = "BUTTON3" }

local check, bind, bindHint, clear
local capturing
local capturedAt -- GetTime() capturing ended: the click that ends with it (the mouse's, or the gamepad cursor's) mustn't start again

local function KeyText(key)
    return GetBindingText and GetBindingText(key) or key
end

local function UpdateBind()
    if not bind then return end
    local key = GetBindingKey(ACTION)
    -- (Clear, beside it, while not capturing: the hint in its place)
    if capturing then
        bind:SetText(L["Press a key"])
        clear:Hide()
        bindHint:Show()
    else
        bind:SetText(key and KeyText(key) or NOT_BOUND or "Not bound")
        clear:SetEnabled(key ~= nil)
        clear:Show()
        bindHint:Hide()
    end
end

local function StopCapture()
    capturing = false
    capturedAt = GetTime()
    bind:SetScript("OnKeyDown", nil)
    bind:SetScript("OnGamePadButtonDown", nil)
    bind:SetScript("OnMouseWheel", nil)
    bind:EnableKeyboard(false)
    bind:EnableMouseWheel(false) -- (the Options list scrolls under it again)
    if bind.EnableGamePadButton then bind:EnableGamePadButton(false) end
    UpdateBind()
end

-- Binds `key` (nil: none, Clear) to the window in place of its key before,
-- saved with the game's binding set.
local function SetKey(key)
    if InCombatLockdown() then
        print(ERR_NOT_IN_COMBAT or "You can't do that while in combat.")
        return
    end
    for _, old in ipairs({ GetBindingKey(ACTION) }) do SetBinding(old) end
    if key then SetBinding(key, ACTION) end
    SaveBindings(GetCurrentBindingSet())
end

-- A key already bound to something else asks first (Yes takes it over).
StaticPopupDialogs["WILDGEAR_REBIND"] = {
    text = L["%s is bound to %s.\nUse it for WildGear instead?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, key)
        SetKey(key)
        UpdateBind()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function TryKey(key)
    local prev = GetBindingAction(key)
    if prev and prev ~= "" and prev ~= ACTION then
        StaticPopup_Show("WILDGEAR_REBIND", KeyText(key), _G["BINDING_NAME_" .. prev] or prev, key)
    else
        SetKey(key)
    end
end

-- The key or button with the modifiers held, as bindings name them
-- (ALT-CTRL-SHIFT-X); plain left or right click cancels.
local function Take(key)
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. (IsMetaKeyDown and IsMetaKeyDown() and "META-" or "") .. key
    StopCapture() -- (before the popup, so its keys reach it)
    if combo ~= "BUTTON1" and combo ~= "BUTTON2" then
        TryKey(combo)
        UpdateBind()
    end
end

local function OnMouseDown(_, button)
    if not capturing then return end
    local key = MOUSE[button] or (button:match("^Button(%d+)$") and "BUTTON" .. button:match("%d+"))
    if key then Take(key) end
end

local function OnMouseWheel(_, delta)
    Take(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end

local function OnKeyDown(_, key)
    if MODIFIERS[key] then return end
    if key == "ESCAPE" then StopCapture() else Take(key) end
end

local function OnGamePadButtonDown(_, button)
    for _, cvar in ipairs(PAD_MODIFIER_CVARS) do
        if GetCVar(cvar) == button then return end
    end
    Take(button)
end

local function OnBindClick(self)
    if capturing then
        StopCapture()
    elseif capturedAt and GetTime() - capturedAt < 0.5 then
        return -- (the press that just ended capturing)
    elseif InCombatLockdown() then
        print(ERR_NOT_IN_COMBAT or "You can't do that while in combat.")
    else
        capturing = true
        self:EnableKeyboard(true)
        self:SetScript("OnKeyDown", OnKeyDown)
        self:EnableMouseWheel(true)
        self:SetScript("OnMouseWheel", OnMouseWheel)
        if self.EnableGamePadButton then
            self:EnableGamePadButton(true)
            self:SetScript("OnGamePadButtonDown", OnGamePadButtonDown)
        end
        UpdateBind()
    end
end

local function OpenWindow()
    if SettingsPanel and SettingsPanel:IsShown() then
        if SettingsPanel.Close then SettingsPanel:Close(true) else HideUIPanel(SettingsPanel) end
    end
    if not (ns.UI.Frame() and ns.UI.Frame():IsShown()) then ns.UI.Toggle() end
end

-- The switch follows the setting (also changed by /wildgear minimap and Settings).
function O.Refresh()
    if check then check:SetChecked(ns.Minimap.Shown()) end
    UpdateBind()
end

local function Create()
    local frame = CreateFrame("Frame")
    frame:Hide()

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    title:SetText("WildGear")
    local version = C_AddOns and C_AddOns.GetAddOnMetadata("WildSpark", "X-WildGear-Version")
    if version and not version:find("^@") then -- (a dev copy's TOC keeps v1.3.5; packaging fills it in)
        local v = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        v:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
        v:SetText(version)
    end

    local open = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    open:SetText(L["Open the window"])
    local text = open:GetFontString()
    open:SetSize(math.max(160, (text and text:GetStringWidth() or 0) + 32), 24)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    open:SetScript("OnClick", OpenWindow)

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    hint:SetPoint("LEFT", open, "RIGHT", 12, 0)
    hint:SetText(L["or type /wildgear"])

    check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -3, -14)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 1)
    label:SetText(L["Minimap button"])
    check:SetScript("OnClick", function(self)
        if self:GetChecked() then ns.db.minimapButton = nil else ns.db.minimapButton = false end
        ns.Minimap.Refresh()
        ns.Settings.Update() -- (its Shown on switch, while that panel is open)
    end)

    local bindLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    bindLabel:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 3, -16)
    bindLabel:SetText(L["Key binding"])
    bind = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    bind:SetSize(160, 24)
    bind:SetPoint("LEFT", bindLabel, "RIGHT", 12, 0)
    bind:RegisterForClicks("LeftButtonUp")
    bind:SetScript("OnClick", OnBindClick)
    bind:HookScript("OnMouseDown", OnMouseDown) -- (any mouse button, while capturing)
    -- (A gamepad has no Esc: moving the cursor off the button cancels too.)
    bind:HookScript("OnLeave", function() if capturing then StopCapture() end end)
    clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetText(L["Clear"])
    local clearText = clear:GetFontString()
    clear:SetSize(math.max(70, (clearText and clearText:GetStringWidth() or 0) + 24), 24)
    clear:SetPoint("LEFT", bind, "RIGHT", 6, 0)
    clear:SetScript("OnClick", function()
        SetKey(nil)
        UpdateBind()
    end)
    bindHint = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    bindHint:SetPoint("LEFT", bind, "RIGHT", 12, 0)
    bindHint:SetText(L["Esc cancels"])

    frame:SetScript("OnShow", O.Refresh)
    frame:SetScript("OnHide", function() if capturing then StopCapture() end end)
    O.category = Settings.RegisterCanvasLayoutCategory(frame, "WildGear")
    Settings.RegisterAddOnCategory(O.category)
end

-- Whether Open can show this page (What's new's Try it now).
function O.CanOpen()
    return O.category ~= nil and Settings.OpenToCategory ~= nil and not InCombatLockdown()
end

-- Opens the game's Options on this page.
function O.Open()
    if not O.CanOpen() then return end
    Settings.OpenToCategory(O.category.GetID and O.category:GetID() or O.category)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_BINDINGS") -- (also set under Options > Keybindings)
loader:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_BINDINGS" then
        if not capturing then UpdateBind() end
    elseif Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Create()
    end
end)
