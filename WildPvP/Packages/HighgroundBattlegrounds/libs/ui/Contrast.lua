local _, ns = ...
local Theme = ns.Theme

-- Class text may need lighter/darker ink, especially yellow and white on
-- linen. Blend toward neutral white/black so distinct hues stay distinct.
-- Cache per palette and repaint even windows that are currently idle.
local cache = {}
local rowCache = {}
local classTexts = setmetatable({}, { __mode = "k" })

local function Luminance(c)
  local function Linear(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  return Linear(c[1]) * 0.2126 + Linear(c[2]) * 0.7152 + Linear(c[3]) * 0.0722
end

local function Mix(fg, bg, alpha)
  local c = {}
  for i = 1, 3 do c[i] = fg[i] * alpha + bg[i] * (1 - alpha) end
  return c
end

local function Readable(c, backgrounds)
  local l = Luminance(c)
  for _, bg in ipairs(backgrounds) do
    if (math.max(l, bg) + 0.05) / (math.min(l, bg) + 0.05) < 4.5 then return false end
  end
  return true
end

-- Class backgrounds stay visible over the whole enemy row, independently
-- of health. Bound the tint against the brightest/darkest possible health
-- fill and the board's overlays; white/yellow classes need less tint than
-- blue/red ones. Cache per RGB and theme, never per health update.
function Theme.EnemyRowColor(c)
  local base = Theme.Rgb("surface")
  if not c or Theme.Alpha("classRow") == 0 then return base end
  local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
  local key = r .. ":" .. g .. ":" .. b
  if rowCache[key] then return rowCache[key] end
  local original, result = { r, g, b }, base
  for step = 20, 0, -1 do
    result = Mix(original, base, Theme.Alpha("classRow") * step / 20)
    local backgrounds = { Luminance(result) }
    for _, fill in ipairs({ "black", "white" }) do
      local bg = Mix(Theme.Rgb(fill), result, Theme.Alpha("healthFill"))
      bg = Mix(Theme.Rgb("textMuted"), bg, math.max(Theme.Alpha("zebraOdd"), Theme.Alpha("zebraEven")))
      bg = Mix(Theme.Rgb("accent"), bg, Theme.Alpha("topTint"))
      local hover = Theme.Rgb("overlayHover")
      backgrounds[#backgrounds + 1] = Luminance(Mix(hover, bg, hover[4]))
    end
    local readable = true
    for _, ink in ipairs({ "text", "textMuted", "textDim", "accent", "danger", "kill", "success", "pending", "chipCarrier" }) do
      if not Readable(Theme.Rgb(ink), backgrounds) then readable = false; break end
    end
    if readable then break end
  end
  rowCache[key] = result
  return result
end

function Theme.ClassColor(c)
  local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
  local key = r .. ":" .. g .. ":" .. b
  if cache[key] then return cache[key] end
  local original, backgrounds = { r, g, b }, {}
  for _, name in ipairs({ "bg", "surface", "surfaceRaised" }) do
    for _, fill in ipairs({ "black", "white" }) do
      local bg = Mix(Theme.Rgb(fill), Theme.Rgb(name), Theme.Alpha("healthFill"))
      local hover = Theme.Rgb("overlayHover")
      backgrounds[#backgrounds + 1] = Luminance(Mix(hover, bg, hover[4]))
    end
  end
  if Theme.Alpha("classRow") > 0 then
    for _, fill in ipairs({ "black", "white" }) do
      local bg = Mix(Theme.Rgb(fill), Theme.EnemyRowColor(c), Theme.Alpha("healthFill"))
      local hover = Theme.Rgb("overlayHover")
      backgrounds[#backgrounds + 1] = Luminance(Mix(hover, bg, hover[4]))
    end
  end
  local lightInk = Luminance(Theme.Rgb("text")) > Luminance(Theme.Rgb("bg"))
  local ink, result = Theme.Rgb(lightInk and "white" or "black"), original
  for step = 0, 20 do
    result = Mix(ink, original, step / 20)
    if Readable(result, backgrounds) then break end
  end
  cache[key] = result
  return result
end

function Theme.PaintClass(fs, color)
  Theme.Unpaint(fs)
  fs.wbClass = color
  classTexts[fs] = true
  fs:SetTextColor(unpack(Theme.ClassColor(color)))
end

Theme.OnChange(function()
  wipe(cache)
  wipe(rowCache)
  for fs in pairs(classTexts) do
    if fs.wbClass then fs:SetTextColor(unpack(Theme.ClassColor(fs.wbClass)))
    else classTexts[fs] = nil end
  end
end)
