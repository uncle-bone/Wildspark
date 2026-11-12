-- LFGForever -- core/window.lua
--
-- The window /lfg opens, shaped after Blizzard's own Group Finder.
--
-- THE SHAPE IS NOT THE OBVIOUS ONE. LFGParentFrame carries no chrome at all: it
-- is a bare Frame holding a close button, a portrait and tabs
-- (Mainline/Blizzard_LFGVanilla_ParentFrame.xml:29-32). The visible border,
-- title bar and portrait ring come from whichever TAB PANEL is showing, and each
-- of those inherits PortraitFrameTemplateNoCloseButton with setAllPoints="true"
-- (Blizzard_LFGVanilla_Listing.xml:278, Browse.xml:378, WhoList.xml:89).
--
-- That two-layer split is reproduced here even though there is only one content
-- panel (the Filters / Whispers tabs live inside it, core/filterpanel.lua),
-- because it is what lets window-level tabs be added later by swapping the
-- panel instead of rebuilding the frame.
--
-- Templates used, each confirmed to load on camelot with
-- `element_check.py template <Name>`:
--   PortraitFrameTemplateNoCloseButton  SharedUIPanelTemplates.xml:656
--   UIPanelCloseButtonNoScripts         SharedUIPanelTemplates.xml (the art of
--                                       UIPanelCloseButton, :148, without its
--                                       OnClick)
--   PanelDragBarTemplate                SharedUIPanelTemplates.xml:1628
-- Deliberately NOT used: any LFG* template. They live inside the LoadOnDemand
-- Blizzard_GroupFinder_VanillaStyle, so CreateFrame against them errors until
-- that addon is pulled in.
local _, root = ...
local LFGF = root.WildGroups
-- Every word this file shows, from core/locale.lua (loaded first).
local L = LFGF.L

local FRAME_NAME = "WildSparkWildGroupsFrame"

-- 1165 x 620. The width is WeeklyRewardsFrame's (Blizzard_WeeklyRewards.xml),
-- picked as a real Blizzard panel of this size rather than an arbitrary
-- number. The height was Blizzard's LFGParentFrame height, 535
-- (ParentFrame.xml:30), until 0.22.0-dev.1 added the filter panel's fourth
-- section, Miscellaneous (core/filterpanel_miscellaneous.lua): 535 plus the
-- section's gap (20), title (~16), rule and gaps (16) and one 32-high row of
-- filters, 84, rounded up to 85 so the ~15 left under the last section stays.
-- The title's height is in no source, so the fit is confirmed in the client.
-- .claude/rules/filter-miscellaneous-section.md
--
-- It is also the SMALLEST the window gets: the player can make it bigger with
-- the grip in its bottom-right corner (BuildResizeButton below), never smaller.
-- The content panel is anchored with SetAllPoints rather than sized -- its rect
-- is DERIVED from the parent's -- so the chrome, the title and the close button
-- follow a resize with no other edit.
--
-- At this width the window no longer fits every screen, which is what the
-- fit on show (FitToScreen below) is for.
local WIDTH, HEIGHT = 1165, 620
-- Addon identity lives in core/main.lua, which the .toc loads first.
local TITLE = LFGF.TITLE

-- The addon's icon also lives in core/main.lua; both the window's portrait and
-- the tab on Blizzard's Group Finder read it from there.

-- NOT A UI PANEL. This window used to be registered with Blizzard's panel
-- manager (RegisterUIPanel, area "left"), and that registration cost three
-- things the player asked for:
--
--   * it could not be moved: on every panel show or hide the manager clears a
--     left-area panel's anchors and writes its own TOPLEFT
--     (UIParentPanelManager.lua:643-644), so a drag lost to the next panel;
--   * it could not be opened or closed in combat: ShowUIPanel and HideUIPanel
--     refuse addon code under InCombatLockdown (:852-861);
--   * it touched other windows: a left panel with allowOtherPanels = 0
--     replaces whatever holds the left slot (:387-404), and the centre-panel
--     alternative closes every panel and every UISpecialFrames window when it
--     opens (:288-292).
--
-- So it is a plain frame, as every addon window in examples/ is: Show() and
-- Hide(), Escape through UISpecialFrames, its own position. Blizzard's panels
-- open and close beside it and it never closes one of them. See
-- .claude/rules/groupfinder-window.md, "Why it is not a UI panel".

