---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local ICON_PATH = "Interface\\AddOns\\Warbandeer\\icons\\fieldaccolade.tga"

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "fieldAccolade", label = "Field Accolade",
    iconPath    = ICON_PATH,
    iconColor   = ns.theme.colors.muted,
    iconOffsetX = 9,
    width = 42,
    justifyH = ui.justify.Center,
    tooltip = {"Field Accolade", "Field Accolades held."},
    getData = function(t)
      local qty = t.currency and t.currency.FieldAccolade or 0
      -- known 0 at max level reads as a muted em-dash; below-max stays empty
      if qty == 0 then return t.basic.level >= ns.wow.maxLevel and ns.ZeroDash or "" end
      return {
        text     = qty,
        justifyH = ui.justify.Right,
        fontInfo = ns.theme.fonts.number,
      }
    end,
  }
)
