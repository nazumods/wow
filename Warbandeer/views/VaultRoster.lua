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
end, {
  faction = "alliance",
  backdrop = { color = ns.Colors.TransparentBlack },
})
ns.VaultRoster = VaultRoster

-- This table's roster, sorted by level/ilvl/name. "both" is the whole warband; a single side filters.
---@return Character[]
function VaultRoster:GetCharacters()
  local toons = ns.api.GetAllCharacters()  -- returns a copy
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
  for n, c in ipairs(ns.VaultColumns) do cells[n] = c.getData(toon) or "" end
  return cells
end

-- Resting backdrop: gold wash for the logged-in character, dimmed for still-levelling characters.
---@param i integer
function VaultRoster:restRow(i)
  local row, toon = self.rows[i], self._toons[i]
  if not row then return end
  if toon and toon.name == ns.api.GetCurrentCharacter() then
    row:backdropColor(theme.colors.selected)
  elseif toon and (toon.basic.level or 0) < ns.wow.maxLevel then
    row:backdropColor(0, 0, 0, 0.22)
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
end
