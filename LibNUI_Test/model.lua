local Model    = LibNUI.Model
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Shows the logged-in character on a draggable, zoomable model viewer. Drag to
-- spin, scroll to zoom; proves SetUnit + the rotate/zoom mouse wiring.
---@return TitleFrame
local function makeModel()
  local f = window("Model", 280, 380)

  local model = Model:new{
    parent = f,
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT", 4, -4},
      BottomRight = {f, "BOTTOMRIGHT", -4, 4},
    },
  }
  model:Unit("player")

  return f
end

table.insert(LibNUITest.tests, {
  key  = "model",
  name = "Model",
  desc = "DressUpModel viewer with drag-rotate + scroll-zoom",
  run  = toggling(makeModel),
})
