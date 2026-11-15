-- Unified native-map compatibility. Private development build; WoW acceptance pending.
local _, addonNS = ...
local HM = addonNS.WildMaps
local C = {leases={}, hooked=setmetatable({}, {__mode='k'}), active=false}
HM.Compatibility=C
local W=HM.WorldMap
local function under(f,parent)
 for _=1,64 do if not f then return false end;if f==parent then return true end;f=f.GetParent and f:GetParent()end
 return false
end
local function leatrixLoaded()
 return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Leatrix_Maps")
end
local function questieLoaded()
 return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('Questie')
end
local function questieModule(name)
 if not QuestieLoader or type(QuestieLoader.ImportModule)~='function' then return nil end
 local ok,value=pcall(QuestieLoader.ImportModule,QuestieLoader,name)
 if ok and type(value)=='table' then return value end
end
local function frameSurface(f)
 local kind=type(f)
 return (kind=='table' or kind=='userdata') and type(f.GetParent)=='function'
  and type(f.IsShown)=='function' and type(f.Show)=='function' and type(f.Hide)=='function' and type(f.SetShown)=='function'
end
-- Internal OpenMap surfaces are source-locked to the two audited Forever packages.
-- 0.7.5 predates Client/Root; its actual IsBuilt/Parts accessors identify the same pair.
function C:OpenMapSurfaces(canvas)
 local ns,api=_G.OpenMap,_G.OpenMapAPI
 if type(ns)~='table' then return end
 local legacy=ns.version=='v0.7.5-beta' and ns.Client==nil
 local current=ns.version=='v0.8.0-beta' and ns.Client=='Forever'
 if not (legacy or current) or type(api)~='table' or api.major~=1 or api.version~=4
  or type(api.IsStitched)~='function' or type(ns.GetModule)~='function' then return end
 local ok,mod=pcall(ns.GetModule,ns,'worldmap')
 local stitch=ns.MapStitch
 if not ok or type(mod)~='table' or type(mod.IsStitched)~='function' or type(stitch)~='table'
  or type(stitch.Parts)~='function' or type(stitch.SetShown)~='function'
  or (legacy and type(stitch.IsBuilt)~='function') or (current and type(stitch.Root)~='function') then return end
 local cached=self.openMapSurfaces
 local cachedValid=cached and cached.api==api and cached.mod==mod and cached.stitch==stitch and cached.canvas==canvas
  and cached.legacy==legacy and cached.parts==stitch.Parts and cached.isBuilt==stitch.IsBuilt and cached.root
  and frameSurface(canvas) and cached.root:GetParent()==canvas and cached.icons:GetParent()==canvas:GetParent()
  and under(cached.icons,WorldMapFrame.ScrollContainer)
 local root,parts
 if legacy then
  local ready,built=pcall(stitch.IsBuilt)
  if not ready or type(built)~='boolean' then return end
  if built then
   if cachedValid then return cached end
   local read,value=pcall(stitch.Parts)
   if not read or type(value)~='table' then return end
   parts=value
   local pair=parts[1]
   local frames=type(pair)=='table' and pair[1]=='all OpenMap art and icons' and pair[2]
   root=type(frames)=='table' and frames[1]
   if not root then return end
  end
 else
  local got,value=pcall(stitch.Root)
  if not got then return end
  root=value
  if cachedValid and cached.root==root then return cached end
 end
 if root and not frameSurface(root) then return end
 local state={api=api,mod=mod,stitch=stitch,canvas=canvas,parts=stitch.Parts,isBuilt=stitch.IsBuilt,legacy=legacy}
 if root then
  local read,value=true,parts
  if not parts then read,value=pcall(stitch.Parts)end
  local pair=read and type(value)=='table' and value[1]
  local frames=type(pair)=='table' and pair[1]=='all OpenMap art and icons' and pair[2]
  local icons=type(frames)=='table' and frames[2]
  if type(frames)~='table' or frames[1]~=root or not frameSurface(canvas)
   or root:GetParent()~=canvas or not frameSurface(icons) or icons==root
   or icons:GetParent()~=canvas:GetParent() or not under(icons,WorldMapFrame.ScrollContainer) then return end
  state.root,state.icons=root,icons
 end
 self.openMapSurfaces=state
 return state
end
local function stitched(state)
 if not state then return false end
 local ok,value=pcall(state.api.IsStitched)
 return ok and value==true
