local _, ns = ...
local T, U = ns.Timers, ns.Util
local M = { rows = {}, notices = {}, states = {} }
T.Mechanics = M
local BRIEF = {
  silvershard_mines = "Escort controlled carts to a depot; contest enemy carts before delivery.",
  deephaul_ravine = "Escort your carts and deliver the crystal; deny enemy deliveries.",
  strand_of_the_ancients = "Attack: breach gates and reach the relic. Defend: delay the attackers.",
  isle_of_conquest = "Secure vehicle bases, breach the enemy keep and defeat its commander.",
  alterac_valley = "Defend your towers; take enemy towers and graveyards before pushing their general.",
  wintergrasp = "Attack: breach the fortress and reach the relic. Defend: hold until the round ends.",
  ashran = "Push the battle objectives and protect your commander.",
}
local GOAL = {
  silvershard_mines = "Escort carts to depots", deephaul_ravine = "Escort carts; deliver the crystal",
  strand_of_the_ancients = "Fight for gates and the relic", isle_of_conquest = "Take vehicles; breach the keep",
  alterac_valley = "Take towers; defeat the general", wintergrasp = "Fight for the fortress and relic",
  ashran = "Push objectives; protect commander",
}
local function Clean(text)
  text = U.value(text)
  if type(text) ~= "string" or text == "" then return end
  return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("[\r\n]+", " "):sub(1, 240)
end
local function Live()
  local bg = ns.GetBG and ns.GetBG()
  return ns.IsActive() and bg and (bg.kind == "carts" or bg.kind == "epic") and bg
end

local function Add(key, text, tag, value, maximum, owner)
  text = Clean(text)
  if not text then return end
  local detail = text
  value, maximum = U.value(value), U.value(maximum)
  local frac = type(value) == "number" and type(maximum) == "number" and maximum > 0 and value / maximum or nil
  if frac then detail = detail .. string.format(" (%g/%g)", value, maximum) end
  local previous = M.states[key]
  if previous and previous ~= text and ns.MatchHistory then ns.MatchHistory.Note(text) end
  M.states[key] = text
  M.rows[#M.rows + 1] = { tag = tag or "STATUS", text = text, detail = detail,
    time = frac and string.format("%d%%", frac * 100 + 0.5) or "", frac = frac,
    color = owner and T.TeamColor(owner) or ns.Theme.Rgb("textMuted") }
end

local function Widget(id)
  local W = C_UIWidgetManager
  local getters = { "GetIconAndTextWidgetVisualizationInfo", "GetTextWithStateWidgetVisualizationInfo",
    "GetDoubleIconAndTextWidgetVisualizationInfo", "GetStatusBarWidgetVisualizationInfo",
    "GetCaptureBarWidgetVisualizationInfo", "GetDoubleStateIconRowVisualizationInfo" }
  for _, key in ipairs(getters) do
    local data = U.call(W[key], id)
    if type(data) == "table" and U.value(data.shownState or data.state) ~= 0 then
      local prefix = "widget:" .. id
      if data.leftIcons or data.rightIcons then
        for _, side in ipairs({ "leftIcons", "rightIcons" }) do
          for i, icon in ipairs(data[side] or {}) do
            local state = U.value(icon.iconState)
            if state == 1 or state == 2 then
              Add(prefix .. side .. i, state == 1 and icon.state1Tooltip or icon.state2Tooltip, "OBJECTIVE")
            end
          end
        end
      elseif data.leftText or data.rightText then
        Add(prefix .. "L", data.leftText, "STATUS")
        Add(prefix .. "R", data.rightText, "STATUS")
      else
        Add(prefix, Clean(data.text) or Clean(data.overrideBarText) or data.tooltip,
          key:find("CaptureBar", 1, true) and "CONTROL" or "STATUS", data.barValue, data.barMax or data.barMaxValue)
      end
      return
    end
  end
end

function M.Poll()
  local bg = Live()
  if not bg then M.rows, M.notices, M.states, M.match = {}, {}, {}, nil; return end
  if M.match ~= ns.MatchSerial or M.map ~= bg.id then M.rows, M.notices, M.states = {}, {}, {} end
  M.match, M.map, M.rows = ns.MatchSerial, bg.id, {}
  local W, seen = C_UIWidgetManager, {}
  if W and W.GetAllWidgetsBySetID then
    for _, getter in ipairs({ "GetTopCenterWidgetSetID", "GetBelowMinimapWidgetSetID" }) do
      local set = U.read(W[getter])
      local widgets = set and U.call(W.GetAllWidgetsBySetID, set)
      for _, widget in ipairs(type(widgets) == "table" and widgets or {}) do
        local id = U.value(widget.widgetID)
        if type(id) == "number" and not seen[id] then seen[id] = true; Widget(id) end
      end
    end
  end
  -- Older clients expose round / reinforcement text as world states.
  if #M.rows == 0 then
    for i = 1, U.read(GetNumWorldStateUI) or 0 do
      local _, state, text, _, _, _, _, dynamic = U.call(GetWorldStateUIInfo, i)
      if U.value(state) == 1 then Add("legacy:" .. i, Clean(dynamic) or text, "ROUND") end
    end
  end
  local map = T.MapID()
  local P = C_AreaPoiInfo
  local ids = map and U.call(P and P.GetAreaPOIForMap, map)
  for _, id in ipairs(type(ids) == "table" and ids or {}) do
    local info = U.call(P.GetAreaPOIInfo, map, id)
    if type(info) == "table" and not T.HasGraveyard(info.name or "", info) then
      local owner = T.OwnerOf(info)
      local name, description = Clean(info.name), Clean(info.description)
      if name and (owner or description) then
        Add("poi:" .. id, name .. (owner and (owner == T.MyTeam() and " · ours" or " · theirs") or "")
          .. (description and (" · " .. description) or ""), bg.kind == "carts" and "CART" or "OBJECTIVE", nil, nil, owner)
      end
    end
  end
end

function M.Chat(_, text)
  if not Live() then return end
  text = Clean(text)
  if not text then return end
  if M.notices[1] and M.notices[1].text == text and GetTime() - M.notices[1].at < 2 then return end
  table.insert(M.notices, 1, { text = text, at = GetTime() })
  while #M.notices > 3 do table.remove(M.notices) end
end

function M.Append(rows, now)
  local bg = Live()
  if not bg or not ns.Core.On("objectiveOverview") then return end
  if BRIEF[bg.id] then table.insert(rows, 1, { tag = "PLAN", text = GOAL[bg.id], detail = BRIEF[bg.id], time = "", color = ns.Theme.Rgb("info") }) end
  local seen = {}
  for _, row in ipairs(M.rows) do
    if not seen[row.text] then rows[#rows + 1] = row; seen[row.text] = true end
    if #rows >= 12 then break end
  end
  for _, entry in ipairs(M.notices) do
    if now - entry.at < 45 then rows[#rows + 1] = { tag = "EVENT", text = entry.text,
      time = U.Ago(math.floor(now - entry.at)), color = ns.Theme.Rgb("warning") } end
  end
end

U.Every(1, M.Poll, "battleground mechanics")
U.Events({ CHAT_MSG_BG_SYSTEM_ALLIANCE = M.Chat, CHAT_MSG_BG_SYSTEM_HORDE = M.Chat,
  CHAT_MSG_BG_SYSTEM_NEUTRAL = M.Chat, CHAT_MSG_RAID_BOSS_EMOTE = M.Chat,
  PLAYER_ENTERING_WORLD = function() M.rows, M.notices, M.states = {}, {}, {} end }, "battleground status")
