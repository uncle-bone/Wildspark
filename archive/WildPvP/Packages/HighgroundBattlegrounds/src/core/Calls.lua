local _, ns = ...
local U, Kit, T = ns.Util, ns.Kit, ns.Timers
local Calls = {}
ns.ObjectiveCalls = Calls
local LABELS = { incoming = "Incoming", help = "Need help", clear = "Clear", escort = "Escort our carrier" }

function Calls.Area()
  local area = U.read(GetSubZoneText)
  return (ns.NodeForArea and ns.NodeForArea(area)) or (area ~= "" and area) or "my position"
end

function Calls.Draft(kind, count, location)
  if not LABELS[kind] then return false, "Choose incoming, help, clear or escort." end
  if count ~= nil and not tonumber(count) then return false, "Enemy count must be 1–40." end
  count = tonumber(count)
  if count and (count < 1 or count > 40 or count ~= math.floor(count)) then return false, "Enemy count must be 1–40." end
  location = U.Trim(location or Calls.Area()):gsub("[\r\n|]", ""):sub(1, 90)
  local number = count and (kind == "incoming" and (" " .. count) or kind == "help" and (" (" .. count .. " enemies)")) or ""
  local text = LABELS[kind] .. (number or "") .. " — " .. location
  local db = ns.GetDB()
  local channel = db and db.objectiveChannel or "i"
  local prefixes = { i = "/i ", raid = "/raid ", party = "/p ", s = "/s " }
  local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
  local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
  local edit = active and active()
  if edit and edit:GetText() ~= "" then return false, "Send or clear your current chat draft first." end
  if not open then return false, "Chat is unavailable." end
  open((prefixes[channel] or prefixes.i) .. text)
  return true
end

function Calls.Open(embedded)
  if Calls.win then
    Calls.win.area:SetText(Calls.Area())
    if not embedded then if ns.Hub then ns.Hub.Release(Calls.win) end; Calls.win:Show() end
    return Calls.win
  end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "Calls", { title = "TEAM CALLOUTS", width = 510,
    height = 300, sub = "Prepare a message, then press Enter to send", savedKey = "calls" })
  Calls.win = w
  w.area = Kit.Input(w, 300, "Location"); w.area:SetPoint("TOPLEFT", 20, -95)
  w.count = Kit.Input(w, 110, "Enemy count"); w.count:SetPoint("LEFT", w.area, "RIGHT", 12, 0)
  w.channel = Kit.Select(w, { width = 200, menu = true, choices = {
    { key = "i", label = "Battleground" }, { key = "raid", label = "Raid" },
    { key = "party", label = "Party" }, { key = "s", label = "Say" },
  }, onChange = function(_, value) ns.GetDB().objectiveChannel = value end })
  w.channel:SetPoint("TOPLEFT", 20, -145)
  for i, kind in ipairs({ "incoming", "help", "clear", "escort" }) do
    local button = Kit.Button(w, LABELS[kind], 220, 28, { onClick = function()
      local ok, err = Calls.Draft(kind, w.count:GetText() ~= "" and w.count:GetText() or nil, w.area:GetText())
      if not ok then U.Say(err) end
    end })
    button:SetPoint("TOPLEFT", 20 + ((i - 1) % 2) * 235, -195 - math.floor((i - 1) / 2) * 36)
  end
  w.area:SetText(Calls.Area()); w.channel:SetValue(ns.GetDB().objectiveChannel or "i", true)
  if embedded then w:Hide() else w:Show() end
  return w
end

function Calls.Command(text)
  local kind, rest = (text or ""):match("^(%S*)%s*(.-)$")
  if kind == "" then return Calls.Open() end
  local count, area = rest:match("^(%d+)%s*(.-)$")
  C_Timer.After(0.01, function()
    local ok, err = Calls.Draft(kind:lower(), count, (count and area ~= "" and area) or (not count and rest ~= "" and rest) or nil)
    if not ok then U.Say(err) end
  end)
end
if ns.Commands then ns.Commands.calls = function(_, msg) Calls.Command(msg:match("^%S+%s*(.*)$")) end end
