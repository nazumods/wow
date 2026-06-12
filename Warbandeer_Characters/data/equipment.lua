---@type Warbandeer_Characters
local ns = select(2, ...)
local Player = ns.wow.Player
local RequestLoadItemData = C_Item.RequestLoadItemData -- luacheck: globals C_Item
local GetItemID = C_Item.GetItemID
local GetItemInfo, GetCurrentItemLevel = C_Item.GetItemInfo, C_Item.GetCurrentItemLevel -- luacheck: globals C_Item
local GetItemUpgradeInfo = C_Item.GetItemUpgradeInfo
local GetInventoryItemLink = GetInventoryItemLink -- luacheck: globals GetInventoryItemLink

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
        local link = GetInventoryItemLink("player", index)
        if link then
          local name = GetItemInfo(link)
          if name then
            local ilvl = GetCurrentItemLevel({equipmentSlotIndex = index})
            local upgradeInfo = GetItemUpgradeInfo(link)
            slots[slot] = {
              name = name,
              link = link,
              ilvl = ilvl,
              track = upgradeInfo and upgradeInfo.trackString or nil,
              trackLevel = upgradeInfo and upgradeInfo.currentLevel or nil,
            }
          end
        end
      end
      return slots
    end,
    event = "PLAYER_EQUIPMENT_CHANGED",
    eventDelay = 500,
    eventHandler = function()
      local toLoad = {}
      for _, index in pairs(EquipmentSlots) do
        local link = GetInventoryItemLink("player", index)
        if link then toLoad[#toLoad + 1] = index end
      end
      if #toLoad == 0 then
        ns.Equipment:Update(ns.currentData)
        return
      end
      local pending = {}
      for _, index in ipairs(toLoad) do
        local id = GetItemID({equipmentSlotIndex = index})
        if id then pending[id] = (pending[id] or 0) + 1 end
        RequestLoadItemData({equipmentSlotIndex = index})
      end
      ns.equipmentPending = pending
    end,
  },
  ilvl = {
    get = function()
      return Player:GetAverageItemLevel()
    end,
  },
  trackScanned = {
    get = function() return true end,
  },
}

function ns:ITEM_DATA_LOAD_RESULT(itemID)
  if not self.equipmentPending then return end
  local n = self.equipmentPending[itemID]
  if not n then return end
  if n > 1 then
    self.equipmentPending[itemID] = n - 1
  else
    self.equipmentPending[itemID] = nil
    if not next(self.equipmentPending) then
      self.equipmentPending = nil
      self.Equipment:Update(self.currentData)
    end
  end
end
ns:registerEvent("ITEM_DATA_LOAD_RESULT")
