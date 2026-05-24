local _, ns = ...
local Set = ns.lua.sets.Set
local Values = ns.lua.sets.values
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local IsOnQuest = C_QuestLog.IsOnQuest
local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn

local LUMBER_AXE_QUEST = 93647 -- Lumber For You

local WWIRepQuests = {
  Dornogal   = 82362,
  Assembly   = 82385,
  Hallowfall = 82407,
  Azjkahet   = 82446,
  Undermine  = 85827,
  Arathi     = 89400,
  Karesh     = 90667,
}
local WWIRepQuestsR = tInvert(WWIRepQuests)

-- Delve introduction quests (one-time per character). Add entries as discovered.
local DelveQuests = {
  ["Shadow Enclave"]      = 93372,
  ["Collegiate Calamity"] = 93384,
  ["The Darkway"]         = 93385,
  ["Parhelion Plaza"]     = 93386,
  ["Atal'Aman"]           = 93409,
  ["Twilight Crypts"]     = 93410,
  ["The Gulf of Memory"]  = 93416,
  ["The Grudge Pit"]      = 93421,
  ["Sunkiller Sanctum"]   = 93427,
  ["Shadowguard Point"]   = 93428,
}

---@type Broker
ns.Quests = ns:RegisterBroker("quests")
ns.Quests.fields = {
  UndermineStoryMode = {
    ids = Set{q=86204},
    maxLevel = true,
    get = function(_, _, currentValue)
      return currentValue or IsQuestFlaggedCompleted(86204)
    end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, _, questId)
      if self.ids[questId] then
        self:set(true)
      end
    end,
  },
  WWIRep = {
    ids = Values(WWIRepQuests),
    maxLevel = true,
    get = function()
      local d = { complete = true, missing = 0 }
      for zone,id in pairs(WWIRepQuests) do
        d[zone] = IsQuestFlaggedCompleted(id)
        d.complete = d.complete and d[zone]
        if not d[zone] then d.missing = d.missing + 1 end
      end
      return d
    end,
    event = "QUEST_TURNED_IN",
    eventHandler = function(self, currentValue, questId)
      if not self.ids[questId] then return end
      currentValue.missing = currentValue.missing and (currentValue.missing - 1) or 0
      currentValue.complete = currentValue.missing == 0
      local zone = WWIRepQuestsR[questId]
      if zone ~= nil then
        currentValue[zone] = true
      end
    end,
  },
  LumberAxe = {
    get = function(_, _, currentValue)
      return currentValue or IsQuestFlaggedCompleted(LUMBER_AXE_QUEST) or IsOnQuest(LUMBER_AXE_QUEST) or false
    end,
    event = {"QUEST_ACCEPTED", "QUEST_TURNED_IN"},
    eventHandler = function(self, _, questId)
      if questId == LUMBER_AXE_QUEST then
        self:set(true)
      end
    end,
  },
  delves = {
    ids = Values(DelveQuests),
    get = function()
      local d = { complete = true, missing = 0 }
      for label,id in pairs(DelveQuests) do
        local done = IsQuestFlaggedCompleted(id) or ReadyForTurnIn(id) or false
        d[label] = done
        d.complete = d.complete and done
        if not done then d.missing = d.missing + 1 end
      end
      return d
    end,
    event = {"QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED"},
  },
}

function ns:QUEST_TURNED_IN(questId)
  ns.Print("quest turned in " .. questId)
end
ns:registerEvent("QUEST_TURNED_IN")
