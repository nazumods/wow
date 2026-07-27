---@type Warbandeer_Decor
local ns = select(2, ...)

-- Pure, WoW-API-free catalog helpers (busted-specced in spec/). Everything that
-- actually touches C_HousingCatalog lives in scan.lua; keeping the count math and
-- the variant de-dupe pure lets them be unit-tested with literal tables.

---@class HousingDecorInfo
---@field owned boolean          owned anywhere (storage, unredeemed, or placed)
---@field stored integer         on-hand instances (storage + unredeemed)
---@field total integer          owned anywhere (stored + placed)
---@field bonus integer          House XP granted on first-time acquisition
---@field bonusAvailable boolean bonus is still claimable (a bonus exists AND you own none)

-- Re-open the class to declare the pure helpers this file hangs on the namespace.
---@class Warbandeer_Decor
---@field NormalizeEntry fun(entry: table?): HousingDecorInfo?
---@field DedupeVariants fun(variants: table[]?): number[]

---Reduce a raw HousingCatalogEntryInfo to the owned/bonus flags the list renders.
---Mirrors ShadowsOfUI-HousingVendor's NormalizeEntry: `stored` counts on-hand
---(storage + not-yet-redeemed auto-awards), `total` adds placed instances, and the
---first-acquisition bonus is only "available" while you own none (so an un-zeroed
---bonus field on already-owned decor can't dangle a claimed bonus). Every count is
---`or 0`-guarded, so a partial entry (missing numerics) normalizes cleanly.
---@param entry table?  HousingCatalogEntryInfo
---@return HousingDecorInfo?
function ns.NormalizeEntry(entry)
  if not entry then return nil end
  local stored = (entry.totalNumStored or 0) + (entry.remainingRedeemable or 0)
  local total = stored + (entry.totalNumPlaced or 0)
  local bonus = entry.firstAcquisitionBonus or 0
  return {
    owned = total > 0,
    stored = stored,
    total = total,
    bonus = bonus,
    bonusAvailable = bonus > 0 and total == 0,
  }
end

---Collapse the searcher's variant descriptors into a de-duplicated list of decor
---recordIDs. `GetCatalogSearchResults()` returns one HousingCatalogEntryVariantID per
---variant (dye recolors share a recordID) and interleaves decor with room entries,
---so filter to `entryType == Decor` and keep one recordID each, in first-seen order
---(the searcher's own order, which the game presents sensibly).
---@param variants table[]?  list of { entryType, recordID } variant descriptors
---@return number[] recordIDs  unique decor recordIDs, first-seen order
function ns.DedupeVariants(variants)
  local out, seen = {}, {}
  if not variants then return out end
  local decor = Enum.HousingCatalogEntryType.Decor
  for _, v in ipairs(variants) do
    if v.entryType == decor and v.recordID and not seen[v.recordID] then
      seen[v.recordID] = true
      out[#out + 1] = v.recordID
    end
  end
  return out
end
