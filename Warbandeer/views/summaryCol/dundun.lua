---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Shard of Dundun (currency 3376): earn up to 8/week and hold at most 8, used to
-- empower the Abundance world event. The cell shows the held count, red when the
-- character is done for the week — either full (held 8, can't earn until spent) OR
-- the week's 8 already earned (held < 8 after spending). Hover shows held + earned
-- this week.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "shardOfDundun", label = "Shard of Dundun",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\dundun.tga",
    iconColor = ns.theme.colors.muted,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Shard of Dundun", "Shards held. Red when full (8) or the week's 8 are earned — spend at Chel the Chip to earn more."},
    getData = function(t)
      if not t.currency then return "" end
      local c = t.currency.ShardOfDundun
      -- stale pre-table-shape entries store a bare number
      if type(c) == "number" then
        return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
      end
      -- nothing held and nothing earned this week: muted em-dash at max, blank below.
      -- (held 0 but earned 8 — spent and done — still renders, in capped red.)
      if not c or (c.quantity == 0 and (c.earned or 0) == 0) then
        return t.basic.level >= ns.wow.maxLevel and ns.ZeroDashC or ""
      end
      local tipColor   = c.capped and ns.CappedColor or ns.UncappedColor
      local heldLine   = "Held: " .. c.quantity .. "/" .. (c.max or 0)
      local earnedLine = "Earned this week: " .. (c.earned or 0) .. "/" .. (c.weeklyMax or 0)
      return {
        text     = c.quantity,
        justifyH = ui.justify.Center,
        color    = tipColor,
        onEnter  = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine(heldLine, tipColor[1], tipColor[2], tipColor[3])
          ui.tip:AddLine(earnedLine, tipColor[1], tipColor[2], tipColor[3])
          ui.tip:Show()
        end,
        onLeave  = function() ui.tip:Hide() end,
      }
    end,
  }
)
