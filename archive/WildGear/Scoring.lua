local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Character slots and the inventoryTypes that can go in them. Main hand and
-- off hand are filled per weapon setup (see ns.WeaponSetups), not from `inv`.
-- `equip` lists the character's inventory slot ids (GetInventoryItemID).
ns.SlotGroups = {
    { key = "head",     label = L["Head"],      inv = { [1] = true }, equip = { 1 } },
    { key = "neck",     label = L["Neck"],      inv = { [2] = true }, equip = { 2 } },
    { key = "shoulder", label = L["Shoulder"],  inv = { [3] = true }, equip = { 3 } },
    { key = "back",     label = L["Back"],      inv = { [16] = true }, equip = { 15 } },
    { key = "chest",    label = L["Chest"],     inv = { [5] = true, [20] = true }, equip = { 5 } },
    { key = "wrist",    label = L["Wrist"],     inv = { [9] = true }, equip = { 9 } },
    { key = "hands",    label = L["Hands"],     inv = { [10] = true }, equip = { 10 } },
    { key = "waist",    label = L["Waist"],     inv = { [6] = true }, equip = { 6 } },
    { key = "legs",     label = L["Legs"],      inv = { [7] = true }, equip = { 7 } },
    { key = "feet",     label = L["Feet"],      inv = { [8] = true }, equip = { 8 } },
    { key = "finger",   label = L["Finger"],    inv = { [11] = true }, slots = 2, equip = { 11, 12 } },
    { key = "trinket",  label = L["Trinket"],   inv = { [12] = true }, slots = 2, equip = { 13, 14 } },
    { key = "mainhand", label = L["Main Hand"], weapon = true, equip = { 16 } },
    { key = "offhand",  label = L["Off Hand"],  weapon = true, equip = { 17 } },
    { key = "ranged",   label = L["Ranged"],    inv = { [15] = true, [25] = true, [26] = true, [28] = true }, equip = { 18 } },
}

ns.SourceTypes = { "quest", "drop", "crafted", "boe" }
ns.SourceLabels = { quest = L["Quest"], drop = L["Dungeon"], crafted = L["Crafted"], boe = L["BoE"] }

