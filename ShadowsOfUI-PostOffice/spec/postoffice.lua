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
