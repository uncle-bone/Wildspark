-- WildRolls 1.3.4 - WoW Forever 1.60.1 / Interface 16001
-- Native loot windows support Alt+drag through frame-independent cursor polling.
-- Edit Mode, the controller loot UI and Blizzard native roll actions remain intact.
-- Built from the working 1.2.6 positioning path; saved positions are preserved.

local ADDON_NAME, root = ...
local MOD = root.WildLootRolls or {}
root.WildLootRolls = MOD
_G.WildLootRolls = MOD
local ADDON_VERSION = "1.3.4"

WildLootRollDB = WildLootRollDB or {}

local defaults = {
    enabled = true, point = "CENTER", relativePoint = "CENTER", x = 0, y = -170,
    locked = true, spacing = 4, scale = 1.0, showVoteCounts = true,
    showEditPreviews = true, showReceivedPreview = true, previewCount = 3, stackUpwards = false,
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
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WildRolls|r: " .. tostring(s))
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
    if type(WildLootRollDB) ~= "table" then WildLootRollDB = {} end
    local db = WildLootRollDB
    if db.placement ~= nil and db.schemaVersion == nil then
        -- Old WildRolls spacing was a full frame-to-frame distance (100 by default);
        -- the new schema stores only the gap between native 67-pixel frames.
        db.spacing = math.max(0, math.min(24, (tonumber(db.spacing) or 100) - 67))
        db.schemaVersion = 2
    end
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
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.showVoteCounts) ~= "boolean" then db.showVoteCounts = true end
    if type(db.showEditPreviews) ~= "boolean" then db.showEditPreviews = true end
    if type(db.showReceivedPreview) ~= "boolean" then db.showReceivedPreview = true end
    if type(db.stackUpwards) ~= "boolean" then db.stackUpwards = false end
    db.previewCount = math.floor(Clamp(db.previewCount, 1, 5, defaults.previewCount) + 0.5)
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
    frame.dragTitle = title
    return frame
end

-- Keep mover sizes unchanged from 1.2.8 so existing saved positions retain
-- the exact TOPLEFT (roll) / CENTER (toast) they already had in-game.
local anchor = CreateMover("WildRollsAnchor", 335, 38, "Loot Roll")
local popupAnchor = CreateMover("WildRollsPopupAnchor", 340, 76, "Loot Received Popup")
local rollPreview = nil
local rollPreviews = {}
local popupPreview = nil
local RefreshPreviewLayout
local SelectEditFrame -- Native-like selection: click a preview to open its settings.

-- Blizzard positions the FIRST queued loot alert with its BOTTOM 10 units
-- above AlertFrame's TOP. AlertFrame is 10 high and LootWonAlertFrame is 96
-- high: the real toast CENTER is 5 + 10 + 48 = 63 units ABOVE the host center.
-- Both the cosmetic preview and its Edit Mode selection must share that exact
-- offset. The popupAnchor represents the native host, not the toast itself.
-- This preserves Blizzard's own notification stacking and saved host anchors.
local RECEIVED_TOAST_CENTER_OFFSET_Y = 63

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
    local pass = AtlasTexture(frame, "ARTWORK", "lootroll-toast-icon-pass-up", 32, 32,
        "LEFT", need, "RIGHT", 6, 2)
    local greed = AtlasTexture(frame, "ARTWORK", "lootroll-toast-icon-greed-up", 32, 32,
        "TOP", need, "BOTTOM", 0, 5)
    local needCount = CosmeticText(frame, "2", "GameFontNormalSmall", 14, 12,
        "LEFT", need, "RIGHT", 1, 0)
    if needCount.SetJustifyH then needCount:SetJustifyH("LEFT") end
    local greedCount = CosmeticText(frame, "4", "GameFontNormalSmall", 14, 12,
        "LEFT", greed, "RIGHT", 1, 0)
    if greedCount.SetJustifyH then greedCount:SetJustifyH("LEFT") end

    local timer = CreateFrame("StatusBar", nil, frame)
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, 2)
    SkinTexture(timer, "BACKGROUND", "Interface\\Buttons\\WHITE8X8", 190, 8,
        "CENTER", timer, "CENTER", 0, 0):SetVertexColor(0, 0, 0, 0.95)
    timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    timer:SetStatusBarColor(1, 1, 0, 1)
    timer:SetMinMaxValues(0, 100)
    timer:SetValue(70)
    frame.needCount = needCount
    frame.greedCount = greedCount
    frame.itemName = name
    return frame
end

local function CreateReceivedPreview()
    -- Reuses the genuine LootWonAlertFrameTemplate skin, with its precise
    -- 276x96 background texture region and LootItemExtended icon placement.
    local frame = CreateFrame("Frame", nil, popupAnchor)
    frame:SetSize(276, 96)
    frame:SetPoint("CENTER", popupAnchor, "CENTER", 0, RECEIVED_TOAST_CENTER_OFFSET_Y)
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
    -- Selecting and dragging are separate, just like Blizzard Edit Mode.
    -- MouseDown selects immediately, while a real drag still moves the anchor.
    preview:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and editModeActive and SelectEditFrame then
            SelectEditFrame(mover == anchor and "roll" or "received")
        end
    end)
    preview:SetScript("OnDragStart", function()
        if editModeActive then mover:StartMoving() end
    end)
    preview:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        if editModeActive then onStop() end
    end)
end

local PositionAnchor, PositionPopupAnchor, PositionLootFrames, PositionLootWonAlerts, PositionGamepadLoot

local function EnsureNativePreviews()
    if not rollPreview then
        rollPreview = CreateRollPreview()
        EnablePreviewDragging(rollPreview, anchor, function()
            local point, _, relative, x, y = anchor:GetPoint(1)
            if point then
                local db = WildLootRollDB
                db.point, db.relativePoint, db.x, db.y = point, relative or point, x, y
            end
            PositionAnchor()
            PositionLootFrames()
            PositionGamepadLoot()
        end)
    end
    if not popupPreview then
        popupPreview = CreateReceivedPreview()
        EnablePreviewDragging(popupPreview, popupAnchor, function()
            local x, y = popupAnchor:GetCenter()
            local ux, uy = UIParent:GetCenter()
            if x and y and ux and uy then
                local db = WildLootRollDB
                db.popupPoint, db.popupRelativePoint = "CENTER", "CENTER"
                db.popupX, db.popupY = x - ux, y - uy
                db.popupCustom = true
            end
            PositionPopupAnchor()
            PositionLootWonAlerts()
        end)
    end
    -- Additional visual-only rolls reuse the same artwork, with no rollID or loot actions.
    local count = WildLootRollDB.previewCount or 3
    for i = 2, count do
        if not rollPreviews[i] then
            local extra = CreateRollPreview()
            rollPreviews[i] = extra
            EnablePreviewDragging(extra, anchor, function()
                local point, _, relative, x, y = anchor:GetPoint(1)
                if point then
                    local db = WildLootRollDB
                    db.point, db.relativePoint = point, relative or point
                    db.x, db.y = Finite(x, defaults.x), Finite(y, defaults.y)
                end
                PositionAnchor()
                PositionLootFrames()
                PositionGamepadLoot()
            end)
        end
    end
    rollPreviews[1] = rollPreview
    if RefreshPreviewLayout then RefreshPreviewLayout() end
    -- The received-item sample is independent of the Loot Roll preview toggle.
    -- Never hide or otherwise touch real Blizzard LootWonAlertFrame windows.
    popupPreview:SetAlpha(1)
    popupPreview:SetShown(editModeActive and WildLootRollDB.showReceivedPreview)
end

RefreshPreviewLayout = function()
    if not WildLootRollDB then return end
    local db = WildLootRollDB
    local count, scale = db.previewCount or 3, db.scale or 1
    local step = 67 * scale + (db.spacing or 4)
    local direction = db.stackUpwards and 1 or -1
    for index, preview in ipairs(rollPreviews) do
        preview:SetScale(scale)
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, (index - 1) * step * direction)
        if preview.itemName then preview.itemName:SetText("Test Loot " .. index) end
        if preview.needCount then preview.needCount:SetShown(db.showVoteCounts) end
        if preview.greedCount then preview.greedCount:SetShown(db.showVoteCounts) end
        preview:SetShown(editModeActive and db.showEditPreviews and index <= count)
    end
