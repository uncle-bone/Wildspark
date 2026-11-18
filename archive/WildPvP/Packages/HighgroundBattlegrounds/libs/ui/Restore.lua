local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Secure "target, act, then go back to your target" buttons, for every
-- clickable enemy row (kill order, nearby, arena, flag carriers).
---------------------------------------------------------------------------
-- "Target X, focus/mark it, then go back to your target": with NO target
-- before the click, /targetlasttarget has nothing to return to and leaves
-- you on the enemy. A secure snippet (allowed in combat) checks at click
-- time and ends the macro with /targetlasttarget or /cleartarget.
-- Buttons store the macro without its last line in "wb-<attribute>".
local canWrap = not (ns.Caps and ns.Caps.secureSnippets == false)
local restoreHeader = canWrap and CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
local RESTORE_SNIPPET = [[
  local attr = (button == "RightButton") and "macrotext2" or "macrotext"
  local body = self:GetAttribute("wb-" .. attr)
  if body and body ~= "" then
    if UnitExists("target") then
      self:SetAttribute(attr, body .. "\n/targetlasttarget")
    else
      self:SetAttribute(attr, body .. "\n/cleartarget")
    end
  end
]]
function Core.WrapRestore(btn)
  -- Checking pcall(WrapScript) alone is insufficient: snippets compile on
  -- the click, outside that pcall. Keep native macro actions on clients
  -- without a restricted compiler, including both clicks on enemy rows.
  if restoreHeader and restoreHeader.WrapScript then
    pcall(restoreHeader.WrapScript, restoreHeader, btn, "OnClick", RESTORE_SNIPPET)
  end
end

-- Set a target-then-return macro: the fallback text (if the snippet can't
-- run) plus the body the snippet completes.
function Core.SetReturnMacro(btn, attr, body)
  btn:SetAttribute("wb-" .. attr, body or "")
  btn:SetAttribute(attr, body and (body .. "\n/targetlasttarget") or "")
end
