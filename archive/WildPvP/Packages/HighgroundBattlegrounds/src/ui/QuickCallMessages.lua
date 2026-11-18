local _, ns = ...
local U = ns.Util
local Quick = { COUNTS = { "1", "2", "3+" }, COOLDOWN = 2 }
ns.QuickCalls = Quick

-- Honor the shared chat formatter when present; older hosts send plain text.
local function ChatText(text)
  return U.ChatText and U.ChatText(text) or text
end

local function Contains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end

local function Clean(area)
  return U.Trim(area or ""):gsub("[%c|]", ""):sub(1, 90)
end

function Quick.Enabled(feature)
  local db = ns.GetDB()
  return not ns.STANDBY and db and db.quickCalls == true and (not feature or db[feature] == true)
end

function Quick.Live()
  return ns.IsActive() and select(2, IsInInstance()) == "pvp"
end

-- Resolve at click time too: the core's next tick may not have seen a map change.
function Quick.Battleground()
  return ns.ResolveBattleground(ns.Intel.MapID(), select(8, GetInstanceInfo()), ns.CLIENT)
end

function Quick.Context()
  local bg = Quick.Live() and Quick.Battleground()
  return bg and (bg.id .. ":" .. (ns.MatchSerial or 0))
end

-- Roads or a map-wide zone name do not identify a local help destination.
-- The extra controls remain useful there, even with timers switched off.
function Quick.Area()
  local area = Clean(U.read(GetSubZoneText))
  if area == "" then area = Clean(U.read(GetMinimapZoneText)) end
  if area == "" or ns.IsZoneName(ns.Intel.MapID(), area) then return nil end
  return area
end

local function Rules(preview, sample)
  local bg = preview and ns.BattlegroundConfigs[sample] or Quick.Battleground()
  return bg and bg.rules.callouts or {}, bg
end

function Quick.Destinations(preview)
  local config, bg = Rules(preview, "arathi_basin")
  local landmarks, mapID = {}, ns.Intel.MapID()
  -- A loading screen can still report the previous UI map. Never reuse its POIs.
  if not preview and bg and Contains(bg.ui, mapID) then landmarks = ns.Intel.Landmarks(mapID) end
  local list, seen = {}, {}
  local function Add(name, observed)
    name = Clean(name)
    if name == "" then return end
    local key = config.aliases and config.aliases[name:lower()] or name:lower()
    local index = seen[key]
    if not index then
      list[#list + 1] = name; seen[key] = #list
    elseif observed then
      list[index] = name -- Prefer the client's spelling over the fallback.
    end
  end
  -- Known bases are available before map landmarks load. On other locales,
  -- prefer the client's names once available instead of duplicating English names.
  local locale = U.read(GetLocale) or "enUS"
  if preview or #landmarks == 0 or locale == "enUS" or locale == "enGB" then
    for _, name in ipairs(config.destinations or {}) do Add(name) end
  end
  for _, landmark in ipairs(landmarks) do Add(landmark.name, true) end
  table.sort(list)
  return list
end

function Quick.Routes(preview)
  local config = Rules(preview, "warsong_gulch")
  return config.routes or {}
end

function Quick.Message(choice, area)
  if choice == "clear" then return ChatText("All clear — " .. area) end
  if choice ~= nil and not Contains(Quick.COUNTS, tostring(choice)) then return nil end
  local enemies = choice and (" (" .. choice .. (tostring(choice) == "1" and " enemy)" or " enemies)")) or ""
  return ChatText("Need help — " .. area .. enemies)
end

function Quick.DestinationMessage(count, destination)
  if not Contains(Quick.COUNTS, tostring(count)) then return nil end
  return ChatText(count .. (tostring(count) == "1" and " enemy" or " enemies") .. " going to " .. destination)
end

function Quick.RouteMessage(route)
  return ChatText("EFC going " .. route:lower())
end

-- Only called synchronously by a click. All kinds share one cooldown and
-- leave chat drafts intact. Failed sends never queue or consume the cooldown.
local function Send(text)
  if not Quick.Enabled() or not Quick.Live() then return false, "Quick callouts are only available in a battleground." end
  if Quick.sentAt and GetTime() - Quick.sentAt < Quick.COOLDOWN then return false, "Wait a moment before another callout." end
  -- Never fall back to a premade party/raid: this message is for the whole BG.
  if ns.Comms.GroupChannel() ~= "INSTANCE_CHAT" then return false, "Battleground chat is unavailable." end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  if not send then return false, "Battleground chat is unavailable." end
  local ok, result = pcall(send, text, "INSTANCE_CHAT")
  if not ok or result == false then return false, "The callout could not be sent." end
  Quick.sentAt = GetTime()
  Quick.Update()
  return true
end

function Quick.Send(choice)
  local area = Quick.Area()
  if not area then return false, "Enter a named battleground area first." end
  local text = Quick.Message(choice, area)
  if not text then return false, "Choose Help, 1, 2, 3+ or All clear." end
  return Send(text)
end

function Quick.SendDestination(count, destination, context)
  if not Quick.Enabled("quickCallsDestinations") then return false, "Enable Enemy destination callouts first." end
  if (context and context ~= Quick.Context()) or not Contains(Quick.Destinations(), destination) then
    return false, "Choose a destination in this battleground."
  end
  local text = Quick.DestinationMessage(count, destination)
  if not text then return false, "Choose 1, 2 or 3+." end
  return Send(text)
end

function Quick.SendRoute(route, context)
  if not Quick.Enabled("quickCallsRoutes") then return false, "Enable EFC route callouts first." end
  if (context and context ~= Quick.Context()) or not Contains(Quick.Routes(), route) then
    return false, "Choose an EFC route in Warsong Gulch or Twin Peaks."
  end
  return Send(Quick.RouteMessage(route))
end