end

-- Recover inaccessible saved anchors (e.g. after resolution/UI scale changes).
-- Keep valid positions and SavedVariables intact until the user moves a frame.
local function RecoverOffscreen(mover, topOffset, bottomOffset, width)
    local left, right = mover:GetLeft(), mover:GetRight()
    local top, bottom = mover:GetTop(), mover:GetBottom()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not (left and right and top and bottom and sw and sh and sw > 0 and sh > 0) then return end
    local visibleLeft = width and (left + right - width) / 2 or left
    local visibleRight = width and (left + right + width) / 2 or right
    if visibleRight < 24 or visibleLeft > sw - 24 or top + topOffset < 24 or bottom + bottomOffset > sh - 24 then
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

PositionAnchor = function()
    local db = WildLootRollDB
    anchor:ClearAllPoints()
    anchor:SetPoint(db.point, UIParent, db.relativePoint, db.x, db.y)
end

PositionPopupAnchor = function()
    local db = WildLootRollDB
    popupAnchor:ClearAllPoints()
    if db.popupCustom then
        popupAnchor:SetPoint(db.popupPoint, UIParent, db.popupRelativePoint, db.popupX, db.popupY)
        RecoverOffscreen(popupAnchor, RECEIVED_TOAST_CENTER_OFFSET_Y + 10, RECEIVED_TOAST_CENTER_OFFSET_Y - 10, 276)
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
        WildLootRollDB.point = point
        WildLootRollDB.relativePoint = relative or point
        WildLootRollDB.x = Finite(x, defaults.x)
        WildLootRollDB.y = Finite(y, defaults.y)
    end
end

local function SavePopupPosition()
    local x, y = popupAnchor:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not x or not y or not ux or not uy then return end
    local db = WildLootRollDB
    db.popupPoint, db.popupRelativePoint = "CENTER", "CENTER"
    db.popupX, db.popupY = x - ux, y - uy
    db.popupCustom = true
end

-- Keep loot windows in stable slots even if Blizzard recycles its native frames.
local positioning = false
local rollSlots = {}
local anonymousSlots = {}
local function GetLootFrame(i)
    return _G["GroupLootFrame" .. i]
end
local function CanPositionLootFrame(frame)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown()
        and frame.IsProtected and frame:IsProtected() then return false end
    return true
end
local function CurrentRollKey(frame)
    if frame.rollID ~= nil then return "roll:" .. tostring(frame.rollID) end
    return frame
