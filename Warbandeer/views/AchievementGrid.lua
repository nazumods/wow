---@type Warbandeer
local ns = select(2, ...)
local api = ns.api
-- 12.1.0 renamed OpenAchievementFrameToAchievement -> ShowAchievementFrameForAchievement
local OpenAchievement = ShowAchievementFrameForAchievement or OpenAchievementFrameToAchievement

-- The achievement cell grid shared by the Legion and Milestones views (#1100): the catalog list
-- folded into rows `width` wide, one clickable name cell per achievement, green when complete.

---@class Warbandeer
---@field AchievementGridData fun(catalogKey: string, width: number): table
---@field RefreshAchievementGrid fun(grid: TableFrame)

---Build the cell grid for one catalog list.
---
---The catalog lives in Warbandeer_Characters (data/achievementcatalog.lua) since the persistence
---layer needs the full id set regardless of whether a view is open. Read here, at call time rather
---than file scope, so a missing or stale producer costs the view when opened, not three files at
---load (#746).
---@param catalogKey string  key into `api:GetAchievementCatalog()` (e.g. "legion", "milestones")
---@param width number  achievements per row
---@return table
function ns.AchievementGridData(catalogKey, width)
  return ns.lua.maps.map(
    ns.lua.lists.fold(api:GetAchievementCatalog()[catalogKey], width),
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
end

---Re-read completion state and repaint. The grid is built once, so without this an achievement
---earned mid-session stayed red until /reload; ACHIEVEMENT_EARNED updates the persisted snapshot
---immediately (data/achievements.lua), so calling this from OnBeforeShow is enough.
---@param grid TableFrame
function ns.RefreshAchievementGrid(grid)
  grid.data = grid:GetData()
  grid:update()
end
