-- Spy for Forever: a note of your own on a player.
--
-- CurseForge request: "add the option to add a note like it used to be in the old
-- days ... my own notes on the players that I have on KOS". A free text per player,
-- written from the right-click menu on a row or with /spy note, shown in the row
-- tooltip and in the Kill On Sight alert. Shared by the characters of the account,
-- like the Kill On Sight list and the tags. Written from scratch.

local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:GetLocale("Spy")

local MAX_LENGTH = 200

local function store()
	SpyDB.playerNotes = SpyDB.playerNotes or {}
	local realm = tostring(Spy.StoreRealm or Spy.RealmName or "?")
	SpyDB.playerNotes[realm] = SpyDB.playerNotes[realm] or {}
	return SpyDB.playerNotes[realm]
end

local function trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function Spy:PlayerNote(name)
	if type(name) ~= "string" or not SpyDB then
		return nil
	end
	local note = store()[name]
	return type(note) == "string" and note ~= "" and note or nil
end

-- An empty text removes the note. Says so in the chat.
function Spy:SetPlayerNote(name, text)
	if type(name) ~= "string" or name == "" then
		return
	end
	text = trim(text):gsub("|", "/") -- no chat escape codes in a saved note
	if #text > MAX_LENGTH then
		text = text:sub(1, MAX_LENGTH)
	end
	store()[name] = text ~= "" and text or nil
	local shown = name:gsub("%-", " ")
	DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. (text ~= "" and L["NoteSet"]:format(shown, text) or L["NoteCleared"]:format(shown)))
	if Spy.MainWindow and Spy.RefreshCurrentList then
		Spy:RefreshCurrentList()
	end
end

StaticPopupDialogs["Spy_PlayerNote"] = {
	text = L["EnterNote"],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	hasEditBox = 1,
	editBoxWidth = 300,
	maxLetters = MAX_LENGTH,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(self)
		local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
		if editBox then
			editBox:SetText(Spy:PlayerNote(self.playerName) or "")
			editBox:HighlightText()
		end
	end,
	OnAccept = function(self)
		local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
		if editBox and self.playerName then
			Spy:SetPlayerNote(self.playerName, editBox:GetText())
		end
	end,
	EditBoxOnEnterPressed = function(editBox)
		local dialog = editBox:GetParent()
		if dialog and dialog.playerName then
			Spy:SetPlayerNote(dialog.playerName, editBox:GetText())
		end
		if dialog then dialog:Hide() end
	end,
	EditBoxOnEscapePressed = function(editBox)
		local dialog = editBox:GetParent()
		if dialog then dialog:Hide() end
	end,
}

-- The note dialog for that player. playerName is set before the dialog's OnShow
-- through the data argument, so the box opens with the current note in it.
function Spy:EditPlayerNote(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	local dialog = StaticPopup_Show("Spy_PlayerNote", (name:gsub("%-", " ")), nil, nil)
	if dialog then
		dialog.playerName = name
		local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if editBox and editBox.SetText then
			editBox:SetText(Spy:PlayerNote(name) or "")
			if editBox.HighlightText then editBox:HighlightText() end
		end
	end
	return dialog
end

-- /spy note First Last: text   (no name: your target; nothing after ":" removes it)
function Spy:NoteCommand(value)
	local typed, text = tostring(value or ""):match("^([^:]*):(.*)$")
	if not typed then
		typed, text = tostring(value or ""), nil
	end
	typed = trim(typed)
	local name
	if typed == "" then
		name = Spy:PlayerName("target")
		if type(name) ~= "string" or Spy:Readable(UnitIsUnit("target", "player")) then
			DEFAULT_CHAT_FRAME:AddMessage(L["SpySignatureColored"] .. L["NoteNoTarget"])
			return
		end
	else
		name = Spy:TypedPlayerName(typed)
		if not name then
			DEFAULT_CHAT_FRAME:AddMessage(typed .. " - " .. L["InvalidInput"])
			return
		end
	end
	if text == nil then
		Spy:EditPlayerNote(name)
	else
		Spy:SetPlayerNote(name, text)
	end
end

if Spy.optionsSlash and Spy.optionsSlash.args then
	Spy.optionsSlash.args.note = {
		name = L["NoteSlash"],
		desc = L["NoteSlashDescription"],
		type = "input",
		order = 16,
		pattern = ".*",
		set = function(_, value) Spy:NoteCommand(value) end,
		dialogHidden = true,
	}
end

function Spy:NotesReport()
	local count = 0
	for _ in pairs(SpyDB and SpyDB.playerNotes and SpyDB.playerNotes[tostring(Spy.StoreRealm or Spy.RealmName or "?")] or {}) do
		count = count + 1
	end
	return ("Player notes: %d"):format(count)
end
