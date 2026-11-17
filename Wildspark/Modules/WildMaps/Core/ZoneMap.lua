-- Compact dungeon zone map for WildSpark's integrated map catalog.
local _, ns = ...
local HM = ns.WildMaps
local Zone = { zoom = 1, sizeIndex = 2 }
HM.ZoneMap = Zone
if ns.WildMapsModule then ns.WildMapsModule.ZoneMap = Zone end
-- Floor selection is shared with the catalog but never touches Blizzard's
-- World Map frame. WildMaps is presented only in this compact movable window.
HM.WorldMap = HM.WorldMap or { floorSelections = {} }
local MapState = HM.WorldMap
MapState.floorSelections = MapState.floorSelections or {}
function MapState:SetMap(map) self.map = map end
function MapState:GetSelectedFloorIndex(map)
    local count = map and map.floors and #map.floors or 0
    if count < 1 then return 1 end
    local index = self.floorSelections[map.id] or 1
    index = math.max(1, math.min(count, index))
    self.floorSelections[map.id] = index
    return index
end
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 340, 250, 760, 560
local function zoneText(key, fallback)
    local locale = ns.L
    local value = locale and locale[key]
    if type(value) == "string" then return value end
    return fallback
end
function Zone:SetMap(map) MapState.map = map end
local function make()
 if Zone.frame then return end
 local f=CreateFrame("Frame","WildSparkZoneMap",UIParent,"BackdropTemplate")
 Zone.frame=f; f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
 f:SetPoint("CENTER",UIParent,"CENTER",0,0)
 local hotkey=CreateFrame("Button","WildSparkZoneMapHotkey",UIParent); hotkey:SetSize(1,1); hotkey:SetPoint("CENTER"); hotkey:SetAlpha(0); hotkey:SetScript("OnClick",function()Zone:ToggleCurrent()end); hotkey:Show(); Zone.hotkeyOwner=hotkey
 local function bindHotkey()
  if not InCombatLockdown or not InCombatLockdown() then
   if type(SetOverrideBindingClick)=="function" then pcall(SetOverrideBindingClick,hotkey,true,"SHIFT-M","WildSparkZoneMapHotkey") end
  end
 end
 f:RegisterEvent("PLAYER_LOGIN"); f:RegisterEvent("PLAYER_ENTERING_WORLD"); f:RegisterEvent("PLAYER_REGEN_ENABLED")
 f:SetScript("OnEvent",bindHotkey); bindHotkey()
 f:SetScript("OnDragStart",function(self)self:StartMoving()end); f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
 f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetPoint("TOPLEFT",12,-10)
 f.close=CreateFrame("Button",nil,f,"UIPanelCloseButton");f.close:SetPoint("TOPRIGHT",-2,-2);f.close:SetScript("OnClick",function()f:Hide()end)
 f.view=CreateFrame("Frame",nil,f);f.view:SetPoint("TOPLEFT",12,-34);f.view:SetPoint("BOTTOMRIGHT",-12,38);f.view:EnableMouse(true);f.view:EnableMouseWheel(true);f.view:SetClipsChildren(true)
 f.render=HM.Renderer:Create(f.view)
 f.label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.label:SetPoint("BOTTOMLEFT",12,14)
 local function btn(text,point,relativePoint,x,y,fn)local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(42,22);b:SetText(text);b:SetPoint(point,f,relativePoint,x,y);b:SetScript("OnClick",fn);return b end
 f.prev=btn("<","BOTTOMLEFT","BOTTOMLEFT",12,8,function()Zone:StepMap(-1)end);f.next=btn(">","BOTTOMLEFT","BOTTOMLEFT",58,8,function()Zone:StepMap(1)end)
 f.minus=btn("-","BOTTOMRIGHT","BOTTOMRIGHT",-104,8,function()Zone:SetZoom(Zone.zoom-.25)end);f.plus=btn("+","BOTTOMRIGHT","BOTTOMRIGHT",-58,8,function()Zone:SetZoom(Zone.zoom+.25)end)
 f.floor=btn(zoneText("WILDMAPS_FLOOR","Floor"),"BOTTOMRIGHT","BOTTOMRIGHT",-12,8,function()Zone:StepFloor()end)
 f.resize=CreateFrame("Button",nil,f)
 f.resize:SetSize(18,18);f.resize:SetPoint("BOTTOMRIGHT",-5,5);f.resize:EnableMouse(true)
 f.resize.texture=f.resize:CreateTexture(nil,"OVERLAY");f.resize.texture:SetAllPoints();f.resize.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
 f.resize:SetScript("OnMouseDown",function()f:StartSizing("BOTTOMRIGHT")end)
 f.resize:SetScript("OnMouseUp",function()f:StopMovingOrSizing();local w,h=f:GetSize();f:SetSize(math.max(MIN_WIDTH,math.min(MAX_WIDTH,w)),math.max(MIN_HEIGHT,math.min(MAX_HEIGHT,h)))end)
 if f.SetResizable then f:SetResizable(true) end
 if f.SetResizeBounds then f:SetResizeBounds(MIN_WIDTH,MIN_HEIGHT,MAX_WIDTH,MAX_HEIGHT) end
 local function onWheel(_,d)Zone:SetZoom(Zone.zoom+(d>0 and .25 or -.25))end;f:EnableMouseWheel(true);f:SetScript("OnMouseWheel",onWheel);f.view:SetScript("OnMouseWheel",onWheel)
 f:SetScript("OnShow",function()Zone:Refresh()end)
 f:SetScript("OnUpdate",function(_,e)Zone.elapsed=(Zone.elapsed or 0)+e;if Zone.elapsed>.5 then Zone.elapsed=0;Zone:Refresh()end end)
 Zone:ApplySize()
 f:Hide()
