-- Spy for Forever: the options window, built with the game's own templates.
--
-- A Blizzard panel (ButtonFrameTemplate) with the categories on the left, like the old
-- Interface Options, and the settings on the right: classic check boxes, sliders, the
-- game's dropdowns, input boxes and buttons. Requested by the user instead of the Ace3
-- dialog.
--
-- The pages are drawn from Spy.options, the same table the Ace3 dialog and the game's
-- Settings panel use, so every setting is here once and stays in sync. Only what that
-- table uses is supported: toggle, range, select, multiselect, input, execute,
-- description, header and inline groups, with get/set/handler/disabled/hidden inherited
-- from the parent groups as AceConfig does.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local Guard = Spy.ForeverGuard

local WIDTH, HEIGHT = 840, 600
local LIST_WIDTH = 176
local UNIT = 170                 -- AceConfig's width for a normal control
local GAP = 8

local OW = {}
Spy.OptionsUI = OW

-- AceConfig helpers ------------------------------------------------------------------

local function orderOf(option)
	local order = option.order
	if type(order) == "function" then
		local ok, value = pcall(order)
		order = ok and value or nil
	end
	order = tonumber(order) or 100
	if order < 0 then order = 100000 + order end
	return order
end

-- The options of a group, in AceConfig's order.
local function sortedKeys(group)
	local keys = {}
	for key in pairs(group.args or {}) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		local oa, ob = orderOf(group.args[a]), orderOf(group.args[b])
		if oa ~= ob then return oa < ob end
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- path = { group, ..., option } tables; keys = their keys. Builds AceConfig's info.
local function makeInfo(path, keys)
	local option = path[#path]
	local info = { options = Spy.options, option = option, type = option.type, arg = option.arg,
		uiType = "dialog", uiName = "Spy", appName = "Spy" }
	for i, key in ipairs(keys) do info[i] = key end
	for i = #path, 1, -1 do
		if path[i].handler then info.handler = path[i].handler break end
	end
	return info
end

-- A field, inherited from the parent groups when the option does not set it.
local function inherited(path, field)
	for i = #path, 1, -1 do
		local value = path[i][field]
		if value ~= nil then return value end
	end
	return Spy.options[field]
end

-- Calls a function or a handler method the AceConfig way.
local function call(value, info, ...)
	if type(value) == "function" then
		return value(info, ...)
	elseif type(value) == "string" and info.handler and type(info.handler[value]) == "function" then
		return info.handler[value](info.handler, info, ...)
	end
	return value
end

local function resolve(path, keys, field, inherit)
	local value
	if inherit then value = inherited(path, field) else value = path[#path][field] end
	if type(value) == "function" or (type(value) == "string" and (field == "values" or field == "disabled" or field == "hidden")) then
		local info = makeInfo(path, keys)
		local ok, result = pcall(call, value, info)
		if ok then return result end
		OW.lastError = field .. ": " .. tostring(result)
		return nil
	end
	return value
end

local function textOf(path, keys, field)
	local value = resolve(path, keys, field, false)
	if value == nil then return "" end
	return tostring(value)
end

local function isHidden(path, keys)
	local option = path[#path]
	if option.dialogHidden or option.guiHidden then return true end
	return resolve(path, keys, "hidden", true) == true
end

local function isDisabled(path, keys)
	return resolve(path, keys, "disabled", true) == true
end

local function getValue(path, keys, ...)
	local get = inherited(path, "get")
	if get == nil then return nil end
	local ok, a, b, c, d = pcall(call, get, makeInfo(path, keys), ...)
	if not ok then
		OW.lastError = "get: " .. tostring(a)
		return nil
	end
	return a, b, c, d
end

-- Sets a value, then redraws the page: other settings may depend on it.
local function setValue(path, keys, ...)
	local option = path[#path]
	local info = makeInfo(path, keys)
	local validate = inherited(path, "validate")
	if validate then
		local ok, result = pcall(call, validate, info, ...)
		if ok and type(result) == "string" then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. result)
			OW:Redraw()
			return
		end
	end
	local setter = option.type == "execute" and option.func or inherited(path, "set")
	local ok, err = pcall(call, setter, info, ...)
	if not ok then
		OW.lastError = "set: " .. tostring(err)
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["ForeverError"])
	end
	local registry = LibStub("AceConfigRegistry-3.0", true)
	OW.selfNotify = true
	if registry then registry:NotifyChange("Spy") end
	OW.selfNotify = nil
	OW:Redraw()
	if Spy.RefreshPreview then Spy:RefreshPreview() end
end

local function confirmThen(path, keys, action)
	local option = path[#path]
	local confirm = option.confirm
	if not confirm then
		action()
		return
	end
	local text = option.confirmText or textOf(path, keys, "name")
	if type(confirm) == "function" or type(confirm) == "string" then
		local value = resolve(path, keys, "confirm", false)
		if value == false or value == nil then action() return end
		if type(value) == "string" then text = value end
	end
	StaticPopupDialogs["SPY_FOREVER_CONFIRM"] = {
		text = text, button1 = YES or "Yes", button2 = NO or "No",
		OnAccept = function() action() end,
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	}
	StaticPopup_Show("SPY_FOREVER_CONFIRM")
end

local function showTooltip(owner, title, text)
	if not text or text == "" then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title or "", 1, 0.82, 0, 1, true)
	GameTooltip:AddLine(text, 1, 1, 1, true)
	GameTooltip:Show()
end

local function hideTooltip() GameTooltip:Hide() end

-- Widget pools: a redraw hands every widget back and takes them again.

local pools = {}

local function acquire(kind, create)
	local pool = pools[kind]
	if not pool then
		pool = { free = {}, used = {} }
		pools[kind] = pool
	end
	local widget = table.remove(pool.free)
	if not widget then widget = create() end
	pool.used[#pool.used + 1] = widget
	widget:SetParent(OW.content)
	widget:ClearAllPoints()
	widget:Show()
	return widget
end

local function releaseAll()
	for _, pool in pairs(pools) do
		for _, widget in ipairs(pool.used) do
			widget:Hide()
			pool.free[#pool.free + 1] = widget
		end
		pool.used = {}
	end
end

-- Widgets -------------------------------------------------------------------------

local function newLabel(parent, font)
	local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	label:SetJustifyH("LEFT")
	return label
end

-- The classic check box of the old Interface Options.
local function createCheck()
	local check = CreateFrame("CheckButton", nil, OW.content)
	check:SetSize(26, 26)
	check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	check.Label = newLabel(check)
	check.Label:SetPoint("LEFT", check, "RIGHT", 2, 1)
	check:SetScript("OnEnter", function(self) showTooltip(self, self.title, self.tip) end)
	check:SetScript("OnLeave", hideTooltip)
	check:SetScript("OnClick", function(self)
		if self.onToggle then self.onToggle(self:GetChecked() and true or false) end
	end)
	return check
end

local function createSlider()
	local holder = CreateFrame("Frame", nil, OW.content)
	holder:SetSize(UNIT + 20, 48)
	local slider = CreateFrame("Slider", nil, holder, "UISliderTemplateWithLabels")
	slider:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -18)
	slider:SetSize(UNIT, 17)
	slider:SetObeyStepOnDrag(true)
	holder.Slider = slider
	holder.Label = slider.Text or newLabel(holder, "GameFontNormalSmall")
	holder.Label:ClearAllPoints()
	holder.Label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
	holder.Label:SetFontObject("GameFontNormalSmall")
	holder.Value = newLabel(holder, "GameFontHighlightSmall")
	holder.Value:SetPoint("TOP", slider, "BOTTOM", 0, 3)
	slider:SetScript("OnValueChanged", function(self, value, userInput)
		if holder.format then holder.Value:SetText(holder.format(value)) end
		if userInput and holder.onChange then holder.pending = value end
	end)
	slider:SetScript("OnMouseUp", function()
		if holder.pending ~= nil and holder.onChange then
			local value = holder.pending
			holder.pending = nil
			holder.onChange(value)
		end
	end)
	slider:SetScript("OnEnter", function(self) showTooltip(self, holder.title, holder.tip) end)
	slider:SetScript("OnLeave", hideTooltip)
	return holder
end

local function createDropdown()
	local holder = CreateFrame("Frame", nil, OW.content)
	holder:SetSize(UNIT + 30, 48)
	holder.Label = newLabel(holder, "GameFontNormalSmall")
	holder.Label:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, 0)
	local dropdown = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -16)
	dropdown:SetWidth(UNIT + 10)
	holder.Dropdown = dropdown
	dropdown:SetScript("OnEnter", function(self) showTooltip(self, holder.title, holder.tip) end)
	dropdown:SetScript("OnLeave", hideTooltip)
	return holder
end

local function createInput()
	local holder = CreateFrame("Frame", nil, OW.content)
	holder:SetSize(UNIT * 2, 44)
	holder.Label = newLabel(holder, "GameFontNormalSmall")
	holder.Label:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, 0)
	local box = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
	box:SetPoint("TOPLEFT", holder, "TOPLEFT", 8, -16)
	box:SetSize(UNIT * 2 - 80, 22)
	box:SetAutoFocus(false)
	holder.Box = box
	local okay = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
	okay:SetSize(60, 22)
	okay:SetPoint("LEFT", box, "RIGHT", 6, 0)
	okay:SetText(OKAY or "Okay")
	holder.Okay = okay
	local function submit()
		local text = box:GetText() or ""
		box:ClearFocus()
		if holder.onSubmit then holder.onSubmit(text) end
	end
	box:SetScript("OnEnterPressed", submit)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	okay:SetScript("OnClick", submit)
	box:SetScript("OnEnter", function(self) showTooltip(self, holder.title, holder.tip) end)
	box:SetScript("OnLeave", hideTooltip)
	return holder
