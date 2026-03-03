local _, ns = ...
local Set = ns.lua.sets.Set
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted -- luacheck: globals C_QuestLog

local Dailies = {}

---@type Broker
ns.Daily = ns:RegisterBroker("dailies")
ns.Daily.fields = {
  -- group = {
  --   resetOn = ns.RESET_DAILY,
  --   ids = Set{1, 2},
  --   get = function(self, toon)
  --     local n = 0
  --     for id,_ in pairs(self.ids) do
  --       n = n + (IsQuestFlaggedCompleted(id) and 1 or 0)
  --     end
  --     return n
  --   end,
  --   onComplete = function(toon)
  --     toon.dailies.group = toon.dailies.group + 1
  --   end,
  -- },
}
