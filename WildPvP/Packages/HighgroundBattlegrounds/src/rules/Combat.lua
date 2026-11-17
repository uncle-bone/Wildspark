local _, ns = ...

-- Small, client-independent rules. Callers supply observations; these helpers
-- never read WoW APIs or assume that hidden information is available.
function ns.RangeConfig(class, specID)
  local base = ns.RangeBands[class]
  local profile = specID and ns.Specs[specID]
  local override = profile and profile.range
  if not override then return base end
  return {
    attackYards = override.attackYards or (base and base.attackYards),
    reachYards = override.reachYards or (base and base.reachYards),
    bands = override.bands or (base and base.bands) or {},
  }
end

-- Share of YOUR damage that a phys- or magic-only answer affects. Mixed
-- specs (Ret, Enhancement...) are hurt by either answer, but only half as much.
-- Unknown damage counts every answer in full.
function ns.DamageShare(myDmg, kind)
  if not kind or not myDmg then return 1 end
  if myDmg == "mixed" then return 0.5 end
  return myDmg == kind and 1 or 0
end

-- How much an active defensive aura protects against YOU (0 = irrelevant).
function ns.DefensiveWeight(spellID, myDmg)
  local defensive = ns.Defensives and ns.Defensives[spellID]
  if not defensive then return 0 end
  return ns.DamageShare(myDmg, defensive.vs) * (defensive.scale or 1)
end

-- Cata's configured range probes are targeted abilities. Their successful
-- casts identify a nearby opponent even if nameplates/range polling miss it.
-- Damage events are only useful for immediate melee abilities: projectiles,
-- periodic ticks and arbitrary procs do not prove current proximity.
local combatRanges = {}
if ns.CLIENT == "cata" then
  for _, config in pairs(ns.RangeBands) do
    for _, band in ipairs(config.bands or {}) do
      for _, spellID in ipairs(band[2]) do
        combatRanges[spellID] = math.max(combatRanges[spellID] or 0, band[1])
      end
    end
  end
end
function ns.CombatSightRadius(event, spellID)
  local yards = combatRanges[spellID]
  if not yards then return nil end
  if event == "SPELL_CAST_SUCCESS" then return yards end
  if yards <= 5 and (event == "SPELL_DAMAGE" or event == "SPELL_MISSED") then return yards end
end

function ns.AssaultStacks(elapsed, rules)
  if not rules or not rules.firstStackSeconds or not rules.stackInterval then return nil end
  if elapsed < rules.firstStackSeconds then return nil end
  local stacks = 1 + math.floor((elapsed - rules.firstStackSeconds) / rules.stackInterval)
  return rules.maxStacks and math.min(stacks, rules.maxStacks) or stacks
end

-- One preference per ability, including racial and aura variants. Observed
-- timers are retained so re-enabling a spell can reuse a still-valid clock.
local cooldownKeys = {}
local function addCooldownKeys(list)
  for _, entry in ipairs(list or {}) do
    cooldownKeys[entry[1]] = entry[1]
    for _, id in ipairs(entry.alt or {}) do cooldownKeys[id] = entry[1] end
  end
end
addCooldownKeys(ns.KitCommon)
for _, list in pairs(ns.Kits or {}) do addCooldownKeys(list) end

function ns.CooldownTracked(settings, spellID)
  local disabled = settings and settings.disabledCooldowns
  local key = cooldownKeys[spellID] or spellID
  return not (disabled and disabled[key])
end

function ns.CooldownKey(spellID)
  return cooldownKeys[spellID] or spellID
end

local protection = {}
for spellID in pairs(ns.Defensives or {}) do protection[ns.CooldownKey(spellID)] = true end

-- Drop cached signals when their spell is unchecked, before scanning again.
-- Hiding an active defensive must not look like it expired.
function ns.FilterCooldownState(enemy, settings)
  if enemy.defSpell and not ns.CooldownTracked(settings, enemy.defSpell) then
    enemy.def, enemy.defIcon, enemy.defSpell = false, nil, nil
  end
  if enemy.burstSpell and not ns.CooldownTracked(settings, enemy.burstSpell) then
    enemy.burst, enemy.burstIcon, enemy.burstSpell = false, nil, nil
  end
  if enemy.burnedSpell and not ns.CooldownTracked(settings, enemy.burnedSpell) then
    enemy.burnedAt, enemy.burnedSpell = nil, nil
  end
end

function ns.TrackCooldown(enemy, entry, event, now)
  local key = entry[1]
  enemy.cds = enemy.cds or {}
  -- A just-cast personal protection is not an opening. Repeated aura
  -- evidence refreshes its active state without extending the cooldown.
  -- External casts do not prove the caster is the protected recipient.
  if protection[key] and entry[3] ~= "external" then
    enemy.activeCooldowns = enemy.activeCooldowns or {}
    enemy.activeCooldowns[key] = true
  end
  if event == "SPELL_AURA_APPLIED" then
    -- An ally entering an existing Barrier/AMZ is not another cast. Aura
    -- observations can seed a missing timer but never extend a known one.
    if enemy.cds[key] and enemy.cds[key] > now then return end
  else
    enemy.cdCasts = enemy.cdCasts or {}
    local last = enemy.cdCasts[key]
    if last and now - last < 1 then return end -- cast + interrupt duplicate
    enemy.cdCasts[key] = now
  end
  enemy.cds[key] = now + entry[2]
  if event ~= "SPELL_AURA_APPLIED" then
    for _, id in ipairs(entry.resets or {}) do enemy.cds[id] = nil end
  end
end