end
-- Match OpenMap's verified stitched parent branch; native fallback remains
-- governed by WildMaps' existing observed-map-change navigation handling.
local function openMapPadFocus()
 local soft=_G.SoftCursor
 return soft and soft:IsShown() and InputUtil and type(InputUtil.IsGamepadUIEnabled)=='function'
  and InputUtil.IsGamepadUIEnabled()
  and (not WorldMapFrame.IsCanvasGamepadFocus or WorldMapFrame:IsCanvasGamepadFocus())
end
function C:HandleParentNavigation(button,parentID)
 if button~='RightButton' or W.bypassUntilClose or not W:IsPresentationShown() then return false end
 local state=self:OpenMapSurfaces(self.canvas)
 if not self.active or not stitched(state) or not (openMapPadFocus() or parentID) then return false end
 local scroll=WorldMapFrame.ScrollContainer
 if type(scroll.ShouldNavigateOnClick)~='function' or not scroll:ShouldNavigateOnClick()
  or (type(scroll.ShouldNavigateIgnoreZoneMapPositionData)=='function' and scroll:ShouldNavigateIgnoreZoneMapPositionData())
  or type(WorldMapFrame.NavigateToParentMap)~='function' then return false end
 -- OpenMap can zoom out successfully without changing the native map ID.
 -- Release the presentation before forwarding this explicit navigation request.
 self:Yield()
 WorldMapFrame:NavigateToParentMap()
 return true
end
function C:ObserveOpenMap(target,key,callback)
 if not target or type(target[key])~='function' then return end
 if not self.openMapHooks then self.openMapHooks=setmetatable({}, {__mode='k'}) end
 local hooks=self.openMapHooks[target]
 if not hooks then hooks={};self.openMapHooks[target]=hooks end
 if hooks[key]==target[key] then return end
 hooksecurefunc(target,key,callback)
 hooks[key]=target[key]
end
function C:InstallOpenMap(state)
 if not state then return end
 self:ObserveOpenMap(state.mod,'SetupPanel',function()C:Refresh()end)
 self:ObserveOpenMap(state.mod,'RefreshPanel',function()C:Refresh()end)
 self:ObserveOpenMap(state.mod,'RefreshRail',function()C:Refresh()end)
 self:ObserveOpenMap(state.mod,'SetupExtras',function()C:Refresh()end)
 self:ObserveOpenMap(state.mod,'RefreshExtras',function()C:Refresh()end)
 self:ObserveOpenMap(state.stitch,'Build',function()C.openMapSurfaces=nil;C:Refresh()end)
 self:ObserveOpenMap(state.stitch,'SetShown',function(shown)
  local now=C:OpenMapSurfaces(C.canvas)
  local lease=now and now.stitch==state.stitch and C.leases[now.icons]
  -- SetShown(false) can skip the actual frame call while our lease holds it hidden.
  if lease and lease.active and not lease.writing then lease.wanted=not not shown end
  C:Refresh()
 end)
 self:ObserveOpenMap(state.api,'ShowWorld',function(u,v)
  local now=C:OpenMapSurfaces(C.canvas)
  if now and now.api==state.api and type(u)=='number' and type(v)=='number' and stitched(now) then C:Yield()end
 end)
 self:ObserveOpenMap(WorldMapFrame,'NavigateToParentMap',function()
  local now=C:OpenMapSurfaces(C.canvas)
  if stitched(now) and openMapPadFocus() then C:Yield()end
 end)
 -- Reconcile only when a late/replaced rail changes; reuse the existing discovery tick.
 if self.active and not self.busy and self:OpenMapControls(state)~=self.openMapControlRoot then self:Refresh()end
end
local function fontString(f)
 local kind=type(f)
 return (kind=='table' or kind=='userdata') and type(f.GetObjectType)=='function' and f:GetObjectType()=='FontString'
end
function C:OpenMapCoordinates(state)
 local scroll=WorldMapFrame.ScrollContainer
 if not state or type(state.mod.CoordsLeft)~='function' or not scroll.GetChildren then return end
 local found
 for _,bar in ipairs({scroll:GetChildren()})do
  local player,cursor=bar.player,bar.cursor
  if fontString(player) and fontString(cursor) and player~=cursor
   and fontString(player.at) and fontString(cursor.at) then
   local p,q=player:GetParent(),cursor:GetParent()
   if p and q and p~=q and p:GetParent()==bar and q:GetParent()==bar
    and player.at:GetParent()==p and cursor.at:GetParent()==q then
    if found then return end -- Ambiguous structure: do not guess another addon's frame.
    found=bar
   end
  end
 end
 return found
