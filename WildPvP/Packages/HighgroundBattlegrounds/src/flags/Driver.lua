local _, ns = ...
local Timers = ns.Timers
local Flags = ns.Flags
local Util, Core, Guard = ns.Util, ns.Core, ns.Util.Guard

-- Blizzard's quest tracker and carrier frames, hidden in battlegrounds.
local trackerHidden = false
local arenaHidden
function Flags.Tracker()
  return WatchFrame or ObjectiveTrackerFrame
end
function Flags.ApplyBlizzard()
  local db = Timers.DB()
  local inBG = Flags.InBG()
  local tr = Flags.Tracker()
  if tr then
    local hide = inBG and ns.IsActive and ns.IsActive() and db and Core.On("hideTracker")
    if hide and tr:IsShown() then
      if InCombatLockdown() then
        tr:SetAlpha(0)
      else
        tr:Hide()
        tr:SetAlpha(1)
      end
      trackerHidden = true
    elseif not hide and trackerHidden then
      tr:SetAlpha(1)
      if not InCombatLockdown() then
        trackerHidden = false
        tr:Show()
        if tr == WatchFrame and WatchFrame_Update then
          pcall(WatchFrame_Update, WatchFrame)
        end
      end
    end
  end
  local af = ArenaEnemyFrames
  if af then
    local hide = inBG and Flags.FlagsEnabled() and db and Core.On("hideCarrierFrames") and Flags.FlagBG() and Flags.flagWin and Flags.flagWin:IsShown()
    if hide then
      if af:IsShown() then
        arenaHidden = arenaHidden or { shown = true, alpha = af:GetAlpha() }
        if InCombatLockdown() then
          af:SetAlpha(0)
        else
          af:Hide()
        end
      end
    elseif arenaHidden then
      af:SetAlpha(arenaHidden.alpha)
      if not InCombatLockdown() then
        local shown = arenaHidden.shown
        arenaHidden = nil
        if shown then af:Show() end
      end
    end
  end
end

local hooked = {}
function Flags.Hook()
  local tr = Flags.Tracker()
  if tr and not hooked.tr then
    hooked.tr = true
    tr:HookScript("OnShow", function()
      if Flags.InBG() then
        Flags.ApplyBlizzard()
      end
    end)
  end
  if ArenaEnemyFrames_UpdateVisible and not hooked.arena then
    hooked.arena = true
    hooksecurefunc("ArenaEnemyFrames_UpdateVisible", Flags.ApplyBlizzard)
  end
end

local function OnChat(event, msg)
  if Flags.ReadChat() and Flags.InBG() and Flags.FlagBG() then Guard("flags chat", Flags.OnChat, event, msg) end
end
local function OnWorld(event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    wipe(Flags.carriers)
    wipe(Flags.lastCarrier)
  end
  Flags.Hook()
  Guard("flags blizzard", Flags.ApplyBlizzard)
  if event == "PLAYER_REGEN_ENABLED" and Flags.pendingMacro then
    Flags.SetMacros()
  end
end
local handlers = {
  CHAT_MSG_BG_SYSTEM_ALLIANCE = OnChat, CHAT_MSG_BG_SYSTEM_HORDE = OnChat, CHAT_MSG_BG_SYSTEM_NEUTRAL = OnChat,
}
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
  "ADDON_LOADED" }) do
  handlers[ev] = OnWorld
end
Util.Events(handlers, "flags events")
Util.Every(0.25, function()
  if Timers.previewing then return end -- sample carriers (timers/Driver.lua)
  Guard("flags", Flags.UpdateFlags, GetTime())
  Guard("flags blizzard", Flags.ApplyBlizzard)
end, "flags")
ns.Test = ns.Test or {}
ns.Test.flags = { carriers = Flags.carriers, lastCarrier = Flags.lastCarrier, OnChat = Flags.OnChat, rows = function()
  return Flags.frows
end }
