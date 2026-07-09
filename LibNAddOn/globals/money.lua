---@class LibNAddOn
local ns = select(2, ...)
local floor = math.floor

-- WoW-money helpers on ns.wow. Guarded so this file is independent of load order
-- (and loadable standalone in specs); globals/wow.lua creates ns.wow with its data.
ns.wow = ns.wow or {}

-- Group a whole number with the client's thousands separator (a plain tostring when
-- BreakUpLargeNumbers is unavailable, e.g. in specs). Only gold is ever large enough
-- to need this — silver/copper are capped at 99.
local function grouped(n) return (BreakUpLargeNumbers or tostring)(n) end

-- Plain-text coin string with no texture escapes — for editable or plain text (mail
-- subjects, the copy window, chat) where GetCoinTextureString's icon markup wouldn't
-- render. Omits zero denominations but returns "0c" for a zero amount. The gold part
-- is thousands-grouped by default (see `grouped`); pass { grouped = false } for plain
-- digits. e.g. 10230405 copper -> "1,023g 4s 5c", 10000 -> "1g", 0 -> "0c".
---@param copper integer
---@param opts { grouped: boolean? }?  gold grouping is on by default; { grouped = false } disables it
---@return string
function ns.wow.CoinString(copper, opts)
  local parts = {}
  local g = floor(copper / 10000)
  local s = floor(copper % 10000 / 100)
  local c = copper % 100
  if g > 0 then
    local gt = (opts and opts.grouped == false) and tostring(g) or grouped(g)
    parts[#parts + 1] = gt .. "g"
  end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- Grouped gold-only amount with no coin suffix, e.g. 12345678 copper -> "1,234".
-- Truncates to whole gold and thousands-groups it by default (see `grouped`); pass
-- { grouped = false } for plain digits. Callers append their own "g"/"g this week"
-- suffix, so a bare right-aligned number column can adopt this too.
---@param copper integer
---@param opts { grouped: boolean? }?  grouping is on by default; { grouped = false } disables it
---@return string
function ns.wow.GoldString(copper, opts)
  local gold = floor(copper / 10000)
  if opts and opts.grouped == false then return tostring(gold) end
  return grouped(gold)
end
