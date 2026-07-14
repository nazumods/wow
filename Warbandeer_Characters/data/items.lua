---@type Warbandeer_Characters
local ns = select(2, ...)
local BagID = ns.wow.Player.bags.ItemID
local Find = ns.lua.lists.find
local GetNumSlots = ns.wow.Items.GetNumSlots

local SpecialItems = {
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

---@class ItemsBroker: Broker
local Items = ns:RegisterBroker("items")

local LAST_BAG_IDX = NUM_BAG_SLOTS + 1
Items.fields = {
  bags = {
    missing = false,
    get = function()
      local bags = {}
      for i = 1, LAST_BAG_IDX do
        local id = BagID(i)
        bags[i] = { id = id, slots = GetNumSlots(i) }
      end
      for name,i in pairs(SpecialItems) do
        bags[name] = Find(bags, function(b) return b.id == i.id end)
      end
      return bags
    end,
  },
  reagentBag = {
    missing = false,
    get = function()
      return { id = BagID(LAST_BAG_IDX), slots = GetNumSlots(LAST_BAG_IDX)}
    end,
  },
}
