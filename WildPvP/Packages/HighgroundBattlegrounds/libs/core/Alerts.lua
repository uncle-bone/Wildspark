local _, ns = ...
local U = ns.Util
local A = { categories = {}, pending = {}, last = {} }
ns.Alerts = A

-- One queue arbitrates sounds across features. Existing event cooldowns
-- still apply; a burst of sightings cannot drown out an objective warning.
for _, d in ipairs({
  { "capture", "Base capture", 5, true }, { "objective", "Objective changes", 5, true },
  { "resurrection", "Resurrection", 4, true }, { "go", "Kill window", 4 },
  { "sap", "Sap opportunity", 3, true }, { "bounty", "Bounty spotted", 2 },
  { "stealth", "Enemy stealth", 3 }, { "nearby", "Nearby enemy", 1 },
  { "lockon", "Target lock", 1 },
}) do
  A.categories[#A.categories + 1] = { key = d[1], label = d[2], priority = d[3], objective = d[4] }
end

function A.Settings()
  local db = ns.GetDB and ns.GetDB() or ns.Core.db
  if not db then return { mode = "everything", channels = {} } end
  if type(db.alerts) ~= "table" then db.alerts = {} end
  if type(db.alerts.channels) ~= "table" then db.alerts.channels = {} end
  return db.alerts
end

function A.Allowed(category, channel)
  local settings, definition = A.Settings()
  for _, d in ipairs(A.categories) do if d.key == category then definition = d end end
  if not definition then return false end
  local mode = settings.mode or "everything"
  if mode == "essential" and definition.priority < 2 then return false end
  if mode == "critical" and definition.priority < 4 then return false end
  if mode == "objectives" and not definition.objective then return false end
  if mode == "quiet" and channel == "sound" then return false end
  local channels = settings.channels[category]
  if type(channels) == "table" and channels[channel] == false then return false end
  return channel ~= "sound" or ns.Core.On("sound")
end

function A.SetMode(mode)
  if not ({ essential = true, everything = true, critical = true, objectives = true, quiet = true })[mode] then return false end
  A.Settings().mode = mode
  wipe(A.pending)
  return true
end

local lastSound, lastPriority = -math.huge, 0
function A.Flush()
  local now, best = GetTime(), nil
  for key, item in pairs(A.pending) do
    A.pending[key] = nil
    if item.sound and A.Allowed(item.category, "sound") and (not best or item.priority > best.priority) then best = item end
  end
  if best and (now - lastSound >= 1.5 or best.priority > lastPriority) then
    lastSound, lastPriority = now, best.priority
    best.sound()
  end
end

function A.Emit(category, key, text, sound, show)
  local now = GetTime()
  key = category .. ":" .. tostring(key or text or "event")
  if now - (A.last[key] or -math.huge) < 1 then return false end
  A.last[key] = now
  if text and A.Allowed(category, "text") then
    if show then show(text) else U.Say(text) end
  end
  local priority = 1
  for _, d in ipairs(A.categories) do if d.key == category then priority = d.priority end end
  A.pending[key] = { category = category, text = text, sound = sound, show = show, priority = priority }
  return true
end

-- Text is immediate. Sounds are collected briefly so simultaneous events
-- play only their highest-priority cue.
function U.Notify(category, key, text, sound, show)
  return A.Emit(category, key, text, sound, show)
end

function U.Warning(text, tone)
  if RaidNotice_AddMessage and RaidWarningFrame then
    local r, g, b = ns.Theme.Color(tone or "warning")
    RaidNotice_AddMessage(RaidWarningFrame, text, { r = r, g = g, b = b })
  else U.Say(text) end
end

U.Every(0.15, A.Flush, "alerts")
U.Every(60, function()
  for key, at in pairs(A.last) do if GetTime() - at > 60 then A.last[key] = nil end end
end, "alert cleanup")
