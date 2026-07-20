---@class Warbandeer_HousingDecor
---@field _entries HousingDecorEntry[]  live decor snapshot (rebuilt each Scan; never persisted)
---@field _categoryName table<number, string>  categoryID -> localized name (filter dropdown)
---@field _subcategoryName table<number, string>  subcategoryID -> localized name (filter dropdown)
---@field _searcher table?  the persistent HousingCatalogSearcher (nil pre-housing)
local ns = select(2, ...)

local C_HousingCatalog, Enum = C_HousingCatalog, Enum

---One scanned decor entry: identity + presentation + normalized owned/bonus state.
---@class HousingDecorEntry
---@field recordID number         stable catalog key (the analog of Collected's setId)
---@field name string             display name
---@field iconTexture number|string?  file icon (mutually exclusive with iconAtlas)
---@field iconAtlas string?        atlas icon (mutually exclusive with iconTexture)
---@field quality number?          ItemQuality (colors the name + icon border)
---@field categoryIDs number[]?    catalog categories this entry belongs to
---@field subcategoryIDs number[]? catalog subcategories this entry belongs to
---@field sourceText string?       "where to get it" blurb (InfoTip)
---@field owned boolean
---@field stored integer
---@field total integer
---@field bonus integer
---@field bonusAvailable boolean

-- The live snapshot. Rebuilt from scratch every Scan and never written to the DB: the
-- catalog is fully enumerable from the client, so a saved copy could only go stale.
ns._entries = {}
ns._categoryName = {}
ns._subcategoryName = {}

-- Resolve + cache a category / subcategory's localized name once. Names are static
-- reference data, so cache only successful resolutions and retry a miss on the next
-- scan (the catalog may still be loading on the first pass).
local function ensureCatName(id)
  if ns._categoryName[id] then return end
  local info = C_HousingCatalog.GetCatalogCategoryInfo(id)
  if info and info.name then ns._categoryName[id] = info.name end
end
local function ensureSubName(id)
  if ns._subcategoryName[id] then return end
  local info = C_HousingCatalog.GetCatalogSubcategoryInfo(id)
  if info and info.name then ns._subcategoryName[id] = info.name end
end

---Rebuild the live decor snapshot from the housing catalog: enumerate every entry
---variant via the searcher, collapse to unique decor recordIDs, resolve each to its
---owned/bonus state + category tags, and cache the category names the filters need.
---Recomputes the account-wide collected/total tallies, refreshes the open window, and
---fires scan subscribers. Clears to empty (no error) when the catalog API is absent (a
---pre-housing client) or the searcher hasn't primed yet — the storage events re-run it.
function ns:Scan()
  local entries = {}
  if C_HousingCatalog and ns._searcher then
    -- Read the results of the last RunSearch (populated asynchronously). With no native
    -- filter set on the searcher this is the full catalog; we filter in Lua (GetItems).
    local ids = ns.DedupeVariants(ns._searcher:GetCatalogSearchResults())
    for _, recordID in ipairs(ids) do
      local raw = C_HousingCatalog.GetCatalogEntryInfoByRecordID(
        Enum.HousingCatalogEntryType.Decor, recordID, true)
      if raw then
        local info = ns.NormalizeEntry(raw)
        entries[#entries + 1] = {
          recordID = recordID,
          name = raw.name or ("Decor " .. recordID),
          iconTexture = raw.iconTexture,
          iconAtlas = raw.iconAtlas,
          quality = raw.quality,
          categoryIDs = raw.categoryIDs,
          subcategoryIDs = raw.subcategoryIDs,
          sourceText = raw.sourceText,
          owned = info.owned,
          stored = info.stored,
          total = info.total,
          bonus = info.bonus,
          bonusAvailable = info.bonusAvailable,
        }
        if raw.categoryIDs then for _, c in ipairs(raw.categoryIDs) do ensureCatName(c) end end
        if raw.subcategoryIDs then for _, s in ipairs(raw.subcategoryIDs) do ensureSubName(s) end end
      end
    end
  end
  ns._entries = entries

  local collected = 0
  for _, e in ipairs(entries) do if e.owned then collected = collected + 1 end end
  self.db.collected = collected
  self.db.total = #entries

  if ns.window then ns.window:Refresh() end
  -- Notify consumers (Warbandeer's embedded decor view) now the snapshot is fresh, so
  -- both grids stay in sync (see api.lua OnScanned).
  if ns._scanned then
    for _, fn in ipairs(ns._scanned) do fn() end
  end
end

-- Debounced re-scan. The housing events fire in bursts (login, entering a house), and
-- ns:delay keeps only one pending timer per addon, so repeated calls coalesce into a
-- single Scan once the burst settles.
local function scanSoon()
  ns:delay(300, function() ns:Scan() end)
end

-- (Re-)run the catalog search. The searcher's result set is only populated once a search
-- has run — mirrors Blizzard's HousingDashboardCatalog, which `RunSearch()`es (on login
-- and on HOUSING_STORAGE_UPDATED) and reads `GetCatalogSearchResults()`. Results arrive
-- asynchronously via the ResultsUpdatedCallback wired in onLogin, which drives the scan.
local function runSearch()
  if ns._searcher then ns._searcher:RunSearch() end
end

-- Prime the searcher on login: create it, point its results callback at a debounced scan,
-- and kick the first search so the catalog loads without the player having to open
-- Blizzard's own housing panel first.
function ns:onLogin()
  if not (C_HousingCatalog and C_HousingCatalog.CreateCatalogSearcher) then return end
  ns._searcher = C_HousingCatalog.CreateCatalogSearcher()
  ns._searcher:SetResultsUpdatedCallback(scanSoon)
  runSearch()
end

-- Owned counts (and the catalog contents) change on several signals, so on each one both
-- re-run the search (the callback picks up newly-acquired / removed decor) and directly
-- re-scan (owned counts are re-queried per recordID, so they refresh even when the entry
-- set is unchanged): buying / placing / redeeming decor (HOUSING_STORAGE_UPDATED + its
-- per-entry sibling) and learning a brand-new decor (NEW_HOUSING_ITEM_ACQUIRED).
local function refresh()
  runSearch()
  scanSoon()
end
for _, event in ipairs({
  "HOUSING_STORAGE_UPDATED",
  "HOUSING_STORAGE_ENTRY_UPDATED",
  "NEW_HOUSING_ITEM_ACQUIRED",
}) do
  ns:registerEvent(event, refresh)
end
