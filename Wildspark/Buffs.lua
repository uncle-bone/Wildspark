-- WildBuffs: press one button, buff the next nearby player who needs your buff.
-- WoW won't let addons cast on their own, so the addon picks the target and you press the button.

local ADDON_NAME = "WildBuffs"
local SKIP_PVP   = true   -- don't flag yourself by buffing PvP-flagged players
local SKIP_SECONDS = 10   -- skip a player this long after LoS / invalid target errors
local BOUNCED_SECONDS = 900 -- after "A more powerful spell is already active", skip THAT buff on that player for 15 min
local SAY_EVERY = 50      -- milestone /say every this many casts (fixed)
local REFRESH_DEFAULT = 30 -- minutes: recast if a buff has this much time or less left (set in options)

-- Names shown in Options > Keybindings > AddOns
BINDING_HEADER_WILDBUFFS = ADDON_NAME
_G["BINDING_NAME_CLICK WildBuffsButton:LeftButton"] = "Buff next player"

local function UsesMana(unit) return UnitPowerType(unit) == 0 end

-- per-character settings (paladin order, druid thorns)
local function S() return (ForeverBuffs_CharDB and ForeverBuffs_CharDB.settings) or {} end

---------------------------------------------------------------------------
-- Class configs. Buffs are checked top to bottom; first one that fits wins.
--   spell    = name to cast           same = aura names that count as "already has it"
--   ranks    = { spellID, level learned } highest first
--   duration = seconds the buff lasts (for the "hours handed out" stat)
--   when     = optional: only give this buff if when(unit) is true
-- exclusive = true: you can only have ONE of your own buffs from this list on a player
---------------------------------------------------------------------------
local CONFIG = {
  MAGE = {
    buffs = {
      { spell = "Arcane Intellect", sameIDs = {1459, 23028}, duration = 3600,
        same  = { "Arcane Intellect", "Arcane Brilliance" },
        ranks = { {10157,56}, {10156,42}, {1461,28}, {1460,14}, {1459,1} },
        when  = function(u) return UsesMana(u) or S().aiEveryone == true end },
    },
  },

  PRIEST = {
    buffs = {
      { spell = "Power Word: Fortitude", sameIDs = {1243, 21562}, duration = 3600,
        same  = { "Power Word: Fortitude", "Prayer of Fortitude" },
        ranks = { {10938,60}, {10937,48}, {2791,36}, {1245,24}, {1244,12}, {1243,1} } },
      { spell = "Divine Spirit", sameIDs = {14752, 27681}, duration = 3600,
        same  = { "Divine Spirit", "Prayer of Spirit" },
        ranks = { {27841,60}, {14819,50}, {14818,40}, {14752,30} } },
      { spell = "Shadow Protection", sameIDs = {976, 27683}, duration = 600,
        same  = { "Shadow Protection", "Prayer of Shadow Protection" },
        ranks = { {10958,56}, {10957,42}, {976,30} },
        when  = function() return S().shadowProt == true end },
    },
  },

  DRUID = {
    buffs = {
      { spell = "Mark of the Wild", sameIDs = {1126, 21849}, duration = 3600,
        same  = { "Mark of the Wild", "Gift of the Wild" },
        ranks = { {9885,60}, {9884,50}, {8907,40}, {5234,30}, {6756,20}, {5232,10}, {1126,1} } },
      { spell = "Thorns", sameIDs = {467}, duration = 600,
        same  = { "Thorns" },
        ranks = { {9910,44}, {9756,34}, {8914,24}, {1075,14}, {782,6}, {467,1} },
        when  = function() return S().thorns == true end },
    },
  },

  PALADIN = {
    exclusive = true,
    buffs = {
      { key = "K", spell = "Blessing of Kings", sameIDs = {20217, 25898}, duration = 3600,
        same  = { "Blessing of Kings", "Greater Blessing of Kings" },
        ranks = { {20217,20} } },
      { key = "W", spell = "Blessing of Wisdom", sameIDs = {19742, 25894}, duration = 3600,
        same  = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
        ranks = { {25290,60}, {19854,54}, {19853,44}, {19852,34}, {19850,24}, {19742,14} } },
      { key = "M", spell = "Blessing of Might", sameIDs = {19740, 25782}, duration = 3600,
        same  = { "Blessing of Might", "Greater Blessing of Might" },
        ranks = { {25291,60}, {19838,52}, {19837,42}, {19836,32}, {19835,22}, {19834,12}, {19740,4} } },
    },
    -- order to try, based on the player and your /wildbuffs setup choices
    order = function(unit, k)
      -- the third blessing is a fallback, so everyone can always get something from you
      if UsesMana(unit) then
        if S().manaFirst == "W" then return { k.W, k.K, k.M } end
        return { k.K, k.W, k.M }
      else
        if S().meleeFirst == "M" then return { k.M, k.K, k.W } end
        return { k.K, k.M, k.W }
      end
    end,
  },
}

local _, CLASS = UnitClass("player")
local CFG = CONFIG[CLASS]
if not CFG then
  _G.WildBuffs = { supported = false, class = CLASS }
  return
end

