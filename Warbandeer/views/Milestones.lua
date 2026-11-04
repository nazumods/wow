---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame

-- Achievements Table
---@class MilestonesAchievements: TableFrame
---@field GetData fun(self: MilestonesAchievements): table  builds the achievement cell grid
local Achievements = Class(TableFrame, function(self)
  for _,r in ipairs(self.rows) do r:backdropColor(ns.Colors.TransparentBlack) end
  for _,c in ipairs(self.cols) do c:backdropColor(ns.Colors.TransparentBlack) end
end, {
  autosize = true,
  headerHeight = 0,
  headerWidth = 0,
  GetData = function() return ns.AchievementGridData("milestones", 12) end,
})

-- Main View
---@class Milestones: Frame
---@field achievements MilestonesAchievements
local Milestones = Class(Frame, function(self)
  self.achievements = Achievements:new{
    parent = self,
    position = {
      TopLeft = {0, 0},
    },
  }
  self:Height(self.achievements:Height())
  self:Width(self.achievements:Width())
end, {
  name = "milestones",
  onLoad = function(self)
    self:Height(self.achievements:Height())
    self:Width(self.achievements:Width())
  end,
})
Milestones.name = "milestones"
Milestones._title = "Milestones"
ns.views.Milestones = Milestones

function Milestones:OnBeforeShow()
  ns.RefreshAchievementGrid(self.achievements)
end
