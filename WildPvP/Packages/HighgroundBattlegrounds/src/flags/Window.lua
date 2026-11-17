local _, ns = ...
local Timers = ns.Timers
local Flags = ns.Flags
local Core, Theme, Kit, Hud, Util = ns.Core, ns.Theme, ns.Kit, ns.Hud, ns.Util

function Flags.BuildFlags()
  if Flags.flagWin or InCombatLockdown() then
    return
  end
  local prefix = ns.FRAME_PREFIX or "Highground"
  Flags.flagWin = Timers.MakeWindow(prefix .. "FlagsFrame", "FLAG CARRIERS", "flagsPoint", { "TOP", "TOP", -Timers.THEME.timers.spacing, -150 }, true)
  if not Flags.flagWin then
    return
  end
  Flags.frows = {}
  for i, team in ipairs({ "mine", "theirs" }) do
    local r = Hud.UnitRow(Flags.flagWin, prefix .. "FlagRow" .. i, { bar = true, tip = function(self)
      return self.side == "mine" and "Allied flag carrier · Protect this player" or "Enemy flag carrier · Stop this player"
    end })
    r.side = team
    r.team = team == "mine" and Timers.MyTeam() or Timers.Other(Timers.MyTeam())
    r.tag = Theme.Text(r.bar, "label")
    r.tag:SetJustifyH("LEFT")
    r.right = Theme.Text(r.bar, "code")
    Flags.frows[i] = r
  end
  Flags.LayoutRows()
  Flags.SetMacros() -- stable arena targets must exist before the first combat pickup
end

-- Normal: icon, name over tag. Compact: one line. Out of combat (secure rows).
function Flags.LayoutRows()
  if not Flags.frows or InCombatLockdown() then return end
  local compact = Timers.Compact()
  for i, r in ipairs(Flags.frows) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Flags.FTOP - (i - 1) * (Flags.FROW_H + Timers.WIN_GAP))
    r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
    r:SetHeight(Flags.FROW_H)
    for _, region in ipairs({ r.tag, r.icon, r.right, r.name }) do region:ClearAllPoints() end
    if compact then
      r.icon:SetSize(16, 16)
      r.icon:SetPoint("LEFT", 4, 0)
      Timers.Font(r.tag, "caption")
      r.tag:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
      r.tag:SetWidth(56)
      Timers.Font(r.right, "label")
      r.right:SetPoint("RIGHT", -5, 0)
      Timers.Font(r.name, "control")
      r.name:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
      r.name:SetPoint("RIGHT", r.right, "LEFT", -4, 0)
    else
      r.icon:SetSize(28, 28)
      r.icon:SetPoint("LEFT", 8, 0)
      Timers.Font(r.tag, "label")
      r.tag:SetPoint("BOTTOMLEFT", 44, 8)
      r.tag:SetWidth(56)
      Timers.Font(r.right, "code")
      r.right:SetPoint("BOTTOMRIGHT", -7, 8)
      Timers.Font(r.name, "rowNameLarge")
      r.name:SetPoint("TOPLEFT", 44, -6)
      r.name:SetPoint("RIGHT", -7, 0)
    end
  end
  Flags.flagWin:SetHeight(Flags.FTOP + 2 * (Flags.FROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
end

function Flags.UpdateFlags(now)
  local want = Flags.FlagsEnabled() and Flags.InBG() and Flags.FlagBG()
  if not want then
    Timers.SecureHide(Flags.flagWin)
    wipe(Flags.carriers)
    return
  end
  if not Flags.flagWin then
    Flags.BuildFlags()
    if not Flags.flagWin then
      return
    end
  end
  Flags.flagWin:SetAlpha(1)
  local me = Timers.MyTeam()
  local objective = Timers.Rules().objective
  for _, r in ipairs(Flags.frows) do
    r.team = r.side == "mine" and me or Timers.Other(me)
    local c = Flags.carriers[r.team]
    local col = Timers.TeamColor(r.team)
    r.tag:SetText(r.side == "mine" and "ALLY" or "ENEMY")
    Theme.Paint(r.tag, col)
    local unit = c and c.name and Flags.CarrierUnit(r.team, c.name)
    if not (c and c.name) then
      -- arena token without a chat message (e.g. joined mid-game)
      local u = Flags.CarrierUnit(r.team, nil)
      local okN, n
      if u then okN, n = pcall(UnitName, u) end
      if okN and Timers.plain(n) and n then
        c = { name = n, since = nil }
        Flags.carriers[r.team] = c
        Flags.lastCarrier[r.team] = n
        unit = u
      end
    end
    if c and c.name then
      local short = c.name:match("^[^-]+")
      local class, specIcon
      if unit then
        local okC, _, cl = pcall(UnitClass, unit)
        class = okC and Timers.plain(cl) and cl or nil
      end
      if ns.EnemyKeyByName and r.team ~= me then
        local k = ns.EnemyKeyByName(c.name)
        local e = k and ns.enemies[k]
        class = class or (e and e.class)
        local si = e and e.specID and ns.Core and ns.Core.specInfo[e.specID]
        specIcon = si and si.icon
      end
      local cc = ns.Util.ClassColor(class)
      if specIcon then
        r.icon:SetTexture(specIcon)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon:Show()
      elseif class then
        Kit.ClassIcon(r.icon, class)
      else
        r.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_0" .. (r.team == "A" and "2" or "1"))
        r.icon:SetTexCoord(0, 1, 0, 1)
        r.icon:Show()
      end
      local hp, drawn = Hud.Health(r.bar, unit)
      local bc = cc and Core.BarColor(cc, r.team)
      Timers.BarColor(r.bar, bc or col, drawn and Timers.BAR_SEEN or Timers.BAR_UNSEEN)
      r.name:SetText(short)
      local stacks = ns.FlagStacks and ns.FlagStacks()
      local parts = {}
      if hp then
        parts[#parts + 1] = string.format("%d%%", hp * 100 + 0.5)
      end
      if stacks and objective == "flag" then
        parts[#parts + 1] = "x" .. stacks
      end
      if c.since then
        parts[#parts + 1] = Timers.Clock(now - c.since)
      end
      r.right:SetText(table.concat(parts, "  "))
      Theme.Paint(r.right, hp and hp < 0.35 and "danger" or "text")
    else
      r.icon:Hide()
      r.bar:SetValue(0)
      local dropped = c and c.dropped and now - c.dropped < 15
      r.name:SetText(dropped and "Flag dropped" or "No carrier seen")
      r.right:SetText(dropped and Timers.Clock(now - c.dropped) or "")
      Theme.Paint(r.right, "textMuted")
    end
    if r.macroFor ~= (c and c.name) or r.macroTeam ~= r.team then
      Flags.SetMacros()
    end
  end
  if Timers.SecureShow(Flags.flagWin) and ns.Dock then ns.Dock() end
end
