local _, ns = ...
local select, pairs, insert = select, pairs, table.insert

---@class Lists
local lists = {}
ns.lua.lists = lists

---create a list from the values of multiple tables
---@class Lists
---@field values fun(...: table): table
function lists.values(...)
  local copy = {}
  local t
  for i=1,select("#", ...) do
    t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        insert(copy, v)
      end
    end
  end
  return copy
end

---generate an list by calling a function 1..n times with the index
---@class Lists
---@field generate fun(f: fun(i: integer): any, n: integer, start: integer?): table
function lists.generate(f, n, start)
  local r, a = {}, start or 1
  for i=a,n do insert(r, i, f(i)) end
  return r
end

---return a new table by transforming each value by the given function
---@class Lists
---@field map fun(t: table, f: fun(v: any, k: integer): any): table
function lists.map(t, f)
  local r = {}
  for k,v in ipairs(t) do
    insert(r, f and f(v, k) or v)
  end
  return r
end

---@class Lists
---@field filter fun(t: table, f: fun(v:any, k: integer): any): table
function lists.filter(t, f)
  local r = {}
  for k,v in ipairs(t) do
    if f(v, k) then
      insert(r, v)
    end
  end
  return r
end

---find a value in a list, returning the index
---if value is a function, it will be called for each value, and the matching value will be returned after the index
---@class Lists
---@field find fun(t: table, value: any | fun(v: any): boolean): integer | nil
function lists.find(table, value)
  if type(value) == "function" then
    for i,v in ipairs(table) do
      if value(v) then
        return i, v
      end
    end
  end
  for i,v in ipairs(table) do
    if v == value then
      return i
    end
  end
  return nil
end

---fold a list into a list of lists, each of size n
---@class Lists
---@field fold fun(t: table, n: integer): table
function lists.fold(t, n)
  local r = {}
  local c = math.ceil(#t / n)
  for i=1,n do
    r[i] = {}
    for j=1,c do
      local index = (j-1)*n + i
      if t[index] then
        insert(r[i], t[index])
      end
    end
  end
  return r
end

---prepend values to a list
---@class Lists
---@field prepend fun(t: table, ...: any): table
function lists.prepend(t, ...)
  local arg = {...}
  for i=#arg, 1, -1 do
    table.insert(t, 1, arg[i])
  end
  return t
end
