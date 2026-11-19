---@diagnostic disable: undefined-global
-- modules/MinimapLens/wow/Triggers.lua -- how the lens opens and closes (plan M2 F4).
--
-- Opens only by hand (owner, F0): the key binding (Key Bindings > AddOns > Quantum Dungeon
-- Tools, no key by default; Bindings.xml calls `/qdt lens bind`), the magnifier button on the
-- minimap and `/qdt lens`. Closes by itself on leaving the instance (a loading screen already
-- does it in Lens.lua; here a zone change without one), on opening Edit Mode and on logout.
--
-- Magnifier (artboards LensReposo / LensActiva): a 34 px round button, navy with a 2 px ring,
-- glued to the minimap's ring bottom right (to the square's corner when the minimap is square or
-- the lens is on). Off = ring tickIdle + zoom-in in muted; on = gold ring, gold halo, zoom-out.
-- Always there while the module is on, inside an instance or not (owner, 2026-11-16: appearing
-- only inside was awkward under EllesmereUI). Parented to UIParent and ANCHORED to the Minimap,
-- not its child: EllesmereUI gathers every named Button child of the Minimap into its button
-- flyout and hides it (Hide + SetAlpha(0) + a Show hook, re-scanned on every ADDON_LOADED).
-- It hides and shows with the Minimap through hooks. Shown and hidden with a fade (module switch).
local _, ns = ...
local Lens = ns.WildMaps
local issecretvalue = ns.issecretvalue or function() return false end

local T = {}
ns.WildMapsTriggers = T

local SIZE, RING, HALO, ICON = 34, 2, 40, 18   -- artboard px
local Weave -- the standalone UI tween library is intentionally not required by WildSpark
local button, fade
local target = 0          -- alpha the button is heading to
local inside            -- last IsInInstance() read (nil = unknown)
local openedInside      -- the lens that is on was opened inside an instance
local draggingButton = false
local suppressClick = false

local function UI() return ns.WildMapsUI end

