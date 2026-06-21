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
  ns:after(MAIL_WARN_DELAY, function() self:WarnExpiringMail() end)
end
