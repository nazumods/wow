local _, ns = ...
local Player = ns.wow.Player
local GetSpecializationRoleByID = GetSpecializationRoleByID -- luacheck: globals GetSpecializationRoleByID

---@class Character
---@field basic BasicBroker

---@class BasicBroker: Broker
---@field level integer
---@field specialization {primary:Specialization?, active:Specialization, role:string, key:SpecializationKey}?
---@field professions {primary:any?, secondary:any?, fishing:any?, cooking:any?}?
---@field remix { unbound: integer }
ns.Basic = ns:RegisterBroker("basic")

ns.Basic.fields = {
  level = {
    order = 0, -- make sure this is updated first
    get = function() return Player:GetLevel() end,
    event = "PLAYER_LEVEL_UP",
    eventDelay = 500, -- delay to allow level up to complete
  },
  specialization = {
    get = function()
      local pid, primarySpec = Player:GetPrimarySpecialization()
      local aid, activeSpec = Player:GetActiveSpecialization()
      return {
        primary = primarySpec,
        active = activeSpec,
        role = GetSpecializationRoleByID(pid or aid),
        key = (pid or aid) and gsub(primarySpec or activeSpec, " ", ""),
      }
    end,
  },
  professions = {
    get = function()
      local professions = Player:GetProfessions()
      return {
        primary = professions.prof1:GetInfo(),
        secondary = professions.prof2:GetInfo(),
        fishing = professions.fishing:GetInfo(),
        cooking = professions.cooking:GetInfo(),
      }
    end,
  },
  remix = {
    get = function()
      local c = C_CurrencyInfo.GetCurrencyInfo(3268)
      local power = c and c.quantity or -1
      return {
        unbound = power > 115875 and floor((power - 115875) / 50000) or -1
      }
    end,
    event = "CURRENCY_DISPLAY_UPDATE",
    eventFilter = function(_, type) return type == 3268 end,
  },
}

local C_Bank = C_Bank
local HasMaxBankTabs, FetchNumPurchasedBankTabs = C_Bank.HasMaxBankTabs, C_Bank.FetchNumPurchasedBankTabs

ns:registerCommand("dump", "bank", function()
  local character = 0
  local guild = 1
  local account = 2
  ns.Print("Bank Expansion Info:")
  ns.Print("Has Max Bank Account Space:", (HasMaxBankTabs(account) and "yes" or "no"))
  ns.Print("Has Max Bank Guild Space:", (HasMaxBankTabs(guild) and "yes" or "no"))
  ns.Print("Has Max Bank Character Space:", (HasMaxBankTabs(character) and "yes" or "no"))
  ns.Print("Num Bank Account Tabs:", FetchNumPurchasedBankTabs(account))
  ns.Print("Num Bank Guild Tabs:", FetchNumPurchasedBankTabs(guild))
  ns.Print("Num Bank Character Tabs:", FetchNumPurchasedBankTabs(character))
end, "Dump bank expansion info")

local gt = {
  explorer = 207,
  adventurer = 220,
  veteran = 233,
  champion = 246,
  hero = 259,
  mythic = 272,
}

ns:registerCommand("dump", "gt", function()
  --local gt = ns.data.gearTiers
  ns.Print("Gear Tier ilvl info:")
  ns.Print("Explorer: "..gt.explorer)
  ns.Print("Adventurer: "..gt.adventurer)
  ns.Print("Veteran: "..gt.veteran)
  ns.Print("Champion: "..gt.champion)
  ns.Print("Hero: "..gt.hero)
  ns.Print("Mythic: "..gt.mythic)
end, "Gear Tier ilvl info")