-- WildSpark: move Blizzard's group loot roll frames and show a real placement preview.
-- Roll buttons and their behavior remain Blizzard's; only their anchors and scale are changed.
local ADDON, ns = ...
local MOD = {}
local L = ns.L
ns.WildLootRolls = MOD
_G.WildLootRolls = MOD

local DEFAULTS = { enabled = true, x = 0, y = 160, scale = 1, spacing = 100, placement = false }
local db, editor, anchor, layoutHooked
local originalFrames = {}
local unpack = unpack or table.unpack
local MAX_ROLLS = 4

local function RollFrame(index)
	return _G["GroupLootFrame" .. index]
end

local function PlaceAnchor()
	if not anchor or not db then return end
	anchor:ClearAllPoints()
	anchor:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.x) or 0, tonumber(db.y) or 160)
end

local function CaptureNativeFrame(frame)
	if originalFrames[frame] then return end
	local points = {}
	for index = 1, frame:GetNumPoints() do
		points[index] = { frame:GetPoint(index) }
	end
	originalFrames[frame] = { points = points, scale = frame:GetScale() or 1 }
end

local function RestoreNativeFrames()
	for index = 1, MAX_ROLLS do
		local frame = RollFrame(index)
		local original = frame and originalFrames[frame]
		if frame and original then
			frame:SetScale(original.scale)
			if #original.points > 0 and type(_G.GroupLootContainer_Update) ~= "function" then
				frame:ClearAllPoints()
				for _, point in ipairs(original.points) do frame:SetPoint(unpack(point)) end
			end
		end
	end
end

local function PositionRollFrames()
	if not db or not db.enabled or not anchor then return end
	PlaceAnchor()
	local spacing = math.max(50, math.min(200, tonumber(db.spacing) or DEFAULTS.spacing))
	local scale = math.max(0.6, math.min(1.6, tonumber(db.scale) or 1))
	for index = 1, MAX_ROLLS do
		local frame = RollFrame(index)
		if frame and frame:IsShown() then
			CaptureNativeFrame(frame)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -((index - 1) * spacing))
			frame:SetScale(scale)
		end
	end
end

local function Apply()
	if not db then return end
	if db.enabled then
		PositionRollFrames()
	else
		if type(_G.GroupLootContainer_Update) == "function" then
			_G.GroupLootContainer_Update(_G.GroupLootContainer)
		else
			RestoreNativeFrames()
		end
	end
	if editor then editor:SetScale(tonumber(db.scale) or 1) end
end

