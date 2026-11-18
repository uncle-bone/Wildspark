local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Sap calls (rogues, Warsong Gulch and Twin Peaks): when the enemy flag
-- carrier or an enemy healer dies, they come back out of combat at their
-- graveyard, where a sap keeps them out of the fight. The carrier is
-- whoever last picked up your flag (flags/State.lua); healers come from the
-- known spec. One raid warning + sound per death.
---------------------------------------------------------------------------
Core.SAP_MAPS = { warsong_gulch = true, twin_peaks = true }
Core.SAP_REPEAT = 10 -- seconds: a death seen twice (combat log + unit scan) calls once

function Core.SapReason(e)
  if Core.me.class ~= "ROGUE" or not (Core.currentBG and Core.SAP_MAPS[Core.currentBG.id]) then
    return nil
  end
  local fc = ns.LastEnemyCarrier and ns.LastEnemyCarrier()
  if fc and Core.Canon(fc) == e.key then
    return "FC"
  end
  if Core.IsHealer(e) then
    return "healer"
  end
end

-- Seconds until the enemy team's next resurrection wave, when known.
-- Reads timers/ (loaded later) at call time; nil without it.
local function EnemyWave(now)
  local T = ns.Timers
  if not (T and T.PickWaves) then return nil end
  local ok, _, theirs = pcall(T.PickWaves, now)
  return ok and theirs and theirs[2] - now or nil
end

function Core.SapCall(e)
  if not (Core.db and Core.On("sapCall")) then return end
  local reason = Core.SapReason(e)
  local now = GetTime()
  if not reason or (e.sapCalledAt and now - e.sapCalledAt < Core.SAP_REPEAT) then return end
  e.sapCalledAt = now
  local name = (e.display or e.key or "?"):match("^[^-]+")
  local wave = EnemyWave(now)
  local msg = string.format("SAP %s (%s) at their graveyard%s", name, reason,
    wave and wave > 0 and string.format(" - res in %ds", wave + 0.5) or "")
  if ns.Util.Notify then
    ns.Util.Notify("sap", e.key, msg, ns.Util.AlertSound, function(text) ns.Util.Warning(text, "gold") end)
  else
  if RaidNotice_AddMessage and RaidWarningFrame then
    local r, g, b = ns.Theme.Color("gold")
    RaidNotice_AddMessage(RaidWarningFrame, msg, { r = r, g = g, b = b })
  end
  if Core.On("sound") then
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
  end
  return msg
end
