local _, ns = ...

-- Pure data registry. A TOC loads one class/client config, then this registry
-- and one file per battleground. Rules never fall through to another client.
ns.BattlegroundConfigs = {}
local index = { retail = { ui = {}, inst = {} }, cata = { ui = {}, inst = {} } }
local resolved = {}

local PRIORITY = {
  ctf = { label = "CTF", objective = 1.5, focus = 1.3, impact = 1.2 },
  orb = { label = "Orbs", objective = 1.4, focus = 1.2 },
  carry = { label = "Flag+bases", objective = 1.2, impact = 1.2 },
  nodes = { label = "Nodes", impact = 1.3, focus = 1.3 },
  carts = { label = "Carts", impact = 1.3, focus = 1.3 },
  resource = { label = "Resources", impact = 1.3, focus = 1.3 },
  epic = { label = "Epic", focus = 1.5, range = 1.5, impact = 0.8 },
}

local function Copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = Copy(v) end
  return out
end

-- Lists replace lists; named rule groups merge. False explicitly disables a
-- value inherited from shared rules (nil cannot be stored in a Lua table).
local function Merge(dst, src)
  for k, v in pairs(src or {}) do
    if type(v) == "table" and type(dst[k]) == "table" and v[1] == nil and dst[k][1] == nil then
      Merge(dst[k], v)
    else
      dst[k] = Copy(v)
    end
  end
  return dst
end

function ns.RegisterBattleground(config)
  assert(type(config.id) == "string" and not ns.BattlegroundConfigs[config.id], "duplicate/missing battleground id")
  assert(type(config.name) == "string" and PRIORITY[config.kind], "invalid battleground identity")
  assert(type(config.size) == "number" and config.size > 0, "battleground needs a team size")
  assert(type(config.clients) == "table" and next(config.clients), "battleground needs a client")
  for client, maps in pairs(config.clients) do
    assert(index[client], "unsupported battleground client: " .. tostring(client))
    for _, kind in ipairs({ "ui", "inst" }) do
      for _, id in ipairs(maps[kind] or {}) do
        assert(type(id) == "number" and not index[client][kind][id], "duplicate/invalid map id: " .. tostring(id))
        index[client][kind][id] = config
      end
    end
  end
  ns.BattlegroundConfigs[config.id] = config
end

function ns.ResolveBattleground(ui, instance, client, mode)
  client = client or ns.CLIENT
  local lookup = index[client]
  if not lookup then return nil end
  -- An instance ID is more reliable than a transient/stale UI map.
  local config = lookup.inst[instance] or lookup.ui[ui]
  if not config then return nil end
  mode = (client == "retail" and mode == "blitz" and "blitz") or (mode == "rated" and "rated") or "standard"
  local maps = config.clients[client]
  local variant = maps.variants and maps.variants[instance]
  local key = client .. ":" .. config.id .. ":" .. (variant and variant.id or "default") .. ":" .. mode
  if resolved[key] then return resolved[key] end
  local rules = {
    resurrection = { period = 30 },
    capture = {},
    graveyards = { mode = "none" },
    scoring = { predict = false },
    map = {},
    priority = Copy(PRIORITY[config.kind]),
  }
  Merge(rules, config.rules)
  Merge(rules, maps.rules)
  Merge(rules, variant and variant.rules)
  if mode == "blitz" then
    rules.priority.impact = (rules.priority.impact or 1) * 1.3
    Merge(rules, config.blitz)
  elseif mode == "rated" then
    -- Rated battlegrounds resurrect every 45 seconds.
    Merge(rules, { resurrection = { period = 45 } })
    Merge(rules, config.rated)
  end
  assert(rules.resurrection.period > 0, "invalid resurrection period")
  if rules.capture.seconds then assert(rules.capture.seconds > 0, "invalid capture time") end
  local bg = {
    id = config.id, name = config.name, kind = config.kind, client = client, mode = mode,
    -- Players per team: rated battlegrounds are 10v10, Blitz 8v8.
    size = (mode == "blitz" and 8) or (mode == "rated" and 10) or config.size,
    variant = variant and variant.id,
    ui = maps.ui or {}, inst = maps.inst or {}, rulesKey = key, rules = rules,
    coverage = config.coverage,
  }
  resolved[key] = bg
  return bg
end
