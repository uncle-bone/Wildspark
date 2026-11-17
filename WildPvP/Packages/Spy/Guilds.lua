-- Spy for Forever: watched guilds.
--
-- Guilds you want to know about (a CurseForge comment: "Player X - in guild <...>").
-- Spy warns you when a member of one of them shows up near you: an enemy (instead of
-- the plain "new enemy" sound) or a player of your own faction. Written from scratch.
--
-- The list is kept per realm for the whole account: an alt knows the guild too.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local Guard = Spy.ForeverGuard

local FRIENDLY_COOLDOWN = 300     -- seconds before the same player of our faction is announced again
local SOUND = "Interface\\AddOns\\Spy\\Sounds\\detected-kosguild.mp3"
local ICON = "Interface\\Icons\\INV_Misc_TabardPVP_01"

Spy.GuildAlerted = {}

local function settings()
	return Spy.db and Spy.db.profile or {}
end

local function enabled(key)
	return settings()[key] ~= false
end

function Spy:GuildList()
	SpyDB.guildWatch = SpyDB.guildWatch or {}
	local realm = tostring(Spy.StoreRealm or Spy.RealmName or "?")
	SpyDB.guildWatch[realm] = SpyDB.guildWatch[realm] or {}
	return SpyDB.guildWatch[realm]
end

local function key(guild)
	if type(guild) ~= "string" then
		return nil
	end
	guild = strtrim(guild)
	if guild == "" then
		return nil
	end
	return guild:lower()
end

-- The list entry for a guild name (any case), or nil.
function Spy:WatchedGuild(guild)
	local k = key(guild)
	return k and Spy:GuildList()[k] or nil
end

function Spy:ToggleGuild(guild, reason, quiet)
	local k = key(guild)
	if not k then
		return
	end
	guild = strtrim(guild)
	local list = Spy:GuildList()
	if list[k] then
		local name = list[k].name
		list[k] = nil
		if settings().EnableSound then
			Spy:PlaySound("Interface\\AddOns\\Spy\\Sounds\\list-remove.mp3", settings().SoundChannel)
		end
		if not quiet then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["GuildRemoved"]:format(name))
		end
	else
		list[k] = { name = guild, reason = reason, added = time() }
		if settings().EnableSound then
			Spy:PlaySound("Interface\\AddOns\\Spy\\Sounds\\list-add.mp3", settings().SoundChannel)
		end
		if not quiet then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["GuildAdded"]:format(guild)
				.. (reason and (" (" .. reason .. ")") or ""))
		end
	end
	Spy:RefreshGuildOptions()
end

local function showAlert(player, guild, reason)
	local window = Spy.AlertWindow
	if not window then
		return
	end
	if SpyFrameIsFading(window) and Spy.AlertType == "kos" then
		return
	end
	Spy.Colors:RegisterBorder("Alert", "KOS Guild Border", window)
	window.Icon:SetBackdrop({ bgFile = ICON })
	Spy.Colors:RegisterBorder("Alert", "Background", window.Icon)
	Spy.Colors:RegisterBackground("Alert", "Icon", window.Icon)
	Spy.Colors:RegisterFont("Alert", "KOS Guild Text", window.Title)
	window.Title:SetText(L["AlertGuildTitle"])
	Spy.Colors:RegisterFont("Alert", "Name Text", window.Name)
	window.Name:SetText(player .. " <" .. guild .. ">")
	Spy.Colors:RegisterFont("Alert", "Location Text", window.Location)
	window.Location:SetText(reason or "")
	local width = math.max(window.Title:GetStringWidth(), window.Name:GetStringWidth(), window.Location:GetStringWidth())
	window:SetWidth(width + 52)
	Spy.FrameFlashStop(window)
	Spy.FrameFlash(window, 0, 1, 4, false, 3, 0)
	Spy.AlertType = "kosguild"
end