-- Sources (Settings' Filters, for all characters): whether each source type
-- counts at all (ns.db[type] = false when off: quest, drop, crafted, boe),
-- and with BoE items blue (boeRare) and purple ones (boeEpic) and the
-- dungeons' own (boeDungeon), which count as BoE only, not as dungeon drops
-- (UsableSources). All on by default.
function ns.SourceOn(sourceType)
    return ns.db[sourceType] ~= false
end

-- Whether a quest source is left out by Quest's Dungeon quests switch
-- (ns.db.questDungeon = false when off): a quest the game's quest log files
-- as a Dungeon quest, for those who only play in the open world.
local function DungeonQuestOff(s)
    if ns.db.questDungeon ~= false then return false end
    local q = ns.Quests and ns.Quests[s.id]
    return q ~= nil and q.type == "Dungeon"
end

local function BoEAllowed(s, item)
    local db = ns.db
    if db.boe == false or (s.dungeon and db.boeDungeon == false) then return false end
    local quality = item.quality or 2
    return not ((quality == 3 and db.boeRare == false) or (quality >= 4 and db.boeEpic == false))
end

-- How the hands are filled. inventoryType 13 one-hand, 17 two-hand, 21 main
-- hand only, 22 off hand only (weapon), 14 shield, 23 held in off hand.
-- An off-hand weapon's DPS is weighed with ohDps (ns.OffDpsWeight).
-- "held" takes a shield too (for the classes that carry one): a caster's or
-- healer's off hand counts the same either way.
ns.WeaponSetups = {
    twohand   = { label = L["Two-hander"],    main = { [17] = true } },
    dualwield = { label = L["Dual wield"],    main = { [13] = true, [21] = true }, off = { [13] = true, [22] = true } },
    shield    = { label = L["1H + shield"],   main = { [13] = true, [21] = true }, off = { [14] = true } },
    held      = { label = L["1H + off-hand"], main = { [13] = true, [21] = true }, off = { [14] = true, [23] = true } },
    onehand   = { label = L["One-hander"],    main = { [13] = true, [21] = true } }, -- when no other setup takes a one-hander
}

-- Setups each spec may use; the first one is the default. Each setup is
-- ranked on its own, with its own best (a caster or healer picks between a
-- one-hander and off hand, and a two-hander, as melee specs do).
local SPEC_SETUPS = {
    WARRIOR = { arms = { "twohand", "dualwield" }, fury = { "dualwield", "twohand" }, protection = { "shield" } },
    PALADIN = { holy = { "held", "twohand" }, protection = { "shield" }, retribution = { "twohand" } },
    HUNTER  = { beastmastery = { "twohand", "dualwield" }, marksmanship = { "twohand", "dualwield" },
                survival = { "twohand", "dualwield" }, survivalmelee = { "twohand", "dualwield" } },
    ROGUE   = { assassination = { "dualwield" }, combat = { "dualwield" }, subtlety = { "dualwield" } },
    PRIEST  = { discipline = { "twohand", "held" }, holy = { "twohand", "held" }, shadow = { "twohand", "held" } },
    SHAMAN  = { elemental = { "held", "twohand" }, enhancement = { "twohand", "shield" },
                restoration = { "held", "twohand" } },
    MAGE    = { arcane = { "twohand", "held" }, fire = { "twohand", "held" }, frost = { "twohand", "held" } },
    WARLOCK = { affliction = { "twohand", "held" }, demonology = { "twohand", "held" },
                destruction = { "twohand", "held" } },
    DRUID   = { balance = { "twohand", "held" }, feral = { "twohand", "held" }, bear = { "twohand", "held" },
                restoration = { "twohand", "held" } },
}

-- Weapon types a spec's abilities need, by hand ("main", "off"), from a level:
-- Ambush (18) a dagger in the main hand, Mutilate (40) a dagger in each (the
-- client's SpellEquippedItems). Matches HAND_TYPES in tools/statmodel/specs/rogue.py.
local DAGGER = { [15] = true }
local SPEC_HAND_TYPES = {
    ROGUE = {
        assassination = { main = { 18, DAGGER }, off = { 40, DAGGER } },
        subtlety      = { main = { 18, DAGGER } },
    },
}

-- Dual Wield levels from the client's skill table (warrior 20, hunter 20, rogue 10).
-- Shamans can't dual wield on Forever (no talent or trainer spell for it).
local DUAL_WIELD_LEVEL = { [1] = 20, [3] = 20, [4] = 10 }
-- Weapon masters teach a character's other weapon types from this level (one
-- ns.WeaponTrainLevels lists from its own: Polearms 20). Before it, a character
-- wields the types its race and class start with (ns.StartingWeapons) and the
-- ones it has learned since (p.weaponSkills): no staff for a level 5 hunter.
local TRAIN_LEVEL = 10
local SHIELD_USERS = { [1] = true, [2] = true, [7] = true }
local TWO_HAND_SUBCLASSES = { 1, 5, 6, 8, 10 } -- 2H axe, 2H mace, polearm, 2H sword, staff

local RANGED_INV = { [15] = true, [25] = true, [26] = true }
local RELIC_INV = 28
local RELIC_OWNER = { [7] = 2, [8] = 11, [9] = 7 } -- libram: paladin, idol: druid, totem: shaman
-- Classes whose ranged slot only ever holds a relic.
local RELIC_CLASSES = { [2] = true, [7] = true, [11] = true }
-- Classes limited to these ranged subclasses, though trained in more:
-- hunters skip thrown for bows (2), guns (3) and crossbows (18).
local RANGED_SUBCLASSES = { [3] = { [2] = true, [3] = true, [18] = true } }

-- Slot label for the character: the ranged slot reads "Relic" for relic classes.
function ns.GroupLabel(g, p)
    if g.key == "ranged" and p and RELIC_CLASSES[p.classId] then return L["Relic"] end
    return g.label
end
-- Classic rule: plate/mail users wear one tier lower before this level.
-- Unverified on Forever.
local ARMOR_UPGRADE_LEVEL = 40
ns.ARMOR_UPGRADE_LEVEL = ARMOR_UPGRADE_LEVEL
local FACTION_SIDE = { Alliance = 1, Horde = 2 }
-- Dungeons inside one faction's city or land, by zone: their drops count for
-- that faction only (their BoE drops still count for both, from the AH).
-- Hall of Thanes and The Stockade Alliance, Ragefire Chasm Horde.
local DUNGEON_SIDE = { [16919] = 1, [717] = 1, [2437] = 2 }
-- How far above the player's level a quest may be and still count: by default
-- 3 (orange quests); Settings' Filters, for all characters, set 0 to
-- QUEST_ABOVE_MAX (ns.db.questAbove), or any level (ns.db.questAnyLevel: from
-- the quest's required level).
local QUEST_LEVEL_MARGIN = 3
ns.QUEST_ABOVE, ns.QUEST_ABOVE_MAX = QUEST_LEVEL_MARGIN, 10

-- The levels above yours a quest may be, No limit aside.
function ns.QuestAbove()
    return ns.db.questAbove or QUEST_LEVEL_MARGIN
end

local function QuestMargin()
    if ns.db.questAnyLevel then return math.huge end
    return ns.QuestAbove()
end
-- Look-ahead upgrades must beat the item they replace by this share (skips sidegrades).
local MIN_UPGRADE_GAIN = 0.03

local band = bit.band

local function HasBit(mask, index)
    if index > 32 then return false end
    return band(mask % 4294967296, 2 ^ (index - 1)) ~= 0 -- bit.band is 32-bit
end

-- Wowhead race masks: bit id-1 for the Classic races, bit 32 (2^32) for High
-- Order Skyborne (95) and bit 33 for Windshaper Skyborne (96), as its quest
-- pages show. Besides its own bit, a Skyborne race passes a mask that includes
-- every Classic race of the player's faction (faction-wide masks often leave
-- it out).
local SKYBORNE_BIT = { [95] = 4294967296, [96] = 8589934592 }
local FACTION_RACES = { Alliance = 77, Horde = 178 } -- 1+4+8+64 / 2+16+32+128

local function RaceAllowed(mask, raceId, faction)
    if raceId <= 32 then return HasBit(mask, raceId) end
    local own = SKYBORNE_BIT[raceId]
    if own and math.floor(mask / own) % 2 == 1 then return true end
    local classic = FACTION_RACES[faction]
    return classic ~= nil and band(mask % 4294967296, classic) == classic
end

-- Miscellaneous weapons (the Skinning Knife) need no weapon skill: every class
-- wields them.
local MISC_WEAPON = 14

local weaponSets = {}
local function CanUseWeapon(classId, subclass)
    if subclass == MISC_WEAPON then return true end
    local set = weaponSets[classId]
    if not set then
        set = {}
        for _, sc in ipairs(ns.WeaponProficiencies[classId] or {}) do set[sc] = true end
        weaponSets[classId] = set
    end
    return set[subclass] == true and subclass ~= 20 -- 20 = fishing pole
end

-- Whether the character wields weapon type `subclass` at its level: one its
-- class can use, known from the start, learned, or taught by then (TRAIN_LEVEL).
local function Wields(p, subclass)
    if not CanUseWeapon(p.classId, subclass) then return false end
    if subclass == MISC_WEAPON or (p.weaponSkills and p.weaponSkills[subclass]) then return true end
    local start = ns.StartingWeapons and ns.StartingWeapons[p.raceId]
    start = start and start[p.classId]
    if not start then return true end -- (no data for the race and class)
    for _, sc in ipairs(start) do
        if sc == subclass then return true end
    end
    return p.level >= math.max(TRAIN_LEVEL, ns.WeaponTrainLevels and ns.WeaponTrainLevels[subclass] or 0)
end

local function MaxArmor(classId, level)
    local max = ns.ArmorProficiencies[classId] or 1
    if max >= 3 and level < ARMOR_UPGRADE_LEVEL then max = max - 1 end
    return max
end

-- Class armor only (armor purists): the class's own armor type and nothing
-- lighter, e.g. mail for a warrior before 40 and plate from then on.
local function IsLighterArmorAt(item, classId, level)
    local sc = item.subclass
    return item.class == 4 and item.slot ~= 16 and sc >= 1 and sc < MaxArmor(classId, level)
end

function ns.IsLighterArmor(item, p)
    return IsLighterArmorAt(item, p.classId, p.level)
end

-- Why this character can't equip the item (ignoring its required level):
-- "class", "race", "skill" (a profession rank) or "type" (weapon, armor,
-- shield or relic type); nil when it can. Only the armor type, the weapon
-- types not learned yet (Wields) and off-hand weapons (Dual Wield) depend on
-- the character's level.
function ns.EquipProblem(item, p)
    if item.classMask and not HasBit(item.classMask, p.classId) then return "class" end
    if item.raceMask and not RaceAllowed(item.raceMask, p.raceId, p.faction) then return "race" end
    if item.reqSkill and (p.professions[item.reqSkill] or 0) < (item.reqSkillRank or 0) then return "skill" end
    if item.class == 2 then
        if item.slot == 22 and p.level < (DUAL_WIELD_LEVEL[p.classId] or math.huge) then return "type" end
        local ranged = RANGED_SUBCLASSES[p.classId]
        if ranged and RANGED_INV[item.slot] and not ranged[item.subclass] then return "type" end
        return not Wields(p, item.subclass) and "type" or nil
    end
    local sc = item.subclass
    -- cloaks; misc (0) and Wowhead's negative jewelry subclasses (-2 ring, -3 neck, -4 trinket)
    if item.slot == 16 or sc <= 0 then return nil end
    if sc == 6 then return not SHIELD_USERS[p.classId] and "type" or nil end
    if RELIC_OWNER[sc] then return RELIC_OWNER[sc] ~= p.classId and "type" or nil end
    if sc >= 1 and sc <= 4 then return sc > MaxArmor(p.classId, p.level) and "type" or nil end
    return "type"
end

-- Can this character equip the item at all (ignoring its required level)?
local function CanEquip(item, p)
    return ns.EquipProblem(item, p) == nil
end
ns.CanEquip = CanEquip

-- The level from which the character can wear the item, its required level
-- aside: its own level, else the one that lifts what stops it (a weapon type
-- taught by then, Dual Wield, mail and plate); nil when none does.
function ns.WearLevel(item, p)
    local levels = { p.level, TRAIN_LEVEL, ARMOR_UPGRADE_LEVEL, DUAL_WIELD_LEVEL[p.classId] }
    for _, level in pairs(ns.WeaponTrainLevels or {}) do levels[#levels + 1] = level end
    table.sort(levels)
    for _, level in ipairs(levels) do
        if level >= p.level and CanEquip(item, setmetatable({ level = level }, { __index = p })) then return level end
    end
end

-- Whether the quest (a quest source or an ns.Quests entry) is open to the
-- character's faction, class and race.
local function QuestOpen(q, p)
    local side = FACTION_SIDE[p.faction]
    if q.side and q.side ~= 3 and side and q.side ~= side then return false end
    if q.reqClass and q.reqClass > 0 and not HasBit(q.reqClass, p.classId) then return false end
    if q.reqRace and q.reqRace > 0 and not RaceAllowed(q.reqRace, p.raceId, p.faction) then return false end
    return true
end

-- The level from which UsableSources lets a source through. A low-level reward
-- can come from a high-level quest (Forever lowered many reward requirements),
-- so a quest also has to be doable: within QuestMargin of its level, never
-- before its required level. A minLevel (a manual fix for easy quests, e.g. In
-- Nightmares, or ones behind a higher-level prerequisite, e.g. The Fury Runs
-- Deep) is the level it is doable from at the default margin, so it moves
-- with the setting as the quest's level does.
-- A craft counts from the level its skill rank can be trained at (Classic's
-- trainer tiers: Journeyman 10, Expert 20, Artisan 35), so a level 5 isn't
-- shown an Engineering 250 cloak with no required level.
local function CraftLevel(skill)
    if not skill or skill <= 75 then return 0 end
    return skill <= 150 and 10 or skill <= 225 and 20 or 35
end

local function SourceLevel(s)
    if s.type == "crafted" then return CraftLevel(s.skill) end
    if s.type ~= "quest" then return 0 end
    local level = s.minLevel and (s.minLevel + QUEST_LEVEL_MARGIN) or s.level or 0
    return math.max(s.reqLevel or 0, level - QuestMargin())
end

-- The item's sources this character can actually obtain, of the types the
-- Sources filters let through, and BoE ones the BoE filters let through. A
-- dungeon's BoE drop counts as BoE only: its BoE source (s.dungeon) stands
-- for its drop source (s.boe). A bind-on-pickup craft (s.bop) counts only for
-- your own professions (ns.HasProfession); others can be bought from a crafter.
local function UsableSources(item, p, maxLevel)
    local out, boe = {}, false
    for _, s in ipairs(item.sources) do
        if s.type == "boe" then boe = true end
    end
    for _, s in ipairs(item.sources) do
        if not ns.SourceOn(s.type) then -- (left out)
        elseif s.type == "quest" then
            if SourceLevel(s) <= maxLevel and QuestOpen(s, p) and not DungeonQuestOff(s) then out[#out + 1] = s end
        elseif s.type == "boe" then
            if BoEAllowed(s, item) then out[#out + 1] = s end
        elseif s.type == "crafted" then
            if SourceLevel(s) <= maxLevel and not (s.bop and not ns.HasProfession(p, ns.ProfessionId(s.profession))) then
                out[#out + 1] = s
            end
        elseif s.type == "drop" and DUNGEON_SIDE[s.zoneId] and DUNGEON_SIDE[s.zoneId] ~= FACTION_SIDE[p.faction] then
            -- (the other faction's dungeon)
        elseif not (s.type == "drop" and s.boe and boe) then
            out[#out + 1] = s
        end
    end
    return out
end

-- The level from which this character can get the item from a source of the
-- given type (any type when nil): the item's own required level, raised for a
-- quest reward to what the quest itself needs. Nil when no such source is open
-- to the character's faction, class or race.
function ns.ObtainLevel(item, p, sourceType)
    local best
    for _, s in ipairs(UsableSources(item, p, math.huge)) do
        if not sourceType or s.type == sourceType then
            local level = math.max(item.reqLevel or 0, SourceLevel(s))
            if not best or level < best then best = level end
        end
    end
    return best
end

---------------------------------------------------------------- weapon setups

local function CanSetup(key, p)
    if key == "dualwield" then
        local lvl = DUAL_WIELD_LEVEL[p.classId]
        return lvl ~= nil and p.level >= lvl
    elseif key == "shield" then
        return SHIELD_USERS[p.classId] == true
    elseif key == "twohand" then
        for _, sc in ipairs(TWO_HAND_SUBCLASSES) do
            if Wields(p, sc) then return true end
        end
        return false
    end
    return true
end

-- Whether `item` goes in hand `hand` ("main" or "off") of setup `key` for
-- profile `p`: its inventory type, and the weapon type the spec's abilities
-- need there at p's level (SPEC_HAND_TYPES).
function ns.SetupFits(p, key, hand, item)
    local set = ns.WeaponSetups[key]
    if not (set[hand] and set[hand][item.slot]) then return false end
    local rules = SPEC_HAND_TYPES[p.classFile] and SPEC_HAND_TYPES[p.classFile][p.spec]
    local rule = rules and rules[hand]
    return not rule or p.level < rule[1] or item.class ~= 2 or rule[2][item.subclass] == true
end

-- Whether a second copy of `item` can be had and worn beside the first (in
-- the other hand, ring or trinket slot): it isn't unique, and it comes from
-- somewhere besides a quest, which gives one.
function ns.TwoCopies(item)
    if item.unique then return false end
    for _, s in ipairs(item.sources or {}) do
        if s.type ~= "quest" then return true end
    end
    return false
end

-- Place `place` (1 or 2) of slot group bucket `bucket` (ns.Rank): its best,
-- and for the second ring or trinket another copy of the best when one can be
-- had (bucket.second, marked `copy`), else the next best. A hand with an off
-- hand beside it: its row (bucket.pick, PickPair).
function ns.SlotPick(bucket, place)
    if bucket.paired and place == 1 then return bucket.pick end
    if place == 2 and bucket.second then return bucket.second end
    return bucket.all[place]
end

-- Setups this class/spec/level can use, default first: the window's Weapons
-- box choices. Never empty. When none of them takes a one-hander (a hunter below the Dual Wield level,
-- Retribution), a one-hander held alone comes last, so its default stays: you
-- may be wearing one (a level 5 hunter's axe), and a better one is an upgrade.
-- `any`: then every other setup the class can hold at its level too, for
-- gear none of the spec's takes, judged against what you wear (a shield for
-- an Arms warrior: an upgrade beside a lone one-hander, not for a two-hander).
local ALL_SETUPS = { "twohand", "dualwield", "shield", "held", "onehand" }
function ns.WeaponSetupOptions(p, any)
    local out, oneHand = {}, false
    local list = SPEC_SETUPS[p.classFile] and SPEC_SETUPS[p.classFile][p.spec] or { "twohand", "held" }
    for _, key in ipairs(list) do
        if CanSetup(key, p) then
            out[#out + 1] = key
            if ns.WeaponSetups[key].main[13] then oneHand = true end
        end
    end
    if not oneHand then out[#out + 1] = "onehand" end
    if any then
        local have = {}
        for _, key in ipairs(out) do have[key] = true end
        for _, key in ipairs(ALL_SETUPS) do
            if not have[key] and CanSetup(key, p) then out[#out + 1] = key end
        end
    end
    return out
end

-- The setups spec `spec` may use, its default first (SPEC_SETUPS), whatever the level.
function ns.SpecSetups(classFile, spec)
    return SPEC_SETUPS[classFile] and SPEC_SETUPS[classFile][spec] or { "twohand", "held" }
end

-- True when one of the spec's setups holds a weapon in the off hand (dual
-- wield): its off-hand DPS and speed weights count. Else they're 0.
function ns.HoldsOffHandWeapon(classFile, spec)
    for _, key in ipairs(ns.SpecSetups(classFile, spec)) do
        local off = ns.WeaponSetups[key].off
        if off and (off[13] or off[22]) then return true end
    end
    return false
end

local function PrefKey(p)
    return p.classFile .. ":" .. p.spec
end

-- The saved choice for this class/spec, a setup key; falls back to the default
-- (also for a choice the class/spec/level doesn't allow, or the old "auto").
-- A profile with its own setup (p.setup: the tooltip's off profiles, the
-- smoketest's audit) uses that.
function ns.GetWeaponSetupPref(p)
    local options = ns.WeaponSetupOptions(p)
    for _, key in ipairs(options) do
        if key == p.setup then return key end
    end
    local pref = ns.charDB and ns.charDB.weapons and ns.charDB.weapons[PrefKey(p)]
    for _, key in ipairs(options) do
        if key == pref then return key end
    end
    return options[1]
end

function ns.SetWeaponSetupPref(p, key)
    ns.charDB.weapons = ns.charDB.weapons or {}
    ns.charDB.weapons[PrefKey(p)] = key
end

-- The weapon imbue a setup's weights assume, for specs whose setups are
-- played with different imbues: { learned at level, spell id, English name },
-- the highest level first. Matches SETUP_IMBUE in
-- tools/statmodel/specs/shaman_enhancement.py.
local SETUP_IMBUES = {
    SHAMAN = { enhancement = {
        twohand = { { 30, 8232, "Windfury Weapon" }, { 1, 8017, "Rockbiter Weapon" } },
        shield  = { { 10, 8024, "Flametongue Weapon" }, { 1, 8017, "Rockbiter Weapon" } },
    } },
}

-- The imbue setup `key` is weighted for at p's level: its name in the game's
-- language and its icon (nil outside the game); nil when the spec has none.
function ns.SetupImbue(p, key)
    local spec = SETUP_IMBUES[p.classFile] and SETUP_IMBUES[p.classFile][p.spec]
    for _, e in ipairs(spec and spec[key] or {}) do
        if p.level >= e[1] then
            local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(e[2]))
                or (GetSpellTexture and GetSpellTexture(e[2]))
            return ns.SpellName(e[2], e[3]), icon
        end
    end
end

-- A setup's label with its imbue: "Two-hander (Windfury Weapon)". `short`
-- shows the imbue as its icon only ("<icon> Two-hander"), for narrow boxes.
function ns.WeaponSetupLabel(p, key, short)
    local label = ns.WeaponSetups[key].label
    local imbue, icon = ns.SetupImbue(p, key)
    if not imbue then return label end
    if short then return icon and ("|T" .. icon .. ":12:12|t " .. label) or label end
    return string.format(L["%s (%s)"], label, imbue)
end

-- The weapon setup whose weights score items for profile `p`: the chosen one.
-- Only matters for specs with ns.HasSetupWeights.
function ns.WeightSetup(p)
    return ns.GetWeaponSetupPref(p)
end

---------------------------------------------------------------- scoring

-- Score of +1% crit and +1% hit for profile `p`: { critPct = n, hitPct = n }.
-- Item critPct/hitPct and racial weapon crit use these, not the bracket's
-- stat table, so the placeholder level scaling applies. p.weights, when set,
-- is the weight profile to use (an off spec's: WeightProfiles.lua).
-- It also names the class and spec (effectClass, effectSpec), whose value of an
-- item's effect (item.effects, Data/ItemEffects.lua) ScoreParts adds.
function ns.PctWeights(p, setup)
    setup = setup or ns.WeightSetup(p)
    return { critPct = ns.CritPctWeight(p.classFile, p.spec, p.level, setup, p.weights),
             hitPct = ns.HitPctWeight(p.classFile, p.spec, p.level, setup, p.weights),
             effectClass = p.classFile, effectSpec = p.spec }
end

-- The stats item `item`'s effect is worth to the class and spec `pct` names, or nil:
-- { atkpwr = 78, offHand = { atkpwr = 49 } }, offHand for a one-hander whose effect is
-- worth less in the off hand (fewer swings there, and specials strike with the main hand).
local function EffectStats(item, pct)
    local byClass = item.effects and item.effects[pct.effectClass]
    return byClass and byClass[pct.effectSpec]
end

-- Score of effect stats `effect` (its numbers: offHand is a table of its own).
local function EffectScore(effect, weights, pct)
    local score = 0
    for stat, value in pairs(effect) do
        if type(value) == "number" then
            local w = pct[stat]
            if w == nil then w = weights[stat] or 0 end
            score = score + value * w
        end
    end
    return score
end

-- Score of a stats table (an item's, a random suffix's), with racial stat multipliers.
local function StatScore(stats, weights, racial, pct)
    local mult = racial and racial.statMult
    local score = 0
    for stat, value in pairs(stats) do
        local w = pct[stat]
        if w == nil then w = weights[stat] or 0 end
        score = score + value * w * (mult and mult[stat] or 1)
    end
    return score
end

-- The weight of a point of weapon DPS on `item`.
local function DpsWeight(item, weights)
    local w
    if RANGED_INV[item.slot] then w = weights.rangedDps else w = weights.dps end
    return w or 0
end

-- The weight of a point of an off-hand weapon's DPS: the spec's ohDps, else
-- half of dps (off-hand hits do half damage).
function ns.OffDpsWeight(weights)
    return weights.ohDps or 0.5 * (weights.dps or 0)
end

-- A weapon's damage score: its DPS times `dpsWeight`, plus its speed's
-- (ns.SpeedScore with speed weight `key`). Speed can cancel the DPS's value
-- but not take it below nothing.
local function WeaponScore(item, dps, dpsWeight, weights, key)
    return math.max(0, dps * dpsWeight + ns.SpeedScore(item, weights, key))
end

-- Score parts of an item: stats (with racial stat multipliers), weapon DPS
-- and speed, racial weapon-crit bonus, and weapon DPS and speed in the off
-- hand. `pct` is ns.PctWeights.
local function ScoreParts(item, weights, racial, pct)
    local stats = StatScore(item.stats or {}, weights, racial, pct)
    -- The item's effect, as the stats it is worth to this spec (no racial multiplier:
    -- they aren't the item's own).
    local effect = EffectStats(item, pct)
    local effectScore = effect and EffectScore(effect, weights, pct) or 0
    stats = stats + effectScore
    local dps, offDps = 0, 0
    if item.weapon and item.weapon.dps then
        local ranged = RANGED_INV[item.slot]
        dps = WeaponScore(item, item.weapon.dps, DpsWeight(item, weights), weights, ranged and "rangedSpeed" or "speed")
        if item.class == 2 and not ranged then
            offDps = WeaponScore(item, item.weapon.dps, ns.OffDpsWeight(weights), weights, "ohSpeed")
            -- In the off hand (stats + offDps) the effect counts at its off-hand value.
            if effect and effect.offHand then
                offDps = offDps + EffectScore(effect.offHand, weights, pct) - effectScore
            end
        end
    end
    local bonus = 0
    local wc = racial and racial.weaponCrit
    if wc and item.class == 2 and not RANGED_INV[item.slot] and wc.subclasses[item.subclass] then
        bonus = wc.pct * pct.critPct
    end
    return stats, dps, bonus, offDps
end

function ns.ScoreItem(item, weights, racial, pct)
    local stats, dps, bonus = ScoreParts(item, weights, racial, pct)
    return stats + dps + bonus
end

---------------------------------------------------------------- random suffixes

-- Forever's random suffixes ("of the Monkey") are bonus lists, as on Retail:
-- an item's `rand` names the ones it drops with (ns.SuffixTrees, Data/Tables.lua),
-- each a share of the item's stat budget per stat. The budget depends on the
-- item's level, quality and slot type: 0 two-handers, head, chest and legs;
-- 1 shoulders, waist, feet, hands and trinkets; 2 neck, rings, cloaks, wrists,
-- shields and held in off hand; 3 one-handed weapons; 4 ranged weapons and wands.
-- A caster suffix ("of Sorcery", ns.Suffixes' `caster`) also cuts a weapon's
-- DPS, to its weapon.cdps.
local FULL_SLOT = { [1] = true, [5] = true, [7] = true, [20] = true }
local MINOR_SLOT = { [3] = true, [6] = true, [8] = true, [10] = true, [12] = true }
local TWO_HAND_SUB = { [1] = true, [5] = true, [6] = true, [8] = true, [10] = true }
local RANGED_SUB = { [2] = true, [3] = true, [16] = true, [18] = true, [19] = true }

local function SuffixSlotType(item)
    if item.class == 2 then
        return TWO_HAND_SUB[item.subclass] and 0 or RANGED_SUB[item.subclass] and 4 or 3
    end
    return FULL_SLOT[item.slot] and 0 or MINOR_SLOT[item.slot] and 1 or 2
end

local suffixCache = setmetatable({}, { __mode = "k" })

-- The random suffixes `item` drops with, each with its stats on it:
-- { { id = ns.Suffixes id, stats = { agi = 7, sta = 7 } }, ..., byId = { [id] = stats } };
-- empty for an item without (or without a stat budget at its level).
function ns.ItemSuffixes(item)
    local list = suffixCache[item]
    if list then return list end
    list = { byId = {} }
    local tree = item.rand and ns.SuffixTrees and ns.SuffixTrees[item.rand]
    local budget = tree and ns.StatBudget[item.itemLevel]
    budget = budget and budget[item.quality]
    budget = budget and budget[SuffixSlotType(item) + 1]
    for _, id in ipairs(budget and tree or {}) do
        local suffix = ns.Suffixes[id]
        if suffix then
            local stats = {}
            for key, share in pairs(suffix.stats) do
                local value = math.floor(share * budget / 10000 + 0.5)
                if value ~= 0 then stats[key] = value end
            end
            list[#list + 1] = { id = id, stats = stats }
            list.byId[id] = stats
        end
    end
    suffixCache[item] = list
    return list
end

-- The DPS of weapon `item` with random suffix `id`, when the suffix cuts it.
local function CasterDps(item, id)
    return item.weapon and item.weapon.cdps and ns.Suffixes[id].caster and item.weapon.cdps
end

-- `item` with random suffix `id` (ns.Suffixes): its stats plus the suffix's,
-- and its DPS with it, or nil when it doesn't drop with that suffix.
function ns.SuffixedItem(item, id)
    for _, s in ipairs(ns.ItemSuffixes(item)) do
        if s.id == id then
            local out, stats = {}, {}
            for k, v in pairs(item) do out[k] = v end
            for k, v in pairs(item.stats or {}) do stats[k] = v end
            for k, v in pairs(s.stats) do stats[k] = (stats[k] or 0) + v end
            out.stats, out.rand, out.suffix = stats, nil, id
            local cdps = CasterDps(item, id)
            if cdps then out.weapon = { speed = item.weapon.speed, dps = cdps } end
            return out
        end
    end
end

-- { [tree] = { suffix, ... } }: the SUFFIX_PICKS suffixes of each
-- ns.SuffixTrees entry that score best (StatScore) with these weights, and as
-- many caster suffixes, which can lose on a weapon by the DPS they cut. A
-- suffix's stats are shares of the same budget on every item of its tree, so
-- these are the same for all of them, and each ranking works them out once;
-- BestSuffix then scores the few on the item itself, as rounding a small
-- budget can put the second or third first (3 Strength against 2 + 2 Stamina).
local SUFFIX_PICKS = 5
local function BestSuffixes(weights, racial, pct)
    local value, best = {}, {}
    for id, suffix in pairs(ns.Suffixes or {}) do value[id] = StatScore(suffix.stats, weights, racial, pct) end
    local function ByValue(a, b) return value[a] > value[b] end
    for tree, list in pairs(ns.SuffixTrees or {}) do
        local sorted = {}
        for _, id in ipairs(list) do
            if value[id] then sorted[#sorted + 1] = id end
        end
        table.sort(sorted, ByValue)
        local picks, plain, caster = {}, 0, 0
        for _, id in ipairs(sorted) do
            if ns.Suffixes[id].caster then
                caster = caster + 1
                if caster <= SUFFIX_PICKS then picks[#picks + 1] = id end
            else
                plain = plain + 1
                if plain <= SUFFIX_PICKS then picks[#picks + 1] = id end
            end
        end
        best[tree] = picks
    end
    return best
end

-- The suffix of `item` (of its tree's picks, BestSuffixes) that scores best on
-- it with its DPS (`dps` and `offDps`, the scores of the item's own), the
-- score of its stats, of its DPS and of its DPS in the off hand; nil, `dps`
-- and `offDps` without one. A suffix is picked as in the main hand: casters,
-- whose suffixes cut DPS, don't wield an off hand.
local function BestSuffix(item, picks, weights, racial, pct, dps, offDps)
    local byId = ns.ItemSuffixes(item).byId
    local best, bestStats, bestDps, bestOff
    for _, id in ipairs(picks or {}) do
        local stats = byId[id]
        if stats then
            local s = StatScore(stats, weights, racial, pct)
            local cdps = CasterDps(item, id)
            -- (a caster suffix cuts the DPS, not the speed)
            local d = cdps and WeaponScore(item, cdps, DpsWeight(item, weights), weights,
                RANGED_INV[item.slot] and "rangedSpeed" or "speed") or dps
            if not best or s + d > bestStats + bestDps then
                best, bestStats, bestDps = id, s, d
                bestOff = cdps and offDps > 0 and WeaponScore(item, cdps, ns.OffDpsWeight(weights), weights, "ohSpeed")
                    or offDps
            end
        end
    end
    return best, bestStats, bestDps or dps, bestOff or offDps
end

-- Item tooltip lines for the percent stats (ns.PctStats) of `item`, scored for
-- profile `p`: { { "includes +1% crit", "+29.9" }, ... }. Stats the profile
-- doesn't value are left out.
function ns.PctScoreLines(item, p)
    local lines = {}
    local weights = item.stats and ns.GetWeights(p.classFile, p.spec, p.level, ns.WeightSetup(p), p.weights)
    if not weights then return lines end
    local pct = ns.PctWeights(p)
    for _, s in ipairs(ns.PctStats) do
        local value = item.stats[s.key]
        local w = pct[s.key]
        if w == nil then w = weights[s.key] or 0 end
        if value and w ~= 0 then
            lines[#lines + 1] = { string.format(L["includes %s"], ns.PctLabel(s, value)),
                                  string.format("%+.1f", value * w) }
        end
    end
    return lines
end

-- Scorer for items worn by profile `p`: function(item, groupKey) -> score, by
-- the same rules as ns.Rank: off-hand weapons count their DPS with
-- ns.OffDpsWeight, and the racial weapon crit only counts outside the off
-- hand. Nil without weights.
function ns.SlotScorer(p)
    local weights = ns.GetWeights(p.classFile, p.spec, p.level, ns.WeightSetup(p), p.weights)
    if not weights then return nil end
    local racial = ns.Racials[p.raceId]
    local pct = ns.PctWeights(p)
    return function(item, key)
        local stats, dps, bonus, offDps = ScoreParts(item, weights, racial, pct)
        if key == "offhand" then return stats + offDps end
        return stats + dps + bonus
    end
end

local function ByScore(a, b)
    if a.score ~= b.score then return a.score > b.score end
    local al, bl = a.item.itemLevel or 0, b.item.itemLevel or 0
    if al ~= bl then return al > bl end -- stat-less relics: newest first
    return a.id < b.id
end

local function NewBucket()
    return { all = {}, quest = {}, drop = {}, crafted = {}, boe = {} }
end

local function AddEntry(bucket, entry)
    bucket.all[#bucket.all + 1] = entry
    local seen = {}
    for _, s in ipairs(entry.sources) do
        if not seen[s.type] then
            seen[s.type] = true
            bucket[s.type][#bucket[s.type] + 1] = entry
        end
    end
end

local function SortBucket(bucket)
    for _, list in pairs(bucket) do table.sort(list, ByScore) end
end

-- Adds worn entry `e` to bucket.all, before it is sorted: in place of the
-- data's entry for the same item when it scores higher (a random suffix),
-- else only when the item isn't listed yet.
local function AddOwned(bucket, e)
    for i, x in ipairs(bucket.all) do
        if x.id == e.id then
            if e.score > x.score then bucket.all[i] = e end
            return
        end
    end
    bucket.all[#bucket.all + 1] = e
end

-- Entry for one slot. In the off hand a weapon's DPS counts as c.offDps, and
-- the racial crit bonus only counts in the main hand, since it applies once.
local function MakeEntry(c, offHand)
    local score = c.stats + (offHand and c.offDps or c.dps + c.bonus)
    local e = { id = c.id, item = c.item, sources = c.sources, score = score, levels = c.levels,
                owned = c.owned, link = c.link, suffix = c.suffix }
    if not offHand and c.bonus > 0 then e.racialBonus, e.racialName = c.bonus, c.racialName end
    return e
end

-- Look-ahead upgrades for one slot and source type (any source when nil):
-- items that become available from it after the player's level, in the order
-- they do, keeping only those that beat everything available before them.
-- `current` is the slot's ranked list for that source now; `slots` is 2 for
-- rings and trinkets, where beating the second best counts. Kept entries are
-- copies with `level` (when it opens up), `gain` (score over the item it
-- would replace), `sourceType` and `opensBy` (the source type it opens up
-- from first: the one its row names).
local function UpgradePath(entries, current, slots, sourceType)
    local list = {}
    for _, e in ipairs(entries) do
        local level, by
        for t, l in pairs(e.levels) do
            if (not sourceType or t == sourceType) and (not level or l < level) then level, by = l, t end
        end
        if level then list[#list + 1] = { entry = e, level = level, by = by } end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return ByScore(a.entry, b.entry)
    end)
    local best = {} -- the `slots` best scores so far, best first
    for i = 1, slots do best[i] = current[i] and current[i].score or 0 end
    local path = {}
    for _, u in ipairs(list) do
        local e = u.entry
        if e.score > best[slots] * (1 + MIN_UPGRADE_GAIN) then
            local copy = {}
            for k, v in pairs(e) do copy[k] = v end
            copy.level, copy.gain, copy.sourceType, copy.opensBy = u.level, e.score - best[slots], sourceType, u.by
            path[#path + 1] = copy
            best[slots] = e.score
            table.sort(best, function(a, b) return a > b end)
        end
    end
    return path
end

-- The hands' rows (bucket.pick, ns.SlotPick). One item fills both only when a
-- second copy can be had (ns.TwoCopies: not a unique one or a quest's): where
-- both hands' best is the same item and it can't, it goes to the hand the
-- pair adds up higher with, and the other hand's row takes its next best. Not
-- when you wear it in both hands. The lists keep every item, that one in both
-- hands; bucket.taken is the item the other hand's row holds.
local function PickPair(main, off)
    local m, o = main.all[1], off.all[1]
    main.paired, off.paired, main.pick, off.pick = true, true, m, o
    if m and o and m.id == o.id and not (m.owned and o.owned) and not ns.TwoCopies(m.item) then
        local m2, o2 = main.all[2], off.all[2]
        if m.score + (o2 and o2.score or 0) >= (m2 and m2.score or 0) + o.score then
            off.pick, off.taken = o2, m.id
        else
            main.pick, main.taken = m2, o.id
        end
    end
end

-- The hands of setup `key` for profile `p` (ns.SetupFits). `owned`: worn
-- weapons, each only for the hand it is worn in.
local function BuildHands(p, key, weapons, owned)
    local main, off = NewBucket(), ns.WeaponSetups[key].off and NewBucket() or nil
    for _, c in ipairs(weapons) do
        if ns.SetupFits(p, key, "main", c.item) then
            local e = MakeEntry(c)
            if e.score > 0 then AddEntry(main, e) end
        end
        if off and ns.SetupFits(p, key, "off", c.item) then
            local e = MakeEntry(c, true)
            if e.score > 0 then AddEntry(off, e) end
        end
    end
    for _, c in ipairs(owned) do
        if c.key == "mainhand" and ns.SetupFits(p, key, "main", c.item) then
            local e = MakeEntry(c)
            if e.score > 0 then AddOwned(main, e) end
        elseif c.key == "offhand" and off and ns.SetupFits(p, key, "off", c.item) then
            local e = MakeEntry(c, true)
            if e.score > 0 then AddOwned(off, e) end
        end
    end
    SortBucket(main)
    if off then
        SortBucket(off)
        PickPair(main, off)
    end
    return main, off
end

-- When a look-ahead item becomes usable from each source type: its required
-- level, that type's earliest source, and the level the character can wear
-- it from (ns.WearLevel: weapon training, mail and plate). Returns
-- { [sourceType] = level }, sources (earliest first); nil when nothing opens
-- up after the player's level and by `maxLevel`.
local function UpcomingLevels(item, p, maxLevel, classArmorOnly)
    -- (the cheap checks first: this runs for most items)
    if (item.reqLevel or 0) > maxLevel then return nil end
    local sources = UsableSources(item, p, maxLevel)
    if #sources == 0 then return nil end
    local future = setmetatable({ level = maxLevel }, { __index = p })
    if not CanEquip(item, future) then return nil end
    local floor = math.max(item.reqLevel or 0, ns.WearLevel(item, p) or maxLevel)
    local levels
    for _, s in ipairs(sources) do
        local level = math.max(floor, SourceLevel(s))
        if level > p.level and level <= maxLevel and not (levels and levels[s.type] and levels[s.type] <= level)
            and not (classArmorOnly and IsLighterArmorAt(item, p.classId, level)) then
            levels = levels or {}
            levels[s.type] = level
        end
    end
    if not levels then return nil end
    table.sort(sources, function(a, b) return SourceLevel(a) < SourceLevel(b) end)
    return levels, sources
end

-- Rank every usable item for player `p`.
-- opts.ahead: also list upgrades that become usable within this many levels.
-- opts.classArmorOnly: skip armor lighter than the class's own type.
-- opts.owned: the character's worn gear (ns.GetEquipped). It is theirs already,
-- so each worn item ranks in its slot's `all` list even when the data doesn't
-- offer it (vendor gear, world drops, a quest reward taken before its quest's
-- level), with owned = true and its link, and is never a look-ahead upgrade.
-- Returns { [groupKey] = { all = {...}, quest = {...}, drop = {...}, crafted = {...}, boe = {...} },
--           weapons = { setup = key },
--           upcoming = { [groupKey] = { all = {...}, quest = {...}, ... } } }
-- Each list holds { id, item, score, sources, suffix?, racialBonus?, racialName? } sorted best
-- first, all usable at the player's level. An item with random suffixes is
-- scored with the one that suits the spec best, its `suffix` (ns.Suffixes id).
-- Sources count as the Sources filters say (ns.SourceOn); an item with no source
-- left is left out. result.offhand is nil when the chosen
-- setup has no off hand (two-hander). result.upcoming (only with opts.ahead) holds
-- each slot's UpgradePath per source (and across all of them); its entries also
-- have `level`, `gain` and `sourceType`.
-- The hands are filled for the chosen weapon setup (ns.GetWeaponSetupPref),
-- and a spec with weights per setup (ns.HasSetupWeights) ranks with its weights.
function ns.Rank(p, opts)
    opts = opts or {}
    local chosen = ns.GetWeaponSetupPref(p)
    local weightSetup = chosen
    local weights = ns.GetWeights(p.classFile, p.spec, p.level, weightSetup, p.weights)
    if not weights then return nil end
    local ahead = opts.ahead or 0
    local racial = ns.Racials[p.raceId]
    local pct = ns.PctWeights(p, weightSetup)
    local crit = racial and racial.weaponCrit
    local racialName = crit and ns.SpellName(crit.spell, crit.name)
    local bestSuffix = BestSuffixes(weights, racial, pct)

    local owned, ownedIds = {}, {}
    for key, list in pairs(opts.owned or {}) do
        for _, w in ipairs(list) do
            local item = w.item
            if item and item.slot and (item.reqLevel or 0) <= p.level and CanEquip(item, p)
                and not (opts.classArmorOnly and ns.IsLighterArmor(item, p)) then
                ownedIds[w.id] = true
                local stats, dps, bonus, offDps = ScoreParts(item, weights, racial, pct)
                owned[#owned + 1] = { id = w.id, item = item, sources = item.sources or {}, stats = stats, dps = dps,
                                      offDps = offDps, bonus = bonus, racialName = racialName, key = key, owned = true,
                                      link = w.link }
            end
        end
    end

    local result = {}
    for _, g in ipairs(ns.SlotGroups) do
        if not g.weapon then result[g.key] = NewBucket() end
    end

    local weapons, upcoming = {}, {} -- hand candidates, bucketed per setup below; look-ahead candidates
    for id, item in pairs(ns.Items) do
        local sources, levels
        if (item.reqLevel or 0) <= p.level then
            sources = UsableSources(item, p, p.level)
            if #sources == 0 or not CanEquip(item, p) or (opts.classArmorOnly and ns.IsLighterArmor(item, p)) then
                sources = nil
            end
        end
        if (not sources or #sources == 0) and ahead > 0 and not ownedIds[id] then
            levels, sources = UpcomingLevels(item, p, p.level + ahead, opts.classArmorOnly)
        end
        if sources and #sources > 0 then
            local stats, dps, bonus, offDps = ScoreParts(item, weights, racial, pct)
            local suffix, extra
            if item.rand then
                suffix, extra, dps, offDps = BestSuffix(item, bestSuffix[item.rand], weights, racial, pct, dps, offDps)
            end
            local c = { id = id, item = item, sources = sources, stats = stats + (extra or 0), dps = dps,
                        offDps = offDps, bonus = bonus, levels = levels, racialName = racialName, suffix = suffix }
            if levels then
                upcoming[#upcoming + 1] = c
            else
                for _, g in ipairs(ns.SlotGroups) do
                    if g.inv and g.inv[item.slot] then
                        local e = MakeEntry(c)
                        -- Relics carry equip effects rather than stats, so list them at 0 too.
                        if e.score > 0 or item.slot == RELIC_INV then AddEntry(result[g.key], e) end
                    end
                end
                weapons[#weapons + 1] = c
            end
        end
    end
    for _, c in ipairs(owned) do
        local bucket = result[c.key] -- (hands: BuildHands)
        if bucket then
            local e = MakeEntry(c)
            if e.score > 0 or c.item.slot == RELIC_INV then AddOwned(bucket, e) end
        end
    end
    for key, bucket in pairs(result) do SortBucket(bucket) end
    -- The second ring or trinket (ns.SlotPick): another copy of the best when
    -- one can be had, not one you'd own already (owned) or its link.
    for _, g in ipairs(ns.SlotGroups) do
        local bucket = g.slots == 2 and result[g.key]
        local top = bucket and bucket.all[1]
        if top and ns.TwoCopies(top.item) then
            local copy = {}
            for k, v in pairs(top) do copy[k] = v end
            copy.owned, copy.link, copy.copy = nil, nil, true
            bucket.second = copy
        end
    end

    result.mainhand, result.offhand = BuildHands(p, chosen, weapons, owned)
    result.weapons = { setup = chosen }

    if ahead > 0 then
        result.upcoming = {}
        for _, g in ipairs(ns.SlotGroups) do
            local current = result[g.key] and result[g.key].all
            if current then
                local entries = {}
                for _, c in ipairs(upcoming) do
                    local e
                    if g.inv and g.inv[c.item.slot] then
                        e = MakeEntry(c)
                    elseif g.weapon then
                        -- A hand's weapon type is judged at the level the item opens up.
                        if not c.at then
                            local first
                            for _, l in pairs(c.levels) do first = math.min(first or l, l) end
                            c.at = setmetatable({ level = first }, { __index = p })
                        end
                        if g.key == "mainhand" and ns.SetupFits(c.at, chosen, "main", c.item) then
                            e = MakeEntry(c)
                        elseif g.key == "offhand" and ns.SetupFits(c.at, chosen, "off", c.item) then
                            e = MakeEntry(c, true)
                        end
                    end
                    if e and e.score > 0 then entries[#entries + 1] = e end
                end
                local slots = g.slots or 1
                if slots == 2 then current = { current[1], ns.SlotPick(result[g.key], 2) }
                elseif result[g.key].paired then current = { result[g.key].pick } end
                local paths = { all = UpgradePath(entries, current, slots) }
                for _, t in ipairs(ns.SourceTypes) do
                    paths[t] = UpgradePath(entries, result[g.key][t], slots, t)
                end
                result.upcoming[g.key] = paths
            end
        end
    end
    return result
end

-- (lines of one item: by score, then suffix)
local function SuffixOrder(a, b)
    if a.id == b.id and a.score == b.score then return (a.suffix or 0) < (b.suffix or 0) end
    return ByScore(a, b)
end

-- Ranked list `list` (one of ns.Rank's for profile `p`, best first) with each
-- item that has random suffixes on a line per suffix, each with its `suffix`
-- and `score`, best first: the window's slot lists show them all, to weigh
-- one against another at the auction house. Suffixes that add nothing for the
-- spec are left out, and the one of a worn copy listed beside it (its line is
-- the worn one). Only the first `n` lines are worked out; `offHand`: the off
-- hand's list. Entries stay as ns.Rank made them otherwise.
function ns.SuffixRows(list, p, n, offHand)
    local setup = ns.GetWeaponSetupPref(p)
    local weights = ns.GetWeights(p.classFile, p.spec, p.level, setup, p.weights)
    if not weights then return list end
    local racial, pct = ns.Racials[p.raceId], ns.PctWeights(p, setup)
    local worn = {} -- id -> the suffix a worn copy in the list has
    for _, e in ipairs(list) do
        local base = e.owned and ns.Items[e.id]
        local s = base and base.rand and ns.LinkSuffix(e.link, base)
        if s then worn[e.id] = s end
    end
    local out = {}
    for _, e in ipairs(list) do
        if #out >= n then
            table.sort(out, SuffixOrder)
            if out[n].score >= e.score then break end
        end
        local added = false
        local base = not e.owned and e.item and e.item.rand and e.item
        for _, s in ipairs(base and ns.ItemSuffixes(base) or {}) do
            if s.id ~= worn[e.id] and (s.id == e.suffix or StatScore(s.stats, weights, racial, pct) > 0) then
                local stats, dps, bonus, offDps = ScoreParts(ns.SuffixedItem(base, s.id), weights, racial, pct)
                local line = {}
                for k, v in pairs(e) do line[k] = v end
                line.suffix, line.score = s.id, stats + (offHand and offDps or dps + bonus)
                out[#out + 1], added = line, true
            end
        end
        if not added and not (base and worn[e.id] == e.suffix) then out[#out + 1] = e end
    end
    table.sort(out, SuffixOrder)
    return out
end

local INV_LABEL = {
    [1] = L["Head"], [2] = L["Neck"], [3] = L["Shoulder"], [5] = L["Chest"], [6] = L["Waist"], [7] = L["Legs"],
    [8] = L["Feet"], [9] = L["Wrist"], [10] = L["Hands"], [11] = L["Finger"], [12] = L["Trinket"],
    [13] = L["One-Hand"], [14] = L["Shield"], [15] = L["Ranged"], [16] = L["Back"], [17] = L["Two-Hand"],
    [20] = L["Chest"], [21] = L["Main Hand"], [22] = L["Off Hand"], [23] = L["Held In Off-hand"],
    [25] = L["Thrown"], [26] = L["Ranged"], [28] = L["Relic"],
}
local WEAPON_LABEL = {
    [0] = L["Axe"], [1] = L["Axe"], [2] = L["Bow"], [3] = L["Gun"], [4] = L["Mace"], [5] = L["Mace"],
    [6] = L["Polearm"], [7] = L["Sword"], [8] = L["Sword"], [10] = L["Staff"], [13] = L["Fist Weapon"],
    [15] = L["Dagger"], [16] = L["Thrown"], [18] = L["Crossbow"], [19] = L["Wand"],
}
local ARMOR_LABEL = { [1] = L["Cloth"], [2] = L["Leather"], [3] = L["Mail"], [4] = L["Plate"] }

-- The slot, or for a weapon its type (two-handers say so): "Chest", "Finger",
-- "Sword", "Two-Hand Sword", "Bow" ...
function ns.ItemSlotLabel(item)
    if item.class == 2 and item.slot ~= 17 then return WEAPON_LABEL[item.subclass] or L["Weapon"] end
    if item.class == 2 then return ns.ItemTypeLabel(item) end
    return INV_LABEL[item.slot] or "?"
end

-- Every label ItemSlotLabel gives, for sizing the column that shows them.
function ns.SlotLabels()
    local out = { L["Weapon"], string.format(L["%s %s"], INV_LABEL[17], L["Weapon"]) }
    for _, label in pairs(INV_LABEL) do out[#out + 1] = label end
    for _, label in pairs(WEAPON_LABEL) do out[#out + 1] = label end
    for _, sub in ipairs({ 1, 5, 6, 8, 10 }) do -- (the two-handed kinds)
        out[#out + 1] = string.format(L["%s %s"], INV_LABEL[17], WEAPON_LABEL[sub])
    end
    return out
end

-- "Two-Hand Sword", "Chest, Mail", "Finger" ...
function ns.ItemTypeLabel(item)
    local inv = INV_LABEL[item.slot] or "?"
    if item.class == 2 then
        local w = WEAPON_LABEL[item.subclass] or L["Weapon"]
        if RANGED_INV[item.slot] or item.slot == 25 then return w end
        return string.format(L["%s %s"], inv, w)
    end
    local armor = ARMOR_LABEL[item.subclass]
    return armor and string.format(L["%s, %s"], inv, armor) or inv
end

-- Marks a dungeon drop that binds on equip.
local BOE_HEX = "|cff33cccc"

-- Short human-readable description of a source. `nameColor` (a "|cff..."
-- code) colors a quest's name, e.g. to mark it as hoverable. A quest is
-- marked "Quest: ", or by `questMark` in its place: the quest icon in the
-- window's lists, "" where the list already says quest.
function ns.DescribeSource(s, nameColor, questMark)
    if s.type == "quest" then
        local zone = ns.ZoneName(s.zoneId)
        local name = ns.QuestName(s.id, s.name)
        if nameColor then name = nameColor .. name .. "|r" end
        local text = name .. (s.level and (" [" .. s.level .. "]") or "")
            .. (zone and string.format(L[" (%s)"], zone) or "")
        return questMark and (questMark .. text) or string.format(L["Quest: %s"], text)
    elseif s.type == "drop" then
        return string.format(L["%s, %s"], ns.NpcName(s.npcId, s.npc), ns.PlaceName(s.zoneId, s.zone))
            .. (s.boe and (" " .. BOE_HEX .. L["(BoE)"] .. "|r") or "")
    elseif s.type == "crafted" then
        return string.format("%s%s", L[s.profession], s.skill and (" " .. s.skill) or "")
    elseif s.type == "boe" then
        -- A dungeon's boss or trash, a rare, or a world drop (of one zone, or anywhere).
        local place = s.zone and ns.PlaceName(s.zoneId, s.zone) or ns.ZoneName(s.zoneId)
        local what = (s.npcId or s.dungeon) and ns.NpcName(s.npcId, s.npc) or L["World drop"]
        return place and string.format(L["%s, %s"], what, place) or what
    end
    return s.type
end

---------------------------------------------------------------- quest tooltip

local SIDE_LABEL = { [1] = "|cff4a9eff" .. L["Alliance"] .. "|r", [2] = "|cffff5050" .. L["Horde"] .. "|r",
    [3] = "|cffffd100" .. L["Neutral"] .. "|r" }
local GREY, WHITE, GOLD_HEX, GREEN = "|cff888888", "|cffffffff", "|cffffd100", "|cff33ff99"
-- Quests in the quest log; not gold, which is Neutral's (SIDE_LABEL).
ns.ACTIVE_HEX, ns.ACTIVE_RGB = "|cffc080ff", { 0.75, 0.5, 1 }
local START_LABEL = { npc = L["Quest giver"], object = L["Starts at"], item = L["Starts from item"] }

ns.QuestOpen = QuestOpen
ns.FactionSide = FACTION_SIDE -- faction name -> quest side (1 Alliance, 2 Horde)

-- "Alliance" (blue), "Horde" (red) or "Neutral" for a quest (source or
-- ns.Quests entry) side. A quest without one is open to both (QuestOpen), so
-- it is Neutral too.
function ns.QuestSideLabel(side)
    return SIDE_LABEL[side or 3]
end

-- Class names (class-colored in game) for a class quest; nil when every class may take it.
local function ClassNames(mask)
    local names, all = {}, true
    for _, c in ipairs(ns.Classes) do
        if HasBit(mask, c.id) then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.file]
            names[#names + 1] = (color and color.colorStr) and ("|c" .. color.colorStr .. c.name .. "|r") or c.name
        else
            all = false
        end
    end
    return (not all and #names > 0) and table.concat(names, L[", "]) or nil
end

-- Race names for a race quest; nil when the mask covers every race of the quest's side.
local function RaceNames(mask, side)
    local names, all = {}, true
    for _, r in ipairs(ns.Races or {}) do
        if r.id <= 32 and (not side or side == 3 or FACTION_SIDE[r.faction] == side) then
            if HasBit(mask, r.id) then names[#names + 1] = ns.RaceName(r) else all = false end
        end
    end
    return (not all and #names > 0) and table.concat(names, L[", "]) or nil
end

-- "Westfall 56.2, 47.6"; the zone is left out when it is `sameZone`.
local function StartLocation(start, sameZone)
    local zone = start.zoneId ~= sameZone and ns.ZoneName(start.zoneId)
    local coords = start.x and string.format("%.1f, %.1f", start.x, start.y)
    if zone and coords then return zone .. " " .. coords end
    return zone or coords
end

-- The step's quests the profile can take (all of them without a profile, or
-- when none fit), always keeping `keep` (the quest being shown).
local function StepQuests(ids, p, keep)
    local out = {}
    for _, id in ipairs(ids) do
        if not p or id == keep or QuestOpen(ns.Quests[id] or {}, p) then out[#out + 1] = id end
    end
    return #out > 0 and out or ids
end

-- The logged-in character's progress on a quest: "done", "active" (in the
-- quest log) or nil.
local function QuestState(id)
    local log = C_QuestLog
    if not log then return nil end
    if log.IsQuestFlaggedCompleted and log.IsQuestFlaggedCompleted(id) then return "done" end
    if log.GetLogIndexForQuestID and log.GetLogIndexForQuestID(id) then return "active" end
    return nil
end
ns.QuestState = QuestState

-- A chain step's progress: "done" when any of its quests is, else "active" when one is in the log.
local function StepState(ids)
    local state
    for _, id in ipairs(ids) do
        local st = QuestState(id)
        if st == "done" then return st end
        state = state or st
    end
    return state
end

-- Where to go next for quest source `s`: in a chain, the step after the last
-- one (up to this quest) the character has done or has in the quest log, so
-- skipped optional steps don't count, and steps marked optional (a breadcrumb
-- the next step is also given without) are skipped; outside a chain, the
-- quest itself. Returns {id, name, step, steps, start, pending} (`pending`: the earlier step
-- still in the quest log, to hand in first), or nil and "done" / "active" when
-- this quest itself is done or in the log.
function ns.QuestPinTarget(s, p)
    local q = ns.Quests and ns.Quests[s.id] or {}
    local chain = q.chain and ns.QuestChains and ns.QuestChains[q.chain.id]
    local steps = chain or { { s.id } }
    local current = chain and q.chain.step or 1
    local nextStep, pending = 1, nil
    for i = current, 1, -1 do
        local st = StepState(i == current and { s.id } or steps[i])
        if st and i == current then return nil, st end
        if st then
            nextStep = i + 1
            if st == "active" then pending = i end
            break
        end
    end
    while nextStep < current do
        local optional = true
        for _, id in ipairs(steps[nextStep]) do optional = optional and (ns.Quests[id] or {}).optional end
        if not optional then break end
        nextStep = nextStep + 1
    end
    local pick = nextStep == current and s.id or nil
    if not pick then
        local ids = StepQuests(steps[nextStep], p)
        for _, id in ipairs(ids) do
            if (ns.Quests[id] or {}).start then pick = id break end
        end
        pick = pick or ids[1]
    end
    local target = ns.Quests[pick] or {}
    return {
        id = pick, name = ns.QuestName(pick, s.name), start = target.start, pending = pending,
        step = chain and nextStep, steps = chain and #chain,
    }
end

-- The chain of ns.Quests entry `q` for quest `qid`, as rows for the tooltip
-- and the quest panel: {step, steps, rows = {{step, id, name, level, first,
-- current, state, optional}}}, where `first` marks a step's first quest (the
-- others are alternatives) and `state` is the character's progress (QuestState).
local function ChainRows(q, qid, p)
    local chain = q.chain and ns.QuestChains and ns.QuestChains[q.chain.id]
    if not chain then return nil end
    local out = { step = q.chain.step, steps = #chain, rows = {} }
    for i, ids in ipairs(chain) do
        for j, id in ipairs(StepQuests(ids, p, qid)) do
            local cq = ns.Quests[id] or {}
            out.rows[#out.rows + 1] = { step = i, id = id, name = ns.QuestName(id), level = cq.level,
                first = j == 1, current = id == qid, state = QuestState(id), optional = cq.optional }
        end
    end
    return out
end

-- Everything known about quest source `s` (from Data/Quests.lua), for the quest
-- tooltip and the quest panel; nil when the quest has no details.
-- { id, name, level, reqLevel, side, sideLabel, tags = {text...}, zone, start,
--   startLabel, startName, startWhere, rewards, chain (ChainRows), state (QuestState),
--   target / targetState (ns.QuestPinTarget) }
function ns.QuestInfo(s, p)
    local q = s.type == "quest" and ns.Quests and ns.Quests[s.id]
    if not q then return nil end
    local side = q.side or s.side
    local info = {
        id = s.id, name = ns.QuestName(s.id, s.name), level = q.level or s.level,
        reqLevel = s.reqLevel or q.reqLevel, side = side, sideLabel = ns.QuestSideLabel(side), tags = {},
        rewards = q.rewards, state = QuestState(s.id), chain = ChainRows(q, s.id, p),
    }
    local tags = info.tags
    if q.type then tags[#tags + 1] = "|cffff8040" .. string.format(L["%s quest"], L[q.type]) .. "|r" end
    local reqClass = q.reqClass or s.reqClass
    local classes = reqClass and reqClass > 0 and ClassNames(reqClass)
    if classes then tags[#tags + 1] = string.format(L["Class quest: %s"], classes) end
    local reqRace = q.reqRace or s.reqRace
    local races = reqRace and reqRace > 0 and RaceNames(reqRace, side)
    if races then tags[#tags + 1] = string.format(L["Races: %s"], WHITE .. races .. "|r") end
    if p and not (QuestOpen(q, p) and QuestOpen(s, p)) then
        tags[#tags + 1] = "|cffff5050" .. L["Not available to this character"] .. "|r"
    end

    -- The zone the quest is filed under, else (e.g. class quests) where it starts.
    local start = q.start
    local zoneId = s.zoneId
    if not (zoneId and ns.ZoneNames[zoneId]) then zoneId = start and start.zoneId end
    info.zone = ns.ZoneName(zoneId)
    if start then
        info.start, info.startLabel, info.startWhere = start, START_LABEL[start.kind or "npc"], StartLocation(start, zoneId)
        info.startName = ns.StartName(start)
    end
    info.target, info.targetState = ns.QuestPinTarget(s, p)
    return info
end

-- "Level 12, requires level 8" (the requirement in `grey`); "Quest" without a level.
function ns.QuestLevelText(level, reqLevel, grey)
    return (level and string.format(L["Level %d"], level) or L["Quest"])
        .. (reqLevel and (grey .. string.format(L[", requires level %d"], reqLevel) .. "|r") or "")
end

-- One-line summary of a quest's rewards: "Choose 1 of 3 items, 8 silver".
local function RewardSummary(r)
    if not r then return nil end
    local parts = {}
    if r.choices then parts[#parts + 1] = string.format(L["choose 1 of %d items"], #r.choices) end
    if r.items then parts[#parts + 1] = ns.Plural(#r.items, "%d item", "%d items") end
    for _, spell in ipairs(r.spells or {}) do parts[#parts + 1] = ns.SpellName(spell[1], spell[2]) end
    if r.money then parts[#parts + 1] = ns.MoneyText(r.money) end
    if #parts == 0 then return nil end
    local text = table.concat(parts, L[", "])
    -- Capital first letter, ASCII only: upper() works on bytes, and the game's
    -- turns a Chinese character's first byte into another (0xE4 -> 0xC4).
    return (text:gsub("^[a-z]", string.upper))
end

-- "1g 20s 5c" (coin icons in game).
function ns.MoneyText(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
    return table.concat(out, " ")
end

-- Lines for the hover tooltip of quest source `s`: a summary of ns.QuestInfo
-- (the quest panel has the full chain and rewards). Each line is a string or
-- {left, right}; colors are inline. Empty when the quest has no details.
function ns.QuestTooltipLines(s, p)
    local lines = {}
    local info = ns.QuestInfo(s, p)
    if not info then return lines end
    local function Add(left, right) lines[#lines + 1] = right and { left, right } or left end

    Add(GOLD_HEX .. info.name .. "|r")
    Add(ns.QuestLevelText(info.level, info.reqLevel, GREY), info.sideLabel)
    for _, tag in ipairs(info.tags) do Add(tag) end
    Add(" ")
    if info.zone then Add(GREY .. L["Zone"] .. "|r", WHITE .. info.zone .. "|r") end
    if info.start then
        Add(GREY .. info.startLabel .. "|r", WHITE .. info.startName .. "|r")
        if info.startWhere then Add(" ", WHITE .. info.startWhere .. "|r") end
    end
    local chain = info.chain
    if chain then
        local progress
        if info.target and info.target.step and info.target.step ~= chain.step then
            progress = GOLD_HEX .. string.format(L["next for you: step %d"], info.target.step) .. "|r"
        end
        Add(GREY .. L["Quest chain"] .. "|r", WHITE .. string.format(L["step %d of %d"], chain.step, chain.steps) .. "|r")
        if progress then Add(" ", progress) end
    end
    local rewards = RewardSummary(info.rewards)
    if rewards then Add(GREY .. L["Rewards"] .. "|r", WHITE .. rewards .. "|r") end

    Add(" ")
    if info.targetState == "done" then
        Add(GREEN .. L["You have completed this quest"] .. "|r")
    elseif info.targetState == "active" then
        Add(ns.ACTIVE_HEX .. L["This quest is in your quest log"] .. "|r")
    end
    Add(GREY .. L["Click: quest details, chain and rewards"] .. "|r")
    local target = info.target
    if target and target.start and target.start.x then
        Add(GREY .. string.format(L["Right-click: pin %s on your map%s"], ns.StartName(target.start),
            target.step and string.format(L[" (step %d)"], target.step) or "") .. "|r")
    end
    return lines
end
