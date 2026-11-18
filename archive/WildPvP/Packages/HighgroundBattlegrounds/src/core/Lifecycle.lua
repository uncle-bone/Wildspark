local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Main loop: the 0.25s tick while active, turning on and off with the
-- battleground. The tick runs the battleground engine (scoreboard, units,
-- nameplates, carriers, captures), then the kill order and its displays.
-- A build that leaves out the kill order (Highground Battlegrounds) has no
-- main panel, scope or target buttons: their stages and calls are skipped.
---------------------------------------------------------------------------

-- Each stage runs protected: one failing stage must not freeze the panel.
-- Errors are kept in HighgroundDB.errors (read after /reload) and in /hg err.
-- Returns only whether fn succeeded; see ns.Util.Guard for results and args.
function Core.Guard(stage, fn)
  return (ns.Util.Guard(stage, fn))
end

-- Stages after the live scans, in order: { guard name, Core function }.
-- The function is looked up each tick; a stage this build lacks is skipped.
Core.TICK_STAGES = {
  { "plates", "ScanPlates" }, -- core/Auras.lua
  { "capplates", "UpdateCapPlates" }, -- ui/CapPlates.lua
  { "healermarks", "UpdateHealerMarks" }, -- ui/HealerMarks.lua
  { "burstmarks", "UpdateBurstMarks" }, -- ui/BurstMarks.lua
  { "dock", "Dock" }, -- ui/Compact.lua
  { "score", "Recompute" }, -- core/Scoring.lua
  { "targetbtn", "UpdateTargetButton" }, -- ui/Actions.lua
  { "render", "Render" }, -- ui/Render.lua
}

local lastRosterPoll = 0

function Core.Tick()
  if not Core.active then
    return
  end
  if not Core.testMode then
    if Core.DetectMap() then
      Core.ObjectiveStart()
    end
    -- Poll the scoreboard too: UPDATE_BATTLEFIELD_SCORE doesn't always fire
    -- (e.g. in the starting area before gates open).
    local now = GetTime()
    if now - lastRosterPoll >= 2 then
      lastRosterPoll = now
      Core.Guard("roster", Core.RefreshRoster)
    end
    Core.Guard("carriers", Core.ScanCarrierTokens)
    Core.Guard("scan", Core.ScanUnits)
    Core.Guard("allies", Core.ScanAllyTargets)
    Core.Guard("capture", Core.ScanGroupCasts)
    Core.Guard("capture", Core.ExpireCaptures)
  end
  for _, stage in ipairs(Core.TICK_STAGES) do
    local fn = Core[stage[2]]
    if fn then Core.Guard(stage[1], fn) end
  end
  if Core.lastError and Core.subtitle then
    Core.subtitle:SetText(ns.Theme.Hex("danger") .. "error|r /hg err")
  end
end

-- Kill-order displays on and off (main panel, scope); none without them.
local function ShowPanel(on)
  if Core.frame then Core.frame:SetShown(on) end
end

local ticker, scoreTicker
function Core.SetActive(on)
  if on == Core.active then
    return
  end
  Core.active = on
  if on then
    Core.UpdateMe()
    if not Core.testMode then
      Core.ObjectiveStart()
    end
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      ShowPanel(Core.PriorityOn())
    end
    ticker = C_Timer.NewTicker(0.25, Core.Tick)
    if not Core.testMode then
      scoreTicker = C_Timer.NewTicker(5, Core.RequestScores)
      Core.RequestScores()
    end
    Core.Tick()
  else
    if ticker then ticker:Cancel() end
    if scoreTicker then scoreTicker:Cancel() end
    ticker, scoreTicker = nil, nil
    if Core.sniper then
      Core.sniper:Hide()
      Core.sniper.soundKey = nil
    end
    if Core.UpdateHealerMarks then Core.UpdateHealerMarks() end
    if InCombatLockdown() then
      Core.layoutPending = true
    else
      ShowPanel(false)
    end
  end
end


-- Team-size switches: bg10 (up to 10v10, Blitz included), bg15, bg40
-- (larger, 35v35 Ashran included). nil for a battleground Highground doesn't know.
function Core.SizeBracket(size)
  if not size then return nil end
  return size <= 10 and "bg10" or size <= 15 and "bg15" or "bg40"
end

function Core.TeamSize()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local _, _, _, _, _, _, _, inst = GetInstanceInfo()
  local blitz = ns.Caps.blitz and C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() or false
  local rated = not blitz and Core.IsRatedBG and Core.IsRatedBG() or false
  local bg = ns.ResolveBattleground(ui, inst, ns.CLIENT, blitz and "blitz" or rated and "rated" or "standard")
  return bg and bg.size
end

function Core.SizeOn()
  local bracket = Core.SizeBracket(Core.TeamSize())
  return not bracket or Core.On(bracket)
end

function Core.InRatedBG()
  local _, instanceType = IsInInstance()
  if instanceType ~= "pvp" or not Core.SizeOn() then
    return false
  end
  if Core.On("allBGs") then
    return true
  end
  if not C_PvP then return false end
  return (C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground())
    or (C_PvP.IsRatedMap and C_PvP.IsRatedMap())
    or (C_PvP.IsSoloRBG and C_PvP.IsSoloRBG())
    or false
end

-- Apply the Target recommendations switch to the secure main panel.
function Core.ApplyKillOrder()
  if InCombatLockdown() then
    Core.layoutPending = true -- applied when combat ends
    return
  end
  ShowPanel(Core.active and Core.PriorityOn())
  if Core.UpdateTargetButton then Core.UpdateTargetButton() end
end

function Core.CheckZone()
  if Core.testMode then
    return
  end
  local on = Core.InRatedBG()
  if not on then
    wipe(Core.enemies)
    Core.allyFaction = nil
    Core.currentBG, Core.currentProfile, Core.mapKey = nil, nil, nil
    Core.obj.mode, Core.obj.assaultStart = nil, nil
    ns.flagRespawnAt = nil
  end
  Core.SetActive(on)
end
