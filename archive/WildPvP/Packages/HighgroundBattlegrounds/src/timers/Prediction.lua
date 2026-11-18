local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Bases window: captures in progress + who wins, and when.
-- Like Capping's bars and score predictor, plus:
--   * the max score is read from the scoreboard (not assumed 1600)
--   * points per second for each base count are measured live (and saved
--     per battleground), seeded with Arathi Basin's known table
--   * "IF" = the result if every capture in progress lands
--   * "NEED" = how many bases the losing side must hold to turn it
---------------------------------------------------------------------------

do
  local SCORE_WIDGETS = { { 1893, 1894 }, { 3116, 3117 } } -- Alliance, Horde (AB; EotS / Gilneas)
  local function WidgetText(id)
    local W = C_UIWidgetManager
    local f = W and W.GetIconAndTextWidgetVisualizationInfo
    if not f then
      return nil
    end
    local ok, info = pcall(f, id)
    local t = ok and type(info) == "table" and info.text
    if Timers.plain(t) and type(t) == "string" and t ~= "" then
      return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
  end
  -- "Bases: 3  Resources: 1210/1600" -> 1210, 1600, 3 ; "1210/1600" -> 1210, 1600
  local function Parse(text)
    if not text then
      return nil
    end
    local b, s, m = text:match("(%d+)[^%d/]+(%d+)%s*/%s*(%d+)")
    if not b then
      s, m = text:match("(%d+)%s*/%s*(%d+)")
    end
    if s then
      return tonumber(s), tonumber(m), tonumber(b)
    end
  end
  local function Read()
    for _, pair in ipairs(SCORE_WIDGETS) do
      local as, am, ab = Parse(WidgetText(pair[1]))
      local hs, hm, hb = Parse(WidgetText(pair[2]))
      if as and hs then
        return { A = { s = as, m = am, b = ab }, H = { s = hs, m = hm, b = hb } }
      end
    end
    -- Any other scoreboard: the first two "x/y" widgets at the top of the screen.
    local W = C_UIWidgetManager
    if W and W.GetTopCenterWidgetSetID and W.GetAllWidgetsBySetID then
      local okS, set = pcall(W.GetTopCenterWidgetSetID)
      local okL, list = pcall(W.GetAllWidgetsBySetID, okS and set or 0)
      local found = {}
      for _, wi in ipairs(okL and type(list) == "table" and list or {}) do
        local s, m, b = Parse(WidgetText(wi.widgetID))
        if s then
          found[#found + 1] = { id = wi.widgetID, s = s, m = m, b = b }
        end
      end
      table.sort(found, function(x, y)
        return x.id < y.id
      end)
      if #found >= 2 then
        return { A = found[1], H = found[2] }
      end
    end
  end

  -- Bases scoring right now: map nodes owned and not under assault (an
  -- assaulted base scores for nobody) when the map knows who owns them,
  -- else the scoreboard's count.
  local function Bases(sc)
    local cA, cH, known = 0, 0, 0
    for _, nd in pairs(Timers.nodes) do
      -- The configured scoring maps attach a graveyard to each resource
      -- base. Other POIs (notably the central flag) do not generate income.
      if nd.hasGraveyard and (nd.owner or nd.assault) then
        known = known + 1
      end
      if nd.hasGraveyard and not nd.assault then
        if nd.owner == "A" then
          cA = cA + 1
        elseif nd.owner == "H" then
          cH = cH + 1
        end
      end
    end
    local wA, wH = sc.A.b, sc.H.b
    if wA and wH and known < wA + wH then
      return { A = wA, H = wH }
    end
    if known > 0 or not (wA and wH) then
      return known > 0 and { A = cA, H = cH } or nil
    end
    return { A = wA, H = wH }
  end

  local lastSc

  local function Learned()
    local db, key = Timers.DB(), Timers.RulesKey()
    local scoring = Timers.Rules().scoring
    if not (db and key and scoring) then
      return nil
    end
    db.rates = db.rates or {}
    db.rates[key] = db.rates[key] or {}
    return db.rates[key], scoring.seedRates
  end

  local function Rate(n)
    if n == 0 then
      return 0
    end
    local learned, seed = Learned()
    local r = (learned and learned[n]) or (seed and seed[n])
    if r then
      return r
    end
    -- unknown count: scale the nearest known one
    local bestK, bestR
    for _, t in ipairs({ learned or {}, seed or {} }) do
      for k, v in pairs(t) do
        if k > 0 and v > 0 and (not bestK or math.abs(k - n) < math.abs(bestK - n)) then
          bestK, bestR = k, v
        end
      end
    end
    return bestR and bestR * n / bestK or nil
  end

  -- Watch score ticks: steady ticks at an unchanged base count -> rate,
  -- measured from one tick to a later one (whole ticks only).
  local function Track(team, s, n, now)
    local tr = Timers.track[team]
    if not tr or tr.n ~= n or s < tr.s1 or s - tr.s1 > 60 then
      Timers.track[team] = { n = n, s1 = s, ticks = 0 }
      return
    end
    if s ~= tr.s1 then
      tr.ticks = tr.ticks + 1
      tr.t1, tr.s1 = now, s
      if tr.ticks == 1 then
        tr.t0, tr.s0 = now, s
      elseif tr.ticks >= 3 and n and n > 0 and tr.t1 > tr.t0 then
        local r = (tr.s1 - tr.s0) / (tr.t1 - tr.t0)
        local learned = Learned()
        if learned then
          learned[n] = learned[n] and (learned[n] * 0.7 + r * 0.3) or r
        end
      end
    end
  end

  function Timers.Scores(now)
    Timers.UpdateNodePhases(now)
    local scoring = Timers.Rules().scoring
    if not (scoring and scoring.predict) then return nil end
    local sc = Read()
    if not sc then
      lastSc = nil
      return nil
    end
    sc.n = Bases(sc)
    sc.max = sc.A.m or sc.H.m
    if sc.n then
      Track("A", sc.A.s, sc.n.A, now)
      Track("H", sc.H.s, sc.n.H, now)
    end
    lastSc = sc
    return sc
  end

  -- Who reaches max first. withCaps: captures in progress land at their
  -- timers. nOverride: what-if base counts. -> { winner, at, A, H } or nil
  function Timers.Predict(sc, now, withCaps, nOverride)
    if not (sc and sc.max and (sc.n or nOverride)) then
      return nil
    end
    local s = { A = sc.A.s, H = sc.H.s }
    local base = nOverride or sc.n
    local n = { A = base.A, H = base.H }
    local events = {}
    if withCaps then
      for _, nd in pairs(Timers.nodes) do
        if nd.hasGraveyard and nd.assault and nd.capEnd and nd.capEnd > now then
          events[#events + 1] = { t = nd.capEnd, to = nd.assault }
        end
      end
      table.sort(events, function(a, b)
        return a.t < b.t
      end)
    end
    local t = now
    for i = 1, #events + 1 do
      local e = events[i]
      local te = e and e.t or math.huge
      local ra, rh = Rate(n.A), Rate(n.H)
      if not (ra and rh) then
        return nil
      end
      local ta = ra > 0 and (sc.max - s.A) / ra or math.huge
      local th = rh > 0 and (sc.max - s.H) / rh or math.huge
      local tw = math.min(ta, th)
      if t + tw <= te then
        if tw == math.huge then
          return nil
        end
        local out = { winner = ta <= th and "A" or "H", at = t + tw }
        out.A = math.min(sc.max, s.A + ra * tw)
        out.H = math.min(sc.max, s.H + rh * tw)
        return out
      end
      local dt = te - t
      s.A, s.H, t = s.A + ra * dt, s.H + rh * dt, te
      n[e.to] = n[e.to] + 1
    end
  end
end
