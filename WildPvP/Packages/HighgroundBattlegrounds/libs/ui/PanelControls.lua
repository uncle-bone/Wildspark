local _, ns = ...
local Core, Kit, Theme, Motion = ns.Core, ns.Kit, ns.Theme, ns.Motion
local Panels = { windows = {} }
ns.PanelControls = Panels

function Panels.Locked()
  return Core.db and Core.db.locked == true
end

function Panels.Action()
  return Panels.Locked() and "Unlock panels" or "Lock panels"
end

function Panels.Hint()
  if InCombatLockdown() then return "Panels can be moved after combat ends." end
  return Panels.Locked() and "Unlock panels to drag their headers."
    or "Drag panel headers to move. Lock panels when done."
end

function Panels.Tooltip()
  return { { Panels.Locked() and "Panels locked" or "Panels unlocked", "text" },
    { Panels.Hint(), "textMuted", true },
    { "Use any panel cogwheel to lock or unlock all panels.", "textMuted", true } }
end

-- Unlocking restores drag handles without changing the saved appearance.
function ns.ShowPanelHeaders()
  return Core.db and not Panels.Locked()
end

function Core.SetPanelsLocked(locked)
  if not Core.db then return end
  Core.db.locked = locked == true
  if ns.ApplyOpacity then ns.ApplyOpacity() end
  Panels.Refresh()
end

function Panels.Toggle()
  GameTooltip_Hide()
  Core.SetPanelsLocked(not Panels.Locked())
  ns.Util.Say((Panels.Locked() and "Panels locked. " or "Panels unlocked. ") .. Panels.Hint())
end

function Panels.MenuItem()
  return { text = Panels.Action(), run = Panels.Toggle }
end

-- SecureHide leaves a shown frame at alpha zero in combat. It must not
-- own the column's only cog, or leave an invisible button catching clicks.
function Panels.Visible(w)
  if not w:IsVisible() then return false end
  local parent = w
  while parent do
    if parent:GetAlpha() <= 0 then return false end
    parent = parent:GetParent()
  end
  return true
end

local function DockMembers()
  local members, head = {}
  if Core.compact then
    for _, name in ipairs(Core.DOCK or {}) do
      local w = _G[name]
      if w and w.gear then
        members[w] = true
        if not head and Panels.Visible(w) then head = w end
      end
    end
  end
  return members, head
end

function Panels.RefreshGears()
  local members, head = DockMembers()
  local groupHover = false
  for w in pairs(members) do
    if Panels.Visible(w) and (w:IsMouseOver() or w.gear:IsMouseOver()) then groupHover = true end
  end
  local menu = Kit.Dropdown.Frame()
  for _, w in ipairs(Panels.windows) do
    local gear = w.gear
    local shown = Panels.Visible(w) and (not members[w] or w == head)
    if gear.available ~= shown or gear:IsShown() ~= shown then
      gear.available = shown
      gear:EnableMouse(shown)
      gear:SetShown(shown)
      if not shown then
        Motion.Stop(gear)
        Theme.Tint(gear:GetNormalTexture(), "textMuted")
        if GameTooltip:GetOwner() == gear then GameTooltip_Hide() end
        if menu and menu.anchor == gear then Kit.Dropdown.Hide() end
      end
    end
    if shown then
      local hover = members[w] and groupHover or w:IsMouseOver() or gear:IsMouseOver()
      local open = menu and menu:IsShown() and menu.anchor == gear
      Motion.Alpha(gear, (not Panels.Locked() or hover or open) and 1 or Theme.Alpha("panelCog"))
    end
  end
end

function Panels.Refresh()
  Panels.RefreshGears()
  if ns.Hub and ns.Hub.RefreshHome then ns.Hub.RefreshHome() end
end

function Panels.Layout(w, height, padding)
  local gear = w.gear
  local size = math.min(Theme.Size("control"), height - 2)
  gear:SetSize(size, size)
  gear:ClearAllPoints()
  gear:SetPoint("RIGHT", w, "TOPRIGHT", -padding, -height / 2)
  local icon = gear:GetNormalTexture()
  icon:ClearAllPoints()
  icon:SetPoint("CENTER")
  icon:SetSize(math.min(20, size - 4), math.min(20, size - 4))
end

local watcher
function Panels.Register(w, key)
  if w.gear then return w.gear end
  local gear = CreateFrame("Button", nil, w)
  w.gear, gear.panel, gear.key = gear, w, key or w.key
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  Theme.Tint(gear:GetNormalTexture(), "textMuted")
  gear:SetAlpha(Panels.Locked() and Theme.Alpha("panelCog") or 1)
  gear:SetScript("OnEnter", function(self)
    Theme.Tint(self:GetNormalTexture(), "white")
    Motion.Alpha(self, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Theme.TipLine(GameTooltip, "Panel controls", "text")
    for _, line in ipairs(Panels.Tooltip()) do Theme.TipLine(GameTooltip, line[1], line[2], line[3]) end
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function(self)
    Theme.Tint(self:GetNormalTexture(), "textMuted")
    GameTooltip_Hide()
    Panels.Refresh()
  end)
  gear:SetScript("OnClick", function(self)
    if not self.available then return end
    GameTooltip_Hide()
    Panels.ToggleMenu(self)
  end)
  Panels.windows[#Panels.windows + 1] = w
  w:HookScript("OnShow", Panels.RefreshGears)
  w:HookScript("OnHide", Panels.RefreshGears)
  -- One small reconciliation also catches alpha-only hides, direct saved
  -- lock changes and hovering children (whose mouse events do not bubble).
  if not watcher then watcher = ns.Util.Every(0.1, Panels.RefreshGears, "panel controls") end
  Panels.RefreshGears()
  return gear
end

Theme.OnChange(Panels.Refresh)
ns.Util.Events({ PLAYER_REGEN_DISABLED = Panels.Refresh, PLAYER_REGEN_ENABLED = Panels.Refresh,
  PLAYER_ENTERING_WORLD = Panels.Refresh }, "panel controls")
