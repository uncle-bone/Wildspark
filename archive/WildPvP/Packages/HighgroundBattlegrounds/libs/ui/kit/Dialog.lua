local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Windows in the kit style: dialogs (header band, accent bar, title, close
-- button, drag, saved position) and the copy/paste box. Saved positions
-- live in Core.db.windows (HighgroundDB, or HighgroundMacrosDB in
-- Highground Macros). Highground's HUD windows are in timers/Windows.lua.
---------------------------------------------------------------------------
local ANCHORS = { CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
  TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function Offset(v)
  return type(v) == "number" and v == v and math.abs(v) < 10000
end

-- Saved position { point, relativePoint, x, y } in Core.db.windows[key],
-- or nil. A damaged entry is dropped.
function Kit.SavedPoint(key)
  local db = Core.db
  local all = db and db.windows
  if not key or type(all) ~= "table" then return nil end
  local p = all[key]
  if type(p) == "table" and ANCHORS[p[1]] and ANCHORS[p[2]] and Offset(p[3]) and Offset(p[4]) then return p end
  all[key] = nil
end

function Kit.SavePoint(key, frame)
  local db = Core.db
  if not (key and db) then return end
  if type(db.windows) ~= "table" then db.windows = {} end
  local p, _, rp, x, y = frame:GetPoint()
  if p then db.windows[key] = { p, rp, x, y } end
end

-- Put a window at its saved position, else at opts.point
-- ({ point, relativePoint, x, y }, default centred).
function Kit.PlaceWindow(frame, key, default)
  local p = Kit.SavedPoint(key) or default or { "CENTER", "CENTER", 0, 0 }
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- Dialog window. opts: title, sub, width, height, strata ("DIALOG"),
-- savedKey (position in Core.db.windows), point (default position),
-- header (band height, size.header), titleRole ("display"), alpha (fill,
-- alpha.dialog), opacity (true: follow Background opacity instead),
-- frameless (true: obey the Frameless setting), accent (colour token of the
-- band, bar and border, "accent"; the border is borderAccent by default),
-- borderAlpha, noClose, onClose(self).
-- Returns the frame with .head, .bar, .title, .sub, .close, .content and
-- :SetTitle(text), :SetSub(text). Escape closes it when it has a name.
-- Dragging checks IsMovable, so a host can pin it (hub/Hub.lua); a pinned
-- window does not save its position.
function Kit.Dialog(name, opts)
  opts = opts or {}
  local header = opts.header or Z("header")
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w:SetSize(opts.width or 480, opts.height or 320)
  w:SetFrameStrata(opts.strata or "DIALOG")
  local accent = opts.accent or "accent"
  Theme.Backdrop(w, { alpha = not opts.opacity and (opts.alpha or "dialog") or nil,
    border = opts.accent or "borderAccent", borderAlpha = opts.borderAlpha, frameless = opts.frameless or false })
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    if self:IsMovable() then self:StartMoving() end
  end)
  w:SetScript("OnDragStop", function(self)
    if not self:IsMovable() then return end
    self:StopMovingOrSizing()
    Kit.SavePoint(opts.savedKey, self)
  end)
  w.savedKey = opts.savedKey
  Kit.PlaceWindow(w, opts.savedKey, opts.point)
  if name and type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end

  w.head = Theme.Fill(w, "BORDER", accent, "band")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.head:SetHeight(header)
  w.bar = Theme.Fill(w, "ARTWORK", accent)
  w.bar:SetPoint("TOPLEFT", 1, -1)
  w.bar:SetSize(Z("accentBar"), header)
  w.rule = Theme.Fill(w, "ARTWORK", "border")
  w.rule:SetPoint("TOPLEFT", 1, -header)
  w.rule:SetPoint("TOPRIGHT", -1, -header)
  w.rule:SetHeight(Z("line"))
  w.inlay = Kit.Inlay(w)
  w.title = Theme.Text(w, opts.titleRole or "display", "titleText")
  w.title:SetPoint("TOPLEFT", S("xl") + S("xs"), -(header >= Z("header") and S("lg") or S("md")))
  w.title:SetText(opts.title or "")
  w.sub = Theme.Text(w, "label", "textMuted")
  w.sub:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -(S("xs") + 1))
  w.sub:SetText(opts.sub or "")
  w.sub:SetJustifyH("LEFT")
  w.sub:SetWordWrap(false)
  local function headerText()
    w.sub:ClearAllPoints()
    if Core.FontScale() > 1.2 then
      -- Large text gets a single row of title + metadata, leaving the
      -- content below the header unobstructed.
      w.sub:SetPoint("LEFT", w.title, "RIGHT", S("lg"), 0)
    else
      w.sub:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -(S("xs") + 1))
    end
    if Core.FontScale() > 1.2 and w.headerRight then
      w.sub:SetPoint("RIGHT", w.headerRight, "LEFT", -12, 0)
    else
      w.sub:SetPoint("RIGHT", w, "RIGHT", -52, 0)
    end
  end
  w.LayoutHeader = headerText
  Core.OnFontScaleChange(headerText)
  headerText()
  if not opts.noClose then
    w.close = Kit.Button(w, "X", Z("close"), Z("close"), { onClick = function() w:Hide() end })
    w.close:SetPoint("TOPRIGHT", -(S("md") + S("xs")), -(S("md") + S("xs")))
    Kit.Tooltip(w.close, { "Close", "Escape also closes this window." })
  end
  w.content = CreateFrame("Frame", nil, w)
  w.content:SetPoint("TOPLEFT", S("lg"), -header - S("md"))
  w.content:SetPoint("BOTTOMRIGHT", -S("lg"), S("lg"))
  function w:SetTitle(text) self.title:SetText(text or "") end
  function w:SetSub(text) self.sub:SetText(text or "") end
  w:Hide()
  w:SetScript("OnHide", function(self) if opts.onClose then opts.onClose(self) end end)
  Kit.Entrance(w)
  return w