local function PreviewButton(parent, label, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(label)
	button:Disable()
	return button
end

local function SavePosition()
	if not editor or not db then return end
	local x, y = editor:GetCenter()
	if not x then return end
	db.x = x - UIParent:GetWidth() / 2
	db.y = y - UIParent:GetHeight() / 2
	Apply()
end

local function CreateEditor()
	if editor then return end
	editor = CreateFrame("Frame", "WildLootRollsEditPreview", UIParent, "BackdropTemplate")
	editor:SetSize(360, 112)
	editor:SetFrameStrata("DIALOG")
	editor:SetMovable(true)
	editor:EnableMouse(true)
	editor:SetClampedToScreen(true)
	editor:SetBackdrop({
		bgFile = "Interface/Buttons/WHITE8X8",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	editor:SetBackdropColor(0.055, 0.055, 0.055, 0.96)
	editor:SetBackdropBorderColor(1, 0.68, 0.05, 1)

	local titleBar = CreateFrame("Frame", nil, editor)
	titleBar:SetPoint("TOPLEFT", 5, -4)
	titleBar:SetPoint("TOPRIGHT", -5, -4)
	titleBar:SetHeight(22)
	titleBar:EnableMouse(true)
	local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 7, 0)
	title:SetText("|cffffd200" .. (L.WILDLOOTROLLS_EDIT_TITLE or "WildSpark Edit Mode") .. "|r  |cffaaaaaa(Preview)|r")
	titleBar:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then editor:StartMoving() end
	end)
	titleBar:SetScript("OnMouseUp", function()
		editor:StopMovingOrSizing()
		SavePosition()
	end)

	local close = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -1, -1)
	close:SetSize(24, 24)
	close:SetScript("OnClick", function()
		if db then db.placement = false end
		editor:Hide()
	end)

	local icon = editor:CreateTexture(nil, "ARTWORK")
	icon:SetSize(42, 42)
	icon:SetPoint("TOPLEFT", 14, -33)
	icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
	local item = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	item:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -2)
	item:SetText("|cffffd200" .. (L.WILDLOOTROLLS_PREVIEW or "Preview Item") .. "|r")
	local instruction = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	instruction:SetPoint("TOPLEFT", item, "BOTTOMLEFT", 0, -4)
	instruction:SetWidth(270)
	instruction:SetJustifyH("LEFT")
	instruction:SetText(L.WILDLOOTROLLS_INSTRUCTION or "Drag this header to position group loot rolls.")
	local need = PreviewButton(editor, _G.ROLL_NEED or "Need", 74)
	local greed = PreviewButton(editor, _G.ROLL_GREED or "Greed", 74)
	local pass = PreviewButton(editor, _G.ROLL_PASS or "Pass", 74)
	need:SetPoint("BOTTOMLEFT", 14, 9)
	greed:SetPoint("LEFT", need, "RIGHT", 6, 0)
	pass:SetPoint("LEFT", greed, "RIGHT", 6, 0)

	editor:SetScript("OnHide", function()
		if db then db.placement = false end
	end)
end

local function PositionEditor()
	if not db then return end
	CreateEditor()
	editor:ClearAllPoints()
	editor:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.x) or 0, tonumber(db.y) or 160)
	editor:SetScale(tonumber(db.scale) or 1)
	editor:SetShown(db.placement == true and db.enabled == true)
end

local function OnNativeLayout()
	if db and db.enabled then
		C_Timer.After(0, PositionRollFrames)
	end
end

local function Initialize()
	if not db then return end
	CreateEditor()
	if not anchor then
		anchor = CreateFrame("Frame", "WildLootRollsAnchor", UIParent)
		anchor:SetSize(1, 1)
		anchor:Hide()
	end
	if not layoutHooked and type(_G.GroupLootContainer_Update) == "function" and hooksecurefunc then
		hooksecurefunc("GroupLootContainer_Update", OnNativeLayout)
		layoutHooked = true
	end
	PlaceAnchor()
	Apply()
	PositionEditor()
end

function MOD.IsEnabled()
	return db and db.enabled == true
end

function MOD.SetEnabled(value)
	if not db then return end
	db.enabled = value and true or false
	if not db.enabled then db.placement = false end
	Apply()
	PositionEditor()
end

function MOD.TogglePlacement()
	if not db or not db.enabled then return end
	db.placement = not db.placement
	PositionEditor()
end

function MOD.AdjustScale(delta)
	if not db then return end
	db.scale = math.max(0.6, math.min(1.6, math.floor(((tonumber(db.scale) or 1) + delta) * 10 + 0.5) / 10))
	Apply()
	PositionEditor()
end

function MOD.AdjustSpacing(delta)
	if not db then return end
	db.spacing = math.max(50, math.min(200, (tonumber(db.spacing) or DEFAULTS.spacing) + delta))
	Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("START_LOOT_ROLL")
events:RegisterEvent("CANCEL_LOOT_ROLL")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and type(name) == "string" and string.lower(name) == string.lower(ADDON) then
		_G.WildLootRollDB = type(_G.WildLootRollDB) == "table" and _G.WildLootRollDB or {}
		db = _G.WildLootRollDB
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then db[key] = value end
		end
		if type(db.placement) ~= "boolean" then db.placement = false end
	elseif event == "PLAYER_LOGIN" then
		Initialize()
	elseif (event == "START_LOOT_ROLL" or event == "CANCEL_LOOT_ROLL") and db then
		Initialize()
		C_Timer.After(0.05, PositionRollFrames)
	end
end)
