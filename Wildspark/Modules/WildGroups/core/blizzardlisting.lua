-- LFGForever -- core/blizzardlisting.lua
--
-- Blizzard's Create Listing tab hands over to WildGroups. When the player's
-- OWN click on its post button ("List Self", "List Group", "Update") is
-- answered with a listing, WildGroups opens on that listing's activities and
-- waits for the search Blizzard sends for it, and Blizzard's window closes, out
-- of combat. The author's decisions, the taint reasoning and the client checks:
-- .claude/rules/open-after-listing.md.
--
-- HOW, AND WHY THIS WAY
--
-- Blizzard's flow (Blizzard_LFGVanilla_Listing.lua): the button's OnClick
-- (:674-677) runs CreateOrUpdateListing (:264-328), which sets its upvalue
-- PENDING_LISTING_UPDATE and sends the listing. The server answers with
-- LFG_LIST_ACTIVE_ENTRY_UPDATE, and Blizzard's handler (:102-119), on
-- (created or pending) with an entry, calls LFGParentFrame_SearchActiveEntry
-- (ParentFrame.lua:167-170): its own window switches to Browse and searches the
-- listing. Then it clears the pending flag.
--
-- So this file does two things, and touches nothing else of Blizzard's:
--
--   * A script POST-hook on the button's OnClick, which runs after Blizzard's
--     handler has sent the listing and set its flag ("Securely post-hooks a
--     widget script handler", and the hook is "not spreading taint to
--     already-done execution", warcraft.wiki.gg, ScriptRegion:HookScript and
--     Secure Execution and Tainting). Nothing of Blizzard's runs after it in
--     that click. It only writes a local of this file.
--
--   * Its own event frame, for the server's answer. The game starts every
--     handler it calls secure ("When WoW begins executing Lua code, the
--     execution starts off 'secure'", the same wiki page), so ours cannot
--     taint Blizzard's handler for the same event, in either order.
--
-- NOT hooksecurefunc on LFGParentFrame_SearchActiveEntry, the obvious hook
-- point: Blizzard's handler keeps running after it returns and writes
-- PENDING_LISTING_UPDATE = false (:119), and "All Lua values and references can
-- be tainted - local variables, global variables, ..." (the same page). The
-- next answer reads that flag (:106) and would run Blizzard's own
-- C_LFGList.Search as WildGroups, to be refused. And no search of ours: this
-- runs from an event, not a click, so C_LFGList.Search would be refused too.
-- Blizzard's own search is the one waited for.
local _, root = ...
local LFGF = root.WildGroups

-- How long a click waits for the server's answer. If none comes, a later,
-- unrelated update of the listing (a member joining) must not open the window.
local ANSWER_TIMEOUT_SECONDS = 15

-- Whether the player clicked the post button and the server has not answered.
local awaiting = false
local answerTimer

local function StopAwaiting()
	awaiting = false
	if answerTimer then
		answerTimer:Cancel()
		answerTimer = nil
	end
end

--- The post-hook on Blizzard's post button: the click has sent a listing.
--- The button is enabled only while there is something to send
--- (UpdatePostButtonEnableState, Listing.lua:493-498), and the engine fires no
--- OnClick for a disabled button, so every click that reaches here sent one.
local function OnPostClicked()
	StopAwaiting()
	awaiting = true
	answerTimer = C_Timer.NewTimer(ANSWER_TIMEOUT_SECONDS, function()
		answerTimer = nil
		awaiting = false
	end)
end

-- The server's answer: LFG_LIST_ACTIVE_ENTRY_UPDATE, with or without its
-- `created` flag (LFGListInfoDocumentation.lua:694-703), after a create, an
-- update, a failure or a removal alike -- Blizzard's handler tells them apart
-- by whether an entry exists (:105-118), and so does this one. A failed
-- create may come as LFG_LIST_ENTRY_CREATION_FAILED (:754-759) instead. Any
-- answer ends the wait: only the first one after the click is the click's.
local events = CreateFrame("Frame")
events:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
events:RegisterEvent("LFG_LIST_ENTRY_CREATION_FAILED")
events:SetScript("OnEvent", function(_, event)
	if not awaiting then
		return
	end
	StopAwaiting()
	if event ~= "LFG_LIST_ACTIVE_ENTRY_UPDATE" or not C_LFGList.HasActiveEntryInfo() then
		return
	end

	-- activityIDs is NeverSecret (LFGListInfoDocumentation.lua:938), so it is
	-- read as it comes, as LFGF.Activities and the invite whisper read it.
	local entry = C_LFGList.GetActiveEntryInfo()
	LFGF.OpenForListing(entry and entry.activityIDs)
	-- Out of combat only; in combat both windows stay open, and stay open
	-- after it, by the author's decision.
	LFGF.CloseBlizzardGroupFinder()
end)

-- Blizzard_GroupFinder_VanillaStyle is LoadOnDemand, so the button does not
-- exist until it loads; ContinueOnAddOnLoaded runs at once when it already has,
-- and once otherwise (EventUtil.lua:67-75). The name is written out for
-- groupfinder_check.py, which recognises this guard textually. The button is
-- LFGListingFrame's parentKey PostButton (Mainline/Blizzard_LFGVanilla_
-- Listing.xml:319-327).
EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
	local listing = _G.LFGListingFrame
	local button = listing and listing.PostButton
	if button then
		button:HookScript("OnClick", OnPostClicked)
	end
end)
