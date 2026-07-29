---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local insert = table.insert
local Class, Frame, Texture = ns.lua.Class, ui.Frame, ui.Texture
local TableRow, TableCol, Cell = ui.TableRow, ui.TableCol, ui.Cell
local TopRight, BottomLeft, Right = ui.edge.TopRight, ui.edge.BottomLeft, ui.edge.Right
local Top, Bottom = ui.edge.Top, ui.edge.Bottom

-- making a table: https://www.wowinterface.com/forums/showthread.php?t=58670
---@class TableFrame: Frame
---@field name? string
---@field autosize? boolean
---@field backdrop? table
---@field colBackdrop? table
---@field GetData? fun(): table
---@field colInfo? table
---@field rowInfo? table
---@field headerFont? string
---@field colHeaderFont? string
---@field rowHeaderFont? string
---@field headerHeight? integer
---@field cellHeight? integer
---@field cellWidth? integer
---@field padding? integer
---@field hPad? integer  horizontal inset (px) applied to both sides of every cell; per-column override via colInfo[i].hPad (or asymmetric colInfo[i].hPadL / hPadR)
---@field rowNames table
---@field offsetX integer
---@field offsetY integer
---@field rows table
---@field cols table
---@field cells table
---@field rowArea table
---@field footerHeight? integer  height of the footer row (defaults to cellHeight)
---@field footerBackdrop? table  backdrop for the footer row
---@field footerRow? table  the footer TableRow, created lazily by setFooter
---@field footerCells? table  footer Cell[] keyed by column index
---@field detachedFooter? boolean  opt-in: size footer cells to their own content and anchor each to its column by the justify-matching edge (instead of spanning the column), so a data column can autosize below its footer total's width
---@field onSort? fun(self: TableFrame, key: any, descending: boolean)  fired when a sortable header is clicked; the consumer sorts its own data and repaints (see `_clickSort`)
---@field _sortKey? any  key of the active sort column (nil = unsorted)
---@field _sortDesc? boolean  active sort direction
---@field _sortCols? table[]  {col, key} for every sortable column, driven by `_refreshSortHeaders`
---@field virtual? boolean  opt-in: build cell frames only for the rows the viewport can show, and
---  re-bind them to a sliding window of `data` as it scrolls. Off by default — see `BindViewport`
---  for the wiring and the constraints it imposes.
---@field overscan? integer  rows kept resident beyond each edge of the viewport (default 3)
---@field _viewport ScrollFrame?  bound viewport (virtual mode)
---@field _resident integer?  live row-frame count (virtual mode)
---@field _top integer?  data index currently bound to resident row 1 (virtual mode)
local TableFrame = Class(Frame, function(self)
  if not self.colNames and self.colInfo then
    self.colNames = {}
    for _,i in ipairs(self.colInfo) do insert(self.colNames, i.name or "") end
  end
  if not self.rowNames and self.rowInfo then
    self.rowNames = {}
    for _,i in ipairs(self.rowInfo) do insert(self.rowNames, i.name or "") end
  end

  self.numCols = self.numCols or (self.colNames and #self.colNames) or 0
  self.numRows = self.numRows or (self.rowNames and #self.rowNames) or 0
  self.headerWidth = self.headerWidth or self.cellWidth
  self.headerHeight = self.headerHeight or self.cellHeight
  self.offsetX = self.rowNames ~= nil and self.headerWidth or 0
  self.offsetY = self.colNames ~= nil and self.headerHeight or 0
  self.colHeight = self.cellHeight * (self.numRows) + self.headerHeight
  local width = self.offsetX
  local height = self.offsetY

  self.cols = {}
  self.rows = {}
  self._sortCols = {}

  if self.colNames then
    for i=1,#self.colNames do
      local w = self.colInfo and self.colInfo[i].width or self.cellWidth
      local padLeft = (i > 1 and self.colInfo and self.colInfo[i].padLeft) or 0
      width = width + w + padLeft
      insert(self.cols, TableCol:new{
        parent = self,
        name = "$parentCol"..i,
        label = self.colNames[i],
        atlas = self.colInfo and self.colInfo[i].atlas,
        atlasSize = self.colInfo and self.colInfo[i].atlasSize,
        path = self.colInfo and self.colInfo[i].path,
        coords = self.colInfo and self.colInfo[i].coords,
        vertexColor = self.colInfo and self.colInfo[i].vertexColor,
        iconOffsetX = self.colInfo and self.colInfo[i].iconOffsetX,
        headerHeight = self.headerHeight,
        position = {
          TopLeft = i == 1 and {self.offsetX, 0} or {self.cols[i-1], TopRight, padLeft, 0},
          Bottom = {},
          Width = w,
        },
        padding = self.colInfo and self.colInfo[i].padding or nil,
        justifyH = self.colInfo and self.colInfo[i].justifyH,
        font = self.colHeaderFont or self.headerFont,
        color = self.colInfo and self.colInfo[i].color,
        tooltip = self.colInfo and self.colInfo[i].tooltip,
        sortable = self.colInfo and self.colInfo[i].sortable,
        backdrop = self.colInfo and self.colInfo[i].backdrop or self.backdrop or self.colBackdrop or
          {color = math.fmod(i, 2) == 0 and "colEven" or "colOdd"},
      })
      self:_wireSortCol(self.cols[i], self.colInfo and self.colInfo[i], i)
    end
  end

  self.rowArea = Frame:new{
    parent = self,
    position = {
      TopLeft = {0, -self.offsetY},
      Width = width,
    },
  }

  if self.rowNames then
    for i=1,#self.rowNames do
      local h = self.rowInfo and self.rowInfo[i].height or self.cellHeight
      height = height + h
      insert(self.rows, TableRow:new{
        parent = self.rowArea,
        name = "$parentRow"..i,
        label = self.rowNames[i],
        atlas = self.rowInfo and self.rowInfo[i].atlas,
        atlasSize = self.rowInfo and self.rowInfo[i].atlasSize,
        position = {
          TopLeft = i == 1 and {0, 0} or {self.rows[i-1], BottomLeft},
          Right = {},
          Height = h,
        },
        justifyH = self.rowInfo and self.rowInfo[i].justifyH,
        font = self.rowHeaderFont or self.headerFont,
        color = self.rowInfo and self.rowInfo[i].color,
        backdrop = self.rowInfo and self.rowInfo[i].backdrop or self.backdrop or
          {color = math.fmod(i, 2) == 0 and "rowEven" or "rowOdd"}
      })
    end
  end
  self.rowArea:Height(height - self.offsetY)

  self.cells = {}
  for i=1,self.numRows do
    insert(self.cells, i, {})
  end

  if not self.colInfo then self.colInfo = {} end
  if not self.rowInfo then self.rowInfo = {} end

  self:Width(width)
  self:Height(height)
end, {
  cellWidth = 100,
  cellHeight = 20,
  virtual = false,
  overscan = 3,
})
ui.TableFrame = TableFrame

-- ─── Viewport virtualisation (opt-in via `virtual = true`) ────────────────────
--
-- A static table builds one cell frame per (row, column) in `data`. That cost is a function of the
-- DATA size, not of what the user can see: a 473-row grid in a 23-row viewport built 6,622 cells to
-- show ~5% of them, and the frame count drove not just creation but the engine's own layout pass and
-- the scroll frame's content-extent walk (nazumods/wow#843).
--
-- Virtual mode keeps only enough row frames to cover the viewport (plus `overscan` beyond each edge)
-- and re-binds them to a sliding window of `data` as the view scrolls. The row area still spans
-- every data row, so the scrollbar range and any offset maths a consumer already does are unchanged
-- — only the number of frames inside it shrinks.
--
-- CONSTRAINTS, all of them checkable at the call site:
--   * **Uniform row height.** The window↔offset mapping is `floor(offset / cellHeight)`, so per-row
--     `rowInfo[i].height` is not honoured. A variable-height table needs a prefix-sum index; not
--     built, because nothing needs it yet.
--   * **`Autosize` measures resident rows only.** It walks `self.rows`/`self.cells`, which in this
--     mode is the visible window — so a column sized from cell text would resize as you scroll. Size
--     such a column from the DATA instead, or give it a fixed width.
--   * **Row headers are per-frame**, so `rowNames` entries follow the window rather than the data.
--     Don't combine `virtual` with row headers.
--   * **No footer.** `setFooter` anchors to the row area's bottom, which is now the bottom of the
--     whole dataset rather than of the visible rows.

-- Bind the viewport this table scrolls inside. Required for `virtual` — without it there is no
-- offset to derive the window from. The scroll frame's child must be this table's `rowArea`, which
-- is already how a scrolling TableFrame is wired.
---@param scroll ScrollFrame  the viewport whose child is `self.rowArea`
---@return TableFrame
function TableFrame:BindViewport(scroll)
  self._viewport = scroll
  -- Chain rather than replace: a consumer may already be watching its own scroll.
  local prior = scroll.onScroll
  scroll.onScroll = function(s, offset)
    if prior then prior(s, offset) end
    self:_rebind()
  end
  scroll._widget:SetScript("OnVerticalScroll", function(_, offset) scroll:onScroll(offset) end)
  return self
end

-- How many row frames it takes to cover the viewport, plus overscan at both edges.
---@return integer
function TableFrame:_residentCount()
  local view = self._viewport and self._viewport:Height() or 0
  return math.max(math.ceil(view / self.cellHeight) + self.overscan * 2, 1)
end

-- Grow the resident pool to cover the viewport, size the row area to the WHOLE dataset (so the
-- scroll range still spans every row), and bind the window to the current offset.
function TableFrame:_virtualUpdate()
  local n, rowH = #self.data, self.cellHeight
  local want = math.min(self:_residentCount(), n)
  for _ = #self.rows + 1, want do self:addRow{} end
  -- Hide any resident rows this dataset doesn't need (a smaller `data` than a previous pass).
  for i = 1, #self.rows do
    local live = i <= want
    self.rows[i]:SetShown(live)
    for _, cell in pairs(self.cells[i]) do cell:SetShown(live) end
  end
  self._resident = want
  -- addRow grew both heights by a row apiece as it went, so both are restated outright rather than
  -- adjusted — but they are NOT the same number.
  --
  -- The row area is the scroll child, so it spans the whole dataset: that extent is what gives the
  -- viewport its scroll range. The table itself is not scrolled — it holds the column frames, which
  -- anchor their Bottom to it — so sizing it to the dataset stretches every column backdrop
  -- thousands of pixels past the viewport and paints them down the screen as vertical bands. It
  -- gets the visible height instead.
  self.rowArea:Height(n * rowH)
  local visibleH = self._viewport and self._viewport:Height() or (want * rowH)
  self:Height(self.offsetY + visibleH)
  self._top = nil   -- force the bind below even if the offset hasn't moved
  self:_rebind()
end

-- Point the resident rows at the slice of `data` the current offset exposes. Cheap enough to run on
-- every scroll event: it early-outs unless the window actually moved, and when it does move it costs
-- one re-anchor plus one `Cell:update` per resident cell — no frame creation.
function TableFrame:_rebind()
  local resident = self._resident
  if not (self.virtual and resident and resident > 0) then return end
  local rowH, n = self.cellHeight, #self.data
  local offset = self._viewport and self._viewport:VerticalScroll() or 0
  local first = math.floor(offset / rowH) - self.overscan + 1
  local last = n - resident + 1
  if first > last then first = last end
  if first < 1 then first = 1 end
  if first == self._top then return end
  self._top = first

  for k = 1, resident do
    local rowFrame, dataRow = self.rows[k], self.data[first + k - 1]
    -- Resident frames are a sliding window, so they can't stay chained to their predecessor the way
    -- a static table's are — each is placed at its data row's absolute offset. Re-setting TOPLEFT
    -- replaces that point and leaves the row's Right/Height anchors alone (a ClearAllPoints here
    -- would drop them).
    rowFrame:TopLeft(self.rowArea, ui.edge.TopLeft, 0, -((first + k - 2) * rowH))
    for colN = 1, #self.cols do
      local data = dataRow and dataRow[colN]
      local cell = self.cells[k][colN]
      if data and not cell then
        self.cells[k][colN] = Cell:new{
          parent = self.rowArea,
          name = "$parentCell"..k.."-"..colN,
          position = self:cellPosition(colN, rowFrame),
          data = data,
        }
      elseif data then
        cell:update(data)
        cell:Show()
      elseif cell then
        -- The incoming row has nothing for this column; blank the slot rather than leaving the
        -- previous occupant's content sitting under a different row's data.
        cell:Hide()
      end
    end
  end
end

-- Resize the frame to show exactly n rows, hiding dead space when the active
-- row count shrinks below the pool size. Safe to call after addRow growth loops.
---@param n integer  number of visible rows
function TableFrame:ResizeRows(n)
  -- No-op in virtual mode: the resident window already governs which frames exist, and the row
  -- area is already sized to the whole dataset. Hiding "surplus" rows here would blank part of the
  -- visible window, since a resident row index is a viewport slot, not a data row.
  if self.virtual then return end
  local rowH = 0
  for i = 1, math.min(n, #self.rows) do
    rowH = rowH + (self.rowInfo[i] and self.rowInfo[i].height or self.cellHeight)
  end
  self.rowArea:Height(rowH)
  -- Include the detached footer band (setFooter grows the frame by footerHeight once); without
  -- it a ResizeRows after setFooter would size over the footer cells anchored to the column bottoms.
  self:Height(self.offsetY + rowH + (self.footerRow and self.footerHeight or 0))
  -- Show exactly n rows: hide the rest *and their cells* (cells parent to the row area,
  -- not the row). A ScrollFrame derives its range from the scroll child's content extent,
  -- not its set height — rows left shown below the shrunk row area would keep the range
  -- full and let a hosting scroll view overscroll into dead space below the data.
  for i = 1, #self.rows do
    local shown = i <= n
    self.rows[i]:SetShown(shown)
    for _, cell in pairs(self.cells[i]) do cell:SetShown(shown) end
  end
end

function TableFrame:Autosize()
  local s, w = 0, 0
  if self.rowNames then
    -- A texture-only row header (built from an atlas/path rowInfo) has no .label,
    -- only .texture — skip it rather than nil-index its width.
    for _,r in ipairs(self.rows) do
      if r.header.label then s = max(s, r.header.label:Width()) end
    end
    s = s + (self.padding or 2)
    for _,r in ipairs(self.rows) do
      if r.header.label then r.header.label:Width(s) end
    end
  end
  local offset = s
  for i,c in ipairs(self.cols) do
    if self.autosize or (self.colInfo and self.colInfo[i].autosize) then
      -- Widest string in the column: the header, then every cell. An icon-only header or
      -- cell has no .label (AutoWidget built a Texture instead), so skip it — a column with
      -- no text anywhere keeps its configured width rather than nil-indexing the header or
      -- collapsing to padding. Mirrors the row-header/cell guards above and below.
      local widest
      if c.header.label then widest = c.header.label._widget:GetUnboundedStringWidth() end
      for n = 1, #self.rows do
        if self.cells[n][i] and self.cells[n][i].label then
          local cw = self.cells[n][i].label._widget:GetUnboundedStringWidth()
          widest = widest and max(widest, cw) or cw
        end
      end
      if widest then c:Width(widest + (self.padding or 2)) end
      if i == 1 then c:TopLeft(offset, 0) end
    end
    w = w + c:Width()
  end
  self:Width(offset + w)
  -- force the rows to recompute their bounds
  for _,r in ipairs(self.rows) do
    r:Right(self, ui.edge.Right)
  end
end

function TableFrame:onLoad()
  if not self.data and self.GetData then self.data = self:GetData() end
  if self.data then self:update() end
  if self.autosize then self:Autosize() end
end

---@param n integer
---@return TableRow
function TableFrame:row(n) return self.rows[n] end
---@param n integer
---@return TableCol
function TableFrame:col(n) return self.cols[n] end

-- ─── Sorting ────────────────────────────────────────────────────────────────
-- Opt-in per column via colInfo (`sortable`, optional `sortKey`, `descFirst`). The
-- frame owns the header UI + active-sort state; the consumer owns the comparator and
-- repaint via `onSort` (TableFrame never permutes `self.data` itself, so a consumer's
-- index-parallel state stays aligned). Mirrors SortableHeaderRow's contract.

-- Point a freshly-built sortable column's header at `_clickSort` and record it so
-- `_refreshSortHeaders` can restyle it. No-op for a column that didn't opt in.
---@param col TableCol
---@param info table?  the column's colInfo entry
---@param i integer    column index (fallback sort key)
function TableFrame:_wireSortCol(col, info, i)
  if not (info and info.sortable) then return end
  local key, descFirst = info.sortKey or i, info.descFirst
  col.onHeaderClick = function() self:_clickSort(key, descFirst) end
  self._sortCols[#self._sortCols + 1] = { col = col, key = key }
end

-- Restyle every sortable header for the current sort state (active = accent + arrow).
function TableFrame:_refreshSortHeaders()
  for _, c in ipairs(self._sortCols) do
    c.col:SetSortState(c.key == self._sortKey, self._sortDesc or false)
  end
end

-- A user clicked a sortable header: the active column flips direction, a new column
-- starts at its natural direction (`descFirst` or ascending). Fires `onSort` so the
-- consumer re-sorts its data and repaints.
---@param key any
---@param descFirst boolean?
function TableFrame:_clickSort(key, descFirst)
  if self._sortKey == key then
    self._sortDesc = not self._sortDesc
  else
    self._sortKey, self._sortDesc = key, descFirst or false
  end
  self:_refreshSortHeaders()
  if self.onSort then self:onSort(self._sortKey, self._sortDesc) end
end

-- Get the active sort as (key, descending), or set it programmatically (no `onSort`).
-- Pass `key = nil` to read; set a key to make it the active sort and restyle headers.
---@param key any?
---@param descending boolean?
---@return any, boolean|TableFrame
function TableFrame:Sort(key, descending)
  if key == nil then return self._sortKey, self._sortDesc or false end
  self._sortKey, self._sortDesc = key, descending or false
  self:_refreshSortHeaders()
  return self
end

-- Position table for a cell in column `colN` spanning `rowFrame` vertically.
-- Left/right anchors are inset by the column's horizontal pad so a column can
-- breathe without padding the rows top/bottom. Padding is read per-column from
-- colInfo (hPadL/hPadR, or hPad as a both-sides shorthand) falling back to the
-- table-level hPad; sides default independently so `hPadL` alone insets the
-- left edge only (handy for pushing the first/last column off the table edge).
---@param colN integer
---@param rowFrame table  the TableRow (or footer row) the cell sits in
---@return table
function TableFrame:cellPosition(colN, rowFrame)
  local info = self.colInfo and self.colInfo[colN]
  local hPad = (info and info.hPad) or self.hPad or 0
  local padL = (info and info.hPadL) or hPad
  local padR = (info and info.hPadR) or hPad
  return {
    Top = {rowFrame, Top},
    Bottom = {rowFrame, Bottom},
    Left = {self.cols[colN], ui.justify.Left, padL, 0},
    Right = {self.cols[colN], Right, -padR, 0},
  }
end

-- Store an externally-built cell element, growing the cell grid as needed.
---@param row integer
---@param col integer
---@param element table  the cell (or any widget) occupying that grid slot
function TableFrame:set(row, col, element)
  if #self.cells < row then
    for i=#self.cells+1,row do
      insert(self.cells, i, {})
    end
  end
  self.cells[row][col] = element
end

-- Append a column, widening the table. `info` matches a colInfo entry.
---@param info table
---@return TableFrame
function TableFrame:addCol(info)
  local n = #self.cols + 1
  self.colInfo[n] = info
  local w = self.colInfo and self.colInfo[n].width or self.cellWidth
  local padLeft = (n > 1 and self.colInfo[n].padLeft) or 0
  insert(self.cols, TableCol:new{
    parent = self,
    name = "$parentCol"..n,
    label = self.colInfo[n].name,
    -- mirror the constructor's per-column header options so columns added
    -- dynamically render identically to ones declared up front
    atlas = self.colInfo[n].atlas,
    atlasSize = self.colInfo[n].atlasSize,
    path = self.colInfo[n].path,
    coords = self.colInfo[n].coords,
    vertexColor = self.colInfo[n].vertexColor,
    iconOffsetX = self.colInfo[n].iconOffsetX,
    color = self.colInfo[n].color,
    padding = self.colInfo[n].padding,
    headerHeight = self.headerHeight,
    position = {
      TopLeft = n == 1 and {self.offsetX, 0} or {self.cols[n-1], TopRight, padLeft, 0},
      Bottom = {},
      Width = w,
    },
    justifyH = self.colInfo and self.colInfo[n].justifyH,
    font = self.colHeaderFont or self.headerFont,
    tooltip = self.colInfo and self.colInfo[n].tooltip,
    sortable = self.colInfo[n].sortable,
    backdrop = self.colInfo and self.colInfo[n].backdrop or self.backdrop or self.colBackdrop or
      {color = math.fmod(n, 2) == 0 and "colEven" or "colOdd"},
  })
  self:_wireSortCol(self.cols[n], self.colInfo[n], n)
  self:Width(self:Width()+w+padLeft)
  self.rowArea:Width(self.rowArea:Width()+w+padLeft)
  return self
end

-- Append a row, growing the table. `info` matches a rowInfo entry.
---@param info table
---@return TableFrame
function TableFrame:addRow(info)
  local n = #self.rows + 1
  self.rowInfo[n] = info
  insert(self.cells, {})
  local h = self.rowInfo and self.rowInfo[n].height or self.cellHeight
  insert(self.rows, n, TableRow:new{
    parent = self.rowArea,
    name = "$parentRow"..n,
    label = self.rowInfo[n].name,
    position = {
      TopLeft = n == 1 and {0, 0} or {self.rows[n-1], BottomLeft},
      Right = {},
      Height = h,
    },
    -- mirror the constructor's per-row header options so rows added dynamically
    -- render identically to ones declared up front
    justifyH = self.rowInfo[n].justifyH,
    font = self.rowHeaderFont or self.headerFont,
    color = self.rowInfo and self.rowInfo[n].color,
    backdrop = self.rowInfo and self.rowInfo[n].backdrop or self.backdrop or
      {color = math.fmod(n, 2) == 0 and "rowEven" or "rowOdd"},
  })
  self.rowArea:Height(self.rowArea:Height()+h)
  self:Height(self:Height()+h)
  return self
end

-- Position a *detached* footer cell (opt-in via `detachedFooter`). Instead of
-- spanning its column (Left→Right, which clamps the cell to the column width), the
-- cell anchors to the column's BOTTOM by the single edge matching its justification
-- and is sized to its own content by the caller. Columns span down to the table
-- bottom, which coincides with the footer band, so anchoring to the column bottom
-- lands the cell in the footer row while tracking its column horizontally — this is
-- what decouples the footer's width from the column's: a data column can autosize to
-- its values while a wider total overflows into the empty footer space beside it.
-- Padding matches cellPosition's per-column hPad resolution.
---@param colN integer
---@param justifyH string  the cell's ui.justify constant (Left/Center/Right)
---@return table
function TableFrame:detachedFooterPosition(colN, justifyH)
  local info = self.colInfo and self.colInfo[colN]
  local hPad = (info and info.hPad) or self.hPad or 0
  local padL = (info and info.hPadL) or hPad
  local padR = (info and info.hPadR) or hPad
  local col = self.cols[colN]
  if justifyH == ui.justify.Right then
    return { BottomRight = {col, ui.edge.BottomRight, -padR, 0}, Height = self.footerHeight }
  elseif justifyH == ui.justify.Center then
    return { Bottom = {col, ui.edge.Bottom, 0, 0}, Height = self.footerHeight }
  end
  return { BottomLeft = {col, ui.edge.BottomLeft, padL, 0}, Height = self.footerHeight }
end

-- Build (or refresh) a footer row pinned below the data rows. `data` is a
-- per-column map of cell data (same shape as a row's cell data) keyed by column
-- index; columns absent from `data` get no footer cell. Reuses footer cells on
-- subsequent calls so it can be re-run to refresh, like `update()`.
---@param data table  footer cell data keyed by column index
---@return TableFrame
function TableFrame:setFooter(data)
  if not self.footerRow then
    self.footerHeight = self.footerHeight or self.cellHeight
    self.footerRow = TableRow:new{
      parent = self,
      name = self.name and self.name.."Footer" or nil,
      position = {
        TopLeft = {self.rowArea, BottomLeft, 0, 0},
        Right = {},
        Height = self.footerHeight,
      },
      backdrop = self.footerBackdrop or {color = "footer"},
    }
    Texture:new{
      parent = self.footerRow,
      layer = ui.layer.Overlay,
      position = {
        TopLeft = {self.footerRow, ui.edge.TopLeft, 0, 0},
        TopRight = {self.footerRow, ui.edge.TopRight, 0, 0},
        PixelHeight = 1,
      },
      color = "divider",
    }
    self.footerCells = {}
    self:Height(self:Height() + self.footerHeight)
  end
  for colN, cellData in pairs(data) do
    if not self.footerCells[colN] then
      local justifyH = (type(cellData) == "table" and cellData.justifyH) or ui.justify.Left
      self.footerCells[colN] = Cell:new{
        parent = self,
        name = "$parentFooterCell"..colN,
        position = self.detachedFooter and self:detachedFooterPosition(colN, justifyH)
          or self:cellPosition(colN, self.footerRow),
        data = cellData,
      }
    else
      self.footerCells[colN]:update(cellData)
    end
    -- A detached footer cell is sized to its own content (not clamped to the
    -- column), so a wide aggregate total overflows into neighbouring empty footer
    -- space instead of forcing the column wider. Re-measured on every refresh:
    -- the total's text width changes with the data (and the cell anchors by one
    -- edge, so the width simply grows/shrinks away from that edge).
    if self.detachedFooter then
      local cell = self.footerCells[colN]
      cell:Width(math.ceil(cell.label and cell.label:UnboundedWidth() or 0) + 2)
    end
  end
  return self
end

function TableFrame:update()
  -- Virtual tables size their pool to the viewport, not to the data, so they take their own path
  -- rather than the create-a-cell-per-data-row loop below.
  if self.virtual then return self:_virtualUpdate() end
  for rowN,row in ipairs(self.data) do
    if not self.rows[rowN] then self:addRow{} end
    -- ipairs stops at the first nil, dropping data in sparse rows.
    local maxCol = #self.cols
    for k in pairs(row) do
      if type(k) == "number" and k > maxCol then maxCol = k end
    end
    for colN = 1, maxCol do
      local data = row[colN]
      if not self.cols[colN] then self:addCol{} end
      if data and not self.cells[rowN][colN] then
        self.cells[rowN][colN] = Cell:new{
          parent = self.rowArea,
          name = "$parentCell"..rowN.."-"..colN,
          position = self:cellPosition(colN, self.rows[rowN]),
          data = data,
        }
      elseif data then
        self.cells[rowN][colN]:update(data)
      end
    end
  end
end
