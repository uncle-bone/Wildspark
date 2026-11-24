-- LFGForever -- core/wholookup.lua
--
-- Where a player is: asked with /who from the addon itself and read back from
-- the answer, one question at a time, while Blizzard's own Who list is kept
-- out of it. The whisper log's Location link asks (core/whisperlog.lua) and
-- shows what comes back. In memory only: a /reload forgets every answer.
-- .claude/rules/whisper-location-lookup.md
--
-- C_FriendList.SendWho is HasRestrictions (FriendListDocumentation.lua) and
-- the sources do not say which states refuse it. A client probe settled it
-- (2026-11-22): sent from /run, a tainted path like addon code, it worked out
-- of combat and in combat, and the answer came back as WHO_LIST_UPDATE.
local _, root = ...
local LFGF = root.WildGroups

-------------------------------------------------------
---------- Keeping Blizzard's Who list out of it
-------------------------------------------------------
-- BLIZZARD'S CAMELOT WHO LIST OPENS ITS WINDOW ON EVERY ANSWER. It registers
-- WHO_LIST_UPDATE from its OnLoad, and on it UpdateWhoList fills the list and
-- ends with PanelTemplates_SetTab(LFGParentFrame, 3) and
-- ShowUIPanel(LFGParentFrame) (Blizzard_GroupFinder_VanillaStyle/Mainline/
-- WhoList.lua, LFGWhoListMixin). Left listening, our answer would open
-- Blizzard's Group Finder on the Who tab. It is the only Who list on camelot:
-- the Mainline FriendsFrame, which listens too, does not load there
-- (Blizzard_FriendsFrame.toc), and the Camelot one does not listen.
--
-- So while our question is out its event is taken away -- only while the list
-- is hidden and listening -- and given back once the answer has been read. A
-- list the player has open is left alone: it shows our answer too, which is
-- what it is open for.
--
-- Nothing is written onto Blizzard's frame. Its event registration is the
-- engine's, set through the frame's own methods, and no field of the frame is
-- read or written (UpdateWhoList's selectedTab is the field that tainted the
-- player's own Group Finder key before; .claude/rules/whisper-location-lookup.md,
-- History).
local WHO_EVENT = "WHO_LIST_UPDATE"

--- The Who list whose event is taken away, or nil.
local hushed

--- Blizzard's Who list, or nil before its LoadOnDemand addon is in.
local function WhoList()
	return _G.LFGWhoListFrame
end

local function Hush()
	local list = WhoList()
	if list and not list:IsVisible() and list:IsEventRegistered(WHO_EVENT) then
		list:UnregisterEvent(WHO_EVENT)
		hushed = list
	end
end

--- Give the event back, and send /who answers to chat again unless a Who list
--- is open and wants them (its OnShow turned them to the UI, WhoList.lua).
local function Unhush()
	if hushed then
		hushed:RegisterEvent(WHO_EVENT)
		hushed = nil
	end
	local list = WhoList()
	if not (list and list:IsVisible()) then
		C_FriendList.SetWhoToUi(false)
	end
end

-------------------------------------------------------
---------- The question and its answer
-------------------------------------------------------
-- How long an answer is waited for. A question with no answer by then is
-- given up: the player can ask again, and an answer that still comes goes to
-- chat as a /who answer always does.
LFGF.WHO_ANSWER_SECONDS = 5

-- The server sends no more rows than this (MAX_WHOS_FROM_SERVER, WhoList.lua).
local MAX_ROWS = 50

--- Each player's last answer, by LFGF.PlayerKey: { area = string or nil,
--- time = GetServerTime() }. A nil area is "not found".
local answers = {}

--- The question out, or nil: { key, answered, timer }.
local question

local function Announce(key)
	EventRegistry:TriggerEvent(LFGF.EVENT_LOCATION_LOOKUP_CHANGED, key)
end

