local _, ns = ...
ns.Timers = ns.Timers or {}
local Timers = ns.Timers
local Core, Theme, Hud = ns.Core, ns.Theme, ns.Hud
local S = Theme.Space

---------------------------------------------------------------------------
-- HUD windows (res timers, bases, flags, arena, nearby): movable, position
-- saved per window and character (drag; /hg lock locks them with the main
-- panel; /hg timers reset puts them back). Timer rows: location and state,
-- a readable clock and progress line.
---------------------------------------------------------------------------
Timers.THEME = ns.UIConfig
Timers.WIN_W, Timers.ROW_H, Timers.TOP = Timers.THEME.timers.width, Timers.THEME.timers.row, Timers.THEME.timers.header
Timers.WIN_PAD, Timers.WIN_GAP = Timers.THEME.timers.padding, Timers.THEME.timers.gap
Timers.windows, Timers.timerWindows = {}, {}

-- Saved settings and positions (ns.GetDB / ns.GetPositions: Highground's
-- core, or standalone/Core.lua).
function Timers.DB()
  return ns.GetDB and ns.GetDB()
end

local ROUND = { round = true }
function Timers.Clock(sec)
  return ns.Util.Clock(sec, ROUND)
end

function Timers.Positions()
  return ns.GetPositions and ns.GetPositions()
end

-- UI scale times the window's own Appearance scale.
local PANEL = { timersPoint = "timers", basesPoint = "timers", flagsPoint = "flags", arenaPoint = "arena" }
function Timers.WinScale(w)
  local db = Timers.DB()
  local base = db and db.scale or Timers.THEME.scale.default
  return base * (ns.PanelScale and ns.PanelScale(PANEL[w.key] or "timers") or 1)
end

function Timers.PlaceWin(w)
  local pos = Timers.Positions()
  if ns.DockHead and ns.DockHead() and w.docks then
    -- Compact: docked windows hang under the column (ui/Compact.lua).
    w:SetScale(Timers.WinScale(w))
    w.dockedTo = nil
    ns.Dock()
    return
  end
  w:ClearAllPoints()
  local p = pos and pos[w.key]
  if p then
    w:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    w:SetPoint(w.def[1], UIParent, w.def[2], w.def[3], w.def[4])
  end
  w:SetScale(Timers.WinScale(w))
end

function ns.TimersApplyScale()
  if InCombatLockdown() then return end
  for _, w in ipairs(Timers.windows) do
    w:SetScale(Timers.WinScale(w))
  end
end

function ns.TimersWindowReset()
  local pos = Timers.Positions()
  for _, w in ipairs(Timers.windows) do
    if pos then
      pos[w.key] = nil
    end
    if not (w.secure and InCombatLockdown()) then Timers.PlaceWin(w) end
  end
end

-- Secure windows cannot be hidden or shown in combat. SecureHide fades
-- them out instead; SecureShow places and shows them once out of combat
-- (owners re-run their update on PLAYER_REGEN_ENABLED). SecureShow returns
-- true when it showed the window.
function Timers.SecureHide(w)
  if not (w and w:IsShown()) then return end
  if InCombatLockdown() then w:SetAlpha(0) else w:Hide() end
  ns.PanelControls.Refresh()
end

function Timers.SecureShow(w)
  if w:IsShown() or InCombatLockdown() then return false end
  Timers.PlaceWin(w)
  w:Show()
  return true
end

