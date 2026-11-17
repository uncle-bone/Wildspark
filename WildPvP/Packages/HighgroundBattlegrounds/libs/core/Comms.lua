local _, ns = ...

---------------------------------------------------------------------------
-- Addon messages: the group channel, protected sends and one shared
-- CHAT_MSG_ADDON frame that hands each message to its prefix's listener.
-- Prefixes in use (wire formats live with their modules):
--   HighgroundC  capture probes   core/CapShare.lua
--   HighgroundT  timers           timers/Sharing.lua
--   HighgroundI  map intel        map/Sharing.lua
--   HighgroundB  guild bounties   bounty/Sync.lua
--   HighgroundP  setup profiles  options/ProfileSharing.lua (Highground)
-- Each prefix registers with the client once, on PLAYER_LOGIN (or at
-- once when already logged in). Throttling stays with each module.
---------------------------------------------------------------------------
local Util = ns.Util
local Comms = {}
ns.Comms = Comms

-- The group's chat channel: instance group first, then raid, then party.
-- nil when not in a group.
function Comms.GroupChannel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  elseif IsInRaid and IsInRaid() then
    return "RAID"
  elseif IsInGroup and IsInGroup() then
    return "PARTY"
  end
end

-- True when the client can send addon messages.
function Comms.CanSend()
  return C_ChatInfo ~= nil and C_ChatInfo.SendAddonMessage ~= nil
end

-- Send text under prefix on channel (target for WHISPER). Errors are
-- swallowed. Returns false when there is no channel or no send API.
function Comms.Send(prefix, text, channel, target)
  if ns.STANDBY or not (channel and Comms.CanSend()) then return false end
  pcall(C_ChatInfo.SendAddonMessage, prefix, text, channel, target)
  return true
end

local listeners = {} -- [prefix] = { fn, stage }
local registered = {} -- [prefix] = true once the client knows it
local loggedIn = false

local function Register(prefix)
  if registered[prefix] or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
  registered[prefix] = pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix) or nil
end

-- Call fn(text, channel, sender) for each string message under prefix,
-- guarded under stage (default the prefix). One listener per prefix.
-- On standby (ns.STANDBY) Highground listens instead.
function Comms.Listen(prefix, fn, stage)
  if ns.STANDBY then return end
  assert(not listeners[prefix], "Comms.Listen: " .. tostring(prefix) .. " already has a listener")
  listeners[prefix] = { fn = fn, stage = stage or prefix }
  if loggedIn or (IsLoggedIn and IsLoggedIn()) then Register(prefix) end
end

Comms.frame = Util.Events({
  PLAYER_LOGIN = function()
    loggedIn = true
    for prefix in pairs(listeners) do Register(prefix) end
  end,
  -- Every addon's messages arrive here: filter by prefix before guarding.
  CHAT_MSG_ADDON = function(_, prefix, text, channel, sender, ...)
    local l = listeners[prefix]
    if l and type(text) == "string" then Util.Guard(l.stage, l.fn, text, channel, sender, ...) end
  end,
}, "comms")
