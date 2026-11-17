-- Spy for Forever: kills by your pet, and map icons kept away from the world map.
--
-- CurseForge comment (warlock): "it does not track my killing blows when my succubus
-- offs them". Without the combat log, a win comes from PARTY_KILL, and the game may
-- not send it for a pet's killing blow. Spy now notes which enemy your pet is
-- attacking; when that enemy dies and no PARTY_KILL says who killed him, the kill is
-- yours. In battlegrounds the game hides who killed whom from addons altogether
-- (PARTY_KILL is "secret when unit identity restricted"), so wins cannot be counted
-- there; losses still come from the death recap.
--
-- CurseForge comments: "conflicts with opening and closing the map with a controller",
-- "occasionally crashes when using controller". With a controller, the world map lists
-- every frame on it in one call (GetChildren) to build its navigation. Spy created its
-- 20 map notes and one skull per fight of the combat map right on the world map: up
-- to several hundred frames, and a GetChildren that returns that many values crashes
-- the client. The icons now wait in a hidden frame of their own and only go on the map
-- (through HereBeDragons) while they are shown, at most MAP_SKULL_LIMIT of them, and
-- the controller navigation is told to skip them.
-- Written from scratch.

local Guard = Spy.ForeverGuard

local PET_WINDOW = 4      -- seconds since the pet last had him targeted
local KILL_WAIT = 0.5     -- wait for a PARTY_KILL before calling it the pet's kill
local KILL_MATCH = 3      -- a PARTY_KILL this close to the death settles it

Spy.PetTargets = {}       -- victim GUID -> GetTime() our pet last had him targeted
Spy.PartyKillGUIDs = {}   -- victim GUID -> GetTime() a PARTY_KILL named him
Spy.ForeverStats.petKills = Spy.ForeverStats.petKills or 0
Spy.ForeverStats.hiddenKills = Spy.ForeverStats.hiddenKills or 0

-- Map icons -----------------------------------------------------------------------------

Spy.MapSkullLimit = 100

function Spy:MapIconHolder()
	if not Spy.MapHolder then
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:Hide()
		holder.smartNavigationIgnored = true
		Spy.MapHolder = holder
	end
	return Spy.MapHolder
end

function Spy:KeepOffMap(icon)
	if icon then
		icon.smartNavigationIgnored = true
		icon:SetParent(Spy:MapIconHolder())
	end
	return icon
end

local baseCreateMapNote = Spy.CreateMapNote
function Spy:CreateMapNote(num, ...)
	baseCreateMapNote(self, num, ...)
	local note = Spy.MapNoteList and Spy.MapNoteList[num]
	if note then
		Spy:KeepOffMap(note.worldIcon)
		Spy:KeepOffMap(note.miniIcon)
	end
end

-- Pet kills ------------------------------------------------------------------------------

function Spy:NotePetTarget()
	local pet = Spy:Readable(UnitGUID("pet"))
	if not pet then
		return
	end
	Spy.PetGUID[pet] = time()
	local target = Spy:Readable(UnitGUID("pettarget"))
	if target then
		Spy.PetTargets[target] = GetTime()
	end
end

local baseScan = Spy.ScanVisibleUnits
Spy.ScanVisibleUnits = function(...)
	Guard("NotePetTarget", Spy.NotePetTarget)(Spy)
	local now = GetTime()
	for guid, when in pairs(Spy.PetTargets) do
		if now - when > 60 then Spy.PetTargets[guid] = nil end
	end
	for guid, when in pairs(Spy.PartyKillGUIDs) do
		if now - when > 60 then Spy.PartyKillGUIDs[guid] = nil end
	end
	return baseScan(...)
end

local basePartyKill = Spy.PartyKillEvent
Spy.PartyKillEvent = function(self, event, attackerGUID, targetGUID, ...)
	local target = Spy:Readable(targetGUID)
	if target then
		Spy.PartyKillGUIDs[target] = GetTime()
	end
	if attackerGUID ~= nil and Spy:IsSecret(attackerGUID) then
		Spy.ForeverStats.hiddenKills = Spy.ForeverStats.hiddenKills + 1
	end
	return basePartyKill(self, event, attackerGUID, targetGUID, ...)
end

Spy.PetKillDiedEvent = Guard("PetKillDiedEvent", function(guid)
	if not Spy.EnabledInZone then
		return
	end
	guid = Spy:Readable(guid)
	local seen = guid and Spy.PetTargets[guid]
	if not seen or GetTime() - seen > PET_WINDOW then
		return
	end
	local name = Spy:PlayerNameFromGUID(guid)
	local playerData = name and SpyPerCharDB.PlayerData[name]
	if not playerData or playerData.isEnemy == false then
		return
	end
	local died, where, when = GetTime(), Spy:PlayerPosition(), time()
	Spy:ScheduleTimer(function()
		local kill = Spy.PartyKillGUIDs[guid]
		if kill and math.abs(kill - died) <= KILL_MATCH then
			return -- the game said who killed him
		end
		Spy.PetTargets[guid] = nil
		playerData.wins = (playerData.wins or 0) + 1
		Spy.ForeverStats.kills = Spy.ForeverStats.kills + 1
		Spy.ForeverStats.petKills = Spy.ForeverStats.petKills + 1
		Spy.LastKill = { name = name, when = time() }
		Spy.LastPartyKill = { when = time(), result = "pet's target died, no kill event: " .. name }
		if Spy.RecordEncounter then
			Spy:RecordEncounter(name, "W", "pet", where, when)
		end
	end, KILL_WAIT)
end)

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "UNIT_DIED")
pcall(events.RegisterUnitEvent, events, "UNIT_TARGET", "pet")
pcall(events.RegisterEvent, events, "UNIT_PET")
events:SetScript("OnEvent", Guard("PetKillEvents", function(_, event, ...)
	if event == "UNIT_DIED" then
		Spy.PetKillDiedEvent(...)
	else
		Spy:NotePetTarget()
	end
end))

function Spy:PetKillsReport()
	local count = 0
	for _ in pairs(Spy.PetTargets) do count = count + 1 end
	return ("Pet kills counted: %d | enemies your pet attacked lately: %d | kill events with the players hidden by the game: %d"):format(
		Spy.ForeverStats.petKills, count, Spy.ForeverStats.hiddenKills)
end
