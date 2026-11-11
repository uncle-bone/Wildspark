-- WildSpark: move Blizzard group loot rolls, with an in-game placement editor and preview.
-- The preview is visual only; real roll controls always remain Blizzard's frames.
local ADDON, ns = ...
local MOD = {}
ns.WildLootRolls = MOD
_G.WildLootRolls = MOD

local defaults = { enabled = true, x = 0, y = 160, scale = 1, placement = false }
local db, container, editor, applying, originalPoint, originalScale
local unpack = unpack or table.unpack

local function SavePosition()
	if not editor or not db then return end
	local x, y = editor:GetCenter()
	if not x then return end
	db.x, db.y = x - UIParent:GetWidth() / 2, y - UIParent:GetHeight() / 2
end

local function Apply()
	if not db or not container then return end
	applying = true
	if db.enabled then
		container:SetScale(db.scale or 1)
		container:ClearAllPoints()
		container:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, (db.y or 160) - 54)
	elseif originalPoint then
		container:ClearAllPoints()
		container:SetPoint(unpack(originalPoint))
		container:SetScale(originalScale or 1)
	end
	applying = false
end

local function PreviewButton(parent, label, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(label)
	button:Disable()
	return button
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
	title:SetText("|cffffd200WildSpark Edit Mode|r  |cffaaaaaa(Preview)|r")
	titleBar:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then editor:StartMoving() end
	end)
	titleBar:SetScript("OnMouseUp", function()
		editor:StopMovingOrSizing()
		SavePosition()
		Apply()
	end)

	local done = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
	done:SetSize(64, 20)
	done:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
	done:SetText("Done")
	done:SetScript("OnClick", function()
		db.placement = false
		editor:Hide()
	end)

	local icon = editor:CreateTexture(nil, "ARTWORK")
	icon:SetSize(42, 42)
	icon:SetPoint("TOPLEFT", 14, -33)
	icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
	local item = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	item:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -2)
	item:SetText("|cffffd200Preview Item|r")
	local instruction = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	instruction:SetPoint("TOPLEFT", item, "BOTTOMLEFT", 0, -4)
	instruction:SetText("Drag this header to position group loot rolls.")
	local need = PreviewButton(editor, "Need", 74)
	local greed = PreviewButton(editor, "Greed", 74)
	local pass = PreviewButton(editor, "Pass", 74)
	need:SetPoint("BOTTOMLEFT", 14, 9)
	greed:SetPoint("LEFT", need, "RIGHT", 6, 0)
	pass:SetPoint("LEFT", greed, "RIGHT", 6, 0)
end

local function PositionEditor()
	CreateEditor()
	editor:ClearAllPoints()
	editor:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 160)
	editor:SetShown(db.placement == true and db.enabled == true)
end

local function CaptureOriginal()
	if originalPoint or not container then return end
	local point, relative, relativePoint, x, y = container:GetPoint(1)
	if point then originalPoint = { point, relative or UIParent, relativePoint or point, x or 0, y or 0 } end
	originalScale = container:GetScale() or 1
end

local function Initialize()
	if not _G.GroupLootContainer or container then return end
	container = _G.GroupLootContainer
	CaptureOriginal()
	if hooksecurefunc then
		hooksecurefunc(container, "SetPoint", function()
			if db and db.enabled and not applying then C_Timer.After(0, Apply) end
		end)
	end
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
	db.scale = math.max(0.6, math.min(1.6, math.floor(((db.scale or 1) + delta) * 10 + 0.5) / 10))
	Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("START_LOOT_ROLL")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON then
		_G.WildLootRollDB = _G.WildLootRollDB or {}
		db = _G.WildLootRollDB
		for key, value in pairs(defaults) do
			if db[key] == nil then db[key] = value end
		end
	elseif (event == "PLAYER_LOGIN" or event == "START_LOOT_ROLL") and db then
		Initialize()
		PositionEditor()
	end
end)
