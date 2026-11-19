-- modules/MinimapLens/core/Lens.lua -- PURE LOGIC (Lua 5.1, ZERO WoW API).
--
-- Minimap Lens core (plan M2 F2): the settings and their limits, the lens geometry (square side,
-- default position from the LensActiva artboard), what each minimap owner lets us touch, the
-- snapshot validation and the zoom kept in the DB so a crash or a disconnect with the lens on
-- does not leave the minimap one step closer (F1 gotcha 16: the client remembers the zoom).
-- The WoW side (modules/MinimapLens/wow/Lens.lua) reads the game and applies what this decides.
local _, ns = ...
local Style = {
  HEX = { muted = "b59a68" },
  rgba = function(hex, a)
    local n = tonumber(hex, 16) or 0
    return { r = math.floor(n / 65536) / 255, g = math.floor(n / 256) % 256 / 255, b = n % 256 / 255, a = a }
  end,
}

local Lens = {}
ns.WildMaps = Lens

-- Settings (db.minimapLens). size = factor over the original minimap side; opacity 0..1.
-- Defaults: LensActiva artboard (440 px over a 170 px minimap = 260 %), full opacity.
Lens.SIZE    = { default = 2.6, min = 1.5, max = 3.5, step = 0.1 }
Lens.OPACITY = { default = 1.0, min = 0.4, max = 1.0, step = 0.05 }
Lens.SCREEN_FIT = 0.85      -- the square never grows past this share of the screen height

-- Default spot (no saved position): the artboard's square centre on its 1280x720 frame, i.e.
-- 80 px right of and 30 px below the screen centre, scaled to the real UIParent height. Not the
-- minimap corner: there Blizzard's minimap grows off screen and the quest list covers it (gotcha 13).
Lens.DESIGN_H = 720
Lens.DEFAULT_POS = { point = "CENTER", x = 80, y = -30 }

-- Mask textures (F1 gotchas 8 and 12): square = what ElvUI/EUI use; round = Blizzard's look,
-- the one restored when nobody else owns the minimap (there is no getter for the mask).
Lens.MASK_SQUARE = 130937
Lens.MASK_ROUND  = 186178

-- QDT outline (artboard: 1 px dark edge, 2 px Secondary at 85 %, 1 px dark edge), inside out.
Lens.OUTLINE = {
  { size = 1, color = { r = 0, g = 0, b = 0, a = 0.75 } },
  { size = 2, color = Style.rgba(Style.HEX.muted, 0.85) },
  { size = 1, color = { r = 0, g = 0, b = 0, a = 0.6 } },
}

local function round(v) return math.floor(v + 0.5) end

-- Clamps to [min, max] and snaps to the step (sliders, F5). Non-numbers fall to the default.
function Lens.clamp(v, spec)
  if type(v) ~= "number" or v ~= v then return spec.default end
  if v < spec.min then v = spec.min elseif v > spec.max then v = spec.max end
  return round((v - spec.min) / spec.step) * spec.step + spec.min
end

-- Fills the missing fields (additive, no migration); `saved` and `pos` stay nil until used.
function Lens.applyDefaults(db)
  if type(db) ~= "table" then return end
  if db.size == nil then db.size = Lens.SIZE.default end
  if db.opacity == nil then db.opacity = Lens.OPACITY.default end
end

------------------------------------------------------------------------------
-- Page settings (plan M2 F5, artboard AppLens). Sliders hold whole percents; the switches are
-- nil until changed (nil = default), so a reset is just clearing them.
------------------------------------------------------------------------------
Lens.SWITCHES = {
  -- «extra zoom when it opens» was removed (owner, 2026-11-17): a zoom level reached while the
  -- lens is see-through never loads the underground terrain, and the fix flickered.
  { key = "hideGathering", default = false },   -- herbs and minerals off while on (decision 6)
  { key = "locked",        default = false },   -- the lens cannot be dragged
  { key = "hoverOnly",     default = true },    -- magnifier only on minimap hover (owner, 2026-11-16)
}
local SWITCH = {}
for _, s in ipairs(Lens.SWITCHES) do SWITCH[s.key] = s end