-- The extra room the fit leaves around the window: the panel manager's own
-- default checkFit buffers, CHECK_FIT_DEFAULT_EXTRA_WIDTH / _HEIGHT
-- (UIParentPanelManager.lua:29-30), so the window shrinks exactly where it did
-- while it was a checkFit panel.
local FIT_EXTRA_WIDTH, FIT_EXTRA_HEIGHT = 20, 20

-- THE SAVED POSITION is LFGForeverDB.windowX / windowY: the offset of the
-- window's CENTRE from the screen's (UIParent's) centre, in UIParent units.
-- Account-wide, like every other key in the table.
--
-- WITH NOTHING SAVED -- a first install, or after Reset -- the window is centred
-- across, with its TOP where Blizzard's Group Finder's top sits (the author's
-- choice: the screen centre sat too low). A left UI panel's top is the
-- manager's TOP_OFFSET, -116 below the top of the screen (UIPanelLayoutFrame.lua
-- :3), passed through ClampUIPanelY, which moves a tall panel up until its
-- bottom is 140 above the screen's bottom, but never above -10
-- (UIParentPanelManager.lua:641-644, :1007-1019). The window asks those same
-- globals about ITSELF (see DefaultTop), so it lands where LFGParentFrame would.
-- The literal is the fallback if they are ever missing.
local DEFAULT_TOP_OFFSET = -116

-- Frames are never garbage collected, so this is built once and reused.
local window

-- THE CONTENT SPLIT
-- -----------------
-- Two InsetFrameTemplate panels side by side: the group/player list on the
-- left, filters on the right.
--
-- The template is Blizzard's own words -- "the inner frame used for content by
-- many panels" (SharedUIPanelTemplates.xml:386) -- and contributes a tiled
-- marble background plus a nine-slice border (:389-402). Two of them with a
-- gutter between therefore read as two separate wells with no custom art at
-- all. TradeFrame does exactly this for its two item columns
-- (TradeFrame.xml:282-378, left x 4..166 and right x 175..338).
--
-- The ANCHORING is the Settings recipe (Blizzard_SettingsPanel.xml:58-70),
-- mirrored: there the fixed-width column is on the left and the flexible one
-- fills what is left; here the filters are the fixed column on the right.
--
-- What that buys: the list is given NO width. It is anchored to Content's left
-- edge and to the filter panel's left edge, and two opposite anchors fully
-- determine a rect (see .claude/context/patterns-ui.md). So the list absorbs
-- every width change the window ever makes, for free -- the same property that
-- made widening the window a one-constant edit.

-- The filter panel's own width lives in core/filterpanel.lua, because how much
-- room filters need is a question about filters. At the window's 1165 its 600
-- leaves ~546 for the list (1155 usable after the insets, minus 600, minus the
-- gutter below). A wider window keeps the filters at 600 and gives the list
-- everything else, by the author's decision.

-- The gap between the two insets. TradeFrame puts its two columns 9 apart
-- (TradeFrame.xml:342 x=4..166, :285 x=175..338).
local PANEL_GUTTER = 9

-- The content region inside a portrait-style frame, taken from
-- ButtonFrameTemplate's own $parentInset (SharedUIPanelTemplates.xml:713-718):
-- TOPLEFT (4, -60), BOTTOMRIGHT (-6, 26). Reusing Blizzard's numbers means the
-- split lines up with every other window of this shape instead of floating at
-- offsets invented here. -60 clears the title bar; 26 leaves a footer strip for
-- buttons later.
local INSET_LEFT, INSET_TOP = 4, -60
local INSET_RIGHT, INSET_BOTTOM = -6, 26

