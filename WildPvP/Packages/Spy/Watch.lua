-- Spy for Forever: the watch list.
--
-- Players of your own faction you want to remember (a ninja looter, a griefer). Spy
-- warns you, with its own sound, when one of them shows up near you (his nameplate,
-- your target, focus or mouseover) and when one of them is in your group or raid.
-- Requested in a CurseForge comment, written from scratch.
--
-- The list is kept per realm and faction for the whole account, like the shared Kill
-- On Sight list: an alt remembers the ninja looter too.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local Guard = Spy.ForeverGuard

local NEARBY_COOLDOWN = 300       -- seconds before the same watched player is announced again
local SOUND = "Interface\\AddOns\\Spy\\Sounds\\detected-kosguild.mp3"
local ICON = "Interface\\Icons\\INV_Misc_Eye_01"

Spy.WatchAlerted = {}
Spy.WatchInGroup = {}

local function settings()
	return Spy.db and Spy.db.profile or {}
end

local function enabled(key)
	return settings()[key] ~= false
end

function Spy:WatchList()
	SpyDB.watchData = SpyDB.watchData or {}
	local realm = tostring(Spy.StoreRealm or Spy.RealmName or "?")
	local faction = tostring(Spy.FactionName or "?")
	SpyDB.watchData[realm] = SpyDB.watchData[realm] or {}
	SpyDB.watchData[realm][faction] = SpyDB.watchData[realm][faction] or {}
	return SpyDB.watchData[realm][faction]
end

function Spy:IsWatched(name)
	return type(name) == "string" and Spy:WatchList()[name] ~= nil
end

-- "Name" or "First Last", then optionally ": reason".
local function splitTyped(value)
	value = tostring(value or "")
	local name, reason = value:match("^([^:]*):(.*)$")
	if not name then
		name = value
	end
	reason = reason and strtrim(reason) or nil
	if reason == "" then
		reason = nil
	end
	return strtrim(name), reason
end

function Spy:ToggleWatch(name, reason, quiet)
	local list = Spy:WatchList()
	if list[name] then
		list[name] = nil
		Spy.WatchAlerted[name] = nil
		Spy.WatchInGroup[name] = nil
		if settings().EnableSound then
			Spy:PlaySound("Interface\\AddOns\\Spy\\Sounds\\list-remove.mp3", settings().SoundChannel)
		end
		if not quiet then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["WatchRemoved"]:format(name))
		end
	else
		list[name] = { added = time(), reason = reason }
		if settings().EnableSound then
			Spy:PlaySound("Interface\\AddOns\\Spy\\Sounds\\list-add.mp3", settings().SoundChannel)
		end
		if not quiet then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["WatchAdded"]:format(name)
				.. (reason and (" (" .. reason .. ")") or ""))
		end
		Spy:CheckWatchedGroup()
	end
	Spy:RefreshWatchOptions()
end

local function zoneText()
	local zone = Spy:Readable(GetZoneText())
	local subZone = Spy:Readable(GetSubZoneText())
	if type(subZone) == "string" and subZone ~= "" and subZone ~= zone then
		return subZone .. ", " .. tostring(zone)
	end
	return type(zone) == "string" and zone or nil
end

local function remember(entry, unit)
	if unit then
		entry.class = Spy:Readable((select(2, UnitClass(unit)))) or entry.class
		local level = tonumber(Spy:Readable(UnitLevel(unit)))
		if level and level > 0 then
			entry.level = level
		end
		local guild = Spy:Readable((GetGuildInfo(unit)))
		if guild ~= nil then
			entry.guild = guild
		end
	end
	entry.seen = time()
	entry.zone = zoneText() or entry.zone
end

local function showAlert(name, location)
	local window = Spy.AlertWindow
	if not window then
		return
	end
	if SpyFrameIsFading(window) and (Spy.AlertType == "kos" or Spy.AlertType == "kosguild") then
		return
	end
	Spy.Colors:RegisterBorder("Alert", "KOS Guild Border", window)
	window.Icon:SetBackdrop({ bgFile = ICON })
	Spy.Colors:RegisterBorder("Alert", "Background", window.Icon)
	Spy.Colors:RegisterBackground("Alert", "Icon", window.Icon)
	Spy.Colors:RegisterFont("Alert", "KOS Guild Text", window.Title)
	window.Title:SetText(L["AlertWatchTitle"])
	Spy.Colors:RegisterFont("Alert", "Name Text", window.Name)
	window.Name:SetText(name)
	Spy.Colors:RegisterFont("Alert", "Location Text", window.Location)
	window.Location:SetText(location or "")
	local width = math.max(window.Title:GetStringWidth(), window.Name:GetStringWidth(), window.Location:GetStringWidth())
	window:SetWidth(width + 52)
	Spy.FrameFlashStop(window)
	Spy.FrameFlash(window, 0, 1, 4, false, 3, 0)
	Spy.AlertType = "watch"
end

