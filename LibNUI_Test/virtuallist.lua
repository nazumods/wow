local VirtualList = LibNUI.VirtualList
local Frame       = LibNUI.Frame
local Label       = LibNUI.Label
local toggling    = LibNUITest.toggling
local window      = LibNUITest.window

-- 40 rows of mixed height in a pooled scrolling list: proves the row pool, the variable
-- heights, and the themed scrollbar (every 5th row is a tall row). Up/Down arrows drive a
-- selection highlight via VirtualList:Row + :ScrollToItem — the selectable-list primitives.
---@return TitleFrame
local function makeVirtualList()
  local f = window("VirtualList", 300, 320)

  local sel
  local list
  list = VirtualList:new{
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
    updateRow = function(_, row, item, i)
      row.label:Text(item.text)
      row.background:Color(i == sel and {0.3, 0.5, 0.9, 0.4} or {1, 1, 1, 0.03})
      return item.height
    end,
  }

  local items = {}
  for i = 1, 40 do
    local tall = (i % 5 == 0)
    items[i] = { text = "Row " .. i .. (tall and "  (tall)" or ""), height = tall and 40 or 22 }
  end
  list:SetItems(items)

  -- Arrow-key selection: recolour the previous + new row via :Row, then :ScrollToItem.
  local function select(idx)
    idx = idx < 1 and 1 or (idx > #items and #items or idx)
    local prev = sel and list:Row(sel)
    if prev then prev.background:Color(1, 1, 1, 0.03) end
    sel = idx
    local row = list:Row(idx)
    if row then row.background:Color(0.3, 0.5, 0.9, 0.4) end
    list:ScrollToItem(idx)
  end
  f._widget:EnableKeyboard(true)
  f._widget:SetScript("OnKeyDown", function(_, key)
    if key == "UP" then select((sel or 1) - 1)
    elseif key == "DOWN" then select((sel or 1) + 1) end
  end)
  select(1)

  return f
end

table.insert(LibNUITest.tests, {
  key  = "virtuallist",
  name = "VirtualList",
  desc = "Pooled list; Up/Down select via Row + ScrollToItem (40 rows, every 5th tall)",
  run  = toggling(makeVirtualList),
})
