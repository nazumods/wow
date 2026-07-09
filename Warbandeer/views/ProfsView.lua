---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, TableFrame, ScrollFrame =
  ns.lua.Class, ui.Frame, ui.TableFrame, ui.ScrollFrame
local Colors = ns.Colors
local theme = ns.theme
local insert, sort = table.insert, table.sort

-- Shared data + helpers live in views/profs/ProfsData.lua (loaded first), on ns.profs.
local P = ns.profs
local EXP_ORDER, EXP_ABBR, PROF_ORDER, CHAR_LIST_H, VIEW_WIDTH, TRANSPARENT, SELECTED, DIM =
  P.EXP_ORDER, P.EXP_ABBR, P.PROF_ORDER, P.CHAR_LIST_H, P.VIEW_WIDTH, P.TRANSPARENT, P.SELECTED, P.DIM
local makeGridColInfo, makeCharColInfo, makeEmptyRow, rowDivider, skillCell, buildBestSkills, buildCharList, sortCharEntries =
  P.makeGridColInfo, P.makeCharColInfo, P.makeEmptyRow, P.rowDivider, P.skillCell, P.buildBestSkills, P.buildCharList, P.sortCharEntries

---@class ProfsView: Frame
---@field gridTable TableFrame        Account Summary grid (professions x expansions)
---@field charTable TableFrame        per-profession character list
---@field charScroll ScrollFrame      scroll wrapper over the character-list rows
---@field emptyHint Label             "select a profession" hint
---@field _selectedRowIdx integer?    selected grid row, nil when none
---@field _visibleProfs string[]      profession name per visible grid row
---@field _toons Character[]?         all characters (refreshed each OnBeforeShow)
---@field _charToons Character[]      character per char-list row
---@field _charEntries table[]        current char-list entries ({toon, prof, detail}), re-sorted on header click
---@field _charColCount integer       char-table column count (for empty-row padding)
local ProfsView = Class(Frame, function(self)
  -- Account Summary grid: rows = professions, columns = expansions.
  self.gridTable = TableFrame:new{
    parent   = self,
    colInfo  = makeGridColInfo(),
    backdrop = TRANSPARENT,
    position = { TopLeft = {} },
  }

  -- Character-list section: a fixed header TableFrame + a ScrollFrame for the rows.
  -- The character table's header is placed immediately below the grid.
  -- A ScrollFrame is laid over the row area so only the header stays fixed.
  self.charTable = TableFrame:new{
    parent   = self,
    colInfo  = makeCharColInfo(),
    backdrop = TRANSPARENT,
    position = { TopLeft = { self.gridTable, ui.edge.BottomLeft, 0, -8 } },
  }
  -- Clicking a sortable header re-sorts the current character list (TableFrame owns the
  -- header UI + arrow; we own the comparator + repaint — see _sortCharList).
  self.charTable.onSort = function(_, key, desc) self:_sortCharList(key, desc) end

  -- charTable.offsetY is the header height; the scroll starts just below the header.
  local scrollTop = 8 + self.charTable.offsetY
  self.charScroll = ScrollFrame:new{
    parent   = self,
    position = {
      TopLeft = { self.gridTable, ui.edge.BottomLeft, 0, -scrollTop },
      Height  = CHAR_LIST_H,
      Width   = VIEW_WIDTH,
    },
  }
  self.charScroll:Child(self.charTable.rowArea)

  self.emptyHint = ui.Label:new{
    parent  = self.charScroll,
    text    = "Select a profession above to view characters",
    color   = theme.colors.muted,
    position = { Center = {} },
  }

  self._selectedRowIdx = nil
  self._visibleProfs   = {}
  self._toons          = nil
  self._charToons      = {}
  self._charColCount   = 2 + #EXP_ORDER  -- icon + name + expansions

  self:Width(VIEW_WIDTH)
  self:Height(self.gridTable:Height() + scrollTop + CHAR_LIST_H)
end, {
  name   = "profs",
  background = theme.colors.window,
})
ProfsView.name = "profs"
ProfsView._title = "Professions"
ns.views.ProfsView = ProfsView

---@return Character[]
function ProfsView:GetCharacters()
  local toons = ns.api.GetAllCharacters()
  sort(toons, ns.byLevelIlvl)
  return toons
end

