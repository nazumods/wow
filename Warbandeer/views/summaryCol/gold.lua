---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local BreakUpLargeNumbers = BreakUpLargeNumbers

-- gold
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    name = "Gold",
    width = 85,
    justifyH = ui.justify.Right,
    getData = function(t)
      if not t.currency or not t.currency.gold then return "" end
      return {
        text = BreakUpLargeNumbers(math.floor(t.currency.gold / 10000)),
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
        color = {1, 0.82, 0, 1},
      }
    end,
    -- footer: total gold across the warband
    getFooter = function(toons)
      local total = 0
      for _,t in ipairs(toons) do
        if t.currency and t.currency.gold then total = total + t.currency.gold end
      end
      if total == 0 then return "" end
      return {
        text = BreakUpLargeNumbers(math.floor(total / 10000)),
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
        color = {1, 0.82, 0, 1},
      }
    end,
  }
)
