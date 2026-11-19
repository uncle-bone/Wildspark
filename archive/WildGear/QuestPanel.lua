local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Quest panel, docked beside the main window: opened by left-clicking a quest
-- name (Best in slot rows) or a quest header (Dungeon loot tab). Shows the
-- quest's details, its rewards ranked for the profile (the best choice
-- highlighted), the whole chain with the character's progress (click a step
-- for its details, right-click to pin its quest giver), and buttons to pin the
-- next step or this quest's giver and to copy Wowhead links (addons can't open
-- a browser, so the link goes in a box to copy).

local UI, W = ns.UI, ns.Widgets
local L = ns.L
local QP = {}
ns.QuestPanel = QP

local WIDTH = 330
local PAD = 12
local LINE = 18 -- text line and item row height
local ICON = 16
local BUTTON_H = 20
local COPY_H = 44 -- copy box with its label
-- Wowhead's site in the game's language (Locale.lua's LANGUAGES).
local WOWHEAD = "https://www.wowhead.com/forever/" .. (ns.language.wowhead and ns.language.wowhead .. "/" or "")
local GREY, WHITE, GOLD, GREEN = "|cff888888", "|cffffffff", "|cffffd100", "|cff33ff99"
local BEST_TINT = { 0.2, 1, 0.6, 0.1 }
local CURRENT_TINT = { 0.2, 1, 0.6, 0.06 }
local NEXT_TINT = { 1, 0.82, 0, 0.08 }
local WORN_TINT = { UI.WORN_RGB[1], UI.WORN_RGB[2], UI.WORN_RGB[3], 0.1 }
local START_KIND = { npc = "npc", object = "object", item = "item" }
local START_LINK_LABEL = { npc = L["Wowhead: quest giver"], object = L["Wowhead: start object"],
    item = L["Wowhead: start item"] }

local panel
local shown -- the quest source on display
local history = {} -- sources to go back to after clicking chain steps
local lines = {} -- pooled content lines
local used, y = 0, 0

local function TipAnchor(owner)
    local x = owner:GetCenter()
    return (x and UIParent:GetWidth() and x > UIParent:GetWidth() / 2) and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
end

local function HideTip()
    GameTooltip:Hide()
end

---------------------------------------------------------------- content lines

local function GetLine()
    used = used + 1
    local l = lines[used]
    if not l then
        l = CreateFrame("Button", nil, panel.content)
        l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        l.tint = l:CreateTexture(nil, "BACKGROUND")
        l.tint:SetAllPoints()
        l.hl = l:CreateTexture(nil, "HIGHLIGHT")
        l.hl:SetAllPoints()
        l.hl:SetColorTexture(1, 1, 1, 0.08)
        l.rule = W.Rule(l, 1, 0.82, 0, 0.3)
        l.rule:SetPoint("BOTTOMLEFT")
        l.rule:SetPoint("BOTTOMRIGHT")
        l.icon = l:CreateTexture(nil, "ARTWORK")
        l.icon:SetSize(ICON, ICON)
        l.right = l:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        l.right:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        l.right:SetJustifyH("RIGHT")
        l.left = l:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        l.left:SetJustifyH("LEFT")
        l.left:SetWordWrap(false)
        l:SetScript("OnLeave", HideTip)
        lines[used] = l
    end
    return l
end

-- Adds a line: o = { left, right, font, icon, indent, height, tint, rule,
-- onEnter, onClick, data }. Lines without handlers don't take the mouse.
local function AddLine(o)
    local l = GetLine()
    local h = o.height or LINE
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", 0, -y)
    l:SetHeight(h)
    l.left:SetFontObject(o.font or WildGearFontHighlightSmall)
    local x = 4 + (o.indent or 0)
    if o.icon then
        l.icon:SetTexture(o.icon)
        l.icon:ClearAllPoints()
        l.icon:SetPoint("LEFT", l, "LEFT", x, 0)
        l.icon:Show()
        x = x + ICON + 6
    else
        l.icon:Hide()
    end
    l.left:ClearAllPoints()
    l.left:SetPoint("LEFT", l, "LEFT", x, 0)
    l.left:SetPoint("RIGHT", l.right, "LEFT", -6, 0)
    l.left:SetText(o.left or "")
    l.right:SetText(o.right or "")
    if o.tint then
        l.tint:SetColorTexture(unpack(o.tint))
        l.tint:Show()
    else
        l.tint:Hide()
    end
    if o.rule then l.rule:Show() else l.rule:Hide() end
    l.data = o.data
    l:SetScript("OnEnter", o.onEnter)
    l:SetScript("OnClick", o.onClick)
    l:EnableMouse(o.onEnter ~= nil or o.onClick ~= nil)
    l:Show()
    y = y + h
    return l
end

local function Gap(h)
    y = y + (h or 6)
end

local function Header(text, right)
    Gap(8)
    AddLine({ left = GOLD .. text .. "|r", right = right, font = WildGearFontNormal, height = 20, rule = true })
    Gap(3)
end

---------------------------------------------------------------- rewards

local function ItemEnter(self)
    GameTooltip:SetOwner(self, TipAnchor(self))
    GameTooltip:SetHyperlink("item:" .. self.data.id)
    ns.Tooltip.AddBlock(GameTooltip, self.data.id, nil, ns.GetProfile()) -- as item tooltips everywhere
    ns.Tooltip.HintLast(GameTooltip)
    GameTooltip:Show()
end

local function ItemClick(self)
    if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        HandleModifiedItemClick(ns.ItemLink(self.data.id))
    end
end

-- Why the profile can't take gear `item` from a quest (`open`: the quest is
-- open to the profile's faction, class and race).
local function WhyNot(item, p, open)
    local from = ns.WearLevel(item, p) -- (weapon training, mail and plate)
    if not from then return L["can't use"] end
    local level = math.max(item.reqLevel or 0, from)
    if level > p.level then return string.format(L["requires level %d"], level) end
    if ns.db.classArmorOnly and ns.IsLighterArmor(item, p) then return L["not class armor"] end
    if not open then return L["quest not available"] end
    return ""
end

-- Name (quality colored, from the game when it knows the item) and what the
-- item means for the profile: its rank and gain over worn gear, when it
-- unlocks, or why it can't be used. Returns name, right text, info, tooltip line.
local function DescribeReward(id, count, p, open)
    local item = ns.Items[id]
    local name, _, quality
    if C_Item and C_Item.GetItemInfo then name, _, quality = C_Item.GetItemInfo(id) end
    if not name then ns.RequestItem(id) end
    name = name or (item and ns.ItemName(id))
    quality = quality or (item and item.quality) or 1
    local text = name and (ns.QualityHex(quality) .. name .. "|r") or (GREY .. string.format(L["item %d (loading)"], id) .. "|r")
    if count and count > 1 then text = text .. WHITE .. " x" .. count .. "|r" end
    if not item then return text, nil, nil end -- not gear the addon ranks
    local info = UI.RewardInfo(id)
    if info and info.upcoming then
        return text, GREEN .. string.format(L["lvl %d %s"], info.level, info.slot) .. "|r", info
    elseif info then
        local right = string.format("%s#%d %s|r", WHITE, info.rank, info.slot)
        if info.wornText and info.wornText ~= "" then right = right .. "  " .. info.wornText end
        return text, right, info
    end
    return text, GREY .. WhyNot(item, p, open) .. "|r", nil
end

-- The choice to take: the biggest gain over worn gear, else (planning another
-- class) the best slot rank. Nil when none of them is usable now.
local function BestChoice(infos)
    local best, bestKey
    for id, info in pairs(infos) do
        if not info.upcoming then
            local key = info.gain or -info.rank
            if not bestKey or key > bestKey then best, bestKey = id, key end
        end
    end
    return best
end

local function Rewards(r, p, open)
    Header(L["Rewards"])
    if not r then
        AddLine({ left = GREY .. L["No rewards listed on Wowhead"] .. "|r" })
        return
    end
    local counts = r.counts or {}
    local function Items(ids, label, pickBest)
        AddLine({ left = GREY .. label .. "|r" })
        local rows, infos = {}, {}
        for _, id in ipairs(ids) do
            local text, right, info = DescribeReward(id, counts[id], p, open)
            rows[#rows + 1] = { id = id, text = text, right = right }
            infos[id] = info
        end
        local best = pickBest and #ids > 1 and BestChoice(infos)
        for _, row in ipairs(rows) do
            local isBest = row.id == best
            AddLine({
                left = row.text, right = isBest and (GREEN .. L["best pick"] .. "|r  " .. (row.right or "")) or row.right,
                icon = UI.ItemIcon(row.id), indent = 6,
                tint = (isBest and BEST_TINT) or (UI.IsWorn(row.id) and WORN_TINT) or nil,
                data = row, onEnter = ItemEnter, onClick = ItemClick,
            })
        end
    end
    if r.choices then Items(r.choices, L["Choose one of:"], true) end
    if r.items then Items(r.items, r.choices and L["You will also receive:"] or L["You will receive:"]) end
    if r.spells then
        AddLine({ left = GREY .. L["You will learn:"] .. "|r" })
        for _, spell in ipairs(r.spells) do
            local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell[1]))
                or (GetSpellTexture and GetSpellTexture(spell[1]))
            AddLine({
                left = WHITE .. ns.SpellName(spell[1], spell[2]) .. "|r", icon = icon, indent = 6, data = spell,
                onEnter = function(self)
                    GameTooltip:SetOwner(self, TipAnchor(self))
                    GameTooltip:SetSpellByID(self.data[1])
                    GameTooltip:Show()
                end,
            })
        end
    end
    if r.money then AddLine({ left = GREY .. L["Money"] .. "|r", right = ns.MoneyText(r.money) }) end
    if r.xp then
        local xp = BreakUpLargeNumbers and BreakUpLargeNumbers(r.xp) or tostring(r.xp)
        AddLine({ left = GREY .. L["Experience"] .. "|r", right = WHITE .. xp .. "|r" })
    end
    for i, rep in ipairs(r.rep or {}) do
        local faction = ns.FactionName(rep[1])
        AddLine({ left = i == 1 and (GREY .. L["Reputation"] .. "|r") or "",
                  right = string.format("%s%+d|r %s", rep[2] >= 0 and GREEN or "|cffff5050", rep[2], faction) })
    end
