local _, ns = ...
local IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted

---@type Maps
local maps = ns.lua.maps

local data = {}

---@class Progress
---@field progress integer
---@field goal integer

---@class Character
---@field artifacts ArtifactBroker

---@class ArtifactBroker: Broker
ns.Artifacts = ns:RegisterBroker("artifacts")

ns.Artifacts.fields = {
  ---@class ArtifactBroker
  ---@field hidden { SpecializationKey: boolean }
  hidden = {
    get = function(_, toon)
      return data[toon.classKey] and maps.map(data[toon.classKey], function(v)
        return IsQuestFlaggedCompleted(v.hidden)
      end)
    end,
    event = "QUEST_TURNED_IN",
  },

  ---@class ArtifactBroker
  ---@field hiddenColors { wq: Progress, dungeon: Progress, kills: Progress }
  hiddenColors = {
    ids = {wq = 11153, dungeon = 11152, kills = 11154},
    get = function(self, toon)
      -- Evokers don't have class hall
      if toon.classId == 13 then return { goal = 0, progress = 0 } end
      return maps.map(self.ids, function(v)
        local _, _, _, a, g = GetAchievementCriteriaInfo(v, 1)
        return { goal = g, progress = a }
      end)
    end,
    event = "QUEST_TURNED_IN",
  },

  classHall = {
    data = {-288,-272,3,7,6,0,8,4,9,5,2,1},
    get = function(self, toon)
      -- Evokers don't have class hall
      if toon.classId == 13 then return false end
      local _, _, completed = GetAchievementCriteriaInfoByID(42565,108648 + self.data[toon.classId])
      return completed
    end,
    event = "QUEST_TURNED_IN",
  },
}

ns:registerCommand("dump", "artifact", function()
  local t = ns.currentData
  ns.Print("Artifact hidden")
  for k,v in pairs(t.artifacts.hidden) do
    ns.Print(k, v and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
  end
  local _, _, _, a, g = GetAchievementCriteriaInfo(11152, 1)
  print("Dungeon", a, g)
  local _, _, _, a, g = GetAchievementCriteriaInfo(11153, 1)
  print("WQ", a, g)
  local _, _, _, a, g = GetAchievementCriteriaInfo(11154, 1)
  print("Kills", a, g)
end)

data.DeathKnight = {
  Blood = { hidden = 43646, },
  Frost = { hidden = 43647, },
  Unholy = { hidden = 43648, },
}

data.DemonHunter = {
  Havoc = { hidden = 43649, },
  Vengeance = { hidden = 43650, },
}

data.Druid = {
  Balance = { hidden = 43651, },
  Feral = { hidden = 43652, },
  Guardian = { hidden = 43653, },
  Restoration = { hidden = 43654, },
}

data.Hunter = {
  BeastMastery = { hidden = 43655, },
  Marksman = { hidden = 43656, },
  Survival = { hidden = 43657, },
}

data.Mage = {
  Arcane = { hidden = 43658, },
  Fire = { hidden = 43659, },
  Frost = { hidden = 43660, },
}

data.Monk = {
  Brewmaster = { hidden = 43661, },
  Mistweaver = { hidden = 43662, },
  Windwalker = { hidden = 43663, },
}

data.Paladin = {
  Holy = { hidden = 43664, },
  Protection = { hidden = 43665, },
  Retribution = { hidden = 43666, }
}

data.Priest = {
  Discipline = { hidden = 43667, },
  Holy = { hidden = 43668, },
  Shadow = { hidden = 43669, },
}

data.Rogue = {
  Assassination = { hidden = 43670, },
  Outlaw = { hidden = 43671, },
  Subtlety = { hidden = 43672, },
}

data.Shaman = {
  Elemental = { hidden = 43673, },
  Enhancement = { hidden = 43674, },
  Restoration = { hidden = 43675, },
}

data.Warlock = {
  Affliction = { hidden = 43676, },
  Demonology = { hidden = 43677, },
  Destruction = { hidden = 43678, },
}

data.Warrior = {
  Arms = { hidden = 43679, },
  Fury = { hidden = 43680, },
  Protection = { hidden = 43681, },
}
