---@type Warbandeer_Characters
local ns = select(2, ...)
local Player = ns.wow.Player
local GetSpecializationRoleByID = GetSpecializationRoleByID
local GetServerTime = GetServerTime

---@class Character
---@field basic BasicBroker?

---@class BasicBroker: Broker
local Basic = ns:RegisterBroker("basic")

Basic.fields = {
  ---@class BasicBroker
  ---@field level integer
  level = {
    order = 0, -- make sure this is updated first
    get = function() return Player:GetLevel() end,
    event = "PLAYER_LEVEL_UP",
    eventDelay = 500, -- delay to allow level up to complete
  },
  ---@class BasicBroker: Broker
  ---@field specialization {primary:Specialization?, active:Specialization, role:string, key:SpecializationKey, id:integer?}?
  -- `active` = the spec actually being played (GetSpecialization); `primary` = the LOOT
  -- spec (GetLootSpecialization), which a player can deliberately set to a different spec.
  -- All spec-derived data (id/role/key, which downstream drive stat priorities, enchant /
  -- gem / mastery recommendations and the role icon) must follow the PLAYED spec, so it
  -- prefers `active` over the loot spec. Refreshes when the player swaps spec.
  specialization = {
    get = function()
      local pid, primarySpec = Player:GetPrimarySpecialization()
      local aid, activeSpec = Player:GetActiveSpecialization()
      local specId = aid or pid
      return {
        primary = primarySpec,
        active = activeSpec,
        role = specId and GetSpecializationRoleByID(specId),
        key = specId and gsub(activeSpec or primarySpec, " ", ""),
        -- Numeric global spec ID: locale-independent, persisted so consumers can resolve stat priorities for alts.
        id = specId,
      }
    end,
    event = "PLAYER_SPECIALIZATION_CHANGED",
  },
  ---@class BasicBroker: Broker
  ---@field professions {primary:any?, secondary:any?, fishing:any?, cooking:any?}?
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
  ---@class BasicBroker: Broker
  ---@field xp {percent:number, restPercent:number, isResting:boolean, recordedAt:integer}?
  xp = {
    get = function()
      local maxXP = Player:GetMaxXP()
      if not maxXP or maxXP == 0 then return nil end
      return {
        percent = Player:GetXP() / maxXP,
        restPercent = (Player:GetXPExhaustion() or 0) / maxXP,
        isResting = Player.IsResting(),
        recordedAt = GetServerTime(),
      }
    end,
    event = {"PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING"},
    eventDelay = 1000,
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