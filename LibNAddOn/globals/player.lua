---@class LibNAddOn
local ns = select(2, ...)

local Mixin, max = Mixin, math.max
local UnitXP, UnitXPMax, GetXPExhaustion, GetRestState = UnitXP, UnitXPMax, GetXPExhaustion, GetRestState
local UnitClassBase, GetAverageItemLevel = UnitClassBase, GetAverageItemLevel
local GetProfessions, GetProfessionInfo = GetProfessions, GetProfessionInfo
local UnitHealth, UnitHealthMax, UnitExists, UnitIsAFK = UnitHealth, UnitHealthMax, UnitExists, UnitIsAFK
local UnitPower, UnitPowerMax, UnitPowerType, UnitRace = UnitPower, UnitPowerMax, UnitPowerType, UnitRace
local InCombatLockdown, IsResting, GetShapeshiftFormID = InCombatLockdown, IsResting, GetShapeshiftFormID
local GetInventoryItemID = GetInventoryItemID
local ContainerIDToInventoryID = C_Container.ContainerIDToInventoryID
local GetActivities = C_WeeklyRewards.GetActivities
local GetExampleRewardItemHyperlinks = C_WeeklyRewards.GetExampleRewardItemHyperlinks
local GetDetailedItemLevelInfo = C_Item.GetDetailedItemLevelInfo
local UnitLevel, UnitName = UnitLevel, UnitName

local wow = ns.wow