-- Magnifier corner (owner, 2026-11-16: bottom right hid EllesmereUI's + / -). nil = default.
Lens.CORNERS = { "BL", "BR", "TL", "TR" }
Lens.CORNER_DEFAULT = "BL"
local CORNER = { BL = true, BR = true, TL = true, TR = true }
local function corner(v) return CORNER[v] and v or Lens.CORNER_DEFAULT end

-- Module switch (live: off closes the lens and hides the magnifier). nil = on.
function Lens.isOn(db) return type(db) ~= "table" or db.enabled ~= false end

function Lens.get(db, key)
  db = type(db) == "table" and db or {}
  if key == "size" then return Lens.clamp(db.size, Lens.SIZE) end
  if key == "opacity" then return Lens.clamp(db.opacity, Lens.OPACITY) end
  if key == "corner" then return corner(db.corner) end
  local s = SWITCH[key]
  if not s then return nil end
  if db[key] == nil then return s.default end
  return db[key] and true or false
end

function Lens.isChanged(db, key)
  if key == "size" then return math.abs(Lens.get(db, key) - Lens.SIZE.default) > 1e-6 end
  if key == "opacity" then return math.abs(Lens.get(db, key) - Lens.OPACITY.default) > 1e-6 end
  if key == "corner" then return Lens.get(db, key) ~= Lens.CORNER_DEFAULT end
  local s = SWITCH[key]
  return s ~= nil and Lens.get(db, key) ~= s.default
end

function Lens.changedCount(db)
  local n = 0
  if Lens.isChanged(db, "size") then n = n + 1 end
  if Lens.isChanged(db, "opacity") then n = n + 1 end
  if Lens.isChanged(db, "corner") then n = n + 1 end
  for _, s in ipairs(Lens.SWITCHES) do
    if Lens.isChanged(db, s.key) then n = n + 1 end
  end
  return n
end

-- «Reset the lens»: settings only. The position has its own reset (move mode) and the module
-- switch is not a lens setting.
function Lens.reset(db)
  if type(db) ~= "table" then return end
  db.size, db.opacity, db.corner = Lens.SIZE.default, Lens.OPACITY.default, nil
  for _, s in ipairs(Lens.SWITCHES) do db[s.key] = nil end
end

-- Whole percent for the sliders and the summary line (2.6 -> 260).
function Lens.percent(v) return round((tonumber(v) or 0) * 100) end

-- Gathering tracking (Find Herbs, Find Minerals). rows = { { spellID, active } } read from
-- C_Minimap.GetTrackingInfo; returns the spellIDs to turn off now (and to turn back on later).
Lens.GATHER = { [2383] = true, [2580] = true }
function Lens.gatherToHide(rows)
  local out = {}
  if type(rows) ~= "table" then return out end
  for _, r in ipairs(rows) do
    if type(r) == "table" and Lens.GATHER[r.spellID] and r.active == true then out[#out + 1] = r.spellID end
  end
  return out
end

-- Where a dragged frame ended, as the CENTER offset from UIParent's centre (UIParent units).
-- cx, cy = the frame's centre in UIParent units.
function Lens.centerOffset(cx, cy, uiW, uiH)
  if type(cx) ~= "number" or type(cy) ~= "number" or type(uiW) ~= "number" or type(uiH) ~= "number" then
    return nil
  end
  return { point = "CENTER", x = round(cx - uiW / 2), y = round(cy - uiH / 2) }
end

-- Side of the square lens: the original's larger side times the factor, capped to the screen
-- and never smaller than the original. Whole UI units.
function Lens.side(w, h, factor, screenH)
  local base = math.max(w, h)
  local s = base * Lens.clamp(factor, Lens.SIZE)
  if type(screenH) == "number" and screenH > 0 then s = math.min(s, screenH * Lens.SCREEN_FIT) end
  return round(math.max(s, base))
end

-- One zoom step closer (design decision 3), capped to the last level. `levels` = GetZoomLevels.
function Lens.zoomIn(zoom, levels)
  local top = (type(levels) == "number" and levels > 0) and levels - 1 or 5
  return math.min(zoom + 1, top)
end

-- Where the lens goes: the saved position if it is well formed, else the artboard default.
function Lens.position(pos, uiH)
  if type(pos) == "table" and type(pos.point) == "string" and type(pos.x) == "number"
      and type(pos.y) == "number" then
    return { point = pos.point, x = pos.x, y = pos.y }
  end
  local k = (type(uiH) == "number" and uiH > 0) and uiH / Lens.DESIGN_H or 1
  local d = Lens.DEFAULT_POS
  return { point = d.point, x = round(d.x * k), y = round(d.y * k) }
end

-- What the lens may touch given who owns the minimap
-- ("none" | "eui" | "elvui" | "elvui+eui" | "other" = an unknown addon that set its own shape).
--   mask/shape: square mask + GetMinimapShape only on Blizzard's minimap (ElvUI, EUI and any
--               addon with its own GetMinimapShape own their mask).
--   icons:      LibDBIcon Refresh, except with EllesmereUIMinimap, which hides those buttons in
--               its drawer and Refresh would force them visible for good (gotcha 4).
function Lens.plan(owner)
  local eui = type(owner) == "string" and owner:find("eui", 1, true) ~= nil
  return { mask = owner == "none", shape = owner == "none", icons = not eui }
end

-- A snapshot is usable only if every number came back readable (no secret, no nil) and the
-- minimap had at least one anchor. `isSecret` is injected (ns.issecretvalue on the WoW side).
local NUMBERS = { "w", "h", "scale", "alpha", "zoom" }
function Lens.validSnapshot(s, isSecret)
  if type(s) ~= "table" then return false, "no snapshot" end
  for _, k in ipairs(NUMBERS) do
    local v = s[k]
    if isSecret and isSecret(v) then return false, "secret " .. k end
    if type(v) ~= "number" then return false, "missing " .. k end
  end
  if type(s.points) ~= "table" or #s.points == 0 then return false, "no anchor" end
  return true
end

-- Did the move hold? (F1 gotchas 29-30: with EUI and the minimap snapped, our SetPoint is
-- undone.) `want` = the anchor we set { point, x, y }; `got` = the Minimap's only anchor, read
-- back, or nil when it has several or is not relative to UIParent (someone else anchored it).
function Lens.held(want, got, tol)
  if type(want) ~= "table" or type(got) ~= "table" then return false end
  if got.point ~= want.point or type(got.x) ~= "number" or type(got.y) ~= "number" then return false end
  tol = tol or 0.5
  return math.abs(want.x - got.x) <= tol and math.abs(want.y - got.y) <= tol
end

------------------------------------------------------------------------------
-- Coexistence (plan M2 F3): soft mode. Another UI that writes on the Minimap while the lens is
-- on gets the last word for a moment; the lens then puts back only what drifted. If it keeps
-- writing (REFEREE.max fixes inside REFEREE.window seconds), the lens yields: it stays on as the
-- other UI left it and warns once. The zoom is never fought (the wheel and EUI's reset own it).
------------------------------------------------------------------------------
Lens.REFEREE = { max = 4, window = 10 }   -- a stomp + the echo of our fix (EUI reanchors on resize) = 2

-- Name shown in the warning; nil = an unknown addon (the caller says "another addon").
local OWNER_NAME = { eui = "EllesmereUI", elvui = "ElvUI", ["elvui+eui"] = "ElvUI" }
function Lens.ownerName(owner) return OWNER_NAME[owner] end

-- referee:call(now) after a foreign write left the lens drifted:
--   "reapply" (put it back), "yield" (once: stop fixing, warn) or "idle" (already yielded).
function Lens.newReferee(spec)
  spec = spec or Lens.REFEREE
  local r = { hits = {}, yielded = false }
  function r:call(now)
    if self.yielded then return "idle" end
    local keep = {}
    for _, t in ipairs(self.hits) do
      if now - t < spec.window then keep[#keep + 1] = t end
    end
    self.hits = keep
    if #keep >= spec.max then
      self.yielded = true
      return "yield"
    end
    keep[#keep + 1] = now
    return "reapply"
  end
  return r
end

-- What drifted from the lens. want = { side, scale, alpha?, pos? } (alpha nil while a fade runs,
-- pos nil when the move did not hold: that anchor is not ours to fight); got = { w, h, scale,
-- alpha, anchor } read back (anchor nil = several points or not on UIParent). Unreadable numbers
-- count as no drift (never fight what cannot be measured). Returns { size?, scale?, alpha?,
-- anchor? } = true for each field to put back, or nil when nothing drifted.
local function off(a, b, tol)
  return type(a) == "number" and type(b) == "number" and math.abs(a - b) > tol
end
function Lens.drift(want, got)
  if type(want) ~= "table" or type(got) ~= "table" then return nil end
  local fix, any = {}, false
  local function mark(k) fix[k] = true; any = true end
  if off(want.side, got.w, 0.5) or off(want.side, got.h, 0.5) then mark("size") end
  if off(want.scale, got.scale, 0.01) then mark("scale") end
  if want.alpha ~= nil and off(want.alpha, got.alpha, 0.01) then mark("alpha") end
  if want.pos ~= nil and not Lens.held(want.pos, got.anchor) then mark("anchor") end
  return any and fix or nil
end

-- The original zoom, kept in the DB while the lens is on (gotcha 16). The normal exit restores
-- it before any reload; this covers a crash or a disconnect.
function Lens.markApplied(db, zoom)
  if type(db) == "table" then db.saved = { zoom = zoom } end
end

function Lens.markRestored(db)
  if type(db) == "table" then db.saved = nil end
end

-- The gathering tracking the lens turned off (F5), kept next to the zoom for the same reason.
function Lens.markTracking(db, ids)
  if type(db) == "table" and type(db.saved) == "table" then
    db.saved.tracking = (type(ids) == "table" and #ids > 0) and ids or nil
  end
end

-- spellIDs to turn back on at login (nil = none). Leaves the zoom mark alone: call it first.
function Lens.takePendingTracking(db)
  if type(db) ~= "table" or type(db.saved) ~= "table" then return nil end
  local t = db.saved.tracking
  db.saved.tracking = nil
  return (type(t) == "table" and #t > 0) and t or nil
end

-- Zoom to put back at login (nil = nothing pending). Clears the mark.
function Lens.takePendingZoom(db)
  if type(db) ~= "table" or type(db.saved) ~= "table" then return nil end
  local z = db.saved.zoom
  db.saved = nil
  return type(z) == "number" and z or nil
end

------------------------------------------------------------------------------
-- Triggers (plan M2 F4)
------------------------------------------------------------------------------
-- Magnifier button spot, as the offset of its centre from the Minimap's CENTER (artboards
-- LensReposo / LensActiva), in the chosen corner (db.corner, default bottom left). Round
-- minimap: on the ring (the artboard's 34 px button on a 170 px map sits 80/54 off the centre).
-- Square minimap (the lens itself, ElvUI, EUI): on the corner. Whole UI units.
Lens.BUTTON_ROUND = { x = 80 / 170, y = 54 / 170 }
function Lens.buttonOffset(w, h, square, where)
  if type(w) ~= "number" or type(h) ~= "number" then return 0, 0 end
  where = corner(where)
  local sx = where:sub(2, 2) == "R" and 1 or -1
  local sy = where:sub(1, 1) == "T" and 1 or -1
  if square then return sx * math.floor(w / 2 + 0.5), sy * math.floor(h / 2 + 0.5) end
  return sx * math.floor(w * Lens.BUTTON_ROUND.x + 0.5), sy * math.floor(h * Lens.BUTTON_ROUND.y + 0.5)
end

-- Closing on leaving the instance: a loading screen already closes the lens
-- (PLAYER_LEAVING_WORLD); this covers a zone change without one. Only a lens opened inside an
-- instance closes (one opened outside to try it stays). Unknown (nil) never closes.
function Lens.leftInstance(openedInside, inside)
  return openedInside == true and inside == false
end
