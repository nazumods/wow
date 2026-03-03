local _, ns = ...
local ui = ns.ui
local Class, BgFrame = ns.lua.Class, ui.BgFrame

local TableCol = Class(BgFrame, function(self)
  self.header = ui.AutoWidget:new{
    parent = self,
    -- label
    label = self.label,
    font = self.font,
    color = self.color or {1, 215/255, 0, 1},
    justifyH = self.justifyH or ui.justify.Center,
    justifyV = ui.justify.Middle,
    -- texture
    atlas = self.atlas,
    atlasSize = self.atlasSize,
    path = self.path,
    coords = self.coords,
    vertexColor = self.vertexColor,
    layer = (self.path or self.atlas) and ns.ui.layer.Artwork,
    position = {
      TopLeft = {self.padding or 0, -(self.padding or 0)},
      BottomRight = {self, ui.edge.TopRight, -(self.padding or 0), -self.headerHeight + (self.padding or 0)},
    },
  }
end)
ui.TableCol = TableCol