---Static helpers for the current player ("player" unit). Members defined in the
---table literal below are plain WoW API wrappers; typed here so callers get
---param/return info.
---@class Player
---@field Cast fun(spellIndex: number, bookType: string?) cast a spell by spellbook slot
---@field GetAverageItemLevel fun(): integer overall ilvl, floored
---@field GetClassId fun(): integer
---@field GetClassName fun(self: Player): string localized class name
---@field GetHealth fun(): number
---@field GetHealthMax fun(): number
---@field GetHealthPercent fun(self: Player): string e.g. "85%"
---@field GetHealthValues fun(self: Player): number, number, string health, max, percent
---@field GetLevel fun(): number
---@field GetMaxXP fun(): number
---@field GetMountIcon fun(id: number): number? icon FileID
---@field GetName fun(): string
---@field GetPetHealthValues fun(): number, number pet health, max
---@field GetPower fun(self: Player, idx: number?): number
---@field GetPowerMax fun(self: Player, idx: number?): number
---@field GetPowerPercent fun(self: Player, idx: number?): string e.g. "85%"
---@field GetPowerType fun(): number, string powerType enum, token (e.g. "MANA")
---@field GetPowerValues fun(self: Player, idx: number?): number, number power, max
---@field GetShapeshiftFormID fun(): number? form/stance/stealth ID, nil when not shifted
---@field GetActiveSpecialization fun(): number, string, string, number, string, string, string id, name, description, icon, role, classFile, className
---@field GetPrimarySpecialization fun(): number, string, string, number, string, string, string id, name, description, icon, role, classFile, className (loot spec)
---@field GetRace fun(): string, number raceFile, raceId
---@field GetXP fun(): number
---@field GetXPExhaustion fun(): number? rested bonus XP remaining, nil if none
---@field GetXPPercent fun(self: Player): number 0-1 fraction of the level
---@field HasTarget fun(): boolean
---@field HasToy fun(toyId: number): boolean
---@field InCombat fun(): boolean
---@field IsAFK fun(): boolean
---@field isMaxLevel fun(self: Player): boolean
---@field isRested fun(): boolean
---@field IsResting fun(): boolean
---@field IsMountUsable fun(id: number): boolean
---@field IsMountCollected fun(id: number): boolean
---@field IsSpellKnown fun(spellId: number, isPet: boolean?): boolean
---@field Mount fun(mountId: number) summon a mount by ID
---@field UseToy fun(toyId: number)
---@field bags { ItemID: fun(slot: number): number? } bag helpers (slot is a container ID)
local Player = {
  Cast = CastSpell,
  GetAverageItemLevel = function() local _, ilvl = GetAverageItemLevel(); return math.floor(ilvl) end,
  GetClassId = function() local _, classId = UnitClassBase("player"); return classId end,
  GetClassName = function(self) return GetClassInfo(self:GetClassId()) end,
  GetHealth = function() return UnitHealth("player") end,
  GetHealthMax = function() return UnitHealthMax("player") end,
  GetHealthPercent = function(self) return math.floor(100 * (self:GetHealth() / self:GetHealthMax())).."%" end,
  GetHealthValues = function(self) return self:GetHealth(), self:GetHealthMax(), self:GetHealthPercent() end,
  GetLevel = function() return UnitLevel("player") end,
  GetMaxXP = function() return UnitXPMax("player") end,
  GetMountIcon = function(id)
    local _, _, icon = C_MountJournal.GetMountInfoByID(id)
    return icon
  end,
  GetName = function() return UnitName("player") end,
  GetPetHealthValues = function() return UnitHealth("pet"), UnitHealthMax("pet") end,
  GetPower = function(self, idx) return UnitPower("player", idx) end,
  GetPowerMax = function(self, idx) return UnitPowerMax("player", idx) end,
  GetPowerPercent = function(self, idx)
    local m = self:GetPowerMax(idx)
    if m == 0 then return "0%" end  -- power types with no max would divide to nan
    return math.floor(100 * (self:GetPower(idx) / m)).."%"
  end,
  GetPowerType = function() return UnitPowerType("player") end,
  GetPowerValues = function(self, idx) return self:GetPower(idx), self:GetPowerMax(idx) end,
  -- https://wowpedia.fandom.com/wiki/API_GetShapeshiftFormID (forms, stealth, wolf, stance, etc)
  GetShapeshiftFormID = GetShapeshiftFormID,
  -- id, name, description, icon (FileID), role (DAMAGE | TANK | HEALER, classFile (e.g. PRIEST), className (e.g. Priest)
  GetActiveSpecialization = function()
    local spec = GetSpecialization()
    if not spec then return end  -- no active spec yet (e.g. very early login)
    return GetSpecializationInfo(spec)
  end,
  GetPrimarySpecialization = function() return GetSpecializationInfoByID(GetLootSpecialization()) end,
  GetRace = function()
    local _, raceFile, raceId = UnitRace("player")
    return raceFile, raceId
  end,
  GetXP = function() return UnitXP("player") end,
  GetXPExhaustion = function() return GetXPExhaustion() end,
  GetXPPercent = function(self)
    local m = self:GetMaxXP()
    if m == 0 then return 0 end  -- at max level GetMaxXP is 0 -> avoid 0/0 = nan
    return self:GetXP() / m
  end,
  HasTarget = function() return UnitExists("target") end,
  HasToy = PlayerHasToy,
  InCombat = InCombatLockdown,
  IsAFK = function() return UnitIsAFK("player") end,
  isMaxLevel = function(self) return self:GetLevel() == wow.maxLevel end,
  isRested = function() return 1 == GetRestState() end,
  IsResting = IsResting,
  IsMountUsable = function(id)
    local _, _, _, _, usable = C_MountJournal.GetMountInfoByID(id)
    return usable
  end,
  IsMountCollected = function(id)
    local _, _, _, _, _, _, _, _, _, _, collected = C_MountJournal.GetMountInfoByID(id)
    return collected
  end,
  IsSpellKnown = IsSpellKnown,
  Mount = C_MountJournal.SummonByID,
  UseToy = UseToy,

  bags = {
    ItemID = function(slot)
      return GetInventoryItemID("player", ContainerIDToInventoryID(slot))
    end,
  },
}
ns.wow.Player = Player

---Rested bonus XP as a fraction of the current level's max XP (0 if not rested).
---@return number
function Player:GetRestPercent()
  if not self:isRested() then return 0 end
  local maxXP = self:GetMaxXP()
  if maxXP == 0 then return 0 end  -- at max level GetMaxXP is 0 -> avoid 0/0 = nan
  return max(0, self:GetXPExhaustion() / maxXP)
end

---@class ProfessionInfo
---@field id integer profession index (as returned by GetProfessions)
---@field name string
---@field icon number icon FileID
---@field skillLevel integer current skill level
---@field maxSkill integer max skill level
---@field skillID integer trade skill line ID
---@field skillMod integer skill modifier from gear/buffs
---@field numAbilities integer number of spellbook abilities
---@field spellOffset integer spellbook offset of the first ability
---@field specializationIndex integer
---@field specializationOffset integer

---One profession slot; `id` is nil when the slot is unlearned.
---@class Profession
---@field id integer? profession index, or nil if not learned
---@field GetInfo fun(self: Profession): ProfessionInfo?
local Profession = {}
---Detailed info for this profession, or nil if the slot is unlearned.
---@return ProfessionInfo?
function Profession:GetInfo()
  if not self.id then return nil end
  local name, icon, skillLvl, x, abils, offset, skillID, skillMod, specIdx, specOffset = GetProfessionInfo(self.id)
  return {
    id = self.id,
    name = name,
    icon = icon,
    skillLevel = skillLvl,
    maxSkill = x,
    skillID = skillID,
    skillMod = skillMod,
    numAbilities = abils,
    spellOffset = offset,
    specializationIndex = specIdx,
    specializationOffset = specOffset,
  }
end

---All five profession slots as Profession objects (id is nil for unlearned slots).
---@return { prof1: Profession, prof2: Profession, archaeology: Profession, fishing: Profession, cooking: Profession }
function Player:GetProfessions()
  local prof1, prof2, arch, fishing, cooking = GetProfessions()
  return {
    prof1 = Mixin({id = prof1}, Profession),
    prof2 = Mixin({id = prof2}, Profession),
    archaeology = Mixin({id = arch}, Profession),
    fishing = Mixin({id = fishing}, Profession),
    cooking = Mixin({id = cooking}, Profession),
  }
end

local ACTIVITY_TYPES = {
  [1] = "Dungeons",
  [3] = "Raid",
  [6] = "World"
}

ns.wow.GreatVault = {}
---Aggregate this week's Great Vault reward options by activity type.
---@return table rewards currently always empty (reserved)
---@return table<number, integer> counts reward count per item level
---@return table<string, { complete: integer, progress: integer, max: integer }> progress per activity type ("Dungeons"/"Raid"/"World")
---@return number best highest reward item level
---@return integer bestN number of rewards at the best item level
function ns.wow.GreatVault.getRewardOptions()
  local rewards = {}
  local counts = {}
  local progress = {}
  local best = 0
  local bestN = 0
  -- https://warcraft.wiki.gg/wiki/API_C_WeeklyRewards.GetActivities
  local activities = GetActivities()
  for _,activity in ipairs(activities) do
    local type = ACTIVITY_TYPES[activity.type]
    if type then
      if not progress[type] then progress[type] = { complete = 0, progress = 0, max = 0 } end
      local complete = activity.progress >= activity.threshold
      progress[type].progress = activity.progress
      progress[type].max = max(progress[type].max, activity.threshold)
      if complete then
        progress[type].complete = progress[type].complete + 1
        local link = GetExampleRewardItemHyperlinks(activity.id)
        if link then
          local ilvl = GetDetailedItemLevelInfo(link)
          if ilvl then
            if not counts[ilvl] then
              counts[ilvl] = 1
            else
              counts[ilvl] = counts[ilvl] + 1
            end
            if ilvl > best then
              best = ilvl
              bestN = 1
            elseif ilvl == best then
              bestN = bestN + 1
            end
          end
        end
      end
    end
  end
  return rewards, counts, progress, best, bestN
end

---@class VaultRewards
---@field rewards {}
---@field counts table<integer, integer> Map of iLVL to count of that iLVL rewards
---@field progress table<string, { complete: integer, progress: integer, max: integer }>
---@field best integer iLVL of best reward
---@field bestN integer Count of best iLVL rewards

---@class Player
---@field GetRewardOptions fun(): VaultRewards
function Player:GetRewardOptions()
  local rewards, counts, progress, best, bestN = ns.wow.GreatVault.getRewardOptions()
  return {
    rewards = rewards,
    counts = counts,
    progress = progress,
    best = best,
    bestN = bestN,
  }
end

ns:registerCommand("player", "", function(self, args)
  if args == "" then
    ns.Print("Usage: /lib player <method>")
    for k in pairs(Player) do
      ns.Print("  " .. k)
    end
    return
  end
  if type(Player[args]) == "function" then
    local result = Player[args](Player)
    if type(result) == "table" then
      ns.Print(args..":")
      for k,v in pairs(result) do
        print(k, v)
      end
    else
      ns.Print(args..":", result)
    end
  else
    ns.Print(args..":", Player[args])
  end
end, "Dump info about the current player")
