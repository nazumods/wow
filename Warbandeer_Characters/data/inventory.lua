---@type Warbandeer_Characters
local ns = select(2, ...)
local C_Container = C_Container
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo

-- Container IDs read by C_Container: backpack (0), the four equipped bags
-- (1..NUM_BAG_SLOTS) and the reagent bag (NUM_BAG_SLOTS+1). Summed into an
-- itemID -> total-count map so the warband-stock tooltip can tell you how many
-- of an item every character is carrying. Last-seen per character (the map is
-- only refreshable while that character is logged in).
local LAST_BAG = (NUM_BAG_SLOTS or 4) + 1

---@class InventoryBroker: Broker
local Inventory = ns:RegisterBroker("inventory")

Inventory.fields = {
  counts = {
    event = "BAG_UPDATE_DELAYED",
    eventDelay = 500,
    get = function()
      local counts = {}
      for bag = 0, LAST_BAG do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
          local info = GetContainerItemInfo(bag, slot)
          if info and info.itemID then
            counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
          end
        end
      end
      return counts
    end,
  },
}
