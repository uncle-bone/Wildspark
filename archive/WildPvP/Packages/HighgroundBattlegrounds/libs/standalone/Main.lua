local addon, ns = ...
local Core, Util, Theme = ns.Core, ns.Util, ns.Theme

---------------------------------------------------------------------------
-- Start-up of a standalone addon, from its own Main.lua:
--   ns.Standalone.Start({
--     command = "HIGHGROUNDMACROS", slash = { "/hgm", "/hgmacros" },
--     help = { "/hgm pve: ..." },           -- lines for /<cmd> help
--     commands = { name = fn(rest) },       -- /<cmd> name rest
--     default = fn(cmd, rest),              -- anything else (cmd may be "")
--     settings = { hint, keys, buttons },   -- standalone/Settings.lua page
--     onLoad = fn(db),                      -- after the saved variable loads
--   })
-- Every addon also gets /<cmd> help, theme NAME and config. On standby
-- (Highground loaded, standalone/Bootstrap.lua) the command only points to
-- /hg, and nothing else starts.
---------------------------------------------------------------------------
local Standalone = {}
ns.Standalone = Standalone

function Standalone.Refresh()
  if ns.StandaloneSettings then ns.StandaloneSettings.Refresh() end
end

local function Register(spec, handler)
  for i, slash in ipairs(spec.slash) do _G["SLASH_" .. spec.command .. i] = slash end
  SlashCmdList[spec.command] = function(msg) Util.Guard("slash", handler, msg) end
end

local function Standby(spec)
  local text = (ns.STANDBY_LABEL or "Highground") .. " is loaded and already has this: use "
    .. (ns.STANDBY_COMMAND or "/hg") .. ". You can disable " .. ns.LABEL .. "."
  Register(spec, function() Util.Say(text) end)
  -- Once per session; Util.Events registers nothing on standby.
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Util.Say(text)
  end)
end

function Standalone.Start(spec)
  Standalone.spec = spec
  if ns.STANDBY then return Standby(spec) end
  local first = spec.slash[1]
  local help = {}
  for _, line in ipairs(spec.help or {}) do help[#help + 1] = line end
  help[#help + 1] = first .. " alerts: alert presets and channels"
  help[#help + 1] = first .. " config: settings"
  help[#help + 1] = first .. " theme NAME: " .. table.concat(Theme.Names(), ", ")
  Register(spec, function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "help" or cmd == "?" then
      for _, line in ipairs(help) do Util.Say(line) end
    elseif cmd == "theme" then
      Util.Say(Theme.Use(rest:lower()) and ("theme: " .. rest:lower()) or "no such theme")
    elseif cmd == "alerts" and ns.Alerts then
      ns.Alerts.Open()
    elseif cmd == "config" and ns.StandaloneSettings then
      ns.StandaloneSettings.Open()
    elseif spec.commands and spec.commands[cmd] then
      spec.commands[cmd](rest)
    elseif spec.default then
      spec.default(cmd, rest)
    else
      for _, line in ipairs(help) do Util.Say(line) end
    end
  end)
  Util.Events({
    ADDON_LOADED = function(_, name)
      if name ~= addon then return end
      local db = _G[ns.SAVED_VARIABLE]
      local fresh = type(db) ~= "table"
      db = type(db) == "table" and db or {}
      if fresh then ns.ApplyFirstRunDefaults(db) end
      _G[ns.SAVED_VARIABLE] = db
      Core.db = db
      Theme.Sync()
      if spec.settings and ns.StandaloneSettings then ns.StandaloneSettings.Page(spec.settings) end
      if spec.onLoad then spec.onLoad(db) end
    end,
  }, "load")
end
