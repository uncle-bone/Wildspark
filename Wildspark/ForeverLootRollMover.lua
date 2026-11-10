-- ForeverLootRollMover 1.2.10 - WoW Forever 1.60.1 / Interface 16001
-- Edit Mode is the only way to move either frame. Both previews use the
-- actual Blizzard XML templates; real loot frames remain untouched.
-- Built from the working 1.2.6 positioning path; saved positions are preserved.

local ADDON_NAME = ...
local ADDON_VERSION = "1.2.10"

ForeverLootRollMoverDB = ForeverLootRollMoverDB or {}

local defaults = {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -170,
    locked = true, spacing = 4, scale = 1.0,
    popupCustom = false, popupPoint = "CENTER", popupRelativePoint = "CENTER",
    popupX = 0, popupY = 0,
}
local MIN_SCALE, MAX_SCALE = 0.70, 1.40
local MIN_SPACING, MAX_SPACING = 0, 24
local MAX_LOOT_FRAMES = 8
local editModeActive = false
local editModeReady = false

local function Print(s)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ForeverLootRollMover|r: " .. tostring(s))
    end
end

local function Finite(value, fallback)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return fallback
    end
    return value
end

local function Clamp(value, minimum, maximum, fallback)
    return math.max(minimum, math.min(maximum, Finite(value, fallback)))
end

local validPoints = {
    CENTER=true, TOP=true, BOTTOM=true, LEFT=true, RIGHT=true,
    TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true,
}

local function InitDB()
    if type(ForeverLootRollMoverDB) ~= "table" then ForeverLootRollMoverDB = {} end
    local db = ForeverLootRollMoverDB
    for k, value in pairs(defaults) do
        if db[k] == nil then db[k] = value end
    end
    db.scale = Clamp(db.scale, MIN_SCALE, MAX_SCALE, defaults.scale)
    db.spacing = Clamp(db.spacing, MIN_SPACING, MAX_SPACING, defaults.spacing)
    for _, key in ipairs({"point", "relativePoint", "popupPoint", "popupRelativePoint"}) do
        if not validPoints[db[key]] then db[key] = defaults[key] end
    end
    for _, key in ipairs({"x", "y", "popupX", "popupY"}) do
        db[key] = Finite(db[key], defaults[key])
    end
    if type(db.popupCustom) ~= "boolean" then db.popupCustom = false end
    -- Legacy unlock state is intentionally discarded: only Edit Mode can drag.
    db.locked = true
end