end
PositionLootFrames = function()
    if positioning or not WildLootRollDB or WildLootRollDB.enabled == false then return end
    positioning = true
    local visible, active = {}, {}
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        if frame and frame.IsShown and frame:IsShown() then
            local key = CurrentRollKey(frame)
            visible[#visible + 1] = {frame = frame, key = key}
            active[key] = true
            -- Keep a temporary frame slot alive until its new roll ID can
            -- inherit it; otherwise it gets purged before the transfer.
            if type(key) == "string" and anonymousSlots[frame] then
                active[frame] = true
            end
        end
    end
    for key in pairs(rollSlots) do if not active[key] then rollSlots[key] = nil end end
    for key in pairs(anonymousSlots) do if not active[key] then anonymousSlots[key] = nil end end
    local occupied = {}
    for _, slot in pairs(rollSlots) do occupied[slot] = true end
    for _, slot in pairs(anonymousSlots) do occupied[slot] = true end
    for _, item in ipairs(visible) do
        local key = item.key
        local slots = type(key) == "string" and rollSlots or anonymousSlots
        if not slots[key] then
            local temporary = anonymousSlots[item.frame]
            if temporary and not occupied[temporary] then
                slots[key] = temporary
                anonymousSlots[item.frame] = nil
                occupied[temporary] = true
            elseif temporary and type(key) == "string" then
                -- Transfer the slot from an anonymous frame to its new rollID.
                slots[key] = temporary
                anonymousSlots[item.frame] = nil
                occupied[temporary] = true
            else
                for slot = 1, MAX_LOOT_FRAMES do
                    if not occupied[slot] then
                        slots[key], occupied[slot] = slot, true
                        break
                    end
                end
            end
        end
    end
    local scale = WildLootRollDB.scale or 1
    local spacing = WildLootRollDB.spacing or 4
    local direction = WildLootRollDB.stackUpwards and 1 or -1
    for _, item in ipairs(visible) do
        local frame, key = item.frame, item.key
        local slot = type(key) == "string" and rollSlots[key] or anonymousSlots[key]
        if slot and CanPositionLootFrame(frame) then
            if frame.SetScale and frame:GetScale() ~= scale then frame:SetScale(scale) end
            local frameHeight = frame.GetHeight and frame:GetHeight() or 67
            if not frameHeight or frameHeight <= 0 then frameHeight = 67 end
            local x, y = 0, direction * (slot - 1) * (frameHeight * scale + spacing)
            local point, relative, relativePoint, oldX, oldY = frame:GetPoint(1)
            if point ~= "TOPLEFT" or relative ~= anchor or relativePoint ~= "TOPLEFT"
                or oldX ~= x or oldY ~= y then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
            end
        end
    end
    positioning = false
end

-- Forever uses a separate native, scrollable loot roll window in Gamepad UI.
-- The keyboard's GroupLootFrame1..N are not displayed in that mode.
-- Both UI paths share the existing Edit Mode loot position and roll scale.
-- Never replace the controller's native window/buttons or its input handlers.
local gamepadPositioning = false
local gamepadFrameHooked = nil
local function IsGamepadLootMode()
    return InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function"
        and InputUtil.IsGamepadUIEnabled() == true
end

PositionGamepadLoot = function()
    if gamepadPositioning or not IsGamepadLootMode() or not WildLootRollDB or WildLootRollDB.enabled == false then return end
    local frame = _G.GamepadGroupLootRollFrame
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown()
        and frame.IsProtected and frame:IsProtected() then return end

    -- Check the current anchor so polling does not continuously disturb
    -- Blizzard's scroll list or its controller focus/selection state.
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    local scale = WildLootRollDB.scale or 1
    local atTarget = point == "TOPLEFT" and relative == anchor
        and relativePoint == "TOPLEFT" and x == 0 and y == 0
    if atTarget and (not frame.GetScale or frame:GetScale() == scale) then return end

    gamepadPositioning = true
    if frame.SetScale then frame:SetScale(scale) end
    if not atTarget then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    end
    gamepadPositioning = false
end

-- Standalone cosmetic preview for controller players. This must never
-- show the real GamepadGroupLootRollFrame: it owns live roll state and focus.
-- Toggle with /wildrolls testpad, independently of Edit Mode. The preview is
-- deliberately not clickable and cannot submit Need/Greed/Pass rolls.
local gamepadTestPreview
local RegisterGamepadTestSurface
local QueueRefresh, RefreshAltInput
local function EnsureGamepadTestPreview()
    if gamepadTestPreview then return gamepadTestPreview end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(305, 104)
    frame:SetFrameStrata("DIALOG")
    frame:SetScale(1)
    frame:EnableMouse(false)
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.055, 0.065, 0.08, 0.94)
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    border:SetHeight(2)
    border:SetColorTexture(0.7, 0.55, 0.24, 1)
    CosmeticText(frame, "Controller Loot Roll - TEST", "GameFontNormal", 270, 17,
        "TOPLEFT", frame, "TOPLEFT", 9, -7)
    SkinTexture(frame, "ARTWORK", "Interface\\Icons\\INV_Chest_Chain_05", 34, 34,
        "TOPLEFT", frame, "TOPLEFT", 11, -34)
    CosmeticText(frame, "Example item (visual preview)", "GameFontHighlightSmall", 235, 16,
        "TOPLEFT", frame, "TOPLEFT", 53, -35)
    CosmeticText(frame, "Need     Greed     Pass", "GameFontNormalSmall", 240, 18,
        "TOPLEFT", frame, "TOPLEFT", 53, -57)
    CosmeticText(frame, "No real roll or controller input", "GameFontDisableSmall", 275, 16,
        "BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
    frame:Hide()
    gamepadTestPreview = frame
    return frame
end

local function UpdateGamepadTestPreview()
    if not gamepadTestPreview or not gamepadTestPreview:IsShown() then return end
    gamepadTestPreview:SetScale(WildLootRollDB.scale or 1)
    -- Read the same saved Edit Mode anchor used by the real controller window.
    -- No repositioning of live Blizzard frames is performed by this preview.
    local point, relative, relpoint, x, y = gamepadTestPreview:GetPoint(1)
    if point ~= "TOPLEFT" or relative ~= anchor or relpoint ~= "TOPLEFT" or x ~= 0 or y ~= 0 then
        gamepadTestPreview:ClearAllPoints()
        gamepadTestPreview:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    end
end

local function ToggleGamepadTestPreview()
    local frame = EnsureGamepadTestPreview()
    if frame:IsShown() then
        frame:Hide()
        if RefreshAltInput then RefreshAltInput() end
        Print("controller preview hidden. /wildrolls testpad to show it again.")
        return
    end
    if editModeActive then
        Print("close Edit Mode before using /wildrolls testpad.")
        return
    end
    UpdateGamepadTestPreview()
    frame:Show()
    UpdateGamepadTestPreview()
    if RegisterGamepadTestSurface then RegisterGamepadTestSurface(frame) end
    if RefreshAltInput then RefreshAltInput() end
    Print("controller visual test shown at the Loot Roll Edit Mode position. /wildrolls testpad hides it.")
    if not IsGamepadLootMode() then
        Print("Gamepad UI is currently disabled. Enable it for a real controller-mode check.")
    end
    Print("This is a visual preview only; verify an actual group loot roll to confirm native Gamepad placement.")
end

local function HookGamepadLoot()
    local frame = _G.GamepadGroupLootRollFrame
    if not frame or frame == gamepadFrameHooked then return end
    gamepadFrameHooked = frame
    if frame.HookScript then
        frame:HookScript("OnShow", function() QueueRefresh(true, false, false); RefreshAltInput() end)
        frame:HookScript("OnHide", function() RefreshAltInput() end)
    end
    if type(hooksecurefunc) == "function" and frame.SetPoint then
        hooksecurefunc(frame, "SetPoint", function()
            if not gamepadPositioning then QueueRefresh(true, false, false) end
        end)
    end
    PositionGamepadLoot()
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
    if hostPositioning or not WildLootRollDB.enabled or not WildLootRollDB.popupCustom then return end
    local host = AlertFrame
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return end
    if not CanMove(host) then return end
    if not savedHostPoint then
        local point, relativeTo, relativePoint, x, y = host:GetPoint(1)
        if point then savedHostPoint = {point, relativeTo, relativePoint, x, y} end
    end
    local point, relativeTo, relativePoint, x, y = host:GetPoint(1)
    if point == "CENTER" and relativeTo == popupAnchor and relativePoint == "CENTER" and x == 0 and y == 0 then return end
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
    if not WildLootRollDB.enabled or not WildLootRollDB.popupCustom then return end
    -- AlertFrame manages the alert stack. Moving each child individually
    -- fights Blizzard's anchor updates and may move alerts off-screen.
    -- Leave every LootWonAlertFrame under Blizzard control.
    PositionAlertHost()
end

-- Forever 1.60.1 uses the encounter-based C_LootHistory API rather than
-- the obsolete C_LootHistory.GetItem/GetPlayerInfo pair. Match the native
-- roll's item link to an active history drop. Never fabricate a vote count.
local voteLabels = {}
local rollHistoryKeys = {}
local votes = {}

local function GetItemIdentity(link)
    if type(link) ~= "string" then return nil end
    -- Item links can differ in formatting while referring to the same item.
    return link:match("|Hitem:(%d+):") or link:match("item:(%d+):")
end

local function GetVoteButtons(frame)
    if not frame then return end
    local container = frame.LootButtonContainer
    local frameName = frame.GetName and frame:GetName() or nil
    local need = (container and container.NeedButton) or frame.NeedButton
        or (frameName and _G[frameName .. "NeedButton"])
    local greed = (container and container.GreedButton) or frame.GreedButton
        or (frameName and _G[frameName .. "GreedButton"])
    return need, greed
end

local function IsOpenDrop(drop)
    return type(drop) == "table" and not drop.winner and not drop.allPassed
        and type(drop.rollInfos) == "table"
end

local function CountDropVotes(drop)
    if not IsOpenDrop(drop) then return nil end
    local need, greed = 0, 0
    for _, player in ipairs(drop.rollInfos) do
        local state = type(player) == "table" and player.state or nil
        -- Forever: NeedMainSpec=0, NeedOffSpec=1, Greed=3.
        if state == 0 or state == 1 then
            need = need + 1
        elseif state == 3 then
            greed = greed + 1
        end
    end
    return {need = need, greed = greed}
end

local function ReadVoteHistory()
    local history = C_LootHistory
    votes = {}
    if not WildLootRollDB.showVoteCounts then return end
    if type(history) ~= "table" or type(history.GetAllEncounterInfos) ~= "function"
        or type(history.GetSortedDropsForEncounter) ~= "function" then return end
    if type(GetLootRollItemLink) ~= "function" then return end

    -- Build the list of visible rolls. Never assign one encounter drop to
    -- two simultaneously displayed rolls of the same item.
    local active = {}
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        if frame and frame.IsShown and frame:IsShown() and frame.rollID then
            local good, link = pcall(GetLootRollItemLink, frame.rollID)
            if good and GetItemIdentity(link) then
                active[#active + 1] = {rollID = frame.rollID, link = link,
                    itemID = GetItemIdentity(link)}
            end
        end
    end
    local activeIDs = {}
    for _, roll in ipairs(active) do activeIDs[roll.rollID] = true end
    for id in pairs(rollHistoryKeys) do if not activeIDs[id] then rollHistoryKeys[id] = nil end end
    if #active == 0 then return end
    local ok, encounters = pcall(history.GetAllEncounterInfos)
    if not ok or type(encounters) ~= "table" then return end

    local drops = {}
    for idx = 1, math.min(#encounters, 25) do
        local encounter = encounters[idx]
        if type(encounter) == "table" and type(encounter.encounterID) == "number" then
            local success, list = pcall(history.GetSortedDropsForEncounter, encounter.encounterID)
            if success and type(list) == "table" then
                for _, drop in ipairs(list) do
                    if IsOpenDrop(drop) and GetItemIdentity(drop.itemHyperlink) then
                        drops[#drops + 1] = {encounter = encounter.encounterID,
                            key = drop.lootListKey, itemID = GetItemIdentity(drop.itemHyperlink),
                            link = drop.itemHyperlink, startTime = drop.startTime or 0,
                            data = drop}
                    end
                end
            end
        end
    end

    local claimed = {}
    local function Assign(roll, candidate)
        if not candidate then return false end
        local key = tostring(candidate.encounter) .. ":" .. tostring(candidate.key)
        if claimed[key] then return false end
        local result = CountDropVotes(candidate.data)
        if not result then return false end
        claimed[key] = true
        rollHistoryKeys[roll.rollID] = key
        votes[roll.rollID] = result
        return true
    end
    -- Prefer cached mapping. A historic identical item must not steal a roll
    -- from a newer drop while both records remain in Blizzard's loot history.
    for _, roll in ipairs(active) do
        local cached = rollHistoryKeys[roll.rollID]
        if cached then
            for _, drop in ipairs(drops) do
                local key = tostring(drop.encounter) .. ":" .. tostring(drop.key)
                if key == cached and drop.itemID == roll.itemID then
                    Assign(roll, drop)
                    break
                end
            end
        end
    end
    for _, roll in ipairs(active) do
        if not votes[roll.rollID] then
            local best = nil
            for _, drop in ipairs(drops) do
                local key = tostring(drop.encounter) .. ":" .. tostring(drop.key)
                if not claimed[key] and drop.itemID == roll.itemID then
                    if not best or (drop.link == roll.link and best.link ~= roll.link)
                        or ((drop.link == roll.link) == (best.link == roll.link)
                            and drop.startTime > best.startTime) then
                        best = drop
                    end
                end
            end
            Assign(roll, best)
        end
    end
end

local function EnsureVoteLabel(button)
    if not button then return nil end
    if not button.__WildRollsVoteLabel then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Overlay the outer right edge, without covering the actual button.
        label:SetPoint("LEFT", button, "RIGHT", 1, 0)
        if label.SetJustifyH then label:SetJustifyH("LEFT") end
        if label.SetTextColor then label:SetTextColor(1, 0.84, 0.35, 1) end
        button.__WildRollsVoteLabel = label
    end
    return button.__WildRollsVoteLabel
end

local function HideVoteLabelSet(labels)
    if not labels then return end
    if labels.need then labels.need:Hide() end
    if labels.greed then labels.greed:Hide() end
end

local function UpdateVoteLabels()
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        local labels = voteLabels[i]
        if frame and frame.IsShown and frame:IsShown() then
            local count = WildLootRollDB.showVoteCounts and frame.rollID and votes[frame.rollID]
            local needButton, greedButton = GetVoteButtons(frame)
            if count and needButton and greedButton then
                if not labels then labels = {}; voteLabels[i] = labels end
                labels.need = EnsureVoteLabel(needButton)
                labels.greed = EnsureVoteLabel(greedButton)
                if labels.need then labels.need:SetText(tostring(count.need)); labels.need:Show() end
                if labels.greed then labels.greed:SetText(tostring(count.greed)); labels.greed:Show() end
            else
                HideVoteLabelSet(labels)
            end
        else
            HideVoteLabelSet(labels)
        end
    end
end

local function PositionAll()
    PositionLootFrames()
    PositionGamepadLoot()
    PositionLootWonAlerts()
end

anchor:SetScript("OnMouseDown", function(_, button)
    if editModeActive and button == "LeftButton" and SelectEditFrame then SelectEditFrame("roll") end
end)
popupAnchor:SetScript("OnMouseDown", function(_, button)
    if editModeActive and button == "LeftButton" and SelectEditFrame then SelectEditFrame("received") end
end)

anchor:SetScript("OnDragStart", function(self)
    if editModeActive then self:StartMoving() end
end)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not editModeActive then return end
    SaveRollPosition()
    PositionAnchor()
    PositionLootFrames()
    PositionGamepadLoot()
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

-- Hold Alt to enable a temporary, invisible mouse-capturing surface above
-- each shown native roll frame. This prevents the game-world camera from
-- receiving the drag's initial mouse-down. Without Alt, the surface is hidden
-- and all original Blizzard loot buttons remain fully clickable.
local altDragging = false
local dragCursorX, dragCursorY = nil, nil
local dragStartX, dragStartY = nil, nil
local dragPoint, dragRelativePoint = nil, nil
local dragDriver = CreateFrame("Frame")

local function StopAltDragging()
    if not altDragging then return end
    altDragging = false
    dragDriver:SetScript("OnUpdate", nil)
    dragCursorX, dragCursorY = nil, nil
    SaveRollPosition()
    PositionAnchor()
    PositionLootFrames()
    PositionGamepadLoot()
end

local function CanAltMove()
    if not WildLootRollDB or WildLootRollDB.enabled == false then return false end
    if editModeActive then return false end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        -- Avoid modifying native protected Blizzard roll frames in combat.
        return false
    end
    return type(GetCursorPosition) == "function"
        and type(IsAltKeyDown) == "function"
        and type(IsMouseButtonDown) == "function"
end

local function CursorOver(frame, cursorX, cursorY)
    if not frame or not frame.IsShown or not frame:IsShown() then return false end
    if frame.IsMouseOver and frame:IsMouseOver() then return true end
    -- The native window may have a child consuming mouse input; geometry
    -- fallback still recognizes the cursor inside the parent loot window.
    if not frame.GetLeft or not frame.GetRight or not frame.GetTop or not frame.GetBottom then return false end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    return left and right and top and bottom
        and cursorX >= left and cursorX <= right
        and cursorY >= bottom and cursorY <= top
end

local function IsCursorOverLoot(cursorX, cursorY)
    if gamepadTestPreview and CursorOver(gamepadTestPreview, cursorX, cursorY) then return true end
    local gamepad = _G.GamepadGroupLootRollFrame
    if gamepad and CursorOver(gamepad, cursorX, cursorY) then return true end
    for i = 1, MAX_LOOT_FRAMES do
        if CursorOver(GetLootFrame(i), cursorX, cursorY) then return true end
    end
    return false
end

local UpdateAltDrag
local function StartAltDragging(cursorX, cursorY)
    if not CanAltMove() or altDragging then return end
    local point, _, relativePoint, x, y = anchor:GetPoint(1)
    if not point then return end
    dragPoint, dragRelativePoint = point, relativePoint or point
    dragStartX, dragStartY = Finite(x, 0), Finite(y, 0)
    dragCursorX, dragCursorY = cursorX, cursorY
    altDragging = true
    dragDriver:SetScript("OnUpdate", function() UpdateAltDrag() end)
end

UpdateAltDrag = function()
    if not altDragging then return end
    if not CanAltMove() then
        StopAltDragging()
        return
    end
    local leftDown = IsMouseButtonDown("LeftButton") and true or false
    local altDown = IsAltKeyDown() and true or false
    local rawX, rawY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale == 0 then scale = 1 end
    local cursorX, cursorY = rawX / scale, rawY / scale
    if altDragging then
        if not leftDown or not altDown then
            StopAltDragging()
        else
            local deltaX, deltaY = cursorX - dragCursorX, cursorY - dragCursorY
            local x, y = dragStartX + deltaX, dragStartY + deltaY
            local _, _, _, oldX, oldY = anchor:GetPoint(1)
            if x ~= oldX or y ~= oldY then
                anchor:ClearAllPoints()
                anchor:SetPoint(dragPoint, UIParent, dragRelativePoint, x, y)
            end
        end
    end
end

-- A temporary child surface handles only Alt+mouse-down; its mouse events
-- never reach the game world, unlike a global cursor poll alone. It does not
-- replace or reparent the Blizzard buttons, and is hidden without Alt.
local altDragSurfaces = {}
local function RegisterAltDrag(frame)
    if not frame or not frame.CreateFontString or not frame.GetFrameLevel then return end
    if altDragSurfaces[frame] then return end
    local surface = CreateFrame("Frame", nil, frame)
    surface:SetAllPoints(frame)
    surface:SetFrameLevel(frame:GetFrameLevel() + 30)
    surface:EnableMouse(true)
    surface:RegisterForDrag("LeftButton")
    surface:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or not CanAltMove() or not IsAltKeyDown() then return end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if not scale or scale == 0 then scale = 1 end
        StartAltDragging(x / scale, y / scale)
    end)
    surface:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then StopAltDragging() end
    end)
    surface:SetScript("OnDragStart", function(self)
        if not altDragging and CanAltMove() and IsAltKeyDown() then
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            if not scale or scale == 0 then scale = 1 end
            StartAltDragging(x / scale, y / scale)
        end
    end)
    surface:SetScript("OnDragStop", function() StopAltDragging() end)
    surface:Hide()
    altDragSurfaces[frame] = surface
    if RefreshAltInput then RefreshAltInput() end