-- name: Spy's key for the player ("First-Last"). Returns true when it warned.
function Spy:AlertGuild(name, guild)
	local entry = Spy:WatchedGuild(guild)
	if not entry or not enabled("WarnOnGuildWatch") then
		return false
	end
	local display = name:gsub("%-", " ")
	local message = L["GuildNearby"]:format(display, entry.name) .. (entry.reason and (" (" .. entry.reason .. ")") or "")
	DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. message)
	if settings().DisplayWarnings == "ErrorFrame" then
		local color = settings().Colors and settings().Colors.Warning and settings().Colors.Warning["Warning Text"]
		UIErrorsFrame:AddMessage(message, color and color.r or 1, color and color.g or 0.8, color and color.b or 0.2, 1.0, UIERRORS_HOLD_TIME)
	else
		showAlert(display, entry.name, entry.reason)
	end
	if settings().EnableSound then
		Spy:PlaySound(SOUND, settings().SoundChannel)
	end
	entry.seen = time()
	entry.lastMember = name
	Spy.LastGuildAlert = { name = name, guild = entry.name, when = time() }
	return true
end

-- Enemies: Spy's own alert for a new enemy nearby. A Kill On Sight player keeps his
-- alert; a member of a watched guild gets this one instead of the "new enemy" sound.
local baseAlertPlayer = Spy.AlertPlayer
function Spy:AlertPlayer(player, source, ...)
	if source == nil or source == Spy.CharacterName then
		local playerData = SpyPerCharDB.PlayerData[player]
		if not SpyPerCharDB.KOSData[player] and playerData and playerData.guild then
			local ok, warned = pcall(Spy.AlertGuild, Spy, player, playerData.guild)
			if ok and warned then
				return
			end
		end
	end
	return baseAlertPlayer(self, player, source, ...)
end

-- Players of our faction: Spy:ScanUnit hands every one of them to Spy:WatchSeen.
local baseWatchSeen = Spy.WatchSeen
Spy.WatchSeen = function(self, name, unit, ...)
	Guard("GuildSeen", function()
		if not settings().Enabled or not unit then
			return
		end
		local guild = Spy:Readable((GetGuildInfo(unit)))
		if not Spy:WatchedGuild(guild) then
			return
		end
		local last = Spy.GuildAlerted[name]
		if last and GetTime() - last < FRIENDLY_COOLDOWN then
			return
		end
		Spy.GuildAlerted[name] = GetTime()
		Spy:AlertGuild(name, guild)
	end)()
	if baseWatchSeen then
		return baseWatchSeen(self, name, unit, ...)
	end
end

-- Options, slash commands, /spy debug ------------------------------------------------

local function sortedKeys()
	local keys = {}
	for k in pairs(Spy:GuildList()) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end

function Spy:GuildDescription(entry)
	local parts = { "<" .. entry.name .. ">" }
	if entry.reason then parts[#parts + 1] = "(" .. entry.reason .. ")" end
	if entry.seen then
		parts[#parts + 1] = "- " .. L["GuildLastSeen"]:format(tostring(entry.lastMember or "?"):gsub("%-", " "),
			date("%Y-%m-%d %H:%M", entry.seen))
	end
	return table.concat(parts, " ")
end

Spy.options.args.GuildOptions = {
	name = L["GuildOptions"],
	desc = L["GuildOptions"],
	type = "group",
	order = 7,
	args = {
		intro = { name = L["GuildOptionsDescription"], type = "description", order = 1, fontSize = "medium" },
		WarnOnGuildWatch = {
			name = L["WarnOnGuildWatch"],
			desc = L["WarnOnGuildWatchDescription"],
			type = "toggle",
			order = 2,
			width = "full",
			get = function() return enabled("WarnOnGuildWatch") end,
			set = function(_, value) Spy.db.profile.WarnOnGuildWatch = value end,
		},
		add = {
			name = L["GuildAdd"],
			desc = L["GuildAddDescription"],
			type = "input",
			order = 3,
			width = "full",
			get = function() return "" end,
			set = function(_, value) Spy:GuildCommand(value) end,
		},
		list = { name = L["GuildListTitle"], type = "group", inline = true, order = 4, args = {} },
	},
}

function Spy:RefreshGuildOptions()
	local args = {}
	local keys = sortedKeys()
	if #keys == 0 then
		args.empty = { name = L["GuildEmpty"], type = "description", order = 1 }
	end
	for index, k in ipairs(keys) do
		local entry = Spy:GuildList()[k]
		args["guild" .. index] = { name = Spy:GuildDescription(entry), type = "description", order = index * 2, width = 2.5 }
		args["remove" .. index] = {
			name = L["GuildRemoveButton"],
			type = "execute",
			order = index * 2 + 1,
			width = 0.6,
			func = function() Spy:ToggleGuild(entry.name) end,
		}
	end
	Spy.options.args.GuildOptions.args.list.args = args
	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry then
		registry:NotifyChange("Spy")
	end
end

-- "/spy guild" alone: the guild of the current target. "/spy guild Name: reason" otherwise.
function Spy:GuildCommand(value)
	value = tostring(value or "")
	local guild, reason = value:match("^([^:]*):(.*)$")
	guild = strtrim(guild or value)
	reason = reason and strtrim(reason) or nil
	if reason == "" then
		reason = nil
	end
	if guild == "" then
		guild = Spy:Readable(UnitExists("target")) and Spy:Readable((GetGuildInfo("target"))) or nil
		if type(guild) ~= "string" or guild == "" then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["GuildNoTarget"])
			return
		end
	end
	Spy:ToggleGuild(guild, reason)
