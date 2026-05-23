---@class LibNAddOn
local ns = select(2, ...)

---@class Lua
---@field sets Sets set utility functions

---@class Sets
local sets = {}
ns.lua.sets = sets

---@class Sets
---@field Set fun(list: table): table create a Set from a list of values
function sets.Set(list)
  local set = {}
  for _,v in ipairs(list) do
    if type(v) == "number" then
      v = v..""
    end
    set[v] = true
  end
  return set
end

---@class Sets
---@field values fun(t: table): table return the values of a table as a Set
function sets.values(t)
  local r = {}
  for _,v in pairs(t) do
    if type(v) == "number" then
      v = v..""
    end
    r[v] = true
  end
  return r
end
