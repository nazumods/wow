local _, ns = ...
local ui = ns.ui
local Class, BgFrame = ns.lua.Class, ui.BgFrame

local TableCol = Class(BgFrame, function(self)
  local p = self.padding or 0
  local headerPosition
  if self.path then
    -- path-based icons (e.g. currency icons) have no atlas-size constraint,
    -- so they stretch to fill the header rect. Pin them to a square anchored
    -- to the top of the column so wider columns don't distort them.
    local size = self.headerHeight - 2 * p
    headerPosition = {
      Top = {0, -p},
      Size = {size, size},
    }
  else
    headerPosition = {
      TopLeft = {p, -p},
      BottomRight = {self, ui.edge.TopRight, -p, -self.headerHeight + p},
    }
  end
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
    position = headerPosition,
  }
end)
ui.TableCol = TableCol
