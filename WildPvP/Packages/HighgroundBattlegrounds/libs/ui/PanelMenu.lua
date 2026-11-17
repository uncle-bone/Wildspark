local _, ns = ...
local Core, Kit, Panels = ns.Core, ns.Kit, ns.PanelControls

-- Highground supplies its guided placement flow. Standalones unlock and
-- show their existing previews; the same menu can end the preview.
function Panels.Arrange()
  if InCombatLockdown() then return ns.Util.Say(Panels.Hint()) end
  Core.SetPanelsLocked(false)
  if ns.BattlegroundsPreview then
    if not ns.Timers.previewing then ns.BattlegroundsPreview.Start() end
  elseif ns.ArenaPreview then
    if not ns.Arena.preview and not ns.Arena.InArena() then ns.ArenaPreview() end
  elseif ns.NearbyPreview and not ns.Nearby.preview then
    ns.NearbyPreview()
  end
  ns.Util.Say(Panels.Hint())
end

local function Settings(page)
  if ns.Hub then ns.Hub.Open(page)
  elseif ns.StandaloneSettings then ns.StandaloneSettings.Open() end
end

function Panels.Items(key)
  local items = { Panels.MenuItem(), { text = "Arrange panels", run = Panels.Arrange,
    hint = InCombatLockdown() and "After combat" or nil } }
  local function Add(text, run) items[#items + 1] = { text = text, run = run } end
  local function EndPreview(run)
    items[#items + 1] = { text = "End preview", hint = InCombatLockdown() and "After combat" or nil,
      run = function()
        if InCombatLockdown() then return ns.Util.Say(Panels.Hint()) end
        run()
      end }
  end
  local page, label = "general", "Highground settings"
  if key == "enemies" then
    Add("Show 5 enemies", function() Core.SetRows(5) end)
    Add("Show 10 enemies", function() Core.SetRows(10) end)
    Add("Show all enemies", function() Core.SetRows(Core.MAX_ROWS) end)
  elseif key == "nearbyPoint" then
    page, label = "nearby", "Nearby settings"
    if ns.EnemyJournal then Add("Enemy journal", function() ns.EnemyJournal.Open() end) end
    Add("Clear recent sightings", function() ns.NearbyClear() end)
    if ns.Nearby.preview then EndPreview(function() ns.NearbyPreview() end) end
  elseif key == "arenaPoint" then
    label = "Arena settings"
    if ns.MatchHistory then Add("Match history", function() ns.MatchHistory.Open() end) end
    if ns.Arena.preview then EndPreview(function() ns.ArenaPreview() end) end
  else
    page, label = "timers", "Battleground settings"
    if key == "quickCallsPoint" or key == "flagsPoint" then page = "general" end
    if ns.ObjectiveCalls then Add("Team callouts", function() ns.ObjectiveCalls.Open() end) end
    if ns.MatchHistory then Add("Match history", function() ns.MatchHistory.Open() end) end
    if ns.Timers and ns.Timers.previewing and ns.BattlegroundsPreview then
      EndPreview(function() ns.BattlegroundsPreview.Stop() end)
    end
  end
  Add(label, function() Settings(page) end)
  return items
end

function Panels.ToggleMenu(anchor)
  if Kit.Dropdown.Open(anchor, Panels.Items(anchor.key), function(item) item.run() end,
    { width = (InCombatLockdown() and 350 or 220) * math.max(1, Core.FontScale()), onClose = Panels.RefreshGears }) then
    Kit.Dropdown.Select(0, true)
  end
  Panels.Refresh()
end
