local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The Stat weights side panel (opened by the window's Stat weights button,
-- docked on its right, UI.DockSides): the weights that rank items for the
-- window's class, spec and weapon setup, and their profiles (WeightProfiles.lua).
--   [icon] [ Custom ⌄ ]  New  Import  Export
--   Dual wield · Levels 1-60
--   Strength   2     Agility     1.01     (orange: not the default at your level)
--   ...
--   Reset  Rename                    Delete      (on Default: Edit)
-- The selector picks a profile, or Default (the model's weights, by level);
-- the icon button opens the icon picker (not for Default). Typing a weight
-- saves it in the picked profile. Default can't be changed: its boxes are
-- locked, and Edit (in Reset's place) asks whether to make a profile from it
-- (Create, Cancel), then for a name in the name box over the selector, then
-- makes a copy of it under that name, picked, to change. New does the same
-- for what's picked, without asking; Escape in the name box makes nothing.
-- Reset makes the profile the defaults at your level again; Delete asks
-- first. A profile imported with level brackets shows its bracket for your
-- level, its boxes locked.
-- The first profile you make starts a tour of the panel, once (below: tour).
-- Import and Export open over the panel: Import reads a pasted string (ours
-- or Pawn's), its name and what it is for (the class fixed: the string's, or
-- yours) changeable before importing; Export shows the picked weights as our
-- string or Pawn's, selected, to copy.

local UI, W, T, L = ns.UI, ns.Widgets, ns.Theme, ns.L
local WP = ns.WeightProfiles

local WP_PANEL = {}
ns.WeightsPanel = WP_PANEL

local PAD = 14
local ROW = 19
local COLS = 2
local COL_WIDTH = 150
local ICON = 24 -- the icon button
local ORANGE, GREY, RED = "|cffff9900", "|cff999999", "|cffff5050"

local panel
local tour, ShowTour -- the tour's step shown (nil: none), and what shows it (below: tour)
local tourMade -- (step 1: whether the name box made the profile)

local function ClassColored(classFile, text)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return (c and c.colorStr) and ("|c" .. c.colorStr .. text .. "|r") or text
end

local function ClassName(classFile)
    for _, c in ipairs(ns.Classes) do
        if c.file == classFile then return c.name end
    end
    return classFile
end

-- The window's profile, the weapon setup its weights are for, and the weight
-- profile picked for them (nil: Default).
local function Current()
    local p = ns.GetProfile()
    local setup = ns.WeightSetup(p)
    return p, setup, WP.Resolve(p.classFile, p.spec, setup)
end

local function RangeText(from, to)
    return string.format(L["Levels %d-%d"], from, to)
end

---------------------------------------------------------------- icon picker

local picker
local PICK = 26 -- an icon in the picker
local PICK_COLS = 8

-- The icon picker under the icon button: the class's spec icons, then its
-- abilities' (WP.ICONS), then a few for any class. A click picks one for the
-- profile (its own spec's icon: none, the default) and closes it.
local function IconPicker()
    if picker then return picker end
    picker = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    if T.Classic() then W.Window(picker, true) else W.Backdrop(picker, 0.05, 0.05, 0.05, 0.97) end
    picker:SetFrameStrata("DIALOG")
    picker:EnableMouse(true)
    picker.heads, picker.tiles = {}, {}
    local function Head(i)
        local h = picker.heads[i]
        if not h then
            h = picker:CreateFontString(nil, "OVERLAY", W.LabelFont())
            picker.heads[i] = h
        end
        return h
    end
    local function Tile(i)
        local b = picker.tiles[i]
        if b then return b end
        b = CreateFrame("Button", nil, picker, "BackdropTemplate")
        b:SetSize(PICK, PICK)
        W.Backdrop(b, 0, 0, 0, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64)
        W.AddHighlight(b)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.name or "")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        picker.tiles[i] = b
        return b
    end
    picker.Fill = function()
        local p, setup, prof = Current()
        if not prof then return picker:Hide() end
        local current = WP.IconTexture(p.classFile, p.spec, prof.icon)
        local inset = T.Classic() and 14 or 8
        local y, n, h = inset, 0, 0
        local function Section(title, entries)
            h = h + 1
            local head = Head(h)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", picker, "TOPLEFT", inset, -y)
            head:SetText(title)
            head:Show()
            y = y + 16
            for i, e in ipairs(entries) do
                n = n + 1
                local b = Tile(n)
                local col, row = (i - 1) % PICK_COLS, math.floor((i - 1) / PICK_COLS)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", picker, "TOPLEFT", inset + col * (PICK + 4), -(y + row * (PICK + 4)))
                b.icon:SetTexture(e.texture)
                b.name = e.name
                if e.texture == current then
                    b:SetBackdropBorderColor(T.Accent())
                else
                    b:SetBackdropBorderColor(T.BORDER[1], T.BORDER[2], T.BORDER[3], 1)
                end
                b:SetScript("OnClick", function()
                    prof.icon = e.icon
                    picker:Hide()
                    UI.Refresh()
                end)
                b:Show()
            end
            y = y + math.ceil(#entries / PICK_COLS) * (PICK + 4) + 6
        end
        local specs = {}
        for _, spec in ipairs(ns.Specs[p.classFile] or {}) do
            specs[#specs + 1] = { texture = ns.SpecIconPath(p.classFile, spec), name = ns.SpecLabel(spec, p.classFile),
                                  icon = spec ~= p.spec and ("spec:" .. spec) or nil }
        end
        Section(L["Specs"], specs)
        local class = {}
        for _, e in ipairs(WP.ICONS[p.classFile] or {}) do
            class[#class + 1] = { texture = e[2], name = ns.SpellName(e[1], ""), icon = e[2] }
        end
        Section(ClassName(p.classFile), class)
        local other = {}
        for _, e in ipairs(WP.OTHER_ICONS) do other[#other + 1] = { texture = e[1], name = L[e[2]], icon = e[1] } end
        Section(L["Other"], other)
        for i = h + 1, #picker.heads do picker.heads[i]:Hide() end
        for i = n + 1, #picker.tiles do picker.tiles[i]:Hide() end
        picker:SetSize(2 * inset + PICK_COLS * (PICK + 4) - 4, y + inset - 6)
    end
    picker:Hide()
    picker:SetScript("OnHide", function() if tour then ShowTour() end end) -- (back from under it)
    return picker
end

---------------------------------------------------------------- dialogs

-- A dialog over the whole panel (Import, Export): its own title band and
-- close button. Returns it, with f.body (where its contents go, from its top
-- left: x, y).
local function Dialog(title)
    local f = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    f:SetAllPoints(panel)
    f:SetFrameLevel(panel:GetFrameLevel() + 20)
    -- (solid: the panel under it would show through the opacity setting)
    if T.Classic() then W.Window(f) else W.Backdrop(f, T.WINDOW[1], T.WINDOW[2], T.WINDOW[3], 1) end
    f:EnableMouse(true)
    W.TitleBand(f, title, "WildGearFontNormal", true)
    local close = W.CloseButton(f, function() f:Hide() end)
    if not T.Classic() then close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6) end
    f.inset = W.Inset()
    f.top = W.TITLE_HEIGHT + 10 + f.inset
    f:Hide()
    -- (the tour's box, a layer above the panel, steps aside while it's open)
    f:SetScript("OnShow", function() if tour then W.HideCoach() end end)
    f:SetScript("OnHide", function() if tour then ShowTour() end end)
    return f
end

-- A box for long text: a multi-line edit box in a framed area `height` tall.
local function TextArea(parent, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(height)
    if T.Classic() then W.Box(frame) else W.Fill(frame, T.FIELD[1], T.FIELD[2], T.FIELD[3]) end
    local box = CreateFrame("EditBox", nil, frame)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(WildGearFontHighlightSmall)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
    box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5)
    box:SetHeight(height - 10)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function() box:SetFocus() end)
    frame.box = box
    return frame
end

-- The setup labels for class/spec's setups (all of them, whatever the level).
local function SetupOptions(classFile, spec, selected)
    local out = {}
    local p = { classFile = classFile, spec = spec, level = ns.MAX_LEVEL }
    for _, key in ipairs(ns.SpecSetups(classFile, spec)) do
        out[#out + 1] = { text = ns.WeaponSetupLabel(p, key), short = ns.WeaponSetupLabel(p, key, true),
                          value = key, selected = key == selected }
    end
    return out
end

local importDialog
local function ImportDialog()
    if importDialog then return importDialog end
    local f = Dialog(L["Import stat weights"])
    local x = PAD + f.inset
    local width = panel:GetWidth() - 2 * x
    f.area = TextArea(f, 96)
    f.area:SetPoint("TOPLEFT", f, "TOPLEFT", x, -f.top)
    f.area:SetPoint("RIGHT", f, "RIGHT", -x, 0)

    local nameLabel = f:CreateFontString(nil, "OVERLAY", W.LabelFont())
    nameLabel:SetPoint("TOPLEFT", f.area, "BOTTOMLEFT", 0, -16)
    nameLabel:SetText(L["Name"])
    f.name = W.EditBox(f, 180, 22)
    f.name:SetPoint("LEFT", nameLabel, "LEFT", 46, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", -x, 0)
    f.name:SetMaxLetters(60)

    local forLabel = f:CreateFontString(nil, "OVERLAY", W.LabelFont())
    forLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -20)
    forLabel:SetText(L["For"])
    f.class = f:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    f.class:SetPoint("LEFT", forLabel, "LEFT", 46, 0)
    f.spec = W.Selector(f, {
        width = 110,
        options = function()
            local out = {}
            for _, spec in ipairs(f.reading and ns.Specs[f.classFile] or {}) do
                out[#out + 1] = { text = ns.Tooltip.SpecLabel({ classFile = f.classFile }, spec), value = spec,
                                  selected = spec == f.specKey }
            end
            return out
        end,
        set = function(spec)
            f.specKey = spec
            f.setup = ns.SpecSetups(f.classFile, spec)[1]
            f.Refresh()
        end,
        fallback = function() return "" end,
    })
    f.spec:SetPoint("LEFT", f.class, "RIGHT", 8, 9)
    f.setupBox = W.Selector(f, {
        width = 110,
        options = function() return f.reading and SetupOptions(f.classFile, f.specKey, f.setup) or {} end,
        set = function(setup)
            f.setup = setup
            f.Refresh()
        end,
        fallback = function() return "" end,
    })
    f.setupBox:SetPoint("LEFT", f.spec, "RIGHT", 6, 0)
    f.setupBox:SetPoint("RIGHT", f, "RIGHT", -x, 0)

    f.info = f:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    f.info:SetPoint("TOPLEFT", forLabel, "BOTTOMLEFT", 0, -18)
    f.info:SetPoint("RIGHT", f, "RIGHT", -x, 0)
    f.info:SetJustifyH("LEFT")
    f.info:SetSpacing(2)

    f.go = W.FitButton(W.FlatButton(f, L["Import"], 80, 22))
    f.go:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -x, 10 + f.inset)
    f.go:SetScript("OnClick", function()
        if not f.brackets then return end
        local prof = WP.Import(f.classFile, f.specKey, f.setup, f.name:GetText(), f.brackets, f.reading.icon)
        f:Hide()
        local p, setup = Current()
        if not (p.classFile == f.classFile and p.spec == f.specKey and WP.SetupKey(p.classFile, p.spec, setup)
                == WP.SetupKey(f.classFile, f.specKey, f.setup)) then
            ns.Printf(L["Saved %s for %s."], prof.name, ClassColored(f.classFile, ClassName(f.classFile)) .. " "
                .. ns.SpecLabel(f.specKey, f.classFile) .. " · " .. ns.WeaponSetups[WP.SetupKey(f.classFile,
                f.specKey, f.setup)].label)
        end
        UI.Refresh()
    end)

    -- Reads the pasted text and fills in the rest.
    local function Read()
        local reading, err = WP.Parse(f.area.box:GetText())
        f.reading, f.error = reading, err
        if reading then
            local p, setup = Current()
            f.classFile = reading.classFile or p.classFile
            f.specKey = reading.spec or (f.classFile == p.classFile and p.spec) or ns.Specs[f.classFile][1]
            f.setup = reading.setup or (f.classFile == p.classFile and f.specKey == p.spec and setup)
                or ns.SpecSetups(f.classFile, f.specKey)[1]
            f.setup = WP.SetupKey(f.classFile, f.specKey, f.setup)
            f.name:SetText(WP.CleanName(reading.name))
        end
        f.Refresh()
    end
    f.area.box:SetScript("OnTextChanged", function(_, user)
        if user then Read() end
    end)

    -- The rest as the reading says: the class, the selectors, what it will
    -- import (Pawn's: scaled, stats skipped), the Import button.
    f.Refresh = function()
        local reading = f.reading
        f.brackets = nil
        local lines = {}
        if reading then
            local factor, anchor
            f.brackets, factor, anchor = WP.Build(reading, f.classFile, f.specKey, f.setup, Current().level)
            f.class:SetText(ClassColored(f.classFile, ClassName(f.classFile)))
            local first = reading.format == "pawn" and L["Pawn string"] or L["WildGear string"]
            if factor then
                local label = anchor
                for _, s in ipairs(ns.WeightStats) do
                    if s.key == anchor then label = s.label end
                end
                local scale = WP.Format(factor)
                first = first .. " · " .. string.format(L["scaled x%s so %s = %s"], scale, label,
                    WP.Format(WP.InUse(f.classFile, f.specKey, Current().level, f.setup, "default")[anchor] or 1))
            end
            lines[1] = first
            if #reading.skipped > 0 then
                local shown = {}
                for i = 1, math.min(6, #reading.skipped) do shown[i] = reading.skipped[i] end
                lines[2] = string.format(L["Skipped: %s"], table.concat(shown, ", ")
                    .. (#reading.skipped > 6 and ", …" or ""))
            end
            if #f.brackets > 1 then lines[#lines + 1] = L["Its weights change with level, so they can't be edited."] end
        else
            f.class:SetText("")
            if f.error and f.area.box:GetText() ~= "" then lines[1] = RED .. f.error .. "|r" end
        end
        f.info:SetText(table.concat(lines, "\n"))
        f.spec.Update()
        f.setupBox.Update()
        f.spec.SetEnabled(reading ~= nil)
        f.setupBox.SetEnabled(reading ~= nil)
        if f.brackets then f.go:Enable() W.SetActive(f.go, true) else f.go:Disable() W.SetActive(f.go, false) end
    end

    f:HookScript("OnShow", function() -- (after Dialog's)
        f.area.box:SetText("")
        f.name:SetText("")
        f.reading, f.error = nil, nil
        f.Refresh()
        f.area.box:SetFocus()
    end)
    importDialog = f
    return f
end

local exportDialog
local function ExportDialog()
    if exportDialog then return exportDialog end
    local f = Dialog(L["Export stat weights"])
    local x = PAD + f.inset
    f.what = f:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    f.what:SetPoint("TOPLEFT", f, "TOPLEFT", x, -f.top)
    f.what:SetPoint("RIGHT", f, "RIGHT", -x, 0)
    f.what:SetJustifyH("LEFT")
    f.format = "flb"
    f.choice = W.Segmented(f, nil, { { key = "flb", text = "WildGear" }, { key = "pawn", text = "Pawn" } },
        130, function(key)
            f.format = key
            f.Fill(true)
        end)
    f.choice:SetPoint("TOPLEFT", f.what, "BOTTOMLEFT", 0, -10)
    f.area = TextArea(f, 150)
    f.area:SetPoint("TOPLEFT", f.choice, "BOTTOMLEFT", 0, -10)
    f.area:SetPoint("RIGHT", f, "RIGHT", -x, 0)
    f.area.box:SetScript("OnTextChanged", function(self, user)
        if user then -- (it can't be changed: only copied)
            self:SetText(f.text or "")
            self:HighlightText()
        end
    end)
    f.area.box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.hint = f:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    f.hint:SetPoint("TOPLEFT", f.area, "BOTTOMLEFT", 0, -8)
    f.hint:SetText(L["Press Ctrl+C to copy"])

    -- The string for what's picked now; `focus` (on opening, a format picked):
    -- selected, in focus to copy. (The panel's refreshes leave the focus be:
    -- they come with many of the game's events, and would take it from chat.)
    f.Fill = function(focus)
        local p, setup, prof = Current()
        local name = prof and prof.name or L["Default"]
        f.what:SetText(name .. GREY .. " · |r" .. ClassColored(p.classFile, ClassName(p.classFile)) .. " "
            .. ns.SpecLabel(p.spec, p.classFile) .. GREY .. " · " .. ns.WeaponSetupLabel(p, setup, true) .. "|r")
        f.choice.Update(f.format)
        local text
        if f.format == "pawn" then
            text = WP.ExportPawn(p.classFile, p.spec, p.level, setup, prof)
        else
            text = WP.Export(p.classFile, p.spec, p.level, setup, prof)
        end
        if text ~= f.text or focus then
            f.text = text
            f.area.box:SetText(text)
            f.area.box:HighlightText()
        end
        if focus then f.area.box:SetFocus() end
    end
    f:HookScript("OnShow", function() f.Fill(true) end) -- (after Dialog's)
    exportDialog = f
    return f
end

---------------------------------------------------------------- tour

-- Once (for all characters: ns.db.weightsTourSeen), from the first profile
-- you make (Edit, New): a box by one thing at a time, Next going on, Skip
-- ending it, as closing the panel or going back to Default does.
--   1 the name box: name it, then Enter (Escape: no profile, so no tour till the next one)
--   2 the icon button (a click opens the picker, the box going under it: on to 3)
--   3 the weights: over the right column's top box, the rows left clear
--   4 the weapon setup line: the weights are for this class, spec and setup alone
--   5 the window's Talent spec box: another spec, or weapon set, has its own
local TOUR_STEPS = 5

local function EndTour()
    tour = nil
    W.HideCoach()
end

local function GoTour(step)
    tour = step
    if step > 1 then ns.db.weightsTourSeen = true end
    ShowTour()
end

ShowTour = function()
    if not tour then return end
    if not panel:IsVisible() then return EndTour() end
    if picker and picker:IsShown() then return W.HideCoach() end -- (back as it closes)
    for _, d in ipairs({ importDialog, exportDialog }) do
        if d and d:IsShown() then return W.HideCoach() end -- (likewise: Dialog)
    end
    local p, setup, prof = Current()
    local opts = { step = tour .. "/" .. TOUR_STEPS, left = true, next = L["Next"], skip = L["Skip"],
                   onNext = function() GoTour(tour + 1) end, onSkip = EndTour }
    if tour == 1 then
        -- (Either makes the profile first, as Enter does: the name box goes as
        -- the click starts, or else at the button's click; the button then
        -- goes on (naming). Skip keeps it, and the tour counts as seen.)
        local function Name()
            if not panel.nameBox:IsShown() then return end
            panel.nameBox.naming = true
            panel.nameBox:ClearFocus()
            panel.nameBox.naming = nil
        end
        opts.onNext = function()
            Name()
            if tourMade then GoTour(2) else EndTour() end
        end
        opts.onSkip = function()
            Name()
            if tourMade then ns.db.weightsTourSeen = true end
            EndTour()
        end
        -- (by the selector, where the name box is: it stays as the name box goes)
        W.Coach(panel.profile.value, L["Name your profile, then press Enter."], opts)
    elseif tour == 2 then
        opts.spot = true -- (a small button, easy to miss)
        W.Coach(panel.icon, L["Click to pick its icon."], opts)
    elseif tour == 3 then
        if WP.Locked(prof) then return GoTour(4) end -- (a copy of imported brackets: its boxes don't take typing)
        local box
        for _, row in ipairs(panel.rows) do
            if row.col == 1 and row.line == 0 then box = row.box end
        end
        opts.above, opts.left = true, false
        W.Coach(box, L["Type in a box to change a weight. Changed ones turn orange."], opts)
    elseif tour == 4 then
        W.Coach(panel.range, string.format(L["These weights are only for %s with %s."],
            ClassColored(p.classFile, p.className) .. " " .. ns.SpecLabel(p.spec, p.classFile),
            ns.WeaponSetupLabel(p, setup)), opts)
    else
        local box = UI.SpecBox()
        if not box then return EndTour() end
        opts.next, opts.skip, opts.onNext = L["Done"], nil, EndTour
        W.Coach(box, string.format(L["Each spec and weapon set has its own weights. For another, change %s or %s here."],
            L["Talent spec"], L["Weapons"]), opts)
    end
end

---------------------------------------------------------------- panel

-- The weight a row shows: what ranks now (a profile's, or the defaults at your
-- level). Off-hand DPS is 0 for a spec that never holds an off-hand weapon.
local function Shown(p, setup, key, stats)
    local v = stats[key]
    if v == nil and key == "ohDps" and ns.HoldsOffHandWeapon(p.classFile, p.spec) then v = ns.OffDpsWeight(stats) end
    return v or 0
end

-- Fills the panel for the window's profile.
function WP_PANEL.Update()
    if not (panel and panel:IsShown()) then return end
    local p, setup, prof = Current()
    panel.sub:SetText(ClassColored(p.classFile, p.className) .. " " .. ns.SpecLabel(p.spec, p.classFile))
    local from, to = WP.Range(p.classFile, p.spec, p.level, setup)
    panel.range:SetText(ns.WeaponSetupLabel(p, setup, true) .. " · " .. RangeText(from, to))
    panel.icon.icon:SetTexture(WP.IconTexture(p.classFile, p.spec, prof and prof.icon))
    panel.icon:SetEnabled(prof ~= nil) -- (Default keeps its spec's icon)
    panel.profile.Update()
    local stats = WP.InUse(p.classFile, p.spec, p.level, setup) or {}
    local defaults = WP.InUse(p.classFile, p.spec, p.level, setup, "default") or {}
    -- (Default can't be changed: Edit copies it first; nor a profile with brackets)
    local locked = not prof or WP.Locked(prof)
    for _, row in ipairs(panel.rows) do
        local v = Shown(p, setup, row.key, stats)
        local differs = prof and WP.Format(v) ~= WP.Format(Shown(p, setup, row.key, defaults))
        row.label:SetText(differs and (ORANGE .. row.labelText .. "|r") or row.labelText)
        if not row.box:HasFocus() then row.box:SetText(WP.Format(v)) end
        row.box:EnableMouse(not locked)
        row.box:SetAlpha(locked and 0.6 or 1)
    end
    for _, b in ipairs({ panel.reset, panel.rename, panel.delete }) do
        if prof then b:Show() else b:Hide() end
    end
    if prof then panel.edit:Hide() else panel.edit:Show() end
    if tour and tour > 1 and not prof then EndTour() end -- (back on Default, or another spec's)
    if picker and picker:IsShown() then picker.Fill() end
    if exportDialog and exportDialog:IsShown() then exportDialog.Fill(false) end
end

local function CommitWeight(box)
    local p, setup = Current()
    local value = tonumber(box:GetText())
    local stats = WP.InUse(p.classFile, p.spec, p.level, setup) or {}
    if value and math.abs(value) <= 100000 and WP.Format(value) ~= WP.Format(Shown(p, setup, box.key, stats))
        and WP.SetWeight(p.classFile, p.spec, p.level, setup, box.key, value) then
        UI.Refresh()
    else
        box:SetText(WP.Format(Shown(p, setup, box.key, stats)))
    end
end

-- Puts the name box over the selector, `text` in it, selected: to name the
-- picked profile (`mode` "rename"), or a new one before it's made ("new":
-- Edit on Default, New), a copy of what's picked. Enter or a click elsewhere
-- goes ahead, Escape doesn't.
local function StartName(mode, text)
    -- (what it's for, kept: the window's spec or weapons may change meanwhile)
    local p, setup, prof = Current()
    panel.nameBox.target = { classFile = p.classFile, spec = p.spec, level = p.level, setup = setup, prof = prof }
    panel.nameBox.mode = mode
    panel.nameBox:SetText(text)
    panel.nameBox:Show()
    panel.nameBox:SetFocus()
    panel.nameBox:HighlightText()
end

local function StartRename()
    local _, _, prof = Current()
    if prof then StartName("rename", prof.name) end
end

local function StartNew()
    local _, _, prof = Current()
    StartName("new", prof and prof.name or L["Custom"])
    if not ns.db.weightsTourSeen then GoTour(1) end
end

local function ProfileOptions()
    local p, setup, prof = Current()
    local out = {}
    local from, to = ns.DefaultWeightRange(p.classFile, p.spec, p.level, setup)
    out[1] = { text = WP.Icon(p.classFile, p.spec, nil) .. " " .. L["Default"] .. "  " .. GREY .. RangeText(from, to)
        .. "|r", short = L["Default"], value = "default", selected = prof == nil }
    for _, e in ipairs(WP.List(p.classFile, p.spec, setup)) do
        local a, b = WP.Range(p.classFile, p.spec, p.level, setup, e.id)
        out[#out + 1] = { text = WP.Icon(p.classFile, p.spec, e) .. " " .. e.name .. "  " .. GREY .. RangeText(a, b)
            .. "|r", short = e.name, value = e.id, selected = prof == e }
    end
    return out
end

function WP_PANEL.Create()
    local frame = UI.Frame()
    local rowsPerCol = math.ceil(#ns.WeightStats / COLS)
    local inset = W.Inset()
    local top = W.TITLE_HEIGHT + 84 + inset -- below the title band, the class/spec, profile and range lines
    panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    panel:SetSize(COLS * COL_WIDTH + 2 * PAD + 2 * inset, top + rowsPerCol * ROW + 40 + inset)
    panel:SetClampedToScreen(true) -- placed by UI.DockSides
    W.Window(panel)
    panel:EnableMouse(true)
    local title, band = W.TitleBand(panel, L["Stat weights"], "WildGearFontNormal")
    W.PanelIcon(title, band, "Weights") -- (Modern: a scale before the title)
    local x = PAD + inset

    panel.sub = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
    panel.sub:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(W.TITLE_HEIGHT + 8 + inset))
    panel.sub:SetJustifyH("LEFT")

    -- The profile row: icon button, selector, New, Import, Export.
    local rowY = -(W.TITLE_HEIGHT + 8 + inset + 18 + 14)
    panel.icon = W.FlatButton(panel, "", ICON, ICON)
    panel.icon:SetPoint("LEFT", panel, "TOPLEFT", x, rowY)
    panel.icon.icon = panel.icon:CreateTexture(nil, "ARTWORK")
    panel.icon.icon:SetPoint("TOPLEFT", 2, -2)
    panel.icon.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    panel.icon.icon:SetTexCoord(5 / 64, 59 / 64, 5 / 64, 59 / 64)
    panel.icon:SetScript("OnClick", function(self)
        local f = IconPicker()
        if f:IsShown() then return f:Hide() end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        f.Fill()
        f:Show()
        if tour then -- (the tour's box goes, back as it closes: past the icon step)
            if tour == 2 then tour = 3 end
            W.HideCoach()
        end
    end)
    panel.export = W.FitButton(W.FlatButton(panel, L["Export"], 50, 22))
    panel.export:SetPoint("RIGHT", panel, "TOPRIGHT", -x, rowY)
    panel.export:SetScript("OnClick", function() ExportDialog():Show() end)
    panel.import = W.FitButton(W.FlatButton(panel, L["Import"], 50, 22))
    panel.import:SetPoint("RIGHT", panel.export, "LEFT", -4, 0)
    panel.import:SetScript("OnClick", function() ImportDialog():Show() end)
    panel.new = W.FitButton(W.FlatButton(panel, L["New"], 40, 22))
    panel.new:SetPoint("RIGHT", panel.import, "LEFT", -4, 0)
    panel.new:SetScript("OnClick", StartNew)
    panel.profile = W.Selector(panel, {
        width = 100, options = ProfileOptions,
        set = function(value)
            local p, setup = Current()
            WP.Pick(p.classFile, p.spec, setup, value ~= "default" and value or nil)
            UI.Refresh()
        end,
    })
    panel.profile:SetPoint("LEFT", panel.icon, "RIGHT", 4, 9)
    panel.profile:SetPoint("RIGHT", panel.new, "LEFT", -6, 9)
    -- (the selector's box: its value button, whose bubble and name box go on it)
    for _, child in ipairs({ panel.profile:GetChildren() }) do
        if child:IsObjectType("Button") then panel.profile.value = child end
    end
    panel.profile.value = panel.profile.value or panel.profile
    panel.nameBox = W.EditBox(panel, 100, 22)
    panel.nameBox:SetAllPoints(panel.profile.value)
    panel.nameBox:SetFrameLevel(panel.profile.value:GetFrameLevel() + 5)
    panel.nameBox:SetMaxLetters(60)
    -- (the selector's name hidden under it: Classic's box is see-through)
    panel.nameBox:SetScript("OnShow", function()
        if panel.profile.value.text then panel.profile.value.text:Hide() end
    end)
    panel.nameBox:SetScript("OnHide", function()
        if panel.profile.value.text then panel.profile.value.text:Show() end
    end)
    -- (Enter or a click elsewhere goes ahead: StartName; Escape doesn't)
    panel.nameBox:SetScript("OnEscapePressed", function(self)
        self.cancel = true
        self:ClearFocus()
    end)
    panel.nameBox:HookScript("OnEditFocusLost", function(self)
        if not self:IsShown() then return end
        local t = self.target
        local made
        if t and not self.cancel then
            if self.mode == "new" then
                made = WP.New(t.classFile, t.spec, t.level, t.setup, self:GetText())
            elseif t.prof then
                WP.Rename(t.classFile, t.spec, t.setup, t.prof, self:GetText())
            end
        end
        self.cancel = nil
        self:Hide()
        UI.Refresh()
        if tour == 1 then
            tourMade = made
            if not made then
                EndTour()
            elseif not (self.naming or W.CoachUnderMouse()) then -- (by the tour's box: its button goes on)
                GoTour(2)
            end
        end
    end)
    panel.nameBox:Hide()

    panel.range = panel:CreateFontString(nil, "OVERLAY", "WildGearFontDisableSmall")
    panel.range:SetPoint("TOPLEFT", panel, "TOPLEFT", x, rowY - 18)
    panel.range:SetJustifyH("LEFT")

    panel.rows = {}
    local labels = {}
    for i, stat in ipairs(ns.WeightStats) do
        local row = { key = stat.key, labelText = stat.label,
            col = math.floor((i - 1) / rowsPerCol), line = (i - 1) % rowsPerCol }
        row.label = panel:CreateFontString(nil, "OVERLAY", "WildGearFontHighlightSmall")
        row.label:SetJustifyH("LEFT") -- (placed below)
        labels[i] = stat.label
        local box = W.EditBox(panel, 46, 17)
        box:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
        box:SetJustifyH("RIGHT") -- (the numbers line up)
        box:SetMaxLetters(7)
        box.key = stat.key
        box:HookScript("OnEditFocusLost", CommitWeight)
        box:SetScript("OnEscapePressed", function(self)
            local p, setup = Current()
            self:SetText(WP.Format(Shown(p, setup, self.key, WP.InUse(p.classFile, p.spec, p.level, setup) or {})))
            self:ClearFocus()
        end)
        row.box = box
        panel.rows[i] = row
    end
    -- The labels fit the longest one in the client's language and the text
    -- size, the boxes the longest number they take (7 letters, insets 6 + 6);
    -- the panel widens with them.
    T.Track(function()
        local labelWidth = math.min(150, math.max(88,
            math.ceil(W.TextWidth("WildGearFontHighlightSmall", labels)) + 2))
        local boxWidth = math.max(46,
            math.ceil(W.TextWidth("WildGearFontHighlightSmall", { "-88.888" })) + 14)
        local colWidth = COL_WIDTH + labelWidth - 88 + boxWidth - 46
        for _, row in ipairs(panel.rows) do
            row.label:SetPoint("TOPLEFT", panel, "TOPLEFT", x + row.col * colWidth, -top - row.line * ROW)
            row.label:SetWidth(labelWidth)
            row.box:SetWidth(boxWidth)
        end
        panel:SetWidth(COLS * colWidth + 2 * PAD + 2 * inset)
    end)

    local bottom = 8 + inset -- (Classic: clear of the thick border)
    panel.reset = W.FitButton(W.FlatButton(panel, L["Reset"], 60, 22))
    panel.reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, bottom)
    panel.reset:SetScript("OnClick", function()
        local p, setup, prof = Current()
        if prof then WP.Reset(p.classFile, p.spec, p.level, setup, prof) end
        UI.Refresh()
    end)
    panel.rename = W.FitButton(W.FlatButton(panel, L["Rename"], 60, 22))
    panel.rename:SetPoint("LEFT", panel.reset, "RIGHT", 4, 0)
    panel.rename:SetScript("OnClick", StartRename)
    -- (on Default, in Reset's place: a copy to change, asked first, then named)
    panel.edit = W.FitButton(W.FlatButton(panel, L["Edit"], 60, 22))
    panel.edit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", x, bottom)
    panel.edit:SetScript("OnClick", function(self)
        W.Confirm(self, L["Default can't be changed. Create a profile from it to edit?"], L["Create"], L["Cancel"],
            StartNew)
    end)
    panel.delete = W.FitButton(W.FlatButton(panel, L["Delete"], 60, 22))
    panel.delete:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -x, bottom)
    panel.delete:SetScript("OnClick", function(self)
        local _, _, prof = Current()
        if not prof then return end
        W.Confirm(self, string.format(L["Delete %s?"], prof.name), L["Delete"], L["Cancel"], function()
            local p, setup, still = Current()
            if still == prof then WP.Delete(p.classFile, p.spec, setup, prof.id) end
            UI.Refresh()
        end)
    end)

    panel:SetScript("OnShow", function(self)
        UI.ClaimSide(self)
        WP_PANEL.Update()
    end)
    panel:SetScript("OnHide", function()
        if picker then picker:Hide() end
        if importDialog then importDialog:Hide() end
        if exportDialog then exportDialog:Hide() end
        EndTour()
    end)
    panel:Hide()
    return panel
end

-- Opens the window if it's closed, then the panel (What's new's notes).
function WP_PANEL.Show()
    if not (UI.Frame() and UI.Frame():IsShown()) then UI.Toggle() end
    if panel and not panel:IsShown() then panel:Show() end
end

-- The panel, and its Import and Export dialogs and icon picker once made (the smoketest's).
function WP_PANEL.Parts()
    return panel, importDialog, exportDialog, picker
end
