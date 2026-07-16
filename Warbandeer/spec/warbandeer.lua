-- Loads Warbandeer's WoW-API-free view modules into a fresh namespace, passing the same
-- (addonName, ns) vararg WoW passes each addon file. Specs call warbandeer.load() to get an
-- isolated ns per test. Only pure files belong here — views/titles/TitlesCompute.lua is the
-- earned/unearned/earnable categoriser (ns.ComputeTitles), with no C_*/frame use, so it loads
-- standalone (the client + Epithet reads are the impure shell in views/titles/TitlesData.lua,
-- which is not loaded here). Paths are relative to the AddOns root, where busted runs.

local M = {}

-- Pure files this addon exposes for unit testing (extend as more pure logic is added).
local FILES = {
  "views/titles/TitlesCompute.lua",
}

---@return table ns  a fresh namespace with the pure modules loaded
function M.load()
  local ns = {}
  for _, f in ipairs(FILES) do
    assert(loadfile("Warbandeer/" .. f))("Warbandeer", ns)
  end
  return ns
end

return M
