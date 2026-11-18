local addon, ns = ...
local U, Core = ns.Util, ns.Core
local S = { GRACE = 2, REPEAT = 10 }
ns.Stealth = S

-- Shared by Nearby and the battleground/arena observers. Only the final
-- hiding aura ends stealth; Vanish and Invisibility have intermediate auras.
S.spells = {
  [1784] = { "Stealth", fades = true }, [1785] = { "Stealth", fades = true },
  [1786] = { "Stealth", fades = true }, [1787] = { "Stealth", fades = true },
  [115191] = { "Stealth", fades = true },
  [5215] = { "Prowl", fades = true }, [6783] = { "Prowl", fades = true }, [9913] = { "Prowl", fades = true },
  [1856] = { "Vanish" }, [1857] = { "Vanish" }, [11327] = { "Vanish" },
  [66] = { "Invisibility" }, [32612] = { "Invisibility", fades = true },
  [110959] = { "Greater Invisibility", fades = true },
  [58984] = { "Shadowmeld", fades = true },
  [199483] = { "Camouflage", fades = true },
}

local sounds = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\"
local function Play(file)
  -- Newly installed files need a client restart. Until then, use the
  -- original in-game Stealth sound kit, never the raid-warning cue.
  if not U.call(PlaySoundFile, sounds .. file .. ".ogg", "Master") then
    U.call(PlaySound, 3325, "Master")
  end
end
function S.EnterSound() Play("stealth-enter") end
function S.ExitSound() Play("stealth-exit") end

local function Notify(e, spell, faded, nearby)
  if ns.NearbyHistory and ns.NearbyHistory.Muted and ns.NearbyHistory.Muted(e.name) then return end
  local class = U.ClassName(e.class)
  local who = e.name:match("^[^-]+") .. (class and (" (" .. class .. ")") or "")
  local text = faded and (who .. ": " .. spell .. " faded")
    or (who .. " used " .. spell .. (nearby and " nearby" or ""))
  local sound = (not nearby or Core.O("nearbySound")) and (faded and S.ExitSound or S.EnterSound) or nil
  if U.Notify then U.Notify("stealth", e.name .. (faded and ":faded" or ""), text, sound)
  else
    U.Say(text, "warning")
    if sound and Core.On("sound") then sound() end
  end
end

function S.Hid(e, spellId, nearby)
  local spell = S.spells[U.value(spellId) or 0]
  if not (spell and e) then return end
  local now = GetTime()
  local quiet = e.hidden and now - e.hidden.at < S.REPEAT
  e.hidden = { spell = spell[1], id = spellId, at = now }
  if not quiet then Notify(e, spell[1], false, nearby) end
end

-- A visible stealthed enemy can still have a readable aura. Never infer a
-- fade from an unreadable aura result. Confirmed combat-log removals bypass
-- both this check and the grace period, including an immediate stealth break.
local function StillHidden(unit, hidden)
  local get = unit and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if not get then return false end
  local name = U.SpellName(hidden.id) or hidden.spell
  local ok, aura = pcall(get, unit, name, "HELPFUL")
  return not ok or U.secret(aura) or type(aura) == "table"
end

function S.Shown(e, unit, nearby, confirmed)
  if not (e and e.hidden) then return end
  if not confirmed and (GetTime() - e.hidden.at < S.GRACE or StillHidden(unit, e.hidden)) then return end
  local spell = e.hidden.spell
  e.hidden = nil
  Notify(e, spell, true, nearby)
end

function S.UnitKey(unit)
  return Core.FullUnitName(unit)
end

function S.Hostile(unit)
  return U.read(UnitIsPlayer, unit) and U.read(UnitCanAttack, "player", unit)
end

function S.HostileFlags(flags)
  return type(flags) == "number" and bit.band(flags, 0x40) ~= 0 and bit.band(flags, 0x400) ~= 0
end
