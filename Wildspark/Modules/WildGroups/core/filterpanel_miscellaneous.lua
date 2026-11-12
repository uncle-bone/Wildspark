-- LFGForever -- core/filterpanel_miscellaneous.lua
--
-- The filter panel's fourth section, MISCELLANEOUS: a home for filters that
-- fit none of the other three (groups by role, players by role and level,
-- players by class). Added in 0.22.0-dev.1.
--
-- A FACTORY, like the panel itself: LFGF.BuildMiscellaneousSection builds the
-- section and returns it UNANCHORED. core/filterpanel.lua stacks it under the
-- class section and registers it with the Filters tab, so where it sits and
-- which tab owns it stay in the one place the whole stack can be read.
--
-- A PLAIN SECTION, the same title, rule and grid as the other three, built from
-- core/filterpanel_shared.lua. Blizzard puts a loose set of options under a
-- plain MISCELLANEOUS heading the same way in its combat-log settings
-- (Mainline/ChatConfigFrame.xml:724-755, ChatConfigFrame.lua:797).
--
-- ONE ROW, two filters, each a label and a multi-select dropdown: Playstyle
-- from the left, Languages flush right. The window's default height
-- (core/window.lua) counts this section and its one row.
-- .claude/rules/filter-miscellaneous-section.md, .claude/rules/playstyle-filter.md,
-- .claude/rules/language-filter.md
local _, root = ...
local LFGF = root.WildGroups
-- Every word this file shows, from core/locale.lua (loaded first).
local L = LFGF.L
-- The section builders, from core/filterpanel_shared.lua (loaded just before).
local Shared = LFGF.FilterShared

-- Blizzard's own word, MISCELLANEOUS (GlobalStrings/enUS.lua:14324), through
-- the locale table (core/locale.lua), which the settings page's Miscellaneous
-- section reads too, so both language packs already translate it. Published
-- like the other section titles, so a spec can name the same string.
LFGF.MISCELLANEOUS_SECTION_TITLE = L.MISCELLANEOUS

-- What LFGForeverDB.collapsedFilterSections saves when the section is
-- collapsed (core/filterpanel_shared.lua, BuildHeader).
local COLLAPSE_KEY = "miscellaneous"

-- How many grid rows the section reserves.
local ROW_COUNT = 1

-------------------------------------------------------
---------- The Playstyle filter
-------------------------------------------------------
-- A "Playstyle" label, then a dropdown of the four playstyles a listing can
-- carry, each a checkbox, all ticked by default. The list panel narrows
-- players and groups by it (core/listpanel.lua, MatchesPlaystyleFilter).
-- ONLY SEARCH SEARCHES, as with every filter: a tick changes the dropdown and
-- nothing else until Search takes the snapshot.

-- The label, Blizzard's GROUP_FINDER_FILTER_PLAYSTYLE through the locale
-- table. Published for MeasureLayout (core/filterpanel.lua) and the specs.
LFGF.PLAYSTYLE_ROW_LABEL = L.PLAYSTYLE_ROW_LABEL

-- Blizzard's own camelot playstyle dropdown, on its Listing tab, is 210 wide
-- (Mainline/Blizzard_LFGVanilla_Listing.xml:558-559). In English the longest
-- text this one shows, "Carry Offered", fits with room to spare; a longer
-- translation is cut off, and Blizzard's dropdown then shows the whole text as
-- a tooltip (DropdownSelectionTextMixin:ShouldShowTooltip, MenuTemplates.lua).
-- Published for MeasureLayout.
LFGF.PLAYSTYLE_DROPDOWN_WIDTH = 210

-- Each checkbox's data is the playstyle's enum value, as Blizzard's own
-- playstyle menu hands its radios (Blizzard_LFGVanilla_Listing.lua:945-948);
-- the selection is kept by the saved key (LFGF.PLAYSTYLES, core/main.lua).
local KEY_BY_VALUE = {}
for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
	KEY_BY_VALUE[playstyle.value] = playstyle.key
end

--- How many playstyles are ticked, and the last one found.
local function CountTicked(selected)
	local ticked, last = 0, nil
	for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
		if selected[playstyle.key] then
			ticked, last = ticked + 1, playstyle
		end
	end
	return ticked, last
end

