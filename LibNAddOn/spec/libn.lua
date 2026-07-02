-- Loads LibNAddOn's pure-Lua modules into a fresh namespace table, passing
-- the same (addonName, ns) vararg WoW passes to each addon file. Specs call
-- libn.load() to get an isolated ns per test. Paths are relative to the
-- AddOns root, where busted runs.
--
-- Only WoW-API-free files belong here; anything touching C_* or frames
-- stays in-game-tested.

local libn = {}

-- Mirrors the load order of LibNAddOn.toc (maps must precede class:
-- class.lua reads ns.lua.maps.merge at load time).
local FILES = {
  "lua/lua.lua",
  "lua/strings.lua",
  "lua/lists.lua",
  "lua/maps.lua",
  "lua/sets.lua",
  "lua/class.lua",
}

-- WoW global used by class.lua: shallow-copies each source into the target.
local function Mixin(target, ...)
  for i = 1, select("#", ...) do
    for k, v in pairs(select(i, ...)) do
      target[k] = v
    end
  end
  return target
end

---@return table ns a fresh LibNAddOn namespace with ns.lua.* populated
function libn.load()
  _G.Mixin = _G.Mixin or Mixin
  local ns = {}
  for _, f in ipairs(FILES) do
    assert(loadfile("LibNAddOn/" .. f))("LibNAddOn", ns)
  end
  return ns
end

return libn