------------------------------------------------------------------------------
-- Self-check: _checkLens.triggers = { inside, shown, key, opens = {..}, closes = {..} }
------------------------------------------------------------------------------
local LOG = 10
local function log(list, what)
  local root = WildsparkDB
  if type(root) ~= "table" then return end
  root._checkLens = root._checkLens or {}
  local t = root._checkLens.triggers or {}
  root._checkLens.triggers = t
  t[list] = t[list] or {}
  local l = t[list]
  l[#l + 1] = what
  while #l > LOG do table.remove(l, 1) end
  t.inside, t.shown = inside, button and button:IsShown() or false
end

------------------------------------------------------------------------------
-- Reads
------------------------------------------------------------------------------
local function readInside()
  local ok, v = pcall(IsInInstance)
  if not ok or issecretvalue(v) or type(v) ~= "boolean" then return nil end
  return v
end

-- The key bound to the lens, as the client spells it ("Shift-M"), or nil.
local function squareMinimap()
  local fn = GetMinimapShape
  if type(fn) ~= "function" then return false end
  local ok, shape = pcall(fn)
  return ok and not issecretvalue(shape) and type(shape) == "string" and shape ~= "ROUND"
end

------------------------------------------------------------------------------
-- The magnifier
------------------------------------------------------------------------------
local function circle(parent, layer, size, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetSize(size, size)
  t:SetPoint("CENTER")
  t:SetTexture("Interface\\Buttons\\WHITE8x8")
  return t
end

local function paint()
  if not button then return end
  local C = { gold = { r = 1, g = 0.82, b = 0 }, tickIdle = { r = 0.58, g = 0.45, b = 0.20 }, muted = { r = 0.74, g = 0.70, b = 0.62 }, panel = { r = 0.12, g = 0.08, b = 0.04 } }
  local on = UI():IsOn()
  local ring = on and C.gold or C.tickIdle
  local glyph = on and C.gold or C.muted
  button.ring:SetVertexColor(ring.r, ring.g, ring.b, 1)
  button.halo:SetShown(on)
  button.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_01")
  button.icon:SetVertexColor(glyph.r, glyph.g, glyph.b, 1)
end

-- Glued to the ring (round) or to the corner (square / lens on), from the Minimap's centre.
local function place()
  if not button then return end
  local okS, w, h = pcall(Minimap.GetSize, Minimap)
  if not okS or issecretvalue(w) or issecretvalue(h) then return end
  local settings = ns.db and ns.db.wildMaps
  local saved = settings and settings.buttonPos
  local x, y
  if type(saved) == "table" and type(saved.x) == "number" and type(saved.y) == "number" then
    x, y = saved.x, saved.y
  else
    x, y = Lens.buttonOffset(w, h, UI():IsOn() or squareMinimap(), Lens.get(settings, "corner"))
  end
  -- Not a child of the Minimap: follow its strata (the lens may raise it) and stay above it.
  button:SetFrameStrata(Minimap:GetFrameStrata() or "LOW")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function showTip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText("WildMaps")
  GameTooltip:AddLine(UI():IsOn() and "Click to close the minimap lens" or "Click to enlarge the current minimap", 1, 0.82, 0)
  GameTooltip:AddLine("Hold Ctrl and drag to move this magnifier", 0.78, 0.78, 0.78, true)
  GameTooltip:Show()
end

local function stopDragging(self)
  if not draggingButton then return end
  draggingButton = false
  self:StopMovingOrSizing()
  local bx, by = self:GetCenter()
  local mx, my = Minimap:GetCenter()
  local mapScale, buttonScale = Minimap:GetEffectiveScale(), self:GetEffectiveScale()
  if type(bx) ~= "number" or type(by) ~= "number" or type(mx) ~= "number" or type(my) ~= "number"
      or type(mapScale) ~= "number" or type(buttonScale) ~= "number" or mapScale <= 0 then
    place()
    return
  end
  local w, h = Minimap:GetSize()
  local x, y = (bx * buttonScale - mx * mapScale) / mapScale,
    (by * buttonScale - my * mapScale) / mapScale
  local halfButton = SIZE * buttonScale / mapScale / 2
  local maxX = math.max(0, w / 2 - halfButton)
  local maxY = math.max(0, h / 2 - halfButton)
  x, y = math.max(-maxX, math.min(maxX, x)), math.max(-maxY, math.min(maxY, y))
  ns.db.wildMaps.buttonPos = { x = x, y = y }
  suppressClick = true
  place()
  C_Timer.After(0, function() suppressClick = false end)
end

local function fadeTo(to)
  target = to
  if not Weave then
    button:SetAlpha(to)
    button:SetShown(to > 0)
    return
  end
  if not fade then
    fade = { goal = Weave.signal(0) }
    fade.tween = Weave.tween(fade.goal, { duration = FADE, easing = Weave.easing.outQuad })
    fade.effect = Weave.effect(function()
      local v = fade.tween()
      if type(v) ~= "number" then return end
      button:SetAlpha(v)
      if v <= 0.001 and target == 0 then button:Hide() end
    end)
  end
  local from = button:IsShown() and button:GetAlpha() or 0
  if to > 0 then button:Show() end
  fade.goal:set(to)
  fade.tween:snap(from)
end

-- «Magnifier only on hover» (default on): the mouse over the minimap or over the button itself.
local function hovering()
  local ok, over = pcall(Minimap.IsMouseOver, Minimap)
  if ok and over == true then return true end
  if button:IsShown() then
    local okB, overB = pcall(button.IsMouseOver, button)
    return okB and overB == true
  end
  return false
end

-- Whenever the module is on (inside an instance or not); with «only on hover», only while the
-- mouse is over the minimap, the lens open or not (owner 2026-11-17: the gold magnifier stayed
-- in sight over the open lens).
local watcher = CreateFrame("Frame")
local function update()
  if not button then return end
  local d = ns.db and ns.db.wildMaps
  local on = Lens.isOn(d)
  local hoverOnly = on and Lens.get(d, "hoverOnly")
  watcher:SetShown(hoverOnly and true or false)
  local want = on and (not hoverOnly or hovering())
  if want then place() end
  paint()
  if want and target ~= 1 then fadeTo(1) elseif not want and target ~= 0 then fadeTo(0) end
end

-- Polls the hover (10 Hz) only while «only on hover» applies: OnEnter/OnLeave of the Minimap
-- would flicker crossing to the button, which overhangs its edge.
local POLL = 0.1
local since, lastHover = 0, nil
watcher:Hide()
watcher:SetScript("OnUpdate", function(_, elapsed)
  since = since + elapsed
  if since < POLL then return end
  since = 0
  local h = hovering()
  if h ~= lastHover then
    lastHover = h
    update()
  end
end)

local function build()
  if button or not Minimap then return end
  local C = { gold = { r = 1, g = 0.82, b = 0 }, tickIdle = { r = 0.58, g = 0.45, b = 0.20 }, muted = { r = 0.74, g = 0.70, b = 0.62 }, panel = { r = 0.12, g = 0.08, b = 0.04 } }
  -- UIParent, not Minimap: see the header (EllesmereUI's button flyout).
  local b = CreateFrame("Button", "WildSparkWildMapsLensButton", UIParent)
  b:SetSize(SIZE, SIZE)
  b:SetFrameStrata(Minimap:GetFrameStrata() or "LOW")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 10)
  b:RegisterForClicks("LeftButtonUp")
  b:SetMovable(true)
  b:RegisterForDrag("LeftButton")
  b.halo = circle(b, "BACKGROUND", HALO, 0)
  b.halo:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.22)
  b.ring = circle(b, "BORDER", SIZE, 0)
  b.fill = circle(b, "ARTWORK", SIZE - 2 * RING, 0)
  b.fill:SetVertexColor(C.panel.r, C.panel.g, C.panel.b, 1)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetSize(ICON, ICON)
  b.icon:SetPoint("CENTER")
  b:SetScript("OnClick", function(self)
    if suppressClick or IsControlKeyDown() then suppressClick = false; return end
    GameTooltip:Hide()
    T:Toggle("button")
    if self:IsMouseOver() then showTip(self) end
  end)
  b:SetScript("OnEnter", showTip)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    if not IsControlKeyDown() or draggingButton then return end
    draggingButton = true
    self:StartMoving()
  end)
  b:SetScript("OnDragStop", stopDragging)
  b:SetAlpha(0)
  b:Hide()
  button = b
  paint()
  -- The minimap changes size (the lens, EUI's own resize): stay glued to the ring.
  Minimap:HookScript("OnSizeChanged", function() if button:IsShown() then place() end end)
  -- Not its child any more: hide and come back with the Minimap by hand.
  Minimap:HookScript("OnHide", function() button:Hide() end)
  Minimap:HookScript("OnShow", function()
    if target > 0 then
      place()
      button:Show()
    end
  end)
end

------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------
-- source: "button", "bind", "slash" (only for the self-check).
function T:Toggle(source)
  local wasOn = UI():IsOn()
  UI():Toggle()
  if UI():IsOn() ~= wasOn then log(wasOn and "closes" or "opens", source or "?") end
end

-- The page changed the corner (or reset it): move the magnifier now.
function T:Replace() place() end

-- The page changed «only on hover» (or reset it).
function T:Refresh()
  lastHover = nil
  update()
end

local function close(reason)
  if not UI():IsOn() then return end
  UI():Off()
  log("closes", reason)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local now = readInside()
    if now ~= nil then inside = now end
    if Lens.leftInstance(openedInside, inside) then close("left") end
    update()
  end
end)

function T:Init()
  build()
  inside = readInside()
  UI():OnChange(function(on)
    if on then openedInside = inside == true end
    update()
  end)
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  -- Edit Mode does not move the lens (gotcha 17), but the design closes it there.
  if EventRegistry and EventRegistry.RegisterCallback then
    pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", function() close("editmode") end, T)
  end
  update()
end

return T
