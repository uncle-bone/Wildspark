local _, addonTable = ...

local WildLayer = _G.WildLayer
local detector = CreateFrame("Frame")
local minimapLabel

-- Forever exposes a stable-within-session zoneUID in creature/vehicle GUIDs. It is useful
-- as a local layer fingerprint, but Blizzard explicitly obfuscates other GUID fields and this
-- value is not a verified, globally numbered server layer. Keep the label honest about that.
local function getGuidLayerID(unit)
	if not UnitExists(unit) then
		return nil
	end

	local ok, guid = pcall(UnitGUID, unit)
	if not ok or type(guid) ~= "string" then
		return nil
	end

	local unitType, zoneUID = guid:match("^([^-]+)%-[^%-]*%-[^%-]*%-[^%-]*%-([^%-]+)%-")
	if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "GameObject" then
		return nil
	end
	if not zoneUID or zoneUID == "" or zoneUID == "0" then
		return nil
	end
	return zoneUID
end

local function getMapContext()
	local mapID
	if C_Map and C_Map.GetBestMapForUnit then
		local ok, result = pcall(C_Map.GetBestMapForUnit, "player")
		if ok then
			mapID = result
		end
	end
	local mapInfo
	if mapID and C_Map and C_Map.GetMapInfo then
		local ok, result = pcall(C_Map.GetMapInfo, mapID)
		if ok then
			mapInfo = result
		end
	end
	return mapID, mapInfo and mapInfo.name
end

local function refreshLabel()
	if not minimapLabel then
		return
	end

	local officialLayer = tonumber(_G.NWB_CurrentLayer)
	if officialLayer and officialLayer > 0 then
		minimapLabel:SetText("Layer " .. officialLayer)
		minimapLabel:SetTextColor(0.3, 1, 0.3)
	else
		local observation = addonTable.layerObservation
		if observation then
			minimapLabel:SetText("ID " .. observation.id)
			minimapLabel:SetTextColor(1, 0.82, 0.2)
		else
			minimapLabel:SetText("Layer ?")
			minimapLabel:SetTextColor(0.85, 0.85, 0.85)
		end
	end

	if addonTable.bunnyLDB then
		addonTable.bunnyLDB.text = minimapLabel:GetText()
	end
end

function WildLayer:ObserveLayerUnit(unit)
	local ok, id = pcall(getGuidLayerID, unit)
	if not ok then
		return false
	end
	if not id then
		return false
	end

	local mapID, zoneName = getMapContext()
	local nameOK, unitName = pcall(UnitName, unit)
	addonTable.layerObservation = {
		id = id,
		mapID = mapID,
		zoneName = zoneName or GetZoneText() or "Unknown zone",
		unitName = nameOK and unitName or "NPC",
		seenAt = GetServerTime and GetServerTime() or time(),
	}
	refreshLabel()
	return true
end

local function sampleVisibleUnits()
	if WildLayer:ObserveLayerUnit("target") or WildLayer:ObserveLayerUnit("mouseover") then
		return
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, plates = pcall(C_NamePlate.GetNamePlates)
		if ok and type(plates) == "table" then
			for _, plate in ipairs(plates) do
				local unit = plate and plate.namePlateUnitToken
				if unit and WildLayer:ObserveLayerUnit(unit) then
					break
				end
			end
		end
	end
end

local function clearZoneObservation()
	addonTable.layerObservation = nil
	refreshLabel()
	C_Timer.After(0.5, sampleVisibleUnits)
end

detector:RegisterEvent("PLAYER_LOGIN")
detector:RegisterEvent("PLAYER_TARGET_CHANGED")
detector:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
detector:RegisterEvent("NAME_PLATE_UNIT_ADDED")
detector:RegisterEvent("ZONE_CHANGED_NEW_AREA")
detector:RegisterEvent("PLAYER_ENTERING_WORLD")
detector:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_LOGIN" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
		clearZoneObservation()
		return
	end
	if event == "NAME_PLATE_UNIT_ADDED" then
		WildLayer:ObserveLayerUnit(unit)
		return
	end
	if event == "PLAYER_TARGET_CHANGED" then
		WildLayer:ObserveLayerUnit("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		WildLayer:ObserveLayerUnit("mouseover")
	end
end)

C_Timer.NewTicker(1, refreshLabel)

if Minimap then
	local holder = CreateFrame("Frame", "WildLayerObservedLayerLabel", UIParent)
	holder:SetSize(120, 14)
	holder:SetFrameStrata("MEDIUM")
	holder:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	holder:EnableMouse(false)
	minimapLabel = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	minimapLabel:SetPoint("TOP", Minimap, "BOTTOM", 0, -2)
	minimapLabel:SetWidth(120)
	minimapLabel:SetJustifyH("CENTER")
	minimapLabel:SetShadowColor(0, 0, 0, 1)
	minimapLabel:SetShadowOffset(1, -1)
	refreshLabel()
end

addonTable.layerDetector = {
	getGuidLayerID = getGuidLayerID,
	refreshLabel = refreshLabel,
}