-- Localization: get each buff's name in the game's language from its spell ID,
-- so detection and casting work on German, French, etc. clients.
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  return (GetSpellInfo(id))
end
for _, b in ipairs(CFG.buffs) do
  b.name = SpellName(b.ranks[#b.ranks][1]) or b.spell     -- cast/display name
  for _, id in ipairs(b.sameIDs or {}) do
    local n = SpellName(id)
    if n then b.same[#b.same + 1] = n end                 -- English names stay as a fallback
  end
end

CFG.byKey = {}
for _, b in ipairs(CFG.buffs) do if b.key then CFG.byKey[b.key] = b end end

local MY_NAMES = {}
for _, b in ipairs(CFG.buffs) do
  for _, n in ipairs(b.same) do MY_NAMES[n] = true end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- present[name] = seconds left on that buff (huge if the game doesn't say)
-- mineName/mineRem = one of YOUR buffs from this class's list, if they have one
local function ScanAuras(unit)
  local present, mineName, mineRem = {}, nil, nil
  local now = GetTime()
  for i = 1, 40 do
    local name, source, dur, expires
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      -- Forever uses the modern C_UnitAuras API. Aura access can be denied
      -- for restricted unit tokens; isolate that failure to this unit/index.
      local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
      if not ok or not aura then break end
      local readOK
      readOK, name, source, dur, expires = pcall(function()
        return aura.name, aura.sourceUnit, aura.duration, aura.expirationTime
      end)
      if not readOK then break end
    elseif UnitBuff then
      -- Compatibility fallback for clients that still expose the legacy API.
      local ok, n, _, _, d, e, src = pcall(UnitBuff, unit, i)
      if not ok or not n then break end
      name, source, dur, expires = n, src, d, e
    else
      break
    end

    -- Ignore incomplete aura records rather than indexing a table with nil.
    if name then
      local rem = math.huge
      if type(dur) == "number" and dur > 0 and type(expires) == "number" and expires > 0 then
        rem = math.max(0, expires - now)
      end
      if not present[name] or rem > present[name] then present[name] = rem end
      if MY_NAMES[name] and source and UnitIsUnit(source, "player") then
        mineName, mineRem = name, rem
      end
    end
  end
  return present, mineName, mineRem
end

-- Highest rank you know that this target can receive.
-- Rule: target level + 10 must be >= the level the rank is learned at.
-- (This client does NOT auto-downrank, so we pick the rank ourselves.)
local function PickRank(unit, ranks)
  local lvl = UnitLevel(unit)
  if not lvl or lvl <= 0 then lvl = 999 end   -- unknown/skull: use top rank
  for _, r in ipairs(ranks) do
    if IsPlayerSpell(r[1]) and lvl + 10 >= r[2] then return r[1] end
  end
end

local function InRange(unit, spell)
  if UnitIsUnit(unit, "player") then return true end
  local r
  if C_Spell and C_Spell.IsSpellInRange then
    r = C_Spell.IsSpellInRange(spell, unit)
  else
    r = IsSpellInRange(spell, unit)
  end
  return r == true or r == 1
end

local function SpellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
  return GetSpellTexture(id)
end

-- refresh when this much time or less is left; never more than half the buff
-- (so short buffs like Thorns don't get recast constantly)
local function Threshold(b)
  local m = (ForeverBuffs_DB and ForeverBuffs_DB.refreshMin) or REFRESH_DEFAULT
  return math.min(m * 60, b.duration * 0.5)
end

-- blocked[guid][buff.spell] = time: that buff "bounced" on that player
-- ("A more powerful spell is already active"), so try their next buff instead
local blocked = {}
local function IsBlocked(guid, b)
  local t = guid and blocked[guid] and blocked[guid][b.spell]
  return t and t > GetTime()
end

local function ChooseBuff(unit, guid, present, mineName, mineRem)
  if not present then present, mineName, mineRem = ScanAuras(unit) end

  -- Paladin-style: they already have one of yours. Skip it, or refresh that same one if it's low.
  if CFG.exclusive and mineName then
    for _, b in ipairs(CFG.buffs) do
      for _, n in ipairs(b.same) do
        if n == mineName then
          if mineRem > Threshold(b) or IsBlocked(guid, b) then return end
          local id = PickRank(unit, b.ranks)
          if id then return b, id end
          return
        end
      end
    end
    return
  end

  local list = CFG.order and CFG.order(unit, CFG.byKey) or CFG.buffs
  for _, b in ipairs(list) do
    if (not b.when or b.when(unit)) and not IsBlocked(guid, b) then
      local has = false
      for _, n in ipairs(b.same) do
        if present[n] and present[n] > Threshold(b) then has = true break end
      end
      if not has then
        local id = PickRank(unit, b.ranks)
        if id then return b, id end
      end
    end
  end
end

local function ChooseSpecificBuff(unit, guid, wanted, present, mineName, mineRem)
  if not present then present, mineName, mineRem = ScanAuras(unit) end
  if wanted.when and not wanted.when(unit) then return end
  if IsBlocked(guid, wanted) then return end

  if CFG.exclusive and mineName then
    local mineBuff
    for _, candidate in ipairs(CFG.buffs) do
      for _, name in ipairs(candidate.same) do
        if name == mineName then mineBuff = candidate; break end
      end
      if mineBuff then break end
    end
    if mineBuff ~= wanted or mineRem > Threshold(wanted) then return end
  else
    for _, name in ipairs(wanted.same) do
      if present[name] and present[name] > Threshold(wanted) then return end
    end
  end

  return PickRank(unit, wanted.ranks)
end

local function BasicOK(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
  if not UnitIsFriend("player", unit) then return false end
  if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) or not UnitIsVisible(unit) then return false end
  if SKIP_PVP and UnitIsPVP(unit) and not UnitIsPVP("player") then return false end
  return true
end

local UNITS = { "player", "target", "focus" }
for i = 1, 4  do UNITS[#UNITS + 1] = "party" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "raid" .. i end
for i = 1, 40 do UNITS[#UNITS + 1] = "nameplate" .. i end

local skipUntil = {}

local function FindTarget()
  local fUnit, fBuff, fID, count = nil, nil, nil, 0
  local byBuff = {}
  local seen, now = {}, GetTime()
  for _, unit in ipairs(UNITS) do
    if BasicOK(unit) then
      local guid = UnitGUID(unit)
      if guid and not seen[guid] and not (skipUntil[guid] and skipUntil[guid] > now) then
        seen[guid] = true
        local present, mineName, mineRem = ScanAuras(unit)
        local b, id = ChooseBuff(unit, guid, present, mineName, mineRem)
        if b and InRange(unit, b.name) then
          count = count + 1
          if not fUnit then fUnit, fBuff, fID = unit, b, id end
        end
        for _, candidate in ipairs(CFG.buffs) do
          local spellID = ChooseSpecificBuff(unit, guid, candidate, present, mineName, mineRem)
          if spellID and InRange(unit, candidate.name) then
            if byBuff[candidate] then
              byBuff[candidate].count = byBuff[candidate].count + 1
            else
              byBuff[candidate] = { unit = unit, spellID = spellID, count = 1 }
            end
          end
        end
      end
    end
  end
  return fUnit, fBuff, fID, count, byBuff
end

---------------------------------------------------------------------------
-- Stats + bragging
---------------------------------------------------------------------------
local pendingSay   -- message to /say on the next button press

local function FormatTime(sec)
  local h = sec / 3600
  if h >= 1 then
    local n = math.floor(h)
    return n .. (n == 1 and " hour" or " hours")
  end
  local m = math.floor(sec / 60)
  return m .. (m == 1 and " minute" or " minutes")
end

local function RecordBuff(buff)
  ForeverBuffs_CharDB.buffs = ForeverBuffs_CharDB.buffs or {}
  local st = ForeverBuffs_CharDB.buffs[buff.spell] or { count = 0, seconds = 0 }
  st.count   = st.count + 1
  st.seconds = st.count * buff.duration
  ForeverBuffs_CharDB.buffs[buff.spell] = st

  local every = SAY_EVERY
  if ForeverBuffs_DB.say == true and st.count % every == 0 then
    pendingSay = ("I've handed out %s of %s to random players with %s!"):format(
      FormatTime(st.seconds), buff.name, ADDON_NAME)
  end
end

---------------------------------------------------------------------------
-- UI: compact action-bar-sized icon, name to the right. Shift+drag to move.
---------------------------------------------------------------------------
local holder = CreateFrame("Frame", "WildBuffsFrame", UIParent)
holder:SetSize(36, 36)
holder:SetPoint("CENTER")
holder:SetMovable(true)
holder:SetClampedToScreen(true)

-- show/hide the button, optionally hiding it in combat (uses a secure driver so it works mid-fight)
-- off inside dungeons/raids unless the player turns that option off
local function PausedHere()
  if not ForeverBuffs_DB or ForeverBuffs_DB.instanceOff == false then return false end
  local inInst, kind = IsInInstance()
  return inInst and (kind == "party" or kind == "raid")
end

local function UpdateVisibility()
  if InCombatLockdown() then return end
  UnregisterStateDriver(holder, "visibility")
  if ForeverBuffs_DB and (ForeverBuffs_DB.hidden or PausedHere()) then
    holder:Hide()
  elseif ForeverBuffs_DB and ForeverBuffs_DB.hideInCombat then
    RegisterStateDriver(holder, "visibility", "[combat] hide; show")
  else
    holder:Show()
  end
end

local btn = CreateFrame("Button", "WildBuffsButton", holder, "SecureActionButtonTemplate")
btn:SetAllPoints()
btn:RegisterForClicks("AnyUp", "AnyDown")
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function()
  if IsShiftKeyDown() and not InCombatLockdown() then holder:StartMoving() end
end)
btn:SetScript("OnDragStop", function()
  holder:StopMovingOrSizing()
  local p, _, rp, x, y = holder:GetPoint()
  ForeverBuffs_DB.pos = { p, rp, x, y }
end)

local function UpdateRotatingButtonVisibility()
  if InCombatLockdown() then return end
  if ForeverBuffs_DB and ForeverBuffs_DB.showRotating == false then
    btn:Hide()
  else
    btn:Show()
  end
end

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
icon:SetTexture(SpellIcon(CFG.buffs[1].ranks[#CFG.buffs[1].ranks][1]))
btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

local bg = btn:CreateTexture(nil, "OVERLAY")
bg:SetAllPoints()

local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("LEFT", btn, "RIGHT", 6, 0)
label:SetJustifyH("LEFT")

-- "+N waiting", matching the name
local moreText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")  -- same font/color as the name
moreText:SetPoint("LEFT", label, "RIGHT", 6, 0)

-- flashy glow when someone new needs a buff
local glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
glow:SetBlendMode("ADD")
glow:SetVertexColor(1, 0.85, 0.3)
glow:SetSize(72, 72)
glow:SetPoint("CENTER")
glow:SetAlpha(0)
-- pulse driven by our own timer (more reliable than animation groups on this client)
local glowOn, glowT = false, 0
local glowDriver = CreateFrame("Frame", nil, btn)
glowDriver:SetScript("OnUpdate", function(_, dt)
  if not glowOn then return end
  glowT = glowT + dt
  glow:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin(glowT * 6)))
end)
local function SetGlow(on)
  if on == glowOn then return end
  glowOn, glowT = on, 0
  if not on then glow:SetAlpha(0) end
end

-- WildBuffs never changes friendly nameplate CVars. It only scans nameplates the user already has enabled.
local DEBUG = false
local cur = {}     -- current pick: guid, buff, spellID, saying
local last = {}    -- what the last real press was aimed at
local spellButtons = {}
local spellButtonByBuff = {}
local lastBoundKey, lastBoundName
local ApplyBinding

local function SpellCastName(buff, spellID)
  local name = buff.name
  local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
  if not sub or sub == "" then
    for i, rank in ipairs(buff.ranks) do
      if rank[1] == spellID then sub = "Rank " .. (#buff.ranks - i + 1); break end
    end
  end
  if #buff.ranks > 1 and sub and sub ~= "" then name = name .. "(" .. sub .. ")" end
  return name
end

local function CastMacro(unit, buff, spellID)
  local castName = SpellCastName(buff, spellID)
  local text
  if unit:find("^nameplate") then
    local name = UnitName(unit)
    local restore = UnitExists("target") and "/targetlasttarget" or "/cleartarget"
    text = "/target " .. name .. "\n/cast [@target,help,nodead] " .. castName .. "\n" .. restore
  else
    text = "/cast [@" .. unit .. ",help,nodead] " .. castName
  end
  if pendingSay then text = text .. "\n/say " .. pendingSay end
  return text
end

local function CreateSpellButton(buff, index)
  local button = CreateFrame("Button", "WildBuffsSpellButton" .. index, holder, "SecureActionButtonTemplate")
  button:SetSize(36, 36)
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnDragStart", function()
    if IsShiftKeyDown() and not InCombatLockdown() then holder:StartMoving() end
  end)
  button:SetScript("OnDragStop", function()
    holder:StopMovingOrSizing()
    local p, _, rp, x, y = holder:GetPoint()
    ForeverBuffs_DB.pos = { p, rp, x, y }
  end)
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
  local texture = button:CreateTexture(nil, "ARTWORK")
  texture:SetAllPoints()
  texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  texture:SetTexture(SpellIcon(buff.ranks[#buff.ranks][1]))
  local bg = button:CreateTexture(nil, "OVERLAY")
  bg:SetAllPoints()
  local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", button, "RIGHT", 6, 0)
  label:SetJustifyH("LEFT")
  local moreText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  moreText:SetPoint("LEFT", label, "RIGHT", 6, 0)
  local glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.85, 0.3)
  glow:SetSize(72, 72)
  glow:SetPoint("CENTER")
  glow:SetAlpha(0)
  local glowState, glowT = false, 0
  local glowDriver = CreateFrame("Frame", nil, button)
  glowDriver:SetScript("OnUpdate", function(_, dt)
    if not glowState then return end
    glowT = glowT + dt
    glow:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin(glowT * 6)))
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(buff.name)
    GameTooltip:AddLine("Click to buff the next nearby player who needs this spell.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:HookScript("PreClick", function(self, mouse, down)
    if down ~= GetCVarBool("ActionButtonUseKeyDown") then return end
    local state = self.wildBuffState
    last.guid, last.buff, last.spellID, last.time = state and state.guid, buff, state and state.spellID, GetTime()
    last.isSelf = state and state.unit and UnitIsUnit(state.unit, "player")
    if state and state.saying then pendingSay = nil end
  end)
  local state = { button = button, buff = buff, texture = texture, bg = bg,
    label = label, moreText = moreText, glow = glow }
  state.SetGlow = function(on)
    if on == glowState then return end
    glowState, glowT = on, 0
    if not on then glow:SetAlpha(0) end
  end
  button.wildBuffState = state
  return state
end

local function UpdateSpellButtons(targets)
  if InCombatLockdown() then return end
  local active = {}
  for _, buff in ipairs(CFG.buffs) do
    if (not buff.when or buff.when("player")) then
      local spellID = PickRank("player", buff.ranks)
      if spellID then active[#active + 1] = { buff = buff, spellID = spellID } end
    end
  end

  if #active == 0 or (#active < 2 and ForeverBuffs_DB.showRotating ~= false) then
    for _, state in ipairs(spellButtons) do
      state.button:SetAttribute("type", nil)
      state.button:SetAttribute("macrotext", nil)
      state.button:Hide()
    end
    return
  end

  for index, item in ipairs(active) do
    local buff, spellID = item.buff, item.spellID
    local state = spellButtonByBuff[buff]
    if not state then
      state = CreateSpellButton(buff, index)
      spellButtonByBuff[buff] = state
      spellButtons[#spellButtons + 1] = state
    end
    local button, target = state.button, targets and targets[buff]
    button:ClearAllPoints()
    -- With the rotating button disabled, the first spell button occupies its place.
    if index == 1 and ForeverBuffs_DB.showRotating == false then
      button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    else
      local anchor = index == 1 and btn or spellButtonByBuff[active[index - 1].buff].button
      button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    end
    state.texture:SetTexture(SpellIcon(spellID))
    state.target, state.spellID = target and target.unit, target and target.spellID
    state.guid = state.target and UnitGUID(state.target)
    state.saying = target ~= nil and pendingSay ~= nil
    if target then
      button:SetAttribute("type", "macro")
      button:SetAttribute("macrotext", CastMacro(target.unit, buff, target.spellID))
      button:SetAlpha(1)
      button:Enable()
      state.label:SetText(UnitName(target.unit) or "?")
      state.label:SetTextColor(1, 0.82, 0)
      state.moreText:SetText(target.count > 1 and ("+" .. (target.count - 1)) or "")
      state.bg:SetColorTexture(0, 0, 0, 0)
      state.SetGlow(ForeverBuffs_DB.flash ~= false)
    else
      button:SetAttribute("type", nil)
      button:SetAttribute("macrotext", nil)
      button:SetAlpha(0.45)
      button:Disable()
      state.label:SetText("Nobody to buff")
      state.label:SetTextColor(0.55, 0.55, 0.55)
      state.moreText:SetText("")
      state.bg:SetColorTexture(0, 0, 0, 0.65)
      state.SetGlow(false)
    end
    button:Show()
  end

  for _, state in ipairs(spellButtons) do
    local activeBuff = false
    for _, item in ipairs(active) do if item.buff == state.buff then activeBuff = true; break end end
    if not activeBuff then
      state.button:SetAttribute("type", nil)
      state.button:SetAttribute("macrotext", nil)
      state.SetGlow(false)
      state.button:Hide()
    end
  end
end

btn:HookScript("PreClick", function(self, mouse, down)
  -- the button only acts on one of down/up, matching this CVar
  if down ~= GetCVarBool("ActionButtonUseKeyDown") then return end
  last.guid, last.buff, last.spellID, last.time = cur.guid, cur.buff, cur.spellID, GetTime()
  last.isSelf = cur.isSelf
  if cur.saying then pendingSay = nil end
  if DEBUG then
    local mt = self:GetAttribute("macrotext")
    print("WildBuffs: " .. tostring(self:GetAttribute("type")) .. " | " .. (mt and mt:gsub("\n", " | ") or "nil"))
  end
end)

---------------------------------------------------------------------------
-- Scan loop (attributes can only change out of combat)
---------------------------------------------------------------------------
local t = 0
holder:SetScript("OnUpdate", function(_, dt)
  t = t + dt
  if t < 0.25 then return end
  t = 0

  if InCombatLockdown() then
    SetGlow(false)
    moreText:SetText("")
    label:SetText("In combat")
    bg:SetColorTexture(0.5, 0, 0, 0.6)
    return
  end

  -- never let a scan error spam popups (some fights restrict what addons can read)
  local ok, unit, buff, spellID, count, byBuff = pcall(FindTarget)
  if not ok then unit, buff, spellID, count, byBuff = nil, nil, nil, 0, {} end
  UpdateSpellButtons(byBuff)
  ApplyBinding()
  cur.guid, cur.buff, cur.spellID, cur.saying = unit and UnitGUID(unit), buff, spellID, nil
  cur.isSelf = unit and UnitIsUnit(unit, "player")
  SetGlow(unit ~= nil and ForeverBuffs_DB.flash ~= false)

  if unit then
    -- Name the exact rank, e.g. "Blessing of Might(Rank 2)". The rank text comes from
    -- the game so it's in the player's language; fall back to "Rank N".
    local castName = buff.name
    local sub = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    if not sub or sub == "" then
      for i, r in ipairs(buff.ranks) do
        if r[1] == spellID then sub = "Rank " .. (#buff.ranks - i + 1) break end
      end
    end
    -- single-rank spells (Kings) have no rank, and "(Rank 1)" makes /cast silently fail
    if #buff.ranks > 1 and sub and sub ~= "" then castName = castName .. "(" .. sub .. ")" end

    local text
    if unit:find("^nameplate") then
      -- This client won't cast straight onto a nameplate unit, so target them
      -- by first name, cast, then put your target back.
      local name = UnitName(unit)   -- first name only (2nd return is the WoW Forever 2nd name)
      local restore = UnitExists("target") and "/targetlasttarget" or "/cleartarget"
      text = "/target " .. name .. "\n/cast [@target,help,nodead] " .. castName .. "\n" .. restore
    else
      text = "/cast [@" .. unit .. ",help,nodead] " .. castName
    end
    if pendingSay then
      text = text .. "\n/say " .. pendingSay
      cur.saying = true
    end

    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", text)
    icon:SetTexture(SpellIcon(spellID))
    label:SetText(UnitName(unit) or "?")
    moreText:SetText(count > 1 and ("+" .. (count - 1)) or "")
    bg:SetColorTexture(0, 0, 0, 0)
  else
    btn:SetAttribute("type", nil)
    moreText:SetText("")
    label:SetText("|cff888888Nobody to buff|r")
    bg:SetColorTexture(0, 0, 0, 0.65)
  end
end)

---------------------------------------------------------------------------
-- Events: count successful casts, skip players after LoS-type errors
---------------------------------------------------------------------------
local SKIP_ERRORS = {}
for _, k in ipairs({ "SPELL_FAILED_LINE_OF_SIGHT", "SPELL_FAILED_BAD_TARGETS",
                     "SPELL_FAILED_OUT_OF_RANGE", "SPELL_FAILED_TARGET_NOT_IN_RANGE",
                     "SPELL_FAILED_LOWLEVEL" }) do
  if _G[k] then SKIP_ERRORS[_G[k]] = true end
end

ApplyBinding = function()
  if InCombatLockdown() then return end
  local bindingButton = btn
  if ForeverBuffs_DB.showRotating == false then
    for _, state in ipairs(spellButtons) do
      if state.button:IsShown() then bindingButton = state.button; break end
    end
  end
  local bindingName = bindingButton:GetName() or "WildBuffsButton"
  if lastBoundKey == ForeverBuffs_DB.key and lastBoundName == bindingName then return end
  ClearOverrideBindings(btn)
  lastBoundKey, lastBoundName = ForeverBuffs_DB.key, bindingName
  if ForeverBuffs_DB.key then
    SetOverrideBindingClick(btn, true, ForeverBuffs_DB.key, bindingName, "LeftButton")
  end
end

---------------------------------------------------------------------------
-- Options window (/wildbuffs, or click the minimap icon)
---------------------------------------------------------------------------
local opt
local refreshers = {}

local function RefreshOptions()
  for _, f in ipairs(refreshers) do f() end
end

local function StatsText()
  local lines = { "|cff66ccffStats - " .. UnitName("player") .. "|r" }
  local any = false
  for _, b in ipairs(CFG.buffs) do
    local st = ForeverBuffs_CharDB.buffs[b.spell]
    if st then
      any = true
      lines[#lines + 1] = ("%s: %d casts, %s"):format(b.name, st.count, FormatTime(st.seconds))
    end
  end
  if not any then lines[#lines + 1] = "Nothing yet. Go make some strangers' day." end
  return table.concat(lines, "\n")
end

local function CurrentKey()
  return ForeverBuffs_DB.key or GetBindingKey("CLICK WildBuffsButton:LeftButton")
end

-- waits for the next key press and binds it
local capture = CreateFrame("Frame", nil, UIParent)
capture:Hide()
capture:EnableKeyboard(true)
capture:SetPropagateKeyboardInput(false)
capture:SetFrameStrata("TOOLTIP")
local MODS = { LSHIFT=1, RSHIFT=1, LCTRL=1, RCTRL=1, LALT=1, RALT=1 }
capture:SetScript("OnKeyDown", function(self, key)
  if MODS[key] then return end
  self:Hide()
  if key ~= "ESCAPE" and not InCombatLockdown() then
    local p = ""
    if IsAltKeyDown() then p = p .. "ALT-" end
    if IsControlKeyDown() then p = p .. "CTRL-" end
    if IsShiftKeyDown() then p = p .. "SHIFT-" end
    ForeverBuffs_DB.key = p .. key
    ApplyBinding()
  end
  RefreshOptions()
end)

local function OpenOptions()
  if opt then
    if opt:IsShown() then opt:Hide() else RefreshOptions(); opt:Show() end
    return
  end

  local classRows = (CLASS == "PALADIN" and 2) or ((CLASS == "DRUID" or CLASS == "PRIEST" or CLASS == "MAGE") and 1) or 0
  opt = CreateFrame("Frame", "WildBuffsOptions", UIParent, "BasicFrameTemplateWithInset")
  opt:SetSize(330, 527 + classRows * 66)
  opt:SetPoint("CENTER")
  opt:SetFrameStrata("DIALOG")
  opt:SetMovable(true); opt:EnableMouse(true); opt:SetClampedToScreen(true)
  opt:RegisterForDrag("LeftButton")
  opt:SetScript("OnDragStart", opt.StartMoving)
  opt:SetScript("OnDragStop", opt.StopMovingOrSizing)
  tinsert(UISpecialFrames, "WildBuffsOptions")   -- Esc closes it

  local title = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("WildBuffs")

  local y = -34
  local function Header(text)
    local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    y = y - 20
  end

  local function Check(text, get, set)
    local cb = CreateFrame("CheckButton", nil, opt, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 14, y)
    local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(text)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); RefreshOptions() end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(get() and true or false) end
    y = y - 26
    return cb
  end

  -- radio list: one option per line, selected one is bright with a filled dot
  local function Choice(text, opts, key)
    local fs = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 18, y)
    fs:SetText(text)
    y = y - 18
    local items = {}
    for i, o in ipairs(opts) do
      local rb = CreateFrame("CheckButton", nil, opt, "UIRadioButtonTemplate")
      rb:SetSize(18, 18)
      rb:SetPoint("TOPLEFT", 26, y)
      local lfs = opt:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      lfs:SetPoint("LEFT", rb, "RIGHT", 6, 0)
      lfs:SetText(o[1])
      rb:SetHitRectInsets(0, -(lfs:GetStringWidth() + 10), 0, 0)   -- clicking the text works too
      rb:SetScript("OnClick", function() ForeverBuffs_CharDB.settings[key] = o[2]; RefreshOptions() end)
      items[i] = { rb = rb, fs = lfs, v = o[2] }
      y = y - 20
    end
    refreshers[#refreshers + 1] = function()
      for _, x in ipairs(items) do
        local on = (x.v == S()[key])
        x.rb:SetChecked(on)
        if on then x.fs:SetTextColor(0.3, 1, 0.3) else x.fs:SetTextColor(0.55, 0.55, 0.55) end
      end
    end
    y = y - 8
  end

  -- General
  Header("General")
  Check("Show buff button",
    function() return not ForeverBuffs_DB.hidden end,
    function(v)
      if InCombatLockdown() then print("WildBuffs: not in combat.") return end
      ForeverBuffs_DB.hidden = not v or nil
      UpdateVisibility()
    end)
  Check("Show rotating all-buffs button",
    function() return ForeverBuffs_DB.showRotating ~= false end,
    function(v)
      if InCombatLockdown() then print("WildBuffs: not in combat.") return end
      ForeverBuffs_DB.showRotating = v
      UpdateRotatingButtonVisibility()
      ApplyBinding()
    end)
  Check("Turn off inside dungeons and raids",
    function() return ForeverBuffs_DB.instanceOff ~= false end,
    function(v)
      if InCombatLockdown() then print("WildBuffs: not in combat.") return end
      ForeverBuffs_DB.instanceOff = v
      UpdateVisibility()
    end)
  Check("Hide buff button in combat",
    function() return ForeverBuffs_DB.hideInCombat == true end,
    function(v)
      if InCombatLockdown() then print("WildBuffs: not in combat.") return end
      ForeverBuffs_DB.hideInCombat = v or nil
      UpdateVisibility()
    end)
  Check("Show minimap icon",
    function() return not ForeverBuffs_DB.mmHidden end,
    function(v)
      ForeverBuffs_DB.mmHidden = not v or nil
      local mm = _G.WildBuffsMinimapButton
      if mm then if v then mm:Show() else mm:Hide() end end
    end)
  Check("Glow when someone needs a buff",
    function() return ForeverBuffs_DB.flash ~= false end,
    function(v) ForeverBuffs_DB.flash = v end)

  local sl = CreateFrame("Slider", "WildBuffsScaleSlider", opt, "OptionsSliderTemplate")
  sl:SetPoint("TOPLEFT", 22, y - 16)
  sl:SetWidth(200)
  sl:SetMinMaxValues(0.5, 2.5)
  sl:SetValueStep(0.1)
  if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
  _G[sl:GetName() .. "Low"]:SetText("50%")
  _G[sl:GetName() .. "High"]:SetText("250%")
  local slText = _G[sl:GetName() .. "Text"]
  sl:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v * 10 + 0.5) / 10
    slText:SetText("Button size: " .. math.floor(v * 100 + 0.5) .. "%")
    if InCombatLockdown() or v == (ForeverBuffs_DB.scale or 1) then return end
    ForeverBuffs_DB.scale = v
    holder:SetScale(v)
  end)
  refreshers[#refreshers + 1] = function() sl:SetValue(ForeverBuffs_DB.scale or 1) end
  y = y - 48

  local rs = CreateFrame("Slider", "WildBuffsRefreshSlider", opt, "OptionsSliderTemplate")
  rs:SetPoint("TOPLEFT", 22, y - 16)
  rs:SetWidth(200)
  rs:SetMinMaxValues(0, 55)
  rs:SetValueStep(5)
  if rs.SetObeyStepOnDrag then rs:SetObeyStepOnDrag(true) end
  _G[rs:GetName() .. "Low"]:SetText("0")
  _G[rs:GetName() .. "High"]:SetText("55")
  local rsText = _G[rs:GetName() .. "Text"]
  rs:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / 5 + 0.5) * 5
    if v == 0 then rsText:SetText("Refresh: only when missing")
    else rsText:SetText("Refresh at " .. v .. " min or less left") end
    ForeverBuffs_DB.refreshMin = v
  end)
  refreshers[#refreshers + 1] = function() rs:SetValue(ForeverBuffs_DB.refreshMin or REFRESH_DEFAULT) end
  y = y - 48

  Check("Milestone /say every 50 casts",
    function() return ForeverBuffs_DB.say == true end,
    function(v) ForeverBuffs_DB.say = v end)

  -- keybind
  local kfs = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  kfs:SetPoint("TOPLEFT", 18, y - 4)
  local setKey = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
  setKey:SetSize(80, 22)
  setKey:SetPoint("TOPLEFT", 150, y)
  setKey:SetText("Set key")
  setKey:SetScript("OnClick", function()
    if InCombatLockdown() then print("WildBuffs: not in combat.") return end
    capture:Show(); kfs:SetText("Keybind: |cffffff00press a key...|r")
  end)
  local clrKey = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
  clrKey:SetSize(70, 22)
  clrKey:SetPoint("LEFT", setKey, "RIGHT", 6, 0)
  clrKey:SetText("Clear")
  clrKey:SetScript("OnClick", function()
    if InCombatLockdown() then return end
    ForeverBuffs_DB.key = nil; ApplyBinding(); RefreshOptions()
  end)
  refreshers[#refreshers + 1] = function()
    if not capture:IsShown() then kfs:SetText("Keybind: |cffffffff" .. (CurrentKey() or "none") .. "|r") end
  end
  y = y - 30

  local reset = CreateFrame("Button", nil, opt, "UIPanelButtonTemplate")
  reset:SetSize(170, 22)
  reset:SetPoint("TOPLEFT", 18, y)
  reset:SetText("Reset button position")
  reset:SetScript("OnClick", function()
    ForeverBuffs_DB.pos = nil
    holder:ClearAllPoints(); holder:SetPoint("CENTER")
  end)
  y = y - 36

  -- Class options
  if CLASS == "PALADIN" then
    Header("Paladin")
    Choice("Mana users:", { { "Kings  >  Wisdom  >  Might", "K" }, { "Wisdom  >  Kings  >  Might", "W" } }, "manaFirst")
    Choice("Everyone else:", { { "Kings  >  Might  >  Wisdom", "K" }, { "Might  >  Kings  >  Wisdom", "M" } }, "meleeFirst")
  elseif CLASS == "MAGE" then
    Header("Mage")
    Choice("Arcane Intellect on non-mana users:", { { "Off", false }, { "On", true } }, "aiEveryone")
  elseif CLASS == "PRIEST" then
    Header("Priest")
    Choice("Also cast Shadow Protection (10 min):", { { "Off", false }, { "On", true } }, "shadowProt")
  elseif CLASS == "DRUID" then
    Header("Druid")
    Choice("Also cast Thorns (10 min):", { { "Off", false }, { "On", true } }, "thorns")
  end

  -- Stats
  local stats = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  stats:SetPoint("TOPLEFT", 18, y - 4)
  stats:SetPoint("RIGHT", -16, 0)
  stats:SetJustifyH("LEFT")
  refreshers[#refreshers + 1] = function() stats:SetText(StatsText()) end

  opt:SetScript("OnShow", RefreshOptions)
  RefreshOptions()
  opt:Show()
end

_G.WildBuffs = {
  supported = true,
  class = CLASS,
  OpenOptions = OpenOptions,
  GetOption = function(key) return ForeverBuffs_DB and ForeverBuffs_DB[key] end,
  SetOption = function(key, value)
    if InCombatLockdown() then print("WildBuffs: change this setting out of combat."); return end
    ForeverBuffs_DB = ForeverBuffs_DB or {}
    ForeverBuffs_DB[key] = value and true or false
    if key == "hidden" or key == "instanceOff" or key == "hideInCombat" then UpdateVisibility() end
    if key == "mmHidden" then
      local button = _G.WildBuffsMinimapButton
      if button then if value then button:Hide() else button:Show() end end
    end
    RefreshOptions()
  end,
}
---------------------------------------------------------------------------
-- Minimap icon: left-click options, right-click show/hide button, drag to move
---------------------------------------------------------------------------
local mm = CreateFrame("Button", "WildBuffsMinimapButton", Minimap)
mm:Hide()
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local mmBg = mm:CreateTexture(nil, "BACKGROUND")
mmBg:SetSize(20, 20)
mmBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mmBg:SetPoint("TOPLEFT", 7, -5)
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("TOPLEFT", 6, -5)
mmIcon:SetTexture("Interface\\AddOns\\Wildspark\\Media\\icon.tga")
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetPoint("TOPLEFT")

local function PlaceMinimapButton()
  local a = math.rad(ForeverBuffs_DB.mmAngle or 200)
  local r = Minimap:GetWidth() / 2 + 10
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

mm:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local sc = Minimap:GetEffectiveScale()
    ForeverBuffs_DB.mmAngle = math.deg(math.atan2(py / sc - my, px / sc - mx))
    PlaceMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

mm:SetScript("OnClick", function(_, mouse)
  if mouse == "RightButton" then
    if InCombatLockdown() then print("WildBuffs: not in combat.") return end
    ForeverBuffs_DB.hidden = (not ForeverBuffs_DB.hidden) or nil
    UpdateVisibility()
    if opt and opt:IsShown() then RefreshOptions() end
  else
    OpenOptions()
  end
end)

mm:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine("WildBuffs")
  GameTooltip:AddLine("Left-click: options", 1, 1, 1)
  GameTooltip:AddLine("Right-click: show/hide buff button", 1, 1, 1)
  GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("UI_ERROR_MESSAGE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3)
  if event == "PLAYER_LOGIN" then
    ForeverBuffs_DB = ForeverBuffs_DB or {}
    ForeverBuffs_CharDB = ForeverBuffs_CharDB or {}
    ForeverBuffs_CharDB.buffs = ForeverBuffs_CharDB.buffs or {}
    local st0 = ForeverBuffs_CharDB.settings or {}
    ForeverBuffs_CharDB.settings = st0
    if st0.manaFirst == nil then st0.manaFirst = "K" end
    if st0.meleeFirst == nil then st0.meleeFirst = "K" end
    if st0.thorns == nil then st0.thorns = false end
    if st0.shadowProt == nil then st0.shadowProt = false end
    if st0.aiEveryone == nil then st0.aiEveryone = false end
    if ForeverBuffs_DB.mmHidden == nil then ForeverBuffs_DB.mmHidden = true end
    PlaceMinimapButton()
    if ForeverBuffs_DB.mmHidden then mm:Hide() else mm:Show() end
    -- recompute time from cast count, so duration changes apply to old casts too
    for _, b in ipairs(CFG.buffs) do
      local st = ForeverBuffs_CharDB.buffs[b.spell]
      if st then st.seconds = st.count * b.duration end
    end
    local pos = ForeverBuffs_DB.pos
    if pos then
      holder:ClearAllPoints()
      holder:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    holder:SetScale(ForeverBuffs_DB.scale or 1)
    UpdateRotatingButtonVisibility()
    UpdateVisibility()
    ApplyBinding()

  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if ForeverBuffs_DB then UpdateVisibility() end

  elseif event == "PLAYER_REGEN_ENABLED" then
    UpdateVisibility()
    UpdateRotatingButtonVisibility()
    ApplyBinding()

  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- a1 = unit, a2 = castGUID, a3 = spellID
    local match = false
    if last.buff and last.spellID then
      for _, r in ipairs(last.buff.ranks) do if r[1] == a3 then match = true break end end
    end
    if match and last.time and GetTime() - last.time < 3 then
      if not last.isSelf then RecordBuff(last.buff) end   -- buffing yourself doesn't count
      last.spellID = nil
    end

  elseif event == "UI_ERROR_MESSAGE" then
    local msg = (type(a1) == "number") and a2 or a1
    if not (msg and last.guid and last.time and GetTime() - last.time < 1.5) then return end
    if SKIP_ERRORS[msg] then
      skipUntil[last.guid] = GetTime() + SKIP_SECONDS
      if DEBUG then print("WildBuffs: skipping that player for " .. SKIP_SECONDS .. "s (" .. msg .. ")") end
      last.guid = nil
    elseif msg == SPELL_FAILED_AURA_BOUNCED and last.buff then
      blocked[last.guid] = blocked[last.guid] or {}
      blocked[last.guid][last.buff.spell] = GetTime() + BOUNCED_SECONDS
      if DEBUG then print("WildBuffs: " .. last.buff.name .. " blocked on that player for " .. BOUNCED_SECONDS .. "s; trying their next buff") end
      last.guid = nil
    end
  end
end)

---------------------------------------------------------------------------
-- Slash commands: /wildbuffs or /wb
---------------------------------------------------------------------------
SLASH_WILDBUFFS1, SLASH_WILDBUFFS2 = "/wildbuffs", "/wb"
SlashCmdList.WILDBUFFS = function(msg)
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()

  if cmd == "stats" then
    print("|cff66ccff" .. ADDON_NAME .. "|r - " .. UnitName("player") .. ":")
    local any = false
    for _, b in ipairs(CFG.buffs) do
      local st = ForeverBuffs_CharDB.buffs[b.spell]
      if st then
        any = true
        print(("  %s: %d casts, %s"):format(b.name, st.count, FormatTime(st.seconds)))
      end
    end
    if not any then print("  Nothing yet. Go make some strangers' day.") end
    return
  elseif cmd == "" or cmd == "setup" or cmd == "options" then
    OpenOptions()
    return
  elseif cmd == "minimap" then
    ForeverBuffs_DB.mmHidden = not ForeverBuffs_DB.mmHidden or nil
    if ForeverBuffs_DB.mmHidden then mm:Hide() else mm:Show() end
    print("WildBuffs: minimap icon " .. (ForeverBuffs_DB.mmHidden and "hidden" or "shown"))
    return
  elseif cmd == "say" then
    if arg == "on" then ForeverBuffs_DB.say = true
    elseif arg == "off" then ForeverBuffs_DB.say = false
    end
    print(("WildBuffs /say milestones: %s (every %d casts)"):format(
      ForeverBuffs_DB.say == true and "ON" or "OFF", SAY_EVERY))
    return
  end

  if InCombatLockdown() then print("WildBuffs: not in combat.") return end

  if cmd == "why" then
    -- explain why your current target is or isn't being picked
    local u = "target"
    local function say(m) print("|cff66ccffWildBuffs why:|r " .. m) end
    if not UnitExists(u) then say("target someone first") return end
    local nm = UnitName(u) or "?"
    if not UnitIsPlayer(u) then say(nm .. " is not a player") return end
    if not UnitIsFriend("player", u) then say(nm .. " is not friendly") return end
    if UnitIsDeadOrGhost(u) then say(nm .. " is dead") return end
    if not UnitIsConnected(u) then say(nm .. " is offline") return end
    if not UnitIsVisible(u) then say(nm .. " is not visible") return end
    if SKIP_PVP and UnitIsPVP(u) and not UnitIsPVP("player") then say(nm .. " is PvP flagged and you are not") return end
    local g = UnitGUID(u)
    if skipUntil[g] and skipUntil[g] > GetTime() then
      say(("%s is skipped for %ds (line of sight / range / low level error)"):format(nm, skipUntil[g] - GetTime())) return
    end
    say(("%s: level %s, %s"):format(nm, tostring(UnitLevel(u)), UsesMana(u) and "mana user" or "non-mana"))
    local present, mineName, mineRem = ScanAuras(u)
    if mineName then say(("has your %s, %s left"):format(mineName, FormatTime(mineRem == math.huge and 0 or mineRem))) end
    local list = CFG.order and CFG.order(u, CFG.byKey) or CFG.buffs
    for _, b in ipairs(list) do
      local why
      if b.when and not b.when(u) then why = "not for this player / option off"
      elseif IsBlocked(g, b) then why = "blocked ('more powerful spell' error)"
      elseif not PickRank(u, b.ranks) then why = "you don't know it, or they're too low level"
      else
        for _, n in ipairs(b.same) do
          if present[n] then
            local r = present[n]
            why = (r > Threshold(b)) and ("already has " .. n .. (r == math.huge and "" or (", " .. FormatTime(r) .. " left"))) or nil
            break
          end
        end
      end
      say(b.name .. ": " .. (why or "|cff00ff00needs it|r"))
    end
    local b = ChooseBuff(u, g)
    if b then
      say("would cast " .. b.name .. (InRange(u, b.name) and "" or " |cffff5555but out of range|r"))
    else
      say("nothing to cast")
    end
    return
  elseif cmd == "debug" then
    DEBUG = not DEBUG
    print("FB debug: " .. (DEBUG and "ON" or "OFF"))
  elseif cmd == "bind" and arg ~= "" then
    ForeverBuffs_DB.key = arg:upper()
    ApplyBinding()
    print("WildBuffs: bound to " .. ForeverBuffs_DB.key)
  elseif cmd == "unbind" then
    ForeverBuffs_DB.key = nil
    ApplyBinding()
    print("WildBuffs: keybind removed")
  elseif cmd == "hide" then
    ForeverBuffs_DB.hidden = true; UpdateVisibility()
  elseif cmd == "show" then
    ForeverBuffs_DB.hidden = nil; UpdateVisibility()
  elseif cmd == "reset" then
    ForeverBuffs_DB.pos = nil
    holder:ClearAllPoints(); holder:SetPoint("CENTER")
  else
    print("WildBuffs: /wildbuffs (options) | /wildbuffs why (explain target) | /wildbuffs minimap | /wildbuffs stats | /wildbuffs say on|off | /wildbuffs bind <KEY> | /wildbuffs unbind | /wildbuffs show | /wildbuffs hide | /wildbuffs reset | /wildbuffs debug")
  end
end
