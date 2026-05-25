local _, ns = ...
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo -- luacheck: globals C_CurrencyInfo
local GetMoney = GetMoney -- luacheck: globals GetMoney

---@type Broker
ns.Currency = ns:RegisterBroker("currency")

ns.Currency.fields = {
  RestoredCofferKey = {
    id = 3028,
    get = function(self) return GetCurrencyInfo(self.id).quantity end,
  },
  gold = {
    get = function() return GetMoney() end,
    event = "PLAYER_MONEY",
  },
  CofferKeyShard = {
    id = 3310, -- Coffer Key Shard
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return nil end
      local cap = info.maxWeeklyQuantity or 0
      local earned = info.quantityEarnedThisWeek or 0
      return {
        quantity = info.quantity,
        capped = cap > 0 and earned >= cap,
      }
    end,
  },
  HeroDawncrest = {
    ids = {3345, 3346},
    get = function(self)
      local total = 0
      for _, id in ipairs(self.ids) do
        local info = GetCurrencyInfo(id)
        if info then total = total + (info.quantity or 0) end
      end
      return total > 0 and total or nil
    end,
  },
  MythDawncrest = {
    ids = {3347, 3348},
    get = function(self)
      local total = 0
      for _, id in ipairs(self.ids) do
        local info = GetCurrencyInfo(id)
        if info then total = total + (info.quantity or 0) end
      end
      return total > 0 and total or nil
    end,
  },
}
