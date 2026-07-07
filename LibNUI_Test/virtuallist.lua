local VirtualList = LibNUI.VirtualList
local Frame       = LibNUI.Frame
local Label       = LibNUI.Label
local toggling    = LibNUITest.toggling
local window      = LibNUITest.window

-- 40 rows of mixed height in a pooled scrolling list: proves the row pool, the variable
-- heights, and the themed scrollbar (every 5th row is a tall row).
---@return TitleFrame
local function makeVirtualList()
  local f = window("VirtualList", 300, 320)

  local list = VirtualList:new{
    parent   = f,
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT",  6, -6},
      BottomRight = {f,          "BOTTOMRIGHT", -6,  6},
    },
    createRow = function(l)
      local row = Frame:new{ parent = l:Content(), background = {1, 1, 1, 0.03} }
      row.label = Label:new{ parent = row, position = { Left = {row, 8, 0} } }
      return row
    end,
    updateRow = function(_, row, item)
      row.label:Text(item.text)
      return item.height
    end,
  }

  local items = {}
  for i = 1, 40 do
    local tall = (i % 5 == 0)
    items[i] = { text = "Row " .. i .. (tall and "  (tall)" or ""), height = tall and 40 or 22 }
  end
  list:SetItems(items)

  return f
end

table.insert(LibNUITest.tests, {
  key  = "virtuallist",
  name = "VirtualList",
  desc = "Pooled variable-height scrolling list (40 rows, every 5th tall)",
  run  = toggling(makeVirtualList),
})
