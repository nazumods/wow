local _, ns = ...
local insert, remove = table.insert, table.remove
local Player = ns.wow.Player

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
  for _,name in ipairs(self.brokerOrder) do
    insert(queue, 1, name)
  end
  self:delay(100, "refreshQueue")
end

function ns:refreshQueue()
  if #queue == 0 then return end
  local broker = remove(queue)
  ns.Print("Refreshing data: " .. broker)
  self.brokers[broker]:Update(self.currentData)
  self:delay(100, "refreshQueue")
end
