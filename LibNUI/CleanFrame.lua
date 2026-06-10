local _, ns = ...
local ui = ns.ui

local Class, Frame, unpack = ns.lua.Class, ui.Frame, unpack
local TopLeft, BottomRight = ui.edge.TopLeft, ui.edge.BottomRight

local CleanFrame = Class(Frame, function(self)
  self.border = Frame:new{
    parent = self,
    name = "$parentBorder",
    template = "BackdropTemplate",
    position = {
      TopLeft = {self, TopLeft, -3, 3},
      BottomRight = {self, BottomRight, 3, -3},
    },
  }
  -- from BackdropTemplate
  self.border._widget:SetBackdrop({
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4},
  })
  self.border._widget:SetBackdropBorderColor(unpack(self:ThemeColor("border")))
end, {
  parent = UIParent,
  clamped = true,
  strata = "MEDIUM",
  background = "window",
})
ui.CleanFrame = CleanFrame
