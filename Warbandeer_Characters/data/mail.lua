---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, sort = table.insert, table.sort
local floor, max = math.floor, math.max
local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
local GetServerTime = GetServerTime

local DAY = 86400
local MAX_ATTACH = ATTACHMENTS_MAX_RECEIVE or 16
-- A piece of mail flagged "expiring soon" once it's within this many days of expiry
-- (drives the login warning; the Summary column applies the same window).
ns.MAIL_WARN_DAYS = 3

---@class MailData
---@field scannedAt integer server time of the last inbox scan
---@field count integer number of mail in the inbox
---@field expiries integer[] absolute server-time expiry stamps, ascending (one per mail)
---@field items table<integer, integer> itemID -> attached count across all mail
---@field money integer total attached gold, in copper

---@class Character
---@field mail MailData?

-- Scan the open inbox into the current character's mail cache. Inbox data is only
-- readable while a mailbox is open (MAIL_INBOX_UPDATE), so this is a last-seen cache,
-- mirroring the bank scanner. `daysLeft` is fractional days remaining; we store an
-- absolute expiry (now + daysLeft*DAY) so the cached value stays correct as it ages.
local function scanInbox()
  local toon = ns.currentData
  if not toon then return end
  local num = GetInboxNumItems() or 0
  local now = GetServerTime()
  local expiries, items, money = {}, {}, 0
  for index = 1, num do
    local _, _, _, _, mailMoney, _, daysLeft, itemCount = GetInboxHeaderInfo(index)
    if daysLeft then insert(expiries, now + floor(daysLeft * DAY)) end
    money = money + (mailMoney or 0)
    if itemCount and itemCount > 0 then
      for i = 1, MAX_ATTACH do
        local _, itemID, _, count = GetInboxItem(index, i)
        if itemID then items[itemID] = (items[itemID] or 0) + (count or 1) end
      end
    end
  end
  sort(expiries)
  toon.mail = { scannedAt = now, count = num, expiries = expiries, items = items, money = money }
end

ns:registerEvent("MAIL_INBOX_UPDATE", scanInbox)

-- Print a one-line account-wide warning naming each character with mail expiring within
-- MAIL_WARN_DAYS, soonest first, e.g. "Mail expiring soon on: Vellika (1d), Kurorin (2d)".
-- Last-seen data, so a mailbox not visited recently may be stale (inherent to alt caches).
---@class Warbandeer_Characters
---@field WarnExpiringMail fun(self)
function ns:WarnExpiringMail()
  local now = GetServerTime()
  local threshold = now + ns.MAIL_WARN_DAYS * DAY
  local soon = {}
  for name, c in pairs(self.db.characters) do
    local m = c.mail
    local first = m and m.expiries and m.expiries[1]
    if first and first <= threshold then
      insert(soon, { name = name, days = max(0, floor((first - now) / DAY)), ts = first })
    end
  end
  if #soon == 0 then return end
  sort(soon, function(a, b) return a.ts < b.ts end)
  local parts = {}
  for _, w in ipairs(soon) do insert(parts, ("%s (%dd)"):format(w.name, w.days)) end
  ns.Print("Mail expiring soon on: " .. table.concat(parts, ", "))
end
