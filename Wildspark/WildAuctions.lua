local ADDON_NAME, ns = ...
-- WildAuctions only lists carried items in the Auction House Sell tab.
-- It does not scan listings, show price data, or post auctions.
local ROW_HEIGHT = 48
WildAuctionsDB = WildAuctionsDB or {}
local db = WildAuctionsDB
if db.enabled == nil then db.enabled = true end
local frame, panel, rows, scrollChild, statusText, countText

local function Print(message)
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff55d6a8WildAuctions:|r " .. tostring(message)) end
end

local function BagLocation(bag, slot)
	local itemLocation = _G.ItemLocation
	if not itemLocation or type(itemLocation.CreateFromBagAndSlot) ~= "function" then return nil end
	local function Matches(location)
		if not location or type(location.IsBagAndSlot) ~= "function" or type(location.GetBagAndSlot) ~= "function" then return false end
		local hasBagSlot, isBagSlot = pcall(location.IsBagAndSlot, location)
		local bagOK, actualBag, actualSlot = pcall(location.GetBagAndSlot, location)
		return hasBagSlot and isBagSlot == true and bagOK and actualBag == bag and actualSlot == slot
	end
	-- WildAuctions (MIT-licensed Forever adaptation) documents the canonical
	-- ItemLocation:CreateFromBagAndSlot(bag, slot) path. Some Forever builds may
	-- expose dot-call semantics; accept that only if it returns the exact slot.
	local ok, location = pcall(itemLocation.CreateFromBagAndSlot, itemLocation, bag, slot)
	if ok and Matches(location) then return location end
	ok, location = pcall(itemLocation.CreateFromBagAndSlot, bag, slot)
	if ok and Matches(location) then return location end
	return nil
end

local function IsBound(info, location)
	local ok, bound = pcall(function() return info and info.isBound end)
	if ok and bound == true then return true end
	if location and C_Item and type(C_Item.IsBound) == "function" then
		ok, bound = pcall(C_Item.IsBound, location)
		if ok and bound == true then return true end
	end
	return false
end

local function ItemDetails(info)
	local id = tonumber(info.itemID)
	local name, link, icon = info.itemName, info.hyperlink, info.iconFileID
	if id and (not name or not link or not icon) then
		local fn = C_Item and C_Item.GetItemInfo or _G.GetItemInfo
		if type(fn) == "function" then
			local ok, n, l, _, _, _, _, _, _, tex = pcall(fn, id)
			if ok then name, link, icon = name or n, link or l, icon or tex end
		end
	end
	return id, name or (id and ("Item " .. id) or "Unknown item"), link, icon
end

