-- Compact dungeon zone map for WildSpark's integrated map catalog.
local _, ns = ...
local HM = ns.WildMaps
local Zone = { zoom = 1, sizeIndex = 2 }
HM.ZoneMap = Zone
local sizes = { {340,250}, {430,310}, {560,400} }
local function make()
 if Zone.frame then return end
 local f=CreateFrame("Frame","WildSparkZoneMap",UIParent,"BackdropTemplate")
 Zone.frame=f; f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
 f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
 f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");f.title:SetPoint("TOPLEFT",12,-10)
 f.close=CreateFrame("Button",nil,f,"UIPanelCloseButton");f.close:SetPoint("TOPRIGHT",-2,-2);f.close:SetScript("OnClick",function()f:Hide()end)
 f.view=CreateFrame("Frame",nil,f);f.view:SetPoint("TOPLEFT",12,-34);f.view:SetPoint("BOTTOMRIGHT",-12,38)
 f.render=HM.Renderer:Create(f.view)
 f.label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");f.label:SetPoint("BOTTOMLEFT",12,14)
 local function btn(text,point,x,fn)local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(42,22);b:SetText(text);b:SetPoint(point,f,x,0);b:SetScript("OnClick",fn);return b end
 f.prev=btn("<","BOTTOMLEFT",12,function()Zone:StepMap(-1)end);f.next=btn(">","BOTTOMLEFT",58,function()Zone:StepMap(1)end)
 f.minus=btn("-","BOTTOMRIGHT",-104,function()Zone:SetZoom(Zone.zoom-.25)end);f.plus=btn("+","BOTTOMRIGHT",-58,function()Zone:SetZoom(Zone.zoom+.25)end)
 f.floor=btn("Floor","BOTTOMRIGHT",-12,function()Zone:StepFloor()end)
 f:SetScript("OnMouseWheel",function(_,d)Zone:SetZoom(Zone.zoom+(d>0 and .25 or -.25))end)
 f:SetScript("OnShow",function()Zone:Refresh()end)
 f:SetScript("OnUpdate",function(_,e)Zone.elapsed=(Zone.elapsed or 0)+e;if Zone.elapsed>.5 then Zone.elapsed=0;Zone:Refresh()end end)
 Zone:ApplySize()
end
function Zone:ApplySize()if self.frame then local s=sizes[self.sizeIndex];self.frame:SetSize(s[1],s[2])end end
function Zone:SetZoom(v)self.zoom=math.max(1,math.min(2.5,v));if self.frame then self:Refresh()end end
function Zone:GetMap()
 if self.pinnedMap then return HM.Registry:GetMap(self.pinnedMap) end
 return HM.currentMap
end
function Zone:StepMap(d)
 local maps=HM.Registry:GetMaps();if #maps==0 then return end
 local idx=1;for i,m in ipairs(maps)do if m.id==(self.pinnedMap or (HM.currentMap and HM.currentMap.id))then idx=i;break end end
 idx=((idx-1+d)%#maps)+1;self.pinnedMap=maps[idx].id;self:Refresh()
end
function Zone:StepFloor()
 local map=self:GetMap();if not map or not map.floors or #map.floors<2 then return end
 local wm=HM.WorldMap;local i=wm:GetSelectedFloorIndex(map)or 1;wm.floorSelections[map.id]=i%#map.floors+1;if wm.map==map then wm:RefreshMap();wm:RefreshFloorSelector()end;self:Refresh()
end
function Zone:Refresh()
 if not self.frame then return end
 local map=self:GetMap();if not map then self.title=self.frame.title;self.frame.title:SetText("WildMaps Zone Map");self.frame.label:SetText("No supported dungeon detected");HM.Renderer:Clear(self.frame.render);return end
 self.frame.title:SetText(map.name)
 local draw=map
 if map.floors and #map.floors>0 then local i=HM.WorldMap:GetSelectedFloorIndex(map)or 1;local floor=map.floors[i];draw=setmetatable({}, {__index=map});draw.render=floor.render or map.render end
 HM.Renderer:Layout(self.frame.render,draw);self.frame.render:SetScale(self.zoom)
 local i=HM.WorldMap:GetSelectedFloorIndex(map)or 1;self.frame.floor:SetText(map.floors and #map.floors>1 and (i.."/"..#map.floors)or"Floor")
 self.frame.label:SetText(string.format("Zoom %.0f%%  •  Mouse wheel to zoom",self.zoom*100))
end
function Zone:Show()make();self.pinnedMap=nil;self.frame:Show();self:Refresh()end
function Zone:Toggle()make();if self.frame:IsShown()then self.frame:Hide()else self:Show()end end
SLASH_WILDMAPZONE1="/wildmaps"
SlashCmdList.WILDMAPZONE=function(msg)
 msg=(msg or ""):lower()
 if msg=="zone" or msg=="map" then Zone:Toggle()
 elseif msg=="size" then Zone.sizeIndex=Zone.sizeIndex%#sizes+1;make();Zone:ApplySize();Zone.frame:Show()
 else HM:Print("commands: /wildmaps zone, /wildmaps size") end
end
