---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api
local insert = table.insert
local C_Container = C_Container
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local GetItemInfo = C_Item.GetItemInfo
local ItemLocation = ItemLocation

-- Per-character cache of equippable gear sitting in the character's bags, so
-- consumers can tell which loose items would upgrade a
-- slot. Last-seen model like the rest of the addon: rescanned on BAG_UPDATE_DELAYED
-- for the active character only. We keep only armour/weapons with a real equip
-- slot (API:ClassifyGearItem), which makes the list tiny. The matching "held in
-- the bank" gear lives in data/bank.lua (db.bank.*.equip); this broker is bags only.

---@class GearCandidate
---@field link string item hyperlink
---@field itemID integer
---@field ilvl integer? effective (context-scaled) item level, matching equipped slots (nil → recompute from link)
---@field equipLoc string INVTYPE_* the item fills
---@field classID integer Enum.ItemClass (Armor|Weapon)
---@field subClassID integer armour type / weapon subclass
---@field quality integer? Enum.ItemQuality, captured at scan time so the artifact gate works on cold/offline items (nil for entries cached before v17)
---@field reqLevel integer? required character level, captured at scan time (item warm) so the level gate reads consistently for cold/offline alts (nil for entries cached before v18)

---Scan the active character's bags for equippable gear.
---@return GearCandidate[]
local function scanBags()
  local items = {}
  -- Backpack (0) through the carried bags (NUM_BAG_SLOTS); the reagent bag holds no gear.
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID then
        -- Cheap instant class/subclass filter before any other call (~150 slots).
        local equipLoc, classID, subClassID = API:ClassifyGearItem(info.itemID)
        if equipLoc then
          local link = info.hyperlink
          -- Effective (context-scaled) ilvl via the bag location, NOT the link's
          -- unscaled GetDetailedItemLevelInfo: equipped slots are measured with
          -- GetCurrentItemLevel, so a candidate must use the same basis or an item
          -- downscaled in Chromie Time / a scaled zone (true ilvl 655 shown as 102)
          -- reads hundreds of levels too high and fakes a massive upgrade. Fall back to
          -- the link's ilvl only when the item is cold (GetCurrentItemLevel nil) so the
          -- candidate still ranks instead of being dropped (the scaled value refreshes on
          -- the next BAG_UPDATE_DELAYED once it loads).
          local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
          insert(items, {
            link = link,
            itemID = info.itemID,
            ilvl = GetCurrentItemLevel(loc) or (link and GetDetailedItemLevelInfo(link)) or nil,
            equipLoc = equipLoc,
            classID = classID,
            subClassID = subClassID,
            -- Captured now (item warm), so the upgrade finder's artifact gate fires for
            -- this candidate even when later read for an offline alt with the item cold.
            quality = info.quality,
            -- Required level is a static per-item property; captured warm here so a
            -- consumer's "can equip now?" gate doesn't depend on a live (cold) lookup
            -- when the candidate is read for an offline alt or just after a reload.
            reqLevel = link and (select(5, GetItemInfo(link))) or nil,
          })
        end
      end
    end
  end
  return items
end

---@class Character
---@field gearbag { items: GearCandidate[] }?

---@class GearBag: Broker
ns.GearBag = ns:RegisterBroker("gearbag")

ns.GearBag.fields = {
  ---@type BrokerField
  items = {
    get = scanBags,
    event = "BAG_UPDATE_DELAYED",
    eventDelay = 500,
  },
}