-- Battleground HUD window (resurrection timers, bases, flags, arena,
-- nearby): movable, position saved per character under key (default
-- def = { point, relativePoint, x, y }), docked in the compact layout
-- unless noDock, title and info line in the header. secure: it holds
-- secure buttons, so it doesn't move in combat.
function Timers.MakeWindow(name, title, key, def, secure, noDock)
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w.key, w.def, w.rows, w.secure = key, def, {}, secure
  w.docks = not noDock
  w:SetSize(Timers.WIN_W, Timers.TOP + Timers.ROW_H + S("sm"))
  Theme.Backdrop(w)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    local db = Timers.DB()
    if self.docks and ns.DockDrag and ns.DockDrag(self, true) then
      return -- compact: the whole column moves
    end
    if self.secure and InCombatLockdown() then
      return -- holds secure buttons: can't move in combat
    end
    if not (db and db.locked) then self:StartMoving() end
  end)
  w:SetScript("OnDragStop", function(self)
    if self.docks and ns.DockDrag and ns.DockDrag(self, false) then return end
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local pos = Timers.Positions()
    if pos then pos[self.key] = { p, rp, x, y } end
  end)
  w.head = Core.Surface(w, "BORDER")
  Theme.Paint(w.head, "surface")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.brand = Theme.Fill(w, "ARTWORK", "accent")
  w.title = Theme.Text(w, "heading", "titleText")
  w.title:SetPoint("LEFT", w.brand, "RIGHT", S("sm"), 0)
  w.title:SetText(title)
  w.info = Theme.Text(w, "label", "textMuted")
  w.info:SetJustifyH("RIGHT")
  Core.Chrome(w.head, w.brand, w.title, w.info)
  ns.PanelControls.Register(w)
  Timers.windows[#Timers.windows + 1] = w
  if not secure then Timers.timerWindows[#Timers.timerWindows + 1] = w end
  Timers.LayoutWindow(w)
  Timers.PlaceWin(w)
  w:Hide()
  return w
end

-- Text helpers: font is a type role.
Timers.Font = Theme.SetRole

-- Health fill alpha of the carrier and arena rows: health known, not.
local function BarAlpha()
  Timers.BAR_SEEN, Timers.BAR_UNSEEN = Theme.Alpha("healthFill"), Theme.Alpha("healthUnseen")
end
BarAlpha()
Theme.OnChange(BarAlpha)

-- Status bar colour: a token name, a live token table (both repainted on a
-- theme switch), { r, g, b } or a class colour { r =, g =, b = }.
function Timers.BarColor(bar, color, alpha)
  Theme.Paint(bar, color, alpha)
end

local function Compact()
  return Core.compact or false
end
Timers.Compact = Compact

-- Header, width and rows for the current layout (normal or compact).
function Timers.LayoutWindow(w)
  local compact = Compact()
  w:SetWidth(Timers.WIN_W)
  w.head:SetHeight(Timers.TOP - (compact and 1 or 4))
  w.brand:SetSize(3, compact and 8 or 12)
  w.brand:ClearAllPoints()
  w.brand:SetPoint("TOPLEFT", Timers.WIN_PAD, compact and -4 or -7)
  Timers.Font(w.title, compact and "headingSmall" or "heading")
  Timers.Font(w.info, compact and "caption" or "label")
  ns.PanelControls.Layout(w, Timers.TOP, Timers.WIN_PAD)
  w.info:ClearAllPoints()
  w.info:SetPoint("RIGHT", w.gear, "LEFT", -S("sm"), 0)
  w.info:SetWidth(math.max(40, Timers.WIN_W - (compact and 100 or 128) - w.gear:GetWidth() - S("sm")))
  w.title:SetPoint("RIGHT", w.info, "LEFT", -S("sm"), 0)
  w.title:SetWordWrap(false)
  w.info:SetWordWrap(false)
  for i, r in ipairs(w.rows) do Timers.LayoutRow(w, r, i) end
  if w.relayout then w.relayout() end
end

-- Normal: place over tag, clock on the right. Compact: one line.
function Timers.LayoutRow(w, r, i)
  local compact = Compact()
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Timers.ROW_H + Timers.WIN_GAP))
  r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  r:SetHeight(Timers.ROW_H)
  r.tag:ClearAllPoints()
  r.time:ClearAllPoints()
  r.place:ClearAllPoints()
  if compact then
    Timers.Font(r.tag, "caption")
    r.tag:SetPoint("LEFT", 5, 0)
    r.tag:SetWidth(44)
    Timers.Font(r.time, "timerSmall")
    r.time:SetPoint("RIGHT", -5, 0)
    r.time:SetWidth(50)
    Timers.Font(r.place, "detail")
    r.place:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
  else
    Timers.Font(r.tag, "label")
    r.tag:SetPoint("BOTTOMLEFT", 7, 5)
    r.tag:SetWidth(76)
    Timers.Font(r.time, "timer")
    r.time:SetPoint("RIGHT", -7, 1)
    r.time:SetWidth(65)
    Timers.Font(r.place, "rowNameSmall")
    r.place:SetPoint("TOPLEFT", 7, -3)
  end
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
end

