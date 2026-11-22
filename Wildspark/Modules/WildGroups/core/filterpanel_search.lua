-- LFGForever -- core/filterpanel_search.lua
--
-- The filter panel's search row: the category dropdown, the activity dropdown
-- and the Search button, with everything behind them -- the activity list,
-- the ticked activities, the search itself and its timeout.
--
-- A BUILDER, called first by LFGF.CreateFilterPanel (core/filterpanel.lua):
-- LFGF.BuildSearchRow puts the row's state, events and methods on the panel
-- and returns its category dropdown UNANCHORED. core/filterpanel.lua places
-- it, hangs Role Check, the settings gear and every section off it, and lays
-- out from the sizes published below. What Search sends of the Filters tab
-- is asked of the panel when Search is clicked (panel:CurrentFilters,
-- panel.LevelRange). .claude/rules/filterpanel-search-row.md
--
-- THE DEFAULT FILTER ROW
-- ----------------------
-- Category dropdown, activity dropdown, then a Search button where Blizzard
-- has its refresh button -- copied from Blizzard's camelot Browse panel
-- (Blizzard_LFGVanilla_Browse.lua:1041-1259 and
-- Mainline/Blizzard_LFGVanilla_Browse.xml:414-479) so the two read as one UI.
--
-- SECRET VALUES: this file is on the safe side of that line. Only five
-- C_LFGList getters are SecretInChatMessagingLockdown -- GetActiveEntryInfo,
-- GetApplicantInfo, GetSearchResultInfo, GetSearchResultLeaderInfo,
-- GetSearchResultPlayerInfo. Category and activity info are NOT among them, so
-- their names can be read and formatted normally. The
-- SecretArguments = "AllowedWhenUntainted" on GetLfgCategoryInfo constrains
-- what may be passed IN, and this file passes plain numbers. The results list
-- is where the care is needed, not here. The one read of GetActiveEntryInfo
-- (LFGF.Activities) takes only its activityIDs, which the documentation marks
-- NeverSecret (LFGListInfoDocumentation.lua:938).
local _, root = ...
local LFGF = root.WildGroups
-- Every word this file shows, from core/locale.lua (loaded first).
local L = LFGF.L

-- Blizzard's own widget sizes: SetWidth(118) and SetWidth(167) in the two
-- dropdown OnLoads (Browse.lua:1042, :1108). (Their 32x32 refresh button,
-- Browse.xml:448, is a labelled Search button here, sized below.)
local CATEGORY_DROPDOWN_WIDTH = 118
local ACTIVITY_DROPDOWN_WIDTH = 167
-- The size Blizzard gives a labelled panel button in THIS addon: 111x28, the
-- same as their Send Message and Back buttons (Browse.xml:526,
-- Listing.xml:309).
local SEARCH_BUTTON_WIDTH = 111
local SEARCH_BUTTON_HEIGHT = 28

-- Blizzard's own gaps, kept exactly: the activity dropdown hangs 15 off the
-- category dropdown's right edge and the refresh button 9 off the activity
-- dropdown's (Browse.xml:427, :450). Our Search button takes the refresh
-- button's 9.
local CATEGORY_TO_ACTIVITY_GAP = 15
local ACTIVITY_TO_SEARCH_GAP = 9

-- WowStyle1DropdownTemplate's own height -- <Size x="120" y="25"/> at
-- Blizzard_Menu/Mainline/MenuTemplates.xml:4, the file camelot loads
-- ([Family]\MenuTemplates.xml, Blizzard_Menu.toc:21). The dropdowns never set
-- a height, so this is the number the client gives them, and naming it keeps
-- the two sides of the subtraction below symmetrical.
local DROPDOWN_HEIGHT = 25

