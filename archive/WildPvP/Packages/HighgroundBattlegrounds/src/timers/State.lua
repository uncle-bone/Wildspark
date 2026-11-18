local _, ns = ...
ns.Timers = ns.Timers or {} -- ui/Windows.lua (the HUD windows) may come first
local Timers = ns.Timers

-- Battleground timers: base captures and resurrection waves, for both
-- teams, per location. Shown in the resurrection and objective windows and
-- on the map (map/Pins.lua layer).
--
-- Base captures: map POIs change icon when a base is assaulted (the
-- "contested" icon set Capping uses on this client). Assault -> countdown
-- (duration from the battleground rules); owner from the POI's factionID / icon /
-- how the contest ended.
--
-- Res waves use the configured period and an observed spirit-guide clock.
-- Sources, best first:
--   1. you are dead:  GetAreaSpiritHealerTime()       exact, your team
--   2. a teammate goes ghost -> alive                   exact (+-0.25s)
--   3. a base is captured: its graveyard starts its clock then  approx
--   4. enemy Spirit Guide spell in the combat log       exact, enemy team
--   5. an enemy dies, then is seen again: the wave was in between. Every
--      such interval votes; the clock is where the votes pile up   estimate
-- Graveyard positions are learned from where people come back to life and
-- saved per map for next time. Teammates running Highground share 1 and 5.

Timers.PREFIX = "HighgroundT"
-- Faction colors, as on Blizzard's own map: Alliance blue, Horde red, by
-- the team's side (cross-faction games included), not by ours/theirs.
-- Live theme colours: they follow a theme switch.
Timers.FACTION_TOKEN = { A = "factionA", H = "factionH" }
Timers.FACTION_COLOR = { A = ns.Theme.Rgb("factionA"), H = ns.Theme.Rgb("factionH") }
Timers.FACTION_TEAM = { [469] = "A", [67] = "H", [1] = "A", [0] = "H" }

Timers.plain = ns.Util.plain

-- Timers.DB and Timers.Clock: ui/Windows.lua.
function Timers.Rules()
  return ns.GetBGRules and ns.GetBGRules() or {}
end

function Timers.RulesKey()
  local bg = ns.GetBG and ns.GetBG()
  return bg and bg.rulesKey
end

-- Configured period, unless this match's exact waves showed another one.
function Timers.WavePeriod()
  local res = Timers.Rules().resurrection
  return Timers.periodOverride or (res and res.period)
end

function Timers.Enabled()
  return Timers.DB() and ns.Core.On("timers")
end

Timers.stats = { waves = 0, votes = 0, guide = 0, caps = 0, sent = 0, recv = 0 }

-- Guarded call; failures land in Util.GuardStats and HighgroundDB.errors.
Timers.Try = ns.Util.Guard

-- Failures of the battleground windows (stages named "timers ...", "flags",
-- "arena", "nearby"): count and one of the messages, or nil.
local OWN = { timers = true, flags = true, arena = true, nearby = true }
function Timers.Errors()
  local n, first = 0, nil
  for stage, st in pairs(ns.Util.GuardStats) do
    if OWN[stage:match("^%a+")] then
      n = n + st.errors
      if not first or st.lastError < first then first = st.lastError end
    end
  end
  if n > 0 then return n, first end
end

Timers.MyTeam = ns.Util.MyTeam

function Timers.Other(team)
  return team == "A" and "H" or "A"
end

-- Team of a player named in a battleground announcement. Cross-faction
-- games announce on the character's faction channel, so the channel does
-- not tell the team; your group and the scoreboard's enemies do.
function Timers.TeamOfName(name)
  if type(name) ~= "string" or not Timers.plain(name) then return nil end
  local short = name:match("^[^-]+")
  if short == UnitName("player") then return Timers.MyTeam() end
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, raid and n or math.max(n - 1, 0) do
    local member = ns.Util.read(UnitName, (raid and "raid" or "party") .. i)
    if member ~= nil and member == short then return Timers.MyTeam() end
  end
  if ns.EnemyKeyByName and ns.EnemyKeyByName(name) then return Timers.Other(Timers.MyTeam()) end
end

function Timers.MapID()
  return ns.CurrentMapID and ns.CurrentMapID()
end

-- Where a unit is: coordinates when the client gives them, else its area
-- (sub-zone) and that area's anchor on the map (map/Areas.lua).
-- A zone-wide area name ("Twin Peaks") doesn't identify a graveyard: drop it.
function Timers.Loc(unit, name)
  local m = Timers.MapID()
  if m and ns.Locate then
    local x, y, area, how = ns.Locate(m, unit, name)
    if area and ns.IsZoneName and ns.IsZoneName(m, area) then
      area = nil
    end
    return x, y, area, how
  end
end

function Timers.XY(unit)
  local m = Timers.MapID()
  if m and ns.UnitXY then
    return ns.UnitXY(m, unit)
  end
end

function Timers.Place(x, y)
  return ns.Place and ns.Place(x, y) or "?"
end

-- Time left, to the nearest second: "42s", "1:15" (Util.Clock).

---------------------------------------------------------------------------
-- State (wiped when the map changes)
---------------------------------------------------------------------------
Timers.nodes = {} -- [poiName] = { x, y, icon, owner, assault, capStart, capEnd }
Timers.gys = {} -- list of { team, x, y, label, wave, conf, bins, votes, node }
Timers.guideGY = {} -- [spirit guide GUID] = gy

Timers.ghost, Timers.pendingRez, Timers.lastGuide, Timers.outbox, Timers.track = {}, {}, {}, {}, {}

Timers.gameGYs = {} -- [mapID] = { {name, x, y} } | false: the game's own graveyard list
