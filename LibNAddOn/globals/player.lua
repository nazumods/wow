---@class LibNAddOn
local ns = select(2, ...)
-- luacheck: globals UnitXP UnitXPMax GetXPExhaustion GetRestState UnitClassBase GetProfessions GetProfessionInfo
-- luacheck: globals GetAverageItemLevel PlayerHasToy UseToy IsSpellKnown C_MountJournal CastSpell UnitExists
-- luacheck: globals UnitHealth UnitHealthMax InCombatLockdown IsResting UnitPower UnitPowerMax UnitPowerType UnitRace
-- luacheck: globals GetShapeshiftFormID UnitIsAFK GetLootSpecialization GetSpecialization GetSpecializationInfo GetSpecializationInfoByID

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

---@class Player
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
  GetPowerPercent = function(self, idx) return math.floor(100 * (self:GetPower(idx) / self:GetPowerMax(idx))).."%" end,
  GetPowerType = function() return UnitPowerType("player") end,
  GetPowerValues = function(self, idx) return self:GetPower(idx), self:GetPowerMax(idx) end,
  -- https://wowpedia.fandom.com/wiki/API_GetShapeshiftFormID (forms, stealth, wolf, stance, etc)
  GetShapeshiftFormID = GetShapeshiftFormID,
  -- id, name, description, icon (FileID), role (DAMAGE | TANK | HEALER, classFile (e.g. PRIEST), className (e.g. Priest)
  GetActiveSpecialization = function() return GetSpecializationInfo(GetSpecialization()) end,
  GetPrimarySpecialization = function() return GetSpecializationInfoByID(GetLootSpecialization()) end,
  GetRace = function()
    local _, raceFile, raceId = UnitRace("player")
    return raceFile, raceId
  end,
  GetXP = function() return UnitXP("player") end,
  GetXPExhaustion = function() return GetXPExhaustion() end,
  GetXPPercent = function(self) return self:GetXP() / self:GetMaxXP() end,
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

function Player:GetRestPercent()
  if not self:isRested() then return 0 end
  local maxXP = self:GetMaxXP()
  return max(0, self:GetXPExhaustion() / maxXP)
end

local Profession = {}
function Profession:GetInfo()
  if not self.id then return nil end
  local name, icon, skillLvl, x, abils, offset, skillID, skillMod, specIdx, specOffset, v = GetProfessionInfo(self.id)
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
    isKhazAlgar = "Khaz Algar Fishing" == v or "Khaz Algar Cooking" == v
  }
end

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

ns:registerCommand("player", nil, function(self, args)
  if args == "" then
    ns.Print("Usage: /lib player <method>")
    for k in pairs(Player) do
      ns.Print("  " .. k)
    end
    return
  end
  if type(Player[args]) == "function" then
    local result = Player[args]()
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