end

---------------------------------------------------------------- chain

local function StepEnter(self)
    local r = self.data
    local q = ns.Quests[r.id] or {}
    GameTooltip:SetOwner(self, TipAnchor(self))
    GameTooltip:AddLine(r.name, 1, 0.82, 0)
    if q.level then GameTooltip:AddLine(ns.QuestLevelText(q.level, q.reqLevel, ""), 1, 1, 1) end
    if q.start then
        local zone = ns.ZoneName(q.start.zoneId)
        GameTooltip:AddLine(ns.StartName(q.start) .. (zone and (L[", "] .. zone) or ""), 1, 1, 1)
    end
    if r.state == "done" then GameTooltip:AddLine(L["Completed"], 0.2, 1, 0.6) end
    if r.state == "active" then GameTooltip:AddLine(L["In your quest log"], unpack(ns.ACTIVE_RGB)) end
    if not r.current then GameTooltip:AddLine(L["Click: show this quest"], 0.53, 0.53, 0.53) end
    if q.start and q.start.x then GameTooltip:AddLine(L["Right-click: pin its quest giver"], 0.53, 0.53, 0.53) end
    GameTooltip:Show()
end

local function StepClick(self, button)
    local r = self.data
    if button == "RightButton" then
        ns.PinQuestGiver(r.id)
    elseif not r.current then
        QP.Show({ type = "quest", id = r.id, name = r.name }, true)
    end