end
function Zone:ApplySize()if self.frame and not self.frame:GetWidth() or self.frame and self.frame:GetWidth()==0 then self.frame:SetSize(430,310)end end
-- 100% is the fitted full-map view. Never scale the artwork below its fitted
-- size, which used to make the map collapse into a tiny patch in the viewport.
function Zone:SetZoom(v)self.zoom=math.max(1,math.min(3,v));if self.frame then self:Refresh()end end
function Zone:GetMap()
 if self.pinnedMap then return HM.Registry:GetMap(self.pinnedMap) end
 return HM.currentMap
end
function Zone:StepMap(d)
 local maps=HM.Registry:GetMaps();if #maps==0 then return end
 local idx=d>0 and 0 or #maps;for i,m in ipairs(maps)do if m.id==(self.pinnedMap or (HM.currentMap and HM.currentMap.id))then idx=i;break end end
 idx=((idx-1+d)%#maps)+1;self.pinnedMap=maps[idx].id;self:Refresh()
end
function Zone:StepFloor()
 local map=self:GetMap();if not map or not map.floors or #map.floors<2 then return end
 local wm=HM.WorldMap;local i=wm:GetSelectedFloorIndex(map)or 1;wm.floorSelections[map.id]=i%#map.floors+1;self:Refresh()
end
function Zone:Refresh()
 if not self.frame then return end
 local map=self:GetMap()
 if not map then
  local uiMapID
  if C_Map and type(C_Map.GetBestMapForUnit)=="function" then local ok,id=pcall(C_Map.GetBestMapForUnit,"player");if ok then uiMapID=id end end
  local info
  if uiMapID and C_Map and type(C_Map.GetMapInfo)=="function" then local ok,value=pcall(C_Map.GetMapInfo,uiMapID);if ok then info=value end end
  if uiMapID and info and HM.Renderer:LayoutLiveMap(self.frame.render, uiMapID) then
 self.frame.render:SetScale(self.zoom)
   self.liveMapID = uiMapID
   self.frame.title:SetText(info.name or GetRealZoneText and GetRealZoneText() or "Current Zone")
   self.frame.label:SetText(string.format("Current zone  •  Zoom %.0f%%  •  Mouse wheel to zoom  •  Shift+M to close", self.zoom * 100))
   self.frame.floor:SetText("Zone")
   return
  end
  self.liveMapID=nil
  self.frame.title:SetText(zoneText("WILDMAPS_ZONE_TITLE","WildMaps Zone Map"));self.frame.label:SetText(zoneText("WILDMAPS_NO_MAP","No zone map available"));self.frame.floor:SetText("Floor");HM.Renderer:Clear(self.frame.render);return
 end
 self.liveMapID=nil
 self.frame.title:SetText(map.name)
 local draw=map
 if map.floors and #map.floors>0 then local i=HM.WorldMap:GetSelectedFloorIndex(map)or 1;local floor=map.floors[i];draw=setmetatable({}, {__index=map});draw.render=floor.render or map.render end
 HM.Renderer:Layout(self.frame.render,draw);self.frame.render:SetScale(self.zoom)
 local i=HM.WorldMap:GetSelectedFloorIndex(map)or 1;self.frame.floor:SetText(map.floors and #map.floors>1 and (i.."/"..#map.floors)or"Floor")
 self.frame.label:SetText(string.format("Zoom %.0f%%  •  Mouse wheel to zoom",self.zoom*100))
end
function Zone:Show()
 if ns.WildMapsModule and not ns.WildMapsModule.IsEnabled() then return false end
 make();self.frame:Show();self:Refresh();return true
end
function Zone:ToggleCurrent()
 if ns.WildMapsModule and not ns.WildMapsModule.IsEnabled() then return false end
 make();if self.frame:IsShown()then self.frame:Hide()else self.pinnedMap=HM.currentMap and HM.currentMap.id or nil;self:Show()end
 return true
end
function Zone:Toggle()return self:ToggleCurrent()end
make()
SLASH_WILDMAPZONE1="/wildmaps"
SlashCmdList.WILDMAPZONE=function(msg)
 msg=(msg or ""):lower()
 if msg=="zone" or msg=="map" then Zone:ToggleCurrent()
 else HM:Print(zoneText("WILDMAPS_COMMANDS","commands: /wildmaps zone")) end
end

