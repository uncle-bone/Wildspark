local addon, ns = ...

---------------------------------------------------------------------------
-- First file of every standalone addon (Highground Macros, Bounties, ...):
-- what Highground's class configuration and core otherwise provide to the
-- shared files. Names come from the addon's folder and TOC title.
--   ns.CLIENT (which API) and ns.GAME (which content), from the interface
--   number: 1150x Classic Era, 2050x The Burning Crusade (Anniversary):
--   classic API; 1600x WoW Forever: classic content on the Midnight client;
--   4040x Cataclysm Classic; 12xxxx Retail.
--   ns.STANDBY: Highground itself is loaded (the TOCs list it under
--   OptionalDeps, so it loads first). It has every feature, so this addon
--   stays idle: Util.Events, Util.Every and Comms.Listen register nothing
--   and standalone/Main.lua only says to use /hg.
---------------------------------------------------------------------------
local toc = type(GetBuildInfo) == "function" and select(4, GetBuildInfo()) or 0
if toc < 16000 then
  ns.CLIENT, ns.GAME = "classic", "classic"
elseif toc < 20000 then
  ns.CLIENT, ns.GAME = "retail", "forever"
elseif toc < 30000 then
  ns.CLIENT, ns.GAME = "classic", "tbc"
elseif toc >= 40000 and toc < 50000 then
  ns.CLIENT, ns.GAME = "cata", "cata"
else
  ns.CLIENT, ns.GAME = "retail", "retail"
end

local api = C_AddOns or {}
local metadata = api.GetAddOnMetadata or GetAddOnMetadata
local loaded = api.IsAddOnLoaded or IsAddOnLoaded
local title = metadata and metadata(addon, "Title")

ns.MEDIA = "Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Intel\\libs\\media\\"
ns.SOUNDS = "Interface\\AddOns\\WildSpark\\Modules\\WildPvP\\Features\\Intel\\src\\sounds\\"
-- Names the shared files use: chat label, global frame prefix, saved variable.
ns.LABEL = "WildPvP"
ns.FRAME_PREFIX, ns.SAVED_VARIABLE = "WildPvPIntel", "HighgroundBattlegroundsDB"
ns.STANDBY = false
ns.Core = { me = {} }
