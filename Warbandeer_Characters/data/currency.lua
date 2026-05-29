local _, ns = ...
-- luacheck: globals C_CurrencyInfo C_Item GetMoney
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetMoney = GetMoney
local GetItemCount = C_Item.GetItemCount

local function weeklyTracked(self)
  local info = GetCurrencyInfo(self.id)
  if not info then return nil end
  local cap    = info.maxWeeklyQuantity or 0
  local earned = info.quantityEarnedThisWeek or 0
  return { quantity = info.quantity, earned = earned, max = cap, capped = cap > 0 and earned >= cap }
end

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
  HeroDawncrest = { id = 3345, get = weeklyTracked },
  MythDawncrest = { id = 3347, get = weeklyTracked },

  -- Midnight crest currencies (quantity only, no weekly cap)
  AdventurerCrest  = { id = 3383, get = function(self) return GetCurrencyInfo(self.id).quantity end },
  VeteranCrest     = { id = 3341, get = function(self) return GetCurrencyInfo(self.id).quantity end },
  ChampionCrest    = { id = 3343, get = function(self) return GetCurrencyInfo(self.id).quantity end },

  -- Midnight resource currencies
  Manaflux         = { id = 3378, get = function(self) return GetCurrencyInfo(self.id).quantity end },
  VoidlightMarl    = { id = 3316, get = function(self) return GetCurrencyInfo(self.id).quantity end },
  NebulousVoidcore = { id = 3418, get = function(self) return GetCurrencyInfo(self.id).quantity end },

  -- Shard of Dun Dun: weekly cap 8
  ShardDunDun = { id = 3376, get = weeklyTracked },

  -- Spark of Radiance: item (232875), not a currency
  SparkOfRadiance = {
    get = function() return GetItemCount(232875) end,
    event = "BAG_UPDATE_DELAYED",
  },
}
