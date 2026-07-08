---@class ShadowsOfUI_PostOffice: AddOn
local ns = LibNAddOn(...)

-- Headless mailbox helper. Re-derives a few of Postal's "pure logic" modules in
-- the suite's LibNAddOn style: it injects no UI of its own, only augments the
-- native mail experience and exposes toggles in the Blizzard Settings panel.
--
-- Feature flags — all on by default, matching Postal's shipped module defaults.
local Defaults = {
  rake = true,            -- report coin collected each mailbox visit
  tradeBlock = true,      -- suppress trade requests while the mailbox is open
  wire = true,            -- auto-fill a blank Send-Mail subject with the coin amount
  express = true,         -- modifier-click shortcuts (ctrl-return, alt-attach)
  expressAutoSend = false, -- alt-attach also sends the letter (off: a send is a deliberate click)
  forward = true,         -- "Forward" button on an open letter
  carbonCopy = true,      -- copy-to-window button on an open letter
  blackBook = true,       -- recipient menu + autocomplete on the "To:" field
  quickAttach = true,     -- trade-goods category attach buttons beside Send Mail
  doNotWant = true,       -- per-row return/delete icon on each inbox letter
  select = true,          -- inbox checkboxes + batch Open/Return buttons
}

function ns:MigrateDB()
  local db = self.db
  for k, v in pairs(Defaults) do
    if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
  end
  -- Table-valued state gets an explicit seed (kept out of Defaults so no instance
  -- ever aliases the shared defaults table).
  if db.blackBookRecent == nil then db.blackBookRecent = {} end -- recently-mailed names, newest first
  db.version = 7
end

-- Plain-text coin string (no texture escapes, for editable/subject text). e.g.
-- 10230405 copper -> "1023g 4s 5c"; omits zero parts. Shared by Wire + CarbonCopy.
local floor = math.floor
function ns.PlainCoins(copper)
  local parts = {}
  local g = floor(copper / 10000)
  local s = floor(copper % 10000 / 100)
  local c = copper % 100
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

--------------------------------------------------------------------------------
-- Mailbox lifecycle
--
-- Retail opens and closes the mail window through the player-interaction manager
-- (the legacy MAIL_SHOW/MAIL_CLOSED events are not fired for the mailbox), so we
-- watch the interaction frame events and filter to the mailbox interaction type.
-- Features subscribe with OnMailShow/OnMailHide at file-load time; each callback
-- checks its own enable flag so a live settings toggle takes effect next visit.
--------------------------------------------------------------------------------
local MAILBOX = Enum.PlayerInteractionType.MailInfo

ns._atMailbox = false
ns._onShow = {} ---@type function[]
ns._onHide = {} ---@type function[]

function ns.OnMailShow(fn) table.insert(ns._onShow, fn) end
function ns.OnMailHide(fn) table.insert(ns._onHide, fn) end

function ns.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(self, interactionType)
  if interactionType ~= MAILBOX then return end
  self._atMailbox = true
  for _, fn in ipairs(self._onShow) do fn() end
end

function ns.PLAYER_INTERACTION_MANAGER_FRAME_HIDE(self, interactionType)
  if interactionType ~= MAILBOX then return end
  self._atMailbox = false
  for _, fn in ipairs(self._onHide) do fn() end
end

-- Defining the methods above is not enough; the event listener only dispatches
-- events it has been registered for (see LibNAddOn/eventListener.lua).
ns:registerEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
ns:registerEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

-- Open-letter refresh. Blizzard's OpenMail_Update runs whenever the open-mail view
-- redraws (opening a letter, taking an attachment). Features that decorate the open
-- letter (Forward, CarbonCopy) subscribe here to refresh their button. OpenMail_Update
-- is load-on-demand (Blizzard_MailFrame), so hook it lazily on the first mailbox open.
ns._onOpenMailUpdate = {} ---@type function[]
function ns.OnOpenMailUpdate(fn) table.insert(ns._onOpenMailUpdate, fn) end

local openMailHooked = false
ns.OnMailShow(function()
  if openMailHooked or not OpenMail_Update then return end
  openMailHooked = true
  hooksecurefunc("OpenMail_Update", function()
    for _, fn in ipairs(ns._onOpenMailUpdate) do fn() end
  end)
end)

-- Shared inbox-row decoration. Blizzard's InboxFrame_Update redraws the 7 visible
-- inbox rows for the current page; features register ONE per-row callback here rather
-- than each racing its own InboxFrame_Update hook. The callback receives a `row` with
-- { i = 1..7, index = mail index, present = has a letter, item = MailItemN frame,
-- expire = MailItemNExpireTime frame }. Per-row WIDGETS anchor to those frames so they
-- follow the active row layout; the row LAYOUT itself (width/indent) is owned by
-- whichever feature changes it. Hooked lazily — InboxFrame_Update is load-on-demand.
local INBOX_ROWS = 7
ns._onInboxRow = {} ---@type fun(row: table)[]
function ns.OnInboxRow(fn) table.insert(ns._onInboxRow, fn) end

