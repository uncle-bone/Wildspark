local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Stat weights per class and spec, in "points per 1 of the stat".
-- Keys match the Wowhead stat keys in Data/Items.lua, plus three weapon keys:
--   dps       = weapon DPS for main hand / two-hand slots
--   ohDps     = weapon DPS in the off hand (dual wield); half of dps without one
--   rangedDps = weapon DPS for ranged slots (bows, guns, crossbows, thrown, wands)
-- and a speed weight for each: speed, ohSpeed, rangedSpeed = the score of
-- +0.1 s of that weapon's speed at the same DPS (positive: slower is better).
-- A weapon's speed counts from the speed the weight was measured at,
-- speedRef / ohSpeedRef / rangedSpeedRef in the same table (the model's worn
-- weapon), else ns.SPEED_REF's for its kind: a weapon at that speed scores
-- as on its DPS alone (ns.SpeedScore).
--
-- Each spec has a list of brackets; the first whose `upTo` >= player level wins.
-- A spec whose weapon setups value stats differently (Enhancement: two-hander
-- with Windfury, one-hander and shield with Flametongue) also has
-- `setups = { [setupKey] = { brackets = {...} } }` for its other setups, and
-- every bracket then carries `scale`: kills per hour per point of weight
-- (tools/statmodel's; the addon doesn't use it).
-- `source` says where the numbers come from; "placeholder" is a rough
-- Classic-style starting point to be replaced with real per-level values, and
-- "model" means Data/ModelWeights.lua (tools/statmodel), which replaces the
-- placeholder for every spec it covers.
--
-- On Forever, gear hit, crit, expertise, dodge, parry and block are flat "+X%"
-- equip effects, so items carry them as hitPct, critPct, expPct, dodgePct,
-- parryPct and blockPct (per 1%), and ranged-only hit ("with ranged weapons",
-- Infernal Trickster Leggings) as rhitPct. hitPct and critPct are weighted by
-- ns.HitPctWeight and ns.CritPctWeight below; the others are ordinary stat
-- weights. The rating keys (hitrtng...) stay for the model and for worn items
-- the game reports.

-- Arms and Fury share one set for now.
local warriorDps = {
    str = 2.0, atkpwr = 1.0, agi = 0.6, hitrtng = 0.7, critstrkrtng = 0.6, hastertng = 0.5,
    expPct = 5, sta = 0.2, armor = 0.01, dps = 14,
}

-- Per-1% expertise, dodge, parry and block are rating weights times the
-- gear-planner's level-60 rating per 1% (10 expertise, 12 dodge, 15 parry,
-- 5 block).
local physTank = {
    sta = 1.5, armor = 0.1, armorbonus = 0.1, defrtng = 1.2, dodgertng = 1.0, parryrtng = 0.9,
    blockrtng = 0.6, block = 0.3, str = 1.0, agi = 0.6, hitrtng = 0.4, expPct = 4, atkpwr = 0.3,
    dps = 5, dodgePct = 12, parryPct = 13.5, blockPct = 3,
}

-- Protection paladins do most of their threat and damage with Holy spells
-- (Consecration, Holy Shield, Seal of Righteousness, Retribution Aura), so
-- spell damage outweighs Strength. Healing-only power doesn't help. The
-- Enhanced Fury Seal talent covers mana, so mana regen is worthless and Int
-- (a bit of crit) is nearly so.
local protPaladin = {}
for k, v in pairs(physTank) do protPaladin[k] = v end
protPaladin.splpwr, protPaladin.spldmg, protPaladin.holsplpwr = 1.3, 1.3, 1.3
protPaladin.int = 0.15
protPaladin.str, protPaladin.atkpwr = 0.8, 0.2

-- Healers: healing power dominates. `splpwr` (generic spell power) also heals;
-- `spldmg` and school spell power are damage-only, so they're worth nothing.
local healer = {
    splheal = 1.0, splpwr = 1.0, int = 0.35, spi = 0.25, manargn = 0.5,
    critstrkrtng = 0.2, hastertng = 0.3, sta = 0.1,
}

