---@class LibNAddOn
local ns = select(2, ...)
local select, pairs, insert = select, pairs, table.insert

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

---@class Maps
---@field merge fun(dest: table, ...): table merge multiple tables into the first one, overwriting existing keys
function maps.merge(destination, ...)
  for i=1,select("#", ...) do
    local t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        if '__index' ~= k then
          if type(destination[k]) == "table" and type(v) == "table" then
            maps.merge(destination[k], v)
          else
            destination[k] = v
          end
        end
      end
    end
  end
  return destination
end

---@class Maps
---@field fill fun(destination: table, ...): table fill the destination table from the source tables, without overwriting existing keys
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

---@class Maps
---@field map fun(t: table, f: fun(v: any, k: integer | string): any): table return a new table by transforming each value by the given function
function maps.map(t, f)
  local r = {}
  for k,v in pairs(t) do
    r[k] = f(v, k)
  end
  return r
end

---@class Maps
---@field toMap fun(t: table, f: fun(v: any, k: integer | string): any): table return a new table by mapping each value by the given function
function maps.toMap(t, f)
  local r = {}
  for i,v in ipairs(t) do
    r[v] = f == nil and v or f(v, i)
  end
  return r
end

---@class Maps
---@field toList fun(t: table, f: fun(k: integer | string, v: any): any): table return a list by transforming the key/value pairs of the map
function maps.toList(t, f)
  local r = {}
  for k,v in pairs(t) do
    insert(r, f(k, v))
  end
  return r
end

---@class Maps
---@field any fun(t: table, f: fun(v: any): boolean): boolean return true if the function returns true for any value in the table
function maps.any(t, f)
  for _,v in pairs(t) do
    if f(v) then
      return true
    end
  end
  return false
end

---@class Maps
---@field anyKey fun(t: table, f: fun(k: integer | string): boolean): boolean return true if the function returns true for any key in the table
function maps.anyKey(t, f)
  for k,_ in pairs(t) do
    if f(k) then
      return true
    end
  end
  return false
end
