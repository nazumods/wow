---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

local GetServerTime = GetServerTime
local HOUR, DAY = 3600, 86400
local WARN = 6 * HOUR   -- red when the soonest auction expires within this
local MAX_AGE = 2 * DAY -- auctions run <=48h; older cache means everything has resolved

-- auctions — count of a character's active auctions at the AH, red when the soonest is
-- about to expire. The live count comes from stored expiry stamps still in the future, so a
-- stale cache (or expired auctions) drops out instead of showing a phantom count. Blank when
-- the character has no live auctions or hasn't visited the AH.
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "auctions", label = "Auctions",
    name = "AH",
    width = 32,
    justifyH = ui.justify.Center,
    tooltip = {
      "Auctions",
      "Active auctions waiting at the Auction House.",
      "Red when the soonest expires within 6 hours.",
    },
    getData = function(t)
      local a = t.auctions
      if not a or not a.scannedAt then return "" end
      local now = GetServerTime()
      if now - a.scannedAt > MAX_AGE then return "" end
      local live, soonest = 0, nil
      if a.expiries and #a.expiries > 0 then
        for _, ts in ipairs(a.expiries) do
          if ts > now then
            live = live + 1
            -- soonest = the min future stamp; don't assume expiries are sorted.
            if not soonest or ts < soonest then soonest = ts end
          end
        end
      else
        live = a.count or 0 -- no per-auction expiry captured; fall back to the scanned count
      end
      if live == 0 then return "" end
      local soon = soonest and soonest <= now + WARN
      return { text = live, justifyH = ui.justify.Center, color = soon and ns.CappedColor or nil }
    end,
  }
)
