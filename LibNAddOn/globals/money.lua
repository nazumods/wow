---@class LibNAddOn
local ns = select(2, ...)
local floor = math.floor

-- WoW-money helpers on ns.wow. Guarded so this file is independent of load order
-- (and loadable standalone in specs); globals/wow.lua creates ns.wow with its data.
ns.wow = ns.wow or {}

-- Plain-text coin string with no texture escapes — for editable or plain text (mail
-- subjects, the copy window, chat) where GetCoinTextureString's icon markup wouldn't
-- render. Omits zero denominations but returns "0c" for a zero amount.
-- e.g. 10230405 copper -> "1023g 4s 5c", 10000 -> "1g", 0 -> "0c".
---@param copper integer
---@return string
function ns.wow.CoinString(copper)
  local parts = {}
  local g = floor(copper / 10000)
  local s = floor(copper % 10000 / 100)
  local c = copper % 100
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- Grouped gold-only amount with no coin suffix, e.g. 12345678 copper -> "1,234".
-- Truncates to whole gold and applies the client's large-number grouping via
-- BreakUpLargeNumbers (falling back to a plain tostring when it's unavailable, e.g.
-- in specs). Callers append their own "g"/"g this week" suffix, so a bare
-- right-aligned number column can adopt this too.
---@param copper integer
---@return string
function ns.wow.GoldString(copper)
  local gold = floor(copper / 10000)
  return (BreakUpLargeNumbers or tostring)(gold)
end