end
-- Panel.lua's vertical tab rail is one OpenMap-owned frame; do not lease
-- every padRoot (that list also includes independent menus and dialogs).
function C:OpenMapControls(state)
 if not state or type(state.mod.padRoots)~='table' then return end
 local function button(f,parent)
  return frameSurface(f) and f:GetParent()==parent and type(f.GetObjectType)=='function' and f:GetObjectType()=='Button'
 end
 local function texture(r,parent)
  local kind=type(r)
  return (kind=='table' or kind=='userdata') and type(r.GetObjectType)=='function' and r:GetObjectType()=='Texture'
   and type(r.GetParent)=='function' and r:GetParent()==parent
 end
 local found
 for _,rail in ipairs(state.mod.padRoots)do
  if frameSurface(rail) and rail:GetParent()==WorldMapFrame and type(rail.favs)=='table'
   and button(rail.main,rail) and button(rail.arrow,rail) and rail.main~=rail.arrow
   and texture(rail.main.icon,rail.main) and texture(rail.main.bg,rail.main)
   and texture(rail.main.hover,rail.main) and texture(rail.main.selected,rail.main)
   and rail.main.glow==rail.main.selected and texture(rail.arrow.icon,rail.arrow) then
   local valid=true
   for _,fav in ipairs(rail.favs)do if not button(fav,rail) then valid=false;break end end
   if valid then
    if found then return end -- Ambiguous ownership: never guess a foreign control.
    found=rail
   end
  end
 end
 return found
end
-- Only the audited rail needs a settling Hide: its OnHide EndDrag clears
-- dragPos, then RefreshRail may Show once. A second Hide cannot restart it.
local function holdHidden(f,l)
 l.writing=true;f:Hide()
 if l.settle and f:IsShown() then f:Hide()end
 l.writing=false
end
local blockWheel=function()end
function C:ShieldOpenMapInput(on)
 if not self.wheelLeases then self.wheelLeases={} end
 local desired={}
 if on then
  for _,key in ipairs({'interactionLayer','floorSelector'})do
   local f=W[key]
   if f and f.EnableMouseWheel and f.IsMouseWheelEnabled then desired[f]=true end
  end
 end
 for f,l in pairs(self.wheelLeases)do
  if not desired[f]then
   if f:GetScript('OnMouseWheel')==blockWheel then f:SetScript('OnMouseWheel',l.script) end
   f:EnableMouseWheel(l.enabled);self.wheelLeases[f]=nil
  end
 end
 for f in pairs(desired)do
  if not self.wheelLeases[f] then
   self.wheelLeases[f]={enabled=f:IsMouseWheelEnabled(),script=f:GetScript('OnMouseWheel')}
  end
  f:SetScript('OnMouseWheel',blockWheel);f:EnableMouseWheel(true)
 end
end
function C:Visibility(f,on,settle)
 if not f or not f.IsShown then return end
 local l=self.leases[f]
 if on then
  if not l then
   l={wanted=f:IsShown(),active=false,settle=settle==true};self.leases[f]=l
   hooksecurefunc(f,'Show',function()
    if l.writing or not l.active then return end;l.wanted=true;holdHidden(f,l)
   end)
   hooksecurefunc(f,'Hide',function()if l.active and not l.writing then l.wanted=false end end)
   hooksecurefunc(f,'SetShown',function(_,v)
    if not l.active or l.writing then return end
    l.wanted=not not v;holdHidden(f,l)
   end)
  end
  l.settle=settle==true
  if not l.active then l.wanted=f:IsShown();l.active=true end
  holdHidden(f,l)
 elseif l and l.active then
  l.active=false;l.writing=true;f:SetShown(l.wanted);l.writing=false
 end
end
function C:TooltipAlpha(t,on)
 if not t then return end
 if not self.alphas then self.alphas={}end
 local l=self.alphas[t]
 if on then
  if not l then
   l={};self.alphas[t]=l
   hooksecurefunc(t,'SetAlpha',function(_,a)
    if l.active and not l.writing then l.wanted=a;l.writing=true;t:SetAlpha(0);l.writing=false end
   end)
  end
  if not l.active then l.wanted=t:GetAlpha();l.active=true end
  l.writing=true;t:SetAlpha(0);l.writing=false
 elseif l and l.active then l.active=false;t:SetAlpha(l.wanted)end
