local _, ns = ...
local insert = table.insert
local ui = ns.ui
local Class, Frame, TableFrame, TabFrame, Texture, Label = ns.lua.Class, ui.Frame, ui.TableFrame, ui.TabFrame, ui.Texture, ui.Label
local GetMajorFactionIDs = C_MajorFactions.GetMajorFactionIDs
local GetMajorFactionData, GetFactionDataByID = C_MajorFactions.GetMajorFactionData, C_Reputation.GetFactionDataByID
local GetRenownLevels, IsFactionParagon = C_MajorFactions.GetRenownLevels, C_Reputation.IsFactionParagon
local GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation
local GetFriendshipReputationRanks = C_GossipInfo.GetFriendshipReputationRanks

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- table of reputations for a given expansion level
local Factions = Class(TableFrame, function(self)
  self.data = {}
  local seen = {}

  local function addFaction(factionID)
    local info = GetMajorFactionData(factionID)
    if info and info.name and info.name ~= "" then
      local levels = GetRenownLevels(factionID)
      local maxLevel = info.maxLevel or (levels and levels[#levels] and levels[#levels].level)
      local done = maxLevel ~= nil and info.renownLevel == maxLevel
      local nameColor = info.factionFontColor and info.factionFontColor.color
      if nameColor and nameColor.a == 0 then nameColor.a = 100 end
      self:addRow({backdrop = TransparentBackdrop})
      insert(self.data, {
        {text = info.name, color = nameColor},
        {
          text = done and "complete" or (info.renownLevel .. " / " .. (maxLevel or "?")),
          color = done and DIM_GREEN_FONT_COLOR or nameColor,
          justifyH = ui.justify.Right,
        },
      })

      if ns.data.minorFactions[factionID] then
        for _, subFactionID in ipairs(ns.data.minorFactions[factionID]) do
          local subMajorInfo = GetMajorFactionData(subFactionID)
          local subDone, subText, subName
          if subMajorInfo and subMajorInfo.renownLevel ~= nil then
            -- standard major faction (GetMajorFactionData works)
            subDone = subMajorInfo.maxLevel and (subMajorInfo.renownLevel == subMajorInfo.maxLevel)
            local subMax = subMajorInfo.maxLevel
            if not subMax then
              local subLevels = GetRenownLevels(subFactionID)
              subMax = subLevels and subLevels[#subLevels] and subLevels[#subLevels].level
            end
            subText = subDone and "complete" or (subMajorInfo.renownLevel .. " / " .. (subMax or "?"))
            subName = subMajorInfo.name
          else
            local friendInfo = GetFriendshipReputation(subFactionID)
            local rankInfo = friendInfo and friendInfo.friendshipFactionID
                             and friendInfo.friendshipFactionID > 0
                             and GetFriendshipReputationRanks(friendInfo.friendshipFactionID)
            if rankInfo and rankInfo.maxLevel > 1 then
              -- friendship reputation with real levels (e.g. Valeera — level 1-60)
              subDone = rankInfo.currentLevel >= rankInfo.maxLevel
              subText = subDone and "complete" or (rankInfo.currentLevel .. " / " .. rankInfo.maxLevel)
              subName = friendInfo.name
            else
              -- standard reputation: show progress within current tier
              local subInfo = GetFactionDataByID(subFactionID)
              subDone = subInfo.reaction >= 8
              if subDone then
                subText = "complete"
              else
                local progress = subInfo.currentStanding - (subInfo.currentReactionThreshold or 0)
                local tierSize = (subInfo.nextReactionThreshold or 0) - (subInfo.currentReactionThreshold or 0)
                subText = tierSize > 0 and (progress .. " / " .. tierSize) or tostring(subInfo.currentStanding)
              end
              subName = subInfo.name
            end
          end
          self:addRow({backdrop = TransparentBackdrop})
          insert(self.data, {
            {text = "  " .. subName, color = nameColor},
            {
              text = subText,
              color = subDone and DIM_GREEN_FONT_COLOR or nameColor,
              justifyH = ui.justify.Right,
            },
          })
        end
      end
    end
  end

  for _, factionID in ipairs(GetMajorFactionIDs(self.expansionLevel)) do
    seen[factionID] = true
    addFaction(factionID)
  end
  for _, factionID in ipairs(self.extraFactionIDs) do
    if not seen[factionID] then
      addFaction(factionID)
    end
  end
end, {
  expansionLevel = 10,  -- LE_EXPANSION_THE_WAR_WITHIN
  extraFactionIDs = {},
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 190, backdrop = TransparentBackdrop},
    {width = 90, backdrop = TransparentBackdrop},
  },
})

-- Table of top toon per class
local TopAlts = Class(TableFrame, function(self)
  -- fit col 2 to the widest name
  local w = 0
  for _, r in ipairs(self.cells) do
    if r[2] and r[2].label then
      w = max(w, r[2].label._widget:GetUnboundedStringWidth())
    end
  end
  if w > 0 then
    local delta = w - self.cols[2]:Width()
    self.cols[2]:Width(w)
    self.rowArea:Width(self.rowArea:Width() + delta)
    self:Width(self:Width() + delta)
  end
end, {
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 20, backdrop = TransparentBackdrop},
    {width = 100, backdrop = TransparentBackdrop},
    {width = 30, backdrop = TransparentBackdrop},
  },
  GetData = function(self)
    local toons = ns.api.GetAllCharacters()
    local top = {}
    for _, toon in pairs(toons) do
      if not top[toon.classKey] or
        toon.basic.level > top[toon.classKey].basic.level or
        (toon.basic.level == top[toon.classKey].basic.level and toon.equipment.ilvl > top[toon.classKey].equipment.ilvl)
      then
        top[toon.classKey] = toon
      end
    end
    top = ns.lua.lists.values(top)
    table.sort(top, function (c1, c2)
      if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
      if c1.equipment.ilvl ~= c2.equipment.ilvl then return c1.equipment.ilvl > c2.equipment.ilvl end
      return c1.name < c2.name
    end)
    local data = {}
    for _, toon in ipairs(top) do
      self:addRow({backdrop = TransparentBackdrop})
      insert(data, {
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
      })
    end
    return data
  end,
})

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    TopLeft = {3, -2},
    BottomRight = {-3, 2},
  },
}

