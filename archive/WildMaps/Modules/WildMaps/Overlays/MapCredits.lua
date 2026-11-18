local _, addonNS = ...
local HM = addonNS.WildMaps

-- An opt-in footer for externally credited artwork. It never changes source
-- dimensions, tiles, crop data or shared approach padding. Font strings are
-- noninteractive children of the renderer and follow its visibility/UI scale.
HM.MapCredits = {}
local Credits = HM.MapCredits
local GAP = 6
local BOTTOM_MARGIN = 4

function Credits:Reserve(frame, map, availableWidth)
    local label = frame.artworkCredit
    if label then label:Hide() end
    local text = map and map.artworkCredit
    if type(text) ~= "string" or text == "" then return 0 end

    if not label then
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetJustifyH("CENTER")
        label:SetTextColor(1, 0.9, 0.7, 1)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        if label.SetWordWrap then label:SetWordWrap(true) end
        frame.artworkCredit = label
    end

    label:ClearAllPoints()
    label:SetWidth(math.max(1, availableWidth - 16))
    label:SetHeight(0) -- Re-measure wrapping after a resize without the old height cap.
    label:SetText(text)
    local height = math.max(12, label:GetStringHeight())
    label:SetHeight(height)
    label:SetPoint("TOP", frame, "BOTTOM", 0, -GAP)
    label:Show()
    return GAP + height + BOTTOM_MARGIN
end