end

-- Copy/paste window: title, hint, a multi-line box on a well, a status
-- line, Close at the bottom left and optional action buttons from the
-- bottom right. opts: Kit.Dialog opts plus hint, buttons ({ key, label,
-- tone?, width?, onClick(box) }), onText(box, text), below (height of an
-- area under the text box, inside the well: .below).
-- Returns the dialog with .hint, .box (EditBox), .status, .actions[key],
-- :Open(title, hint, text[, select]), :SetStatus(text[, color]), :GetText().
function Kit.CopyBox(name, opts)
  opts = opts or {}
  local o = {}
  for k, v in pairs(opts) do o[k] = v end
  o.header, o.titleRole = o.header or Z("headerSmall"), o.titleRole or "title"
  o.width, o.height = o.width or 480, o.height or 300
  local c = Kit.Dialog(name, o)
  local foot = Z("control") + S("lg") * 2
  c.hint = Theme.Text(c, "body", "textMuted")
  c.hint:SetPoint("TOPLEFT", S("lg"), -o.header - S("sm"))
  c.hint:SetPoint("RIGHT", -S("lg"), 0)
  c.hint:SetJustifyH("LEFT")
  c.hint:SetText(o.hint or "")
  local top = o.header + S("sm") + S("xl") + S("xs")
  local well = Theme.Fill(c, "BACKGROUND", "well")
  c.well = well
  well:SetPoint("TOPLEFT", S("md") + S("xs"), -top)
  well:SetPoint("BOTTOMRIGHT", -(S("md") + S("xs")), foot + S("lg"))
  c.scroll = CreateFrame("ScrollFrame", name and (name .. "Scroll") or nil, c, "UIPanelScrollFrameTemplate")
  c.scroll:SetPoint("TOPLEFT", well, "TOPLEFT", S("sm"), -S("sm"))
  c.scroll:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -S("xl") - S("md"), o.below or S("sm"))
  if o.below then
    c.below = CreateFrame("Frame", nil, c)
    c.below:SetPoint("TOPLEFT", c.scroll, "BOTTOMLEFT", 0, -S("sm"))
    c.below:SetPoint("RIGHT", -(S("lg") + S("xs")), 0)
    c.below:SetHeight(o.below - S("sm"))
  end
  c.box = CreateFrame("EditBox", nil, c.scroll)
  c.box:SetMultiLine(true)
  c.box:SetAutoFocus(false)
  c.box:SetMaxLetters(0)
  c.box:SetWidth(o.width - S("xl") * 4)
  Theme.SetRole(c.box, "code")
  Theme.Paint(c.box, "text")
  c.box:SetScript("OnEscapePressed", function() c:Hide() end)
  if o.onText then c.box:SetScript("OnTextChanged", function(self) o.onText(c, self:GetText()) end) end
  c.scroll:SetScrollChild(c.box)
  c.status = Theme.Text(c, "body")
  c.status:SetPoint("BOTTOMLEFT", S("lg"), foot)
  c.status:SetPoint("RIGHT", -S("lg"), 0)
  c.status:SetJustifyH("LEFT")
  c.done = Kit.Button(c, "Close", 70, Z("control"), { onClick = function() c:Hide() end })
  c.done:SetPoint("BOTTOMLEFT", S("lg"), S("lg"))
  c.actions = {}
  local prev
  for i = #(o.buttons or {}), 1, -1 do
    local def = o.buttons[i]
    local b = Kit.Button(c, def.label, def.width or 100, Z("control"),
      { tone = def.tone, onClick = function() if def.onClick then def.onClick(c) end end })
    if prev then b:SetPoint("RIGHT", prev, "LEFT", -S("sm"), 0) else b:SetPoint("BOTTOMRIGHT", -S("lg"), S("lg")) end
    c.actions[def.key or i] = b
    prev = b
  end
  function c:SetStatus(text, color)
    self.status:SetText(text or "")
    Theme.Paint(self.status, color or "text")
  end
  function c:GetText() return self.box:GetText() or "" end
  function c:Open(title, hint, text, select)
    if title then self:SetTitle(title) end
    if hint then self.hint:SetText(hint) end
    self:SetStatus("")
    self:Show()
    self.box:SetText(text or "")
    self.box:SetFocus()
    if select then self.box:HighlightText() end
  end
  return c
end