-- Highlight the clicked grid row and populate the character list below it.
---@param rowIdx integer  index into self._visibleProfs
function ProfsView:SelectRow(rowIdx)
  -- Restore the previous row's resting (transparent) backdrop.
  if self._selectedRowIdx then
    local prev = self.gridTable.rows[self._selectedRowIdx]
    if prev then prev:backdropColor(0, 0, 0, 0) end
  end

  self._selectedRowIdx = rowIdx
  local row = self.gridTable.rows[rowIdx]
  if row then row:backdropColor(SELECTED) end

  self:RebuildCharList(self._visibleProfs[rowIdx])
end

-- Resting backdrop for a grid row: gold wash if selected, otherwise transparent.
---@param rowIdx integer  index into self.gridTable.rows
function ProfsView:RestoreGridRow(rowIdx)
  local row = self.gridTable.rows[rowIdx]
  if not row then return end
  if self._selectedRowIdx == rowIdx then
    row:backdropColor(SELECTED)
  else
    row:backdropColor(0, 0, 0, 0)
  end
end

-- Resting backdrop for char row i: muted-gold wash for the logged-in character
-- (the suite-wide "this is you" marker, see SummaryView/GearView), transparent
-- otherwise. Padding rows have no toon, so they stay transparent.
---@param i integer  index into self.charTable.rows
function ProfsView:restCharRow(i)
  local row, toon = self.charTable.rows[i], self._charToons[i]
  if not row then return end
  if toon and toon.name == ns.api.GetCurrentCharacter() then
    row:backdropColor(theme.colors.selected)
  else
    row:backdropColor(0, 0, 0, 0)
  end
end

-- Rebuild the character list for profName; pass nil to clear the list. Re-applies the
-- table's active column sort (if any) so a chosen sort persists across profession
-- switches; a fresh selection with no active sort keeps buildCharList's default order.
---@param profName string|nil
function ProfsView:RebuildCharList(profName)
  self._charEntries = profName and buildCharList(self._toons, profName) or {}
  local key, desc = self.charTable:Sort()
  if key then sortCharEntries(self._charEntries, key, desc) end
  self:_renderCharRows()
end

-- onSort handler: re-sort the current entries by the clicked column and repaint. Kept
-- separate from RebuildCharList so a header click never rebuilds the entry list.
---@param key any      "name" or an expansion abbr
---@param desc boolean
function ProfsView:_sortCharList(key, desc)
  sortCharEntries(self._charEntries, key, desc)
  self:_renderCharRows()
end

