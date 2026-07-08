---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

-- One "label: value" stat field — an optional small icon, a muted label, and an accent
-- value to its right. Stack several for a summary block; the returned widget keeps a
-- `Value` setter for live updates. Height defaults to the icon size; width to fit is the
-- caller's anchoring choice.
---@class LabeledValue: Frame
---@field label string           the field caption
---@field value string|number?   initial value text
---@field icon string|number?    optional icon (path or fileID) left of the label
---@field labelColor string|table  caption colour (default "muted")
---@field valueColor string|table  value colour (default "header")
---@field iconSize number        icon square size in px (default 16)
---@field gap number             px between icon/label/value (default 4)
---@field height number          row height (default 16) — intrinsic, survives any `position`
---@field valueLabel Label
---@field _icon Texture?
local LabeledValue = Class(Frame, function(self)
  self:Height(self.height)   -- intrinsic (a caller's position table would replace a position default)
  local left = 0
  if self.icon then
    self._icon = Texture:new{
      parent = self, layer = ui.layer.Artwork, path = self.icon,
      coords = {0.08, 0.92, 0.08, 0.92},
      position = { Left = {self, 0, 0}, Size = {self.iconSize, self.iconSize} },
    }
    left = self.iconSize + self.gap
  end

  local caption = Label:new{
    parent = self, text = self.label, color = self.labelColor,
    position = { Left = {self, left, 0} },
  }
  self.valueLabel = Label:new{
    parent = self, text = self.value, color = self.valueColor,
    position = { Left = {caption, ui.edge.Right, self.gap, 0} },
  }
end, {
  type       = "Frame",
  labelColor = "muted",
  valueColor = "header",
  iconSize   = 16,
  gap        = 4,
  height     = 16,
})
ui.LabeledValue = LabeledValue

-- Get/set the value text.
---@param v string|number?
---@return string|LabeledValue
function LabeledValue:Value(v)
  if v == nil then return self.valueLabel:Text() end
  self.valueLabel:Text(v)
  return self
end
