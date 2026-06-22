---@type Warbandeer_Characters
local ns = select(2, ...)
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetMoney = GetMoney

---@class CurrencyBroker: Broker
local Currency = ns:RegisterBroker("currency")

Currency.fields = {
  RestoredCofferKey = {
    id = 3028,
    -- GetCurrencyInfo returns nil for a currency the character hasn't discovered yet,
    -- so guard the index (consumers coalesce nil → 0).
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      return info and info.quantity
    end,
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
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      local c = toon.currency and toon.currency.HeroDawncrest
      if not c then return nil end
      return {quantity = c.quantity, earned = 0, max = c.max, capped = false}
    end,
  },
  NebulousVoidcore = {
    id = 3418, -- season-total cap (totalEarned vs maxQuantity) grows by 2 each weekly reset
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return {quantity = 0, earned = 0, max = 0, capped = false} end
      local earned = info.totalEarned or 0
      local max    = info.maxQuantity or 0
      return {
        quantity = info.quantity or 0,
        earned   = earned,
        max      = max,
        capped   = max > 0 and earned >= max,
      }
    end,
    event = "CURRENCY_DISPLAY_UPDATE",
    eventFilter = function(self, _, currencyID) return currencyID == self.id end,
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      local c = toon.currency and toon.currency.NebulousVoidcore
      if not c then return nil end
      -- a stale pre-table-shape entry is a bare number holding just the count
      if type(c) == "number" then
        return {quantity = c, earned = 0, max = 0, capped = false}
      end
      -- the cap grows at reset, so a previously capped character can earn again
      return {quantity = c.quantity, earned = c.earned, max = c.max, capped = false}
    end,
  },
  FieldAccolade = {
    id = 3405,
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      return info and info.quantity
    end,
  },
  UnalloyedAbundance = {
    id = 3377,
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      return info and info.quantity
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
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      local c = toon.currency and toon.currency.MythDawncrest
      if not c then return nil end
      return {quantity = c.quantity, earned = 0, max = c.max, capped = false}
    end,
  },
  UntaintedManaCrystal = {
    id = 3356, -- weekly earn cap (maxWeeklyQuantity 250); hard cap 1000
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
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      local c = toon.currency and toon.currency.UntaintedManaCrystal
      if not c then return nil end
      return {quantity = c.quantity, earned = 0, max = c.max, capped = false}
    end,
  },
  ShardOfDundun = {
    -- (3376) Empowers the Abundance world event. Earn up to 8 per week
    -- (maxWeeklyQuantity) and hold at most 8 (maxQuantity) — you can't earn while
    -- full. "Done this week" is therefore EITHER constraint hit: holding the cap, OR
    -- having earned the week's 8 (held < 8 after spending). Both caps are 8.
    id = 3376,
    get = function(self)
      local info = GetCurrencyInfo(self.id)
      if not info then return {quantity = 0, earned = 0, max = 0, weeklyMax = 0, capped = false} end
      local q      = info.quantity or 0
      local earned = info.quantityEarnedThisWeek or 0
      local max    = info.maxQuantity or 0
      local weekly = info.maxWeeklyQuantity or 0
      return {
        quantity  = q,
        earned    = earned,
        max       = max,
        weeklyMax = weekly,
        capped    = (max > 0 and q >= max) or (weekly > 0 and earned >= weekly),
      }
    end,
    event = "CURRENCY_DISPLAY_UPDATE",
    eventFilter = function(self, _, currencyID) return currencyID == self.id end,
    resetOn = ns.RESET_WEEKLY,
    reset = function(_, toon)
      local c = toon.currency and toon.currency.ShardOfDundun
      if not c then return nil end
      -- the week's earn allowance refreshes; held shards carry over, so re-derive
      -- capped from the hold cap alone (earned is 0 for the new week).
      return {
        quantity  = c.quantity,
        earned    = 0,
        max       = c.max,
        weeklyMax = c.weeklyMax,
        capped    = c.max > 0 and c.quantity >= c.max,
      }
    end,
  },
}
