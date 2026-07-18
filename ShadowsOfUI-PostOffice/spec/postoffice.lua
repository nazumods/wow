-- Loads ShadowsOfUI-PostOffice/doNotWant.lua against a minimal fake WoW/ns
-- environment so the pure delete-index resolution (ns.ResolveDeleteIndex) can be
-- unit-tested. doNotWant.lua touches almost no WoW API at load time -- it only
-- registers two StaticPopupDialogs and two ns callbacks -- so these stubs are just
-- enough to let the file load. Path is relative to the AddOns root, where busted runs.
local M = {}

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

return M
