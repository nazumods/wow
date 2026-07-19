---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local theme = ns.theme
local Class, TableFrame, Texture = ns.lua.Class, ui.TableFrame, ui.Texture
local filter = ns.lua.lists.filter

-- One faction's Great Vault roster: a row per character, columns from ns.VaultColumns. `faction`
-- selects the roster ("both" = the merged warband; the crest column keeps the sides distinguishable).
-- Mirrors the Summary view's per-faction table (row hover highlight, click-through to Detail, the
-- logged-in character's gold wash, dimmed levellers) without touching it.
---@class VaultRoster: TableFrame
---@field faction "alliance"|"horde"|"both"  which roster this table shows
---@field columns SummaryColumn[]  the visible columns this table renders (passed in by VaultView)
---@field _toons Character[]  row index -> character (refreshed each OnBeforeShow)
local VaultRoster = Class(TableFrame, function(self)
  self._toons = self:GetCharacters()
  self.data = {}
  for i, t in ipairs(self._toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()
  for i, row in ipairs(self.rows) do
    self:restRow(i)
    Texture:new{
      parent = row,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = { row, ui.edge.TopLeft, 0, 0 },
        TopRight = { row, ui.edge.TopRight, 0, 0 },
        Height = 1,
      },
      color = theme.colors.divider,
    }
  end
  self:AutosizeColumns()  -- fit the Raid Lockouts column to its widest cell (see AutosizeColumn)
end, {
  faction = "alliance",
  backdrop = { color = ns.Colors.TransparentBlack },
})
ns.VaultRoster = VaultRoster

-- Size every autosize-flagged column (colInfo.autosize) to the widest text it renders. The Vault
-- twin of ClassSummary:AutosizeColumn: VaultRoster is a plain TableFrame, so it can't use
-- TableFrame:Autosize — that width recompute is a bare column-width sum that drops this view's
-- per-column gutters (COL_GUTTER) and would spill the last column past the window edge.
function VaultRoster:AutosizeColumns()
  for i, info in ipairs(self.colInfo) do
    if info.autosize then self:AutosizeColumn(i) end
  end
end

-- Resize column `i` to the widest text it currently renders (its header + every cell), then grow
-- the table + rowArea by the delta so the gutter-spaced column chain stays aligned. Cells anchor to
-- their column's edges (inset by the column's hPad), so the resize reflows them and every later
-- column. The header carries no inset (this view sets no per-column `padding`); each cell's text is
-- inset by the column's hPadL/hPadR (see TableFrame:cellPosition), so it needs that much more room.
---@param i integer  column index to size
function VaultRoster:AutosizeColumn(i)
  local col = self.cols[i]
  if not col then return end
  local info = self.colInfo[i] or {}
  local hPad = info.hPad or self.hPad or 0
  local padL, padR = info.hPadL or hPad, info.hPadR or hPad
  local widest = (col.header.label and col.header.label:UnboundedWidth()) or 0
  for r = 1, #self.rows do
    local cell = self.cells[r] and self.cells[r][i]
    if cell and cell.label then widest = math.max(widest, cell.label:UnboundedWidth() + padL + padR) end
  end
  local target = math.ceil(widest) + 4  -- a little breathing room before the window edge
  if info.minWidth and target < info.minWidth then target = info.minWidth end
  local delta = target - col:Width()
  if delta == 0 then return end
  col:Width(target)
  self:Width(self:Width() + delta)
  self.rowArea:Width(self.rowArea:Width() + delta)
end

-- This table's roster, sorted by level/ilvl/name. "both" is the whole warband; a single side filters.
---@return Character[]
function VaultRoster:GetCharacters()
  local toons = ns.api.GetAllCharacters()  -- returns a copy
  -- The Great Vault is a max-level-only feature, so hide levellers entirely: below max they
  -- have no vault data at all, so their rows would just be blank noise.
  toons = filter(toons, function(t) return (t.basic.level or 0) >= ns.wow.maxLevel end)
  if self.faction ~= "both" then
    local wantAlliance = self.faction == "alliance"
    toons = filter(toons, function(t) return t.isAlliance == wantAlliance end)
  end
  table.sort(toons, ns.byLevelIlvl)
  return toons
end

-- One cell per column, by position; nil getData → "" so the array stays index-aligned.
---@param toon Character
---@return table
function VaultRoster:GetRowData(toon)
  local cells = {}
  for n, c in ipairs(self.columns) do cells[n] = c.getData(toon) or "" end
  return cells
end

-- Resting backdrop: gold wash for the logged-in character, transparent otherwise. The roster is
-- max-level-only (see GetCharacters), so there are no levellers to dim here.
---@param i integer
function VaultRoster:restRow(i)
  local row, toon = self.rows[i], self._toons[i]
  if not row then return end
  if toon and toon.name == ns.api.GetCurrentCharacter() then
    row:backdropColor(theme.colors.selected)
  else
    row:backdropColor(0, 0, 0, 0)
  end
end

-- Chain each cell's onEnter/onLeave onto the row hover highlight, and default a cell with no onClick
-- to opening its character in Detail. Each cell is copied so shared getData tables aren't mutated.
---@param cells table
---@param i integer
---@return table
function VaultRoster:decorateRow(cells, i)
  for n, cell in ipairs(cells) do
    local src = type(cell) == "table" and cell or { text = cell }
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    local onEnter, onLeave, onClick = src.onEnter, src.onLeave, src.onClick
    copy.onEnter = function(s)
      local row = self.rows[i]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    copy.onLeave = function(s)
      self:restRow(i)
      if onLeave then onLeave(s) end
    end
    copy.onClick = function(s)
      if onClick then onClick(s); return end
      local toon, w = self._toons[i], ns.MainWindow
      if toon and w then
        w:getView("detail"):Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
end

function VaultRoster:OnBeforeShow()
  self._toons = self:GetCharacters()
  self.data = {}
  for i, t in ipairs(self._toons) do
    self.data[i] = self:decorateRow(self:GetRowData(t), i)
  end
  self:update()
  for i in ipairs(self.rows) do self:restRow(i) end
  self:AutosizeColumns()  -- re-fit the Raid Lockouts column to this roster's widest cell
end
