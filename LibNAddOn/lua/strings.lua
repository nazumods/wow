---@class LibNAddOn
local ns = select(2, ...)
local sub = string.sub
local gmatch = string.gmatch
local insert = table.insert

---@class Lua
---@field strings Strings string utility functions

---@class Strings
local strings = {}
ns.lua.strings = strings

---@class Strings
---@field startsWith fun(str: string, start: string): boolean returns true if str starts with start
function strings.startsWith(str, start)
  return str and sub(str, 1, #start) == start
end

---@class Strings
---@field split fun(token: string, str: string): table returns a List of the substrings in str that are separated by token
function strings.split(token, str)
  local result = {}
  for part in gmatch(str, "[^"..token.."]+") do
    insert(result, part)
  end
  return result
end