--- The dropdown's text, by the author's rule: All when every playstyle is
--- ticked AND when none is (both filter nothing, LFGListAdvancedFilters in
--- Blizzard's retail finder reads them the same way, LFGList.lua:2470), the
--- name when one is, and the count ("2 selected") otherwise.
---
--- SET WITH OverrideText, from our own state, as the camelot Browse activity
--- dropdown does (LFGBrowseActivityDropdownMixin:UpdateHeader, Browse.lua
--- :1198-1209) and this panel's activity dropdown does. Blizzard's selection
--- text (DropdownSelectionTextMixin:UpdateToMenuSelections, MenuTemplates.lua
--- :813-848) would join the ticked names, and it updates only on a menu click,
--- while this state also changes from outside the menu: Reset filters, My
--- filters, the restore at build, Defaults. OverrideText turns selection text
--- off for good (:804-811), which is what is wanted here.
local function UpdateText(section)
	local ticked, only = CountTicked(section.selectedPlaystyles)
	local text
	if ticked == 0 or ticked == #LFGF.PLAYSTYLES then
		text = L.PLAYSTYLE_ALL
	elseif ticked == 1 then
		text = GetGeneralPlaystyleString(only.value)
	else
		text = L.PLAYSTYLES_SELECTED_FORMAT:format(ticked)
	end
	section.PlaystyleDropdown:OverrideText(text)
end

--- The menu: the four playstyles, as checkboxes, in Blizzard's order, named
--- with Blizzard's own words (GetGeneralPlaystyleString, Blizzard_LFGUtil/
--- Mainline/LFGUtil.lua:315, loaded at startup), and nothing else -- no Select
--- all / Unselect all, by the author's decision.
---
--- A TICK KEEPS THE MENU OPEN: a checkbox's description carries
--- MenuResponse.Refresh by default (MenuTemplates.CreateCheckbox,
--- MenuTemplates.lua:369-382), and SetSelected answers nothing to override it.
--- Unticking the last one leaves none ticked: the boxes show that, and the
--- text says All (the author's choice over re-ticking all four).
local function SetupMenu(section)
	local function IsSelected(value)
		return section.selectedPlaystyles[KEY_BY_VALUE[value]] == true
	end
	local function SetSelected(value)
		local key = KEY_BY_VALUE[value]
		section.selectedPlaystyles[key] = not section.selectedPlaystyles[key]
		UpdateText(section)
	end

	section.PlaystyleDropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetTag("MENU_LFGF_PLAYSTYLE")
		for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
			rootDescription:CreateCheckbox(GetGeneralPlaystyleString(playstyle.value),
				IsSelected, SetSelected, playstyle.value)
		end
	end)
end

--- The Playstyle row: the label on the row's centre at the grid's label
--- inset, where the Level row's sits on its own row, and the dropdown the
--- Level row's gap after it. Both children of the section's content, so the
--- tab system and collapsing hide them with it.
local function BuildPlaystyleRow(panel, section)
	local x, rowTop = Shared.GridCell(1, 1, 0)

	local label = section.Content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetText(LFGF.PLAYSTYLE_ROW_LABEL)
	label:SetPoint("LEFT", section.Content, "TOPLEFT", x + Shared.ROW_LABEL_INSET_X,
		rowTop - Shared.ROLE_ROW_HEIGHT / 2)

	local dropdown = CreateFrame("DropdownButton", nil, section.Content, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(LFGF.PLAYSTYLE_DROPDOWN_WIDTH)
	dropdown:SetPoint("LEFT", label, "RIGHT", Shared.ROW_LABEL_TO_CONTROL_GAP, 0)

	section.PlaystyleLabel = label
	section.PlaystyleDropdown = dropdown
	panel.PlaystyleLabel = label
	panel.PlaystyleDropdown = dropdown

	-- Every playstyle ticked: "show everyone", the start for a filter nobody
	-- has touched.
	section.selectedPlaystyles = {}
	for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
		section.selectedPlaystyles[playstyle.key] = true
	end

	--- What the dropdown says right now, as a fresh table with every
	--- playstyle named: FilterSnapshot's `playstyles` (core/filterpanel.lua).
	function section:GetPlaystyles()
		local playstyles = {}
		for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
			playstyles[playstyle.key] = self.selectedPlaystyles[playstyle.key] == true
		end
		return playstyles
	end

	--- Put the dropdown into the state `playstyles` describes, or the defaults
	--- for nil: ApplyFilters (the restore at build, Reset filters, My filters,
	--- Defaults). A playstyle the record does not name, or names with anything
	--- but a boolean, takes its default, ticked -- so a record from before the
	--- filter existed ticks all four.
	function section:SetPlaystyles(playstyles)
		for _, playstyle in ipairs(LFGF.PLAYSTYLES) do
			local value = playstyles and playstyles[playstyle.key]
			if type(value) == "boolean" then
				self.selectedPlaystyles[playstyle.key] = value
			else
				self.selectedPlaystyles[playstyle.key] = true
			end
		end
		UpdateText(self)
	end

	SetupMenu(section)
	UpdateText(section)
end

--- Whether the Playstyle dropdown narrows nothing: every playstyle ticked, or
--- none. Anything else still filters.
local function PlaystylesAtDefaults(section)
	local ticked = CountTicked(section.selectedPlaystyles)
	return ticked == 0 or ticked == #LFGF.PLAYSTYLES
end

-------------------------------------------------------
---------- The Languages filter
-------------------------------------------------------
-- A "Languages" label, then a dropdown of the languages the game offers for a
-- Group Finder search, flush right on the Playstyle row. Your game's language
-- is always ticked and cannot be unticked; at first it is the only one.
--
-- IT WORKS ON THE SERVER, unlike every other filter: a result carries no
-- language (LfgSearchResultData, LFGListInfoDocumentation.lua:978-1014), so
-- the choice goes into C_LFGList.Search (core/filterpanel.lua, RequestSearch)
-- and the list panel never sees it. Tested in the client: no language filter
-- returns your own language only, and any language set returns those
-- languages and your own (.claude/rules/language-filter.md). Hence the locked
-- row, and hence the default, which is the search the addon always sent.
--
-- Blizzard's camelot finder offers no such choice. The four C_LFGList calls
-- are in the client but undocumented; their shapes, and the locked rows, are
-- the retail finder's language menu (Blizzard_GroupFinder/Mainline/LFGList.lua
-- :2691-2709). Its US-region rule (:2421-2423) is not copied: the region name
-- is empty on Forever, and the choice is offered everywhere.
--
-- READ AT EVERY USE, NEVER CACHED: nothing says the offered list is there when
-- the panel is built, so the dropdown checks again whenever it is shown.