local inboxHooked = false
ns.OnMailShow(function()
  if inboxHooked or not InboxFrame_Update then return end
  inboxHooked = true
  hooksecurefunc("InboxFrame_Update", function()
    local num = GetInboxNumItems()
    local page = InboxFrame.pageNum or 1
    for i = 1, INBOX_ROWS do
      local index = (page - 1) * INBOX_ROWS + i
      local row = { i = i, index = index, present = index <= num,
        item = _G["MailItem" .. i], expire = _G["MailItem" .. i .. "ExpireTime"] }
      for _, fn in ipairs(ns._onInboxRow) do fn(row) end
    end
  end)
end)

-- Ask the inbox to redraw (re-runs InboxFrame_Update → our per-row callbacks). Used by
-- inbox features to apply a live settings toggle. Safe no-op away from an open mailbox.
function ns.RefreshInbox()
  if InboxFrame_Update and ns._atMailbox then InboxFrame_Update() end
end

--------------------------------------------------------------------------------
-- Settings-change routing
--
-- Features register a reaction keyed by their setting so a toggle can take
-- effect immediately (e.g. TradeBlock un-blocking while you're at the mailbox).
--------------------------------------------------------------------------------
ns._settingReactions = {} ---@type table<string, fun(value: boolean)>
function ns.OnSettingChanged(key, fn) ns._settingReactions[key] = fn end

function ns:settingChanged(key, value)
  local react = ns._settingReactions[key]
  if react then react(value) end
end

--------------------------------------------------------------------------------
-- Blizzard Settings panel (one checkbox per feature; no window of our own).
--------------------------------------------------------------------------------
local function dbTable(db) return db end
ns:RegisterSettings{
  {
    title = ns._TITLE,
    parent = "Shadows of UI",
    fields = {
      { typ = "checkbox", key = "rake", default = true, name = "Report coin collected",
        label = "report coin collected", table = dbTable,
        tooltip = "Print the coin you looted each time you close the mailbox." },
      { typ = "checkbox", key = "tradeBlock", default = true, name = "Block trades at the mailbox",
        label = "block trades at the mailbox", table = dbTable,
        tooltip = "Decline incoming trade requests while the mailbox is open, then restore your setting on close." },
      { typ = "checkbox", key = "wire", default = true, name = "Auto-subject for coin",
        label = "auto-subject for coin", table = dbTable,
        tooltip = "When sending coin, fill a blank Send-Mail subject with the amount." },
      { typ = "checkbox", key = "express", default = true, name = "Modifier-click shortcuts",
        label = "modifier-click shortcuts", table = dbTable,
        tooltip = "Ctrl-click an inbox letter to return it; Alt-click a bag item to attach it to the letter you're writing." },
      { typ = "checkbox", key = "expressAutoSend", default = false, name = "Alt-click also sends",
        label = "alt-click also sends", table = dbTable,
        tooltip = "After an Alt-click attaches an item, send the letter immediately (needs a recipient). Off by default." },
      { typ = "checkbox", key = "forward", default = true, name = "Forward button",
        label = "forward button", table = dbTable,
        tooltip = "Add a Forward button to an open letter to re-send its text and attachments to someone else." },
      { typ = "checkbox", key = "carbonCopy", default = true, name = "Copy-mail button",
        label = "copy-mail button", table = dbTable,
        tooltip = "Add a small button to an open letter that copies its text (and auction invoice details) into a selectable window." },
      { typ = "checkbox", key = "blackBook", default = true, name = "Recipient menu + autocomplete",
        label = "recipient menu + autocomplete", table = dbTable,
        tooltip = "Add a recipient menu (recent, warband alts, friends, guild) beside the To: field,"
          .. " and auto-complete names from those lists as you type (replaces Blizzard's popup)." },
      { typ = "checkbox", key = "quickAttach", default = true, name = "Quick-attach buttons",
        label = "quick-attach buttons", table = dbTable,
        tooltip = "Add trade-goods category buttons beside the Send Mail frame — click one to attach"
          .. " every stack of that type (cloth, herbs, ore …) from your bags to the letter." },
      { typ = "checkbox", key = "doNotWant", default = true, name = "Inbox return/delete icons",
        label = "inbox return/delete icons", table = dbTable,
        tooltip = "Show a small icon on each inbox letter — click it to return the letter to its sender,"
          .. " or delete it (whichever it would do on expiry). Deletions ask for confirmation." },
      { typ = "checkbox", key = "select", default = true, name = "Inbox select checkboxes",
        label = "inbox select checkboxes", table = dbTable,
        tooltip = "Add a checkbox to each inbox letter plus Open / Return buttons — tick letters and"
          .. " batch-open (take all attachments + coin) or return them. Shift/Ctrl-click for range / same-sender." },
    },
  },
}

-- "Changelog" button in the settings category (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- /spost → open settings. OpenToCategory takes a category ID, not a name (and our
-- category is a subcategory), so resolve it from the registered category object.
SLASH_SUI_POSTOFFICE1 = "/spost"
SlashCmdList["SUI_POSTOFFICE"] = function()
  if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end
