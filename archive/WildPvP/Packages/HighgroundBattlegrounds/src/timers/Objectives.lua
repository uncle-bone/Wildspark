local _, ns = ...
local Timers = ns.Timers

local TEAM_NAME = { A = "Alliance", H = "Horde" }
-- Bases that score, per battleground (the map also lists other points,
-- e.g. Eye of the Storm's flag), and what to call them.
function Timers.Round10(v)
  return math.floor(v / 10 + 0.5) * 10
end

function Timers.ObjectiveRows(now)
  local out = {}
  local rules = Timers.Rules()
  local scoring = rules.scoring or {}
  Timers.UpdateNodePhases(now)
  -- Predictable: score grows with bases held (not reinforcements, not
  -- flag captures).
  local sc = scoring.predict and Timers.Scores(now) or nil
  local info
  if sc then
    local cA, cH = Timers.TeamColor("A"), Timers.TeamColor("H")
    info = string.format("%s%d|r  %s%d|r  %s/%s|r", Timers.Hex(cA), sc.A.s, Timers.Hex(cH), sc.H.s,
      ns.Theme.Hex("textMuted"), tostring(sc.max or "?"))
    -- WIN: every capture in progress lands (what happens if nobody stops
    -- it). HELD: the defenders retake them all now (shown if it changes
    -- the winner or the time by more than 5s).
    local q = Timers.Predict(sc, now, true)
    local held
    if sc.n then
      local hn, any = { A = sc.n.A, H = sc.n.H }, false
      for _, nd in pairs(Timers.nodes) do
        if nd.hasGraveyard and nd.assault and nd.owner then
          hn[nd.owner], any = hn[nd.owner] + 1, true
        end
      end
      held = any and Timers.Predict(sc, now, false, hn) or nil
    end
    if q then
      local c = Timers.TeamColor(q.winner)
      out[#out + 1] = { tag = "WIN", color = c, frac = sc[q.winner].s / sc.max, time = Timers.Clock(q.at - now),
        text = string.format("%s  %d-%d", TEAM_NAME[q.winner], Timers.Round10(q.A), Timers.Round10(q.H)) }
    end
    if held and (not q or held.winner ~= q.winner or math.abs(held.at - q.at) > 5) then
      local c = Timers.TeamColor(held.winner)
      out[#out + 1] = { tag = "HELD", color = c, frac = sc[held.winner].s / sc.max, time = Timers.Clock(held.at - now),
        est = true, text = string.format("if defended: %s %d-%d", TEAM_NAME[held.winner], Timers.Round10(held.A),
          Timers.Round10(held.H)) }
    end
    -- How many bases the side that's behind must hold to win instead.
    local ref = q
    local total = scoring.bases or 0
    local word = scoring.noun or "base"
    if ref and sc.n and total > 0 then
      local lose = Timers.Other(ref.winner)
      for k = (sc.n[lose] or 0) + 1, total do
        local nn = { [lose] = k, [ref.winner] = math.min(sc.n[ref.winner] or 0, total - k) }
        local r = Timers.Predict(sc, now, false, nn)
        if r and r.winner == lose then
          out[#out + 1] = { tag = "NEED", color = Timers.TeamColor(lose), time = "",
            text = string.format("%s needs %d %s%s", TEAM_NAME[lose], k, word, k > 1 and "s" or "") }
          break
        end
      end
    end
  end
  -- Enemies clicking a banner right now (their capture cast).
  local clicks = {}
  for _, e in pairs(ns.enemies or {}) do
    local c = ns.Capping and ns.Capping(e)
    if c then clicks[#clicks + 1] = { e = e, c = c } end
  end
  table.sort(clicks, function(a, b) return a.c.finish < b.c.finish end)
  for _, k in ipairs(clicks) do
    local left = math.max(0, k.c.finish - now)
    out[#out + 1] = { tag = "CAPPING", color = Timers.TeamColor(Timers.Other(Timers.MyTeam())),
      text = k.e.display:match("^[^-]+") .. (k.c.node and ("  " .. k.c.node) or ""),
      left = left, total = k.c.finish - k.c.start, est = k.c.est,
      time = string.format("%s%.1fs", k.c.est and "~" or "", left) }
  end
  -- Teammates (and you) clicking a banner.
  for _, a in ipairs(ns.AllyCaptures and ns.AllyCaptures() or {}) do
    local left = math.max(0, a.finish - now)
    local node = a.node or a.me and ns.NodeForArea and ns.MyArea and ns.NodeForArea(ns.MyArea()) or nil
    out[#out + 1] = { tag = "CAPPING", color = Timers.TeamColor(Timers.MyTeam()),
      text = (a.me and "You" or a.name) .. (node and ("  " .. node) or ""),
      left = left, total = a.finish - a.start, time = string.format("%.1fs", left) }
  end
  -- Captures in progress.
  local caps = {}
  for _, n in pairs(Timers.nodes) do
    -- (a capture 20s past its timer that the map never resolved: drop it)
    if n.assault and not (n.capEnd and now - n.capEnd > 20) then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, function(a, b)
    return (a.capEnd or math.huge) < (b.capEnd or math.huge)
  end)
  for _, n in ipairs(caps) do
    out[#out + 1] = { tag = "CAP", color = Timers.TeamColor(n.assault),
      text = n.name .. (n.owner and n.owner ~= n.assault and "  (from " .. TEAM_NAME[n.owner] .. ")" or ""),
      left = n.capEnd and n.capEnd - now, total = n.capEnd and n.capStart and (n.capEnd - n.capStart) or Timers.CapTime() }
  end
  local capture = rules.capture or {}
  local phases = {}
  for _, n in pairs(Timers.nodes) do
    if n.holdEnd or n.resetEnd then phases[#phases + 1] = n end
  end
  table.sort(phases, function(a, b) return (a.holdEnd or a.resetEnd) < (b.holdEnd or b.resetEnd) end)
  for _, n in ipairs(phases) do
    out[#out + 1] = { tag = n.holdEnd and "LOCK" or "RESET",
      color = n.owner and Timers.TeamColor(n.owner) or ns.Theme.Rgb("textMuted"), text = n.name,
      left = (n.holdEnd or n.resetEnd) - now,
      total = n.holdEnd and capture.holdSeconds or capture.resetSeconds, est = true }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    out[#out + 1] = { tag = "FLAG", color = ns.Theme.Rgb("white"), left = ns.flagRespawnAt - now,
      total = rules.flags and rules.flags.respawnSeconds, text = "respawn" }
  end
  if Timers.AddOverview then Timers.AddOverview(out, now) end
  if Timers.Mechanics then Timers.Mechanics.Append(out, now) end
  return out, info
end

-- The resurrection and objective windows, made on first use (named
-- <prefix>TimersFrame and <prefix>BasesFrame: Highground or the folder).
function Timers.Windows()
  if not Timers.resWin then
    local prefix = ns.FRAME_PREFIX or "Highground"
    Timers.resWin = Timers.MakeWindow(prefix .. "TimersFrame", "RESURRECTION", "timersPoint", { "TOP", "TOP", 0, -150 })
    Timers.objWin = Timers.MakeWindow(prefix .. "BasesFrame", "OBJECTIVES", "basesPoint",
      { "TOP", "TOP", Timers.THEME.timers.spacing, -150 })
  end
  return Timers.resWin, Timers.objWin
end

function Timers.UpdateWindow(now)
  local resWin, objWin = Timers.Windows()
  Timers.ShowRows(resWin, Timers.Rows(now))
  local db = Timers.DB()
  local rows, info = Timers.ObjectiveRows(now)
  if db and ns.Core.On("objectives") and #rows > 0 then
    Timers.ShowRows(objWin, rows, info)
  else
    objWin:Hide()
  end
end
function Timers.HideWindows()
  -- Other plain HUD windows, such as quick callouts, own their visibility.
  if Timers.resWin then Timers.resWin:Hide() end
  if Timers.objWin then Timers.objWin:Hide() end
end
ns.Test = ns.Test or {}
ns.Test.timersRows = Timers.Rows
ns.Test.objectiveRows = Timers.ObjectiveRows
ns.Test.predict = function(now)
  local sc = Timers.Scores(now)
  return sc, Timers.Predict(sc, now, false), Timers.Predict(sc, now, true)
end
