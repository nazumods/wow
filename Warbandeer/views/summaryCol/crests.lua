---@class Warbandeer
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

local function formatCrest(c)
  if not c then return "" end
  -- stale DB entries from before the table migration store a bare number
  if type(c) == "number" then
    return c > 0 and {text = c, justifyH = ui.justify.Center} or ""
  end
  if c.quantity == 0 then return "" end
  local lines = {c.quantity .. " held"}
  if c.max > 0 then
    lines[2] = c.earned .. " / " .. c.max .. " earned this week"
    if c.capped then lines[3] = "Weekly cap reached" end
  end
  return {
    text     = c.quantity,
    justifyH = ui.justify.Center,
    color    = c.capped and ns.CappedColor or ns.UncappedColor,
    onEnter  = function(self)
      ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
      ui.tip:ClearLines()
      for _, l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:Show()
    end,
    onLeave = function(self) ui.tip:Hide() end,
  }
end

-- Hero Dawncrest
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    currencyID = 3345,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Hero Dawncrest", "Hero Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.HeroDawncrest)
    end,
  }
)

-- Myth Dawncrest
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    currencyID = 3347,
    width = 30,
    justifyH = ui.justify.Center,
    tooltip = {"Myth Dawncrest", "Myth Dawncrest held. Red when weekly cap reached."},
    getData = function(t)
      if not t.currency then return "" end
      return formatCrest(t.currency.MythDawncrest)
    end,
  }
)
