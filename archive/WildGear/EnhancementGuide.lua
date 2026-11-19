local _, addonRoot = ...
local ns = addonRoot.WildGear
local Guide = {}
ns.EnhancementGuide = Guide
local frame, content, scroll, search, levelText, selected = nil, nil, nil, nil, nil, "weapons"
local tabs = {}
local rowPool, rowCount = {}, 0

local function PlayerLevel()
    return (UnitLevel and UnitLevel("player")) or 1
end

local function Font(parent, template, text)
    local f = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    if text then f:SetText(text) end
    return f
end

local function RowText(name, suffix, ready)
    local c = ready and "|cff55dd77" or "|cffc8b579"
    return c .. name .. "|r  |cffaaaaaa" .. suffix .. "|r"
end

local function MakeFrame()
    if frame then return end
    frame = CreateFrame("Frame", "WildGearEnhancementGuide", UIParent, "BackdropTemplate")
    frame:SetSize(760, 590)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=24, insets={left=8,right=8,top=8,bottom=8} })
    end
    local title = Font(frame, "GameFontNormalLarge", "WildGear · Enchants & Enhancements")
    title:SetPoint("TOPLEFT", 18, -14)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() frame:Hide() end)
    levelText = Font(frame, "GameFontHighlight")
    levelText:SetPoint("TOPRIGHT", close, "BOTTOMLEFT", -4, 5)

    local tabDefs = {
        { key="weapons", label="Weapon buffs" },
        { key="armor", label="Armor & gear mods" },
        { key="enchants", label="178 permanent enchants" },
    }
    for i, def in ipairs(tabDefs) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(i == 3 and 190 or 145, 24)
        b:SetPoint("TOPLEFT", 18 + (i-1)*154, -48)
        b:SetText(def.label)
        b:SetScript("OnClick", function() selected = def.key; search:SetText(""); Guide.Refresh() end)
        tabs[def.key] = b
    end
    search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(155, 24)
    search:SetPoint("TOPRIGHT", -44, -49)
    search:SetAutoFocus(false)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetScript("OnTextChanged", function() Guide.Refresh() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local hint = Font(frame, "GameFontDisableSmall", "Search")
    hint:SetPoint("RIGHT", search, "LEFT", -6, 0)

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -84)
    scroll:SetPoint("BOTTOMRIGHT", -34, 18)
    content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(690)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    frame:SetScript("OnShow", function() Guide.Refresh() end)
end

local function AddEntry(y, primary, detail, isReady, height)
    rowCount = rowCount + 1
    local line = rowPool[rowCount]
    if not line then
        line = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        rowPool[rowCount] = line
    end
    line:ClearAllPoints()
    line:Show()
    line:SetPoint("TOPLEFT", 0, -y)
    line:SetWidth(680)
    line:SetJustifyH("LEFT")
    line:SetJustifyV("TOP")
    line:SetWordWrap(true)
    line:SetText(RowText(primary, detail, isReady))
    return y + height
end

local function FilterMatch(text, query)
    return query == "" or text:lower():find(query, 1, true) ~= nil
end

local function RefreshLevelItems(items, query, level, y, typeKey)
    local groups = {}
    for _, item in ipairs(items) do
        local group = item.group or item.slot or "Other"
        groups[group] = groups[group] or {}
        groups[group][#groups[group]+1] = item
    end
    local order = typeKey == "weapons"
        and {"Weapon stone", "Weapon oil", "Weapon stone · situational"}
        or {"Armor patch", "Armor patch · Attack Power", "Armor patch · Spell Power", "Armor patch · Defense/Stamina", "Weapon enhancement", "Shield enhancement", "Boots enhancement", "Ranged weapon enhancement"}
    for _, group in ipairs(order) do
        local list = groups[group]
        if list then
            y = AddEntry(y, group, "", true, 30)
            for _, item in ipairs(list) do
                local gate = item.level
                local searchable = item.name .. " " .. group .. " " .. item.profession
                if FilterMatch(searchable, query) then
                    local ready = not gate or level >= gate
                    local detail
                    if gate then
                        detail = (ready and "usable now · " or "available at level ") .. tostring(gate) .. " · " .. item.profession
                    else
                        detail = (item.itemLevel and ("enhancement item level " .. item.itemLevel .. " · ") or "") .. item.profession .. " · character-level gate not listed"
                    end
                    if item.effect then detail = detail .. " · " .. item.effect end
                    if item.note then detail = detail .. " · " .. item.note end
                    if item.targetMin then detail = detail .. " · target item level " .. item.targetMin .. "+" end
                    y = AddEntry(y, item.name, detail, ready, 38)
                end
            end
            y = y + 6
        end
    end
    return y
end

local function RefreshEnchants(query)
    local y, lastSlot = 0, nil
    for _, e in ipairs(ns.EnchantData or {}) do
        local searchable = table.concat({e.name, e.slot, e.materials, e.formula}, " ")
        if FilterMatch(searchable, query) then
            if e.slot ~= lastSlot then
                y = AddEntry(y, e.slot, "", true, 28)
                lastSlot = e.slot
            end
            local skill = e.yellow and ("Enchanting skill: yellow " .. e.yellow .. ", grey " .. e.grey) or "Enchanting skill varies by trainer/formula"
            y = AddEntry(y, e.name, skill .. " · " .. e.materials .. " · " .. e.formula, true, 58)
        end
    end
    return y
end

function Guide.Refresh()
    if not frame or not content then return end
    levelText:SetText("Character level " .. PlayerLevel())
    for key, button in pairs(tabs) do
        if key == selected then button:LockHighlight() else button:UnlockHighlight() end
    end
    for _, line in ipairs(rowPool) do line:Hide() end
    rowCount = 0
    local query = search and search:GetText():lower() or ""
    local y
    if selected == "weapons" then
        y = RefreshLevelItems(ns.LevelingEnhancements or {}, query, PlayerLevel(), 0, "weapons")
    elseif selected == "armor" then
        y = RefreshLevelItems(ns.ArmorEnhancements or {}, query, PlayerLevel(), 0, "armor")
    else
        y = RefreshEnchants(query)
    end
    if y == 0 then y = AddEntry(0, "No matches", "Try a shorter search.", false, 34) end
    content:SetHeight(math.max(y, 1))
end

function Guide.Show()
    MakeFrame()
    frame:Show()
    Guide.Refresh()
end

function Guide.Toggle()
    MakeFrame()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