--- Place the two content columns. Each panel is BUILT by its own file --
--- core/listpanel.lua and core/filterpanel.lua -- which return it unanchored;
--- the arrangement is this file's job, so the whole layout reads in one place.
local function BuildContentPanels(content)
	-- Fixed column first: the flexible one is anchored to it.
	local filter = LFGF.CreateFilterPanel(content)
	filter:SetPoint("TOPRIGHT", content, "TOPRIGHT", INSET_RIGHT, INSET_TOP)
	filter:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
	content.FilterPanel = filter

	-- The list gets no width from anywhere -- see core/listpanel.lua. TOPLEFT
	-- against the content region and BOTTOMRIGHT against the filter panel's left
	-- edge is the whole layout.
	local list = LFGF.CreateListPanel(content)
	list:SetPoint("TOPLEFT", content, "TOPLEFT", INSET_LEFT, INSET_TOP)
	list:SetPoint("BOTTOMRIGHT", filter, "BOTTOMLEFT", -PANEL_GUTTER, 0)
	content.ListPanel = list

	-- The filter panel restored the saved Filters tab as it was built; the list
	-- starts filtered the same way, so the two agree before the first Search.
	-- Handed over HERE rather than over EventRegistry because the list does
	-- not exist yet while the filter panel is being built; the window already
	-- wires the two columns together, and neither panel learns of the other.
	-- Not a search: no spinner, no query. See .claude/rules/saved-filters.md.
	list:UseFilters(filter:CurrentFilters())

	-- The invite whisper names the activities ticked in the filter panel when
	-- the player has no listing (core/main.lua, InviteWhisperMessage). The
	-- list panel's invite button asks main.lua, and main.lua asks the filter
	-- panel through this, so the two panels still never learn of each other.
	-- Read at click time, so a tick counts before any Search.
	LFGF.SetInviteActivitySource(function() return filter:SelectedActivityIDs() end)
end

-- The side tab strip, mirroring Blizzard's own so a player can move between all
-- four views from whichever window is open. The first three are LINKS to
-- Blizzard's finder, not alternative states of this window.
--
-- Metadata transcribed from ParentFrame.xml:94-121: the icons are the
-- iconTexture KeyValues, the tooltips are the LFG_LIST_TAB_* globals
-- (GlobalStrings/enUS.lua:13678-13680), and `tab` is the index
-- LFGVanilla_ToggleFrame takes -- 1 Listing, 2 Browse, 3 Who List.
-- Each tooltip is Blizzard's own tab name by default (LFG_LIST_TAB_1..3,
-- through core/locale.lua), so it names the tab it opens in the client's words.
local function BuildSideTabs(frame)
	local own = CreateFrame("Frame", nil, frame, "LargeSideTabButtonTemplate")
	own:SetID(4)
	own.Icon:SetAtlas(LFGF.ICON_ATLAS)
	own.Icon:SetSize(30, 30)
	own:SetFillToInterior(true)
	own:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -60)
	own.tooltipText = TITLE
	own:SetChecked(true)
	frame.BetterTab = own
end

--- The saved centre offset, or nothing when there is no usable one.
--- DEFENSIVE, like every reader of LFGForeverDB: it is a file on disk, and a
--- string, a NaN or an infinity must not reach SetPoint (LFGF.IsFiniteNumber,
--- core/main.lua). Both values or neither -- half a position is not one.
local function SavedPosition()
	local x, y = LFGF.SavedValue("windowX"), LFGF.SavedValue("windowY")
	if LFGF.IsFiniteNumber(x) and LFGF.IsFiniteNumber(y) then
		return x, y
	end
	return nil
end

--- The window's scale, or 1 if it cannot be read. GetScale is
--- SecretReturnsForAspect Scale (SimpleFrameAPIDocumentation.lua:620); nothing
--- here gives the window a secret scale, but a secret would error in the
--- division below.
local function ReadableScale(frame)
	local scale = LFGF.ReadableNumbers(frame:GetScale())
	if scale == nil or scale <= 0 then
		return 1
	end
	return scale
end

--- Put the window's centre at (x, y) from the screen's centre, in UIParent
--- units. One anchor, replaced each time. SetPoint offsets are in the frame's
--- OWN scaled units, which is why they are divided by the scale -- what the
--- panel manager does with every placement (UIParentPanelManager.lua:644, :696).
local function Place(frame, x, y)
	local scale = ReadableScale(frame)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", x / scale, y / scale)
end

--- Where Blizzard's panel manager would put this window's top, from the top of
--- the screen, in UIParent units. GetUIPanelLayoutAttribute and ClampUIPanelY
--- are globals of the always-loaded Blizzard_UIParentPanelManager
--- (`element_check.py global` -> loads on camelot). On a frame that is not a
--- registered panel, GetUIPanelHeight -- which ClampUIPanelY calls -- falls back
--- to the frame's own height times its scale (UIParentPanelManager.lua:968-985),
--- so it measures this window as it is now, after the fit.
local function DefaultTop(frame)
	if not (GetUIPanelLayoutAttribute and ClampUIPanelY) then
		return DEFAULT_TOP_OFFSET
	end
	local top = LFGF.ReadableNumbers(
		ClampUIPanelY(frame, GetUIPanelLayoutAttribute("TOP_OFFSET") or DEFAULT_TOP_OFFSET))
	if type(top) ~= "number" then
		return DEFAULT_TOP_OFFSET
	end
	return top
