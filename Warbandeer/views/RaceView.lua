---@type Warbandeer
local ns = select(2, ...)
local max = math.max
local ui = ns.ui

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

-- The race a character belongs to when the race tables do not know it (a race added after
-- the tables were written: NormalizeRaceId gives raceIdx 0): the client's localized race name
-- when it has one, else the raw name the character was saved with.
local function unknownRaceName(t)
  local info = t.raceId and C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(t.raceId)
  local name = info and info.raceName
  if name and name ~= "" then return name end
  return t.race or "Unknown"
end

---@class RaceView: TableFrame
---@field headerWidth number  width of the race-name header column
-- Class × race grid (the races are ns.api's per-faction tables, which on Forever list only
-- Forever's races), built dynamically (like RoleView): the base
-- TableFrame builds no rows/cols, so we set the header offsets ourselves and
-- addCol/addRow as we go. One character per cell — a race with several of a
-- class spills into extra physical rows beneath its label. A race the tables do not know
-- gets its own row group under its own faction, after that faction's known races.
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

  -- One group per race, per faction: the known races first (in table order), then one group per
  -- race the tables do not know (by name). A group is { name, buckets[colIdx] = {toons} }.
  local sides = {
    { isAlliance = true, groups = {} },
    { isAlliance = false, groups = {} },
  }
  for i, name in ipairs(ns.api.ALLIANCE_RACES) do sides[1].groups[i] = { name = name, buckets = {} } end
  for i, name in ipairs(ns.api.HORDE_RACES) do sides[2].groups[i] = { name = name, buckets = {} } end
  local unknown = { {}, {} }  -- per side: race name -> group

  -- bucket characters by race group + class column
  for _, t in pairs(ns.api.GetAllCharacters()) do
    local colIdx = classColIdx[t.classKey]
    if colIdx then
      local s = t.isAlliance and 1 or 2
      -- raceIdx indexes the per-faction race array; 0 (or nothing there) is a race we do not know
      local g = t.raceIdx and sides[s].groups[t.raceIdx]
      if not g then
        local name = unknownRaceName(t)
        g = unknown[s][name]
        if not g then
          g = { name = name, buckets = {} }
          unknown[s][name] = g
        end
      end
      local b = g.buckets
      b[colIdx] = b[colIdx] or {}
      insert(b[colIdx], t)
    end
  end
  -- unknown races follow their faction's known ones, in name order (pairs order is not stable)
  for s = 1, 2 do
    local extra = {}
    for _, g in pairs(unknown[s]) do insert(extra, g) end
    table.sort(extra, function(a, b) return a.name < b.name end)
    for _, g in ipairs(extra) do insert(sides[s].groups, g) end
  end

  -- emit one physical row per stacked character (at least one per race so empty
  -- races still show their label). The race name labels the first row of its group.
  local allianceEndRow
  local groupIdx = 0
  for _, side in ipairs(sides) do
    for _, g in ipairs(side.groups) do
      groupIdx = groupIdx + 1
      local b = g.buckets
      local stack = 1
      for _, toonsInCol in pairs(b) do stack = max(stack, #toonsInCol) end
      for k = 1, stack do
        local rowData = {}
        for colIdx, toonsInCol in pairs(b) do
          if toonsInCol[k] then rowData[colIdx] = nameCell(toonsInCol[k]) end
        end
        insert(self.data, rowData)
        self:addRow({
          name = k == 1 and g.name or "",
          color = side.isAlliance and PLAYER_FACTION_COLOR_ALLIANCE or PLAYER_FACTION_COLOR_HORDE,
          justifyH = ui.justify.Left,
          backdrop = {color = {0, 0, 0, groupIdx % 2 == 0 and 0.2 or 0}},
        })
      end
    end
    if side.isAlliance then allianceEndRow = #self.rows end
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
