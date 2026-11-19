local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The character's worn gear, scored with the same weights and rules as the
-- rankings so the window can compare it with them; and the gear of your
-- equipment sets, and the best of what you carry, which item tooltips can
-- compare with instead (Settings: Compare with). Items missing from
-- Data/Items.lua (vendor gear, world drops...) and random-suffix items
-- ("of the Bear", whose extra stats the data doesn't have) are read from the
-- game's own item stats instead.

-- Game stat keys (GetItemStats) -> the Wowhead keys the weights use.
local GAME_STATS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor", RESISTANCE2_NAME = "firres", RESISTANCE3_NAME = "natres",
    RESISTANCE4_NAME = "frores", RESISTANCE5_NAME = "shares", RESISTANCE6_NAME = "arcres",
    ITEM_MOD_ATTACK_POWER_SHORT = "atkpwr", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rgdatkpwr",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feratkpwr",
    ITEM_MOD_SPELL_POWER_SHORT = "splpwr", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spldmg",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "splheal", ITEM_MOD_SPELL_PENETRATION_SHORT = "splpen",
    -- "Increases damage done by Shadow spells and effects": a stat of its own per school.
    ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "arcsplpwr", ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "firsplpwr",
    ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "frosplpwr", ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "holsplpwr",
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "natsplpwr", ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "shasplpwr",
    -- Hit, crit, expertise, dodge, parry and block rating: GAME_PCT below.
    ITEM_MOD_HASTE_RATING_SHORT = "hastertng",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defrtng", ITEM_MOD_BLOCK_VALUE_SHORT = "block",
    ITEM_MOD_MANA_REGENERATION_SHORT = "manargn", ITEM_MOD_POWER_REGEN0_SHORT = "manargn",
    ITEM_MOD_HEALTH_REGEN_SHORT = "healthrgn",
    -- Druid weapons' "in Cat, Bear... forms" attack power: no tooltip line, only this stat.
    ITEM_MOD_MELEE_ATTACK_POWER_SHORT = "feratkpwr",
}
local DPS_STAT = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
-- Forever's gear hit, crit, expertise, dodge, parry and block are flat
-- percentages, which the data keeps as hitPct... If the game reports them as
-- rating, it is at the level-60 rate per 1% (the scraper's GP_RATING_PCT). The
-- data's own percentage wins, so an item isn't counted twice.
local GAME_PCT = {
    ITEM_MOD_HIT_RATING_SHORT = { "hitPct", 10 }, ITEM_MOD_CRIT_RATING_SHORT = { "critPct", 14 },
    ITEM_MOD_EXPERTISE_RATING_SHORT = { "expPct", 10 },
    ITEM_MOD_DODGE_RATING_SHORT = { "dodgePct", 12 }, ITEM_MOD_PARRY_RATING_SHORT = { "parryPct", 15 },
    ITEM_MOD_BLOCK_RATING_SHORT = { "blockPct", 5 },
}

-- Equip locations -> inventoryType, as in Data/Items.lua `slot`.
local INV_TYPE = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11,
    INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16,
    INVTYPE_2HWEAPON = 17, INVTYPE_ROBE = 20, INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22,
    INVTYPE_HOLDABLE = 23, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_RELIC = 28,
}

local function LinkName(link)
    return link and link:match("|h%[(.-)%]|h")
end
ns.LinkName = LinkName

