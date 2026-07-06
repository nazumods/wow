---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local GetServerTime = GetServerTime
local DAY = 86400
local WARN_DAYS = 3 -- red when the soonest mail expires within this many days
local MAIL_ICON = "ui-hud-minimap-mail-up" -- the minimap new-mail envelope

-- mail — new (unread) mail waiting trumps everything: the cell shows just an envelope
-- icon (persisted account-wide, so it shows on alts and survives a /reload). With no
-- mail waiting it falls back to the count of items/gold in the mailbox. Either way the
-- cell goes red when a piece is about to expire. Blank when the mailbox is empty with no
-- new mail, or hasn't been scanned yet (the "mail" entry in /wbc missing surfaces
-- never-visited characters).
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
      "An envelope marks new (unread) mail waiting.",
      "Red when something expires within " .. WARN_DAYS .. " days.",
    },
    getData = function(t)
      local m = t.mail
      if not m then return "" end
      local count = m.count
      local hasCount = count and count > 0
      if not m.hasMail and not hasCount then return "" end
      -- The earliest expiry is the min, not expiries[1] — don't assume the data
      -- layer stored them sorted.
      local soonest
      for _, e in ipairs(m.expiries or {}) do
        if not soonest or e < soonest then soonest = e end
      end
      local soon = soonest and soonest <= GetServerTime() + WARN_DAYS * DAY
      -- New mail waiting trumps the count: show just the envelope. Otherwise fall back
      -- to the inbox count. Either way the cell goes red when a piece expires soon.
      local text = m.hasMail and ("|A:" .. MAIL_ICON .. ":14:14|a") or count
      return {
        text = text,
        justifyH = ui.justify.Center,
        color = soon and ns.CappedColor or nil,
      }
    end,
  }
)
