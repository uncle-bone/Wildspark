-- LFGForever -- core/locale.lua
--
-- Every word LFG Forever shows, by key, in English -- and the one place a
-- LANGUAGE PACK can replace them. The first file the .toc loads, so by the time
-- any other file runs, LFGF.L already holds the words it should show.
--
-- A LANGUAGE PACK is a separate addon, LoadOnDemand, whose TOC carries
--   ## X-LFGForever-LanguagePack: 1
--   ## AllowAddOnTableAccess: 1
-- and whose only file fills its OWN addon table (the second vararg every file
-- gets) with { api = 1, language = "...", strings = { KEY = "...", ... } }.
-- This file walks the addon list, loads the FIRST such addon that works, reads
-- that table back, and copies each string it accepts over the English one.
-- Enabling or disabling the pack in the AddOns list is the language switch;
-- with no pack, nothing here changes a word. .claude/rules/language-packs.md
--
-- NOT HERE, by the author's decisions: the whisper text sent to other players
-- (the two default messages, the class and talent words, the "or" joiner; all
-- in core/main.lua and core/talents.lua), which stays English whatever the
-- pack; the %class%-style placeholders; the name "LFG Forever"; and anything
-- the game itself names -- dungeons, zones, categories, playstyles.
local addonName, root = ...
local LFGF = root.WildGroups or {}
root.WildGroups = LFGF
LFGF.MODULE_VERSION = "1.3.0"
LFGF.UPSTREAM_ADDON_NAME = "LFGForever"

--- The client's own string, so a German client keeps Blizzard's German for
--- these words when no pack is installed, as it always did; the English is
--- only for a client that lacks the global. Read once, here: GlobalStrings
--- are loaded before any addon file runs, and never change after.
local function Blizzard(globalName, english)
	local value = _G[globalName]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return english
end

--- A class's name the way the client says it -- LOCALIZED_CLASS_NAMES_MALE,
--- built by Blizzard_FrameXMLBase/Constants.lua:37 before any addon loads --
--- with the English behind it.
local function ClassName(token, english)
	local names = LOCALIZED_CLASS_NAMES_MALE
	local value = type(names) == "table" and names[token]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return english
end

