---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local BreakUpLargeNumbers = BreakUpLargeNumbers -- luacheck: globals BreakUpLargeNumbers

-- gold
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Gold",
    width = 70,
    justifyH = ui.justify.Right,
    getData = function(t)
      if not t.currency or not t.currency.gold then return "" end
      return {
        text = BreakUpLargeNumbers(math.floor(t.currency.gold / 10000)) .. "g",
        justifyH = ui.justify.Right,
        color = {1, 0.82, 0, 1},
      }
    end,
  }
)