end

local function createButton()
	local button = CreateFrame("Button", nil, OW.content, "UIPanelButtonTemplate")
	button:SetHeight(22)
	button:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
	button:SetScript("OnEnter", function(self) showTooltip(self, self.title, self.tip) end)
	button:SetScript("OnLeave", hideTooltip)
	return button
end

local function createText()
	local holder = CreateFrame("Frame", nil, OW.content)
	holder.Text = newLabel(holder, "GameFontHighlight")
	holder.Text:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	holder.Text:SetJustifyV("TOP")
	return holder
end

local function createSection()
	local holder = CreateFrame("Frame", nil, OW.content)
	holder:SetHeight(24)
	holder.Title = newLabel(holder, "GameFontNormal")
	holder.Title:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -2)
	holder.Line = holder:CreateTexture(nil, "ARTWORK")
	holder.Line:SetColorTexture(1, 0.82, 0, 0.35)
	holder.Line:SetHeight(1)
	holder.Line:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -18)
	holder.Line:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -18)
	return holder
end

-- Layout ----------------------------------------------------------------------------
-- A flow layout: controls are placed left to right and wrap; "full" width controls take
-- a whole line.

local Flow = {}
Flow.__index = Flow

local function newFlow(x, y, width)
	return setmetatable({ left = x, x = x, y = y, width = width, lineHeight = 0 }, Flow)
