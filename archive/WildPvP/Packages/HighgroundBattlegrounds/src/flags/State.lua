local _, ns = ...
local Timers = ns.Timers
ns.Flags = {}
local Flags = ns.Flags

---------------------------------------------------------------------------
-- Flags window (Warsong Gulch, Twin Peaks, Eye of the Storm): who holds
-- each flag, their health, Focused/Brutal Assault stacks, time held.
-- Rows are secure buttons, usable in combat:
--   left-click = target, right-click = focus.
-- The macros never need changing: Blizzard puts flag carriers on the arena
-- unit tokens in battlegrounds, so "[@arena1,harm]" is always the enemy
-- carrier ("help" ours); the carrier's name (set out of combat) is the
-- fallback. Replaces Blizzard's carrier frames (ArenaEnemyFrames), which
-- are hidden in battlegrounds, like the quest tracker (both optional).
---------------------------------------------------------------------------

Flags.FROW_H, Flags.FTOP = Timers.THEME.flags.row, Timers.TOP
Flags.carriers = {} -- [team] = { name, since, dropped = time }
Flags.lastCarrier = {} -- [team] = name of whoever last picked up a flag

-- The enemy who last picked up your flag (they may have dropped it since).
function Flags.LastEnemyCarrier()
  return Flags.lastCarrier[Timers.Other(Timers.MyTeam())]
end
ns.LastEnemyCarrier = Flags.LastEnemyCarrier

Flags.pendingMacro = false

function Flags.FlagsEnabled()
  return Timers.DB() and ns.Core.On("flags") and ns.IsActive and ns.IsActive()
end

-- Flag announcements feed the carrier panel and the rogue sap calls
-- (core/SapCall.lua), so either one keeps them read.
function Flags.ReadChat()
  return Flags.FlagsEnabled() or (Timers.DB() and ns.Core.On("sapCall") and ns.IsActive and ns.IsActive()) or false
end

function Flags.InBG()
  local _, t = IsInInstance()
  return t == "pvp"
end

function Flags.FlagBG()
  local objective = Timers.Rules().objective
  return objective == "flag" or objective == "carry"
end

function Flags.Strip(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Chat: "The Horde flag was picked up by X!" (X is Alliance), "... dropped
-- by X!", "X captured the Horde flag!", "returned to its base";
-- Eye of the Storm: "X has taken the flag!" (team = X's team when known,
-- else the chat channel).
function Flags.OnChat(event, msg)
  if type(msg) ~= "string" or not Timers.plain(msg) then
    return
  end
  if ns.LocalizedChat then msg = ns.LocalizedChat(msg) end
  msg = Flags.Strip(msg)
  local now = GetTime()
  if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
    if msg:find("placed at their bases") or msg:find("wins") then
      wipe(Flags.carriers)
      wipe(Flags.lastCarrier)
    end
    return
  end
  local chanTeam = event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" and "A" or "H"
  local flag, who = msg:match("The (%a+) [Ff]lag was picked up by (.+)!")
  if who then
    local team = flag == "Alliance" and "H" or "A"
    Flags.carriers[team] = { name = who, since = now }
    Flags.lastCarrier[team] = who
    return
  end
  flag, who = msg:match("The (%a+) [Ff]lag was dropped by (.+)!")
  if who then
    local team = flag == "Alliance" and "H" or "A"
    Flags.carriers[team] = { dropped = now }
    return
  end
  who = msg:match("^(.+) has taken the flag!")
  if who then
    wipe(Flags.carriers)
    Flags.carriers[Timers.TeamOfName(who) or chanTeam] = { name = who, since = now }
    return
  end
  if msg:find("flag has been dropped") then
    -- One flag: whoever carried it dropped it (the channel is the
    -- carrier's character faction in cross-faction games).
    local team = Flags.carriers.A and Flags.carriers.A.name and "A"
      or Flags.carriers.H and Flags.carriers.H.name and "H" or chanTeam
    wipe(Flags.carriers)
    Flags.carriers[team] = { dropped = now }
    return
  end
  flag = msg:match("captured the (%a+) [Ff]lag")
  if flag then
    Flags.carriers[flag == "Alliance" and "H" or "A"] = nil
    return
  end
  if msg:find("captured the flag") or msg:find("flag has been reset") then
    wipe(Flags.carriers)
    return
  end
  flag = msg:match("The (%a+) [Ff]lag was returned")
  if flag then
    Flags.carriers[flag == "Alliance" and "H" or "A"] = nil
  end
end

-- Carrier unit right now: an arena token of the right reaction, else a
-- teammate's raid unit / any visible unit with that name.
function Flags.CarrierUnit(team, name)
  local ours = team == Timers.MyTeam()
  for i = 1, 4 do
    local u = "arena" .. i
    if ns.Util.read(UnitExists, u) then
      local harm = ns.Util.read(UnitCanAttack, "player", u)
      if harm ~= nil and (harm and not ours or not harm and ours) then
        return u
      end
    end
  end
  if name then
    local short = name:match("^[^-]+")
    local allies = ns.AllyUnits and ns.AllyUnits() or {}
    if ours and allies[short] then
      return allies[short]
    end
    for _, u in ipairs({ "target", "focus", "mouseover" }) do
      local n = ns.Util.read(UnitName, u)
      if n ~= nil and n == short then
        return u
      end
    end
  end
end

function Flags.SetMacros()
  if not Flags.frows then
    return
  end
  if InCombatLockdown() then
    Flags.pendingMacro = true
    return
  end
  Flags.pendingMacro = false
  for _, r in ipairs(Flags.frows) do
    local c = Flags.carriers[r.team]
    local name = c and c.name
    local react = r.team == Timers.MyTeam() and "help" or "harm"
    local conditions = {}
    for i = 1, 4 do
      conditions[#conditions + 1] = string.format("[@arena%d,%s] arena%d", i, react, i)
    end
    local cond = table.concat(conditions, "; ")
    local byName = name and (ns.Core.TargetMacro(name) .. "\n") or ""
    r:SetAttribute("macrotext1", byName .. "/target " .. cond)
    r:SetAttribute("macrotext2", (name and ("/focus " .. name .. "\n") or "") .. "/focus " .. cond)
    r.macroFor, r.macroTeam = name, r.team
  end
end
