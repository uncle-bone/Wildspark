local _, addonNS = ...
local HM = addonNS.WildMaps

-- WC current-area localization experiment.
--
-- Purpose:
--   Use Blizzard's current indoor/subzone name as a coarse localization anchor
--   and shade the corresponding WMO groups on WildMaps' WC instance map.
--
-- This is deliberately isolated from Core and the production map module.
-- It makes no claim about exact player position inside the highlighted area.

local Area = {}
HM.Experiments = HM.Experiments or {}
HM.Experiments.WCCurrentArea = Area

local WC_INSTANCE_ID = 43
local TARGET_MAP_ID = "wailing_caverns_instance_legacy"
local POLL_INTERVAL = 0.25

-- Group geometry exported from WailingCaverns_Instance.wmo (FileDataID 109567).
-- Coordinates are WMO-local. desc is Blizzard's groupDescription when present.
local groups = {
    {i=0,  id=3335, name="bridge_right",  desc="Screaming Gully",        x1=-71.393028,  y1=-331.390717, x2=77.012558,   y2=-236.989426},
    {i=1,  id=3337, name="bridge_left",   desc="Screaming Gully",        x1=-179.447784, y1=-158.923767, x2=96.834580,   y2=2.432465},
    {i=2,  id=3342, name="32324",         desc="Pit of Fangs",           x1=-80.504013,  y1=-554.361206, x2=169.650543,  y2=-360.036438},
    {i=3,  id=3343, name="fafaf",         desc="Crag of the Everliving", x1=25.334133,   y1=-100.476059, x2=367.462555,  y2=89.164742},
    {i=4,  id=3336, name="final",         desc="Dreamer's Rock",         x1=-187.503922, y1=-305.155975, x2=-60.490612,  y2=-20.583588},
    {i=5,  id=3332, name="afterbigroom",  desc=nil,                      x1=97.748810,   y1=-156.759827, x2=187.767517,  y2=-113.999931},
    {i=6,  id=3333, name="slanted_hall",  desc=nil,                      x1=58.991867,   y1=-261.131805, x2=128.956878,  y2=-146.756851},
    {i=7,  id=3334, name="bridge_middle", desc="Screaming Gully",        x1=-65.641380,  y1=-237.044968, x2=70.024834,   y2=-158.868225},
    {i=8,  id=5692, name="transition",    desc="Pit of Fangs",           x1=55.747757,   y1=-369.063721, x2=82.798538,   y2=-301.678436},
    {i=9,  id=5693, name="stomach",       desc="Winding Chasm",          x1=186.571426,  y1=-93.141335,  x2=415.876160,  y2=176.928604},
    {i=10, id=3338, name="big1",          desc=nil,                      x1=186.571426,  y1=-335.668671, x2=483.479431,  y2=84.817696},
    {i=11, id=3339, name="big4",          desc=nil,                      x1=147.585541,  y1=-337.288971, x2=364.530457,  y2=84.817696},
    {i=12, id=6384, name="Sandy",         desc=nil,                      x1=96.779022,   y1=-85.222137,  x2=147.008514,  y2=-56.516006},
    {i=13, id=6416, name="maze02",        desc="Winding Chasm",          x1=221.559204,  y1=138.853867,  x2=317.547455,  y2=267.612579},
    {i=14, id=6417, name="maze01",        desc="Winding Chasm",          x1=45.766815,   y1=50.398251,   x2=189.997330,  y2=212.910782},
    {i=15, id=6418, name="maze03",        desc="Winding Chasm",          x1=140.418839,  y1=170.705231,  x2=246.683640,  y2=254.346542},
    {i=16, id=6419, name="maze04",        desc="Winding Chasm",          x1=-12.053643,  y1=14.605211,   x2=104.737274,  y2=108.775261},
    {i=17, id=6420, name="maze05",        desc="Winding Chasm",          x1=-83.555466,  y1=102.633064,  x2=60.536995,   y2=149.218246},
    {i=18, id=6421, name="maze06",        desc="Winding Chasm",          x1=-53.573895,  y1=127.201500,  x2=89.806725,   y2=281.643707},
    {i=19, id=6422, name="maze07",        desc="Winding Chasm",          x1=86.163910,   y1=236.384827,  x2=215.738663,  y2=369.777863},
    {i=20, id=6423, name="maze08",        desc="Winding Chasm",          x1=107.317963,  y1=205.235855,  x2=153.084885,  y2=264.043793},
    {i=21, id=6424, name="maze09",        desc="Winding Chasm",          x1=182.082703,  y1=228.022964,  x2=303.917328,  y2=350.275726},
    {i=22, id=6680, name="maze_split",    desc=nil,                      x1=9.523927,    y1=176.767975,  x2=128.579086,  y2=286.861908},
}

