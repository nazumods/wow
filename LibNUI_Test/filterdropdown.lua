local FilterDropdown = LibNUI.FilterDropdown
local Label    = LibNUI.Label
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Two filter dropdowns wired to a readout. Exercises the labelled button + chevron,
-- the option menu (including a disabled, greyed, unselectable entry), `onSelect`, the
-- `bordered` frame, and the shared behaviour: opening one menu closes the other, and
-- Esc closes only the open menu (try Esc with a menu up vs. none — with none, Esc
-- should close the test window instead).
---@return TitleFrame
local function makeFilterDropdown()
  local f = window("FilterDropdown", 320, 120)

  local readout = Label:new{
    parent = f,
    position = { Top = {f.titlebar, "BOTTOM", 0, -16} },
    text = "pick one",
  }

  FilterDropdown:new{
    parent = f,
    position = { TopLeft = {f, "TOPLEFT", 20, -44} },
    width = 130, menuWidth = 150, bordered = true, selected = "all",
    options = {
      { key = "all", label = "Expansion" },
      { key = 11,    label = "The War Within" },
      { key = 12,    label = "Midnight" },
      { key = 99,    label = "Disabled", enabled = false },
    },
    onSelect = function(_, key) readout:Text("expansion: " .. tostring(key)) end,
  }

  FilterDropdown:new{
    parent = f,
    position = { TopLeft = {f, "TOPLEFT", 160, -44} },
    width = 110, menuWidth = 120, bordered = true, selected = "all",
    options = {
      { key = "all",  label = "Category" },
      { key = "Raid", label = "Raid" },
      { key = "PvP",  label = "PvP" },
    },
    onSelect = function(_, key) readout:Text("category: " .. tostring(key)) end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "filterdropdown",
  name = "Filter Dropdown",
  desc = "Labelled dropdown menu (bordered); Esc closes only it, one open at a time",
  run  = toggling(makeFilterDropdown),
})
