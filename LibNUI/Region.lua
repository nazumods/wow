local _, ns = ...
local ui = ns.ui

local Class, unpack = ns.lua.Class, unpack

---@class Region
---@field _widget table backing WoW UI widget
---@field OnBeforeShow function
local Region = Class(nil, function(self)
  self._widget = self:CreateWidget()
  if self.position then self:Position(self.position) end
  if self.alpha then self:Alpha(self.alpha) end
end)
ui.Region = Region

function Region:Parent(parent)
  self._widget:SetParent(parent._widget or parent)
end

function Region:Position(position)
  for k,v in pairs(position) do
    if self[k] then
      if type(v) == "table" then
        self[k](self, unpack(v))
      elseif v ~= false then
        self[k](self, v)
      end
    end
  end
end

function Region:GetName() return self._widget:GetName() end

function Region:SetPoint(point, target, edge, x, y)
  if type(target) == "table" and target._widget then target = target._widget end
  -- must be called with explicit arguments, passing nil confuses it
  if x == nil and y == nil then
    if target == nil and edge == nil then
      self._widget:SetPoint(point)
    else
      self._widget:SetPoint(point, target, edge)
    end
  else
    self._widget:SetPoint(point, target, edge, x, y)
  end
end

function Region:All() self._widget:SetAllPoints() end
function Region:Center(...) self:SetPoint(ui.edge.Center, ...) end
function Region:Top(...) self:SetPoint(ui.edge.Top, ...) end
function Region:TopLeft(...) self:SetPoint(ui.edge.TopLeft, ...) end
function Region:TopRight(...) self:SetPoint(ui.edge.TopRight, ...) end
function Region:Bottom(...) self:SetPoint(ui.edge.Bottom, ...) end
function Region:BottomLeft(...) self:SetPoint(ui.edge.BottomLeft, ...) end
function Region:BottomRight(...) self:SetPoint(ui.edge.BottomRight, ...) end
function Region:Left(...) self:SetPoint(ui.edge.Left, ...) end
function Region:Right(...) self:SetPoint(ui.edge.Right, ...) end

function Region:Size(x, y) return x == nil and self._widget:GetSize() or self._widget:SetSize(x, y) end

function Region:Width(w) return w == nil and self._widget:GetWidth() or self._widget:SetWidth(w) end
function Region:Height(h) return h == nil and self._widget:GetHeight() or self._widget:SetHeight(h) end

function Region:Show()
  if self.OnBeforeShow then self:OnBeforeShow() end
  self._widget:Show()
end
function Region:Hide() self._widget:Hide() end
function Region:SetShown(b) if b then self:Show() else self:Hide() end end
function Region:Toggle() self:SetShown(not self._widget:IsVisible()) end

function Region:Alpha(a) return a == nil and self._widget:GetAlpha() or self._widget:SetAlpha(a) end
