local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The addon's verdict on item tooltips anywhere in the game (bags, the
-- character pane, chat links, loot, vendors, quest rewards...), below the
-- game's own lines, all of it on a faint orange band:
--
--     [logo] WildGear
--   +----------------------------------------------------------+
--   | [bar]  [icon] Fury                                   84.2 |
--   |        [up]   +6.1  (+8%)   vs Bloodspattered Wristbands |
--   |               86% of best                       #3 Wrist |
--   +----------------------------------------------------------+
--   +----------------------------------------------------------+
--   | [bar]  [icon] Arms                         [up] +2.1  61.0 |
--   | [bar]  [icon] Protection              Not for 1H + shield |
--   +----------------------------------------------------------+
--
-- Your main spec is the window's (Settings can change it too): the item's
-- score, its gain or loss over the item it would replace (the weaker ring or
-- trinket; for weapons, the hands you'd end up with) in the gear the spec is
-- compared with (Tip.Compare: by default what you wear), and how close it
-- comes to the best item you can get for the slot at your level (bar colors as
-- My gear's legend). The off specs picked in Settings (Tip.OffList: each a
-- spec, weapon setup and weight profile, per character) get a row each in a
-- box of their own: where the item stands for them, its gain over the gear
-- each is compared with (by default the best of what you wear and carry),
-- and their score. Each line shows its weight profile's icon and its spec,
-- and its setup or profile's name where another line has the same spec
-- (Tip.LineLabels). Armor is scored with the line's weapon setup; a weapon in
-- the spec's setup that uses it (HandVerdict). Gear you can't equip, or
-- that none of the spec's setups uses, says so; gear you can wear only later
-- (its required level, mail and plate from ns.ARMOR_UPGRADE_LEVEL) gets its
-- score and that level, no gain over yours. Always for your own
-- character, whatever the window is planning. The window's own item tooltips
-- show the same block for the profile it shows (Tip.AddBlock), followed by
-- what only the window knows (whose gains are over what you wear).
-- An upgrade for your main spec stands out: its box turns green, and the
-- gain's arrow bobs with a green glow behind it.
-- In the game's quest windows, the reward choice QuestWindow.lua marks as
-- the best pick says so, under the block.
-- WildGearDB.tooltip = false turns it all off (Settings panel).

local L = ns.L
local Tip = {}
ns.Tooltip = Tip

local MEDIA = "Interface\\AddOns\\WildSpark\\Modules\\WildGear\\Media\\"
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
local CROSS = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:0|t"
-- Colors as 0-255 triples, for |c codes and the |T tint alike.
local GOLD, GREEN, RED = { 255, 209, 0 }, { 51, 255, 153 }, { 255, 112, 112 }
local GREY, BLUE, ORANGE = { 136, 136, 136 }, { 102, 179, 255 }, { 255, 153, 0 }
local TRACK = { 56, 56, 64 } -- the bar's empty part
-- My gear's legend (UI.lua Tiers): BiS, 85%+, 50%+, then the rest.
local BIS = { 255, 128, 0 }
local function TierColor(ratio)
    return (ratio >= 0.97 and BIS) or (ratio > 0.85 and { 163, 53, 238 }) or (ratio > 0.5 and { 0, 112, 221 })
        or { 157, 157, 157 }
end
local BAR_WIDTH, BAR_HEIGHT = 48, 6
local HAND_INV = { [13] = true, [14] = true, [17] = true, [21] = true, [22] = true, [23] = true }
local UPGRADE = 0.05 -- the least gain shown as one (green, with an up arrow)

local function Color(c, text)
    return string.format("|cff%02x%02x%02x%s|r", c[1], c[2], c[3], text)
end

-- A color as 0-1 values, for SetVertexColor and SetColorTexture.
local function Rgb(c)
    return c[1] / 255, c[2] / 255, c[3] / 255
end

-- One of the Media icons (white, 32x32) tinted `c`, at the text's height.
local function Icon(name, c)
    return string.format("|T%s%s:0:0:0:0:32:32:0:32:0:32:%d:%d:%d|t", MEDIA, name, c[1], c[2], c[3])
end

local function Block(width, c)
    if width < 1 then return "" end -- (a width of 0 would mean "as tall as the text")
    return string.format("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t",
        BAR_HEIGHT, width, c[1], c[2], c[3])
end

-- A small meter: `ratio` (0-1) of it filled in color `c`.
local function Bar(ratio, c)
    local fill = math.floor(math.max(0, math.min(ratio, 1)) * BAR_WIDTH + 0.5)
    return Block(fill, c) .. Block(BAR_WIDTH - fill, TRACK)
end

local function ClassColored(classFile, text)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return (c and c.colorStr) and ("|c" .. c.colorStr .. text .. "|r") or text
end

---------------------------------------------------------------- profiles

-- Your character as profile `spec` with weapon setup `setup` (nil: the
-- window's choice for that spec).
function Tip.Profile(p, spec, setup)
    local out = {}
    for k, v in pairs(p) do out[k] = v end
    out.spec, out.setup = spec, setup
    return out
end

-- "[icon] Fury": the spec's icon and name in its class color (orange when
-- `guess`: the window's spec not picked yet).
function Tip.SpecLabel(p, spec, guess)
    local name = ns.SpecLabel(spec, p.classFile)
    return ns.SpecIcon(p.classFile, spec) .. " " .. (guess and Color(ORANGE, name) or ClassColored(p.classFile, name))
end

---------------------------------------------------------------- off specs

-- Your off specs, per character: charDB.offSpecs = { { spec, setup, weights,
-- compare }... } (picked in Settings, up to Tip.MAX_OFF), each scored as its
-- spec with weapon setup `setup` (nil: the window's for it), weight profile
-- `weights` (WeightProfiles.lua: a profile's id; nil, or one deleted since,
-- for the default weights) and compared with `compare` (as Tip.Compare's;
-- nil: "bags"). Any spec of your class, your main spec too with other weights
-- or another setup. The old shape, { [spec] = true } (1.1.2's switches),
-- becomes these, each with the window's setup for it and the profile picked
-- for that. Settings lists them under the main spec: Add off spec adds
-- Tip.NextEntry, x removes one. An entry the same as the main spec's line
-- or an earlier one is kept but doesn't score (Tip.Skipped), so changing
-- the main spec never changes the list.
Tip.MAX_OFF = 3

-- A new entry for spec `spec` of yours (profile `p`): the window's weapon
-- setup for it, the profile picked for that, and what it was compared with.
-- (The setup chosen or the spec's first, not what your level allows yet:
-- Fury's Dual wield is kept at level 15, scored as Two-hander till it can
-- be, as the window does: ns.GetWeaponSetupPref.)
function Tip.NewEntry(p, spec)
    local setups = ns.SpecSetups(p.classFile, spec)
    local chosen = ns.charDB.weapons and ns.charDB.weapons[p.classFile .. ":" .. spec]
    local setup = chosen == "onehand" and chosen or setups[1]
    for _, s in ipairs(setups) do
        if s == chosen then setup = chosen end
    end
    return { spec = spec, setup = setup, compare = ns.charDB.compare and ns.charDB.compare[spec],
             weights = ns.WeightProfiles.PickedId(p.classFile, spec, setup) }
end

function Tip.OffList()
    local list = ns.charDB.offSpecs
    if list and list[1] == nil and next(list) then
        local p, new = ns.GetPlayer(), {}
        for _, spec in ipairs(ns.Specs[p.classFile] or {}) do
            if list[spec] == true and spec ~= p.spec then new[#new + 1] = Tip.NewEntry(p, spec) end
        end
        ns.charDB.offSpecs = #new > 0 and new or nil
        list = ns.charDB.offSpecs
    end
    return list or {}
end

-- What off spec entry `e` is compared with: its choice, a deleted set the default "bags".
function Tip.EntryCompare(e)
    local choice = e.compare
    if type(choice) == "number" and not ns.EquipmentSetInfo(choice) then choice = nil end
    return choice or "bags"
end

-- Your character (profile `p`) as off spec entry `e`: its spec, setup and
-- weights, and what it is compared with (p.compare).
function Tip.EntryProfile(p, e)
    local out = Tip.Profile(p, e.spec, e.setup)
    out.lineSetup = e.setup -- (kept as p.setup is set to judge a weapon in another: State)
    out.weights = e.weights or "default"
    out.compare = Tip.EntryCompare(e)
    return out
end

-- The weight profile profile `p` scores with (nil: the defaults), and its
-- weapon setup.
local function LineProfile(p)
    local setup = ns.GetWeaponSetupPref(p)
    return ns.WeightProfiles.Resolve(p.classFile, p.spec, setup, p.weights), setup
end

-- What tells profile `p`'s line apart: its spec, its setup (One-hander apart
-- from the setup whose profiles it shares: weapons rank otherwise) and its
-- weights.
local function LineKey(p)
    local prof, setup = LineProfile(p)
    return table.concat({ p.spec, setup, prof and prof.id or "-" }, ":")
end

-- The off spec entries that don't score for profile `p` (your class), by
-- index: an unknown spec, or the same line as the main spec's (p's) or an
-- earlier entry's. Settings greys them out.
function Tip.Skipped(p)
    local out, seen = {}, { [LineKey(p)] = true }
    for i, e in ipairs(Tip.OffList()) do
        local key = ns.IsSpec(p.classFile, e.spec) and LineKey(Tip.EntryProfile(p, e))
        if not key or seen[key] then out[i] = true else seen[key] = true end
    end
    return out
end

-- The off spec entries that score for profile `p` (your class).
function Tip.OffEntries(p)
    local out, skipped = {}, Tip.Skipped(p)
    for i, e in ipairs(Tip.OffList()) do
        if not skipped[i] then out[#out + 1] = e end
    end
    return out
end

-- The entry Add off spec adds for profile `p` (your class): your first spec
-- with no line yet (Tip.NewEntry), else a line not there yet of your main
-- spec, then of the others: on the window's setup for the spec first, then
-- its other setups, each with your profiles for it, then Default. nil when
-- the list is full (Tip.MAX_OFF) or every line is there.
function Tip.NextEntry(p)
    local list = Tip.OffList()
    if #list >= Tip.MAX_OFF then return nil end
    local listed, taken = { [p.spec] = true }, { [LineKey(p)] = true }
    for _, e in ipairs(list) do
        listed[e.spec] = true
        if ns.IsSpec(p.classFile, e.spec) then taken[LineKey(Tip.EntryProfile(p, e))] = true end
    end
    local specs = ns.Specs[p.classFile] or {}
    for _, spec in ipairs(specs) do
        if not listed[spec] then return Tip.NewEntry(p, spec) end
    end
    local order = { p.spec }
    for _, spec in ipairs(specs) do
        if spec ~= p.spec then order[#order + 1] = spec end
    end
    for _, spec in ipairs(order) do
        local first = ns.GetWeaponSetupPref(Tip.Profile(p, spec))
        local setups = { first }
        for _, s in ipairs(ns.SpecSetups(p.classFile, spec)) do
            if s ~= first then setups[#setups + 1] = s end
        end
        for _, setup in ipairs(setups) do
            local ids = {}
            for _, prof in ipairs(ns.WeightProfiles.List(p.classFile, spec, setup)) do ids[#ids + 1] = prof.id end
            ids[#ids + 1] = false -- (Default)
            for _, id in ipairs(ids) do
                local e = { spec = spec, setup = setup, weights = id or nil,
                            compare = ns.charDB.compare and ns.charDB.compare[spec] }
                if not taken[LineKey(Tip.EntryProfile(p, e))] then return e end
            end
        end
    end
    return nil
end

---------------------------------------------------------------- dual talent

-- Dual talent (learned at level 40): two talent sets, swapped at any time.
-- Each one can be linked to one of your spec lines in Settings, the main
-- spec's (charDB.mainTalents) or an off spec entry's (e.talents): 1 is the
-- primary set, 2 the secondary, each on one line at most. The line linked to
-- the active set is your main spec: on a swap (ACTIVE_TALENT_GROUP_CHANGED)
-- or a link changed, Tip.SyncTalents makes that off spec entry the main spec
-- and puts the main spec's line in its place, each keeping its setup, weights,
-- its link and an equipment set it is compared with; else it is compared as
-- its new place's lines are at first (the main spec with what you wear, an
-- off spec with Worn + bags: Tip.Compare). Forever has Retail's calls:
-- C_SpecializationInfo.GetActiveSpecGroup() and GetNumSpecGroups().

-- The dev addon's fake dual talent (its /wildgear talents: WildGearDevDB.talents
-- = { sets = 2, active = 1 or 2 }), for a character below 40; nil: the game's.
local function FakeTalents()
    local db = WildGearDevDB
    return type(db) == "table" and type(db.talents) == "table" and db.talents or nil
end

-- How many talent sets you have: 2 once dual talent is learned, else 1.
function Tip.TalentSets()
    local fake = FakeTalents()
    local n = fake and fake.sets or (GetNumSpecGroups and GetNumSpecGroups())
    return type(n) == "number" and n or 1
end

-- The active talent set, 1 or 2.
function Tip.ActiveTalentSet()
    local info, fake = C_SpecializationInfo, FakeTalents()
    local n = fake and fake.active or (info and info.GetActiveSpecGroup and info.GetActiveSpecGroup())
    return type(n) == "number" and n or 1
end

-- The talent set linked to off spec entry `index` (nil: the main spec's line).
function Tip.LinkedTalents(index)
    if not index then return ns.charDB.mainTalents end
    local e = Tip.OffList()[index]
    return e and e.talents
end

-- The main spec's line as an off spec entry: its spec, its weapon setup (the
-- chosen one, as Tip.NewEntry), weights, its equipment set (else Worn + bags,
-- an off spec's at first) and its link.
local function SetOnly(compare)
    return type(compare) == "number" and compare or nil
end

local function MainEntry(p)
    local e = Tip.NewEntry(p, p.spec)
    e.compare = SetOnly(Tip.Compare(p.spec))
    e.talents = ns.charDB.mainTalents
    return e
end

-- Makes the off spec entry linked to the active talent set your main spec,
-- the main spec's line taking its place in the list. True when it did.
function Tip.SyncTalents()
    if not ns.charDB or Tip.TalentSets() < 2 then return false end
    local set = Tip.ActiveTalentSet()
    if ns.charDB.mainTalents == set then return false end
    local p, list = ns.GetPlayer(), Tip.OffList()
    for i, e in ipairs(list) do
        if e.talents == set and ns.IsSpec(p.classFile, e.spec) then
            list[i] = MainEntry(p)
            ns.charDB.offSpecs = list
            ns.charDB.spec, ns.charDB.mainTalents = e.spec, set
            if ns.charDB.sim then ns.charDB.sim.spec = nil end
            local profile = Tip.Profile(p, e.spec)
            if e.setup then ns.SetWeaponSetupPref(profile, e.setup) end
            ns.WeightProfiles.Pick(p.classFile, e.spec, e.setup or ns.GetWeaponSetupPref(profile), e.weights)
            ns.charDB.compare = ns.charDB.compare or {}
            ns.charDB.compare[e.spec] = SetOnly(Tip.EntryCompare(e)) -- (else Worn)
            return true
        end
    end
    return false
end

-- Links talent set `set` (nil: none) to off spec entry `index` (nil: the main
-- spec's line), and off any other line, then syncs (Tip.SyncTalents).
function Tip.LinkTalents(index, set)
    local list = Tip.OffList()
    if set then
        if ns.charDB.mainTalents == set then ns.charDB.mainTalents = nil end
        for _, e in ipairs(list) do
            if e.talents == set then e.talents = nil end
        end
    end
    if not index then
        ns.charDB.mainTalents = set
    elseif list[index] then
        list[index].talents = set
    end
    Tip.SyncTalents()
end

-- The icon of profile `p`'s line: its weight profile's, else its spec's.
function Tip.LineIcon(p)
    return ns.WeightProfiles.IconTexture(p.classFile, p.spec, (LineProfile(p) or {}).icon)
end

-- The labels of the lines for profiles `lines` (the main spec's first, then
-- the off specs'): each its icon and spec name in the class color, then, only
-- to tell lines of the same spec apart, in grey, its weapon setup (another
-- line of the spec has another) and its weights' name (another has others).
function Tip.LineLabels(lines)
    local info = {}
    for i, p in ipairs(lines) do
        local prof, setup = LineProfile(p)
        info[i] = { spec = p.spec, setup = setup, prof = prof }
    end
    local out = {}
    for i, a in ipairs(info) do
        local p, setupDiffers, profDiffers = lines[i], false, false
        for j, b in ipairs(info) do
            if j ~= i and b.spec == a.spec then
                setupDiffers = setupDiffers or b.setup ~= a.setup
                profDiffers = profDiffers or b.prof ~= a.prof
            end
        end
        local extra = {}
        if setupDiffers then extra[#extra + 1] = ns.WeaponSetups[a.setup].label end
        if profDiffers then
            extra[#extra + 1] = a.prof and ns.WeightProfiles.ShortName(a.prof.name, 16) or L["Default"]
        end
        out[i] = ns.WeightProfiles.IconMarkup(Tip.LineIcon(p)) .. " "
            .. ClassColored(p.classFile, ns.SpecLabel(p.spec, p.classFile))
            .. (#extra > 0 and ("|cff999999 · " .. table.concat(extra, " · ") .. "|r") or "")
    end
    return out
end


---------------------------------------------------------------- your gear and rankings

-- Per profile and level: { p, gear = ns.GetEquipped, ranked = ns.Rank, score = ns.SlotScorer }.
-- Built on the first tooltip that needs it, dropped when your gear, level,
-- skills or (through UI.Refresh) the window's settings change.
local states = {}
local loading -- a worn item hadn't loaded when a state was built

function Tip.Invalidate()
    states, loading = {}, nil
end

-- Whether profile `p` is your own class, so your worn gear is its gear.
local function OwnClass(p)
    return select(2, UnitClass("player")) == p.classFile
end

-- The rankings for a state, made the first time a verdict asks for a
-- standing (a tooltip shows it): a gain (bag arrows, the wish list, quest
-- marks, the API) needs only your gear and the scorer, and ranking every
-- item takes tens of milliseconds at 60. Done on every gear change, it was a
-- hitch on each weapon swap (a warrior's macro), twice over for a one-hander
-- in your bags (judged in a second setup). Its weapon setup is there at once.
local function LazyRanked(p, opts, setup)
    local done
    return setmetatable({ weapons = { setup = setup } }, { __index = function(t, k)
        if done then return nil end
        done = true
        for key, v in pairs(ns.Rank(p, opts) or {}) do rawset(t, key, v) end
        return rawget(t, k)
    end })
end

-- (Another class, planned in the window, has no worn gear: s.noGear.)
local function Build(p)
    local own = OwnClass(p)
    local opts = { classArmorOnly = ns.db.classArmorOnly, owned = own and ns.GetEquipped(p) or {} }
    local setup = ns.GetWeaponSetupPref(p) -- (as ns.Rank's: no weights, no rankings)
    if not ns.GetWeights(p.classFile, p.spec, p.level, setup, p.weights) then return { none = true } end
    local ranked = LazyRanked(p, opts, setup)
    for _, list in pairs(opts.owned) do
        for _, w in ipairs(list) do
            if not w.item then loading = true end
        end
    end
    return { p = p, gear = opts.owned, noGear = not own, ranked = ranked, score = ns.SlotScorer(p) }
end

-- What spec `spec` of yours is compared with (Settings: charDB.compare =
-- { [spec] = choice }, per character): "worn", "bags" (the best of what you
-- wear and carry in your bags for it) or the ID of one of your equipment
-- manager's sets. By default, what you wear for your main spec, "bags" for
-- the others; a set since deleted counts as the default.
function Tip.Compare(spec)
    local choice = ns.charDB.compare and ns.charDB.compare[spec]
    if type(choice) == "number" and not ns.EquipmentSetInfo(choice) then choice = nil end
    return choice or (spec == ns.GetPlayer().spec and "worn" or "bags")
end

-- With `source` (Tip.Compare; your own class only) other than "worn", the
-- gear compared with is the best of what you wear and carry in your bags for
-- p's spec ("bags": ns.GetBestOwned) or an equipment set (ns.GetSetGear), not
-- what you wear: the same rankings, other gear. Dropped on bag and set changes too.
local function State(p, source)
    local setup = ns.GetWeaponSetupPref(p)
    local prof = ns.WeightProfiles.Resolve(p.classFile, p.spec, setup, p.weights)
    local key = table.concat({ p.classFile, p.raceId, p.spec, setup, p.level, prof and prof.id or "-" }, ":")
    states[key] = states[key] or Build(p)
    local s = not states[key].none and states[key] or nil
    if not (s and source and source ~= "worn") or s.noGear then return s end
    local sourceKey = key .. "|" .. source
    if not states[sourceKey] then
        local gear, missing
        if source == "bags" then
            -- The hands it plays now: in the line's own setup (an off spec
            -- entry's, else the window's for the spec; a weapon may be judged
            -- in another, p.setup).
            local own = Tip.Profile(p, p.spec, p.lineSetup)
            gear, missing = ns.GetBestOwned(p, { ns.GetWeaponSetupPref(own) }, ns.db.classArmorOnly)
        else
            gear = ns.GetSetGear(p, source)
        end
        if missing then loading = true end
        for _, list in pairs(gear or {}) do
            for _, w in ipairs(list) do
                if not w.item then loading = true end
            end
        end
        states[sourceKey] = setmetatable({ gear = gear or s.gear, source = source }, { __index = s })
    end
    return states[sourceKey]
end

---------------------------------------------------------------- the verdict

-- Where a score of `score` would rank in a slot's ranked list (`all`, best
-- first, item `id` itself left out): rank, and the score as a share of the best.
local function Standing(all, id, score)
    if not (all and all[1]) then return nil end
    local rank, best = 1, score
    for _, e in ipairs(all) do
        if e.id ~= id then
            if e.score > score + 0.001 then rank = rank + 1 end
            if e.score > best then best = e.score end
        end
    end
    return rank, best > 0 and score / best or 1
end

-- The slot group of a non-hand item.
local function GroupOf(item)
    for _, g in ipairs(ns.SlotGroups) do
        if g.inv and g.inv[item.slot] then return g end
    end
end

-- Why your class can never wear the item: "Wand", "Chest, Plate", "Other
-- classes only"...; nil when it can at some level.
local function CantEquip(item, p)
    if ns.CanEquip(item, p) then return nil end
    local problem = ns.EquipProblem(item, setmetatable({ level = ns.MAX_LEVEL }, { __index = p }))
    if problem == "class" then return L["Other classes only"] end
    if problem == "race" then return L["Other races only"] end
    if problem == "skill" then return L["Needs a profession skill"] end
    if problem == "type" then return ns.ItemTypeLabel(item) end
end

-- The level you can wear the item from: its required level, or the level
-- that lifts what stops you (ns.WearLevel: weapon training, mail and plate).
local function UnlockLevel(item, p)
    return math.max(item.reqLevel or 0, ns.WearLevel(item, p) or ns.MAX_LEVEL)
end

-- Ring, trinket, armor, ranged: against the worn item it would replace.
local function SlotVerdict(s, r, item, id, gainOnly)
    local g = GroupOf(item)
    if not g then return nil end
    local list, slots = s.gear[g.key] or {}, g.slots or 1
    r.score = s.score(item, g.key)
    for _, w in ipairs(list) do
        if w.id == id then r.worn = true end
    end
    if not r.worn then
        if #list < slots then
            r.empty = true
        elseif list[#list].score then
            r.base, r.vs = list[#list].score, { list[#list] }
        else
            r.loading = true
        end
    end
    r.slots, r.label = slots, ns.GroupLabel(g, s.p)
    if not gainOnly then r.list = s.ranked[g.key] and s.ranked[g.key].all end
    return r
end

-- Weapons, shields and held off-hands, judged in the spec's weapon setup that
-- uses them: the one the profile plays (the window's choice) when it does,
-- else the first of the spec's setups that does
-- (a two-hander for a dual-wielding Fury: its two-hander setup). That setup's
-- weights (Enhancement's differ per setup) score the item and your worn hands.
-- The hands you'd wear with it are compared with the hands you wear now: a
-- two-hander replaces both; in one hand, it keeps what you wear in the other
-- (but not beside a worn two-hander), or in the main hand it moves your main
-- hand to the off hand. The best of these wins for a one-hander you can dual
-- wield, and its standing is in that setup's ranked list for the hand it
-- wins in. A hand takes the weapon types the spec's abilities need there
-- (ns.SetupFits: a Subtlety rogue's main-hand dagger). When none of the
-- spec's setups uses the item, it is judged in another setup the class can
-- hold, against what you wear, with no standing (a shield for an Arms
-- warrior); r.reason when none can. For gear you can wear only later
-- (r.unlock): the setups you'll have then, as a level 5 hunter's staff in the
-- two-hander setup of level 10.
local function HandVerdict(s, r, item, id, gainOnly)
    local at = r.unlock and setmetatable({ level = r.unlock }, { __index = s.p }) or s.p
    local function Fits(key)
        return ns.SetupFits(at, key, "main", item) or ns.SetupFits(at, key, "off", item)
    end
    local setup, own = s.ranked.weapons.setup, true
    if not Fits(setup) then
        setup = nil
        local spec = {}
        for _, key in ipairs(ns.WeaponSetupOptions(at)) do spec[key] = true end
        for _, key in ipairs(ns.WeaponSetupOptions(at, true)) do
            if Fits(key) then
                setup, own = key, spec[key] == true
                break
            end
        end
    end
    if not setup then
        -- A setup holds it, but not as a weapon type the spec's abilities take.
        local set = ns.WeaponSetups[s.ranked.weapons.setup]
        if set.main[item.slot] or (set.off and set.off[item.slot]) then
            r.reason = string.format(L["Not for %s"], ns.SpecLabel(s.p.spec, s.p.classFile))
            return r
        end
        local labels = {}
        for _, key in ipairs(ns.WeaponSetupOptions(at)) do labels[#labels + 1] = ns.WeaponSetups[key].label end
        r.reason = string.format(L["Not for %s"], table.concat(labels, " / "))
        return r
    end
    if setup ~= s.ranked.weapons.setup then
        s = State(Tip.Profile(s.p, s.p.spec, setup), s.source)
        if not s then return nil end
    end
    local fitsMain, fitsOff = ns.SetupFits(at, setup, "main", item), ns.SetupFits(at, setup, "off", item)

    local main, off = s.gear.mainhand and s.gear.mainhand[1], s.gear.offhand and s.gear.offhand[1]
    if (main and not main.score) or (off and not off.score) then r.loading = true end
    local current = (main and main.score or 0) + (off and off.score or 0)
    local asMain, asOff = s.score(item, "mainhand"), s.score(item, "offhand")
    local best
    local function Consider(total, hand, a, b) -- a, b: the worn items it replaces, either may be nil
        if not best or total > best.total + 0.001 then
            local vs = {}
            if a then vs[#vs + 1] = a end
            if b then vs[#vs + 1] = b end
            best = { total = total, hand = hand, vs = vs }
        end
    end
    local mainTwoHand = main and main.item and main.item.slot == 17
    if fitsMain and item.slot == 17 then
        Consider(asMain, "mainhand", main, off)
    elseif fitsMain then
        Consider(asMain + (off and off.score or 0), "mainhand", main)
        -- Your main hand moves to the off hand (a better dagger for an Assassination rogue).
        if main and main.item and main.id ~= id and ns.SetupFits(at, setup, "off", main.item) then
            Consider(asMain + s.score(main.item, "offhand"), "mainhand", main, off)
        end
    end
    if fitsOff then
        if mainTwoHand then
            Consider(asOff, "offhand", main)
        else
            Consider((main and main.score or 0) + asOff, "offhand", off)
        end
    end
    if (main and main.id == id) or (off and off.id == id) then
        r.worn = true
    elseif #best.vs == 0 then
        r.empty, r.current = true, current -- (the hand it fills was empty; the other may not be)
    else
        r.base, r.vs = current, best.vs
    end
    r.score, r.total = best.hand == "mainhand" and asMain or asOff, best.total
    local hand = best.hand
    if own and not gainOnly and s.ranked[hand] then
        r.list, r.handScore = s.ranked[hand].all, hand == "mainhand" and asMain or asOff
        r.label = (hand == "mainhand" and setup == "twohand") and L["Two-Hand"]
            or (hand == "mainhand" and L["Main Hand"] or L["Off Hand"])
    end
    r.slots = 1
    return r
end

-- What to say about item `id` (Data/Items.lua shape `item`) for profile state
-- `s`; nil for an item that isn't gear. r.cant (your class can't equip it at
-- all) or r.reason (the profile's weapon setup doesn't use it) when it can't.
-- With `gainOnly`, no standing (r.list, r.rank): the rankings aren't made.
local function Verdict(s, item, id, gainOnly)
    if not (item and item.slot) then return nil end
    local cant = CantEquip(item, s.p)
    if cant then return { cant = cant } end
    local unlock = UnlockLevel(item, s.p)
    local r = { unlock = unlock > s.p.level and unlock or nil }
    if HAND_INV[item.slot] then
        r = HandVerdict(s, r, item, id, gainOnly)
    else
        r = SlotVerdict(s, r, item, id, gainOnly)
    end
    if not r or r.reason then return r end
    -- Nothing to compare with for another class, and gear you can't wear yet
    -- (a level 5 hunter's mail) isn't an upgrade over what you wear now.
    if s.noGear then r.worn = nil end
    if s.noGear or r.unlock then r.empty, r.base, r.vs = nil, nil, nil end
    if r.base then
        r.delta = (r.total or r.score) - r.base
    elseif r.empty then
        r.delta = (r.total or r.score) - (r.current or 0)
    end
    if r.list and not r.unlock then
        r.rank, r.ratio = Standing(r.list, id, r.handScore or r.score)
    end
    return r
end

-- The verdict on item `id` (its `link` when known) for profile `p` (your
-- character by default), as the block shows it for p's spec; nil for an item
-- that isn't gear, or without stat weights. (QuestWindow.lua picks with it.)
-- `gainOnly`: as Verdict's.
function Tip.Verdict(id, link, p, gainOnly)
    p = p or ns.GetPlayer()
    local s = State(p, p.compare or Tip.Compare(p.spec))
    return s and Verdict(s, ns.LinkItem(id, link), id, gainOnly)
end

-- What item `id` (its `link` when known) gains profile `p` (your character
-- by default) over the gear p's spec is compared with, as its tooltip says:
-- 0 for an item in that gear, at least UPGRADE for one that fills an empty
-- slot; nil when p can't wear it now (or, with Armor
-- type: Class type, it is lighter armor) or it isn't gear. Second result:
-- true when that can't be told yet (the item, or your worn gear, still
-- loading). The marks on quest rewards (QuestWindow.lua) and bag items
-- (BagMarks.lua) go by it.
function Tip.Gain(id, link, p)
    p = p or ns.GetPlayer()
    local item = ns.LinkItem(id, link)
    if not item then
        local Cached = C_Item and C_Item.IsItemDataCachedByID
        return nil, Cached ~= nil and not Cached(id)
    end
    local r = Tip.Verdict(id, link, p, true)
    if not r or r.cant or r.reason or r.unlock then return nil end
    if ns.db.classArmorOnly and ns.IsLighterArmor(item, p) then return nil end
    if r.worn then return 0 end
    if r.loading or not r.delta then return nil, true end
    -- Anything you can wear beats an empty slot, even with no stat the spec
    -- values (a white chest for a mage, whose weights give armor nothing).
    if r.empty then return math.max(r.delta, UPGRADE) end
    return r.delta
end

---------------------------------------------------------------- drawing

-- "+6.1  (+8%)": the gain, and its share of what it replaces when that says something.
local function DeltaText(d, base)
    local text = string.format("%+.1f", d)
    local pct = base and base > 0 and d / base * 100
    if pct and math.abs(pct) >= 1 and math.abs(pct) < 1000 then
        text = text .. string.format("  (%+d%%)", pct < 0 and math.ceil(pct - 0.5) or math.floor(pct + 0.5))
    end
    return text
end

-- The gain itself: a green up arrow and "+6.1" (with `base`, its share of
-- it too), a red down arrow and the loss, or a grey 0.0.
local function GainText(d, base)
    if d >= UPGRADE then return Icon("TipUp", GREEN) .. " " .. Color(GREEN, DeltaText(d, base)) end
    if d <= -UPGRADE then return Icon("TipDown", RED) .. " " .. Color(RED, DeltaText(d, base)) end
    return Color(GREY, "0.0")
end

local function VsText(r)
    if not r.vs then return "" end
    if #r.vs > 1 then return Color(GREY, L["vs both hands"]) end
    return Color(GREY, string.format(L["vs %s"], ns.WornItemName(r.vs[1])))
end

-- The item is in the gear compared with (Tip.Compare's `source`): Equipped,
-- the best you have, or in the set.
local function HaveText(source)
    if source == "bags" then return L["Best you have"] end
    if type(source) == "number" then return string.format(L["In %s"], ns.EquipmentSetInfo(source) or "?") end
    return L["Equipped"]
end

-- A line (two columns with `right`); its colors are in the text.
local function Line(tooltip, left, right)
    if right then tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1) else tooltip:AddLine(left, 1, 1, 1) end
end

-- Puts the tooltip's lines from line `first` on in the font of its body text
-- (line 2): GameTooltipText, or a UI addon's own. A tooltip reuses its text
-- lines from item to item, and a font set on a line stays: EllesmereUI sets
-- its smaller font on the lines a tooltip has when it shows, so the block
-- would change size partway down. SetFont, as SetFontObject doesn't undo a
-- font set that way. (UI.lua calls it for the lines it adds under the block too.)
function Tip.NormalFont(tooltip, first)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return end
    local body = first > 2 and _G[name .. "TextLeft2"]
    local path, size, flags
    if body then path, size, flags = body:GetFont() end
    if not path and GameTooltipText then path, size, flags = GameTooltipText:GetFont() end
    if not path then return end
    for n = first, tooltip:NumLines() do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = _G[name .. side .. n]
            if fs then fs:SetFont(path, size, flags or "") end
        end
    end
end

-- Every spec gets a row of the same shape, so the columns line up: a bar at
-- the left edge for how close the item comes to the best you can get for the
-- slot (in My gear's colors; full and orange, with a star after the name, for
-- the best in slot; empty when that doesn't apply), the spec's icon and name,
-- and on the right its score (or why it isn't for the spec). The boxes' other
-- text starts in one column, under the spec names (INDENT is as wide as the
-- bar), so it reads as one piece: the main spec's lines, Can't equip. Those
-- lines put their icon where the spec icon is and their text where the spec
-- name is; a line without an icon leaves the icon's place blank (ICON_SLOT,
-- the size of an icon in text and its space). The upgrade arrow is drawn
-- over the gain line's ICON_SLOT (ShowUpgrade). The gap after the bar is a
-- blank of fixed width, not spaces (their width depends on the font).
local GAP_WIDTH = 7
local GAP = "|T" .. MEDIA .. "Blank:1:" .. GAP_WIDTH .. "|t"
local INDENT = "|T" .. MEDIA .. "Blank:1:" .. BAR_WIDTH .. "|t" .. GAP
local ICON_BLANK = "|T" .. MEDIA .. "Blank:0|t" -- as big as an icon in text
local ICON_SLOT = ICON_BLANK .. " "
-- The header (logo and title) starts at the left edge, over the bars.
local LOGO_SIZE = 14
local HEADER = "|T" .. MEDIA .. "Icon:" .. LOGO_SIZE .. ":" .. LOGO_SIZE .. "|t" .. GAP
local LIGHT = { 200, 200, 200 } -- other specs' scores, under the main one's white

local function IsBest(r)
    return r.rank ~= nil and r.rank <= r.slots and not r.unlock
end

local function RowBar(r)
    if IsBest(r) then return Bar(1, BIS) end
    if r.ratio and not r.unlock then return Bar(r.ratio, TierColor(r.ratio)) end
    return Bar(0, TRACK)
end

local function SpecRow(tooltip, label, r, right)
    Line(tooltip, RowBar(r) .. GAP .. label .. (IsBest(r) and (" " .. Icon("TipStar", BIS)) or ""), right)
end

-- The main spec's standing in words, under its row: the share of the best
-- (and on the right, the rank), Best in slot, or the level you can wear it from.
local function StandingText(r)
    if r.unlock then return Color(ORANGE, string.format(L["Usable at level %d"], r.unlock)) end
    if IsBest(r) then return Color(BIS, L["Best in slot"]) end
    if r.ratio then
        return Color(TierColor(r.ratio), string.format(L["%d%% of best"], math.floor(r.ratio * 100))),
            r.rank and Color(GREY, string.format(L["#%d %s"], r.rank, r.label))
    end
end

-- `main`: { label, r, source } (r: the spec's verdict, against the gear
-- `source`, Tip.Compare); each of `offs`: { label, r, source }. Returns
-- where the boxes go: { boxes = { { first line, last line } }, spacers = { line },
-- band = { first line, last line }, upgrade = the main spec's gain line when
-- the item is an upgrade for it }. `plain`: text only, for a tooltip with no
-- boxes or band (Tip.AddLines): the upgrade's arrow is in its line's text,
-- and the only spacers are a blank line before the title and between the boxes.
local function Draw(tooltip, main, offs, plain)
    local layout = { boxes = {}, spacers = {} }
    local top, head
    local UP_SLOT = plain and (Icon("TipUp", GREEN) .. " ") or ICON_SLOT -- (else ShowUpgrade's arrow goes there)
    -- A spacer line (ShowBoxes makes it short) before each box, and one after the last.
    local function Spacer()
        Line(tooltip, " ")
        layout.spacers[#layout.spacers + 1] = tooltip:NumLines()
    end
    local function Open()
        if not plain or #layout.boxes > 0 then Spacer() end
        top = tooltip:NumLines() + 1
    end
    local function Close()
        layout.boxes[#layout.boxes + 1] = { top, tooltip:NumLines() }
    end
    -- The band runs from the title to the spacer under the last box.
    local function Finish()
        if not plain then Spacer() end
        layout.band = { head, tooltip:NumLines() }
        return layout
    end

    local r = main.r
    Line(tooltip, " ")
    Line(tooltip, HEADER .. Color(GOLD, "WildGear"))
    head = tooltip:NumLines()
    Open()
    if r.cant then
        -- Your class can't wear it in any spec: nothing more to say.
        Line(tooltip, INDENT .. CROSS .. " " .. Color(RED, L["Can't equip"]), Color(GREY, r.cant))
        Close()
        return Finish()
    end

    -- Your main spec: its row, then the item against the gear it is compared
    -- with, and its standing.
    SpecRow(tooltip, main.label, r, r.reason and "" or string.format("%.1f", r.score))
    if r.reason then
        Line(tooltip, INDENT .. CROSS .. " " .. Color(RED, r.reason))
    else
        if r.worn then
            Line(tooltip, INDENT .. CHECK .. " " .. Color(BLUE, HaveText(main.source)))
        elseif r.empty then
            Line(tooltip, INDENT .. UP_SLOT .. Color(GREEN, string.format("%+.1f", r.delta)),
                Color(GREY, L["Fills an empty slot"]))
            layout.upgrade = tooltip:NumLines()
        elseif r.delta and not r.loading and r.delta >= UPGRADE then
            Line(tooltip, INDENT .. UP_SLOT .. Color(GREEN, DeltaText(r.delta, r.base)), VsText(r))
            layout.upgrade = tooltip:NumLines()
        elseif r.delta and not r.loading then
            Line(tooltip, INDENT .. GainText(r.delta, r.base), VsText(r))
        end
        local standing, rank = StandingText(r)
        if standing then Line(tooltip, INDENT .. ICON_SLOT .. standing, rank) end
    end
    Close()

    -- Other specs, in their own box: a row each, its score after the gain
    -- over the gear it is compared with, or the level it can be worn from.
    -- An item already in that gear says so in the main spec's words ("Best
    -- you have", "In" the set), without the check: for an off spec it isn't
    -- "equipped", worn or not.
    if #offs == 0 then return Finish() end
    Open()
    for _, o in ipairs(offs) do
        local right, or_ = nil, o.r
        if or_.reason then
            right = Color(GREY, or_.reason)
        else
            right = Color(LIGHT, string.format("%.1f", or_.score))
            if or_.unlock then
                right = Color(ORANGE, string.format(L["lvl %d"], or_.unlock)) .. GAP .. right
            elseif or_.worn then
                right = Color(BLUE, HaveText(o.source)) .. GAP .. right
            elseif or_.delta and not or_.loading then
                right = GainText(or_.delta) .. GAP .. right
            end
        end
        SpecRow(tooltip, o.label, or_, right)
    end
    Close()
    return Finish()
end

---------------------------------------------------------------- boxes

-- Each box is a faint panel with a thin border, drawn on the tooltip itself
-- (its BORDER layer: over the tooltip's background, under its text). It is
-- pinned to its first and last lines, so it follows them whatever their font,
-- and reaches BOX_X left of them (the bars' edge) and BOX_Y above and below.
-- Its right edge stays BOX_X in from the tooltip's as the tooltip resizes.
-- The spacer lines before each box and after the last are SPACER points high.
-- Under the boxes, the whole block (from BAND_Y above the title to the last
-- spacer) sits on a band of faint warm tint, BAND_X in from the tooltip's
-- edges, down to its bottom while nothing follows the block. Boxes and bands
-- are hidden when the tooltip is cleared. On an upgrade for the main spec, its
-- box is green and the gain line's arrow moves (ShowUpgrade).
-- It is all anchors: Lua never reads a size or position, which Midnight makes
-- secret when a line's text is (arithmetic on them errors).
local BOX_X, BOX_Y, SPACER = 5, 3, 6
local BAND_X, BAND_Y = 1, 4
-- [tooltip] = { box, ..., used = boxes shown, bands = { band }, bandsUsed = bands shown, spacers = { line },
-- upgrade = the upgrade's arrow and motion, made on first use }
local boxSets = {}

-- An invisible texture to anchor to. Pinned by two opposite corners, one to a
-- line and one to the tooltip, it lends a third corner that takes its x from
-- the tooltip and its y from the line, as a single anchor can't.
local function NewCorner(tooltip)
    local t = tooltip:CreateTexture(nil, "BORDER")
    t:SetAlpha(0)
    return t
end

local function NewBox(tooltip)
    local b = { fill = tooltip:CreateTexture(nil, "BORDER", nil, 6), edges = {}, corner = NewCorner(tooltip) }
    for i = 1, 4 do b.edges[i] = tooltip:CreateTexture(nil, "BORDER", nil, 7) end
    return b
end

-- A box's colors: faint white, or (`green`) the quest panel's best-pick green.
local function Paint(b, green)
    local r, g, bl = 1, 1, 1
    if green then r, g, bl = Rgb(GREEN) end
    b.fill:SetColorTexture(r, g, bl, green and 0.12 or 0.06)
    for _, e in ipairs(b.edges) do e:SetColorTexture(r, g, bl, green and 0.9 or 0.15) end
end

-- The upgrade's motion: the arrow rises BOB points and back every BOB_TIME
-- seconds, starting BOB_LOW under its spot (it stays clear of the spec icon above).
local BOB, BOB_LOW, BOB_TIME = 3, -1, 1

-- One frame of the motion, timed from when the tooltip started showing the
-- item (u.start), not from when it was last drawn: a tooltip refreshes by
-- clearing and drawing again (a bag item's five times a second), and the
-- motion carries on through it. A tooltip hidden and shown again without
-- being drawn again (as when an item is equipped) has no u.start: the motion
-- starts over.
local function Animate(u)
    u.start = u.start or GetTime()
    local up = 0.5 - 0.5 * math.cos(2 * math.pi * (GetTime() - u.start) / BOB_TIME) -- 0 to 1 and back
    u.arrow:SetPoint("CENTER", u.line, "LEFT", u.column + u.icon / 2, BOB_LOW + BOB * up)
    u.glow:SetAlpha(0.2 + 0.5 * up)
end

-- The green up arrow over the gain line's ICON_SLOT, on a soft green glow.
-- On a frame of its own over the tooltip, which drives the motion.
local function NewUpgrade(tooltip)
    local u = CreateFrame("Frame", nil, tooltip)
    u:SetAllPoints()
    u:Hide()
    u.arrow = u:CreateTexture(nil, "OVERLAY")
    u.arrow:SetTexture(MEDIA .. "TipUp")
    u.arrow:SetVertexColor(Rgb(GREEN))
    u.glow = u:CreateTexture(nil, "ARTWORK")
    u.glow:SetTexture(MEDIA .. "Glow")
    u.glow:SetBlendMode("ADD")
    u.glow:SetVertexColor(Rgb(GREEN))
    u.glow:SetPoint("CENTER", u.arrow, "CENTER")
    u.ruler = u:CreateFontString(nil, "OVERLAY") -- (measures text: Measure)
    u.ruler:SetPoint("TOPLEFT")
    u.ruler:SetAlpha(0)
    u:SetScript("OnUpdate", Animate)
    return u
end

-- The width of `text` in the font of tooltip line `line`, in the units
-- anchors use; nil when it can't be known.
local function Measure(u, line, text)
    local path, size, flags = line:GetFont()
    if not path then return nil end
    u.ruler:SetFont(path, size, flags or "")
    u.ruler:SetText(text)
    local width = u.ruler:GetStringWidth()
    if type(width) ~= "number" or (issecretvalue and issecretvalue(width)) or width <= 0 then return nil end
    return width
end

-- Shows the upgrade's arrow on gain line `line`. The arrow goes where the
-- line's ICON_SLOT is, as big as an icon in its text
-- (the arrow fills 26/32 of its texture). Both are measured in the line's
-- font, not taken from BAR_WIDTH and GAP_WIDTH: a size in a text's |T and an
-- anchor's offset needn't be in the same units (in the game, an arrow placed
-- 55 from the line's edge sat 11 right of the 55-wide INDENT). The motion
-- starts over only for another item (`key`) or once the tooltip has been hidden.
local function ShowUpgrade(tooltip, set, line, key)
    set.upgrade = set.upgrade or NewUpgrade(tooltip)
    local u = set.upgrade
    if not u.start or u.key ~= key then u.start, u.key = GetTime(), key end
    u.line = line
    u:Show()
    u.column = Measure(u, line, INDENT) or (BAR_WIDTH + GAP_WIDTH)
    u.icon = Measure(u, line, ICON_BLANK) or 13
    u.arrow:SetSize(u.icon * 32 / 26, u.icon * 32 / 26)
    u.glow:SetSize(u.icon * 2.4, u.icon * 2.4)
    Animate(u)
end

local function NewBand(tooltip)
    local fill = tooltip:CreateTexture(nil, "BORDER", nil, 5)
    fill:SetColorTexture(1, 0.6, 0.2, 0.08) -- light orange
    return { fill = fill, top = NewCorner(tooltip), bottom = NewCorner(tooltip) }
end

-- The box's border, `px` thick (the side edges stop short of the corners, so
-- the corners aren't drawn twice).
local function Outline(b, px)
    local top, bottom, left, right = b.edges[1], b.edges[2], b.edges[3], b.edges[4]
    top:SetPoint("TOPLEFT", b.fill)
    top:SetPoint("TOPRIGHT", b.fill)
    top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", b.fill)
    bottom:SetPoint("BOTTOMRIGHT", b.fill)
    bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", b.fill, "TOPLEFT", 0, -px)
    left:SetPoint("BOTTOMLEFT", b.fill, "BOTTOMLEFT", 0, px)
    left:SetWidth(px)
    right:SetPoint("TOPRIGHT", b.fill, "TOPRIGHT", 0, -px)
    right:SetPoint("BOTTOMRIGHT", b.fill, "BOTTOMRIGHT", 0, px)
    right:SetWidth(px)
end

-- Ends each band at the tooltip's bottom while nothing follows its block,
-- else under the block's last line.
local function FitBands(tooltip)
    local set = boxSets[tooltip]
    if not set then return end
    for i = 1, set.bandsUsed do
        local b = set.bands[i]
        if tooltip:NumLines() == b.lastLine then
            b.fill:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -BAND_X, BAND_X)
        else
            b.fill:SetPoint("BOTTOMRIGHT", b.bottom, "BOTTOMRIGHT")
        end
    end
end

-- Takes the boxes, bands and arrow off and gives the spacer lines their font
-- back: the tooltip's next lines reuse them. (Only while a line still has the
-- spacer's size: one EllesmereUI fonted since keeps its font.)
local function Unplace(set)
    for _, b in ipairs(set) do
        b.fill:Hide()
        for _, e in ipairs(b.edges) do e:Hide() end
    end
    for _, b in ipairs(set.bands) do b.fill:Hide() end
    for _, s in ipairs(set.spacers) do
        local _, size = s.line:GetFont()
        if size and math.abs(size - SPACER) <= 0.5 then s.line:SetFont(s.path, s.size, s.flags) end
    end
    if set.upgrade then set.upgrade:Hide() end
    set.used, set.bandsUsed, set.spacers = 0, 0, {}
end

local function HideBoxes(tooltip)
    local set = boxSets[tooltip]
    if not set then return end
    Unplace(set)
    set.blocks = {}
end

-- Puts the spacer lines in their small font. True when one wasn't in it:
-- EllesmereUI sets its font on every line when the tooltip shows.
local function SpacerFont(tooltip)
    local set = boxSets[tooltip]
    local changed = false
    for _, s in ipairs(set and set.spacers or {}) do
        local path, size, flags = s.line:GetFont()
        if path and math.abs(size - SPACER) > 0.5 then
            s.line:SetFont(path, SPACER, flags or "")
            changed = true
        end
    end
    return changed
end

-- Draws the spacers, boxes, band and arrow of a block's `layout` (Draw) on its
-- lines, after any already drawn (`key`: the item, as the tooltip shows it).
local function Place(tooltip, set, layout, key)
    local name = tooltip:GetName()
    local function At(n) return _G[name .. "TextLeft" .. n] end
    for _, n in ipairs(layout.spacers) do
        local line = At(n)
        local path, size, flags
        if line then path, size, flags = line:GetFont() end
        if path then set.spacers[#set.spacers + 1] = { line = line, path = path, size = size, flags = flags or "" } end
    end
    SpacerFont(tooltip)
    local px = PixelUtil and PixelUtil.GetNearestPixelSize(1, tooltip:GetEffectiveScale(), 1) or 1
    for i, lines in ipairs(layout.boxes) do
        local first, last = At(lines[1]), At(lines[2])
        if first and last then
            set.used = set.used + 1
            set[set.used] = set[set.used] or NewBox(tooltip)
            local b = set[set.used]
            b.fill:SetPoint("TOPLEFT", first, "TOPLEFT", -BOX_X, BOX_Y)
            b.corner:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT", 0, -BOX_Y)
            b.corner:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -BOX_X, 0)
            b.fill:SetPoint("BOTTOMRIGHT", b.corner, "BOTTOMRIGHT")
            Outline(b, px)
            Paint(b, i == 1 and layout.upgrade ~= nil)
            b.fill:Show()
            for _, e in ipairs(b.edges) do e:Show() end
        end
    end
    if layout.upgrade and At(layout.upgrade) then ShowUpgrade(tooltip, set, At(layout.upgrade), key) end
    local head, last = layout.band and At(layout.band[1]), layout.band and At(layout.band[2])
    if head and last then
        set.bandsUsed = set.bandsUsed + 1
        set.bands[set.bandsUsed] = set.bands[set.bandsUsed] or NewBand(tooltip)
        local b = set.bands[set.bandsUsed]
        b.lastLine = layout.band[2]
        b.top:SetPoint("TOPRIGHT", head, "TOPLEFT", 0, BAND_Y)
        b.top:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", BAND_X, 0)
        b.fill:SetPoint("TOPLEFT", b.top, "TOPLEFT")
        b.bottom:SetPoint("BOTTOMLEFT", last, "BOTTOMLEFT")
        b.bottom:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -BAND_X, 0)
        b.fill:Show()
    end
    FitBands(tooltip)
end

-- A line's text, or nil when it has none or it is secret (Midnight: never compared).
local function Readable(text)
    if issecretvalue and issecretvalue(text) then return nil end
    return type(text) == "string" and text or nil
end

-- The line nearest to `index` whose text is `text`; nil when none is.
local function FindLine(name, total, index, text)
    for d = 0, total do
        for _, n in ipairs(d == 0 and { index } or { index - d, index + d }) do
            local line = n >= 1 and n <= total and _G[name .. "TextLeft" .. n]
            if line and Readable(line:GetText()) == text then return n end
        end
    end
end

-- Moves every line of a block's `layout` `by` lines.
local function ShiftLayout(layout, by)
    for i, n in ipairs(layout.spacers) do layout.spacers[i] = n + by end
    for _, lines in ipairs(layout.boxes) do lines[1], lines[2] = lines[1] + by, lines[2] + by end
    if layout.band then layout.band[1], layout.band[2] = layout.band[1] + by, layout.band[2] + by end
    if layout.upgrade then layout.upgrade = layout.upgrade + by end
end

-- Another addon may move the tooltip's lines after the block is drawn without
-- clearing it: ItemTree keeps its "... for the full tree" hint the last line
-- by writing each line's text one line up (fonts stay put). The spacers' small
-- font and the boxes are on the lines, not their text, so they then sat one
-- line off, the spec rows in the spacers' tiny font. So each block's title is
-- looked for after every Show: when it moved, the block's lines move with it
-- (a Gap, without a title, with the block before it); when it is gone, the
-- boxes go.
local following
local function Follow(tooltip)
    local set = boxSets[tooltip]
    if following or not (set and set.blocks[1]) then return end
    local name, total = tooltip.GetName and tooltip:GetName(), tooltip:NumLines()
    if not (name and total) then return end
    local by, moved = 0, false
    for _, block in ipairs(set.blocks) do
        if block.text then
            local at = FindLine(name, total, block.head, block.text)
            if not at then return HideBoxes(tooltip) end
            by, block.head = at - block.head, at
        end
        if by ~= 0 then
            ShiftLayout(block.layout, by)
            moved = true
        end
    end
    if not moved then return end
    following = true
    local ok, err = pcall(function()
        Unplace(set)
        for _, block in ipairs(set.blocks) do Place(tooltip, set, block.layout, block.key) end
        pcall(tooltip.Show, tooltip) -- (Show fits the lines again)
    end)
    following = false
    if not ok then error(err, 0) end
end

-- Shows the boxes and band of a block's `layout` (Draw), after any already
-- shown, and the upgrade's arrow and green box when it is one (`key`: the
-- item, as the tooltip shows it).
local function ShowBoxes(tooltip, layout, key)
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return end
    local set = boxSets[tooltip]
    if not set then
        set = { used = 0, bands = {}, bandsUsed = 0, spacers = {}, blocks = {} }
        boxSets[tooltip] = set
        tooltip:HookScript("OnTooltipCleared", HideBoxes)
        tooltip:HookScript("OnSizeChanged", function(t)
            Follow(t)
            FitBands(t)
        end)
        tooltip:HookScript("OnShow", function(t)
            if SpacerFont(t) then pcall(t.Show, t) end -- (Show fits the lines again)
        end)
        tooltip:HookScript("OnHide", function()
            if set.upgrade then set.upgrade.start = nil end -- (the next hover starts the motion over)
        end)
        -- (ItemTree's move ends with a Show that needn't change the size)
        if tooltip.Show then hooksecurefunc(tooltip, "Show", Follow) end
    end
    local block = { layout = layout, key = key }
    local head = layout.band and _G[name .. "TextLeft" .. layout.band[1]]
    if head then block.head, block.text = layout.band[1], Readable(head:GetText()) end
    set.blocks[#set.blocks + 1] = block
    Place(tooltip, set, layout, key)
end

---------------------------------------------------------------- hooks

-- Whether the tooltip belongs to the window, one of its side panels or a
-- frame of ours elsewhere that adds the block itself (owns.addsBlock: My gear
-- beside the Character frame), as their rows do (UI.lua ShowItemTooltip).
local function FromWindow(tooltip)
    local main = ns.UI and ns.UI.Frame and ns.UI.Frame()
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    while owner do
        if (main and owner == main) or owner.addsBlock then return true end
        owner = owner.GetParent and owner:GetParent()
    end
    return false
end

local function DisplayedLink(tooltip)
    if TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, link = TooltipUtil.GetDisplayedItem(tooltip)
        if link then return link end
    end
    if tooltip.GetItem then return select(2, tooltip:GetItem()) end
end

-- What the block says about item `id` for profile `p`: its main spec's line
-- and its off specs' (as Draw takes them), nil when there's nothing to say.
local function Lines(id, link, p)
    local item = ns.LinkItem(id, link)
    local source = Tip.Compare(p.spec)
    local s = State(p, source)
    local r = s and Verdict(s, item, id)
    if not r then return nil end
    local main = { r = r, source = source }
    local lines, offs = { p }, {}
    if not r.cant and OwnClass(p) then
        for _, e in ipairs(Tip.OffEntries(p)) do
            local ep = Tip.EntryProfile(p, e)
            local os = State(ep, ep.compare)
            local or_ = os and Verdict(os, item, id)
            if or_ then
                lines[#lines + 1] = ep
                offs[#offs + 1] = { r = or_, source = ep.compare }
            end
        end
    end
    local labels = Tip.LineLabels(lines)
    main.label = labels[1]
    for i, o in ipairs(offs) do o.label = labels[i + 1] end
    return main, offs
end

-- Adds the block for item `id` (its `link` when known: random suffixes, items
-- the data lacks) to `tooltip`, for profile `p`: your character by default,
-- or the profile the window shows (another class gets no comparison with your
-- gear, nor your off specs). Returns the main spec's verdict, nil when
-- nothing was added (not gear, or no stat weights).
function Tip.AddBlock(tooltip, id, link, p)
    p = p or ns.GetPlayer()
    local main, offs = Lines(id, link, p)
    if not main then return nil end
    local first = tooltip:NumLines() + 1
    local layout = Draw(tooltip, main, offs)
    Tip.NormalFont(tooltip, first)
    ShowBoxes(tooltip, layout, link or id)
    return main.r
end

-- The block as text only, on a tooltip of another addon's that has no lines
-- of the game's tooltip to put boxes on (Dialogue UI's: DialogueUI.lua). It
-- takes AddLine and AddDoubleLine, and a blank line with AddBlankLine when it
-- has one (a line of " " would be as tall as text). Returns the main spec's
-- verdict, nil when nothing was added.
function Tip.AddLines(tooltip, id, link, p)
    p = p or ns.GetPlayer()
    local main, offs = Lines(id, link, p)
    if not main then return nil end
    local n = 0
    local out = {}
    function out.NumLines() return n end
    function out.AddLine(_, text, ...)
        n = n + 1
        if text == " " and tooltip.AddBlankLine then return tooltip:AddBlankLine() end
        return tooltip:AddLine(text, ...)
    end
    function out.AddDoubleLine(_, ...)
        n = n + 1
        return tooltip:AddDoubleLine(...)
    end
    Draw(out, main, offs, true)
    return main.r
end

-- ItemTree keeps its "... for the full tree" hint the tooltip's last line,
-- moving it under the lines added after its block (Follow), but only on the
-- next frame or a resize: an equipped or bag item's tooltip is filled again
-- every 0.2 s, and each time it was drawn once with the hint above the block,
-- so the block, its band's foot and ItemTree's rule flickered. So it is asked
-- to move it now, after the block's last lines and before the tooltip's Show.
function Tip.HintLast(tooltip)
    local itemTree = rawget(_G, "ItemTree")
    local module = type(itemTree) == "table" and rawget(itemTree, "Tooltip")
    local keep = type(module) == "table" and module.KeepHintLast
    if type(keep) == "function" then pcall(keep, tooltip) end
end

-- A short spacer line under the block, so lines added after it (UI.lua)
-- don't sit on the band's bottom edge.
function Tip.Gap(tooltip)
    Line(tooltip, " ")
    ShowBoxes(tooltip, { boxes = {}, spacers = { tooltip:NumLines() } })
end

local function Annotate(tooltip)
    local link = DisplayedLink(tooltip)
    local id = link and tonumber(link:match("item:(%d+)"))
    -- (Already on this fill when it went in ahead of ItemTree's block: AheadOfItemTree.)
    local set = boxSets[tooltip]
    if id and set and set.blocks[1] and set.link == link then return end
    if not (id and Tip.AddBlock(tooltip, id, link)) then return end
    boxSets[tooltip].link = link
    -- The best pick in the game's quest windows says why (QuestWindow.lua), as the window's rows do.
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    local lines = owner and ns.QuestWindow and ns.QuestWindow.TipLines(owner)
    if lines and lines[1] then
        Tip.Gap(tooltip)
        local first = tooltip:NumLines() + 1
        for _, text in ipairs(lines) do tooltip:AddLine(text, 1, 1, 1, true) end
        Tip.NormalFont(tooltip, first)
    end
    Tip.HintLast(tooltip)
    tooltip:Show() -- (Show fits the new lines)
end

local reported -- a broken hook would error on every hover: report the first error only
local function OnItem(tooltip)
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end -- (not the comparison tooltips)
    if not (ns.db and ns.charDB) or ns.db.tooltip == false or FromWindow(tooltip) then return end
    local ok, err = pcall(Annotate, tooltip)
    if not ok and not reported then
        reported = true
        if geterrorhandler then geterrorhandler()(err) else error(err) end
    end
end

-- ItemTree's block is meant to be a tooltip's last (its "... for the full
-- tree" hint the last line), and it places its rule by measuring the lines as
-- the tooltip is filled: lines added under it moved the hint (Follow) and made
-- the rule jump for a frame each time the game filled the tooltip again (bag
-- items, every 0.2 s). So with ItemTree, the block goes in just before ItemTree
-- draws its own: ItemTree's item pass (looked up on every call) runs ours first.
-- Our own post call then finds the block there and leaves it. It also checks
-- the wrap is still in place on every item tooltip (ItemTree may set its item
-- pass again after login), and puts it back if not; without ItemTree, or
-- without that pass, nothing is done and the block goes under ItemTree's.
local wrapped -- (our wrap of ItemTree's item pass)
local function AheadOfItemTree()
    local itemTree = rawget(_G, "ItemTree")
    local module = type(itemTree) == "table" and rawget(itemTree, "Tooltip")
    local draw = type(module) == "table" and rawget(module, "OnItem")
    if type(draw) ~= "function" or draw == wrapped then return end
    wrapped = function(tooltip, data, source, ...)
        if source == nil or source == "item" then OnItem(tooltip) end
        return draw(tooltip, data, source, ...)
    end
    module.OnItem = wrapped
end

local function PostCall(tooltip)
    AheadOfItemTree()
    OnItem(tooltip)
end

-- Hooks run in the order they were added, so the block goes under the lines
-- of addons that hook items at load or at login (Syndicator's item counts,
-- Auctionator's prices): it is added a frame after login.
local function Hook()
    AheadOfItemTree()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, PostCall)
    else
        for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tooltip and tooltip.HookScript then tooltip:HookScript("OnTooltipSetItem", PostCall) end
        end
    end
end

-- Talents swapped (or maybe: any talent event, and at login): the main spec
-- follows, when the active set is linked to another line; else only Settings
-- changes (its dot on the active set). Tip.SyncTalents does nothing when the
-- main spec's line has the active set already, so extra calls are free.
local function TalentsChanged()
    if Tip.SyncTalents() then
        local p = ns.GetPlayer()
        ns.Printf(L["Main spec: %s"], Tip.SpecLabel(p, p.spec) .. " · " .. ns.WeaponSetups[ns.GetWeaponSetupPref(p)].label)
        ns.QuestWindow.Refresh()
        ns.UI.Refresh()
    else
        ns.Settings.Update()
    end
end

-- The talent events: Blizzard's own talent window on Forever (Camelot's
-- Blizzard_ClassTalentsFrame on the shared one) ends a swap on
-- ACTIVE_COMBAT_CONFIG_CHANGED, reading GetActiveSpecGroup() then, and
-- refreshes on PLAYER_TALENT_UPDATE; it never listens for
-- ACTIVE_TALENT_GROUP_CHANGED, which the client documents but nobody has
-- seen fire on Forever. So all three, and a check at login (a swap the events
-- missed).
local TALENT_EVENTS = { ACTIVE_TALENT_GROUP_CHANGED = true, ACTIVE_COMBAT_CONFIG_CHANGED = true,
    PLAYER_TALENT_UPDATE = true }

local events = CreateFrame("Frame")
-- (Skills: Player.lua calls UI.Refresh, and so Tip.Invalidate, only when one changes what you can wear.)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "EQUIPMENT_SETS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_TALENT_UPDATE" }) do
    pcall(events.RegisterEvent, events, e)
end
events.flbisTalents = true -- (the dev addon's fake talent swap sends its event here)
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local function Login()
            Hook()
            TalentsChanged()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, Login) else Login() end
    elseif TALENT_EVENTS[event] then
        TalentsChanged()
    elseif event == "BAG_UPDATE_DELAYED" or event == "EQUIPMENT_SETS_CHANGED" then
        -- Only the states with gear other than what you wear (a set's items
        -- may be in your bags): the rest don't change.
        for key in pairs(states) do
            if key:find("|", 1, true) then states[key] = nil end
        end
    -- Any item loading would rebuild far too often: only while worn gear waits on one.
    elseif event ~= "GET_ITEM_INFO_RECEIVED" or loading then
        Tip.Invalidate()
    end
end)