end

--- Centred across, the top at DefaultTop. Divided by the scale for the same
--- reason as Place, and as the manager does (UIParentPanelManager.lua:644).
local function PlaceAtDefault(frame)
	local scale = ReadableScale(frame)
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOP", 0, DefaultTop(frame) / scale)
end

--- Where the window belongs now: the saved position, or the default.
local function Restore(frame)
	local x, y = SavedPosition()
	if x == nil then
		PlaceAtDefault(frame)
	else
		Place(frame, x, y)
	end
end

--- Where the window's centre is now, as an offset from the screen's centre in
--- UIParent units -- or nothing, if that cannot be read.
---
--- GetCenter is MayReturnNothing and SecretWhenAnchoringSecret
--- (SimpleScriptRegionAPIDocumentation.lua:145). Neither is expected for this
--- window, but either would error in the arithmetic, so every value is checked
--- (LFGF.ReadableNumbers) BEFORE anything else touches it.
local function CurrentPosition(frame)
	local centerX, centerY = frame:GetCenter()
	local parentX, parentY = UIParent:GetCenter()
	centerX, centerY, parentX, parentY = LFGF.ReadableNumbers(centerX, centerY, parentX, parentY)
	if centerX == nil then
		return nil
	end
	local scale = ReadableScale(frame)
	return centerX * scale - parentX, centerY * scale - parentY
end

--- After a drag: save where the window was dropped and take the anchor back.
---
--- The anchor StartMoving leaves behind is the client's choice, and the
--- sources do not say what it is; re-anchoring makes it ours again.
--- SetUserPlaced(false) keeps the client's own position cache out of it:
--- StartMoving marks the frame user-placed, and Blizzard clears the flag after
--- a drag "So that we don't save the position" (FloatingChatFrame.xml:680-682).
---
--- If the drop position cannot be read, nothing is saved and the window goes
--- back to the last saved position (or the default). The next readable drag
--- saves as usual.
local function SavePosition(frame)
	frame:SetUserPlaced(false)

	local x, y = CurrentPosition(frame)
	if x == nil then
		Restore(frame)
		return
	end
	LFGF.SaveValue("windowX", x)
	LFGF.SaveValue("windowY", y)
	Place(frame, x, y)
end

