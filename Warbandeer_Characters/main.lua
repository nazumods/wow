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
    toon[brokerName][fieldName] = field:get(toon, toon[brokerName][fieldName])
  end
  if #queue == 0 then
    toon.lastRefresh = time()
    return
  end
  self:delay(100, "refreshQueue")
end