end

local function Chain(info)
    local chain = info.chain
    Header(L["Quest chain"], WHITE .. string.format(L["step %d of %d"], chain.step, chain.steps) .. "|r")
    local nextId = info.target and info.target.id
    for _, r in ipairs(chain.rows) do
        local label = r.first and string.format("%d. %s", r.step, r.name) or ("      " .. string.format(L["or %s"], r.name))
        if r.optional then label = label .. L[" (optional)"] end
        local color = (r.current and GREEN) or (r.state == "done" and GREY) or WHITE
        local right = (r.state == "done" and GREEN .. L["done"] .. "|r")
            or (r.state == "active" and ns.ACTIVE_HEX .. L["in quest log"] .. "|r")
            or (r.id == nextId and not r.current and GOLD .. L["next for you"] .. "|r")
            or (r.level and GREY .. string.format(L["lvl %d"], r.level) .. "|r")
        if r.current then right = GREEN .. L["this quest"] .. "|r" .. (right and ("  " .. right) or "") end
        AddLine({
            left = color .. label .. "|r", right = right, data = r,
            tint = (r.current and CURRENT_TINT) or (r.id == nextId and NEXT_TINT) or nil,
            onEnter = StepEnter, onClick = StepClick,
        })
    end
end

---------------------------------------------------------------- buttons

local function ShowCopy(url, label)
    panel.copyLabel:SetText(GREY .. string.format(L["%s: press Ctrl+C, then paste it in your browser"], label) .. "|r")
    panel.copy.url = url
    panel.copy:SetText(url)
    panel.copy:Show()
    panel.copyLabel:Show()
    QP.Refresh()
    panel.copy:SetFocus()
    panel.copy:HighlightText()
end

local function HideCopy()
    panel.copy:ClearFocus()
    panel.copy:Hide()
    panel.copyLabel:Hide()
end

local function SetButton(b, text, enabled)
    b:SetText(text)
    if enabled then b:Enable() else b:Disable() end
