local Slider   = LibNUI.Slider
local Label    = LibNUI.Label
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- A value slider wired to a readout label; proves the thumb drag, step snapping,
-- and the OnChange callback.
---@return TitleFrame
local function makeSlider()
  local f = window("Slider", 280, 120)

  local readout = Label:new{
    parent = f,
    position = { Top = {f.titlebar, "BOTTOM", 0, -20} },
    text = "1.00",
  }

  Slider:new{
    parent = f,
    min = 0.5, max = 2.5, step = 0.05, value = 1,
    position = {
      Left  = {f, "LEFT", 20, -12},
      Right = {f, "RIGHT", -20, -12},
      Height = 16,
    },
    OnChange = function(_, v) readout:Text(("%.2f"):format(v)) end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "slider",
  name = "Slider",
  desc = "Value slider with a draggable thumb + OnChange readout",
  run  = toggling(makeSlider),
})
