local FilterDropdown = LibNUI.FilterDropdown
local Label    = LibNUI.Label
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Three dropdowns wired to a readout. Verify the select behaviour: the menu hangs
-- flush under the button's left edge and is never narrower than it (the first
-- dropdown's overlong option widens the menu), option text lines up exactly with
-- the button text, the current selection renders gold on open, the chevron flips
-- while open, a disabled entry is greyed and unselectable (its click is swallowed,
-- not passed through), clicking anywhere outside closes the menu, opening one menu
-- closes the other, and Esc closes only the open menu (try Esc with a menu up vs.
-- none — with none, Esc should close the test window instead). The third dropdown
-- exercises the borderless variant.
---@return TitleFrame
local function makeFilterDropdown()
  local f = window("FilterDropdown", 320, 140)

  local readout = Label:new{
    parent = f,
    position = { Top = {f.titlebar, "BOTTOM", 0, -16} },
    text = "pick one",
  }

  FilterDropdown:new{
    parent = f,
    position = { TopLeft = {f, "TOPLEFT", 20, -44} },
    width = 130, bordered = true, selected = "all",
    options = {
      { key = "all", label = "Expansion" },
      { key = 11,    label = "The War Within" },
      { key = 12,    label = "Midnight" },
      { key = 13,    label = "An Overlong Label That Widens The Menu" },
      { key = 99,    label = "Disabled", enabled = false },
    },
    onSelect = function(_, key) readout:Text("expansion: " .. tostring(key)) end,
  }

  FilterDropdown:new{
    parent = f,
    position = { TopLeft = {f, "TOPLEFT", 160, -44} },
    width = 110, bordered = true, selected = "all",
    options = {
      { key = "all",  label = "Category" },
      { key = "Raid", label = "Raid" },
      { key = "PvP",  label = "PvP" },
    },
    onSelect = function(_, key) readout:Text("category: " .. tostring(key)) end,
  }

  FilterDropdown:new{
    parent = f,
    position = { TopLeft = {f, "TOPLEFT", 20, -72} },
    width = 130, selected = 1,
    options = {
      { key = 1, label = "Borderless" },
      { key = 2, label = "Second" },
    },
    onSelect = function(_, key) readout:Text("borderless: " .. tostring(key)) end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "filterdropdown",
  name = "Filter Dropdown",
  desc = "Select control: aligned attached menu, gold selection, click-outside close",
  run  = toggling(makeFilterDropdown),
})
