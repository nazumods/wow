local _, ns = ...
local select, pairs, insert = select, pairs, table.insert

-- Maps
-- Maps are used to store key-value pairs, where keys are not necessarily numeric or sequential.

-- wow api
-- Mixin https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLBase/Mixin.lua
-- CopyTable

---@class Maps
local maps = {}
ns.lua.maps = maps

-- merge multiple tables into the first one, overwriting existing keys
---@class Maps
---@field merge fun(dest: table, ...): table
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

-- fill the destination table from the source tables, without overwriting existing keys
function maps.fill(destination, ...)
  for i=1,select("#", ...) do
    local t = select(i, ...)
    if t then
      for k, v in pairs(t) do
        if destination[k] == nil then
          destination[k] = v
        elseif type(destination[k]) == "table" and type(v) == "table" then
          --maps.fill(destination[k], v)
        end
      end
    end
  end
  return destination
end

---return a new table by transforming each value by the given function
---@class Maps
---@field map fun(t: table, f: fun(v: any, k: integer | string): any): table
function maps.map(t, f)
  local r = {}
  for k,v in pairs(t) do
    r[k] = f(v, k)
  end
  return r
end

-- return a new table by mapping each value by the given function
function maps.toMap(t, f)
  local r = {}
  for i,v in ipairs(t) do
    r[v] = f == nil and v or f(v, i)
  end
  return r
end

---return a list by transforming the key/value pairs of the map
---@class Maps
---@field toList fun(t: table, f: fun(k: integer | string, v: any): any): table
function maps.toList(t, f)
  local r = {}
  for k,v in pairs(t) do
    insert(r, f(k, v))
  end
  return r
end

-- return true if the function returns true for any value in the table
function maps.any(t, f)
  for _,v in pairs(t) do
    if f(v) then
      return true
    end
  end
end

-- return true if the function returns true for any key in the table
function maps.anyKey(t, f)
  for k,_ in pairs(t) do
    if f(k) then
      return true
    end
  end
end