-- THE SAVED SIZE is LFGForeverDB.windowWidth / windowHeight, in the window's
-- own units (before the fit scales it), account-wide. Both values or neither:
-- a hand edit that leaves one, or anything that is not a finite number, is
-- unusable, and the window opens at the default size.
--
-- A USABLE VALUE BELOW ITS MINIMUM IS RAISED TO IT, and the other is kept
-- (0.22.0-dev.1, the author's decision). The default height grew from 535 to
-- 620 then, so a size 0.21.0 saved can be a real choice and still short of
-- the new minimum; throwing it away would lose the player's width too. The
-- saved values are left as they are until the next resize writes new ones.
local function SavedSize()
	local width, height = LFGF.SavedValue("windowWidth"), LFGF.SavedValue("windowHeight")
	if LFGF.IsFiniteNumber(width) and LFGF.IsFiniteNumber(height) then
		return math.max(width, WIDTH), math.max(height, HEIGHT)
	end
	return WIDTH, HEIGHT
end

--- The window's centre and size, in its own units, or nothing if any of them
--- cannot be read. GetCenter is MayReturnNothing, and both GetCenter and
--- GetSize are SecretWhenAnchoringSecret (SimpleScriptRegionAPIDocumentation
--- .lua:145, :276), so every value is checked before any arithmetic.
local function ReadableRect(frame)
	local centerX, centerY = frame:GetCenter()
	local width, height = frame:GetSize()
	return LFGF.ReadableNumbers(centerX, centerY, width, height)
end

--- Before a resize: pin the window's TOPLEFT where it is, so the corner under
--- the cursor is the one that moves and the top-left stays put, as Blizzard's
--- resizable windows do (the chat frames, the Damage Meter -- all anchored by
--- a corner). The resize grip calls this as the window's onResizeStartCallback
--- just before StartSizing (SharedUIPanelTemplates.lua:1693-1714); false stops
--- the resize from starting, which is the answer when the window cannot be
--- read. GetCenter and SetPoint offsets are in the same units, the window's
--- own, so the corner is the centre less half the size.
local function PinTopLeft(frame)
	local centerX, centerY, width, height = ReadableRect(frame)
	if centerX == nil then
		return false
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", centerX - width / 2, centerY + height / 2)
	return true
end

--- After a resize: save the new size, then the centre it moved to (the
--- top-left stayed, so the centre did not) with SavePosition, which also takes
--- the anchor back and keeps the client's layout cache out of it. If the size
--- cannot be read, the saved one is kept.
local function SaveSize(frame)
	local _, _, width, height = ReadableRect(frame)
	if width ~= nil then
		LFGF.SaveValue("windowWidth", width)
		LFGF.SaveValue("windowHeight", height)
	end
	SavePosition(frame)
end

--- Scale the window down if it would not fit the screen, then put it where it
--- was saved, or at the default. In that order: the saved offset is divided by
--- the scale, and the default's clamp measures the scaled height.
---
--- FrameUtil.UpdateScaleForFit is what the panel manager's checkFit calls
--- (FrameUtil.lua:162-179, via UIParentPanelManager.lua:245-246, :983-985):
--- SetScale(1), then the smaller of the two fit ratios if the window is too
--- big. `element_check.py global FrameUtil` -> Blizzard_SharedXMLBase, loads
--- on camelot.
local function FitAndPlace(frame)
	FrameUtil.UpdateScaleForFit(frame, FIT_EXTRA_WIDTH, FIT_EXTRA_HEIGHT)
	Restore(frame)
end

--- The title bar is the drag handle, and nothing else is: a drag that started
--- on a list row or a checkbox would fight the control under it.
---
--- PanelDragBarTemplate is Blizzard's own title-bar drag handle
--- (SharedUIPanelTemplates.xml:1628-1640, mixin at SharedUIPanelTemplates.lua
--- :1537-1633), used by ColorPickerFrame and EventTrace. It moves its parent
--- unless told otherwise, so Init points it at the outer window.
---
--- It covers TitleContainer, the portrait frame's own title strip -- x 58 to
--- -24, 20 tall (SharedUIPanelTemplates.xml:600-604) -- which stops short of
--- the portrait on the left and the close button on the right.
---
--- The save is a HookScript on OnDragStop, not the template's stop callback:
--- the callback runs BEFORE its StopMovingOrSizing (:1583-1605), while a hook
--- runs after the whole script, when the move has ended.
local function BuildDragBar(frame, content)
	local dragBar = CreateFrame("Button", nil, content, "PanelDragBarTemplate")
	dragBar:SetAllPoints(content.TitleContainer)
	dragBar:Init(frame)
	dragBar:HookScript("OnDragStop", function()
		SavePosition(frame)
	end)
	frame.DragBar = dragBar
end

-- REPORT A BUG, in the header: the strip under the title bar
-- (TopTileStreaks, y -21 down, SharedUIPanelTemplates.xml:634-640), at its
-- right end, above the filter panel. Blizzard's camelot Group Browser puts
-- its 16-high gear in the same strip, at TOPRIGHT (-12, -32)
-- (Blizzard_LFGVanilla_Browse.xml:593-596). Ours sits at the same height and
-- ends where LFG Forever's settings gear below it ends: the filter panel's
-- right edge (INSET_RIGHT) less its row padding. Below the title bar, so the
-- drag bar never takes its clicks; above the panels (INSET_TOP).
--
-- The icon is Blizzard's own bug, a FILE that only Blizzard's PTR issue
-- reporter uses (Blizzard_PTRFeedback_FrameTemplates.xml:11, OnlyBetaAndPTR),
-- so whether the live client ships it is a client check.
-- .claude/rules/report-bug-header.md
local REPORT_BUG_ICON_FILE = "Interface\\HelpFrame\\HelpIcon-Bug"
local REPORT_BUG_ICON_SIZE = 16
local REPORT_BUG_ICON_TO_TEXT_GAP = 2
local REPORT_BUG_HEIGHT = 16
local REPORT_BUG_TOP = -32

--- The header's Report a bug: one Button holding the icon and the words, sized
--- to both so the whole of it is clickable. The words are the button's own
--- font string, in LFGF.CreateRowLink's fonts, so the engine turns them white
--- on hover with no script -- as the filter sections' headers do
--- (BuildHeader, core/filterpanel_shared.lua). A left click opens the Report
--- a bug popup (core/main.lua), which plays its own sound; a Button answers
--- left clicks only by default. No combat check: the popup has none.
local function BuildReportBug(content)
	local button = CreateFrame("Button", nil, content)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(REPORT_BUG_ICON_FILE)
	icon:SetSize(REPORT_BUG_ICON_SIZE, REPORT_BUG_ICON_SIZE)
	icon:SetPoint("LEFT", button, "LEFT", 0, 0)
	button.Icon = icon

	local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	text:SetPoint("LEFT", icon, "RIGHT", REPORT_BUG_ICON_TO_TEXT_GAP, 0)
	button:SetFontString(text)
	button:SetNormalFontObject(GameFontNormalSmall)
	button:SetHighlightFontObject(GameFontHighlightSmall)
	button:SetText(L.REPORT_BUG)
	-- Measured after SetText: our own string, never secret.
	button:SetSize(REPORT_BUG_ICON_SIZE + REPORT_BUG_ICON_TO_TEXT_GAP + text:GetStringWidth(),
		REPORT_BUG_HEIGHT)
	button:SetPoint("TOPRIGHT", content, "TOPRIGHT",
		INSET_RIGHT - LFGF.FilterShared.ROW_PADDING, REPORT_BUG_TOP)

	button:SetScript("OnEnter", function(self)
		LFGF.ShowTooltip(self, L.SETTINGS_REPORT_BUG_LABEL, L.SETTINGS_REPORT_BUG_TOOLTIP)
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:SetScript("OnClick", function()
		LFGF.ShowReportBug()
	end)

	content.ReportBug = button
end

--- The resize grip: Blizzard's PanelResizeButtonTemplate
--- (Mainline/SharedUIPanelTemplates.xml:1642, mixin SharedUIPanelTemplates.lua
--- :1635-1778), the one Event Trace uses, at Event Trace's offsets
--- (Blizzard_EventTrace.xml:183-187), in the footer strip under the columns.
--- `element_check.py template PanelResizeButtonTemplate` -> loads on camelot.
---
--- Init(target, minWidth, minHeight): the minimums are required -- the mixin
--- compares against them unguarded -- and the maximums are left out, so there
--- is none. Init only holds the minimum while its own grip is held (it wraps
--- the target's OnSizeChanged); SetResizeBounds in BuildWindow gives the client
--- the same minimum.
---
--- The save is the stopped callback, which runs AFTER StopMovingOrSizing; the
--- target's onResizeStopCallback would run before it (:1699-1719).
---
--- No combat check: the window is a plain frame, like the drag bar's.
local function BuildResizeButton(frame, content)
	local grip = CreateFrame("Button", nil, content, "PanelResizeButtonTemplate")
	grip:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 4)
	grip:Init(frame, WIDTH, HEIGHT)
	grip:SetOnResizeStoppedCallback(SaveSize)
	frame.onResizeStartCallback = function()
		return PinTopLeft(frame)
	end
	frame.ResizeButton = grip
end

--- Keep the window on the screen, side tabs included, so it can never be
--- dragged or restored somewhere it cannot be dragged back from.
---
--- The tab strip hangs off the window's TOPRIGHT at x 0 (BuildSideTabs), so it
--- reaches one tab's width past the window's own rect. A POSITIVE right inset
--- pushes the clamp edge outwards: Blizzard's own uses show the convention --
--- GMChat's (-35, 0, 30, 0) takes in buttons on its left and top
--- (Blizzard_GMChatUI.lua:37), the console's (-10, 10, 10, -10) a margin all
--- round (Blizzard_Console_AutoComplete.xml:125). The tab's width is set by
--- its template's OnLoad, from its atlas (SharedUIPanelTemplates.lua:328-331).
local function ClampToScreen(frame)
	local tabWidth = LFGF.ReadableNumbers(frame.BetterTab:GetWidth()) or 0
	frame:SetClampedToScreen(true)
	frame:SetClampRectInsets(0, tabWidth, 0, 0)
end

local function BuildWindow()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent)
	frame:SetSize(SavedSize())
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	-- Resizable from its grip (BuildResizeButton), never below the default
	-- size and with no maximum. SetResizeBounds's maximums are optional
	-- (SimpleFrameAPIDocumentation.lua:1445-1456).
	frame:SetResizable(true)
	frame:SetResizeBounds(WIDTH, HEIGHT)
	-- Hidden BEFORE the OnShow/OnHide scripts are attached, so building the
	-- window does not play the close sound.
	frame:Hide()

	local content = CreateFrame("Frame", nil, frame, "PortraitFrameTemplateNoCloseButton")
	content:SetAllPoints(frame)
	content:SetTitle(TITLE)
	-- SetPortraitAtlasRaw, not SetPortraitToAsset: the icon is an atlas
	-- (PortraitFrame.lua:63-65 -> GetPortrait():SetAtlas).
	content:SetPortraitAtlasRaw(LFGF.ICON_ATLAS)
	frame.Content = content

	-- On the PARENT, not the content panel -- which is why the panel inherits the
	-- NoCloseButton variant. Blizzard's is on the parent too (ParentFrame.xml:39).
	--
	-- The NoScripts variant with our own OnClick. UIPanelCloseButton's OnClick
	-- is UIPanelCloseButton_OnClick, which calls HideUIPanel(parent)
	-- (SharedUIPanelTemplates.lua:152-164) -- and HideUIPanel runs its combat
	-- refusal BEFORE it checks whether the frame is a panel at all
	-- (UIParentPanelManager.lua:910-925). A plain Hide() is never refused.
	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)
	frame.CloseButton = closeButton

	-- The same two sounds Blizzard's finder plays (ParentFrame.lua:51, :59).
	frame:SetScript("OnShow", function(self)
		FitAndPlace(self)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		-- Ask for the guild roster, so the next search can mark guildmates.
		-- Blizzard only asks when a guild-related window opens; see
		-- LFGF.RequestGuildRoster in core/relations.lua. A request, not a
		-- listener: nothing here waits for the answer.
		LFGF.RequestGuildRoster()
		-- The player's talent points per tree, for the active spec
		-- (core/talents.lua). Read on every open; nothing listens for changes.
		LFGF.LoadTalentPoints()
	end)
	frame:SetScript("OnHide", function()
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
	end)

	BuildContentPanels(content)
	BuildSideTabs(frame)
	BuildDragBar(frame, content)
	BuildReportBug(content)
	BuildResizeButton(frame, content)
	ClampToScreen(frame)

	-- Escape closes it: CloseAllWindows, Blizzard's Escape handler, ends in
	-- CloseSpecialWindows, which hides every shown frame named here
	-- (UIParentPanelManager.lua:1106-1116, :1168, :1190). Added once, because
	-- the window is built once.
	tinsert(UISpecialFrames, FRAME_NAME)

	return frame