-- What core/filterpanel.lua lays out from (it loads just after this file):
-- the row's width before Role Check, Blizzard's 9 gap (Role Check and the
-- settings gear take it too), the Search button's height (Role Check takes
-- it), and how far that button overhangs the dropdowns (the sections and
-- the tabs' sections clear it).
LFGF.SEARCH_ROW_WIDTH = CATEGORY_DROPDOWN_WIDTH + CATEGORY_TO_ACTIVITY_GAP
	+ ACTIVITY_DROPDOWN_WIDTH + ACTIVITY_TO_SEARCH_GAP + SEARCH_BUTTON_WIDTH
LFGF.SEARCH_ROW_GAP = ACTIVITY_TO_SEARCH_GAP
LFGF.SEARCH_BUTTON_HEIGHT = SEARCH_BUTTON_HEIGHT
-- The Search button is the filter row's tallest element -- 28 against the
-- dropdowns' 25 -- and it is centred on them, so it overhangs the dropdown's
-- bottom edge by half the difference.
LFGF.SEARCH_ROW_OVERHANG = (SEARCH_BUTTON_HEIGHT - DROPDOWN_HEIGHT) / 2

-------------------------------------------------------
---------- Activity selection state
-------------------------------------------------------
-- Mirrors LFGBrowseActivityDropdownMixin's selectedValues (Browse.lua:1107).

local function ActivityIsSelected(panel, activityID)
	return tContains(panel.selectedActivityIDs, activityID)
end

local function ActivityToggle(panel, activityID)
	local index = tIndexOf(panel.selectedActivityIDs, activityID)
	if index then
		table.remove(panel.selectedActivityIDs, index)
	else
		table.insert(panel.selectedActivityIDs, activityID)
	end
	panel:UpdateActivityHeader()
end

local function ActivityReset(panel)
	panel.selectedActivityIDs = {}
	panel:UpdateActivityHeader()
end

-- How many dropped activities the chat line names before it counts the rest:
-- "A, B, C and 2 more".
local NAMED_DROPPED_ACTIVITIES = 3

--- Two or more names for the chat line: "A and B", "A, B and C", then
--- "A, B, C and 2 more". Every word from core/locale.lua.
local function JoinDroppedNames(names)
	local shown = {}
	for index = 1, math.min(#names, NAMED_DROPPED_ACTIVITIES) do
		shown[index] = names[index]
	end
	if #names > NAMED_DROPPED_ACTIVITIES then
		table.insert(shown, L.ACTIVITY_LIST_MORE_FORMAT:format(#names - NAMED_DROPPED_ACTIVITIES))
	end
	return table.concat(shown, L.ACTIVITY_LIST_SEPARATOR, 1, #shown - 1)
		.. L.ACTIVITY_LIST_LAST_SEPARATOR .. shown[#shown]
end

--- Untick every activity that `offered` does not hold, and say so in ONE
--- chat line. Returns whether anything was unticked. It never searches.
---
--- WHY. The ticks are kept apart from the list they were picked from, and
--- that list changes under them: LFGF.Activities leaves out an activity the
--- player's level has left, or one offered only while it was in the player's
--- own listing, and the server can stop offering one. A tick the menu no
--- longer shows cannot be unticked, and Search would keep sending it.
--- Blizzard's Browse tab has the same gap: its selectedValues are never
--- checked again (LFGBrowseActivityDropdownMixin, Blizzard_LFGVanilla_Browse.lua).
---
--- `offered` is LFGF.Activities for the category, so "Show all level
--- activities" counts as it does everywhere: while it is on, nothing drops
--- for level, only what the server stopped offering.
---
--- The names are the menu's (LFGUtil_GetActivityInfoName), in the order they
--- were ticked. An activity the client no longer describes is unticked with no
--- name (GetActivityInfoTable is MayReturnNothing,
--- LFGListInfoDocumentation.lua:186). See .claude/rules/level-range-filter.md.
local function DropUnofferedActivities(panel, offered)
	local kept, names, dropped = {}, {}, false
	for _, activityID in ipairs(panel.selectedActivityIDs) do
		if tContains(offered, activityID) then
			table.insert(kept, activityID)
		else
			dropped = true
			local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
			if activityInfo then
				table.insert(names, LFGUtil_GetActivityInfoName(activityInfo))
			end
		end
	end
	if not dropped then
		return false
	end

	panel.selectedActivityIDs = kept
	panel:UpdateActivityHeader()
	local setting = L.SETTINGS_SHOW_ALL_LEVELS_LABEL
	if #names == 1 then
		LFGF.Print(L.ACTIVITY_NO_LONGER_OFFERED_FORMAT:format(names[1], names[1], setting))
	elseif #names > 1 then
		LFGF.Print(L.ACTIVITIES_NO_LONGER_OFFERED_FORMAT:format(JoinDroppedNames(names), setting))
	end
	return true
end

-------------------------------------------------------
---------- Level ranges
-------------------------------------------------------

--- The activities a category offers: what the dropdowns list, and what a
--- search with nothing ticked asks for.
---
--- BLIZZARD'S RULE, UNDER OUR OWN SETTING. Blizzard's Group Finder drops every
--- activity whose suggested level range does not hold the player's level, unless
--- its CVar disableSuggestedLevelActivityFilter is on
--- (LFGUtil_GetFilteredActivities, Blizzard_LFGVanilla_ParentFrame.lua:259-280).
--- This is the same rule with LFGF.ShowAllLevelRanges() in the CVar's place:
--- the addon never reads or writes Blizzard's CVar (core/main.lua says why), so
--- ticking the option in one finder does not change the other.
---
--- The rule, as Blizzard's:
---   * out of range means minLevelSuggestion above the player's level, or
---     maxLevelSuggestion below it; a 0 means no limit on that side, and both
---     ends count as inside;
---   * an activity of the player's own listing is always kept, so they can
---     find their own group. activityIDs is NeverSecret
---     (LFGListInfoDocumentation.lua:938); GetActiveEntryInfo answers nothing
---     when there is no listing (MayReturnNothing, :141).
---
--- ONE DIFFERENCE: an activity with no info table is KEPT. GetActivityInfoTable
--- is MayReturnNothing (:186) and Blizzard indexes it unguarded; here it is let
--- through, the way the filters let a listing through when they cannot check it.
---
--- UnitLevel carries no secret predicate (UnitDocumentation.lua:2474-2487), and
--- everything else read here is a plain number. Only engine API, so unlike the
--- LFGUtil_* helpers this works before the LoadOnDemand Group Finder is in.
function LFGF.Activities(categoryID, activityGroupID)
	local activities = C_LFGList.GetAvailableActivities(categoryID, activityGroupID)
	if LFGF.ShowAllLevelRanges() then
		return activities
	end

	local activeEntryInfo = C_LFGList.GetActiveEntryInfo()
	local listed = activeEntryInfo and activeEntryInfo.activityIDs or {}
	local playerLevel = UnitLevel("player")

	local kept = {}
	for _, activityID in ipairs(activities) do
		local keep = true
		if not tContains(listed, activityID) then
			local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
			if activityInfo then
				local minLevel = activityInfo.minLevelSuggestion
				local maxLevel = activityInfo.maxLevelSuggestion
				keep = not ((minLevel > 0 and minLevel > playerLevel)
					or (maxLevel > 0 and maxLevel < playerLevel))
			end
		end
		if keep then
			table.insert(kept, activityID)
		end
	end
	return kept
end

-------------------------------------------------------
---------- Favorite activities
-------------------------------------------------------
-- A star at the right end of each Dungeons and Raids row of the activity menu
-- marks a favorite: listed first in its own sub-list from the next open, and
-- still listed when the player's level is outside its range. Saved per
-- character, activity ID -> true. The author's decisions are in
-- .claude/rules/favorite-activities.md.

-- The two categories with stars: Dungeon and Raid, Blizzard's own IDs
-- (Mainline/LFGVanilla_Constants.lua:10-11).
local FAVORITE_CATEGORIES = { [2] = true, [114] = true }

-- Blizzard's Auction House star: gold on a favorite, the empty one otherwise,
-- each its own highlight, at 0.2 and 0.4 (UpdateFavoriteState,
-- Blizzard_AuctionHouseTableBuilder.lua:239-245). 40x36 art (AtlasInfo.lua),
-- drawn 13x12: as tall as the menu's checkbox square, common-dropdown-ticksquare
-- at its 12x12 atlas size (Mainline/MenuVariants.lua, CreateCheckbox), with
-- the art's shape kept.
local FAVORITE_ATLAS = "auctionhouse-icon-favorite"
local NOT_FAVORITE_ATLAS = "auctionhouse-icon-favorite-off"
local STAR_WIDTH, STAR_HEIGHT = 13, 12
-- 2 up from the row's middle, level with the row's text in the client:
-- Blizzard lifts the text and tick 1 (Mainline/MenuVariants.lua,
-- CreateCheckbox), and the star's art sits low in its box, so centred, and
-- even 1 up, it read low.
local STAR_OFFSET_Y = 2

local FAVORITES_KEY = "favoriteActivities"

--- Whether this character starred `activityID`. Only a saved true counts.
local function IsFavoriteActivity(activityID)
	local saved = LFGF.SavedValue(FAVORITES_KEY)
	return type(saved) == "table" and saved[activityID] == true
end

--- Star or unstar `activityID` for this character. Writes only the
--- favorites, and clears the key when none is left.
local function SetFavoriteActivity(activityID, favorite)
	local saved, favorites = LFGF.SavedValue(FAVORITES_KEY), {}
	if type(saved) == "table" then
		for id, value in pairs(saved) do
			if value == true then
				favorites[id] = true
			end
		end
	end
	favorites[activityID] = favorite or nil
	LFGF.SaveValue(FAVORITES_KEY, next(favorites) ~= nil and favorites or nil)
end

--- What the activity menu lists: LFGF.Activities, plus this character's
--- favorites the server offers that the level rule left out. The menu, the
--- check of its ticks and a group's row use this; a Search with nothing
--- ticked and the category list keep LFGF.Activities, the player's level
--- alone, by the author's decisions.
local function MenuActivities(categoryID, activityGroupID)
	local activities = LFGF.Activities(categoryID, activityGroupID)
	if not FAVORITE_CATEGORIES[categoryID] then
		return activities
	end
	for _, activityID in ipairs(C_LFGList.GetAvailableActivities(categoryID, activityGroupID)) do
		if IsFavoriteActivity(activityID) and not tContains(activities, activityID) then
			table.insert(activities, activityID)
		end
	end
	return activities
end

--- The star on one activity row, drawn each time the menu draws the row: an
--- initializer, Blizzard's recipe for a button on a menu row
--- (CooldownViewerUtil.lua:90-108). Both stars are Blizzard's hover button
--- (MenuTemplates.AttachUtilityButton), its own texture hidden for the star's
--- art, as the Cooldown Viewer's is: shown only while the row is hovered, and
--- kept shown on a favorite. Both sit at the row's right end, where Blizzard
--- puts its gear (MenuVariants.GearButtonAnchor). Not AttachBasicButton: built
--- from addon code, its pass-through is refused in combat
--- (.claude/rules/favorite-activities.md, decision S5).
---
--- A click stars or unstars, then redraws the open menu where it is
--- (ReinitializeAll, which a menu offers, Menu.lua:1781-1787): no row moves
--- until the menu opens again, and an open sub-list stays open. The star's
--- own tooltip is hidden first, so the next hover shows the new words. No
--- sound, like the Auction House star. A redraw (this click, or a tick) keeps
--- the row's own fields (Compositor.lua, Clear), so the wraps of the row's
--- OnEnter / OnLeave pile up; the newest runs last and decides, and the row
--- gets its own star frame back (FrameFactory pools are per parent).
local function AddFavoriteStar(row, activityID)
	row:AddInitializer(function(button, _, menu)
		local favorite = IsFavoriteActivity(activityID)
		-- Both stars are Blizzard's hover button, as My filters' x is. Its
		-- AttachTemplate leaves the button's metatable alone, so the protected
		-- pass-through inside is allowed in combat; AttachBasicButton's
		-- AttachFrame does not, and was refused there.
		local star = MenuTemplates.AttachUtilityButton(button, nil, STAR_WIDTH, STAR_HEIGHT)
		star.Texture:Hide()
		if favorite then
			-- The gold star shows at once, and again after the row's leave,
			-- which Blizzard's hover button answers with a hide.
			star:Show()
			local onLeave = button.OnLeave
			button.OnLeave = function(...)
				onLeave(...)
				star:Show()
			end
		elseif button:IsMouseMotionFocus() then
			-- Redrawn under the mouse (a tick, or this star's own click): no
			-- OnEnter comes, so show it now, by the check Blizzard uses to put
			-- the row's own highlight back (MenuTemplates.lua,
			-- ButtonInitializer). Not IsMouseOver: while initializers run the
			-- row is 1x1 (Menu.lua, CallInitializers), so it is never under
			-- the cursor then.
			star:Show()
		end
		local atlas = favorite and FAVORITE_ATLAS or NOT_FAVORITE_ATLAS
		star:SetNormalAtlas(atlas)
		star:SetHighlightAtlas(atlas, "ADD")
		star:GetHighlightTexture():SetAlpha(favorite and 0.2 or 0.4)
		MenuTemplates.SetUtilityButtonAnchor(star, MenuVariants.GearButtonAnchor, button, 0, STAR_OFFSET_Y)
		-- Blizzard's words as the white title, then a gold line saying what a
		-- favorite does, the shape of the addon's other tooltips
		-- (LFGF.ShowTooltip), by the hook SetUtilityButtonTooltipText uses
		-- (MenuUtil.HookTooltipScripts).
		MenuUtil.HookTooltipScripts(star, function(tooltip)
			GameTooltip_SetTitle(tooltip, favorite and L.REMOVE_FAVORITE or L.SET_FAVORITE)
			GameTooltip_AddNormalLine(tooltip, L.FAVORITES_LISTED_AT_TOP)
		end)
		MenuTemplates.SetUtilityButtonClickHandler(star, function()
			MenuUtil.HideTooltipEx(star, GetAppropriateTooltip())
			SetFavoriteActivity(activityID, not favorite)
			menu:ReinitializeAll()
		end)
	end)
end

-------------------------------------------------------
---------- The dropdowns
-------------------------------------------------------

--- The categories the menu would actually OFFER, in menu order.
---
--- Not simply GetAvailableCategories: the menu drops a category with no
--- activities, and one whose info cannot be read. Both the menu and the
--- auto-selection below walk this, so "the first category" means the first one
--- the player can actually see -- auto-selecting something invisible would be
--- worse than selecting nothing.
local function SelectableCategories()
	local selectable = {}

	-- The activity menu a category leads to is built from LFGUtil_* helpers
	-- that live INSIDE the LoadOnDemand Group Finder
	-- (Blizzard_LFGVanilla_ParentFrame.lua:185-280), so they do not exist until
	-- that addon is in -- and this function is also called while the panel is
	-- BUILT, on the first /lfg, which can come first. (LFGF.Activities itself
	-- needs only engine API.)
	--
	-- No categories is the honest answer then, and
	-- LFG_LIST_AVAILABILITY_UPDATE is what picks it up afterwards.
	if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder_VanillaStyle") then
		return selectable
	end

	for _, categoryID in ipairs(C_LFGList.GetAvailableCategories()) do
		if #LFGF.Activities(categoryID) ~= 0 then
			local categoryInfo = C_LFGList.GetLfgCategoryInfo(categoryID)
			if categoryInfo then
				table.insert(selectable, { id = categoryID, name = categoryInfo.name })
			end
		end
	end

	return selectable
end

-- Declared before SetupCategoryMenu because the menu's generator closes over
-- it, and assigned after because it calls the menu back.
local SelectCategory

--- Category radios, from Browse.lua:1050-1081.
---
--- The one behaviour worth naming: a category whose filtered activity list is
--- empty is SKIPPED entirely (:1074), so the player is never offered a category
--- that would produce nothing.
local function SetupCategoryMenu(panel)
	-- SetupMenu's generator is called as (dropdown, rootDescription)
	-- (DropdownButton.lua:237). The category menu never needs the dropdown
	-- itself, so the first parameter is left unnamed rather than unused.
	panel.CategoryDropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetTag("MENU_LFGF_CATEGORY")

		local function IsSelected(value)
			return panel.selectedCategoryID == value
		end
		local function SetSelected(value)
			SelectCategory(panel, value)
		end

		local categories = SelectableCategories()
		if #categories == 0 then
			rootDescription:CreateRadio(L.CATEGORY_NONE)
			return
		end

		for _, category in ipairs(categories) do
			rootDescription:CreateRadio(category.name, IsSelected, SetSelected, category.id)
		end
	end)
end

--- Choose a category, from the menu or from the auto-selection.
---
--- One function so the two cannot drift: picking a category has side effects
--- beyond the field, and an auto-selection that set only the field would leave
--- a stale activity menu and a disabled Search button.
function SelectCategory(panel, categoryID)
	panel.selectedCategoryID = categoryID
	-- Browse.lua:1096-1099 -- choosing a category clears the activity filter,
	-- because the old activities belong to the old category.
	ActivityReset(panel)
	SetupCategoryMenu(panel)
	panel:SetupActivityMenu()
	panel:UpdateSearchState()
end

--- Pick the first category for the player, if they have not picked one.
---
--- A panel that opens with no category cannot search: the Search button is
--- disabled, and C_LFGList.Search refuses a categoryID of 0. So the player's
--- first click would always be the same click, and it is made for them. On this
--- client the first selectable category is Dungeons (id 2,
--- Mainline/LFGVanilla_Constants.lua:10).
---
--- It chooses, it does not SEARCH. Picking a category for someone is a
--- convenience; running a query they did not ask for is not.
local function SelectFirstCategory(panel)
	if panel.selectedCategoryID > 0 then
		return
	end

	local categories = SelectableCategories()
	if #categories == 0 then
		return
	end

	SelectCategory(panel, categories[1].id)
end

--- "Show all level activities" changed (core/settings.lua): rebuild the dropdowns
--- for the new activity list.
---
--- Blizzard's finder does the same on its CVar's change
--- (LFGBrowseMixin:ActivityFiltersChanged, Browse.lua:140-143, :320-322): the
--- ticked activities are cleared, because the list they were ticked from has
--- changed. Theirs also drops the category; this keeps it while the menu still
--- offers it, and otherwise moves to the first one, so the Search button stays
--- usable. It does NOT search: a setting is not a request for results.
local function LevelRangesChanged(panel)
	local current = panel.selectedCategoryID
	local offered = false
	for _, category in ipairs(SelectableCategories()) do
		if category.id == current then
			offered = true
		end
	end

	SelectCategory(panel, offered and current or 0)
	SelectFirstCategory(panel)
end

--- One activity row's text in the activity menu: the name Blizzard shows
--- (LFGUtil_GetActivityInfoName, ParentFrame.lua:282-285), then, while "Show
--- activity level ranges" is on, its suggested level range.
---
--- The range is the one Blizzard's camelot Listing tab shows beside each
--- activity -- minLevelSuggestion / maxLevelSuggestion (Listing.lua:1011-1012),
--- formatted by its rule (:1153-1161), copied exactly so the two finders never
--- disagree about the same dungeon:
---   * min == max, or max == 0: one number, LFD_LEVEL_FORMAT_SINGLE "(%d)",
---     or nothing at all when min is 0 too;
---   * otherwise LFD_LEVEL_FORMAT_RANGE "(%d - %d)" -- including "(0 - 20)",
---     which is how Blizzard's tab shows a range with no floor.
--- Both are GlobalStrings (enUS.lua:13496-13497), used whole so a translation
--- keeps its own wording. Neither field is secret: GetActivityInfoTable only
--- restricts its ARGUMENTS (AllowedWhenUntainted), and its activityID comes
--- from C_LFGList itself.
function LFGF.ActivityMenuText(activityInfo)
	if not activityInfo then
		return ""
	end
	local name = LFGUtil_GetActivityInfoName(activityInfo)
	if not LFGF.ShowActivityLevelRanges() then
		return name
	end

	local minLevel = activityInfo.minLevelSuggestion
	local maxLevel = activityInfo.maxLevelSuggestion
	local range
	if minLevel == maxLevel or maxLevel == 0 then
		if minLevel ~= 0 then
			range = string.format(L.LEVEL_SINGLE_FORMAT, minLevel)
		end
	else
		range = string.format(L.LEVEL_RANGE_FORMAT, minLevel, maxLevel)
	end
	return range and (name .. " " .. range) or name
end

--- From this level on the activity menu goes by name. Fixed at 60, Forever's
--- level cap, by the author's decision (.claude/rules/activity-menu-order.md,
--- *At level 60*): at the cap the level order no longer helps.
local NAME_ORDER_LEVEL = 60

--- Below level 60: Blizzard's camelot LISTING tab's order. By the author's
--- decision (2026-10-04), copied from ActivitySortComparator
--- (Blizzard_LFGVanilla_Listing.lua:965-981), whose fields are filled from
--- GetActivityInfoTable (:1006-1013):
---   1. orderIndex, HIGHEST first;
---   2. maxLevelSuggestion: 0 (no cap) first, then the highest cap first;
---   3. minLevelSuggestion, highest first;
---   4. the name the menu shows (LFGUtil_GetActivityInfoName), ignoring case.
--- Nothing after that, as in the Listing tab: two rows equal on all four may
--- come out either way, since table.sort is not stable.
local function ListingOrder(lhs, rhs)
	if lhs.orderIndex ~= rhs.orderIndex then
		return lhs.orderIndex > rhs.orderIndex
	elseif lhs.maxLevelSuggestion ~= rhs.maxLevelSuggestion then
		if lhs.maxLevelSuggestion == 0 or rhs.maxLevelSuggestion == 0 then
			return lhs.maxLevelSuggestion == 0
		end
		return lhs.maxLevelSuggestion > rhs.maxLevelSuggestion
	elseif lhs.minLevelSuggestion ~= rhs.minLevelSuggestion then
		return lhs.minLevelSuggestion > rhs.minLevelSuggestion
	end
	return strcmputf8i(LFGUtil_GetActivityInfoName(lhs), LFGUtil_GetActivityInfoName(rhs)) < 0
end

--- From level 60: Blizzard's camelot BROWSE dropdown's order, copied from
--- LFGUtil_SortActivityIDs (Blizzard_LFGVanilla_ParentFrame.lua:175-194):
---   1. orderIndex, LOWEST first;
---   2. the name the menu shows, ignoring case, when the names differ;
---   3. the activity ID, lowest first.
--- It reads no level at all. Where every activity has the same orderIndex,
--- this is A to Z.
local function BrowseOrder(lhs, rhs, lhsID, rhsID)
	if lhs.orderIndex ~= rhs.orderIndex then
		return lhs.orderIndex < rhs.orderIndex
	end
	local lhsName, rhsName = LFGUtil_GetActivityInfoName(lhs), LFGUtil_GetActivityInfoName(rhs)
	if lhsName ~= rhsName then
		return strcmputf8i(lhsName, rhsName) < 0
	end
	return lhsID < rhsID
end

--- The order of the activity menu's rows: this character's favorites
--- (IsFavoriteActivity) first, so they lead their own sub-list, then
--- ListingOrder below level 60 and BrowseOrder from 60 on, which also orders
--- the favorites among themselves. Every category alike.
---
--- `infos` holds each activity's answer from OrganizeActivitiesForMenu, so the
--- sort asks the client nothing. None of these fields is secret, and none is
--- nilable (LFGListInfoDocumentation.lua:884-888). `byName` is decided once
--- per menu, by the caller.
local function ActivityMenuOrder(infos, byName)
	return function(lhsID, rhsID)
		local lhsFavorite, rhsFavorite = IsFavoriteActivity(lhsID), IsFavoriteActivity(rhsID)
		if lhsFavorite ~= rhsFavorite then
			return lhsFavorite
		end
		if byName then
			return BrowseOrder(infos[lhsID], infos[rhsID], lhsID, rhsID)
		end
		return ListingOrder(infos[lhsID], infos[rhsID])
	end
end

--- The activities bucketed by group, each bucket in ActivityMenuOrder, plus
--- each activity's info table.
---
--- Blizzard's LFGUtil_OrganizeActivitiesByActivityGroup (ParentFrame.lua
--- :227-244) does the bucketing, but always sorts each bucket the Browse way,
--- with no favorites, and keeps no info, so the rows would ask for it again. This asks once per
--- activity: GetActivityInfoTable builds a table on every call and
--- MayReturnNothing (LFGListInfoDocumentation.lua:186), so a second answer is
--- not even sure to be there. An activity with no answer is left out, as
--- Blizzard's organiser leaves it out (:231).
---
--- The player's level is read here, each time the menu is built (it is
--- built on every open, DropdownButton.lua:117-118), so reaching 60 needs no
--- event. UnitLevel carries no secret predicate (UnitDocumentation.lua
--- :2474-2487).
local function OrganizeActivitiesForMenu(activities)
	local organized, infos = {}, {}
	for _, activityID in ipairs(activities) do
		local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
		if activityInfo then
			infos[activityID] = activityInfo
			local groupID = activityInfo.groupFinderActivityGroupID
			organized[groupID] = organized[groupID] or {}
			table.insert(organized[groupID], activityID)
		end
	end

	local order = ActivityMenuOrder(infos, UnitLevel("player") >= NAME_ORDER_LEVEL)
	for _, activityIDs in pairs(organized) do
		table.sort(activityIDs, order)
	end
	return organized, infos
end

--- Activity checkboxes, from Browse.lua:1114-1181.
---
--- Two behaviours copied exactly:
---   * with NO category the dropdown is disabled and its selections cleared
---     (:1175-1179) -- this is the "disabled until you pick a category" rule;
---   * the menu SHAPE depends on how many activity groups there are (:1158-1162):
---     several groups become submenus, a single group stays flat on the root
---     with its activities indented by LFG_LIST_INDENT ("  %s").
---
--- Each activity row's text is LFGF.ActivityMenuText: the name, and its level
--- range while that setting is on. The indent wraps both. Group rows have no
--- level, and the dropdown's own text (UpdateActivityHeader) stays the bare
--- name, so the 167-wide button never has to hold a range.
---
--- ONE DIFFERENCE: below level 60 the rows within a group, and the rows with
--- no group, are in the Listing tab's order (ActivityMenuOrder above),
--- whatever the level-range setting says; from 60 they are in this
--- dropdown's own Browse order. The groups keep Blizzard's own order
--- (LFGUtil_SortActivityGroupIDs).
---
--- OURS: in Dungeons and Raids each activity row carries the favorite star
--- (AddFavoriteStar), and the menu lists this character's favorites even
--- outside the player's level (MenuActivities).
function LFGF.SetupActivityMenu(panel)
	panel.ActivityDropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_LFGF_ACTIVITY")

		local function IsActivitySelected(value) return ActivityIsSelected(panel, value) end
		local function SelectActivity(value) ActivityToggle(panel, value) end

		if panel.selectedCategoryID <= 0 then
			dropdown:SetEnabled(false)
			ActivityReset(panel)
			return
		end

		dropdown:SetEnabled(true)

		local activities = MenuActivities(panel.selectedCategoryID)
		local starred = FAVORITE_CATEGORIES[panel.selectedCategoryID]
		-- A tick this menu would not show could never be unticked, so it goes
		-- first. The menu is built on every open (DropdownButton.lua:117-118).
		DropUnofferedActivities(panel, activities)
		if #activities == 0 then
			return
		end

		local organized, infos = OrganizeActivitiesForMenu(activities)
		local activityGroupIDs = GetKeysArray(organized)
		LFGUtil_SortActivityGroupIDs(activityGroupIDs)

		for _, activityGroupID in ipairs(activityGroupIDs) do
			local activityIDs = organized[activityGroupID]

			if activityGroupID == 0 then
				-- Free-floating activities, with no group of their own.
				for _, activityID in ipairs(activityIDs) do
					local row = rootDescription:CreateCheckbox(LFGF.ActivityMenuText(infos[activityID]),
						IsActivitySelected, SelectActivity, activityID)
					if starred then
						AddFavoriteStar(row, activityID)
					end
				end
			else
				local groupText = C_LFGList.GetActivityGroupInfo(activityGroupID)
				local groupCheckbox = rootDescription:CreateCheckbox(groupText,
					function() return panel:IsAnyActivitySelectedInGroup(activityGroupID) end,
					function()
						panel:SetAllActivitiesInGroup(activityGroupID,
							not panel:IsAnyActivitySelectedInGroup(activityGroupID))
					end,
					activityGroupID)

				-- One group: keep everything on the root and indent it. More
				-- than one: nest each group's activities under it.
				local parentMenu, textIndent = rootDescription, LFG_LIST_INDENT
				if #activityGroupIDs > 1 then
					parentMenu, textIndent = groupCheckbox, "%s"
				end

				for _, activityID in ipairs(activityIDs) do
					local text = string.format(textIndent, LFGF.ActivityMenuText(infos[activityID]))
					local row = parentMenu:CreateCheckbox(text, IsActivitySelected, SelectActivity, activityID)
					if starred then
						AddFavoriteStar(row, activityID)
					end
				end
			end
		end
	end)
end

-------------------------------------------------------
---------- The Search button
-------------------------------------------------------
-- In the place of Blizzard's hand-rolled refresh button (Browse.xml:447-479):
-- a labelled UIPanelButtonTemplate, with Blizzard's "Search Again" as its
-- tooltip.

local function BuildSearchButton(panel)
	-- UIPanelButtonTemplate, which is what Blizzard uses for every labelled
	-- button in this addon -- Send Message and Group Invite on the browse panel
	-- (Browse.xml:525, :534), Back on the listing one (Listing.xml:308).
	--
	-- It replaced a hand-rolled UI-SquareButton carrying a refresh icon. That
	-- one needed a tooltip to say what it did, a pair of OnMouseDown/OnMouseUp
	-- handlers to nudge the icon a pixel while held, and four textures; a
	-- labelled button needs none of that art, and gets the tooltip from its
	-- template (below).
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(SEARCH_BUTTON_WIDTH, SEARCH_BUTTON_HEIGHT)

	-- SEARCH ("Search", GlobalStrings/enUS.lua:19010) rather than Blizzard's
	-- LFG_LIST_SEARCH_AGAIN ("Search Again", Browse.xml:475). Theirs sits on a
	-- panel that has already searched once by the time you can read it; this
	-- window opens with nothing searched, so "Again" would be wrong on first
	-- use. Still a Blizzard global, so it stays localised.
	button:SetText(L.SEARCH)

	-- BLIZZARD'S "SEARCH AGAIN" AS ITS TOOLTIP, the one their camelot Browse
	-- tab's refresh button shows: LFG_LIST_SEARCH_AGAIN as a white title,
	-- anchored right (Mainline/Blizzard_LFGVanilla_Browse.xml:538-540). Set
	-- through the template's own tooltipText, which UIPanelButtonMixin:OnEnter
	-- shows exactly so (Mainline/SharedUIPanelTemplates.lua:225-238). Added in
	-- 0.19.0-dev.4 at the author's request; until then the button had none.
	-- Like Blizzard's, it does not show while the button is disabled: the
	-- client fires no OnEnter on a disabled button without motion scripts.
	button.tooltipText = L.SEARCH_AGAIN

	button:SetScript("OnClick", function()
		LFGF.PlayClick()
		panel:RequestSearch()
	end)

	return button
end

-- HOW LONG A SEARCH MAY GO UNANSWERED before the panel gives up on it.
-- Blizzard's Browse tab has no timeout: it waits for the two answer events
-- alone (Browse.lua:147-153, :317), so if neither ever came its button would
-- stay off for the session, and so would ours. Nobody has seen that happen.
-- 15 seconds is far beyond a normal answer (.claude/rules/list-result-updates.md,
-- Search timeout). A late answer is still drawn: both panels handle it
-- exactly as an answer on time.
local SEARCH_TIMEOUT_SECONDS = 15

--- Give up on the search in flight: Search works again, and the list hears it
--- as a failed search (LFGF.EVENT_SEARCH_TIMED_OUT).
local function SearchTimedOut(panel)
	panel.searchTimer = nil
	panel.searching = false
	panel:UpdateSearchState()
	EventRegistry:TriggerEvent(LFGF.EVENT_SEARCH_TIMED_OUT)
end

--- The Filters tab as a search should use it.
---
--- A MIN ABOVE THE MAX is lowered to the max first. Blizzard's level control
--- does that only when it is HIDDEN (LevelRangeFrameMixin:OnHide,
--- InputBoxTemplates.lua:395-397), so without this a player who typed 30 and
--- 20 would search with a range nothing can be in. Running Blizzard's own
--- FixLevelRange keeps the boxes showing exactly what was searched. The
--- Filters tab is the panel's (core/filterpanel.lua), so it is asked for its
--- snapshot.
local function SearchSnapshot(panel)
	panel.LevelRange:FixLevelRange()
	return panel:CurrentFilters()
end

--- Wait for the answer to a search that has gone out: the Search button's own
--- (RequestSearch), or Blizzard's search for the player's new listing
--- (FollowListing). One function, so the two waits cannot drift apart.
---
--- No game event fires when a search STARTS, only when it ends, so the list
--- panel would have nothing to hang a loading state on. Announced over
--- EventRegistry rather than by calling the list directly, so the two panels
--- stay as unaware of each other as the result events already leave them.
--- The role selection rides along as this event's PAYLOAD rather than
--- through a seam of its own. Sent only from a search, which is what makes
--- "the filter applies on Search" structural: the list panel has no other
--- way to learn a checkbox changed.
---
--- SAVED HERE, and only once a search is really going out -- after
--- RequestSearch's two early returns -- so what is saved is exactly what the
--- list is about to be filtered by. The next session restores it
--- (ApplyFilters).
local function AwaitResults(panel, filters)
	LFGF.SaveFilters(filters)
	EventRegistry:TriggerEvent(LFGF.EVENT_SEARCH_STARTED, filters)

	panel.searching = true
	panel:UpdateSearchState()
	-- A new wait can only start once `searching` is false: after an answer,
	-- which cancels the timer, or after the timer itself has fired. So there is
	-- never an older timer to stop here.
	panel.searchTimer = C_Timer.NewTimer(SEARCH_TIMEOUT_SECONDS, function()
		SearchTimedOut(panel)
	end)
end

--- Run the search.
---
--- The call and its constants are Blizzard's (Browse.lua:331-352): filter 0,
--- preferredFilters 0, no cross-faction, no advanced filter. The advancedFilter
--- slot is where role filtering would go (AdvancedFilterOptions,
--- LFGListInfoDocumentation.lua:836-856 -- needsTank, needsHealer, needsDamage,
--- needsMyClass); Blizzard's own camelot UI passes nil, so it is unexercised on
--- this client and left nil here too.
---
--- THE LANGUAGE FILTER is ours: Blizzard's camelot UI passes nil, which the
--- server answers with the player's own language only. The Languages dropdown
--- (core/filterpanel_miscellaneous.lua, LFGF.LanguageSearchFilter) sends nil
--- for that default too, and a set of languages otherwise.
---
--- Three things this has to get right, each with a spec:
---
---   1. NO ACTIVITIES TICKED MEANS SEARCH THEM ALL (Browse.lua:335-338). An
---      empty selection is not an empty search -- passing an empty activityIDs
---      list returns nothing and looks broken.
---
---   2. C_LFGList.Search is HasRestrictions = true
---      (LFGListInfoDocumentation.lua:574), and it is called with NO
---      restriction check: in the client it works in combat and in a dungeon
---      (the comment in the body says why the old check went).
---
---   3. Results are ASYNCHRONOUS. The button disables until
---      LFG_LIST_SEARCH_RESULTS_RECEIVED or LFG_LIST_SEARCH_FAILED arrives
---      (Browse.lua:317), or a player can stack requests -- or until
---      SEARCH_TIMEOUT_SECONDS pass with neither (above).
---
--- Results are NOT handed to the list panel directly. Both panels listen to the
--- same game events, so neither knows the other exists -- see core/listpanel.lua.
---
--- Answers true when the search went out, and false when it could not: a
--- search still running, or no category. Those are the two reasons the Search
--- button is greyed (UpdateSearchState), which is what keeps the Search key
--- (LFGF.SearchFromKey, core/window.lua) as silent as a click on that button.
local function RequestSearch(panel)
	if panel.searching then
		return false
	end

	local categoryID = panel.selectedCategoryID
	if categoryID <= 0 then
		return false
	end

	-- NO RESTRICTION PRE-CHECK, and that is deliberate. This used to refuse the
	-- search whenever any of the six Enum.AddOnRestrictionType members was
	-- active, and then lock the button for two seconds to say so. Tested in the
	-- client, the search works fine in combat and in a dungeon: the guard was
	-- only ever refusing work the client would have allowed.
	--
	-- IsAddOnRestrictionActive answers "is the player in this SITUATION", not
	-- "will this call be refused" -- every enum value documents a player state
	-- (RestrictedActionsConstantsDocumentation.lua:26-31), and Chat is about
	-- addon chat, not about searching. HasRestrictions = true says a function
	-- participates in the restriction system; WHICH states gate it is
	-- engine-side and is not in the sources.
	--
	-- Blizzard's whole UI references C_RestrictedActions exactly once, in its
	-- own documentation file, and their camelot Browse calls Search with no
	-- check at all (Browse.lua:345). The sanctioned shape is REACTIVE: call it,
	-- and if the engine refuses it fires ADDON_ACTION_BLOCKED naming the
	-- function (RestrictedActionsDocumentation.lua:74-84).
	--
	-- core/window.lua's InCombatLockdown check before Blizzard's side tabs
	-- open Blizzard's Group Finder (ShowUIPanel underneath) STAYS, and
	-- the difference is the point: that one is read off Blizzard's own Lua
	-- ("We no longer allow addons to show or hide UI panels in combat",
	-- UIParentPanelManager.lua:852), not inferred from a flag.

	local activityIDs = panel.selectedActivityIDs
	if #activityIDs == 0 then
		activityIDs = LFGF.Activities(categoryID)
	end

	-- THE SNAPSHOT COMES FIRST, so the languages the server is sent are the
	-- ones saved and handed to the list.
	local filters = SearchSnapshot(panel)

	C_LFGList.Search(categoryID, 0, 0, LFGF.LanguageSearchFilter(filters.languages), false, nil,
		activityIDs)

	AwaitResults(panel, filters)
	return true
end

--- After the player's own listing on Blizzard's Create Listing tab is
--- answered (core/blizzardlisting.lua, through LFGF.OpenForListing): set the
--- dropdowns to the listing and wait for the search Blizzard sends for it.
---
--- The dropdowns follow Blizzard's own rule for its Browse dropdowns
--- (LFGBrowseMixin:SetSelectedSearchActivities, Browse.lua:257-285): the first
--- listed activity the client describes picks the category, and that
--- category's listed activities are ticked, in the listing's order. A listing
--- holds one category's activities, so in practice that is all of them. When
--- no listed activity is described, the dropdowns are left as they were.
--- The menu offers every listed activity whatever the player's level
--- (LFGF.Activities keeps the player's own listing's).
---
--- IT SENDS NOTHING. Blizzard's own answer handler searches the listing
--- (Listing.lua:102-119 -> ParentFrame.lua:167-170 -> Browse.lua:233-245), and
--- a search of ours from here would be refused: this runs from an event, not
--- a click. So it waits for that search as for one of its own: the spinner,
--- Search greyed, the timeout, the boxes saved and handed to the list. Unless
--- a search is already being waited for: that one's answer, or Blizzard's,
--- ends it.
---
--- `activityIDs` is LfgEntryData.activityIDs, NeverSecret
--- (LFGListInfoDocumentation.lua:938), or nil.
local function FollowListing(panel, activityIDs)
	local categoryID, listed = 0, {}
	for _, activityID in ipairs(activityIDs or {}) do
		local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
		if activityInfo then
			if categoryID == 0 then
				categoryID = activityInfo.categoryID
			end
			if activityInfo.categoryID == categoryID then
				table.insert(listed, activityID)
			end
		end
	end

	if categoryID > 0 then
		-- SelectCategory clears the ticks and rebuilds both menus, as a pick
		-- from the category menu does.
		SelectCategory(panel, categoryID)
		for _, activityID in ipairs(listed) do
			if not ActivityIsSelected(panel, activityID) then
				ActivityToggle(panel, activityID)
			end
		end
	end

	if not panel.searching then
		AwaitResults(panel, SearchSnapshot(panel))
	end
end

-------------------------------------------------------
---------- The row
-------------------------------------------------------

--- Build the search row on `panel`: its state, its events, its methods
--- (the ones core/window.lua and core/filterpanel.lua call), the three
--- controls, and the first category. Returns the category dropdown
--- UNANCHORED, for the panel to place.
function LFGF.BuildSearchRow(panel)
	panel.selectedCategoryID = 0
	panel.selectedActivityIDs = {}
	panel.searching = false

	-- Both search-outcome events, because a failure has to release the button
	-- just as a success does -- otherwise one bad search disables refresh for
	-- the rest of the session.
	panel:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	panel:RegisterEvent("LFG_LIST_SEARCH_FAILED")
	-- The panel is built on the first /lfg, which can precede the LFG data
	-- arriving -- in which case there is no category to pick yet. This is the
	-- event Blizzard's own Browse panel watches for exactly that
	-- (Browse.lua:55, :145).
	panel:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
	panel:SetScript("OnEvent", function(self, event)
		if event == "LFG_LIST_AVAILABILITY_UPDATE" then
			SelectFirstCategory(self)
			-- The activity list may have changed: Blizzard's finder asks the
			-- server for a new one on every level-up
			-- (Blizzard_LFGVanilla_ParentFrame.lua:54-55). An open menu is
			-- rebuilt, or a click on a row it still shows would tick that
			-- activity again; GenerateMenu on an open dropdown rebuilds it in
			-- place (DropdownButton.lua:195-200).
			if self.selectedCategoryID > 0
				and DropUnofferedActivities(self, MenuActivities(self.selectedCategoryID))
				and self.ActivityDropdown:IsMenuOpen() then
				self.ActivityDropdown:GenerateMenu()
			end
			return
		end
		self.searching = false
		self:UpdateSearchState()
		if self.searchTimer then
			self.searchTimer:Cancel()
			self.searchTimer = nil
		end
	end)

	function panel:IsAnyActivitySelectedInGroup(activityGroupID)
		for _, activityID in ipairs(MenuActivities(self.selectedCategoryID, activityGroupID)) do
			if ActivityIsSelected(self, activityID) then
				return true
			end
		end
		return false
	end

	function panel:SetAllActivitiesInGroup(activityGroupID, selected)
		for _, activityID in ipairs(MenuActivities(self.selectedCategoryID, activityGroupID)) do
			if ActivityIsSelected(self, activityID) ~= selected then
				ActivityToggle(self, activityID)
			end
		end
	end

	--- Browse.lua:1242-1254: default text, the single activity's name, or a count.
	--- One difference: GetActivityInfoTable is MayReturnNothing
	--- (LFGListInfoDocumentation.lua:186) and LFGUtil_GetActivityInfoName
	--- indexes what it is handed (ParentFrame.lua:284), so a single activity
	--- the client no longer describes shows the count ("1 activity selected")
	--- instead of raising an error.
	function panel:UpdateActivityHeader()
		local selected = self.selectedActivityIDs
		local activityInfo = #selected == 1 and C_LFGList.GetActivityInfoTable(selected[1])
		if #selected == 0 then
			self.ActivityDropdown:OverrideText(L.ACTIVITY_HEADER_DEFAULT)
		elseif activityInfo then
			self.ActivityDropdown:OverrideText(LFGUtil_GetActivityInfoName(activityInfo))
		else
			self.ActivityDropdown:OverrideText(string.format(L.ACTIVITY_HEADER_FORMAT, #selected))
		end
	end

	function panel:SetupActivityMenu() LFGF.SetupActivityMenu(self) end

	--- Browse.lua:317 -- nothing to search without a category, and nothing to
	--- ask for while an answer is still coming. Those are the only two reasons,
	--- and there is no combat branch: see RequestSearch for why the restriction
	--- guard and the two-second refusal lock that hung off it were removed.
	function panel:UpdateSearchState()
		self.SearchButton:SetEnabled(self.selectedCategoryID > 0 and not self.searching)
	end

	function panel:RequestSearch() return RequestSearch(self) end

	--- The player's own listing was answered: show it and wait for Blizzard's
	--- search for it. See FollowListing.
	function panel:FollowListing(activityIDs) FollowListing(self, activityIDs) end

	--- The activities ticked in the activity dropdown RIGHT NOW, in the order
	--- they were ticked, as a fresh copy: nothing outside can change the
	--- selection through it. Not a search snapshot -- a tick counts before
	--- Search is clicked. core/window.lua hands this to both whispers
	--- (LFGF.SetActivityFilterSource, core/main.lua): the invite whisper names
	--- them when the player has no listing, and Ask to Join names the group's
	--- ticked ones. Deliberately NOT part of FilterSnapshot: that
	--- shape is what is saved and what My filters keep, and activities are
	--- neither (.claude/rules/saved-filters.md).
	function panel:SelectedActivityIDs() return CopyTable(self.selectedActivityIDs) end

	local category = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	category:SetWidth(CATEGORY_DROPDOWN_WIDTH)
	category:SetDefaultText(L.CATEGORY)
	panel.CategoryDropdown = category

	local activity = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	activity:SetWidth(ACTIVITY_DROPDOWN_WIDTH)
	activity:SetDefaultText(L.ACTIVITY_HEADER_DEFAULT)
	activity:SetPoint("LEFT", category, "RIGHT", CATEGORY_TO_ACTIVITY_GAP, 0)
	panel.ActivityDropdown = activity

	panel.SearchButton = BuildSearchButton(panel)
	panel.SearchButton:SetPoint("LEFT", activity, "RIGHT", ACTIVITY_TO_SEARCH_GAP, 0)

	SetupCategoryMenu(panel)
	panel:SetupActivityMenu()
	panel:UpdateActivityHeader()
	panel:UpdateSearchState()
	SelectFirstCategory(panel)

	-- The panel is the owner, so one panel registers once however often the
	-- setting changes -- the whisper log's pattern (core/whisperlog.lua).
	EventRegistry:RegisterCallback(LFGF.EVENT_LEVEL_RANGES_CHANGED, function()
		LevelRangesChanged(panel)
	end, panel)

	return category
end