-- KEY RULES (a spec holds the code to them):
--   * a key whose value is passed to string.format / SetFormattedText ends in
--     _FORMAT, and only those do -- what a pack's value is checked against;
--   * a key is never reused with a new meaning: change the English meaning,
--     change the key, so an older pack falls back to English instead of
--     showing the wrong words.
local L = {
	-- core/main.lua
	COMBAT_SETTINGS = "settings can't be opened during combat.",
	LOADED_VERSION_FORMAT = "%s %s loaded. Type %s",
	LOADED_FORMAT = "%s loaded. Type %s",

	-- core/relations.lua
	RELATION_GUILD = Blizzard("LFG_LIST_GUILD_MEMBER", "Guild Member"),
	RELATION_FRIEND = Blizzard("LFG_LIST_FRIEND", "Friend"),

	-- core/settings.lua. A *_LABEL here is a Settings row label: one line, no
	-- wrap, about 28 characters (Blizzard_SettingControls.lua:338-341).
	SETTINGS_WHISPER_LOG_SIZE_LABEL = "Whisper log size",
	SETTINGS_WHISPER_LOG_SIZE_TOOLTIP =
		"How many received whispers the Whispers tab keeps. When there are more, the oldest are removed.",
	SETTINGS_ASK_TO_JOIN_AUTO_WHISPER_LABEL = "Auto-whisper on Ask to Join",
	SETTINGS_ASK_TO_JOIN_AUTO_WHISPER_TOOLTIP = "When on, Ask to Join whispers the group leader your message. "
		.. "When off, it opens a whisper so you can type your own.",
	SETTINGS_ASK_TO_JOIN_MESSAGE_LABEL = "Message",
	SETTINGS_ASK_TO_JOIN_MESSAGE_TOOLTIP = "%class% and %level% become your class and level. %talents% becomes your active talent tree: the one you have spent the most points in. %role% becomes the roles you selected in Blizzard's Group Finder. Up to 200 characters. Saved for this character.",
	-- The "?" beside each message box: a title, then one bulleted line per
	-- keyword, "<keyword> - <description>". Only the description is here: the
	-- keyword, its colour and the bullet are added by core/settings.lua.
	SETTINGS_PLACEHOLDERS_TITLE = "Placeholders",
	SETTINGS_PLACEHOLDER_CLASS = "your class",
	SETTINGS_PLACEHOLDER_LEVEL = "your level",
	SETTINGS_PLACEHOLDER_TALENTS = "your main talent tree: the one with the most points",
	SETTINGS_PLACEHOLDER_ROLE = "the roles you selected in Blizzard's Group Finder",
	SETTINGS_PLACEHOLDER_DUNGEON = "the dungeons of your listing, or with no listing, "
		.. "the activities ticked in the activity filter",
	SETTINGS_INVITE_AUTO_WHISPER_LABEL = "Auto-whisper on Invite",
	SETTINGS_INVITE_AUTO_WHISPER_TOOLTIP = "When on, inviting a player from the players list also "
		.. "whispers them your message. When off, it only invites.",
	SETTINGS_INVITE_MESSAGE_LABEL = "Message",
	SETTINGS_INVITE_MESSAGE_TOOLTIP = "%dungeon% becomes the dungeon of your listing, or all of them "
		.. "if it has several (\"Deadmines, Wailing Caverns or Shadowfang Keep\"). "
		.. "With no listing, it becomes the activities ticked in the activity filter. "
		.. "Up to 200 characters. Saved for this character.",
	SETTINGS_SEARCH_HEADER = "Search",
	SETTINGS_SHOW_ALL_LEVELS_LABEL = "Show all level activities",
	SETTINGS_SHOW_ALL_LEVELS_TOOLTIP = "Show activities for every dungeon and raid, not only the "
		.. "ones suggested for your level.",
	SETTINGS_SHOW_LEVEL_RANGES_LABEL = "Show suggested level ranges",
	SETTINGS_SHOW_LEVEL_RANGES_TOOLTIP = "Show each activity's suggested level range after "
		.. "its name in the activity dropdown, for example Deadmines (17 - 24).",
	SETTINGS_MARK_GUILDMATES_LABEL = "Mark guild members",
	SETTINGS_MARK_GUILDMATES_TOOLTIP = "Show a guild icon beside guildmates and list them first.",
	SETTINGS_MARK_FRIENDS_LABEL = "Mark friends",
	SETTINGS_MARK_FRIENDS_TOOLTIP = "Show a friends icon beside your WoW and Battle.net friends "
		.. "and list them first.",
	-- "Sort players by", the last row of Search: a dropdown whose tooltip adds
	-- one "<name>: <line>" per order (Blizzard_Settings.lua:416-496). Keep each
	-- name short: the dropdown is 220 wide (Blizzard_SettingControls.lua:818).
	SETTINGS_PLAYER_SORT_LABEL = "Sort players by",
	SETTINGS_PLAYER_SORT_TOOLTIP = "How players are ordered in the Players list. Your own listing "
		.. "comes first, then guild members and friends.",
	PLAYER_SORT_NEWEST = "Newest listings",
	PLAYER_SORT_NEWEST_TOOLTIP = "New listings at the top.",
	PLAYER_SORT_OLDEST = "Oldest listings",
	PLAYER_SORT_OLDEST_TOOLTIP = "The longest-listed players at the top.",
	PLAYER_SORT_LEVEL_HIGH = "Highest level",
	PLAYER_SORT_LEVEL_HIGH_TOOLTIP = "Higher levels at the top.",
	PLAYER_SORT_LEVEL_LOW = "Lowest level",
	PLAYER_SORT_LEVEL_LOW_TOOLTIP = "Lower levels at the top.",
	PLAYER_SORT_CLASS = Blizzard("CLASS", "Class"),
	PLAYER_SORT_CLASS_TOOLTIP = "Listings grouped by class.",
	-- The key binding's label, on Blizzard's Keybindings page (core/slash.lua)
	-- and on the key binding row of LFG Forever's page. The key opens and
	-- closes it. The row's button opens Blizzard's Keybindings page.
	BINDING_OPEN_WINDOW = "Open LFG Forever",
	KEYBINDINGS = Blizzard("SETTINGS_KEYBINDINGS_LABEL", "Keybindings"),
	SETTINGS_KEYBINDING_TOOLTIP = "Set the key on Blizzard's Keybindings page.",
	SETTINGS_MINIMAP_BUTTON_LABEL = "Show minimap button",
	SETTINGS_MINIMAP_BUTTON_TOOLTIP = "Show a button on the edge of the minimap that opens and "
		.. "closes LFG Forever. Drag it to move it. /lfg works either way.",
	-- The settings page's sentence above Report a bug. %s is a language
	-- pack's exact title, which stays English; the quote marks around it are
	-- the translation's.
	SETTINGS_LANGUAGE_PACKS_FORMAT = "LFG Forever is also available in other languages. "
		.. "Each one is a separate addon on CurseForge, for example \"%s\".",
	SETTINGS_REPORT_BUG_LABEL = "Found a bug or have an idea?",
	SETTINGS_REPORT_BUG_TOOLTIP = "Tell us on Discord.",
	REPORT_BUG_POPUP_TEXT = "Copy the link with Ctrl+C and paste it into your browser.",
	-- The window header's Report a bug, beside Blizzard's bug icon. Its
	-- tooltip is the two sentences above.
	REPORT_BUG = "Report a bug",
	SETTINGS_RESET_WINDOW_LABEL = "Window position and size",
	SETTINGS_RESET_WINDOW_TOOLTIP = "Move the LFG Forever window back to where it first opened, at its original size.",
	MISCELLANEOUS = Blizzard("MISCELLANEOUS", "Miscellaneous"),
	RESET = Blizzard("RESET", "Reset"),
	CLOSE = Blizzard("CLOSE", "Close"),

	-- core/listpanel.lua
	ASK_TO_JOIN = "Ask to Join",
	GROUP_INVITE = Blizzard("GROUP_INVITE", "Group Invite"),
	LEVEL_ABBR = Blizzard("LEVEL_ABBR", "Lvl"),
	ACTIVITY_COUNT_FORMAT = Blizzard("LFGBROWSE_ACTIVITY_COUNT", "%d |4activity:activities;"),
	SEARCHING = Blizzard("SEARCHING", "Searching..."),
	LIST_DIVIDER_PLAYERS = Blizzard("LFG_LIST_CATEGORY_SOLO_PLAYERS", "Players"),
	LIST_DIVIDER_GROUPS = Blizzard("LFG_LIST_CATEGORY_GROUPS", "Groups"),
	-- The tooltip of each box's header: what a click on it does.
	LIST_COLLAPSE_GROUPS = "Collapse the Groups list",
	LIST_COLLAPSE_PLAYERS = "Collapse the Players list",
	LIST_EXPAND_GROUPS = "Expand the Groups list",
	LIST_EXPAND_PLAYERS = "Expand the Players list",
	NO_RESULTS = Blizzard("LFG_LIST_NO_RESULTS_FOUND",
		"No groups found. If you can't find what you're looking for, consider starting a group."),
	SEARCH_FAILED = Blizzard("LFG_LIST_SEARCH_FAILED",
		"Search Failed. Please wait a moment and try again."),

	-- core/whisperlog.lua
	WHISPERS_TAB_TITLE = "Whispers",
	WHISPERS_SECTION_TITLE = "Messages from players",
	LOCATION = "Location",
	NO_WHISPERS = "No whispers yet.",
	REMOVE = Blizzard("REMOVE", "Remove"),
	INVITE = Blizzard("INVITE", "Invite"),
	CONTINUED = Blizzard("CONTINUED", "..."),

	-- core/filterpanel.lua
	ROLE_SECTION_TITLE = "Find players by role and level",
	CLASS_SECTION_TITLE = "Find players by class",
	GROUP_SECTION_TITLE = "Find groups by role",
	-- core/filterpanel_shared.lua: the tooltip of the warning a collapsed
	-- section shows while its filters are not at their defaults.
	COLLAPSED_FILTERS_TITLE = "Filters still apply",
	COLLAPSED_FILTERS_TOOLTIP = "This section is collapsed, but its filters are still used in your search.",
	FILTERS_TAB_TITLE = "Filters",
	RESET_FILTERS = "Reset filters",
	-- The class filter's two links, and the Languages menu's first two rows
	-- (core/filterpanel_miscellaneous.lua), so the panel says it one way.
	UNSELECT_ALL = "Unselect all",
	SELECT_ALL = "Select all",
	CLEAR_CHAT = "Clear chat",
	LEVEL_RANGE_LABEL = "Player level range",
	MY_FILTERS = "My filters",
	SAVE_NEW_FILTER = "Save new filter",
	-- core/filterpanel_miscellaneous.lua: the Playstyle row. Its label is
	-- Blizzard's own over the retail filter's playstyles
	-- (Blizzard_GroupFinder/Mainline/LFGList.lua:2675); the dropdown says ALL
	-- when every playstyle is ticked or none is, the one name when one is, and
	-- the count otherwise. The names themselves stay the game's
	-- (GetGeneralPlaystyleString), as on the list rows.
	PLAYSTYLE_ROW_LABEL = Blizzard("GROUP_FINDER_FILTER_PLAYSTYLE", "Playstyle"),
	PLAYSTYLE_ALL = Blizzard("ALL", "All"),
	PLAYSTYLES_SELECTED_FORMAT = "%d selected",
	-- core/filterpanel_miscellaneous.lua: the Languages row, flush right on the
	-- Playstyle row. The label is Blizzard's own over its retail language menu
	-- (Blizzard_GroupFinder/Mainline/LFGList.lua:2686); its two bulk rows are
	-- the class filter's Select all and Unselect all, above. The dropdown names
	-- the one language ticked (by default, the player's own), says ALL when
	-- every one is, and the count otherwise.
	LANGUAGES_ROW_LABEL = Blizzard("LANGUAGES_LABEL", "Languages"),
	LANGUAGES_ALL = Blizzard("ALL", "All"),
	LANGUAGES_SELECTED_FORMAT = "%d selected",
	LANGUAGE_LOCKED_TOOLTIP = "Your game's language is always included in the search.",
	LANGUAGES_UNAVAILABLE_TOOLTIP = "Only your game's language can be searched here.",
	-- Read by code, L["LANGUAGE_NAME_" .. string.upper(code)]: one per locale
	-- the WowLocale structure holds (LFGListInfoDocumentation.lua:1045-1060).
	-- Blizzard's retail language names (LFG_LIST_LANGUAGE_*), except for the
	-- two pairs those name alike: Chinese takes the names
	-- LocaleUtil.GetLocaleDisplayName prefers (LOCALE_DISPLAY_NAME_*,
	-- Blizzard_SharedXMLBase/LocaleUtil.lua:12-24), Spanish the client's ESES
	-- and ESMX.
	LANGUAGE_NAME_DEDE = Blizzard("LFG_LIST_LANGUAGE_DEDE", "German"),
	LANGUAGE_NAME_ENUS = Blizzard("LFG_LIST_LANGUAGE_ENUS", "English"),
	LANGUAGE_NAME_ESES = Blizzard("ESES", "Spanish (EU)"),
	LANGUAGE_NAME_ESMX = Blizzard("ESMX", "Spanish (Latin American)"),
	LANGUAGE_NAME_FRFR = Blizzard("LFG_LIST_LANGUAGE_FRFR", "French"),
	LANGUAGE_NAME_ITIT = Blizzard("LFG_LIST_LANGUAGE_ITIT", "Italian"),
	LANGUAGE_NAME_KOKR = Blizzard("LFG_LIST_LANGUAGE_KOKR", "Korean"),
	LANGUAGE_NAME_PTBR = Blizzard("LFG_LIST_LANGUAGE_PTBR", "Portuguese"),
	LANGUAGE_NAME_RURU = Blizzard("LFG_LIST_LANGUAGE_RURU", "Russian"),
	LANGUAGE_NAME_ZHCN = Blizzard("LOCALE_DISPLAY_NAME_ZHCN", "Chinese (Simplified)"),
	LANGUAGE_NAME_ZHTW = Blizzard("LOCALE_DISPLAY_NAME_ZHTW", "Chinese (Traditional)"),
	ROLE_TANK = Blizzard("TANK", "Tank"),
	ROLE_HEALER = Blizzard("HEALER", "Healer"),
	ROLE_DAMAGE = Blizzard("DAMAGER", "Damage"),
	-- Read by token, L["CLASS_" .. classFilename]: the camelot nine
	-- (CLASS_SORT_ORDER, Camelot/Constants.lua:1-11).
	CLASS_WARRIOR = ClassName("WARRIOR", "Warrior"),
	CLASS_PALADIN = ClassName("PALADIN", "Paladin"),
	CLASS_HUNTER = ClassName("HUNTER", "Hunter"),
	CLASS_ROGUE = ClassName("ROGUE", "Rogue"),
	CLASS_PRIEST = ClassName("PRIEST", "Priest"),
	CLASS_SHAMAN = ClassName("SHAMAN", "Shaman"),
	CLASS_MAGE = ClassName("MAGE", "Mage"),
	CLASS_WARLOCK = ClassName("WARLOCK", "Warlock"),
	CLASS_DRUID = ClassName("DRUID", "Druid"),
	GROUP_TANK_AVAILABLE = "Tank role available",
	GROUP_HEALER_AVAILABLE = "Healer role available",
	GROUP_DAMAGE_AVAILABLE = "Damage role available",
	GROUP_HAS_TANK = "Has tank",
	GROUP_HAS_HEALER = "Has healer",
	-- core/filterpanel_groupclasses.lua: the Groups section's class filter, a
	-- dropdown with no label of its own, so its text says what it does. NONE
	-- while it hides nothing (no class selected, or every class), then the one
	-- class in the plural, then the count from two on. Three dots, never the
	-- one-character ellipsis: Blizzard's English strings use "..." and never
	-- that glyph, which the game font may lack.
	GROUP_CLASSES_NONE = "No groups with...",
	GROUP_CLASSES_ONE_FORMAT = "No %s",
	GROUP_CLASSES_COUNT_FORMAT = "No %d classes",
	-- Its tooltip, one short plain sentence (players found a longer one hard
	-- to read): the rule while it hides nothing, and the same sentence with the
	-- classes it hides by, each in its class colour, joined "A, B or C" with
	-- the two separators below (a translator picks the words for this sentence:
	-- "ni", "i", "a", ...).
	GROUP_CLASSES_TOOLTIP = "Show groups without chosen classes.",
	GROUP_CLASSES_EXCLUDED_TOOLTIP_FORMAT = "Show groups without %s.",
	GROUP_CLASSES_LIST_SEPARATOR = ", ",
	GROUP_CLASSES_LIST_LAST_SEPARATOR = " or ",
	-- Read by token, L["CLASS_PLURAL_" .. classFilename]: each class in the
	-- plural, as it follows "No" in the two texts above ("No Paladins", "no
	-- Druids, Mages or Warlocks"). A language that changes a noun after "no"
	-- writes that form here. Ours, not the client's: it has no plural names.
	CLASS_PLURAL_WARRIOR = "Warriors",
	CLASS_PLURAL_PALADIN = "Paladins",
	CLASS_PLURAL_HUNTER = "Hunters",
	CLASS_PLURAL_ROGUE = "Rogues",
	CLASS_PLURAL_PRIEST = "Priests",
	CLASS_PLURAL_SHAMAN = "Shamans",
	CLASS_PLURAL_MAGE = "Mages",
	CLASS_PLURAL_WARLOCK = "Warlocks",
	CLASS_PLURAL_DRUID = "Druids",
	CATEGORY_NONE = Blizzard("LFG_TYPE_NONE", "None"),
	LEVEL_SINGLE_FORMAT = Blizzard("LFD_LEVEL_FORMAT_SINGLE", "(%d)"),
	LEVEL_RANGE_FORMAT = Blizzard("LFD_LEVEL_FORMAT_RANGE", "(%d - %d)"),
	SEARCH = Blizzard("SEARCH", "Search"),
	-- The Search button's tooltip, Blizzard's refresh button's (Browse.xml:540).
	SEARCH_AGAIN = Blizzard("LFG_LIST_SEARCH_AGAIN", "Search Again"),
	MY_FILTER_PROMPT = "Name your new filter:",
	MY_FILTERS_FULL_FORMAT = "My filters holds up to %d filters. Delete one to save a new filter.",
	MY_FILTER_EMPTY = "Type a name for your new filter.",
	MY_FILTER_TOO_LONG_FORMAT = "Use at most %d letters.",
	MY_FILTER_TAKEN_FORMAT = 'You already have a filter named "%s".',
	-- Chat lines, each printed after "LFG Forever: ".
	MY_FILTER_SAVED_FORMAT = 'filter "%s" saved.',
	MY_FILTER_APPLIED_FORMAT = 'filter "%s" applied. Click Search to use it.',
	MY_FILTER_DELETED_FORMAT = 'filter "%s" deleted.',
	OKAY = Blizzard("OKAY", "Okay"),
	CANCEL = Blizzard("CANCEL", "Cancel"),
	DELETE = Blizzard("DELETE", "Delete"),
	ROLE_CHECK = Blizzard("ROLE_POLL", "Role Check"),
	ROLE_CHECK_ONLY_LEADER = Blizzard("ERR_LFG_ROLE_CHECK_ONLY_LEADER",
		"Only your group leader can initiate a Role Check."),
	-- The settings gear's tooltip, at the end of the search row.
	SETTINGS = Blizzard("SETTINGS", "Settings"),
	ACTIVITY_HEADER_DEFAULT = Blizzard("LFGBROWSE_ACTIVITY_HEADER_DEFAULT", "Filter by activity"),
	ACTIVITY_HEADER_FORMAT = Blizzard("LFGBROWSE_ACTIVITY_HEADER", "%d |4activity:activities; selected"),
	CATEGORY = Blizzard("CATEGORY", "Category"),

	-- core/window.lua. COMBAT_WINDOW is printed after "LFG Forever: ".
	COMBAT_WINDOW = "the group finder can't be opened during combat.",
	TAB_CREATE_LISTING = Blizzard("LFG_LIST_TAB_1", "Create Listing"),
	TAB_GROUP_BROWSER = Blizzard("LFG_LIST_TAB_2", "Group Browser"),
	TAB_WHO_LIST = Blizzard("LFG_LIST_TAB_3", "Who List"),

	-- core/minimap.lua
	MINIMAP_LEFT_CLICK = "Left-click to open or close.",
	MINIMAP_RIGHT_CLICK = "Right-click for settings.",
	MINIMAP_DRAG = "Drag to move.",
}
LFGF.L = L

-------------------------------------------------------
---------- Language packs
-------------------------------------------------------

-- The pack table layout this file reads. A pack with another number is
-- skipped, so the layout can change later without an old pack breaking
-- anything: it just shows English.
LFGF.LANGUAGE_PACK_API = 1

-- The TOC field that marks an addon as an LFG Forever language pack. Read with
-- C_AddOns.GetAddOnMetadata, which answers for addons not loaded yet -- the way
-- AtlasLoot Classic reads its LoadOnDemand modules' X- fields on this client.
local PACK_FIELD = "X-LFGForever-LanguagePack"

local function ValidPack(pack)
	return type(pack) == "table" and pack.api == LFGF.LANGUAGE_PACK_API
		and type(pack.strings) == "table"
end

--- Load one pack and return its table, or nil.
---
--- LoadAddOn runs the pack's file NOW, before it returns
--- (AddOnsDocumentation.lua:347-361: loaded, reason). A pack that is disabled,
--- out of date, missing or broken does not load -- false plus a reason, or an
--- error the pcall catches. GetAddOnLocalTable (:149-163) returns the pack's
--- own table only when its TOC opted in with AllowAddOnTableAccess; otherwise
--- it errors, also caught. Every failure is nil, and the caller tries the next.
local function LoadPack(name)
	local ok, loaded = pcall(C_AddOns.LoadAddOn, name)
	if not (ok and loaded) then
		return nil
	end
	local readOk, pack = pcall(C_AddOns.GetAddOnLocalTable, name)
	if readOk and ValidPack(pack) then
		return pack
	end
	return nil
end

--- The FIRST pack in addon-list order that loads and is valid. The search
--- stops there, so a second enabled pack is never even loaded -- it cannot
--- interfere, and costs nothing.
local function FindPack()
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and name ~= addonName and name ~= LFGF.UPSTREAM_ADDON_NAME then
			local field = C_AddOns.GetAddOnMetadata(name, PACK_FIELD)
			if field and field ~= "" then
				local pack = LoadPack(name)
				if pack then
					return pack
				end
			end
		end
	end
	return nil
end

--- The sorted conversion letters of a format string ("%s ... %d" -> "ds"),
--- or nil when it holds a % that is neither a conversion nor "%%".
local function Conversions(text)
	text = text:gsub("%%%%", "")
	local letters = {}
	for letter in text:gmatch("%%%d*%$?[-+ #0]*%d*%.?%d*(%a)") do
		letters[#letters + 1] = letter
	end
	local _, percents = text:gsub("%%", "")
	if percents ~= #letters then
		return nil
	end
	table.sort(letters)
	return table.concat(letters)
end

--- Whether a pack's value may replace the English one under this key. Built
--- so that nothing a pack holds can make string.format error in this addon.
local function Accepts(key, english, value)
	if type(english) ~= "string" or type(value) ~= "string" or value == "" then
		return false
	end
	if key:sub(-7) == "_FORMAT" then
		-- No positional %2$s: the client's format reads it, but the busted
		-- runtime (stock Lua 5.1) does not, so it could not be tested.
		if value:find("%%%d+%$") then
			return false
		end
		local want = Conversions(english)
		return want ~= nil and Conversions(value) == want
	end
	-- Not a format string: a % only where the English has one -- the
	-- %class%-style placeholders in two Settings tooltips.
	return english:find("%", 1, true) ~= nil or value:find("%", 1, true) == nil
end

local pack = FindPack()
if pack then
	for key, value in pairs(pack.strings) do
		if type(key) == "string" and Accepts(key, L[key], value) then
			L[key] = value
		end
	end
end
