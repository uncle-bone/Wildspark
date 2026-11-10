-- WildResources: class-aware power and cooldown tracker for WoW Forever.
-- Resource types are discovered from the live client API; unknown/custom power IDs
-- remain visible as "Power <id>" instead of being guessed to mean a Retail resource.
local ADDON, ns = ...
WildResourcesDB = WildResourcesDB or {}
local DB = WildResourcesDB
local DEFAULTS = {
    enabled = true, cooldowns = true, locked = true, combatOnly = false,
    scale = 1, x = 0, y = -170, showPower = {}, maxIcons = 24,
}
local function InitDB()
    for k, v in pairs(DEFAULTS) do if DB[k] == nil then DB[k] = type(v) == "table" and {} or v end end
    if type(DB.showPower) ~= "table" then DB.showPower = {} end
    DB.scale = math.max(0.65, math.min(1.6, tonumber(DB.scale) or 1))
    DB.maxIcons = math.max(8, math.min(40, tonumber(DB.maxIcons) or 24))
    DB.x, DB.y = tonumber(DB.x) or 0, tonumber(DB.y) or -170
end
local function SafeNumber(v)
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end
local function PowerName(id)
    local enum = Enum and Enum.PowerType
    if enum then
        for name, value in pairs(enum) do
            if value == id and type(name) == "string" then
                return name:gsub("^.*_", ""):gsub("(%l)(%u)", "%1 %2")
            end
        end
    end
    for name, value in pairs(_G) do
        if type(name) == "string" and type(value) == "number" and value == id and name:match("^SPELL_POWER_") then
            return name:gsub("^SPELL_POWER_", ""):gsub("_", " "):lower():gsub("(%a)([%w']*)", function(a,b) return a:upper()..b end)
        end
    end
    return "Power "..id
end
local POWER_COLORS = {
    [0]={0.05,0.35,0.90}, [1]={0.85,0.12,0.12}, [2]={0.95,0.55,0.15}, [3]={0.95,0.85,0.10},
    [4]={0.90,0.25,0.55}, [5]={0.45,0.55,0.80}, [6]={0.15,0.55,0.95}, [7]={0.55,0.45,0.75},
    [8]={0.30,0.55,0.90}, [9]={0.95,0.85,0.15}, [11]={0.15,0.75,0.95}, [12]={0.15,0.85,0.65},
    [13]={0.55,0.25,0.85}, [16]={0.25,0.75,0.95},
}
local root, resourceRows, spellIcons, specLabel, powerOptionsPanel
local currentPowers, knownSpells = {}, {}
local cachedSpecText, lastSpecRead = nil, 0
local RefreshPowerOptions
local BAR_W, BAR_H, ICON, GAP = 236, 17, 32, 5
local function PlayerSpec()
    local className, classToken = UnitClass("player")
    local spec
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and index then
            local ok2, id, name = pcall(C_SpecializationInfo.GetSpecializationInfo, index)
            if ok2 then spec = name end
        end
    end
    if not spec and GetSpecialization then
        local ok, index = pcall(GetSpecialization)
        if ok and index and GetSpecializationInfo then
            local ok2, _, name = pcall(GetSpecializationInfo, index)
            if ok2 then spec = name end
        end
    end
    if not spec then
        local active = type(GetActiveTalentGroup) == "function" and GetActiveTalentGroup() or nil
        if type(GetNumTalentTabs) == "function" and type(GetTalentTabInfo) == "function" then
            local best, points
            for tab=1,(GetNumTalentTabs() or 0) do
                local name, _, spent = GetTalentTabInfo(tab, false, false, active)
                spent = SafeNumber(spent) or 0
                if name and (not points or spent > points) then best, points = name, spent end
            end
            spec = best
        end
        if not spec and active then spec = "Talent Group "..active end
    end
    -- Forever-specific spec APIs are not assumed. If present, use only a readable string.
    for _, api in ipairs({"GetActiveChrSpec", "GetActiveSpec"}) do
        if not spec and type(_G[api]) == "function" then
            local ok, value = pcall(_G[api])
            if ok and type(value) == "string" and value ~= "" then spec = value end
        end
    end
    return className or classToken or "Unknown", classToken or "UNKNOWN", spec or "Specialization not exposed"
