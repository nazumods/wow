local _, ns = ...
local Set, ValueList, any, anyKey = ns.lua.sets.Set, ns.lua.lists.values, ns.lua.maps.any, ns.lua.maps.anyKey
local Player = ns.wow.Player
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted

local DMFQuests = {
  Alchemy = 29506,
  Blacksmithing = 29508,
  Cooking = 29509,
  Enchanting = 29510,
  Engineering = 29511,
  Fishing = 29513,
  Herbalism = 25914,
  Inscription = 29515,
  Jewelcrafting = 29516,
  LeatherWorking = 29517,
  Mining = 29518,
  Skinning = 29519,
  Tailoring = 25920,
}

---@class WeeklyBroker: Broker
ns.Weekly = ns:RegisterBroker("weeklies")
ns.Weekly.fields = {
  ---@class WeeklyBroker
  ---@field DMF boolean
  DMF = {
    ids = ValueList(DMFQuests),
    resetOn = ns.RESET_SUNDAY,
    get = function()
      return any(DMFQuests, function(id)
        return IsQuestFlaggedCompleted(id)
      end)
    end,
  },
  ---@class WeeklyBroker
  ---@field theater boolean
  theater = {
    ids = Set{83240},
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function(self)
      return anyKey(self.ids, function(id) return IsQuestFlaggedCompleted(id) end)
    end,
    reset = function() return false end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then
        self:set(true)
      end
    end,
  },
  preMidnight = {
    ids = Set{87308,91795},
    --maxLevel = true,
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
      --84736, 84737, 84738, 84739, -- cache 1-4 Season 1 & 2
      91175, 91176, 91177, 91178, -- cache 1-4 Season 3
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
        self:set(currentValue + 1)
      end
    end,
  },
  ---@class WeeklyBroker
  ---@field vault { rewards: integer, counts: integer, best: integer, bestN: integer }
  vault = {
    maxLevel = true,
    resetOn = ns.RESET_WEEKLY,
    get = function()
      local rewards = Player:GetRewardOptions()
      return rewards.best > 0 and rewards or nil
    end,
    event = "WEEKLY_REWARDS_UPDATE", -- WEEKLY_REWARDS_ITEM_CHANGED
    eventDelay = 1000,
  },
}
