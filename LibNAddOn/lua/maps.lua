---@class LibNAddOn
local ns = select(2, ...)
local select, pairs, insert, type, getmetatable = select, pairs, table.insert, type, getmetatable

-- Maps
-- Maps are used to store key-value pairs, where keys are not necessarily numeric or sequential.

-- wow api
-- Mixin https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLBase/Mixin.lua
-- CopyTable

---@class Lua
---@field maps Maps utility functions for working with tables as maps

---@class Maps
local maps = {}
ns.lua.maps = maps

---merge multiple tables into the first one, overwriting existing keys; plain
---sub-tables are copied so the sources are never aliased into the destination,
---while metatabled values (frames, mixins, class instances) stay shared by
---reference
---@param destination table
---@param ... any
---@return table
function maps.merge(destination, ...)
  for i=1,select("#", ...) do
    local t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        if '__index' ~= k then
          if type(destination[k]) == "table" and type(v) == "table" then
            maps.merge(destination[k], v)
          elseif type(v) == "table" and getmetatable(v) == nil then
            destination[k] = maps.merge({}, v)
          else
            destination[k] = v
          end
        end
      end
    end
  end
  return destination
end

---fill the destination table from the source tables, without overwriting existing keys
---@param destination table
---@param ... any
---@return table
function maps.fill(destination, ...)
  for i=1,select("#", ...) do
    local t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        -- Shallow on purpose: existing keys (including sub-tables) are left
        -- untouched; only maps.merge recurses.
        if destination[k] == nil then
          destination[k] = v
        end
      end
    end
  end
  return destination
end

---return a new table by transforming each value by the given function
---@param t table
---@param f fun(v: any, k: integer | string): any
---@return table
function maps.map(t, f)
  local r = {}
  for k,v in pairs(t) do
    r[k] = f(v, k)
  end
  return r
end

---return a new table by mapping each value by the given function
---@param t table
---@param f? fun(v: any, k: integer): any
---@return table
function maps.toMap(t, f)
  local r = {}
  for i,v in ipairs(t) do
    if f ~= nil then r[v] = f(v, i) else r[v] = v end
  end
  return r
end

---return a list by transforming the key/value pairs of the map
---@param t table
---@param f fun(k: integer | string, v: any): any
---@return table
function maps.toList(t, f)
  local r = {}
  for k,v in pairs(t) do
    insert(r, f(k, v))
  end
  return r
end

---return true if the function returns true for any value in the table
---@param t table
---@param f fun(v: any): boolean
---@return boolean
function maps.any(t, f)
  for _,v in pairs(t) do
    if f(v) then
      return true
    end
  end
  return false
end

---return true if the function returns true for any key in the table
---@param t table
---@param f fun(k: integer | string): boolean
---@return boolean
function maps.anyKey(t, f)
  for k,_ in pairs(t) do
    if f(k) then
      return true
    end
  end
  return false
end
