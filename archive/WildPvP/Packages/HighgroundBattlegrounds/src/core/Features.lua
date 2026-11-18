local _, ns = ...
local Core = ns.Core

-- Feature switches, tuning reset and test mode: one place that applies a
-- change and its side effects, for the settings pages and slash commands.

-- Side effects of turning a feature on or off (runtime lookups: these live in ui/).
local EFFECTS = {
  compact = function(on) if ns.SetCompact then ns.SetCompact(on) end end,
  allBGs = function() Core.CheckZone() end,
  minimap = function() if ns.MinimapButton then ns.MinimapButton.Apply() end end,
  killorder = function() Core.ApplyKillOrder() end,
  quickCalls = function() if ns.QuickCalls then ns.QuickCalls.Update() end end,
}
EFFECTS.quickCallsDestinations = EFFECTS.quickCalls
EFFECTS.quickCallsRoutes = EFFECTS.quickCalls

-- Set a General-page switch. Returns the new value.
function Core.SetFeature(key, on)
  on = on and true or false
  Core.db[key] = on
  local effect = EFFECTS[key] or (key:match("^bg%d+$") and EFFECTS.allBGs)
  if effect then effect(on) end
  local Options = ns.Options
  if Options and Options.RefreshFeatures then Options.RefreshFeatures() end
  if Options and Options.PointsChanged then Options.PointsChanged() end
  if ns.Standalone then ns.Standalone.Refresh() end -- a standalone addon's page
  return on
end

-- Set a behavior option or a point value (a standalone addon's settings
-- page). Returns whether it was saved, and why not.
local function Tune(kind, key, value)
  local ok, err = Core.SetTuning(kind, key, value)
  if ns.Standalone then ns.Standalone.Refresh() end
  return ok, err
end
function Core.SetOption(key, value) return Tune("option", key, value) end
function Core.SetPoint(key, value) return Tune("point", key, value) end

-- Back to default points, weights, spec ratings and behavior options.
-- Feature switches, appearance and tracking choices are kept.
function Core.ResetTuning()
  Core.db.specRatings = {}
  wipe(Core.profileCache)
  Core.db.points, Core.db.weights = {}, {}
  for _, def in ipairs(ns.OptionsConfig.behavior) do Core.db[def.key] = def.def end
  Core.BuildCurve()
end

-- Leave the /hg test preview.
function Core.StopTest()
  if not Core.testMode then return false end
  Core.testMode = false
  Core.SetActive(false)
  wipe(Core.enemies)
  Core.CheckZone()
  return true
end
