---@class ShadowsOfUI_PostOffice: AddOn
local ns = LibNAddOn(...)

-- Headless mailbox helper. Re-derives a few of Postal's "pure logic" modules in
-- the suite's LibNAddOn style: it injects no UI of its own, only augments the
-- native mail experience and exposes toggles in the Blizzard Settings panel.
--
-- Feature flags — all on by default, matching Postal's shipped module defaults.
local Defaults = {
  rake = true,       -- report coin collected each mailbox visit
  tradeBlock = true, -- suppress trade requests while the mailbox is open
  wire = true,       -- auto-fill a blank Send-Mail subject with the coin amount
}

function ns:MigrateDB()
  local db = self.db
  for k, v in pairs(Defaults) do
    if db[k] == nil then db[k] = v end -- non-destructive: only add missing keys
  end
  db.version = 1
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
    },
  },
}

-- "Changelog" button in the settings category (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- /spost → open settings
SLASH_SUI_POSTOFFICE1 = "/spost"
SlashCmdList["SUI_POSTOFFICE"] = function()
  Settings.OpenToCategory(ns._TITLE)
end