local function ScanBags()
	local items, c = {}, C_Container
	if not c or type(c.GetContainerNumSlots) ~= "function" or type(c.GetContainerItemInfo) ~= "function" then return items end
	for bag = 0, math.max(tonumber(NUM_BAG_SLOTS) or 4, 5) do
		local ok, slots = pcall(c.GetContainerNumSlots, bag)
		if ok and type(slots) == "number" then
			for slot = 1, slots do
				local got, info = pcall(c.GetContainerItemInfo, bag, slot)
				if got and type(info) == "table" and info.itemID and not info.isLocked then
					local location = BagLocation(bag, slot)
					-- IsSellItemValid incorrectly rejects some valid BoE gear on this client.
					-- Use the actual bound flag instead; include every other bag item.
					if not IsBound(info, location) then
						local id, name, link, icon = ItemDetails(info)
						if id then items[#items + 1] = { bag=bag, slot=slot, itemID=id, count=tonumber(info.stackCount) or 1, name=name, link=link, icon=icon } end
					end
				end
			end
		end
	end
	table.sort(items, function(a,b)
		if a.name == b.name then return a.bag * 100 + a.slot < b.bag * 100 + b.slot end
		return a.name < b.name
	end)
	return items
end

local function SelectItem(item)
	if InCombatLockdown and InCombatLockdown() then Print("Item selection is unavailable in combat."); return end
	if not AuctionHouseFrame or type(AuctionHouseFrame.SetPostItem) ~= "function" then Print("Blizzard Sell form is not ready."); return end
	local c = C_Container
	local info = c and c.GetContainerItemInfo and c.GetContainerItemInfo(item.bag, item.slot)
	if not info or tonumber(info.itemID) ~= item.itemID or info.isLocked then
		Print("That bag slot changed. Refreshing the list.")
		if panel then panel:Refresh() end
		return
	end
	local location = BagLocation(item.bag, item.slot)
	if not location then Print("The client could not identify that bag item."); return end
	local validOK, valid = pcall(function() return location:IsValid() end)
	if not validOK or valid ~= true then
		Print("That bag item is no longer available. Refreshing the list.")
		if panel then panel:Refresh() end
		return
	end
	if IsBound(info, location) then
		Print("That item is soulbound and cannot be sold.")
		if panel then panel:Refresh() end
		return
	end
	local ok, err = pcall(AuctionHouseFrame.SetPostItem, AuctionHouseFrame, location)
	if not ok then Print("Blizzard Sell form could not load that item: " .. tostring(err)); return end
	-- Match AuctionMaster: selecting an item alone leaves the quantity at its
	-- default. Fill the available count and refresh Blizzard's post-state.
	for _, frameName in ipairs({"ItemSellFrame", "CommoditiesSellFrame"}) do
		local sellFrame = AuctionHouseFrame[frameName]
		local getItem = sellFrame and sellFrame.GetItem
		local itemObject
		if type(getItem) == "function" then
			local itemOK, result = pcall(getItem, sellFrame)
			if itemOK then itemObject = result end
		end
		local valid = false
		if itemObject and type(itemObject.IsValid) == "function" then
			local validOK, result = pcall(itemObject.IsValid, itemObject)
			valid = validOK and result == true
		end
		local quantity = sellFrame and sellFrame.QuantityInput
		local shown = false
		if quantity and type(quantity.IsShown) == "function" then
			local shownOK, result = pcall(quantity.IsShown, quantity)
			shown = shownOK and result == true
		end
		if valid and shown then
			local available = item.count
			if C_AuctionHouse and type(C_AuctionHouse.GetAvailablePostCount) == "function" then
				local countOK, result = pcall(C_AuctionHouse.GetAvailablePostCount, itemObject)
				if countOK and tonumber(result) and tonumber(result) > 0 then available = tonumber(result) end
			end
			if type(quantity.SetQuantity) == "function" then pcall(quantity.SetQuantity, quantity, available) end
			if type(sellFrame.UpdatePostState) == "function" then pcall(sellFrame.UpdatePostState, sellFrame) end
			local input = quantity.InputBox
			if input and type(input.SetCursorPosition) == "function" then pcall(input.SetCursorPosition, input, 0) end
		end
	end
	Print("Loaded into Blizzard Sell form. Review it there; no auction is posted automatically.")
end

local function MakeRow(index)
	local b = CreateFrame("Button", nil, scrollChild)
	b:SetSize(284, ROW_HEIGHT)
	b:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(34, 34)
	b.icon:SetPoint("LEFT", 2, 0)
	b.nameText = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	b.nameText:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
	b.nameText:SetWidth(228)
	b.nameText:SetJustifyH("LEFT")
	b.nameText:SetWordWrap(false)
	b:SetScript("OnClick", function(self) if self.item then SelectItem(self.item) end end)
	return b
end

local function Refresh()
	if not panel or not scrollChild then return end
	local items = ScanBags()
	local total = math.max(#items, 1)
	for i = 1, total do
		rows[i] = rows[i] or MakeRow(i)
		local b, item = rows[i], items[i]
		if item then
			b.item = item
			b.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			b.nameText:SetText(item.name .. "  |cffaaaaaa x" .. item.count .. "|r")
			b:Show()
		else b.item = nil; b:Hide() end
	end
	for i = total + 1, #rows do rows[i]:Hide() end
	scrollChild:SetHeight(total * ROW_HEIGHT)
	if countText then countText:SetText(#items .. " unbound bag items") end
	if statusText then statusText:SetText("Click an item to load it into Blizzard Sell form. Nothing is posted.") end
end

local function CreatePanel()
	if panel or not AuctionHouseFrame then return end
	panel = CreateFrame("Frame", "WildAuctionsPanel", UIParent, "BackdropTemplate")
	panel:SetSize(322, 510)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=8, edgeSize=24, insets={left=8,right=8,top=8,bottom=8}})
	panel:SetBackdropColor(0.035, 0.045, 0.055, 0.97)
	panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, -96)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 17, -15)
	title:SetText("WildAuctions")
	local refresh = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	refresh:SetSize(78, 24)
	refresh:SetPoint("TOPRIGHT", -14, -13)
	refresh:SetText("Refresh")
	refresh:SetScript("OnClick", Refresh)
	statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	statusText:SetWidth(280)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(true)
	countText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	countText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
	countText:SetWidth(280)
	countText:SetJustifyH("LEFT")
	local creditText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	creditText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 18)
	creditText:SetText("Made by Uncle Bone")
	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 15, -94)
	scroll:SetPoint("BOTTOMRIGHT", -30, 38)
	scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(284, 1)
	scroll:SetScrollChild(scrollChild)
	rows = {}
	panel.Refresh = Refresh
	panel:Hide()
