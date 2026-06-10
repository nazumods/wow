---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Nebulous Voidcore: the season-total cap grows by 2 each weekly reset, so red
-- (earned the current max) means the character is done until the next reset.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\voidcore.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Nebulous Voidcore", "Voidcores held. Red when the current cap is earned — more unlock at weekly reset."},
    getData = function(t)
      local c = t.currency and t.currency.NebulousVoidcore
      -- stale DB entries from before the table shape store a bare number
      if type(c) == "number" then
        return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
      end
      if not c then return "" end
      -- max-level characters always show the count — a red 0 means everything
      -- earned and spent; leveling characters only when they hold any
      if c.quantity == 0 and t.basic.level < ns.wow.maxLevel then return "" end
      return {
        text     = c.quantity,
        justifyH = ui.justify.Center,
        color    = c.capped and ns.CappedColor or ns.UncappedColor,
      }
    end,
  }
)
