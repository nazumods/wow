---@type Warbandeer_Characters
local ns = select(2, ...)
local insert, sort = table.insert, table.sort
local floor, max = math.floor, math.max
local GetInboxNumItems = GetInboxNumItems
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxItem = GetInboxItem
local GetServerTime = GetServerTime
local HasNewMail = HasNewMail

local DAY = 86400
local MAX_ATTACH = ATTACHMENTS_MAX_RECEIVE or 16
-- A piece of mail flagged "expiring soon" once it's within this many days of expiry
-- (drives the login warning; the Summary column applies the same window).
ns.MAIL_WARN_DAYS = 3

---@class MailData
---@field scannedAt integer? server time of the last inbox scan (nil until a mailbox is opened)
---@field count integer? number of mail in the inbox (nil until a mailbox is opened)
---@field expiries integer[]? absolute server-time expiry stamps, ascending (one per mail)
---@field items table<integer, integer>? itemID -> attached count across all mail
---@field money integer? total attached gold, in copper
---@field hasMail boolean? true while the character has new (unread) mail waiting — the
---  minimap-envelope state (HasNewMail). Tracked independently of the inbox scan so it
---  reflects mail that has arrived but not yet been picked up; nil once the inbox is clear.

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
  toon.mail = {
    scannedAt = now, count = num, expiries = expiries, items = items, money = money,
    hasMail = HasNewMail() or nil,
  }
end

ns:registerEvent("MAIL_INBOX_UPDATE", scanInbox)

-- New-mail (minimap-envelope) state. HasNewMail is readable without opening a mailbox,
-- so this catches mail that has arrived but not been picked up — persisted so the Summary
-- column can flag it on alts. Stored on the mail record (created if the inbox was never
-- scanned); cleared to nil once no mail is waiting. UPDATE_PENDING_MAIL fires at login and
-- whenever the indicator changes, so the flag survives /reload rather than vanishing.
--
-- This is the exact event + API Blizzard's own MiniMapMailFrameMixin uses to raise/lower
-- the minimap envelope (Blizzard_Minimap/Mainline/Minimap.lua), so our flag flips in
-- lockstep with that icon. Caveat: Blizzard skips registering the event entirely when the
-- `IngameMailNotificationDisabled` game rule is active (no minimap icon on such realms/modes),
-- in which case this flag simply never sets — the column falls back to the inbox count.
local function updatePendingMail()
  local toon = ns.currentData
  if not toon then return end
  if HasNewMail() then
    if toon.mail then toon.mail.hasMail = true else toon.mail = { hasMail = true } end
  elseif toon.mail then
    toon.mail.hasMail = nil
  end
end

ns:registerEvent("UPDATE_PENDING_MAIL", updatePendingMail)

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

-- Missing report: mail is captured only while a mailbox is open (count stamped even for an
-- empty inbox), so a nil count means the character has never visited one since tracking began.
-- Last-seen cache, not a broker field, so it registers here.
ns:RegisterMissing{
  order = 80,
  check = function(toon) if not toon.mail or toon.mail.count == nil then return "mail" end end,
}
