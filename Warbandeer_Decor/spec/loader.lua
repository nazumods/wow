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

return M
