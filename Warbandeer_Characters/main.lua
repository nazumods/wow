---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, remove = table.insert, table.remove
local maxLevel = ns.wow.maxLevel

ns:registerCommand("refresh", "", function(self)
  self:refresh()
  self.Print("character data refreshed.")
end, "Refresh character data")

ns:registerCommand("dump", "", function(self)
  self.Print(self.currentData.name)
end, "Dump current character data")

-- Shared dump buffer: each /wbc dump <x> body writes lines via out:line(...)
-- instead of printing directly, so the same content can render to chat (dump) or
-- a copyable window (wdump — chat truncates and can't be copied). ns:registerDump
-- registers both wrappers and records the dump so `wdump` (bare/*) can emit them all.
local dumps = {}

local function makeBuffer()
  ---@class DumpBuffer
  ---@field lines string[]
  local buf = { lines = {} }
  -- out:line(...) mirrors print's space-joined varargs, appending one line.
  function buf:line(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    insert(self.lines, table.concat(parts, " "))
  end
  return buf
end

---@class Warbandeer_Characters
---@field registerDump fun(self, subcmd: string, title: string, description: string, body: fun(self, out: DumpBuffer, args: string))

--- Register a dump subcommand that renders through a shared buffer, wiring up both
--- `dump <subcmd>` (→ chat) and `wdump <subcmd>` (→ copyable window titled `title`).
---@param subcmd string
---@param title string window title used by the wdump variant
---@param description string
---@param body fun(self, out: DumpBuffer, args: string)
function ns:registerDump(subcmd, title, description, body)
  insert(dumps, { title = title, body = body })
  self:registerCommand("dump", subcmd, function(_, args)
    local buf = makeBuffer()
    body(self, buf, args)
    for _, line in ipairs(buf.lines) do print(line) end
  end, description)
  self:registerCommand("wdump", subcmd, function(_, args)
    local buf = makeBuffer()
    body(self, buf, args)
    ns.ui.ToggleCopyWindow(title, table.concat(buf.lines, "\n"))
  end, description)
end

-- /wbc wdump (or wdump *) — every dump under one copyable window, section-headed.
ns:registerCommand("wdump", "", function(self)
  local buf = makeBuffer()
  buf:line("Current character: " .. self.currentData.name)
  for _, d in ipairs(dumps) do
    buf:line("")
    buf:line("== " .. d.title .. " ==")
    d.body(self, buf, "")
  end
  ns.ui.ToggleCopyWindow("Warbandeer Dump", table.concat(buf.lines, "\n"))
end, "Dump everything to a copyable window")

local queue = {}
function ns:refresh()
  queue = {}
  for _,brokerName in ipairs(self.brokerOrder) do
    local broker = self.brokers[brokerName]
    for _,fieldName in ipairs(broker.fieldOrder) do
      insert(queue, {brokerName, fieldName})
    end
  end
  self:delay(100, "refreshQueue")
end

---@class Character
---@field lastRefresh integer? Timestamp of last broker refresh

function ns:refreshQueue()
  if #queue == 0 then return end
  local entry = remove(queue, 1)
  local brokerName, fieldName = entry[1], entry[2]
  local field = self.brokers[brokerName].fields[fieldName]
  local toon = self.currentData
  if not (field.maxLevel and toon.basic.level < maxLevel) then
    -- A field's get reads live WoW APIs that can momentarily return nil (an
    -- undiscovered currency, an item not yet loaded), so a throw here must not kill
    -- the rest of the queue: ns:delay clears its OnUpdate before invoking us, so an
    -- error would skip the re-arm below and silently strand every field after this
    -- one (and never stamp lastRefresh). pcall and keep the cached value on failure
    -- so the chain always continues to the next field.
    local ok, value = pcall(field.get, field, toon, toon[brokerName][fieldName])
    if ok then toon[brokerName][fieldName] = value end
  end
  if #queue == 0 then
    toon.lastRefresh = time()
    return
  end
  self:delay(100, "refreshQueue")
end
