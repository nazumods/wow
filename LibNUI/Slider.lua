---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Texture, Label = ui.Frame, ui.Texture, ui.Label

-- https://warcraft.wiki.gg/wiki/UIOBJECT_Slider
-- A value slider: a themed track with a draggable gold thumb. Drag or click to
-- change the value; OnChange fires with the new value (and whether it came from
-- the user). Set `step` to snap to increments.
---@class Slider: Frame
---@field min number  minimum value (default 0)
---@field max number  maximum value (default 1)
---@field step number?  value step; also snaps while dragging when set
---@field value number?  initial value
---@field orientation string  "HORIZONTAL" (default) | "VERTICAL"
---@field thickness number  track thickness in px (default 4)
---@field OnChange fun(self: Slider, value: number, userInput: boolean)?  value-changed callback
---@field label string?  optional caption shown above the track's left end
---@field valueFormat fun(value: number): string?  optional formatter; enables a live value readout above the track's right end
---@field caption Label?  the caption Label (when `label` is set)
---@field valueLabel Label?  the readout Label (when `valueFormat` is set)
---@field track Texture  the bar track behind the thumb
---@field _thumb Texture  the draggable handle
local Slider = Class(Frame, function(self)
  local w = self._widget
  local horizontal = self.orientation == "HORIZONTAL"
  w:EnableMouse(true)   -- required for the thumb to be grabbable / track clickable
  w:SetOrientation(self.orientation)
  w:SetMinMaxValues(self.min, self.max)
  if self.step then w:SetValueStep(self.step); w:SetObeyStepOnDrag(true) end

  -- Track: a thin themed bar centered along the slider's length.
  self.track = Texture:new{
    parent = self, layer = ui.layer.Background, color = "backdrop",
    position = horizontal
      and { Left = {0, 0}, Right = {0, 0}, Height = self.thickness }
      or  { Top = {0, 0}, Bottom = {0, 0}, Width = self.thickness },
  }

  -- Thumb: a small gold handle. SetThumbTexture hands its positioning to the
  -- Slider, so we only set its size here.
  self._thumb = Texture:new{
    parent = self, layer = ui.layer.Overlay, color = "header",
    position = { Size = horizontal and {12, 16} or {16, 12} },
  }
  w:SetThumbTexture(self._thumb._widget)

  -- optional caption + live value readout, floating just above the track ends so they
  -- add no layout height of their own
  if self.label then
    self.caption = Label:new{
      parent = self, text = self.label, color = "muted",
      font = ui.fonts.GameFontHighlightSmall,
      position = { BottomLeft = {self, ui.edge.TopLeft, 0, 2} },
    }
  end
  if self.valueFormat then
    self.valueLabel = Label:new{
      parent = self, color = "header", justifyH = ui.justify.Right,
      font = ui.fonts.GameFontHighlightSmall,
      position = { BottomRight = {self, ui.edge.TopRight, 0, 2} },
    }
  end

  w:SetScript("OnValueChanged", function(_, value, userInput)
    if self.valueLabel then self.valueLabel:Text(self.valueFormat(value)) end
    if self.OnChange then self:OnChange(value, userInput) end
  end)
  if self.value then
    w:SetValue(self.value)
    -- SetValue at the initial value may not fire OnValueChanged; seed the readout
    if self.valueLabel then self.valueLabel:Text(self.valueFormat(self.value)) end
  end
end, {
  type = "Slider",
  min = 0,
  max = 1,
  orientation = "HORIZONTAL",
  thickness = 4,
})
ui.Slider = Slider

-- Get/set the slider value. Setting also fires OnChange (userInput = false).
---@param v number?
---@return number|Slider
function Slider:Value(v)
  if v == nil then return self._widget:GetValue() end
  self._widget:SetValue(v)
  return self
end

---@param min number
---@param max number
---@return Slider
function Slider:MinMax(min, max)
  self._widget:SetMinMaxValues(min, max)
  return self
end
