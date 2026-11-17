local _, ns = ...
local Core = ns.Core

-- One saved scale for every HUD panel. Protected panels only resize out of
-- combat; the latest requested scale is applied on PLAYER_REGEN_ENABLED.
function ns.InitializeUIScale()
  if not Core.db.uiScaleVersion then
    if Core.db.scale == 1 then Core.db.scale = Core.THEME.scale.default end
    Core.db.uiScaleVersion = 1
  end
end

function ns.ApplyUIScale()
  if not Core.db then return false end
  local applied = not InCombatLockdown()
  if applied then
    if Core.frame then Core.frame:SetScale(Core.db.scale * (Core.PanelScale and Core.PanelScale("main") or 1)) end
    if ns.TimersApplyScale then ns.TimersApplyScale() end
  end
  if ns.RefreshUIScaleOption then ns.RefreshUIScaleOption() end
  return applied
end

function ns.SetUIScale(value)
  value = tonumber(value)
  if not Core.db or not value or value ~= value or math.abs(value) == math.huge then return false end
  Core.db.scale = math.max(Core.THEME.scale.min, math.min(Core.THEME.scale.max, value))
  return ns.ApplyUIScale()
end

-- Execute curve (retail secret health): only its alpha is read (ui/Health.lua),
-- 1 below executePct and 0 above.
function Core.BuildCurve()
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then
    return
  end
  local r, g, b = ns.Theme.Color("kill")
  Core.execCurve = C_CurveUtil.CreateColorCurve()
  Core.execCurve:SetType(Enum.LuaCurveType.Step)
  Core.execCurve:AddPoint(0, CreateColor(r, g, b, 1))
  Core.execCurve:AddPoint(Core.db.executePct, CreateColor(r, g, b, 0))
end