end
local function CreateBar(id)
    local bar = CreateFrame("StatusBar", nil, root)
    bar:SetSize(BAR_W, BAR_H)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.03,0.03,0.03,0.88)
    bar.bg = bg
    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", 5, 0); label:SetJustifyH("LEFT")
    local value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", -5, 0); value:SetJustifyH("RIGHT")
    bar.label, bar.valueText, bar.powerID = label, value, id
    return bar
end
local function ScanPowers()
    local found, candidates = {}, {}
    for id=0,40 do candidates[id]=true end
    local enum = Enum and Enum.PowerType
    if enum then
        for _,id in pairs(enum) do
            id=SafeNumber(id)
            if id and id>=0 and id<=128 and id%1==0 then candidates[id]=true end
        end
    end
    for name,id in pairs(_G) do
        if type(name)=="string" and name:match("^SPELL_POWER_") and type(id)=="number"
            and id>=0 and id<=128 and id%1==0 then candidates[id]=true end
    end
    for id in pairs(candidates) do
        if type(UnitPowerMax) == "function" then
            local ok, maximum = pcall(UnitPowerMax, "player", id)
            maximum = ok and SafeNumber(maximum) or nil
            if maximum and maximum > 0 then found[#found+1] = id end
        end
    end
    -- Older Wrath clients expose rune cooldowns separately from UnitPower.
    if type(GetRuneCount) == "function" then
        local ok, count = pcall(GetRuneCount)
        if ok and SafeNumber(count) and count > 0 then
            local seen = false
            for _,id in ipairs(found) do if id == 5 then seen=true end end
            if not seen then found[#found+1] = 5 end
        end
    end
    table.sort(found)
    return found
end
local function SpellBookEntries()
    local out, seen = {}, {}
    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function" or type(GetSpellBookItemInfo) ~= "function" then return out end
    for tab=1,(GetNumSpellTabs() or 0) do
        local _, _, offset, count = GetSpellTabInfo(tab)
        offset, count = tonumber(offset) or 0, tonumber(count) or 0
        for slot=offset+1,offset+count do
            local ok, kind, id = pcall(GetSpellBookItemInfo, slot, BOOKTYPE_SPELL)
            if ok and kind == "SPELL" and SafeNumber(id) and not seen[id] then
                local passive = false
                if type(IsPassiveSpell) == "function" then
                    local pOk, p = pcall(IsPassiveSpell, slot, BOOKTYPE_SPELL); passive = pOk and p or false
                end
                local name, _, texture
                if type(GetSpellBookItemName) == "function" then name = GetSpellBookItemName(slot, BOOKTYPE_SPELL) end
                if C_Spell and C_Spell.GetSpellInfo then
                    local info = C_Spell.GetSpellInfo(id)
                    if info then name, texture = info.name or name, info.iconID or info.icon end
                end
                if not texture and type(GetSpellTexture) == "function" then texture = GetSpellTexture(id) end
                local baseCooldown
                if type(GetSpellBaseCooldown)=="function" then
                    local cdOK,ms=pcall(GetSpellBaseCooldown,id)
                    if cdOK then baseCooldown=SafeNumber(ms) end
                end
                if not passive and name and texture and (baseCooldown==nil or baseCooldown>1500) then
                    seen[id]=true
                    out[#out+1] = { id=id, name=name, texture=texture }
                end
            end
        end
    end
    table.sort(out,function(a,b) return a.id < b.id end)
    return out
end
local function SetPosition()
    root:ClearAllPoints(); root:SetPoint("CENTER", UIParent, "CENTER", DB.x, DB.y)
end
local function SetScale()
    root:SetScale(DB.scale)
end
local function Layout()
    local y=-48
    for _,id in ipairs(currentPowers) do
        local row=resourceRows[id]
        if not row then row=CreateBar(id); resourceRows[id]=row end
        if DB.showPower[id] ~= false then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",root,"TOPLEFT",14,y)
            y=y-BAR_H-GAP
            row:Show()
        else
            row:Hide()
        end
    end
    local x=14
    local shown=0
    for i,entry in ipairs(knownSpells) do
        if not DB.cooldowns or i>DB.maxIcons then break end
        shown=i
        local button=spellIcons[i]
        if not button then
            button=CreateFrame("Frame",nil,root)
            button:SetSize(ICON,ICON)
            button.tex=button:CreateTexture(nil,"ARTWORK"); button.tex:SetAllPoints()
            button.tex:SetTexCoord(.08,.92,.08,.92)
            button.cd=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
            button.cd:SetAllPoints(); button.cd:SetDrawEdge(true)
            button:SetScript("OnEnter",function(self)
                if self.spellID then GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetSpellByID(self.spellID); GameTooltip:Show() end
            end)
            button:SetScript("OnLeave",GameTooltip_Hide)
            spellIcons[i]=button
        end
        button.spellID=entry.id; button.tex:SetTexture(entry.texture)
        button:ClearAllPoints(); button:SetPoint("TOPLEFT",root,"TOPLEFT",x,y-4)
        x=x+ICON+GAP
        if x+ICON>BAR_W+28 then x=14; y=y-ICON-GAP end
        button:Show()
    end
    for i=shown+1,#spellIcons do if spellIcons[i] then spellIcons[i]:Hide() end end
    local bottom=math.abs(y)+ICON+10
    root:SetSize(BAR_W+28, math.max(90,bottom+8))
end
local function RefreshPowerList()
    local fresh=ScanPowers()
    local changed=#fresh~=#currentPowers
    if not changed then for i,id in ipairs(fresh) do if currentPowers[i]~=id then changed=true; break end end end
    currentPowers=fresh
    if changed then Layout(); if RefreshPowerOptions then RefreshPowerOptions() end end
end
local function Refresh()
    if not root then return end
    local now=GetTime()
    if not cachedSpecText or now-lastSpecRead>=1 then
        local class,_,spec=PlayerSpec()
        cachedSpecText=class.."  |cffbbbbbb"..spec.."|r"
        lastSpecRead=now
        specLabel:SetText(cachedSpecText)
    end
    for _,id in ipairs(currentPowers) do
        local row=resourceRows[id]
        if row then
            local ok,v=pcall(UnitPower,"player",id)
            local okm,m=pcall(UnitPowerMax,"player",id)
            v=ok and SafeNumber(v) or 0; m=okm and SafeNumber(m) or 0
            if id==5 and type(GetRuneCooldown)=="function" then
                local ready,total=0,0
                for rune=1,6 do
                    local runeOK,_,_,isReady=pcall(GetRuneCooldown,rune)
                    if runeOK then total=total+1; if isReady then ready=ready+1 end end
                end
                if total>0 then v,m=ready,total end
            end
            row:SetMinMaxValues(0,math.max(1,m)); row:SetValue(math.max(0,v))
            local pname=PowerName(id)
            local color=(PowerBarColor and (PowerBarColor[id] or PowerBarColor[pname])) or POWER_COLORS[id] or {.35,.7,.95}
            row:SetStatusBarColor(color.r or color[1] or .35,color.g or color[2] or .7,color.b or color[3] or .95,1)
            row.label:SetText((id==5 and type(GetRuneCount)=="function") and "Runes" or pname)
            row.valueText:SetText(("%d / %d"):format(v,m))
            row:SetShown(DB.enabled and DB.showPower[id] ~= false)
        end
    end
    for _,button in ipairs(spellIcons) do
        if button:IsShown() and button.spellID then
            local start,duration,enabled
            if C_Spell and C_Spell.GetSpellCooldown then
                local info=C_Spell.GetSpellCooldown(button.spellID)
                if info then start,duration,enabled=info.startTime,info.duration,info.isEnabled end
            elseif GetSpellCooldown then start,duration,enabled=GetSpellCooldown(button.spellID) end
            start,duration=SafeNumber(start),SafeNumber(duration)
            enabled=SafeNumber(enabled)
            if start and duration and duration>0 and enabled~=0 then button.cd:SetCooldown(start,duration) else button.cd:Clear() end
        end
    end
    root:SetShown(DB.enabled and (not DB.combatOnly or UnitAffectingCombat("player")))
end
local function RebuildSpells()
    knownSpells=SpellBookEntries()
    RefreshPowerList()
    Layout(); Refresh()
end
local function MakeRoot()
    root=CreateFrame("Frame","WildResourcesTracker",UIParent,BackdropTemplateMixin and "BackdropTemplate" or nil)
    root:SetFrameStrata("MEDIUM"); root:SetClampedToScreen(true); root:SetMovable(true); root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    if root.SetBackdrop then root:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}) end
    root:SetScript("OnDragStart",function(self) if not DB.locked then self:StartMoving() end end)
    root:EnableMouse(not DB.locked)
    root:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local _,_,_,x,y=self:GetPoint(1); DB.x,DB.y=x or 0,y or -170
    end)
    local title=root:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",12,-8); title:SetText("WildResources")
    specLabel=root:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    specLabel:SetPoint("TOPLEFT",12,-26)
    root.title=title
    resourceRows={}; spellIcons={}
    SetPosition(); SetScale()