-- Casters: spell power dominates and weapon/wand DPS is ignored. Only the
-- spec's own school counts; e.g. a fire mage gets nothing from frost power.
local function caster(school)
    local w = {
        splpwr = 1.0, spldmg = 1.0, int = 0.4, spi = 0.2, hitrtng = 0.8, critstrkrtng = 0.5,
        hastertng = 0.5, sta = 0.1, manargn = 0.5,
    }
    for s, v in pairs(school) do w[s] = v end
    return w
end

-- Bear form: item armor is multiplied in form. On Forever the paws swing with the
-- equipped weapon's DPS (2.5 s in bear, 1.0 s in cat), so weapon DPS counts.
local bear = {
    sta = 1.5, armor = 0.15, armorbonus = 0.1, agi = 1.0, str = 1.0, feratkpwr = 0.5, atkpwr = 0.5,
    defrtng = 1.0, dodgertng = 1.0, hitrtng = 0.4, expPct = 4, dodgePct = 12, dps = 6,
}

local function placeholder(stats)
    return { source = "placeholder", brackets = { { upTo = 60, stats = stats } } }
end

ns.Weights = {
    WARRIOR = {
        arms = placeholder(warriorDps),
        fury = placeholder(warriorDps),
        protection = placeholder(physTank),
    },
    PALADIN = {
        holy = placeholder(healer),
        protection = placeholder(protPaladin),
        -- Seals, Judgement, Consecration and Exorcism are Holy damage, so spell
        -- damage is worth a fair bit, though well behind Strength.
        retribution = placeholder({
            str = 2.0, atkpwr = 1.0, agi = 0.5, critstrkrtng = 0.6, hitrtng = 0.6, hastertng = 0.4,
            int = 0.3, splpwr = 0.6, spldmg = 0.6, holsplpwr = 0.6, manargn = 0.3,
            sta = 0.2, armor = 0.01, dps = 14,
        }),
    },
    HUNTER = {
        beastmastery = placeholder({
            agi = 2.0, rgdatkpwr = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.7, hastertng = 0.6,
            int = 0.3, sta = 0.2, str = 0.1, armor = 0.01, rangedDps = 14, dps = 1,
        }),
        marksmanship = placeholder({
            agi = 2.0, rgdatkpwr = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.8, hastertng = 0.5,
            int = 0.3, sta = 0.2, str = 0.1, armor = 0.01, rangedDps = 14, dps = 1,
        }),
        survival = placeholder({
            agi = 2.2, rgdatkpwr = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.7, hastertng = 0.5,
            int = 0.3, sta = 0.2, str = 0.1, armor = 0.01, rangedDps = 14, dps = 2,
        }),
        survivalmelee = placeholder({
            agi = 2.0, str = 1.0, atkpwr = 1.0, rgdatkpwr = 0.5, hitrtng = 0.8, critstrkrtng = 0.7,
            int = 0.2, sta = 0.3, armor = 0.02, dps = 10, rangedDps = 4,
        }),
    },
    ROGUE = {
        assassination = placeholder({
            agi = 2.0, str = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.7, hastertng = 0.6,
            expPct = 5, sta = 0.2, armor = 0.01, dps = 14, rangedDps = 1,
        }),
        combat = placeholder({
            agi = 2.0, str = 1.0, atkpwr = 1.0, hitrtng = 0.9, critstrkrtng = 0.6, hastertng = 0.6,
            expPct = 6, sta = 0.2, armor = 0.01, dps = 14, rangedDps = 1,
        }),
        subtlety = placeholder({
            agi = 2.0, str = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.7, hastertng = 0.5,
            expPct = 5, sta = 0.2, armor = 0.01, dps = 14, rangedDps = 1,
        }),
    },
    PRIEST = {
        discipline = placeholder(healer),
        holy = placeholder(healer),
        shadow = placeholder(caster({ shasplpwr = 1.0, spi = 0.5 })),
    },
    SHAMAN = {
        elemental = placeholder(caster({ natsplpwr = 1.0, firsplpwr = 0.4, frosplpwr = 0.2 })),
        -- Shocks, Flametongue and Lightning Shield scale with spell damage;
        -- mostly Nature and Fire, a little Frost (Frost Shock).
        enhancement = placeholder({
            str = 2.0, atkpwr = 1.0, agi = 0.8, hitrtng = 0.8, critstrkrtng = 0.7, hastertng = 0.6,
            expPct = 5, int = 0.3, splpwr = 0.5, spldmg = 0.5, natsplpwr = 0.4, firsplpwr = 0.4,
            frosplpwr = 0.2, manargn = 0.3, sta = 0.2, armor = 0.01, dps = 14,
        }),
        restoration = placeholder(healer),
    },
    MAGE = {
        arcane = placeholder(caster({ arcsplpwr = 1.0, int = 0.7 })),
        fire = placeholder(caster({ firsplpwr = 1.0 })),
        frost = placeholder(caster({ frosplpwr = 1.0 })),
    },
    WARLOCK = {
        affliction = placeholder(caster({ shasplpwr = 1.0, sta = 0.4 })),
        demonology = placeholder(caster({ shasplpwr = 1.0, sta = 0.5 })),
        destruction = placeholder(caster({ shasplpwr = 1.0, firsplpwr = 0.6, sta = 0.4 })),
    },
    DRUID = {
        balance = placeholder(caster({ arcsplpwr = 0.6, natsplpwr = 0.6 })),
        -- Weapon DPS counts in cat form on Forever (see `bear`).
        feral = placeholder({
            agi = 1.5, str = 1.5, feratkpwr = 1.0, atkpwr = 1.0, hitrtng = 0.8, critstrkrtng = 0.7,
            hastertng = 0.4, expPct = 5, sta = 0.5, armor = 0.03, armorbonus = 0.03, dps = 13,
        }),
        bear = placeholder(bear),
        restoration = placeholder(healer),
    },
}