end

local function IsSellTab()
	if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() or type(AuctionHouseFrame.GetDisplayMode) ~= "function" then return false end
	local ok, mode = pcall(AuctionHouseFrame.GetDisplayMode, AuctionHouseFrame)
	if not ok then return false end
	local d = AuctionHouseFrameDisplayMode
	return d and (mode == d.ItemSell or mode == d.CommoditiesSell) or false
end

local function UpdateVisibility()
	if db.enabled == false then if panel then panel:Hide() end; return end
	if not AuctionHouseFrame then return end
	CreatePanel()
	if not panel then return end
	if IsSellTab() then panel:Show(); Refresh() else panel:Hide() end
end

local function TryAttach()
	if not AuctionHouseFrame then return false end
	CreatePanel()
	if type(AuctionHouseFrame.SetDisplayMode) == "function" and not AuctionHouseFrame.wildAuctionsHooked then
		local ok = pcall(hooksecurefunc, AuctionHouseFrame, "SetDisplayMode", function()
			if C_Timer then C_Timer.After(0, UpdateVisibility) else UpdateVisibility() end
		end)
		if ok then AuctionHouseFrame.wildAuctionsHooked = true end
	end
	local sellTab = AuctionHouseFrame.SellTab
	if sellTab and type(sellTab.HookScript) == "function" and not sellTab.wildAuctionsHooked then
		local ok = pcall(sellTab.HookScript, sellTab, "OnClick", function()
			if C_Timer then C_Timer.After(0, UpdateVisibility) else UpdateVisibility() end
		end)
		if ok then sellTab.wildAuctionsHooked = true end
	end
	UpdateVisibility()
	return true
end

local function OnEvent(_, event)
	if event == "AUCTION_HOUSE_SHOW" then
		local function attach() if not TryAttach() and C_Timer then C_Timer.After(0.5, attach) end end
		if C_Timer then C_Timer.After(0, attach) else attach() end
	elseif event == "AUCTION_HOUSE_CLOSED" then
		if panel then panel:Hide() end
	elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
		if panel and panel:IsShown() then Refresh() end
	elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		if C_Timer then C_Timer.After(0, TryAttach) else TryAttach() end
	end
end

frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", OnEvent)

ns.WildAuctions = {
	Refresh = Refresh,
	GetEnabled = function() return db.enabled ~= false end,
	SetEnabled = function(value) db.enabled = value and true or false; UpdateVisibility() end,
	OpenSellTab = function()
		if AuctionHouseFrame and AuctionHouseFrame:IsShown() then
			local d, mode = AuctionHouseFrameDisplayMode, AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.ItemSell
			if mode and type(AuctionHouseFrame.SetDisplayMode) == "function" then
				pcall(AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame, mode)
				if C_Timer then C_Timer.After(0, UpdateVisibility) end
			end
			return
		end
		if type(ToggleAuctionHouse) == "function" then
			ToggleAuctionHouse()
			if C_Timer then C_Timer.After(0.5, function()
				local d = AuctionHouseFrameDisplayMode
				local mode = d and d.ItemSell
				if AuctionHouseFrame and AuctionHouseFrame:IsShown() and mode and type(AuctionHouseFrame.SetDisplayMode) == "function" then
					pcall(AuctionHouseFrame.SetDisplayMode, AuctionHouseFrame, mode)
					UpdateVisibility()
				end
			end) end
		else Print("Open the Auction House from a city auctioneer.") end
	end,
}

