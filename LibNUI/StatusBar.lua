local _, ns = ...

local ui = ns.ui
local Class, unpack, Mixin = ns.lua.Class, unpack, Mixin
local Frame, Texture = ui.Frame, ui.Texture

-- https://wowpedia.fandom.com/wiki/Widget_API#StatusBar

local StatusBar = Class(Frame, function(self)
  if self.backdrop then
    self.backdrop = Texture:new(Mixin({
      parent = self,
      name = "$parentBackdrop",
      layer = ui.layer.Background,
      position = { All = true },
      color = {0, 0, 0, 0.8}
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
    if type(self.texture) == "table" then
      local tOps = self.texture
      local tex = Texture:new(Mixin({
        parent = self,
      }, tOps))
      self._widget:SetStatusBarTexture(tex._widget)
      tex._widget:ClearAllPoints()
      tex:Top(self)
      tex:Left(self)
      tex:Right(self)
      tex:Bottom(self)
      local l, r, t, b = unpack(tOps.coords or {0, 1, 0, 1})
      self.X1 = l
      self.X2 = r
      self.Xd = r - l
      self.Y1 = t
      self.Y2 = b
      self.Yd = b - t
      self.texture = tex
    else
      self._widget:SetStatusBarTexture(self.texture)
      self.texture = nil
    end
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

function StatusBar:Color(c) self._widget:SetColorFill(unpack(c)) end
function StatusBar:Texture(t) self._widget:SetStatusBarTexture(t) end

function StatusBar:SetValue(v)
  if not self.texture then self._widget:SetValue(v); return end
  local n, m = self._widget:GetMinMaxValues()
  local p = 1 - (v / (m-n))
  local dx, dy = self.Xd * p, self.Yd * p
  local l, r, t, b = self.X1, self.X2, self.Y1, self.Y2
  if self._widget:GetOrientation() == "HORIZONTAL" then
    if dx > 0 then -- luacheck: ignore
      --
    end
  else -- vertical
    -- bottom up
    t = t + dy
    self.texture:Top(0, self:Height() * -dy)
  end
  self.texture:Coords(l, r, t, b)
end
