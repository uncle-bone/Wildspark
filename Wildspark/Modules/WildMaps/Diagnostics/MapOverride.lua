local _, addonNS = ...
local HM = addonNS.WildMaps

HM.MapOverride = HM.MapOverride or {}
local MapOverride = HM.MapOverride

local DEFAULT_DURATION_MINUTES = 30
local MAX_DURATION_MINUTES = 120
local originalRefreshMap = HM.RefreshMap

local shortcuts = {
    bfd = "blackfathom_deeps",
    bfda = "blackfathom_deeps_approach",
    rfda = "razorfen_downs_approach",
    sta = "sunken_temple_approach",
    ulda = "uldaman_approach",
    brd = "blackrock_depths",
    brm = "blackrock_mountain_interior",
    lbrs = "lower_blackrock_spire",
    ubrs = "upper_blackrock_spire",
    rfc = "ragefire_chasm",
    rfd = "razorfen_downs",
    rfk = "razorfen_kraul",
    sfk = "shadowfang_keep",
    zf = "zul_farrak",
    wc = "wailing_caverns_instance",
    wcwmo = "wailing_caverns_instance_legacy",
    wca = "wailing_caverns_approach",
    dmext = "dire_maul_exterior",
    maraap = "maraudon_approach",
    gnomap = "gnomeregan_approach",
    deadminesap = "deadmines_approach",
}

local function normalize(text)
    if HM.Registry and HM.Registry.Normalize then
        return HM.Registry.Normalize(text or "")
    end

    text = string.lower(text or "")
    text = string.gsub(text, "[%s%p]", "")
    return text
end

local function trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function now()
    return GetTime and GetTime() or 0
end

local function remainingMinutes()
    if not MapOverride.active or not MapOverride.expiresAt then
        return nil
    end
    return math.max(0, (MapOverride.expiresAt - now()) / 60)
end

function MapOverride:IsActive()
    return self.active ~= nil
end

function MapOverride:IsExpired()
    return self.active and self.expiresAt and now() >= self.expiresAt
end

function MapOverride:Apply(map, minutes)
    minutes = tonumber(minutes) or DEFAULT_DURATION_MINUTES
    if minutes < 1 then
        minutes = 1
    elseif minutes > MAX_DURATION_MINUTES then
        minutes = MAX_DURATION_MINUTES
    end

    self.active = {
        map = map,
        startedAt = now(),
        durationMinutes = minutes,
    }
    self.expiresAt = self.active.startedAt + minutes * 60

    HM.currentMap = map
    HM.WorldMap:SetMap(map)

    -- WC's old WMO/current-area implementation is archived and normally
    -- dormant. It is activated only when the hidden legacy map is forced.
    if HM.Experiments and HM.Experiments.WCCurrentArea then
        HM.Experiments.WCCurrentArea.enabled = (map.id == "wailing_caverns_instance_legacy")
        if HM.Experiments.WCCurrentArea.enabled and HM.Experiments.WCCurrentArea.Refresh then
            HM.Experiments.WCCurrentArea:Refresh(true)
        end
    end

    HM:Print(
        "diagnostic map override ON ->",
        map.id,
        "(" .. map.name .. ")",
        string.format("for %d min; clears on new area/instance, /reload, timeout, or /wmmap off", minutes)
    )
end

function MapOverride:Clear(reason, refreshRealMap)
    if not self.active then
        return false
    end

    local previous = self.active.map
    self.active = nil
    self.expiresAt = nil

    if HM.Experiments and HM.Experiments.WCCurrentArea then
        HM.Experiments.WCCurrentArea.enabled = false
        if HM.Experiments.WCCurrentArea.Hide then
            HM.Experiments.WCCurrentArea:Hide()
        end
    end

    HM:Print(
        "diagnostic map override OFF ->",
        previous and previous.id or "<unknown>",
        reason and ("(" .. reason .. ")") or ""
    )

    if refreshRealMap ~= false and originalRefreshMap then
        originalRefreshMap(HM, "diagnostic override cleared")
    end

    return true
end

