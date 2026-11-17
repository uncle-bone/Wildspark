-- Spy on World of Warcraft: Forever.
--
-- Forever runs the retail client (Interface 16001) on the Vanilla world. Two things
-- change what Spy can do there:
--
-- 1. The combat log is closed to addons. COMBAT_LOG_EVENT_UNFILTERED has no payload
--    and nothing reads it, so Spy:CombatLogEvent is gone. What it told Spy now comes
--    from unit tokens: the nameplates, target, focus and mouseover, scanned when they
--    appear and again every second while they stay (that keeps an enemy "active",
--    like his actions in the combat log used to), their spell casts
--    (UNIT_SPELLCAST_SUCCEEDED: stealth alerts, level guesses from abilities), and
--    PARTY_KILL / the death recap for the win and loss counts.
--
-- 2. Values can be secret. The client hands addon code opaque values it may display
--    but not compare, concatenate or use as a table key. Everything read from the API
--    goes through Spy:Readable first, which turns a secret into nil.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")
local _

local SCAN_INTERVAL = 1           -- seconds between two scans of the visible units
local CAST_DEDUP_WINDOW = 1       -- one cast fires for every token of the caster
local TARGETING_WINDOW = 6        -- seconds before a death that "targeting me" counts
local RECAP_DELAYS = { 0.5, 2 }   -- the death recap is filled in shortly after PLAYER_DEAD

Spy.NamePlateUnits = {}
Spy.TargetingMe = {}
Spy.RecentCasts = {}
Spy.ForeverStats = { scans = 0, casts = 0, stealth = 0, kills = 0, deaths = 0 }

-- Secret values ---------------------------------------------------------------

function Spy:IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

-- The value itself, or nil when the client keeps it secret.
function Spy:Readable(value)
	if value == nil or Spy:IsSecret(value) then
		return nil
	end
	return value
end

-- CurseForge report: with the game's controller interface on, "AddOn 'Spy' tried to
-- call the protected function SetPreferredGamepadInteractTarget()" around party
-- invites, chat and targeting players, then the face buttons stop answering. Those
-- all go through the right-click menu on a player, where Spy adds its own entries
-- (Watch, Kill On Sight, Watch the guild). Entries made by an addon taint the menu,
-- and with the controller interface, opening it changes the controller bindings,
-- which ends in that protected call. So Spy keeps out of the game's player menus
-- while the controller interface is on, or when the option says so.
Spy.ForeverStats.menusSkipped = 0

function Spy:GamepadUIEnabled()
	if InputUtil and InputUtil.IsGamepadUIEnabled then
		local ok, on = pcall(InputUtil.IsGamepadUIEnabled)
		return ok and Spy:Readable(on) == true
	end
	return false
end

function Spy:SkipPlayerMenus()
	local profile = Spy.db and Spy.db.profile
	if (profile and profile.PlayerMenuEntries == false) or Spy:GamepadUIEnabled() then
		Spy.ForeverStats.menusSkipped = Spy.ForeverStats.menusSkipped + 1
		return true
	end
	return false
end

-- New handlers are guarded: an error is kept for /spy debug and announced once,
-- instead of breaking the event for the rest of the session.
local function Guard(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			Spy.ForeverLastError = label .. ": " .. tostring(err)
			if not Spy.ForeverErrorShown then
				Spy.ForeverErrorShown = true
				DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["ForeverError"])
			end
		end
	end
end
Spy.ForeverGuard = Guard

-- Client differences ------------------------------------------------------------

function Spy:GetZonePVPInfo()
	if C_PvP and C_PvP.GetZonePVPInfo then
		return Spy:Readable(C_PvP.GetZonePVPInfo())
	end
	if GetZonePVPInfo then
		return Spy:Readable(GetZonePVPInfo())
	end
end

-- Units -------------------------------------------------------------------------

-- "Name" or "Name-Realm", the key Spy uses everywhere (what GetUnitName(unit, true)
-- returned on Classic), for a player unit whose name the client lets us read.
function Spy:PlayerName(unit)
	if not Spy:Readable(UnitExists(unit)) or not Spy:Readable(UnitIsPlayer(unit)) then
		return nil
	end
	local name, realm = UnitName(unit)
	if Spy:IsSecret(name) or Spy:IsSecret(realm) then
		return nil
	end
	if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
		return nil
	end
	if type(realm) == "string" and realm ~= "" then
		name = name .. "-" .. realm
	end
	return name
end

function Spy:EnemyPlayerName(unit)
	local name = Spy:PlayerName(unit)
	if name and Spy:Readable(UnitIsEnemy("player", unit)) then
		return name
	end
	return nil
end

-- Forever: the GUIDs of the players we read, mapped to the name Spy keys them by.
-- GetPlayerInfoByGUID does not give the "First-Last" key UnitName gives (Forever
-- names have a surname where Classic had the realm), so a kill or a death recap that
-- only carries a GUID is matched through what the scan already saw.
Spy.GUIDNames = {}
Spy.SecretClass = {} -- name -> class the client keeps secret (battlegrounds), for this session only
Spy.GUIDNameCount = 0
local GUID_NAME_LIMIT = 2000

function Spy:RememberGUID(unit, name)
	local guid = Spy:Readable(UnitGUID(unit))
	if type(guid) ~= "string" or Spy.GUIDNames[guid] == name then
		return
	end
	if Spy.GUIDNameCount >= GUID_NAME_LIMIT then
		Spy.GUIDNames, Spy.GUIDNameCount = {}, 0
	end
	if not Spy.GUIDNames[guid] then
		Spy.GUIDNameCount = Spy.GUIDNameCount + 1
	end
	Spy.GUIDNames[guid] = name
end

