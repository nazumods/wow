-- Test harness: loads the pure Warbandeer_Decor modules into a fresh ns with a
-- minimal WoW stub, so the count/de-dupe logic (catalog.lua) and the wanted model
-- (ratings.lua) can be unit-tested without the game client. Mirrors HousingVendor's
-- spec/hvendor.lua. Paths are relative to the AddOns root (busted's cwd).
local M = {}

---Load catalog.lua + ratings.lua into a fresh ns and return it.
---@return table ns
function M.load()
  -- Only DedupeVariants touches a WoW global (the entry-type enum); stub it minimally.
  _G.Enum = { HousingCatalogEntryType = { Invalid = 0, Decor = 1, Room = 2 } }

  local ns = { db = { wanted = {} } }
  assert(loadfile("Warbandeer_Decor/catalog.lua"))("Warbandeer_Decor", ns)
  assert(loadfile("Warbandeer_Decor/ratings.lua"))("Warbandeer_Decor", ns)
  return ns
end

---Load the same modules plus scan.lua, so `ns:Scan()` can be driven against a fake
---catalog. scan.lua captures `C_HousingCatalog` as an upvalue and registers its housing
---events at file scope, so both the stub and `ns:registerEvent` must exist before the
---load. Returns the namespace and the record table `ns:Scan()` resolves recordIDs
---through -- `ns._searcher` starts nil, i.e. a cold session whose catalog hasn't primed.
---@param db table?  starting DB (defaults to an empty one); `ns:Scan()` writes its tallies here
---@return table ns, table<number, table> records  recordID -> raw HousingCatalogEntryInfo
function M.loadScan(db)
  _G.Enum = { HousingCatalogEntryType = { Invalid = 0, Decor = 1, Room = 2 } }

  local records = {}
  _G.C_HousingCatalog = {
    GetCatalogEntryInfoByRecordID = function(_, recordID) return records[recordID] end,
    GetCatalogCategoryInfo = function(id) return { name = "Category " .. id } end,
    GetCatalogSubcategoryInfo = function(id) return { name = "Subcategory " .. id } end,
  }

  local ns = { db = db or { wanted = {} } }
  function ns:registerEvent() end     -- scan.lua registers its housing events at load
  function ns:delay(_, fn) fn() end   -- run the debounced re-scan inline
  assert(loadfile("Warbandeer_Decor/catalog.lua"))("Warbandeer_Decor", ns)
  assert(loadfile("Warbandeer_Decor/ratings.lua"))("Warbandeer_Decor", ns)
  assert(loadfile("Warbandeer_Decor/scan.lua"))("Warbandeer_Decor", ns)
  return ns, records
end

---Give `ns` a searcher returning `variants`, so the next `ns:Scan()` sees a primed catalog.
---@param ns table
---@param variants table[]  `{ entryType, recordID }` descriptors, as the real searcher returns
function M.prime(ns, variants)
  ns._searcher = {
    GetCatalogSearchResults = function() return variants end,
    RunSearch = function() end,
  }
end

return M
