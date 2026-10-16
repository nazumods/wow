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

-- Hook one of the mail frame's redraw functions. Retail has them as globals
-- (InboxFrame_Update, OpenMail_Update); Forever's mail frame replaced them with the
-- frames' own methods (InboxFrame:Update, OpenMailFrame:Update), which Blizzard calls
-- through the frame, so a hook on the method sees every redraw. This is an API-shape
-- difference, so it is detected by existence, not by flavor (the global is tried first:
-- Retail is unchanged). Returns true only when a hook was installed, so a caller can
-- retry on a later mailbox open if Blizzard_MailFrame had not created the frame yet.
local function hookUpdate(globalName, frame, fn)
  if type(_G[globalName]) == "function" then
    hooksecurefunc(globalName, fn)
    return true
  end
  if frame and frame.Update then
    hooksecurefunc(frame, "Update", fn)
    return true
  end
  return false
end

-- Open-letter refresh. Blizzard's OpenMail_Update (Forever: OpenMailFrame:Update) runs
-- whenever the open-mail view redraws (opening a letter, taking an attachment). Features
-- that decorate the open letter (Forward, CarbonCopy) subscribe here to refresh their
-- button. Blizzard_MailFrame's frames are not guaranteed to exist when this file loads,
-- so hook lazily on the first mailbox open (and retry on the next one if they were absent).
ns._onOpenMailUpdate = {} ---@type function[]
function ns.OnOpenMailUpdate(fn) table.insert(ns._onOpenMailUpdate, fn) end

local openMailHooked = false
ns.OnMailShow(function()
  if openMailHooked then return end
  openMailHooked = hookUpdate("OpenMail_Update", OpenMailFrame, function()
    for _, fn in ipairs(ns._onOpenMailUpdate) do fn() end
  end)
end)

-- Shared inbox-row decoration. Blizzard's InboxFrame_Update (Forever: InboxFrame:Update)
-- redraws the 7 visible inbox rows for the current page; features register ONE per-row
-- callback here rather than each racing its own hook. The callback receives a `row` with
-- { i = 1..7, index = mail index, present = has a letter, item = MailItemN frame,
-- expire = MailItemNExpireTime frame }. Per-row WIDGETS anchor to those frames so they
-- follow the active row layout; the row LAYOUT itself (width/indent) is owned by
-- whichever feature changes it. Hooked lazily on the first mailbox open (the mail frames
-- are not guaranteed to exist when this file loads).
local INBOX_ROWS = 7
ns._onInboxRow = {} ---@type fun(row: table)[]
function ns.OnInboxRow(fn) table.insert(ns._onInboxRow, fn) end

local inboxHooked = false
ns.OnMailShow(function()
  if inboxHooked then return end
  inboxHooked = hookUpdate("InboxFrame_Update", InboxFrame, function()
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

-- Redraw the inbox through whichever API this client has (Retail: the InboxFrame_Update
-- global; Forever: InboxFrame:Update); does nothing if neither exists yet.
function ns.UpdateInbox()
  if InboxFrame_Update then
    InboxFrame_Update()
  elseif InboxFrame and InboxFrame.Update then
    InboxFrame:Update()
  end
end

-- Ask the inbox to redraw (re-runs our per-row callbacks). Used by inbox features to
-- apply a live settings toggle. Safe no-op away from an open mailbox.
function ns.RefreshInbox()
  if ns._atMailbox then ns.UpdateInbox() end
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
