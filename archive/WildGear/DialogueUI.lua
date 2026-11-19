local _, addonRoot = ...
local ns = addonRoot.WildGear

-- Dialogue UI (the addon) shows quests in a window of its own instead of the
-- game's, so neither the marks of QuestWindow.lua nor the block of
-- Tooltip.lua reach the rewards there. With it:
--   * Its upgrade arrow on a reward (its setting "Evaluate Item Rewards")
--     goes by our verdict (QuestWindow.IsRewardUpgrade: the tiles' rule, main
--     spec, else off specs) instead of item level alone. We register as its
--     item evaluator (DialogueUIAPI.AddItemEvaluator), at login: it takes one
--     addon, and its own Pawn plugin registers later, on entering the world,
--     so Pawn users see Dialogue UI say once a session that we have it. Its
--     1.0.7 only starts asking an evaluator registered that way when the
--     setting is next changed, so its reward buttons are hooked too (their
--     mixin, before it makes any): ShowUpgradeIcon shows the arrow only on
--     our upgrades, and SetItem asks for it on each of them (again a moment
--     later while an item is loading).
--   * Its item tooltip gets the block as text (Tip.AddLines, through
--     DialogueUIAPI.AddItemTooltipProcessorExternal). With its "Use Blizzard
--     Tooltip" it shows the game's tooltip, which has the block anyway.
-- Settings: Quest rewards off gives Dialogue UI back its own arrows; Tooltip
-- off leaves its tooltip alone.

local NAME = "WildGear"
local RETRY, RETRIES = 0.35, 3 -- a reward still loading: ask again this much later, this many times

local reported -- report the first error only: it would repeat on every reward
local function Report(err)
    if reported then return end
    reported = true
    if geterrorhandler then geterrorhandler()(err) else error(err) end
end

local function Ready()
    return ns.db and ns.charDB and ns.QuestWindow and ns.QuestWindow.IsRewardUpgrade and true or false
end

-- The evaluator: whether the reward with link `link` is an upgrade, and
-- whether that can be told yet.
local function IsUpgrade(link)
    if not Ready() then return false, true end
    local ok, up, ready = pcall(ns.QuestWindow.IsRewardUpgrade, link)
    if not ok then
        Report(up)
        return false, true
    end
    return up, ready
end

-- Our verdict on reward button `button` (its quest's reward `index` of kind
-- `type`), as IsUpgrade's; nil when it isn't ours to give (not an item,
-- Settings' Quest rewards off, the addon still loading).
local function ButtonVerdict(button)
    if not Ready() or ns.db.questMarks == false then return nil end
    if button.objectType ~= "item" or not button.type or not button.index or not GetQuestItemLink then return nil end
    return IsUpgrade(GetQuestItemLink(button.type, button.index))
end

-- Whether Dialogue UI's own setting has its arrows on.
local function ArrowsOn()
    local db = rawget(_G, "DialogueUI_DB")
    return type(db) ~= "table" or db.ShowUpgradeArrow ~= false
end

local function AskButton(button, tries)
    if not (ArrowsOn() and button.isEquippable and button:IsShown()) then return end
    local up, ready = ButtonVerdict(button)
    if up then
        button:ShowUpgradeIcon()
    elseif up == false and not ready and tries < RETRIES then
        local kind, index = button.type, button.index
        C_Timer.After(RETRY, function()
            if button.type == kind and button.index == index then AskButton(button, tries + 1) end
        end)
    end
end

-- Hooks the reward buttons' mixin `mixin`; the buttons copy its functions when made.
local function HookButtons(mixin)
    if type(mixin) ~= "table" or mixin.flbisHooked then return end
    if type(mixin.ShowUpgradeIcon) ~= "function" or type(mixin.SetItem) ~= "function" then return end
    mixin.flbisHooked = true
    local show = mixin.ShowUpgradeIcon
    mixin.ShowUpgradeIcon = function(self, ...)
        local up = ButtonVerdict(self)
        if up == nil or up then return show(self, ...) end
    end
    hooksecurefunc(mixin, "SetItem", function(self)
        local ok, err = pcall(AskButton, self, 0)
        if not ok then Report(err) end
    end)
end

local function Tooltip(tooltip, itemID, itemLink)
    if not Ready() or ns.db.tooltip == false or not itemID then return false end
    local ok, r = pcall(ns.Tooltip.AddLines, tooltip, itemID, itemLink)
    if not ok then
        Report(r)
        return false
    end
    return r ~= nil
end

local done = {}
local function Hook()
    HookButtons(rawget(_G, "DUIDialogItemButtonMixin"))
    local api = rawget(_G, "DialogueUIAPI")
    if type(api) ~= "table" then return end
    if not done.tooltip and type(api.AddItemTooltipProcessorExternal) == "function" then
        done.tooltip = true
        api.AddItemTooltipProcessorExternal(Tooltip)
    end
    if not done.evaluator and Ready() and type(api.AddItemEvaluator) == "function" then
        done.evaluator = true
        api.AddItemEvaluator(NAME, IsUpgrade)
    end
end

Hook() -- (the buttons' mixin, before Dialogue UI makes any: it loads first, OptionalDeps)
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "DialogueUI" then Hook() end
end)
