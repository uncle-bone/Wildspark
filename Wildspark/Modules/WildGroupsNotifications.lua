-- Restore direct party/raid invite feedback when the Forever client does not
-- provide Blizzard's normal chat line and notification sound.
local _, root = ...
local groups = root.WildGroups
if not groups then return end

local function playInviteSound()
	if type(PlaySound) ~= "function" then return end
	-- PlaySound accepts numeric SoundKit IDs; a string such as "ReadyCheck"
	-- may silently do nothing without raising an error. Use the battleground
	-- queue-pop cue, then fall back to Blizzard's standard group-invite sound.
	local queueSound = SOUNDKIT and SOUNDKIT.PVP_THROUGH_QUEUE or 8459
	local ok, willPlay = pcall(PlaySound, queueSound, "Master", false)
	if ok and willPlay == true then return end
	local inviteSound = SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE or 880
	pcall(PlaySound, inviteSound, "Master", false)
end

local function readableName(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	return value ~= "" and value or nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:SetScript("OnEvent", function(_, event, inviter)
	if event ~= "PARTY_INVITE_REQUEST" and event ~= "GUILD_INVITE_REQUEST" then return end
	if not groups.IsEnabled or not groups.IsEnabled() then return end
	local kind = event == "GUILD_INVITE_REQUEST" and "Guild" or "Group/raid"
	groups.Print(kind .. " invite from " .. (readableName(inviter) or "unknown player"))
	playInviteSound()
end)
frame:RegisterEvent("GUILD_INVITE_REQUEST")

local lastInviteName, lastInviteTime
local function onInviteSent(name)
	if not groups.IsEnabled or not groups.IsEnabled() then return end
	name = readableName(name) or "unknown player"
	local now = GetTime and GetTime() or 0
	if name == lastInviteName and now - (lastInviteTime or -2) < 1 then return end
	lastInviteName, lastInviteTime = name, now
	groups.Print("Invited " .. name .. " to the group/raid")
	playInviteSound()
end

if type(hooksecurefunc) == "function" then
	local partyInfo = C_PartyInfo
	if type(partyInfo) == "table" and type(partyInfo.InviteUnit) == "function" then
		hooksecurefunc(partyInfo, "InviteUnit", onInviteSent)
	end
	if type(InviteUnit) == "function" then
		hooksecurefunc("InviteUnit", onInviteSent)
	end
	local function onGuildInviteSent(name)
		if not groups.IsEnabled or not groups.IsEnabled() then return end
		name = readableName(name) or "unknown player"
		local now = GetTime and GetTime() or 0
		if name == lastInviteName and now - (lastInviteTime or -2) < 1 then return end
		lastInviteName, lastInviteTime = name, now
		groups.Print("Invited " .. name .. " to the guild")
	end
	local guildInfo = C_GuildInfo
	if type(guildInfo) == "table" and type(guildInfo.Invite) == "function" then
		hooksecurefunc(guildInfo, "Invite", onGuildInviteSent)
	end
	if type(GuildInvite) == "function" then
		hooksecurefunc("GuildInvite", onGuildInviteSent)
	end
end
