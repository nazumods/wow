---@type Warbandeer_Characters
local ns = select(2, ...)
-- luacheck: globals C_WeeklyRewards C_MythicPlus
local Set, ValueList, any = ns.lua.sets.Set, ns.lua.lists.values, ns.lua.maps.any
local Player = ns.wow.Player
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local GetActivities = C_WeeklyRewards.GetActivities
local GetOwnedKeystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel

local DMFQuests = {
  Alchemy = 29506,
  Blacksmithing = 29508,
  Cooking = 29509,
  Enchanting = 29510,
  Engineering = 29511,
  Fishing = 29513,
  Herbalism = 29514,
  Inscription = 29515,
  Jewelcrafting = 29516,
  LeatherWorking = 29517,
  Mining = 29518,
  Skinning = 29519,
  Tailoring = 29520,
}

---@class WeeklyBroker: Broker
ns.Weekly = ns:RegisterBroker("weeklies")
ns.Weekly.fields = {
  ---@class WeeklyBroker
  ---@field DMF boolean
  DMF = {
    ids = ValueList(DMFQuests),
    resetOn = ns.RESET_SUNDAY,
    get = function(_, _, current)
      -- Once completed, stay completed until the Sunday reset clears it.
      -- An early/transient read (e.g. quest log not yet populated) returns
      -- false for everything — don't let that wipe a stored completion.
      return any(DMFQuests, function(id)
        return IsQuestFlaggedCompleted(id)
      end) or current
    end,
    -- Capture turn-ins live: without this, a completion is only stored if a
    -- refresh runs before the faire ends and clears the quest flags.
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then self:set(true) end
    end,
  },
  preMidnight = {
    ids = Set{87308,91795},
    resetOn = ns.RESET_WEEKLY,
    get = function(self)
      return {
        eight = IsQuestFlaggedCompleted(87308),
        three = IsQuestFlaggedCompleted(91795)
      }
    end,
    reset = function() return { three = false, eight = false } end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then self:set(self:get())
      end
    end,
  },
  ---@class WeeklyBroker
  ---@field caches integer
  caches = {
    ids = Set{
      93595, 93766, 93769, 88998, 89507, -- Midnight
      --84736, 84737, 84738, 84739, -- WWI cache 1-4 Season 1 & 2
      -- 91175, 91176, 91177, 91178, -- WWI cache 1-4 Season 3
      --82453, -- The Beginning of the End (From Dragon flight??)
      --82355, -- Special Assignment: Cinderbee Surge
      --82679, -- Archives: Seeking History
      --89294, -- Karesh special assignment Aligned Views
      --89293, -- Karesh special assignment
      --85460, -- Ecological Succession Cache 1st completion?
      --87419, -- World Soul Weekly (Delves)
      --91855, -- World Soul Weekly (Karesh World Quests)  looks like these all get flagged completed when one is done.
    },
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(self)
      local n = 0
      for id,_ in pairs(self.ids) do
        n = n + (IsQuestFlaggedCompleted(id) and 1 or 0)
      end
      return n
    end,
    reset = function() return 0 end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, currentValue, questId)
      if self.ids[questId] then
        self:set((currentValue or 0) + 1)
      end
    end,
  },
  ---@class WeeklyBroker
  ---@field vault VaultRewards
  vault = {
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      local rewards = Player:GetRewardOptions()
      -- A transient/early API return can report best == 0; don't wipe
      -- previously-stored vault data — keep the existing value instead.
      if rewards.best > 0 then return rewards end
      return current
    end,
    event = "WEEKLY_REWARDS_UPDATE", -- WEEKLY_REWARDS_ITEM_CHANGED
    eventDelay = 1000,
  },
  ---@class WeeklyBroker
  ---@field hasUnclaimedVault boolean
  hasUnclaimedVault = {
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function() return C_WeeklyRewards.HasAvailableRewards() end,
    -- depends on vault being reset first; safe because "hasUnclaimedVault" < "vault" in fieldOrder
    reset = function(_, toon) return toon.weeklies and toon.weeklies.vault and toon.weeklies.vault.best > 0 end,
    event = "WEEKLY_REWARDS_UPDATE",
    eventDelay = 1000,
  },
  ---@class WeeklyBroker
  ---@field keystone integer? current keystone level, nil if none
  keystone = {
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function()
      return GetOwnedKeystoneLevel()  -- MayReturnNothing: nil when no keystone
    end,
    event = "CHALLENGE_MODE_COMPLETED",
  },
  ---@class WeeklyBroker
  ---@field dungeons {done: integer, max: integer}? M+ runs done and vault max threshold
  dungeons = {
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(_, _, current)
      local activities = GetActivities()
      -- transient/early API return — keep existing data rather than wiping
      if not activities then return current end
      local done, maxThreshold = 0, 0
      for _, a in ipairs(activities) do
        if a.type == 1 then  -- Enum.WeeklyRewardChestThresholdType.Activities (M+ dungeons)
          done = a.progress
          if a.threshold > maxThreshold then maxThreshold = a.threshold end
        end
      end
      return done > 0 and { done = done, max = maxThreshold } or nil
    end,
    event = "CHALLENGE_MODE_COMPLETED",
    eventDelay = 2000,
  },
}

ns:registerCommand("dump", "m+", function(self)
  local ks = self.currentData.weeklies.keystone
  local dg = self.currentData.weeklies.dungeons
  ns.Print("Keystone: " .. (ks and ("+"..ks) or "none"))
  if dg then
    ns.Print("Dungeons: " .. dg.done .. "/" .. dg.max)
  else
    ns.Print("Dungeons: 0")
  end
end)

ns:registerCommand("dump", "vault", function(self)
  ---@type VaultRewards
  local vault = self.currentData.weeklies.vault
  if not vault or vault.best <= 0 then
    ns.Print("No current vault data.")
    return
  end

  ns.Print("Vault Rewards: " .. vault.best)
  for ilvl,count in pairs(vault.counts) do
    print(ilvl .. " x " .. count)
  end

  for k,v in pairs(vault.progress) do
    print(k, ": " .. v.progress .. "/" .. v.max)
  end
end)
