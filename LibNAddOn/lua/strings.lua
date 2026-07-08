---@class LibNAddOn
local ns = select(2, ...)
local sub = string.sub
local gmatch = string.gmatch
local insert = table.insert
local floor = math.floor
local format = string.format

---@class Lua
---@field strings Strings string utility functions

---@class Strings
local strings = {}
ns.lua.strings = strings

---returns true if str starts with start
---@param str string
---@param start string
---@return boolean
function strings.startsWith(str, start)
  return str and sub(str, 1, #start) == start
end

---splits str on each character in token; token is treated as a char class, so only a single non-magic character is safe (avoid `-`, `%`, `^`)
---@param token string
---@param str string
---@return table
function strings.split(token, str)
  local result = {}
  for part in gmatch(str, "[^"..token.."]+") do
    insert(result, part)
  end
  return result
end

---format a duration in seconds as a clock string. The shared formatter for run timers,
---completion times, cooldowns, etc. (consumed by LibNUI's Timer widget).
---@param seconds number?  elapsed/remaining seconds; nil/negative → 0, fractions floored
---@param style string?  "m:ss" (default; minutes unbounded) | "h:mm:ss" | "auto" (h:mm:ss at ≥ 1h, else m:ss)
---@return string
function strings.duration(seconds, style)
  seconds = floor(seconds or 0)
  if seconds < 0 then seconds = 0 end
  local m = floor(seconds / 60)
  if style == "auto" then style = seconds >= 3600 and "h:mm:ss" or "m:ss" end
  if style == "h:mm:ss" then
    return format("%d:%02d:%02d", floor(m / 60), m % 60, seconds % 60)
  end
  return format("%d:%02d", m, seconds % 60)
end

---strip WoW UI escape sequences, leaving the plain text: `|cAARRGGBB`…`|r` colour
---codes, `|T…|t` inline textures, and `|A…|a` inline atlases. For feeding marked-up
---API strings (delve/quest descriptions, tooltip lines) into contexts that re-colour or
---measure the text, where embedded codes would corrupt the result.
---@param str string?  the marked-up text; nil passes through as nil
---@return string?  the plain text (nil when str is nil)
function strings.stripEscapes(str)
  if not str then return nil end
  -- parens collapse gsub's (result, count) to just the string
  return (str:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", "")
             :gsub("|T.-|t", "")
             :gsub("|A.-|a", ""))
end
