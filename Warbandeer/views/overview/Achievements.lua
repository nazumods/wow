---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local api = ns.api
local ui = ns.ui
local Class, TableFrame = ns.lua.Class, ui.TableFrame
local theme = ns.theme
-- 12.1.0 renamed OpenAchievementFrameToAchievement -> ShowAchievementFrameForAchievement
local OpenAchievement = ShowAchievementFrameForAchievement or OpenAchievementFrameToAchievement

ns.overview = ns.overview or {}

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- Per-expansion achievement ID lists (display order), consumed by Overview's EXPANSIONS
-- table and passed to an Achievements instance as `achievementIds`. The catalog itself lives
-- in Warbandeer_Characters (data/achievementcatalog.lua) since the persistence layer needs
-- the full id set regardless of whether this view is open.
local checklist = api:GetAchievementCatalog().checklist
ns.overview.wwiAchievementIds = checklist.wwi
ns.overview.midnightAchievementIds = checklist.midnight
ns.overview.dragonflightAchievementIds = checklist.dragonflight

-- Persisted completion colour for one achievement (metaAlts, e.g. 41818's Heroic variant
-- 41820, is resolved by IsAchievementComplete).
local function achColor(achievementId)
  return api:IsAchievementComplete(achievementId) and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR
end

-- Single-column achievement checklist for one expansion.
---@class OverviewAchievements: TableFrame
---@field achievementIds number[]  achievement IDs to list, in display order
local Achievements = Class(TableFrame, function(self)
  self.data = {}
  for _, achievementId in ipairs(self.achievementIds) do
    self:addRow({backdrop = TransparentBackdrop})
    local row = self.rows[#self.rows]
    local _, name = GetAchievementInfo(achievementId)
    insert(self.data, {
      {
        text = name,
        color = achColor(achievementId),
        onClick = function()
          OpenAchievement(achievementId)
        end,
        onEnter = function() row.backdrop:Color(theme.colors.hover) end,
        onLeave = function() row.backdrop:Color(0, 0, 0, 0) end,
      },
    })
  end
  self:update()
end, {
  achievementIds = {},
  headerHeight = 0,
  headerWidth = 0,
  colInfo = {
    {width = 200, backdrop = TransparentBackdrop},
  },
})

-- Re-read persisted completion state and recolour each row. ACHIEVEMENT_EARNED updates the
-- snapshot immediately (data/achievements.lua), so Overview:OnBeforeShow calling this is
-- enough for a mid-session earn to turn green without a /reload (the rows are built once
-- and otherwise never revisited).
function Achievements:Refresh()
  for i, achievementId in ipairs(self.achievementIds) do
    self.data[i][1].color = achColor(achievementId)
  end
  self:update()
end

ns.overview.Achievements = Achievements
