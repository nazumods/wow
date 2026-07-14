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
    -- Size to the widest gold *cell*, not the footer: AutosizeColumn measures the
    -- header + data cells only. The g/s/c grand total is far wider, but the detached
    -- footer (#535) lets it overflow left into the footer band instead of clamping
    -- the column — so the data area no longer carries the total's width (#540).
    autosize = true,
    -- ...but never below this floor, so the wide g/s/c grand total still clears the
    -- Played total to its left whenever the Titles buffer column is visible (#540).
    minWidth = 90,
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
