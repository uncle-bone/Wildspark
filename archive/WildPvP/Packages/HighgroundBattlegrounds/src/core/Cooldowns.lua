local _, ns = ...
local Core = ns.Core
local Util = ns.Util

---------------------------------------------------------------------------
-- Cooldowns: Cata class kits (which cooldowns an enemy has, which are
-- down), their score bonus and icons, and the dormant gear proxy.
---------------------------------------------------------------------------

-- Gear proxy: max HP vs the median of visible non-tank enemies. Dormant in
-- practice: despite the API docs, UnitHealthMax on enemy players came back
-- secret in every BG recorded (0 plain samples), so gearRef stays nil. Kept in
-- case Blizzard relaxes it; costs nothing while inactive.
-- Core.gearRef is the median max HP, updated during Recompute.
function Core.Median(list)
  local copy = {}
  for i, v in ipairs(list) do
    copy[i] = v
  end
  table.sort(copy)
  local n = #copy
  if n == 0 then
    return nil
  end
  return n % 2 == 1 and copy[(n + 1) / 2] or (copy[n / 2] + copy[n / 2 + 1]) / 2
end

function Core.UpdateGearRef()
  local hps = {}
  for _, e in pairs(Core.enemies) do
    local tank = e.specID and Core.specInfo[e.specID] and Core.specInfo[e.specID].role == "TANK"
    if e.hpMedian and not tank then
      hps[#hps + 1] = e.hpMedian
    end
  end
  Core.gearRef = #hps >= 4 and Core.Median(hps) or nil
end

-- A spell's name, else its ID as text.
function Core.SpellName(id)
  return Util.SpellName(id) or tostring(id)
end

-- Cata class kits (config/cata/Kits.lua): which cooldowns an enemy has, and which
-- the combat log has seen them use. kitBySpell maps every ID an ability can
-- show up as (cast, aura, racial variant) to its kit entry.
Core.kitBySpell = {}
function Core.BuildKits()
  local function add(entry, class)
    entry.class = class
    Core.kitBySpell[entry[1]] = entry
    for _, id in ipairs(entry.alt or {}) do
      Core.kitBySpell[id] = entry
    end
  end
  for _, entry in ipairs(ns.KitCommon or {}) do
    add(entry, nil)
  end
  for class, list in pairs(ns.Kits or {}) do
    for _, entry in ipairs(list) do
      add(entry, class)
    end
  end
end

-- This enemy's kit: shared entries + their class's, filtered to their spec
-- (unknown spec -> every entry of the class).
function Core.KitFor(e)
  local out = {}
  if not ns.Kits or Core.db.cooldowns == false then -- Cooldowns feature switch
    return out
  end
  for _, entry in ipairs(ns.KitCommon or {}) do
    if ns.CooldownTracked(Core.db, entry[1]) then out[#out + 1] = entry end
  end
  local idx = e.specID and Core.specIndex[e.specID]
  for _, entry in ipairs(ns.Kits[e.class] or {}) do
    if (not entry.spec or not idx or entry.spec == idx) and ns.CooldownTracked(Core.db, entry[1]) then
      out[#out + 1] = entry
    end
  end
  return out
end

-- Seconds until a kit entry is back, or nil when ready / never seen used.
function Core.CdLeft(e, entry)
  if Core.db.cooldowns == false or not ns.CooldownTracked(Core.db, entry[1]) then return nil end
  local readyAt = e.cds and e.cds[entry[1]]
  local left = readyAt and readyAt - GetTime()
  return left and left > 0 and left or nil
end

-- Cooldown length as "m:ss" (Util.Clock).
function Core.Clock(sec)
  return Util.Clock(sec)
end

-- Points while down: no trinket = CC them, no immunity = it sticks.
local KIT_POINTS = { trinket = "trinketDown", immune = "immuneDown", def = "defDown" }
function Core.CooldownBonus(e)
  local pts, names = 0, {}
  for _, entry in ipairs(Core.KitFor(e)) do
    local left = Core.CdLeft(e, entry)
    if left and not (e.activeCooldowns and e.activeCooldowns[entry[1]])
      and KIT_POINTS[entry[3]] and ns.DamageShare(Core.me.dmg, entry.vs) > 0 then
      -- Cloak only matters against magic, Evasion only against physical damage.
      -- Per-spell override (Options > Cooldowns) beats the type's value.
      local ov = Core.db.points and Core.db.points["kit" .. entry[1]]
      pts = pts + (ov or Core.P(KIT_POINTS[entry[3]])) * ns.DamageShare(Core.me.dmg, entry.vs)
      names[#names + 1] = entry[4] .. " " .. Core.Clock(left)
    end
  end
  return math.min(pts, Core.P("kitCap")), #names > 0 and ("down: " .. table.concat(names, ", ")) or nil
end

-- A spell's icon, or nil.
function Core.SpellIcon(id)
  return Util.SpellTexture(id)
end

-- Ability icon for a kit entry (inline texture), or its name without one.
function Core.IconText(entry, size)
  local icon = Core.SpellIcon(entry[1])
  return icon and string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", tostring(icon), size or 14, size or 14) or entry[4]
end

-- Defensives they can't use right now, for the hero card: trinket and
-- immunities first, as ability icons.
local SUMMARY_KINDS = { trinket = 1, immune = 2, external = 3, def = 4 }
function Core.DownSummary(e, max)
  local list = {}
  for _, entry in ipairs(Core.KitFor(e)) do
    if SUMMARY_KINDS[entry[3]] and Core.CdLeft(e, entry) and not (e.activeCooldowns and e.activeCooldowns[entry[1]])
      and ns.DamageShare(Core.me.dmg, entry.vs) > 0 then
      list[#list + 1] = entry
    end
  end
  table.sort(list, function(a, b) return SUMMARY_KINDS[a[3]] < SUMMARY_KINDS[b[3]] end)
  local out = {}
  for i = 1, math.min(#list, max or 4) do out[i] = Core.IconText(list[i]) end
  return #out > 0 and ("DOWN " .. table.concat(out, " ")) or nil
end

function Core.IsHealer(e)
  local si = e.specID and Core.specInfo[e.specID]
  local p = e.specID and ns.Specs[e.specID]
  return (si and si.role == "HEALER") or (p and p.healer) or false
end