end
RegisterGamepadTestSurface = RegisterAltDrag

local function UpdateAltDragSurfaces()
    -- Keep the active surface visible until mouse release, even if Alt was
    -- released a fraction of a frame earlier. Normal votes are unobstructed.
    local active = CanAltMove() and IsAltKeyDown()
    for frame, surface in pairs(altDragSurfaces) do
        local visible = active and frame.IsShown and frame:IsShown()
        if visible then
            local desired = frame:GetFrameLevel() + 30
            if surface:GetFrameLevel() ~= desired then surface:SetFrameLevel(desired) end
            if not surface:IsShown() then surface:Show() end
        elseif surface:IsShown() then
            surface:Hide()
        end
    end
end

RefreshAltInput = function()
    if altDragging and (not CanAltMove() or not IsAltKeyDown()) then StopAltDragging() end
    UpdateAltDragSurfaces()
end

local hookRoll = false
local hookContainer = false
local hookFix = false
local hookPopupAnchor = false
local hookPopupShow = false

local function HookLootFrames()
    for i = 1, MAX_LOOT_FRAMES do
        local frame = GetLootFrame(i)
        if frame and not frame.__WildRollsFrameHooked then
            frame.__WildRollsFrameHooked = true
            if frame.HookScript then
                frame:HookScript("OnShow", function() QueueRefresh(true, true, false); RefreshAltInput() end)
                frame:HookScript("OnHide", function() QueueRefresh(true, true, false); RefreshAltInput() end)
            end
            if type(hooksecurefunc) == "function" then
                hooksecurefunc(frame, "SetPoint", function()
                    if not positioning then QueueRefresh(true, false, false) end
                end)
            end
        end
        if frame then
            RegisterAltDrag(frame)
            local n = frame:GetName()
            for _, key in ipairs({"NeedButton", "GreedButton", "PassButton", "DisenchantButton"}) do
                local button = (n and _G[n .. key]) or nil
                if button and button.HookScript and not button.__WildRollsHooked then
                    button.__WildRollsHooked = true
                    button:HookScript("OnClick", function() QueueRefresh(true, true, false) end)
                end
            end
        end
    end