end

--- Build the window if it does not exist yet. Shared by the two entry points
--- below so the lazy build cannot drift apart. No combat check: a plain
--- frame's Show and Hide are not refused in combat.
local function Prepare()
	window = window or BuildWindow()
	return window
end

--- Forget the saved position and size, and put the window back at its default
--- size, scale and place if it exists -- open or closed, in combat or not (a
--- plain frame's SetSize and SetPoint are not refused). The fit runs again
--- because a big saved size may have scaled the window down. A window not
--- built yet needs nothing more: it opens that way. Called by the settings
--- page's Reset button and on Blizzard's Defaults (core/settings.lua).
function LFGF.ResetWindowPosition()
	LFGF.SaveValue("windowX", nil)
	LFGF.SaveValue("windowY", nil)
	LFGF.SaveValue("windowWidth", nil)
	LFGF.SaveValue("windowHeight", nil)
	if window then
		window:SetSize(WIDTH, HEIGHT)
		FitAndPlace(window)
	end
end

--- Toggle the window. Used by /lfg, the minimap button and the addon
--- compartment.
function LFGF.ToggleWindow()
	if not LFGF.IsEnabled() then return end
	local frame = Prepare()
	frame:SetShown(not frame:IsShown())
end

--- Open the window, never close it. Used by the tab on Blizzard's Group Finder
--- (core/blizzardtab.lua): a launcher means "show me that window". Blizzard's
--- Group Finder stays open beside it -- this window touches no other window.
function LFGF.OpenWindow()
	if not LFGF.IsEnabled() then return end
	Prepare():Show()
end

function LFGF.CloseWindow()
	if window then window:Hide() end
end
