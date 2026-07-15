---@type Warbandeer_Characters
local ns = select(2, ...)

-- Delay the mail-expiry warning past the login message flood so it isn't buried.
local MAIL_WARN_DELAY = 6000

-- register onLogin after brokers are initialized
ns.onLogin = function(self, login, reload)
  if not self.initialized then
    self:initialize()
    self.initialized = true
  end
  self:refresh()
  -- Warm the client item cache for class-mount items: C_MountJournal.GetMountFromItem returns nil
  -- for an item whose data isn't loaded, so this keeps the first Detail appearance-card render from
  -- showing an OWNED mount as missing (data/classmounts.lua; spell-keyed entries need no warming).
  for _, roster in pairs(ns.ClassMounts) do
    for _, e in ipairs(roster) do
      if e.itemID then C_Item.RequestLoadItemDataByID(e.itemID) end
    end
  end
  ns:after(MAIL_WARN_DELAY, function() self:WarnExpiringMail() end)
end
