local _, addonRoot = ...
local ns = addonRoot.WildGear
local L = ns.L

-- Spec keys per class, in Classic talent-tab order (tab 1, 2, 3). Feral and
-- Survival come in two profiles, each with its own weights: the original key
-- keeps its old meaning (cat, ranged) so saved choices and edited weights carry
-- over, and the second profile follows it. Healers have one profile (dungeon
-- healing), and Protection one, the average of dungeon and solo tanking.
ns.Specs = {
    WARRIOR = { "arms", "fury", "protection" },
    PALADIN = { "holy", "protection", "retribution" },
    HUNTER  = { "beastmastery", "marksmanship", "survival", "survivalmelee" },
    ROGUE   = { "assassination", "combat", "subtlety" },
    PRIEST  = { "discipline", "holy", "shadow" },
    SHAMAN  = { "elemental", "enhancement", "restoration" },
    MAGE    = { "arcane", "fire", "frost" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    DRUID   = { "balance", "feral", "bear", "restoration" },
}

ns.MAX_LEVEL = 60

ns.Classes = {
    { id = 1, file = "WARRIOR", name = L["Warrior"] },
    { id = 2, file = "PALADIN", name = L["Paladin"] },
    { id = 3, file = "HUNTER", name = L["Hunter"] },
    { id = 4, file = "ROGUE", name = L["Rogue"] },
    { id = 5, file = "PRIEST", name = L["Priest"] },
    { id = 7, file = "SHAMAN", name = L["Shaman"] },
    { id = 8, file = "MAGE", name = L["Mage"] },
    { id = 9, file = "WARLOCK", name = L["Warlock"] },
    { id = 11, file = "DRUID", name = L["Druid"] },
}

-- ns.Races (id, name, faction, allowed classes, traits) is generated into Data/Tables.lua.

function ns.RaceAllowsClass(race, classId)
    for _, c in ipairs(race.classes or {}) do
        if c == classId then return true end
    end
    return false
end

-- Profile labels are short: the spec selector shows about 14 characters.
local SPEC_LABELS = {
    beastmastery = "Beast Mastery",
    survival = "Surv (Ranged)", survivalmelee = "Surv (Melee)",
    feral = "Feral (Cat)", bear = "Feral (Bear)",
}

-- A language may name a spec differently per class (Korean: warrior Protection
-- 방어, paladin 보호); its Locales file then has "Protection (PALADIN)" too.
function ns.SpecLabel(key, classFile)
    local label = SPEC_LABELS[key] or (key:sub(1, 1):upper() .. key:sub(2))
    return classFile and rawget(L, label .. " (" .. classFile .. ")") or L[label]
end

-- An icon per spec, mostly the Classic talent tabs' (Interface\Icons\...).
local SPEC_ICONS = {
    WARRIOR = { arms = "Ability_Warrior_SavageBlow", fury = "Ability_Warrior_InnerRage", protection = "INV_Shield_06" },
    PALADIN = { holy = "Spell_Holy_HolyBolt", protection = "Spell_Holy_DevotionAura",
                retribution = "Spell_Holy_AuraOfLight" },
    HUNTER  = { beastmastery = "Ability_Hunter_BeastTaming", marksmanship = "Ability_Marksmanship",
                survival = "Ability_Hunter_SwiftStrike", survivalmelee = "Ability_MeleeDamage" },
    ROGUE   = { assassination = "Ability_Rogue_Eviscerate", combat = "Ability_BackStab", subtlety = "Ability_Stealth" },
    PRIEST  = { discipline = "Spell_Holy_WordFortitude", holy = "Spell_Holy_HolyBolt",
                shadow = "Spell_Shadow_ShadowWordPain" },
    SHAMAN  = { elemental = "Spell_Nature_Lightning", enhancement = "Spell_Nature_LightningShield",
                restoration = "Spell_Nature_MagicImmunity" },
    MAGE    = { arcane = "Spell_Holy_MagicalSentry", fire = "Spell_Fire_FireBolt02", frost = "Spell_Frost_FrostBolt02" },
    WARLOCK = { affliction = "Spell_Shadow_DeathCoil", demonology = "Spell_Shadow_Metamorphosis",
                destruction = "Spell_Shadow_RainOfFire" },
    DRUID   = { balance = "Spell_Nature_StarFall", feral = "Ability_Druid_CatForm", bear = "Ability_Racial_BearForm",
                restoration = "Spell_Nature_HealingTouch" },
}

-- The spec's icon texture (nil for an unknown spec).
function ns.SpecIconPath(classFile, key)
    local icon = SPEC_ICONS[classFile] and SPEC_ICONS[classFile][key]
    return icon and ("Interface\\Icons\\" .. icon)
end

-- "|T...|t" markup of the spec's icon, cropped of its border, at the text's
-- height ("" for an unknown spec).
function ns.SpecIcon(classFile, key)
    local path = ns.SpecIconPath(classFile, key)
    return path and ("|T" .. path .. ":0:0:0:0:64:64:5:59:5:59|t") or ""
end

function ns.IsSpec(classFile, key)
    for _, s in ipairs(ns.Specs[classFile] or {}) do
        if s == key then return true end
    end
    return false
end

-- Profession ranks keyed by skill line id (164 blacksmithing, 202 engineering, ...).
-- Tries the Retail API, then the Classic skill-line API. Returns {} if neither works.
local SKILL_BY_NAME = {
    Blacksmithing = 164, Leatherworking = 165, Tailoring = 197, Engineering = 202,
    Enchanting = 333, Alchemy = 171, Jewelcrafting = 755,
}
for _, name in ipairs({ "Blacksmithing", "Leatherworking", "Tailoring", "Engineering", "Enchanting", "Alchemy",
    "Jewelcrafting" }) do
    SKILL_BY_NAME[L[name]] = SKILL_BY_NAME[name] -- the game's names are in its own language
end

function ns.GetProfessions()
    local ranks = {}
    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local ok, p1, p2 = pcall(GetProfessions)
        for _, idx in pairs(ok and { p1, p2 } or {}) do
            local _, _, rank, _, _, _, skillLine = GetProfessionInfo(idx)
            if skillLine then ranks[skillLine] = rank end
        end
    end
    if next(ranks) == nil and type(GetNumSkillLines) == "function" then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank = GetSkillLineInfo(i)
            if not isHeader and SKILL_BY_NAME[name] then ranks[SKILL_BY_NAME[name]] = rank end
        end
    end
    return ranks
end

-- A profession's skill line id from its English name (a crafted source's
-- profession, "Tailoring"), or nil.
function ns.ProfessionId(name)
    return SKILL_BY_NAME[name]
