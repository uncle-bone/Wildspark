local _, ns = ...
local Core = ns.Core

-- Specs
---------------------------------------------------------------------------
Core.specByName = {} -- [classToken][localized spec name] = specID
Core.classSpecs = {} -- [classToken] = { specID, ... }
Core.specInfo = {} -- [specID] = { name, icon, role, class }
Core.specIndex = {} -- [specID] = talent-tree index within its class

function Core.BuildSpecLookup()
  local function readInfo(get, ...)
    if type(get) ~= "function" then return end
    local ok, id, name, _, icon, role = pcall(get, ...)
    if ok and type(id) == "number" and id > 0 and type(name) == "string" and name ~= "" then
      return id, name, icon, role
    end
  end
  local numSpecs = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
    or GetNumSpecializationsForClassID
  for _, classID in ipairs(ns.ClassIDs) do
    local _, classFile = GetClassInfo(classID)
    if classFile then
      local byIndex = ns.SpecsByIndex and ns.SpecsByIndex[classFile]
      local fallbacks = ns.SpecFallbacks and ns.SpecFallbacks[classFile]
      Core.specByName[classFile] = {}
      Core.classSpecs[classFile] = {}
      -- Cata has exactly three talent trees even when the modern count API
      -- is absent or returns zero. Retail continues to use its client count.
      local count = byIndex and #byIndex or (numSpecs and numSpecs(classID)) or 0
      for i = 1, count do
        local fallback = fallbacks and fallbacks[i]
        -- Forever lists trees by fixed ID: its client may still number specs
        -- like retail (four druid specs), which would shift the trees.
        local specID, name, icon, role
        if not ns.PreferSpecFallbacks then specID, name, icon, role = readInfo(GetSpecializationInfoForClassID, classID, i) end
        if not specID and fallback then
          specID, name, icon, role = readInfo(GetSpecializationInfoByID, fallback[1])
          if not specID then
            specID, name, role, icon = fallback[1], fallback[2], fallback[3], fallback[4]
          end
        end
        if specID then
          Core.specByName[classFile][name] = specID
          if fallback then
            Core.specByName[classFile][fallback[2]] = specID
            if fallback[5] then Core.specByName[classFile][fallback[5]] = specID end
          end
          Core.classSpecs[classFile][i] = specID
          Core.specInfo[specID] = { name = name, icon = icon, role = role, class = classFile }
          Core.specIndex[specID] = i
          -- Cata data is keyed by talent-tree index, not spec ID.
          if byIndex and byIndex[i] then
            ns.Specs[specID] = byIndex[i]
          end
        end
      end
    end
  end
end

function Core.BaseProfile(specID)
  return ns.Specs[specID] or ns.RoleDefaults[Core.specInfo[specID] and Core.specInfo[specID].role or "DAMAGER"]
end

-- Spec ratings can be overridden in the options page
-- (HighgroundDB.specRatings[specID] = { k = squishiness, i = kill value }).
Core.profileCache = {}
function Core.Profile(specID)
  local base = Core.BaseProfile(specID)
  local ov = Core.db and Core.db.specRatings and Core.db.specRatings[specID]
  if not ov then
    return base
  end
  local c = Core.profileCache[specID]
  if not c then
    c = setmetatable({ k = ov.k or base.k, i = ov.i or base.i }, { __index = base })
    Core.profileCache[specID] = c
  end
  return c
end

