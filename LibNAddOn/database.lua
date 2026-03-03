local _, ns = ...

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
    addOn.db = _G[dbName]
    -- migrate if needed
    if version and addOn.MigrateDB and version ~= addOn.db.version then
      addOn:MigrateDB()
    end
  end, 1) -- run before addOn.onLoad
end