-- Paint the char table from self._charEntries (already ordered): one row per entry,
-- rebuilding the index-parallel _charToons + per-row hover/click closures together so a
-- row click always opens the character now shown on that row.
function ProfsView:_renderCharRows()
  local entries = self._charEntries
  self._charToons = {}

  -- Build data rows for real characters.
  local rowData = {}
  for i, entry in ipairs(entries) do
    local toon   = entry.toon
    local detail = entry.detail
    self._charToons[i] = toon

    -- Map expansion abbreviation → data from this character's cached detail.
    local expMap = {}
    if detail and detail.expansions then
      for _, exp in ipairs(detail.expansions) do
        local abbr = EXP_ABBR[exp.name]
        if abbr then expMap[abbr] = exp end
      end
    end

    local row = {
      -- Faction icon.
      ns.factionIcon[toon.isAlliance],
      -- Character name (class coloured; realm on hover). The logged-in character
      -- is marked by a muted-gold row wash (see restCharRow), not inline.
      {
        text    = toon.name,
        color   = Colors[toon.classKey],
        onEnter = function(s)
          ui.tip:AnchorTo(s, "ANCHOR_BOTTOMRIGHT", -10, 10)
          ui.tip:ClearLines()
          ui.tip:AddLine(toon.realm)
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
      },
    }

    -- One cell per expansion, green if at cap.
    for _, abbr in ipairs(EXP_ORDER) do
      local exp = expMap[abbr]
      if exp then
        insert(row, {
          text  = exp.skillLevel,
          color = exp.skillLevel >= exp.maxSkillLevel and theme.colors.green or theme.colors.text,
        })
      else
        insert(row, { text = "—", color = DIM })
      end
    end

    insert(rowData, self:decorateCharRow(row, i, toon))
  end

  -- Grow the row pool to cover all real entries (update() would do this too,
  -- but doing it here lets us set backdrops/dividers before the update call).
  for _ = #self.charTable.rows + 1, #entries do
    self.charTable:addRow({})
  end
  self.charTable:ResizeRows(#entries)

  -- Pad data with empty rows to clear stale cells from a previous (larger) selection.
  local emptyRow = makeEmptyRow(self._charColCount)
  for _ = #entries + 1, #self.charTable.rows do
    insert(rowData, emptyRow)
  end

  -- Rows rest transparent (the void surface shows through) except the logged-in
  -- character's gold wash; a thin divider sits above each real row, hidden on the
  -- empty padding rows.
  for i, tblRow in ipairs(self.charTable.rows) do
    self:restCharRow(i)
    rowDivider(tblRow):SetShown(i <= #entries)
  end

  self.charTable.data = rowData
  self.charTable:update()
  self.emptyHint:SetShown(#entries == 0)
end

-- Make every cell in char row `i` drive the row hover highlight and open that
-- character in the Detail view on click, chaining onto any existing cell handlers
-- (so the name's realm tooltip keeps working). Each cell is a shallow COPY of the
-- source data — the faction-icon cell is a shared table object (ns.factionIcon[...]),
-- so mutating it in place would chain wrappers across every row sharing it.
---@param cells table  the row's per-column cell data array
---@param i integer    row index
---@param toon table   the character this row represents
---@return table cells
function ProfsView:decorateCharRow(cells, i, toon)
  for n, cell in ipairs(cells) do
    local src = type(cell) == "table" and cell or { text = cell }
    local copy = {}
    for k, v in pairs(src) do copy[k] = v end
    local onEnter, onLeave, onClick = src.onEnter, src.onLeave, src.onClick
    copy.onEnter = function(s)
      local row = self.charTable.rows[i]
      if row then row:backdropColor(theme.colors.hover) end
      if onEnter then onEnter(s) end
    end
    copy.onLeave = function(s)
      self:restCharRow(i)
      if onLeave then onLeave(s) end
    end
    copy.onClick = function(s)
      if onClick then onClick(s) end
      local w = ns.MainWindow
      if toon and w then
        w:getView("detail"):Select(toon)
        w:view("detail")
      end
    end
    cells[n] = copy
  end
  return cells
end

-- Called automatically by Region:Show() just before the frame becomes visible.
function ProfsView:OnBeforeShow()
  self._toons = self:GetCharacters()
  local bestSkills = buildBestSkills(self._toons)

  -- Build grid rows only for professions present in the warband.
  local visibleProfs = {}
  local gridRowData  = {}

  for _, profName in ipairs(PROF_ORDER) do
    local data = bestSkills[profName]
    if data then
      local rowIdx  = #visibleProfs + 1
      local onClick = function() self:SelectRow(rowIdx) end
      -- Whole row brightens on hover unless it's the selected row.
      local onEnter = function()
        if self._selectedRowIdx ~= rowIdx then
          local row = self.gridTable.rows[rowIdx]
          if row then row:backdropColor(theme.colors.hover) end
        end
      end
      local onLeave = function() self:RestoreGridRow(rowIdx) end

      insert(visibleProfs, profName)
      local row = { { text = profName, onClick = onClick, onEnter = onEnter, onLeave = onLeave } }
      for _, abbr in ipairs(EXP_ORDER) do
        local skill = data[abbr]
        local cell = skillCell(skill and skill.best, skill and skill.max, onClick)
        cell.onEnter = onEnter
        cell.onLeave = onLeave
        insert(row, cell)
      end
      insert(gridRowData, row)
    end
  end

  -- Grow grid row pool; rows stay transparent with a divider above each visible one.
  for _ = #self.gridTable.rows + 1, #visibleProfs do
    self.gridTable:addRow({})
  end
  self.gridTable:ResizeRows(#visibleProfs)
  for i, tblRow in ipairs(self.gridTable.rows) do
    tblRow:backdropColor(0, 0, 0, 0)
    rowDivider(tblRow):SetShown(i <= #visibleProfs)
  end

  self.gridTable.data = gridRowData
  self.gridTable:update()

  self._visibleProfs   = visibleProfs
  self._selectedRowIdx = nil

  -- Clear the character list.
  self:RebuildCharList(nil)

  local scrollTop = 8 + self.charTable.offsetY
  self:Width(VIEW_WIDTH)
  self:Height(self.gridTable:Height() + scrollTop + CHAR_LIST_H)
end