--- Whether a /who row's name is the player's: the name as it comes, or
--- without what follows its last hyphen, read through LFGF.PlayerKey. So
--- "Firstname Surname", "Firstname-Surname" (the link form) and either with a
--- "-Something" after it all match, and no other name does.
local function NameMatches(fullName, key)
	fullName = LFGF.Readable(fullName, nil)
	if fullName == nil then
		return false
	end
	if LFGF.PlayerKey(fullName) == key then
		return true
	end
	local before = string.match(fullName, "^(.+)%-[^%-]*$")
	return before ~= nil and LFGF.PlayerKey(before) == key
end

--- The player's area in the answer being read, or nil when no row names them
--- or their area cannot be read or is empty.
local function AreaInAnswer(key)
	local count = LFGF.Readable((C_FriendList.GetNumWhoResults()), 0)
	for index = 1, math.min(count, MAX_ROWS) do
		local info = C_FriendList.GetWhoInfo(index)
		if info and NameMatches(info.fullName, key) then
			local area = LFGF.Readable(info.area, nil)
			if area ~= nil and area ~= "" then
				return area
			end
			return nil
		end
	end
	return nil
end

--- End a question: the event given back, the player free to ask again.
local function Finish(asked)
	if question ~= asked then
		return
	end
	question = nil
	if asked.timer then
		asked.timer:Cancel()
	end
	Unhush()
	Announce(asked.key)
end

local events = CreateFrame("Frame")
events:RegisterEvent(WHO_EVENT)
-- THE ANSWER IS READ AT ONCE AND BLIZZARD'S LIST GETS ITS EVENT BACK A FRAME
-- LATER. Registering it again inside this dispatch could hand the list the
-- very answer being read, and open Blizzard's Group Finder after all; the
-- sources do not say whether a frame registered during a dispatch receives
-- it. An answer to a question nobody asked (Blizzard's open Who tab, say) is
-- not ours to read.
events:SetScript("OnEvent", function()
	local asked = question
	if asked == nil or asked.answered then
		return
	end
	asked.answered = true
	answers[asked.key] = { area = AreaInAnswer(asked.key), time = GetServerTime() }
	Announce(asked.key)
	C_Timer.After(0, function()
		Finish(asked)
	end)
end)

--- Look a player up with /who. Returns true when the question went out, false
--- when it did not: a name that cannot be read or is empty, a question already
--- out, or game rules that switch the Who list off (Blizzard's own /who does
--- nothing then, SlashCommands.lua).
---
--- THE QUERY IS THE QUOTED FULL NAME, by the player's key: tested in the
--- client, `/who "Firstname Surname"` finds the player while the x- and n-
--- tags do not.
function LFGF.LookUpLocation(name)
	local key = LFGF.PlayerKey(name)
	if key == nil or question ~= nil then
		return false
	end
	if C_GameRules.IsGameRuleActive(Enum.GameRule.IngameWhoListDisabled) then
		return false
	end

	local asked = { key = key }
	question = asked
	Hush()
	-- The answer to the UI, so it arrives as WHO_LIST_UPDATE rather than as
	-- chat lines (what Blizzard's Who tab turns on while it shows, WhoList.lua).
	C_FriendList.SetWhoToUi(true)
	C_FriendList.SendWho('"' .. key .. '"', Enum.SocialWhoOrigin.Social)
	asked.timer = C_Timer.NewTimer(LFGF.WHO_ANSWER_SECONDS, function()
		if not asked.answered then
			Finish(asked)
		end
	end)
	Announce(key)
	return true
end

--- What is known of a player's whereabouts this session:
---   "searching"              while the question about them is out;
---   "found", area, time      their area, and when it was asked (GetServerTime);
---   "notfound", nil, time    /who did not find them;
---   nil                      never looked up, or never answered.
function LFGF.LocationLookup(name)
	local key = LFGF.PlayerKey(name)
	if key == nil then
		return nil
	end
	if question and question.key == key and not question.answered then
		return "searching"
	end
	local answer = answers[key]
	if answer == nil then
		return nil
	end
	if answer.area then
		return "found", answer.area, answer.time
	end
	return "notfound", nil, answer.time
end

--- Whether a question is out, so no other can be asked yet.
function LFGF.LocationLookupBusy()
	return question ~= nil
end
