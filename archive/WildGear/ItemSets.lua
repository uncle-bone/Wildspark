local _, addonRoot = ...
local ns = addonRoot.WildGear

-- The Dungeon loot tab's Sets view: each item set with a piece that drops in
-- the dungeon and that the profile can wear
-- (now or later; with Settings' Armor type: Class type, only its own armor).
-- A set's header (unfolded at first) names it and how many of its pieces you
-- have (worn, in your bags or bank). Under it: every
-- piece in paper doll order, where it comes from (this dungeon's boss, else
-- the place, profession or quest) and a tick when you have it, then the
-- bonuses, the ones you have lit. Bonus text is the game's (the bonus
-- spell's description), in the game's language. Data: Data/Sets.lua.

local UI, L = ns.UI, ns.L
local S = {}
ns.ItemSetLines = S

local SAME, GAIN, GOLD = "|cff888888", "|cff33ff99", "|cffffd100"
local BOE_HEX = "|cff33cccc" -- (Scoring.lua's)
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " -- (UI.lua's WORN_CHECK)
local folds = {} -- [set id] = true for sets folded this session
local waiting = {} -- [spell id] = true while its description loads

local byItem -- [item id] = { set... }
local function SetsOf(id)
    if not byItem then
        byItem = {}
        for _, set in ipairs(ns.ItemSets or {}) do
            for _, iid in ipairs(set.items) do
                byItem[iid] = byItem[iid] or {}
                table.insert(byItem[iid], set)
            end
        end
    end
    return byItem[id]
end

-- Whether you have item `id`: worn, in your bags, or in your bank (as the
-- game last saw it).
local function Have(id)
    if C_Item and C_Item.IsEquippedItem and C_Item.IsEquippedItem(id) then return true end
    local Count = (C_Item and C_Item.GetItemCount) or GetItemCount
    return Count ~= nil and (Count(id, true) or 0) > 0
end

-- Whether profile `p` can wear `item` now or at some level.
local function Wearable(item, p)
    local level = ns.WearLevel(item, p)
    if not level then return false end
    if ns.db.classArmorOnly then
        local at = setmetatable({ level = math.max(level, item.reqLevel or 0) }, { __index = p })
        if ns.IsLighterArmor(item, at) then return false end
    end
    return true
end

-- Bonus text: the bonus spell's description (its first line), loaded on
-- demand; the list redraws once it has.
local function BonusText(spell)
    local Describe = C_Spell and C_Spell.GetSpellDescription
    local text = Describe and Describe(spell)
    if (not text or text == "") and Spell and Spell.CreateFromSpellID and not waiting[spell] then
        waiting[spell] = true
        local s = Spell:CreateFromSpellID(spell)
        if not s:IsSpellEmpty() then
            s:ContinueOnSpellLoad(function()
                waiting[spell] = nil
                UI.Refresh()
            end)
        end
    end
    if not text or text == "" then
        local Name = C_Spell and C_Spell.GetSpellName
        text = Name and Name(spell) or ""
    end
    return text
end

-- Where `dungeon`'s piece comes from: its boss here (`here`), else its first
-- source in short: who drops it where (a boss before trash; another wing of
-- the same instance by the wing's name: "Herod, Armory"), the profession,
-- the quest.
local function PieceSource(id, here, dungeon)
    if here[id] then return ns.BossName(here[id].boss) end
    local item = ns.Items[id]
    local sources = item and item.sources or {}
    local s = sources[1]
    for _, x in ipairs(sources) do
        if x.type == "drop" and x.npcId then s = x break end
    end
    if not s then return "" end
    if s.type == "drop" then
        local place = ns.PlaceName(s.zoneId, s.zone) or ""
        local base = s.zoneId == dungeon.zoneId and ns.ZoneName(dungeon.zoneId)
        if base and place:sub(1, #base) == base and #place > #base then
            place = place:sub(#base + 1):gsub("^[%s:：]+", "")
        end
        local who = s.npcId and ns.NpcName(s.npcId, s.npc) or L["Trash"]
        return string.format(L["%s, %s"], who, place)
    end
    if s.type == "crafted" then return L[s.profession] end
    if s.type == "quest" then return ns.QuestName(s.id, s.name) end
    if s.type == "boe" then
        local place = s.zone and ns.PlaceName(s.zoneId, s.zone) or ns.ZoneName(s.zoneId)
        return place or L["World drop"]
    end
    return ""
end

-- The Sets view's lines (`Add`) for `dungeon` and profile `p`.
function S.Add(dungeon, p, Add)
    if not ns.ItemSets then return end
    -- here[item id] = { boss }: who drops it in this dungeon, a boss
    -- rather than trash (its quest rewards aren't drops).
    local here, sets, seen = {}, {}, {}
    for _, boss in ipairs(dungeon.bosses or {}) do
        for _, drop in ipairs(boss.quest and {} or boss.items or {}) do
            local cur = here[drop.id]
            if not cur or (not cur.boss.id and boss.id) then here[drop.id] = { boss = boss } end
            for _, set in ipairs(SetsOf(drop.id) or {}) do
                if not seen[set.id] then
                    seen[set.id] = true
                    sets[#sets + 1] = set
                end
            end
        end
    end
    local shown = {}
    for _, set in ipairs(sets) do
        local wearable = false
        for _, id in ipairs(set.items) do
            local item = ns.Items[id]
            if item and Wearable(item, p) then wearable = true break end
        end
        if wearable then shown[#shown + 1] = set end
    end
    if #shown == 0 then
        Add({ kind = "note", text = SAME .. L["No item sets for you here."] .. "|r" })
        return
    end
    for i, set in ipairs(shown) do
        if i > 1 then Add({ kind = "spacer" }) end
        local have = 0
        for _, id in ipairs(set.items) do
            if Have(id) then have = have + 1 end
        end
        local folded = folds[set.id] == true
        Add({ kind = "itemset", set = set, have = have, folded = folded,
              action = function()
                  folds[set.id] = not folded
                  UI.Refresh()
              end })
        if not folded then
            for _, id in ipairs(set.items) do
                Add({ kind = "setpiece", id = id, have = Have(id), source = PieceSource(id, here, dungeon), drop = here[id] })
            end
            if set.bonuses[1] then Add({ kind = "spacer" }) end
            for _, b in ipairs(set.bonuses) do
                Add({ kind = "setbonus", pieces = b[1], spell = b[2], on = have >= b[1] })
            end
        end
    end
end

---------------------------------------------------------------- drawing (UI.List.Draw)

local List = UI.List
local Draw = List.Draw

-- Set header: { set, have, folded, action }. On the right, how many of its
-- pieces you have.
function Draw.itemset(line, l)
    line.rule:Show()
    List.SetSide(line, string.format("%s%d/%d|r", l.have > 0 and GAIN or SAME, l.have, #l.set.items))
    List.SetHeader(line, GOLD .. l.set.name .. "|r", List.ShowFold(line, l.folded))
    line.action = l.action
end

-- A piece the data lacks (no known source): its name and quality from the game.
local function GameName(id)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        return SAME .. string.format(L["item %d"], id) .. "|r"
    end
    local quality = C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    return ns.QualityHex(quality) .. name .. "|r"
end

-- Its slot, as the game names it (INVTYPE_FINGER: "Finger").
local function GameSlot(id)
    local Instant = C_Item and C_Item.GetItemInfoInstant
    local equipLoc = Instant and select(4, Instant(id))
    return equipLoc and _G[equipLoc] or ""
end

-- Set piece: { id, have, source, drop ({ boss } when it drops here) }:
-- slot, icon, name (a tick first when you have it), who drops it here (a
-- boss, or Trash), else where it comes from in grey, BoE if it is, and its
-- gain. No drop chance: the data's isn't accurate.
function Draw.setpiece(line, l)
    local item = ns.Items[l.id]
    List.ShowAll(line.slot, line.sIcon, line.sName, line.source, line.gain)
    line.slot:SetText(item and ns.ItemSlotLabel(item) or GameSlot(l.id))
    List.ItemIcon(l.id, line.sIcon)
    -- (a worn one gets its tick from UI.MarkWorn)
    line.sName:SetText((l.have and not UI.IsWorn(l.id) and CHECK or "")
        .. (item and List.ColoredName(l.id) or GameName(l.id)))
    local boe = false
    for _, s in ipairs(item and item.sources or {}) do
        if s.boe or s.type == "boe" then boe = true break end
    end
    line.source:SetText((l.drop and l.source or (SAME .. l.source .. "|r"))
        .. (boe and ("  " .. BOE_HEX .. L["BoE"] .. "|r") or ""))
    -- Its gain over what you wear, as the Summary's picks show it: green when
    -- it's an upgrade (now, or with Look ahead), grey when not; its rank
    -- while planning another class.
    local info = List.RankMap()[l.id]
    local gain = info and (info.upcoming and info.entry.gain or List.Verdict(info))
    if gain then
        line.gain:SetText(string.format("%s%+.1f|r", gain >= 0.05 and GAIN or SAME, gain))
    elseif info and not info.upcoming and not List.Worn() then
        line.gain:SetText(string.format("%s#%d|r", SAME, info.rank))
    else
        line.gain:SetText("")
    end
    line.entry = (info and info.entry)
        or { id = l.id, sources = item and item.sources or {}, why = not item and L["not ranked"] or nil }
end

-- Set bonus: { pieces, spell, on }: "(2) +5 Arcane Resistance.", green once
-- you have that many pieces. The full text on hover.
function Draw.setbonus(line, l)
    local text = BonusText(l.spell)
    local first = text:match("^[^\r\n]*") or text
    List.SetHeader(line, string.format("%s(%d)|r  %s%s|r", l.on and GAIN or SAME, l.pieces,
        l.on and GAIN or "|cffbbbbbb", first), 14, WildGearFontHighlightSmall)
    line.tip = text ~= "" and string.format(ITEM_SET_BONUS_GRAY or "(%d) Set: %s", l.pieces, text) or nil
end
