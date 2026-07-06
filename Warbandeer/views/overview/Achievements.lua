---@type Warbandeer
local ns = select(2, ...)
local insert = table.insert
local ui = ns.ui
local Class, TableFrame = ns.lua.Class, ui.TableFrame
local theme = ns.theme
-- 12.1.0 renamed OpenAchievementFrameToAchievement -> ShowAchievementFrameForAchievement
local OpenAchievement = ShowAchievementFrameForAchievement or OpenAchievementFrameToAchievement

ns.overview = ns.overview or {}

local TransparentBackdrop = {color = ns.Colors.TransparentBlack}

-- Per-expansion achievement ID lists (display order), consumed by Overview's
-- EXPANSIONS table and passed to an Achievements instance as `achievementIds`.
ns.overview.wwiAchievementIds = {20597, 40791, 20596, 40309, 40360, 41052, 40618, 41818, 41970, 41808, 61017}
ns.overview.midnightAchievementIds = {
  62386, -- Light Up the Night (meta)
  62110, -- Loremaster of Midnight
  62104, -- Midnight Lore Hunter
  61741, -- Delve Loremaster: Midnight
  61506, -- Allied Race: Haranir
  61839, -- (existing)
  62261, -- Forever Song (Eversong Woods story)
  61453, -- Making an Amani Out of You (Zul'Aman story)
  62260, -- That's Aln, Folks! (Harandar story)
  62256, -- Yelling into the Voidstorm (Voidstorm story)
  61957, -- Sojourner of Eversong Woods
  61452, -- Sojourner of Zul'Aman
  61739, -- Sojourner of Harandar
  61864, -- Sojourner of Voidstorm
}

-- Live completion colour for one achievement (41818 = the Midnight meta, also
-- satisfied by its Heroic variant 41820). Read fresh so a mid-session earn recolours.
local function achColor(achievementId)
  local _, _, _, completed = GetAchievementInfo(achievementId)
  if achievementId == 41818 then
    local _, _, _, completedH = GetAchievementInfo(41820)
    completed = completed or completedH
  end
  return completed and DIM_GREEN_FONT_COLOR or DIM_RED_FONT_COLOR
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

-- Re-read completion state and recolour each row. Overview:OnBeforeShow calls this
-- so an achievement earned mid-session turns green without a /reload (the rows are
-- built once and otherwise never revisited).
function Achievements:Refresh()
  for i, achievementId in ipairs(self.achievementIds) do
    self.data[i][1].color = achColor(achievementId)
  end
  self:update()
end

ns.overview.Achievements = Achievements