-- The key Spy uses for a player, from a name and realm (or surname) given by some
-- other API: "First-Last" as the scan writes it, "First Last" with a space, a bare
-- first name that matches a single known "First-Something". nil when Spy does not
-- know the player.
function Spy:KnownPlayerKey(name, realm)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local known = SpyPerCharDB and SpyPerCharDB.PlayerData or {}
	local candidates = {}
	if type(realm) == "string" and realm ~= "" then
		candidates[#candidates + 1] = name .. "-" .. realm
		candidates[#candidates + 1] = name .. "-" .. realm:gsub("%s", "")
	end
	candidates[#candidates + 1] = name
	candidates[#candidates + 1] = (name:gsub("%s+", "-"))
	for _, key in ipairs(candidates) do
		if known[key] then
			return key
		end
	end
	local first = name:match("^([^%s%-]+)")
	if not first then
		return nil
	end
	local found
	local prefix = first:lower() .. "-"
	for key in pairs(known) do
		if key:lower():sub(1, #prefix) == prefix then
			if found then
				return nil -- two players share this first name: no guess
			end
			found = key
		end
	end
	return found
end

-- The key of the player behind a GUID, or nil when Spy cannot tell. The second value
-- says how it was found (for /spy debug).
function Spy:PlayerNameFromGUID(guid)
	guid = Spy:Readable(guid)
	if type(guid) ~= "string" or not guid:find("^Player%-") then
		return nil, "no player GUID"
	end
	if Spy.GUIDNames[guid] then
		return Spy.GUIDNames[guid], "seen"
	end
	local ok, _, _, _, _, _, name, realm = pcall(GetPlayerInfoByGUID, guid)
	if not ok or Spy:IsSecret(name) or Spy:IsSecret(realm) then
		return nil, "name hidden"
	end
	if type(name) ~= "string" or name == "" then
		return nil, "no name"
	end
	local key = Spy:KnownPlayerKey(name, realm)
	if key then
		return key, "matched"
	end
	if type(realm) == "string" and realm ~= "" then
		name = name .. "-" .. realm
	end
	return name, "unknown " .. name
end

-- The Classic target, mouseover and nameplate handlers, merged. Same fields, same
-- level guess for a skull, same lists; returns the name when the unit is an enemy.
function Spy:ScanUnit(unit)
	local name = Spy:PlayerName(unit)
	if not name or SpyPerCharDB.IgnoreData[name] then
		return nil
	end
	Spy.ForeverStats.scans = Spy.ForeverStats.scans + 1
	Spy:RememberGUID(unit, name)
	local playerData = SpyPerCharDB.PlayerData[name]
	local isEnemy = Spy:Readable(UnitIsEnemy("player", unit))
	if isEnemy then
		local learnt = true
		if playerData and playerData.isGuess == false then learnt = false end

		local rawClass = select(2, UnitClass(unit))
		local class = Spy:Readable(rawClass)
		-- In a battleground the client keeps the class secret (identity restricted):
		-- the row came out black. Kept for the session to colour the row with, see
		-- Spy:SetBar in Display.lua; the client draws the colour without telling us.
		if class == nil and Spy:IsSecret(rawClass) then
			Spy.SecretClass[name] = rawClass
		end
		local race = Spy:Readable((UnitRace(unit)))
		local level = tonumber(Spy:Readable(UnitLevel(unit)))
		local guild = Spy:Readable((GetGuildInfo(unit)))
		local faction = Spy:Readable((UnitFactionGroup(unit)))
		local guess = false
		if level == Spy.Skull then
			if playerData and playerData.level then
				if playerData.level > (UnitLevel("player") + 10) and playerData.level < Spy.MaximumPlayerLevel then
					guess = true
					level = nil
				elseif UnitLevel("player") < Spy.MaximumPlayerLevel - 9 then
					guess = true
					level = UnitLevel("player") + 10
				end
			else
				guess = true
				level = UnitLevel("player") + 10
			end
		end
		-- The Classic PvP ranks (UnitPVPRank) do not exist on Forever.
		Spy:UpdatePlayerData(name, class, level, race, guild, faction, true, guess, nil)
		if Spy.EnabledInZone then
			Spy:AddDetected(name, time(), learnt)
		end
		return name
	elseif isEnemy == false then
		if playerData then
			Spy:RemovePlayerData(name)
		end
		-- A player of our faction: only the watch list cares (Watch.lua).
		if Spy.WatchSeen then
			Spy:WatchSeen(name, unit)
		end
	end
	return nil
end

-- Nameplates ----------------------------------------------------------------------

-- CurseForge comment "no stealth rogue alert?": a rogue who stealths loses his
-- nameplate at once, and the cast often arrives after it, on a token that points at
-- nobody any more. The name read on each nameplate is kept, and for a moment after the
-- nameplate goes, a cast on that token is put down to its last enemy.
Spy.PlateNames = {}
Spy.GonePlates = {}
local GONE_WINDOW = 1.5

Spy.NamePlateEvent = Guard("NamePlateEvent", function(self, event, unit)
	if type(unit) ~= "string" then
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		Spy.NamePlateUnits[unit] = true
		Spy.GonePlates[unit] = nil
		Spy.PlateNames[unit] = Spy:ScanUnit(unit)
	else
		Spy.NamePlateUnits[unit] = nil
		if Spy.PlateNames[unit] then
			Spy.GonePlates[unit] = { name = Spy.PlateNames[unit], at = GetTime() }
		end
		Spy.PlateNames[unit] = nil
	end
end)

function Spy:NoteTargetingMe(unit, name)
	local ok, same = pcall(UnitIsUnit, unit .. "target", "player")
	if ok and Spy:Readable(same) then
		Spy.TargetingMe[name] = GetTime()
	end
end

-- Every second: the enemies still on screen stay active, and whoever targets us is
-- noted for the loss count.
Spy.ScanVisibleUnits = Guard("ScanVisibleUnits", function(self)
	if not Spy.EnabledInZone then
		return
	end
	for unit in pairs(Spy.NamePlateUnits) do
		if Spy:Readable(UnitExists(unit)) then
			local name = Spy:ScanUnit(unit)
			Spy.PlateNames[unit] = name
			if name then Spy:NoteTargetingMe(unit, name) end
		else
			Spy.NamePlateUnits[unit] = nil
		end
	end
	for _, unit in ipairs({ "target", "focus" }) do
		local name = Spy:ScanUnit(unit)
		if name then Spy:NoteTargetingMe(unit, name) end
	end
	local now = GetTime()
	for name, when in pairs(Spy.TargetingMe) do
		if now - when > 60 then Spy.TargetingMe[name] = nil end
	end
	for key, when in pairs(Spy.RecentCasts) do
		if now - when > CAST_DEDUP_WINDOW then Spy.RecentCasts[key] = nil end
	end
end)

function Spy:StartUnitScan()
	if not Spy.UnitScanTimer then
		Spy.UnitScanTimer = Spy:ScheduleRepeatingTimer("ScanVisibleUnits", SCAN_INTERVAL)
	end
end

function Spy:StopUnitScan()
	if Spy.UnitScanTimer then
		Spy:CancelTimer(Spy.UnitScanTimer)
		Spy.UnitScanTimer = nil
	end
end

-- Spell casts -----------------------------------------------------------------------

-- Classic warned on the Stealth and Prowl auras seen in the combat log. Vanish puts a
-- rogue in stealth as well. The names catch ranks or IDs Forever may have changed.
local STEALTH_SPELLS = { [1784] = true, [1785] = true, [1786] = true, [1787] = true, [1856] = true, [1857] = true }
local PROWL_SPELLS = { [5215] = true, [6783] = true, [9913] = true }

function Spy:StealthKind(spellID)
	if STEALTH_SPELLS[spellID] then return "stealth" end
	if PROWL_SPELLS[spellID] then return "prowl" end
	local spellName = C_Spell and C_Spell.GetSpellName and Spy:Readable(C_Spell.GetSpellName(spellID))
	if spellName and spellName == L["Stealth"] then return "stealth" end
	if spellName and spellName == L["Prowl"] then return "prowl" end
	return nil
end

local WATCHED_UNITS = { target = true, focus = true, mouseover = true }

local function isWatchedUnit(unit)
	return type(unit) == "string" and (WATCHED_UNITS[unit] or unit:find("^nameplate%d+$") ~= nil)
end

Spy.SpellCastEvent = Guard("SpellCastEvent", function(self, event, unit, castGUID, spellID)
	if not Spy.EnabledInZone or not isWatchedUnit(unit) then
		return
	end
	local name = Spy:ScanUnit(unit)
	local gone = false
	if not name then
		local last = Spy.GonePlates[unit]
		if not (last and GetTime() - last.at <= GONE_WINDOW) then
			return
		end
		name, gone = last.name, true
	end
	local rawSpellID = spellID
	spellID = Spy:Readable(spellID)
	if type(spellID) ~= "number" then
		if Spy:IsSecret(rawSpellID) then
			Spy.ForeverStats.hiddenCasts = (Spy.ForeverStats.hiddenCasts or 0) + 1
		end
		return
	end
	-- The same cast arrives once per token pointing at the caster.
	local key = name .. ":" .. spellID
	local now = GetTime()
	if Spy.RecentCasts[key] and now - Spy.RecentCasts[key] < CAST_DEDUP_WINDOW then
		return
	end
	Spy.RecentCasts[key] = now
	Spy.ForeverStats.casts = Spy.ForeverStats.casts + 1
	if not gone then
		Spy:NoteTargetingMe(unit, name)
	end

	-- Classic learnt the level of a skull from the abilities in the combat log.
	local playerData = SpyPerCharDB.PlayerData[name]
	if playerData and playerData.isGuess then
		local learnt = Spy:ParseUnitAbility(true, "SPELL_CAST_SUCCESS", name, playerData.class, playerData.race, spellID, nil)
		if learnt then
			Spy:AddDetected(name, time(), learnt)
		end
	end

	local kind = Spy:StealthKind(spellID)
	if kind then
		Spy.ForeverStats.stealth = Spy.ForeverStats.stealth + 1
		if gone then
			Spy.ForeverStats.goneStealth = (Spy.ForeverStats.goneStealth or 0) + 1
		end
		Spy.LastStealth = { name = name, spellID = spellID, when = time(), gone = gone }
		if kind == "prowl" then
			Spy:AlertProwlPlayer(name)
		else
			Spy:AlertStealthPlayer(name)
		end
	end
end)

-- Wins and losses ------------------------------------------------------------------

function Spy:IsMineGUID(guid)
	if guid == Spy:Readable(UnitGUID("player")) or guid == Spy:Readable(UnitGUID("pet")) then
		return true
	end
	return Spy.PetGUID[guid] ~= nil
end

-- A member of the group (or his pet) by GUID: their kills go on the combat map.
function Spy:IsGroupGUID(guid)
	local count = GetNumGroupMembers and GetNumGroupMembers() or 0
	if count == 0 then
		return false
	end
	local raid = IsInRaid and IsInRaid()
	local prefix, last = raid and "raid" or "party", raid and count or math.min(count, 4)
	for i = 1, last do
		for _, unit in ipairs({ prefix .. i, prefix .. "pet" .. i }) do
			if guid == Spy:Readable(UnitGUID(unit)) then
				return true
			end
		end
	end
	return false
end

-- PARTY_KILL replaces the combat log PARTY_KILL and the pet overkill check. A win
-- counts our killing blow or our pet's, as on Classic; a group member's kill only
-- goes on the combat map.
Spy.PartyKillEvent = Guard("PartyKillEvent", function(self, event, attackerGUID, targetGUID)
	if not Spy.EnabledInZone then
		return
	end
	Spy.ForeverStats.partyKills = (Spy.ForeverStats.partyKills or 0) + 1
	local seen = { when = time() }
	Spy.LastPartyKill = seen
	attackerGUID = Spy:Readable(attackerGUID)
	if not attackerGUID then
		seen.result = "killer hidden"
		return
	end
	local mine = Spy:IsMineGUID(attackerGUID)
	if not mine and not Spy:IsGroupGUID(attackerGUID) then
		seen.result = "not us or our group"
		return
	end
	local name, how = Spy:PlayerNameFromGUID(targetGUID)
	local playerData = name and SpyPerCharDB.PlayerData[name]
	if not playerData then
		seen.result = "victim " .. tostring(how)
		return
	end
	seen.result = (mine and "our kill: " or "group kill: ") .. name .. " (" .. how .. ")"
	if mine then
		playerData.wins = (playerData.wins or 0) + 1
		Spy.ForeverStats.kills = Spy.ForeverStats.kills + 1
		Spy.LastKill = { name = name, when = time() }
	end
	if Spy.RecordEncounter then
		Spy:RecordEncounter(name, "W", mine and "kill" or "group")
	end
end)

local function recapID()
	if not (C_DeathRecap and C_DeathRecap.GetRecapLink) then
		return nil
	end
	local ok, link = pcall(C_DeathRecap.GetRecapLink)
	link = ok and Spy:Readable(link)
	if type(link) ~= "string" then
		return nil
	end
	return tonumber(link:match("death:(%d+)"))
end

local function isSecretTable(value)
	return issecrettable ~= nil and issecrettable(value) == true
end

-- The killing blow of the latest death recap (the first event, as the Blizzard recap
-- reads it), when it names a player we know. The second value says why not:
-- "stale" while the recap still describes an earlier death, "no player" when the
-- blow came from a creature, a fall or someone Spy never saw (no loss then, as on
-- Classic), anything else when the recap could not be read at all.
function Spy:KillerFromRecap()
	if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then
		return nil, "unavailable"
	end
	local id = recapID()
	if id and id == Spy.LastRecapID then
		return nil, "stale"
	end
	-- This recap belongs to this death now, read or not: never blame it on the next one.
	Spy.LastRecapID = id
	local ok, events = pcall(C_DeathRecap.GetRecapEvents)
	if not ok or type(events) ~= "table" or isSecretTable(events) then
		return nil, "unreadable"
	end
	local event = events[1]
	if type(event) ~= "table" or isSecretTable(event) then
		return nil, "empty"
	end
	-- Combat log timestamps are epoch seconds: one from minutes ago is a recap left
	-- over from before a /reload.
	local stamp = Spy:Readable(event.timestamp)
	if type(stamp) == "number" and stamp > 1000000000 and math.abs(time() - stamp) > 60 then
		return nil, "stale"
	end
	if Spy:Readable(event.hideCaster) then
		return nil, "hidden"
	end
	local name = Spy:PlayerNameFromGUID(event.sourceGUID)
	if not (name and SpyPerCharDB.PlayerData[name]) then
		local sourceName = Spy:Readable(event.sourceName)
		if type(sourceName) == "string" and sourceName ~= "" then
			name = Spy:KnownPlayerKey(sourceName) or name
		end
	end
	if name and SpyPerCharDB.PlayerData[name] then
		return name, "recap"
	end
	return nil, "no player"
end

-- Recap answers that leave the question open; after them the targeting guess runs.
local RECAP_UNKNOWN = { unavailable = true, unreadable = true, empty = true, stale = true, hidden = true }

-- The enemy players who had us targeted in the last seconds, taken at the moment of
-- death: the scan keeps running while we wait for the recap and would move them on.
function Spy:DeathSuspects()
	local suspects, now = {}, GetTime()
	for name, when in pairs(Spy.TargetingMe) do
		if now - when <= TARGETING_WINDOW then
			suspects[#suspects + 1] = name
		end
	end
	return suspects
end

-- Fallback when the recap could not say: the one enemy player who had us targeted
-- just before we died. Two or more of them and nobody gets the kill.
function Spy:KillerFromTargeting(suspects)
	if #suspects == 1 and SpyPerCharDB.PlayerData[suspects[1]] then
		return suspects[1], "targeting"
	end
	return nil, #suspects > 1 and "several targeting" or "nobody targeting"
end

-- CurseForge comment: a hunter got losses for fights he won, maybe from Feign Death.
-- Feign Death leaves no death recap, so the "who had us targeted" guess blamed the
-- enemy he was fighting. A death only counts while we are really dead or a ghost.
local FEIGN_DEATH = 5384

function Spy:IsFeigningDeath()
	if UnitIsFeignDeath then
		local ok, feigning = pcall(UnitIsFeignDeath, "player")
		if ok and Spy:Readable(feigning) == true then
			return true
		end
	end
	if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, FEIGN_DEATH)
		if ok and type(aura) == "table" and not isSecretTable(aura) then
			return true
		end
	end
	return false
end

-- False only when the game says plainly that we are alive (or feigning).
function Spy:ReallyDead()
	if Spy:IsFeigningDeath() then
		return false
	end
	if UnitIsDeadOrGhost then
		local ok, dead = pcall(UnitIsDeadOrGhost, "player")
		if ok and Spy:Readable(dead) == false then
			return false
		end
	end
	return true
end

function Spy:ResolveDeath(suspects, attempt)
	if not Spy:ReallyDead() then
		Spy.LastDeath = { how = "not counted: alive again (Feign Death?)", when = time() }
		return
	end
	local killer, how = Spy:KillerFromRecap()
	if not killer and how == "stale" and attempt < #RECAP_DELAYS then
		Spy:ScheduleTimer(function()
			Guard("ResolveDeath", Spy.ResolveDeath)(Spy, suspects, attempt + 1)
		end, RECAP_DELAYS[attempt + 1] - RECAP_DELAYS[attempt])
		return
	end
	if not killer and RECAP_UNKNOWN[how] then
		local recapResult = how
		killer, how = Spy:KillerFromTargeting(suspects)
		how = how .. " (recap: " .. recapResult .. ")"
	elseif not killer then
		how = "recap: " .. how
	end
	Spy.LastDeath = { killer = killer, how = how, when = time() }
	if killer then
		local playerData = SpyPerCharDB.PlayerData[killer]
		playerData.loses = (playerData.loses or 0) + 1
		Spy.ForeverStats.deaths = Spy.ForeverStats.deaths + 1
		if Spy.RecordEncounter then
			Spy:RecordEncounter(killer, "L", how:match("^%a+"), suspects.where, suspects.when)
		end
	end
end

Spy.PlayerDeadEvent = Guard("PlayerDeadEvent", function(self)
	if not Spy.EnabledInZone then
		return
	end
	if Spy:IsFeigningDeath() then
		Spy.LastDeath = { how = "not counted: Feign Death", when = time() }
		return
	end
	local suspects = Spy:DeathSuspects()
	-- Where and when we fell: the recap is read later, maybe after a release.
	suspects.where = Spy.PlayerPosition and Spy:PlayerPosition()
	suspects.when = time()
	Spy:ScheduleTimer(function()
		Guard("ResolveDeath", Spy.ResolveDeath)(Spy, suspects, 1)
	end, RECAP_DELAYS[1])
end)

-- Minimap button ----------------------------------------------------------------------
-- Hand placed like the other Forever addons, named SpyMinimapButton so MinimapButtons
-- can collect it.

local MINIMAP_RADIUS = 80
-- Right side of the minimap, a little above the middle: the widest gap left between
-- TargetTooltip (6.0) and Vitals (1.2).
Spy.MinimapDefaultAngle = 0.45

local minimapButton

local function minimapSettings()
	local settings = Spy.db.profile.MinimapButton
	if type(settings) ~= "table" then
		settings = {}
		Spy.db.profile.MinimapButton = settings
	end
	local angle = settings.angle
	if type(angle) ~= "number" or angle ~= angle or angle == math.huge or angle == -math.huge then
		settings.angle = Spy.MinimapDefaultAngle
	end
	if settings.hide == nil then
		settings.hide = false
	end
	return settings
end

local function placeMinimapButton(angle)
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * MINIMAP_RADIUS, math.sin(angle) * MINIMAP_RADIUS)
end

local function angleFromCursor()
	local scale = Spy:Readable(UIParent:GetEffectiveScale())
	if not scale or scale <= 0 then scale = 1 end
	local cursorX, cursorY = GetCursorPosition()
	cursorX = (Spy:Readable(cursorX) or 0) / scale
	cursorY = (Spy:Readable(cursorY) or 0) / scale
	local centerX, centerY = Minimap:GetCenter()
	return math.atan2(cursorY - (Spy:Readable(centerY) or 0), cursorX - (Spy:Readable(centerX) or 0))
end

local function countKeys(list)
	local count = 0
	for _ in pairs(list) do count = count + 1 end
	return count
end

function Spy:ShowMinimapTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	GameTooltip:AddLine("Spy")
	if not Spy.db.profile.Enabled then
		GameTooltip:AddLine(L["MinimapOff"], 1, 0.3, 0.3)
	elseif not Spy.EnabledInZone then
		GameTooltip:AddLine(L["MinimapOffInZone"], 1, 0.82, 0)
	else
		GameTooltip:AddLine(L["MinimapNearby"]:format(countKeys(Spy.NearbyList), countKeys(Spy.ActiveList)), 1, 1, 1)
		local kos = {}
		for name in pairs(Spy.NearbyList) do
			if SpyPerCharDB.KOSData[name] then kos[#kos + 1] = name end
		end
		if #kos > 0 then
			table.sort(kos)
			GameTooltip:AddLine(L["MinimapKoSNearby"]:format(table.concat(kos, ", ")), 1, 0.2, 0.2, true)
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["MinimapLeftClick"], 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L["MinimapRightClick"], 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L["MinimapDrag"], 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

-- Left click does what the title bar close button and /spy show do. The window holds
-- secure target buttons, so like the rest of Spy it is left alone during combat.
function Spy:ToggleMainWindow()
	if InCombatLockdown() then
		return
	end
	if Spy.MainWindow:IsShown() then
		Spy.MainWindow:Hide()
	elseif Spy.db.profile.Enabled then
		Spy.MainWindow:Show()
		Spy:RefreshCurrentList()
	else
		Spy:EnableSpy(true, true)
	end
end

function Spy:RefreshMinimapButton()
	if not minimapButton then
		return
	end
	local settings = minimapSettings()
	placeMinimapButton(settings.angle)
	minimapButton:SetShown(not settings.hide)
	minimapButton.icon:SetDesaturated(not Spy.db.profile.Enabled)
end

function Spy:SetMinimapButtonShown(shown)
	minimapSettings().hide = not shown
	Spy:RefreshMinimapButton()
end

function Spy:CreateMinimapButton()
	if minimapButton or not Minimap then
		return minimapButton
	end
	minimapButton = CreateFrame("Button", "SpyMinimapButton", Minimap)
	minimapButton:SetSize(31, 31)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetFrameLevel(8)
	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:RegisterForDrag("LeftButton")
	minimapButton:SetMovable(true)

	local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	minimapButton.icon = icon

	local border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	minimapButton:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			Spy:ShowConfig()
		else
			Spy:ToggleMainWindow()
		end
		if GameTooltip:IsOwned(self) then Spy:ShowMinimapTooltip(self) end
	end)
	minimapButton:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local settings = minimapSettings()
			settings.angle = angleFromCursor()
			placeMinimapButton(settings.angle)
		end)
	end)
	minimapButton:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	minimapButton:SetScript("OnEnter", function(self) Spy:ShowMinimapTooltip(self) end)
	minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	Spy.MinimapButton = minimapButton
	Spy:RefreshMinimapButton()
	return minimapButton
end

-- Row clicks ------------------------------------------------------------------------------
-- Forever characters have a first name and a surname ("Glory Boy"). For other players the
-- client hands the surname where Classic had the realm, so Spy keys them "Fetto-Vandike", and
-- "/targetexact Fetto-Vandike" finds nobody (seen in game). The macro clears the target, then
-- tries "First Surname", "First-Surname", the first name alone and a loose match, each only
-- while nothing is targeted ([noexists]), so a later line never replaces a found player.
function Spy:TargetMacro(name)
	local first, second = name:match("^([^%-]+)%-(.+)$")
	if not first then
		return "/targetexact " .. name
	end
	return table.concat({
		"/cleartarget",
		"/targetexact " .. first .. " " .. second,
		"/targetexact [noexists] " .. name,
		"/targetexact [noexists] " .. first,
		"/target [noexists] " .. first .. " " .. second,
	}, "\n")
end

-- A row is a secure button that runs "/targetexact <name>". The macro is written into each
-- row as soon as the list changes (out of combat), not only in the click itself, and every
-- click is recorded for /spy debug, with what the target was right after.

function Spy:NoteRowClick(row, name, button, down)
	local click = Spy.LastRowClick
	if down or not click or click.row ~= row or GetTime() - click.at > 2 then
		click = { row = row, at = GetTime(), when = time(), events = "" }
		Spy.LastRowClick = click
	end
	click.name = name
	click.button = button
	click.combat = InCombatLockdown()
	click.events = click.events .. (down and "press " or "release ")
	click.modifiers = (IsShiftKeyDown() and "Shift " or "") .. (IsControlKeyDown() and "Ctrl " or "")
	local onClick = row.GetScript and row:GetScript("OnClick")
	click.secure = ("type1=%s protected=%s onclick=%s"):format(tostring(Spy:Readable(row:GetAttribute("type1"))),
		tostring(row.IsProtected and row:IsProtected()),
		onClick == nil and "none" or (onClick == SecureActionButton_OnClick and "secure" or "other"))
end

-- What the client really ran after a click: the secure macro, then the targeting call.
Spy.SecureTrace = {}
local function traceSecure(what)
	table.insert(Spy.SecureTrace, 1, { what = what, when = time() })
	Spy.SecureTrace[9] = nil
end
if C_Macro and C_Macro.RunMacroText then
	hooksecurefunc(C_Macro, "RunMacroText", function(text, button)
		traceSecure(("RunMacroText(%s, %s)"):format(tostring(Spy:Readable(text)):gsub("\n", " / "), tostring(button)))
	end)
end
if TargetUnit then
	hooksecurefunc("TargetUnit", function(name, exact)
		traceSecure(("TargetUnit(%s, %s)"):format(tostring(Spy:Readable(name)), tostring(exact)))
	end)
end

-- A press over the Spy window: which frame the client gave it to.
local mouseWatcher = CreateFrame("Frame")
pcall(mouseWatcher.RegisterEvent, mouseWatcher, "GLOBAL_MOUSE_DOWN")
-- Guarded: with a controller the client sends presses of its own here (CurseForge
-- comment: "occasionally crashes when using controller"), and a debug trace must
-- never be the thing that breaks.
mouseWatcher:SetScript("OnEvent", Guard("WindowPress", function(_, _, button)
	if type(button) ~= "string" or not button:find("Button$") then
		return -- not a mouse button: a gamepad press
	end
	local window = Spy.MainWindow
	if not (window and window:IsShown() and window:IsMouseOver()) then
		return
	end
	local names = {}
	local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
	for _, focus in ipairs(foci or {}) do
		local ok, name = pcall(focus.GetDebugName or focus.GetName, focus)
		names[#names + 1] = ok and tostring(name) or "?"
	end
	Spy.LastWindowPress = { when = time(), button = tostring(button), under = #names > 0 and table.concat(names, ", ") or "nothing" }
end))

local function noteRowResult(row)
	local click = Spy.LastRowClick
	if click and click.row == row then
		click.macro = Spy:Readable(row:GetAttribute("macrotext"))
		click.targetAfter = Spy:PlayerName("target") or (Spy:Readable(UnitExists("target")) and "a non-player") or "none"
	end
end

local baseCreateRow = Spy.CreateRow
function Spy:CreateRow(num, ...)
	local existed = Spy.MainWindow.Rows[num]
	baseCreateRow(self, num, ...)
	local row = Spy.MainWindow.Rows[num]
	if row and not existed then
		row:HookScript("PostClick", noteRowResult)
	end
end

local baseRefreshCurrentList = Spy.RefreshCurrentList
function Spy:RefreshCurrentList(...)
	baseRefreshCurrentList(self, ...)
	if InCombatLockdown() or not (Spy.MainWindow and Spy.MainWindow.Rows) then
		return
	end
	for index, row in pairs(Spy.MainWindow.Rows) do
		local name = Spy.ButtonName[index]
		if name and name ~= "" then
			local macro = Spy:TargetMacro(name)
			if row:GetAttribute("macrotext") ~= macro then
				row:SetAttribute("macrotext", macro)
			end
		end
	end
end

-- The client reports actions it refused to an addon: keep Spy's for /spy debug.
Spy.BlockedActions = {}
local blockedWatcher = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "MACRO_ACTION_BLOCKED", "MACRO_ACTION_FORBIDDEN" }) do
	pcall(blockedWatcher.RegisterEvent, blockedWatcher, event)
end
blockedWatcher:SetScript("OnEvent", function(_, event, first, second)
	local addon, fn = first, second
	if event:find("^MACRO") then
		addon, fn = "macro", first
	end
	addon, fn = Spy:Readable(addon), Spy:Readable(fn)
	if addon == "Spy" or addon == "macro" then
		table.insert(Spy.BlockedActions, 1, { event = event, fn = tostring(fn), when = time() })
		Spy.BlockedActions[6] = nil
	end
end)

-- The Spy window --------------------------------------------------------------------------
-- The window holds secure buttons, so the client refuses to show or hide it in combat. What
-- Spy wanted to do then is done when combat ends. Every show and hide is recorded with the
-- line of code that asked for it, and Spy says in chat when it turns itself off in a zone.

Spy.WindowLog = {}

local function callerOf(stack)
	local places = {}
	-- retail stacks read "[Interface/AddOns/Spy/Spy.lua]:123:" (older clients: "Spy.lua:123:")
	for file, line in tostring(stack or ""):gmatch("([%w_%-]+%.[lx][um][al])%]?:(%d+)") do
		if file ~= "Forever.lua" and #places < 3 then
			places[#places + 1] = file .. ":" .. line
		end
	end
	return #places > 0 and table.concat(places, " < ") or "?"
end

local function logWindow(shown)
	table.insert(Spy.WindowLog, 1, {
		shown = shown, when = time(), combat = InCombatLockdown(), zoneOn = Spy.EnabledInZone,
		where = callerOf(debugstack and debugstack(3, 6, 0)),
	})
	Spy.WindowLog[6] = nil
end

function Spy:WatchMainWindow()
	if Spy.MainWindow and not Spy.MainWindowWatched then
		Spy.MainWindowWatched = true
		Spy.MainWindow:HookScript("OnShow", function() logWindow(true) end)
		Spy.MainWindow:HookScript("OnHide", function() logWindow(false) end)
	end
end

local baseLeftCombatEvent = Spy.LeftCombatEvent
function Spy:LeftCombatEvent(...)
	baseLeftCombatEvent(self, ...)
	local window = Spy.MainWindow
	if Spy.ShowAfterCombat then
		Spy.ShowAfterCombat = nil
		if Spy.db.profile.Enabled and Spy.EnabledInZone and not window:IsShown() then
			window:Show()
			Spy:RefreshCurrentList()
		end
	end
	if Spy.HideAfterCombat then
		Spy.HideAfterCombat = nil
		if (not Spy.db.profile.Enabled or not Spy.EnabledInZone) and window:IsShown() then
			window:Hide()
		end
	end
end

-- Debug ---------------------------------------------------------------------------------

local function yesNo(value)
	if Spy:IsSecret(value) then return "<secret>" end
	if value == nil then return "?" end
	return value and "yes" or "no"
end

-- The result of an API call that may not exist or may refuse its arguments.
local function try(fn, ...)
	if not fn then return nil end
	local ok, value = pcall(fn, ...)
	if ok then return value end
	return nil
end

local function cvarBool(name)
	if not (C_CVar and C_CVar.GetCVarBool) then
		return nil
	end
	local ok, value = pcall(C_CVar.GetCVarBool, name)
	if ok then
		return Spy:Readable(value)
	end
	return nil
end

function Spy:NameplatesEnabled()
	return cvarBool("nameplateShowEnemies")
end

-- "Always show nameplates" (Options > Nameplates). Off, the client only shows
-- nameplates while you are in combat, so Spy sees almost nobody (CurseForge comments:
-- "only when I mouse over them").
function Spy:NameplatesAlways()
	return cvarBool("nameplateShowAll")
end

-- /spy nameplates: turns both on. CVars cannot be changed in combat.
function Spy:TurnOnNameplates()
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["NameplatesCombat"])
		return false
	end
	for _, name in ipairs({ "nameplateShowEnemies", "nameplateShowAll" }) do
		pcall(C_CVar.SetCVar, name, "1")
	end
	local done = Spy:NameplatesEnabled() ~= false and Spy:NameplatesAlways() ~= false
	DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. (done and L["NameplatesDone"] or L["NameplatesFailed"]))
	return done
end

-- The retail client keeps its own copy of the position of a frame moved with
-- StartMoving (layout-local.txt) and puts it back at login, anchored by another point
-- and with the height the window had at logout: Spy's window moved at each /reload,
-- locked or not (CurseForge comment). Spy saves and restores its windows itself.
function Spy:NoClientLayout(frame)
	if frame.SetDontSavePosition then
		pcall(frame.SetDontSavePosition, frame, true)
	end
	if frame.SetUserPlaced then
		pcall(frame.SetUserPlaced, frame, false)
	end
end

function Spy:DescribeUnit(unit)
	if not Spy:Readable(UnitExists(unit)) then
		return "none"
	end
	local secretIdentity = try(C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret, unit)
	local name = Spy:PlayerName(unit)
	if not name then
		local raw = UnitName(unit)
		if Spy:IsSecret(raw) then
			return "<hidden name> (identity secret: " .. yesNo(secretIdentity) .. ")"
		end
		return tostring(raw) .. " (not a player)"
	end
	local class = Spy:Readable((select(2, UnitClass(unit))))
	local level = Spy:Readable(UnitLevel(unit))
	local enemy = Spy:Readable(UnitIsEnemy("player", unit))
	return ("%s, %s %s, %s, identity secret: %s"):format(name, tostring(level or "?"), tostring(class or "?"),
		enemy and "enemy" or "not an enemy", yesNo(secretIdentity))
end

-- The original turns Spy off at each loading screen and checks the zone 6 s later, and
-- every chat channel notice in between pushes the check back by 6 s more. With notices
-- arriving all the time (an addon joining and leaving channels) the check never ran and
-- Spy stayed off: /spy debug said "zone change still being processed" (CurseForge
-- comment). As a safety net, Spy off for 15 s with no reason left to be off (and no
-- wait running) runs the check itself.
-- The zones to stay off in are kept by their English name ("Booty Bay"), and the
-- original compared that name with GetZoneText/GetSubZoneText, which give the zone in
-- the client's language: outside English clients no listed zone ever matched (CurseForge
-- comment: "I'm in Booty Bay, I have it deactivated, yet the notifications pop up").
-- A listed zone now matches its English name or its translation, in any case.
local function sameName(a, b)
	return type(a) == "string" and type(b) == "string" and a ~= "" and a:lower() == b:lower()
