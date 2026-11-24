-- LFGForever -- core/db.lua
--
-- THE SAVED TABLES: every key WildGroups keeps on disk, its default, and the
-- four helpers every other file reads and writes them through. Loads SECOND,
-- after core/locale.lua, so every later file can read a default at file scope.
--
--   LFGForeverDB      ## SavedVariables               account-wide
--   LFGForeverCharDB  ## SavedVariablesPerCharacter   per character
--
-- The client assigns both before the addon's ADDON_LOADED, or leaves them nil
-- on a first install (and on a character's first load); core/settings.lua
-- creates them then, through LFGF.SavedTable.
--
-- ONE OWNER. No other file names LFGForeverDB or LFGForeverCharDB: they read
-- with LFGF.SavedValue / LFGF.SavedSetting and write with LFGF.SaveValue, so a
-- key is spelled once, here (spec/LFGForever/db_spec.lua holds both). The keys
-- are the ones 0.20.0 writes, unchanged: a renamed key would lose the
-- player's value, so renaming one needs a migration, and there are none.
--
-- NO REPAIR ON LOAD, by the author's decision (2026-10-11). A saved value of
-- the wrong type stays on disk; each reader falls back when it reads it, as
-- before. .claude/rules/saved-variables-db.md

local _, root = ...
local LFGF = root.WildGroups

local ACCOUNT, CHARACTER = "account", "character"

local GLOBAL_NAMES = {
	[ACCOUNT] = "LFGForeverDB",
	[CHARACTER] = "LFGForeverCharDB",
}

--- Every key on disk, in the order the settings page shows its settings, then
--- the state the addon keeps by itself. Fields:
---   key       the name in the saved table
---   scope     "account" (LFGForeverDB) or "character" (LFGForeverCharDB)
---   variable  the Blizzard Settings variable, for the eleven that are settings
---             (prefixed with the addon's name: variables share one registry
---             across every addon, Blizzard_Setting.lua:390-395)
---   type      the Lua type a usable value has
---   default   what a reader answers when nothing usable is saved, and what
---             Settings.RegisterAddOnSetting writes for a missing setting
---   min       (whisperLogSize only) the smallest usable number
LFGF.SAVED_KEYS = {
	-- How many received whispers the Whispers tab keeps.
	{ key = "whisperLogSize", scope = ACCOUNT, variable = "LFGFOREVER_WHISPER_LOG_SIZE",
		type = "number", default = 200, min = 1 },

	-- Ask to Join: whisper the leader with the message, or open a whisper box.
	{ key = "askToJoinAutoWhisper", scope = ACCOUNT, variable = "LFGFOREVER_ASK_TO_JOIN_AUTO_WHISPER",
		type = "boolean", default = true },
	-- The Ask to Join whisper, PER CHARACTER since 0.11.0. Six placeholders are
	-- filled in when the button is clicked (LFGF.AskToJoinMessage, core/main.lua):
	-- %class%, %level%, %talents%, %role%, and the group's %dungeon% and
	-- %dungeon_en%, rather than string.format's %s and %d, because the player
	-- edits this text and a stray % must not be read as a format directive. No
	-- addon tag: the leader reads a greeting from a player, not an advert. %role%
	-- is not in the default, by the author's decision: players add it themselves
	-- (.claude/rules/role-placeholder.md). %dungeon_en% is, at the end, by the
	-- author's decision: a group with nothing to name (Quests & Zones) then
	-- reads "...Inv please to ". core/settings.lua moves a character still
	-- holding an older default to this one (.claude/rules/ask-to-join-dungeon.md).
	{ key = "askToJoinMessage", scope = CHARACTER, variable = "LFGFOREVER_ASK_TO_JOIN_MESSAGE",
		type = "string", default = "Hi! I am a %talents% %class%, %level%. Inv please to %dungeon_en%" },

	-- Invite: whisper the invited player with the message (0.12.0-dev.1).
	{ key = "inviteAutoWhisper", scope = ACCOUNT, variable = "LFGFOREVER_INVITE_AUTO_WHISPER",
		type = "boolean", default = true },
	-- The Invite whisper, per character from the start, %dungeon% filled in from
	-- the player's own listing or the ticked activities (LFGF.InviteWhisperMessage,
	-- core/main.lua; .claude/rules/invite-whisper.md). The wording is the author's.
	-- The default names them in English (%dungeon_en%), by the author's decision:
	-- Forever is mostly English-speaking. core/settings.lua moves a character
	-- still holding the older "%dungeon%" default to this one
	-- (.claude/rules/dungeon-en-placeholder.md).
	{ key = "inviteMessage", scope = CHARACTER, variable = "LFGFOREVER_INVITE_MESSAGE",
		type = "string", default = "Hey! Want to join %dungeon_en%?" },

	-- SHOW ALL LEVEL ACTIVITIES: when on, the filter panel offers and searches
	-- every activity, not only those whose suggested level range holds the
	-- player's level (LFGF.Activities, core/filterpanel_search.lua). OUR OWN SETTING,
	-- not Blizzard's CVar disableSuggestedLevelActivityFilter, which this addon
	-- neither reads nor writes: writing it from addon code would leave a value
	-- set by tainted code in Blizzard's CVarCallbackRegistry cache
	-- (CvarUtil.lua:132-138), which their finder then reads. Off by default, like
	-- the CVar (CVars.lua:625). .claude/rules/level-range-filter.md
	{ key = "showAllLevelRanges", scope = ACCOUNT, variable = "LFGFOREVER_SHOW_ALL_LEVEL_RANGES",
		type = "boolean", default = false },
	-- SHOW SUGGESTED LEVEL RANGES: each activity menu row ends in its range,
	-- "Deadmines (17 - 24)" (LFGF.ActivityMenuText, core/filterpanel_search.lua).
	{ key = "showActivityLevelRanges", scope = ACCOUNT, variable = "LFGFOREVER_SHOW_ACTIVITY_LEVEL_RANGES",
		type = "boolean", default = true },

	-- THE GUILD AND FRIEND MARKS (core/relations.lua). Off means no icon, no
	-- moving up, and no call to that API at all, in both lists. Friends were OFF
	-- and labelled Experimental until 0.21.0-dev.7, while the friend system was
	-- disabled in the Forever beta; confirmed working in the client on
	-- 2026-10-12, now ON by default. A new default only reaches players with
	-- nothing saved: every older file holds false, and keeps it, by the
	-- author's decision (.claude/rules/relation-icons.md).
	{ key = "markGuildmates", scope = ACCOUNT, variable = "LFGFOREVER_MARK_GUILDMATES",
		type = "boolean", default = true },
	{ key = "markFriends", scope = ACCOUNT, variable = "LFGFOREVER_MARK_FRIENDS",
		type = "boolean", default = true },
	-- SORT PLAYERS BY: the order of the players list's Players box, one of
	-- LFGF.PLAYER_SORT_ORDERS (core/main.lua), saved by name. "newest" is the
	-- order the list always kept before the setting existed.
	-- .claude/rules/player-sort-order.md
	{ key = "playerSortOrder", scope = ACCOUNT, variable = "LFGFOREVER_PLAYER_SORT_ORDER",
		type = "string", default = "newest" },
	-- SHOW LISTING NOTES: a listing's details text on a line of its own in the
	-- players list, in every category (InlineNote, core/listpanel.lua). Read
	-- when the list is built. On by default, so Quests & Zones keep the note
	-- they always had. .claude/rules/inline-note.md
	{ key = "showListingNotes", scope = ACCOUNT, variable = "LFGFOREVER_SHOW_LISTING_NOTES",
		type = "boolean", default = true },

	-- THE MINIMAP BUTTON (core/minimap.lua). The addon compartment entry is
	-- declared in the TOC and is not governed by this: it is Blizzard's menu.
	{ key = "showMinimapButton", scope = ACCOUNT, variable = "LFGFOREVER_SHOW_MINIMAP_BUTTON",
		type = "boolean", default = true },
	-- PLAYER RATINGS: the window's third tab, listing Blizzard's Recent Allies
	-- with one to three stars each (core/playerratings.lua), the marks in the
	-- lists, the rating order, the "Do you want to rate them?" chat line and
	-- the last party members list. ON by default, by the author's decision. A
	-- saved off stays off. .claude/rules/player-ratings.md
	{ key = "showPlayerRatings", scope = ACCOUNT, variable = "LFGFOREVER_SHOW_PLAYER_RATINGS",
		type = "boolean", default = true },

	-- The Filters tab as last searched, reset or applied from My filters
	-- (core/main.lua, LFGF.SavedFilters; .claude/rules/saved-filters.md). PER
	-- CHARACTER, by the author's decision: a level-60 main and a level-20 alt
	-- want different filters. A character's first load copies the account-wide
	-- record older versions wrote (LFGF.CopyAccountFiltersToCharacter, below).
	{ key = "filters", scope = CHARACTER, type = "table" },
	-- My filters, in save order (core/main.lua, LFGF.MyFilters; my-filters.md).
	-- Account-wide, by the author's decision: every character can apply them.
	{ key = "myFilters", scope = ACCOUNT, type = "table" },
	-- The Filters tab sections the player collapsed, a set of section keys
	-- (core/main.lua, LFGF.CollapsedFilterSections;
	-- .claude/rules/collapsible-filter-sections.md). Per character, like the
	-- filters, and copied from the old account-wide record the same way.
	{ key = "collapsedFilterSections", scope = CHARACTER, type = "table" },
	-- Set once a character's first load has copied the old account-wide
	-- filters and collapsed sections (LFGF.CopyAccountFiltersToCharacter), so a
	-- later nil is never filled from the old record again.
	{ key = "copiedAccountFilters", scope = CHARACTER, type = "boolean" },
	-- The activity menu's favorite dungeons and raids, activity ID -> true
	-- (core/filterpanel_search.lua). Per character, by the author's decision;
	-- Blizzard's Defaults forgets them (core/settings.lua).
	{ key = "favoriteActivities", scope = CHARACTER, type = "table" },
	-- The players' ratings, one to three stars each, keyed by "Firstname Surname"
	-- (core/main.lua, LFGF.PlayerRating; added in 1.5.0-dev.5,
	-- .claude/rules/player-ratings.md). Kept when the Player ratings setting is
	-- off, and when the player is no longer a recent ally.
	{ key = "playerRatings", scope = ACCOUNT, type = "table" },
	-- The last five players who joined your party, newest first, each with
	-- their name, class, level, GUID, your zone and the time they joined
	-- (core/recentparty.lua; added in 1.5.0-dev.14,
	-- .claude/rules/player-ratings.md). Per character, by the author's
	-- decision: Blizzard's Recent Allies are each character's own.
	{ key = "recentPartyMembers", scope = CHARACTER, type = "table" },

	-- The window's centre, as an offset from UIParent's centre in UIParent
	-- units, and its size in its own units (core/window.lua). No default: with
	-- nothing saved the window opens at its own default place and size.
	{ key = "windowX", scope = ACCOUNT, type = "number" },
	{ key = "windowY", scope = ACCOUNT, type = "number" },
	{ key = "windowWidth", scope = ACCOUNT, type = "number" },
	{ key = "windowHeight", scope = ACCOUNT, type = "number" },
	-- The window's size in Compact mode, saved apart from the full window's
	-- by the author's decision (core/window.lua; .claude/rules/compact-mode.md).
	-- Compact mode itself is never saved. With nothing saved, Compact mode is
	-- the full size less the filter column.
	{ key = "compactWindowWidth", scope = ACCOUNT, type = "number" },
	{ key = "compactWindowHeight", scope = ACCOUNT, type = "number" },

	-- Where on the minimap's rim the button sits, in degrees counter-clockwise
	-- from the right (core/minimap.lua). 225 -- bottom left -- is LibDBIcon's
	-- default (LibDBIcon-1.0.lua:157), so a first install lands where players
	-- expect minimap buttons.
	{ key = "minimapAngle", scope = ACCOUNT, type = "number", default = 225 },
}

