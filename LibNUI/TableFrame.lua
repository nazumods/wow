---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local insert = table.insert
local Class, Frame, Texture = ns.lua.Class, ui.Frame, ui.Texture
local TableRow, TableCol, Cell = ui.TableRow, ui.TableCol, ui.Cell
local TopRight, BottomLeft, Right = ui.edge.TopRight, ui.edge.BottomLeft, ui.edge.Right
local Top, Bottom = ui.edge.Top, ui.edge.Bottom

-- making a table: https://www.wowinterface.com/forums/showthread.php?t=58670
---@class TableFrame: Frame
---@field autosize? boolean
---@field backdrop? table
---@field colBackdrop? table
---@field GetData? fun(): table
---@field colInfo? table
---@field rowInfo? table
---@field headerFont? string
---@field colHeaderFont? string
---@field headerHeight? integer
---@field cellHeight? integer
---@field cellWidth? integer
---@field padding? integer
---@field hPad? integer  horizontal inset (px) applied to both sides of every cell; per-column override via colInfo[i].hPad (or asymmetric colInfo[i].hPadL / hPadR)
---@field rowNames table
---@field offsetX integer
---@field rows table
---@field cols table
---@field cells table
---@field rowArea table
---@field footerHeight? integer  height of the footer row (defaults to cellHeight)
---@field footerBackdrop? table  backdrop for the footer row
---@field footerRow? table  the footer TableRow, created lazily by setFooter
---@field footerCells? table  footer Cell[] keyed by column index
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
        backdrop = self.colInfo and self.colInfo[i].backdrop or self.backdrop or self.colBackdrop or
          {color = math.fmod(i, 2) == 0 and "colEven" or "colOdd"},
      })
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
})
ui.TableFrame = TableFrame

-- Resize the frame to show exactly n rows, hiding dead space when the active
-- row count shrinks below the pool size. Safe to call after addRow growth loops.
function TableFrame:ResizeRows(n)
  local rowH = 0
  for i = 1, math.min(n, #self.rows) do
    rowH = rowH + (self.rowInfo[i] and self.rowInfo[i].height or self.cellHeight)
  end
  self.rowArea:Height(rowH)
  self:Height(self.offsetY + rowH)
end

function TableFrame:Autosize()
  local s, w = 0, 0
  if self.rowNames then
    for _,r in ipairs(self.rows) do
      s = max(s, r.header.label:Width())
    end
    s = s + (self.padding or 2)
    for _,r in ipairs(self.rows) do
      r.header.label:Width(s)
    end
  end
  local offset = s
  for i,c in ipairs(self.cols) do
    if self.autosize or (self.colInfo and self.colInfo[i].autosize) then
      s = c.header.label._widget:GetUnboundedStringWidth()
      for n = 1, #self.rows do
        if self.cells[n][i] and self.cells[n][i].label then
          s = max(s, self.cells[n][i].label._widget:GetUnboundedStringWidth())
        end
      end
      s = s + (self.padding or 2)
      c:Width(s)
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

function TableFrame:row(n) return self.rows[n] end
function TableFrame:col(n) return self.cols[n] end

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

function TableFrame:set(row, col, element)
  if #self.cells < row then
    for i=#self.cells+1,row do
      insert(self.cells, i, {})
    end
  end
  self.cells[row][col] = element
end

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
    backdrop = self.colInfo and self.colInfo[n].backdrop or self.backdrop or self.colBackdrop or
      {color = math.fmod(n, 2) == 0 and "colEven" or "colOdd"},
  })
  self:Width(self:Width()+w+padLeft)
  self.rowArea:Width(self.rowArea:Width()+w+padLeft)
  return self
end

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
        Height = 1,
      },
      color = "divider",
    }
    self.footerCells = {}
    self:Height(self:Height() + self.footerHeight)
  end
  for colN, cellData in pairs(data) do
    if not self.footerCells[colN] then
      self.footerCells[colN] = Cell:new{
        parent = self,
        name = "$parentFooterCell"..colN,
        position = self:cellPosition(colN, self.footerRow),
        data = cellData,
      }
    else
      self.footerCells[colN]:update(cellData)
    end
  end
  return self
end

function TableFrame:update()
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