end

function Spy:InFilteredZone(zone, subZone)
	zone, subZone = Spy:Readable(zone), Spy:Readable(subZone)
	for filteredZone, value in pairs(Spy.db.profile.FilteredZones or {}) do
		if value then
			local translated = rawget(L, filteredZone) -- no lookup warning for a zone without translation
			for _, name in ipairs({ filteredZone, translated }) do
				if sameName(zone, name) or sameName(subZone, name) then
					return true
				end
			end
		end
	end
	return false
end

-- The real cause: the original PlayerEnteringWorldEvent re-ran itself every 6 s while
-- notices kept coming, and each run turned Spy off again. Spy now turns off once, at the
-- loading screen, and waits for channel notices to calm down for at most ZONE_WAIT_MAX
-- seconds; the sub-zone events wait the same way.
local ZONE_WAIT_MAX = 12

function Spy:WaitForZone()
	local quiet = Spy.ChnlTime <= time() - 6
	if not quiet and GetTime() - (Spy.ZoneWaitStart or 0) < ZONE_WAIT_MAX then
		if not Spy.ZoneWaitTimer then
			Spy.ZoneWaitTimer = Spy:ScheduleTimer(function()
				Spy.ZoneWaitTimer = nil
				Spy:WaitForZone()
			end, 6)
		end
		return
	end
	Spy.ZoneWaitStart = nil
	Spy:ZoneChanged()