-- how: "nearby" or "group".
function Spy:AlertWatch(name, how)
	local entry = Spy:WatchList()[name]
	if not entry then
		return
	end
	local display = name:gsub("%-", " ")
	local message = (how == "group" and L["WatchInGroup"] or L["WatchNearby"]):format(display)
		.. (entry.reason and (" (" .. entry.reason .. ")") or "")
	DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. message)
	if settings().DisplayWarnings == "ErrorFrame" then
		local color = settings().Colors and settings().Colors.Warning and settings().Colors.Warning["Warning Text"]
		UIErrorsFrame:AddMessage(message, color and color.r or 1, color and color.g or 0.8, color and color.b or 0.2, 1.0, UIERRORS_HOLD_TIME)
	else
		showAlert(display, entry.reason or (how == "group" and L["WatchGroupShort"] or nil))
	end
	if settings().EnableSound and enabled("WatchSound") then
		Spy:PlaySound(SOUND, settings().SoundChannel)
	end
	Spy.LastWatchAlert = { name = name, how = how, when = time() }
end

-- Called by Spy:ScanUnit for every player of our faction it reads.
function Spy:WatchSeen(name, unit)
	local entry = Spy:WatchList()[name]
	if not entry or not settings().Enabled then
		return
	end
	remember(entry, unit)
	if not enabled("WarnOnWatch") then
		return
	end
	local last = Spy.WatchAlerted[name]
	if last and GetTime() - last < NEARBY_COOLDOWN then
		return
	end
	Spy.WatchAlerted[name] = GetTime()
	Spy:AlertWatch(name, "nearby")
end

-- Watched players in the group: announced when they join (or when we join them).
function Spy:CheckWatchedGroup()
	if not Spy.db then
		return
	end
	local present = {}
	local count = GetNumGroupMembers and GetNumGroupMembers() or 0
	if count > 0 then
		local raid = IsInRaid and IsInRaid()
		local prefix, last = raid and "raid" or "party", raid and count or math.min(count, 4)
		for i = 1, last do
			local unit = prefix .. i
			local name = Spy:PlayerName(unit)
			if name and Spy:IsWatched(name) then
				present[name] = unit
			end
		end
	end
	for name, unit in pairs(present) do
		if not Spy.WatchInGroup[name] then
			remember(Spy:WatchList()[name], unit)
			Spy.WatchAlerted[name] = GetTime()
			if settings().Enabled and enabled("WarnOnWatchGroup") then
				Spy:AlertWatch(name, "group")
			end
		end
	end
	Spy.WatchInGroup = present
end

local events = CreateFrame("Frame")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", Guard("WatchEvents", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" and Spy.db and not Spy.WatchOptionsReady then
		Spy.WatchOptionsReady = true
		Spy:RefreshWatchOptions()
	end
	Spy:CheckWatchedGroup()
end))

-- Right-click menu on a player ------------------------------------------------------
-- Forever has the retail menus: Menu.ModifyMenu adds entries to the player menus
-- (target and party frames, chat names). A player of our faction can be watched, an
-- enemy put on Kill On Sight.

local MENUS = { "PLAYER", "TARGET", "FOCUS", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "ENEMY_PLAYER",
	"CHAT_ROSTER", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER", "GUILD" }

function Spy:MenuPlayer(contextData)
	if type(contextData) ~= "table" then
		return nil
	end
	local unit = Spy:Readable(contextData.unit)
	if type(unit) == "string" then
		if Spy:Readable(UnitIsUnit(unit, "player")) then
			return nil
		end
		local name = Spy:PlayerName(unit)
		if name then
			return name, Spy:Readable(UnitIsEnemy("player", unit))
		end
		return nil
	end
	local name = Spy:Readable(contextData.name)
	if type(name) ~= "string" or name == "" or name == Spy.CharacterName then
		return nil
	end
	local server = Spy:Readable(contextData.server)
	if not name:find("-", 1, true) and type(server) == "string" and server ~= "" and server ~= Spy.RealmName then
		name = name .. "-" .. server
	end
	local playerData = SpyPerCharDB.PlayerData[name]
	return name, playerData and playerData.isEnemy or false
end

local function addMenuEntries(owner, description, contextData)
	if Spy:SkipPlayerMenus() then
		return -- Forever.lua says why (controller interface)
	end
	local ok, err = pcall(function()
		local name, isEnemy = Spy:MenuPlayer(contextData)
		if not name then
			return
		end
		description:CreateDivider()
		description:CreateTitle("Spy")
		if isEnemy then
			local onList = SpyPerCharDB.KOSData[name] ~= nil
			description:CreateButton(onList and L["MenuKOSRemove"] or L["MenuKOSAdd"], function()
				Spy:ToggleKOSPlayer(not SpyPerCharDB.KOSData[name], name)
			end)
		else
			description:CreateButton(Spy:IsWatched(name) and L["MenuWatchRemove"] or L["MenuWatchAdd"], function()
				Spy:ToggleWatch(name)
			end)
		end
	end)
	if not ok then
		Spy.ForeverLastError = "WatchMenu: " .. tostring(err)
	end
end

if Menu and Menu.ModifyMenu then
	for _, which in ipairs(MENUS) do
		pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, addMenuEntries)
	end
	Spy.WatchMenus = true
