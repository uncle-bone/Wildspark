local _, ns = ...
local Core, Theme = ns.Core, ns.Theme
local Motion = {}
ns.Motion = Motion

-- One driver, awake only while a transition is running. Each region owns
-- one transition; retargeting starts at its current value. Alpha never
-- changes geometry; Value also supports plain-frame accordion layouts.
local active, tick, driver = {}, {}, nil

local function Reduced() return Core.db and Core.db.reducedMotion == true end

local function Idle()
  if driver and not next(active) then driver:SetScript("OnUpdate", nil); driver:Hide() end
end

local function Apply(region, state, value)
  if state.apply then state.apply(region, value) else region:SetAlpha(value) end
end

local function Finish(region, state)
  active[region] = nil
  Apply(region, state, state.to)
  if state.hide then region:Hide() end
end

-- Layout and visibility callbacks can start or cancel other transitions.
-- Snapshot before invoking them so each starting state advances only once.
local function Snapshot(pending)
  local count = 0
  for region, state in pairs(active) do
    pending[count + 1], pending[count + 2] = region, state
    count = count + 2
  end
  return count
end

local function Update(_, elapsed)
  local count = Snapshot(tick)
  for i = 1, count, 2 do
    local region, state = tick[i], tick[i + 1]
    tick[i], tick[i + 1] = nil, nil
    if active[region] == state then
      state.elapsed = state.elapsed + elapsed
      local progress = math.min(1, state.elapsed / state.duration)
      if progress >= 1 or Reduced() or not region:IsVisible() then
        Finish(region, state)
      else
        -- Cubic ease-out: immediate response with a soft landing, no overshoot.
        local eased = 1 - (1 - progress) ^ 3
        Apply(region, state, state.from + (state.to - state.from) * eased)
      end
    end
  end
  Idle()
end

function Motion.IsPlaying(region) return active[region] ~= nil end

-- Cancel without invoking a stale completion. Optional alpha snaps to a
-- known state; otherwise the current visual value is preserved.
function Motion.Stop(region, alpha)
  active[region] = nil
  if alpha ~= nil then region:SetAlpha(alpha) end
  Idle()
end

-- Settle a transition at its requested endpoint, including its layout.
function Motion.Finish(region)
  if active[region] then Finish(region, active[region]) end
  Idle()
end

local function Start(region, from, target, duration, apply)
  duration = type(duration) == "string" and Theme.Motion(duration) or duration or Theme.Motion("hover")
  if Reduced() or duration <= 0 or not region:IsVisible() or from == target then
    Motion.Stop(region)
    if apply then apply(region, target) else region:SetAlpha(target) end
    return
  end
  local previous = active[region]
  if previous and previous.to == target and previous.apply == apply then previous.hide = nil; return end
  active[region] = { from = from, to = target, elapsed = 0, duration = duration, apply = apply }
  if not driver then driver = CreateFrame("Frame", nil, UIParent) end
  driver:SetScript("OnUpdate", Update)
  driver:Show()
end

-- duration: a motion token, or seconds (0 for immediate updates).
-- This primitive only changes alpha, never visibility or geometry.
function Motion.Alpha(region, alpha, duration)
  Start(region, region:GetAlpha() or 1, alpha, duration)
end

-- A scalar owned by a plain frame. apply(owner, value) updates its visual
-- state. Keep that callback stable when retargeting; never resize secure UI.
function Motion.Value(owner, from, target, duration, apply)
  Start(owner, from, target, duration, apply)
end

-- Decorative textures only: fading out may hide the texture at completion.
-- Callers keep action, selection and focus state synchronous with input.
function Motion.Show(region, on, duration)
  if on then
    if not region:IsShown() then region:SetAlpha(0); region:Show() end
    Motion.Alpha(region, 1, duration)
  else
    Motion.Alpha(region, 0, duration)
    if active[region] then active[region].hide = true else region:Hide() end
  end
end

-- Shallow entrances keep new content readable on the first frame. Nested
-- windows don't multiply fades, and repeated refreshes don't restart one.
function Motion.Reveal(region, duration, from)
  if Reduced() or not region:IsVisible() then Motion.Stop(region, 1); return end
  if active[region] and active[region].reveal then return end
  local parent = region:GetParent()
  while parent do
    if active[parent] and active[parent].reveal then Motion.Stop(region, 1); return end
    parent = parent:GetParent()
  end
  Motion.Stop(region, from or Theme.Alpha("enter"))
  Motion.Alpha(region, 1, duration or "enter")
  if active[region] then active[region].reveal = true end
end

-- Semantic marks disappear immediately; entering marks start visible.
function Motion.Mark(region, on, immediate, duration)
  local shown = region:IsShown()
  if not on then Motion.Stop(region, 1); region:Hide(); return end
  region:Show()
  if immediate then Motion.Stop(region, 1)
  elseif not shown then Motion.Reveal(region, duration or "select", Theme.Alpha("markEnter")) end
end

-- Changing the accessibility preference settles every in-flight state now.
-- Re-enabling motion never replays an old interaction.
function Motion.Refresh()
  if not Reduced() then return end
  local pending = {}
  local count = Snapshot(pending)
  for i = 1, count, 2 do
    local region, state = pending[i], pending[i + 1]
    if active[region] == state then Finish(region, state) end
  end
  Idle()
end