end

function Spy:PlayerEnteringWorldEvent()
	Spy.EnabledInZone = false
	Spy.ZoneWaitStart = GetTime()
	Spy:WaitForZone()
end

function Spy:ZoneChangedEvent()
	Spy.ZoneWaitStart = Spy.ZoneWaitStart or GetTime()
	Spy:WaitForZone()
end
Spy.ZoneChangedNewAreaEvent = Spy.ZoneChangedEvent

function Spy:ZoneWatchdog()
	if not Spy.db or not Spy.db.profile.Enabled or Spy.EnabledInZone or Spy.ZoneWaitTimer
		or Spy:ZoneOffReason() ~= L["ReasonPending"] then
		Spy.ZoneOffSince = nil
		return
	end
	if Spy.ZoneOffSince == nil then
		Spy.ZoneOffSince = GetTime()
		return
	end
	-- Longer than the normal wait after a loading screen: only a stuck state is repaired.
	if GetTime() - Spy.ZoneOffSince < ZONE_WAIT_MAX + 3 then
		return
	end
	Spy.ZoneOffSince = nil
	Spy.ZoneRepairs = (Spy.ZoneRepairs or 0) + 1
	Spy.LastZoneRepair = time()
	Spy:ZoneChanged()
end

-- Why Spy:ZoneChanged left Spy off here, in the same order as its tests, with the
-- option that decides it when there is one.
function Spy:ZoneOffReason()
	if Spy.EnabledInZone then
		return nil
	end
	local profile = Spy.db.profile
	local pvpType = Spy:GetZonePVPInfo()
	local zone, subZone = GetZoneText(), GetSubZoneText()
	local function because(reason, option)
		return option and (L[reason] .. " (" .. L[option] .. ")") or L[reason]
	end
	if pvpType == "sanctuary" and not profile.EnabledInSanctuaries then
		return because("ReasonSanctuary", "EnabledInSanctuaries")
	end
	if zone == "" then
		return because("ReasonNoZone")
	end
	if Spy:InFilteredZone(zone, subZone) then
		return because("ReasonListedZone", "DisabledInZones")
	end
	local inInstance, instanceType = IsInInstance()
	if inInstance then
		if instanceType == "pvp" then
			return because("ReasonBattleground", "EnabledInBattlegrounds")
		elseif instanceType == "arena" then
			return because("ReasonArena", "EnabledInArenas")
		end
		return because("ReasonInstance")
	end
	if pvpType == "combat" then
		return because("ReasonCombatZone", "EnabledInWintergrasp")
	end
	if Spy:Readable(UnitIsPVP("player")) == false and profile.DisableWhenPVPUnflagged then
		return because("ReasonUnflagged", "DisableWhenPVPUnflagged")
	end
	return because("ReasonPending")
