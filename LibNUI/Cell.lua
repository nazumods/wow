local _, ns = ...
local ui = ns.ui
local Class, Frame = ns.lua.Class, ui.Frame
local Label, Texture = ui.Label, ui.Texture

local Cell = Class(Frame, function(self)
  -- cells are parented to the view, same as the rows and cols,
  -- so raise it above them
  self._widget:Raise()
  local data = type(self.data) == "table" and self.data or {text = self.data}
  if data.onClick then self:SetScript("OnMouseUp", function() data.onClick(self) end) end
  if data.onEnter then self:SetScript("OnEnter", function() data.onEnter(self) end) end
  if data.onLeave then self:SetScript("OnLeave", function() data.onLeave(self) end) end
  if data.path or data.atlas then
    self:Texture()
  else
    self:Label()
  end
end)
ui.Cell = Cell

function Cell:Texture()
  local data = self.data
  if self.texture then
    if data.path then
      self.texture:Texture(data.path)
      if data.coords then self.texture:Coords(unpack(data.coords)) end
      if data.vertexColor then self.texture:SetVertexColor(unpack(data.vertexColor)) end
    end
    if data.atlas then self.texture:Atlas(data.atlas, data.atlasSize ~= nil and data.atlasSize or true) end
    if data.position then self.texture:Position(data.position) end
  else
    self.texture = Texture:new{
      parent = self,
      atlas = data.atlas,
      atlasSize = data.atlasSize,
      path = data.path,
      coords = data.coords,
      vertexColor = data.vertexColor,
      layer = ns.ui.layer.Artwork,
      position = data.position or { All = true },
    }
  end
end

function Cell:Label()
  local data = type(self.data) == "table" and self.data or {text = self.data}
  if self.label then
    self.label:Text(data.text)
    if data.color then self.label:Color(data.color) end
  else
    self.label = Label:new{
      parent = self,
      text = data.text,
      color = data.color,
      font = data.font,
      position = { All = true },
      justifyH = data.justifyH or ui.justify.Left,
    }
  end
end

function Cell:update(data)
  self.data = data
  if type(data) == "table" and (data.path or data.atlas) then
    if self.label then self.label:Hide() end
    if self.texture then self.texture:Show() end
    self:Texture()
  else
    if self.texture then self.texture:Hide() end
    if self.label then self.label:Show() end
    self:Label()
  end
  if type(data) == "table" then
    if data.onClick then self:SetScript("OnMouseUp", function() data.onClick(self) end) else self:RemoveScript("OnMouseUp") end
    if data.onEnter then self:SetScript("OnEnter", function() data.onEnter(self) end) else self:RemoveScript("OnEnter") end
    if data.onLeave then self:SetScript("OnLeave", function() data.onLeave(self) end) else self:RemoveScript("OnLeave") end
  end
end
