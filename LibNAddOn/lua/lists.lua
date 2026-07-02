---@class LibNAddOn
local ns = select(2, ...)
local select, pairs, insert = select, pairs, table.insert

---@class Lua
---@field lists Lists list utility functions

---@class Lists
local lists = {}
ns.lua.lists = lists

---create a list from the values of multiple tables
---@param ... any
---@return table
function lists.values(...)
  local copy = {}
  local t
  for i=1,select("#", ...) do
    t = select(i, ...)
    if t then
      for _, v in pairs(t) do
        insert(copy, v)
      end
    end
  end
  return copy
end

---generate a packed list by calling f(i) for i in [start, n]
---@param f fun(i: integer): any
---@param n integer
---@param start integer
---@return table
function lists.generate(f, n, start)
  local r, a = {}, start or 1
  for i=a,n do insert(r, f(i)) end
  return r
end

---Return a new list by transforming each value with `f`.
---If `f` returns nil or false the original value is kept (Lua `or` fallback).
---Omit `f` for a shallow copy.
---@param t table
---@param f? fun(v: any, k: integer): any
---@return table
function lists.map(t, f)
  local r = {}
  for k,v in ipairs(t) do
    insert(r, f and f(v, k) or v)
  end
  return r
end

---@param t table
---@param f fun(v: any, k: integer): any
---@return table
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
---@param table table
---@param value any | fun(v: any): boolean
---@return integer | nil, any
function lists.find(table, value)
  if type(value) == "function" then
    for i,v in ipairs(table) do
      if value(v) then
        return i, v
      end
    end
    return nil  -- a predicate that matched nothing shouldn't fall through to == compare
  end
  for i,v in ipairs(table) do
    if v == value then
      return i
    end
  end
  return nil
end

---fold a list into n sub-lists via round-robin distribution
---@param t table
---@param n integer
---@return table
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
---@param t table
---@param ... any
---@return table
function lists.prepend(t, ...)
  local arg = {...}
  for i=#arg, 1, -1 do
    table.insert(t, 1, arg[i])
  end
  return t
end
