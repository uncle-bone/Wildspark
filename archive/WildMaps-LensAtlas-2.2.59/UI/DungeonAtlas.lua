---@diagnostic disable: undefined-global
-- Standalone WildMaps dungeon atlas. The window renders one selected floor from the
-- bundled, attributed tile set; it never resizes the game's minimap or opens WorldMapFrame.
local _, ns = ...

local UI = {}
ns.WildMapsDungeonUI = UI

local DATA = ns.WildMapsDungeons or {}
local BOSS_POINTS = ns.WildMapsBossPoints or {}
local TILE_ROOT = "Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\AtlasTiles\\"
local MAP_W, MAP_H, TILE = 1002, 668, 256
local MIN_ZOOM, MAX_ZOOM = 1, 5
local DEFAULT_W, DEFAULT_H = 820, 650
local MIN_W, MIN_H = 540, 430

local frame, view, canvas, status, mapTitle, floorTitle
local tiles, bossPins = {}, {}
local playerPin, manualPin, estimatePin
local selected, selectedIndex, selectedFloor = nil, 1, 1
local zoom, offsetX, offsetY = 1, 0, 0
local dragging, sizing
local encounterID, encounterName
local lastSubzone = ""
local updateElapsed = 0
local updateStatus

local function saved()
  local root = ns.db and ns.db.wildMaps
  if type(root) ~= "table" then return nil end
  root.atlas = type(root.atlas) == "table" and root.atlas or {}
  return root.atlas
end

local function safeCall(fn, ...)
  if type(fn) ~= "function" then return false end
  return pcall(fn, ...)
end

local function readable(v)
  if ns.issecretvalue then
    local ok, secret = pcall(ns.issecretvalue, v)
    if not ok or secret then return false end
  end
  return true
end

local function nameOf(d)
  if type(d) ~= "table" then return "Dungeon map" end
  if type(d.name) == "table" then return d.name.enUS or d.name.ruRU or d.key or "Dungeon map" end
  return d.name or d.key or "Dungeon map"
end

local function floorName(d, i)
  local floor = d and d.floors and d.floors[i]
  if floor and type(floor.name) == "table" then return floor.name.enUS or floor.name.ruRU or ("Floor " .. i) end
  if floor and type(floor.name) == "string" then return floor.name end
  return "Floor " .. i
end

local function validDungeon(d)
  return type(d) == "table" and type(d.floors) == "table" and #d.floors > 0
    and type(d.floors[1].tiles) == "string"
end