end
local function ToggleTracker()
    if root then root:SetShown(not root:IsShown()) end
end
local function Check(parent,label,key,callback)
    local b=CreateFrame("CheckButton",nil,parent,"InterfaceOptionsCheckButtonTemplate")
    b.Text:SetText(label); b:SetChecked(DB[key])
    b:SetScript("OnClick",function(self) DB[key]=self:GetChecked(); callback() end)
    return b
end
RefreshPowerOptions=function()
    if not powerOptionsPanel then return end
    for _,child in ipairs({powerOptionsPanel:GetChildren()}) do child:Hide() end
    local col,row=0,0
    for _,id in ipairs(currentPowers) do
        local b=CreateFrame("CheckButton",nil,powerOptionsPanel,"InterfaceOptionsCheckButtonTemplate")
        b.Text:SetText(PowerName(id).." ("..id..")")
        b:SetChecked(DB.showPower[id]~=false)
        b:SetScript("OnClick",function(self)
            DB.showPower[id]=self:GetChecked()
            Layout(); Refresh()
        end)
        b:SetPoint("TOPLEFT",col*190,-row*24)
        col=col+1
        if col>=3 then col,row=0,row+1 end
    end
end
local function OpenOptions()
    if not Settings or not Settings.OpenToCategory then ToggleTracker(); return end
    if WildResourcesCategory and WildResourcesCategory.GetID then pcall(Settings.OpenToCategory,WildResourcesCategory:GetID()) else ToggleTracker() end