end

-- Whether the profession (skill line id) is one of yours, as Settings' Crafted
-- lists them: picked there (ns.charDB.professions[id] = true, or false for one
-- you've learned but don't count), else learned (p.professions). Bind-on-pickup
-- crafts count only for these.
function ns.HasProfession(p, id)
    local picked = ns.charDB and ns.charDB.professions and ns.charDB.professions[id]
    if picked ~= nil then return picked end
    return p.professions[id] ~= nil
end

-- Switch the profession on or off for this character; a pick that matches the
-- game (learned, or not) isn't kept, so it follows the game again.
function ns.ToggleProfession(p, id)
    local on = not ns.HasProfession(p, id)
    local picks = ns.charDB.professions or {}
    if on == (p.professions[id] ~= nil) then picks[id] = nil else picks[id] = on end
    ns.charDB.professions = next(picks) and picks or nil
end

-- The spell each weapon skill teaches, per weapon type (item subclass).
local WEAPON_SKILL_SPELLS = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201, [8] = 202,
    [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009,
}

-- The weapon types your character has learned the skill for: { [subclass] =
-- true }, or nil when the game can't tell (it reports none, and every
-- character starts with one).
function ns.GetWeaponSkills()
    local Known = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown) or IsSpellKnown
    if not Known then return nil end
    local out
    for subclass, spell in pairs(WEAPON_SKILL_SPELLS) do
        local ok, known = pcall(Known, spell)
        if ok and known then
            out = out or {}
            out[subclass] = true
        end
    end
    return out
end

-- The profession ranks items need to be worn (reqSkillRank), per skill line:
-- { [skill line] = { [rank] = true } }. Built once, after the data loaded.
local skillSteps
local function SkillSteps()
    if not skillSteps then
        skillSteps = {}
        for _, item in pairs(ns.Items or {}) do
            if item.reqSkill and item.reqSkillRank then
                skillSteps[item.reqSkill] = skillSteps[item.reqSkill] or {}
                skillSteps[item.reqSkill][item.reqSkillRank] = true
            end
        end
    end
    return skillSteps
end

