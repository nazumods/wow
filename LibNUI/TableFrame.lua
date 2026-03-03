local _, ns = ...
local ui = ns.ui
local insert = table.insert
local Class, Frame = ns.lua.Class, ui.Frame
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
---@field rowNames table
---@field offsetX integer
---@field rows table
---@field cols table
---@field cells table
---@field rowArea table
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
      width = width + w
      insert(self.cols, TableCol:new{
        parent = self,
        name = "$parentCol"..i,
        label = self.colNames[i],
        atlas = self.colInfo and self.colInfo[i].atlas,
        atlasSize = self.colInfo and self.colInfo[i].atlasSize,
        headerHeight = self.headerHeight,
        position = {
          TopLeft = i == 1 and {self.offsetX, 0} or {self.cols[i-1], TopRight, self.colInfo and self.colInfo[i].padLeft or 0, 0},
          Bottom = {},
          Width = w,
        },
        padding = self.colInfo and self.colInfo[i].padding or nil,
        justifyH = self.colInfo and self.colInfo[i].justifyH,
        font = self.colHeaderFont or self.headerFont,
        color = self.colInfo and self.colInfo[i].color,
        backdrop = self.colInfo and self.colInfo[i].backdrop or self.backdrop or self.colBackdrop or
          {color = {0, 0, 0, math.fmod(i, 2) == 0 and 0.6 or 0.4}},
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
          {color = {0, 0, 0, math.fmod(i, 2) == 0 and 0.2 or 0}}
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

function TableFrame:onLoad()
  if not self.data and self.GetData then self.data = self:GetData() end
  if self.data then self:update() end

  if self.autosize then
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
        for n,r in ipairs(self.rows) do
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
end

function TableFrame:row(n) return self.rows[n] end
function TableFrame:col(n) return self.cols[n] end

function TableFrame:set(row, col, element)
  if #self.cells < row then
    for i=#self.cells,row do
      insert(self.cells, i, {})
    end
  end
  self.cells[row][col] = element
end

function TableFrame:addCol(info)
  local n = #self.cols + 1
  self.colInfo[n] = info
  local w = self.colInfo and self.colInfo[n].width or self.cellWidth
  insert(self.cols, TableCol:new{
    parent = self,
    name = "$parentCol"..n,
    label = self.colInfo[n].name,
    headerHeight = self.headerHeight,
    position = {
      TopLeft = n == 1 and {self.offsetX, 0} or {self.cols[n-1], TopRight},
      Bottom = {},
      Width = w,
    },
    justifyH = self.colInfo and self.colInfo[n].justifyH,
    font = self.colHeaderFont or self.headerFont,
    backdrop = self.colInfo and self.colInfo[n].backdrop or self.backdrop or self.colBackdrop or
      {color = {0, 0, 0, math.fmod(n, 2) == 0 and 0.6 or 0.4}},
  })
  self:Width(self:Width()+w)
  self.rowArea:Width(self.rowArea:Width()+w)
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
    color = self.rowInfo and self.rowInfo[n].color,
    backdrop = self.rowInfo and self.rowInfo[n].backdrop or self.backdrop or
      {color = {0, 0, 0, math.fmod(n, 2) == 0 and 0.2 or 0}},
  })
  self.rowArea:Height(self.rowArea:Height()+h)
  self:Height(self:Height()+h)
  return self
end

function TableFrame:update()
  for rowN,row in ipairs(self.data) do
    if not self.rows[rowN] then self:addRow{} end
    for colN,data in ipairs(row) do
      if not self.cols[colN] then self:addCol{} end
      if data and not self.cells[rowN][colN] then
        self.cells[rowN][colN] = Cell:new{
          parent = self.rowArea,
          name = "$parentCell"..rowN.."-"..colN,
          position = {
            Top = {self.rows[rowN], Top},
            Bottom = {self.rows[rowN], Bottom},
            Left = {self.cols[colN], ui.justify.Left},
            Right = {self.cols[colN], Right},
          },
          data = data,
        }
      elseif data then
        self.cells[rowN][colN]:update(data)
      end
    end
  end
end