-- The two HUD movers are invisible input anchors, not substitute skins.
-- Previews draw the actual Blizzard textures and atlases using FrameXML
-- sizes and offsets; they never depend on hidden XML template instances.
local function Text(parent, value, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetText(value)
    return fs
end

local function CreateMover(name, width, height, heading)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    local title = Text(frame, heading .. " - Drag to move", "GameFontNormal")
    title:SetPoint("BOTTOM", frame, "TOP", 0, height > 60 and 16 or 5)
    return frame
end

-- Keep mover sizes unchanged from 1.2.8 so existing saved positions retain
-- the exact TOPLEFT (roll) / CENTER (toast) they already had in-game.
local anchor = CreateMover("ForeverLootRollMoverAnchor", 335, 38, "Loot Roll")
local popupAnchor = CreateMover("ForeverLootRollMoverPopupAnchor", 340, 76, "Loot Received Popup")
local rollPreview = nil
local popupPreview = nil

-- Edit Mode artwork: reproduce the game's exact GroupLootFrameTemplate and
-- LootWonAlertFrameTemplate layout using the same Blizzard textures/atlases.
-- Never instantiate a hidden XML alert or roll template: on Forever 70790 the
-- inherited models can stay invisible and some template aliases are absent.
-- These purely visual examples have no rollID, event handlers or loot buttons.
local function SkinTexture(parent, layer, path, width, height, point, relative, relativePoint, x, y, texCoords)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(path)
    if width and height then texture:SetSize(width, height) end
    if point then texture:SetPoint(point, relative or parent, relativePoint or point, x or 0, y or 0) end
    if texCoords then texture:SetTexCoord(unpack(texCoords)) end
    return texture
end

local function AtlasTexture(parent, layer, atlas, width, height, point, relative, relativePoint, x, y)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    if texture.SetAtlas then texture:SetAtlas(atlas, false) end
    if width and height then texture:SetSize(width, height) end
    if point then texture:SetPoint(point, relative or parent, relativePoint or point, x or 0, y or 0) end
    return texture
end

local function CosmeticText(parent, value, font, width, height, point, relative, relativePoint, x, y)
    local text = Text(parent, value, font)
    if width and height then text:SetSize(width, height) end
    text:SetPoint(point, relative or parent, relativePoint or point, x or 0, y or 0)
    return text
end

local function CreateRollPreview()
    -- 277x67 is exactly the native GroupLootFrameTemplate size in Forever's
    -- Mainline-family FrameXML; texture coordinates and offsets match its XML.
    local frame = CreateFrame("Frame", nil, anchor)
    frame:SetSize(277, 67)
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    SkinTexture(frame, "BACKGROUND", "Interface\\LootFrame\\LootToast", 277, 67,
        "CENTER", frame, "CENTER", 0, 0,
        {0.28222656, 0.55273438, 0.30859375, 0.57031250})
    local border = SkinTexture(frame, "BORDER", "Interface\\LootFrame\\LootToast", 286, 76,
        "CENTER", frame, "CENTER", 0, 0,
        {0.00097656, 0.28027344, 0.43750000, 0.73437500})
    border:SetVertexColor(0.25, 0.95, 0.25, 1)

    local name = CosmeticText(frame, "Test Loot", "GameFontNormal", 125, 30,
        "TOPLEFT", frame, "TOPLEFT", 60, -15)
    if name.SetJustifyH then name:SetJustifyH("LEFT") end
    local icon = SkinTexture(frame, "ARTWORK", "Interface\\Icons\\INV_Chest_Chain_05",
        34, 34, "TOPLEFT", frame, "TOPLEFT", 10, -13)
    AtlasTexture(frame, "OVERLAY", "loottoast-itemborder-green", 42, 42,
        "CENTER", icon, "CENTER", 0, 0)

    local need = AtlasTexture(frame, "ARTWORK", "lootroll-toast-icon-need-up", 32, 32,
        "TOPRIGHT", frame, "TOPRIGHT", -44, -6)
    AtlasTexture(frame, "ARTWORK", "lootroll-toast-icon-pass-up", 32, 32,
        "LEFT", need, "RIGHT", 6, 2)
    AtlasTexture(frame, "ARTWORK", "lootroll-toast-icon-greed-up", 32, 32,
        "TOP", need, "BOTTOM", 0, 5)

    local timer = CreateFrame("StatusBar", nil, frame)
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 2)
    SkinTexture(timer, "BACKGROUND", "Interface\\Buttons\\WHITE8X8", 190, 8,
        "CENTER", timer, "CENTER", 0, 0):SetVertexColor(0, 0, 0, 0.95)
    timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    timer:SetStatusBarColor(1, 1, 0, 1)
    timer:SetMinMaxValues(0, 100)
    timer:SetValue(70)
    return frame
end

local function CreateReceivedPreview()
    -- Reuses the genuine LootWonAlertFrameTemplate skin, with its precise
    -- 276x96 background texture region and LootItemExtended icon placement.
    local frame = CreateFrame("Frame", nil, popupAnchor)
    frame:SetSize(276, 96)
    frame:SetPoint("CENTER", popupAnchor, "CENTER", 0, 0)
    SkinTexture(frame, "BACKGROUND", "Interface\\LootFrame\\LootToast", 276, 96,
        "CENTER", frame, "CENTER", 0, 0,
        {0.28222656, 0.55175781, 0.57812500, 0.95312500})
    local icon = SkinTexture(frame, "BORDER", "Interface\\Icons\\INV_Misc_Bag_10",
        52, 52, "TOPLEFT", frame, "TOPLEFT", 22, -23)
    AtlasTexture(frame, "ARTWORK", "loottoast-itemborder-green", 64, 64,
        "CENTER", icon, "CENTER", 0, 0)
    CosmeticText(frame, "You received", "GameFontNormal", 167, 16,
        "TOPLEFT", icon, "TOPRIGHT", 7, 0)
    local name = CosmeticText(frame, "Example item", "GameFontNormalMed3", 167, 33,
        "TOPLEFT", icon, "TOPRIGHT", 10, -19)
    if name.SetJustifyH then name:SetJustifyH("LEFT") end
    if name.SetTextColor then name:SetTextColor(0.12, 1.0, 0.12) end
    SkinTexture(frame, "ARTWORK", "Interface\\Buttons\\UI-GroupLoot-Dice-Up", 22, 22,
        "TOPRIGHT", frame, "TOPRIGHT", -20, -18)
    return frame