end

-- Pin and Wowhead buttons for `info`; the second pin button only when the
-- next step isn't this quest.
local function UpdateButtons(info)
    local target, state = info.target, info.targetState
    local nextBtn, giverBtn = panel.pinNext, panel.pinGiver
    local half = (WIDTH - 2 * PAD - 6) / 2
    if state == "done" then
        SetButton(nextBtn, L["Quest completed"], false)
    elseif state == "active" then
        SetButton(nextBtn, L["In your quest log"], false)
    elseif target and target.start and target.start.x then
        local own = target.id == info.id
        SetButton(nextBtn, own and L["Pin quest giver"] or string.format(L["Pin next step (%d)"], target.step), true)
    else
        SetButton(nextBtn, L["No map location"], false)
    end
    local ownGiver = info.start and info.start.x
    local separate = ownGiver and not (target and target.id == info.id and not state)
    nextBtn:SetWidth(separate and half or (WIDTH - 2 * PAD))
    if separate then giverBtn:Show() else giverBtn:Hide() end

    local kind = info.start and info.start.id and START_KIND[info.start.kind or "npc"]
    panel.linkGiver:SetText(kind and START_LINK_LABEL[kind] or L["No quest giver link"])
    if kind then panel.linkGiver:Enable() else panel.linkGiver:Disable() end
end

---------------------------------------------------------------- panel

local function Render()
    local p = ns.GetProfile()
    local info = ns.QuestInfo(shown, p)
    if not info then
        panel:Hide()
        return
    end
    used, y = 0, 0

    -- The quest's name in the title band, after the back button or at the
    -- edge without one; a name on two lines makes the band taller.
    local back = #history > 0
    if back then panel.back:Show() else panel.back:Hide() end
    local left = (back and PAD + 22 or PAD) - 2
    if panel.icon then -- (Modern: the quest mark first, close after the back button)
        if back then left = left - 2 end
        panel.icon:SetPoint("LEFT", panel.band, "LEFT", left, 0)
        left = left + panel.icon:GetWidth() + 7
    end
    panel.title:ClearAllPoints()
    panel.title:SetPoint("LEFT", panel.band, "LEFT", left, 0)
    panel.title:SetWidth(WIDTH - 2 * PAD - 16 - left)
    panel.title:SetText(info.name)
    local band = math.max(W.TITLE_HEIGHT, (panel.title:GetStringHeight() or 0) + 14)
    panel.band:SetHeight(band)
    local inset = W.Inset() -- (Classic: all of it further in, the band too)
    local top = band + 8 + inset
    panel.content:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + inset, -top)

    AddLine({ left = ns.QuestLevelText(info.level, info.reqLevel, GREY), right = info.sideLabel })
    for _, tag in ipairs(info.tags) do AddLine({ left = tag }) end
    if info.state == "done" then AddLine({ left = GREEN .. L["You have completed this quest"] .. "|r" }) end
    if info.state == "active" then AddLine({ left = ns.ACTIVE_HEX .. L["This quest is in your quest log"] .. "|r" }) end

    Header(L["Where"])
    if info.zone then AddLine({ left = GREY .. L["Zone"] .. "|r", right = WHITE .. info.zone .. "|r" }) end
    if info.start then
        AddLine({ left = GREY .. info.startLabel .. "|r", right = WHITE .. info.startName .. "|r" })
        if info.startWhere then AddLine({ left = "", right = WHITE .. info.startWhere .. "|r" }) end
    else
        AddLine({ left = GREY .. L["No quest giver listed on Wowhead"] .. "|r" })
    end

    Rewards(info.rewards, p, ns.QuestOpen(ns.Quests[shown.id], p) and ns.QuestOpen(shown, p))
    if info.chain then Chain(info) end

    for i = used + 1, #lines do lines[i]:Hide() end
    panel.content:SetHeight(math.max(y, 1))
    UpdateButtons(info)
    local copyH = panel.copy:IsShown() and COPY_H or 0
    panel:SetHeight(top + y + 12 + 2 * BUTTON_H + 4 + copyH + PAD + inset)
    UI.DockSides()
end

