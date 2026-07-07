local ScrollFrame = LibNUI.ScrollFrame
local Frame    = LibNUI.Frame
local Label    = LibNUI.Label
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- A scroll container with the opt-in themed scrollbar: proves the auto-hiding gold
-- thumb tracks the offset, drag scrolls, and the mousewheel stays in sync.
---@return TitleFrame
local function makeScrollFrame()
  local f = window("ScrollFrame", 260, 260)

  local scroll = ScrollFrame:new{
    parent    = f,
    scrollbar = true,
    position  = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT",  8, -6},
      BottomRight = {f,          "BOTTOMRIGHT", -8,  8},
    },
  }

  local child = Frame:new{ parent = scroll, position = { Width = 210 } }
  local y = -4
  for i = 1, 30 do
    Label:new{
      parent   = child,
      text     = "Scrollable row " .. i,
      position = { TopLeft = {child, "TOPLEFT", 4, y} },
    }
    y = y - 22
  end
  child:Height(30 * 22 + 8)

  scroll:Child(child)
  scroll:Refresh()   -- populate the range so the scrollbar sizes + shows

  return f
end

table.insert(LibNUITest.tests, {
  key  = "scrollframe",
  name = "ScrollFrame",
  desc = "Scroll container with the themed auto-hiding scrollbar + mousewheel",
  run  = toggling(makeScrollFrame),
})