end

local function InstallGlobalHooks()
    if not hooksecurefunc then return end
    if not hookContainer and type(GroupLootContainer_Update) == "function" then
        hooksecurefunc("GroupLootContainer_Update", function() QueueRefresh(true, false, false) end)
        hookContainer = true
    end
    if not hookFix and type(AlertFrame_FixAnchors) == "function" then
        hooksecurefunc("AlertFrame_FixAnchors", function()
            QueueRefresh(true, false, true)
        end)
        hookFix = true
    end
    if not hookRoll and type(GroupLootFrame_OpenNewFrame) == "function" then
        hooksecurefunc("GroupLootFrame_OpenNewFrame", function() QueueRefresh(true, true, false, true) end)
        hookRoll = true
    end
    if not hookPopupAnchor and type(AlertFrame_SetLootWonAnchors) == "function" then
        hooksecurefunc("AlertFrame_SetLootWonAnchors", function() QueueRefresh(false, false, true) end)
        hookPopupAnchor = true
    end
    if not hookPopupShow and type(LootWonAlertFrame_ShowAlert) == "function" then
        hooksecurefunc("LootWonAlertFrame_ShowAlert", function() QueueRefresh(false, false, true) end)
        hookPopupShow = true
    end
    if not hostHookInstalled and AlertFrame and type(hooksecurefunc) == "function" then
        -- Reassert the user's Edit Mode position when Blizzard reanchors the
        -- alert host. The recursion guard ensures our own SetPoint is ignored.
        hooksecurefunc(AlertFrame, "SetPoint", function()
            if not hostPositioning and WildLootRollDB.popupCustom then QueueRefresh(false, false, true) end
        end)
        hostHookInstalled = true
    end
end

-- Contextual settings attached to Blizzard's own Edit Mode manager.
-- They open only after clicking a movable preview, not when opening Edit Mode.
local settingsPanel, settingsControls
local editSelection = nil -- nil, "roll", or "received" (session-only)
local ApplyEditPreviews

-- Blizzard's Edit Mode selection artwork is reused verbatim.  This is a
-- cosmetic selection, not a registered Blizzard system: registering fake
-- system IDs in the protected manager would taint layouts on WoW Forever.
local nativeSelections = {}
local function CreateNativeSelection(mover, kind, title)
    local ok, selection = pcall(CreateFrame, "Frame", nil, mover, "EditModeSystemSelectionTemplate")
    local supportsTemplate = ok and selection and type(selection.ShowSelected) == "function"
        and type(selection.ShowHighlighted) == "function" and type(selection.SetSystem) == "function"
    if not supportsTemplate then
        -- Old Forever clients without that optional template still get a
        -- selectable hit area; avoid custom colored borders or fake skins.
        if not ok or not selection then selection = CreateFrame("Frame", nil, mover) end
        local label = selection:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        label:SetPoint("CENTER", selection, "CENTER", 0, 0)
        label:SetText(title)
        selection.simpleLabel = label
    else
        -- The selection mixin expects only GetSystemName for its label.
        selection:SetSystem({GetSystemName = function() return title end})
    end
    selection:SetFrameStrata("DIALOG")
    selection:SetFrameLevel(mover:GetFrameLevel() + 30)
    selection:EnableMouse(true)
    selection:RegisterForDrag("LeftButton")
    selection:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and editModeActive and SelectEditFrame then
            SelectEditFrame(kind)
        end
    end)
    selection:SetScript("OnDragStart", function()
        if editModeActive and not (InCombatLockdown and InCombatLockdown()) then
            mover:StartMoving()
        end
    end)
    selection:SetScript("OnDragStop", function()
        mover:StopMovingOrSizing()
        if not editModeActive then return end
        if kind == "roll" then
            SaveRollPosition()
            PositionAnchor()
            PositionLootFrames()
            PositionGamepadLoot()
        else
            SavePopupPosition()
            PositionPopupAnchor()
            PositionLootWonAlerts()
        end
    end)
    if supportsTemplate then
        selection:SetScript("OnEnter", function(self)
            if self.ShowEditInstructions then self:ShowEditInstructions(true) end
        end)
        selection:SetScript("OnLeave", function(self)
            if self.ShowEditInstructions then self:ShowEditInstructions(false) end
        end)
    end
    selection:Hide()
    nativeSelections[kind] = {frame = selection, native = supportsTemplate, title = title}
end

local function UpdateSelectionGeometry()
    local roll = nativeSelections.roll and nativeSelections.roll.frame
    local received = nativeSelections.received and nativeSelections.received.frame
    if roll then
        local db = WildLootRollDB
        local count = db.showEditPreviews and db.previewCount or 1
        local scale = db.scale or 1
        local step = 67 * scale + (db.spacing or 4)
        local topOffset = db.stackUpwards and (count - 1) * step or 0
        roll:ClearAllPoints()
        roll:SetPoint("TOPLEFT", anchor, "TOPLEFT", -8, topOffset + 8)
        roll:SetSize(277 * scale + 16, 67 * scale + (count - 1) * step + 16)
    end
    if received then
        received:ClearAllPoints()
        received:SetPoint("CENTER", popupAnchor, "CENTER", 0, RECEIVED_TOAST_CENTER_OFFSET_Y)
        received:SetSize(292, 112)
    end
end

local function UpdateSelectionOutlines()
    -- Defer template creation until Blizzard Edit Mode is loaded; otherwise
    -- a slash command before first opening Edit Mode could freeze the fallback.
    if not editModeActive and not nativeSelections.roll then return end
    if not nativeSelections.roll then
        CreateNativeSelection(anchor, "roll", "Loot Roll")
        CreateNativeSelection(popupAnchor, "received", "Loot Received")
    end
    UpdateSelectionGeometry()
    for kind, data in pairs(nativeSelections) do
        local selection = data.frame
        if not editModeActive then
            selection:Hide()
        else
            if data.native then
                if editSelection == kind then
                    selection:ShowSelected()
                    selection:SetAlpha(1)
                else
                    selection:ShowHighlighted()
                    local shown = kind == "roll" and WildLootRollDB.showEditPreviews
                        or kind == "received" and WildLootRollDB.showReceivedPreview
                    selection:SetAlpha(shown and 0.25 or 0.75)
                end
            else
                local shown = kind == "roll" and WildLootRollDB.showEditPreviews
                    or kind == "received" and WildLootRollDB.showReceivedPreview
                selection.simpleLabel:SetShown(not shown or editSelection == kind)
            end
            selection:Show()
        end
    end
    -- Blizzard's selection template already draws its own text and borders;
    -- these old custom labels are no longer required.
    if anchor.dragTitle then anchor.dragTitle:Hide() end
    if popupAnchor.dragTitle then popupAnchor.dragTitle:Hide() end
