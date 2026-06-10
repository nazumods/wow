---@type LibNUI_AddOn
local ns = select(2, ...)

local ui = ns.ui
local Class, unpack = ns.lua.Class, unpack
local Region = ui.Region

---@class LibNUI
---@field Texture Texture

---@class Texture: Region
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

function Texture:Atlas(...) self._widget:SetAtlas(...) end
function Texture:Texture(texture) self._widget:SetTexture(texture) end
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
function Texture:Coords(...) self._widget:SetTexCoord(...) end
-- nine-slice: margins are in source-texture pixels; mode is Enum.UITextureSliceMode
function Texture:SliceMargins(l, t, r, b) self._widget:SetTextureSliceMargins(l, t, r, b) end
function Texture:SliceMode(mode) self._widget:SetTextureSliceMode(mode) end
