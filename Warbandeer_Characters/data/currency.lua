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
    id = 3345,
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return {quantity = 0, earned = 0, max = 0, capped = false} end
      local earned = info.quantityEarnedThisWeek or 0
      local max    = info.maxWeeklyQuantity or 0
      return {
        quantity = info.quantity or 0,
        earned   = earned,
        max      = max,
        capped   = max > 0 and earned >= max,
      }
    end,
  },
  MythDawncrest = {
    id = 3347,
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return {quantity = 0, earned = 0, max = 0, capped = false} end
      local earned = info.quantityEarnedThisWeek or 0
      local max    = info.maxWeeklyQuantity or 0
      return {
        quantity = info.quantity or 0,
        earned   = earned,
        max      = max,
        capped   = max > 0 and earned >= max,
      }
    end,
  },
}