-- A model bracket's speedRef = { speed = 2.6, ... } (the speeds its speed
-- weights were measured at) goes into its stats as speedRef = 2.6, ..., so
-- copies of the weights (profiles, shared strings) keep it.
local function MergeSpeedRefs(brackets)
    for _, b in ipairs(brackets or {}) do
        for key, v in pairs(b.speedRef or {}) do b.stats[key .. "Ref"] = v end
        b.speedRef = nil
    end
end

for classFile, specs in pairs(ns.ModelWeights or {}) do
    for spec, w in pairs(specs) do
        MergeSpeedRefs(w.brackets)
        for _, s in pairs(w.setups or {}) do MergeSpeedRefs(s.brackets) end
        ns.Weights[classFile][spec] = w
    end
end

-- The speed a speed weight counts from when its weights don't say
-- (placeholders, Pawn scales, profiles from before): the usual speed of the
-- weapon's kind, two-handers 3.3, ranged weapons 2.8, other weapons 2.4.
ns.SPEED_REF = { twoHand = 3.3, ranged = 2.8, other = 2.4 }

-- The score of weapon `item`'s speed with weight `key` ("speed", "ohSpeed",
-- "rangedSpeed") of `weights`: (speed - reference) x 10 x weight.
function ns.SpeedScore(item, weights, key)
    local w = weights[key]
    local speed = item.weapon and item.weapon.speed
    if not (w and w ~= 0 and speed) then return 0 end
    local ref = weights[key .. "Ref"]
    if not ref then
        local inv = item.slot
        ref = (inv == 17 and ns.SPEED_REF.twoHand)
            or ((inv == 15 or inv == 25 or inv == 26) and ns.SPEED_REF.ranged) or ns.SPEED_REF.other
    end
    return (speed - ref) * 10 * w
end

-- Score for +1% crit chance at level 60, used for item crit (critPct) and
-- racial weapon crit (Human swords, Orc axes, Dwarf maces). Scaled down
-- linearly with level, because item stat budgets grow roughly linearly.
-- Placeholders, like the rest; model brackets carry their own.
local CRIT_PCT = {
    WARRIOR = { arms = 25, fury = 25, protection = 12 },
    PALADIN = { holy = 6, protection = 8, retribution = 25 },
    HUNTER  = { beastmastery = 25, marksmanship = 25, survival = 25, survivalmelee = 25 },
    ROGUE   = { assassination = 25, combat = 25, subtlety = 25 },
    PRIEST  = { discipline = 6, holy = 6, shadow = 10 },
    SHAMAN  = { elemental = 10, enhancement = 25, restoration = 6 },
    MAGE    = { arcane = 10, fire = 10, frost = 10 },
    WARLOCK = { affliction = 10, demonology = 10, destruction = 10 },
    DRUID   = { balance = 10, feral = 25, bear = 5, restoration = 6 },
}

