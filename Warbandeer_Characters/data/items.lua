local _, ns = ...
local BagID = ns.wow.Player.bags.ItemID
local Find = ns.lua.lists.find
local GetNumSlots = ns.wow.Items.GetNumSlots

ns:registerCommand("refresh", "items", function(self)
  ns:scanItems()
  ns.Print("items scanned.")
end)

local Items = {
  GoblinMiniFridge = {
    id = 220774,
  },
  ArathorSatchel = {
    id = 224578,
  },
  PortableRefridgerator = {
    id = 92748,
  },
}

---@type Broker
ns.Items = ns:RegisterBroker("items")

local LAST_BAG_IDX = NUM_BAG_SLOTS + 1 -- luacheck: globals NUM_BAG_SLOTS
ns.Items.fields = {
  bags = {
    get = function()
      local bags = {}
      for i = 1, LAST_BAG_IDX do
        local id = BagID(i)
        bags[i] = { id = id, slots = GetNumSlots(i) }
      end
      for name,i in pairs(Items) do
        bags[name] = Find(bags, function(b) return b.id == i.id end)
      end
      return bags
    end,
  },
  reagentBag = {
    get = function()
      return { id = BagID(LAST_BAG_IDX), slots = GetNumSlots(LAST_BAG_IDX)}
    end,
  },
}
