---@class LibNAddOn
local ns = select(2, ...)

---@class AddOn
---@field db AddOnDatabase database table
---@field MigrateDB fun(self) optional function to migrate the database when version changes

---@class AddOnDatabase
---@field version string|number version number of the database, used for migration

---@class LibNAddOn
---@field setupDB fun(addOnName: string, addOn: AddOn, ops: table) set up a database for an add-on
function ns.setupDB(addOnName, addOn, ops)
  local dbName = ops.name
  local version = ops.version or (ops.defaults and ops.defaults.version)

  addOn:registerEvent("ADDON_LOADED", function(self, name)
    if name ~= addOnName then return end

    -- initialize db
    if not _G[dbName] then
      _G[dbName] = {}
    end

    -- link to addOn
    self.db = _G[dbName]
    -- migrate if needed
    if version and self.MigrateDB and tonumber(version) ~= tonumber(self.db.version) then
      self:MigrateDB()
    end
  end, 1) -- run before addOn.onLoad
end
