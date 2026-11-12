-- LFGForever -- core/slash.lua
--
-- The /lfg slash command.
--
-- `/lfg` is unclaimed on this client. Blizzard ships /lfd, /df and
-- /dungeonfinder (SLASH_DUNGEONS1-6) and /lfr (SLASH_RAIDFINDER5-6), but no
-- SLASH_* global anywhere in the 993 in GlobalStrings/enUS.lua has the value
-- "/lfg" -- and on Forever those Dungeon/Raid Finder commands lead nowhere
-- anyway, because Blizzard_GroupFinder is gated off camelot entirely
-- (Blizzard_GroupFinder.toc:10, ## ExcludeLoadGameType: camelot).

-- The registry key. SlashCmdList is ONE global table shared by every addon on
-- the machine, so the key is namespaced rather than named after the command:
-- keying on "LFG" would take a name any other addon may also want, and the
-- last one loaded would silently win.
--
-- This is also why Blizzard's own RegisterNewSlashCommand
-- (SlashCommandsRegistry.lua:42-51) is not used here. It does exactly what the
-- two lines below do, but derives the key from the command word
-- (`local name = string.upper(command)`), so it would register us as "LFG".
-- It also requires a second alias and would build "/"..nil without one.
local COMMAND_KEY = "WILDGROUPS"

-- The addon's private table, the second of the two varargs the client passes
-- every addon file. core/window.lua puts ToggleWindow on it, and the .toc loads
-- that file first.
local _, root = ...
local LFGF = root.WildGroups
local L = LFGF.L

-- Registration is the pair of globals Blizzard's dispatcher reads:
--
--   * SLASH_<KEY><n> -- the tokens, walked from 1 upwards until one is nil
--     (ChatFrameUtil.lua:795-804). One token, so there is no SLASH_..."2".
--   * SlashCmdList[<KEY>] -- the handler.
--
-- ChatFrameUtil.ImportAllListsToHash() folds the pair into hash_SlashCmdList
-- and it runs on EVERY parse (ChatFrameEditBox.lua:253), so registering at file
-- scope like this is picked up whenever the player first types the command --
-- there is no ordering requirement against Blizzard's own setup pass.
--
-- Assigned through _G rather than as bare global statements because these are
-- dynamic names built from COMMAND_KEY; writing them out literally would let
-- the key and the token drift apart silently.
-- LFGF.SLASH_COMMAND, not a literal: core/main.lua's load greeting names the
-- same constant, so the command the player is told to type and the command
-- that is registered cannot drift apart.
_G["SLASH_" .. COMMAND_KEY .. "1"] = "/wildgroups"

-- The handler's signature is (msg, editBox): the trimmed argument string and
-- the chat edit box the command was typed into (ChatFrameEditBox.lua:266-267).
-- Neither is used -- `/lfg` takes no arguments -- and naming unused parameters
-- is noise, so they are simply not declared.
--
-- LFGF.ToggleWindow is resolved at CALL time, not load time, so this file does
-- not care that core/window.lua defines it; the .toc ordering is for clarity,
-- not correctness.
_G.SlashCmdList[COMMAND_KEY] = function()
	LFGF.ToggleWindow()
end

-- The key binding, Bindings.xml's LFGFOREVER_TOGGLE: the other way to open the
-- window from the keyboard, so it does what /lfg does.
--
-- Blizzard's Keybindings page titles the section _G[category]
-- (Keybindings.lua:220-226) and labels the row BINDING_NAME_<action>
-- (BindingUtil.lua:142-148), reading both when it builds its rows -- at the
-- earliest on this addon's ADDON_LOADED, after this file has run. The section
-- is the addon's name, which is never translated; the label is LFGF.L's, so a
-- language pack translates it.
BINDING_HEADER_WILDGROUPS = LFGF.TITLE
BINDING_NAME_WILDGROUPS_TOGGLE = L.BINDING_OPEN_WINDOW

-- What the binding's body calls. A binding body runs in the global
-- environment, so this is a global, namespaced like the compartment's
-- (core/minimap.lua). It works in combat: the window is a plain frame.
function WildSpark_WildGroups_ToggleWindow()
	LFGF.ToggleWindow()
end
