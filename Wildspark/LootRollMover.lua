-- WildSpark: configurable placement for Blizzard group loot roll frames.
-- Clean implementation against the Blizzard frame API; no third-party source is bundled.
local ADDON, ns = ...
local MOD = {}
ns.WildLootRolls = MOD
_G.WildLootRolls = MOD

local defaults = { enabled = true, x = 0, y = 160, scale = 1, placement = false }
local db, container, handle, applying, originalPoint, originalScale
local unpack = unpack or table.unpack

local function SavePosition()
	if not handle or not db then return end
	local x, y = handle:GetCenter()
	if not x then return end
	db.x, db.y = x - UIParent:GetWidth() / 2, y - UIParent:GetHeight() / 2
end
local function Apply()
	if not db or not container then return end
	applying = true
	if db.enabled then
		container:SetScale(db.scale or 1)
		container:ClearAllPoints()
		container:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, (db.y or 160) - 46)
	elseif originalPoint then
		container:ClearAllPoints()
		container:SetPoint(unpack(originalPoint))
		container:SetScale(originalScale or 1)
	end
	applying = false
end
local function CreateHandle()
	if handle then return end
	handle = CreateFrame("Button", "WildLootRollMoverHandle", UIParent, "BackdropTemplate")
	handle:SetSize(148, 26)
	handle:SetFrameStrata("DIALOG")
	handle:SetMovable(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetClampedToScreen(true)
	handle:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
	handle:SetBackdropColor(0.18, 0.11, 0.02, 0.92)
	local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetText("|cffffd200WildSpark: drag loot rolls|r")
	handle:SetScript("OnDragStart", function(self) self:StartMoving() end)
	handle:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
		Apply()
	end)
	handle:SetScript("OnClick", function()
		db.placement = false
		handle:Hide()
	end)
end
local function PositionHandle()
	CreateHandle()
	handle:ClearAllPoints()
	handle:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 160)
	handle:SetShown(db.placement == true and db.enabled == true)
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
	PositionHandle()
end
function MOD.IsEnabled() return db and db.enabled == true end
function MOD.SetEnabled(value)
	if not db then return end
	db.enabled = value and true or false
	if not db.enabled then db.placement = false end
	Apply()
	PositionHandle()
end
function MOD.TogglePlacement()
	if not db or not db.enabled then return end
	db.placement = not db.placement
	PositionHandle()
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
		for key, value in pairs(defaults) do if db[key] == nil then db[key] = value end end
	elseif (event == "PLAYER_LOGIN" or event == "START_LOOT_ROLL") and db then
		Initialize()
		PositionHandle()
	end
end)
