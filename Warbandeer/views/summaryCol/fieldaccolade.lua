---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    currencyID = 3405,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Field Accolade", "Field Accolades held."},
    getData = function(t)
      local qty = t.currency and t.currency.FieldAccolade or 0
      if qty == 0 then return "" end
      return {
        text     = qty,
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
      }
    end,
  }
)