end

local function EnablePreviewDragging(preview, mover, onStop)
    preview:EnableMouse(true)
    preview:RegisterForDrag("LeftButton")
    preview:SetScript("OnDragStart", function()
        if editModeActive then mover:StartMoving() end
    end)
    preview:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        if editModeActive then onStop() end
    end)
end

local PositionAnchor, PositionPopupAnchor, PositionLootFrames, PositionLootWonAlerts

local function EnsureNativePreviews()
    if not rollPreview then
        rollPreview = CreateRollPreview()
        EnablePreviewDragging(rollPreview, anchor, function()
            local point, _, relative, x, y = anchor:GetPoint(1)
            if point then
                local db = ForeverLootRollMoverDB
                db.point, db.relativePoint, db.x, db.y = point, relative or point, x, y
            end
            PositionAnchor()
            PositionLootFrames()
        end)
    end
    if not popupPreview then
        popupPreview = CreateReceivedPreview()
        EnablePreviewDragging(popupPreview, popupAnchor, function()
            local x, y = popupAnchor:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if x and y and ux and uy then
                local db = ForeverLootRollMoverDB
                db.popupPoint, db.popupRelativePoint = "CENTER", "CENTER"
                db.popupX, db.popupY = x - ux, y - uy
                db.popupCustom = true
            end
            PositionPopupAnchor()
            PositionLootWonAlerts()
        end)
    end
    -- Both previews are visible whenever their Edit Mode anchor is shown.
    -- No hidden template, loot event, item cache or animation is needed.
    rollPreview:SetScale(ForeverLootRollMoverDB.scale or 1)
    rollPreview:SetAlpha(1)
    popupPreview:SetAlpha(1)
    rollPreview:Show()
    popupPreview:Show()
end

PositionAnchor = function()
    local db = ForeverLootRollMoverDB
    anchor:ClearAllPoints()
    anchor:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

PositionPopupAnchor = function()
    local db = ForeverLootRollMoverDB
    popupAnchor:ClearAllPoints()
    if db.popupCustom then
        popupAnchor:SetPoint(db.popupPoint, UIParent, db.popupRelativePoint, db.popupX, db.popupY)
    else
        -- Legacy installs without a chosen popup location keep the native
        -- default until the user moves the simulated alert in Edit Mode.
        if AlertFrame and AlertFrame.GetCenter then
            local x, y = AlertFrame:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if x and y and ux and uy then
                popupAnchor:SetPoint("CENTER", UIParent, "CENTER", x - ux, y - uy)
                return
            end
        end
        popupAnchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 165)
    end
end

local function SaveRollPosition()
    local point, _, relative, x, y = anchor:GetPoint(1)
    if point then
        ForeverLootRollMoverDB.point = point
        ForeverLootRollMoverDB.relativePoint = relative or point
        ForeverLootRollMoverDB.x = Finite(x, defaults.x)
        ForeverLootRollMoverDB.y = Finite(y, defaults.y)
    end
end

local function SavePopupPosition()
    local x, y = popupAnchor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not x or not y or not ux or not uy then return end
    local db = ForeverLootRollMoverDB
    db.popupPoint, db.popupRelativePoint = "CENTER", "CENTER"
    db.popupX, db.popupY = x - ux, y - uy
    db.popupCustom = true
end

-- Original 1.2.6 group-loot positioning; real frames are never repurposed
-- for previews (the latter are separate Blizzard-template instances).
local positioning = false
local function GetLootFrame(i)
    return _G["GroupLootFrame" .. i]
end
PositionLootFrames = function()
    if positioning then return end
    positioning = true
    local previous
    local scale, spacing = ForeverLootRollMoverDB.scale, ForeverLootRollMoverDB.spacing
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        if frame then
            if frame.SetScale then frame:SetScale(scale) end
            frame:ClearAllPoints()
            if not previous or not frame:IsShown() then
                frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            else
                frame:SetPoint("TOP", previous, "BOTTOM", 0, -spacing)
            end
            if frame:IsShown() then previous = frame end
        end
    end
    positioning = false
end

