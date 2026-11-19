local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The addon follows the game's text language: one of LANGUAGES below, else
-- English. UI strings are keyed by their English text (L["Best in slot"]);
-- Locales\<locale>.lua fills in the translation, and a string it lacks shows in
-- English.
--
-- Names of game things (items and their random suffixes, quests, NPCs, zones...) come from the data,
-- which is English. On a translated client the helpers below return the names
-- in Data\Names_<locale>.lua (ns.LocalNames), or the game's own for factions,
-- spells and races, falling back to the English name.

ns.locale = GetLocale and GetLocale() or "enUS"

-- The languages the addon is translated into, and what else differs with them:
--   bigFont  the client's fonts run larger than the Latin ones, so the window's
--            text is a point smaller (Theme.lua)
--   wowhead  Wowhead's path for the language (QuestPanel.lua's links)
--   plural   for a language with a third plural form: n -> "one", "few" or
--            "many" (ns.Plural)
local LANGUAGES = {
    zhCN = { bigFont = true, wowhead = "cn" },
    zhTW = { bigFont = true, wowhead = "cn" }, -- Wowhead has no Traditional Chinese
    deDE = { wowhead = "de" },
    koKR = { bigFont = true, wowhead = "ko" },
    esES = { wowhead = "es" },
    esMX = { wowhead = "es" }, -- Wowhead has no Latin American Spanish
    -- Russian: 1, 21, 31 предмет; 2-4, 22-24 предмета; 0, 5-20, 25-30 предметов.
    ruRU = { wowhead = "ru", plural = function(n)
        local ten, hundred = n % 10, n % 100
        if ten == 1 and hundred ~= 11 then return "one" end
        if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then return "few" end
        return "many"
    end },
}
ns.translated = LANGUAGES[ns.locale] ~= nil
ns.language = LANGUAGES[ns.locale] or {}

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- string.format(L[one or many], n): "1 item" / "3 items". A language with a
-- plural rule picks by it, and its "few" form is ns.PluralFew[many], which its
-- Locales file fills in (Russian "%d предмета").
function ns.Plural(n, one, many)
    local rule = ns.language.plural
    if not rule then return string.format(L[n == 1 and one or many], n) end
    local form = rule(n)
    local few = form == "few" and ns.PluralFew and ns.PluralFew[many]
    return string.format(few or L[form == "one" and one or many], n)
end

local function Local(kind, id)
    local names = id and ns.LocalNames and ns.LocalNames[kind]
    return names and names[id]
end

-- A language Wowhead lacks (zhTW): another one's name, converted (zhCN's), of
-- an item or quest no scan named. The translations differ, so the game's own
-- name goes first.
local function Fallback(kind, id)
    local names = id and ns.LocalFallbackNames and ns.LocalFallbackNames[kind]
    return names and names[id]
end

-- A non-empty name from a game API, or nil.
local function Nonempty(name)
    return type(name) == "string" and name ~= "" and name or nil
end

-- Wowhead hasn't translated every name (it lists ~300 items as "[Vendetta]"),
-- so items and quests missing from ns.LocalNames take the game's own name once
-- it has loaded them; the window refreshes when it has (UI.lua). Ids asked
-- for this session, so each is only asked once:
local requested = { item = {}, quest = {} }

local function GameItemName(id)
    if not (C_Item and C_Item.GetItemNameByID) then return nil end
    local name = Nonempty(C_Item.GetItemNameByID(id))
    if not name and not requested.item[id] and C_Item.RequestLoadItemDataByID then
        requested.item[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
    return name
end

local function GameQuestName(id)
    if not (C_QuestLog and C_QuestLog.GetTitleForQuestID) then return nil end
    local name = Nonempty(C_QuestLog.GetTitleForQuestID(id))
    if not name and not requested.quest[id] and C_QuestLog.RequestLoadQuestByID then
        requested.quest[id] = true
        C_QuestLog.RequestLoadQuestByID(id)
    end
    return name
end

-- With `suffix` (an ns.Suffixes id), the name the game gives the item with
-- that random suffix: "Ghostwalker Pads of the Monkey", put together as the
-- game does (ITEM_SUFFIX_TEMPLATE: Chinese and Korean put the suffix first).
function ns.ItemName(id, suffix)
    local item = ns.Items[id]
    local name = Local("item", id) or (ns.translated and GameItemName(id)) or Fallback("item", id)
        or (item and item.name) or string.format(L["item %d"], id)
    local s = suffix and ns.Suffixes and ns.Suffixes[suffix]
    local text = s and (Local("suffix", s.name) or (ns.SuffixNames and ns.SuffixNames[s.name]))
    if not text then return name end
    return string.format(ns.translated and ITEM_SUFFIX_TEMPLATE or "%s %s", name, text)
end

-- `fallback`: the name a quest source carries, for quests missing from ns.Quests.
function ns.QuestName(id, fallback)
    local q = ns.Quests and ns.Quests[id]
    return Local("quest", id) or (ns.translated and GameQuestName(id)) or Fallback("quest", id) or (q and q.name)
        or fallback or ("#" .. id)
end

-- NPC `id` named `fallback` in the data; "Trash" (no id) stands for a dungeon's trash mobs.
function ns.NpcName(id, fallback)
    if not id and fallback == "Trash" then return L["Trash"] end
    return Local("npc", id) or fallback
end

-- Where a quest starts (Data/Quests.lua `start`): an NPC, an object or an item.
function ns.StartName(start)
    local kind = (start.kind == "object" or start.kind == "item") and start.kind or "npc"
    return Local(kind, start.id) or start.name
end

-- A zone's name in the game's language, or nil (English clients use the data's).
local function TranslatedZone(id)
    if not (ns.translated and id) then return nil end
    return Local("zone", id) or Nonempty(C_Map and C_Map.GetAreaInfo and id > 0 and C_Map.GetAreaInfo(id))
end

function ns.ZoneName(id)
    return TranslatedZone(id) or (id and ns.ZoneNames[id])
end

-- Zone `zoneId`, called `name` in the data, which adds the wing of a zone
-- split into wings ("Scarlet Monastery: Graveyard"); `name` as it is on an
-- English client.
function ns.PlaceName(zoneId, name)
    local zone = TranslatedZone(zoneId)
    if not zone then return name end
    local english = ns.ZoneNames[zoneId]
    if name and english and name:sub(1, #english + 2) == english .. ": " then
        return string.format(L["%s: " .. name:sub(#english + 3)], zone)
    end
    return zone
end

-- An ns.Dungeons entry's name.
function ns.DungeonName(d)
    return ns.PlaceName(d.zoneId, d.name)
end

-- A dungeon boss, or its "Trash" / "Quest rewards" group (no id).
function ns.BossName(b)
    if not b.id then return L[b.name] end
    return ns.NpcName(b.id, b.name)
end

function ns.RaceName(race)
    local info = ns.translated and C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(race.id)
    return Nonempty(info and info.raceName) or race.name
end

function ns.FactionName(id)
    if ns.translated then
        local data = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(id)
        local name = Nonempty(data and data.name) or Nonempty(GetFactionInfoByID and GetFactionInfoByID(id))
        if name then return name end
    end
    return ns.FactionNames and ns.FactionNames[id] or string.format(L["faction %d"], id)
end

function ns.SpellName(id, fallback)
    if not (ns.translated and id) then return fallback end
    return Nonempty(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id))
        or Nonempty(GetSpellInfo and GetSpellInfo(id)) or fallback
end

function ns.CurrencyName(id, fallback)
    local info = ns.translated and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
    return Nonempty(info and info.name) or fallback
end
