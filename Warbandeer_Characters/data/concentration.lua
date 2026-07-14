---@type Warbandeer_Characters
local ns = select(2, ...)
local GetServerTime = GetServerTime

---@class ConcentrationEntry
---@field name string
---@field currencyId integer
---@field quantity integer
---@field maxQuantity integer
---@field rechargingAmountPerCycle integer
---@field rechargingCycleDurationMS integer
---@field lastUpdated integer

---@class Character
---@field concentration ConcentrationBroker?

---@class ConcentrationBroker: Broker
---@field data table<integer, ConcentrationEntry>?

-- Midnight expansion concentration currencies, keyed by PARENT skill line ID.
-- Gathering professions (182 Herb, 186 Mining, 393 Skinning) have no concentration.
local CONCENTRATION_CURRENCIES = {
  [171] = 3161,  -- Alchemy
  [164] = 3162,  -- Blacksmithing
  [333] = 3163,  -- Enchanting
  [202] = 3164,  -- Engineering
  [773] = 3165,  -- Inscription
  [755] = 3166,  -- Jewelcrafting
  [165] = 3167,  -- Leatherworking
  [197] = 3168,  -- Tailoring
}

local function tryCapture(skillLineID, profName, result)
  local currencyId = CONCENTRATION_CURRENCIES[skillLineID]
  if not currencyId then return end
  local curr = C_CurrencyInfo.GetCurrencyInfo(currencyId)
  if not curr or curr.maxQuantity == 0 then return end
  result[skillLineID] = {
    name                      = profName,
    currencyId                = currencyId,
    quantity                  = curr.quantity                  or 0,
    maxQuantity               = curr.maxQuantity               or 0,
    rechargingAmountPerCycle  = curr.rechargingAmountPerCycle  or 0,
    rechargingCycleDurationMS = curr.rechargingCycleDurationMS or 0,
    lastUpdated               = GetServerTime(),
  }
end

ns.Concentration = ns:RegisterBroker("concentration")
ns.Concentration.fields = {
  data = {
    missing = false,
    -- Called at login and on CURRENCY_DISPLAY_UPDATE. No profession window needed.
    get = function(self, toon, currentValue)
      local result = {}
      if currentValue then for k, v in pairs(currentValue) do result[k] = v end end
      local profs = toon.basic and toon.basic.professions
      if not profs then return result end
      for _, slot in ipairs({"primary", "secondary"}) do
        local p = profs[slot]
        if p and p.skillID then tryCapture(p.skillID, p.name, result) end
      end
      return result
    end,

    event = "CURRENCY_DISPLAY_UPDATE",
    -- Unfiltered (we track several profession currencies), so it fires on every currency
    -- change all session. Debounce a burst into one profession scan.
    eventDelay = 1000,
  },
}
