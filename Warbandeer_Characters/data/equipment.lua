local _, ns = ...
local Player = ns.wow.Player
local DoesItemExist =  C_Item.DoesItemExist -- luacheck: globals C_Item
local RequestLoadItemData = C_Item.RequestLoadItemData -- luacheck: globals C_Item
local GetItemID, GetItemInfo, GetCurrentItemLevel =  C_Item.GetItemID, C_Item.GetItemInfo, C_Item.GetCurrentItemLevel -- luacheck: globals C_Item

local EquipmentSlots = {
  Head = 1,
  Neck = 2,
  Shoulder = 3,
  -- Shirt = 4
  Chest = 5,
  Waist = 6,
  Legs = 7,
  Feet = 8,
  Wrist = 9,
  Hands = 10,
  Finger1 = 11,
  Finger2 = 12,
  Trinket1 = 13,
  Trinket2 = 14,
  Back = 15,
  MainHand = 16,
  OffHand = 17,
}

---@type Broker
ns.Equipment = ns:RegisterBroker("equipment")

ns.Equipment.fields = {
  slots = {
    get = function()
      local slots = {}
      for slot, index in pairs(EquipmentSlots) do
        if DoesItemExist({equipmentSlotIndex = index}) then
          local id = GetItemID({equipmentSlotIndex = index})
          if id then
            local name, link = GetItemInfo(id)
            if link then
              local ilvl = GetCurrentItemLevel({equipmentSlotIndex = index})
              slots[slot] = {name = name, link = link, ilvl = ilvl}
            end
          end
        end
      end
      return slots
    end,
    event = "PLAYER_EQUIPMENT_CHANGED",
    eventDelay = 500,
    eventHandler = function()
      ns.requests = 16
      for _, index in pairs(EquipmentSlots) do
        if DoesItemExist({equipmentSlotIndex = index}) then
          RequestLoadItemData({equipmentSlotIndex = index})
        end
      end
    end,
  },
  ilvl = {
    get = function()
      return Player:GetAverageItemLevel()
    end,
  },
}

function ns:ITEM_DATA_LOAD_RESULT()
  if not self.requests then return end
  self.requests = self.requests - 1
  if self.requests == 0 then
    self.Equipment:Update(self.currentData) -- updates all fields
  end
end
ns:registerEvent("ITEM_DATA_LOAD_RESULT")
