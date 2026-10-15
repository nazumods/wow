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

-- ---------------------------------------------------------------------------------------------
-- Flavored loads of the REAL view/column files (spec/forever_views_spec.lua).
--
-- The files under views/ build frames through LibNUI, which busted does not have, so these loads
-- use an "anything" stub for every UI/WoW name a file reaches for at load time, while the parts
-- the specs assert on are real: LibNAddOn's own flavor.lua (so `ns:Supports` is the real feature
-- table for the flavor under test, loaded through LibNAddOn/spec/libn.lua), its lists/maps
-- helpers, and the real Warbandeer source files. Nothing here proves a frame renders; it proves
-- which views/columns REGISTER and which reads survive absent data.
-- ---------------------------------------------------------------------------------------------

local libn = require("LibNAddOn.spec.libn")

-- A value that is whatever a file wants it to be: any field is another one, any call returns
-- one, arithmetic gives 0, concatenation "". ipairs/pairs over it are empty (rawget semantics).
local function anything()
  local mt = {}
  local function number() return 0 end
  mt.__index = function() return anything() end
  mt.__call = function() return anything() end
  mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__mod, mt.__pow, mt.__unm = number, number, number, number, number, number, number
  mt.__concat = function() return "" end
  mt.__lt = function() return false end
  mt.__le = function() return false end
  mt.__tostring = function() return "<anything>" end
  return setmetatable({}, mt)
end
M.anything = anything

-- Stand-in for ns.lua.Class: records the constructor and options; `new{...}` hands back its own
-- options table (so a SummaryColumn:new{key = ...} spec stays inspectable), or a stub with none.
local function stubClass(_, ctor, opts)
  return { __ctor = ctor, __opts = opts, new = function(_, o) return o or anything() end }
end

-- WoW globals the loaded files read at load time; set for the duration of one load.
local LOAD_GLOBALS = { "C_Item", "C_CurrencyInfo", "C_ClassColor", "C_PlayerInfo", "BreakUpLargeNumbers",
  "DARKYELLOW_FONT_COLOR", "DIM_GREEN_FONT_COLOR", "DIM_RED_FONT_COLOR" }

---Load real Warbandeer files into a namespace for `flavor` ("retail"|"forever").
---`files` are paths under Warbandeer/. `opts.globals` adds WoW globals for the load (and the later
---calls the spec makes: they stay set until M.restoreGlobals()); `opts.ns` seeds extra namespace fields.
---@param flavor "retail"|"forever"
---@param files string[]
---@param opts { globals: table?, ns: table? }?
---@return table ns
function M.loadFlavored(flavor, files, opts)
  opts = opts or {}
  local lns = libn.load({ flavor = flavor })
  local lua = setmetatable({ Class = stubClass }, { __index = lns.lua })
  local ns = setmetatable({ views = {}, lua = lua, SummaryColumns = {} },
    { __index = function() return anything() end })
  lns.linkFlavor(ns)
  ns.SummaryColumn = { new = function(_, o) return o end }
  for k, v in pairs(opts.ns or {}) do ns[k] = v end

  M._saved = M._saved or {}
  local function setGlobal(k, v)
    if M._saved[k] == nil then M._saved[k] = { value = _G[k] } end
    _G[k] = v
  end
  for _, k in ipairs(LOAD_GLOBALS) do setGlobal(k, anything()) end
  setGlobal("LibNAddOn", function() return ns end)
  for k, v in pairs(opts.globals or {}) do setGlobal(k, v) end

  for _, f in ipairs(files) do
    assert(loadfile("Warbandeer/" .. f))("Warbandeer", ns)
  end
  return ns
end

---Undo every global M.loadFlavored set (call from after_each).
function M.restoreGlobals()
  for k, saved in pairs(M._saved or {}) do _G[k] = saved.value end
  M._saved = nil
end

return M
