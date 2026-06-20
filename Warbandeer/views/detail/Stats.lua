---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, StatChart = ui.Frame, ui.Label, ns.StatChart
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

-- The rating's status vs its Archon target (within 5% = on-target, over, under), mirroring
-- ClassCodex's classification — each carries an inline colour `code` (for the "571 / 869"
-- number) and the matching `label` (for the hover). nil = no target.
local DELTA = {
  at    = { code = "|cff73d973", label = "In target range" },
  above = { code = "|cff66b3ff", label = "Over target" },
  below = { code = "|cffe67373", label = "Under target" },
}
local function deltaState(current, target)
  if not (current and target and target > 0) then return nil end
  local pct = (current - target) / target * 100
  if math.abs(pct) < 5 then return "at" end
  return pct > 0 and "above" or "below"
end

-- Hover tooltip for a stat cell that has an Archon target: the stat name, the colour-matched
-- status line + signed delta, and the current/target ratings. No-op when the cell has no target.
local function showStatTip(cell)
  local t = cell._tip
  if not t then return end
  local d = DELTA[t.state]
  ns.AnchorTip(cell)
  ui.tip:ClearLines()
  ui.tip:AddLine(t.label)
  local diff = t.current - t.target
  ui.tip:AddLine(("%s%s|r |cffb0b0b0(%s%d)|r"):format(d.code, d.label, diff >= 0 and "+" or "−", math.abs(diff)))
  ui.tip:AddLine(("|cff808080%d / %d target|r"):format(t.current, t.target))
  ui.tip:Show()
end

-- Lazily build the 4-cell grid (fixed layout; values filled by `_showStats`).
function DetailView:_buildStatGrid()
  if self._statCells then return end
  local c = theme.colors
  -- Two narrower columns with the radar centred in the gap between them.
  local cellW = (D.PANEL_W - D.STATS_CHART - 2 * D.GAP) / 2
  local grid = Frame:new{
    parent = self,
    position = { TopLeft = {D.P, -D.STATS_TOP}, Width = D.PANEL_W, Height = D.STATS_H },
  }
  -- Radar chart filling the centre channel, vertically centred over the grid.
  self._statChart = StatChart:new{
    parent = grid, radius = D.STATS_CHART / 2 - 4,
    position = {
      TopLeft = {(D.PANEL_W - D.STATS_CHART) / 2, -(D.STATS_H - D.STATS_CHART) / 2},
      Width = D.STATS_CHART, Height = D.STATS_CHART,
    },
  }
  self._statCells = {}
  for i, spec in ipairs(CELLS) do
    local cell = Frame:new{
      parent = grid, background = c.module,
      position = {
        TopLeft = {spec.col == 0 and 0 or (D.PANEL_W - cellW), -spec.row * D.STATS_ROW_H},
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
    -- Hover shows the target status (only armed in `_showStats` when a target exists).
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function() showStatTip(cell) end)
    cell:SetScript("OnLeave", function() ui.tip:Hide() end)
    self._statCells[i] = { key = spec.key, label = spec.label, name = name, pct = pct, rating = rating, frame = cell }
  end
end

-- Fill the grid from the character's stored secondary stats, tinting its top-priority stat
-- and showing each rating against its Archon target ("571 / 869", status-coloured) when
-- ClassCodex supplies one.
function DetailView:_showStats()
  self:_buildStatGrid()
  local c = theme.colors
  local sec = self._char.stats and self._char.stats.secondary
  local top = topStats(self._char.name)
  local api = ShadowsOfUI_UpgradeApi
  local targets = api and api.StatTargets and api:StatTargets(self._char.name)
  for _, cell in ipairs(self._statCells) do
    local s = sec and sec[cell.key]
    local hot = top[cell.key]
    cell.name:Color(hot and c.gold or c.muted)
    local target = s and targets and targets[cell.key]
    local state = s and deltaState(s.rating, target)
    cell.frame._tip = state and { label = cell.label, state = state, current = s.rating, target = target } or nil
    if s then
      cell.pct:Text(("%.2f%%"):format(s.pct or 0)):Color(hot and c.gold or c.text)
      if state then
        cell.rating:Text(("%s%d|r |cff808080/ %d|r"):format(DELTA[state].code, s.rating, target))
      else
        cell.rating:Text(s.rating and tostring(s.rating) or "")
      end
    else
      cell.pct:Text("—"):Color(c.muted)
      cell.rating:Text("")
    end
  end
  -- Feed the centre radar the four gear ratings (0 when unscanned), tinting tier-1 gold.
  local function rating(key) local s = sec and sec[key]; return s and s.rating or 0 end
  self._statChart:Set(rating("crit"), rating("haste"), rating("mastery"), rating("versatility"), top)
end
