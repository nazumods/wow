---@type Warbandeer_Characters
local ns = select(2, ...)
---@type WarbandeerAPI
local API = ns.api
local insert = table.insert
local C_Container = C_Container
local GetCurrentItemLevel = C_Item.GetCurrentItemLevel
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
          -- reads hundreds of levels too high and fakes a massive upgrade.
          insert(items, {
            link = link,
            itemID = info.itemID,
            ilvl = GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot)),
            equipLoc = equipLoc,
            classID = classID,
            subClassID = subClassID,
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