end

function Flow:newline()
	if self.x > self.left then
		self.y = self.y - self.lineHeight - GAP
		self.x = self.left
		self.lineHeight = 0
	end
end

function Flow:place(widget, width, height)
	if self.x > self.left and self.x + width > self.left + self.width then
		self:newline()
	end
	widget:SetPoint("TOPLEFT", OW.content, "TOPLEFT", self.x, self.y)
	self.x = self.x + width + GAP
	if height > self.lineHeight then self.lineHeight = height end
end

function Flow:full(widget, height)
	self:newline()
	widget:SetPoint("TOPLEFT", OW.content, "TOPLEFT", self.x, self.y)
	widget:SetWidth(self.width)
	self.y = self.y - height - GAP
end

local function widthOf(option, flow)
	local width = option.width
	if width == "full" then return flow.width end
	if width == "double" then return UNIT * 2 end
	if width == "half" then return UNIT / 2 end
	if type(width) == "number" then return UNIT * width end
	return UNIT
end

-- One option -------------------------------------------------------------------------

local drawGroup

local function drawToggle(path, keys, flow, label, valueOf, onToggle)
	local option = path[#path]
	local check = acquire("check", createCheck)
	check.Label:SetText(label)
	check.title, check.tip = label, textOf(path, keys, "desc")
	check:SetChecked(valueOf() and true or false)
	local disabled = isDisabled(path, keys)
	check:SetEnabled(not disabled)
	check.Label:SetFontObject(disabled and "GameFontDisable" or "GameFontHighlight")
	check.onToggle = onToggle
	local width = math.max(widthOf(option, flow), 30 + (check.Label:GetStringWidth() or 0))
	flow:place(check, math.min(width, flow.width), 26)
end

local function drawOption(path, keys, flow)
	local option = path[#path]
	local kind = option.type
	local name = textOf(path, keys, "name")
	if kind == "toggle" then
		drawToggle(path, keys, flow, name,
			function() return getValue(path, keys) end,
			function(value) setValue(path, keys, value) end)
	elseif kind == "multiselect" then
		local section = acquire("section", createSection)
		section.Title:SetText(name)
		flow:full(section, 22)
		local values = resolve(path, keys, "values", false) or {}
		local order = {}
		for key in pairs(values) do order[#order + 1] = key end
		table.sort(order, function(a, b) return tostring(values[a]) < tostring(values[b]) end)
		for _, key in ipairs(order) do
			drawToggle(path, keys, flow, tostring(values[key]),
				function() return getValue(path, keys, key) end,
				function(value) setValue(path, keys, key, value) end)
		end
		flow:newline()
	elseif kind == "range" then
		local holder = acquire("slider", createSlider)
		local slider = holder.Slider
		local min, max = option.softMin or option.min or 0, option.softMax or option.max or 100
		local step = option.step or option.bigStep or ((max - min) / 100)
		holder.format = function(value)
			if option.isPercent then return ("%d%%"):format(math.floor(value * 100 + 0.5)) end
			if step >= 1 then return tostring(math.floor(value + 0.5)) end
			return ("%.2f"):format(value)
		end
		holder.Label:SetText(name)
		holder.title, holder.tip = name, textOf(path, keys, "desc")
		slider:SetMinMaxValues(min, max)
		slider:SetValueStep(step)
		if slider.Low then slider.Low:SetText(holder.format(min)) end
		if slider.High then slider.High:SetText(holder.format(max)) end
		local value = tonumber((getValue(path, keys))) or min
		holder.onChange = nil
		slider:SetValue(value)
		holder.Value:SetText(holder.format(value))
		holder.onChange = function(newValue) setValue(path, keys, newValue) end
		slider:SetEnabled(not isDisabled(path, keys))
		flow:place(holder, UNIT + 20, 48)
	elseif kind == "select" then
		local holder = acquire("dropdown", createDropdown)
		holder.Label:SetText(name)
		holder.title, holder.tip = name, textOf(path, keys, "desc")
		local values = resolve(path, keys, "values", false) or {}
		local order = {}
		if type(option.sorting) == "table" then
			for _, key in ipairs(option.sorting) do order[#order + 1] = key end
		else
			for key in pairs(values) do order[#order + 1] = key end
			table.sort(order, function(a, b) return tostring(values[a]) < tostring(values[b]) end)
		end
		-- LibSharedMedia lists name -> path: the name is what players read.
		local showKey = option.dialogControl ~= nil
		local dropdown = holder.Dropdown
		dropdown:SetupMenu(function(_, root)
			for _, key in ipairs(order) do
				root:CreateRadio(showKey and tostring(key) or tostring(values[key]),
					function() return getValue(path, keys) == key end,
					function() setValue(path, keys, key) end, key)
			end
		end)
		dropdown:SetEnabled(not isDisabled(path, keys))
		holder.order, holder.values, holder.showKey = order, values, showKey
		flow:place(holder, UNIT + 30, 48)
	elseif kind == "input" then
		local holder = acquire("input", createInput)
		holder.Label:SetText(name)
		holder.title, holder.tip = name, textOf(path, keys, "desc")
		local current = getValue(path, keys)
		holder.Box:SetText(type(current) == "string" and current or "")
		holder.onSubmit = function(text)
			if option.pattern and not text:match(option.pattern) then
				DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. (option.usage or L["InvalidInput"] or "?"))
				return
			end
			setValue(path, keys, text)
		end
		holder.Box:SetEnabled(not isDisabled(path, keys))
		local width = option.width == "full" and flow.width or UNIT * 2
		holder:SetWidth(width)
		holder.Box:SetWidth(width - 80)
		flow:place(holder, width, 44)
	elseif kind == "execute" then
		local button = acquire("button", createButton)
		button:SetText(name)
		button:SetWidth(math.max(110, (button:GetFontString() and button:GetFontString():GetStringWidth() or 60) + 30))
		button.title, button.tip = name, textOf(path, keys, "desc")
		button:SetEnabled(not isDisabled(path, keys))
		button.onClick = function()
			confirmThen(path, keys, function() setValue(path, keys) end)
		end
		flow:place(button, button:GetWidth(), 24)
	elseif kind == "description" then
		local holder = acquire("text", createText)
		local font = "GameFontHighlight"
		if option.fontSize == "large" then font = "GameFontHighlightLarge" elseif option.fontSize == "small" then font = "GameFontHighlightSmall" end
		holder.Text:SetFontObject(font)
		-- AceConfig gives a description the whole line unless it says otherwise.
		local width = flow.width
		if option.width ~= nil and option.width ~= "full" then width = widthOf(option, flow) end
		holder.Text:SetWidth(width)
		holder.Text:SetText(name)
		local height = math.max(12, holder.Text:GetStringHeight() or 12)
		holder:SetSize(width, height)
		if width >= flow.width then
			flow:full(holder, height)
		else
			flow:place(holder, width, height)
		end
	elseif kind == "header" then
		local section = acquire("section", createSection)
		section.Title:SetText(name)
		flow:full(section, 22)
	elseif kind == "group" and option.inline then
		local section = acquire("section", createSection)
		section.Title:SetText(name)
		flow:full(section, 22)
		drawGroup(path, keys, flow)
		flow:newline()
		flow.y = flow.y - 4
	end
end

drawGroup = function(path, keys, flow)
	local group = path[#path]
	for _, key in ipairs(sortedKeys(group)) do
		local option = group.args[key]
		local childPath, childKeys = { unpack(path) }, { unpack(keys) }
		childPath[#childPath + 1], childKeys[#childKeys + 1] = option, key
		-- Sub-pages (groups that are not inline) are reached from the list on the left.
		if not (option.type == "group" and not option.inline) and not isHidden(childPath, childKeys) then
			drawOption(childPath, childKeys, flow)
		end
	end
end

-- Pages --------------------------------------------------------------------------

-- The categories on the left: top-level groups, then their sub-pages, indented.
local function collectPages()
	local pages = {}
	local function add(group, path, keys, depth)
		for _, key in ipairs(sortedKeys(group)) do
			local option = group.args[key]
			if option.type == "group" and not option.inline then
				local childPath, childKeys = { unpack(path) }, { unpack(keys) }
				childPath[#childPath + 1], childKeys[#childKeys + 1] = option, key
				if not isHidden(childPath, childKeys) then
					pages[#pages + 1] = { path = childPath, keys = childKeys, depth = depth, key = table.concat(childKeys, ".") }
					add(option, childPath, childKeys, depth + 1)
				end
			end
		end
	end
	add(Spy.options, { Spy.options }, {}, 0)
	-- Ace3's Profiles page has no order and would sort first: it belongs at the end.
	table.sort(pages, function(a, b)
		local pa, pb = a.keys[1] == "Profiles", b.keys[1] == "Profiles"
		if pa ~= pb then return pb end
		return false
	end)
	return pages
end

function OW:DrawPage()
	releaseAll()
	local page = OW.page
	if not page then return end
	local width = OW.scroll:GetWidth() - 8
	if not width or width < 100 then width = WIDTH - LIST_WIDTH - 60 end
	OW.content:SetWidth(width)
	local flow = newFlow(4, -4, width - 8)
	local title = acquire("pageTitle", function()
		local holder = CreateFrame("Frame", nil, OW.content)
		holder.Text = newLabel(holder, "GameFontNormalLarge")
		holder.Text:SetPoint("TOPLEFT")
		return holder
	end)
	title.Text:SetText(textOf(page.path, page.keys, "name"))
	title:SetSize(flow.width, 22)
	flow:full(title, 22)
	local desc = textOf(page.path, page.keys, "desc")
	if desc ~= "" and desc ~= title.Text:GetText() then
		local holder = acquire("text", createText)
		holder.Text:SetFontObject("GameFontHighlightSmall")
		holder.Text:SetWidth(flow.width)
		holder.Text:SetText(desc)
		local height = math.max(12, holder.Text:GetStringHeight() or 12)
		holder:SetSize(flow.width, height)
		flow:full(holder, height)
	end
	-- The live preview of the Spy window sits at the top of the Display page.
	if page.key == "DisplayOptions" and Spy.CreatePreview then
		local box = acquire("preview", function()
			local holder = CreateFrame("Frame", nil, OW.content)
			holder.Label = newLabel(holder, "GameFontNormalSmall")
			holder.Label:SetPoint("TOPLEFT")
			holder.Preview = Spy:CreatePreview(holder)
			holder.Preview:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -16)
			return holder
		end)
		box.Label:SetText(L["WindowPreview"])
		Spy:DrawPreview(box.Preview)
		local scale = Spy:WindowScale()
		local height = 16 + box.Preview:GetHeight() * scale + 6
		box:SetSize(flow.width, height)
		flow:full(box, height)
	end
	drawGroup(page.path, page.keys, flow)
	flow:newline()
	OW.content:SetHeight(math.max(10, -flow.y + 10))
end

function OW:Redraw()
	if OW.frame and OW.frame:IsShown() then
		OW:DrawPage()
		OW:DrawList()
	end
end

function OW:SelectPage(key)
	for _, page in ipairs(OW.pages) do
		if page.key == key then
			OW.page = page
			OW.scroll:SetVerticalScroll(0)
			OW:DrawList()
			OW:DrawPage()
			return true
		end
	end
	return false
end

function OW:DrawList()
	OW.pages = collectPages()
	OW.listButtons = OW.listButtons or {}
	for _, button in ipairs(OW.listButtons) do button:Hide() end
	for i, page in ipairs(OW.pages) do
		local button = OW.listButtons[i]
		if not button then
			button = CreateFrame("Button", nil, OW.list)
			button:SetHeight(20)
			button.Text = newLabel(button, "GameFontNormal")
			button.Text:SetPoint("LEFT", button, "LEFT", 6, 0)
			button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			button.Selected = button:CreateTexture(nil, "BACKGROUND")
			button.Selected:SetAllPoints(button)
			button.Selected:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			button.Selected:SetBlendMode("ADD")
			button:SetScript("OnClick", function(self) OW:SelectPage(self.pageKey) end)
			OW.listButtons[i] = button
		end
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", OW.list, "TOPLEFT", 4 + page.depth * 12, -6 - (i - 1) * 21)
		button:SetPoint("RIGHT", OW.list, "RIGHT", -4, 0)
		button.pageKey = page.key
		button.Text:SetText(textOf(page.path, page.keys, "name"))
		local selected = OW.page and OW.page.key == page.key
		button.Text:SetFontObject(selected and "GameFontHighlight" or (page.depth > 0 and "GameFontHighlightSmall" or "GameFontNormal"))
		button.Selected:SetShown(selected)
		button:Show()
	end
end

-- The window ---------------------------------------------------------------------------

function OW:Create()
	if OW.frame then return OW.frame end
	local frame = CreateFrame("Frame", "SpyOptionsFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	Spy:NoClientLayout(frame)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	if frame.SetTitle then frame:SetTitle(L["OptionsWindowTitle"]:format(tostring(Spy.Version or ""))) end
	if frame.SetPortraitToAsset then frame:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Spyglass_03") end
	tinsert(UISpecialFrames, "SpyOptionsFrame")

	local inset = frame.Inset or frame
	-- Categories, left.
	local list = CreateFrame("Frame", nil, inset, "BackdropTemplate")
	list:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	list:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 4, 4)
	list:SetWidth(LIST_WIDTH)
	list:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	list:SetBackdropColor(0.06, 0.06, 0.06, 0.8)
	list:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	OW.list = list

	-- Settings, right, in a scroll frame.
	local scroll = CreateFrame("ScrollFrame", "SpyOptionsScrollFrame", inset, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", list, "TOPRIGHT", 12, -6)
	scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -28, 6)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH - LIST_WIDTH - 60, 10)
	scroll:SetScrollChild(content)
	OW.scroll, OW.content = scroll, content

	-- Bottom bar: the settings are saved as they change.
	local note = newLabel(frame, "GameFontDisableSmall")
	note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 8)
	note:SetText(L["OptionsSavedNote"])
	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(96, 22)
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 3)
	close:SetText(CLOSE or "Close")
	close:SetScript("OnClick", function() frame:Hide() end)

	frame:SetScript("OnShow", function() OW:DrawList() if not OW.page then OW:SelectPage("General") end OW:DrawPage() end)
	frame:Hide()
	OW.frame = frame

	-- Changes made elsewhere (slash commands, the watch and guild lists) show at once.
	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry and registry.RegisterCallback then
		registry.RegisterCallback(OW, "ConfigTableChange", function(_, app)
			if app == "Spy" and not OW.selfNotify then OW:Redraw() end
		end)
	end
	return frame
end

function Spy:OpenOptionsWindow(pageKey)
	local frame = OW:Create()
	frame:Show()
	if pageKey then OW:SelectPage(pageKey) end
	return frame
end

-- /spy config and the minimap button open this window; Options > AddOns > Spy keeps
-- the Ace3 pages.
local baseShowConfig = Spy.ShowConfig
function Spy:ShowConfig(...)
	local ok, frame = pcall(OW.Create, OW)
	if not ok or not frame then
		OW.lastError = "create: " .. tostring(frame)
		return baseShowConfig(self, ...)
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

function Spy:OptionsWindowReport()
	return ("Options window: %s | pages %d | last problem: %s"):format(OW.frame and (OW.frame:IsShown() and "open" or "built") or "not built",
		OW.pages and #OW.pages or 0, tostring(OW.lastError or "none"))
end
