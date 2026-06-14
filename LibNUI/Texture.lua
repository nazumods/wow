---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, unpack = ns.lua.Class, unpack
local Region = ui.Region

---@class Texture: Region
---@field atlas string?  atlas name
---@field atlasSize boolean?  use the atlas's native size (false disables explicitly)
---@field rotation number?  rotation in radians (consumed at construction)
---@field color string|number[]?  solid color: theme token or rgba table (0–1 channels)
---@field vertexColor string|number[]?  vertex color: theme token or rgba table
---@field blendMode string?  blend mode (e.g. "ADD")
---@field gradient table?  SetGradient args {orientation, minColor, maxColor}
---@field path string|number?  texture path or fileID
---@field coords number[]?  tex coords {left, right, top, bottom}
local Texture = Class(Region, function(self)
  if self.atlas then
    -- `X ~= nil and X or true` collapses to `true` when X is false, defeating
    -- atlasSize = false. Branch explicitly so the caller's false is honored.
    if self.atlasSize == nil then
      self._widget:SetAtlas(self.atlas)
    else
      self._widget:SetAtlas(self.atlas, self.atlasSize)
    end
  end
  if self.rotation then self._widget:SetRotation(self.rotation); self.rotation = nil end

  if self.color then self:Color(self.color) end
  if self.vertexColor then self:SetVertexColor(self.vertexColor) end
  if self.blendMode then self._widget:SetBlendMode(self.blendMode) end
  if self.gradient then self._widget:SetGradient(unpack(self.gradient)) end

  if self.path then self:Texture(self.path) end
  if self.coords then self:Coords(unpack(self.coords)) end
end, {
  CreateWidget = function(self)
    return (self.parent._widget or self.parent):CreateTexture(self.name, self.layer, self.template)
  end,
})
ui.Texture = Texture

---@param ... any  SetAtlas args: atlasName (string), useAtlasSize (boolean?)
function Texture:Atlas(...) self._widget:SetAtlas(...) end
---@param texture string|number  texture path or fileID
function Texture:Texture(texture) self._widget:SetTexture(texture) end
-- Set a solid color fill. Accepts a theme token, a color table / ColorMixin,
-- or individual channels.
---@param r string|table|number  theme color token, rgba table, ColorMixin, or red channel (0–1)
---@param g number?  green channel (0–1)
---@param b number?  blue channel (0–1)
---@param a number?  alpha channel (0–1)
function Texture:Color(r, g, b, a)
  if type(r) == "string" then r = self:Theme().colors[r] end
  if type(r) == "table" then
    if r.GetRGBA then
      r, g, b, a = r:GetRGBA()
    else
      r, g, b, a = unpack(r)
    end
  end
  self._widget:SetColorTexture(r, g, b, a)
end
---@param r string|table|number  theme color token, rgba table, ColorMixin, or red channel (0–1)
---@param g number?  green channel (0–1)
---@param b number?  blue channel (0–1)
---@param a number?  alpha channel (0–1)
function Texture:SetVertexColor(r, g, b, a)
  if type(r) == "string" then r = self:Theme().colors[r] end
  if type(r) == "table" then
    if r.GetRGBA then
      r, g, b, a = r:GetRGBA()
    else
      r, g, b, a = unpack(r)
    end
  end
  self._widget:SetVertexColor(r, g, b, a)
end
---@param ... number  SetTexCoord args: left, right, top, bottom (or 8-arg corner form)
function Texture:Coords(...) self._widget:SetTexCoord(...) end
-- Apply (or re-apply) a vertex gradient over the texture. minColor sits at the
-- left/top edge, maxColor at the right/bottom; both are ColorMixins, so their
-- alpha is interpolated too. Needs a base texture (e.g. a solid color fill).
---@param orientation string  "HORIZONTAL" | "VERTICAL"
---@param minColor table  ColorMixin at the min edge
---@param maxColor table  ColorMixin at the max edge
function Texture:Gradient(orientation, minColor, maxColor)
  self._widget:SetGradient(orientation, minColor, maxColor)
end
-- nine-slice: margins are in source-texture pixels; mode is Enum.UITextureSliceMode
---@param l number
---@param t number
---@param r number
---@param b number
function Texture:SliceMargins(l, t, r, b) self._widget:SetTextureSliceMargins(l, t, r, b) end
---@param mode number  Enum.UITextureSliceMode
function Texture:SliceMode(mode) self._widget:SetTextureSliceMode(mode) end
