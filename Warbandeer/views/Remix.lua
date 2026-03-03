local _, ns = ...
local insert = table.insert
local ui = ns.ui
local Class, Frame, TableFrame, Texture, Label = ns.lua.Class, ui.Frame, ui.TableFrame, ui.Texture, ui.Label
local GetMajorFactionData, GetFactionDataByID = C_MajorFactions.GetMajorFactionData, C_Reputation.GetFactionDataByID
local GetRenownLevels, IsFactionParagon = C_MajorFactions.GetRenownLevels, C_Reputation.IsFactionParagon

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- Table of characters
local Characters = Class(TableFrame, function(self)
  local toons = self:GetCharacters()

  self.data = {}
  -- todo: track longest toon name
  for _, toon in ipairs(toons) do
    self:addRow({backdrop = TransparentBackdrop})
    insert(self.data, self:GetRowData(toon))
  end
end, {
  name = "characters",
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width =  20, backdrop = TransparentBackdrop},
    {width = 100, backdrop = TransparentBackdrop},
    {width =  30, backdrop = TransparentBackdrop},
    {width =  30, backdrop = TransparentBackdrop},
  },
})

function Characters:GetCharacters()
  local toons = ns.api.GetAllCharacters()
  toons = ns.lua.lists.filter(toons, function(t) return t.IsLegionTimerunner end)
  table.sort(toons, function (c1, c2)
    if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
    if c1.equipment.ilvl ~= c2.equipment.ilvl then return c1.equipment.ilvl > c2.equipment.ilvl end
    return c1.name < c2.name
  end)
  return toons
end

function Characters:GetRowData(toon)
  return {
    {
      text = toon.basic.level,
      color = NORMAL_FONT_COLOR,
    },
    {
      text = toon.name,
      color = ns.Colors[toon.classKey]
    },
    {
      text = ns.IlvlColor(toon.equipment.ilvl),
      justifyH = ui.justify.Right,
    },
    {
      text = toon.basic.remix and toon.basic.remix.unbound or 0,
      justifyH = ui.justify.Right,
      color = toon.basic.remix and toon.basic.remix.unbound > 0 and NORMAL_FONT_COLOR or DIM_RED_FONT_COLOR,
    },
  }
end

function Characters:Refresh()
  local toons = self:GetCharacters()
  for i,t in ipairs(toons) do
    self.data[i] = self:GetRowData(t)
  end
  self:update()
end

local FACTIONS = {
  2170, -- Argussian Reach
  2045, -- Armies of Legionfall
  2165, -- Army of the Light
  1900, -- Court of Farondis
  1883, -- Dreamweavers
  1828, -- Highmountain Tribe
  1859, -- The Nightfallen
  1894, -- The Wardens
  1948, -- Valarjar
}
-- table of reputations and their progress
local Factions = Class(TableFrame, function(self)
  self.data = {}
  for _, factionID in ipairs(FACTIONS) do
    local info = GetFactionDataByID(factionID)
    local done = IsFactionParagon(factionID)
    self:addRow({backdrop = TransparentBackdrop})
    insert(self.data, {
      {
        text = info.name,
        -- color = info.factionFontColor.color,
      },
      {
        text = done and "complete" or (info.currentStanding .. " / " .. ns.data.minorFactionMaxStanding[factionID]),
        color = done and DIM_GREEN_FONT_COLOR,
        justifyH = ui.justify.Right,
      },
    })
  end
end, {
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 150, backdrop = TransparentBackdrop},
    {width = 100, backdrop = TransparentBackdrop},
  },
})

local achievementIds = ns.lua.lists.fold({
  42313, -- Intro

  61108, -- Lorerunner
  61111,
  61109,
  61110,
  61112,
  42537, -- Insurrection
  42647, -- Breaching the Tomb

  61115, -- dungeons
  61114,
  61113,
  60854, -- kara
  60855,
  60850, -- cathedral

  42688, -- keystone
  42689,

  60859, -- raids
  60860,
  60865,
  60870,
  61075,

  61076, -- world bosses
  61080,

  42555, -- world quests
  42674,
  61070, -- heroic
  42673, -- defending the isles
  42672,
  42675,
  61072, -- heroic obelisks

  61053, -- legionslayer

  42314, -- unlimited power
  42315,
  42505,
  42506,
  42507,
  42508,
  42509,
  42510,
  42511,
  42512,
  42513,
  42514,
}, 15)

local Achievements = Class(TableFrame, function(self)
  self.data = ns.lua.maps.map(
    achievementIds,
    function(achievementIds)
      return ns.lua.lists.map(achievementIds, function(achievementId)
        local _, name, _, completed = GetAchievementInfo(achievementId)
        if achievementId == 41818 then
          local _, _, _, completedH = GetAchievementInfo(41820)
          completed = completed or completedH
        end
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
end, {
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 250, backdrop = TransparentBackdrop},
    {width = 250, backdrop = TransparentBackdrop},
    {width = 250, backdrop = TransparentBackdrop},
  },
  rowInfo = ns.lua.maps.map(
    achievementIds,
    function() return {backdrop = TransparentBackdrop} end
  ),
})

-- Remix View
local Remix = Class(Frame, function(self)
  self.characters = Characters:new{
    parent = self,
    position = {
      TopLeft = {5, -5},
    },
  }
  self.factions = Factions:new{
    parent = self,
    position = {
      TopLeft = {self.characters, ui.edge.TopRight, 20, 0},
    },
  }
  self.achievements = Achievements:new{
    parent = self,
    position = {
      TopLeft = {self.factions, ui.edge.TopRight, 20, 0},
    },
  }

  self:Height(20 + math.max(self.characters:Height(), self.factions:Height(), self.achievements:Height()))
  self:Width(10 + 40 + self.characters:Width() + self.factions:Width() + self.achievements:Width())
end, {
  name = "remix",
  _title = "Remix",
})
Remix.name = "remix"
ns.views.Remix = Remix

function Remix:OnBeforeShow()
  self.characters:Refresh()
end
