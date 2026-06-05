local _, ns = ...

local base64 = ns.base64
local crc32  = ns.crc32

local VERSION = 1

-- ── Packer ────────────────────────────────────────────────────────────────────

local function Pack(profile)
  local buf = {}

  local function byte(n)  buf[#buf+1] = n % 256 end
  local function int16(n)
    buf[#buf+1] = math.floor(n / 256) % 256
    buf[#buf+1] = n % 256
  end
  local function int24(n)
    buf[#buf+1] = math.floor(n / 65536) % 256
    buf[#buf+1] = math.floor(n / 256)   % 256
    buf[#buf+1] = n % 256
  end
  local function str8(s)
    s = s or ""
    byte(#s)
    for i = 1, #s do buf[#buf+1] = string.byte(s, i) end
  end
  local function str16(s)
    s = s or ""
    int16(#s)
    for i = 1, #s do buf[#buf+1] = string.byte(s, i) end
  end

  -- metadata
  str8(profile.char  or "")
  str8(profile.class or "")
  str8(profile.spec  or "")

  -- slots
  local slots = profile.slots or {}
  int16(#slots)
  for _, s in ipairs(slots) do
    byte(s.id)
    str8(s.type)
    int24(s.index    or 0)
    str8(s.strindex or "")
  end

  -- bindings
  local binds = profile.binds or {}
  int16(#binds)
  for _, b in ipairs(binds) do
    str8(b.command)
    str8(b.key1 or "")
    str8(b.key2 or "")
  end

  -- macros
  local macros = profile.macros or {}
  int16(#macros)
  for _, m in ipairs(macros) do
    int16(m.id)
    str8(m.name)
    str8(m.icon)
    str16(m.body or "")
  end

  -- pet slots
  local petslots = profile.petslots or {}
  byte(#petslots)
  for _, p in ipairs(petslots) do
    byte(p.id)
    str8(p.type)
    int24(p.index    or 0)
    str8(p.strindex or "")
  end

  -- outfits
  local outfits = profile.outfits or {}
  byte(#outfits)
  for _, name in ipairs(outfits) do
    str8(name)
  end

  return buf
end

-- ── Unpacker ──────────────────────────────────────────────────────────────────

local function Unpack(buf)
  local pos = 1

  local function byte()
    local v = buf[pos]; pos = pos + 1; return v
  end
  local function int16()
    local hi, lo = buf[pos], buf[pos+1]; pos = pos + 2
    return hi * 256 + lo
  end
  local function int24()
    local a, b, c = buf[pos], buf[pos+1], buf[pos+2]; pos = pos + 3
    return a * 65536 + b * 256 + c
  end
  local function str8()
    local len = byte()
    local s = {}
    for _ = 1, len do s[#s+1] = string.char(buf[pos]); pos = pos + 1 end
    return table.concat(s)
  end
  local function str16()
    local len = int16()
    local s = {}
    for _ = 1, len do s[#s+1] = string.char(buf[pos]); pos = pos + 1 end
    return table.concat(s)
  end

  local profile = {}
  profile.char  = str8()
  profile.class = str8()
  profile.spec  = str8()

  local nSlots = int16()
  profile.slots = {}
  for _ = 1, nSlots do
    local s = { id = byte(), type = str8(), index = int24(), strindex = str8() }
    if s.index   == 0 then s.index    = nil end
    if s.strindex == "" then s.strindex = nil end
    profile.slots[#profile.slots+1] = s
  end

  local nBinds = int16()
  profile.binds = {}
  for _ = 1, nBinds do
    local b = { command = str8(), key1 = str8(), key2 = str8() }
    if b.key1 == "" then b.key1 = nil end
    if b.key2 == "" then b.key2 = nil end
    profile.binds[#profile.binds+1] = b
  end

  local nMacros = int16()
  profile.macros = {}
  for _ = 1, nMacros do
    profile.macros[#profile.macros+1] = {
      id = int16(), name = str8(), icon = str8(), body = str16(),
    }
  end

  local nPet = byte()
  profile.petslots = {}
  for _ = 1, nPet do
    local p = { id = byte(), type = str8(), index = int24(), strindex = str8() }
    if p.index    == 0  then p.index    = nil end
    if p.strindex == "" then p.strindex = nil end
    profile.petslots[#profile.petslots+1] = p
  end

  local nOutfits = byte()
  profile.outfits = {}
  for _ = 1, nOutfits do
    profile.outfits[#profile.outfits+1] = str8()
  end

  return profile
end

-- ── Public API ────────────────────────────────────────────────────────────────

local LINE_LEN = 60
local SEP      = IsWindowsClient() and "\r\n" or "\n"

---Encode a profile table to a copyable text string.
---@param profile table
---@return string
function ns.Encode(profile)
  local payload = Pack(profile)

  -- header: [version(1)] [crc(4)] [payload...]
  local frame = { VERSION, 0, 0, 0, 0 }
  for _, b in ipairs(payload) do frame[#frame+1] = b end
  local crc = crc32.enc(frame)
  -- store crc using integer bit ops to stay in integer domain
  frame[2] = bit.band(bit.rshift(crc, 24), 0xFF)
  frame[3] = bit.band(bit.rshift(crc, 16), 0xFF)
  frame[4] = bit.band(bit.rshift(crc,  8), 0xFF)
  frame[5] = bit.band(crc,                 0xFF)

  local b64 = base64.enc(frame)
  local lines = {
    "# Warbandeer Bars RGS",
    "# " .. (profile.char or "") .. " / " .. (profile.class or "") .. " / " .. (profile.spec or ""),
    "# --------------------",
  }
  for i = 1, #b64, LINE_LEN do
    lines[#lines+1] = b64:sub(i, i + LINE_LEN - 1)
  end
  lines[#lines+1] = "# --------------------"
  return table.concat(lines, SEP)
end

---Decode a text string back to a profile table. Returns profile or nil, errmsg.
---@param text string
---@return table|nil, string|nil
function ns.Decode(text)
  -- strip comment lines and whitespace
  local s = text:gsub("(#[^\n]*\n?)", ""):gsub("[@][^\n]*\n?", "")
  s = s:gsub("[\r\n%s]", "")
  local frame = base64.dec(s)

  if #frame < 5 then return nil, "Text too short" end

  local ver = frame[1]
  if ver ~= VERSION then return nil, "Unsupported version: " .. ver end

  -- verify crc
  local stored = bit.bor(
    bit.lshift(frame[2], 24),
    bit.lshift(frame[3], 16),
    bit.lshift(frame[4],  8),
    frame[5]
  )
  local saved2, saved3, saved4, saved5 = frame[2], frame[3], frame[4], frame[5]
  frame[2], frame[3], frame[4], frame[5] = 0, 0, 0, 0
  local computed = crc32.enc(frame)
  frame[2], frame[3], frame[4], frame[5] = saved2, saved3, saved4, saved5

  if stored ~= bit.band(computed, 0xFFFFFFFF) then
    return nil, "CRC mismatch — text may be corrupted"
  end

  -- unpack payload (skip 5-byte header)
  local payload = {}
  for i = 6, #frame do payload[#payload+1] = frame[i] end

  local ok, result = pcall(Unpack, payload)
  if not ok then return nil, "Decode error: " .. tostring(result) end
  return result
end
