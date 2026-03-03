local _, ns = ...
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo -- luacheck: globals C_CurrencyInfo

---@type Broker
ns.Currency = ns:RegisterBroker("currency")

ns.Currency.fields = {
  RestoredCofferKey = {
    id = 3028,
    get = function(self) return GetCurrencyInfo(self.id).quantity end,
  },
}
