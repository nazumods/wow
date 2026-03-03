local _, ns = ...
local ui = ns.ui
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Label = ui.Label

---@type WarbandeerAPI
local api = ns.api

---@type Lists
local lists = ns.lua.lists

---@type Maps
local maps = ns.lua.maps

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- balance of power
-- /run for _,i in ipairs({43496,40668,43517,43514,43518,43519,43520,43521,43522,43527,43523,40673,43525,40675,43524,40678,43526,40603,40608,40613,40672,40614,40615,43528,43898,43531,43530,43532,43533}) do print(i, C_QuestLog.IsQuestFlaggedCompleted(i)) end

-- completed class hall quest lines by class
-- /run local t={-288,-272,3,7,6,0,8,4,9,5,2,1}for i,id in pairs(t) do local _,_,c = GetAchievementCriteriaInfoByID(42565,108648+id)print((GetClassInfo(i)),c and"\124T136814:0\124t"or"\124T136813:0\124t")end

-- mage portal and sheep daily
-- have sheeped it: /run for k,v in pairs{Aszuna=43787,Stormheim=43789,ValSha=43790,Suramar=43791,HighMntn=43788} do print(k,C_QuestLog.IsQuestFlaggedCompleted(v)) end

ns:registerCommand("check", "legion", function()
  local t = api:GetCharacterData()
  if t.classKey == 'Warrior' then
    print('Prot Eligible', C_QuestLog.IsQuestFlaggedCompleted(44311) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Prot Denied', C_QuestLog.IsQuestFlaggedCompleted(44312) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
  elseif t.classKey == 'DeathKnight' then
    local q = C_QuestLog.IsQuestFlaggedCompleted(44188)
    print('Unholy - Special Army of the Dead Summoned:', (q and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r"))
    --print(C_QuestLog.IsQuestFlaggedCompleted(44188) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
  elseif t.classKey == 'Mage' then
    print('Daily Portal Event Roll', C_QuestLog.IsQuestFlaggedCompleted(44384) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Sheep Summon Daily Roll', C_QuestLog.IsQuestFlaggedCompleted(43828) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
  elseif t.classKey == 'Druid' then
    print('Event', C_QuestLog.IsQuestFlaggedCompleted(44326) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Feralas Active', C_QuestLog.IsQuestFlaggedCompleted(44327) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Feralas Touched', C_QuestLog.IsQuestFlaggedCompleted(44331) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Hinterlands Active', C_QuestLog.IsQuestFlaggedCompleted(44328) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Hinterlands Touched', C_QuestLog.IsQuestFlaggedCompleted(44332) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Duskwood Active', C_QuestLog.IsQuestFlaggedCompleted(44329) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
    print('Duskwood Touched', C_QuestLog.IsQuestFlaggedCompleted(44330) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")
  elseif t.classKey == 'Priest' then
    print('Discipline Hidden Appearance Quests:')
    for k,v in ipairs({44339,44340,44341,44342,44343,44344,44345,44346,44347,44348,44349,44350}) do print(format("%s: %s",k,C_QuestLog.IsQuestFlaggedCompleted(v) and "\124cff00ff00Yes\124r" or "\124cffff0000No\124r")) end
  end
end)

local instructions = {
  DeathKnight = {
    Unholy = "Use Army of the Dead",
    Blood = "Withered Army Training",
  },
  Druid = {
    Feral = "Dreamgrove entrance, check for portal emote",
  },
  Mage = {
    Frost = "Order Hall stairs, look for emote",
    Arcane = "Portal into Order Hall, look for sheep emote",
  },
  Monk = {
    Brewmaster = "Tap " .. DARKYELLOW_FONT_COLOR:WrapTextInColorCode("Bubbling Keg") .. " in " .. DARKYELLOW_FONT_COLOR:WrapTextInColorCode("Brewhouse") .. " in Order Hall",
    Mistweaver = "Kill ".. DARKYELLOW_FONT_COLOR:WrapTextInColorCode("Dragons of Nightmare") .. " in " .. DARKYELLOW_FONT_COLOR:WrapTextInColorCode("Emerald Nightmare") .. " raid",
    Windwalker = "Withered Army Training",
  },
  Paladin = {
    Protection = "Withered Army Training",
  },
  Warlock = {
    Affliction = "Collect skulls from " .. DARKYELLOW_FONT_COLOR:WrapTextInColorCode("Danger") .. " World Quests",
  },
  Warrior = {
    Fury = "Valarjar exalted, then skulls from Shar'thos and Nith'ogg, and haft from Skovald",
    Protection = "Path of Huln",
  },
}

local Appearances = Class(TableFrame, function(self)
end, {
  autosize = true,
  padding = 4,
  colBackdrop = TransparentBackdrop,
  colInfo = {
    {},
    {},
    {},
    {},
    {},
    { name = "Dungeon" },
    { name = "WQ" },
    { name = "Kills" },
    { name = "Class Hall" },
  },
})

function Appearances:GetData()
  local data, bc = {}, {}
  local toons = api.GetAllCharacters()
  for _,t in ipairs(toons) do
    if t.artifacts and t.artifacts.hidden and t.artifacts.hiddenColors then
      if bc[t.classKey] == nil then bc[t.classKey] = { specs = {}, wq = 0, dungeon = 0, kills = 0, ch = false } end
      local c = bc[t.classKey]
      for k,v in pairs(t.artifacts.hidden) do
        if c.specs[k] == nil then c.specs[k] = false end
        c.specs[k] = c.specs[k] or v
      end
      c.wq = math.max(c.wq, t.artifacts.hiddenColors.wq.progress)
      c.dungeon = math.max(c.dungeon, t.artifacts.hiddenColors.dungeon.progress)
      c.kills = math.max(c.kills, t.artifacts.hiddenColors.kills.progress)
      c.ch = c.ch or (t.IsLegionTimerunner and t.artifacts.classHall)
    end
  end
  for _,c in ipairs({'DeathKnight', 'DemonHunter', 'Druid', 'Hunter', 'Mage', 'Monk', 'Paladin', 'Priest', 'Rogue', 'Shaman', 'Warlock', 'Warrior'}) do
    if bc[c] ~= nil then
      local s = {{text = c}}
      for k,v in pairs(bc[c].specs) do
        local t = {
          text = k,
          color = v and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
        }
        if (not v) and instructions[c] and instructions[c][k] then
          t.onEnter = function(self)
            ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
            ui.tip:ClearLines()
            ui.tip:AddLine(instructions[c][k])
            ui.tip:Show()
          end
          t.onLeave = function() ui.tip:Hide() end
        end
        table.insert(s, t)
      end
      if #s < 5 then table.insert(s, { text = "" }) end
      if #s < 5 then table.insert(s, { text = "" }) end
      table.insert(s, {
        text = bc[c].dungeon == 30 and 'DONE' or (30 - bc[c].dungeon) .. " left",
        justifyH = ui.justify.Right,
        color = bc[c].dungeon == 30 and DIM_GREEN_FONT_COLOR,
      })
      table.insert(s, {
        text = bc[c].wq == 200 and 'DONE' or (200 - bc[c].wq) .. " left",
        justifyH = ui.justify.Right,
        color = bc[c].wq == 200 and DIM_GREEN_FONT_COLOR,
      })
      table.insert(s, {
        text = bc[c].kills == 1000 and 'DONE' or (1000 - bc[c].kills) .. " left",
        justifyH = ui.justify.Right,
        color = bc[c].kills == 1000 and DIM_GREEN_FONT_COLOR,
      })
      table.insert(s, {
        text = bc[c].ch and 'DONE' or '',
        color = bc[c].ch and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
        justifyH = ui.justify.Center,
      })
      table.insert(data, s)
    end
  end
  return data
end

local achievementIds = {10459, 11160, 11163}

-- Achievements Table
local Achievements = Class(TableFrame, function()
end, {
  colBackdrop = TransparentBackdrop,
  autosize = true,
  headerHeight = 0,
  headerWidth = 0,
  GetData = function(self)
    return ns.lua.maps.map(
      ns.lua.lists.fold(achievementIds, 3),
      function(ids)
        return ns.lua.lists.map(ids, function(achievementId)
          local _, name, _, completed = GetAchievementInfo(achievementId)
          return {
            text = name,
            color = completed and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
            onClick = function()
              OpenAchievementFrameToAchievement(achievementId)
            end,
          }
        end)
      end
    )
  end,
})


---@class Legion: Frame
---@field collected TableFrame
---@field achievements TableFrame
local Legion = Class(Frame, function(self)
  local h = 2

  self.collected = Appearances:new{
    parent = self,
    position = {
      TopLeft = {2, -h},
    },
  }
  h = h + self.collected:Height()

  self.achievements = Achievements:new{
    parent = self,
    position = {
      TopLeft = {self.collected, ui.edge.BottomLeft, 0, -10},
    },
  }
  h = h + self.achievements:Height() + 10

  self:Height(h + 2)
end, {
  name = "legion",
  _title = "Legion",
  onLoad = function(self)
    self:Width(self.collected:Width() + 4)
  end,
})
Legion.name = "legion"
ns.views.Legion = Legion

function Legion:OnBeforeShow()
  self.collected.data = self.collected:GetData()
  self.collected:update()
end
