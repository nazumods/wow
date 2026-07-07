local Accordion = LibNUI.Accordion
local Frame     = LibNUI.Frame
local Label     = LibNUI.Label
local toggling  = LibNUITest.toggling
local window    = LibNUITest.window

-- Three collapsible sections (one expanded to start): proves header carets toggle their
-- child rows, the list re-stacks on toggle, and onToggle fires. Child rows print nothing;
-- header toggles print to chat.
---@return TitleFrame
local function makeAccordion()
  local f = window("Accordion", 300, 320)

  local acc = Accordion:new{
    parent   = f,
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT",  6, -6},
      BottomRight = {f,          "BOTTOMRIGHT", -6,  6},
    },
    createRow = function(a)
      local row = Frame:new{ parent = a:Content() }
      row.label = Label:new{ parent = row, color = "muted", position = { Left = {row, 24, 0} } }
      return row
    end,
    updateRow = function(_, row, rowData)
      row.label:Text(rowData)
      return 20
    end,
    onToggle = function(_, key, expanded)
      print(("|cFF88CCFF[LibNUITest]|r %s -> %s"):format(tostring(key), expanded and "expanded" or "collapsed"))
    end,
  }

  acc:SetSections({
    { key = "fruit", title = "Fruit", expanded = true, rows = {"Apple", "Banana", "Cherry", "Date"} },
    { key = "veg",   title = "Vegetables",             rows = {"Carrot", "Pea", "Onion"} },
    { key = "grain", title = "Grains",                 rows = {"Rice", "Wheat", "Oats", "Barley", "Rye"} },
  })

  return f
end

table.insert(LibNUITest.tests, {
  key  = "accordion",
  name = "Accordion",
  desc = "Collapsible sections with pooled child rows (built on VirtualList)",
  run  = toggling(makeAccordion),
})
