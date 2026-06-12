---@type Warbandeer
local ns = select(2, ...)
local max = math.max
local ui = ns.ui
local lists = ns.lua.lists

local insert = table.insert
local Class, TableFrame, Texture = ns.lua.Class, ui.TableFrame, ui.Texture
local Colors, alpha = ns.Colors, ns.Colors.alpha
local theme = ns.theme

-- Per-character name cell: class-colored name with a hover highlight and
-- click-through to the Detail view (mirrors RoleView/GearView/SummaryView). Each
-- character gets its own cell (a race that has several of a class stacks one toon
-- per physical row), so the highlight + click target the individual character.
local function nameCell(toon)
  return {
    color = Colors[toon.classKey or toon.className],
    text = toon.name,
    justifyH = ui.justify.Center,
    onEnter = function(cell)
      if not cell._hl then
        cell._hl = Texture:new{
          parent = cell,
          layer = ui.layer.Background,
          position = { All = true },
          color = theme.colors.hover,
        }
      else
        cell._hl:Show()
      end
    end,
    onLeave = function(cell)
      if cell._hl then cell._hl:Hide() end
    end,
    onClick = function()
      local w = ns.MainWindow
      if w then
        w:getView("detail"):Select(toon)
        w:view("detail")
      end
    end,
  }
end

-- classes in armor type order
local Classes = {
  "Priest", "Mage", "Warlock",
  "Demon Hunter", "Druid", "Monk", "Rogue",
  "Evoker", "Hunter", "Shaman",
  "Death Knight", "Paladin", "Warrior"
}
local classKeyOf = function(c) return gsub(c, " ", "") end
local classColIdx = {}
for i, c in ipairs(Classes) do classColIdx[classKeyOf(c)] = i end

local Races = lists.values(ns.api.ALLIANCE_RACES, ns.api.HORDE_RACES)
local nAlliance = #ns.api.ALLIANCE_RACES

-- 13-class × 29-race grid, built dynamically (like RoleView): the base
-- TableFrame builds no rows/cols, so we set the header offsets ourselves and
-- addCol/addRow as we go. One character per cell — a race with several of a
-- class spills into extra physical rows beneath its label.
local RaceView = Class(TableFrame, function(self)
  self.offsetX = self.headerWidth
  self.offsetY = self.headerHeight
  self.rowArea:TopLeft(0, -self.offsetY)

  -- class columns: theme-muted header over a faint class-tinted backdrop
  for _, c in ipairs(Classes) do
    local key = classKeyOf(c)
    self:addCol({
      name = c,
      width = 105,
      justifyH = ui.justify.Center,
      backdrop = {color = alpha(Colors[key], 0.06)},
    })
  end

  -- bucket characters by race row + class column (buckets[raceIdx][colIdx] = {toons})
  local buckets = {}
  for i = 1, #Races do buckets[i] = {} end
  for _, t in pairs(ns.api.GetAllCharacters()) do
    -- raceIdx indexes the per-faction race array, so horde toons are offset past
    -- the alliance races to land on the right row group
    local raceIdx = t.raceIdx + (t.isAlliance and 0 or nAlliance)
    local colIdx = classColIdx[t.classKey]
    if colIdx then
      local b = buckets[raceIdx]
      b[colIdx] = b[colIdx] or {}
      insert(b[colIdx], t)
    end
  end

  -- emit one physical row per stacked character (at least one per race so empty
  -- races still show their label). The race name labels the first row of its group.
  local allianceEndRow
  for raceIdx = 1, #Races do
    local b = buckets[raceIdx]
    local stack = 1
    for _, toonsInCol in pairs(b) do stack = max(stack, #toonsInCol) end
    local isAlliance = raceIdx <= nAlliance
    for k = 1, stack do
      local rowData = {}
      for colIdx, toonsInCol in pairs(b) do
        if toonsInCol[k] then rowData[colIdx] = nameCell(toonsInCol[k]) end
      end
      insert(self.data, rowData)
      self:addRow({
        name = k == 1 and Races[raceIdx] or "",
        color = isAlliance and PLAYER_FACTION_COLOR_ALLIANCE or PLAYER_FACTION_COLOR_HORDE,
        justifyH = ui.justify.Left,
        backdrop = {color = {0, 0, 0, raceIdx % 2 == 0 and 0.2 or 0}},
      })
    end
    if raceIdx == nAlliance then allianceEndRow = #self.rows end
  end

  -- addCol/addRow only accumulate the column/row spans (the base table started at
  -- zero, before offsetX/offsetY were set), so fold the header offsets back in:
  -- rows span the full width (their zebra backdrops are visible) and the frame
  -- reserves the header row's height so the last race row isn't clipped.
  local fullWidth = self.headerWidth + #Classes * 105
  self:Width(fullWidth)
  self.rowArea:Width(fullWidth)
  self:Height(self.offsetY + self.rowArea:Height())

  self:update()

  -- thin faction-colored divider between the Alliance and Horde blocks
  if allianceEndRow then
    local row = self.rows[allianceEndRow]
    Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = {row, ui.edge.BottomLeft, 0, 0},
        TopRight = {row, ui.edge.BottomRight, 0, 0},
        Height = 1,
      },
      color = alpha(PLAYER_FACTION_COLOR_ALLIANCE, 0.5),
    }
  end
end, {
  name = "races",
  headerWidth = 135,
  data = {},
})
RaceView.name = "races"
RaceView._title = "Races"
ns.views.RaceView = RaceView
