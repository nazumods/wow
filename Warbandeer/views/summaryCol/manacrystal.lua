---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Untainted Mana-Crystals (currency 3356): weekly earn cap of 250. Red when the
-- week's cap is earned — done until weekly reset. Hover shows earned/cap.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "manaCrystal", label = "Untainted Mana-Crystals",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\manacrystal.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Untainted Mana-Crystals", "Crystals held. Red when the weekly cap is earned — resets at weekly reset."},
    getData = function(t)
      if not t.currency then return "" end
      local c = t.currency.UntaintedManaCrystal
      -- stale pre-table-shape entries store a bare number
      if type(c) == "number" then
        return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
      end
      -- known 0 at max level reads as a muted em-dash; below-max stays empty
      if not c or c.quantity == 0 then
        return t.basic.level >= ns.wow.maxLevel and ns.ZeroDashC or ""
      end
      local tipLine  = c.earned .. "/" .. c.max
      local tipColor = c.capped and ns.CappedColor or ns.UncappedColor
      return {
        text     = c.quantity,
        justifyH = ui.justify.Center,
        color    = tipColor,
        onEnter  = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine(tipLine, tipColor[1], tipColor[2], tipColor[3])
          ui.tip:Show()
        end,
        onLeave  = function() ui.tip:Hide() end,
      }
    end,
  }
)