end
local function ResetRollLocation()
    local db = WildLootRollDB
    db.point, db.relativePoint, db.x, db.y = defaults.point, defaults.relativePoint, defaults.x, defaults.y
    PositionAnchor()
    PositionLootFrames()
    PositionGamepadLoot()
    UpdateGamepadTestPreview()
end
local function ResetReceivedLocation()
    local db = WildLootRollDB
    db.popupCustom = false
    db.popupPoint, db.popupRelativePoint = defaults.popupPoint, defaults.popupRelativePoint
    db.popupX, db.popupY = defaults.popupX, defaults.popupY
    -- Restore Blizzard's native alert host anchor when available. This host
    -- also controls unrelated notifications, so never leave it at our old spot.
    if savedHostPoint and AlertFrame and CanMove(AlertFrame) then
        local point = savedHostPoint
        hostPositioning = true
        AlertFrame:ClearAllPoints()
        AlertFrame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        hostPositioning = false
    end
    PositionPopupAnchor()
end
ApplyEditPreviews = function()
    if not editModeActive then return end
    -- Keep both edit handles accessible even when cosmetic previews are off.
    -- Otherwise disabling previews would make the controls impossible to reopen.
    anchor:Show()
    popupAnchor:Show()
    anchor:EnableMouse(true)
    popupAnchor:EnableMouse(true)
    if anchor.dragTitle then anchor.dragTitle:Hide() end
    if popupAnchor.dragTitle then popupAnchor.dragTitle:Hide() end
    -- Both sample families are initialized, even when one is hidden, so a
    -- checkbox never makes the other frame disappear or become unselectable.
    EnsureNativePreviews()
    if rollPreview and RefreshPreviewLayout then RefreshPreviewLayout() end
    if popupPreview then
        popupPreview:SetShown(WildLootRollDB.showReceivedPreview)
    end
    UpdateSelectionOutlines()
end

local function EnsureEditSettings()
    if settingsPanel then return end
    local manager = EditModeManagerFrame
    if not manager then return end

    -- Same frame structure and skin Blizzard uses for the native per-system
    -- Edit Mode settings dialog. Do not modify the actual Blizzard dialog.
    local panel = CreateFrame("Frame", "WildRollsEditSettings", UIParent)
    panel:SetSize(355, 382)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(205)
    panel:EnableMouse(true)
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    local borderOk, border = pcall(CreateFrame, "Frame", nil, panel, "DialogBorderTranslucentTemplate")
    if not borderOk or not border then
        borderOk, border = pcall(CreateFrame, "Frame", nil, panel, "DialogBorderTemplate")
    end
    if borderOk and border then border:SetAllPoints(panel) end
    settingsPanel = panel
    settingsControls = {}

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function()
        editSelection = nil
        panel:Hide()
        UpdateSelectionOutlines()
    end)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -15)
    settingsControls.title = title
    local rollView = CreateFrame("Frame", nil, panel)
    rollView:SetAllPoints(panel)
    local receivedView = CreateFrame("Frame", nil, panel)
    receivedView:SetAllPoints(panel)
    settingsControls.rollView = rollView
    settingsControls.receivedView = receivedView

    local function PlacePanel()
        panel:ClearAllPoints()
        local left, right = manager:GetLeft(), manager:GetRight()
        local screen = UIParent:GetWidth() or 1280
        if right and screen - right >= 367 then
            panel:SetPoint("TOPLEFT", manager, "TOPRIGHT", 12, 0)
        elseif left and left >= 367 then
            panel:SetPoint("TOPRIGHT", manager, "TOPLEFT", -12, 0)
        else
            panel:SetPoint("TOP", UIParent, "TOP", 0, -260)
        end
    end
    panel.PlacePanel = PlacePanel

    local function Label(parent, value, x, y, font)
        local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightMedium")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        fs:SetText(value)
        return fs
    end

    -- Vertical rows match the controls in EditModeSystemSettingsDialog, using
    -- Blizzard checkboxes and the modern MinimalSliderWithSteppers template.
    local function Check(y, text, key, fn)
        local cb = CreateFrame("CheckButton", nil, rollView, "UICheckButtonTemplate")
        cb:SetSize(32, 32)
        cb:SetPoint("TOPLEFT", rollView, "TOPLEFT", 22, y)
        local label = rollView:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        label:SetPoint("LEFT", cb, "RIGHT", 3, 0)
        label:SetText(text)
        cb:SetScript("OnClick", function(self)
            WildLootRollDB[key] = self:GetChecked() and true or false
            if fn then fn() end
        end)
        settingsControls[key] = cb
    end
    Check(-49, "Show Loot Roll previews", "showEditPreviews", ApplyEditPreviews)
    Check(-80, "Show Need / Greed counts", "showVoteCounts", function()
        ReadVoteHistory()
        UpdateVoteLabels()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
    end)
    Check(-111, "Stack upwards", "stackUpwards", function()
        PositionLootFrames()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        UpdateSelectionOutlines()
    end)

    local function Slider(y, titleText, key, lo, hi, step, formatValue, callback)
        local row = CreateFrame("Frame", nil, rollView)
        row:SetSize(310, 39)
        row:SetPoint("TOPLEFT", rollView, "TOPLEFT", 24, y)
        local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        name:SetPoint("LEFT", row, "LEFT", 0, 0)
        name:SetWidth(95)
        name:SetJustifyH("LEFT")
        name:SetText(titleText)
        local value = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        local function Changed(raw)
            local normalized = Clamp(math.floor(raw / step + 0.5) * step, lo, hi, lo)
            WildLootRollDB[key] = normalized
            value:SetText(formatValue(normalized))
            if callback then callback() end
        end
        local modern = nil
        if type(MinimalSliderWithSteppersMixin) == "table"
            and type(MinimalSliderWithSteppersMixin.Event) == "table" then
            local ok, created = pcall(CreateFrame, "Frame", nil, row, "MinimalSliderWithSteppersTemplate")
            if ok and created and type(created.Init) == "function"
                and type(created.RegisterCallback) == "function" then modern = created end
        end
        if modern then
            modern:SetSize(160, 32)
            modern:SetPoint("LEFT", row, "LEFT", 107, 0)
            modern:Init(WildLootRollDB[key], lo, hi,
                math.floor((hi - lo) / step + 0.5), {})
            -- CallbackRegistry passes (owner, value). Using the first argument
            -- instead of the actual value made every slider jump or get stuck.
            modern:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged,
                function(_, raw) Changed(raw) end)
            settingsControls[key] = {slider = modern, modern = true,
                set = function(v) modern:SetValue(v); value:SetText(formatValue(v)) end}
        else
            local bar = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
            bar:SetSize(165, 17)
            bar:SetPoint("LEFT", row, "LEFT", 105, 0)
            bar:SetMinMaxValues(lo, hi)
            bar:SetValueStep(step)
            if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(true) end
            bar:SetScript("OnValueChanged", function(_, raw) Changed(raw) end)
            settingsControls[key] = {slider = bar, modern = false,
                set = function(v) bar:SetValue(v); value:SetText(formatValue(v)) end}
        end
        value:SetText(formatValue(WildLootRollDB[key]))
    end

    local function UpdateRollLayout()
        PositionLootFrames()
        PositionGamepadLoot()
        UpdateGamepadTestPreview()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        UpdateSelectionOutlines()
    end
    Slider(-163, "Size", "scale", MIN_SCALE, MAX_SCALE, 0.05,
        function(v) return tostring(math.floor(v * 100 + 0.5)) .. "%" end,
        UpdateRollLayout)
    Slider(-209, "Spacing", "spacing", MIN_SPACING, MAX_SPACING, 1,
        function(v) return tostring(math.floor(v + 0.5)) .. " px" end,
        UpdateRollLayout)
    Slider(-255, "Previews", "previewCount", 1, 5, 1,
        function(v) return tostring(math.floor(v + 0.5)) end,
        function()
            if WildLootRollDB.showEditPreviews then EnsureNativePreviews() end
            UpdateRollLayout()
        end)

    local function MakeBlizzardDialogButton(parent)
        local ok, button = pcall(CreateFrame, "Button", nil, parent,
            "EditModeSystemSettingsDialogButtonTemplate")
        if ok and button then return button end
        return CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    end
    local resetRoll = MakeBlizzardDialogButton(rollView)
    resetRoll:SetSize(235, 28)
    resetRoll:SetPoint("TOP", rollView, "TOP", 0, -318)
    resetRoll:SetText("Reset Position")
    resetRoll:SetScript("OnClick", ResetRollLocation)

    Label(receivedView, "Drag the loot notification to move it.", 26, -63, "GameFontHighlightMedium")
    local receivedPreviewToggle = CreateFrame("CheckButton", nil, receivedView, "UICheckButtonTemplate")
    receivedPreviewToggle:SetSize(32, 32)
    receivedPreviewToggle:SetPoint("TOPLEFT", receivedView, "TOPLEFT", 22, -91)
    local receivedPreviewLabel = receivedView:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    receivedPreviewLabel:SetPoint("LEFT", receivedPreviewToggle, "RIGHT", 3, 0)
    receivedPreviewLabel:SetText("Show preview")
    receivedPreviewToggle:SetScript("OnClick", function(self)
        WildLootRollDB.showReceivedPreview = self:GetChecked() and true or false
        ApplyEditPreviews()
    end)
    settingsControls.showReceivedPreview = receivedPreviewToggle
    local receivedStatus = Label(receivedView, "Blizzard default position", 26, -146,
        "GameFontDisableSmall")
    settingsControls.receivedStatus = receivedStatus
    local resetReceived = MakeBlizzardDialogButton(receivedView)
    resetReceived:SetSize(235, 28)
    resetReceived:SetPoint("TOP", receivedView, "TOP", 0, -189)
    resetReceived:SetText("Reset Position")
    resetReceived:SetScript("OnClick", function()
        ResetReceivedLocation()
        receivedStatus:SetText("Blizzard default position")
        UpdateSelectionOutlines()
    end)

    rollView:Hide()
    receivedView:Hide()
    panel:Hide()
    -- Never compete with another Blizzard Edit Mode selection.
    if type(hooksecurefunc) == "function" and type(manager.SelectSystem) == "function" then
        hooksecurefunc(manager, "SelectSystem", function()
            if editModeActive and editSelection then
                editSelection = nil
                panel:Hide()
                UpdateSelectionOutlines()
            end
        end)
    end
