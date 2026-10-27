---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, unpack, Mixin = ns.lua.Class, unpack, Mixin
local Frame, Texture = ui.Frame, ui.Texture

-- https://wowpedia.fandom.com/wiki/Widget_API#StatusBar

---@class StatusBar: Frame
---@field backdrop table|Texture?  backdrop options at construction; the built Texture afterwards
---@field fill table|Texture?  fill texture options ({color, gradient, blend}) at construction; the built Texture afterwards
---@field color number[]?  initial fill color (rgba, 0–1 channels)
---@field texture string|number?  bar texture path or fileID (consumed at construction)
---@field orientation string?  "HORIZONTAL"|"VERTICAL"
---@field min number?  minimum value
---@field max number?  maximum value
local StatusBar = Class(Frame, function(self)
  if self.backdrop then
    self.backdrop = Texture:new(Mixin({
      parent = self,
      name = "$parentBackdrop",
      layer = ui.layer.Background,
      position = { All = true },
      color = "backdrop"
    }, self.backdrop))
  end

  if self.fill then
    local fill = self.fill
    self.fill = Texture:new{
      parent = self,
      name = "$parentFill",
      layer = ui.layer.Artwork,
      color = fill.color,
      gradient = fill.gradient,
      blendMode = fill.blend,
    }
  end
  if self.color then self._widget:SetColorFill(unpack(self.color)) end

  if self.texture then
    self._widget:SetStatusBarTexture(self.texture)
    self.texture = nil
  end

  if self.orientation then self._widget:SetOrientation(self.orientation) end
  if self.min and self.max then self._widget:SetMinMaxValues(self.min, self.max) end
end, {
  type = "StatusBar"
})
ui.StatusBar = StatusBar

function StatusBar:onLoad()
  if self.fill then
    self.fill:BottomLeft()
    self.fill:Height(self:Height())
  end
end

---@param c number[]  fill color (rgba, 0–1 channels)
function StatusBar:Color(c) self._widget:SetColorFill(unpack(c)) end
---@param t string|number  texture path or fileID
function StatusBar:Texture(t) self._widget:SetStatusBarTexture(t) end

---@param v number
function StatusBar:SetValue(v) self._widget:SetValue(v) end
