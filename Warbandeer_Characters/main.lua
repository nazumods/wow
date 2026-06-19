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