local function buildList()
  local list = {}
  for _, d in ipairs(DATA) do if validDungeon(d) then list[#list + 1] = d end end
  return list
end

local maps = buildList()

local function currentSubzone()
  local ok, sub = safeCall(GetSubZoneText)
  if not ok or not readable(sub) or type(sub) ~= "string" or sub == "" then
    ok, sub = safeCall(GetMinimapZoneText)
  end
  return ok and readable(sub) and type(sub) == "string" and sub or ""
end

local function currentInstance()
  local ok, name, kind, _, _, _, _, id = safeCall(GetInstanceInfo)
  if not ok or not readable(kind) then return nil end
  if kind ~= "party" and kind ~= "raid" then return nil end
  return name, kind, id
end

local function bestMapID()
  if not (C_Map and type(C_Map.GetBestMapForUnit) == "function") then return nil end
  local ok, id = safeCall(C_Map.GetBestMapForUnit, "player")
  return ok and readable(id) and type(id) == "number" and id or nil
end

local function chooseWing(candidates, instanceID, uiMapID, subzone)
  if #candidates <= 1 then return candidates[1] end
  if uiMapID then
    for _, d in ipairs(candidates) do
      for _, id in ipairs(d.ui or {}) do if id == uiMapID then return d end end
    end
  end
  -- Subzone names for shared wings (notably Scarlet Monastery) distinguish them on Forever.
  local low = string.lower(subzone or "")
  if low ~= "" then
    for _, d in ipairs(candidates) do
      local label = string.lower(nameOf(d))
      local suffix = label:match(":%s*(.+)$")
      if suffix and low:find(suffix, 1, true) then return d end
      for _, f in ipairs(d.floors or {}) do
        for _, s in ipairs(f.subzones or {}) do if string.lower(s) == low then return d end end
      end
    end
  end
  local db = saved()
  local previous = db and db.lastDungeon
  if previous then
    for _, d in ipairs(candidates) do if d.key == previous then return d end end
  end
  return candidates[1]
end

local function findCurrentDungeon()
  local instanceName, _, instanceID = currentInstance()
  if not instanceID then return nil end
  local candidates = {}
  for _, d in ipairs(maps) do
    if d.mapID == instanceID then candidates[#candidates + 1] = d end
  end
  if #candidates == 0 and type(instanceName) == "string" then
    local needle = string.lower(instanceName)
    for _, d in ipairs(maps) do
      local n = string.lower(nameOf(d))
      if n == needle or n:find(needle, 1, true) or needle:find(n, 1, true) then candidates[#candidates + 1] = d end
    end
  end
  if #candidates == 0 then return nil end
  return chooseWing(candidates, instanceID, bestMapID(), currentSubzone())
end

local function floorFromSubzone(d, subzone)
  if not d or not subzone or subzone == "" then return nil end
  local low = string.lower(subzone)
  for i, f in ipairs(d.floors or {}) do
    for _, s in ipairs(f.subzones or {}) do
      if string.lower(s) == low then return i end
    end
    local label = f.name
    if type(label) == "table" then label = label.enUS or label.ruRU end
    if type(label) == "string" and string.lower(label) == low then return i end
  end
  return nil
end

local function safeText(fs, text)
  if fs and fs.SetText then fs:SetText(text or "") end
end

local function mapScale()
  if not view then return 1 end
  local vw, vh = view:GetWidth(), view:GetHeight()
  if not (vw and vh and vw > 1 and vh > 1) then return 1 end
  return math.min(vw / MAP_W, vh / MAP_H) * zoom
end

local function cursorInView()
  local x, y = GetCursorPosition()
  local scale = view:GetEffectiveScale()
  return x / scale - view:GetLeft(), view:GetTop() - y / scale
end

local function clampOffset()
  local s = mapScale()
  local cw, ch = MAP_W * s, MAP_H * s
  local vw, vh = view:GetWidth(), view:GetHeight()
  offsetX = cw <= vw and (vw - cw) / 2 or math.max(vw - cw, math.min(0, offsetX))
  offsetY = ch <= vh and (vh - ch) / 2 or math.max(vh - ch, math.min(0, offsetY))
  return s
end

local function markerButton(parent, texture, size)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size or 24, size or 24)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetPoint("CENTER")
  b.label:SetTextColor(1, 0.88, 0.22)
  b:Hide()
  return b
end

local function positionPin(pin, x, y, s)
  if not pin then return end
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", canvas, "TOPLEFT", x * MAP_W * s, -y * MAP_H * s)
  pin:Show()
end

local function manualMark()
  local db = saved()
  local marks = db and db.marks
  local m = marks and selected and marks[selected.key]
  if type(m) == "table" and m.floor == selectedFloor and type(m.x) == "number" and type(m.y) == "number" then
    return m.x, m.y
  end
end

local function currentPlayerPosition(d)
  local inInstance = currentInstance()
  if not inInstance or not (C_Map and type(C_Map.GetPlayerMapPosition) == "function") then return nil end
  local ids = {}
  local ui = bestMapID()
  if ui then ids[#ids + 1] = ui end
  if d and d.mapID then ids[#ids + 1] = d.mapID end
  for _, f in ipairs(d and d.floors or {}) do
    if f.ui then for _, id in ipairs(f.ui) do ids[#ids + 1] = id end end
  end
  local seen = {}
  for _, mapID in ipairs(ids) do
    if type(mapID) == "number" and not seen[mapID] then
      seen[mapID] = true
      local ok, pos = safeCall(C_Map.GetPlayerMapPosition, mapID, "player")
      if ok and pos ~= nil and readable(pos) then
        local x, y
        local okMethod, getXY = pcall(function() return pos.GetXY end)
        if okMethod and type(getXY) == "function" then
          local okXY, a, b = pcall(getXY, pos)
          if okXY then x, y = a, b end
        else
          local okXY, a, b = pcall(function() return pos.x, pos.y end)
          if okXY then x, y = a, b end
        end
        if readable(x) and readable(y) and type(x) == "number" and type(y) == "number"
            and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x ~= 0 or y ~= 0) then
          return x, y
        end
      end
    end
  end
end

local function updatePins(s)
  if not selected or not selected.floors or not selected.floors[selectedFloor] then return end
  local floor = selected.floors[selectedFloor]
  for _, pin in ipairs(bossPins) do pin:Hide() end
  local pointByID = BOSS_POINTS
  local bossN = 0
  for _, boss in ipairs(selected.bosses or {}) do
    local p = pointByID[boss.id]
    if p and p.f == selectedFloor then
      bossN = bossN + 1
      local pin = bossPins[bossN]
      if not pin then
        pin = markerButton(canvas, "Interface\\Icons\\INV_Misc_QuestionMark", 22)
        bossPins[bossN] = pin
        pin:SetScript("OnEnter", function(self)
          local b = self.boss
          if not b then return end
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          local nm = type(b.name) == "table" and (b.name.enUS or b.name.ruRU) or tostring(b.name or "Boss")
          GameTooltip:SetText((b.n and (b.n .. ". ") or "") .. nm, 1, 0.82, 0)
          GameTooltip:AddLine("Approximate encounter location", 0.75, 0.75, 0.75)
          GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
      pin.boss = boss
      pin.label:SetText(boss.n or "")
      positionPin(pin, p.x, p.y, s)
    end
  end
  local px, py = currentPlayerPosition(selected)
  if px and playerPin then positionPin(playerPin, px, py, s) elseif playerPin then playerPin:Hide() end
  local mx, my = manualMark()
  if mx and manualPin then positionPin(manualPin, mx, my, s) elseif manualPin then manualPin:Hide() end
  if estimatePin then
    local ep = encounterID and pointByID[encounterID]
    if ep and ep.f == selectedFloor and not px then
      positionPin(estimatePin, ep.x, ep.y, s)
      estimatePin.bossName = encounterName or "Boss encounter"
    else
      estimatePin:Hide()
    end
  end
end

local function layoutTiles()
  if not view or not canvas then return end
  local s = clampOffset()
  canvas:SetSize(MAP_W * s, MAP_H * s)
  canvas:ClearAllPoints()
  canvas:SetPoint("TOPLEFT", view, "TOPLEFT", offsetX, -offsetY)
  for i, tex in ipairs(tiles) do
    local row, col = math.floor((i - 1) / 4), (i - 1) % 4
    local w = col == 3 and (MAP_W - 3 * TILE) or TILE
    local h = row == 2 and (MAP_H - 2 * TILE) or TILE
    tex:SetSize(w * s, h * s)
    tex:SetTexCoord(0, w / TILE, 0, h / TILE)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", canvas, "TOPLEFT", col * TILE * s, -row * TILE * s)
  end
  updatePins(s)
end

local function clearTiles()
  for _, tex in ipairs(tiles) do tex:SetTexture(nil); tex:Hide() end
  for _, pin in ipairs(bossPins) do pin:Hide() end
  if playerPin then playerPin:Hide() end
  if manualPin then manualPin:Hide() end
  if estimatePin then estimatePin:Hide() end
end

local function loadMap()
  if not selected then return end
  selectedFloor = math.max(1, math.min(selectedFloor, #selected.floors))
  local floor = selected.floors[selectedFloor]
  clearTiles()
  local loaded = 0
  if floor and floor.tiles then
    for i, tex in ipairs(tiles) do
      local path = TILE_ROOT .. floor.tiles .. i .. ".blp"
      local ok = pcall(tex.SetTexture, tex, path)
      if ok then tex:Show(); loaded = loaded + 1 end
    end
  end
  safeText(mapTitle, nameOf(selected))
  safeText(floorTitle, floorName(selected, selectedFloor) .. "  (" .. selectedFloor .. "/" .. #selected.floors .. ")")
  if loaded == 0 then
    safeText(status, "Map art is unavailable for this floor. Check the WildMaps tile files in the install package.")
  end
  local db = saved()
  if db then db.lastDungeon, db.lastFloor = selected.key, selectedFloor end
  layoutTiles()
end

local function selectMap(index, autoFloor)
  if #maps == 0 then return end
  index = ((index - 1) % #maps) + 1
  selectedIndex, selected = index, maps[index]
  local db = saved()
  if db and db.lastDungeon == selected.key and not autoFloor then
    selectedFloor = tonumber(db.lastFloor) or 1
  else
    selectedFloor = 1
  end
  if autoFloor then selectedFloor = floorFromSubzone(selected, currentSubzone()) or selectedFloor end
  zoom = 1
  offsetX, offsetY = 0, 0
  loadMap()
end

local function autoSelect()
  local d = findCurrentDungeon()
  if not d then
    lastSubzone = currentSubzone()
    return false
  end
  local found
  for i, candidate in ipairs(maps) do if candidate.key == d.key then found = i break end end
  if found then
    if selected ~= d then selectMap(found, true) else
      local fi = floorFromSubzone(d, currentSubzone())
      if fi and fi ~= selectedFloor then selectedFloor = fi; loadMap() end
    end
  end
  lastSubzone = currentSubzone()
  return found ~= nil
end

local function saveWindow()
  local db = saved()
  if not (db and frame) then return end
  db.width, db.height = frame:GetSize()
  local point, _, rel, x, y = frame:GetPoint(1)
  if point and rel and type(x) == "number" and type(y) == "number" then
    db.point, db.relativePoint, db.x, db.y = point, rel, x, y
  end
  db.zoom, db.offsetX, db.offsetY = zoom, offsetX, offsetY
end

local function restoreWindow()
  local db = saved()
  local w = math.max(MIN_W, math.min(UIParent:GetWidth(), tonumber(db and db.width) or DEFAULT_W))
  local h = math.max(MIN_H, math.min(UIParent:GetHeight(), tonumber(db and db.height) or DEFAULT_H))
  frame:SetSize(w, h)
  frame:ClearAllPoints()
  if db and db.point and type(db.x) == "number" and type(db.y) == "number" then
    frame:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x, db.y)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
  zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, tonumber(db and db.zoom) or MIN_ZOOM))
  offsetX, offsetY = tonumber(db and db.offsetX) or 0, tonumber(db and db.offsetY) or 0
end

local function makeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function build()
  if frame or not ns.Skin then return end
  frame = ns.Skin.Window("WildSparkWildMapsDungeonAtlas", DEFAULT_W, DEFAULT_H)
  frame:SetResizable(true)
  if frame.SetResizeBounds then pcall(frame.SetResizeBounds, frame, MIN_W, MIN_H, 1300, 1000)
  else
    if frame.SetMinResize then frame:SetMinResize(MIN_W, MIN_H) end
    if frame.SetMaxResize then frame:SetMaxResize(1300, 1000) end
  end
  frame:SetFrameStrata("MEDIUM")
  frame:SetScript("OnDragStart", nil)
  frame:SetScript("OnDragStop", nil)
  if type(frame.SetTitle) == "function" then frame:SetTitle("WildMaps") end
  if frame.title then frame.title:SetText("WildMaps") end
  if frame.close then frame.close:SetScript("OnClick", function() frame:Hide() end) end

  local control = ns.Skin.Card(frame, 760, 62)
  control:SetPoint("TOPLEFT", 18, -58)
  control:SetPoint("TOPRIGHT", -18, -58)
  local prevMap = makeButton(control, "<", 28, function() selectMap(selectedIndex - 1) end)
  prevMap:SetPoint("LEFT", 8, 0)
  local nextMap = makeButton(control, ">", 28, function() selectMap(selectedIndex + 1) end)
  nextMap:SetPoint("RIGHT", -8, 0)
  mapTitle = control:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mapTitle:SetPoint("TOP", 0, -8)
  mapTitle:SetPoint("LEFT", prevMap, "RIGHT", 6, 0)
  mapTitle:SetPoint("RIGHT", nextMap, "LEFT", -6, 0)
  mapTitle:SetJustifyH("CENTER")
  floorTitle = control:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  floorTitle:SetPoint("BOTTOM", 0, 7)
  local prevFloor = makeButton(control, "<", 24, function()
    if selected then selectedFloor = ((selectedFloor - 2) % #selected.floors) + 1; loadMap() end
  end)
  prevFloor:SetPoint("BOTTOM", floorTitle, "BOTTOM", -105, -2)
  local nextFloor = makeButton(control, ">", 24, function()
    if selected then selectedFloor = (selectedFloor % #selected.floors) + 1; loadMap() end
  end)
  nextFloor:SetPoint("BOTTOM", floorTitle, "BOTTOM", 105, -2)
  local zoomOut = makeButton(control, "−", 28, function() zoom = math.max(MIN_ZOOM, zoom / 1.25); layoutTiles(); saveWindow() end)
  zoomOut:SetPoint("RIGHT", nextMap, "LEFT", -7, 0)
  local zoomIn = makeButton(control, "+", 28, function() zoom = math.min(MAX_ZOOM, zoom * 1.25); layoutTiles(); saveWindow() end)
  zoomIn:SetPoint("RIGHT", zoomOut, "LEFT", -3, 0)
  local home = makeButton(control, "Fit", 42, function() zoom, offsetX, offsetY = 1, 0, 0; layoutTiles(); saveWindow() end)
  home:SetPoint("RIGHT", zoomIn, "LEFT", -3, 0)

  status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("BOTTOMLEFT", 24, 31)
  status:SetPoint("BOTTOMRIGHT", -45, 31)
  status:SetJustifyH("LEFT")

  view = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  view:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -8)
  view:SetPoint("TOPRIGHT", control, "BOTTOMRIGHT", 0, -8)
  view:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 56)
  view:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 56)
  if view.SetBackdrop then
    view:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left=3, right=3, top=3, bottom=3 } })
    view:SetBackdropColor(0.035, 0.03, 0.025, 1)
    view:SetBackdropBorderColor(0.55, 0.43, 0.24, 0.95)
  end
  view:SetClipsChildren(true)
  view:EnableMouse(true)
  view:EnableMouseWheel(true)
  canvas = CreateFrame("Frame", nil, view)
  canvas:SetPoint("TOPLEFT")
  canvas:SetSize(MAP_W, MAP_H)
  for i=1,12 do
    local tex = canvas:CreateTexture(nil, "ARTWORK")
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    tiles[i] = tex
  end
  playerPin = markerButton(canvas, "Interface\\Minimap\\MinimapArrow", 28)
  playerPin.icon:SetVertexColor(0.2, 0.85, 1, 1)
  manualPin = markerButton(canvas, "Interface\\Icons\\INV_Misc_Map_01", 28)
  estimatePin = markerButton(canvas, "Interface\\Icons\\Ability_Hunter_MarkedForDeath", 28)
  estimatePin.icon:SetVertexColor(1, 0.55, 0.2, 1)

  local credit = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  credit:SetPoint("BOTTOMLEFT", 20, 11)
  credit:SetText("Shift-click to place your own marker  •  Boss positions are approximate  •  Map art credits in WildMaps/DMF-CREDITS.md")

  view:SetScript("OnSizeChanged", function() layoutTiles() end)
  view:SetScript("OnMouseWheel", function(_, delta)
    local cx, cy = cursorInView()
    local s0 = mapScale()
    local u = (cx - offsetX) / (MAP_W * s0)
    local v = (cy - offsetY) / (MAP_H * s0)
    zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, zoom * (delta > 0 and 1.25 or 0.8)))
    local s1 = mapScale()
    offsetX, offsetY = cx - u * MAP_W * s1, cy - v * MAP_H * s1
    layoutTiles()
    saveWindow()
  end)
  view:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      local x, y = cursorInView()
      dragging = { x=x, y=y, ox=offsetX, oy=offsetY, moved=false }
    end
  end)
  view:SetScript("OnUpdate", function()
    if dragging and IsMouseButtonDown("LeftButton") then
      local x, y = cursorInView()
      if math.abs(x-dragging.x) + math.abs(y-dragging.y) > 4 then dragging.moved = true end
      if dragging.moved then offsetX, offsetY = dragging.ox + x-dragging.x, dragging.oy + y-dragging.y; layoutTiles() end
    end
  end)
  view:SetScript("OnMouseUp", function(_, button)
    local d = dragging; dragging = nil
    if button == "LeftButton" and d and not d.moved and IsShiftKeyDown() then
      local x, y = cursorInView()
      local s = mapScale()
      local mx, my = (x-offsetX)/(MAP_W*s), (y-offsetY)/(MAP_H*s)
      if mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
        local db = saved()
        db.marks = db.marks or {}
        db.marks[selected.key] = { floor=selectedFloor, x=mx, y=my }
        layoutTiles()
        updateStatus()
      end
    end
    saveWindow()
  end)

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(22, 22)
  grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" then return end
    local x0, y0 = GetCursorPosition()
    local sc = frame:GetEffectiveScale()
    local w0, h0 = frame:GetSize()
    sizing = { x=x0/sc, y=y0/sc, w=w0, h=h0 }
    frame:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    if sizing then frame:StopMovingOrSizing(); sizing=nil; saveWindow(); layoutTiles() end
  end)
  grip:SetScript("OnUpdate", function()
    if sizing and not IsMouseButtonDown("LeftButton") then frame:StopMovingOrSizing(); sizing=nil; saveWindow(); layoutTiles() end
  end)
  frame:SetScript("OnDragStart", function(self) if not sizing then self:StartMoving() end end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); saveWindow() end)
  frame:SetScript("OnShow", function()
    restoreWindow()
    autoSelect()
    if not selected then selectMap(1, false) else loadMap() end
    layoutTiles()
  end)
  frame:SetScript("OnHide", function() clearTiles(); saveWindow(); dragging=nil; sizing=nil end)
  tinsert(UISpecialFrames, "WildSparkWildMapsDungeonAtlas")
  restoreWindow()
  selectMap(1, false)
  frame:Hide()
