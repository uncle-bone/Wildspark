local _, ns = ...
local U = ns.Util
local H = { limit = 100, eventLimit = 200 }
ns.MatchHistory = H
local function DB() return ns.GetDB and ns.GetDB() or ns.Core.db end
local function Map()
  local name, _, _, _, _, _, _, id = GetInstanceInfo()
  return U.value(name) or "PvP", U.value(id)
end
local function Kind() return select(2, IsInInstance()) end
local function Me() return ns.Core.CanonUnit("player") or U.read(UnitName, "player") or "Player" end
local function Duration()
  local duration = U.read(C_PvP and C_PvP.GetActiveMatchDuration)
  if type(duration) == "number" and duration > 0 then return duration end
  local milliseconds = U.read(GetBattlefieldInstanceRunTime)
  if type(milliseconds) == "number" and milliseconds > 0 then return milliseconds / 1000 end
end

function H.All()
  local db = DB()
  if not db then return {} end
  if type(db.matches) ~= "table" then db.matches = {} end
  return db.matches
end

function H.Ensure()
  if not DB() or (Kind() ~= "pvp" and Kind() ~= "arena") then return end
  local name, map = Map()
  if H.current and H.current.map == map then return H.current end
  if H.current and not H.current.finished then H.Finish(true) end
  local saved = DB().matchInProgress
  local duration = Duration()
  if type(saved) == "table" and saved.map == map and saved.character == Me() and saved.game == ns.GAME
    and type(saved.updated) == "number" and time() - saved.updated < 120
    and (not duration or duration >= (saved.lastDuration or 0)) then
    H.current = saved
  else
    local spec = ns.Core.me and ns.Core.me.specID or U.read(GetSpecializationInfo, U.read(GetSpecialization))
    local info = spec and ns.Core.specInfo and ns.Core.specInfo[spec]
    local _, specName = U.call(GetSpecializationInfoByID, spec)
    H.sequence = (H.sequence or 0) + 1
    H.current = { id = tostring(time()) .. ":" .. tostring(map) .. ":" .. H.sequence, map = map, name = name, kind = Kind(),
      character = Me(), game = ns.GAME, spec = spec, specName = info and info.name or U.value(specName),
      started = time(), events = {}, team = ns.GetAllyFaction and ns.GetAllyFaction() }
  end
  H.current.clock, H.current.updated = GetTime(), time()
  H.nodes, H.lastChat = {}, nil
  DB().matchInProgress = H.current
  return H.current
end

function H.Note(text)
  local current = H.Ensure()
  if not current or current.finished or type(text) ~= "string" or U.secret(text) then return end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):sub(1, 240)
  local events = current.events
  local age = math.max(0, time() - current.started)
  local last = events[#events]
  if last and last.text == text and age - last.at < 2 then return end
  events[#events + 1] = { at = age, text = text }
  while #events > H.eventLimit do table.remove(events, 1) end
end

function H.Scores()
  local current = H.current
  if not current then return end
  local count = U.read(GetNumBattlefieldScores) or 0
  for i = 1, count do
    local row
    if C_PvP and C_PvP.GetScoreInfo then row = U.call(C_PvP.GetScoreInfo, i)
    elseif GetBattlefieldScore then
      local name, kills, honorKills, deaths, honor, faction, _, _, _, damage, healing = U.call(GetBattlefieldScore, i)
      row = { name = name, killingBlows = kills, honorableKills = honorKills, deaths = deaths, honorGained = honor,
        faction = faction, damageDone = damage, healingDone = healing }
    end
    if type(row) == "table" then
      local name = U.value(row.name)
      if type(name) == "string" and ns.Core.Canon(name) == Me() then
        current.stats = current.stats or {}
        for _, key in ipairs({ "killingBlows", "honorableKills", "deaths", "honorGained", "damageDone", "healingDone", "ratingChange" }) do
          local value = U.value(row[key])
          if type(value) == "number" then current.stats[key] = value end
        end
        current.team = U.value(row.faction) or current.team
      end
    end
  end
end

function H.Finish(left)
  local current = H.current
  if not current or current.finished then return end
  if not left then H.Scores() end
  local winner = U.read(C_PvP and C_PvP.GetActiveMatchWinner) or U.read(GetBattlefieldWinner)
  current.result = left and "Left early" or (winner == 0 or winner == 1) and current.team ~= nil
    and (winner == current.team and "Win" or "Loss") or "Completed"
  current.duration = (not left and Duration()) or current.lastDuration or math.max(0, time() - current.started)
  current.finished, current.updated = time(), time()
  local list = H.All()
  table.insert(list, 1, current)
  while #list > H.limit do table.remove(list) end
  DB().matchInProgress = nil
  if H.win and H.win:IsShown() then H.win:Refresh() end
end

function H.Poll()
  if Kind() ~= "pvp" and Kind() ~= "arena" then return end
  local current = H.Ensure()
  if not current or current.finished then return end
  current.updated = time()
  current.lastDuration = Duration()
  current.team = ns.GetAllyFaction and ns.GetAllyFaction() or current.team
  for name, node in pairs(ns.Timers and ns.Timers.nodes or {}) do
    local state = node.assault and ("Assault: " .. node.assault) or node.owner and ("Owner: " .. node.owner) or "Neutral"
    if H.nodes[name] and H.nodes[name] ~= state then H.Note(name .. " — " .. state) end
    H.nodes[name] = state
  end
end

U.Every(1, H.Poll, "match journal")
U.Events({
  PLAYER_ENTERING_WORLD = function()
    if Kind() == "pvp" or Kind() == "arena" then
      if H.current and H.current.finished then H.current = nil end
      H.Ensure()
    else
      if DB() then H.Finish(true); DB().matchInProgress = nil end
      H.current = nil
    end
  end,
  PVP_MATCH_COMPLETE = function() H.Ensure(); H.Finish(false) end,
  UPDATE_BATTLEFIELD_SCORE = function()
    H.Scores()
    local winner = U.read(GetBattlefieldWinner)
    if U.read(C_PvP and C_PvP.IsMatchComplete) or winner == 0 or winner == 1 then H.Finish(false) end
  end,
  CHAT_MSG_BG_SYSTEM_ALLIANCE = function(_, msg) H.Note(msg) end,
  CHAT_MSG_BG_SYSTEM_HORDE = function(_, msg) H.Note(msg) end,
  CHAT_MSG_BG_SYSTEM_NEUTRAL = function(_, msg) H.Note(msg) end,
}, "match journal")
