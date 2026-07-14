-- Loads Warbandeer_Characters' WoW-API-free modules into a fresh namespace, passing the
-- same (addonName, ns) vararg WoW passes each addon file. Specs call wbchar.load() to get an
-- isolated ns per test. Only pure files (no C_*/frames) belong here; the appearance-glyph
-- catalog (data/glyphinfo.lua) is data tables + the pure ns.MergeGlyphStatus helper, so it
-- loads standalone. Paths are relative to the AddOns root, where busted runs.

local M = {}

-- Pure files this addon exposes for unit testing (extend as more pure logic is added).
local FILES = {
  "data/glyphinfo.lua",
  "data/learnedunlocks.lua",
  "data/challengetames.lua",
}

---@return table ns  a fresh namespace with the pure modules loaded
function M.load()
  local ns = {}
  for _, f in ipairs(FILES) do
    assert(loadfile("Warbandeer_Characters/" .. f))("Warbandeer_Characters", ns)
  end
  return ns
end

return M
