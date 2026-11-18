local _, ns = ...

-- Only readable Cata observations reach these helpers. Estimates never
-- become training labels; callers must obtain labels from the scoreboard.
local config = ns.CLIENT == "cata" and ns.SpecInferenceConfig

local function validMana(mana, level)
  return type(mana) == "number" and mana > 0 and mana < math.huge
    and type(level) == "number" and level > 0 and level < math.huge
end

local function sampleKey(class, tree)
  return "cata/" .. class .. "/" .. tree
end

function ns.RecordSpecMana(samples, class, tree, mana, level)
  if not config or not validMana(mana, level) then return end
  local profiles = ns.SpecsByIndex[class]
  if not profiles or not profiles[tree] then return end
  local key = sampleKey(class, tree)
  local list = samples[key] or {}
  samples[key] = list
  list[#list + 1] = { mana = mana, level = level }
  if #list > config.mana.sampleLimit then table.remove(list, 1) end
end

function ns.SpecFromMana(samples, class, mana, level)
  if not config or not samples or not validMana(mana, level) then return end
  local profiles = ns.SpecsByIndex[class]
  if not profiles then return end
  local candidate
  for tree = 1, #profiles do
    local count, low, high = 0, math.huge, 0
    for _, sample in ipairs(samples[sampleKey(class, tree)] or {}) do
      if sample.level == level and validMana(sample.mana, sample.level) then
        count = count + 1
        low, high = math.min(low, sample.mana), math.max(high, sample.mana)
      end
    end
    -- Missing examples for a competing tree cannot prove the candidate.
    if count < config.mana.minSamples then return end
    local tolerance = config.mana.tolerance
    if mana >= low * (1 - tolerance) and mana <= high * (1 + tolerance) then
      if candidate then return end -- pools overlap: mana cannot distinguish them
      candidate = tree
    end
  end
  if candidate then return candidate, "maximum mana compared with confirmed specs at this level" end
end

-- A talent-tree ability cast by the enemy: that tree.
function ns.SpecFromCast(class, spellName)
  local casts = config and config.casts and config.casts[class]
  local tree = casts and type(spellName) == "string" and casts[spellName]
  if tree then return tree, spellName .. " cast" end
end

-- Melee hybrids have small mana pools at max level, casters large ones.
-- markers: qualifying buffs seen on the enemy (e.g. lightningShield).
function ns.SpecFromRole(class, mana, level, markers)
  local role = config and config.role
  local rule = role and role[class]
  if not rule or not validMana(mana, level) or level ~= role.level then return end
  if mana < role.low and rule.low then
    return rule.low, "small mana pool for a caster"
  end
  if mana > role.high and rule.high and (not rule.highNeeds or (markers and markers[rule.highNeeds])) then
    return rule.high, "large mana pool" .. (rule.highNeeds and " with " .. rule.highNeeds or "")
  end
end

function ns.SpecLabel(enemy, label)
  if enemy.specSrc == "aura" or enemy.specSrc == "mana" then return "~" .. label end
  return label
end