local wwiAchievementIds     = {20597, 40791, 20596, 40309, 40360, 41052, 40618, 41818, 41970, 41808, 61017}
local midnightAchievementIds = {61839}

local Achievements = Class(TableFrame, function(self)
  self.data = {}
  for _, achievementId in ipairs(self.achievementIds) do
    self:addRow({backdrop = TransparentBackdrop})
    local _, name, _, completed = GetAchievementInfo(achievementId)
    if achievementId == 41818 then
       local _, _, _, completedH = GetAchievementInfo(41820)
       completed = completed or completedH
    end
    insert(self.data, {
      {
        text = name,
        color = completed and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
        onClick = function()
          OpenAchievementFrameToAchievement(achievementId)
        end,
      },
    })
  end
end, {
  achievementIds = {},
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 155, backdrop = TransparentBackdrop},
  },
})

-- Overview
local Overview = Class(Frame, function(self)
  self.topAlts = TopAlts:new{
    parent = self,
    position = {
      TopLeft = {5, -5},
    },
  }

  self.tabFrame = TabFrame:new{
    parent = self,
    tabs = {"Midnight", "WWI"},
    position = {
      TopLeft = {self.topAlts, ui.edge.TopRight, 10, 0},
    },
  }

  -- Midnight tab (tab 1)
  local midnightPanel = self.tabFrame:Tab(1)
  self.midnightFactions = Factions:new{
    parent = midnightPanel,
    expansionLevel = 11,
    extraFactionIDs = {},
    position = { TopLeft = {0, 0} },
  }
  self.midnightAchievements = Achievements:new{
    parent = midnightPanel,
    achievementIds = midnightAchievementIds,
    position = {
      TopLeft = {self.midnightFactions, ui.edge.TopRight, 10, 0},
    },
  }

  -- WWI tab (tab 2)
  local wwiPanel = self.tabFrame:Tab(2)
  self.wwiFactions = Factions:new{
    parent = wwiPanel,
    position = { TopLeft = {0, 0} },
  }
  self.wwiAchievements = Achievements:new{
    parent = wwiPanel,
    achievementIds = wwiAchievementIds,
    position = {
      TopLeft = {self.wwiFactions, ui.edge.TopRight, 10, 0},
    },
  }

  -- size the tab frame to fit the larger of the two tab contents
  local wwiW = self.wwiFactions:Width() + 10 + self.wwiAchievements:Width()
  local wwiH = math.max(self.wwiFactions:Height(), self.wwiAchievements:Height())
  local midW = self.midnightFactions:Width() + 10 + self.midnightAchievements:Width()
  local midH = math.max(self.midnightFactions:Height(), self.midnightAchievements:Height())
  local tabW = math.max(wwiW, midW)
  local tabH = self.tabFrame.tabHeight + math.max(wwiH, midH)
  self.tabFrame:Width(tabW)
  self.tabFrame:Height(tabH)

  self:Height(20 + math.max(self.topAlts:Height(), tabH))
  self:Width(10 + self.topAlts:Width() + 10 + tabW)
end, {
  name = "overview",
  _title = "Overview",
})
Overview.name = "overview"
ns.views.Overview = Overview