end

Spy.optionsSlash.args.guild = {
	name = L["GuildSlash"],
	desc = L["GuildSlashDescription"],
	type = "input",
	order = 16,
	pattern = ".*",
	set = function(_, value) Spy:GuildCommand(value) end,
	dialogHidden = true,
}

Spy.optionsSlash.args.guilds = {
	name = L["GuildListSlash"],
	desc = L["GuildListSlashDescription"],
	type = "execute",
	order = 17,
	func = function()
		local keys = sortedKeys()
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["GuildListCount"]:format(#keys))
		for _, k in ipairs(keys) do
			DEFAULT_CHAT_FRAME:AddMessage("  " .. Spy:GuildDescription(Spy:GuildList()[k]))
		end
	end,
	dialogHidden = true,
}

-- Right-click menu on a player who has a guild: watch or forget that guild.
local MENUS = { "PLAYER", "TARGET", "FOCUS", "PARTY", "RAID_PLAYER", "ENEMY_PLAYER" }

local function addMenuEntry(owner, description, contextData)
	if Spy:SkipPlayerMenus() then
		return -- Forever.lua says why (controller interface)
	end
	local ok, err = pcall(function()
		local unit = type(contextData) == "table" and Spy:Readable(contextData.unit) or nil
		if type(unit) ~= "string" or Spy:Readable(UnitIsUnit(unit, "player")) then
			return
		end
		local guild = Spy:Readable((GetGuildInfo(unit)))
		if type(guild) ~= "string" or guild == "" then
			return
		end
		local text = Spy:WatchedGuild(guild) and L["MenuGuildRemove"] or L["MenuGuildAdd"]
		description:CreateButton(text:format(guild), function()
			Spy:ToggleGuild(guild)
		end)
	end)
	if not ok then
		Spy.ForeverLastError = "GuildMenu: " .. tostring(err)
	end
end

-- After Watch.lua's entries, so the button sits under its "Spy" title.
if Menu and Menu.ModifyMenu then
	for _, which in ipairs(MENUS) do
		pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, addMenuEntry)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", Guard("GuildEvents", function()
	if Spy.db and not Spy.GuildOptionsReady then
		Spy.GuildOptionsReady = true
		Spy:RefreshGuildOptions()
	end
end))

function Spy:GuildReport()
	local last = Spy.LastGuildAlert
	return ("Watched guilds: %d | warn %s | last alert: %s"):format(#sortedKeys(), enabled("WarnOnGuildWatch") and "yes" or "no",
		last and ("%s <%s> %ss ago"):format(last.name, last.guild, time() - last.when) or "none")
end
