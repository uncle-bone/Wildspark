local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Saved variables: create HighgroundDB / HighgroundCharDB (a standalone
-- addon's: ns.SAVED_VARIABLE and its CharDB), fill defaults,
-- reset damaged values (Core.ValidateSaved, core/Settings.lua) and run the
-- one-time upgrades. Called once from ADDON_LOADED (core/Events.lua).
---------------------------------------------------------------------------

-- Old account-wide dialog positions -> HighgroundDB.windows[key]
-- (ui/kit/Dialog.lua). Copies are marked legacy and refreshed each load
-- while the module still saves the old key; the first Kit.SavePoint
-- replaces the copy, after which the old key is ignored.
Core.LEGACY_WINDOWS = { bountyPoint = "bounty", macroPoint = "macros", hubPoint = "hub" }

local function Versioned(db, field, version, fn)
  if (db[field] or 1) < version then
    fn(db)
    db[field] = version
  end
end

local function MigrateWindows(db)
  for legacy, key in pairs(Core.LEGACY_WINDOWS) do
    local p = db[legacy]
    if type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
      and type(p[3]) == "number" and type(p[4]) == "number" then
      if type(db.windows) ~= "table" then db.windows = {} end
      local current = db.windows[key]
      if current == nil or (type(current) == "table" and current.legacy) then
        db.windows[key] = { p[1], p[2], p[3], p[4], legacy = true }
      end
    end
  end
end

-- Per-character window positions, seeded once from the old account-wide
-- ones so an existing layout doesn't move.
local function SeedPositions(db, pos)
  if pos.seeded then return end
  for _, key in ipairs(Core.POSITION_KEYS) do
    if pos[key] == nil and type(db[key]) == "table" then
      pos[key] = { unpack(db[key]) }
    end
  end
  pos.seeded = true
end

local ACCOUNT = ns.SAVED_VARIABLE or "HighgroundDB"
local CHARACTER = ACCOUNT:gsub("DB$", "CharDB")

function Core.LoadSaved()
  Core.firstInstall = type(_G[ACCOUNT]) ~= "table"
  local db = type(_G[ACCOUNT]) == "table" and _G[ACCOUNT] or {}
  _G[ACCOUNT] = db
  Core.db = db
  if Core.firstInstall then
    ns.ApplyFirstRunDefaults(db)
    if not ns.SAVED_VARIABLE then db.locked = true end
  end
  for k, v in pairs(Core.DEFAULTS) do
    if db[k] == nil then
      db[k] = type(v) == "table" and {} or v
    end
  end
  Core.ValidateSaved(db)
  ns.InitializeUIScale()
  for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
    if type(profile) == "table" and type(profile.points) == "table" then ns.NormalizePointSettings(profile.points) end
  end
  Versioned(db, "battlegroundScopeVersion", 2, function()
    -- Enable unrated matches on upgrades, including saved setups that can
    -- load automatically on entry. Later scope choices survive reloads.
    db.allBGs = true
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
      local setup = type(profile) == "table" and profile.setup
      if type(setup) == "table" and type(setup.features) == "table" then setup.features.allBGs = true end
    end
  end)
  Versioned(db, "sniperVersion", 4, function()
    db.sniperY = -62 -- scope sits on the upper torso
  end)
  Versioned(db, "soundVersion", 2, function()
    db.sniperSound = 1 -- custom lock-on sound is the new default
  end)
  Versioned(db, "rowsVersion", 2, function()
    -- Rows used to default to 10: show the whole enemy team instead.
    if db.rows == 10 then db.rows = Core.MAX_ROWS end
  end)
  Versioned(db, "gyLearnedVersion", 2, function()
    -- Start areas learned before the side was confirmed may carry the
    -- wrong team (cross-faction games); they are relearned on release.
    for _, list in pairs(type(db.gyLearned) == "table" and db.gyLearned or {}) do
      if type(list) == "table" then
        for i = #list, 1, -1 do
          if type(list[i]) == "table" and list[i].fromPlace then table.remove(list, i) end
        end
      end
    end
  end)
  MigrateWindows(db)
  Core.pos = type(_G[CHARACTER]) == "table" and _G[CHARACTER] or {}
  _G[CHARACTER] = Core.pos
  SeedPositions(db, Core.pos)
  return db
end
