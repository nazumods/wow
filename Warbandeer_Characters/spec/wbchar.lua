-- Loads Warbandeer_Characters' WoW-API-free modules into a fresh namespace, passing the
-- same (addonName, ns) vararg WoW passes each addon file. Specs call wbchar.load() to get an
-- isolated ns per test. Only files that LOAD without the WoW API belong here; the appearance-glyph
-- catalog (data/glyphinfo.lua) is data tables + the pure ns.MergeGlyphStatus helper, so it
-- loads standalone, and data/titlecatalog.lua's client scan is upvalued at load but only called
-- in game. data/classcollectibles.lua is the same shape — its scan reaches C_QuestLog /
-- C_MountJournal only from inside the function bodies, so the file loads with no WoW API present.
-- Paths are relative to the AddOns root, where busted runs.

local M = {}

-- Pure files this addon exposes for unit testing (extend as more pure logic is added).
local FILES = {
  "data/glyphinfo.lua",
  "data/classmounts.lua",
  "data/learnedunlocks.lua",
  "data/challengetames.lua",
  "data/professionknowledge.lua",
  "data/vaultslots.lua",
  "data/housinginfo.lua",
  "data/titlecatalog.lua",
  "data/classcollectibles.lua",
}

---@return table ns  a fresh namespace with the pure modules loaded
function M.load()
  local ns = {}
  -- data/classmounts.lua registers its `/wbc dump mounts` probe at load. The probe body (the only
  -- WoW-API user in the file) never runs under test, so a no-op registerDump lets the pure catalog
  -- load without the addon core — same idea as libn.lua stubbing Mixin.
  ns.registerDump = function() end
  -- data/professionknowledge.lua registers its broker at load; the broker's get (the file's only
  -- WoW-API user) never runs under test, so a stub RegisterBroker returning a bare object lets the
  -- pure catalog + summariser load without the addon core.
  ns.RegisterBroker = function() return {} end
  -- data/housinginfo.lua (and the other feature-gated files) ask `ns:Supports` at load; this harness plays a client
  -- where everything is supported, so the pure shapers load. spec/forever_gating_spec.lua drives the unsupported side.
  ns.Supports = function() return true end
  for _, f in ipairs(FILES) do
    assert(loadfile("Warbandeer_Characters/" .. f))("Warbandeer_Characters", ns)
  end
  return ns
end

return M
