local _, ns = ...
local A, Kit, Theme = ns.Alerts, ns.Kit, ns.Theme
local modes = {
  { key = "essential", label = "Essentials", hint = "Objective warnings, attack openings, enemy stealth and bounty alerts. Routine sightings and target-lock alerts stay quiet." },
  { key = "everything", label = "Everything", hint = "Allow every alert category, including sightings and target locks." },
  { key = "critical", label = "Critical only", hint = "Focus on captures, objective changes, resurrection and kill windows." },
  { key = "objectives", label = "Objectives", hint = "Focus on bases, carriers, resurrection and sap opportunities." },
  { key = "quiet", label = "Text only", hint = "Show written alerts without alert sounds." },
}
local function Describe(w, mode)
  for _, def in ipairs(modes) do
    if def.key == mode then w.description:SetText(def.label .. "\n\n" .. def.hint); return end
  end
end

function A.Open(embedded)
  if not A.win then
    local profiles = ns.Options and ns.Options.Profiles
    local footer = profiles and profiles.CONTEXT_HEIGHT or 0
    local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "AlertOptions", {
      title = "ALERTS", titleRole = "title", sub = "Saved automatically",
      width = 640, height = 460 + footer, savedKey = "alerts" })
    A.win = w
    w.hint = Theme.Text(w, "bodyLarge", "text")
    w.hint:SetPoint("TOPLEFT", 24, -86); w.hint:SetPoint("TOPRIGHT", -24, -86)
    w.hint:SetHeight(52); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    w.hint:SetText("Which alerts help you while you play?")
    w.mode = Kit.Select(w, { width = 220, menu = true, choices = modes, onPreview = function(_, value)
      Describe(w, value)
    end, onChange = function(_, value)
      A.SetMode(value); w:Refresh()
    end })
    w.mode:SetPoint("TOPLEFT", 24, -140)
    w.description = Theme.Text(w, "bodyLarge", "text")
    w.description:SetPoint("TOPLEFT", w.mode, "TOPRIGHT", 24, 0); w.description:SetPoint("TOPRIGHT", -24, -140)
    w.description:SetHeight(196); w.description:SetJustifyH("LEFT"); w.description:SetJustifyV("TOP"); w.description:SetWordWrap(true)
    w.customize = Kit.Button(w, "Customize categories", 240, 30, { onClick = function()
      w.expanded = not w.expanded; w:Refresh()
    end })
    w.customize:SetPoint("TOPLEFT", 24, -332)
    w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
    w.scroll:SetPoint("TOPLEFT", 24, -378); w.scroll:SetPoint("BOTTOMRIGHT", -44, 96)
    w.body = CreateFrame("Frame", nil, w.scroll)
    w.body:SetSize(550, #A.categories * 42); w.scroll:SetScrollChild(w.body)
    w.rows = {}
    for i, def in ipairs(A.categories) do
      local row = { key = def.key }
      local label = Theme.Text(w.body, "body", "text")
      label:SetPoint("TOPLEFT", 0, -(i - 1) * 42 - 4); label:SetWidth(200)
      label:SetJustifyH("LEFT"); label:SetText(def.label)
      for j, channel in ipairs({ "text", "sound" }) do
        local key = channel
        row[key] = Kit.Toggle(w.body, key == "text" and "Text" or "Sound", { width = 110, onChange = function(_, on)
          local settings = A.Settings()
          settings.channels[def.key] = settings.channels[def.key] or {}
          settings.channels[def.key][key] = on
        end })
        row[key]:SetPoint("TOPLEFT", 228 + (j - 1) * 130, -(i - 1) * 42)
      end
      w.rows[#w.rows + 1] = row
    end
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("BOTTOMLEFT", 24, 65); w.status:SetPoint("BOTTOMRIGHT", -24, 65)
    w.status:SetJustifyH("LEFT")
    w.done = Kit.Button(w, "Done", 220, 34, { tone = "accent", onClick = function()
      if ns.Onboarding and ns.Onboarding.active == "alerts" then return ns.Onboarding.Reviewed("alerts") end
      if ns.Hub then ns.Hub.Release(w) end
      w:Hide()
    end })
    w.done:SetPoint("BOTTOMRIGHT", -24, 20)
    function w:Refresh()
      local settings, mode = A.Settings(), A.Settings().mode or "everything"
      self.mode:SetValue(mode, true)
      Describe(self, mode)
      for _, row in ipairs(self.rows) do
        local v = settings.channels[row.key] or {}
        row.text:SetChecked(v.text ~= false, true); row.sound:SetChecked(v.sound ~= false, true)
      end
      self.customize:SetText(self.expanded and "Hide category controls" or "Customize categories")
      self.scroll:SetShown(self.expanded == true)
      local extra = 96 * math.max(0, ns.Core.FontScale() - 1)
      self.customize:SetPoint("TOPLEFT", 24, -332 - extra)
      self.scroll:SetPoint("TOPLEFT", 24, -378 - extra)
      self:SetHeight((self.expanded and 620 or 460) + footer + extra)
      self.status:SetText(self.expanded and "Your alert level above also applies to these categories." or "You can change this any time.")
      self.done:SetText(ns.Onboarding and ns.Onboarding.active == "alerts" and "Use these alerts" or "Done")
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    ns.Core.OnFontScaleChange(function() if w:IsShown() then w:Refresh() end end)
    if profiles and profiles.AttachContext then profiles.AttachContext(w, { w.scroll, w.status, w.done }) end
  end
  local w = A.win
  w:Refresh()
  if not embedded then if ns.Hub then ns.Hub.Release(w) end; w:Show() end
  return w
end
