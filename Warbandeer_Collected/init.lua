-- luacheck: globals LibNUI WarbandeerApi
local ns = LibNAddOn(...)

function ns:MigrateDB()
  local db = self.db
  if not db.sets then db.sets = {} end
  if not db.collected then db.collected = 0 end
  if not db.total then db.total = 0 end
  db.version = 2
end