-- The label, Blizzard's LANGUAGES_LABEL (its retail menu's, LFGList.lua:2686)
-- through the locale table. Published for MeasureLayout and the specs.
LFGF.LANGUAGES_ROW_LABEL = L.LANGUAGES_ROW_LABEL

-- The same size as the Playstyle dropdown. Published for MeasureLayout.
LFGF.LANGUAGES_DROPDOWN_WIDTH = LFGF.PLAYSTYLE_DROPDOWN_WIDTH

--- The locale codes the game offers, in its own order: strings only, each
--- once, and none when it answers anything but a table.
local function OfferedLanguages()
	local offered, seen = {}, {}
	local answer = C_LFGList.GetAvailableLanguageSearchFilter()
	if type(answer) ~= "table" then
		return offered
	end
	for _, code in ipairs(answer) do
		if type(code) == "string" and not seen[code] then
			seen[code] = true
			table.insert(offered, code)
		end
	end
	return offered
end

--- The offered codes the game locks, as a set: what
--- GetDefaultLanguageSearchFilter marks, as Blizzard's menu reads it
--- (`if defaults[lang]`, LFGList.lua:2708).
local function LockedLanguages(offered)
	local locked = {}
	local defaults = C_LFGList.GetDefaultLanguageSearchFilter()
	if type(defaults) ~= "table" then
		return locked
	end
	for _, code in ipairs(offered) do
		if defaults[code] then
			locked[code] = true
		end
	end
	return locked
end

--- A choice exists when some offered language is not locked: the half of
--- Blizzard's LFGListCanChangeLanguages kept here (LFGList.lua:2425-2435).
local function CanChooseLanguages(offered, locked)
	for _, code in ipairs(offered) do
		if not locked[code] then
			return true
		end
	end
	return false
end

--- A language's name: its locale key (core/locale.lua), which defaults to
--- Blizzard's own string, or the code for one the addon has no key for.
local function LanguageName(code)
	return L["LANGUAGE_NAME_" .. string.upper(code)] or code
end

--- Whether `code` is ticked. A locked language always is.
local function IsLanguageTicked(section, code, locked)
	return locked[code] == true or section.selectedLanguages[code] == true
end

--- The menu's order: the locked languages first, then the rest by the name
--- shown, compared the way Blizzard's camelot Who List sorts its class and
--- race checkboxes (strcmputf8i, WhoList.lua:348-350).
local function MenuOrder(offered, locked)
	local function ByName(a, b)
		return strcmputf8i(LanguageName(a), LanguageName(b)) < 0
	end
	local first, rest = {}, {}
	for _, code in ipairs(offered) do
		table.insert(locked[code] and first or rest, code)
	end
	table.sort(first, ByName)
	table.sort(rest, ByName)
	for _, code in ipairs(rest) do
		table.insert(first, code)
	end
	return first
