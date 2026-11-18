local _, ns = ...
local U, Core, S = ns.Util, ns.Core, ns.Stealth
local P = { seen = {} }
ns.PvPStealth = P

function P.Enabled()
  if not Core.db or Core.testMode then return false end
  local _, kind = U.call(IsInInstance)
  if kind == "pvp" then return Core.active == true end
  return kind == "arena" and ns.Arena and ns.Arena.Enabled()
end

local function Note(name, class)
  local e = P.seen[name] or { name = name }
  e.class, e.last = class or e.class, GetTime()
  P.seen[name] = e
  return e
end

local function Watched(unit)
  return type(unit) == "string" and (unit:match("^nameplate%d+$") or unit:match("^arena%d+$")
    or unit == "target" or unit == "focus" or unit == "mouseover")
end

function P.NoteUnit(unit)
  if not (P.Enabled() and Watched(unit) and S.Hostile(unit)) then return end
  if U.read(UnitIsVisible, unit) == false then return end
  local name = S.UnitKey(unit)
  local e = name and P.seen[name]
  if e then
    e.last = GetTime()
    -- Cata has exact removals; Retail/Forever infer the end only when the
    -- enemy is visible again after an observed cast.
    if not ns.Caps.combatLog then S.Shown(e, unit) end
  end
end

function P.OnUnitCast(unit, spellId)
  spellId = U.value(spellId)
  if not (S.spells[spellId or 0] and P.Enabled() and Watched(unit) and S.Hostile(unit)) then return end
  local name = S.UnitKey(unit)
  if not name then return end
  local _, class = U.call(UnitClass, unit)
  S.Hid(Note(name, U.value(class)), spellId)
end

function P.OnCombatLog()
  if not P.Enabled() then return end
  local _, sub, _, src, srcName, srcFlags, _, dst, dstName, dstFlags, _, id = CombatLogGetCurrentEventInfo()
  local spell = S.spells[id]
  if not spell then return end
  local guid, name, flags
  if sub == "SPELL_CAST_SUCCESS" then guid, name, flags = src, srcName, srcFlags
  elseif sub == "SPELL_AURA_APPLIED" or (sub == "SPELL_AURA_REMOVED" and spell.fades) then
    guid, name, flags = dst, dstName, dstFlags
  else return end
  if not (type(name) == "string" and S.HostileFlags(flags)) then return end
  if sub == "SPELL_AURA_REMOVED" then S.Shown(P.seen[name], nil, false, true)
  else
    local _, class = U.call(GetPlayerInfoByGUID, guid)
    S.Hid(Note(name, U.value(class)), id)
  end
end

local function Reset() wipe(P.seen) end
local handlers = {
  PLAYER_ENTERING_WORLD = Reset,
  ZONE_CHANGED_NEW_AREA = Reset,
  NAME_PLATE_UNIT_ADDED = function(_, unit) P.NoteUnit(unit) end,
  ARENA_OPPONENT_UPDATE = function(_, unit) P.NoteUnit(unit) end,
  UNIT_AURA = function(_, unit) P.NoteUnit(unit) end,
  PLAYER_TARGET_CHANGED = function() P.NoteUnit("target") end,
  PLAYER_FOCUS_CHANGED = function() P.NoteUnit("focus") end,
  UPDATE_MOUSEOVER_UNIT = function() P.NoteUnit("mouseover") end,
}
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = P.OnCombatLog
else
  handlers.UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, id) P.OnUnitCast(unit, id) end
end
U.Events(handlers, "pvp stealth")
U.Every(1, function()
  if not P.Enabled() then Reset(); return end
  for name, e in pairs(P.seen) do if GetTime() - e.last > 300 then P.seen[name] = nil end end
  if ns.Caps.combatLog or not next(P.seen) then return end
  for _, unit in ipairs({ "target", "focus", "mouseover" }) do P.NoteUnit(unit) end
  for i = 1, 5 do P.NoteUnit("arena" .. i) end
  for i = 1, 40 do P.NoteUnit("nameplate" .. i) end
end, "pvp stealth")
