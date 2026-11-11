local addonName, addonTable = ...
local util = addonTable.util

-- Parsed forms of the comma separated settings. Chat can be busy, so the lists are only
-- rebuilt when the corresponding setter runs instead of on every message.
local parsedConfig = {}

--- Drops all cached parsed settings; called by every setter that feeds them.
function WildLayer:InvalidateParsedConfig()
	parsedConfig.triggers = nil
	parsedConfig.blacklist = nil
	parsedConfig.invertKeywords = nil
	parsedConfig.ignorePrefixes = nil
	parsedConfig.filteredChannels = nil
end

function WildLayer:SetDebug(info, val)
	self:DebugPrint("SetDebug", info, val)
	self.db.profile.debug = val
end

function WildLayer:GetDebug(info)
	return self.db.profile.debug
end

function WildLayer:GetEnabled(info)
	return self.db.profile.enabled
end

--- Applies the enabled state and keeps sounds, chat filters and the minimap icon in sync.
---@param info table|nil
---@param val boolean
function WildLayer:SetEnabled(info, val)
	self.db.profile.enabled = val and true or false
	self:SyncRuntimeState()
end

function WildLayer:SetAllowAutoInvites(info, val)
	self.db.profile.allowAutoInvites = val and true or false
	-- Keep WildSpark's module panel and AutoLayer's own profile in sync.
	local db = _G.WildsparkDB
	if type(db) == "table" and type(db.modules) == "table" and type(db.modules.wildLayer) == "table" then
		db.modules.wildLayer.autoInvites = self.db.profile.allowAutoInvites
	end
end

function WildLayer:GetAllowAutoInvites()
	return self.db.profile.allowAutoInvites and true or false
end

function WildLayer:Toggle()
	self:SetEnabled(nil, not self.db.profile.enabled)
	self:Print(self.db.profile.enabled and "enabled" or "disabled")
end

--- Pushes the current profile state to sounds, chat filters and the LDB icon.
--- Safe to call repeatedly: every branch is idempotent.
function WildLayer:SyncRuntimeState()
	local profile = self.db.profile

	if profile.enabled and profile.mutesounds then
		self:MuteAnnoyingSounds()
	else
		self:UnmuteAnnoyingSounds()
	end

	if profile.hideAutoWhispers then
		self:filterChatEventWildLayerWhisperMessages()
	else
		self:unfilterChatEventWildLayerWhisperMessages()
	end

	if profile.hideSystemGroupMessages then
		self:filterChatEventSystemGroupMessages()
	else
		self:unfilterChatEventSystemGroupMessages()
	end

	local bunnyLDB = addonTable.bunnyLDB
	if bunnyLDB then
		bunnyLDB.icon = profile.enabled and addonTable.icons.enabled or addonTable.icons.disabled
		local minimapIcon = LibStub("LibDBIcon-1.0", true)
		if minimapIcon and minimapIcon:IsRegistered("WildLayer") then
			minimapIcon:Refresh("WildLayer", profile.minimap)
		end
	end
end

function WildLayer:SetMinimapHidden(info, val)
	self.db.profile.minimap.hide = val and true or false
	local minimapIcon = LibStub("LibDBIcon-1.0", true)
	if not minimapIcon then
		return
	end
	if self.db.profile.minimap.hide then
		minimapIcon:Hide("WildLayer")
	else
		minimapIcon:Show("WildLayer")
	end
end

function WildLayer:GetMinimapHidden(info)
	return self.db.profile.minimap.hide
end

function WildLayer:SetTriggers(info, val)
	self:DebugPrint("SetTriggers", info, val)
	self.db.profile.triggers = val
	self:InvalidateParsedConfig()
end

function WildLayer:GetTriggers(info)
	return self.db.profile.triggers
end

---@return table<{word: string, pattern: string}>
function WildLayer:ParseTriggers()
	local cached = parsedConfig.triggers
	if cached then
		return cached
	end

	cached = {}
	for _, word in ipairs(util.SplitConfigList(self.db.profile.triggers)) do
		local lowered = string.lower(word)
		cached[#cached + 1] = { word = lowered, pattern = util.TriggerPattern(lowered) }
	end
	parsedConfig.triggers = cached
	return cached
end

function WildLayer:SetIgnorePrefixes(info, val)
	self:DebugPrint("SetIgnorePrefixes", info, val)
	self.db.profile.ignorePrefixes = val
	self:InvalidateParsedConfig()
end

function WildLayer:GetIgnorePrefixes(info)
	return self.db.profile.ignorePrefixes
end

---@return table<string>
function WildLayer:ParseIgnorePrefixes()
	local cached = parsedConfig.ignorePrefixes
	if cached then
		return cached
	end

	cached = {}
	for _, prefix in ipairs(util.SplitConfigList(self.db.profile.ignorePrefixes)) do
		cached[#cached + 1] = string.lower(prefix)
	end
	parsedConfig.ignorePrefixes = cached
	return cached
end

function WildLayer:SetBlacklist(info, val)
	self:DebugPrint("SetBlacklist", info, val)
	self.db.profile.blacklist = val
	self:InvalidateParsedConfig()
end

function WildLayer:GetBlacklist(info)
	return self.db.profile.blacklist
end

---@return table<{word: string}>
function WildLayer:ParseBlacklist()
	local cached = parsedConfig.blacklist
	if cached then
		return cached
	end

	cached = {}
	for _, word in ipairs(util.SplitConfigList(self.db.profile.blacklist)) do
		cached[#cached + 1] = { word = string.lower(word) }
	end
	parsedConfig.blacklist = cached
	return cached
end

function WildLayer:SetInvertKeywords(info, val)
	self:DebugPrint("SetInvertKeywords", info, val)
	self.db.profile.invertKeywords = val
	self:InvalidateParsedConfig()
end

function WildLayer:GetInvertKeywords(info)
	return self.db.profile.invertKeywords
end

---@return table<{word: string}>
function WildLayer:ParseInvertKeywords()
	local cached = parsedConfig.invertKeywords
	if cached then
		return cached
	end

	cached = {}
	for _, word in ipairs(util.SplitConfigList(self.db.profile.invertKeywords)) do
		cached[#cached + 1] = { word = string.lower(word) }
	end
	parsedConfig.invertKeywords = cached
	return cached
end

function WildLayer:SetChannelFiltering(info, val)
	self.db.profile.channelFiltering = val
end

function WildLayer:GetFilteredChannels(info)
	return self.db.profile.filteredChannels
end

function WildLayer:SetFilteredChannels(info, val)
	if val == "" then
		self.db.profile.channelFiltering = "none"
	end
	self.db.profile.filteredChannels = val
	self:InvalidateParsedConfig()
end

---@return table<{name: string, pattern: string}>
function WildLayer:ParseFilteredChannels()
	local cached = parsedConfig.filteredChannels
	if cached then
		return cached
	end

	cached = {}
	for _, channel in ipairs(util.SplitConfigList(self.db.profile.filteredChannels)) do
		cached[#cached + 1] = { name = channel, pattern = util.ChannelPattern(channel) }
	end
	parsedConfig.filteredChannels = cached
	return cached
end
