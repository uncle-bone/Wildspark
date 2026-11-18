local _, ns = ...
local Theme, Kit, Motion = ns.Theme, ns.Kit, ns.Motion
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Kit.Dropdown: one scrolling list, shown under whichever box or button
-- uses it. Items: { text, icon?, hint?, value? }; icon may be a function
-- (item) -> texture, looked up when the row is first drawn.
--   Attach(box, provider[, multiline]): suggestions while typing.
--     provider(textBeforeCursor) -> word, items[, suffix]; accepting puts
--     item.text .. suffix in place of word. Tab accepts; single-line boxes
--     also open on focus, accept on Enter and move with Up/Down.
--   Open(anchor, items, onPick[, opts]): a plain choice list; onPick(item,
--     index). opts: width, selected (index), onPreview(item), onClose().
--     Opening it again closes it. Preview never accepts a choice.
-- Wheel scrolls; a range footer and thumb show when there are more than
-- MAX items. Escape closes.
---------------------------------------------------------------------------
local D = { MAX = 8 }
Kit.Dropdown = D
local list

local function RowH() return Z("row") * math.max(1, ns.Core.FontScale()) end

local function Row(parent, i)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(RowH())
  b:SetPoint("TOPLEFT", S("xs"), -S("xs") - (i - 1) * RowH())
  b:SetPoint("RIGHT", -S("xs"), 0)
  b.bg = Theme.Fill(b, "BACKGROUND", "overlaySelected", 0)
  b.bg:SetAllPoints()
  b.marker = Theme.Fill(b, "ARTWORK", "accent")
  b.marker:SetPoint("TOPLEFT", 0, -S("xs"))
  b.marker:SetPoint("BOTTOMLEFT", 0, S("xs"))
  b.marker:SetWidth(Z("strip"))
  b.marker:Hide()
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(Z("icon"), Z("icon"))
  b.icon:SetPoint("LEFT", S("xs") + 1, 0)
  b.label = Theme.Text(b, "control")
  b.label:SetPoint("LEFT", Z("icon") + S("md") - 1, 0)
  b.label:SetJustifyH("LEFT")
  b.label:SetWordWrap(false)
  b.hint = Theme.Text(b, "caption", "textMuted")
  b.hint:SetPoint("RIGHT", -S("sm"), 0)
  b.hint:SetWidth(110)
  b.hint:SetJustifyH("RIGHT")
  b.hint:SetWordWrap(false)
  b.label:SetPoint("RIGHT", b.hint, "LEFT", -S("sm"), 0)
  b.index = i
  b:SetScript("OnClick", function(self) D.Accept(list.offset + self.index) end)
  b:SetScript("OnEnter", function(self) D.Select(list.offset + self.index, true) end)
  return b
end

local function Build()
  if list then return list end
  -- Named per addon (ns.FRAME_PREFIX): two addons embedding the kit don't share it.
  local name = (ns.FRAME_PREFIX or "Highground") .. "Dropdown"
  list = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  list:SetFrameStrata("TOOLTIP")
  list:SetClampedToScreen(true)
  Theme.Backdrop(list, { alpha = "menu", frameless = false })
  list.rows = {}
  for i = 1, D.MAX do list.rows[i] = Row(list, i) end
  list.more = Theme.Text(list, "caption", "textMuted")
  list.more:SetPoint("BOTTOMRIGHT", -S("md") + S("xs"), S("sm"))
  list.bar = Theme.Fill(list, "ARTWORK", "accent", "bar")
  list.bar:SetWidth(Z("scrollbar"))
  list.offset = 0
  pcall(list.EnableMouseWheel, list, true)
  list:SetScript("OnMouseWheel", function(_, delta) D.Scroll(-delta) end)
  list:SetScript("OnHide", function(self)
    local close = self.onClose
    self.items, self.box, self.anchor, self.onPick, self.onPreview, self.onClose = nil, nil, nil, nil, nil, nil
    if close then close() end
  end)
  -- Clicking elsewhere does not take focus from a WoW edit box, so watch for
  -- a press outside the list and its box (or the box going away).
  list:SetScript("OnUpdate", function(self) D.CheckOutside(self) end)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end
  list:Hide()
  Kit.Entrance(list, "menu", "menuEnter")
  return list
end