-- WMO portal adjacency exported from the same model.
local edges = {
    {7,0},{7,4},{7,6},{6,5},{11,5},{12,1},{8,0},{8,2},{9,3},{11,10},
    {12,3},{3,1},{13,9},{14,3},{15,13},{15,14},{17,14},{16,14},{17,16},
    {18,17},{18,14},{22,18},{22,14},{22,20},{20,15},{19,15},{21,15},
    {21,19},{21,13},{7,1},{22,19},
}

local groupByIndex = {}
local adjacency = {}
for _, group in ipairs(groups) do
    groupByIndex[group.i] = group
    adjacency[group.i] = {}
end
for _, edge in ipairs(edges) do
    local a, b = edge[1], edge[2]
    table.insert(adjacency[a], b)
    table.insert(adjacency[b], a)
end

local function normalize(text)
    if not text or text == "" then return "" end
    return string.lower(text)
end

-- Build the area index from Blizzard-named WMO groups only.
-- Do not automatically absorb unnamed groups into nearby named areas: the
-- first visual test showed that this made the highlight much broader than the
-- evidence justified.
local areaIndex = {}
for _, group in ipairs(groups) do
    if group.desc then
        local key = normalize(group.desc)
        areaIndex[key] = areaIndex[key] or {}
        table.insert(areaIndex[key], group)
    end
end

-- The immediate instance entrance has no Blizzard subzone text. The native
-- minimap screenshots place the player on the unnamed `slanted_hall` group
-- immediately before the Screaming Gully boundary, so use that one group as
-- an explicit entrance fallback.
local entranceGroups = { groupByIndex[6] }

-- Convert WMO-local X/Y into the already-rotated production WC map coordinate.
-- Raw wow.export minimap:
--   px = (topLeftX - localX) * 2
--   py = (localY - topLeftY) * 2
-- Production artwork is the raw image rotated exactly 90 degrees clockwise:
--   displayX = rawHeight - rawY
--   displayY = rawX
local RAW_H = 2094
local RAW_TOP_LEFT_X = 187.50392150878906
local RAW_TOP_LEFT_Y = -492.38482666015625
local PPU = 2
local DISPLAY_W = 2094
local DISPLAY_H = 1517

local function localToDisplay(x, y)
    -- WMO group bounds use the opposite X/Y signs from the minimap coordinate
    -- space exported by wow.export. Negate both axes before applying the same
    -- raw-minimap -> 90-degree-clockwise display transform.
    local worldX = -x
    local worldY = -y
    local rawX = (RAW_TOP_LEFT_X - worldX) * PPU
    local rawY = (worldY - RAW_TOP_LEFT_Y) * PPU
    return RAW_H - rawY, rawX
end

local function groupDisplayRect(group)
    local points = {
        {localToDisplay(group.x1, group.y1)},
        {localToDisplay(group.x1, group.y2)},
        {localToDisplay(group.x2, group.y1)},
        {localToDisplay(group.x2, group.y2)},
    }

    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for _, point in ipairs(points) do
        minX = math.min(minX, point[1])
        maxX = math.max(maxX, point[1])
        minY = math.min(minY, point[2])
        maxY = math.max(maxY, point[2])
    end
    return minX, minY, maxX, maxY
end


