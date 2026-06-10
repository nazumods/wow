---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Catalyst charges (Dawnlight Manaflux): the bank recharges 1 every two weeks
-- up to 8, so a full bank means further recharge is wasted — show it red.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\catalyst.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Catalyst Charges", "Dawnlight Manaflux held. Red when full — recharge is being wasted."},
    getData = function(t)
      local c = t.currency and t.currency.Catalyst
      if not c or c.quantity == 0 then return "" end
      return {
        text     = c.quantity,
        justifyH = ui.justify.Center,
        color    = c.capped and ns.CappedColor or ns.UncappedColor,
      }
    end,
  }
)