end

local function RefreshEditSettings()
    if not settingsControls then return end
    local db = WildLootRollDB
    for _, key in ipairs({"showEditPreviews", "showReceivedPreview", "showVoteCounts", "stackUpwards"}) do
        settingsControls[key]:SetChecked(db[key])
    end
    -- Setting values can trigger callbacks, but these only update the visual
    -- preview and the safe native positioning methods.
    for _, key in ipairs({"scale", "spacing", "previewCount"}) do
        settingsControls[key].set(db[key])
    end
    settingsControls.receivedStatus:SetText(db.popupCustom and
        "Custom position" or "Blizzard default position")
end

SelectEditFrame = function(which)
    if not editModeActive or (which ~= "roll" and which ~= "received") then return end
    if not settingsPanel then EnsureEditSettings() end
    if not settingsPanel then return end
    editSelection = which
    -- Deselect native Blizzard systems when the addon preview is selected.
    local nativeDialog = _G.EditModeSystemSettingsDialog
    if nativeDialog and nativeDialog.IsShown and nativeDialog:IsShown() then
        if EditModeManagerFrame and type(EditModeManagerFrame.ClearSelectedSystem) == "function" then
            pcall(EditModeManagerFrame.ClearSelectedSystem, EditModeManagerFrame)
        end
        nativeDialog:Hide()
    end
    settingsPanel:SetHeight(which == "roll" and 382 or 265)
    settingsControls.title:SetText(which == "roll" and "Loot Roll" or "Loot Received")
    settingsControls.rollView:SetShown(which == "roll")
    settingsControls.receivedView:SetShown(which == "received")
    settingsPanel.PlacePanel()
    RefreshEditSettings()
    settingsPanel:Show()
    UpdateSelectionOutlines()
end

local function UpdateEditMode()
    if not editModeReady then return end
    local manager = EditModeManagerFrame
    local active = manager and manager.IsShown and manager:IsShown() and true or false
    if active == editModeActive then return end
    editModeActive = active
    if active then
        StopAltDragging()
        UpdateAltDrag()
        if gamepadTestPreview then gamepadTestPreview:Hide() end
        PositionAnchor()
        PositionPopupAnchor()
        EnsureEditSettings()
        editSelection = nil
        if settingsPanel then settingsPanel:Hide() end
        ApplyEditPreviews() -- previews are visible, but no settings until selected
        RefreshAltInput()
    else
        editSelection = nil
        if settingsPanel then settingsPanel:Hide() end
        for _, preview in ipairs(rollPreviews) do preview:Hide() end
        if popupPreview then popupPreview:Hide() end
        if anchor.dragTitle then anchor.dragTitle:Hide() end
        if popupAnchor.dragTitle then popupAnchor.dragTitle:Hide() end
        anchor:EnableMouse(false)
        popupAnchor:EnableMouse(false)
        anchor:Show()
        popupAnchor:Show() -- keep native alert host reference available; no mouse or artwork
        UpdateSelectionOutlines()
        PositionAll()
        RefreshAltInput()
    end
end