end
local function RegisterOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel=CreateFrame("Frame",nil,UIParent)
    local heading=panel:CreateFontString(nil,"ARTWORK","GameFontNormalLarge")
    heading:SetPoint("TOPLEFT",16,-16); heading:SetText("WildResources")
    local note=panel:CreateFontString(nil,"ARTWORK","GameFontHighlight")
    note:SetPoint("TOPLEFT",16,-42); note:SetText("Live client power detection and learned spell cooldowns. Unknown power IDs are labeled numerically.")
    local enable=Check(panel,"Enable tracker","enabled",Refresh); enable:SetPoint("TOPLEFT",16,-72)
    local cds=Check(panel,"Show learned spell cooldown icons","cooldowns",function()
        if root then root:Show(); Refresh() end
    end); cds:SetPoint("TOPLEFT",16,-102)
    local combat=Check(panel,"Show only while in combat","combatOnly",Refresh); combat:SetPoint("TOPLEFT",16,-132)
    local lock=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    lock:SetSize(170,24); lock:SetPoint("TOPLEFT",16,-170); lock:SetText(DB.locked and "Unlock tracker" or "Lock tracker")
    lock:SetScript("OnClick",function()
        DB.locked=not DB.locked
        if root then root:EnableMouse(not DB.locked) end
        lock:SetText(DB.locked and "Unlock tracker" or "Lock tracker")
    end)
    local reset=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    reset:SetSize(170,24); reset:SetPoint("LEFT",lock,"RIGHT",8,0); reset:SetText("Reset position")
    reset:SetScript("OnClick",function() DB.x,DB.y=0,-170; SetPosition() end)
    local refresh=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    refresh:SetSize(170,24); refresh:SetPoint("TOPLEFT",16,-204); refresh:SetText("Rescan spells and powers")
    refresh:SetScript("OnClick",RebuildSpells)
    local smaller=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    smaller:SetSize(78,24); smaller:SetPoint("LEFT",refresh,"RIGHT",8,0); smaller:SetText("Scale -")
    smaller:SetScript("OnClick",function() DB.scale=math.max(.65,DB.scale-.1); SetScale() end)
    local larger=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    larger:SetSize(78,24); larger:SetPoint("LEFT",smaller,"RIGHT",4,0); larger:SetText("Scale +")
    larger:SetScript("OnClick",function() DB.scale=math.min(1.6,DB.scale+.1); SetScale() end)
    local powerTitle=panel:CreateFontString(nil,"ARTWORK","GameFontNormal")
    powerTitle:SetPoint("TOPLEFT",16,-244); powerTitle:SetText("Show detected resources")
    powerOptionsPanel=CreateFrame("Frame",nil,panel)
    powerOptionsPanel:SetPoint("TOPLEFT",16,-264); powerOptionsPanel:SetSize(520,150)
    RefreshPowerOptions()
    local ok,cat=pcall(Settings.RegisterCanvasLayoutCategory,panel,"WildResources")
    if ok and cat then pcall(Settings.RegisterAddOnCategory,cat); WildResourcesCategory=cat end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