local byKey = {}
for _, entry in ipairs(LFGF.SAVED_KEYS) do
	byKey[entry.key] = entry
end

local function EntryFor(key)
	local entry = byKey[key]
	if not entry then
		-- A typo in a key would otherwise read nil forever, silently.
		error("WildGroups: no saved key named " .. tostring(key), 3)
	end
	return entry
end

local function GlobalNameFor(scope)
	local name = GLOBAL_NAMES[scope]
	if not name then
		error("WildGroups: no saved table for scope " .. tostring(scope), 3)
	end
	return name
end

--- The saved table for a scope ("account" or "character"), created if it is
--- missing or is not a table. Creating it as a global is what makes the client
--- save it on logout: that is what the TOC's SavedVariables lines mean.
function LFGF.SavedTable(scope)
	local name = GlobalNameFor(scope)
	if type(_G[name]) ~= "table" then
		_G[name] = {}
	end
	return _G[name]
end

--- The raw saved value of a key, or nil. Never creates a table: callable
--- before ADDON_LOADED, when the tables may not exist, and anything can be on
--- disk -- the caller decides what is usable.
function LFGF.SavedValue(key)
	local entry = EntryFor(key)
	local saved = _G[GLOBAL_NAMES[entry.scope]]
	if type(saved) ~= "table" then
		return nil
	end
	return saved[entry.key]
