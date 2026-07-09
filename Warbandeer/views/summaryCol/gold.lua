---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local BreakUpLargeNumbers = BreakUpLargeNumbers

-- gold
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "gold", label = "Gold",
    name = "Gold",
    -- wide enough for the footer's full g/s/c total (e.g. "1,234,567g 45s 12c"),
    -- which is far longer than the gold-only per-character cells
    width = 145,
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
        text = ns.wow.CoinString(total),
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
        color = {1, 0.82, 0, 1},
      }
    end,
  }
)
