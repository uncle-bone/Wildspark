local _, ns = ...

-- Helpers shared by every subsystem. No load-time dependencies, so it loads
-- first and isolated test fixtures can load it alone. ns.Core and ns.Theme
-- are looked up per call.
--
-- Secret-value naming: Util.secret(v) tests, Util.plain(v) is a boolean,
-- Util.value(v) returns v or nil. Modules usually alias
-- `Plain = ns.Util.value`, so a local named Plain returns a value.
local Util = {}
ns.Util = Util

-- Midnight returns secret values for enemy data; they must not be compared
-- or used as table keys. Looked up per call: the global is client-only.
function Util.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- True for a readable, non-nil value.
function Util.plain(v)
  return not Util.secret(v) and v ~= nil
end

-- The value when readable, otherwise nil.
function Util.value(v)
  if Util.plain(v) then return v end
end

-- pcall that returns the results, or nothing when fn is missing or errors.
function Util.call(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p end
end

-- First result of Util.call when readable.
function Util.read(fn, ...)
  return Util.value((Util.call(fn, ...)))
end

-- "A" or "H": the battleground faction (from core), else the character's.
function Util.MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 then
    return "A"
  elseif f == 0 then
    return "H"
  end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

-- Stronger stock class colours, keeping their familiar hues. In
-- particular, Rogue yellow should not look like Priest white. Cache by
-- source RGB so live changes are picked up without allocating per row.
local classColors = {}
function Util.ClassColor(class)
  local custom = CUSTOM_CLASS_COLORS and class and CUSTOM_CLASS_COLORS[class]
  if custom then return custom end
  local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
  if not c then return end
  local cached = classColors[class]
  if cached and cached.r == c.r and cached.g == c.g and cached.b == c.b then return cached.color end
  local high, low = math.max(c.r, c.g, c.b), math.min(c.r, c.g, c.b)
  if high == low then return c end -- Priest white and neutral fallbacks
  local saturation = math.min(1.6, high / (high - low))
  local color = {
    r = math.max(0, high - (high - c.r) * saturation),
    g = math.max(0, high - (high - c.g) * saturation),
    b = math.max(0, high - (high - c.b) * saturation),
  }
  classColors[class] = { r = c.r, g = c.g, b = c.b, color = color }
  return color
end

-- A class token's name in the game's language ("WARRIOR" -> "Warrior").
function Util.ClassName(class)
  return class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
end

-- Sort class tokens by their names in the game's language.
function Util.SortClasses(list)
  table.sort(list, function(a, b) return Util.ClassName(a) < Util.ClassName(b) end)
  return list
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function Util.Trim(s)
  return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "a, b,,c" -> { "a", "b", "c" }: trimmed pieces, empty ones dropped.
-- sep is one character (default ",").
function Util.Split(s, sep)
  local p = (sep or ","):gsub("%p", "%%%0")
  local out = {}
  for piece in ((s or "") .. (sep or ",")):gmatch("([^" .. p .. "]*)" .. p) do
    piece = Util.Trim(piece)
    if piece ~= "" then out[#out + 1] = piece end
  end
  return out
end

-- "1 error", "2 errors"; an upper-case word takes "S" ("2 ERRORS").
function Util.Plural(n, word)
  if n == 1 then return n .. " " .. word end
  return n .. " " .. word .. (word:upper() == word and "S" or "s")
end

-- Seconds as "m:ss", rounded down: Util.Clock(75) -> "1:15".
-- opts.round: nearest second, never below 0, under a minute as "42s"
-- (Util.Clock(41.6, { round = true }) -> "42s").
function Util.Clock(seconds, opts)
  if opts and opts.round then
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 60 then return seconds .. "s" end
  end
  return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Seconds since something: "now", "42s", "7m".
function Util.Ago(seconds)
  if seconds < 3 then return "now" end
  if seconds < 60 then return string.format("%ds", seconds) end
  return string.format("%dm", math.floor(seconds / 60))
end

---------------------------------------------------------------------------
-- Game data, the same on every client (C_Spell where it exists, else the
-- old globals). nil when the game doesn't answer or the value is secret.
---------------------------------------------------------------------------
function Util.SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return Util.read(C_Spell.GetSpellName, id) end
  return Util.read(GetSpellInfo, id)
end

function Util.SpellTexture(spell)
  if C_Spell and C_Spell.GetSpellTexture then return Util.read(C_Spell.GetSpellTexture, spell) end
  return Util.read(GetSpellTexture, spell)
end

-- Spell ID of a spell you know, by name (the highest rank where spells have ranks).
function Util.SpellID(name)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = Util.call(C_Spell.GetSpellInfo, name)
    return type(info) == "table" and Util.value(info.spellID) or nil
  end
  return Util.value((select(7, Util.call(GetSpellInfo, name))))
end

-- Health of a unit from 0 to 1, or nil (unknown, secret or no maximum).
function Util.HealthFraction(unit)
  local hp, max = Util.read(UnitHealth, unit), Util.read(UnitHealthMax, unit)
  if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
  return hp / max
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
-- Colours resolve through ns.Theme.TipHex(token) (chat is a dark frame) when
-- the theme is loaded (ui/ loads after core/, so it is looked up per call);
-- the literal is the fallback. hex is "rrggbb". The label is the addon's
-- name in chat (ns.LABEL, set by an addon that embeds this file).
local LABEL = ns.LABEL or "Highground"
Util.SAY_KINDS = {
  default = { label = LABEL, token = "brand", hex = "ff5533" },
  bounty = { label = LABEL .. " bounty", token = "bounty", hex = "ffd11a" },
  error = { label = LABEL, token = "brand", hex = "ff5533", text = "error", textHex = "ff5555" },
  warning = { label = LABEL, token = "brand", hex = "ff5533", text = "warning", textHex = "ffaa33" },
}

-- "|cffRRGGBB" for a theme token, else for the fallback hex. Accepts a theme
-- answer of "rrggbb", "aarrggbb", "#rrggbb" or a full "|caarrggbb".
function Util.ColorCode(token, fallback)
  local Theme = ns.Theme
  local fn = Theme and (Theme.TipHex or Theme.Hex)
  local hex = token and type(fn) == "function" and Util.call(fn, token)
  if type(hex) == "string" then
    if hex:match("^|c%x%x%x%x%x%x%x%x$") then return hex end
    hex = hex:gsub("^#", "")
    if hex:match("^%x%x%x%x%x%x%x%x$") then return "|c" .. hex end
    if hex:match("^%x%x%x%x%x%x$") then return "|cff" .. hex end
  end
  return "|cff" .. fallback
end

-- Coloured "Highground" label (no trailing space). kind as in Util.Say.
function Util.Prefix(kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  return Util.ColorCode(k.token, k.hex) .. k.label .. "|r"
end

-- Print one chat line: prefix, a space, then text. kind is nil, "bounty",
-- "error" or "warning"; error and warning colour the text too.
-- Returns the printed line.
function Util.Say(text, kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  text = tostring(text)
  if k.text then text = Util.ColorCode(k.text, k.textHex) .. text .. "|r" end
  local line = Util.Prefix(kind) .. " " .. text
  print(line)
  return line
end

---------------------------------------------------------------------------
-- Protected calls
---------------------------------------------------------------------------
-- Per-stage failure counters: GuardStats[stage] = { errors, lastError };
-- lastError is the first "stage: message" key (read by Timers.Errors).
Util.GuardStats = {}

local function Trace(e)
  return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
end

local function Pack(...)
  return { n = select("#", ...), ... }
end

-- Store a failure in HighgroundDB.errors (read after /reload and by /hg err):
-- errors["stage: first line"] = { count, first = "HH:MM:SS", trace }.
-- The first new key also sets Core.lastError. No saved table yet: stats only.
function Util.RecordError(stage, err)
  stage = tostring(stage or "?")
  local line = tostring(err):match("^[^\n]*")
  local key = stage .. ": " .. line
  local stats = Util.GuardStats[stage]
  if not stats then
    stats = { errors = 0 }
    Util.GuardStats[stage] = stats
  end
  stats.errors = stats.errors + 1
  stats.lastError = stats.lastError or key
  local Core = ns.Core
  local db = Core and Core.db or _G[ns.SAVED_VARIABLE or "HighgroundDB"]
  if type(db) ~= "table" then return end
  db.errors = db.errors or {}
  local rec = db.errors[key]
  if rec then
    rec.count = rec.count + 1
  else
    db.errors[key] = { count = 1, first = date and date("%H:%M:%S") or "", trace = tostring(err) }
    if Core then Core.lastError = key end
  end
end

-- Forget recorded failures (saved errors, Core.lastError, GuardStats).
function Util.ClearErrors()
  local Core = ns.Core
  local db = Core and Core.db or _G[ns.SAVED_VARIABLE or "HighgroundDB"]
  if type(db) == "table" then db.errors = nil end
  if Core then Core.lastError = nil end
  Util.GuardStats = {}
end

-- Run fn(...) protected. Returns true plus fn's results, or false plus the
-- traceback after recording it (Util.RecordError).
function Util.Guard(stage, fn, ...)
  local r
  if select("#", ...) == 0 then
    r = Pack(xpcall(fn, Trace))
  else
    local args = Pack(...)
    r = Pack(xpcall(function() return fn(unpack(args, 1, args.n)) end, Trace))
  end
  if not r[1] then Util.RecordError(stage, r[2]) end
  return unpack(r, 1, r.n)
end

---------------------------------------------------------------------------
-- Frames: events and throttled updates
---------------------------------------------------------------------------
-- Frame that runs handlers[event](event, ...) through Util.Guard (stage is
-- name, else the event). A handler is a function, or { fn = f, unit = "player" }
-- / { fn = f, unit = { "party1", "party2" } } for RegisterUnitEvent (at
-- most two units, the client's limit; plain
-- RegisterEvent where the client lacks it). Events the client does not know
-- are skipped. frame.handlers[event] can be swapped later. A standalone
-- addon on standby (ns.STANDBY, Highground is loaded) registers nothing.
function Util.Events(handlers, name)
  local frame = CreateFrame("Frame")
  frame.handlers = {}
  if ns.STANDBY then return frame end
  for event, h in pairs(handlers) do
    local fn, unit = h, nil
    if type(h) == "table" then fn, unit = h.fn, h.unit end
    frame.handlers[event] = fn
    if unit then
      local units = type(unit) == "table" and unit or { unit }
      pcall(frame.RegisterUnitEvent or frame.RegisterEvent, frame, event, units[1], units[2])
    else
      pcall(frame.RegisterEvent, frame, event)
    end
  end
  frame:SetScript("OnEvent", function(self, event, ...)
    local fn = self.handlers[event]
    if fn then Util.Guard(name or event, fn, event, ...) end
  end)
  return frame
end

-- Call fn(elapsed) at most every `seconds` from an OnUpdate frame, guarded
-- under stage name (default "every"). The accumulator resets on each call,
-- like the existing OnUpdate throttles (no catch-up bursts). Returns a running handle with
-- :Stop() and :Start(); handle.frame is the frame. On standby it never runs.
function Util.Every(seconds, fn, name)
  local frame = CreateFrame("Frame")
  local handle = { frame = frame, elapsed = 0 }
  local function Update(_, dt)
    handle.elapsed = handle.elapsed + (dt or 0)
    if handle.elapsed < seconds then return end
    local elapsed = handle.elapsed
    handle.elapsed = 0
    Util.Guard(name or "every", fn, elapsed)
  end
  function handle.Stop()
    frame:SetScript("OnUpdate", nil)
    if frame.Hide then frame:Hide() end
  end
  function handle.Start()
    handle.elapsed = 0
    if frame.Show then frame:Show() end
    frame:SetScript("OnUpdate", Update)
  end
  if ns.STANDBY then handle.Start = function() end else handle.Start() end
  return handle
end

---------------------------------------------------------------------------
-- Text and game helpers
---------------------------------------------------------------------------
-- Strip the separators used by addon messages: , ; : |
function Util.Clean(s)
  return (tostring(s or ""):gsub("[,;:|]", ""))
end

-- Subzone, else zone, else "".
function Util.ZoneName()
  local zone = Util.read(GetSubZoneText) or ""
  if zone == "" then zone = Util.read(GetZoneText) or "" end
  return zone
end

-- "1,234g" (digit grouping when the client provides BreakUpLargeNumbers).
function Util.Gold(n)
  n = tonumber(n) or 0
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)) .. "g"
end

-- Play the raid warning sound. Callers decide whether sound is enabled.
function Util.AlertSound()
  Util.call(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end
