---@type ShadowsOfUI_HousingVendor
local ns = select(2, ...)

local GetItemInfoInstant = C_Item.GetItemInfoInstant

---@class HVDecorInfo
---@field recordID integer?      -- stable catalog key, carried through so consumers can cross-reference (e.g. Warbandeer_Decor's wanted list); nil only on a raw entry that lacks it
---@field owned boolean          -- owns at least one instance (in storage or placed)
---@field stored integer         -- instances on hand (in storage + redeemable), i.e. placeable
---@field total integer          -- instances owned anywhere (stored + placed)
---@field bonus integer          -- House XP granted the first time this decor is acquired
---@field bonusAvailable boolean -- a first-acquisition bonus is still claimable (bonus > 0 and unowned)

-- Normalize a HousingCatalogEntryInfo into the fields the overlay renders. Pure —
-- no WoW API — so it is unit-tested directly. Mirrors Blizzard_HousingCatalogUtil:
--   stored = totalNumStored + remainingRedeemable   (GetEntryNumStored)
--   total  = stored + totalNumPlaced                (GetEntryTotalOwned)
-- `bonusAvailable` gates the star on *unowned* decor so an owned item whose
-- firstAcquisitionBonus field hasn't zeroed out can't dangle a claimed bonus.
-- `recordID` is the entry's stable catalog key (non-nilable on the real struct);
-- carried through so a consumer can cross-reference the counts against a list keyed
-- on it — e.g. Warbandeer_Decor's wanted flags — which EntryFor previously couldn't.
---@param entry table? HousingCatalogEntryInfo
---@return HVDecorInfo?
function ns.NormalizeEntry(entry)
  if not entry then return nil end
  local stored = (entry.totalNumStored or 0) + (entry.remainingRedeemable or 0)
  local total = stored + (entry.totalNumPlaced or 0)
  local bonus = entry.firstAcquisitionBonus or 0
  return {
    recordID = entry.recordID,
    owned = total > 0,
    stored = stored,
    total = total,
    bonus = bonus,
    bonusAvailable = bonus > 0 and total == 0,
  }
end

local getInfo = C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem

-- Cheap, synchronous class/subclass gate: GetItemInfoInstant resolves from the
-- itemID alone (no server round-trip), so this never reads as a false negative.
local function isDecorItem(link)
  local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(link)
  return classID == Enum.ItemClass.Housing and subClassID == Enum.ItemHousingSubclass.Decor
end

-- Session cache keyed by link. A `false` entry means "not decor" — permanent,
-- since an item's class never changes. Decor entries are wiped on
-- HOUSING_STORAGE_UPDATED (owning/placing/redeeming changes the counts).
local cache = {}
function ns.WipeDecorCache() wipe(cache) end

-- Normalized decor info for an item link, or nil when the item isn't housing
-- decor or the catalog hasn't resolved it yet (primed lazily on login — an
-- unresolved decor item stays uncached so it retries once the catalog is ready).
---@param link string an item hyperlink or "item:<id>" string
---@return HVDecorInfo?
function ns.DecorEntryFor(link)
  if not (link and getInfo) then return nil end
  local hit = cache[link]
  if hit ~= nil then return hit or nil end
  if not isDecorItem(link) then
    cache[link] = false
    return nil
  end
  local norm = ns.NormalizeEntry(getInfo(link, true))
  if norm then cache[link] = norm end
  return norm
end

-- Expose the normalized decor lookup as the suite's single decor-detection source
-- (X-NUI-API `HousingDecorApi`). ShadowsOfUI-Collectibles reads `.owned` from it
-- instead of deriving owned-state from the catalog a second time. Guarded so the
-- busted loader (which seeds an empty `ns.api`) — and any run without the API
-- global — stays valid.
if ns.api then ns.api.EntryFor = ns.DecorEntryFor end
