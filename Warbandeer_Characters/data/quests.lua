local _, ns = ...
local Set = ns.lua.sets.Set
local Values = ns.lua.sets.values
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted

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
}

function ns:QUEST_TURNED_IN(questId)
  ns.Print("quest turned in " .. questId)
end
ns:registerEvent("QUEST_TURNED_IN")
