local _, ns = ...

-- Text encodings for strings shared through chat, forums and Discord.
local Codec = {}
ns.Codec = Codec

-- Base64 (RFC 4648, standard alphabet, "=" padding).
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64INDEX = {}
for i = 1, 64 do B64INDEX[B64:sub(i, i)] = i - 1 end

function Codec.Encode64(text)
  local out = {}
  for i = 1, #text, 3 do
    local a, b, c = text:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local chars = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
    for j = 1, 4 do chars[j] = B64:sub(chars[j] + 1, chars[j] + 1) end
    if not b then chars[3] = "=" end
    if not c then chars[4] = "=" end
    out[#out + 1] = table.concat(chars)
  end
  return table.concat(out)
end

-- Text, or nil when this isn't valid base64. Whitespace is ignored.
function Codec.Decode64(text)
  text = (text or ""):gsub("%s+", "")
  if text == "" or #text % 4 ~= 0 or text:find("[^%w%+/=]") or text:find("=[^=]") then return nil end
  -- At most two padding characters (Profiles.Decode64 accepted "====").
  if text:find("===$") then return nil end
  local out = {}
  for i = 1, #text, 4 do
    local n, pad = 0, 0
    for j = i, i + 3 do
      local ch = text:sub(j, j)
      if ch == "=" then pad = pad + 1 end
      n = n * 64 + (B64INDEX[ch] or 0)
    end
    local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
    out[#out + 1] = bytes:sub(1, 3 - pad)
  end
  return table.concat(out)
end

-- Length-prefixed data, never Lua code. Bounded decoding is also used for
-- full setup profiles; imports cannot execute functions or create cycles.
function Codec.Pack(value)
  local function encode(v, depth)
    assert(depth <= 8, "data nesting limit")
    local kind = type(v)
    if kind == "boolean" then return v and "b1" or "b0" end
    if kind == "string" or kind == "number" then
      assert(kind ~= "number" or (v == v and math.abs(v) ~= math.huge), "invalid number")
      local s = tostring(v)
      return (kind == "string" and "s" or "n") .. #s .. ":" .. s
    end
    assert(kind == "table", "unsupported value")
    local keys, out = {}, {}
    for key in pairs(v) do
      assert(type(key) == "string" or type(key) == "number", "invalid key")
      keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return type(a) == type(b) and a < b or type(a) < type(b) end)
    out[1] = "t" .. #keys .. ":"
    for _, key in ipairs(keys) do out[#out + 1] = encode(key, depth + 1); out[#out + 1] = encode(v[key], depth + 1) end
    return table.concat(out)
  end
  return encode(value, 0)
end

function Codec.Unpack(text)
  if type(text) ~= "string" or #text > 131072 then return nil, "data too large" end
  local pos, values = 1, 0
  local function decode(depth)
    values = values + 1
    assert(depth <= 8 and values <= 10000, "data limit")
    local kind = text:sub(pos, pos); pos = pos + 1
    if kind == "b" then
      local value = text:sub(pos, pos); pos = pos + 1
      assert(value == "1" or value == "0", "invalid boolean")
      return value == "1"
    end
    assert(kind == "s" or kind == "n" or kind == "t", "invalid type")
    local colon = assert(text:find(":", pos, true), "missing length")
    local digits = text:sub(pos, colon - 1)
    assert(digits:match("^%d+$") and #digits <= 6, "invalid length")
    local length = tonumber(digits); pos = colon + 1
    if kind == "t" then
      assert(length <= 2000, "too many entries")
      local out = {}
      for _ = 1, length do
        local key = decode(depth + 1)
        assert(type(key) == "string" or type(key) == "number", "invalid key")
        assert(out[key] == nil, "duplicate key")
        out[key] = decode(depth + 1)
      end
      return out
    end
    assert(pos + length - 1 <= #text, "truncated data")
    local result = text:sub(pos, pos + length - 1); pos = pos + length
    if kind == "s" then return result end
    local n = tonumber(result)
    assert(n and n == n and math.abs(n) ~= math.huge, "invalid number")
    return n
  end
  local ok, result = pcall(decode, 0)
  if not ok or pos ~= #text + 1 then return nil, "invalid data" end
  return result
end
