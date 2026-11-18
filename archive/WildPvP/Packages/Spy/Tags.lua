-- Spy for Forever: player tags.
--
-- CurseForge request: a "do not kill" category (he could have ganked me and did not,
-- I return the favour) and a "fair fight" one (a rival, not a Kill On Sight target).
-- Kept simple: a tag set from the right-click menu on a row, shown as a marker on the
-- row (green triangle / orange circle) and in /spy debug. Shared by the characters of
-- the account, like the Kill On Sight list. Written from scratch.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")

local VALID = { spare = true, rival = true }

local function store()
	SpyDB.playerTags = SpyDB.playerTags or {}
	local realm = tostring(Spy.StoreRealm or Spy.RealmName or "?")
	SpyDB.playerTags[realm] = SpyDB.playerTags[realm] or {}
	return SpyDB.playerTags[realm]
end

function Spy:PlayerTag(name)
	if type(name) ~= "string" or not SpyDB then
		return nil
	end
	local tag = store()[name]
	return VALID[tag] and tag or nil
end

-- tag = "spare", "rival" or nil (removes it). Says so in the chat.
function Spy:SetPlayerTag(name, tag)
	if type(name) ~= "string" or name == "" then
		return
	end
	if tag ~= nil and not VALID[tag] then
		return
	end
	store()[name] = tag
	DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. (tag and L["TagSet_" .. tag] or L["TagCleared"]):format(name:gsub("%-", " ")))
	if Spy.MainWindow and Spy.RefreshCurrentList then
		Spy:RefreshCurrentList()
	end
end

function Spy:TagsReport()
	local counts = { spare = 0, rival = 0 }
	for _, tag in pairs(SpyDB and SpyDB.playerTags and SpyDB.playerTags[tostring(Spy.StoreRealm or Spy.RealmName or "?")] or {}) do
		if counts[tag] then counts[tag] = counts[tag] + 1 end
	end
	return ("Player tags: %d do not kill, %d fair fight"):format(counts.spare, counts.rival)
end
