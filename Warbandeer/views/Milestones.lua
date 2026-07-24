---@type Warbandeer
local ns = select(2, ...)
local api = ns.api
local ui = ns.ui
local Class, Frame, TableFrame = ns.lua.Class, ui.Frame, ui.TableFrame
-- 12.1.0 renamed OpenAchievementFrameToAchievement -> ShowAchievementFrameForAchievement
local OpenAchievement = ShowAchievementFrameForAchievement or OpenAchievementFrameToAchievement

-- Catalog lives in Warbandeer_Characters (data/achievementcatalog.lua) since the
-- persistence layer needs the full id set regardless of whether this view is open.
local achievementIds = api:GetAchievementCatalog().milestones

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
  GetData = function(self)
    return ns.lua.maps.map(
      ns.lua.lists.fold(achievementIds, 12),
      function(ids)
        return ns.lua.lists.map(ids, function(achievementId)
          local _, name = GetAchievementInfo(achievementId)
          return {
            text = name,
            color = api:IsAchievementComplete(achievementId) and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR,
            onClick = function()
              OpenAchievement(achievementId)
            end,
          }
        end)
      end
    )
  end,
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
