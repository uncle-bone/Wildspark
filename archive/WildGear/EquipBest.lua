local _, addonRoot = ...
local ns = addonRoot.WildGear

-- My gear's Equip best (UI.lua): puts on the best of what you carry for your
-- main spec, as item tooltips' "Best you have" finds it (ns.GetBestOwned),
-- wherever it beats what you wear. Left out: trinkets (their use and proc
-- effects aren't scored), bag items that would bind to you when put on (you
-- may want to sell or trade them; Equip best's hover lists them), and a
-- two-hander while your off hand has no free bag slot to go to. The items go
-- on one at a time, each once the game has settled the one before, and only
-- out of combat; the cursor is never left holding an item. When they're all
-- on, My gear may offer to save them into your main spec's equipment set
-- (UI.EquipBestDone).

local UPGRADE = 0.05 -- a gain item tooltips show with a green arrow
local STEP = 0.2 -- seconds between moves
local MAX_WAIT = 50 -- steps to wait on a locked item before giving up (10 s)

---------------------------------------------------------------- the plan

-- The weapon setups profile `p` plays: the one picked in the window's Weapons
-- box (as Tooltip.lua's "Best you have").
local function Setups(p)
    return { ns.GetWeaponSetupPref(p) }
end

-- Whether every worn item in `list` is scored (none still loading).
local function Scored(list)
    for _, w in ipairs(list or {}) do
        if not w.score then return false end
    end
    return true
end

local function FreeBagSlots()
    local C = C_Container
    if not (C and C.GetContainerNumFreeSlots) then return math.huge end
    local free = 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local n, family = C.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then free = free + (n or 0) end
    end
    return free
end

-- Armor, rings, ranged: each bag item among the best the slot group holds
-- goes in place of a worn item that isn't among them, the best one on the
-- emptiest slot (an empty one, else the weakest item).
local function SlotSwaps(g, worn, best, swaps)
    local kept, adds, byInv, free = {}, {}, {}, {}
    for _, e in ipairs(best) do
        if e.worn then kept[e.invSlot] = true else adds[#adds + 1] = e end
    end
    for _, w in ipairs(worn) do byInv[w.invSlot] = w end
    for _, invSlot in ipairs(g.equip) do
        if not kept[invSlot] then free[#free + 1] = { invSlot = invSlot, old = byInv[invSlot] } end
    end
    table.sort(free, function(a, b)
        local sa, sb = a.old and a.old.score or -math.huge, b.old and b.old.score or -math.huge
        if sa ~= sb then return sa < sb end
        return a.invSlot < b.invSlot
    end)
    for i, new in ipairs(adds) do -- (best first)
        local f = free[i]
        local gain = f and new.score - (f.old and f.old.score or 0)
        -- (anything you can wear beats an empty slot, scored or not)
        if gain and (gain >= UPGRADE or not f.old) then
            swaps[#swaps + 1] = { invSlot = f.invSlot, new = new, old = { f.old }, gain = gain }
        end
    end
end

-- The hands: the best pair (or two-hander) of the spec's setups, where it
-- beats what you hold. A two-hander in place of a main and off hand puts the
-- off hand in your bags, so it waits for a free bag slot (plan.noRoom). An
-- off hand that none of the setups uses stays beside a new one-hander.
local function HandSwaps(worn, best, plan)
    local wm, wo = worn.mainhand and worn.mainhand[1], worn.offhand and worn.offhand[1]
    local bm, bo = best.mainhand and best.mainhand[1], best.offhand and best.offhand[1]
    if not bm or (wm and not wm.score) or (wo and not wo.score) then return end
    local twoHand = bm.item.slot == 17
    local current = (wm and wm.score or 0) + (wo and wo.score or 0)
    local offAfter = (bo and bo.score) or (not twoHand and wo and wo.score) or 0
    -- Filling empty hands always counts: both of them, or the off hand beside the main hand you keep.
    local fills = (not wm and not wo) or (bm.invSlot == 16 and bo and not wo)
    if bm.score + offAfter < current + UPGRADE and not fills then return end
    if twoHand and wo and bm.invSlot ~= 16 and FreeBagSlots() < 1 then
        plan.noRoom = bm
        return
    end
    if bm.invSlot ~= 16 then
        local old, gain = {}, bm.score - (wm and wm.score or 0)
        if wm then old[#old + 1] = wm end
        if twoHand and wo then
            old[#old + 1] = wo
            gain = gain - wo.score
        end
        plan.swaps[#plan.swaps + 1] = { invSlot = 16, new = bm, old = old, gain = gain }
    end
    if bo and bo.invSlot ~= 17 then
        plan.swaps[#plan.swaps + 1] = { invSlot = 17, new = bo, old = { wo }, gain = bo.score - (wo and wo.score or 0) }
    end
end

-- The swaps from what you wear (`worn`, ns.GetEquipped) to `best`
-- (ns.GetBestOwned), in the slot groups' order.
local function Swaps(worn, best)
    local plan = { swaps = {} }
    for _, g in ipairs(ns.SlotGroups) do
        if g.key == "mainhand" then
            HandSwaps(worn, best, plan)
        elseif g.inv and g.key ~= "trinket" and Scored(worn[g.key]) then
            SlotSwaps(g, worn[g.key] or {}, best[g.key] or {}, plan.swaps)
        end
    end
    return plan
end

-- What Equip best would do for profile `p` (your character, by default for
-- its main spec): { p, swaps = { { invSlot, new, old = { the worn items it
-- replaces }, gain } }, binds = the swaps left out because their item would
-- bind to you, noRoom = a two-hander waiting on a free bag slot }. Entries
-- are ns.GetBestOwned's. Nil without your gear.
function ns.EquipBestPlan(p)
    p = p or ns.GetPlayer()
    local worn = ns.GetEquipped(p)
    if not worn then return nil end
    local setups, armor = Setups(p), ns.db.classArmorOnly
    local plan = Swaps(worn, ns.GetBestOwned(p, setups, armor, true))
    plan.p, plan.binds = p, {}
    for _, s in ipairs(Swaps(worn, ns.GetBestOwned(p, setups, armor)).swaps) do
        if s.new.binds then plan.binds[#plan.binds + 1] = s end
    end
    return plan
end

---------------------------------------------------------------- putting it on

-- The moves left: { { invSlot, guid, link, tries } }, the item found by its
-- GUID where the game has them, else by its link. Nil while not equipping.
-- failed: a move was given up (its item gone, or the game refused it twice).
local moves, failed
local waited = 0

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function CursorBusy()
    return CursorHasItem and CursorHasItem()
end

local function GUID(loc)
    if not (loc and C_Item and C_Item.GetItemGUID and C_Item.DoesItemExist and C_Item.DoesItemExist(loc)) then
        return nil
    end
    return C_Item.GetItemGUID(loc)
end

local function BagGUID(bag, slot)
    return ItemLocation and GUID(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

local function WornGUID(invSlot)
    return ItemLocation and GUID(ItemLocation:CreateFromEquipmentSlot(invSlot))
end

-- Whether move `m`'s item is the one in bag `bag`, slot `slot` (else worn in
-- `invSlot`).
local function IsItem(m, bag, slot, invSlot)
    if m.guid then
        if bag then return BagGUID(bag, slot) == m.guid end
        return WornGUID(invSlot) == m.guid
    end
    local link
    if bag then link = C_Container.GetContainerItemLink(bag, slot) else link = GetInventoryItemLink("player", invSlot) end
    return link ~= nil and link == m.link
end

-- Where move `m`'s item is now: { done = true } in its slot already, { bag,
-- slot } or { invSlot } (worn elsewhere); nil when it's gone.
local function Locate(m)
    if IsItem(m, nil, nil, m.invSlot) then return { done = true } end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            if C_Container.GetContainerItemLink(bag, slot) and IsItem(m, bag, slot) then
                return { bag = bag, slot = slot }
            end
        end
    end
    for invSlot = 1, 19 do
        if invSlot ~= m.invSlot and GetInventoryItemID("player", invSlot) and IsItem(m, nil, nil, invSlot) then
            return { invSlot = invSlot }
        end
    end
end

-- Whether the game is still moving move `m`'s item, or the item in its slot.
local function Locked(m)
    if IsInventoryItemLocked and IsInventoryItemLocked(m.invSlot) then return true end
    if m.at.bag then
        local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(m.at.bag, m.at.slot)
        return type(info) == "table" and info.isLocked == true
    end
    return IsInventoryItemLocked and IsInventoryItemLocked(m.at.invSlot) or false
end

local function Stop()
    moves, failed, waited = nil, nil, 0
end

local Next
local function Schedule()
    if C_Timer and C_Timer.After then C_Timer.After(STEP, Next) else Next() end
end

-- One move: an item from the bags first (a worn item changing hands gets
-- there when the other hand's new item takes its place), else one worn in
-- another slot. A move is done once its item is in its slot; one the game
-- refuses (the item put back) is tried once more, then given up. With all
-- of them done, UI.EquipBestDone.
Next = function()
    if not moves then return end
    if InCombat() or CursorBusy() then return Stop() end
    for i = #moves, 1, -1 do
        local c = moves[i]
        c.at = Locate(c)
        if not (c.at and c.at.done) and (not c.at or c.tries >= 2) then failed = true end
        if not c.at or c.at.done or c.tries >= 2 then table.remove(moves, i) end
    end
    local m
    for _, c in ipairs(moves) do
        if c.at.bag then
            m = c
            break
        end
    end
    m = m or moves[1]
    if not m then
        local ok = not failed
        Stop()
        if ok and ns.UI and ns.UI.EquipBestDone then ns.UI.EquipBestDone() end
        return
    end
    if Locked(m) then
        waited = waited + 1
        if waited > MAX_WAIT then return Stop() end
        return Schedule()
    end
    waited = 0
    m.tries = m.tries + 1
    if m.at.bag then
        if ns.WouldBind(m.at.bag, m.at.slot, m.link) then -- (never bind an item)
            m.tries, failed = 2, true
            return Schedule()
        end
        C_Container.PickupContainerItem(m.at.bag, m.at.slot)
    else
        PickupInventoryItem(m.at.invSlot)
    end
    if CursorBusy() then EquipCursorItem(m.invSlot) end
    if CursorBusy() then ClearCursor() end
    Schedule()
end

-- Puts on plan `plan`'s swaps (ns.EquipBestPlan). False when it can't start:
-- in combat, the cursor holding something, or already equipping.
function ns.EquipBest(plan)
    if moves or not (plan and plan.swaps[1]) or InCombat() or CursorBusy() then return false end
    if not (C_Container and C_Container.PickupContainerItem and EquipCursorItem) then return false end
    moves, waited = {}, 0
    for _, s in ipairs(plan.swaps) do
        local e, guid = s.new, nil
        if e.bag then guid = BagGUID(e.bag, e.slot) elseif e.invSlot then guid = WornGUID(e.invSlot) end
        moves[#moves + 1] = { invSlot = s.invSlot, link = e.link, guid = guid, tries = 0 }
    end
    Next()
    return true
end
