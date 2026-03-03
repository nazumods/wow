local _, ns = ...

-- register onLogin after brokers are initialized
ns.onLogin = function(self, login, reload)
  if not self.initialized then
    self:initialize()
    self.initialized = true
  end
  self:refresh()
end