SLASH_WILDROLLS1 = "/wildrolls"
SlashCmdList["WILDROLLS"] = function(message)
    local command, argument = tostring(message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "scale" then
        local value = tonumber(argument)
        if not value then Print("usage: /wildrolls scale 0.70-1.40") return end
        WildLootRollDB.scale = Clamp(value, MIN_SCALE, MAX_SCALE, 1)
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        UpdateSelectionOutlines()
        PositionLootFrames()
        PositionGamepadLoot()
        UpdateGamepadTestPreview()
        Print("roll scale: " .. string.format("%.2f", WildLootRollDB.scale))
    elseif command == "spacing" or command == "space" then
        local value = tonumber(argument)
        if not value then Print("usage: /wildrolls spacing 0-24") return end
        WildLootRollDB.spacing = math.floor(Clamp(value, MIN_SPACING, MAX_SPACING, 4) + 0.5)
        PositionLootFrames()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        UpdateSelectionOutlines()
        Print("roll spacing: " .. WildLootRollDB.spacing)
    elseif command == "counts" then
        if argument == "on" then WildLootRollDB.showVoteCounts = true
        elseif argument == "off" then WildLootRollDB.showVoteCounts = false
        else Print("usage: /wildrolls counts on|off") return end
        ReadVoteHistory()
        UpdateVoteLabels()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        Print("Need/Greed counters " .. (WildLootRollDB.showVoteCounts and "enabled" or "disabled"))
    elseif command == "preview" or command == "previews" then
        if argument == "on" then WildLootRollDB.showEditPreviews = true
        elseif argument == "off" then WildLootRollDB.showEditPreviews = false
        elseif argument == "toggle" or argument == "" then
            WildLootRollDB.showEditPreviews = not WildLootRollDB.showEditPreviews
        else Print("usage: /wildrolls preview on|off|toggle") return end
        ApplyEditPreviews()
        Print("Edit Mode loot previews " .. (WildLootRollDB.showEditPreviews and "enabled" or "hidden"))
    elseif command == "stack" then
        if argument ~= "up" and argument ~= "down" then Print("usage: /wildrolls stack up|down") return end
        WildLootRollDB.stackUpwards = argument == "up"
        PositionLootFrames()
        if RefreshPreviewLayout then RefreshPreviewLayout() end
        Print("loot roll stacking: " .. argument)
    elseif command == "testpad" or command == "testgamepad" then
        ToggleGamepadTestPreview()
    elseif command == "status" then
        Print("v" .. ADDON_VERSION .. "; Edit Mode or Alt+drag native loot rolls; popup " ..
            (WildLootRollDB.popupCustom and "custom" or "native") .. "; roll scale " ..
            string.format("%.2f", WildLootRollDB.scale) .. "; spacing " .. WildLootRollDB.spacing)
    else
        -- Legacy unlock/lock commands remain retired; no unlock toggle required.
        Print("Use Esc > Edit Mode, or hold Alt and drag a real loot-roll window to reposition it.")
        Print("Options: /wildrolls preview on|off, /wildrolls stack up|down, /wildrolls testpad, /wildrolls scale 0.70-1.40, /wildrolls spacing 0-24, /wildrolls counts on|off, /wildrolls status")
    end
end

-- Batch native hooks/events once on the next UI tick, never from inside SetPoint.
local refreshDriver = CreateFrame("Frame")
local pendingRoll, pendingVotes, pendingPopup, pendingHooks = false, false, false, false
local refreshScheduled = false
local function FlushRefresh()
    refreshScheduled = false
    refreshDriver:SetScript("OnUpdate", nil)
    if not editModeReady then return end
    local roll, votesDirty, popup, hooks = pendingRoll, pendingVotes, pendingPopup, pendingHooks
    pendingRoll, pendingVotes, pendingPopup, pendingHooks = false, false, false, false
    if hooks then
        HookLootFrames()
        HookGamepadLoot()
        RegisterAltDrag(_G.GamepadGroupLootRollFrame)
        InstallGlobalHooks()
    end
    if roll then PositionLootFrames(); PositionGamepadLoot() end
    if votesDirty then ReadVoteHistory(); UpdateVoteLabels() end
    if popup then PositionLootWonAlerts() end
    if roll or hooks then RefreshAltInput() end
end
QueueRefresh = function(roll, votesDirty, popup, hooks)
    if not editModeReady then return end
    pendingRoll = pendingRoll or roll
    pendingVotes = pendingVotes or votesDirty
    pendingPopup = pendingPopup or popup
    pendingHooks = pendingHooks or hooks
    if not refreshScheduled then
        refreshScheduled = true
        refreshDriver:SetScript("OnUpdate", FlushRefresh)
    end
end

local hookedManager
local function HookEditManager()
    local manager = EditModeManagerFrame
    if manager and manager ~= hookedManager and manager.HookScript then
        hookedManager = manager
        manager:HookScript("OnShow", UpdateEditMode)
        manager:HookScript("OnHide", UpdateEditMode)
    end
    UpdateEditMode()
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "MODIFIER_STATE_CHANGED", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER",
    "LOOT_HISTORY_CLEAR_HISTORY", "LOOT_HISTORY_ROLL_CHANGED", "LOOT_ITEM_ROLL_WON",
    "CHAT_MSG_LOOT", "LOOT_CLOSED", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED"}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON_NAME then
        InitDB()
        editModeReady = true
        PositionAnchor()
        PositionPopupAnchor()
        anchor:EnableMouse(false)
        popupAnchor:EnableMouse(false)
        if anchor.dragTitle then anchor.dragTitle:Hide() end
        if popupAnchor.dragTitle then popupAnchor.dragTitle:Hide() end
        anchor:Show()
        popupAnchor:Show()
        HookEditManager()
        QueueRefresh(true, true, true, true)
    elseif not editModeReady then return
    elseif event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        HookEditManager()
        QueueRefresh(true, true, true, true)
    elseif event == "START_LOOT_ROLL" or event == "CANCEL_LOOT_ROLL" then
        QueueRefresh(true, true, false, true)
    elseif event:find("^LOOT_HISTORY_") then
        if WildLootRollDB.showVoteCounts then QueueRefresh(false, true, false) end
    elseif event == "MODIFIER_STATE_CHANGED" or event == "PLAYER_REGEN_DISABLED" then
        RefreshAltInput()
    elseif event == "PLAYER_REGEN_ENABLED" then
        QueueRefresh(true, true, true, true)
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        if not altDragging then PositionAnchor(); PositionPopupAnchor() end
        QueueRefresh(true, false, true)
    elseif event == "GAME_PAD_ACTIVE_CHANGED" or event == "GAME_PAD_CONNECTED" then
        QueueRefresh(true, false, false, true)
    else -- loot notification events: native Blizzard remains responsible for showing alerts
        if WildLootRollDB.popupCustom then QueueRefresh(false, false, true, true) end
    end
end)


-- WildSpark settings-module API.
function MOD.IsEnabled()
    return WildLootRollDB and WildLootRollDB.enabled ~= false
end

function MOD.SetEnabled(value)
    if not WildLootRollDB then return end
    WildLootRollDB.enabled = value and true or false
    if not WildLootRollDB.enabled then
        if type(_G.GroupLootContainer_Update) == "function" then
            pcall(_G.GroupLootContainer_Update, _G.GroupLootContainer)
        end
        if savedHostPoint and CanMove(AlertFrame) then
            hostPositioning = true
            AlertFrame:ClearAllPoints()
            AlertFrame:SetPoint(unpack(savedHostPoint))
            hostPositioning = false
        end
    end
    QueueRefresh(true, true, true, true)
end

function MOD.TogglePlacement()
    if EditModeManagerFrame and not EditModeManagerFrame:IsShown() then
        if ShowUIPanel then ShowUIPanel(EditModeManagerFrame) else EditModeManagerFrame:Show() end
    elseif not EditModeManagerFrame then
        Print("Open Edit Mode to move loot rolls and the loot-received alert.")
    end
end

function MOD.AdjustScale(delta)
    if not WildLootRollDB then return end
    WildLootRollDB.scale = Clamp((WildLootRollDB.scale or defaults.scale) + delta, MIN_SCALE, MAX_SCALE, defaults.scale)
    PositionLootFrames(); PositionGamepadLoot()
    if RefreshPreviewLayout then RefreshPreviewLayout() end
end

function MOD.AdjustSpacing(delta)
    if not WildLootRollDB then return end
    WildLootRollDB.spacing = math.floor(Clamp((WildLootRollDB.spacing or defaults.spacing) + delta, MIN_SPACING, MAX_SPACING, defaults.spacing) + 0.5)
    PositionLootFrames()
    if RefreshPreviewLayout then RefreshPreviewLayout() end
end

function MOD.SetVoteCounts(value)
    if not WildLootRollDB then return end
    WildLootRollDB.showVoteCounts = value and true or false
    QueueRefresh(false, true, false)
end

function MOD.GetVoteCounts()
    return WildLootRollDB and WildLootRollDB.showVoteCounts == true
end

function MOD.SetEditPreviews(value)
    if not WildLootRollDB then return end
    WildLootRollDB.showEditPreviews = value and true or false
    ApplyEditPreviews()
end

function MOD.GetEditPreviews()
    return WildLootRollDB and WildLootRollDB.showEditPreviews == true
end

function MOD.SetReceivedPreview(value)
    if not WildLootRollDB then return end
    WildLootRollDB.showReceivedPreview = value and true or false
    ApplyEditPreviews()
end

function MOD.GetReceivedPreview()
    return WildLootRollDB and WildLootRollDB.showReceivedPreview == true
end

function MOD.SetStackUpwards(value)
    if not WildLootRollDB then return end
    WildLootRollDB.stackUpwards = value and true or false
    PositionLootFrames()
    if RefreshPreviewLayout then RefreshPreviewLayout() end
end

function MOD.GetStackUpwards()
    return WildLootRollDB and WildLootRollDB.stackUpwards == true
end

function MOD.AdjustPreviewCount(delta)
    if not WildLootRollDB then return end
    WildLootRollDB.previewCount = math.floor(Clamp((WildLootRollDB.previewCount or defaults.previewCount) + delta, 1, 5, defaults.previewCount) + 0.5)
    if WildLootRollDB.showEditPreviews then EnsureNativePreviews() end
    ApplyEditPreviews()
    if RefreshPreviewLayout then RefreshPreviewLayout() end
end
