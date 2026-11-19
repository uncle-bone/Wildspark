local _, addonRoot = ...
local ns = addonRoot.WildGear

-- WildGear_API: what other addons can read (bag addons and their
-- plugins, leveling guides): IsUpgrade, OnChanged (version 1); GetSpec,
-- GetSpecs, GetWeights, GetStatKeys, ScoreItem, GetGain (version 2).
-- Documented for their authors in API.md, which ships in the zip: change it
-- with them. Every function is safe to call at any time (nil before
-- PLAYER_LOGIN, or for an unknown class or spec) and hands out copies. Keep
-- them stable; add new ones and bump `version`.

local API = { version = 2 }
WildGear_API = API

-- Internal: BagMarks.lua sets the bag answers and fires the listeners.
local listeners = {}
ns.API = {
    IsUpgrade = function() return false end,
    -- Runs every listener (each one's errors reported, without stopping the others).
    Fire = function()
        for _, func in ipairs(listeners) do xpcall(func, geterrorhandler()) end
    end,
}

local function Copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- The item ID and link for an item link or ID. With an ID, items missing from
-- Data/Items.lua (vendor gear, world drops) get their plain link from the
-- game, which ns.LinkItem reads their stats from: nil until it has loaded.
local function ItemArgs(link)
    if type(link) == "string" then return tonumber(link:match("item:(%d+)")), link end
    if type(link) ~= "number" then return nil end
    if ns.Items[link] then return link end
    local Info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, itemLink = Info(link)
    return link, itemLink
end

function API.IsUpgrade(link) return ns.API.IsUpgrade(link) end

function API.OnChanged(func)
    if type(func) == "function" then listeners[#listeners + 1] = func end
end

function API.GetSpec()
    if not ns.charDB then return nil end
    local p = ns.GetPlayer()
    return p.spec, ns.WeightSetup(p), p.classFile
end

function API.GetSpecs(classFile)
    local specs = ns.Specs[classFile]
    return specs and Copy(specs) or nil
end

function API.GetWeights(classFile, spec, level, setup)
    if not ns.charDB then return nil end
    local p = ns.GetPlayer()
    classFile = classFile or p.classFile
    spec = spec or (classFile == p.classFile and p.spec) or (ns.Specs[classFile] and ns.Specs[classFile][1])
    if not (spec and ns.IsSpec(classFile, spec)) then return nil end
    level = math.max(1, math.min(tonumber(level) or p.level, ns.MAX_LEVEL))
    if not setup and classFile == p.classFile and spec == p.spec then setup = ns.WeightSetup(p) end
    local stats, source, profile = ns.GetWeights(classFile, spec, level, setup)
    if not stats then return nil end
    local out = Copy(stats)
    -- (% crit and hit as the scoring uses them: placeholder weights scale them with level)
    out.critPct = ns.CritPctWeight(classFile, spec, level, setup)
    out.hitPct = ns.HitPctWeight(classFile, spec, level, setup)
    local info = { profile = profile ~= nil }
    if profile then
        info.source = profile.name
        local _, from = ns.WeightBracket(profile.brackets, level)
        info.fromLevel, info.toLevel = from, ns.MAX_LEVEL
        for _, b in ipairs(profile.brackets) do
            if b.upTo >= level then info.toLevel = math.min(b.upTo, ns.MAX_LEVEL) break end
        end
    else
        info.source = ns.Weights[classFile][spec].source
        info.fromLevel, info.toLevel = ns.DefaultWeightRange(classFile, spec, level, setup)
    end
    return out, info
end

function API.GetStatKeys()
    local out = {}
    for _, s in ipairs(ns.WeightStats) do out[#out + 1] = { key = s.key, label = s.label } end
    for _, s in ipairs(ns.SpeedStats) do out[#out + 1] = { key = s.key .. "Ref", label = s.key .. "Ref" } end
    return out
end

function API.ScoreItem(link, offHand)
    local id, itemLink = ItemArgs(link)
    if not (id and ns.charDB) then return nil end
    local item = ns.LinkItem(id, itemLink)
    if not item then
        local Cached = C_Item and C_Item.IsItemDataCachedByID
        return nil, Cached ~= nil and not Cached(id)
    end
    if not item.slot then return nil end
    local score = ns.SlotScorer(ns.GetPlayer())
    if not score then return nil end
    return score(item, offHand and "offhand" or nil)
end

function API.GetGain(link)
    local id, itemLink = ItemArgs(link)
    if not (id and ns.charDB) then return nil end
    return ns.Tooltip.Gain(id, itemLink)
end
