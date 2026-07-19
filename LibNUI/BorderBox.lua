---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Texture = ui.Frame, ui.Texture
local e = ui.edge

-- A thin rectangular outline: four edge textures hugging the frame's own rect, with a
-- transparent interior (it draws only the border). Each edge is two-point-anchored to a
-- pair of the frame's corners, so it stretches with the frame and a resize needs no
-- re-layout. Overlay it on content, or anchor it to a sub-region to frame just that part
-- — e.g. a border around an icon + its number inside a composite table Cell.
---@class BorderBox: Frame
---@field thickness number       edge width in px (default 1)
---@field color string|number[]  edge colour: theme token or rgba (default "border")
---@field _edges Texture[]       edge textures {top, bottom, left, right}
local BorderBox = Class(Frame, function(self)
  local function edge()
    return Texture:new{ parent = self, color = self.color, layer = ui.layer.Overlay, position = {} }
  end
  local top, bottom, left, right = edge(), edge(), edge(), edge()
  self._edges = { top, bottom, left, right }
  local t = self.thickness
  top:SetPoint(e.TopLeft, self, e.TopLeft);        top:SetPoint(e.TopRight, self, e.TopRight);          top:Height(t)
  bottom:SetPoint(e.BottomLeft, self, e.BottomLeft); bottom:SetPoint(e.BottomRight, self, e.BottomRight); bottom:Height(t)
  left:SetPoint(e.TopLeft, self, e.TopLeft);        left:SetPoint(e.BottomLeft, self, e.BottomLeft);      left:Width(t)
  right:SetPoint(e.TopRight, self, e.TopRight);     right:SetPoint(e.BottomRight, self, e.BottomRight);   right:Width(t)
end, {
  thickness = 1,
  color = "border",
})
ui.BorderBox = BorderBox

-- Recolour all four edges.
---@param c string|number[]  theme token or rgba
---@return BorderBox
function BorderBox:Color(c)
  for _, tex in ipairs(self._edges) do tex:Color(c) end
  return self
end

-- Set the edge thickness (px) for all four edges.
---@param t number
---@return BorderBox
function BorderBox:Thickness(t)
  self._edges[1]:Height(t); self._edges[2]:Height(t)
  self._edges[3]:Width(t);  self._edges[4]:Width(t)
  return self
end