end

function Spy:PrintDebug(lines)
	local out = function(text)
		if lines then
			lines[#lines + 1] = text
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff9933ff[Spy]|r " .. text)
		end
	end
	local version, build, _, interface = GetBuildInfo()
	out(("Forever port of Spy %s, client %s (%s), interface %s"):format(Spy.Version, tostring(version), tostring(build), tostring(interface)))
	local inInstance, instanceType = IsInInstance()
	out(("Spy on: %s | in this zone: %s (pvp type %s, flagged %s, instance %s)"):format(
		yesNo(Spy.db.profile.Enabled), yesNo(Spy.EnabledInZone), tostring(Spy:GetZonePVPInfo() or "none"),
		yesNo(UnitIsPVP("player")), inInstance and tostring(instanceType) or "no"))
	if Spy.ZoneRepairs then
		out(("Zone check run again by Spy %d time(s), last %ss ago"):format(Spy.ZoneRepairs, time() - (Spy.LastZoneRepair or time())))
	end
	-- The names the game gives here and the ticked list entries, to see why a listed
	-- zone does not match (CurseForge comment: still on in Booty Bay).
	local listed = {}
	for key, value in pairs(Spy.db.profile.FilteredZones or {}) do
		if value then
			local translated = rawget(L, key)
			listed[#listed + 1] = (translated and translated ~= key) and (key .. " = " .. translated) or key
		end
	end
	table.sort(listed)
	out(("Zone: %s | sub-zone: %s | listed: %s"):format(
		tostring(Spy:Readable(GetZoneText()) or "<hidden>"), tostring(Spy:Readable(GetSubZoneText()) or "<hidden>"),
		#listed > 0 and table.concat(listed, ", ") or "none"))
	local offReason = Spy:ZoneOffReason()
	if offReason then
		out("Off in this zone because: " .. offReason)
	end
	out(("Enemy nameplates: %s | always shown: %s | nameplates watched: %d | unit scan: %s"):format(
		yesNo(Spy:NameplatesEnabled()), yesNo(Spy:NameplatesAlways()), countKeys(Spy.NamePlateUnits),
		Spy.UnitScanTimer and "running" or "stopped"))
	out(("Nearby: %d (active %d) | last hour: %d | KoS: %d | known players: %d"):format(
		countKeys(Spy.NearbyList), countKeys(Spy.ActiveList), countKeys(Spy.LastHourList),
		countKeys(SpyPerCharDB.KOSData), countKeys(SpyPerCharDB.PlayerData)))
	local stats = Spy.ForeverStats
	out(("Seen: %d unit reads, %d enemy casts, %d stealth alerts (%d after the nameplate was gone), %d casts with a hidden spell, %d kills, %d deaths counted"):format(
		stats.scans, stats.casts, stats.stealth, stats.goneStealth or 0, stats.hiddenCasts or 0, stats.kills, stats.deaths))
	local restricted = try(C_Secrets and C_Secrets.HasSecretRestrictions)
	out(("Secret restrictions: %s | target: %s"):format(yesNo(restricted), Spy:DescribeUnit("target")))
	if Spy.LastStealth then
		out(("Last stealth: %s (spell %d) %ss ago"):format(Spy.LastStealth.name, Spy.LastStealth.spellID, time() - Spy.LastStealth.when))
	end
	if Spy.LastPartyKill then
		out(("Last kill event (%d seen): %s, %ss ago"):format(Spy.ForeverStats.partyKills or 0,
			tostring(Spy.LastPartyKill.result), time() - Spy.LastPartyKill.when))
	else
		out("Last kill event: none since login")
	end
	if Spy.LastKill then
		out(("Last kill counted: %s %ss ago"):format(Spy.LastKill.name, time() - Spy.LastKill.when))
	end
	if Spy.LastDeath then
		out(("Last death: killer %s, from %s, %ss ago"):format(tostring(Spy.LastDeath.killer or "none"), Spy.LastDeath.how, time() - Spy.LastDeath.when))
	end
	if Spy.EncounterCounts then
		local wins, losses, probable = Spy:EncounterCounts()
		out(("Combat map: %d fights kept (%d wins, %d losses, %d probable), %d on the map%s"):format(
			wins + losses + probable, wins, losses, probable, Spy.EncountersShown or 0,
			Spy.db.profile.ShowEncounters == false and " (hidden)" or ""))
	end
	out(("Saved data read at login: account %s, character %s"):format(yesNo(Spy.ForeverSavedVarsFound), yesNo(Spy.ForeverCharVarsFound)))
	out(("Shared lists kept under: %s, %s | server %s | old server lists merged at login: %d"):format(tostring(Spy.StoreRealm), tostring(Spy.StoreCharacter), tostring(Spy.RealmName), Spy.MergedRealms or 0))
	local hiddenClasses = 0
	for _ in pairs(Spy.SecretClass or {}) do hiddenClasses = hiddenClasses + 1 end
	out(("Classes kept secret by the game (battlegrounds): %d players | rows painted: %d, failed: %d"):format(hiddenClasses, Spy.SecretClassPainted or 0, Spy.SecretClassFailed or 0))

	-- The window: where it is, why it last appeared or vanished, and what waits for the end of combat.
	local window = Spy.MainWindow
	out(("Window: %s, %d row(s)%s%s"):format(window:IsShown() and "shown" or "hidden", Spy.ListAmountDisplayed or 0,
		Spy.ShowAfterCombat and ", will show after combat" or "", Spy.HideAfterCombat and ", will hide after combat" or ""))
	for i = 1, math.min(3, #Spy.WindowLog) do
		local entry = Spy.WindowLog[i]
		out(("  %s %ss ago by %s%s"):format(entry.shown and "shown" or "hidden", time() - entry.when, entry.where,
			entry.combat and " (in combat)" or ""))
	end

	-- The last click on a row, and whether the client refused anything.
	local click = Spy.LastRowClick
	if click then
		out(("Last row click, %ss ago: %s, %s %s[%s] %s-> macro %s -> target: %s"):format(time() - click.when,
			tostring(click.name or "empty row"), tostring(click.button), click.modifiers, click.events,
			click.combat and "in combat " or "", tostring(click.macro or "?"), tostring(click.targetAfter or "?")))
		out("  row: " .. tostring(click.secure))
	end
	local press = Spy.LastWindowPress
	if press then
		out(("Last press on the window, %ss ago: %s went to %s"):format(time() - press.when, press.button, press.under))
	end
	for i = 1, math.min(6, #Spy.SecureTrace) do
		local entry = Spy.SecureTrace[i]
		out(("Ran %ss ago: %s"):format(time() - entry.when, entry.what))
	end
	if #Spy.SecureTrace == 0 then
		out("Ran: no macro and no TargetUnit since login")
	end
	out(("Buttons act on key %s (ActionButtonUseKeyDown)"):format(
		try(C_CVar and C_CVar.GetCVarBool, "ActionButtonUseKeyDown") and "press" or "release"))
	if #Spy.BlockedActions > 0 then
		for i = 1, math.min(3, #Spy.BlockedActions) do
			local blocked = Spy.BlockedActions[i]
			out(("Blocked by the client %ss ago: %s %s"):format(time() - blocked.when, blocked.event, blocked.fn))
		end
	else
		out("Blocked by the client: nothing")
	end
	if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
		local active = {}
		for label, value in pairs(Enum.AddOnRestrictionType) do
			if try(C_RestrictedActions.IsAddOnRestrictionActive, value) then active[#active + 1] = label end
		end
		table.sort(active)
		out("Addon restrictions active: " .. (#active > 0 and table.concat(active, ", ") or "none"))
	end
	for _, line in ipairs(Spy:SoundReport()) do
		out(line)
	end
	if Spy.WatchReport then
		out(Spy:WatchReport())
		out(("Controller interface: %s | Spy entries in the player menus: %s (left out %d times)"):format(
			Spy:GamepadUIEnabled() and "on" or "off",
			(Spy.db.profile.PlayerMenuEntries == false or Spy:GamepadUIEnabled()) and "off" or "on",
			Spy.ForeverStats.menusSkipped))
	end
	if Spy.GuildReport then
		out(Spy:GuildReport())
	end
	if Spy.AnnounceReport then
		out(Spy:AnnounceReport())
	end
	if Spy.TargetsReport then
		out(Spy:TargetsReport())
	end
	if Spy.TagsReport then
		out(Spy:TagsReport())
		if Spy.NotesReport then out(Spy:NotesReport()) end
		if Spy.PetKillsReport then out(Spy:PetKillsReport()) end
	end
	if Spy.OptionsWindowReport then
		out(Spy:OptionsWindowReport())
	end
	out("Last error: " .. tostring(Spy.ForeverLastError or "none"))
end

-- Sounds ------------------------------------------------------------------------------
-- Every Spy sound goes through here (List.lua calls Spy:PlaySound, not PlaySoundFile).
-- The client's answer is kept for /spy debug, and an MP3 it refuses is tried again as
-- the OGG copy (CurseForge: alerts listed in the window but no sound).

local function tryPlay(path, channel)
	local ok, willPlay = pcall(PlaySoundFile, path, channel)
	if not ok then
		return false, tostring(willPlay)
	end
	return Spy:Readable(willPlay) and true or false, nil
end

function Spy:PlaySound(path, channel)
	channel = channel or "SFX"
	local played, err = tryPlay(path, channel)
	local used = path
	local ogg = path:gsub("%.mp3$", ".ogg")
	if not played and ogg ~= path then
		played, err = tryPlay(ogg, channel)
		used = ogg
	end
	Spy.LastSound = { file = used:match("[^\\/]+$"), channel = channel, played = played, err = err, when = time() }
	return played
end

local function cvarOn(name)
	local value = C_CVar and C_CVar.GetCVar and Spy:Readable(C_CVar.GetCVar(name))
	if value == nil then return "?" end
	return (value == "1" or value == 1 or value == true) and "on" or "OFF"
end

function Spy:SoundReport()
	local profile = Spy.db.profile
	local lines = {
		("Sound: Spy sounds %s, channel %s | game sound %s, effects %s, ambience %s, music %s"):format(
			profile.EnableSound and "on" or "OFF", tostring(profile.SoundChannel), cvarOn("Sound_EnableAllSound"),
			cvarOn("Sound_EnableSFX"), cvarOn("Sound_EnableAmbience"), cvarOn("Sound_EnableMusic")),
	}
	local last = Spy.LastSound
	if last then
		lines[#lines + 1] = ("Last sound, %ss ago: %s on %s, %s%s"):format(time() - last.when, tostring(last.file),
			tostring(last.channel), last.played and "played" or "NOT played", last.err and (" (" .. last.err .. ")") or "")
	else
		lines[#lines + 1] = "Last sound: none since login"
	end
	return lines
end

-- Typed names -------------------------------------------------------------------------
-- Forever characters have a first name and a surname, and Spy keys them "First-Last"
-- (the client hands the surname where Classic had the realm). /spy kos and /spy ignore
-- refused anything with a space: "Fetto Vandike" now finds "Fetto-Vandike". A name Spy
-- already knows keeps its exact spelling; otherwise each part is capitalised like the
-- game does.
-- Case of a whole UTF-8 letter. CurseForge comment: "/spy kos имя фамилия" added
-- "мя амилия": the first letter was cut at its first byte, and a Cyrillic letter takes
-- two. string.upper/lower only know ASCII, so Cyrillic and accented Latin letters are
-- mapped by hand.
local function utf8Lower(s)
	s = s:lower()
	s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end) -- А-П -> а-п
	s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end) -- Р-Я -> р-я
	s = s:gsub("\208([\128-\143])", function(c) return "\209" .. string.char(c:byte() + 16) end) -- Ѐ-Џ (Ё) -> ѐ-џ
	s = s:gsub("\195([\128-\158])", function(c)                                                   -- À-Þ -> à-þ
		if c == "\151" then return "\195" .. c end -- ×
		return "\195" .. string.char(c:byte() + 32)
	end)
	return s
end

local function utf8Upper(s)
	s = s:upper()
	s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end) -- а-п -> А-П
	s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end) -- р-я -> Р-Я
	s = s:gsub("\209([\144-\159])", function(c) return "\208" .. string.char(c:byte() - 16) end) -- ѐ-џ (ё) -> Ѐ-Џ
	s = s:gsub("\195([\160-\190])", function(c)                                                   -- à-þ -> À-Þ
		if c == "\183" then return "\195" .. c end -- ÷
		return "\195" .. string.char(c:byte() - 32)
	end)
	return s
end

-- "имя" -> "Имя": the first whole letter up, the rest down.
local function capitalise(part)
	local first, rest = part:match("^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
	if not first then
		return part
	end
	return utf8Upper(first) .. utf8Lower(rest)
end
Spy.ForeverUtf8Lower, Spy.ForeverCapitalise = utf8Lower, capitalise

function Spy:TypedPlayerName(value)
	value = strtrim(tostring(value or "")):gsub("%s+", " ")
	if value == "" or value:find("%d") then
		return nil
	end
	local key = value:gsub(" ", "-")
	local _, hyphens = key:gsub("%-", "")
	if hyphens > 1 or key:find("^%-") or key:find("%-$") then
		return nil
	end
	local lower = utf8Lower(key)
	for _, list in ipairs({ SpyPerCharDB.KOSData, SpyPerCharDB.IgnoreData, SpyPerCharDB.PlayerData }) do
		for known in pairs(list or {}) do
			if type(known) == "string" and utf8Lower(known) == lower then
				return known
			end
		end
	end
	local parts = {}
	for part in key:gmatch("[^%-]+") do
		parts[#parts + 1] = capitalise(part)
	end
	return table.concat(parts, "-")
end

local function typedNameSetter(toggle, listName)
	return function(info, value)
		local name = Spy:TypedPlayerName(value)
		if not name or Spy_IgnoreList[name] then
			DEFAULT_CHAT_FRAME:AddMessage(tostring(value) .. " - " .. L["InvalidInput"])
		else
			Spy[toggle](Spy, not SpyPerCharDB[listName][name], name)
		end
	end
end
Spy.optionsSlash.args.kos.set = typedNameSetter("ToggleKOSPlayer", "KOSData")
Spy.optionsSlash.args.ignore.set = typedNameSetter("ToggleIgnorePlayer", "IgnoreData")

-- Options and slash commands --------------------------------------------------------------

Spy.options.args.General.args.ShowMinimapButton = {
	name = L["ShowMinimapButton"],
	desc = L["ShowMinimapButtonDescription"],
	type = "toggle",
	order = 11,
	width = "full",
	get = function(info)
		return not minimapSettings().hide
	end,
	set = function(info, value)
		Spy:SetMinimapButtonShown(value)
	end,
}

Spy.options.args.General.args.ZoneMessages = {
	name = L["ZoneMessages"],
	desc = L["ZoneMessagesDescription"],
	type = "toggle",
	order = 12,
	width = "full",
	get = function(info)
		return Spy.db.profile.ZoneMessages == true
	end,
	set = function(info, value)
		Spy.db.profile.ZoneMessages = value
	end,
}

Spy.optionsSlash.args.testsound = {
	name = L["TestSoundSlash"],
	desc = L["TestSoundSlashDescription"],
	type = "execute",
	order = 13,
	func = function()
		Spy:PlaySound("Interface\\AddOns\\Spy\\Sounds\\detected-nearby.mp3", Spy.db.profile.SoundChannel)
		for _, line in ipairs(Spy:SoundReport()) do
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. line)
		end
	end,
	dialogHidden = true,
}

Spy.optionsSlash.args.minimap = {
	name = L["MinimapSlash"],
	desc = L["MinimapSlashDescription"],
	type = "execute",
	order = 11,
	func = function()
		local shown = minimapSettings().hide
		Spy:SetMinimapButtonShown(shown)
		DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. (shown and L["MinimapShown"] or L["MinimapHidden"]))
	end,
	dialogHidden = true,
}

Spy.optionsSlash.args.nameplates = {
	name = L["NameplatesSlash"],
	desc = L["NameplatesSlashDescription"],
	type = "execute",
	order = 11,
	func = function() Spy:TurnOnNameplates() end,
	dialogHidden = true,
}

Spy.optionsSlash.args.debug = {
	name = L["DebugSlash"],
	desc = L["DebugSlashDescription"],
	type = "execute",
	order = 12,
	func = function()
		Spy:PrintDebug()
	end,
	dialogHidden = true,
}

-- Start-up ------------------------------------------------------------------------------------

local baseOnInitialize = Spy.OnInitialize
function Spy:OnInitialize(...)
	-- The Forever beta writes the saved variables but never reads them back: record
	-- whether they arrived, so /spy debug can tell a Spy problem from that client bug.
	Spy.ForeverSavedVarsFound = type(SpyDB) == "table"
	Spy.ForeverCharVarsFound = type(SpyPerCharDB) == "table"
	baseOnInitialize(self, ...)
	-- A recap already there at login belongs to an earlier death.
	Spy.LastRecapID = recapID()
	LibStub("AceConfigDialog-3.0"):SetDefaultSize("Spy", 760, 560)
	Spy:CreateMinimapButton()
	Spy:WatchMainWindow()
	Spy:ScheduleRepeatingTimer("ZoneWatchdog", 3)
	if Spy.db and Spy.db.RegisterCallback then
		Spy.db.RegisterCallback(Spy, "OnDatabaseShutdown", function() Spy:SaveDebugReport() end)
		Spy.ReportOnShutdown = true
	end
end

-- Players who already moved the window have an entry in layout-local.txt, which the
-- client may apply after Spy placed the window: put Spy's position back once the world
-- is loaded.
local layoutWatcher = CreateFrame("Frame")
layoutWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
layoutWatcher:SetScript("OnEvent", Guard("RestoreWindow", function()
	local window = Spy.MainWindow
	local position = Spy.db and Spy.db.profile.MainWindow and Spy.db.profile.MainWindow.Position
	if not window or not position or window.isMoving or InCombatLockdown() then
		return
	end
	Spy:NoClientLayout(window)
	Spy:RestoreMainWindowPosition(position.x, position.y, position.w, 34)
	Spy:ResizeMainWindow()
end))

-- Profile switches reset everything else through HandleProfileChanges; the minimap
-- button follows.
local baseHandleProfileChanges = Spy.HandleProfileChanges
function Spy:HandleProfileChanges(...)
	baseHandleProfileChanges(self, ...)
	Spy:RefreshMinimapButton()
end

local baseEnableSpy = Spy.EnableSpy
function Spy:EnableSpy(value, changeDisplay, ...)
	-- In combat the window cannot be shown or hidden: do it when combat ends.
	if changeDisplay and InCombatLockdown() then
		if value then
			Spy.ShowAfterCombat, Spy.HideAfterCombat = true, nil
		else
			Spy.HideAfterCombat, Spy.ShowAfterCombat = true, nil
		end
	end
	baseEnableSpy(self, value, changeDisplay, ...)
	Spy:RefreshMinimapButton()
end

local baseZoneChanged = Spy.ZoneChanged
function Spy:ZoneChanged(...)
	-- The original shows the window at every zone change, and ZONE_CHANGED fires at each
	-- sub-zone: a window the player closed came back every few minutes with nobody
	-- around (CurseForge comment). A window the player closed stays closed while Spy
	-- stays on; a detection still opens it ("Show Spy when enemy players are detected").
	local window = Spy.MainWindow
	local keepClosed = window and not window:IsShown() and Spy.LastZoneOn == true
	baseZoneChanged(self, ...)
	if keepClosed and Spy.EnabledInZone then
		if not InCombatLockdown() and window:IsShown() then window:Hide() end
		Spy.ShowAfterCombat = nil
		Spy.LastZoneOn = true
		return
	end
	if InCombatLockdown() then
		if Spy.EnabledInZone and not Spy.db.profile.HideSpy then
			Spy.ShowAfterCombat, Spy.HideAfterCombat = true, nil
		elseif not Spy.EnabledInZone then
			Spy.HideAfterCombat, Spy.ShowAfterCombat = true, nil
		end
	end
	-- Say it when Spy turns itself off or back on here, with the reason: otherwise the
	-- window just vanishes (a PvP flag running out is enough). Off unless asked for: with
	-- the PvP flag setting on, every flag change printed a line (CurseForge comment).
	if Spy.db.profile.Enabled and Spy.db.profile.ZoneMessages and Spy.EnabledInZone ~= Spy.LastZoneOn then
		if not Spy.EnabledInZone then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["ZoneOff"]:format(Spy:ZoneOffReason() or "?"))
		elseif Spy.LastZoneOn ~= nil then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["ZoneOn"])
		end
	end
	Spy.LastZoneOn = Spy.EnabledInZone
	-- One hint per session when enemy nameplates are off: they are Spy's main radar now.
	if Spy.EnabledInZone and not Spy.NameplateHintShown then
		if Spy:NameplatesEnabled() == false then
			Spy.NameplateHintShown = true
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["NameplatesOff"])
		elseif Spy:NameplatesAlways() == false then
			Spy.NameplateHintShown = true
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["NameplatesAllOff"])
		end
	end
end

-- The beta writes saved variables at /reload and logout (it only fails to read them back),
-- so the /spy debug report is stored there too: it can be read from the file afterwards.
-- Written from AceDB's OnDatabaseShutdown, which fires before AceDB removes the default
-- values from the profile: after that, every setting left at its default reads nil
-- (the report said "Spy on: ?" and "Spy sounds OFF").
function Spy:SaveDebugReport()
	if type(SpyDB) ~= "table" or not Spy.db then
		return
	end
	local lines = { date("%Y-%m-%d %H:%M:%S") }
	local ok, err = pcall(Spy.PrintDebug, Spy, lines)
	if not ok then
		lines[#lines + 1] = "debug failed: " .. tostring(err)
	end
	SpyDB.ForeverDebug = lines
end

local logoutWatcher = CreateFrame("Frame")
logoutWatcher:RegisterEvent("PLAYER_LOGOUT")
logoutWatcher:SetScript("OnEvent", function()
	if not Spy.ReportOnShutdown then
		Spy:SaveDebugReport()
	end
end)

-- Shared lists (Kill On Sight between characters, watch list, watched guilds) --------
-- CurseForge comment: "share Kill On Sight players between characters is checked but it
-- does not add them to each other". Spy kept these lists per realm, under GetRealmName().
-- On Forever names are unique for the whole region and GetRealmName() gives an internal
-- server ("CAMWOW EU4 Realm 6 PvP"), which differs from one character to another: an alt
-- on another server found an empty list. And each character's own list was kept under its
-- first name only, so two characters with the same first name took each other for itself.
-- Like Ace3 (AceDB r40), the lists are now kept per ruleset (PvP, PvE...) and under the
-- full "First Last" name; lists kept under the old server names are merged in once.

local function ruleActive(rule)
	if not (rule and C_GameRules and C_GameRules.IsGameRuleActive) then
		return false
	end
	local ok, active = pcall(C_GameRules.IsGameRuleActive, rule)
	return ok and Spy:Readable(active) == true
end

local function regionalNames()
	if not RegionalUniqueNamesEnabled then
		return false
	end
	local ok, on = pcall(RegionalUniqueNamesEnabled)
	return ok and Spy:Readable(on) == true
end

local REGION_PREFIX = "Region "

function Spy:ForeverStoreKeys()
	Spy.StoreRealm = Spy.RealmName
	Spy.StoreCharacter = Spy.CharacterName
	if not regionalNames() then
		return
	end
	local rules = Enum and Enum.GameRule or {}
	local key
	if ruleActive(rules.HardcoreRuleset) then
		key = "Hardcore"
	else
		local rp, pvp = ruleActive(rules.RPRuleset), ruleActive(rules.PvPRuleset)
		key = (rp and pvp and "RP-PvP") or (rp and "RP") or (pvp and "PvP") or "PvE"
	end
	Spy.StoreRealm = REGION_PREFIX .. key
	local nameOf = UnitNameUnmodified or UnitName
	local name, surname = nameOf("player")
	name, surname = Spy:Readable(name), Spy:Readable(surname)
	if type(name) == "string" and name ~= "" and type(surname) == "string" and surname ~= "" then
		Spy.StoreCharacter = name .. " " .. surname
	end
end

-- Copies what `source` has and `target` lacks; numbers keep the larger (a later date).
local function merge(target, source)
	for key, value in pairs(source) do
		local current = target[key]
		if type(value) == "table" then
			if type(current) ~= "table" then
				current = {}
				target[key] = current
			end
			merge(current, value)
		elseif current == nil then
			target[key] = value
		elseif type(current) == "number" and type(value) == "number" and value > current then
			target[key] = value
		end
	end
end

function Spy:ForeverMergeRealms()
	if not SpyDB or not Spy.StoreRealm or Spy.StoreRealm == Spy.RealmName then
		return
	end
	local moved = 0
	for _, field in ipairs({ "kosData", "removeKOSData", "watchData", "guildWatch" }) do
		local byRealm = SpyDB[field]
		if type(byRealm) == "table" then
			local oldRealms = {}
			for realm, data in pairs(byRealm) do
				if type(realm) == "string" and realm:sub(1, #REGION_PREFIX) ~= REGION_PREFIX and type(data) == "table" then
					oldRealms[#oldRealms + 1] = realm
				end
			end
			for _, realm in ipairs(oldRealms) do
				byRealm[Spy.StoreRealm] = byRealm[Spy.StoreRealm] or {}
				merge(byRealm[Spy.StoreRealm], byRealm[realm])
				byRealm[realm] = nil
				moved = moved + 1
			end
		end
	end
	Spy.MergedRealms = moved
end

-- Right-click menu on a row ------------------------------------------------------------
-- CurseForge comment: "when right clicking on an enemy in the window, the whole menu is
-- squashed into one, so nothing can be selected". The original uses the old
-- UIDropDownMenu, whose line height and lists are globals of the game's UI: an addon that
-- embeds an old copy of it, or changes them, breaks every menu built on it. The rows now
-- open the menu of the game's own windows (MenuUtil.CreateContextMenu), with the same
-- entries; the old menu stays as a fallback for a client without it.
local function rowPlayer(row)
	local name = row and row.id and Spy.ButtonName[row.id]
	if (not name or name == "") and row and row.LeftText then
		name = Spy:Readable(row.LeftText:GetText())
	end
	if type(name) == "string" and name ~= "" then
		return name
	end
end

local function buildRowMenu(root, player)
	local list = Spy.db.profile.CurrentList
	root:CreateTitle(player)
	if list == 1 or list == 2 then
		local announce = root:CreateButton(L["AnnounceDropDownMenu"])
		announce:CreateButton(L["PartyDropDownMenu"], function() Spy:AnnouncePlayer(player, "PARTY") end)
		announce:CreateButton(L["RaidDropDownMenu"], function() Spy:AnnouncePlayer(player, "RAID") end)
		announce:CreateButton(L["GuildDropDownMenu"], function() Spy:AnnouncePlayer(player, "GUILD") end)
		announce:CreateButton(L["LocalDefenseDropDownMenu"], function() Spy:AnnouncePlayer(player, "LOCAL") end)
		announce:CreateButton(L["GeneralDropDownMenu"], function() Spy:AnnouncePlayer(player, "GENERAL") end)
		local custom = Spy.CustomChannelSetting and Spy:CustomChannelSetting()
		if custom then
			announce:CreateButton(L["CustomChannelDropDownMenu"]:format(custom), function() Spy:AnnouncePlayer(player, "CUSTOM") end)
		end
	end
	if not SpyPerCharDB.KOSData[player] then
		root:CreateButton(L["AddToKOSList"], function() Spy:ToggleKOSPlayer(true, player) end)
	else
		local reasons = root:CreateButton(L["KOSReasonDropDownMenu"])
		for i = 1, Spy_KOSReasonListLength or 0 do
			local group = Spy_KOSReasonList[i]
			if group then
				local sub = reasons:CreateButton(group.title)
				for _, reason in pairs(group.content or {}) do
					sub:CreateCheckbox(reason, function()
						local playerData = SpyPerCharDB.PlayerData[player]
						return playerData and playerData.reason and playerData.reason[reason] == true or false
					end, function()
						Spy:SetKOSReason(player, reason)
					end)
				end
			end
		end
		reasons:CreateButton(L["KOSReasonClear"], function() Spy:SetKOSReason(player, nil) end)
		root:CreateButton(L["RemoveFromKOSList"], function() Spy:ToggleKOSPlayer(false, player) end)
	end
	-- Player tags (Tags.lua): do not kill / fair fight.
	if Spy.SetPlayerTag then
		for _, tag in ipairs({ "spare", "rival" }) do
			root:CreateCheckbox(L["Tag_" .. tag], function() return Spy:PlayerTag(player) == tag end, function()
				Spy:SetPlayerTag(player, Spy:PlayerTag(player) ~= tag and tag or nil)
			end)
		end
	end
	-- The player's note (Notes.lua).
	if Spy.EditPlayerNote then
		root:CreateButton(Spy:PlayerNote(player) and L["NoteEditDropDownMenu"] or L["NoteDropDownMenu"], function() Spy:EditPlayerNote(player) end)
	end
	if not SpyPerCharDB.IgnoreData[player] then
		root:CreateButton(L["AddToIgnoreList"], function() Spy:ToggleIgnorePlayer(true, player) end)
	else
		root:CreateButton(L["RemoveFromIgnoreList"], function() Spy:ToggleIgnorePlayer(false, player) end)
	end
	if list == 1 then
		root:CreateButton(L["Clear"], function() Spy:RemovePlayerFromList(player) end)
	end
end

local baseBarDropDownOpen = Spy.BarDropDownOpen
function Spy:BarDropDownOpen(row, ...)
	local player = rowPlayer(row)
	if player and MenuUtil and MenuUtil.CreateContextMenu then
		local ok, err = pcall(MenuUtil.CreateContextMenu, row, function(_, root)
			buildRowMenu(root, player)
		end)
		if ok then
			Spy.RowMenuOpened = time()
			Spy.ModernRowMenu = true -- ToggleDropDownMenu right after must not open the old one
			return
		end
		Spy.LastRowMenuError = tostring(err)
	end
	Spy.ModernRowMenu = nil
	return baseBarDropDownOpen(self, row, ...)
end

-- The original calls CloseDropDownMenus then ToggleDropDownMenu right after
-- Spy:BarDropDownOpen: skip the old menu when the new one opened.
local baseToggleDropDownMenu = ToggleDropDownMenu
if baseToggleDropDownMenu then
	function Spy.ToggleRowDropDown(...)
		if Spy.ModernRowMenu then
			Spy.ModernRowMenu = nil
			return
		end
		return baseToggleDropDownMenu(...)
	end
end
