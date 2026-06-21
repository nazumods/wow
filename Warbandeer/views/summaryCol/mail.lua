---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local GetServerTime = GetServerTime
local DAY = 86400
local WARN_DAYS = 3 -- red when the soonest mail expires within this many days

-- mail — count of items/gold waiting in each character's mailbox, red when something is
-- about to expire. Blank when the mailbox is empty or hasn't been scanned yet (the
-- "mail" entry in /wbc missing surfaces never-visited characters).
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "mail", label = "Mail",
    name = "Mail",
    width = 36,
    justifyH = ui.justify.Center,
    tooltip = {
      "Mail",
      "Items and gold waiting in each character's mailbox.",
      "Red when something expires within " .. WARN_DAYS .. " days.",
    },
    getData = function(t)
      local m = t.mail
      if not m or not m.count or m.count == 0 then return "" end
      local soonest = m.expiries and m.expiries[1]
      local soon = soonest and soonest <= GetServerTime() + WARN_DAYS * DAY
      return {
        text = m.count,
        justifyH = ui.justify.Center,
        color = soon and ns.CappedColor or nil,
      }
    end,
  }
)