local function Reg(ev) pcall(events.RegisterEvent,events,ev) end
for _,ev in ipairs({"PLAYER_ENTERING_WORLD","UNIT_POWER_UPDATE","UNIT_MAXPOWER","UNIT_DISPLAYPOWER","UPDATE_SHAPESHIFT_FORM","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED","TRAIT_NODE_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","SPELL_UPDATE_COOLDOWN","SPELL_UPDATE_CHARGES","RUNE_POWER_UPDATE","RUNE_TYPE_UPDATE","UNIT_SPELLCAST_SUCCEEDED"}) do Reg(ev) end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_LOGIN" then
        InitDB(); MakeRoot(); RegisterOptions(); RebuildSpells()
        root:SetShown(DB.enabled)
        events:SetScript("OnUpdate",function(_,elapsed)
            events.elapsed=(events.elapsed or 0)+elapsed
            events.scanElapsed=(events.scanElapsed or 0)+elapsed
            if events.scanElapsed>=2 then events.scanElapsed=0; RefreshPowerList() end
            if events.elapsed>=0.20 then events.elapsed=0; Refresh() end
        end)
    elseif unit==nil or unit=="player" then
        if event=="SPELLS_CHANGED" or event=="PLAYER_TALENT_UPDATE" or event=="ACTIVE_TALENT_GROUP_CHANGED" or event=="PLAYER_SPECIALIZATION_CHANGED" or event=="TRAIT_CONFIG_UPDATED" then RebuildSpells()
        else
            if event=="PLAYER_ENTERING_WORLD" or event=="UNIT_DISPLAYPOWER" or event=="UPDATE_SHAPESHIFT_FORM" or event=="RUNE_TYPE_UPDATE" then RefreshPowerList() end
            Refresh()
        end
    end
end)
SLASH_WILDRESOURCES1="/wildresources"
SLASH_WILDRESOURCES2="/wr"
SlashCmdList.WILDRESOURCES=function(msg)
    msg=(msg or ""):lower()
    if msg=="unlock" then DB.locked=false; if root then root:EnableMouse(true) end; print("WildResources: tracker unlocked; drag it to move.")
    elseif msg=="lock" then DB.locked=true; if root then root:EnableMouse(false) end; print("WildResources: tracker locked.")
    elseif msg=="options" then OpenOptions()
    else ToggleTracker() end
end