local function collectMatches(query)
    local direct = HM.Registry:GetMap(query)
    if direct then
        return { direct }
    end

    local shortcutID = shortcuts[string.lower(query)]
    if shortcutID then
        local shortcutMap = HM.Registry:GetMap(shortcutID)
        if shortcutMap then
            return { shortcutMap }
        end
    end

    local needle = normalize(query)
    if needle == "" then
        return {}
    end

    local exact = {}
    local partial = {}

    for _, map in ipairs(HM.Registry:GetMaps()) do
        local candidates = { map.id, map.name }
        if map.detection and type(map.detection.zoneAliases) == "table" then
            for _, alias in ipairs(map.detection.zoneAliases) do
                candidates[#candidates + 1] = alias
            end
        end

        local isExact = false
        local isPartial = false
        for _, candidate in ipairs(candidates) do
            local value = normalize(candidate)
            if value == needle then
                isExact = true
                break
            elseif string.find(value, needle, 1, true) then
                isPartial = true
            end
        end

        if isExact then
            exact[#exact + 1] = map
        elseif isPartial then
            partial[#partial + 1] = map
        end
    end

    if #exact > 0 then
        return exact
    end
    return partial
end

function MapOverride:Resolve(query)
    local matches = collectMatches(query)
    if #matches == 1 then
        return matches[1]
    end
    return nil, matches
end

function MapOverride:List(filter)
    local needle = normalize(filter or "")
    HM:Print("diagnostic maps:")

    local count = 0
    for _, map in ipairs(HM.Registry:GetMaps()) do
        local haystack = normalize(map.id .. " " .. map.name)
        local visible = not map.hiddenDiagnostic or needle ~= ""
        if visible and (needle == "" or string.find(haystack, needle, 1, true)) then
            HM:Print("-", map.id, "-", map.name)
            count = count + 1
        end
    end

    if count == 0 then
        HM:Print("no maps matched filter", filter or "")
    end
end

function MapOverride:Status()
    if self.active then
        local left = remainingMinutes() or 0
        HM:Print(
            "diagnostic override:",
            self.active.map.id,
            "(" .. self.active.map.name .. ")",
            string.format("%.1f min remaining", left)
        )
    else
        HM:Print("diagnostic override: OFF")
    end

    if HM.Detection and HM.Detection.FindCurrentMap then
        local detected = HM.Detection:FindCurrentMap()
        HM:Print("live detector currently sees:", detected and detected.id or "<none>")
    end
end

local function showUsage()
    HM:Print("commands:")
    HM:Print("/wmmap <map id/name> [minutes] - temporarily force a map (default 30, max 120)")
    HM:Print("/wmmap off - return immediately to live detection")
    HM:Print("/wmmap status - show forced map and live detector result")
    HM:Print("/wmmap list [filter] - list available registered maps")
    HM:Print("examples: /wmmap rfc   /wmmap wca   /wmmap dire_maul_exterior 60")
end

function MapOverride:HandleSlash(message)
    message = trim(message)
    if message == "" then
        showUsage()
        return
    end

    local first, rest = message:match("^(%S+)%s*(.-)%s*$")
    local command = string.lower(first or "")

    if command == "off" or command == "clear" or command == "normal" then
        if not self:Clear("manual", true) then
            HM:Print("diagnostic override already OFF")
        end
        return
    end

    if command == "status" then
        self:Status()
        return
    end

    if command == "list" or command == "maps" then
        self:List(rest)
        return
    end

    local query = first
    local minutes = nil
    if rest ~= "" then
        local maybeMinutes = tonumber(rest)
        if not maybeMinutes then
            -- Permit multi-word map names. If the final token is numeric, treat
            -- it as the requested duration; otherwise the entire text is query.
            local namePart, durationPart = message:match("^(.-)%s+(%d+%.?%d*)%s*$")
            if namePart and durationPart then
                query = trim(namePart)
                minutes = tonumber(durationPart)
            else
                query = message
            end
        else
            minutes = maybeMinutes
        end
    end

    local map, matches = self:Resolve(query)
    if not map then
        if matches and #matches > 1 then
            HM:Print("map query is ambiguous:", query)
            for _, candidate in ipairs(matches) do
                HM:Print("-", candidate.id, "-", candidate.name)
            end
        else
            HM:Print("no registered map matched:", query)
            HM:Print("use /wmmap list or /wmmap list <filter>")
        end
        return
    end

    self:Apply(map, minutes)
end

-- Interpose only at runtime; no Core source file is modified. Core's Engine
-- continues calling HM:RefreshMap normally. While a diagnostic override is
-- active, minor zone/subzone refreshes keep the forced map. A true new-area or
-- world-entry transition clears it and immediately returns to live detection.
if originalRefreshMap then
    HM.RefreshMap = function(self, reason)
        if MapOverride:IsActive() then
            if reason == "PLAYER_ENTERING_WORLD" or reason == "ZONE_CHANGED_NEW_AREA" then
                MapOverride:Clear(reason, false)
                return originalRefreshMap(self, reason)
            end

            if MapOverride:IsExpired() then
                MapOverride:Clear("timeout", false)
                return originalRefreshMap(self, "diagnostic override timeout")
            end

            local map = MapOverride.active.map
            HM.currentMap = map
            HM.WorldMap:SetMap(map)
            return
        end

        return originalRefreshMap(self, reason)
    end
end

local timeoutFrame = CreateFrame("Frame")
local timeoutAccumulator = 0
timeoutFrame:SetScript("OnUpdate", function(_, elapsed)
    if not MapOverride:IsActive() then
        return
    end

    timeoutAccumulator = timeoutAccumulator + elapsed
    if timeoutAccumulator < 1.0 then
        return
    end
    timeoutAccumulator = 0

    if MapOverride:IsExpired() then
        MapOverride:Clear("timeout", true)
    end
end)

SLASH_WILDMAPSMAP1 = "/wmmap"
SLASH_WILDMAPSMAP2 = "/wildmapsmap"
SlashCmdList.WILDMAPSMAP = function(message)
    MapOverride:HandleSlash(message)
end
