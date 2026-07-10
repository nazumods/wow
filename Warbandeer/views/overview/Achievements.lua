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
ns.overview.wwiAchievementIds = {
  20597, 40791, 20596, 40309, 40360, 41052, 40618, 41818, 41970, 41808, 61017, -- evergreen
  {20525, 1}, {40253, 1}, -- Keystone Master S1, AOTC: Queen Ansurek (Nerub-ar Palace)
  {41533, 2}, {41298, 2}, -- Keystone Master S2, AOTC: Chrome King Gallywix (Undermine)
  {41973, 3}, {41624, 3}, -- Keystone Master S3, AOTC: Dimensius (Manaforge Omega)
}
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
  {61256, 1}, -- Keystone Master: Season One
  {61626, 1}, -- Ahead of the Curve: Midnight Falls (S1)
}
ns.overview.dragonflightAchievementIds = {
  19458, -- A World Awoken (Dragonflight meta)
  16585, -- Loremaster of the Dragon Isles
  16334, -- Waking Hope (The Waking Shores story)
  15394, -- Ohn'a'Roll (Ohn'ahran Plains story)
  16336, -- Azure Spanner (The Azure Span story)
  16363, -- Just Don't Ask Me to Spell It (Thaldraszus story)
  16401, -- Sojourner of the Waking Shores
  16405, -- Sojourner of Ohn'ahran Plains
  16428, -- Sojourner of Azure Span
  16398, -- Sojourner of Thaldraszus
  {16649, 1}, {17107, 1}, -- Keystone Master S1, AOTC: Raszageth (Vault of the Incarnates)
  {17844, 2}, {18253, 2}, -- Keystone Master S2, AOTC: Sarkareth (Aberrus)
  {19011, 3}, {19350, 3}, -- Keystone Master S3, AOTC: Fyrakk (Amirdrassil)
  {19782, 4},             -- Keystone Master S4 (Fated season; no new raid)
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

-- Distinct season numbers tagged on an achievement list; evergreen entries (plain IDs)
-- carry none. Used by the Overview to build an expansion's season-picker options.
---@param list table[]
---@return number[]
function ns.overview.achievementSeasons(list)
  local set, out = {}, {}
  for _, entry in ipairs(list) do
    if type(entry) == "table" and entry[2] then set[entry[2]] = true end
  end
  for s in pairs(set) do out[#out + 1] = s end
  table.sort(out)
  return out
end

-- Single-column achievement checklist for one expansion. Each entry in `achievementIds`
-- is either a plain achievement ID (evergreen, shown every season) or `{id, season}`
-- (seasonal, shown only for that season or when `season` is "all"/nil).
---@class OverviewAchievements: TableFrame
---@field achievementIds table[]     entries: a plain ID (evergreen) or {id, season}
---@field season number|string?      season to show ("all"/nil = all; else evergreen + that season)
---@field _ids number[]              resolved IDs actually listed, parallel to self.data
local Achievements = Class(TableFrame, function(self)
  self.data, self._ids = {}, {}
  local season = self.season or "all"
  for _, entry in ipairs(self.achievementIds) do
    local id, s
    if type(entry) == "number" then id = entry else id, s = entry[1], entry[2] end
    if not s or season == "all" or s == season then
      self:addRow({backdrop = TransparentBackdrop})
      local row = self.rows[#self.rows]
      local _, name = GetAchievementInfo(id)
      self._ids[#self._ids + 1] = id
      insert(self.data, {
        {
          text = name,
          color = achColor(id),
          onClick = function() OpenAchievement(id) end,
          onEnter = function() row.backdrop:Color(theme.colors.hover) end,
          onLeave = function() row.backdrop:Color(0, 0, 0, 0) end,
        },
      })
    end
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
  for i, id in ipairs(self._ids) do
    self.data[i][1].color = achColor(id)
  end
  self:update()
end

ns.overview.Achievements = Achievements
