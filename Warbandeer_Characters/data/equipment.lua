---@type Warbandeer_Characters
local ns = select(2, ...)
local Player = ns.wow.Player
local RequestLoadItemData = C_Item.RequestLoadItemData
local GetItemID = C_Item.GetItemID
local GetItemInfo, GetCurrentItemLevel = C_Item.GetItemInfo, C_Item.GetCurrentItemLevel
local GetItemUpgradeInfo = C_Item.GetItemUpgradeInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetItemStats = C_Item.GetItemStats
local GetInventoryItemLink = GetInventoryItemLink

-- Number of *empty* gem sockets on an item, from its stat table: an unfilled socket
-- shows up as an EMPTY_SOCKET_* key (PRISMATIC, META, …) whose value is the count; a
-- filled socket contributes its gem's stats instead, so it isn't counted. Needs the
-- item loaded (the broker only builds a slot once GetItemInfo resolves), so it's
-- captured here at scan time and persisted — making it readable warband-wide later.
local function emptySocketCount(link)
  local stats = GetItemStats(link)
  if not stats then return 0 end
  local n = 0
  for key, value in pairs(stats) do
    if key:find("EMPTY_SOCKET") then n = n + value end
  end
  return n
end

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

---@class Character
---@field equipment EquipmentBroker?

---@class EquipmentBroker: Broker
local Equipment = ns:RegisterBroker("equipment")

-- A just-equipped item's data isn't necessarily cached when PLAYER_EQUIPMENT_CHANGED
-- fires, so the scan can read nil for it.  We RequestLoadItemData and re-Update once
-- ITEM_DATA_LOAD_RESULT drains the pending set — but that event does NOT fire for an
-- item whose data is already cached (the common case: equipping straight from your
-- bags), which strands the pending set and leaves the cache showing the pre-swap gear
-- until the next /reload or refresh.  So we also schedule a bounded fallback re-scan;
-- whichever lands first refreshes the cache and a second Update is idempotent.  The
-- generation guard lets a newer equip event supersede an in-flight fallback.
local FALLBACK_DELAY = 800 -- ms; outlasts a typical item-data load
local MAX_FALLBACKS = 5
local fallbackGen = 0

-- True while any equipped slot still holds an item whose data hasn't loaded (so a
-- fresh scan would preserve the stale value rather than read the real one).
local function anyUnloaded()
  for _, index in pairs(EquipmentSlots) do
    local link = GetInventoryItemLink("player", index)
    if link and not GetItemInfo(link) then return true end
  end
  return false
end

local function scheduleFallback()
  fallbackGen = fallbackGen + 1
  local gen, attempt = fallbackGen, 0
  local function tick()
    if gen ~= fallbackGen then return end -- a newer equip event took over
    attempt = attempt + 1
    Equipment:Update(ns.currentData)
    if attempt < MAX_FALLBACKS and anyUnloaded() then
      ns:after(FALLBACK_DELAY, tick)
    end
  end
  ns:after(FALLBACK_DELAY, tick)
end

Equipment.fields = {
  ---@class EquipmentBroker
  ---@field slots any -- TODO
  slots = {
    get = function(_, _, currentValue)
      local existing = currentValue or {}
      local slots = {}
      for slot, index in pairs(EquipmentSlots) do
        local link = GetInventoryItemLink("player", index)
        if link then
          local name = GetItemInfo(link)
          if name then
            local ilvl = GetCurrentItemLevel({equipmentSlotIndex = index})
            local upgradeInfo = GetItemUpgradeInfo(link)
            -- equipLoc/classID/subClassID are synchronous (instant).
            local _, _, _, equipLoc, _, classID, subClassID = GetItemInfoInstant(link)
            slots[slot] = {
              name = name,
              link = link,
              ilvl = ilvl,
              track = upgradeInfo and upgradeInfo.trackString or nil,
              trackLevel = upgradeInfo and upgradeInfo.currentLevel or nil,
              equipLoc = equipLoc,
              classID = classID,
              subClassID = subClassID,
              emptySockets = emptySocketCount(link),
            }
          elseif existing[slot] then
            -- Item present but its data isn't loaded yet — keep the prior value
            -- rather than dropping the slot; a fallback re-scan refines it once
            -- loaded.  (An unequipped slot has no link and is correctly omitted.)
            slots[slot] = existing[slot]
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
        Equipment:Update(ns.currentData)
        return
      end
      local pending = {}
      for _, index in ipairs(toLoad) do
        local id = GetItemID({equipmentSlotIndex = index})
        if id then pending[id] = (pending[id] or 0) + 1 end
        RequestLoadItemData({equipmentSlotIndex = index})
      end
      ns.equipmentPending = pending
      -- ITEM_DATA_LOAD_RESULT may never fire for already-cached items, which would
      -- strand `pending`; schedule a bounded fallback so the scan lands regardless.
      scheduleFallback()
    end,
  },
  ---@class EquipmentBroker
  ---@field ilvl integer
  ilvl = {
    get = function()
      return Player:GetAverageItemLevel()
    end,
  },
  trackScanned = {
    get = function() return true end,
  },
}

---@class Warbandeer_Characters
---@field equipmentPending table

---@class Warbandeer_Characters
---@field ITEM_DATA_LOAD_RESULT fun(itemID)
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
      Equipment:Update(self.currentData)
    end
  end
end
ns:registerEvent("ITEM_DATA_LOAD_RESULT")