-- Item table (Data/Items.lua shape) built from the game's data for the worn
-- item, on top of `base` (its Data/Items.lua entry) when there is one. Nil
-- while the game hasn't loaded the item yet.
local function GameItem(id, link, base)
    local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local raw = GetStats and link and GetStats(link)
    if not raw or next(raw) == nil then return nil end
    local item, stats = {}, {}
    for k, v in pairs(base or {}) do item[k] = v end
    for k, v in pairs(base and base.stats or {}) do stats[k] = v end
    for key, value in pairs(raw) do
        local pct = GAME_PCT[key]
        if pct then
            if not stats[pct[1]] then stats[pct[1]] = value / pct[2] end
        elseif GAME_STATS[key] then
            stats[GAME_STATS[key]] = value
        end
    end
    -- The game's armor is base plus bonus armor; the data keeps the bonus apart.
    if raw.RESISTANCE0_NAME and stats.armorbonus then stats.armor = raw.RESISTANCE0_NAME - stats.armorbonus end
    item.stats = stats
    item.rand = nil -- (the link's stats have its random suffix's already)
    -- The link's DPS over the data's: a caster random suffix cuts a weapon's.
    if raw[DPS_STAT] then item.weapon = { speed = item.weapon and item.weapon.speed, dps = raw[DPS_STAT] } end
    item.name = LinkName(link) or item.name
    if not base then
        local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local _, _, _, equipLoc, _, classId, subclassId = Instant(id)
        item.class, item.subclass, item.slot = classId, subclassId, INV_TYPE[equipLoc]
        local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local _, _, quality, _, reqLevel = Info(id)
        item.quality, item.reqLevel = quality or 1, reqLevel
        item.sources = {}
        item.name = item.name or string.format(ns.L["item %d"], id)
    end
    return item
end