local function Create()
    local main = UI.Frame()
    panel = CreateFrame("Frame", "WildGearQuestPanel", main, "BackdropTemplate")
    panel:SetWidth(WIDTH + 2 * W.Inset())
    W.Window(panel)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    main:HookScript("OnHide", function() panel:Hide() end)
    panel:SetScript("OnShow", function(self) UI.ClaimSide(self) end)

    -- The title band like the other panels', the quest's name in it (placed
    -- by Render), between the back and close buttons (Classic: not in a plaque,
    -- the close button in the border's corner).
    panel.title, panel.band = W.TitleBand(panel, "", "WildGearFontNormal", true)
    panel.title:SetJustifyH("LEFT")
    panel.icon = W.PanelIcon(panel.title, panel.band, "Quest") -- (Modern: the quest mark, placed by Render too)
    local inset = (W.TITLE_HEIGHT - 20) / 2 -- (the buttons as far from the band's edges as from its top)
    panel.back = W.FlatButton(panel, "<", 20, 20)
    panel.back:SetPoint("LEFT", panel.band, "LEFT", inset, 0)
    panel.back:SetScript("OnClick", function()
        shown = table.remove(history) or shown
        HideCopy()
        Render()
    end)
    panel.close = W.CloseButton(panel)
    if not ns.Theme.Classic() then panel.close:SetPoint("RIGHT", panel.band, "RIGHT", -inset, 0) end

    panel.content = CreateFrame("Frame", nil, panel)
    panel.content:SetWidth(WIDTH - 2 * PAD)

    local half = (WIDTH - 2 * PAD - 6) / 2
    local function Button(text, onClick)
        local b = W.FlatButton(panel, text, half, BUTTON_H)
        b:SetDisabledFontObject(WildGearFontDisableSmall)
        b:SetScript("OnClick", onClick)
        return b
    end
    panel.pinNext = Button(L["Pin next step"], function() ns.PinQuest(shown) end)
    panel.pinNext:SetPoint("TOPLEFT", panel.content, "BOTTOMLEFT", 0, -12)
    panel.pinGiver = Button(L["Pin this quest's giver"], function() ns.PinQuestGiver(shown.id) end)
    panel.pinGiver:SetPoint("TOPRIGHT", panel.content, "BOTTOMRIGHT", 0, -12)
    panel.linkQuest = Button(L["Wowhead: quest"], function()
        ShowCopy(WOWHEAD .. "quest=" .. shown.id, L["Quest link"])
    end)
    panel.linkQuest:SetPoint("TOPLEFT", panel.pinNext, "BOTTOMLEFT", 0, -4)
    panel.linkGiver = Button(L["Wowhead: quest giver"], function()
        local q = ns.Quests[shown.id]
        local start = q and q.start
        if start and start.id then
            ShowCopy(WOWHEAD .. START_KIND[start.kind or "npc"] .. "=" .. start.id,
                string.format(L["%s link"], ns.StartName(start)))
        end
    end)
    panel.linkGiver:SetPoint("TOPRIGHT", panel.pinGiver, "BOTTOMRIGHT", 0, -4)
    panel.linkGiver:SetPoint("TOPLEFT", panel.linkQuest, "TOPRIGHT", 6, 0)

    -- Copy box for Wowhead links: selected text, reset if edited, Escape closes it.
    panel.copyLabel = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    panel.copyLabel:SetPoint("TOPLEFT", panel.linkQuest, "BOTTOMLEFT", 0, -8)
    panel.copyLabel:SetWidth(WIDTH - 2 * PAD)
    panel.copyLabel:SetJustifyH("LEFT")
    panel.copy = W.EditBox(panel, WIDTH - 2 * PAD, 20)
    panel.copy:SetPoint("TOPLEFT", panel.copyLabel, "BOTTOMLEFT", 0, -2)
    panel.copy:SetScript("OnEscapePressed", function()
        HideCopy()
        QP.Refresh()
    end)
    panel.copy:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    panel.copy:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self.url then
            self:SetText(self.url)
            self:HighlightText()
        end
    end)
    HideCopy()

    -- Keep progress marks and item names current while the panel is open.
    local pending = false
    panel:SetScript("OnEvent", function()
        if pending or not panel:IsShown() then return end
        pending = true
        C_Timer.After(0.2, function()
            pending = false
            QP.Refresh()
        end)
    end)
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "GET_ITEM_INFO_RECEIVED" }) do
        pcall(panel.RegisterEvent, panel, e)
    end
    panel:Hide()
end

-- Shows quest source `s`; `fromChain` keeps the current quest for the back
-- button. Clicking the quest already shown closes the panel.
function QP.Show(s, fromChain)
    if not (UI.Frame() and ns.Quests[s.id]) then return end
    if not panel then Create() end
    if fromChain then
        history[#history + 1] = shown
    else
        if panel:IsShown() and shown and shown.id == s.id then
            panel:Hide()
            return
        end
        history = {}
    end
    shown = s
    HideCopy()
    Render()
    panel:Show()
end

function QP.Refresh()
    if panel and panel:IsShown() and shown then Render() end
end
