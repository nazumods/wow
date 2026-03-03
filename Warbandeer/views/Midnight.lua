local _, ns = ...
local ui = ns.ui
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
local Label = ui.Label

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    TopLeft = {3, -2},
    BottomRight = {-3, 2},
  },
}

local achievementIds = {
  61467, 42189, 42188, 42187, 61451, 40953, 41186, 41119, 40894, 40859, 40542, 40504, 40210, 20595, 20501, 19719,
  19507, 19408, 17773, 17529, 13723, 13475, 13473, 13049, 13018, 12997, 12582, 11699, 11258, 11257, 11124, 10996,
  10698,  9415,  8316,  7322,  6981,  5442,  5245,  5223,  4859,  4405,  1157,  1153,   940,   938,   231,   229,
    222,   221,   213,   212,   200,   158
}

-- Achievements Table
local Achievements = Class(TableFrame, function(self)
  for _,r in ipairs(self.rows) do r:backdropColor(ns.Colors.TransparentBlack) end
  for _,c in ipairs(self.cols) do c:backdropColor(ns.Colors.TransparentBlack) end
end, {
  autosize = true,
  headerHeight = 0,
  headerWidth = 0,
  GetData = function(self)
    return ns.lua.maps.map(
      ns.lua.lists.fold(achievementIds, 12),
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

-- Main View
local Midnight = Class(Frame, function(self)
  self.achievements = Achievements:new{
    parent = self,
    position = {
      TopLeft = {0, 0},
    },
  }
  self:Height(self.achievements:Height())
  self:Width(self.achievements:Width())
end, {
  name = "midnight",
  _title = "Midnight",
  onLoad = function(self)
    self:Height(self.achievements:Height())
    self:Width(self.achievements:Width())
  end,
})
Midnight.name = "midnight"
ns.views.Midnight = Midnight
