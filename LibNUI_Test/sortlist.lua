local toggling = LibNUITest.toggling
local window   = LibNUITest.window

local DATA = {
  { name = "Aludane",  level = 80, score = 2870 },
  { name = "Brinnea",  level = 74, score = 1210 },
  { name = "Corvash",  level = 80, score = 3105 },
  { name = "Delvana",  level = 68, score = 640  },
  { name = "Ellsworn", level = 80, score = 2440 },
  { name = "Fenwick",  level = 71, score = 980  },
}

-- SortableHeaderRow driving a VirtualList: click headers to sort (Score starts
-- descending), re-click to flip; Clear empties the list to show emptyText, Restore
-- refills — both via TextLink.
---@return TitleFrame
local function makeSortList()
  local f = window("SortList", 320, 300)

  local header = LibNUI.SortableHeaderRow:new{
    parent  = f,
    columns = {
      { key = "name",  label = "Name",  width = 120 },
      { key = "level", label = "Lvl",   width = 50, justifyH = "RIGHT" },
      { key = "score", label = "Score", width = 80, justifyH = "RIGHT", descFirst = true },
    },
    sortKey = "name",
    position = {
      TopLeft  = {f.titlebar, "BOTTOMLEFT", 10, -6},
      TopRight = {f.titlebar, "BOTTOMRIGHT", -10, -6},
    },
  }

  local list = LibNUI.VirtualList:new{
    parent    = f,
    emptyText = "No entries — Restore refills",
    position  = {
      TopLeft     = {header, "BOTTOMLEFT", 0, -2},
      BottomRight = {f, "BOTTOMRIGHT", -10, 32},
    },
    createRow = function(l)
      local row = LibNUI.Frame:new{ parent = l:Content(), background = {1, 1, 1, 0.03} }
      row.name  = LibNUI.Label:new{ parent = row, justifyH = "LEFT",  position = { Left = {row, 4, 0}, Width = 116 } }
      row.level = LibNUI.Label:new{ parent = row, justifyH = "RIGHT", position = { Left = {row, 122, 0}, Width = 50 } }
      row.score = LibNUI.Label:new{ parent = row, justifyH = "RIGHT", color = "header", position = { Left = {row, 174, 0}, Width = 80 } }
      return row
    end,
    updateRow = function(_, row, item)
      row.name:Text(item.name)
      row.level:Text(item.level)
      row.score:Text(item.score)
      return 20
    end,
  }

  local items = {}
  local function refill(key, desc)
    for i = #items, 1, -1 do items[i] = nil end
    for _, e in ipairs(DATA) do items[#items + 1] = e end
    if key then
      table.sort(items, function(a, b)
        if desc then return a[key] > b[key] end
        return a[key] < b[key]
      end)
    end
    list:SetItems(items)
  end
  header.onSort = function(_, key, desc) refill(key, desc) end
  refill(header:Sort())

  local clear = LibNUI.TextLink:new{
    parent   = f,
    text     = "Clear",
    onClick  = function() list:SetItems({}) end,
    position = { BottomLeft = {f, "BOTTOMLEFT", 12, 10} },
  }
  LibNUI.TextLink:new{
    parent   = f,
    text     = "Restore",
    onClick  = function() refill(header:Sort()) end,
    position = { Left = {clear, "RIGHT", 12, 0} },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "sortlist",
  name = "Sortable List",
  desc = "SortableHeaderRow + VirtualList emptyText + TextLink actions",
  run  = toggling(makeSortList),
})
