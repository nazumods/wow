local RingSelector = LibNUI.RingSelector
local window   = LibNUITest.window
local toggling = LibNUITest.toggling

-- A handful of class glyphs so the layout + aim-highlight are visible without any
-- keybind wiring. Point the cursor at a slice (the title shows in the center) and
-- click to fire onSelect.
local ITEMS = {
  { name = "warrior", atlas = "classicon-warrior", title = "Warrior" },
  { name = "mage",    atlas = "classicon-mage",    title = "Mage" },
  { name = "priest",  atlas = "classicon-priest",  title = "Priest" },
  { name = "rogue",   atlas = "classicon-rogue",   title = "Rogue" },
  { name = "druid",   atlas = "classicon-druid",   title = "Druid" },
  { name = "paladin", atlas = "classicon-paladin", title = "Paladin" },
  { name = "hunter",  atlas = "classicon-hunter",  title = "Hunter" },
  { name = "shaman",  atlas = "classicon-shaman",  title = "Shaman" },
}

---@return TitleFrame
local function makeRing()
  local f = window("Ring Selector", 320, 320)
  RingSelector:new{
    parent   = f,
    items    = ITEMS,
    position = { Center = {} },
    onSelect = function(name) print("RingSelector selected:", name) end,
  }
  return f
end

table.insert(LibNUITest.tests, {
  key  = "ring",
  name = "Ring Selector",
  desc = "Radial selector — aim a slice, click to select",
  run  = toggling(makeRing),
})
