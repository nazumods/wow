---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, BgFrame = ns.lua.Class, ui.BgFrame

---@class TableRow: BgFrame
---@field header AutoWidget  row header content (label or texture)
---@field label string?  header text
---@field _highlight Texture?  lazy translucent overlay for the active/current row
---@field _highlighted boolean?  current highlight state
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

-- Mark this row as the active/current one: a translucent accent overlay (the "highlight"
-- theme token) above the row backdrop, created lazily and toggled thereafter — the row's
-- own backdrop colour is never touched, so rowEven/rowOdd striping survives
-- un-highlighting. BgFrame draws its backdrop on the OVERLAY layer (above the ARTWORK
-- header text), so the overlay is stacked at OVERLAY sublevel 1 (above the backdrop) and
-- the header label is lifted to sublevel 2 while highlighted, keeping the text legible
-- on top of the gold rather than tinted by it.
---@param b boolean?
---@return boolean|TableRow  the current state when getting; self when setting
function TableRow:Highlighted(b)
  if b == nil then return self._highlighted or false end
  if b and not self._highlight then
    self._highlight = ui.Texture:new{
      parent = self,
      layer = ui.layer.Overlay,
      color = "highlight",
      position = { All = true },
    }
    self._highlight:DrawLayer(ui.layer.Overlay, 1)
  end
  if self._highlight then self._highlight:SetShown(b) end
  local label = self.header and self.header.label
  if label then
    -- lift above the highlight while active; restore to the default ARTWORK layer
    -- (below the backdrop, as every other row) when cleared
    if b then label:DrawLayer(ui.layer.Overlay, 2)
    else label:DrawLayer(ui.layer.Artwork, 0) end
  end
  self._highlighted = b
  return self
end