end

--- The greyed-out dropdown's tooltip, in the addon's usual shape (a white
--- title and a gold line, as LFGF.ShowTooltip draws them). Handed to the
--- dropdown's own SetTooltip, which shows it on enter
--- (DropdownSelectionTextMixin, MenuTemplates.lua:875-897).
local function UnavailableTooltip(tooltip)
	GameTooltip_SetTitle(tooltip, L.LANGUAGES_ROW_LABEL)
	GameTooltip_AddNormalLine(tooltip, L.LANGUAGES_UNAVAILABLE_TOOLTIP)
end

--- Bring the dropdown in line with the game and the selection: enabled with a
--- choice, greyed out with its tooltip without one, and the text by the
--- author's rule (Playstyle's), taking the first that applies:
---   * one language ticked (the default: yours): its name;
---   * every offered language ticked: ALL;
---   * nothing ticked, which needs nothing offered: ALL, there being no name;
---   * otherwise the count ("2 selected").
--- With no choice every offered language is locked, so the same rule names
--- yours.
---
--- THE TOOLTIP IS CLEARED WITH A CHOICE: while one is set, the dropdown shows
--- it on every hover, in place of Blizzard's truncated-text tooltip.
local function UpdateLanguages(section)
	local offered = OfferedLanguages()
	local locked = LockedLanguages(offered)
	local dropdown = section.LanguagesDropdown

	local canChoose = CanChooseLanguages(offered, locked)
	dropdown:SetEnabled(canChoose)
	dropdown:SetTooltip(not canChoose and UnavailableTooltip or nil)

	local ticked, only = 0, nil
	for _, code in ipairs(offered) do
		if IsLanguageTicked(section, code, locked) then
			ticked, only = ticked + 1, code
		end
	end
	local text
	if ticked == 1 then
		text = LanguageName(only)
	elseif ticked == #offered or ticked == 0 then
		text = L.LANGUAGES_ALL
	else
		text = L.LANGUAGES_SELECTED_FORMAT:format(ticked)
	end
	dropdown:OverrideText(text)
end

--- The menu: Select all and Unselect all first, where Blizzard's camelot Who
--- List puts its bulk buttons (WhoList.lua:337-338), each answering Refresh so
--- the menu stays open (:357-368); then one checkbox per offered language, in
--- MenuOrder. The words are the class filter's links' (core/filterpanel.lua),
--- so the panel says it one way. Unselect all leaves a locked language ticked.
---
--- A LOCKED ROW is Blizzard's own: disabled, so it cannot be clicked, and
--- still ticked (LFGList.lua:2696, :2708-2710). A disabled menu row still
--- takes the mouse's motion (MenuTemplates.lua:193), so its tooltip says why
--- (SetTitleAndTextTooltip, MenuUtil.lua:306-315).
---
--- Regenerated on every open, so it always reads what the game offers now.
local function SetupLanguagesMenu(section)
	section.LanguagesDropdown:SetupMenu(function(_, rootDescription)
		rootDescription:SetTag("MENU_LFGF_LANGUAGES")
		local offered = OfferedLanguages()
		local locked = LockedLanguages(offered)

		-- Unselect all cannot untick a locked language: it reads as ticked
		-- whatever is stored for it (IsLanguageTicked).
		local function SetAll(ticked)
			for _, code in ipairs(offered) do
				section.selectedLanguages[code] = ticked
			end
			UpdateLanguages(section)
			return MenuResponse.Refresh
		end
		local function IsSelected(code)
			return IsLanguageTicked(section, code, locked)
		end
		local function SetSelected(code)
			if locked[code] then
				return
			end
			section.selectedLanguages[code] = not section.selectedLanguages[code]
			UpdateLanguages(section)
		end

		rootDescription:CreateButton(L.SELECT_ALL, SetAll, true)
		rootDescription:CreateButton(L.UNSELECT_ALL, SetAll, false)
		for _, code in ipairs(MenuOrder(offered, locked)) do
			local name = LanguageName(code)
			local checkbox = rootDescription:CreateCheckbox(name, IsSelected, SetSelected, code)
			if locked[code] then
				checkbox:SetEnabled(false)
				checkbox:SetTitleAndTextTooltip(name, L.LANGUAGE_LOCKED_TOOLTIP)
			end
		end
	end)
end

