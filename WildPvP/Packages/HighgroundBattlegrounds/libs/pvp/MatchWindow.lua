local _, ns = ...
local H, U, Kit = ns.MatchHistory, ns.Util, ns.Kit
local LABELS = { killingBlows = "Killing blows", honorableKills = "Honorable kills", deaths = "Deaths",
  honorGained = "Honor", damageDone = "Damage", healingDone = "Healing", ratingChange = "Rating change" }

function H.Entries()
  local entries, wins, losses = {}, 0, 0
  for _, match in ipairs(H.All()) do
    if match.result == "Win" then wins = wins + 1 elseif match.result == "Loss" then losses = losses + 1 end
    local detail = { match.name .. " — " .. match.result, match.character .. " · " .. (match.game or ""),
      "Specialization: " .. (match.specName or tostring(match.spec or "unknown")),
      "Duration: " .. U.Clock(match.duration or 0), "Joined: " .. date("%Y-%m-%d %H:%M", match.started) }
    for _, key in ipairs({ "killingBlows", "honorableKills", "deaths", "honorGained", "damageDone", "healingDone", "ratingChange" }) do
      if match.stats and match.stats[key] ~= nil then detail[#detail + 1] = LABELS[key] .. ": " .. match.stats[key] end
    end
    detail[#detail + 1] = "\nObserved objectives (latest events):"
    for i = math.max(1, #match.events - 10), #match.events do
      local e = match.events[i]; detail[#detail + 1] = U.Clock(e.at) .. "  " .. e.text
    end
    entries[#entries + 1] = { key = match.id, title = match.name .. " · " .. match.result,
      summary = match.character .. " · " .. U.Clock(match.duration or 0), detail = table.concat(detail, "\n"),
      search = match.name .. " " .. match.result .. " " .. match.character .. " " .. tostring(match.spec or "") .. " " .. (match.specName or ""), match = match }
  end
  H.summary = string.format("%d wins · %d losses · %.0f%% win rate in recorded results", wins, losses,
    wins + losses > 0 and wins / (wins + losses) * 100 or 0)
  return entries
end

function H.Open(embedded)
  if not H.win then
    H.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "MatchHistory", {
      title = "MATCH HISTORY", hint = "Search by map, result, character or specialization",
      data = H.Entries, empty = "Completed matches will appear here. Only observed information is recorded.",
      selected = function(_, w) w:SetSub(H.summary or "") end,
      actions = {
        { label = "Full timeline", run = function(entry)
          if not H.timeline then H.timeline = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "MatchTimeline", {
            title = "OBJECTIVE TIMELINE", width = 650, height = 500 }) end
          local lines = {}
          for _, e in ipairs(entry.match.events) do lines[#lines + 1] = U.Clock(e.at) .. "  " .. e.text end
          H.timeline:Open(entry.match.name, "Observed events since joining", table.concat(lines, "\n"), true)
        end },
        { label = "Delete entry", run = function(entry)
          local removed, index
          for i, m in ipairs(H.All()) do if m.id == entry.key then removed, index = table.remove(H.All(), i), i; break end end
          return true, "Match removed. You can undo this below.", function()
            if removed then table.insert(H.All(), math.min(index, #H.All() + 1), removed) end
          end
        end },
      },
    })
  end
  if not embedded then H.win:Open() end
  return H.win
end
