---@type Warbandeer_Characters
local ns = select(2, ...)
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
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      if not toon.currency or not toon.currency.CofferKeyShard then return nil end
      return {
        quantity = toon.currency.CofferKeyShard.quantity,
        capped = false,
      }
    end,
  },
  Catalyst = {
    id = 3378, -- Dawnlight Manaflux (Catalyst charges): banks 1 per two weeks, no weekly-earn caps
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return nil end
      local max = info.maxQuantity or 0
      return {
        quantity = info.quantity or 0,
        max      = max,
        capped   = max > 0 and (info.quantity or 0) >= max,
      }
    end,
    event = "CURRENCY_DISPLAY_UPDATE",
    eventFilter = function(self, _, currencyID) return currencyID == self.id end,
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
