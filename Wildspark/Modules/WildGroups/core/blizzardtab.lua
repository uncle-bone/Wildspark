-- LFGForever -- core/blizzardtab.lua
--
-- A fourth tab on Blizzard's Group Finder that opens this addon's window.
--
-- WHY THIS IS A LAUNCHER AND NOT A FOURTH PANEL
-- ---------------------------------------------
-- The tempting design is to swap Blizzard's three panels out for ours inside
-- their window. This file deliberately does not, because of taint.
--
-- Blizzard_GroupFinder_VanillaStyle carries `## Secure: 1` (its .toc:5) and is
-- the ONLY Blizzard addon in the whole source tree that does. That matters
-- because five C_LFGList getters -- GetActiveEntryInfo, GetApplicantInfo,
-- GetSearchResultInfo, GetSearchResultLeaderInfo, GetSearchResultPlayerInfo --
-- are SecretArguments = "AllowedWhenUntainted". Blizzard's own code reads and
-- FORMATS those secret fields, e.g.
--
--     string.format(LFG_LIST_COMMENT_FORMAT, searchResultInfo.comment)
--                          -- Blizzard_LFGVanilla_Browse.lua:679-680
--
-- which is legal only because that code is untainted. Showing or hiding their
-- panels runs their OnShow inside OUR call stack -- LFGBrowseMixin:OnShow calls
-- UpdateResultList (Browse.lua:169-171) and LFGListingMixin:OnShow calls
-- LoadActiveEntry (Listing.lua:142+), both of which reach that data. The
-- failure mode there is not our tab breaking; it is BLIZZARD'S Group Finder
-- breaking, in code we never wrote.
--
-- So this file attaches a tab, and does exactly one thing to Blizzard's window:
-- when the tab is clicked out of combat, it closes it (CloseBlizzardGroupFinder
-- below, which says why that one call is safe). It never shows or reads a
-- Blizzard LFG panel, never writes LFGParentFrame.selectedTab, and hooks no
-- Blizzard function. Specs assert each of those as a property.
local _, root = ...
local LFGF = root.WildGroups

local TAB_NAME = "WildSparkWildGroupsBlizzardTab"

-- The icon comes from core/window.lua (LFGF.ICON_ATLAS), shared so the tab and
-- the window it opens read as one feature and cannot drift apart. It must not be
-- one of Blizzard's three --
--   Listing  Interface\ICONS\INV_SideTab_GroupFinder_c60   (ParentFrame.xml:97)
--   Browse   Interface\ICONS\INV_SideTab_GroupBrowsing_c60 (:106)
--   Who List Interface\ICONS\INV_SideTab_WhoList_c60       (:116)
-- -- an earlier version used what was then the Browse icon
-- (Achievement_General_StayClassy), putting two of the same picture in a
-- four-tab strip.
local TAB_TOOLTIP = LFGF.TITLE

local tab

local function BuildTab()
	if not LFGF.IsEnabled() then return nil end
	local parent = _G.LFGParentFrame

	-- LargeSideTabButtonTemplate (SharedUIPanelTemplates.xml:1008-1068) is what
	-- Blizzard's own LFGVanillaRightTabTemplate inherits (ParentFrame.xml:21).
	-- It lives in Blizzard_SharedXML and loads unconditionally, so unlike the
	-- LFG* templates it is safe to inherit without the addon being loaded --
	-- though we are inside the load callback anyway, since we need the parent.
	--
	-- It is a Frame, not a Button, and is entirely self-wiring: the template
	-- declares OnLoad/OnMouseDown/OnMouseUp/OnEnter/OnLeave against
	-- SidePanelTabButtonMixin, so all we supply is an icon and a handler.
	local t = _G.CreateFrame("Frame", TAB_NAME, parent, "LargeSideTabButtonTemplate")
	t:SetID(4)

	-- Transcribed from LFGParentFrameRightTabMixin:OnLoad
	-- (Blizzard_LFGVanilla_ParentFrame.lua:101-112) so the icon is inset and
	-- cropped exactly as the other three.
	-- SetAtlas, then SetSize to the 30x30 the other three are forced to
	-- (LFGParentFrameRightTabMixin:OnLoad, ParentFrame.lua:101-112). No
	-- SetTexCoord here: Blizzard's three need it to crop the border off a square
	-- ICONS file, whereas SetAtlas sets the coords from the atlas itself and a
	-- later SetTexCoord would overwrite them with the wrong region.
	t.Icon:SetAtlas(LFGF.ICON_ATLAS)
	t.Icon:SetSize(30, 30)
	t:SetFillToInterior(true)

	-- Continue Blizzard's run of side tabs: each is anchored TOPLEFT to the
	-- previous one's BOTTOMLEFT at y = -2 (ParentFrame.xml:109, :119).
	t:SetPoint("TOPLEFT", parent.WhoListingTab, "BOTTOMLEFT", 0, -2)

	-- Never drawn as selected. Blizzard's three tabs keep owning selection; this
	-- one is a launcher, and looking selected would be a lie.
	t:SetChecked(false)

	t.tooltipText = TAB_TOOLTIP

	-- SetCustomOnMouseUpHandler is the mixin's own extension point
	-- (SharedUIPanelTemplates.lua:373-375), invoked from its OnMouseUp after the
	-- press animation and click sound (:361-371). Using it rather than
	-- SetScript("OnMouseUp") keeps both.
	t:SetCustomOnMouseUpHandler(function(_, button, upInside)
    if button == "LeftButton" and upInside then
        if not LFGF.IsEnabled() then return end
        if InCombatLockdown() then
            LFGF.Print("Open WildGroups after leaving combat.")
            return
        end
        LFGF.OpenWindow()
    end
end)
	return t
end

-- Blizzard_GroupFinder_VanillaStyle is LoadOnDemand (its .toc:6), pulled in from
-- Blizzard_LFGUtil/Camelot/LFGUtil.lua:1-13 when the finder is enabled, so at
-- login none of its frames exist and everything here has to wait.
--
-- ContinueOnAddOnLoaded fires immediately when it is already in -- the usual
-- case, since it arrives at PLAYER_ENTERING_WORLD, typically before addons
-- finish loading. Otherwise it waits for that one ADDON_LOADED and unregisters
-- itself (EventUtil.lua:67-75, :87-102). This is a stronger guard than an
-- IsAddOnLoaded branch: the body cannot run before the addon is in, so there is
-- no path on which LFGParentFrame is nil.
--
-- The addon name is written out rather than held in a local, because
-- groupfinder_check.py recognises this guard textually and cannot resolve a
-- constant through to the call.
EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
	LFGF.UpdateBlizzardTab()
end)

function LFGF.UpdateBlizzardTab()
	if not LFGF.IsEnabled() then
		if tab then tab:Hide() end
		return
	end
	if not tab and _G.LFGParentFrame and _G.LFGParentFrame.WhoListingTab then
		tab = BuildTab()
	end
	if tab then tab:Show() end
end
