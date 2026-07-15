-- Test harness: loads the pure Warbandeer_HousingDecor modules into a fresh ns with a
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
  assert(loadfile("Warbandeer_HousingDecor/catalog.lua"))("Warbandeer_HousingDecor", ns)
  assert(loadfile("Warbandeer_HousingDecor/ratings.lua"))("Warbandeer_HousingDecor", ns)
  return ns
end

return M
