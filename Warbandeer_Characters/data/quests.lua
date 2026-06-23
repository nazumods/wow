---@type Warbandeer_Characters
local ns = select(2, ...)
local Set = ns.lua.sets.Set
local Values = ns.lua.sets.values
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn

local FIND_LUMBER_SPELL = 1256697

local function HasTrackingSpell(spellId)
  for i = 1, C_Minimap.GetNumTrackingTypes() do
    local t = C_Minimap.GetTrackingInfo(i)
    if t and t.spellID == spellId then return true end
  end
  return false
end

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
    ids = Set{86204},
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
      if not currentValue then return end
      local zone = WWIRepQuestsR[questId]
      if zone and not currentValue[zone] then
        currentValue[zone] = true
        currentValue.missing = (currentValue.missing or 0) - 1
        currentValue.complete = currentValue.missing == 0
      end
    end,
  },
  LumberAxe = {
    get = function(_, _, currentValue)
      return currentValue or HasTrackingSpell(FIND_LUMBER_SPELL)
    end,
    event = "SPELLS_CHANGED",
    eventHandler = function(self)
      self:set(HasTrackingSpell(FIND_LUMBER_SPELL))
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
  -- Achievement 61519 "Midnight Season 1: Catalyst Unbound" (unlock your class set
  -- bonuses). The achievement's `completed` is account-wide, but `wasEarnedByMe`
  -- (13th GetAchievementInfo return) is PER-character — true once THIS character has
  -- earned it. Captured per character so the Catalyst column can show it cross-alt.
  -- Sticky: an earned achievement is never lost.
  CatalystUnbound = {
    get = function(_, _, currentValue)
      return currentValue or (select(13, GetAchievementInfo(61519)) or false)
    end,
    event = "ACHIEVEMENT_EARNED",
    eventHandler = function(self, _, achievementId)
      if achievementId == 61519 then self:set(true) end
    end,
  },
}
