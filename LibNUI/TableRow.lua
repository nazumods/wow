local _, ns = ...
local ui = ns.ui
local Class, BgFrame = ns.lua.Class, ui.BgFrame

local TableRow = Class(BgFrame, function(self)
  self.header = ui.AutoWidget:new{
    parent = self,
    -- label
    label = self.label,
    font = self.font,
    color = self.color,
    justifyH = self.justifyH or ui.justify.Center,
    justifyV = ui.justify.Middle,
    -- texture
    atlas = self.atlas,
    atlasSize = self.atlasSize,
    path = self.path,
    coords = self.coords,
    vertexColor = self.vertexColor,
    layer = (self.path or self.atlas) and ns.ui.layer.Artwork,
    position = {Left = {2, 0}},
  }
end)
ui.TableRow = TableRow