-- The 1.2.6 bug: moving only named LootWonAlertFrame instances misses
-- Forever's AlertFrame / newer alert-system host. Handle the host as well,
-- without creating, hiding, replacing or reskinning a genuine alert.
local popupPositioning = false
local hostPositioning = false
local savedHostPoint = nil
local hostHookInstalled = false
local function CanMove(frame)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown()
       and frame.IsProtected and frame:IsProtected() then return false end
    return true
end

local function PositionAlertHost()
    if hostPositioning or not ForeverLootRollMoverDB.popupCustom then return end
    local host = AlertFrame
    if not CanMove(host) then return end
    if not savedHostPoint then
        local point, relativeTo, relativePoint, x, y = host:GetPoint(1)
        if point then savedHostPoint = {point, relativeTo, relativePoint, x, y} end
    end
    local _, relativeTo, relativePoint = host:GetPoint(1)
    if relativeTo == popupAnchor and relativePoint == "CENTER" then return end
    hostPositioning = true
    host:ClearAllPoints()
    -- AlertFrame is the shared toast container. This also allows currently
    -- anonymous loot alert frames to follow the chosen HUD anchor.
    host:SetPoint("CENTER", popupAnchor, "CENTER", 0, 0)
    hostPositioning = false
end

local function GetLootWonFrames()
    local frames, seen = {}, {}
    local function Add(frame)
        if frame and frame.IsShown and not seen[frame] then
            frames[#frames+1] = frame
            seen[frame] = true
        end
    end
    if type(LOOT_WON_ALERT_FRAMES) == "table" then
        for _, frame in ipairs(LOOT_WON_ALERT_FRAMES) do Add(frame) end
    end
    for i = 1, 10 do Add(_G["LootWonAlertFrame" .. i]) end
    return frames
end

PositionLootWonAlerts = function()
    if popupPositioning or not ForeverLootRollMoverDB.popupCustom then return end
    PositionAlertHost()
    popupPositioning = true
    local previous
    for _, frame in ipairs(GetLootWonFrames()) do
        if frame:IsShown() and not frame.__ForeverLootRollMoverPreview and CanMove(frame) then
            frame:ClearAllPoints()
            if not previous then
                frame:SetPoint("CENTER", popupAnchor, "CENTER", 0, 0)
            else
                frame:SetPoint("BOTTOM", previous, "TOP", 0, 10)
            end
            previous = frame
        end
    end
    popupPositioning = false
end

local function PositionAll()
    PositionLootFrames()
    PositionLootWonAlerts()
end

anchor:SetScript("OnDragStart", function(self)
    if editModeActive then self:StartMoving() end
end)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not editModeActive then return end
    SaveRollPosition()
    PositionAnchor()
    PositionLootFrames()
end)

popupAnchor:SetScript("OnDragStart", function(self)
    if editModeActive then self:StartMoving() end
end)
popupAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not editModeActive then return end
    SavePopupPosition()
    PositionPopupAnchor()
    PositionLootWonAlerts()
end)

local hookRoll = false
local hookFix = false
local hookPopupAnchor = false
local hookPopupShow = false

local function HookLootFrames()
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        if frame and not frame.__ForeverLootRollMoverFrameHooked then
            frame.__ForeverLootRollMoverFrameHooked = true
            if frame.HookScript then
                frame:HookScript("OnShow", function() PositionLootFrames() end)
                frame:HookScript("OnHide", function() PositionLootFrames() end)
            end
        end
        if frame then
            local n = frame:GetName()
            for _, key in ipairs({"NeedButton", "GreedButton", "PassButton", "DisenchantButton"}) do
                local button = (n and _G[n .. key]) or nil
                if button and button.HookScript and not button.__ForeverLootRollMoverHooked then
                    button.__ForeverLootRollMoverHooked = true
                    button:HookScript("OnClick", function() PositionLootFrames() end)
                end
            end
        end
    end
end

local function InstallGlobalHooks()
    if not hooksecurefunc then return end
    if not hookFix and type(AlertFrame_FixAnchors) == "function" then
        hooksecurefunc("AlertFrame_FixAnchors", function()
            PositionLootFrames()
            PositionLootWonAlerts()
        end)
        hookFix = true
    end
    if not hookRoll and type(GroupLootFrame_OpenNewFrame) == "function" then
        hooksecurefunc("GroupLootFrame_OpenNewFrame", PositionLootFrames)
        hookRoll = true
    end
    if not hookPopupAnchor and type(AlertFrame_SetLootWonAnchors) == "function" then
        hooksecurefunc("AlertFrame_SetLootWonAnchors", PositionLootWonAlerts)
        hookPopupAnchor = true
    end
    if not hookPopupShow and type(LootWonAlertFrame_ShowAlert) == "function" then
        hooksecurefunc("LootWonAlertFrame_ShowAlert", PositionLootWonAlerts)
        hookPopupShow = true
    end
    if not hostHookInstalled and AlertFrame and type(hooksecurefunc) == "function" then
        -- Reassert the user's Edit Mode position when Blizzard reanchors the
        -- alert host. The recursion guard ensures our own SetPoint is ignored.
        hooksecurefunc(AlertFrame, "SetPoint", function()
            if not hostPositioning then PositionAlertHost() end
        end)
        hostHookInstalled = true
    end
