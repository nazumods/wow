---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local ICON_PATH = "Interface\\AddOns\\Warbandeer\\icons\\unalloyedabundance.tga"

-- Unalloyed Abundance (currency 3377): earned from Abundant Harvests at the
-- Abundance world event (Zul'Aman), spent at Chel the Chip. A plain running
-- total, like Field Accolade — no weekly cap to colour.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "unalloyedAbundance", label = "Unalloyed Abundance",
    iconPath  = ICON_PATH,
    iconColor = ns.theme.colors.muted,
    width = 42,
    justifyH = ui.justify.Center,
    tooltip = {"Unalloyed Abundance", "Unalloyed Abundance held. Earned from Abundant Harvests at the Abundance event."},
    getData = function(t)
      local qty = t.currency and t.currency.UnalloyedAbundance or 0
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