end

--- Write a key, creating its table if needed. Writing nil clears the key and
--- never creates a table just to clear it.
function LFGF.SaveValue(key, value)
	local entry = EntryFor(key)
	local name = GLOBAL_NAMES[entry.scope]
	if value == nil then
		if type(_G[name]) == "table" then
			_G[name][entry.key] = nil
		end
		return
	end
	LFGF.SavedTable(entry.scope)[entry.key] = value
end

--- The saved value when it has the key's type (and, for a number with a
--- `min`, is not below it); the default otherwise.
---
--- NOT `value or default`: that would read a saved false as missing and turn
--- an option the player switched off back on.
function LFGF.SavedSetting(key)
	local entry = EntryFor(key)
	local value = LFGF.SavedValue(key)
	if type(value) ~= entry.type then
		return entry.default
	end
	if entry.min and value < entry.min then
		return entry.default
	end
	return value
end

-- THE FILTERS, PER CHARACTER. Each character keeps its own Filters tab and
-- collapsed sections. Older versions kept one account-wide record for every
-- character, so a character's first load starts from a copy of it, all of it,
-- the level range too, by the author's decisions. .claude/rules/saved-filters.md
local COPIED_FROM_ACCOUNT = { "filters", "collapsedFilterSections" }

--- Copy the old account-wide filters and collapsed sections into this
--- character's table, once per character. Called on ADDON_LOADED
--- (core/settings.lua), after both tables exist.
---
--- ONCE, not "whenever the character has none": nil is a normal state for
--- both keys (Blizzard's Defaults forgets the filters, and expanding every
--- section clears its key), and filling it again on the next login would
--- bring the old record back. So the copy sets `copiedAccountFilters`, even
--- when there was nothing to copy, and only a saved `true` counts as done.
---
--- Never replaces what the character already holds, copies only a table (a
--- deep copy, CopyTable, TableUtil.lua:218-228, so the two records never
--- share a table), and NEVER WRITES THE ACCOUNT TABLE: every character still
--- to log in needs it. The account keys stay on disk, unread by anything else,
--- until a later release drops this copy (CLAUDE.md, Next Release Reminders).
--- .claude/rules/saved-filters.md
function LFGF.CopyAccountFiltersToCharacter()
	if LFGF.SavedValue("copiedAccountFilters") == true then
		return
	end
	local account = _G[GLOBAL_NAMES[ACCOUNT]]
	if type(account) == "table" then
		for _, key in ipairs(COPIED_FROM_ACCOUNT) do
			local old = account[key]
			if LFGF.SavedValue(key) == nil and type(old) == "table" then
				LFGF.SaveValue(key, CopyTable(old))
			end
		end
	end
	LFGF.SaveValue("copiedAccountFilters", true)
end

-- THE OLD DEFAULT CONSTANTS, kept as names (settings.lua and the specs read
-- them) and taken from the table, so each value exists once.
LFGF.WHISPER_LOG_DEFAULT_SIZE = byKey.whisperLogSize.default
LFGF.ASK_TO_JOIN_DEFAULT_MESSAGE = byKey.askToJoinMessage.default
LFGF.INVITE_WHISPER_DEFAULT_MESSAGE = byKey.inviteMessage.default
LFGF.SHOW_ALL_LEVEL_RANGES_DEFAULT = byKey.showAllLevelRanges.default
LFGF.SHOW_ACTIVITY_LEVEL_RANGES_DEFAULT = byKey.showActivityLevelRanges.default
LFGF.MARK_GUILDMATES_DEFAULT = byKey.markGuildmates.default
LFGF.MARK_FRIENDS_DEFAULT = byKey.markFriends.default
LFGF.SHOW_MINIMAP_BUTTON_DEFAULT = byKey.showMinimapButton.default
LFGF.MINIMAP_DEFAULT_ANGLE = byKey.minimapAngle.default
LFGF.PLAYER_SORT_ORDER_DEFAULT = byKey.playerSortOrder.default
