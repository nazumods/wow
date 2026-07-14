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
    missing = false,
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
    missing = false,
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
    missing = false,
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
    missing = false,
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

ns:registerDump("bank", "Bank Expansion Info", "Dump bank expansion info", function(_, out)
  local character = 0
  local guild = 1
  local account = 2
  out:line("Bank Expansion Info:")
  out:line("Has Max Bank Account Space:", (HasMaxBankTabs(account) and "yes" or "no"))
  out:line("Has Max Bank Guild Space:", (HasMaxBankTabs(guild) and "yes" or "no"))
  out:line("Has Max Bank Character Space:", (HasMaxBankTabs(character) and "yes" or "no"))
  out:line("Num Bank Account Tabs:", FetchNumPurchasedBankTabs(account))
  out:line("Num Bank Guild Tabs:", FetchNumPurchasedBankTabs(guild))
  out:line("Num Bank Character Tabs:", FetchNumPurchasedBankTabs(character))
end)

local gt = {
  explorer = 207,
  adventurer = 220,
  veteran = 233,
  champion = 246,
  hero = 259,
  mythic = 272,
}

ns:registerDump("gt", "Gear Tiers", "Gear Tier ilvl info", function(_, out)
  --local gt = ns.data.gearTiers
  out:line("Gear Tier ilvl info:")
  out:line("Explorer: "..gt.explorer)
  out:line("Adventurer: "..gt.adventurer)
  out:line("Veteran: "..gt.veteran)
  out:line("Champion: "..gt.champion)
  out:line("Hero: "..gt.hero)
  out:line("Mythic: "..gt.mythic)
end)