-- What your skills change for the rankings: the weapon types learned, the
-- professions learned and, for each, how many of those item ranks it has
-- reached. A skill point changes none of it, but at one of those ranks.
function ns.SkillSignature()
    local parts = {}
    for subclass in pairs(ns.GetWeaponSkills() or {}) do parts[#parts + 1] = "w" .. subclass end
    local steps = SkillSteps()
    for id, rank in pairs(ns.GetProfessions()) do
        local reached = 0
        for need in pairs(steps[id] or {}) do
            if (rank or 0) >= need then reached = reached + 1 end
        end
        parts[#parts + 1] = id .. ":" .. reached
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

function ns.GetPlayer()
    local raceName, raceFile, raceId = UnitRace("player")
    local className, classFile, classId = UnitClass("player")
    local p = {
        raceName = raceName, raceFile = raceFile, raceId = raceId,
        className = className, classFile = classFile, classId = classId,
        level = UnitLevel("player"),
        faction = UnitFactionGroup("player"), -- "Alliance" / "Horde"
        professions = ns.GetProfessions(),
        weaponSkills = ns.GetWeaponSkills(),
    }
    -- Forever has no API that reports the talent spec, so it is always picked by the player.
    local chosen = ns.charDB and ns.charDB.spec
    if chosen and not ns.IsSpec(classFile, chosen) then
        -- A removed profile: the solo tank and healer profiles were merged into their spec.
        local base = chosen:gsub("solo$", "")
        chosen = ns.IsSpec(classFile, base) and base or nil
        ns.charDB.spec = chosen
    end
    p.spec = chosen or ns.Specs[classFile][1]
    p.specSource = chosen and "chosen" or "default"
    return p
end

local function FindBy(list, key, value)
    for _, e in ipairs(list) do
        if e[key] == value then return e end
    end
end

-- Quests whose giver differs by faction carry the Horde one in `startHorde`
-- (Data/Quests.lua); point `start` at the giver for `faction`, so tooltips,
-- the quest panel and map pins all use it.
local questFaction
local function UseQuestStarts(faction)
    if faction == questFaction or not ns.Quests then return end
    questFaction = faction
    for _, q in pairs(ns.Quests) do
        if q.startHorde then
            q.startAlliance = q.startAlliance or q.start
            q.start = faction == "Horde" and q.startHorde or q.startAlliance
        end
    end
end

-- The character the rankings are for: the real player with any manual
-- overrides from the window (charDB.sim = { classFile, raceId, level, spec }).
-- p.simulated is true when anything differs from the real character.
function ns.GetProfile()
    local p = ns.GetPlayer()
    local sim = ns.charDB and ns.charDB.sim
    p.simulated = false
    if not sim then
        UseQuestStarts(p.faction)
        return p
    end

    -- (Another class or race: not your character, so none of its weapon skills.)
    local cls = sim.classFile and FindBy(ns.Classes, "file", sim.classFile)
    if cls and cls.file ~= p.classFile then
        p.classFile, p.classId, p.className = cls.file, cls.id, cls.name
        p.weaponSkills = nil
        -- Not a guess about real talents (only the own class gets the orange hint).
        p.spec, p.specSource = ns.Specs[cls.file][1], "chosen"
        p.simulated = true
    end
    if sim.spec and ns.IsSpec(p.classFile, sim.spec) and sim.spec ~= p.spec then
        p.spec, p.specSource = sim.spec, "chosen"
        p.simulated = true
    end
    local race = sim.raceId and FindBy(ns.Races, "id", sim.raceId)
    if race and race.id ~= p.raceId then
        p.raceId, p.raceFile, p.raceName, p.faction = race.id, race.name, ns.RaceName(race), race.faction
        p.weaponSkills = nil
        p.simulated = true
    end
    if sim.level and sim.level ~= p.level then
        p.level = sim.level
        p.simulated = true
    end
    UseQuestStarts(p.faction)
    return p
end

-- A level previewed ahead is dropped once the character reaches it; else
-- leveling past it would turn it back into a preview. A preview below the
-- character's level stays.
local levelFrame = CreateFrame("Frame")
local lastLevel
levelFrame:RegisterEvent("PLAYER_LOGIN")
levelFrame:RegisterEvent("PLAYER_LEVEL_UP")
levelFrame:SetScript("OnEvent", function(_, event, newLevel)
    local before = lastLevel
    lastLevel = (event == "PLAYER_LEVEL_UP" and newLevel) or UnitLevel("player")
    local sim = ns.charDB and ns.charDB.sim
    if before and sim and sim.level and sim.level > before and sim.level <= lastLevel then sim.level = nil end
end)

-- The game sends SKILL_LINES_CHANGED for every weapon or trade skill point:
-- everything is judged again (UI.Refresh: tooltips, bag arrows, My gear, the
-- wish list, the window) only when ns.SkillSignature changed; otherwise just
-- the Crafting patterns tab's ranks are updated.
local skillFrame = CreateFrame("Frame")
local lastSkills
skillFrame:RegisterEvent("PLAYER_LOGIN")
pcall(skillFrame.RegisterEvent, skillFrame, "SKILL_LINES_CHANGED")
skillFrame:SetScript("OnEvent", function(_, event)
    if not ns.charDB then return end
    local now = ns.SkillSignature()
    if event == "PLAYER_LOGIN" or lastSkills == nil then
        lastSkills = now
    elseif now ~= lastSkills then
        lastSkills = now
        ns.UI.Refresh()
    else
        ns.UI.ShowSkillRanks()
    end
end)
