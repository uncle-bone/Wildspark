-- WildBuffs caster details.
-- Adapted from NewBuffWhoDis v1.0.0 by DairyManilow, with permission.
-- Original MIT license and copyright notice: CasterInfo-LICENSE.txt.
local API = {}
_G.WildBuffsCasterInfo = API

local PREFIX = "|cff66ccffWildBuffs|r: "
local debugMode = false
local stats = { callbacks = 0, methods = 0, tooltip = 0, matched = 0, shown = 0, captured = 0, missing = 0, ambiguous = 0 }
local cache = {} -- auraInstanceID -> { spellID, name, class }
local lastSpell
local hookInstalled = false
local hookedMethods = {}

local function Say(message)
	print(PREFIX .. message)
end

local function Safe(value)
	if type(issecretvalue) == "function" then
		local ok, secret = pcall(issecretvalue, value)
		if not ok or secret then return false end
	end
	return true
end

local function Field(data, key)
	if not Safe(data) then return nil end
	local ok, value = pcall(function() return data[key] end)
	if ok and Safe(value) then return value end
end

local function Debug(message)
	if debugMode then Say(message) end
end

local function AuraByIndex(index, filter)
	if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then return nil end
	local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, filter)
	if ok and Safe(aura) then return aura end
end

local function Caster(aura)
	local token = Field(aura, "sourceUnit")
	if type(token) ~= "string" or token == "" then return nil end
	if type(UnitExists) == "function" then
		local ok, exists = pcall(UnitExists, token)
		if not ok or not Safe(exists) or not exists then return nil end
	end
	local ok, name, realm = pcall(UnitName, token)
	if not ok or not Safe(name) or type(name) ~= "string" or name == "" then return nil end
	if Safe(realm) and type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
	local class
	if type(UnitClass) == "function" then
		local success, _, classToken = pcall(UnitClass, token)
		if success and Safe(classToken) and type(classToken) == "string" then class = classToken end
	end
	return { name = name, class = class }
end

local function Capture(aura)
	local instance = Field(aura, "auraInstanceID")
	local spell = Field(aura, "spellId")
	if type(instance) ~= "number" or type(spell) ~= "number" then return nil end
	local person = Caster(aura)
	if person then
		local old = cache[instance]
		if not old or old.spellID ~= spell or old.name ~= person.name then
			stats.captured = stats.captured + 1
			Debug("Captured " .. person.name .. " for spell " .. spell)
		end
		cache[instance] = { spellID = spell, name = person.name, class = person.class }
		return cache[instance]
	end
	local old = cache[instance]
	if old and old.spellID == spell then return old end
end

local function Scan()
	local active = {}
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for index = 1, 255 do
			local aura = AuraByIndex(index, filter)
			if not aura then break end
			local instance = Field(aura, "auraInstanceID")
			local spell = Field(aura, "spellId")
			if type(instance) == "number" and type(spell) == "number" then
				active[instance] = spell
				Capture(aura)
			end
		end
	end
	for instance, entry in pairs(cache) do
		if active[instance] ~= entry.spellID then cache[instance] = nil end
	end
end

local function Matching(spell)
	local found
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for index = 1, 255 do
			local aura = AuraByIndex(index, filter)
			if not aura then break end
			if Field(aura, "spellId") == spell then
				if found then return nil, "ambiguous" end
				found = aura
			end
		end
	end
	return found, found and "found" or "missing"
end

local function ShowCaster(tooltip, person)
	local line = "Cast by: " .. person.name
	local ok, count = pcall(tooltip.NumLines, tooltip)
	local tooltipName = tooltip.GetName and tooltip:GetName()
	local lastLine = ok and tooltipName and _G[tooltipName .. "TextLeft" .. count]
	if lastLine then
		local textOK, text = pcall(lastLine.GetText, lastLine)
		if textOK and Safe(text) and text == line then return end
	end
	local color = RAID_CLASS_COLORS and person.class and RAID_CLASS_COLORS[person.class]
	tooltip:AddLine(line, color and color.r or 0.35, color and color.g or 0.95, color and color.b or 0.45)
	stats.shown = stats.shown + 1
end

