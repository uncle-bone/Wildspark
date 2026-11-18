local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Capture probe (/hg cap probe): other players' banner casts may never
-- reach the client, so look for any other sign that a capture is under way.
-- While on, every event that could carry one is kept for the last
-- PROBE_WINDOW seconds; when "X has assaulted the Y!" arrives, everything
-- about X in that window (plus anything touching a game object, and
-- world-state changes) is saved to HighgroundDB.capProbe, newest first,
-- together with X's map positions if X is in your group.
---------------------------------------------------------------------------
Core.PROBE_WINDOW = 12 -- seconds before an announcement worth keeping
Core.PROBE_KEEP = 6 -- assaults kept in HighgroundDB.capProbe
Core.PROBE_MAX_ROWS = 120 -- rows per saved assault

local buffer = {} -- { at, kind, who, text } oldest first
local tracks = {} -- [short name] = { { at, x, y }, ... } group positions

-- Combat-log subevents that fire constantly and never mean a capture.
local NOISE = {
  SWING_DAMAGE = true, SWING_MISSED = true, RANGE_DAMAGE = true, RANGE_MISSED = true,
  SPELL_DAMAGE = true, SPELL_MISSED = true, SPELL_HEAL = true, SPELL_ENERGIZE = true,
  SPELL_PERIODIC_DAMAGE = true, SPELL_PERIODIC_MISSED = true, SPELL_PERIODIC_HEAL = true,
  SPELL_PERIODIC_ENERGIZE = true, SPELL_ABSORBED = true, DAMAGE_SHIELD = true,
  DAMAGE_SHIELD_MISSED = true, SPELL_DRAIN = true, SPELL_LEECH = true,
}

local function Short(name)
  return type(name) == "string" and Core.plain(name) and name:match("^[^-]+") or nil
end

local function Add(kind, who, text)
  buffer[#buffer + 1] = { at = GetTime(), kind = kind, who = who, text = text }
end

-- Drop buffered events older than PROBE_WINDOW.
local function Prune(now)
  local keep = 1
  while buffer[keep] and now - buffer[keep].at > Core.PROBE_WINDOW do keep = keep + 1 end
  if keep > 1 then
    for i = 1, #buffer do buffer[i] = buffer[i + keep - 1] end
  end
end

local function Values(...)
  local out = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    out[#out + 1] = Core.plain(v) and tostring(v) or "?"
  end
  return table.concat(out, " ")
end

local function OnCombatLog()
  local info = { CombatLogGetCurrentEventInfo() }
  local sub, srcGUID, srcName, dstGUID, dstName = info[2], info[4], info[5], info[8], info[9]
  if NOISE[sub] then return end
  local object = (type(srcGUID) == "string" and srcGUID:find("^GameObject"))
    or (type(dstGUID) == "string" and dstGUID:find("^GameObject"))
  local who = Short(srcName) or Short(dstName)
  if not (who or object) then return end
  Add("log", object and "object" or Short(srcName), Values(sub, srcName, dstName, dstGUID, unpack(info, 12, 16)))
  local other = Short(dstName)
  if other and other ~= Short(srcName) then Add("log", other, "(as target) " .. sub) end
end

local function OnUnitEvent(event, unit, ...)
  Add("unit", Short((ns.Util.call(UnitName, unit))), Values(event, unit, ...))
end

local function OnWorld(event, ...) Add("world", "world", Values(event, ...)) end

local function OnChat(event, msg, sender) Add("chat", Short(sender) or "world", Values(event, msg)) end

-- Registered only while the probe is on (Core.SetCapProbe).
local HANDLERS = {
  COMBAT_LOG_EVENT_UNFILTERED = OnCombatLog,
  UPDATE_UI_WIDGET = function(_, w)
    Add("world", "world", "UPDATE_UI_WIDGET " .. tostring(type(w) == "table" and w.widgetID or w))
  end,
}
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED",
  "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_DELAYED", "UNIT_AURA", "UNIT_FLAGS" }) do HANDLERS[event] = OnUnitEvent end
for _, event in ipairs({ "AREA_POIS_UPDATED", "VIGNETTES_UPDATED", "UPDATE_WORLD_STATES" }) do
  HANDLERS[event] = OnWorld
end
for _, event in ipairs({ "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_EMOTE",
  "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_RAID_BOSS_EMOTE", "CHAT_MSG_SYSTEM" }) do HANDLERS[event] = OnChat end

local probe = ns.Util.Events({}, "capprobe")
probe.handlers = HANDLERS

-- Group positions twice a second: does a capper stand still at the flag?
local sampler = ns.Util.Every(0.5, function()
  local now = GetTime()
  Prune(now)
  local mapID = ns.CurrentMapID and ns.CurrentMapID()
  if not (mapID and ns.UnitXY) then return end
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, raid and n or math.max(n - 1, 0) do
    local unit = (raid and "raid" or "party") .. i
    local short = Short((ns.Util.call(UnitName, unit)))
    local x, y = ns.UnitXY(mapID, unit)
    if short and x then
      local t = tracks[short] or {}
      tracks[short] = t
      t[#t + 1] = { at = now, x = x, y = y }
      while t[1] and now - t[1].at > Core.PROBE_WINDOW do table.remove(t, 1) end
    end
  end
end, "capprobe")
sampler.Stop()

function Core.SetCapProbe(on)
  Core.db.capProbeOn = on or nil
  wipe(buffer)
  wipe(tracks)
  for event in pairs(HANDLERS) do
    ns.Util.call(on and probe.RegisterEvent or probe.UnregisterEvent, probe, event)
  end
  if on then sampler.Start() else sampler.Stop() end
end

-- "X has assaulted the Y!": save what was seen of X before it.
function Core.CapProbeAssault(who)
  local short = Short(who)
  if not (Core.db and Core.db.capProbeOn and short) then return end
  local now = GetTime()
  Prune(now)
  local rows = {}
  for _, r in ipairs(buffer) do
    if (r.who == short or r.who == "object" or r.who == "world") and #rows < Core.PROBE_MAX_ROWS then
      rows[#rows + 1] = string.format("-%.1f %s %s", now - r.at, r.kind, r.text)
    end
  end
  local path = {}
  for _, p in ipairs(tracks[short] or {}) do
    path[#path + 1] = string.format("-%.1f %.4f,%.4f", now - p.at, p.x, p.y)
  end
  local list = Core.db.capProbe or {}
  Core.db.capProbe = list
  table.insert(list, 1, { t = date("%H:%M:%S"), who = who, me = short == UnitName("player"),
    rows = rows, path = path, seen = #buffer, positions = next(tracks) ~= nil })
  while #list > Core.PROBE_KEEP do table.remove(list) end
end
