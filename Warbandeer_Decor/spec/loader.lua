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

---Load list.lua against a recording widget fake, so the windowed-row maths (`_window`) and the
---filters (`GetItems`) can be driven without LibNUI. `ns.lua.Class` is stubbed to return the bare
---class table (methods land on it; the constructor never runs), and the LibNUI widget classes to
---a `:new{}` that returns a recording frame: `shown`, `points`, `height` and the text/colour
---setters are no-ops. Returns the class, the namespace, and a `newList(opts)` factory that builds
---a bare instance carrying only the fields `_window` / `GetItems` read.
---@return table List, table ns, fun(opts: table): table newList
function M.loadList()
  _G.ITEM_QUALITY_COLORS = {}
  _G.IsShiftKeyDown = function() return false end
  _G.WarbandeerHousingDecorApi = {}

  local function widget()
    local w = { points = {}, shown = false }
    w._widget = setmetatable({}, { __index = function() return function() end end })
    return setmetatable(w, { __index = function(t, k)
      if k == "Show" then return function(self) self.shown = true end end
      if k == "Hide" then return function(self) self.shown = false end end
      if k == "ClearAllPoints" then return function(self) self.points = {} end end
      if k == "SetPoint" then return function(self, ...) self.points[#self.points + 1] = { ... } end end
      if k == "Height" then return function(self, h) if h then self.height = h end return self.height end end
      return function() end
    end })
  end
  local function widgetClass() return { new = function() return widget() end } end

  local wanted = {}
  local ns = {
    ui = {
      Frame = widgetClass(), Label = widgetClass(), Texture = widgetClass(), ScrollFrame = widgetClass(),
      layer = {}, edge = {}, justify = {},
    },
    lua = { Class = function() return {} end },
    _entries = {},
    wanted = wanted,
  }
  function ns:IsWanted(id) return wanted[id] == true end
  assert(loadfile("Warbandeer_Decor/list.lua"))("Warbandeer_Decor", ns)
  local List = ns.List

  local function newList(opts)
    local self = {
      _rows = {}, _shown = opts.shown or {}, _content = widget(),
      _category = "all", _subcategory = "all", _uncollected = false, _wantedOnly = false, _search = "",
      scroll = {
        Height = function() return opts.viewH end,
        VerticalScroll = function() return opts.offset end,
      },
      Height = function() return opts.selfH end,
    }
    for k, v in pairs(opts.filters or {}) do self[k] = v end
    return self
  end
  return List, ns, newList
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
