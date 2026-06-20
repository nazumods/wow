---@type Warbandeer_Characters
local ns = select(2, ...)
local GetServerTime = GetServerTime

---@class ArtisanCurrencyEntry
---@field name string
---@field currencyId integer
---@field quantity integer
---@field maxQuantity integer
---@field lastUpdated integer

---@class Character
---@field artisanCurrency ArtisanCurrencyBroker?

---@class ArtisanCurrencyBroker: Broker
---@field data table<integer, ArtisanCurrencyEntry>?

-- The current-expansion artisan crafting currency, keyed by PARENT skill line ID. In
-- Midnight this is the per-profession "Artisan's ... Moxie" family, and unlike the older
-- Mettle/Acuity model EVERY profession has one — including the gathering professions
-- (Herbalism/Mining/Skinning). Update this whole table each expansion.
local ARTISAN_CURRENCIES = {
  [171] = 3256, -- Alchemy        — Artisan Alchemist's Moxie
  [164] = 3257, -- Blacksmithing  — Artisan Blacksmith's Moxie
  [333] = 3258, -- Enchanting     — Artisan Enchanter's Moxie
  [202] = 3259, -- Engineering    — Artisan Engineer's Moxie
  [182] = 3260, -- Herbalism      — Artisan Herbalist's Moxie
  [773] = 3261, -- Inscription    — Artisan Scribe's Moxie
  [755] = 3262, -- Jewelcrafting  — Artisan Jewelcrafter's Moxie
  [165] = 3263, -- Leatherworking — Artisan Leatherworker's Moxie
  [186] = 3264, -- Mining         — Artisan Miner's Moxie
  [393] = 3265, -- Skinning       — Artisan Skinner's Moxie
  [197] = 3266, -- Tailoring      — Artisan Tailor's Moxie
}

local function tryCapture(skillLineID, profName, result)
  local currencyId = ARTISAN_CURRENCIES[skillLineID]
  if not currencyId then return end
  local curr = C_CurrencyInfo.GetCurrencyInfo(currencyId)
  -- GetCurrencyInfo returns nil for a currency the character hasn't discovered yet.
  if not curr then return end
  result[skillLineID] = {
    name        = profName,
    currencyId  = currencyId,
    quantity    = curr.quantity    or 0,
    maxQuantity = curr.maxQuantity or 0,
    lastUpdated = GetServerTime(),
  }
end

ns.ArtisanCurrency = ns:RegisterBroker("artisanCurrency")
ns.ArtisanCurrency.fields = {
  data = {
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
  },
}
