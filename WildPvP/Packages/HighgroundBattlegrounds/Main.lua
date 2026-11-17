local _, ns = ...
local Core, Util, Preview = ns.Core, ns.Util, ns.BattlegroundsPreview

---------------------------------------------------------------------------
-- Highground Battlegrounds: Highground's battleground engine, timers, flag
-- carriers and map intel (src/), without the kill order. /hgbg and the
-- settings page (start-up: libs/standalone/Main.lua).
---------------------------------------------------------------------------

-- /hgbg off: stay idle in every battleground (HighgroundBattlegroundsDB.off).
-- Wraps the engine's check (core/Lifecycle.lua); CheckZone looks it up per call.
local inBattleground = Core.InRatedBG
function Core.InRatedBG()
  return not (Core.db and Core.db.off) and inBattleground()
end

local function SetOn(on)
  Core.db.off = not on or nil
  Core.CheckZone()
  Util.Say("battleground tools " .. (on and "on" or "OFF"))
end

local function Status()
  if Core.db.off then return "off: /hgbg on to turn on" end
  local bg = ns.GetBG()
  if Core.active then return "on in " .. (bg and bg.name or GetInstanceInfo() or "this battleground") end
  return "on: waits for a battleground (settings choose which: /hgbg config)"
end

local function TogglePreview()
  local on, changed = Preview.Toggle()
  if not changed then
    Util.Say("no preview changes in combat or in a battleground")
  else
    Util.Say(on and "preview ON: drag the windows into place, /hgbg test again to hide" or "preview off")
  end
end

ns.Standalone.Start({
  command = "HIGHGROUNDBATTLEGROUNDS",
  slash = { "/hgbg", "/hgbattlegrounds" },
  help = {
    "/hgbg calls [incoming|help|clear|escort]: draft a team callout",
    "/hgbg history: match journal and objective timelines",
    "/hgbg: status",
    "/hgbg on, /hgbg off: turn the battleground tools on or off",
    "/hgbg test: preview the resurrection, objective and flag carrier windows",
    "/hgbg reset: windows back to their default spots",
    "/hgbg timers, /hgbg intel: what the timers and the map see this match",
  },
  commands = {
    history = function() ns.MatchHistory.Open() end,
    calls = function(text) ns.ObjectiveCalls.Command(text) end,
    on = function() SetOn(true) end,
    off = function() SetOn(false) end,
    test = TogglePreview,
    reset = function()
      ns.TimersWindowReset()
      Util.Say("windows reset")
    end,
    timers = function() Util.Say(ns.TimersStatus()) end,
    intel = function() Util.Say(ns.IntelStatus()) end,
  },
  default = function(cmd)
    if cmd == "" then return Util.Say(Status()) end
    Util.Say("unknown command: /hgbg help lists them")
  end,
  settings = {
    hint = "Join a battleground and these panels appear automatically. Preview them here to see how they work and move them into place.",
    basic = { "allBGs", "timers", "flags", "intel", "quickCalls", "quickCallsDestinations", "quickCallsRoutes" },
    keys = { "allBGs", "bg10", "bg15", "bg40", "timers", "quickCalls", "quickCallsDestinations", "quickCallsRoutes",
      "objectives", "objectiveOverview", "capAlert", "capPlates", "dieAlert",
      "dieHpPct", "dieResMax", "dieResMin", "flags", "hideCarrierFrames", "sapCall", "hideTracker",
      "intel", "intelShare", "sound" },
    buttons = {
      { "Preview windows", TogglePreview },
      { "Reset positions", function() ns.TimersWindowReset() end, advanced = true },
    },
  },
})
