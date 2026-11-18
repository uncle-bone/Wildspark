local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Cata only (retail has no combat log). Enemy defensives: cast -> on
-- cooldown for its known duration; aura fading -> "spent: GO", even out of
-- sight. Deaths -> dead until the rez wave.
function Core.OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName, _, _, spellId, spellName = CombatLogGetCurrentEventInfo()
  if sub == "SPELL_CAST_START" or sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_FAILED" then
    Core.CaptureFromLog(sub, srcName, spellId, spellName)
    if sub ~= "SPELL_CAST_FAILED" then Core.SpecFromLog(srcName, spellName) end
  elseif sub == "SPELL_INTERRUPT" then
    Core.CaptureEnded(dstName)
  end
  if sub == "SPELL_AURA_APPLIED" and Core.NoteBurst then Core.NoteBurst(dstName, spellId) end
  if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED" or sub == "SPELL_INTERRUPT" then
    local entry = Core.kitBySpell[spellId]
    local e = entry and Core.enemies[Core.Canon(srcName) or ""]
    if e and (entry.class == nil or entry.class == e.class) then
      ns.TrackCooldown(e, entry, sub, GetTime())
    end
  elseif sub == "SPELL_AURA_REMOVED" then
    local target = Core.enemies[Core.Canon(dstName) or ""]
    if target and target.activeCooldowns then target.activeCooldowns[ns.CooldownKey(spellId)] = nil end
    local relevant = ns.DefensiveWeight(spellId, Core.me.dmg) > 0
    local e = relevant and Core.enemies[Core.Canon(dstName) or ""]
    if e and ns.CooldownTracked(Core.db, spellId) then
      e.burnedAt, e.burnedSpell = GetTime(), spellId
    end
  elseif sub == "UNIT_DIED" then
    local e = Core.enemies[Core.Canon(dstName) or ""]
    if e then
      e.dead, e.diedAt = true, GetTime()
      Core.SapCall(e)
    end
  end
end