local function ProcessAuraTooltip(tooltip, data)
	stats.callbacks = stats.callbacks + 1
	if tooltip ~= GameTooltip or not Safe(data) then return end
	local spell = Field(data, "id")
	if type(spell) ~= "number" then spell = Field(data, "spellID") end
	if type(spell) ~= "number" then return end
	lastSpell = spell
	stats.tooltip = stats.tooltip + 1
	local aura, reason = Matching(spell)
	if not aura then
		if reason == "ambiguous" then stats.ambiguous = stats.ambiguous + 1 end
		return
	end
	stats.matched = stats.matched + 1
	local instance = Field(aura, "auraInstanceID")
	local person = Capture(aura)
	if not person and type(instance) == "number" then
		local prior = cache[instance]
		if prior and prior.spellID == spell then person = prior end
	end
	if person then
		ShowCaster(tooltip, person)
	else
		stats.missing = stats.missing + 1
		Debug("Spell " .. spell .. ": caster is not available or cached")
	end
end

local function InstallTooltipHook()
	if hookInstalled then return true end
	local processor = TooltipDataProcessor
	local auraType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.UnitAura
	if not processor or type(processor.AddTooltipPostCall) ~= "function" or auraType == nil then return false end
	local ok = pcall(processor.AddTooltipPostCall, auraType, ProcessAuraTooltip)
	hookInstalled = ok
	return hookInstalled
end

local function ProcessAuraMethod(method, tooltip, unit, index, filter)
	stats.methods = stats.methods + 1
	if tooltip ~= GameTooltip or type(unit) ~= "string" or not UnitIsUnit then return end
	local unitOK, isPlayer = pcall(UnitIsUnit, unit, "player")
	if not unitOK or not Safe(isPlayer) or not isPlayer then return end
	local api = C_UnitAuras
	if not api then return end
	local getter
	if method == "SetUnitAura" then getter = api.GetAuraDataByIndex
	elseif method == "SetUnitBuff" then getter = api.GetBuffDataByIndex or api.GetAuraDataByIndex
	elseif method == "SetUnitDebuff" then getter = api.GetDebuffDataByIndex or api.GetAuraDataByIndex
	elseif method == "SetUnitAuraByAuraInstanceID" or method == "SetUnitBuffByAuraInstanceID" or method == "SetUnitDebuffByAuraInstanceID" then
		getter = api.GetAuraDataByAuraInstanceID
	end
	if type(getter) ~= "function" then return end
	local ok, aura
	if method:find("ByAuraInstanceID", 1, true) then ok, aura = pcall(getter, unit, index)
	else ok, aura = pcall(getter, unit, index, filter) end
	if not ok or not Safe(aura) then return end
	local instance = Field(aura, "auraInstanceID")
	local spell = Field(aura, "spellId")
	if type(instance) ~= "number" or type(spell) ~= "number" then return end
	local person = Capture(aura) or cache[instance]
	if person and person.spellID == spell then
		stats.matched = stats.matched + 1
		lastSpell = spell
		ShowCaster(tooltip, person)
	end
end

local function InstallAuraMethodHooks()
	if not GameTooltip or type(hooksecurefunc) ~= "function" then return end
	for _, method in ipairs({ "SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetUnitAuraByAuraInstanceID", "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID" }) do
		if not hookedMethods[method] and type(GameTooltip[method]) == "function" then
			local currentMethod = method
			local ok = pcall(hooksecurefunc, GameTooltip, method, function(tooltip, unit, index, filter)
				ProcessAuraMethod(currentMethod, tooltip, unit, index, filter)
			end)
			if ok then hookedMethods[method] = true end
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, unit)
	InstallTooltipHook()
	InstallAuraMethodHooks()
	if event == "PLAYER_ENTERING_WORLD" then
		cache = {}
		Scan()
	elseif event == "UNIT_AURA" and unit == "player" then
		Scan()
	end
end)
InstallTooltipHook()
InstallAuraMethodHooks()

function API.Command(input)
	input = (input or ""):lower():match("^%s*(.-)%s*$")
	if input == "debug" then
		debugMode = not debugMode
		Say("Caster diagnostics " .. (debugMode and "ON" or "OFF"))
	elseif input == "status" then
		local count = 0
		for _ in pairs(cache) do count = count + 1 end
		local methodCount = 0
		for _ in pairs(hookedMethods) do methodCount = methodCount + 1 end
		Say(("Caster details | hook=%s methodHooks=%d methodCalls=%d callbacks=%d tooltips=%d matched=%d shown=%d captured=%d cached=%d missing=%d ambiguous=%d")
			:format(hookInstalled and "ready" or "waiting", methodCount, stats.methods, stats.callbacks, stats.tooltip, stats.matched, stats.shown, stats.captured, count, stats.missing, stats.ambiguous))
	elseif input == "scan" then
		Scan()
		Say("Scanned active buffs and debuffs.")
	elseif input == "last" then
		Say("Last tooltip spell ID: " .. tostring(lastSpell))
	else
		Say("Commands: /wildbuffs caster status | debug | scan | last")
	end
end