end
function C:UpdateTooltips()
 local desired={}
 if self.active then
  if questieLoaded()and _G.QuestieGamepadMapTooltip then desired[_G.QuestieGamepadMapTooltip]=true end
  if leatrixLoaded()and _G.LeaMapsPOITooltip then desired[_G.LeaMapsPOITooltip]=true end
 end
 for t in pairs(self.alphas or {})do if not desired[t]then self:TooltipAlpha(t,false)end end
 for t in pairs(desired)do self:TooltipAlpha(t,true)end
end
function C:ReleaseNativeTooltip(canvas)
 local t=GameTooltip;local owner=t and t.GetOwner and t:GetOwner()
 if owner and under(owner,canvas)then
  local leave=owner.GetScript and owner:GetScript('OnLeave')
  if leave then leave(owner)end
  if t:GetOwner()==owner then t:Hide()end
 end
end
function C:Yield()
 if not self.active or not W:IsPresentationShown()then return end
 W.bypassUntilClose=true;W.pendingNavigation=nil;W:RefreshMap();W:RefreshFloorSelector()
end
function C:Install()
 if WorldMapFrame and not self.hooked[WorldMapFrame]then
  self.hooked[WorldMapFrame]=true
  WorldMapFrame:HookScript('OnHide',function()if HM.MapMarkers then HM.MapMarkers:HideAll()end;C:Refresh()end)
 end
    if leatrixLoaded() and not self.slashHooked and SlashCmdList
        and type(SlashCmdList.Leatrix_Maps) == 'function' then
        hooksecurefunc(SlashCmdList, 'Leatrix_Maps', function(message)
            if type(message) ~= 'string' or not C.active then return end
            -- Match Leatrix's token normalization; no broad SetMapID bypass.
            local normalized = message:lower():gsub('%s+', ' ')
            local command, argument = normalized:match('^(%S+) (%S+)')
            if command ~= 'map' and command ~= 'setmap' then return end
            local id = tonumber(argument)
            if not id or id <= 0 or id >= math.huge or id % 1 ~= 0 then return end
            if command == 'setmap' and (id >= 99999 or not C_Map.GetMapArtLayers(id)) then return end
            if command == 'map' and not C_Map.GetMapInfo(argument) then return end
            if not WorldMapFrame or WorldMapFrame:GetMapID() ~= id then return end
            C:Yield()
        end)
        self.slashHooked = true
    end
 if questieLoaded()and not self.tracker then
  local tracker=questieModule('TrackerUtils')
  if not tracker then return end
  if type(tracker.ShowObjectiveOnMap)=='function'and type(tracker.ShowFinisherOnMap)=='function'then
   local distance=questieModule('DistanceUtils')
   local zones=questieModule('ZoneDB')
   if not distance or not zones then return end
   local function confirmed(which,record)
    if not C.active or not record then return end
    -- Read-only revalidation of the same successful-route precondition; same-ID requests count.
    local fn=which=='objective' and distance.GetNearestObjective or distance.GetNearestFinisherOrStarter
    if type(fn)~='function' or type(zones.GetUiMapIdByAreaId)~='function' then return end
    local ok,spawn,zone=pcall(fn,which=='objective' and record.spawnList or record.Finisher)
    if not ok or not spawn then return end
    local mapped,id=pcall(zones.GetUiMapIdByAreaId,zones,zone)
    if mapped and type(id)=='number' and id>0 and WorldMapFrame:GetMapID()==id then C:Yield()end
   end
   hooksecurefunc(tracker,'ShowObjectiveOnMap',function(_,record)confirmed('objective',record)end)
   hooksecurefunc(tracker,'ShowFinisherOnMap',function(_,record)confirmed('finisher',record)end)
   self.tracker=tracker
  end
 end
