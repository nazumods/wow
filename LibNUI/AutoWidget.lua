local _, ns = ...
local ui = ns.ui
local Class, Button, Label, Texture = ns.lua.Class, ui.Button, ui.Label, ui.Texture

-- A widget that automatically configures itself as a Label, Texture, or Button
-- depending on the options. When updating it will reconfigure itself as necessary.
local AutoWidget = Class(nil, function(self)
  if self.onClick then
    self.button = Button:new{
      parent = self.parent,
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
      color = self.color or {1, 1, 1, 1},
      justifyH = self.justifyH or ui.justify.Center,
      justifyV = ui.justify.Middle,
    }
  end
end)
ui.AutoWidget = AutoWidget

function AutoWidget:update(data)
end