end

local function UpdateEditMode()
    if not editModeReady then return end
    local manager = EditModeManagerFrame
    local active = manager and manager.IsShown and manager:IsShown() and true or false
    if active == editModeActive then return end
    editModeActive = active
    if active then
        PositionAnchor()
        PositionPopupAnchor()
        EnsureNativePreviews()
        anchor:Show()
        popupAnchor:Show()
    else
        -- Only the editor draws the simulated loot and received-popup frames.
        anchor:Hide()
        popupAnchor:Hide()
        PositionAll()
    end
end

SLASH_FOREVERLOOTROLLMOVER1 = "/flrm"
SLASH_FOREVERLOOTROLLMOVER2 = "/lootmove"
SLASH_FOREVERLOOTROLLMOVER3 = "/lootrollmove"
SlashCmdList["FOREVERLOOTROLLMOVER"] = function(message)
    local command, argument = tostring(message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "scale" then
        local value = tonumber(argument)
        if not value then Print("usage: /flrm scale 0.70-1.40") return end
        ForeverLootRollMoverDB.scale = Clamp(value, MIN_SCALE, MAX_SCALE, 1)
        if rollPreview then rollPreview:SetScale(ForeverLootRollMoverDB.scale) end
        PositionLootFrames()
        Print("roll scale: " .. string.format("%.2f", ForeverLootRollMoverDB.scale))
    elseif command == "spacing" or command == "space" then
        local value = tonumber(argument)
        if not value then Print("usage: /flrm spacing 0-24") return end
        ForeverLootRollMoverDB.spacing = math.floor(Clamp(value, MIN_SPACING, MAX_SPACING, 4) + 0.5)
        PositionLootFrames()
        Print("roll spacing: " .. ForeverLootRollMoverDB.spacing)
    elseif command == "status" then
        Print("v" .. ADDON_VERSION .. "; move both previews only in Esc > Edit Mode; popup " ..
            (ForeverLootRollMoverDB.popupCustom and "custom" or "native") .. "; roll scale " ..
            string.format("%.2f", ForeverLootRollMoverDB.scale) .. "; spacing " .. ForeverLootRollMoverDB.spacing)
    else
        -- Legacy /unlock, /lock, /popup move, /test and Alt-drag movement were
        -- intentionally retired to leave Edit Mode as the single entry point.
        Print("To move either loot frame, open Esc > Edit Mode. Both simulated frames are draggable there.")
        Print("Options: /flrm scale 0.70-1.40, /flrm spacing 0-24, /flrm status")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("START_LOOT_ROLL")
eventFrame:RegisterEvent("CANCEL_LOOT_ROLL")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON_NAME then
        InitDB()
        editModeReady = true
        PositionAnchor()
        PositionPopupAnchor()
        HookLootFrames()
        InstallGlobalHooks()
        PositionAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookLootFrames()
        InstallGlobalHooks()
        PositionAll()
    elseif event == "START_LOOT_ROLL" or event == "CANCEL_LOOT_ROLL" then
        PositionLootFrames()
    elseif event == "PLAYER_REGEN_ENABLED" then
        PositionAll()
    end
end)

local elapsed = 0
local periodic = 0
eventFrame:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    periodic = periodic + delta
    if elapsed >= 0.12 then
        elapsed = 0
        UpdateEditMode()
    end
    if periodic >= 0.35 then
        periodic = 0
        HookLootFrames()
        InstallGlobalHooks()
        -- Blizzard can add alert frames dynamically or reset their position
        -- after the loot-won event. Reanchor while the custom setting is on.
        if ForeverLootRollMoverDB.popupCustom then PositionLootWonAlerts() end
        if not editModeActive then PositionLootFrames() end
    end
end)