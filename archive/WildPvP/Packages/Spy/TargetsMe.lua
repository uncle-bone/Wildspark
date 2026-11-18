-- Spy for Forever: enemies targeting you.
--
-- CurseForge request: "where I can see who targets me when I'm not paying attention".
-- Every second Spy already reads each enemy nameplate, the target and the focus; it now
-- also asks the game whether that enemy's target is you. An enemy targeting you gets a
-- red name and a crosshair in the Spy window, and an alert with a sound the moment he
-- picks you. Only within nameplate range (about 40 yards): the game tells nothing about
-- players further away. In a battleground the game may keep the answer secret; Spy
-- then shows nothing rather than guessing. Written from scratch.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local Guard = Spy.ForeverGuard

local STALE = 2.5          -- seconds without seeing him target us before he no longer counts
local ALERT_COOLDOWN = 30  -- seconds before the same player is announced again
local ICON = "Interface\\Icons\\Ability_Hunter_SniperShot"
local SOUND = "Interface\\AddOns\\Spy\\Sounds\\detected-kosaway.mp3"

Spy.TargetsNow = {}        -- name -> GetTime() he was last seen targeting us
Spy.TargetsAlerted = {}    -- name -> GetTime() of his last alert
Spy.TargetsStats = { alerts = 0, hidden = 0 }

local function option(key)
	return Spy.db and Spy.db.profile and Spy.db.profile[key] ~= false
end

local function showAlert(player)
	local window = Spy.AlertWindow
	if not window or not Spy.FrameFlash then
		return
	end
	-- A Kill On Sight or stealth alert on screen keeps priority.
	if SpyFrameIsFading(window) and (Spy.AlertType == "kos" or Spy.AlertType == "stealth") then
		return
	end
	Spy.Colors:RegisterBorder("Alert", "KOS Border", window)
	window.Icon:SetBackdrop({ bgFile = ICON })
	Spy.Colors:RegisterBorder("Alert", "Background", window.Icon)
	Spy.Colors:RegisterBackground("Alert", "Icon", window.Icon)
	Spy.Colors:RegisterFont("Alert", "KOS Text", window.Title)
	window.Title:SetText(L["AlertTargetsYouTitle"])
	Spy.Colors:RegisterFont("Alert", "Name Text", window.Name)
	window.Name:SetText(player)
	window.Location:SetText("")
	local width = math.max(window.Title:GetStringWidth(), window.Name:GetStringWidth())
	window:SetWidth(width + 52)
	window.Name:SetWidth(width)
	window.Location:SetWidth(width)
	Spy.FrameFlashStop(window)
	Spy.FrameFlash(window, 0, 1, 4, false, 3, 0)
	Spy.AlertType = "targetsyou"
end

local function alertFor(name)
	local now = GetTime()
	if Spy.TargetsAlerted[name] and now - Spy.TargetsAlerted[name] < ALERT_COOLDOWN then
		return
	end
	Spy.TargetsAlerted[name] = now
	Spy.TargetsStats.alerts = Spy.TargetsStats.alerts + 1
	Spy.TargetsStats.last = { name = name, when = time() }
	if option("TargetsYouAlert") then
		showAlert(name)
		if Spy.db.profile.EnableSound then
			Spy:PlaySound(SOUND, Spy.db.profile.SoundChannel)
		end
	end
end

-- Spy:NoteTargetingMe (Forever.lua) runs for every enemy scanned; it keeps a longer
-- memory for the death recap. Here: is he targeting us right now?
local baseNote = Spy.NoteTargetingMe
function Spy:NoteTargetingMe(unit, name, ...)
	baseNote(self, unit, name, ...)
	local ok, same = pcall(UnitIsUnit, unit .. "target", "player")
	if not ok then
		return
	end
	if Spy:IsSecret(same) then
		Spy.TargetsStats.hidden = Spy.TargetsStats.hidden + 1
		return -- kept secret: no guess either way
	end
	if same == true then
		local fresh = Spy.TargetsNow[name] == nil
		Spy.TargetsNow[name] = GetTime()
		if fresh then
			Spy.TargetsChanged = true
			alertFor(name)
		end
	elseif Spy.TargetsNow[name] then
		Spy.TargetsNow[name] = nil
		Spy.TargetsChanged = true
	end
end

-- After each scan: forget whoever has not been seen targeting us for a while, and
-- redraw the rows when the set changed.
local baseScan = Spy.ScanVisibleUnits
Spy.ScanVisibleUnits = Guard("TargetsMeScan", function(self, ...)
	baseScan(self, ...)
	local now = GetTime()
	for name, when in pairs(Spy.TargetsNow) do
		if now - when > STALE then
			Spy.TargetsNow[name] = nil
			Spy.TargetsChanged = true
		end
	end
	if Spy.TargetsChanged then
		Spy.TargetsChanged = nil
		if Spy.MainWindow and Spy.RefreshCurrentList then
			Spy:RefreshCurrentList()
		end
	end
end)

-- The row of an enemy targeting us: red name and a crosshair before the level.
local baseSetBar = Spy.SetBar
function Spy:SetBar(num, name, desc, value, colorgroup, colorclass, tooltipData, opacity, ...)
	baseSetBar(self, num, name, desc, value, colorgroup, colorclass, tooltipData, opacity, ...)
	local row = Spy.MainWindow and Spy.MainWindow.Rows[num]
	if not row then
		return
	end
	if not row.TargetsYouIcon then
		row.TargetsYouIcon = row:CreateTexture(nil, "OVERLAY")
		row.TargetsYouIcon:SetTexture(ICON)
		row.TargetsYouIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	local icon = row.TargetsYouIcon
	if option("TargetsYouMarker") and type(name) == "string" and Spy.TargetsNow[name] then
		local size = math.max(6, (row:GetHeight() or 14) - 4)
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("RIGHT", row.RightText, "LEFT", -3, 0)
		icon:SetAlpha(opacity or 1)
		icon:Show()
		row.LeftText:SetTextColor(1, 0.25, 0.25, opacity or 1)
	else
		icon:Hide()
	end
end

function Spy:TargetsReport()
	local now, count = 0, 0
	for _ in pairs(Spy.TargetsNow) do count = count + 1 end
	local last = Spy.TargetsStats.last
	return ("Enemies targeting you now: %d | alerts: %d (last: %s) | answers kept secret by the game: %d"):format(
		count, Spy.TargetsStats.alerts, last and ("%s, %ss ago"):format(last.name, time() - last.when) or "none",
		Spy.TargetsStats.hidden)
end

-- Options: Alerts page.
local alerts = Spy.options and Spy.options.args.AlertOptions and Spy.options.args.AlertOptions.args
if alerts then
	alerts.TargetsYouAlert = {
		name = L["TargetsYouAlert"],
		desc = L["TargetsYouAlertDescription"],
		type = "toggle",
		order = 9.5,
		width = "full",
		get = function() return option("TargetsYouAlert") end,
		set = function(_, value) Spy.db.profile.TargetsYouAlert = value end,
	}
	alerts.TargetsYouMarker = {
		name = L["TargetsYouMarker"],
		desc = L["TargetsYouMarkerDescription"],
		type = "toggle",
		order = 9.6,
		width = "full",
		get = function() return option("TargetsYouMarker") end,
		set = function(_, value)
			Spy.db.profile.TargetsYouMarker = value
			if Spy.MainWindow then Spy:RefreshCurrentList() end
		end,
	}
end