-- Score for +1% hit at level 60 (item hitPct), scaled like CRIT_PCT. Forever
-- pools gear hit, so it is spell hit too. Melee and ranged value it like crit;
-- casters at about twice their crit (a miss loses the whole spell, a crit adds
-- half); heals can't miss; tanks a little, for threat.
local HIT_PCT = {
    WARRIOR = { arms = 25, fury = 25, protection = 14 },
    PALADIN = { holy = 0, protection = 10, retribution = 25 },
    HUNTER  = { beastmastery = 25, marksmanship = 25, survival = 25, survivalmelee = 25 },
    ROGUE   = { assassination = 25, combat = 25, subtlety = 25 },
    PRIEST  = { discipline = 0, holy = 0, shadow = 15 },
    SHAMAN  = { elemental = 15, enhancement = 25, restoration = 0 },
    MAGE    = { arcane = 15, fire = 15, frost = 15 },
    WARLOCK = { affliction = 15, demonology = 15, destruction = 15 },
    DRUID   = { balance = 15, feral = 25, bear = 8, restoration = 0 },
}
local PCT_DEFAULTS = { critPct = CRIT_PCT, hitPct = HIT_PCT }

-- The bracket of `brackets` (a list of { upTo, stats }, the lowest level
-- first) for `level`: the first that reaches it, else the last. Returns the
-- bracket and the level it starts at.
function ns.WeightBracket(brackets, level)
    local from = 1
    for _, bracket in ipairs(brackets) do
        if level <= bracket.upTo then return bracket, from end
        from = bracket.upTo + 1
    end
    local last = brackets[#brackets]
    return last, #brackets > 1 and (brackets[#brackets - 1].upTo + 1) or 1
end

-- The default stats of the bracket for this level and weapon setup (the
-- spec's default brackets when that setup has none of its own), the spec's
-- weights, the bracket and the level it starts at.
local function BracketStats(classFile, spec, level, setup)
    local specWeights = ns.Weights[classFile] and ns.Weights[classFile][spec]
    if not specWeights then return nil end
    local set = setup and specWeights.setups and specWeights.setups[setup] or specWeights
    local bracket, from = ns.WeightBracket(set.brackets, level)
    return bracket.stats, specWeights, bracket, from
end

-- True when the spec's weapon setups have weights of their own.
function ns.HasSetupWeights(classFile, spec)
    local specWeights = ns.Weights[classFile] and ns.Weights[classFile][spec]
    return specWeights ~= nil and specWeights.setups ~= nil
end

-- The default weights' level range for `level`: the bracket's first and last level.
function ns.DefaultWeightRange(classFile, spec, level, setup)
    local _, _, bracket, from = BracketStats(classFile, spec, level, setup)
    if not bracket then return 1, ns.MAX_LEVEL end
    return from, math.min(bracket.upTo, ns.MAX_LEVEL)
end

-- The default score of +1% crit or hit (`key` "critPct" or "hitPct") at
-- `level`: model brackets carry their own per level; otherwise the level-60
-- value above, scaled down linearly with level.
local function DefaultPct(classFile, spec, level, key, setup)
    local stats = BracketStats(classFile, spec, level, setup)
    if stats and stats[key] then return stats[key] end
    local defaults = PCT_DEFAULTS[key]
    return (defaults[classFile] and defaults[classFile][spec] or 0) * math.min(level, 60) / 60
end

-- A saved profile's own weights are used as they are, at every level (one
-- bracket, 1-60, unless it was imported with more): Weight profiles in
-- WeightProfiles.lua. `id` names one (an off spec's choice; "default" for the
-- default weights), else the one picked for the spec and setup is used.
local function PctWeight(classFile, spec, level, key, setup, id)
    local profile = ns.WeightProfiles.Resolve(classFile, spec, setup, id)
    if profile then return ns.WeightBracket(profile.brackets, level).stats[key] or 0 end
    return DefaultPct(classFile, spec, level, key, setup)
end

function ns.CritPctWeight(classFile, spec, level, setup, id) return PctWeight(classFile, spec, level, "critPct", setup, id) end
function ns.HitPctWeight(classFile, spec, level, setup, id) return PctWeight(classFile, spec, level, "hitPct", setup, id) end

-- The default weights for a class/spec/level and weapon setup (optional),
-- whatever profile is picked, and their source label.
function ns.DefaultWeights(classFile, spec, level, setup)
    local stats, specWeights = BracketStats(classFile, spec, level, setup)
    if not stats then return nil end
    return stats, L[specWeights.source]
end

-- Returns the stat table and its source label (for display) for a
-- class/spec/level and weapon setup (optional): those of profile `id`, or of
-- the one picked for the spec and setup, else the default weights. Third, the
-- profile (nil: the defaults).
function ns.GetWeights(classFile, spec, level, setup, id)
    local profile = ns.WeightProfiles.Resolve(classFile, spec, setup, id)
    if profile then return ns.WeightBracket(profile.brackets, level).stats, profile.name, profile end
    return ns.DefaultWeights(classFile, spec, level, setup)
end

-- Gear stats that are flat percentages on Forever, with their label format.
ns.PctStats = {
    { key = "critPct", format = L["%s%% crit"] }, { key = "hitPct", format = L["%s%% hit"] },
    { key = "rhitPct", format = L["%s%% ranged hit"] },
    { key = "expPct", format = L["%s%% expertise"] },
    { key = "dodgePct", format = L["%s%% dodge"] }, { key = "parryPct", format = L["%s%% parry"] },
    { key = "blockPct", format = L["%s%% block"] },
}

-- `value` percent of PctStats entry `s`: "+1% crit", "+1.5% hit", "-1% parry".
function ns.PctLabel(s, value)
    local n = value == math.floor(value) and string.format("%+d", value) or string.format("%+.1f", value)
    return string.format(s.format, n)
end

-- Editable weights in display order (the Weights panel). Rating stats no
-- Forever item carries (hit/crit/haste/expertise/armor pen/dodge/parry/block
-- rating) are left out; their weights still apply if an item ever has them.
ns.WeightStats = {
    { key = "str", label = L["Strength"] }, { key = "agi", label = L["Agility"] },
    { key = "sta", label = L["Stamina"] }, { key = "int", label = L["Intellect"] },
    { key = "spi", label = L["Spirit"] },
    { key = "atkpwr", label = L["Attack power"] }, { key = "rgdatkpwr", label = L["Ranged AP"] },
    { key = "feratkpwr", label = L["Feral AP"] },
    { key = "splpwr", label = L["Spell power"] }, { key = "spldmg", label = L["Spell damage"] },
    { key = "splheal", label = L["Healing power"] },
    { key = "arcsplpwr", label = L["Arcane power"] }, { key = "firsplpwr", label = L["Fire power"] },
    { key = "frosplpwr", label = L["Frost power"] }, { key = "holsplpwr", label = L["Holy power"] },
    { key = "natsplpwr", label = L["Nature power"] }, { key = "shasplpwr", label = L["Shadow power"] },
    { key = "splpen", label = L["Spell pen"] }, { key = "defrtng", label = L["Defense"] },
    { key = "block", label = L["Block value"] }, { key = "armor", label = L["Armor"] },
    { key = "armorbonus", label = L["Bonus armor"] }, { key = "manargn", label = L["Mana regen"] },
    { key = "healthrgn", label = L["Health regen"] },
    { key = "dps", label = L["Weapon DPS"] }, { key = "ohDps", label = L["Off-hand DPS"] },
    { key = "rangedDps", label = L["Ranged DPS"] },
}
-- Weapon speed weights, per 0.1 s: "+0.1 s speed".
ns.SpeedStats = {
    { key = "speed", format = L["%s s speed"] }, { key = "ohSpeed", format = L["%s s off-hand speed"] },
    { key = "rangedSpeed", format = L["%s s ranged speed"] },
}
for _, s in ipairs(ns.SpeedStats) do
    ns.WeightStats[#ns.WeightStats + 1] = { key = s.key, label = ns.PctLabel(s, 0.1) }
end
for _, s in ipairs(ns.PctStats) do
    ns.WeightStats[#ns.WeightStats + 1] = { key = s.key, label = ns.PctLabel(s, 1) }
end