function Timers.RowFrame(w, i)
  local r = w.rows[i]
  if r then
    return r
  end
  r = CreateFrame("Frame", nil, w)
  Hud.Surface(r, "BACKGROUND"):SetAllPoints()
  r.tag = Theme.Text(r, "label")
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetHeight(Theme.Size("underline"))
  Core.StatusBar(r.bar)
  r.bar:SetMinMaxValues(0, 1)
  Theme.Fill(r.bar, "BACKGROUND", "overlaySubtle"):SetAllPoints()
  r.time = Theme.Text(r, "timer")
  r.time:SetJustifyH("RIGHT")
  r.place = Theme.Text(r, "rowNameSmall")
  r.place:SetJustifyH("LEFT")
  Timers.LayoutRow(w, r, i)
  r:EnableMouse(true)
  r.ShowTip = function(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Timers.TipLine(GameTooltip, row.detail or row.text or "", "white")
    local meanings = { YOU = "Your resurrection destination", OURS = "Friendly objective or graveyard",
      THEIRS = "Enemy objective or graveyard", SOON = "Your graveyard revives players soon. This is timing information, not an instruction to die.",
      CAP = "Capture in progress", LOCK = "Timed node ownership", RESET = "Node resetting",
      WIN = "Projected win if current captures complete", HELD = "Projection if contested bases are defended",
      NEED = "Bases required for the trailing team to win", FLAG = "Flag respawn countdown",
      PLAN = "Objective plan from the current match state", CONTEST = "Contested objective",
      STATUS = "Observed game status", GATE = "Gate status from the game", CART = "Observed cart or delivery objective",
      ROUND = "Round information from the game", CONTROL = "Observed control progress",
      EVENT = "Recent battleground announcement", OBJECTIVE = "Observed map objective",
      RES = "Awaiting graveyard observations" }
    if meanings[row.tag] then Timers.TipLine(GameTooltip, meanings[row.tag], "info") end
    if row.left then
      Timers.TipLine(GameTooltip, (row.est and "Estimated: " or "Remaining: ") .. Timers.Clock(row.left), "text")
    elseif not row.time and not row.frac then
      Timers.TipLine(GameTooltip, "Countdown not observed yet", "textMuted")
    end
    GameTooltip:Show()
  end
  r:SetScript("OnEnter", r.ShowTip)
  r:SetScript("OnLeave", GameTooltip_Hide)
  w.rows[i] = r
  return r
end

local BAR_LIVE, BAR_EST = 0.85, 0.45 -- progress line alpha: observed, estimated

-- row = { tag, color, text, left + total (bar fills as it runs out) |
--         frac (bar as given), time (text, else from left), est, die }
function Timers.ShowRows(w, rows, info)
  for i, row in ipairs(rows) do
    local r, c = Timers.RowFrame(w, i), row.color
    r.data = row
    r.tag:SetText(row.tag)
    Theme.Paint(r.tag, c)
    local frac = row.frac
    if not frac and row.left then
      frac = math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1)))
    end
    r.bar:SetValue(frac or 0)
    Timers.BarColor(r.bar, c, row.est and BAR_EST or BAR_LIVE)
    r.time:SetText(row.time or (row.left and ((row.est and "~" or "") .. Timers.Clock(row.left))) or "--")
    local urgent = row.die or (row.left and row.left > 0 and row.left <= 5)
    Theme.Paint(r.time, urgent and "warning" or (not row.left and not row.time and "textMuted") or "text")
    r.place:SetText(row.text or "")
    r:Show()
    -- An open tooltip follows the live countdown.
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == r then r.ShowTip(r) end
  end
  for i = #rows + 1, #w.rows do
    w.rows[i]:Hide()
  end
  w.info:SetText(info or "")
  w:SetHeight(Timers.TOP + #rows * (Timers.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  if not InCombatLockdown() and w:GetScale() ~= Timers.WinScale(w) then
    w:SetScale(Timers.WinScale(w))
  end
  w:Show()
  if w.docks and ns.Dock then ns.Dock() end
end
