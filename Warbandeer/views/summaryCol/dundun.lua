---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Shard of Dundun (currency 3376): hard cap of 8, used to empower the Abundance
-- world event. Red when holding the cap — done until some are spent (the
-- earned-this-week API reads 0 even at the cap, so "done" is held >= cap, not
-- earned). Hover shows held/cap.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "shardOfDundun", label = "Shard of Dundun",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\dundun.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Shard of Dundun", "Shards held. Red when holding the cap of 8 — spend at Chel the Chip to earn more."},
    getData = function(t)
      if not t.currency then return "" end
      local c = t.currency.ShardOfDundun
      -- stale pre-table-shape entries store a bare number
      if type(c) == "number" then
        return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
      end
      -- known 0 at max level reads as a muted em-dash; below-max stays empty
      if not c or c.quantity == 0 then
        return t.basic.level >= ns.wow.maxLevel and ns.ZeroDashC or ""
      end
      local tipLine  = c.quantity .. "/" .. c.max
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