local overlayTilesByArea = {
    ["__entrance"] = {
        {row=2, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\entrance_2_3.tga"},
        {row=2, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\entrance_2_4.tga"},
        {row=3, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\entrance_3_3.tga"},
        {row=3, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\entrance_3_4.tga"},
    },
    ["screaming gully"] = {
        {row=1, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_1_3.tga"},
        {row=1, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_1_4.tga"},
        {row=2, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_2_2.tga"},
        {row=2, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_2_3.tga"},
        {row=2, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_2_4.tga"},
        {row=2, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_2_5.tga"},
        {row=3, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_3_2.tga"},
        {row=3, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_3_3.tga"},
        {row=3, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_3_4.tga"},
        {row=3, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\screaming_gully_3_5.tga"},
    },
    ["pit of fangs"] = {
        {row=1, col=1, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_1_1.tga"},
        {row=1, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_1_2.tga"},
        {row=2, col=1, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_2_1.tga"},
        {row=2, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_2_2.tga"},
        {row=3, col=1, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_3_1.tga"},
        {row=3, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\pit_of_fangs_3_2.tga"},
    },
    ["crag of the everliving"] = {
        {row=2, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_2_4.tga"},
        {row=2, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_2_5.tga"},
        {row=2, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_2_6.tga"},
        {row=3, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_3_4.tga"},
        {row=3, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_3_5.tga"},
        {row=3, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_3_6.tga"},
        {row=4, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_4_4.tga"},
        {row=4, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_4_5.tga"},
        {row=4, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_4_6.tga"},
        {row=5, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_5_4.tga"},
        {row=5, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_5_5.tga"},
        {row=5, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\crag_of_the_everliving_5_6.tga"},
    },
    ["dreamer's rock"] = {
        {row=1, col=2, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\dreamers_rock_1_2.tga"},
        {row=1, col=3, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\dreamers_rock_1_3.tga"},
        {row=1, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\dreamers_rock_1_4.tga"},
    },
    ["winding chasm"] = {
        {row=2, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_2_5.tga"},
        {row=2, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_2_6.tga"},
        {row=2, col=7, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_2_7.tga"},
        {row=3, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_3_4.tga"},
        {row=3, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_3_5.tga"},
        {row=3, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_3_6.tga"},
        {row=3, col=7, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_3_7.tga"},
        {row=3, col=8, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_3_8.tga"},
        {row=4, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_4_4.tga"},
        {row=4, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_4_5.tga"},
        {row=4, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_4_6.tga"},
        {row=4, col=7, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_4_7.tga"},
        {row=4, col=8, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_4_8.tga"},
        {row=5, col=4, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_5_4.tga"},
        {row=5, col=5, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_5_5.tga"},
        {row=5, col=6, texture="Interface\\AddOns\\WildSpark\\Modules\\WildMaps\\Media\\Maps\\WailingCavernsInstance\\AreaHighlights\\winding_chasm_5_6.tga"},
    },
}

Area.enabled = false
Area.textures = {}
Area.pollAccumulator = 0
Area.lastAreaKey = nil
Area.lastLayoutKey = nil
Area.currentText = nil

local function getInstanceID()
    return GetInstanceInfo and select(8, GetInstanceInfo()) or nil
end

function Area:IsInWC()
    local inInstance = IsInInstance and select(1, IsInInstance()) or false
    return inInstance and getInstanceID() == WC_INSTANCE_ID
end

function Area:GetCurrentArea()
    local subzone = GetSubZoneText and GetSubZoneText() or ""
    local minimap = GetMinimapZoneText and GetMinimapZoneText() or ""

    local subzoneKey = normalize(subzone)
    if subzoneKey ~= "" and areaIndex[subzoneKey] then
        return subzoneKey, subzone, areaIndex[subzoneKey]
    end

    local minimapKey = normalize(minimap)
    if minimapKey ~= "" and areaIndex[minimapKey] then
        return minimapKey, minimap, areaIndex[minimapKey]
    end

    if subzoneKey == "" and minimapKey == "the wailing caverns" then
        return "__entrance", "Entrance (inferred)", entranceGroups
    end

    return nil, nil, nil
end

function Area:EnsureTextures(count, renderer)
    while #self.textures < count do
        local texture = renderer:CreateTexture(nil, "OVERLAY")
        texture:SetBlendMode("BLEND")
        texture:Hide()
        self.textures[#self.textures + 1] = texture
    end
end

function Area:EnsureLabel(renderer)
    if self.label and self.label:GetParent() == renderer then return end
    if self.label then self.label:Hide() end
    local label = renderer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOP", renderer, "TOP", 0, -12)
    label:SetTextColor(1, 0.82, 0)
    label:Hide()
    self.label = label
end

function Area:Hide()
    for _, texture in ipairs(self.textures) do texture:Hide() end
    if self.label then self.label:Hide() end
    self.lastAreaKey = nil
    self.lastLayoutKey = nil
    self.currentText = nil
end

function Area:Refresh(force)
    if not self.enabled or not self:IsInWC() then self:Hide(); return end
    if not HM.WorldMap or not HM.WorldMap.map or HM.WorldMap.map.id ~= TARGET_MAP_ID then self:Hide(); return end

    local renderer = HM.WorldMap.renderer
    if not renderer or not renderer:IsShown() then self:Hide(); return end

    local areaKey, areaText = self:GetCurrentArea()
    local tileList = areaKey and overlayTilesByArea[areaKey] or nil
    if not tileList then self:Hide(); return end

    local width, height = renderer:GetWidth(), renderer:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return end

    local layoutKey = string.format("%s|%.2f|%.2f", areaKey, width, height)
    if not force and layoutKey == self.lastLayoutKey then return end

    self:EnsureTextures(#tileList, renderer)
    self:EnsureLabel(renderer)

    local sx = width / DISPLAY_W
    local sy = height / DISPLAY_H
    local tileSize = 256

    for index, tileData in ipairs(tileList) do
        local texture = self.textures[index]
        local sourceX = (tileData.col - 1) * tileSize
        local sourceY = (tileData.row - 1) * tileSize
        local sourceW = math.min(tileSize, DISPLAY_W - sourceX)
        local sourceH = math.min(tileSize, DISPLAY_H - sourceY)

        texture:ClearAllPoints()
        texture:SetSize(sourceW * sx, sourceH * sy)
        texture:SetPoint("TOPLEFT", renderer, "TOPLEFT", sourceX * sx, -sourceY * sy)
        texture:SetTexture(tileData.texture)
        texture:SetTexCoord(0, sourceW / tileSize, 0, sourceH / tileSize)
        texture:Show()
    end

    for index = #tileList + 1, #self.textures do self.textures[index]:Hide() end

    self.label:SetText("Current area: " .. areaText)
    self.label:Show()
    self.lastAreaKey = areaKey
    self.lastLayoutKey = layoutKey
    self.currentText = areaText
end

function Area:Status()
    local areaKey, areaText, matches = self:GetCurrentArea()
    HM:Print("WC current-area contour overlay:", self.enabled and "ON" or "off")
    HM:Print("subzone='" .. (GetSubZoneText and GetSubZoneText() or "") ..
        "' minimap='" .. (GetMinimapZoneText and GetMinimapZoneText() or "") .. "'")
    if areaKey and matches then
        local names = {}
        for _, group in ipairs(matches) do
            names[#names + 1] = string.format("%d:%s%s", group.i, group.name, group.desc and "" or "*")
        end
        HM:Print("Current area:", areaText, "=>", table.concat(names, ", "))
        HM:Print("Contour tiles:", #(overlayTilesByArea[areaKey] or {}))
        HM:Print("* = inferred unnamed WMO group")
    else
        HM:Print("Current area: no recognized WC subzone")
    end
end

function Area:SetEnabled(enabled)
    self.enabled = enabled and true or false
    if self.enabled then
        self:Refresh(true)
        HM:Print("WC current-area contour overlay ON")
    else
        self:Hide()
        HM:Print("WC current-area contour overlay off")
    end
end

function Area:HandleCommand(message)
    local command = string.lower((message or ""):match("^%s*(%S*)") or "")
    if command == "" or command == "status" then self:Status()
    elseif command == "on" then self:SetEnabled(true)
    elseif command == "off" then self:SetEnabled(false)
    elseif command == "refresh" then self:Refresh(true)
    else HM:Print("WC area commands: /wma status, on, off, refresh") end
end

SLASH_WILDMAPSWCAREA1 = "/wma"
SLASH_WILDMAPSWCAREA2 = "/wmarea"
SlashCmdList.WILDMAPSWCAREA = function(message) Area:HandleCommand(message) end

local eventFrame = CreateFrame("Frame")
for _, eventName in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "MINIMAP_ZONE_CHANGED",
}) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
end

eventFrame:SetScript("OnEvent", function()
    -- Archived experiment: never restore/persist enablement automatically.
    -- It is activated only when the legacy WC WMO map is explicitly forced.
    if not Area.enabled then return end
    Area:Refresh(true)
end)

eventFrame:SetScript("OnUpdate", function(_, elapsed)
    if not Area.enabled then return end
    Area.pollAccumulator = Area.pollAccumulator + elapsed
    if Area.pollAccumulator < POLL_INTERVAL then return end
    Area.pollAccumulator = 0
    if WorldMapFrame and WorldMapFrame:IsShown() then
        Area:Refresh(false)
    elseif Area.lastAreaKey then
        Area:Hide()
    end
end)
