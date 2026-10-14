-- Loads LibNAddOn's pure-Lua modules into a fresh namespace table, passing
-- the same (addonName, ns) vararg WoW passes to each addon file. Specs call
-- libn.load() to get an isolated ns per test. Paths are relative to the
-- AddOns root, where busted runs.
--
-- Only WoW-API-free files belong here; anything touching C_* or frames
-- stays in-game-tested. The one deliberate exception is flavor.lua, which reads
-- WOW_PROJECT_* and C_AddOns but only if they exist (libn.load below controls the former).

local libn = {}

-- Mirrors the load order of LibNAddOn.toc (maps must precede class:
-- class.lua reads ns.lua.maps.merge at load time).
local FILES = {
  "lua/lua.lua",
  "lua/strings.lua",
  "lua/signal.lua",
  "lua/lists.lua",
  "lua/maps.lua",
  "lua/sets.lua",
  "lua/class.lua",
  "flavor.lua",   -- nil-safe: detection reads WOW_PROJECT_* / C_AddOns only if present
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

-- The client's WOW_PROJECT_CAMELOT / WOW_PROJECT_ID, as flavor.lua reads them at load time.
local CAMELOT = 18

---Load LibNAddOn's pure-Lua modules into a fresh namespace.
---`opts.flavor` picks the client flavor flavor.lua detects while loading: nil or "retail" loads
---as Retail (neither constant defined), "forever" as Forever (WOW_PROJECT_ID = WOW_PROJECT_CAMELOT).
---The two WOW_PROJECT_* globals are set only for the duration of the load and restored after,
---so one spec's flavor never leaks into another's. This lets an addon's specs run as both flavors.
---A malformed call (options that aren't a table, an unknown option key, an unknown flavor) errors
---rather than silently loading as Retail, which would let a spec believe it ran as Forever.
---@param opts { flavor: ("retail"|"forever")? }?
---@return table ns a fresh LibNAddOn namespace with ns.lua.* populated
function libn.load(opts)
  assert(opts == nil or type(opts) == "table", "libn.load: options must be a table, got " .. type(opts))
  for key in pairs(opts or {}) do
    assert(key == "flavor", "libn.load: unknown option " .. tostring(key))
  end
  local flavor = opts and opts.flavor
  assert(flavor == nil or flavor == "retail" or flavor == "forever", "libn.load: unknown flavor " .. tostring(flavor))
  _G.Mixin = _G.Mixin or Mixin
  local ns = {}
  local prevId, prevCamelot = _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT
  _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = nil, nil
  if flavor == "forever" then _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = CAMELOT, CAMELOT end
  local ok, err = pcall(function()
    for _, f in ipairs(FILES) do
      assert(loadfile("LibNAddOn/" .. f))("LibNAddOn", ns)
    end
  end)
  _G.WOW_PROJECT_ID, _G.WOW_PROJECT_CAMELOT = prevId, prevCamelot
  if not ok then error(err, 0) end
  return ns
end

return libn
