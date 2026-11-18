local _, ns = ...
local Timers, Flags, Kit, Theme, Core = ns.Timers, ns.Flags, ns.Kit, ns.Theme, ns.Core

---------------------------------------------------------------------------
-- /hgbg test: the resurrection, objective and flag carrier windows with
-- sample rows (those switched on), to place them outside battlegrounds and
-- out of combat. Click or type again to stop; a battleground starting ends
-- it (timers/Driver.lua).
---------------------------------------------------------------------------
local Preview = {}
ns.BattlegroundsPreview = Preview

local SAMPLE_CARRIERS = { mine = { "Aldric", "PALADIN", 0.82, "x2  0:41" }, theirs = { "Vexa", "ROGUE", 0.31, "x2  0:37" } }

local function ResurrectionRows(me, them)
  return {
    { tag = "YOU", color = Timers.TeamColor(me), text = "Stables", left = 12, total = 30 },
    { tag = "OURS", color = Timers.TeamColor(me), text = "Farm", left = 12, total = 30 },
    { tag = "THEIRS", color = Timers.TeamColor(them), text = "Blacksmith", left = 23, total = 30, est = true },
  }
end

local function ObjectiveRows(me, them)
  local name = { A = "Alliance", H = "Horde" }
  return {
    { tag = "WIN", color = Timers.TeamColor(me), frac = 0.72, time = "3:10", text = name[me] .. "  1500-1180" },
    { tag = "CAP", color = Timers.TeamColor(them), text = "Lumber Mill", left = 38, total = 60 },
    { tag = "CAPPING", color = Timers.TeamColor(them), text = "Vexa  Gold Mine", left = 4, total = 8 },
  }, Timers.Hex(Timers.TeamColor(me)) .. "1080|r  " .. Timers.Hex(Timers.TeamColor(them)) .. "940|r"
end

-- Sample carriers in the flag window (its rows are secure: out of combat).
local function ShowCarriers(me, them)
  Flags.BuildFlags()
  if not Flags.flagWin then return end
  wipe(Flags.carriers)
  for _, r in ipairs(Flags.frows) do
    local s = SAMPLE_CARRIERS[r.side]
    r.team = r.side == "mine" and me or them
    r.tag:SetText(r.side == "mine" and "ALLY" or "ENEMY")
    Theme.Paint(r.tag, Timers.TeamColor(r.team))
    Kit.ClassIcon(r.icon, s[2])
    r.name:SetText(s[1])
    r.bar:SetValue(s[3])
    Timers.BarColor(r.bar, Timers.TeamColor(r.team), Timers.BAR_SEEN)
    r.right:SetText(s[4])
    Theme.Paint(r.right, s[3] < 0.35 and "danger" or "text")
  end
  -- No real carriers: the rows' macros fall back to the arena tokens.
  Flags.SetMacros()
  Flags.flagWin:SetAlpha(1)
  Timers.SecureShow(Flags.flagWin)
end

-- Secure carrier rows only show and hide out of combat.
function Preview.Allowed()
  return not (InCombatLockdown() or Flags.InBG())
end

function Preview.Start()
  if not Preview.Allowed() then return false end
  Timers.previewing = true
  local me = Timers.MyTeam()
  local them = Timers.Other(me)
  local res, obj = Timers.Windows()
  if Core.On("timers") then
    Timers.ShowRows(res, ResurrectionRows(me, them))
    if Core.On("objectives") then Timers.ShowRows(obj, ObjectiveRows(me, them)) end
  end
  if Core.On("flags") then ShowCarriers(me, them) end
  if ns.QuickCalls then ns.QuickCalls.Update() end
  return true
end

function Preview.Stop()
  if InCombatLockdown() then return false end
  Timers.previewing = nil
  Timers.HideWindows()
  Timers.SecureHide(Flags.flagWin)
  if ns.QuickCalls then ns.QuickCalls.Update() end
  return true
end

-- Returns whether the preview is showing now, and whether that changed.
function Preview.Toggle()
  if Timers.previewing then
    local stopped = Preview.Stop()
    return not stopped, stopped
  end
  local started = Preview.Start()
  return started, started
end
