---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class, BgFrame = ns.lua.Class, ui.BgFrame

---@class TableRow: BgFrame
---@field header AutoWidget  row header content (label or texture)
---@field label string?  header text
local TableRow = Class(BgFrame, function(self)
  self.header = ui.AutoWidget:new{
    parent = self,
    -- label
    label = self.label,
    font = self.font,
    fontInfo = not self.font and self:Theme().fonts.header or nil,
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
