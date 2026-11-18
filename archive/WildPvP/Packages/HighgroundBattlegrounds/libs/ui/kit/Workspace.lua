local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- A scroll area with a themed, draggable scrollbar. Call :Refresh() after
-- changing body height. A caller may replace .body with an EditBox.
function Kit.ScrollArea(parent)
  local area = CreateFrame("Frame", nil, parent)
  area.view = CreateFrame("ScrollFrame", nil, area)
  area.view:SetPoint("TOPLEFT")
  area.view:SetPoint("BOTTOMRIGHT", -16, 0)
  area.body = CreateFrame("Frame", nil, area.view)
  area.body:SetSize(1, 1)
  area.view:SetScrollChild(area.body)
  area.bar = CreateFrame("Slider", nil, area)
  area.bar:SetPoint("TOPRIGHT", -2, -2)
  area.bar:SetPoint("BOTTOMRIGHT", -2, 2)
  area.bar:SetWidth(10)
  area.bar:SetOrientation("VERTICAL")
  area.bar:SetValueStep(1)
  local track = Theme.Fill(area.bar, "BACKGROUND", "border")
  track:SetPoint("TOP"); track:SetPoint("BOTTOM"); track:SetWidth(2)
  area.thumb = Theme.Fill(area.bar, "ARTWORK", "controlBorder")
  area.thumb:SetSize(8, 36)
  area.bar:SetThumbTexture(area.thumb)
  area.offset, area.range = 0, 0
  function area:Scroll(value)
    self.offset = math.max(0, math.min(self.range, value))
    self.view:SetVerticalScroll(self.offset)
    if not self.syncing then
      self.syncing = true; self.bar:SetValue(self.offset); self.syncing = nil
    end
    if self.onScroll then self.onScroll(self.offset) end
  end
  function area:Refresh()
    if self.refreshing then return end
    self.refreshing = true
    local h = math.max(1, self.view:GetHeight())
    self.body:SetWidth(math.max(1, self.view:GetWidth()))
    self.range = math.max(0, self.body:GetHeight() - h)
    self.syncing = true
    self.bar:SetMinMaxValues(0, self.range)
    self.syncing = nil
    self.thumb:SetHeight(math.max(24, (h - 4) * h / math.max(h, self.body:GetHeight())))
    self.bar:SetShown(self.range > 0)
    self:Scroll(self.offset)
    self.refreshing = nil
  end
  area.bar:SetScript("OnValueChanged", function(_, value) if not area.syncing then area:Scroll(value) end end)
  area.view:EnableMouseWheel(true)
  area.view:SetScript("OnMouseWheel", function(_, delta) area:Scroll(area.offset - delta * 40) end)
  area.view:SetScript("OnSizeChanged", function() area:Refresh() end)
  return area
end

-- A multiline editing well. Native cursor coordinates are relative to
-- the text's top left; y is negative below the first line. Scroll only
-- enough to keep the caret visible, then let the dropdown follow it.
function Kit.Editor(parent)
  local well = CreateFrame("Frame", nil, parent)
  well.bg = Theme.Fill(well, "BACKGROUND", "well")
  well.bg:SetAllPoints()
  well.edge = Kit.Outline(well, "controlBorder")
  well.scroll = Kit.ScrollArea(well)
  well.scroll:SetPoint("TOPLEFT", 12, -12)
  well.scroll:SetPoint("BOTTOMRIGHT", -4, 12)
  well.scroll:SetFrameLevel(well:GetFrameLevel() + 2)
  well.scroll.view:SetFrameLevel(well.scroll:GetFrameLevel() + 1)
  well.scroll.bar:SetFrameLevel(well.scroll:GetFrameLevel() + 2)
  local code = CreateFrame("EditBox", nil, well.scroll.view)
  code:SetMultiLine(true)
  code:SetAutoFocus(false)
  code:SetMaxLetters(3000) -- syntax colours don't count toward the macro limit
  code:SetSize(1, 1)
  Theme.SetRole(code, "codeLarge")
  Theme.Paint(code, "text")
  well.scroll.body = code
  well.scroll.view:SetScrollChild(code)
  code.wbViewport = well.scroll.view
  code:SetScript("OnSizeChanged", function() well.scroll:Refresh() end)
  code:SetScript("OnCursorChanged", function(_, _, y, _, height)
    local scroll = well.scroll
    code.wbCursorScrolling = true
    scroll:Refresh()
    local top, bottom = -y, -y + height
    if top < scroll.offset then scroll:Scroll(top)
    elseif bottom > scroll.offset + scroll.view:GetHeight() then
      scroll:Scroll(bottom - scroll.view:GetHeight())
    end
    code.wbCursorScrolling = nil
  end)
  well.focusLine = Theme.Fill(well, "OVERLAY", "focus")
  well.focusLine:SetPoint("BOTTOMLEFT")
  well.focusLine:SetPoint("BOTTOMRIGHT")
  well.focusLine:SetHeight(Theme.Size("underline"))
  Kit.Focus(code, well.edge, well.focusLine)
  -- The first Escape dismisses completion; the second leaves the editor.
  code:SetScript("OnEscapePressed", function(self)
    if not Kit.Dropdown.IsShown() then self:ClearFocus() end
  end)
  local catch = CreateFrame("Button", nil, well)
  catch:SetAllPoints()
  catch:SetFrameLevel(well:GetFrameLevel() + 1)
  code:SetFrameLevel(well.scroll.view:GetFrameLevel() + 1)
  catch:SetScript("OnClick", function()
    code:SetFocus()
    if code.SetPlainCursor then code:SetPlainCursor(#code:GetPlainText()) end
  end)
  well.scroll.onScroll = function() if Kit.Dropdown.Position then Kit.Dropdown.Position(code) end end
  well.code, well.catch = code, catch
  return well
end
