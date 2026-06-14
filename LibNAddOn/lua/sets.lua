---@class LibNAddOn
local ns = select(2, ...)

---@class Lua
---@field sets Sets set utility functions

---@class Sets
local sets = {}
ns.lua.sets = sets

---create a Set from a list of values
---@param list table
---@return table
function sets.Set(list)
  local set = {}
  for _,v in ipairs(list) do
    set[v] = true
  end
  return set
end

---return the values of a table as a Set
---@param t table
---@return table
function sets.values(t)
  local r = {}
  for _,v in pairs(t) do
    r[v] = true
  end
  return r
end
