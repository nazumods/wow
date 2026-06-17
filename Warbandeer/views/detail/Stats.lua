---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label = ui.Frame, ui.Label
local theme = ns.theme
local D = ns.detail

local DetailView = ns.views.DetailView
local Top, Left, Right = ui.edge.Top, ui.edge.Left, ui.edge.Right
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight

-- The secondary-stat 2×2 grid under the Item Level / Playtime cards: Crit + Mastery on
-- top, Haste + Versatility below — each cell the effective % (incl. base, as the paperdoll
-- shows) over the gear rating. Values come from the data layer's stored `stats.secondary`
-- (warband-wide last-seen). The spec's top-priority stat is tinted gold when ShadowsOfUI-
-- Upgrade is loaded (OptionalDep, via `StatRanks`); plain otherwise.
local CELLS = {
  { key = "crit",        label = "Critical Strike", col = 0, row = 0 },
  { key = "mastery",     label = "Mastery",         col = 1, row = 0 },
  { key = "haste",       label = "Haste",           col = 0, row = 1 },
  { key = "versatility", label = "Versatility",     col = 1, row = 1 },
}

-- The character's tier-1 secondary stats (a set), for the gold highlight; empty when the
-- upgrade addon isn't loaded or the spec/priority is unknown.
local function topStats(charName)
  local api = ShadowsOfUI_UpgradeApi
  local ranks = api and api.StatRanks and api:StatRanks(charName)
  local set = {}
  if ranks then
    for stat, tier in pairs(ranks) do if tier == 1 then set[stat] = true end end
  end
  return set
end

-- Lazily build the 4-cell grid (fixed layout; values filled by `_showStats`).
function DetailView:_buildStatGrid()
  if self._statCells then return end
  local c = theme.colors
  local cellW = (D.PANEL_W - D.GAP) / 2
  local grid = Frame:new{
    parent = self,
    position = { TopLeft = {D.P, -D.STATS_TOP}, Width = D.PANEL_W, Height = D.STATS_H },
  }
  self._statCells = {}
  for i, spec in ipairs(CELLS) do
    local cell = Frame:new{
      parent = grid, background = c.module,
      position = {
        TopLeft = {spec.col * (cellW + D.GAP), -spec.row * D.STATS_ROW_H},
        Width = cellW, Height = D.STATS_ROW_H - 6,
      },
    }
    local name = Label:new{
      parent = cell, fontInfo = theme.fonts.subcaps, color = c.muted, justifyH = ui.justify.Center,
      text = spec.label:upper(),
      position = { Top = {cell, Top, 0, -5}, Left = {cell, Left, 6, 0}, Right = {cell, Right, -6, 0} },
    }
    local pct = Label:new{
      parent = cell, fontInfo = theme.fonts.number, color = c.text, justifyH = ui.justify.Left,
      position = { BottomLeft = {cell, BottomLeft, 8, 5} },
    }
    local rating = Label:new{
      parent = cell, fontInfo = theme.fonts.stat, color = c.muted, justifyH = ui.justify.Right,
      position = { BottomRight = {cell, BottomRight, -8, 6} },
    }
    self._statCells[i] = { key = spec.key, name = name, pct = pct, rating = rating }
  end
end

-- Fill the grid from the character's stored secondary stats, tinting its top-priority stat.
function DetailView:_showStats()
  self:_buildStatGrid()
  local c = theme.colors
  local sec = self._char.stats and self._char.stats.secondary
  local top = topStats(self._char.name)
  for _, cell in ipairs(self._statCells) do
    local s = sec and sec[cell.key]
    local hot = top[cell.key]
    cell.name:Color(hot and c.gold or c.muted)
    if s then
      cell.pct:Text(("%.2f%%"):format(s.pct or 0)):Color(hot and c.gold or c.text)
      cell.rating:Text(s.rating and tostring(s.rating) or "")
    else
      cell.pct:Text("—"):Color(c.muted)
      cell.rating:Text("")
    end
  end
end
