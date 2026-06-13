---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class, Button, Label, Texture = ns.lua.Class, ui.Button, ui.Label, ui.Texture

---@class LibNUI
---@field AutoWidget AutoWidget

-- A widget that automatically configures itself as a Label, Texture, or Button
-- depending on the options passed at construction time.
---@class AutoWidget: Class
---@field parent table  parent widget the content is created in
---@field button Button?  created when an onClick option is given
---@field texture Texture?  created when a path/atlas option is given
---@field label Label?  created otherwise (the `label` option is the text)
local AutoWidget = Class(nil, function(self)
  if self.onClick then
    -- label/position/font options are not forwarded to Button; set them on
    -- self.button after construction if needed.
    self.button = Button:new{
      parent = self.parent,
      onClick = self.onClick,
    }
  elseif self.path or self.atlas then
    self.texture = Texture:new{
      parent = self.parent,
      atlas = self.atlas,
      atlasSize = self.atlasSize,
      path = self.path,
      coords = self.coords,
      vertexColor = self.vertexColor,
      layer = ui.layer.Artwork,
      position = self.position or {All = true},
    }
  else
    self.label = Label:new{
      parent = self.parent,
      text = self.label,
      position = self.position or {All = true},
      font = self.font,
      fontInfo = self.fontInfo,
      color = self.color or "text",
      justifyH = self.justifyH or ui.justify.Center,
      justifyV = ui.justify.Middle,
    }
  end
end)
ui.AutoWidget = AutoWidget

-- Stub: reconfiguration on data change is not yet implemented.
---@param _data any
function AutoWidget:update(_data)
end
