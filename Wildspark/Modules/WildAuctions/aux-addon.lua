select(2, ...).WildAuctions 'aux'
_G.WildAuctions = _G.WildAuctions or {}
_G.WildAuctions.M = M

local post = require 'aux.tabs.post'
local gui = require 'aux.gui'

function M.print(...)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE .. '<WildAuctions> ' .. join(map({...}, tostring), ' '))
end

local event_frame = CreateFrame'Frame'
for _, event in pairs{'ADDON_LOADED', 'PLAYER_LOGIN', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED'} do
	event_frame:RegisterEvent(event)
end

local aux_events = {}
M.event = setmetatable({}, {__metatable=false, __newindex=function(_, k, v) aux_events[k](v) end})

do
	local handlers, handlers2, handlers3 = {}, {}, {}
	function aux_events.AUX_LOADED(f)
		tinsert(handlers, f)
	end
	function aux_events.PLAYER_LOGIN(f)
		tinsert(handlers2, f)
    end
    function aux_events.AUCTION_HOUSE_LOADED(f)
        tinsert(handlers3, f)
    end
	event_frame:SetScript('OnEvent', function(_, event, arg1, ...)
		if event == 'ADDON_LOADED' then
            if arg1 == 'WildSpark' then
                for _, f in ipairs(handlers) do f(arg1, ...) end
            elseif arg1 == 'Blizzard_AuctionHouseUI' then
                for _, f in ipairs(handlers3) do f(arg1, ...) end
            end
		elseif event == 'PLAYER_LOGIN' then
			for _, f in ipairs(handlers2) do f(arg1, ...) end
            sort(account_data.auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
            print('WildAuctions loaded. Made by Uncle Bone. Use /aux for help.')
            print(full_scan_reminder(account_data.replicate_time, time()))
		else
			_M[event](arg1, ...)
		end
	end)
end

-- WildAuctions (0.5): the second line at login and after /reload. Tooltip prices and recipe costs come
-- from scans, and a Full scan records every price at once, so it says when the last one was and
-- asks for one (Tyler, 2026-10-07: players should get the value out of WildAuctions).
function M.full_scan_reminder(last, now)
    local scan = color.accent.background('Full scan')
    if not last or last <= 0 then
        return 'Tip: at the auction house, click ' .. scan .. ' (top right of aux). It records every price, so your tooltips and recipe costs are right anywhere in the world.'
    end
    local hours = floor(max(0, now - last) / 3600)
    local age
    if hours < 1 then
        age = 'less than an hour ago'
    elseif hours < 24 then
        age = hours .. (hours == 1 and ' hour ago' or ' hours ago')
    else
        local days = floor(hours / 24)
        age = days .. (days == 1 and ' day ago' or ' days ago')
    end
    return 'Last ' .. scan .. ': ' .. age .. '. Run one on each visit to the auction house to keep your tooltip prices current.'
end

-- one character's saved settings with the defaults filled in. 0.8.2 (FB-035): the tooltip lines are
-- filled in one by one, so a line added later (Usually) starts on for a character that already had
-- tooltip settings (assign only fills what is missing at its own level)
TOOLTIP_DEFAULTS = {
    value = true,
    usually = true,
    merchant_sell = true,
    merchant_buy = false,
    daily = false,
    disenchant_value = false,
    disenchant_distribution = false,
    money_icons = false,
}
function M.character_settings(saved)
    assign(saved, {bid_auction_ids = {}, tooltip = {}})
    assign(saved.tooltip, TOOLTIP_DEFAULTS)
    return saved
end

function event.AUX_LOADED()
    _G.aux = aux or {}
    assign(aux, {
        account = {},
        realm = {},
        faction = {},
        character = {},
    })
    M.account_data = assign(aux.account, {
        scale = 1,
        ignore_owner = true,
        action_shortcuts = false,
        post_full_scan = nil,
        post_bid = nil,
        post_duration = post.DURATION_8,
        post_undercut = false,
        full_search = false,
        sniper_percent = 60,
        sniper_profit = 500,
        sniper_sound = true,
        sniper_ignored = {},
        replicate_time = 0,
        window = {},
        background_opacity = 1,
        -- WildAuctions (0.6): the look, 'new' (webster's UI Kit) or 'classic' (the 0.5 look),
        -- chosen in Settings and applied at the next login or /reload
        theme = 'new',
        items = {},
        item_ids = {},
        unused_item_ids = {},
        auctionable_items = {},
        merchant_buy = {},
    })
    do
        local key = format('%s|%s', GetRealmName(), UnitName'player')
        aux.character[key] = aux.character[key] or {}
        M.character_data = character_settings(aux.character[key])
    end
    do
        local key = GetRealmName()
        aux.realm[key] = aux.realm[key] or {}
        M.realm_data = assign(aux.realm[key], {
            characters = {},
            recent_searches = {},
            favorite_searches = {},
        })
    end
    do
        local key = format('%s|%s', GetRealmName(), UnitFactionGroup 'player')
        aux.faction[key] = aux.faction[key] or {}
        M.faction_data = assign(aux.faction[key], {
            history = {},
            post = {},
        })
        -- Forever: the first test version recorded item prices divided by the number of auctions
        -- in a search row, which made recorded values far too low. Start the price history over.
        -- WildAuctions (0.5): version 3 adds market prices and day numbers. A version 2 line (0.4) is
        -- converted when it is first read (core/history.lua), keeping every daily low.
        if faction_data.history_version == 2 then
            faction_data.history_version = 3
        elseif faction_data.history_version ~= 3 then
            faction_data.history = {}
            faction_data.history_version = 3
        end
    end
    -- every file has built its widgets by now; paint them in the chosen look (gui.settle_theme)
    account_data.theme = gui.settle_theme(account_data.theme)
end

tab_info = {}
function M.tab(name)
	local tab = { name = name }
	local tab_event = {
		OPEN = function(f) tab.OPEN = f end,
		CLOSE = function(f) tab.CLOSE = f end,
		USE_ITEM = function(f) tab.USE_ITEM = f end,
		CLICK_LINK = function(f) tab.CLICK_LINK = f end,
	}
	tinsert(tab_info, tab)
	return setmetatable({}, {__metatable=false, __newindex=function(_, k, v) tab_event[k](v) end})
end

do
	local index
	function M.get_tab() return tab_info[index] end
	function on_tab_click(i)
		do (index and get_tab().CLOSE or pass)() end
		index = i
		do (index and get_tab().OPEN or pass)() end
	end
end

M.orig = setmetatable({[_G]={}}, {__index=function(self, key) return self[_G][key] end})
function M.hook(...)
	local name, object, handler
	if select('#', ...) == 3 then
		name, object, handler = ...
	else
		object, name, handler = _G, ...
	end
	handler = handler or getfenv(3)[name]
	orig[object] = orig[object] or {}
	orig[object][name], object[name] = object[name], handler
	return hook
end

do
	local locked

	function M.bid_in_progress()
        return locked
    end

	-- Forever: bids and buyouts go through C_AuctionHouse.PlaceBid with the auction's ID.
	-- Must be called from a click handler (hardware event).
	function M.place_bid(auction_id, amount, on_success, on_failure)
		if locked or not auction_id then
            return
        end
		if GetMoney() < amount then
			UIErrorsFrame:AddExternalErrorMessage(ERR_NOT_ENOUGH_MONEY)
			return
		end
		C_AuctionHouse.PlaceBid(auction_id, amount)
		locked = true
		local result
		local listeners = {
			event_listener('AUCTION_HOUSE_PURCHASE_COMPLETED', function(id)
				if id == auction_id then result = true end
			end),
			event_listener('BID_ADDED', function()
				result = true
			end),
			event_listener('CHAT_MSG_SYSTEM', function(message)
				if message == ERR_AUCTION_BID_PLACED then result = true end
			end),
			event_listener('AUCTION_HOUSE_SHOW_ERROR', function(error)
				result = result or error
			end),
		}
		coro_thread(function()
			local t0 = GetTime()
			while result == nil and GetTime() - t0 < 5 do
				coro_wait()
			end
			for _, listener_id in ipairs(listeners) do
				kill_listener(listener_id)
			end
			locked = false
			-- no answer in 5 seconds: on a slow server the purchase may still go through later, so
			-- the player is told so instead of nothing (found with the slow test auction house)
			if result == nil then
				result = 'timeout'
				print('No answer from the auction house yet. The purchase may still go through: check your mail before buying again.')
			end
			if result == true then
				tinsert(character_data.bid_auction_ids, auction_id)
				while #character_data.bid_auction_ids > 200 do
					tremove(character_data.bid_auction_ids, 1)
				end
				do (on_success or pass)() end
			else
				do (on_failure or pass)(result) end
			end
		end)
	end
end

-- Keep Blizzard's native auction-house frame at scale 1 while hidden. Scaling it down
-- breaks the position and size calculations of its child controls when shown again.
do
    local blizzard_visible = false

    function M.fix_blizzard_frame_position()
        if not AuctionHouseFrame then return end
        AuctionHouseFrame:SetScale(1)
        AuctionHouseFrame:SetClampedToScreen(true)
    end

    function M.resize_blizzard_tabs()
        if not AuctionHouseFrame then return end
        local auctions_frame = AuctionHouseFrame.AuctionsFrame
        for _, tabs in ipairs{AuctionHouseFrame.Tabs, type(auctions_frame) == 'table' and auctions_frame.Tabs} do
            for _, tab in ipairs(type(tabs) == 'table' and tabs or empty) do
                local on_show = tab.GetScript and tab:GetScript('OnShow')
                if on_show and tab:IsShown() then pcall(on_show, tab) end
            end
        end
    end

    function M.blizzard_frame_shown()
        return blizzard_visible
    end

    function M.settle_side_panel()
        -- Keep Blizzard's normal adjacent-panel layout around its full-size auction house frame.
    end

    function M.hook_panel_layout() end

    function M.set_blizzard_frame_shown(shown)
        if not AuctionHouseFrame then return end
        blizzard_visible = shown
        AuctionHouseFrame:SetScale(1)
        if shown then
            M.fix_blizzard_frame_position()
            M.resize_blizzard_tabs()
            AuctionHouseFrame:SetClampedToScreen(true)
            AuctionHouseFrame:SetAlpha(1)
            AuctionHouseFrame:EnableMouse(true)
            AuctionHouseFrame:Raise()
        else
            AuctionHouseFrame:SetAlpha(0)
            AuctionHouseFrame:EnableMouse(false)
        end
        do (update_blizzard_button or pass)() end
    end

    local hooked
    function M.hook_blizzard_frame()
        if hooked or not AuctionHouseFrame then return end
        hooked = true
        AuctionHouseFrame:HookScript('OnShow', function(self)
            M.set_blizzard_frame_shown(false)
            self:UnregisterEvent('AUCTION_HOUSE_POST_WARNING')
            self:UnregisterEvent('AUCTION_HOUSE_POST_ERROR')
        end)
        AuctionHouseFrame:HookScript('OnHide', function()
            blizzard_visible = false
            do (update_blizzard_button or pass)() end
        end)
    end

    function event.AUCTION_HOUSE_LOADED()
        M.hook_blizzard_frame()
        M.hook_panel_layout()
    end
end

function AUCTION_HOUSE_SHOW()
    compat_load_auction_house_ui()
    hook_blizzard_frame()
    hook_panel_layout()
    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        set_blizzard_frame_shown(false)
    end
    frame:Show()
    set_tab(1)
    -- WildAuctions: undercut mode is a choice for the moment, so it starts off every visit and stays
    -- as clicked until the auction house closes (Tyler, 2026-10-17, FB-018: no setting for it)
    post.set_undercut_mode(false)
    query_owned_auctions()
    query_bids()
end

function M.query_owned_auctions()
    C_AuctionHouse.QueryOwnedAuctions({{sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false}})
end

function M.query_bids()
    local ids = {}
    for _, id in ipairs(character_data.bid_auction_ids) do
        tinsert(ids, id)
    end
    for _, id in ipairs(_G.g_activeBidAuctionIDs or empty) do
        tinsert(ids, id)
    end
    C_AuctionHouse.QueryBids({{sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false}}, ids)
end

do
	local handlers = {}
	function aux_events.CLOSE(f)
		tinsert(handlers, f)
	end
	function AUCTION_HOUSE_CLOSED()
		for _, handler in pairs(handlers) do
			handler()
		end
		set_tab()
		frame:Hide()
	end
end