function Core.UpdateMe()
  local _, cls = UnitClass("player")
  Core.me.class = cls
  local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
  local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
  local idx = getSpec and getSpec()
  if ns.SpecsByIndex then
    -- Cata's talent-tab IDs can differ from specialization IDs. Resolve the
    -- selected tree through the same catalog used for enemy scoreboard names.
    local trees = Core.classSpecs[cls] or {}
    local tree = idx
    if not trees[tree] then tree = GetPrimaryTalentTree and GetPrimaryTalentTree() end
    if not trees[tree] and GetTalentTabInfo then
      tree = nil
      local most = 0
      for t = 1, 3 do
        local ok, _, _, _, _, spent = pcall(GetTalentTabInfo, t)
        if ok and type(spent) == "number" and spent > most then
          tree, most = t, spent
        end
      end
    end
    Core.me.specID = trees[tree]
  else
    Core.me.specID = idx and idx > 0 and getInfo and getInfo(idx) or nil
  end
  local p = Core.me.specID and ns.Specs[Core.me.specID]
  Core.me.dmg = p and p.dmg or "magic"
  Core.me.melee = p and p.melee or false
  Core.me.range = ns.RangeConfig(cls, Core.me.specID)
end

-- Spec from an earlier match: our own history first, then BattleGroundEnemiesFixed's.
function Core.HistoricSpec(key, class)
  local h = Core.db.history[key]
  local name = h and h.class == class and h.spec
  if not name then
    local bge = BattleGroundEnemiesDB and BattleGroundEnemiesDB.global
    local ph = bge and bge.PlayerHistory and bge.PlayerHistory[key]
    if ph and ph.classToken == class and type(ph.lastSpec) == "string" then
      name = ph.lastSpec
    end
  end
  return name and Core.specByName[class] and Core.specByName[class][name]
end

function Core.RecordSpecMana(e, id)
  if not ns.SpecInferenceConfig then return end
  local observed = e.specManaObservation
  local tree = id and Core.specIndex[id]
  if not tree or not observed or GetTime() - observed.at > ns.SpecInferenceConfig.mana.observationSeconds then return end
  e.sampledSpecs = e.sampledSpecs or {}
  if e.sampledSpecs[tree] then return end
  Core.db.fingerprints = Core.db.fingerprints or {}
  ns.RecordSpecMana(Core.db.fingerprints, e.class, tree, observed.mana, observed.level)
  e.sampledSpecs[tree] = true
end

-- Combat log (Cata): an enemy casting a talent-tree ability. Only a
-- scoreboard spec outranks it.
function Core.SpecFromLog(srcName, spellName)
  local e = Core.enemies[Core.Canon(srcName) or ""]
  if not e or e.specSrc == "live" or not ns.SpecFromCast then return end
  local tree, reason = ns.SpecFromCast(e.class, spellName)
  local id = tree and Core.classSpecs[e.class] and Core.classSpecs[e.class][tree]
  if id then e.specID, e.specSrc, e.specReason = id, "cast", reason end
end

function Core.EstimateSpec(e, auras)
  if not ns.SpecInferenceConfig then return end
  if e.specSrc == "live" then
    if GetTime() - (e.liveSpecAt or -math.huge) <= 3 then Core.RecordSpecMana(e, e.specID) end
    return
  end
  if e.specSrc == "cast" then return end -- a talent-tree cast outranks buffs and mana
  if auras and auras.specConflict then
    if e.specSrc == "aura" or e.specSrc == "mana" then
      e.specID, e.specSrc, e.specReason = nil, nil, nil
    end
    return
  end
  local tree, reason, source
  if auras and auras.specTree then
    tree, reason, source = auras.specTree, auras.specReason, "aura"
  elseif e.specSrc == "aura" or e.specSrc == "hist" then
    return -- keep stronger evidence when its buff expires or the unit leaves sight
  elseif e.specManaObservation then
    local observed = e.specManaObservation
    tree, reason = ns.SpecFromMana(Core.db.fingerprints, e.class, observed.mana, observed.level)
    if not tree then
      tree, reason = ns.SpecFromRole(e.class, observed.mana, observed.level, auras and auras.markers)
    end
    source = "mana"
  else
    return
  end
  local id = tree and Core.classSpecs[e.class] and Core.classSpecs[e.class][tree]
  if id then
    e.specID, e.specSrc, e.specReason = id, source, reason
  elseif e.specSrc == "mana" then
    e.specID, e.specSrc, e.specReason = nil, nil, nil
  end
end