end

updateStatus = function()
  if not status or not selected then return end
  local sub = currentSubzone()
  local x, y = currentPlayerPosition(selected)
  if x and y then
    status:SetText("Current room: " .. (sub ~= "" and sub or "Unknown") .. "  •  Live map coordinates available")
    return
  end
  if encounterID then
    status:SetText("Current room: " .. (sub ~= "" and sub or "Unknown") .. "  •  Approximate marker near " .. (encounterName or "the active boss") .. "; exact indoor X/Y is unavailable")
  elseif sub ~= "" then
    status:SetText("Current room: " .. sub .. "  •  Exact indoor X/Y is unavailable; Shift-click to place a manual marker")
  else
    status:SetText("Dungeon position unavailable  •  Browse floors or Shift-click the map to place a manual marker")
  end
end

function UI:Open()
  if not frame then build() end
  if not frame then return false end
  autoSelect()
  frame:Show()
  return true
end

function UI:Close()
  if frame then frame:Hide() end
end

function UI:Toggle()
  if not frame then build() end
  if not frame then return false end
  if frame:IsShown() then self:Close() else self:Open() end
  return true
end

function UI:IsOn() return frame and frame:IsShown() or false end

function UI:Init()
  build()
  if not frame then return end
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:RegisterEvent("ZONE_CHANGED")
  events:RegisterEvent("ZONE_CHANGED_INDOORS")
  events:RegisterEvent("ENCOUNTER_START")
  events:RegisterEvent("ENCOUNTER_END")
  events:SetScript("OnEvent", function(_, event, id, name)
    if event == "ENCOUNTER_START" then encounterID, encounterName = id, name
    elseif event == "ENCOUNTER_END" then encounterID, encounterName = nil, nil end
    if frame:IsShown() then
      autoSelect()
      layoutTiles()
      updateStatus()
    end
  end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < 0.4 then return end
    updateElapsed = 0
    if frame:IsShown() then
      local sub = currentSubzone()
      local autoFloor = selected and floorFromSubzone(selected, sub)
      if sub ~= lastSubzone then
        lastSubzone = sub
        if autoFloor and autoFloor ~= selectedFloor then selectedFloor = autoFloor; loadMap() end
        updateStatus()
      end
      local x, y = selected and currentPlayerPosition(selected)
      if x and y then layoutTiles() end
      if encounterID or manualMark() then updatePins(mapScale()) end
    end
  end)
end

return UI
