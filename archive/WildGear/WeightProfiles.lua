local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Stat weight profiles: named sets of stat weights for one class, spec and
-- weapon setup, saved for all characters, that rank items in place of the
-- default weights (the model's, by level: Weights.lua) while picked.
-- A profile is a snapshot: its weights are used as they are at every level
-- (one bracket, levels 1-60), whatever level it was made at. Only one
-- imported with brackets of its own changes with level: profiles have the
-- defaults' shape, brackets = { { upTo, stats }... }, the lowest level first.
--   WildGearDB.weightProfiles = { next = n (the next id's number),
--     sets = { ["CLASS:spec:setup"] = { picked = id (nil: the defaults),
--       list = { { id, name, icon, brackets }... } } } }
-- Setups a spec doesn't list (a lone one-hander) share its default setup's set.
-- A profile's icon is nil (its spec's), "spec:<key>" (another spec's) or a
-- texture file id from WP.ICONS. Off specs name a profile by its id
-- (Tooltip.lua), unique across all sets, so renaming one keeps them.
-- Shared as text (WP.Export, WP.Parse): our own string,
--   FLB1;WARRIOR;fury;dualwield;icon=132333;60:str=2,agi=1.01;Name
-- (options as key=value before the brackets, each bracket `upTo:key=value,...`,
-- separated by "/", the name last), and Pawn's scale tags,
--   ( Pawn: v1: "Name": Class=Warrior, Spec=Fury, Strength=2, ... ),
-- read and written by our own code (Pawn's is not ours to copy).

local WP = {}
ns.WeightProfiles = WP

local NAME_CHARS = 24 -- the longest name, in characters
local MAX_BRACKETS, MAX_STATS, MAX_VALUE = 20, 80, 100000

-- `v` as a weight we take: a finite number no bigger than MAX_VALUE, else nil.
local function Weight(v)
    v = tonumber(v)
    if v and v == v and math.abs(v) <= MAX_VALUE then return v end
end

---------------------------------------------------------------- storage

local function Store(create)
    local db = ns.db
    if not db then return nil end
    if create and not db.weightProfiles then db.weightProfiles = { next = 1, sets = {} } end
    return db.weightProfiles
end

-- The setup whose set holds class/spec/setup's profiles: `setup` when the
-- spec lists it, else the spec's default one.
local function SetupKey(classFile, spec, setup)
    local setups = ns.SpecSetups(classFile, spec)
    for _, s in ipairs(setups) do
        if s == setup then return setup end
    end
    return setups[1]
end
WP.SetupKey = SetupKey

function WP.Key(classFile, spec, setup)
    return classFile .. ":" .. spec .. ":" .. SetupKey(classFile, spec, setup)
end

local function Set(classFile, spec, setup, create)
    local store = Store(create)
    if not store then return nil end
    local key = WP.Key(classFile, spec, setup)
    if not store.sets[key] and create then store.sets[key] = { list = {} } end
    return store.sets[key]
end

local function Find(set, id)
    for i, p in ipairs(set and set.list or {}) do
        if p.id == id then return p, i end
    end
end

-- The class/spec/setup's saved profiles, in the order they were made.
function WP.List(classFile, spec, setup)
    local set = Set(classFile, spec, setup)
    return set and set.list or {}
end

-- Any set's profile `id`, and the class, spec and setup of its set.
function WP.ById(id)
    local store = Store()
    for key, set in pairs(store and store.sets or {}) do
        local p = Find(set, id)
        if p then
            local classFile, spec, setup = key:match("^(%u+):(%w+):(%w+)$")
            return p, classFile, spec, setup
        end
    end
end

-- The profile that ranks for class/spec/setup: profile `id` ("default", or
-- one deleted or of another spec or setup's set: none), else the picked one;
-- nil for the defaults.
function WP.Resolve(classFile, spec, setup, id)
    if id then
        local p, c, s, set = WP.ById(id)
        return p and c == classFile and s == spec and set == SetupKey(classFile, spec, setup) and p or nil
    end
    local set = Set(classFile, spec, setup)
    return set and set.picked and Find(set, set.picked) or nil
end

-- The picked profile's id, nil for the defaults.
function WP.PickedId(classFile, spec, setup)
    local p = WP.Resolve(classFile, spec, setup)
    return p and p.id
end

function WP.Pick(classFile, spec, setup, id)
    local set = Set(classFile, spec, setup, id ~= nil)
    if set then set.picked = id end
end

-- Whether profile `p` changes with level (it was imported with brackets):
-- the window then shows it, unchangeable.
function WP.Locked(p)
    return p ~= nil and #p.brackets > 1
end

---------------------------------------------------------------- names

-- `s` cut to `n` characters (UTF-8).
local function Cut(s, n)
    local count, i = 0, 1
    while i <= #s do
        count = count + 1
        if count > n then return s:sub(1, i - 1) end
        local c = s:byte(i)
        i = i + (c >= 240 and 4 or c >= 224 and 3 or c >= 192 and 2 or 1)
    end
    return s
end

-- A profile name as kept: no control characters, | ; or " (they would break
-- the text, the share strings or Pawn's), trimmed, NAME_CHARS long at most.
function WP.CleanName(name)
    name = tostring(name or ""):gsub("[%z\1-\31\127|;\"]", ""):gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
    if name == "" then name = L["Custom"] end
    return (Cut(name, NAME_CHARS):gsub("[ \t]+$", ""))
end

-- Name `name` cut to `n` characters, "…" after it when cut (tooltips).
function WP.ShortName(name, n)
    local cut = Cut(name, n)
    return cut == name and name or (cut:gsub("[ \t]+$", "") .. "…")
end

-- `name` (cleaned), or with " 2", " 3"... when another profile of the set has it.
local function UniqueName(set, name, except)
    name = WP.CleanName(name)
    local try, n = name, 1
    while true do
        local taken = name == L["Default"] and try == name
        for _, p in ipairs(set.list) do
            if p ~= except and p.name == try then taken = true end
        end
        if not taken then return try end
        n = n + 1
        try = Cut(name, NAME_CHARS - #tostring(n) - 1) .. " " .. n
    end
end

---------------------------------------------------------------- weights

local function Round(v)
    return math.floor(v * 1000 + 0.5) / 1000
end

-- Gear expertise is a flat percentage, 10 rating to 1%, weighed per 1%
-- (expPct). Until 1.3.2 it was weighed per point of rating (exprtng): such a
-- weight in `stats` becomes the per-1% one, ten times it, which scores an item
-- as before.
local function ExpertisePct(stats)
    local v = stats.exprtng
    if v == nil then return end
    stats.exprtng = nil
    if stats.expPct == nil and v ~= 0 then stats.expPct = Round(v * 10) end
end

-- Every weight that ranks for class/spec/setup at `level` with profile `id`
-- (as ns.GetWeights; "default": the defaults), the percent stats' and the off
-- hand's weapon DPS included: a new table, rounded to 3 decimals, without
-- zeros (but the off hand's, which would otherwise be half the main hand's;
-- left out for a spec that never holds an off-hand weapon).
function WP.InUse(classFile, spec, level, setup, id)
    local stats = ns.GetWeights(classFile, spec, level, setup, id)
    if not stats then return nil end
    local out = {}
    for k, v in pairs(stats) do
        if v ~= 0 then out[k] = Round(v) end
    end
    local crit = Round(ns.CritPctWeight(classFile, spec, level, setup, id))
    local hit = Round(ns.HitPctWeight(classFile, spec, level, setup, id))
    out.critPct, out.hitPct = crit ~= 0 and crit or nil, hit ~= 0 and hit or nil
    out.ohDps = ns.HoldsOffHandWeapon(classFile, spec) and Round(ns.OffDpsWeight(stats)) or nil
    return out
end

-- What ranks now as one bracket for every level: a profile's brackets.
function WP.Snapshot(classFile, spec, level, setup, id)
    return { { upTo = ns.MAX_LEVEL, stats = WP.InUse(classFile, spec, level, setup, id) or {} } }
end

-- A new profile in class/spec/setup's set (not picked). Returns it.
function WP.Create(classFile, spec, setup, name, brackets, icon)
    local store = Store(true)
    local set = Set(classFile, spec, setup, true)
    local p = { id = "p" .. store.next, name = UniqueName(set, name), icon = icon, brackets = brackets }
    store.next = store.next + 1
    set.list[#set.list + 1] = p
    return p
end

-- A copy of what ranks now for class/spec/setup at `level` (the picked
-- profile, or the defaults), named `name` (else the picked profile's, or
-- "Custom"), picked. Returns it.
function WP.New(classFile, spec, level, setup, name)
    local from = WP.Resolve(classFile, spec, setup)
    local brackets
    if from and WP.Locked(from) then
        brackets = {}
        for i, b in ipairs(from.brackets) do
            local stats = {}
            for k, v in pairs(b.stats) do stats[k] = v end
            brackets[i] = { upTo = b.upTo, stats = stats }
        end
    else
        brackets = WP.Snapshot(classFile, spec, level, setup)
    end
    local p = WP.Create(classFile, spec, setup, name or (from and from.name) or L["Custom"], brackets,
        from and from.icon)
    WP.Pick(classFile, spec, setup, p.id)
    return p
end

-- Sets weight `key` to `value` in the profile picked for class/spec/setup,
-- in its bracket for `level`. The defaults can't be changed (the window's
-- Edit copies them first): nil then, else the profile.
function WP.SetWeight(classFile, spec, level, setup, key, value)
    local p = WP.Resolve(classFile, spec, setup)
    if not p then return nil end
    local stats = ns.WeightBracket(p.brackets, level).stats
    stats[key] = (value ~= 0 or key == "ohDps") and Round(value) or nil
    return p
end

-- Profile `p` made the defaults at `level` again.
function WP.Reset(classFile, spec, level, setup, p)
    p.brackets = WP.Snapshot(classFile, spec, level, setup, "default")
end

function WP.Rename(classFile, spec, setup, p, name)
    local set = Set(classFile, spec, setup)
    if set and Find(set, p.id) then p.name = UniqueName(set, name, p) end
end

-- Deletes profile `id`; the defaults rank where it was picked. Off specs
-- that named it fall back to the defaults as they're read (Tooltip.lua).
function WP.Delete(classFile, spec, setup, id)
    local set = Set(classFile, spec, setup)
    local _, i = Find(set, id)
    if not i then return end
    table.remove(set.list, i)
    if set.picked == id then set.picked = nil end
end

-- The level range the weights ranking for class/spec/setup at `level` cover:
-- a profile's are 1-60 (or its bracket's, imported with brackets), the
-- defaults' their bracket's.
function WP.Range(classFile, spec, level, setup, id)
    local p = WP.Resolve(classFile, spec, setup, id)
    if not p then return ns.DefaultWeightRange(classFile, spec, level, setup) end
    if #p.brackets == 1 then return 1, ns.MAX_LEVEL end
    local bracket, from = ns.WeightBracket(p.brackets, level)
    return from, math.min(bracket.upTo, ns.MAX_LEVEL)
end

---------------------------------------------------------------- icons

-- The icons a profile can take besides its class's spec icons: per class 24
-- of its abilities ({ spell id, icon file id }, checked against the client's
-- SpellName and SpellMisc tables: none is one of the class's spec icons),
-- and a few for any class.
WP.ICONS = {
    WARRIOR = { { 5242, 132333 }, { 100, 132337 }, { 78, 132282 }, { 772, 132155 }, { 6343, 136105 },
        { 7384, 132223 }, { 5308, 135358 }, { 797, 132338 }, { 1680, 132369 }, { 23881, 136012 },
        { 1719, 132109 }, { 18499, 136009 }, { 20252, 132307 }, { 12292, 132306 }, { 6552, 132938 },
        { 2565, 132110 }, { 871, 132362 }, { 8242, 132357 }, { 6572, 132353 }, { 7386, 132363 },
        { 355, 136080 }, { 12975, 135871 }, { 1160, 132366 }, { 1715, 132316 } },
    PALADIN = { { 20154, 132325 }, { 20162, 135924 }, { 20375, 132347 }, { 23590, 135972 }, { 19740, 135906 },
        { 19742, 135970 }, { 20217, 135995 }, { 19750, 135907 }, { 633, 135928 }, { 642, 135896 },
        { 1022, 135964 }, { 853, 135963 }, { 20116, 135926 }, { 879, 135903 }, { 24239, 132326 },
        { 20925, 135880 }, { 25780, 135962 }, { 19746, 135933 }, { 4987, 135953 }, { 7328, 135955 },
        { 498, 135954 }, { 1152, 135949 }, { 2878, 135983 }, { 20166, 135960 } },
    HUNTER = { { 1130, 132212 }, { 19434, 135130 }, { 2643, 132330 }, { 3044, 132218 }, { 1978, 132204 },
        { 5116, 135860 }, { 3045, 132208 }, { 13165, 136076 }, { 13163, 132159 }, { 5118, 132242 },
        { 19506, 132329 }, { 19574, 132127 }, { 19577, 132111 }, { 883, 132161 }, { 136, 132179 },
        { 5384, 132293 }, { 1499, 135834 }, { 13812, 135826 }, { 2974, 132309 }, { 24335, 135125 },
        { 1988, 132153 }, { 20043, 136074 }, { 1494, 132328 }, { 6197, 132172 } },
    ROGUE = { { 1752, 136189 }, { 5171, 132306 }, { 408, 132298 }, { 1833, 132092 }, { 8676, 132282 },
        { 703, 132297 }, { 1943, 132302 }, { 1776, 132155 }, { 2070, 132310 }, { 2094, 136175 },
        { 1856, 132331 }, { 2983, 132307 }, { 4086, 136205 }, { 1766, 132219 }, { 13750, 136206 },
        { 14177, 135988 }, { 16511, 136168 }, { 14185, 136121 }, { 8647, 132354 }, { 1966, 132294 },
        { 1725, 132289 }, { 921, 133644 }, { 14278, 136136 }, { 14183, 136183 } },
    PRIEST = { { 17, 135940 }, { 139, 135953 }, { 2054, 135915 }, { 2061, 135907 }, { 2060, 135913 },
        { 596, 135943 }, { 14914, 135972 }, { 585, 135924 }, { 8092, 136224 }, { 15407, 136208 },
        { 16592, 136221 }, { 15286, 136230 }, { 8122, 136184 }, { 586, 135994 }, { 588, 135926 },
        { 527, 135894 }, { 2006, 135955 }, { 10060, 135939 }, { 14752, 135898 }, { 14751, 135863 },
        { 15237, 135922 }, { 6726, 135975 }, { 605, 136206 }, { 1425, 136091 } },
    SHAMAN = { { 421, 136015 }, { 8042, 136026 }, { 8050, 135813 }, { 8056, 135849 }, { 8004, 136043 },
        { 1064, 136042 }, { 17364, 132314 }, { 8232, 136018 }, { 8024, 135814 }, { 8017, 136086 },
        { 8075, 136023 }, { 8835, 136046 }, { 8512, 136114 }, { 5675, 136053 }, { 2075, 135825 },
        { 5394, 135127 }, { 2076, 136102 }, { 2645, 136095 }, { 370, 136075 }, { 16188, 136076 },
        { 16164, 136170 }, { 36936, 310733 }, { 8143, 136108 }, { 8177, 136039 } },
    MAGE = { { 133, 135812 }, { 5143, 136096 }, { 1449, 136116 }, { 2136, 135807 }, { 11366, 135808 },
        { 2948, 135827 }, { 2120, 135826 }, { 10, 135857 }, { 122, 135848 }, { 120, 135852 },
        { 11958, 135841 }, { 11426, 135988 }, { 1953, 135736 }, { 118, 136071 }, { 2139, 135856 },
        { 6117, 135991 }, { 168, 135843 }, { 12051, 136075 }, { 12043, 136031 }, { 12042, 136048 },
        { 11129, 135824 }, { 10138, 132796 }, { 400640, 135844 }, { 23028, 135869 } },
    WARLOCK = { { 686, 136197 }, { 348, 135817 }, { 172, 136118 }, { 14868, 136139 }, { 440892, 615099 },
        { 1454, 136126 }, { 689, 136169 }, { 1120, 136163 }, { 5782, 136183 }, { 5484, 136147 },
        { 18265, 136188 }, { 17877, 136191 }, { 17962, 135807 }, { 6353, 135808 }, { 1949, 135818 },
        { 688, 136218 }, { 697, 136221 }, { 691, 136217 }, { 712, 136220 }, { 706, 136185 },
        { 19028, 136160 }, { 755, 136168 }, { 710, 136135 }, { 5699, 135230 } },
    DRUID = { { 9739, 136048 }, { 2912, 135753 }, { 5570, 136045 }, { 339, 136100 }, { 16914, 136018 },
        { 24858, 136036 }, { 783, 132144 }, { 5221, 136231 }, { 22568, 132127 }, { 1079, 132152 },
        { 1822, 132122 }, { 1082, 132140 }, { 6807, 132136 }, { 769, 134296 }, { 1853, 132270 },
        { 774, 136081 }, { 8936, 136085 }, { 18562, 134914 }, { 1126, 136078 }, { 22812, 136097 },
        { 467, 136104 }, { 1850, 132120 }, { 24450, 132142 }, { 770, 136033 } },
}
WP.OTHER_ICONS = { { 133452, "PvP" }, { 132485, "Battleground" }, { 134237, "Dungeon" }, { 134153, "Raid" },
    { 133730, "Danger" }, { 133784, "Money" } }

-- Whether `icon` is one a profile of `classFile` can take (WP.IconTexture).
local function IconAllowed(classFile, icon)
    if type(icon) == "string" then
        local key = icon:match("^spec:(%w+)$")
        return key ~= nil and ns.IsSpec(classFile, key)
    end
    for _, e in ipairs(WP.ICONS[classFile] or {}) do
        if e[2] == icon then return true end
    end
    for _, e in ipairs(WP.OTHER_ICONS) do
        if e[1] == icon then return true end
    end
    return false
end

-- The texture of a profile's `icon` (nil: its spec's) for class/spec.
function WP.IconTexture(classFile, spec, icon)
    if type(icon) == "number" then return icon end
    local key = type(icon) == "string" and icon:match("^spec:(%w+)$")
    if key and ns.IsSpec(classFile, key) then return ns.SpecIconPath(classFile, key) end
    return ns.SpecIconPath(classFile, spec)
end

-- "|T...|t" markup of texture `texture`, cropped of its border, at the text's height.
function WP.IconMarkup(texture)
    return texture and ("|T" .. texture .. ":0:0:0:0:64:64:5:59:5:59|t") or ""
end

-- The icon of class/spec's weights with profile `p` (nil: the defaults), as markup.
function WP.Icon(classFile, spec, p)
    return WP.IconMarkup(WP.IconTexture(classFile, spec, p and p.icon))
end

---------------------------------------------------------------- migration

-- The old edits, WildGearDB.weights[classFile][spec] = { [key] =
-- value }, each replaced the default at every level and for every setup
-- (+1% crit and hit as level-60 values, scaled down by level). They become a
-- profile "Custom" for each setup of the spec, picked: the defaults at
-- `level` with the edits over them, as they ranked then. Done per class, at
-- the first login of a character of that class.
function WP.Migrate(classFile, level)
    local old = ns.db and ns.db.weights and ns.db.weights[classFile]
    if not old then return end
    for spec, edits in pairs(old) do
        if ns.IsSpec(classFile, spec) and type(edits) == "table" and next(edits) then
            for _, setup in ipairs(ns.SpecSetups(classFile, spec)) do
                local defaults = ns.DefaultWeights(classFile, spec, level, setup) or {}
                local merged = {}
                for k, v in pairs(defaults) do merged[k] = v end
                for k, v in pairs(edits) do
                    if k ~= "critPct" and k ~= "hitPct" and type(v) == "number" then merged[k] = v end
                end
                local stats = {}
                for k, v in pairs(merged) do
                    if v ~= 0 then stats[k] = Round(v) end
                end
                for _, key in ipairs({ "critPct", "hitPct" }) do
                    local v = edits[key] and edits[key] * math.min(level, 60) / 60
                        or (key == "critPct" and ns.CritPctWeight or ns.HitPctWeight)(classFile, spec, level, setup, "default")
                    stats[key] = Round(v) ~= 0 and Round(v) or nil
                end
                stats.ohDps = ns.HoldsOffHandWeapon(classFile, spec) and Round(ns.OffDpsWeight(merged)) or nil
                ExpertisePct(stats)
                local p = WP.Create(classFile, spec, setup, L["Custom"], { { upTo = ns.MAX_LEVEL, stats = stats } })
                WP.Pick(classFile, spec, setup, p.id)
            end
        end
    end
    ns.db.weights[classFile] = nil
    if not next(ns.db.weights) then ns.db.weights = nil end
end

-- Saved profiles' expertise weights per point of rating, made per 1% (ExpertisePct).
function WP.MigrateExpertise()
    local store = Store()
    for _, set in pairs(store and store.sets or {}) do
        for _, p in ipairs(set.list or {}) do
            for _, b in ipairs(p.brackets or {}) do ExpertisePct(b.stats) end
        end
    end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    WP.MigrateExpertise()
    WP.Migrate(select(2, UnitClass("player")), UnitLevel("player"))
end)

---------------------------------------------------------------- sharing

-- Every stat key a weight can have: the window's, and any the defaults use.
local known
local function KnownKeys()
    if known then return known end
    known = { ohDps = true }
    for _, s in ipairs(ns.WeightStats) do known[s.key] = true end
    local function Add(set)
        for _, b in ipairs(set.brackets or {}) do
            for k in pairs(b.stats) do known[k] = true end
        end
    end
    for _, specs in pairs(ns.Weights) do
        for _, w in pairs(specs) do
            Add(w)
            for _, s in pairs(w.setups or {}) do Add(s) end
        end
    end
    return known
end

-- `v` as text: up to 3 decimals, no trailing zeros.
local function Fmt(v)
    local s = string.format("%.3f", v):gsub("0+$", ""):gsub("%.$", "")
    return s == "-0" and "0" or s
end
WP.Format = Fmt

-- `stats`' keys, the window's order first, then the rest sorted.
local function OrderedKeys(stats)
    local keys, seen = {}, {}
    for _, s in ipairs(ns.WeightStats) do
        if stats[s.key] ~= nil then
            keys[#keys + 1] = s.key
            seen[s.key] = true
        end
    end
    local rest = {}
    for k in pairs(stats) do
        if not seen[k] then rest[#rest + 1] = k end
    end
    table.sort(rest)
    for _, k in ipairs(rest) do keys[#keys + 1] = k end
    return keys
end

-- What class/spec/setup's weights are at `level` with profile `p` (nil: the
-- defaults, as a snapshot named "Default"): brackets, name, icon.
local function Source(classFile, spec, level, setup, p)
    if p then return p.brackets, p.name, p.icon end
    return WP.Snapshot(classFile, spec, level, setup, "default"), L["Default"], nil
end

-- Our share string for class/spec/setup's weights with profile `p` (nil: the defaults).
function WP.Export(classFile, spec, level, setup, p)
    local brackets, name, icon = Source(classFile, spec, level, setup, p)
    local groups = {}
    for _, b in ipairs(brackets) do
        local parts = {}
        for _, k in ipairs(OrderedKeys(b.stats)) do
            local v = b.stats[k]
            if v ~= 0 or k == "ohDps" then parts[#parts + 1] = k .. "=" .. Fmt(v) end
        end
        groups[#groups + 1] = b.upTo .. ":" .. table.concat(parts, ",")
    end
    return table.concat({ "FLB1", classFile, spec, SetupKey(classFile, spec, setup) }, ";")
        .. (icon and (";icon=" .. tostring(icon)) or "")
        .. ";" .. table.concat(groups, "/") .. ";" .. name
end

-- Pawn's names for the classes and specs, in Pawn's spec order (its numbers).
local PAWN_SPECS = {
    WARRIOR = { { "Arms", "arms" }, { "Fury", "fury" }, { "Protection", "protection" } },
    PALADIN = { { "Holy", "holy" }, { "Protection", "protection" }, { "Retribution", "retribution" } },
    HUNTER = { { "BeastMastery", "beastmastery" }, { "Marksmanship", "marksmanship" }, { "Survival", "survival" } },
    ROGUE = { { "Assassination", "assassination" }, { "Outlaw", "combat" }, { "Subtlety", "subtlety" } },
    PRIEST = { { "Discipline", "discipline" }, { "Holy", "holy" }, { "Shadow", "shadow" } },
    SHAMAN = { { "Elemental", "elemental" }, { "Enhancement", "enhancement" }, { "Restoration", "restoration" } },
    MAGE = { { "Arcane", "arcane" }, { "Fire", "fire" }, { "Frost", "frost" } },
    WARLOCK = { { "Affliction", "affliction" }, { "Demonology", "demonology" }, { "Destruction", "destruction" } },
    DRUID = { { "Balance", "balance" }, { "Feral", "feral" }, { "Guardian", "bear" }, { "Restoration", "restoration" } },
}
local PAWN_SPEC_ALIASES = { Combat = "combat" } -- (older names)

-- Pawn's stat names for ours, one to one (the rest: PawnStats).
local PAWN_STATS = {
    Strength = "str", Agility = "agi", Stamina = "sta", Intellect = "int", Spirit = "spi",
    Ap = "atkpwr", Rap = "rgdatkpwr", FeralAp = "feratkpwr", SpellDamage = "spldmg", Healing = "splheal",
    FireSpellDamage = "firsplpwr", FrostSpellDamage = "frosplpwr", ArcaneSpellDamage = "arcsplpwr",
    ShadowSpellDamage = "shasplpwr", NatureSpellDamage = "natsplpwr", HolySpellDamage = "holsplpwr",
    Mp5 = "manargn", Hp5 = "healthrgn", DefenseRating = "defrtng",
    SpellPenetration = "splpen", BlockValue = "block", DodgeRating = "dodgePct", ParryRating = "parryPct",
    BlockRating = "blockPct", Armor = "armor", BonusArmor = "armorbonus",
}
-- Pawn's names that are one of ours, as melee or spell: Forever pools the two
-- (Pawn counts an item's "+1% hit" per 1% there), so the larger counts.
local PAWN_POOLED = { HitRating = "hitPct", SpellHitRating = "hitPct", CritRating = "critPct",
    SpellCritRating = "critPct", HasteRating = "hastertng", SpellHasteRating = "hastertng" }
-- Pawn's names per point of rating for ours per 1%: ours, and the rating to 1%
-- (gear expertise is a flat percentage, 10 rating to 1%).
local PAWN_RATING = { ExpertiseRating = { "expPct", 10 } }
-- Pawn's weapon DPS and speed stats (folded into ours by the weapon setup),
-- its speed baseline and spell power. Pawn's speed weights are per second,
-- ours per 0.1 s; Pawn counts speed from SpeedBaseline, as ours from speedRef.
local PAWN_WEAPON = { Dps = true, MeleeDps = true, MainHandDps = true, OffHandDps = true, OneHandDps = true,
    TwoHandDps = true, RangedDps = true, Speed = true, MeleeSpeed = true, MainHandSpeed = true,
    OffHandSpeed = true, OneHandSpeed = true, TwoHandSpeed = true, RangedSpeed = true, SpeedBaseline = true,
    SpellPower = true }

-- The stat each spec's default weights hold at 1 (tools/statmodel's
-- NORMALIZE): an imported Pawn scale is brought to it, as upgrade gains are
-- absolute (Tooltip.lua's green arrow starts at +0.05).
local ANCHORS = {
    WARRIOR = { arms = "atkpwr", fury = "atkpwr", protection = "atkpwr" },
    PALADIN = { holy = "splheal", protection = "spldmg", retribution = "atkpwr" },
    HUNTER = { beastmastery = "rgdatkpwr", marksmanship = "rgdatkpwr", survival = "rgdatkpwr", survivalmelee = "str" },
    ROGUE = { assassination = "atkpwr", combat = "atkpwr", subtlety = "atkpwr" },
    PRIEST = { discipline = "splheal", holy = "splheal", shadow = "spldmg" },
    SHAMAN = { elemental = "spldmg", enhancement = "atkpwr", restoration = "splheal" },
    MAGE = { arcane = "spldmg", fire = "spldmg", frost = "spldmg" },
    WARLOCK = { affliction = "spldmg", demonology = "spldmg", destruction = "spldmg" },
    DRUID = { balance = "spldmg", feral = "atkpwr", bear = "atkpwr", restoration = "splheal" },
}

-- Pawn's class name for `classFile` ("Warrior").
local function PawnClass(classFile)
    return classFile:sub(1, 1) .. classFile:sub(2):lower()
end

-- Pawn's spec name for our `spec` (Surv (Melee) is Pawn's Survival).
local function PawnSpec(classFile, spec)
    spec = spec == "survivalmelee" and "survival" or spec
    for _, e in ipairs(PAWN_SPECS[classFile] or {}) do
        if e[2] == spec then return e[1] end
    end
end

-- A Pawn scale tag for class/spec/setup's weights at `level` with profile `p`
-- (nil: the defaults). Our weights mapped back to Pawn's names: +1% hit and
-- crit to both the melee and the spell one, +1% expertise per point of rating
-- (PAWN_RATING), weapon DPS as the melee (the off
-- hand's on top, for off hand weapons) and ranged one; Pawn has no place for
-- the rest (spell power as such: it adds spell damage and healing).
function WP.ExportPawn(classFile, spec, level, setup, p)
    local brackets, name = Source(classFile, spec, level, setup, p)
    local stats = ns.WeightBracket(brackets, level).stats
    local reverse = {}
    for pawn, ours in pairs(PAWN_STATS) do reverse[ours] = pawn end
    local rating = {}
    for pawn, e in pairs(PAWN_RATING) do rating[e[1]] = { pawn, e[2] } end
    local parts = { "Class=" .. PawnClass(classFile) }
    local pawnSpec = PawnSpec(classFile, spec)
    if pawnSpec then parts[#parts + 1] = "Spec=" .. pawnSpec end
    local function Add(key, v)
        if v and v ~= 0 then parts[#parts + 1] = key .. "=" .. Fmt(v) end
    end
    for _, k in ipairs(OrderedKeys(stats)) do
        local v = stats[k]
        if reverse[k] then
            Add(reverse[k], v)
        elseif rating[k] then
            Add(rating[k][1], v / rating[k][2])
        elseif k == "hitPct" then
            Add("HitRating", v)
            Add("SpellHitRating", v)
        elseif k == "critPct" then
            Add("CritRating", v)
            Add("SpellCritRating", v)
        elseif k == "hastertng" then
            Add("HasteRating", v)
            Add("SpellHasteRating", v)
        elseif k == "dps" then
            Add("MeleeDps", v)
        elseif k == "rangedDps" then
            Add("RangedDps", v)
        elseif k == "ohDps" then
            Add("OffHandDps", v - (stats.dps or 0))
        elseif k == "speed" then
            Add("MeleeSpeed", v * 10)
        elseif k == "rangedSpeed" then
            Add("RangedSpeed", v * 10)
        elseif k == "ohSpeed" then
            Add("OffHandSpeed", (v - (stats.speed or 0)) * 10)
        end
    end
    -- Pawn has one baseline for every speed: the main hand's (else the ranged one's).
    local base = (stats.speed and stats.speedRef) or (stats.rangedSpeed and stats.rangedSpeedRef)
    if base then Add("SpeedBaseline", base) end
    return string.format('( Pawn: v1: "%s": %s )', name, table.concat(parts, ", "))
end

-- A string to import, read: { format = "flb" or "pawn", name, classFile,
-- spec, setup, icon (ours), brackets (ours), pawn = { [stat] = value } and
-- skipped = { names } (Pawn's) }, the class, spec and setup nil when it
-- doesn't name them. Else nil and why.
local function ParseFLB(text)
    local parts = {}
    for part in (text .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = part end
    local version = tonumber(parts[1]:match("^FLB(%d+)$") or "")
    if not version then return nil end
    if version > 1 then return nil, L["This string is from a newer version of WildGear."] end
    local out = { format = "flb", classFile = parts[2], spec = parts[3], setup = parts[4], skipped = {} }
    if not (out.classFile and ns.Specs[out.classFile] and out.spec and ns.IsSpec(out.classFile, out.spec)) then
        return nil, L["This string is for a class or spec WildGear doesn't know."]
    end
    local i = 5
    while parts[i] and parts[i]:match("^%s*%a+%s*=") do
        local k, v = parts[i]:match("^[ \t]*(%a+)[ \t]*=[ \t]*(.-)[ \t]*$")
        if k == "icon" then
            local icon = tonumber(v) or v
            if IconAllowed(out.classFile, icon) then out.icon = icon end
        end
        i = i + 1
    end
    local brackets, seen, last = {}, {}, 0
    for group in (parts[i] or ""):gmatch("[^/]+") do
        local upTo, list = group:match("^%s*(%d+)%s*:(.*)$")
        upTo = tonumber(upTo)
        if not upTo or upTo <= last or #brackets >= MAX_BRACKETS then
            return nil, L["This string is broken. Copy all of it again."]
        end
        -- (past the top level: the last bracket reached it, the rest can't be used)
        if last >= ns.MAX_LEVEL then break end
        local stats, n = {}, 0
        for pair in list:gmatch("[^,]+") do
            local k, v = pair:match("^%s*([%a]+)%s*=%s*(%S+)%s*$")
            v = Weight(v)
            -- (a string from before 1.3.2: expertise per point of rating, ExpertisePct)
            if k == "exprtng" and v then k, v = "expPct", v * 10 end
            if k and v and KnownKeys()[k] and n < MAX_STATS then
                stats[k] = v ~= 0 and Round(v) or (k == "ohDps" and 0 or nil)
                n = n + 1
            elseif k and not seen[k] then
                seen[k] = true
                out.skipped[#out.skipped + 1] = k
            end
        end
        brackets[#brackets + 1] = { upTo = math.min(upTo, ns.MAX_LEVEL), stats = stats }
        last = upTo
    end
    if #brackets == 0 then return nil, L["This string has no stat weights."] end
    brackets[#brackets].upTo = ns.MAX_LEVEL
    out.brackets = brackets
    out.name = table.concat(parts, ";", i + 1):gsub(";+$", "")
    return out
end

local function ParsePawn(text)
    local version, name, body = text:match('^%(%s*Pawn%s*:%s*v(%d+)%s*:%s*"([^"]*)"%s*:%s*(.-)%s*%)$')
    if not version then return nil end
    local out = { format = "pawn", name = name, pawn = {}, skipped = {} }
    local class, specName
    for pair in body:gmatch("[^,]+") do
        local k, v = pair:match("^[ \t\r\n]*([%w]+)[ \t]*=[ \t]*([^ \t\r\n]-)[ \t\r\n]*$")
        if k == "Class" then
            class = v
        elseif k == "Spec" then
            specName = v
        elseif k and Weight(v) and (PAWN_STATS[k] or PAWN_POOLED[k] or PAWN_RATING[k] or PAWN_WEAPON[k]) then
            out.pawn[k] = Weight(v)
        elseif k then
            out.skipped[#out.skipped + 1] = k
        end
    end
    if class then
        class = class:upper():gsub("%s", "")
        if ns.Specs[class] then out.classFile = class end
    end
    if out.classFile and specName then
        local n = tonumber(specName)
        for i, e in ipairs(PAWN_SPECS[out.classFile]) do
            if i == n or e[1]:lower() == specName:lower() then out.spec = e[2] end
        end
        out.spec = out.spec or PAWN_SPEC_ALIASES[specName]
        if out.spec and not ns.IsSpec(out.classFile, out.spec) then out.spec = nil end
    end
    local any = false
    for _, v in pairs(out.pawn) do any = any or v ~= 0 end
    if not any then return nil, L["This string has no stat weights."] end
    return out
end

-- Reads a pasted string (ours or Pawn's). Returns the reading (above), or nil
-- and why.
function WP.Parse(text)
    text = tostring(text or ""):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", "")
    if text == "" then return nil, L["Paste a WildGear or Pawn string."] end
    local out, err = ParseFLB(text)
    if out or err then return out, err end
    out, err = ParsePawn(text)
    if out or err then return out, err end
    return nil, L["This isn't a WildGear or Pawn string."]
end

-- The weights a reading imports as, for class/spec/setup at `level`: its
-- brackets. Ours as they are; Pawn's mapped to ours (PAWN_STATS, the pooled
-- ones' larger value, the rating ones per 1%, spell power as spell damage + healing + Pawn's own,
-- weapon DPS by the setup's hands) and brought to the spec's scale: its
-- anchor stat (ANCHORS) made 1, or, when the scale doesn't value it, its
-- main stat made the defaults' at `level`. Second, for Pawn's: the factor
-- and the anchor's key (nil when nothing was scaled).
function WP.Build(reading, classFile, spec, setup, level)
    if reading.format == "flb" then return reading.brackets end
    local pawn, stats = reading.pawn, {}
    for k, v in pairs(pawn) do
        if PAWN_STATS[k] then stats[PAWN_STATS[k]] = v end
    end
    for k, ours in pairs(PAWN_POOLED) do
        if pawn[k] then stats[ours] = math.max(stats[ours] or pawn[k], pawn[k]) end
    end
    for k, e in pairs(PAWN_RATING) do
        if pawn[k] then stats[e[1]] = pawn[k] * e[2] end
    end
    if pawn.Armor and not pawn.BonusArmor then stats.armorbonus = pawn.Armor end
    if pawn.SpellDamage or pawn.Healing or pawn.SpellPower then
        stats.splpwr = (pawn.SpellDamage or 0) + (pawn.Healing or 0) + (pawn.SpellPower or 0)
    end
    local function Sum(...)
        local total, any = 0, false
        for _, k in ipairs({ ... }) do
            if pawn[k] then total, any = total + pawn[k], true end
        end
        return any and total or nil
    end
    local twoHand = SetupKey(classFile, spec, setup) == "twohand"
    stats.dps = Sum("Dps", "MeleeDps", "MainHandDps", twoHand and "TwoHandDps" or "OneHandDps")
    stats.ohDps = Sum("Dps", "MeleeDps", "OffHandDps", "OneHandDps")
    stats.rangedDps = Sum("Dps", "RangedDps")
    if stats.dps and not stats.ohDps then stats.ohDps = 0 end
    -- (speed per second in Pawn, per 0.1 s here)
    local function Speed(...)
        local v = Sum(...)
        return v and v / 10
    end
    stats.speed = Speed("Speed", "MeleeSpeed", "MainHandSpeed", twoHand and "TwoHandSpeed" or "OneHandSpeed")
    stats.ohSpeed = Speed("Speed", "MeleeSpeed", "OffHandSpeed", "OneHandSpeed")
    stats.rangedSpeed = Speed("Speed", "RangedSpeed")

    local anchor = ANCHORS[classFile] and ANCHORS[classFile][spec]
    local factor
    if anchor and (stats[anchor] or 0) > 0 then
        factor = 1 / stats[anchor]
    else
        local defaults = WP.InUse(classFile, spec, level, setup, "default") or {}
        local best, main = 0, nil
        for _, k in ipairs({ "str", "agi", "int" }) do
            if (defaults[k] or 0) > best then best, main = defaults[k], k end
        end
        if main and (stats[main] or 0) > 0 then factor, anchor = best / stats[main], main end
    end
    if not factor then anchor = nil end
    local out = {}
    for k, v in pairs(stats) do
        local scaled = Weight(Round(v * (factor or 1)))
        if scaled and (scaled ~= 0 or k == "ohDps") then out[k] = scaled end
    end
    -- Pawn's baseline as each speed's reference (seconds: not scaled).
    local base = Weight(pawn.SpeedBaseline)
    if base and base > 0 then
        for _, s in ipairs(ns.SpeedStats) do
            if out[s.key] then out[s.key .. "Ref"] = Round(base) end
        end
    end
    return { { upTo = ns.MAX_LEVEL, stats = out } }, factor and factor ~= 1 and factor or nil, anchor
end

-- Imports `brackets` (WP.Build's) as a new profile of class/spec/setup named
-- `name`, picked. Returns it.
function WP.Import(classFile, spec, setup, name, brackets, icon)
    if icon and not IconAllowed(classFile, icon) then icon = nil end
    local p = WP.Create(classFile, spec, setup, name, brackets, icon)
    WP.Pick(classFile, spec, setup, p.id)
    return p
end

WP.IconAllowed = IconAllowed