end

-- Options, slash commands, /spy debug ------------------------------------------------

local function ago(seconds)
	if seconds < 3600 then
		return ("%d min"):format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return ("%d h"):format(math.floor(seconds / 3600))
	end
	return ("%d d"):format(math.floor(seconds / 86400))
end

function Spy:WatchDescription(name, entry)
	local parts = { (name:gsub("%-", " ")) }
	local details = {}
	if entry.level then details[#details + 1] = L["Level"] .. " " .. entry.level end
	if entry.class and L[entry.class] then details[#details + 1] = L[entry.class] end
	if entry.guild and entry.guild ~= "" then details[#details + 1] = "<" .. entry.guild .. ">" end
	if #details > 0 then parts[#parts + 1] = "- " .. table.concat(details, " ") end
	if entry.reason then parts[#parts + 1] = "(" .. entry.reason .. ")" end
	if entry.seen then
		parts[#parts + 1] = "- " .. L["WatchLastSeen"]:format(ago(time() - entry.seen), tostring(entry.zone or "?"))
	end
	return table.concat(parts, " ")
end

local function sortedNames()
	local names = {}
	for name in pairs(Spy:WatchList()) do names[#names + 1] = name end
	table.sort(names)
	return names
end

local function toggle(key, order)
	return {
		name = L[key],
		desc = L[key .. "Description"],
		type = "toggle",
		order = order,
		width = "full",
		get = function() return enabled(key) end,
		set = function(_, value) Spy.db.profile[key] = value end,
	}
end

Spy.options.args.WatchOptions = {
	name = L["WatchOptions"],
	desc = L["WatchOptions"],
	type = "group",
	order = 6,
	args = {
		intro = { name = L["WatchOptionsDescription"], type = "description", order = 1, fontSize = "medium" },
		WarnOnWatch = toggle("WarnOnWatch", 2),
		WarnOnWatchGroup = toggle("WarnOnWatchGroup", 3),
		WatchSound = toggle("WatchSound", 4),
		PlayerMenuEntries = toggle("PlayerMenuEntries", 4.5),
		add = {
			name = L["WatchAdd"],
			desc = L["WatchAddDescription"],
			type = "input",
			order = 5,
			width = "full",
			get = function() return "" end,
			set = function(_, value) Spy:WatchCommand(value) end,
		},
		list = { name = L["WatchListTitle"], type = "group", inline = true, order = 6, args = {} },
	},
}

function Spy:RefreshWatchOptions()
	local args = {}
	local names = sortedNames()
	if #names == 0 then
		args.empty = { name = L["WatchEmpty"], type = "description", order = 1 }
	end
	for index, name in ipairs(names) do
		local entry = Spy:WatchList()[name]
		args["player" .. index] = { name = Spy:WatchDescription(name, entry), type = "description", order = index * 2, width = 2.5 }
		args["remove" .. index] = {
			name = L["WatchRemoveButton"],
			type = "execute",
			order = index * 2 + 1,
			width = 0.6,
			func = function() Spy:ToggleWatch(name) end,
		}
	end
	Spy.options.args.WatchOptions.args.list.args = args
	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry then
		registry:NotifyChange("Spy")
	end
end

-- "/spy watch" alone: the current target. "/spy watch First Last: reason" otherwise.
function Spy:WatchCommand(value)
	local typed, reason = splitTyped(value)
	local name
	if typed == "" then
		name = Spy:PlayerName("target")
		if not name or Spy:Readable(UnitIsUnit("target", "player")) then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["WatchNoTarget"])
			return
		end
	else
		name = Spy:TypedPlayerName(typed)
		if not name then
			DEFAULT_CHAT_FRAME:AddMessage(typed .. " - " .. L["InvalidInput"])
			return
		end
	end
	Spy:ToggleWatch(name, reason)
end

Spy.optionsSlash.args.watch = {
	name = L["WatchSlash"],
	desc = L["WatchSlashDescription"],
	type = "input",
	order = 14,
	pattern = ".*",
	set = function(_, value) Spy:WatchCommand(value) end,
	dialogHidden = true,
}

Spy.optionsSlash.args.watchlist = {
	name = L["WatchListSlash"],
	desc = L["WatchListSlashDescription"],
	type = "execute",
	order = 15,
	func = function()
		local names = sortedNames()
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["WatchListCount"]:format(#names))
		for _, name in ipairs(names) do
			DEFAULT_CHAT_FRAME:AddMessage("  " .. Spy:WatchDescription(name, Spy:WatchList()[name]))
		end
	end,
	dialogHidden = true,
}

function Spy:WatchReport()
	local count = #sortedNames()
	local last = Spy.LastWatchAlert
	return ("Watch list: %d players | menus %s | last alert: %s"):format(count, Spy.WatchMenus and "yes" or "no",
		last and ("%s (%s) %ss ago"):format(last.name, last.how, time() - last.when) or "none")
end
