local _, ns = ...
local Core = ns.Core

-- Roster (scoreboard)
---------------------------------------------------------------------------
-- One scoreboard row as a table. Retail: C_PvP.GetScoreInfo. Cata Classic
-- 4.4.2 only has GetBattlefieldScore; talentSpec is its 16th return and is
-- readable mid-match there.
-- Scoreboard class -> class token. Some servers send the class name
-- ("Death Knight") where the token ("DEATHKNIGHT") belongs: drop spaces, else
-- match the client's localized class names.
function Core.ClassToken(value)
  if type(value) ~= "string" or not Core.plain(value) then return nil end
  local token = value:upper():gsub("[%s_%-]", "")
  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then return token end
  for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for t, localized in pairs(names) do
      if localized == value then return t end
    end
  end
  return token
end

function Core.ScoreInfo(idx)
  if C_PvP and C_PvP.GetScoreInfo then
    return C_PvP.GetScoreInfo(idx)
  end
  local name, _, _, _, _, faction, _, class, classToken, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(idx)
  if name then
    return { name = name, faction = faction, classToken = Core.ClassToken(classToken) or Core.ClassToken(class),
      talentSpec = talentSpec }
  end
end

function Core.RaidNames()
  local set = {}
  set[Core.CanonUnit("player") or ""] = true
  for i = 1, GetNumGroupMembers() or 0 do
    local name = GetRaidRosterInfo(i)
    local key = Core.Canon(name)
    if key then
      set[key] = true
    end
  end
  return set
end

local resettingFilter = false
-- Core.rosterStatus explains an empty roster in /hg err and probe.

