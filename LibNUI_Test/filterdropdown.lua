local FilterDropdown = LibNUI.FilterDropdown
local Label    = LibNUI.Label
local Button   = LibNUI.Button
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
--
-- The "Swap options" button exercises FilterDropdown:SetOptions on the middle
-- (Category) dropdown, cycling three sets: 3 options (flat), 5 options (flat, a
-- wider label), and 25 options (scrolls, past the maxMenuHeight cap). Verify the
-- surviving "all" key stays selected across every swap (label re-points), the
-- rebuilt menu shows the new options (open it after each swap), the menu re-widens
-- to the longest new label, the 25-option set scrolls with the themed scrollbar and
-- the shorter sets go back to flat (no scrollbar), rows reuse cleanly with no stale
-- hover/click, and opening it still closes the others. (Rows are pooled + re-laid in
-- place, so no frames leak across swaps.)
---@return TitleFrame
local function makeFilterDropdown()
  local f = window("FilterDropdown", 320, 168)

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

  local category = FilterDropdown:new{
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

  local short = {
    { key = "all",  label = "Category" },
    { key = "Raid", label = "Raid" },
    { key = "PvP",  label = "PvP" },
  }
  local long = {
    { key = "all",     label = "Category" },
    { key = "Dungeon", label = "Dungeon" },
    { key = "Raid",    label = "Raid (A Wider Label)" },
    { key = "PvP",     label = "PvP" },
    { key = "World",   label = "World" },
  }
  local many = { { key = "all", label = "Category" } }
  for i = 1, 24 do many[#many + 1] = { key = "opt" .. i, label = "Scrolling Option " .. i } end
  local sets = { short, long, many }   -- 3 flat, 5 flat, 25 scrolls — cycles on each click
  local si = 1
  local swap = Button:new{
    parent = f, glow = false, background = "backdrop",
    position = { TopLeft = {f, "TOPLEFT", 20, -100}, Size = {130, 22} },
    onClick = function()
      si = si % #sets + 1
      category:SetOptions(sets[si])
      readout:Text(("swapped [%d opts]: %s"):format(#sets[si], tostring(category.selected)))
    end,
  }
  swap:Text("Swap options")

  return f
end

table.insert(LibNUITest.tests, {
  key  = "filterdropdown",
  name = "Filter Dropdown",
  desc = "Select control: aligned attached menu, gold selection, click-outside close",
  run  = toggling(makeFilterDropdown),
})
