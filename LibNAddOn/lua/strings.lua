local _, ns = ...
local sub = string.sub
local gmatch = string.gmatch
local insert = table.insert

local strings = {}
ns.lua.strings = strings

-- returns true if str starts with start
function strings.startsWith(str, start)
  return str and sub(str, 1, #start) == start
end

-- returns a List of the substrings in str that are separated by token
function strings.split(token, str)
  local result = {}
  for part in gmatch(str, "[^"..token.."]+") do
    insert(result, part)
  end
  return result
end
