local _, ns = ...
local GetMoney = GetMoney -- luacheck: globals GetMoney

---@class Character
---@field gold integer copper held by this character

ns.Gold = ns:RegisterBroker("gold")
ns.Gold.fields = {
  ---@class GoldBroker: Broker
  ---@field gold integer copper held by this character
  gold = {
    get = function() return GetMoney() end,
    event = "PLAYER_MONEY",
  },
}