end
local strataRank={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
function C:SyncFloors()
 if not self.active or not W.floorSelector or not W.interactionLayer then return end
 local floor,shield=W.floorSelector,W.interactionLayer
 if (strataRank[floor:GetFrameStrata()]or 0)<(strataRank[shield:GetFrameStrata()]or 0)then
  floor:SetFrameStrata(shield:GetFrameStrata())
 end
 floor:SetFrameLevel(math.max(floor:GetFrameLevel(),shield:GetFrameLevel()+100))
end
function C:Refresh()
 if self.busy then return end;self.busy=true
 self:Install()
 local canvas=WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
 local container=WorldMapFrame and WorldMapFrame.GetCanvasContainer and WorldMapFrame:GetCanvasContainer()
 -- Never borrow either outer container or any WildMaps-owned presentation object.
 local safe=canvas and canvas~=WorldMapFrame.ScrollContainer and canvas~=container and under(canvas,WorldMapFrame.ScrollContainer)
  and not under(W.host,canvas)and not under(W.presentationHost,canvas)
  and not under(canvas,W.host)and not under(canvas,W.presentationHost)
  and not under(canvas,W.backgroundHost)and not under(canvas,W.interactionLayer)
 local openMap=safe and self:OpenMapSurfaces(canvas)
 self:InstallOpenMap(openMap)
 local active=(questieLoaded()or leatrixLoaded()or openMap~=nil)and W:IsPresentationShown()and safe or false
 if active and (not self.active or self.canvas~=canvas)then self:ReleaseNativeTooltip(canvas)end
 self.active=active
 self.canvas=canvas
 local desired={}
 local controls=active and openMap and self:OpenMapControls(openMap)
 self.openMapControlRoot=controls
 if active then
  desired[canvas]=true
  if controls then
   if not self.leases[controls] or not self.leases[controls].active then self:ReleaseNativeTooltip(controls)end
   desired[controls]=true
  end
  if openMap then
   if openMap.icons then
    if not self.leases[openMap.icons] or not self.leases[openMap.icons].active then self:ReleaseNativeTooltip(openMap.icons)end
    desired[openMap.icons]=true
   end
   local coords=self:OpenMapCoordinates(openMap)
   if coords then desired[coords]=true end
   -- The native area-label provider can also sit outside the canvas.
   for provider in pairs(WorldMapFrame.dataProviders or {})do
    local kind=type(provider)
    local label=(kind=='table' or kind=='userdata') and provider.Label
    if label and type(label.SetLabel)=='function' and under(label,WorldMapFrame.ScrollContainer) then desired[label]=true end
   end
  end
  if questieLoaded()then
   for _,name in ipairs({'BorderFrame','MiniBorderFrame'})do
    local f=WorldMapFrame[name]
    if f and f.GetRegions then for _,r in ipairs({f:GetRegions()})do if r.SetText then desired[r]=true end end end
   end
  end
  -- Native coordinate overlays can be siblings of GetCanvas, particularly with LM.
  for _,f in ipairs(WorldMapFrame.overlayFrames or {})do
   for _,key in ipairs({'PlayerCoords','CursorCoords','CrosshairCoords'})do
    if f[key]then desired[f[key]]=true end
   end
  end
 end
 for f in pairs(self.leases)do if not desired[f]then self:Visibility(f,false)end end
 for f in pairs(desired)do self:Visibility(f,true,f==controls)end
 if active and W.interactionLayer then
  W.interactionLayer:ClearAllPoints();W.interactionLayer:SetAllPoints(WorldMapFrame.ScrollContainer);W.interactionLayer:Show()
  if HM.MapMarkers then HM.MapMarkers:Refresh()end
 end
 self:ShieldOpenMapInput(active and openMap~=nil)
 self:UpdateTooltips()
 self:SyncFloors()
 self.busy=false
end
hooksecurefunc(W,'RefreshFloorSelector',function()C:SyncFloors()end)
hooksecurefunc(W,'RefreshMap',function()C:Refresh()end)
hooksecurefunc(W,'HidePresentation',function()C:Refresh()end)
hooksecurefunc(W,'Ensure',function()C:Refresh()end)
local f=CreateFrame('Frame');f:RegisterEvent('ADDON_LOADED');f:RegisterEvent('PLAYER_LOGIN')
f:SetScript('OnEvent',function()C:Refresh()end)
-- Discovery only: deferred foreign objects and replaced navigation methods may appear later.
f:SetScript('OnUpdate',function()if C.active then C:Install();C:InstallOpenMap(C:OpenMapSurfaces(C.canvas));C:UpdateTooltips()end end)
C:Refresh()