-- Keep completion beside the line being edited and inside its viewport.
-- Above/below is chosen from the available editor space, so suggestions
-- never cover the explanation or the save controls beneath it.
local function PlaceCaret(l)
  local box = l.box
  if not (box and box.wbMultiline) then return end
  local view = box.wbViewport or box
  local rect = box.wbCaret or { x = 0, y = 0, height = 18 }
  local width, height = view:GetWidth(), view:GetHeight()
  local offset = view.GetVerticalScroll and view:GetVerticalScroll() or 0
  local top = math.max(0, math.min(height - rect.height, -rect.y - offset))
  local below, above = height - top - rect.height - 4, top - 4
  local down = below >= math.min(3, #l.items) * RowH() + 28 or below >= above
  local room = down and below or above
  l.caretFooter = room >= RowH() + 28
  l.visibleRows = math.max(1, math.min(5, math.floor((room - (l.caretFooter and 28 or 4)) / RowH())))
  l.offset = math.max(0, math.min(l.offset, #l.items - l.visibleRows))
  local longest = 0
  for _, item in ipairs(l.items) do longest = math.max(longest, #item.text) end
  local w = math.min(width, 380, math.max(260, longest * 7 + 130))
  local x = math.max(0, math.min(rect.x, width - w))
  l:SetWidth(w)
  l:ClearAllPoints()
  l:SetPoint(down and "TOPLEFT" or "BOTTOMLEFT", view, "TOPLEFT", x,
    down and (-top - rect.height - 4) or (-top + 4))
  l.placement = down and "below" or "above"
end

-- Draw the visible window of items.
local function Render()
  local l = list
  PlaceCaret(l)
  local n, max, h = #l.items, l.visibleRows or D.MAX, RowH()
  for i, r in ipairs(l.rows) do
    r:SetHeight(h)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", S("xs"), -S("xs") - (i - 1) * h)
    r:SetPoint("RIGHT", -S("xs"), 0)
    local it = l.items[l.offset + i]
    if it and i <= max then
      r.label:SetText(it.text)
      r.hint:SetText(it.hint and it.hint:upper() or "")
      if type(it.icon) == "function" then it.icon = it.icon(it) or false end
      r.icon:SetTexture(it.icon or nil)
      r.icon:SetShown(it.icon and true or false)
      r.label:ClearAllPoints()
      r.label:SetPoint("LEFT", it.icon and Z("icon") + S("md") - 1 or S("md"), 0)
      if it.hint then r.label:SetPoint("RIGHT", r.hint, "LEFT", -S("sm"), 0)
      else r.label:SetPoint("RIGHT", -S("sm"), 0) end
      Theme.Paint(r.bg, "overlaySelected", l.offset + i == l.selected and select(4, Theme.Color("overlaySelected")) or 0)
      Motion.Mark(r.marker, l.offset + i == l.selected)
      r:Show()
    else
      r:Hide()
    end
  end
  local scrolls = n > max
  local completing = l.box and l.box.wbMultiline
  local footer = completing and l.caretFooter or not completing and scrolls
  local range = scrolls and string.format("%d-%d OF %d", l.offset + 1, math.min(n, l.offset + max), n) or ""
  l.more:SetText(completing and (range .. (scrolls and "  ·  " or "") .. "TAB: INSERT  ·  ESC: CLOSE") or range)
  l.more:SetShown(footer)
  l:SetHeight(S("sm") + math.min(n, max) * h + (footer and S("lg") + S("xs") or 0))
  l.bar:SetShown(scrolls)
  if scrolls then -- a thumb showing where the window is
    local track = math.min(n, max) * h
    l.bar:ClearAllPoints()
    l.bar:SetPoint("TOPRIGHT", -1, -S("xs") - track * l.offset / n)
    l.bar:SetHeight(math.max(S("md"), track * max / n))
  end
end

-- An open list keeps the current palette's selection alpha as well as RGB.
Theme.OnChange(function() if list and list.items then Render() end end)
ns.Core.OnFontScaleChange(function() if list and list.items then Render() end end)

local function Show(anchor, items, width)
  -- Typing updates the same popup in place: no hide/show flash, repeated
  -- entrance, focus churn or premature close callback for the same editor.
  local continuing = list and list:IsShown() and list.box == anchor and not list.onPick
  if not continuing then D.Hide() end
  local l = Build()
  -- One list for every owner: forget the previous one.
  l.box, l.anchor, l.onPick, l.word, l.suffix, l.cursor = nil, nil, nil, "", "", 0
  l.items, l.offset, l.selected = items, 0, 1
  l.visibleRows, l.placement = D.MAX, nil
  l:SetScale(anchor:GetEffectiveScale() / UIParent:GetEffectiveScale())
  l:ClearAllPoints()
  l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -S("xs"))
  l:SetWidth(math.max(width or 220, anchor:GetWidth()))
  Render()
  l:Show()
  return l
end

function D.Position(box)
  if not (list and list.items and list.box == box) or box.wbCursorScrolling or box.wbColoring then return end
  local view, caret = box.wbViewport, box.wbCaret
  if view and caret then
    local top = -caret.y - (view:GetVerticalScroll() or 0)
    if top + caret.height < 0 or top > view:GetHeight() then return D.Hide() end
  end
  Render()
end

-- Close on a mouse press outside the list and its owner, or when the owner
-- is hidden; a box loses focus too, as players expect from a click away.
function D.CheckOutside(l)
  local owner = l.box or l.anchor
  if owner and not owner:IsVisible() then return D.Hide() end
  if not (IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))) then return end
  if l:IsMouseOver() or (owner and owner:IsMouseOver()) then return end
  local box = l.box
  D.Hide()
  if box and box.ClearFocus then box:ClearFocus() end
end

function D.Frame() return list end
function D.IsShown() return list ~= nil and list:IsShown() and list.items ~= nil end
function D.Items() return list and list.items end

function D.Scroll(rows)
  local l = list
  if not (l and l.items) then return end
  l.offset = math.max(0, math.min(#l.items - (l.visibleRows or D.MAX), l.offset + rows))
  Render()
end

-- Select item i (absolute); keyboard selection scrolls it into view.
function D.Select(i, hover)
  local l = list
  if not (l and l.items) then return end
  l.selected = i
  if not hover then
    if i <= l.offset then l.offset = i - 1
    elseif i > l.offset + (l.visibleRows or D.MAX) then l.offset = i - (l.visibleRows or D.MAX) end
  end
  Render()
  if l.onPreview and l.items[i] then l.onPreview(l.items[i], i) end
end

function D.Hide(suppress)
  if list then
    if suppress and list.box then list.box.wbSuppressCompletion = true end
    list:Hide()
  end
end

-- Accept item i (default: the selected one).
function D.Accept(i)
  local l = list
  if not (l and l:IsShown() and l.items) then return false end
  i = i or l.selected or 1
  local it = l.items[i]
  if not it then return false end
  local box, onPick = l.box, l.onPick
  if onPick then
    D.Hide()
    onPick(it, i)
    return true
  end
  local text = box.GetPlainText and box:GetPlainText() or box:GetText() or ""
  local start = l.cursor - #l.word
  local newText = text:sub(1, start) .. it.text .. l.suffix .. text:sub(l.cursor + 1)
  D.Hide()
  box.wbAccepting = true
  box.wbSuppressCompletion = true
  if box.SetPlainText then box:SetPlainText(newText) else box:SetText(newText) end
  local to = start + #it.text + #l.suffix
  if box.SetPlainCursor then box:SetPlainCursor(to) elseif box.SetCursorPosition then box:SetCursorPosition(to) end
  box.wbAccepting = nil
  return true
end

function D.Open(anchor, items, onPick, opts)
  opts = opts or {}
  if list and list:IsShown() and list.anchor == anchor then D.Hide(); return false end
  if not items or #items == 0 then D.Hide(); return false end
  local l = Show(anchor, items, opts.width)
  l.anchor, l.onPick = anchor, onPick
  l.onPreview, l.onClose = opts.onPreview, opts.onClose
  D.Select(opts.selected or 1)
  return true
end

-- Recompute the list for box (on every text change).
function D.Update(box)
  local provider = box.wbDropdown
  if not provider or not box.wbFocused then
    if list and list.box == box then D.Hide() end
    return
  end
  local text = box.GetPlainText and box:GetPlainText() or box:GetText() or ""
  local cursor = box.GetPlainCursor and box:GetPlainCursor()
    or box.GetCursorPosition and box:GetCursorPosition() or #text
  local word, items, suffix = provider(text:sub(1, cursor))
  if not items or #items == 0 then return D.Hide() end
  local l = Show(box, items)
  l.box, l.anchor, l.word, l.suffix, l.cursor = box, box, word or "", suffix or "", cursor
  Render()
end

-- Call after the box's own SetScript calls (SetScript drops hooks).
function D.Attach(box, provider, multiline)
  box.wbDropdown = provider
  box.wbMultiline = multiline
  box:HookScript("OnEditFocusGained", function(self) self.wbFocused = true; self.wbSuppressCompletion = nil end)
  box:HookScript("OnEditFocusLost", function(self)
    self.wbFocused = false
    local function close() if not self.wbFocused and list and list.box == self then D.Hide() end end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, close) else close() end
  end)
  box:HookScript("OnTextChanged", function(self)
    if not self.wbAccepting and not self.wbColoring then self.wbSuppressCompletion = nil; D.Update(self) end
  end)
  box:SetScript("OnTabPressed", function() D.Accept() end)
  box:HookScript("OnEscapePressed", function() D.Hide(true) end)
  if multiline then
    box:HookScript("OnCursorChanged", function(self, x, y, _, height)
      self.wbCaret = { x = x, y = y, height = height }
      if self.wbAccepting or self.wbColoring then return end
      -- Moving with the arrows must refresh both the word and its anchor.
      if self.wbFocused and not self.wbSuppressCompletion then D.Update(self) end
    end)
    return -- Enter and arrows keep their editing meaning
  end
  box:HookScript("OnEditFocusGained", function(self) D.Update(self) end)
  box:HookScript("OnEnterPressed", function() D.Accept() end)
  box:HookScript("OnArrowPressed", function(_, key)
    if not (list and list:IsShown() and list.box == box) then return end
    local n = #list.items
    if key == "DOWN" then D.Select((list.selected or 1) % n + 1)
    elseif key == "UP" then D.Select(((list.selected or 1) - 2) % n + 1) end
  end)
end