--- The Languages row: the dropdown flush right on the Playstyle row's centre,
--- the label the same gap before it. Both children of the section's content,
--- so the tab system and collapsing hide them with it.
local function BuildLanguagesRow(panel, section)
	local _, rowTop = Shared.GridCell(1, 1, 0)

	local dropdown = CreateFrame("DropdownButton", nil, section.Content, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(LFGF.LANGUAGES_DROPDOWN_WIDTH)
	dropdown:SetPoint("RIGHT", section.Content, "TOPRIGHT", 0, rowTop - Shared.ROLE_ROW_HEIGHT / 2)
	-- The template does not take the mouse's motion while disabled, and the
	-- greyed-out dropdown's tooltip needs it (as the Role Check button's does).
	dropdown:SetMotionScriptsWhileDisabled(true)
	-- The offered list may arrive after the panel is built: check again
	-- whenever the dropdown is shown (the window opening, the Filters tab).
	dropdown:HookScript("OnShow", function()
		UpdateLanguages(section)
	end)

	local label = section.Content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetText(LFGF.LANGUAGES_ROW_LABEL)
	label:SetPoint("RIGHT", dropdown, "LEFT", -Shared.ROW_LABEL_TO_CONTROL_GAP, 0)

	section.LanguagesLabel = label
	section.LanguagesDropdown = dropdown
	panel.LanguagesLabel = label
	panel.LanguagesDropdown = dropdown

	-- Nothing ticked beyond the locked languages: the search the addon always
	-- sent.
	section.selectedLanguages = {}

	--- What the dropdown says right now, as a fresh table naming every offered
	--- language: FilterSnapshot's `languages` (core/filterpanel.lua).
	function section:GetLanguages()
		local offered = OfferedLanguages()
		local locked = LockedLanguages(offered)
		local languages = {}
		for _, code in ipairs(offered) do
			languages[code] = IsLanguageTicked(self, code, locked)
		end
		return languages
	end

	--- Put the dropdown into the state `languages` describes, or the default
	--- for nil: ApplyFilters (the restore at build, Reset filters, My filters,
	--- Defaults). Only a language named with true is ticked, so a record from
	--- before the filter existed restores the default. A locked language stays
	--- ticked whatever the record says. A language this client does not offer
	--- is kept aside, out of every snapshot, until it is offered.
	function section:SetLanguages(languages)
		self.selectedLanguages = {}
		if type(languages) == "table" then
			for code, value in pairs(languages) do
				if type(code) == "string" and value == true then
					self.selectedLanguages[code] = true
				end
			end
		end
		UpdateLanguages(self)
	end

	SetupLanguagesMenu(section)
	UpdateLanguages(section)
end

--- Whether the Languages dropdown is at its default: nothing ticked beyond the
--- locked languages.
local function LanguagesAtDefaults(section)
	local offered = OfferedLanguages()
	local locked = LockedLanguages(offered)
	for _, code in ipairs(offered) do
		if not locked[code] and section.selectedLanguages[code] == true then
			return false
		end
	end
	return true
end

--- What C_LFGList.Search is handed as its language filter, from a snapshot's
--- `languages` (FilterSnapshot): nil when nothing beyond the locked languages
--- is ticked -- the search the addon always sent, which the server answers
--- with your own language -- and otherwise a new set of every ticked offered
--- language plus the locked ones, so ALL sends every offered language.
--- Sending the locked ones is belt and braces: the server adds yours anyway.
function LFGF.LanguageSearchFilter(languages)
	local offered = OfferedLanguages()
	local locked = LockedLanguages(offered)
	local filter, beyondLocked = {}, false
	for _, code in ipairs(offered) do
		if locked[code] then
			filter[code] = true
		elseif type(languages) == "table" and languages[code] == true then
			filter[code] = true
			beyondLocked = true
		end
	end
	if not beyondLocked then
		return nil
	end
	return filter
end

--- Build the Miscellaneous section for `panel`. Returns it unanchored.
function LFGF.BuildMiscellaneousSection(panel)
	local section = Shared.BuildSection(panel, LFGF.MISCELLANEOUS_SECTION_TITLE, COLLAPSE_KEY)
	Shared.SizeSection(section, ROW_COUNT)
	BuildPlaystyleRow(panel, section)
	BuildLanguagesRow(panel, section)

	--- For the collapsed section's warning (core/filterpanel_shared.lua,
	--- UpdateSectionWarning): both filters at their defaults.
	function section:IsAtDefaults()
		return PlaystylesAtDefaults(self) and LanguagesAtDefaults(self)
	end

	return section
end