function Core.RefreshRoster()
  if Core.testMode then
    return
  end
  local n = GetNumBattlefieldScores() or 0
  local rows = {}
  -- Why rows get skipped, saved for diagnosis (HighgroundDB.rosterDebug).
  local dbg = { t = date("%H:%M:%S"), scores = n, noInfo = 0, badName = 0, badClass = 0, badFaction = 0 }
  for idx = 1, n do
    local info = Core.ScoreInfo(idx)
    if not info then
      dbg.noInfo = dbg.noInfo + 1
    else
      local key = Core.Canon(info.name)
      local class, faction = info.classToken, info.faction
      if not key then
        dbg.badName = dbg.badName + 1
      elseif not Core.plain(class) then
        dbg.badClass = dbg.badClass + 1
      elseif not Core.plain(faction) then
        dbg.badFaction = dbg.badFaction + 1
      else
        rows[#rows + 1] = { key = key, class = class, faction = faction, spec = info.talentSpec }
      end
    end
  end
  dbg.rows = #rows
  dbg.allyFaction = Core.allyFaction
  local ok, st = pcall(C_PvP and C_PvP.GetActiveMatchState)
  dbg.matchState = ok and Core.plain(st) and st or nil
  Core.db.rosterDebug = dbg
  if n == 0 then
    Core.rosterStatus = "no scoreboard yet"
    return
  end

  -- Your own scoreboard row is the most reliable team source: scoreboard
  -- names are NeverSecret, while group roster names may come back secret.
  -- Read it before waiting for the enemy team, since battlegrounds can be
  -- cross-faction and the character's own faction is not your side.
  if Core.allyFaction == nil then
    local myKey = Core.CanonUnit("player")
    for _, r in ipairs(rows) do
      if r.key == myKey then
        Core.allyFaction = r.faction
        break
      end
    end
  end

  -- Scoreboard filtered to one team (a faction tab was clicked): reset it to
  -- both teams once the scoreboard window is closed, and keep current state.
  local factions, nf = {}, 0
  for _, r in ipairs(rows) do
    if not factions[r.faction] then
      factions[r.faction] = true
      nf = nf + 1
    end
  end
  if nf < 2 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      pcall(SetBattlefieldScoreFaction, -1)
      resettingFilter = false
      Core.RequestScores()
    end
    Core.rosterStatus = nf == 0 and "scoreboard rows unreadable" or "enemy team not on scoreboard yet"
    dbg.status = Core.rosterStatus
    return
  end

  if Core.allyFaction == nil then
    local raid, votes = Core.RaidNames(), {}
    for _, r in ipairs(rows) do
      if raid[r.key] then
        votes[r.faction] = (votes[r.faction] or 0) + 1
      end
    end
    local best, bestN = nil, 1 -- need at least two matching group members
    for f, c in pairs(votes) do
      if c > bestN then
        best, bestN = f, c
      end
    end
    Core.allyFaction = best
  end
  if Core.allyFaction == nil and GetBattlefieldArenaFaction then
    local ok, f = pcall(GetBattlefieldArenaFaction)
    if ok and Core.plain(f) and factions[f] then
      Core.allyFaction = f
    end
  end
  if Core.allyFaction == nil then
    Core.rosterStatus = "can't tell which team is yours"
    dbg.status = Core.rosterStatus
    return
  end
  Core.rosterStatus = nil

  -- A read with only one team means Blizzard's scoreboard is filtered (a
  -- faction tab was clicked, e.g. while dead) or still loading. Never drop
  -- enemies on such a read; reset the filter once the scoreboard is closed.
  local allyRows, enemyRows = 0, 0
  for _, r in ipairs(rows) do
    if r.faction == Core.allyFaction then
      allyRows = allyRows + 1
    else
      enemyRows = enemyRows + 1
    end
  end
  if allyRows == 0 or enemyRows == 0 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      SetBattlefieldScoreFaction(-1)
      resettingFilter = false
      Core.RequestScores()
    end
    return
  end

  local seen = {}
  for _, r in ipairs(rows) do
    if r.faction ~= Core.allyFaction then
      seen[r.key] = true
      local e = Core.enemies[r.key]
      if not e then
        e = { key = r.key, display = Core.DisplayName(r.key) }
        Core.enemies[r.key] = e
      end
      e.class = r.class
      local spec = r.spec
      -- Raw scoreboard spec, possibly secret: only ever handed to SetText.
      e.specLive = nil
      if type(spec) == "string" then e.specLive = spec end
      if Core.plain(spec) and type(spec) == "string" and spec ~= "" and Core.specByName[r.class] then
        local id = Core.specByName[r.class][spec]
        if id then
          e.specID, e.specSrc, e.specReason = id, "live", nil
          e.liveSpecAt = GetTime()
        end
      end
      if not e.specID then
        e.specID = Core.HistoricSpec(r.key, r.class)
        e.specSrc = e.specID and "hist" or nil
      end
    end
  end
  for key in pairs(Core.enemies) do
    if not seen[key] then
      Core.enemies[key] = nil
    end
  end
end

-- After the match, specs are no longer secret: remember them for next time.
function Core.HarvestHistory()
  for idx = 1, GetNumBattlefieldScores() or 0 do
    local info = Core.ScoreInfo(idx)
    if info then
      local key = Core.Canon(info.name)
      local class, spec = info.classToken, info.talentSpec
      if key and Core.plain(class) and Core.plain(spec) and type(spec) == "string" and spec ~= "" then
        Core.db.history[key] = { class = class, spec = spec, t = time() }
        local e = Core.enemies[key]
        local id = Core.specByName[class] and Core.specByName[class][spec]
        if e and id then Core.RecordSpecMana(e, id) end
        if e and (e.maxMana or e.maxHP) and not e.fingerprinted then
          e.fingerprinted = true
          Core.db.fingerprints = Core.db.fingerprints or {}
          local fp = class .. "/" .. spec
          local list = Core.db.fingerprints[fp] or {}
          Core.db.fingerprints[fp] = list
          list[#list + 1] = { mana = e.maxMana, hp = e.maxHP }
          if #list > 50 then
            table.remove(list, 1)
          end
        end
      end
    end
  end
end