-- The random suffix (ns.Suffixes id) among the bonus IDs of `link` that item
-- `base` drops with, or nil. An item string's 13th field is how many bonus
-- IDs follow it.
local function LinkSuffix(link, base)
    local itemString = base and base.rand and link and link:match("item:([%-%d:]*)")
    if not itemString then return nil end
    local fields = {}
    for f in (itemString .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = tonumber(f) or false end
    for i = 14, 13 + (fields[13] or 0) do
        for _, s in ipairs(ns.ItemSuffixes(base)) do
            if s.id == fields[i] then return s.id end
        end
    end
end
ns.LinkSuffix = LinkSuffix

-- An item's data from its link (worn gear, item tooltips): its Data/Items.lua
-- entry unless the game shows it under another name (a random suffix) or
-- doesn't know it at all. The link has the name in the game's language, like
-- ns.ItemName. A random suffix's item the game hasn't loaded yet gets the
-- suffix's stats from the data.
local function WornItem(id, link)
    local base = ns.Items[id]
    if base and (not link or LinkName(link) == ns.ItemName(id)) then return base end
    local item = GameItem(id, link, base)
    if not item then
        ns.RequestItem(id)
        local suffix = LinkSuffix(link, base)
        item = suffix and ns.SuffixedItem(base, suffix)
    end
    return item or base
end
ns.LinkItem = WornItem

-- A worn item's name in the game's language, random suffix included: its
-- link's, else the data's (ns.GetEquipped entry `w`).
function ns.WornItemName(w)
    return LinkName(w.link) or ns.ItemName(w.id)
end

-- Worn gear per slot group, best score first:
-- { [groupKey] = { { id, link, invSlot, item, sources, score, suffix?, worn = true }, ... } },
-- `suffix` the random suffix (ns.Suffixes id) of the link.
-- Scored for profile `p`; `score` is nil without a profile or its stat
-- weights, and `item` too while the game is still loading an unknown item.
function ns.GetEquipped(p)
    if not GetInventoryItemID then return nil end
    local Score = p and ns.SlotScorer(p)
    local out = {}
    for _, g in ipairs(ns.SlotGroups) do
        local list = {}
        for _, invSlot in ipairs(g.equip) do
            local id = GetInventoryItemID("player", invSlot)
            if id then
                local link = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
                local item = WornItem(id, link)
                list[#list + 1] = { id = id, link = link, invSlot = invSlot, item = item, worn = true,
                                    suffix = LinkSuffix(link, ns.Items[id]),
                                    sources = item and item.sources or {}, score = item and Score and Score(item, g.key) }
            end
        end
        table.sort(list, function(a, b) return (a.score or -1) > (b.score or -1) end)
        out[g.key] = list
    end
    return out
end

-- Whether item `id`, just loaded (GET_ITEM_INFO_RECEIVED), is one of the worn
-- items in `gear` (ns.GetEquipped) still loading when it was read: gear ranked
-- with it is to be ranked again. Any other item loading changes only names.
function ns.WornWaiting(gear, id)
    for _, list in pairs(gear or {}) do
        for _, w in ipairs(list) do
            if not w.item and w.id == id then return true end
        end
    end
    return false
end

---------------------------------------------------------------- equipment sets

-- Your equipment manager sets (C_EquipmentSet), by name: { { id, name, icon } }.
-- A set's ID can be 0.
function ns.EquipmentSets()
    local E, out = C_EquipmentSet, {}
    if not (E and E.GetEquipmentSetIDs and E.GetEquipmentSetInfo) then return out end
    for _, id in ipairs(E.GetEquipmentSetIDs() or {}) do
        local name, icon = E.GetEquipmentSetInfo(id)
        if name then out[#out + 1] = { id = id, name = name, icon = icon } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Set `id`'s name and icon; nil when there's no such set.
function ns.EquipmentSetInfo(id)
    local E = C_EquipmentSet
    if not (E and E.GetEquipmentSetInfo and type(id) == "number") then return nil end
    return E.GetEquipmentSetInfo(id)
end

-- Where a set's item is (C_EquipmentSet.GetItemLocations), packed as the
-- game's equipment manager does: a worn one is PLAYER + its slot, one in your
-- bags PLAYER + BAGS + bag * 256 + its slot in the bag, one in the bank has
-- BANK set. Else 1: the set ignores the slot, 0: it empties it, -1: its item
-- wasn't found (sold, deleted).
local LOC_PLAYER, LOC_BAGS, LOC_BANK = 0x100000, 0x200000, 0x400000
local SET_MISSING, SET_EMPTY, SET_IGNORED = -1, 0, 1

local function HasFlag(loc, flag) return math.floor(loc / flag) % 2 == 1 end
local function LinkID(link) return link and tonumber(link:match("item:(%d+)")) end

-- Whether the bank is open (BANKFRAME_OPENED... below): only then can the
-- game see what's in it.
local bankOpen = false

-- The bank's containers: the bank itself and its bags (or tabs).
local function BankBags()
    local B, bags, seen = Enum and Enum.BagIndex or {}, {}, {}
    local function Add(bag)
        if bag and not seen[bag] then seen[bag] = true bags[#bags + 1] = bag end
    end
    Add(B.Bank or -1)
    for name, bag in pairs(B) do
        if type(name) == "string" and name:match("^CharacterBankTab_%d+$") then Add(bag) end
    end
    if NUM_BANKBAGSLOTS then
        local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
        for bag = first, first + NUM_BANKBAGSLOTS - 1 do Add(bag) end
    end
    return bags
end

-- Where set items `ids` are, in GetItemLocations' shape, found by hand: the
-- game's GetItemLocations crashes the client while the bank is open
-- (players' crash logs, Forever 1.3.2), so it isn't called then. A worn one
-- first, then one in the bags, then the bank; each copy counts once (two of
-- the same ring). Second result: { [invSlot] = link } of those in the bank.
local function OwnLocations(ids, ignored)
    local C = C_Container
    local locs, bankLinks, taken = {}, {}, {}
    local function Free(key)
        if taken[key] then return false end
        taken[key] = true
        return true
    end
    local banks
    for _, g in ipairs(ns.SlotGroups) do
        for _, invSlot in ipairs(g.equip) do
            local id = ids[invSlot]
            if ignored[invSlot] then
                locs[invSlot] = SET_IGNORED
            elseif not (id and id > 0) then
                locs[invSlot] = SET_EMPTY
            else
                local loc
                for worn = 1, 19 do
                    if GetInventoryItemID("player", worn) == id and Free("p" .. worn) then
                        loc = LOC_PLAYER + worn
                        break
                    end
                end
                if not loc and C and C.GetContainerNumSlots and C.GetContainerItemLink then
                    for bag = 0, NUM_BAG_SLOTS or 4 do
                        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
                            if LinkID(C.GetContainerItemLink(bag, slot)) == id and Free(bag .. ":" .. slot) then
                                loc = LOC_PLAYER + LOC_BAGS + bag * 256 + slot
                                break
                            end
                        end
                        if loc then break end
                    end
                    banks = banks or BankBags()
                    for _, bag in ipairs(loc and {} or banks) do
                        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
                            local link = C.GetContainerItemLink(bag, slot)
                            if LinkID(link) == id and Free(bag .. ":" .. slot) then
                                loc, bankLinks[invSlot] = LOC_BANK, link
                                break
                            end
                        end
                        if loc then break end
                    end
                end
                locs[invSlot] = loc or SET_MISSING
            end
        end
    end
    return locs, bankLinks
end

-- Away from the bank the game reports a set's item in it as not found
-- (players' report, Forever 1.3.0), so each set's bank items are remembered,
-- per character, while the bank is open: charDB.setBank = { [setID] =
-- { [invSlot] = link } } (or the item ID when its link couldn't be read).
-- Updated as SetSlots reads a set: kept while the bank is closed and the slot
-- reads as not found, dropped once it's anywhere else (or really gone).
local function Banked(setID, invSlot, id, loc, bankLink)
    local db = ns.charDB
    if not db then return nil end
    local sets = db.setBank
    local saved = sets and sets[setID] and sets[setID][invSlot]
    local function Save(value)
        if value == saved then return end
        sets = sets or {}
        db.setBank = sets
        sets[setID] = sets[setID] or {}
        sets[setID][invSlot] = value
        if not next(sets[setID]) then sets[setID] = nil end
        if not next(sets) then db.setBank = nil end
    end
    local savedID = type(saved) == "string" and LinkID(saved) or saved
    if type(loc) == "number" and loc > SET_IGNORED and HasFlag(loc, LOC_BANK) and id and id > 0 then
        if bankOpen then Save(bankLink or id) end
        -- (closed: a link saved for this same item, for its suffix)
        return savedID == id and saved or id
    end
    if loc == SET_MISSING and saved and not bankOpen and not (id and id > 0 and id ~= savedID) then
        return saved
    end
    if saved then Save(nil) end
end

-- What set `setID` does with each of the slot groups' inventory slots:
-- { [invSlot] = its item's ID, or "ignored" (left as it is), "empty" (emptied)
-- or "missing" (its item wasn't found) }, where its items are
-- (GetItemLocations), and the links (or IDs) of those in the bank:
-- { [invSlot] = link }. Nil when there's no such set.
local function SetSlots(setID)
    local E = C_EquipmentSet
    local ids = E and E.GetItemIDs and ns.EquipmentSetInfo(setID) and E.GetItemIDs(setID)
    if not ids then return nil end
    local ignored = E.GetIgnoredSlots and E.GetIgnoredSlots(setID) or {}
    local locs, bankLinks
    if bankOpen then
        locs, bankLinks = OwnLocations(ids, ignored)
    else
        locs, bankLinks = E.GetItemLocations and E.GetItemLocations(setID) or {}, {}
    end
    local plan, bank = {}, {}
    for _, g in ipairs(ns.SlotGroups) do
        for _, invSlot in ipairs(g.equip) do
            local id, loc = ids[invSlot], locs[invSlot]
            if ignored[invSlot] or loc == SET_IGNORED then
                plan[invSlot] = "ignored"
            else
                local banked = Banked(setID, invSlot, id, loc, bankLinks[invSlot])
                if banked then
                    bank[invSlot] = banked
                    plan[invSlot] = type(banked) == "string" and LinkID(banked) or banked
                else
                    plan[invSlot] = (loc == SET_MISSING and "missing")
                        or ((loc == SET_EMPTY or not (id and id > 0)) and "empty")
                        or id
                end
            end
        end
    end
    return plan, locs, bank
end

-- The link of the set's item `id` at location `loc` when it's worn or in your
-- bags (nil in the bank, or when the item there isn't it).
local function SetItemLink(loc, id)
    local low, link = loc % LOC_PLAYER, nil
    if loc < 0 or HasFlag(loc, LOC_BANK) then return nil end
    if HasFlag(loc, LOC_BAGS) then
        local C = C_Container
        link = C and C.GetContainerItemLink and C.GetContainerItemLink(math.floor(low / 256), low % 256)
    elseif HasFlag(loc, LOC_PLAYER) and GetInventoryItemLink then
        link = GetInventoryItemLink("player", low)
    end
    if LinkID(link) == id then return link end
end

-- The bank's contents are only there while it's open: each set's bank items
-- are read then (Banked), and again as they move.
local bankEvents = CreateFrame("Frame")
for _, e in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
                     "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "BAG_UPDATE_DELAYED",
                     "PLAYERBANKSLOTS_CHANGED", "EQUIPMENT_SETS_CHANGED" }) do
    pcall(bankEvents.RegisterEvent, bankEvents, e)
end
local BANKER = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker
bankEvents:SetScript("OnEvent", function(_, event, kind)
    if event:find("^PLAYER_INTERACTION") then
        if not (BANKER and kind == BANKER) then return end
        event = event:find("SHOW$") and "BANKFRAME_OPENED" or "BANKFRAME_CLOSED"
    end
    if event == "BANKFRAME_OPENED" then bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then bankOpen = false return end
    if not (bankOpen and ns.charDB) then return end
    for _, set in ipairs(ns.EquipmentSets()) do SetSlots(set.id) end
end)

-- What you'd wear with equipment set `setID` on, in ns.GetEquipped's shape
-- (scored for profile `p`): a slot the set ignores keeps what you wear, and
-- one it empties, or whose item wasn't found, is empty. Its items are read
-- where the set says they are, so random suffixes count; one in the bank is
-- as it was when the bank was last open (Banked). Nil when there's no such set.
function ns.GetSetGear(p, setID)
    local plan, locs, bank = SetSlots(setID)
    if not plan then return nil end
    local Score = p and ns.SlotScorer(p)
    local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local out = {}
    for _, g in ipairs(ns.SlotGroups) do
        local list = {}
        for _, invSlot in ipairs(g.equip) do
            local id, link = plan[invSlot], nil
            if id == "ignored" then
                id = GetInventoryItemID("player", invSlot)
                link = id and GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
            elseif type(id) ~= "number" then
                id = nil
            else
                link = type(bank[invSlot]) == "string" and bank[invSlot]
                    or locs[invSlot] and SetItemLink(locs[invSlot], id) or nil
                -- (else the game's own link, for an item the data lacks: its stats)
                if not link and not ns.Items[id] and Info then link = select(2, Info(id)) end
            end
            if id then
                local item = WornItem(id, link)
                list[#list + 1] = { id = id, link = link, invSlot = invSlot, item = item,
                                    sources = item and item.sources or {}, score = item and Score and Score(item, g.key) }
            end
        end
        table.sort(list, function(a, b) return (a.score or -1) > (b.score or -1) end)
        out[g.key] = list
    end
    return out
end

-- The slot groups (ns.SlotGroups entries, in order) where what you wear isn't
-- what equipment set `setID` puts on. Slots it ignores, or whose item wasn't
-- found, don't count, nor which of a pair's slots a ring or trinket is in.
-- Nil when there's no such set.
function ns.SetDifferences(setID)
    local plan = SetSlots(setID)
    if not plan then return nil end
    local out = {}
    for _, g in ipairs(ns.SlotGroups) do
        local want, have = {}, {}
        for _, invSlot in ipairs(g.equip) do
            local id = plan[invSlot]
            if id ~= "ignored" and id ~= "missing" then
                want[#want + 1] = id == "empty" and 0 or id
                have[#have + 1] = GetInventoryItemID("player", invSlot) or 0
            end
        end
        table.sort(want)
        table.sort(have)
        for i = 1, #want do
            if want[i] ~= have[i] then
                out[#out + 1] = g
                break
            end
        end
    end
    return out
end

local LOSS = 0.05 -- a loss item tooltips show in red

-- Whether what you wear is at least as good as set `setID` (both scored for
-- profile `p`) in every slot group where they differ (`diffs`,
-- ns.SetDifferences): then it's the set that is out of date, and My gear
-- offers to save what you wear into it. The hands count as one, so a
-- two-hander can stand in for a main and off hand. False while an item
-- hasn't loaded, or without stat weights.
function ns.WornBeatsSet(p, setID, diffs)
    local worn, set = ns.GetEquipped(p), ns.GetSetGear(p, setID)
    if not (worn and set) then return false end
    local function Total(gear, keys)
        local sum = 0
        for _, key in ipairs(keys) do
            for _, w in ipairs(gear[key] or {}) do
                if not w.score then return nil end
                sum = sum + w.score
            end
        end
        return sum
    end
    local units, hands = {}, false
    for _, g in ipairs(diffs) do
        if g.weapon then hands = true else units[#units + 1] = { g.key } end
    end
    if hands then units[#units + 1] = { "mainhand", "offhand" } end
    for _, keys in ipairs(units) do
        local have, want = Total(worn, keys), Total(set, keys)
        if not (have and want) or have < want - LOSS then return false end
    end
    return true
end

-- Saves what you wear as set `setID`, the slots it ignores still ignored. The
-- game saves with the equipment manager's own ignore marks (its pane sets
-- them for the set it shows), so they are set for this set, then put back.
function ns.SaveWornToSet(setID)
    local E = C_EquipmentSet
    if not (E and E.SaveEquipmentSet and ns.EquipmentSetInfo(setID)) then return end
    local marks = E.IgnoreSlotForSave and E.UnignoreSlotForSave and E.IsSlotIgnoredForSave
    local before = {}
    if marks then
        local ignored = E.GetIgnoredSlots and E.GetIgnoredSlots(setID) or {}
        for slot = 1, 19 do
            before[slot] = E.IsSlotIgnoredForSave(slot)
            if ignored[slot] then E.IgnoreSlotForSave(slot) else E.UnignoreSlotForSave(slot) end
        end
    end
    E.SaveEquipmentSet(setID)
    if marks then
        for slot = 1, 19 do
            if before[slot] then E.IgnoreSlotForSave(slot) else E.UnignoreSlotForSave(slot) end
        end
    end
end

---------------------------------------------------------------- your bags

-- Bind types (Enum.ItemBind) that bind an item to you when you put it on: on
-- equip, and warbound until equipped.
local BIND_ON_EQUIP = { [2] = true, [9] = true }

-- Whether putting on the item in bag `bag`, slot `slot` (`link`) would bind it
-- to you: it isn't bound yet, and it binds when equipped (or the game can't
-- say how it binds yet).
function ns.WouldBind(bag, slot, link)
    local C = C_Container
    local info = C and C.GetContainerItemInfo and C.GetContainerItemInfo(bag, slot)
    if type(info) ~= "table" or info.isBound ~= false then return false end
    local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local bindType = Info and select(14, Info(link))
    return bindType == nil or BIND_ON_EQUIP[bindType] == true
end

-- The gear in your bags (the backpack and bag slots; the reagent bag holds
-- none) that profile `p` can wear now: { { id, link, item, bag, slot, binds } }
-- (binds: ns.WouldBind), and true when an item the data lacks hadn't loaded
-- yet (it is left out).
local function BagGear(p, classArmorOnly)
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemLink) then return {} end
    local out, missing = {}, false
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) or 0 do
            local link = C.GetContainerItemLink(bag, slot)
            local id = link and tonumber(link:match("item:(%d+)"))
            local item = id and WornItem(id, link)
            if id and not item then missing = true end
            if item and item.slot and (item.reqLevel or 0) <= p.level and ns.CanEquip(item, p)
                and not (classArmorOnly and ns.IsLighterArmor(item, p)) then
                out[#out + 1] = { id = id, link = link, item = item, bag = bag, slot = slot,
                                  binds = ns.WouldBind(bag, slot, link) }
            end
        end
    end
    return out, missing
end

-- Whether two of item `id` can be worn at once: not a unique (or
-- unique-equipped) one, as the game says; yes when it can't tell.
local function TwoAllowed(id)
    local Uniqueness = C_Item and C_Item.GetItemUniquenessByID
    return not (Uniqueness and Uniqueness(id))
end

-- Your gear as profile `p` (one of your specs) would wear it: per slot group
-- the best of what you wear and carry in your bags, scored for `p`, in
-- ns.GetEquipped's shape but only as many as the slot holds. The hands are
-- the best pair any of weapon setups `setupKeys` allows: the setup the spec
-- plays, so a shield it wears stays its off hand when a held off-hand is
-- judged in another setup. Left as worn while a
-- worn weapon is loading. Bag items `p` can't wear now (or, with
-- classArmorOnly, lighter armor; with noBinding, ones that would bind to you,
-- ns.WouldBind) don't count; the others keep their place (bag, slot). Second
-- result: true when a bag item hadn't loaded yet.
function ns.GetBestOwned(p, setupKeys, classArmorOnly, noBinding)
    local worn, Score = ns.GetEquipped(p), ns.SlotScorer(p)
    if not (worn and Score) then return worn, false end
    local bag, missing = BagGear(p, classArmorOnly)
    if noBinding then
        local kept = {}
        for _, c in ipairs(bag) do
            if not c.binds then kept[#kept + 1] = c end
        end
        bag = kept
    end
    local function Entry(c, key)
        return { id = c.id, link = c.link, invSlot = c.invSlot, item = c.item, worn = c.worn,
                 bag = c.bag, slot = c.slot, binds = c.binds,
                 sources = c.item and c.item.sources or {}, score = c.item and Score(c.item, key) }
    end
    local out = {}
    for _, g in ipairs(ns.SlotGroups) do
        if g.inv then
            local list = {}
            for _, w in ipairs(worn[g.key] or {}) do list[#list + 1] = Entry(w, g.key) end
            for _, c in ipairs(bag) do
                if g.inv[c.item.slot] then list[#list + 1] = Entry(c, g.key) end
            end
            -- (on a tie, the most armor: what fills an empty slot when the spec values none of it)
            table.sort(list, function(a, b)
                local sa, sb = a.score or -1, b.score or -1
                if sa ~= sb then return sa > sb end
                local aa = a.item and a.item.stats and a.item.stats.armor or 0
                local ab = b.item and b.item.stats and b.item.stats.armor or 0
                return aa > ab
            end)
            -- A second ring or trinket: not another copy of the first when that one is unique.
            if g.slots and list[2] and list[2].id == list[1].id and not TwoAllowed(list[1].id) then
                table.remove(list, 2)
            end
            for i = #list, (g.slots or 1) + 1, -1 do list[i] = nil end
            out[g.key] = list
        end
    end

    local main, off = worn.mainhand and worn.mainhand[1], worn.offhand and worn.offhand[1]
    if (main and not main.item) or (off and not off.item) then
        out.mainhand, out.offhand = worn.mainhand, worn.offhand
        return out, missing
    end
    local weapons = {}
    for _, c in ipairs(bag) do weapons[#weapons + 1] = c end
    if main then weapons[#weapons + 1] = main end
    if off then weapons[#weapons + 1] = off end
    -- The best pair (or main hand alone) of any of the setups; a one-hander
    -- can't be in both hands, and a second copy of it only when it isn't unique.
    local bestMain, bestOff, best
    for _, key in ipairs(setupKeys) do
        local set = ns.WeaponSetups[key]
        for _, m in ipairs(set and weapons or {}) do
            if ns.SetupFits(p, key, "main", m.item) then
                local ms = Score(m.item, "mainhand")
                if not best or ms > best then bestMain, bestOff, best = m, nil, ms end
                for _, o in ipairs(set.off and weapons or {}) do
                    if o ~= m and (o.id ~= m.id or TwoAllowed(m.id)) and ns.SetupFits(p, key, "off", o.item) then
                        local total = ms + Score(o.item, "offhand")
                        if total > best then bestMain, bestOff, best = m, o, total end
                    end
                end
            end
        end
    end
    out.mainhand = bestMain and { Entry(bestMain, "mainhand") } or {}
    out.offhand = bestOff and { Entry(bestOff, "offhand") } or {}
    return out, missing
end
