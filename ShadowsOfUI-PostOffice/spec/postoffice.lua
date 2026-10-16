-- Loads ShadowsOfUI-PostOffice/doNotWant.lua against a minimal fake WoW/ns environment
-- so the pure delete-index resolution (ns.ResolveDeleteIndex) and the confirm dialogs'
-- OnAccept/OnShow handlers can be unit-tested. doNotWant.lua touches almost no WoW API at
-- load time -- it only registers two StaticPopupDialogs and two ns callbacks -- so these
-- stubs are just enough to let the file load. Path is relative to the AddOns root, where
-- busted runs.
local M = {}

M.POPUP_MAIL = "SHADOWSOFUI_POSTOFFICE_DELETE_MAIL"
M.POPUP_MONEY = "SHADOWSOFUI_POSTOFFICE_DELETE_MONEY"

---@return table ns
function M.load()
  _G.StaticPopupDialogs = {}
  -- Confirmation-text globals the dialog tables read at load; values are irrelevant here.
  _G.DELETE_MAIL_CONFIRMATION = "Delete this mail?"
  _G.DELETE_MONEY_CONFIRMATION = "Delete this money?"
  _G.ACCEPT = "Accept"
  _G.CANCEL = "Cancel"

  -- doNotWant.lua registers a per-row decorator and a settings reaction at load; both are
  -- no-ops here (the resolution logic under test doesn't route through them).
  local ns = { OnInboxRow = function() end, OnSettingChanged = function() end }
  assert(loadfile("ShadowsOfUI-PostOffice/doNotWant.lua"))("ShadowsOfUI-PostOffice", ns)
  return ns
end

local MAIL_INFO = 17 -- stand-in for Enum.PlayerInteractionType.MailInfo

-- Remove every global the core/express specs install, so one test cannot see another's.
function M.resetMail()
  for _, k in ipairs({ "InboxFrame_Update", "OpenMail_Update", "InboxFrame", "OpenMailFrame",
    "InboxFrame_OnClick", "InboxFrameItem_OnEnter", "HandleModifiedItemClick", "GetInboxNumItems",
    "GetInboxHeaderInfo", "ReturnInboxItem", "IsControlKeyDown", "IsShiftKeyDown", "IsAltKeyDown",
    "hooksecurefunc", "LibNAddOn", "Enum", "SlashCmdList" }) do
    _G[k] = nil
  end
  for i = 1, 7 do _G["MailItem" .. i] = nil; _G["MailItem" .. i .. "ExpireTime"] = nil end
end

-- A faithful-enough hooksecurefunc: hooksecurefunc("Name", fn) wraps the global,
-- hooksecurefunc(table, "Name", fn) wraps the field; the original runs first, then fn.
function M.installHooksecurefunc()
  _G.hooksecurefunc = function(a, b, c)
    local target, name, fn
    if type(a) == "string" then target, name, fn = _G, a, b else target, name, fn = a, b, c end
    local orig = target[name]
    target[name] = function(...)
      local r = orig(...)
      fn(...)
      return r
    end
  end
end

-- Load core.lua (and, with `withExpress`, express.lua) against a fake LibNAddOn namespace.
-- Returns the ns the files populate. Nothing is hooked until a test "opens the mailbox".
---@param withExpress boolean?
---@return table ns
function M.loadCore(withExpress)
  M.resetMail()
  M.installHooksecurefunc()
  local ns = {
    _TITLE = "Post Office",
    registerEvent = function() end,
    RegisterSettings = function() end,
    RegisterChangelog = function() end,
    OnItemTooltip = function() end,
    db = { express = true },
  }
  _G.LibNAddOn = function() return ns end
  _G.Enum = { PlayerInteractionType = { MailInfo = MAIL_INFO } }
  _G.SlashCmdList = {}
  assert(loadfile("ShadowsOfUI-PostOffice/core.lua"))("ShadowsOfUI-PostOffice", ns)
  if withExpress then assert(loadfile("ShadowsOfUI-PostOffice/express.lua"))("ShadowsOfUI-PostOffice", ns) end
  return ns
end

-- Fire the mailbox-open interaction event the way LibNAddOn's listener does.
function M.openMailbox(ns) ns.PLAYER_INTERACTION_MANAGER_FRAME_SHOW(ns, MAIL_INFO) end

-- Install a fake inbox over the header/count/delete API the confirm handlers call. `letters`
-- is an array of { sender, subject, money, cod, hasItem } tables held by reference, so a test
-- can insert or remove entries mid-confirm to model mail arriving or a sibling delete landing.
-- DeleteInboxItem removes the letter for real (as the live API does) and appends it to the
-- returned array, so a test asserts on *which letter* was destroyed, not just an index.
---@param letters table[]
---@return table[] deleted letters, in the order they were destroyed
function M.inbox(letters)
  _G.GetInboxNumItems = function() return #letters end
  _G.GetInboxHeaderInfo = function(i)
    local l = letters[i]
    return nil, nil, l.sender, l.subject, l.money, l.cod, nil, l.hasItem
  end
  local deleted = {}
  _G.DeleteInboxItem = function(i) deleted[#deleted + 1] = table.remove(letters, i) end
  return deleted
end

return M
